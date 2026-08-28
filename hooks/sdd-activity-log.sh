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
#   skill-end       Stop | SessionEnd     + skill, seconds, reason  (cierre del último skill-start de
#                                           ESA sesión aún abierto; ver «Criterio de cierre»)
# Campos comunes: ts (ISO UTC), session (8 chars de session_id), role (sdd_role o "-"), cwd (relativo a
# STATE_ROOT), stage (primer stage `running` de pipeline-state.json), task (.sdd/current-task.json del
# PROJECT_DIR, es decir, del worktree). Los campos vacíos se omiten.
#
# Reglas: nunca falla (exit 0 siempre); no escribe nada si en STATE_ROOT no hay ni .sdd/ ni
# pipeline-state.json (proyectos sin SDD); rota activity.jsonl → activity.1.jsonl al superar 5 MB
# (SDD_ACTIVITY_MAX_BYTES). Un solo proceso jq (o node sin jq) construye la línea.
#
# Criterio de cierre (skill-end) — conservador: ante la duda NO se cierra, porque una skill abierta de
# más solo deja el reloj corriendo, mientras que cerrar de más borra skill y reloj de la barra en mitad
# de una etapa (medido: 14 de los 19 min de una etapa cuando cualquier `stop` cerraba la skill).
#   · SessionEnd            → siempre: la sesión se acabó, la skill también.
#   · Stop en sesión headless (`claude -p`, SDK) → sí: un turno = una skill. Se detecta en el registro
#     no documentado <config>/sessions/*.json buscando .sessionId de ESTA sesión y mirando .entrypoint:
#     "cli" es interactivo; "sdk-cli"/"sdk-py"/… es headless. Sin entrada o sin ese campo NO se cierra.
#     SDD_HEADLESS=1|0 fuerza la respuesta (scripts, tests).
#   · Stop en sesión interactiva → solo si la sesión lleva más de SDD_SKILL_IDLE_SECS (900 s por
#     defecto) sin NINGÚN evento: una skill viva emite eventos (subagentes, skills anidadas, turnos).
#     El Stop de cada turno —incluido el que dispara una pregunta de puerta a mitad de skill— no cierra.
#
# Índice global (<config>/sdd/active-runs.json, bajo sdd_lock): una entrada por checkout principal
# (clave = `root`, NUNCA el nombre de sesión: cada `claude -p` genera uno distinto y efímero) con
# {root, project, stage, skill, started_at, last_seen, agents, state, sessions}. Lo leen
# scripts/sdd-status-line-global.sh (barra de usuario) y hooks/sdd-runs-line.sh. La entrada se borra
# en session-end cuando no queda ninguna sesión viva de ese root; las que llevan más de
# SDD_RUNS_TTL_SECS (24 h) sin latido se purgan en la siguiente escritura.

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

