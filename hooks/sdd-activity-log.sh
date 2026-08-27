#!/bin/bash
# H10: SDD Activity Log
# Hook type: SessionStart | SessionEnd | PreToolUse (Skill|Agent|Task) | UserPromptExpansion
#            | SubagentStart | SubagentStop | Stop  — async: true (SessionEnd síncrono) | Timeout: 5s
# Un único script para varios eventos: lee `hook_event_name` del stdin y añade UNA línea JSON a
# $STATE_ROOT/.sdd/activity.jsonl (bajo sdd_lock). scripts/sdd-watch.sh la pinta en tiempo real.
#
# Eventos registrados (campo `event`):
#   session-start   SessionStart          + source (startup|resume|…)
#   session-end     SessionEnd            + reason
#   skill-start     PreToolUse Skill      + skill, args, via=tool [, in_agent]
#                   UserPromptExpansion   + skill (command_name), args, via=prompt  (/skill tecleado a mano,
#                                           que NO pasa por PreToolUse según la doc de hooks)
#   agent-start     PreToolUse Agent|Task + agent_type (tool_input.subagent_type), description [, in_agent]
#   subagent-start  SubagentStart         + agent_type, agent_id
#   subagent-stop   SubagentStop          + agent_type, agent_id
#   stop            Stop                  (fin de turno del agente principal)
# Campos comunes: ts (ISO UTC), session (8 chars de session_id), role (sdd_role o "-"), cwd (relativo a
# STATE_ROOT), stage (primer stage `running` de pipeline-state.json), task (.sdd/current-task.json del
# PROJECT_DIR, es decir, del worktree). Los campos vacíos se omiten.
#
# Reglas: nunca falla (exit 0 siempre); no escribe nada si en STATE_ROOT no hay ni .sdd/ ni
# pipeline-state.json (proyectos sin SDD); rota activity.jsonl → activity.1.jsonl al superar 5 MB
# (SDD_ACTIVITY_MAX_BYTES). Un solo proceso jq (o node sin jq) construye la línea.

set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
if [ ! -f "$SDD_LIB" ]; then echo "sdd-activity-log: falta $SDD_LIB" >&2; exit 0; fi
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

INPUT=$(cat)
[ -n "$INPUT" ] || exit 0

