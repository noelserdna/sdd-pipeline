#!/usr/bin/env bash
# SDD Pipeline Status Line for Claude Code
# Displays real-time pipeline progress at the bottom of the CLI.
# Reads pipeline-state.json and session JSON (via stdin) to show:
#   P1: Active stage  P2: Progress N/7  P3: Stale/error warnings  P4: Session cost
#
# Installation: configured in .claude/settings.json via sdd-setup (Step 5.8)
# Input: Claude Code session JSON via stdin
# Output: single-line status string to stdout
#
# Version: 0.1.0

set -euo pipefail

# Read session JSON from stdin (Claude Code provides this)
SESSION_JSON=$(cat)

# Locate pipeline-state.json relative to project dir
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATE_FILE="$PROJECT_DIR/pipeline-state.json"

# Session JSON available but cost display removed (not relevant to pipeline status)

# --- Pipeline state ---
if [[ ! -f "$STATE_FILE" ]]; then
  printf "SDD: no pipeline"
  exit 0
fi

# Parse pipeline-state.json with jq (preferred) or node (fallback)
if command -v jq &>/dev/null; then
  OUTPUT=$(jq -r '
    # Ordered pipeline stages
    ["requirements-engineer","specifications-engineer","spec-auditor",
     "test-planner","plan-architect","task-generator","task-implementer"] as $order |

    # Count statuses
    ([$order[] as $s | (.stages[$s].status // "pending") | select(. == "done")] | length) as $done |
    ($order | length) as $total |

    # Find running stage
    ([$order[] as $s | select(.stages[$s].status == "running") | $s] | first // null) as $running |

    # Count stale and error
    ([$order[] as $s | (.stages[$s].status // "pending") | select(. == "stale")] | length) as $stale |
    ([$order[] as $s | (.stages[$s].status // "pending") | select(. == "error")] | length) as $errors |

    # Find next pending/stale stage (recommendation)
    ([$order[] as $s | select((.stages[$s].status // "pending") == "pending" or (.stages[$s].status // "pending") == "stale") | $s] | first // null) as $next |

    # Short stage names for display
    {
      "requirements-engineer": "req",
      "specifications-engineer": "spec",
      "spec-auditor": "audit",
      "test-planner": "test",
      "plan-architect": "plan",
      "task-generator": "tasks",
      "task-implementer": "impl"
    } as $short |

    # Build output
    "SDD [\($done)/\($total)]" +

    # Active stage
    (if $running then " \($short[$running] // $running)" else "" end) +

    # Warnings
    (if $stale > 0 then " !\($stale)stale" else "" end) +
    (if $errors > 0 then " x\($errors)err" else "" end) +

    # Next recommendation (only if not running and not all done)
    (if $running == null and $done < $total and $next then " > \($short[$next] // $next)" else "" end)
  ' "$STATE_FILE" 2>/dev/null) || OUTPUT="SDD: error"

elif command -v node &>/dev/null; then
  OUTPUT=$(node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync('$STATE_FILE', 'utf8'));
      const order = ['requirements-engineer','specifications-engineer','spec-auditor',
                     'test-planner','plan-architect','task-generator','task-implementer'];
      const short = {
        'requirements-engineer':'req','specifications-engineer':'spec','spec-auditor':'audit',
        'test-planner':'test','plan-architect':'plan','task-generator':'tasks','task-implementer':'impl'
      };
      let done=0, stale=0, errors=0, running=null, next=null;
      for (const s of order) {
        const st = (state.stages && state.stages[s] && state.stages[s].status) || 'pending';
        if (st === 'done') done++;
        if (st === 'stale') { stale++; if (!next) next = s; }
        if (st === 'error') errors++;
        if (st === 'running') running = s;
        if (st === 'pending' && !next) next = s;
      }
      let out = 'SDD [' + done + '/' + order.length + ']';
      if (running) out += ' ' + (short[running]||running);
      if (stale > 0) out += ' !' + stale + 'stale';
      if (errors > 0) out += ' x' + errors + 'err';
      if (!running && done < order.length && next) out += ' > ' + (short[next]||next);
      process.stdout.write(out);
    } catch(e) {
      process.stdout.write('SDD: error');
    }
  " 2>/dev/null) || OUTPUT="SDD: error"

else
  OUTPUT="SDD: no jq/node"
fi

printf "%s" "$OUTPUT"