NOW_EPOCH=$(date -u +%s)
EVENT=""
case "$LINE" in *'"event":"'*) EVENT=${LINE#*'"event":"'}; EVENT=${EVENT%%'"'*} ;; esac
SESSION_FULL=""
if [[ "$INPUT" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then SESSION_FULL="${BASH_REMATCH[1]}"; fi
SESSION_SHORT="-"
case "$LINE" in *'"session":"'*) SESSION_SHORT=${LINE#*'"session":"'}; SESSION_SHORT=${SESSION_SHORT%%'"'*} ;; esac

# ── skill-end: cerrar la skill en curso (ver «Criterio de cierre» en la cabecera) ────────────────
# .entrypoint de ESTA sesión en el registro <config>/sessions/*.json ("" si no hay entrada).
session_entrypoint() {
  local dir f line sid="$SESSION_FULL"
  [ -n "$sid" ] || return 0
  dir="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/sessions"
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    IFS= read -r line < "$f" 2>/dev/null || continue
    case "$line" in *"\"sessionId\":\"$sid\""*) ;; *) continue ;; esac
    if [[ "$line" =~ \"entrypoint\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
    fi
    return 0
  done
  return 0
}
is_headless() {
  case "${SDD_HEADLESS:-}" in 1|true|yes) return 0 ;; 0|false|no) return 1 ;; esac
  local ep; ep=$(session_entrypoint) || ep=""
  [ -n "$ep" ] && [ "$ep" != cli ]
}

# Último skill-start del hilo principal de esta sesión sin skill-end/session-end posterior:
# "skill<TAB>segundos<TAB>antigüedad del último evento de la sesión". Vacío si no hay ninguno.
JQ_OPEN_SKILL='
def lines: split("\n") | map(select(length > 0) | (fromjson? // empty)) | map(select(type == "object"));
def ep: ((.ts // "") | tostring | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | (try fromdateiso8601 catch null));
($now | tonumber) as $nowe
| (lines | to_entries | map(.value + {i: .key})) as $ev
| [ $ev[] | select((.session // "-") == $sess) ] as $mine
| ([ $mine[] | select(.event == "skill-start" and ((.in_agent // "") == "")) ] | last) as $sk
| if $sk == null then empty
  elif ([ $mine[] | select(.i > $sk.i and (.event == "skill-end" or .event == "session-end")) ] | length) > 0 then empty
  else ([ $mine[] | ep ] | map(select(. != null)) | max) as $last
    | [ ($sk.skill // ""),
        (if ($sk | ep) == null then 0 else ($nowe - ($sk | ep)) end),
        (if $last == null then 0 else ($nowe - $last) end) ] | @tsv
  end'
open_skill() {
  [ -s "$LOG" ] || return 0
  if sdd_has_jq; then
    tail -n 500 "$LOG" 2>/dev/null | jq -R -s -r --arg sess "$SESSION_SHORT" --arg now "$NOW_EPOCH" "$JQ_OPEN_SKILL" 2>/dev/null || true
    return 0
  fi
  sdd_has_node || return 0
  tail -n 500 "$LOG" 2>/dev/null | SDD_SESS="$SESSION_SHORT" SDD_NOW="$NOW_EPOCH" node -e '
    const fs = require("fs");
    let txt = ""; try { txt = fs.readFileSync(0, "utf8"); } catch (e) { process.exit(0); }
    const ev = txt.split("\n").filter((l) => l.length > 0).map((l) => { try { return JSON.parse(l); } catch (e) { return null; } })
      .filter((o) => o && typeof o === "object" && !Array.isArray(o)).map((o, i) => Object.assign({}, o, { i }));
    const ep = (o) => { const t = Date.parse(String(o.ts || "")); return Number.isFinite(t) ? Math.floor(t / 1000) : null; };
    const now = Number(process.env.SDD_NOW), sess = process.env.SDD_SESS;
    const mine = ev.filter((x) => (x.session == null ? "-" : x.session) === sess);
    const sk = mine.filter((x) => x.event === "skill-start" && !x.in_agent).pop();
    if (!sk) process.exit(0);
    if (mine.some((x) => x.i > sk.i && (x.event === "skill-end" || x.event === "session-end"))) process.exit(0);
    const stamps = mine.map(ep).filter((t) => t !== null);
    const last = stamps.length ? Math.max.apply(null, stamps) : null;
    process.stdout.write([sk.skill || "", ep(sk) === null ? 0 : now - ep(sk), last === null ? 0 : now - last].join("\t") + "\n");
  ' 2>/dev/null || true
}

SKILL_END_LINE=""
END_SKILL=""
if [ "$EVENT" = session-end ] || [ "$EVENT" = stop ]; then
  REASON=""
  if [ "$EVENT" = session-end ]; then REASON=session-end
  elif is_headless; then REASON=headless-stop; fi
  ROW=$(open_skill) || ROW=""
  if [ -n "$ROW" ]; then
    OPEN_SKILL=${ROW%%$'\t'*}; REST=${ROW#*$'\t'}
    OPEN_SECS=${REST%%$'\t'*}; IDLE_SECS=${REST#*$'\t'}
    case "$OPEN_SECS" in ''|*[!0-9]*) OPEN_SECS=0 ;; esac
    case "$IDLE_SECS" in ''|*[!0-9]*) IDLE_SECS=0 ;; esac
    if [ -z "$REASON" ] && [ "$IDLE_SECS" -ge "${SDD_SKILL_IDLE_SECS:-900}" ]; then REASON=idle-stop; fi
    if [ -n "$REASON" ] && [ -n "$OPEN_SKILL" ]; then
      END_SKILL="$OPEN_SKILL"
      SKILL_END_LINE=$(printf '{"ts":"%s","event":"skill-end","session":"%s","role":%s,"cwd":%s,"skill":%s,"seconds":%s,"reason":"%s"}' \
        "$TS" "$SESSION_SHORT" "$(sdd_json_string "${ROLE:--}")" "$(sdd_json_string "$CWD_REL")" \
        "$(sdd_json_string "$OPEN_SKILL")" "$OPEN_SECS" "$REASON")
    fi
  fi
fi

# Lock corto (1 s máx.): si no se consigue, el append de una línea sigue siendo atómico (O_APPEND),
# solo se pierde la rotación de esta vez.
export SDD_LOCK_RETRIES="${SDD_LOCK_RETRIES:-10}"
append_lines() {
  [ -z "$SKILL_END_LINE" ] || printf '%s\n' "$SKILL_END_LINE" >> "$LOG" 2>/dev/null || true
  printf '%s\n' "$LINE" >> "$LOG" 2>/dev/null || true
}
if sdd_lock "$LOG"; then
  if [ -f "$LOG" ] && [ "$(file_size "$LOG")" -gt "$MAX_BYTES" ]; then
    mv -f "$LOG" "$SDD_DIR/activity.1.jsonl" 2>/dev/null || true
  fi
  append_lines
  sdd_unlock "$LOG"
else
  append_lines
fi

# ── Índice global de ejecuciones (<config>/sdd/active-runs.json) ─────────────────────────────────
RUNS_DIR="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/sdd"
RUNS_FILE="$RUNS_DIR/active-runs.json"
# Nombre de skill normalizado (sin el prefijo `plugin:`); solo las skills del pipeline entran al índice.
norm_skill() {
  local s="${1##*:}"
  case "$s" in sdd-*) printf '%s\n' "$s" ;; *) printf '\n' ;; esac
}
LINE_STAGE=""
case "$LINE" in *'"stage":"'*) LINE_STAGE=${LINE#*'"stage":"'}; LINE_STAGE=${LINE_STAGE%%'"'*} ;; esac
LINE_SKILL=""
case "$LINE" in *'"skill":"'*) LINE_SKILL=${LINE#*'"skill":"'}; LINE_SKILL=${LINE_SKILL%%'"'*} ;; esac

RUN_KIND=heartbeat
RUN_SKILL=""
case "$EVENT" in
  skill-start)    RUN_SKILL=$(norm_skill "$LINE_SKILL"); if [ -n "$RUN_SKILL" ]; then RUN_KIND=skill-start; fi ;;
  subagent-start) RUN_KIND=subagent-start ;;
  subagent-stop)  RUN_KIND=subagent-stop ;;
  session-end)    RUN_KIND=session-end ;;
esac
if [ "$RUN_KIND" = heartbeat ] && [ -n "$END_SKILL" ]; then
  RUN_SKILL=$(norm_skill "$END_SKILL")
  if [ -n "$RUN_SKILL" ]; then RUN_KIND=skill-end; fi
fi

JQ_RUNS='
def obj: if type == "object" then . else {} end;
. as $idx
| (($state | fromjson?) // {} | obj) as $st
| ($st.stages | obj) as $sg
| (($sg | length) > 0 and ([ $sg[] | obj | .status ] | all(. == "done"))) as $alldone
| ($idx.runs | obj) as $runs
| ($runs[$root] | obj) as $cur
| (($cur.sessions // []) | if type == "array" then . else [] end) as $sess
| (if $kind == "session-end" then ($sess - [$session]) else (($sess + [$session]) | unique) end) as $sess2
| (if $kind == "subagent-start" then (($cur.agents // 0) + 1)
   elif $kind == "subagent-stop" then ([(($cur.agents // 0) - 1), 0] | max)
   elif $kind == "session-end" then (if ($sess2 | length) == 0 then 0 else ($cur.agents // 0) end)
   else ($cur.agents // 0) end) as $agents
| (if $kind == "skill-start" then $skill
   elif $kind == "skill-end" then (if ($cur.skill // "") == $skill then null else $cur.skill end)
   elif $kind == "session-end" then null
   else ($cur.skill // null) end) as $sk
| (if $sk == null then null elif $kind == "skill-start" then $ts else ($cur.started_at // $ts) end) as $started
| (if $stage != "" then $stage else ($cur.stage // $st.currentStage // null) end) as $stg
| (if $sk != null then "running" elif $alldone then "done" else "idle" end) as $state2
| {root: $root, project: $project, stage: $stg, skill: $sk, started_at: $started,
   last_seen: $ts, agents: $agents, state: $state2, sessions: $sess2} as $entry
| ($runs
   | (if $kind == "session-end" and ($sess2 | length) == 0 then del(.[$root]) else . + {($root): $entry} end)
   | with_entries(select(.key == $root or ((.value | obj | .last_seen // "") >= $cutoff)))) as $runs2
| {"$schema": "sdd-active-runs-v1", updated: $ts, runs: $runs2}'

index_update() {
  local tmpf statef cutoff ttl
  mkdir -p "$RUNS_DIR" 2>/dev/null || return 0
  [ -f "$RUNS_FILE" ] || printf '{}\n' > "$RUNS_FILE" 2>/dev/null || return 0
  ttl="${SDD_RUNS_TTL_SECS:-86400}"
  cutoff=$(date -u -r "$((NOW_EPOCH - ttl))" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) ||
    cutoff=$(date -u -d "@$((NOW_EPOCH - ttl))" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || cutoff="0000-01-01T00:00:00Z"
  statef="$PIPELINE_STATE"; [ -f "$statef" ] || statef=/dev/null
  sdd_lock "$RUNS_FILE" || return 0
  tmpf="$RUNS_FILE.sdd-run.$$"
  if sdd_has_jq; then
    runs_jq() {
      jq --arg root "$STATE_ROOT" --arg project "$(basename "$STATE_ROOT")" --arg ts "$TS" \
         --arg session "$SESSION_SHORT" --arg kind "$RUN_KIND" --arg skill "$RUN_SKILL" \
         --arg stage "$LINE_STAGE" --arg cutoff "$cutoff" --rawfile state "$statef" \
         "$JQ_RUNS" "$RUNS_FILE" > "$tmpf" 2>/dev/null && mv -f "$tmpf" "$RUNS_FILE" 2>/dev/null
    }
    # Un índice corrupto (escritura a medias, disco lleno) se descarta y se reconstruye: es una caché.
    runs_jq || { rm -f "$tmpf"; printf '{}\n' > "$RUNS_FILE" 2>/dev/null && runs_jq; } || rm -f "$tmpf"
  elif sdd_has_node; then
    SDD_RUNS_FILE="$RUNS_FILE" SDD_TMP="$tmpf" SDD_ROOT="$STATE_ROOT" SDD_PROJECT="$(basename "$STATE_ROOT")" \
    SDD_TS="$TS" SDD_SESSION="$SESSION_SHORT" SDD_KIND="$RUN_KIND" SDD_SKILL="$RUN_SKILL" \
    SDD_STAGE="$LINE_STAGE" SDD_CUTOFF="$cutoff" SDD_STATE_FILE="$statef" node -e '
      const fs = require("fs");
      const obj = (v) => (v && typeof v === "object" && !Array.isArray(v)) ? v : {};
      const read = (f) => { try { return JSON.parse(fs.readFileSync(f, "utf8")); } catch (e) { return {}; } };
      const E = process.env;
      const idx = obj(read(E.SDD_RUNS_FILE));
      const st = obj(read(E.SDD_STATE_FILE));
      const sg = obj(st.stages);
      const keys = Object.keys(sg);
      const alldone = keys.length > 0 && keys.every((k) => obj(sg[k]).status === "done");
      const runs = obj(idx.runs);
      const cur = obj(runs[E.SDD_ROOT]);
      const kind = E.SDD_KIND;
      let sess = Array.isArray(cur.sessions) ? cur.sessions.slice() : [];
      if (kind === "session-end") sess = sess.filter((s) => s !== E.SDD_SESSION);
      else if (!sess.includes(E.SDD_SESSION)) sess.push(E.SDD_SESSION);
      sess.sort();
      let agents = cur.agents || 0;
      if (kind === "subagent-start") agents = agents + 1;
      else if (kind === "subagent-stop") agents = Math.max(agents - 1, 0);
      else if (kind === "session-end" && sess.length === 0) agents = 0;
      let sk = cur.skill === undefined ? null : cur.skill;
      if (kind === "skill-start") sk = E.SDD_SKILL;
      else if (kind === "skill-end") sk = (cur.skill || "") === E.SDD_SKILL ? null : (cur.skill || null);
      else if (kind === "session-end") sk = null;
      const started = sk === null ? null : (kind === "skill-start" ? E.SDD_TS : (cur.started_at || E.SDD_TS));
      const stage = E.SDD_STAGE !== "" ? E.SDD_STAGE : (cur.stage || st.currentStage || null);
      const state = sk !== null ? "running" : (alldone ? "done" : "idle");
      if (kind === "session-end" && sess.length === 0) delete runs[E.SDD_ROOT];
      else runs[E.SDD_ROOT] = { root: E.SDD_ROOT, project: E.SDD_PROJECT, stage: stage, skill: sk,
        started_at: started, last_seen: E.SDD_TS, agents: agents, state: state, sessions: sess };
      for (const k of Object.keys(runs)) {
        if (k === E.SDD_ROOT) continue;
        if (String(obj(runs[k]).last_seen || "") < E.SDD_CUTOFF) delete runs[k];
      }
      fs.writeFileSync(E.SDD_TMP, JSON.stringify({ "$schema": "sdd-active-runs-v1", updated: E.SDD_TS, runs: runs }, null, 2) + "\n");
      fs.renameSync(E.SDD_TMP, E.SDD_RUNS_FILE);
    ' 2>/dev/null || rm -f "$tmpf"
  fi
  sdd_unlock "$RUNS_FILE"
  return 0
}
index_update

# ── Marcar la etapa como "running" al arrancar su skill ──────────────────────────────────────────
# H3 (sdd-pipeline-state-updater) solo engancha PostToolUse Write; una skill que escribe con Bash
# (heredocs, habitual en `claude -p`) nunca marcaría su etapa. El nombre de la skill sí lo sabemos aquí.
case "$LINE" in
  *'"event":"skill-start"'*) ;;
  *) exit 0 ;;
esac
SKILL_NAME=${LINE#*'"skill":"'}; SKILL_NAME=${SKILL_NAME%%'"'*}; SKILL_NAME=${SKILL_NAME##*:}
case "$SKILL_NAME" in
  sdd-requirements-engineer)   STAGE=requirements-engineer ;;
  sdd-specifications-engineer) STAGE=specifications-engineer ;;
  sdd-spec-auditor)            STAGE=spec-auditor ;;
  sdd-test-planner)            STAGE=test-planner ;;
  sdd-plan-architect)          STAGE=plan-architect ;;
  sdd-task-generator)          STAGE=task-generator ;;
  sdd-task-implementer)        STAGE=task-implementer ;;
  sdd-security-auditor)        STAGE=security-auditor ;;
  sdd-tech-designer)           STAGE=tech-designer ;;
  sdd-ux-designer)             STAGE=ux-designer ;;
  sdd-gap-detector)            STAGE=gap-detector ;;
  sdd-req-change)              STAGE=req-change ;;
  *) exit 0 ;;
esac
PIPELINE_STATE="$STATE_ROOT/pipeline-state.json"
[ -f "$PIPELINE_STATE" ] || exit 0
NOW_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
sdd_lock "$PIPELINE_STATE" || exit 0
TMP_STATE="$PIPELINE_STATE.sdd-act.$$"
if command -v jq >/dev/null 2>&1; then
  jq --arg s "$STAGE" --arg now "$NOW_TS" '
    .stages //= {} |
    .stages[$s] //= {status: "pending", outputHash: null, lastRun: null, staleReason: null} |
    (if (.stages[$s].status // "") == "error" then . else .stages[$s].status = "running" end) |
    .currentStage = $s | .lastUpdated = $now
  ' "$PIPELINE_STATE" > "$TMP_STATE" 2>/dev/null && mv -f "$TMP_STATE" "$PIPELINE_STATE" 2>/dev/null || rm -f "$TMP_STATE"
elif command -v node >/dev/null 2>&1; then
  SDD_STATE_FILE="$PIPELINE_STATE" SDD_STAGE="$STAGE" SDD_NOW="$NOW_TS" SDD_TMP="$TMP_STATE" node -e '
    const fs = require("fs"), f = process.env.SDD_STATE_FILE, s = process.env.SDD_STAGE;
    try {
      const j = JSON.parse(fs.readFileSync(f, "utf8"));
      j.stages = j.stages || {};
      j.stages[s] = j.stages[s] || { status: "pending", outputHash: null, lastRun: null, staleReason: null };
      if (j.stages[s].status !== "error") j.stages[s].status = "running";
      j.currentStage = s; j.lastUpdated = process.env.SDD_NOW;
      fs.writeFileSync(process.env.SDD_TMP, JSON.stringify(j, null, 2) + "\n");
      fs.renameSync(process.env.SDD_TMP, f);
    } catch (e) { try { fs.unlinkSync(process.env.SDD_TMP); } catch (_) {} }
  ' 2>/dev/null || rm -f "$TMP_STATE"
fi
sdd_unlock "$PIPELINE_STATE"
exit 0
