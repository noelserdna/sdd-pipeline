#!/bin/bash
# H9: SDD Trace Map Auto-Updater
# Hook type: PostToolUse (Write|Edit) | async: true | Timeout: 10s
# Records file writes during task implementation, linking them to the current task's requirements.
# Reads .sdd/current-task.json (breadcrumb written by sdd-task-implementer) and appends/updates
# mappings in .sdd/trace-map.json for automatic traceability capture.

set -euo pipefail

INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's|\\|/|g')

# Check if the write was successful
TOOL_SUCCESS=$(echo "$INPUT" | jq -r '.toolResponse.success // .tool_response.success // "true"' 2>/dev/null) || TOOL_SUCCESS="true"
if [ "$TOOL_SUCCESS" != "true" ]; then
  exit 0
fi

# Extract file_path from hook input
FILE_PATH=$(echo "$INPUT" | jq -r '.toolInput.file_path // .tool_input.file_path // empty' 2>/dev/null) || FILE_PATH=""
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalize path
FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')
REL_PATH="${FILE_PATH#$PROJECT_DIR/}"
if [ "$REL_PATH" = "$FILE_PATH" ]; then
  exit 0
fi

# Only proceed for src/ and tests/ files
case "$REL_PATH" in
  src/*|tests/*) ;;
  *) exit 0 ;;
esac

# Check if breadcrumb exists
CURRENT_TASK="$PROJECT_DIR/.sdd/current-task.json"
if [ ! -f "$CURRENT_TASK" ]; then
  exit 0
fi

TRACE_MAP="$PROJECT_DIR/.sdd/trace-map.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure .sdd directory exists
mkdir -p "$PROJECT_DIR/.sdd"

# Update trace-map.json using jq (preferred) or node (fallback)
update_with_jq() {
  # Read task context
  TASK_ID=$(jq -r '.taskId // empty' "$CURRENT_TASK" 2>/dev/null) || return 1
  if [ -z "$TASK_ID" ]; then
    return 0
  fi
  FASE=$(jq -r '.fase // 0' "$CURRENT_TASK" 2>/dev/null) || FASE=0
  REFS=$(jq -c '.refs // []' "$CURRENT_TASK" 2>/dev/null) || REFS="[]"

  # Initialize trace-map.json if it doesn't exist
  if [ ! -f "$TRACE_MAP" ]; then
    cat > "$TRACE_MAP" <<INIT_EOF
{
  "\$schema": "sdd-trace-map-v1",
  "lastUpdated": "$NOW",
  "mappings": []
}
INIT_EOF
  fi

  local tmpfile="${TRACE_MAP}.tmp.$$"
  jq --arg file "$REL_PATH" \
     --arg taskId "$TASK_ID" \
     --argjson fase "$FASE" \
     --argjson refs "$REFS" \
     --arg now "$NOW" '
    .lastUpdated = $now |
    (.mappings | map(select(.file == $file and .taskId == $taskId)) | length) as $existing |
    if $existing > 0 then
      .mappings = [.mappings[] |
        if .file == $file and .taskId == $taskId then
          .lastModified = $now
        else
          .
        end
      ]
    else
      .mappings += [{
        file: $file,
        taskId: $taskId,
        fase: $fase,
        refs: $refs,
        origin: "hook-captured",
        firstSeen: $now,
        lastModified: $now
      }]
    end
  ' "$TRACE_MAP" > "$tmpfile" 2>/dev/null && mv "$tmpfile" "$TRACE_MAP"
}

update_with_node() {
  node -e "
    const fs = require('fs');
    try {
      const task = JSON.parse(fs.readFileSync('$CURRENT_TASK', 'utf8'));
      if (!task.taskId) process.exit(0);

      const now = '$NOW';
      const relPath = '$REL_PATH';
      let traceMap;

      if (fs.existsSync('$TRACE_MAP')) {
        traceMap = JSON.parse(fs.readFileSync('$TRACE_MAP', 'utf8'));
      } else {
        traceMap = { '\$schema': 'sdd-trace-map-v1', lastUpdated: now, mappings: [] };
      }

      traceMap.lastUpdated = now;
      const idx = traceMap.mappings.findIndex(m => m.file === relPath && m.taskId === task.taskId);

      if (idx >= 0) {
        traceMap.mappings[idx].lastModified = now;
      } else {
        traceMap.mappings.push({
          file: relPath,
          taskId: task.taskId,
          fase: task.fase || 0,
          refs: task.refs || [],
          origin: 'hook-captured',
          firstSeen: now,
          lastModified: now
        });
      }

      fs.writeFileSync('$TRACE_MAP', JSON.stringify(traceMap, null, 2));
    } catch(e) {
      // Silent fail for async hook
    }
  " 2>/dev/null
}

update_with_jq || update_with_node || true

exit 0
