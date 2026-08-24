#!/bin/bash
# H1: SDD Pipeline Status Injection at Session Start
# Hook type: PreToolUse (SessionStart) | Timeout: 10s
# Reads pipeline-state.json and injects pipeline context into the session.
# Also reads dashboard/traceability-graph.json (if present) for coverage stats.

set -euo pipefail

# shellcheck disable=SC2034  # F2: se usa para leer .cwd
INPUT=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
# Normalize Windows paths
PROJECT_DIR=$(echo "$PROJECT_DIR" | sed 's|\\|/|g')
PIPELINE_STATE="$PROJECT_DIR/pipeline-state.json"

# If no pipeline-state.json, report fresh pipeline
if [ ! -f "$PIPELINE_STATE" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"SDD Pipeline: No pipeline-state.json found. Fresh pipeline — all stages pending. Run /sdd-setup to initialize automation."}}'
  exit 0
fi

# Try jq first, fall back to node
parse_with_jq() {
  jq -r '
    "SDD Pipeline [" + (.currentStage // "unknown") + "]: " +
    ([.stages | to_entries[] | select(.value.status == "done") | .key] | length | tostring) + "/7 done" +
    (if ([.stages | to_entries[] | select(.value.status == "stale")] | length) > 0
     then ". STALE: " + ([.stages | to_entries[] | select(.value.status == "stale") | .key] | join(", "))
     else "" end) +
    (if ([.stages | to_entries[] | select(.value.status == "running")] | length) > 0
     then ". RUNNING: " + ([.stages | to_entries[] | select(.value.status == "running") | .key] | join(", "))
     else "" end) +
    (if ([.stages | to_entries[] | select(.value.status == "error")] | length) > 0
     then ". ERROR: " + ([.stages | to_entries[] | select(.value.status == "error") | .key] | join(", "))
     else "" end) +
    ". Next: " + ([.stages | to_entries[] | select(.value.status == "pending" or .value.status == "stale") | .key] | first // "all complete")
  ' "$PIPELINE_STATE" 2>/dev/null
}

parse_with_node() {
  node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync('$PIPELINE_STATE', 'utf8'));
      const entries = Object.entries(state.stages || {});
      const done = entries.filter(([,v]) => v.status === 'done').length;
      const stale = entries.filter(([,v]) => v.status === 'stale').map(([k]) => k);
      const running = entries.filter(([,v]) => v.status === 'running').map(([k]) => k);
      const errors = entries.filter(([,v]) => v.status === 'error').map(([k]) => k);
      const next = entries.find(([,v]) => v.status === 'pending' || v.status === 'stale');
      let msg = 'SDD Pipeline [' + (state.currentStage || 'unknown') + ']: ' + done + '/7 done';
      if (stale.length) msg += '. STALE: ' + stale.join(', ');
      if (running.length) msg += '. RUNNING: ' + running.join(', ');
      if (errors.length) msg += '. ERROR: ' + errors.join(', ');
      msg += '. Next: ' + (next ? next[0] : 'all complete');
      console.log(msg);
    } catch(e) {
      console.log('SDD Pipeline: could not parse pipeline-state.json');
    }
  " 2>/dev/null
}

CONTEXT=$(parse_with_jq) || CONTEXT=$(parse_with_node) || CONTEXT="SDD Pipeline: could not parse pipeline-state.json"

[ -z "$CONTEXT" ] && CONTEXT="SDD Pipeline: could not parse pipeline-state.json"

# Try to append traceability coverage stats from graph
GRAPH_FILE="$PROJECT_DIR/dashboard/traceability-graph.json"

if [ -f "$GRAPH_FILE" ]; then
  coverage_with_jq() {
    jq -r '
      .statistics.traceabilityCoverage as $tc |
      .statistics.orphans as $orph |
      "| Code: " +
        (($tc.reqsWithCode.functionalPercentage // $tc.reqsWithCode.percentage // 0) | floor | tostring) + "%" +
      ", Tests: " +
        (($tc.reqsWithTests.functionalPercentage // $tc.reqsWithTests.percentage // 0) | floor | tostring) + "%" +
      ", Orphans: " +
        (($orph | length) | tostring)
    ' "$GRAPH_FILE" 2>/dev/null
  }

  coverage_with_node() {
    node -e "
      const fs = require('fs');
      try {
        const g = JSON.parse(fs.readFileSync('$GRAPH_FILE', 'utf8'));
        const tc = (g.statistics || {}).traceabilityCoverage || {};
        const orph = (g.statistics || {}).orphans || [];
        const code = Math.floor((tc.reqsWithCode || {}).functionalPercentage || (tc.reqsWithCode || {}).percentage || 0);
        const tests = Math.floor((tc.reqsWithTests || {}).functionalPercentage || (tc.reqsWithTests || {}).percentage || 0);
        console.log('| Code: ' + code + '%, Tests: ' + tests + '%, Orphans: ' + orph.length);
      } catch(e) {}
    " 2>/dev/null
  }

  COVERAGE=$(coverage_with_jq) || COVERAGE=$(coverage_with_node) || COVERAGE=""
  [ -n "$COVERAGE" ] && CONTEXT="$CONTEXT $COVERAGE"
fi

# Escape for JSON output
ESCAPED=$(echo "$CONTEXT" | jq -Rs . 2>/dev/null || node -e "console.log(JSON.stringify(require('fs').readFileSync('/dev/stdin','utf8').trim()))")

echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":$ESCAPED}}"
exit 0
