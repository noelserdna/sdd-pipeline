#!/bin/bash
# H3: SDD Pipeline State Auto-Updater
# Hook type: PostToolUse (Write) | async: true | Timeout: 10s
# Detects writes to pipeline artifact directories and updates pipeline-state.json.
# Only marks stages as "running" (not "done" — that's the skill's responsibility).

set -euo pipefail

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's|\\|/|g')
PIPELINE_STATE="$PROJECT_DIR/pipeline-state.json"

# Check if the write was successful
TOOL_SUCCESS=$(echo "$INPUT" | jq -r '.toolResponse.success // .tool_response.success // "true"' 2>/dev/null) || TOOL_SUCCESS="true"
if [ "$TOOL_SUCCESS" != "true" ]; then
  exit 0
fi

# Extract file_path
FILE_PATH=$(echo "$INPUT" | jq -r '.toolInput.file_path // .tool_input.file_path // empty' 2>/dev/null) || FILE_PATH=""
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize
FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')
REL_PATH="${FILE_PATH#$PROJECT_DIR/}"
if [ "$REL_PATH" = "$FILE_PATH" ]; then
  exit 0
fi

# Skip pipeline-state.json itself (avoid infinite loop)
if [ "$REL_PATH" = "pipeline-state.json" ]; then
  exit 0
fi

# Map path to pipeline stage
path_to_stage() {
  local path="$1"
  case "$path" in
    requirements/*)  echo "requirements-engineer" ;;
    spec/*)          echo "specifications-engineer" ;;
    audits/*)        echo "spec-auditor" ;;
    test/*)          echo "test-planner" ;;
    plan/*)          echo "plan-architect" ;;
    task/*)          echo "task-generator" ;;
    src/*|tests/*)   echo "task-implementer" ;;
    feedback/*)      echo "task-implementer" ;;
    *)               echo "" ;;
  esac
}

STAGE=$(path_to_stage "$REL_PATH")

# If path doesn't map to a stage, skip
if [ -z "$STAGE" ]; then
  exit 0
fi

# Initialize pipeline-state.json if it doesn't exist
if [ ! -f "$PIPELINE_STATE" ]; then
  cat > "$PIPELINE_STATE" <<'INIT_EOF'
{
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
# Only transition pending/stale -> running (don't touch done/error/already-running)
update_with_jq() {
  local tmpfile="${PIPELINE_STATE}.tmp.$$"
  jq --arg stage "$STAGE" --arg now "$NOW" '
    if .stages[$stage].status == "pending" or .stages[$stage].status == "stale" then
      .stages[$stage].status = "running" |
      .stages[$stage].lastRun = $now |
      .stages[$stage].staleReason = null |
      .currentStage = $stage |
      .lastUpdated = $now
    else
      .lastUpdated = $now
    end
  ' "$PIPELINE_STATE" > "$tmpfile" 2>/dev/null && mv "$tmpfile" "$PIPELINE_STATE"
}

update_with_node() {
  node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync('$PIPELINE_STATE', 'utf8'));
      const stage = '$STAGE';
      const now = '$NOW';
      if (!state.stages[stage]) {
        state.stages[stage] = { status: 'pending', outputHash: null, lastRun: null, staleReason: null };
      }
      if (state.stages[stage].status === 'pending' || state.stages[stage].status === 'stale') {
        state.stages[stage].status = 'running';
        state.stages[stage].lastRun = now;
        state.stages[stage].staleReason = null;
        state.currentStage = stage;
      }
      state.lastUpdated = now;
      fs.writeFileSync('$PIPELINE_STATE', JSON.stringify(state, null, 2));
    } catch(e) {
      // Silent fail for async hook
    }
  " 2>/dev/null
}

update_with_jq || update_with_node || true

exit 0
