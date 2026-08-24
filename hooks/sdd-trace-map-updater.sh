#!/bin/bash
# H9: SDD Trace Map Auto-Updater
# Hook type: PostToolUse (Write|Edit) | async: true | Timeout: 10s
# Records file writes during task implementation, linking them to the current task's requirements.
# Reads .sdd/current-task.json (breadcrumb written by sdd-task-implementer) and appends/updates
# mappings in .sdd/trace-map.json for automatic traceability capture.
#
# Dos raíces (hooks/lib/sdd-common.sh):
#   - .sdd/current-task.json vive en PROJECT_DIR (uno por worktree / Stream).
#   - .sdd/trace-map.json vive en STATE_ROOT (raíz del .git común), compartido, bajo sdd_lock.
# Si el breadcrumb trae `stream` y/o `role`, la entrada los incluye.

set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
if [ ! -f "$SDD_LIB" ]; then echo "sdd-trace-map-updater: falta $SDD_LIB" >&2; exit 0; fi
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

INPUT=$(cat)

# Check if the write was successful
TOOL_SUCCESS=$(printf '%s' "$INPUT" | sdd_json_get - '.toolResponse.success // .tool_response.success // "true"') || TOOL_SUCCESS="true"
if [ "$TOOL_SUCCESS" = "false" ]; then
  exit 0
fi

# Extract file_path from hook input
FILE_PATH=$(printf '%s' "$INPUT" | sdd_json_get - '.toolInput.file_path // .tool_input.file_path // empty') || FILE_PATH=""
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

sdd_roots "$INPUT" "$FILE_PATH"

# Only proceed for src/ and tests/ files inside the project
case "$REL_PATH" in
  src/*|tests/*) ;;
  *) exit 0 ;;
esac

# Check if breadcrumb exists (per worktree)
CURRENT_TASK="$PROJECT_DIR/.sdd/current-task.json"
if [ ! -f "$CURRENT_TASK" ]; then
  exit 0
fi

TRACE_MAP="$STATE_ROOT/.sdd/trace-map.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Ensure the shared .sdd directory exists
mkdir -p "$STATE_ROOT/.sdd" 2>/dev/null || exit 0

sdd_lock "$TRACE_MAP" || exit 0

# Initialize trace-map.json if it doesn't exist (under lock)
if [ ! -f "$TRACE_MAP" ]; then
  cat > "$TRACE_MAP" <<INIT_EOF
{
  "\$schema": "sdd-trace-map-v1",
  "lastUpdated": "$NOW",
  "mappings": []
}
INIT_EOF
fi

# Update trace-map.json using jq (preferred) or node (fallback)
update_with_jq() {
  sdd_has_jq || return 1
  # Read task context
  TASK_ID=$(jq -r '.taskId // empty' "$CURRENT_TASK" 2>/dev/null) || return 1
  if [ -z "$TASK_ID" ]; then
    return 0
  fi
  FASE=$(jq -r '.fase // 0' "$CURRENT_TASK" 2>/dev/null) || FASE=0
  REFS=$(jq -c '.refs // []' "$CURRENT_TASK" 2>/dev/null) || REFS="[]"
  STREAM=$(jq -r '.stream // empty' "$CURRENT_TASK" 2>/dev/null) || STREAM=""
  TASK_ROLE=$(jq -r '.role // empty' "$CURRENT_TASK" 2>/dev/null) || TASK_ROLE=""

  local tmpfile="${TRACE_MAP}.tmp.$$"
  if jq --arg file "$REL_PATH" \
     --arg taskId "$TASK_ID" \
     --argjson fase "$FASE" \
     --argjson refs "$REFS" \
     --arg stream "$STREAM" \
     --arg role "$TASK_ROLE" \
     --arg now "$NOW" '
    .lastUpdated = $now |
    .mappings = (.mappings // []) |
    (.mappings | map(select(.file == $file and .taskId == $taskId)) | length) as $existing |
    if $existing > 0 then
      .mappings = [.mappings[] |
        if .file == $file and .taskId == $taskId then
          .lastModified = $now
          | (if $stream != "" then .stream = $stream else . end)
          | (if $role != "" then .role = $role else . end)
        else
          .
        end
      ]
    else
      .mappings += [({
        file: $file,
        taskId: $taskId,
        fase: $fase,
        refs: $refs,
        origin: "hook-captured",
        firstSeen: $now,
        lastModified: $now
      } + (if $stream != "" then { stream: $stream } else {} end)
        + (if $role != "" then { role: $role } else {} end))]
    end
  ' "$TRACE_MAP" > "$tmpfile" 2>/dev/null; then
    mv "$tmpfile" "$TRACE_MAP"
  else
    rm -f "$tmpfile"
    return 1
  fi
}

update_with_node() {
  sdd_has_node || return 1
  SDD_CURRENT_TASK="$CURRENT_TASK" SDD_TRACE_MAP="$TRACE_MAP" SDD_REL_PATH="$REL_PATH" SDD_NOW="$NOW" node -e "
    const fs = require('fs');
    const taskFile = process.env.SDD_CURRENT_TASK, mapFile = process.env.SDD_TRACE_MAP;
    const relPath = process.env.SDD_REL_PATH, now = process.env.SDD_NOW;
    try {
      const task = JSON.parse(fs.readFileSync(taskFile, 'utf8'));
      if (!task.taskId) process.exit(0);
      let traceMap;
      if (fs.existsSync(mapFile)) {
        traceMap = JSON.parse(fs.readFileSync(mapFile, 'utf8'));
      } else {
        traceMap = { '\$schema': 'sdd-trace-map-v1', lastUpdated: now, mappings: [] };
      }
      if (!Array.isArray(traceMap.mappings)) traceMap.mappings = [];
      traceMap.lastUpdated = now;
      const idx = traceMap.mappings.findIndex(m => m.file === relPath && m.taskId === task.taskId);
      if (idx >= 0) {
        traceMap.mappings[idx].lastModified = now;
        if (task.stream) traceMap.mappings[idx].stream = task.stream;
        if (task.role) traceMap.mappings[idx].role = task.role;
      } else {
        const entry = {
          file: relPath,
          taskId: task.taskId,
          fase: task.fase || 0,
          refs: task.refs || [],
          origin: 'hook-captured',
          firstSeen: now,
          lastModified: now
        };
        if (task.stream) entry.stream = task.stream;
        if (task.role) entry.role = task.role;
        traceMap.mappings.push(entry);
      }
      const tmp = mapFile + '.tmp.' + process.pid;
      fs.writeFileSync(tmp, JSON.stringify(traceMap, null, 2) + '\n');
      fs.renameSync(tmp, mapFile);
    } catch(e) {
      // Silent fail for async hook
    }
  " 2>/dev/null
}

update_with_jq || update_with_node || true

sdd_unlock "$TRACE_MAP"
exit 0
