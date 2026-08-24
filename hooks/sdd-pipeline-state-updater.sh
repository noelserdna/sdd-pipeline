#!/bin/bash
# H3: SDD Pipeline State Auto-Updater
# Hook type: PostToolUse (Write) | async: true | Timeout: 10s
# Detects writes to pipeline artifact directories and updates pipeline-state.json.
# Only marks stages as "running" (not "done" — that's the skill's responsibility).
# NOTE: The "summary" field in each stage is EXCLUSIVELY managed by skills on completion.
# This hook must NOT modify or remove the "summary" field. The jq/node updates below
# only touch status/lastRun/staleReason/currentStage/lastUpdated, preserving summary intact.
#
# Dos raíces (hooks/lib/sdd-common.sh): REL_PATH se clasifica respecto al toplevel git del
# fichero (worktree incluido); pipeline-state.json vive SIEMPRE en STATE_ROOT (raíz del .git
# común), así varios worktrees comparten un único estado. Lectura-modificación-escritura bajo
# sdd_lock (mkdir atómico) → jq a fichero temporal en el mismo directorio → mv.

set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
if [ ! -f "$SDD_LIB" ]; then echo "sdd-pipeline-state-updater: falta $SDD_LIB" >&2; exit 0; fi
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

INPUT=$(cat)

# Check if the write was successful
TOOL_SUCCESS=$(printf '%s' "$INPUT" | sdd_json_get - '.toolResponse.success // .tool_response.success // "true"') || TOOL_SUCCESS="true"
if [ "$TOOL_SUCCESS" = "false" ]; then
  exit 0
fi

# Extract file_path
FILE_PATH=$(printf '%s' "$INPUT" | sdd_json_get - '.toolInput.file_path // .tool_input.file_path // empty') || FILE_PATH=""
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

sdd_roots "$INPUT" "$FILE_PATH"
PIPELINE_STATE="$STATE_ROOT/pipeline-state.json"

# Not under the project: skip
case "$REL_PATH" in
  /*|[A-Za-z]:/*) exit 0 ;;
esac

# Skip pipeline-state.json itself (avoid infinite loop)
if [ "$REL_PATH" = "pipeline-state.json" ]; then
  exit 0
fi

# Defensa: REL_PATH ya es relativo al worktree; si aun así llega una copia bajo .claude/worktrees/, ignorar
case "$REL_PATH" in
  .claude/worktrees/*) exit 0 ;;
esac

# Map path to pipeline stage (specific audit prefixes BEFORE the generic audits/* rule)
path_to_stage() {
  local path="$1"
  case "$path" in
    requirements/*)           echo "requirements-engineer" ;;
    spec/*)                   echo "specifications-engineer" ;;
    audits/SECURITY-*)        echo "security-auditor" ;;
    audits/GAP-*)             echo "gap-detector" ;;
    audits/UPSTREAM-IMPACT-*) echo "spec-auditor" ;;
    audits/*)                 echo "spec-auditor" ;;
    design/*)                 echo "tech-designer" ;;
    ux/*)                     echo "ux-designer" ;;
    test/*)                   echo "test-planner" ;;
    plan/*)                   echo "plan-architect" ;;
    task/*)                   echo "task-generator" ;;
    src/*|tests/*)            echo "task-implementer" ;;
    feedback/*)               echo "task-implementer" ;;
    *)                        echo "" ;;
  esac
}

STAGE=$(path_to_stage "$REL_PATH")

# If path doesn't map to a stage, skip
if [ -z "$STAGE" ]; then
  exit 0
fi

# Serialize every read-modify-write of the shared state (worktrees, async hooks)
sdd_lock "$PIPELINE_STATE" || exit 0

# Initialize pipeline-state.json if it doesn't exist (under lock)
if [ ! -f "$PIPELINE_STATE" ]; then
  # Version comes from the plugin manifest; sdd-setup normally creates this file first.
  SDD_VER="unknown"
  for _root in "${CLAUDE_PLUGIN_ROOT:-}" "${SDD_PLUGIN_ROOT:-}" "$(dirname "${BASH_SOURCE[0]}")/.."; do
    if [ -n "$_root" ] && [ -f "$_root/.claude-plugin/plugin.json" ]; then
      SDD_VER=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$_root/.claude-plugin/plugin.json" | head -1)
      [ -n "$SDD_VER" ] && break
      SDD_VER="unknown"
    fi
  done
  cat > "$PIPELINE_STATE" <<INIT_EOF
{
  "sddVersion": "$SDD_VER",
  "hooksVersion": 3,
  "currentStage": "requirements-engineer",
  "lastUpdated": "",
  "stages": {
    "requirements-engineer":    { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "specifications-engineer":  { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "spec-auditor":             { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "test-planner":             { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "plan-architect":           { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "task-generator":           { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "task-implementer":         { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null }
  }
}
INIT_EOF
fi

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update pipeline-state.json atomically
# Transitions pending/stale/done -> running on artifact writes.
# "done" stages revert to "running" because new writes mean the stage is actively changing.
# Skills set "done" explicitly on completion (writing to pipeline-state.json, which H3 skips).
# "error" and "running" are left untouched. The stage key is created if it does not exist.
update_with_jq() {
  sdd_has_jq || return 1
  local tmpfile="${PIPELINE_STATE}.tmp.$$"
  if jq --arg stage "$STAGE" --arg now "$NOW" '
    .stages = (.stages // {}) |
    .stages[$stage] = (.stages[$stage] // { status: "pending", outputHash: null, lastRun: null, staleReason: null }) |
    if .stages[$stage].status == "pending" or .stages[$stage].status == "stale" or .stages[$stage].status == "done" then
      .stages[$stage].status = "running" |
      .stages[$stage].lastRun = $now |
      .stages[$stage].staleReason = null |
      .currentStage = $stage |
      .lastUpdated = $now
    else
      .lastUpdated = $now
    end
  ' "$PIPELINE_STATE" > "$tmpfile" 2>/dev/null; then
    mv "$tmpfile" "$PIPELINE_STATE"
  else
    rm -f "$tmpfile"
    return 1
  fi
}

update_with_node() {
  sdd_has_node || return 1
  SDD_STATE_FILE="$PIPELINE_STATE" SDD_STAGE="$STAGE" SDD_NOW="$NOW" node -e "
    const fs = require('fs');
    const file = process.env.SDD_STATE_FILE, stage = process.env.SDD_STAGE, now = process.env.SDD_NOW;
    try {
      const state = JSON.parse(fs.readFileSync(file, 'utf8'));
      if (!state.stages || typeof state.stages !== 'object') state.stages = {};
      if (!state.stages[stage]) {
        state.stages[stage] = { status: 'pending', outputHash: null, lastRun: null, staleReason: null };
      }
      const st = state.stages[stage].status;
      if (st === 'pending' || st === 'stale' || st === 'done') {
        state.stages[stage].status = 'running';
        state.stages[stage].lastRun = now;
        state.stages[stage].staleReason = null;
        state.currentStage = stage;
      }
      state.lastUpdated = now;
      const tmp = file + '.tmp.' + process.pid;
      fs.writeFileSync(tmp, JSON.stringify(state, null, 2) + '\n');
      fs.renameSync(tmp, file);
    } catch(e) {
      // Silent fail for async hook
    }
  " 2>/dev/null
}

update_with_jq || update_with_node || true

sdd_unlock "$PIPELINE_STATE"
exit 0