# Atajo: `cwd` sale del JSON con un regex de bash (ahorra un proceso jq/node); si trae escapes
# (\", \\, \u…) se deja que sdd_roots lo parsee con jq/node.
FAST_CWD=""
if [[ "$INPUT" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then FAST_CWD="${BASH_REMATCH[1]}"; fi
if [ -n "$FAST_CWD" ] && [ -d "$FAST_CWD" ]; then
  CLAUDE_PROJECT_DIR="$FAST_CWD" sdd_roots ""
else
  sdd_roots "$INPUT"
fi
PIPELINE_STATE="$STATE_ROOT/pipeline-state.json"
SDD_DIR="$STATE_ROOT/.sdd"
# Proyectos sin SDD: ni rastro
if [ ! -f "$PIPELINE_STATE" ] && [ ! -d "$SDD_DIR" ]; then exit 0; fi

ROLE=$(sdd_role) || ROLE=""
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TASK_FILE="$PROJECT_DIR/.sdd/current-task.json"

# cwd relativo a STATE_ROOT ("." en la raíz; absoluto si está fuera, p. ej. un worktree ../x)
CWD_PHYS=$(sdd_physical "$CWD")
case "$CWD_PHYS" in
  "$STATE_ROOT")   CWD_REL="." ;;
  "$STATE_ROOT"/*) CWD_REL="${CWD_PHYS#"$STATE_ROOT"/}" ;;
  *)               CWD_REL="$CWD_PHYS" ;;
esac

JQ_PROG='
def order: ["requirements-engineer","specifications-engineer","spec-auditor","test-planner","plan-architect","task-generator","task-implementer"];
def clip($n): if type == "string" then .[0:$n] else . end;
. as $in
| ($in.hook_event_name // "") as $ev
| ($in.tool_name // "") as $tool
| ($in.tool_input // {} | if type == "object" then . else {} end) as $ti
| (if $ev == "SessionStart" then {event: "session-start", source: $in.source}
   elif $ev == "SessionEnd" then {event: "session-end", reason: $in.reason}
   elif $ev == "Stop" then {event: "stop"}
   elif $ev == "SubagentStart" then {event: "subagent-start", agent_type: $in.agent_type, agent_id: $in.agent_id}
   elif $ev == "SubagentStop" then {event: "subagent-stop", agent_type: $in.agent_type, agent_id: $in.agent_id}
   elif $ev == "UserPromptExpansion" then {event: "skill-start", skill: $in.command_name, args: ($in.command_args | clip(120)), via: "prompt"}
   elif $ev == "PreToolUse" and $tool == "Skill" then {event: "skill-start", skill: $ti.skill, args: ($ti.args | clip(120)), via: "tool", in_agent: $in.agent_id}
   elif $ev == "PreToolUse" and ($tool == "Agent" or $tool == "Task") then {event: "agent-start", agent_type: ($ti.subagent_type // "general-purpose"), description: ($ti.description | clip(120)), in_agent: $in.agent_id}
   else null end) as $e
| if $e == null then empty else
    (($state | fromjson?) // {} | if type == "object" then . else {} end) as $st
    | (($st.stages // {} | if type == "object" then . else {} end) | to_entries | map(select(.value | type == "object" and .status == "running") | .key)) as $r
    | (((order | map(select(. as $s | ($r | index($s)) != null))) + ($r - order)) | first) as $stage
    | (($task | fromjson?) // {} | if type == "object" then . else {} end) as $tk
    | ({ts: $ts, event: $e.event, session: (($in.session_id // "-") | tostring | .[0:8]), role: $role, cwd: $cwd}
       + ($e | del(.event))
       + {stage: $stage, task: $tk.taskId})
    | with_entries(select(.value != null and .value != ""))
  end'

build_with_jq() {
  sdd_has_jq || return 1
  local statef="$PIPELINE_STATE" taskf="$TASK_FILE"
  [ -f "$statef" ] || statef=/dev/null
  [ -f "$taskf" ] || taskf=/dev/null
  printf '%s' "$INPUT" | jq -c --arg ts "$TS" --arg role "${ROLE:--}" --arg cwd "$CWD_REL" \
    --rawfile state "$statef" --rawfile task "$taskf" "$JQ_PROG" 2>/dev/null
}

build_with_node() {
  sdd_has_node || return 1
  printf '%s' "$INPUT" | SDD_TS="$TS" SDD_ROLE_V="${ROLE:--}" SDD_CWD_REL="$CWD_REL" \
    SDD_STATE_FILE="$PIPELINE_STATE" SDD_TASK_FILE="$TASK_FILE" node -e '
    const fs = require("fs");
    const order = ["requirements-engineer","specifications-engineer","spec-auditor","test-planner","plan-architect","task-generator","task-implementer"];
    const readJson = (f) => { try { const v = JSON.parse(fs.readFileSync(f, "utf8")); return v && typeof v === "object" ? v : {}; } catch (e) { return {}; } };
    const clip = (v, n) => (typeof v === "string" ? v.slice(0, n) : v);
    let inp; try { inp = JSON.parse(fs.readFileSync(0, "utf8")); } catch (e) { process.exit(0); }
    if (!inp || typeof inp !== "object") process.exit(0);
    const ev = inp.hook_event_name || "", tool = inp.tool_name || "";
    const ti = inp.tool_input && typeof inp.tool_input === "object" ? inp.tool_input : {};
    let e = null;
    if (ev === "SessionStart") e = { event: "session-start", source: inp.source };
    else if (ev === "SessionEnd") e = { event: "session-end", reason: inp.reason };
    else if (ev === "Stop") e = { event: "stop" };
    else if (ev === "SubagentStart") e = { event: "subagent-start", agent_type: inp.agent_type, agent_id: inp.agent_id };
    else if (ev === "SubagentStop") e = { event: "subagent-stop", agent_type: inp.agent_type, agent_id: inp.agent_id };
    else if (ev === "UserPromptExpansion") e = { event: "skill-start", skill: inp.command_name, args: clip(inp.command_args, 120), via: "prompt" };
    else if (ev === "PreToolUse" && tool === "Skill") e = { event: "skill-start", skill: ti.skill, args: clip(ti.args, 120), via: "tool", in_agent: inp.agent_id };
    else if (ev === "PreToolUse" && (tool === "Agent" || tool === "Task")) e = { event: "agent-start", agent_type: ti.subagent_type || "general-purpose", description: clip(ti.description, 120), in_agent: inp.agent_id };
    if (!e) process.exit(0);
    const st = readJson(process.env.SDD_STATE_FILE);
    const stages = st.stages && typeof st.stages === "object" ? st.stages : {};
    const running = Object.keys(stages).filter((k) => stages[k] && typeof stages[k] === "object" && stages[k].status === "running");
    const stage = order.filter((s) => running.includes(s)).concat(running.filter((s) => !order.includes(s)))[0];
    const tk = readJson(process.env.SDD_TASK_FILE);
    const { event, ...rest } = e;
    const out = Object.assign({ ts: process.env.SDD_TS, event, session: String(inp.session_id == null ? "-" : inp.session_id).slice(0, 8),
      role: process.env.SDD_ROLE_V, cwd: process.env.SDD_CWD_REL }, rest, { stage, task: tk.taskId });
    for (const k of Object.keys(out)) if (out[k] === null || out[k] === undefined || out[k] === "") delete out[k];
    process.stdout.write(JSON.stringify(out) + "\n");
  ' 2>/dev/null
}

LINE=$(build_with_jq) || LINE=$(build_with_node) || LINE=""
[ -n "$LINE" ] || exit 0

mkdir -p "$SDD_DIR" 2>/dev/null || exit 0
LOG="$SDD_DIR/activity.jsonl"
MAX_BYTES="${SDD_ACTIVITY_MAX_BYTES:-5242880}"

file_size() {
  local s
  s=$(stat -c %s "$1" 2>/dev/null) || s=$(stat -f %z "$1" 2>/dev/null) || s=0
  case "$s" in ''|*[!0-9]*) s=0 ;; esac
  printf '%s\n' "$s"
}

# Lock corto (1 s máx.): si no se consigue, el append de una línea sigue siendo atómico (O_APPEND),
# solo se pierde la rotación de esta vez.
export SDD_LOCK_RETRIES="${SDD_LOCK_RETRIES:-10}"
if sdd_lock "$LOG"; then
  if [ -f "$LOG" ] && [ "$(file_size "$LOG")" -gt "$MAX_BYTES" ]; then
    mv -f "$LOG" "$SDD_DIR/activity.1.jsonl" 2>/dev/null || true
  fi
  printf '%s\n' "$LINE" >> "$LOG" 2>/dev/null || true
  sdd_unlock "$LOG"
else
  printf '%s\n' "$LINE" >> "$LOG" 2>/dev/null || true
fi
exit 0
