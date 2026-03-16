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
#   - pipeline-state.json: always allowed (infrastructure, not pipeline artifact)
#   - No pipeline-state.json or no running stage: permissive mode (allow all)

set -euo pipefail

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's|\\|/|g')
PIPELINE_STATE="$PROJECT_DIR/pipeline-state.json"

# Extract tool_name and file_path from hook input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .toolName // empty' 2>/dev/null) || TOOL_NAME=""
FILE_PATH=$(echo "$INPUT" | jq -r '.toolInput.file_path // .tool_input.file_path // empty' 2>/dev/null) || FILE_PATH=""

# If we can't determine the file path, allow
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize path separators
FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

# Convert to relative path
REL_PATH="${FILE_PATH#$PROJECT_DIR/}"
# If path didn't change (wasn't under project dir), allow
if [ "$REL_PATH" = "$FILE_PATH" ]; then
  exit 0
fi

# Always allow pipeline-state.json itself
if [ "$REL_PATH" = "pipeline-state.json" ]; then
  exit 0
fi

# Always allow changes/, feedback/, .claude/ directories (lateral/infrastructure)
case "$REL_PATH" in
  changes/*|feedback/*|.claude/*)
    exit 0
    ;;
esac

# If no pipeline-state.json, permissive mode
if [ ! -f "$PIPELINE_STATE" ]; then
  exit 0
fi

# Find the running stage
get_running_stage() {
  jq -r '[.stages | to_entries[] | select(.value.status == "running") | .key] | first // empty' "$PIPELINE_STATE" 2>/dev/null
}

get_running_stage_node() {
  node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync('$PIPELINE_STATE', 'utf8'));
      const running = Object.entries(state.stages || {}).find(([,v]) => v.status === 'running');
      if (running) console.log(running[0]);
    } catch(e) {}
  " 2>/dev/null
}

RUNNING_STAGE=$(get_running_stage) || RUNNING_STAGE=$(get_running_stage_node) || RUNNING_STAGE=""

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
  REASON="SDD Art. 4 Violation: Stage '$RUNNING_STAGE' cannot modify upstream artifact '$REL_PATH'. Upstream artifacts are immutable during downstream execution. Complete the current stage first, or use sdd-req-change for controlled modifications."
  ESCAPED_REASON=$(echo "$REASON" | jq -Rs . 2>/dev/null || node -e "console.log(JSON.stringify('$REASON'))")
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":$ESCAPED_REASON}}"
  exit 0
fi

# Not prohibited — allow
exit 0
