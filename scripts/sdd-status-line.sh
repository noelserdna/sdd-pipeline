#!/usr/bin/env bash
# SDD Pipeline Status Line for Claude Code
# Displays real-time pipeline progress at the bottom of the CLI.
# Reads pipeline-state.json and session JSON (via stdin) to show:
#   [role] P1: Active stage  P2: Progress N/7  P3: Stale/error warnings
#
# Installation: configured in .claude/settings.json via sdd-setup
# Input: Claude Code status line JSON via stdin ({cwd, workspace:{current_dir, project_dir}, ...})
# Output: single-line status string to stdout
#
# Dos raíces: con hooks/lib/sdd-common.sh disponible (instalación como plugin), el estado se
# lee de STATE_ROOT (raíz del .git común, compartida por worktrees) a partir del cwd del JSON,
# se antepone `[<rol>]` si hay rol y el stage mostrado es el primer `running` dentro de los
# stages del rol. Sin la librería (copia antigua del script en .claude/hooks/), degrada al
# comportamiento anterior: ${CLAUDE_PROJECT_DIR:-$PWD}/pipeline-state.json.
#
# Version: 0.2.0

set -euo pipefail

# Read session JSON from stdin (Claude Code provides this)
SESSION_JSON=$(cat)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SCRIPT_DIR="."

