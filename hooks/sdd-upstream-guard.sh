#!/bin/bash
# H2: SDD Upstream Artifact Immutability Guard
# Hook type: PreToolUse (Edit, Write) | Timeout: 5s
# Enforces Art. 4 of the SDD Constitution: downstream skills cannot modify upstream artifacts.
#
# Immutability table (when stage X is running, these paths are PROHIBITED):
#   test-planner       → requirements/, spec/, audits/
#   plan-architect     → requirements/, spec/, audits/, test/
#   task-generator     → requirements/, spec/, audits/, test/, plan/
#   task-implementer   → requirements/, spec/, audits/, test/, plan/, task/
#
# Exceptions:
#   - spec-auditor (Mode Fix): spec/ is allowed (by design)
#   - task-implementer: Edit on task/TASK-FASE-*.md is allowed (checkbox updates)
#                       Write on task/* is blocked (full overwrite protection)
#   - req-change: requirements/ and spec/ are allowed (lateral skill)
#   - Always allowed (infrastructure, not pipeline artifacts): pipeline-state.json, .sdd/*,
#     changes/*, feedback/*, .claude/hooks/*, .claude/settings*.json, .claude/agents/*,
#     .claude/sdd/*, .claude/sdd-sessions.json
#   - No pipeline-state.json or no running stage: permissive mode (allow all)
#
# Dos raíces (hooks/lib/sdd-common.sh): REL_PATH es relativo al toplevel git del FICHERO
# (worktrees externos, claude -w y .claude/worktrees/x quedan cubiertos); pipeline-state.json
# se lee de STATE_ROOT (raíz del .git común).
#
# Con rol (SDD_ROLE o registro de sesiones) presente en .claude/sdd-sessions.json:
#   (a) REL_PATH fuera de `owns` del rol → deny, haya o no stage running.
#   (b) el stage running que aplica es el primero de `stages` del rol (no el primero global).
#   (c) el resto de reglas de inmutabilidad se aplica igual.
# Sin rol o sin registro → comportamiento anterior.

set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
if [ ! -f "$SDD_LIB" ]; then echo "sdd-upstream-guard: falta $SDD_LIB" >&2; exit 0; fi
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

INPUT=$(cat)

# Extract tool_name and file_path from hook input
TOOL_NAME=$(printf '%s' "$INPUT" | sdd_json_get - '.tool_name // .toolName // empty') || TOOL_NAME=""
FILE_PATH=$(printf '%s' "$INPUT" | sdd_json_get - '.toolInput.file_path // .tool_input.file_path // empty') || FILE_PATH=""

# If we can't determine the file path, allow
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

sdd_roots "$INPUT" "$FILE_PATH"
PIPELINE_STATE="$STATE_ROOT/pipeline-state.json"

# Not under the project: allow
case "$REL_PATH" in
  /*|[A-Za-z]:/*) exit 0 ;;
esac

deny() {
  local escaped
  escaped=$(sdd_json_string "$1")
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$escaped"
  exit 0
}

# Always allowed: infrastructure and lateral directories
case "$REL_PATH" in
  pipeline-state.json|.sdd/*|changes/*|feedback/*) exit 0 ;;
  .claude/hooks/*|.claude/settings*.json|.claude/agents/*|.claude/sdd/*|.claude/sdd-sessions.json) exit 0 ;;
esac

# Role (optional): ownership by path pattern
ROLE=$(sdd_role) || ROLE=""
ROLE_STAGES=""
if [ -n "$ROLE" ] && sdd_role_exists "$ROLE"; then
  OWNS=$(sdd_role_owns "$ROLE") || OWNS=""
  if ! sdd_globs_match "$REL_PATH" "$OWNS"; then
    OWNS_FLAT=$(printf '%s' "$OWNS" | tr '\n' ' ')
    deny "Rol $ROLE no posee $REL_PATH (owns: ${OWNS_FLAT% })"
  fi
  ROLE_STAGES=$(sdd_role_stages "$ROLE") || ROLE_STAGES=""
else
  ROLE=""
fi

# If no pipeline-state.json, permissive mode
if [ ! -f "$PIPELINE_STATE" ]; then
  exit 0
fi

# Running stages, one per line, in file order
get_running_stages() {
  jq -r '.stages // {} | to_entries[] | select(.value.status == "running") | .key' "$PIPELINE_STATE" 2>/dev/null
}

get_running_stages_node() {
  SDD_STATE_FILE="$PIPELINE_STATE" node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync(process.env.SDD_STATE_FILE, 'utf8'));
      for (const [k, v] of Object.entries(state.stages || {})) if (v && v.status === 'running') console.log(k);
    } catch(e) {}
  " 2>/dev/null
}

RUNNING_ALL=$(get_running_stages) || RUNNING_ALL=$(get_running_stages_node) || RUNNING_ALL=""

RUNNING_STAGE=""
for s in $RUNNING_ALL; do
  if [ -n "$ROLE" ]; then
    sdd_list_has "$ROLE_STAGES" "$s" || continue
  fi
  RUNNING_STAGE="$s"
  break
done

# No running stage = permissive mode
if [ -z "$RUNNING_STAGE" ]; then
  exit 0
fi

# Define prohibited paths per running stage
is_prohibited() {
  local stage="$1"
  local path="$2"
  local tool="$3"

  case "$stage" in
    test-planner)
      case "$path" in
        requirements/*|spec/*|audits/*) return 0 ;;
      esac
      ;;
    plan-architect)
      case "$path" in
        requirements/*|spec/*|audits/*|test/*) return 0 ;;
      esac
      ;;
    task-generator)
      case "$path" in
        requirements/*|spec/*|audits/*|test/*|plan/*) return 0 ;;
      esac
      ;;
    task-implementer)
      case "$path" in
        requirements/*|spec/*|audits/*|test/*|plan/*) return 0 ;;
        task/TASK-FASE-*.md)
          # Allow Edit (checkbox updates), block Write (full overwrite)
          [ "$tool" = "Write" ] && return 0
          ;;
        task/*) return 0 ;;
      esac
      ;;
    # spec-auditor: spec/ is allowed (Mode Fix), but requirements/ is not
    spec-auditor)
      case "$path" in
        requirements/*) return 0 ;;
      esac
      ;;
    # specifications-engineer: requirements/ is not modifiable
    specifications-engineer)
      case "$path" in
        requirements/*) return 0 ;;
      esac
      ;;
    # req-change is lateral: no restrictions (it can touch requirements/ and spec/)
    # requirements-engineer: no upstream to protect
    *)
      return 1
      ;;
  esac

  return 1
}

if is_prohibited "$RUNNING_STAGE" "$REL_PATH" "$TOOL_NAME"; then
  deny "SDD Art. 4 Violation: Stage '$RUNNING_STAGE' cannot modify upstream artifact '$REL_PATH'. Upstream artifacts are immutable during downstream execution. Complete the current stage first, or use sdd-req-change for controlled modifications."
fi

# Not prohibited — allow
exit 0