# Ruta del plugin instalado (installed_plugins.json) para cuando este script se copia a .claude/
plugin_install_path() {
  local reg="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/plugins/installed_plugins.json"
  [ -f "$reg" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.plugins // {} | to_entries[] | select(.key | startswith("sdd-pipeline@")) | .value[]?.installPath // empty' "$reg" 2>/dev/null | head -n 1 || true
  elif command -v node >/dev/null 2>&1; then
    SDD_REG="$reg" node -e '
      try { const p = JSON.parse(require("fs").readFileSync(process.env.SDD_REG, "utf8")).plugins || {};
        for (const k of Object.keys(p)) if (k.startsWith("sdd-pipeline@") && Array.isArray(p[k]) && p[k][0] && p[k][0].installPath) { process.stdout.write(p[k][0].installPath + "\n"); break; } } catch (e) {}' 2>/dev/null || true
  fi
}

SDD_LIB=""
for candidate in "$SCRIPT_DIR/../hooks/lib/sdd-common.sh" \
                 "${SDD_PLUGIN_ROOT:-}/hooks/lib/sdd-common.sh" \
                 "${CLAUDE_PLUGIN_ROOT:-}/hooks/lib/sdd-common.sh" \
                 "$(plugin_install_path)/hooks/lib/sdd-common.sh"; do
  case "$candidate" in /hooks/lib/*) continue ;; esac
  if [ -f "$candidate" ]; then SDD_LIB="$candidate"; break; fi
done

ROLE=""
ROLE_STAGES=""
if [ -n "$SDD_LIB" ]; then
  # shellcheck source=../hooks/lib/sdd-common.sh
  . "$SDD_LIB"
  sdd_roots "$SESSION_JSON"
  STATE_FILE="$STATE_ROOT/pipeline-state.json"
  ROLE=$(sdd_role) || ROLE=""
  if [ -n "$ROLE" ]; then
    ROLE_STAGES=$(sdd_role_stages "$ROLE" | tr '\n' ' ') || ROLE_STAGES=""
    ROLE_STAGES="${ROLE_STAGES% }"
  fi
else
  # Sin librería: comportamiento anterior, salvo que SDD_STATE_ROOT / SDD_ROLE lleguen por el
  # entorno (sesiones lanzadas con scripts/sdd-up.sh), que se respetan.
  PROJECT_DIR="${SDD_STATE_ROOT:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
  STATE_FILE="$PROJECT_DIR/pipeline-state.json"
  ROLE="${SDD_ROLE:-}"
  if [ -n "$ROLE" ] && [ -f "$PROJECT_DIR/.claude/sdd-sessions.json" ] && command -v jq >/dev/null 2>&1; then
    ROLE_STAGES=$(jq -r --arg r "$ROLE" '.roles[$r].stages // [] | join(" ")' "$PROJECT_DIR/.claude/sdd-sessions.json" 2>/dev/null) || ROLE_STAGES=""
  fi
fi

PREFIX=""
[ -n "$ROLE" ] && PREFIX="[$ROLE] "

# --- Pipeline state ---
if [[ ! -f "$STATE_FILE" ]]; then
  printf "%sSDD: no pipeline" "$PREFIX"
  exit 0
fi

# Parse pipeline-state.json with jq (preferred) or node (fallback)
if command -v jq &>/dev/null; then
  ROLE_STAGES_JSON="[]"
  if [ -n "$ROLE_STAGES" ]; then
    # shellcheck disable=SC2086  # división por espacios intencionada
    ROLE_STAGES_JSON=$(printf '%s\n' $ROLE_STAGES | jq -R . | jq -s -c .) || ROLE_STAGES_JSON="[]"
  fi
  OUTPUT=$(jq -r --argjson rolestages "$ROLE_STAGES_JSON" '
    # Ordered pipeline stages
    ["requirements-engineer","specifications-engineer","spec-auditor",
     "test-planner","plan-architect","task-generator","task-implementer"] as $order |

    # Count statuses
    ([$order[] as $s | (.stages[$s].status // "pending") | select(. == "done")] | length) as $done |
    ($order | length) as $total |

    # Find running stage: first running (pipeline order), or first running within the role stages
    (if $rolestages == [] then
       ([$order[] as $s | select(.stages[$s].status == "running") | $s] | first // null)
     else
       ([(.stages // {}) | to_entries[] | select(.value.status == "running" and ((.key as $k | $rolestages | index($k)) != null)) | .key] | first // null)
     end) as $running |

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
      "task-implementer": "impl",
      "security-auditor": "sec",
      "tech-designer": "design",
      "ux-designer": "ux",
      "gap-detector": "gap",
      "traceability-check": "trace",
      "dashboard": "dash",
      "req-change": "change"
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
  OUTPUT=$(SDD_STATE_FILE="$STATE_FILE" SDD_ROLE_STAGES="$ROLE_STAGES" node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync(process.env.SDD_STATE_FILE, 'utf8'));
      const roleStages = (process.env.SDD_ROLE_STAGES || '').split(' ').filter(Boolean);
      const order = ['requirements-engineer','specifications-engineer','spec-auditor',
                     'test-planner','plan-architect','task-generator','task-implementer'];
      const short = {
        'requirements-engineer':'req','specifications-engineer':'spec','spec-auditor':'audit',
        'test-planner':'test','plan-architect':'plan','task-generator':'tasks','task-implementer':'impl',
        'security-auditor':'sec','tech-designer':'design','ux-designer':'ux','gap-detector':'gap',
        'traceability-check':'trace','dashboard':'dash','req-change':'change'
      };
      let done=0, stale=0, errors=0, running=null, next=null;
      for (const s of order) {
        const st = (state.stages && state.stages[s] && state.stages[s].status) || 'pending';
        if (st === 'done') done++;
        if (st === 'stale') { stale++; if (!next) next = s; }
        if (st === 'error') errors++;
        if (st === 'running' && !running && roleStages.length === 0) running = s;
        if (st === 'pending' && !next) next = s;
      }
      if (roleStages.length) {
        for (const [k, v] of Object.entries(state.stages || {})) {
          if (v && v.status === 'running' && roleStages.includes(k)) { running = k; break; }
        }
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

# ── Actividad en curso (.sdd/activity.jsonl del hook sdd-activity-log): skill · tiempo · agentes activos ─────────
ACTIVITY=""
ACT_FILE="${STATE_ROOT:-${PROJECT_DIR:-.}}/.sdd/activity.jsonl"
if [ -s "$ACT_FILE" ] && command -v jq >/dev/null 2>&1; then
  ACTIVITY=$(tail -n 400 "$ACT_FILE" 2>/dev/null | jq -r -s --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    def secs: (sub("\\.[0-9]+";"") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime);
    [ .[] | select(type=="object") ] as $ev
    | ($ev | map(select(.event=="skill-start")) | last) as $sk
    | (if $sk == null then null else ($ev | map(select(.event=="stop" and .session==$sk.session and .ts > $sk.ts)) | length) end) as $stopped
    | ($ev | map(select(.event=="subagent-start") | .agent_id) | unique) as $started
    | ($ev | map(select(.event=="subagent-stop") | .agent_id) | unique) as $stopped_agents
    | (($started - $stopped_agents) | length) as $active
    | (if $sk != null and $stopped == 0 then
         (($now | secs) - ($sk.ts | secs)) as $d
         | " · " + ($sk.skill|tostring|sub("^[a-z0-9-]+:";"")) + " " + (if $d >= 3600 then "\($d/3600|floor)h\(($d%3600)/60|floor)m" else "\($d/60|floor)m" end)
       else "" end)
      + (if $active > 0 then " · \($active) agente" + (if $active > 1 then "s" else "" end) else "" end)
  ' 2>/dev/null) || ACTIVITY=""
fi
printf "%s%s%s" "$PREFIX" "$OUTPUT" "$ACTIVITY"
