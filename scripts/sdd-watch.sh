#!/usr/bin/env bash
# sdd-watch.sh — live terminal panel of the SDD pipeline: stages, running skill, agents, sessions,
# handoffs, open questions, bench and the activity log written by hooks/sdd-activity-log.sh. Read-only.
#
# Usage: sdd-watch.sh [DIR | --root DIR] [--once] [--brief] [--interval N]
#   DIR, --root    main checkout (default: $SDD_STATE_ROOT, else the parent of the git common dir, else cwd)
#   --once         print the panel once and exit (tests, reports)
#   --brief        one line per run; with no DIR it walks the global index (~/.claude/sdd/active-runs.json)
#   --interval N   seconds between refreshes (default 5)
#
# Sources (all under ROOT unless noted)
#   pipeline-state.json            stage status/lastRun, currentStage, summary.handoff
#   .sdd/activity.jsonl            one JSON per hook event: session-start|session-end|skill-start|agent-start|
#                                  subagent-start|subagent-stop|stop (ts, session, role, skill, agent_type, …)
#   .sdd/current-task.json         current task of the main checkout and of every `git worktree list` entry
#   ~/.claude/sessions/*.json      live Claude Code sessions whose cwd shares ROOT's git common dir
#   .claude/sdd-sessions.json      role of each session name
#   .sdd/questions-<role>.md       number of [OPEN] questions per station
#   .sdd/bench/events.jsonl        last 5 bench events
#
# Portable: bash 3.2 + git (no awk/grep); jq preferred with a node fallback (SDD_WATCH_JSON=jq|node forces one).
# No `watch`: the script clears and repaints itself. ANSI colours only when stdout is a TTY (NO_COLOR disables).
set -euo pipefail

ROOT=""
ONCE=false
BRIEF=false
INTERVAL=5

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "sdd-watch: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --root)       shift; ROOT="${1:-}" ;;
    --root=*)     ROOT="${1#*=}" ;;
    --once)       ONCE=true ;;
    --brief)      ONCE=true; BRIEF=true ;;
    --interval)   shift; INTERVAL="${1:-}" ;;
    --interval=*) INTERVAL="${1#*=}" ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "sdd-watch: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
    *)            ROOT="$1" ;;   # ruta suelta: igual que --root (así lo llama /sdd-watch)
  esac
  shift
done
ROOT_GIVEN=false
[ -z "$ROOT" ] || ROOT_GIVEN=true
case "$INTERVAL" in ''|*[!0-9]*) die "--interval expects a number of seconds" ;; esac
[ "$INTERVAL" -ge 1 ] || INTERVAL=1

# ── Library (two roots, roles, peers) ────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SCRIPT_DIR="."
SDD_LIB=""
for candidate in "$SCRIPT_DIR/../hooks/lib/sdd-common.sh" \
                 "${SDD_PLUGIN_ROOT:-}/hooks/lib/sdd-common.sh" \
                 "${CLAUDE_PLUGIN_ROOT:-}/hooks/lib/sdd-common.sh"; do
  case "$candidate" in /hooks/lib/*) continue ;; esac
  if [ -f "$candidate" ]; then SDD_LIB="$candidate"; break; fi
done
[ -n "$SDD_LIB" ] || die "hooks/lib/sdd-common.sh not found (run from the plugin checkout or set SDD_PLUGIN_ROOT)"
# shellcheck source=../hooks/lib/sdd-common.sh
. "$SDD_LIB"

# ── --brief sin ruta: una línea por run del índice global ────────────────────
# El índice (<config>/sdd/active-runs.json) lo escribe hooks/sdd-activity-log.sh, con una entrada por
# checkout principal. Así `/sdd-watch` sin argumentos ve los pipelines que corren en OTROS procesos y
# OTROS proyectos. Sin índice o sin entradas, sigue el camino normal (cwd).
global_roots() {
  local f
  f=$(sdd_runs_file)
  [ -f "$f" ] || return 0
  if sdd_has_jq; then
    jq -r '(.runs // {}) | (if type == "object" then . else {} end)
           | [ .[] | select(type == "object" and (.root // "") != "") ] | sort_by(.last_seen // "") | reverse | .[] | .root' "$f" 2>/dev/null || true
  elif sdd_has_node; then
    SDD_RUNS_FILE="$f" node -e '
      const fs = require("fs");
      try {
        const idx = JSON.parse(fs.readFileSync(process.env.SDD_RUNS_FILE, "utf8"));
        const runs = (idx && typeof idx.runs === "object" && idx.runs) || {};
        const all = Object.keys(runs).map((k) => runs[k]).filter((r) => r && r.root);
        all.sort((a, b) => String(b.last_seen || "").localeCompare(String(a.last_seen || "")));
        if (all.length) process.stdout.write(all.map((r) => r.root).join("\n") + "\n");
      } catch (e) {}' 2>/dev/null || true
  fi
  return 0
}
if [ "$BRIEF" = true ] && [ "$ROOT_GIVEN" = false ]; then
  GROOTS=$(global_roots) || GROOTS=""
  if [ -n "$GROOTS" ]; then
    printed=false
    while IFS= read -r r; do
      [ -n "$r" ] && [ -d "$r" ] || continue
      bash "$0" --brief --root "$r" 2>/dev/null && printed=true
    done <<< "$GROOTS"
    [ "$printed" = false ] || exit 0
  fi
fi

# ── Root ─────────────────────────────────────────────────────────────────────
if [ -z "$ROOT" ]; then
  if [ -n "${SDD_STATE_ROOT:-}" ]; then
    ROOT="$SDD_STATE_ROOT"
  else
    ROOT=$(sdd_git_common_dir "$PWD" 2>/dev/null) && ROOT=$(dirname "$ROOT") || ROOT="$PWD"
  fi
fi
ROOT=$(cd "$ROOT" 2>/dev/null && pwd -P) || die "directory not found: $ROOT"
export STATE_ROOT="$ROOT"   # sdd_role_by_name reads $STATE_ROOT/.claude/sdd-sessions.json
STATE="$ROOT/pipeline-state.json"
ACT="$ROOT/.sdd/activity.jsonl"
BENCH="$ROOT/.sdd/bench/events.jsonl"

ENGINE="${SDD_WATCH_JSON:-}"
if [ -z "$ENGINE" ]; then
  if sdd_has_jq; then ENGINE=jq; elif sdd_has_node; then ENGINE=node; else ENGINE=none; fi
fi
[ "$ENGINE" != none ] || die "needs jq or node"

# ── Colours ──────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_B=$'\033[1m'; C_D=$'\033[2m'; C_R=$'\033[0m'
  C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_RED=$'\033[31m'; C_MAG=$'\033[35m'; C_CYN=$'\033[36m'
else
  C_B=""; C_D=""; C_R=""; C_GRN=""; C_YEL=""; C_RED=""; C_MAG=""; C_CYN=""
fi
status_color() {
  case "$1" in
    done) printf '%s' "$C_GRN" ;; running) printf '%s%s' "$C_B" "$C_YEL" ;; stale) printf '%s' "$C_MAG" ;;
    error) printf '%s' "$C_RED" ;; *) printf '%s' "$C_D" ;;
  esac
}

# ── Formatting ───────────────────────────────────────────────────────────────
fmt_dur() { # seconds → "1h 05m" | "12m 03s" | "40s" ("-" if not a number)
  local s="$1" h m
  case "$s" in ''|*[!0-9]*) printf -- '-'; return 0 ;; esac
  h=$((s / 3600)); m=$(((s % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf '%dh %02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf '%dm %02ds' "$m" $((s % 60))
  else printf '%ds' "$s"; fi
}
fmt_ts() { # 2026-08-24T20:30:17Z → 2026-08-24 20:30Z ("-" when absent)
  local t="$1"
  case "$t" in ????-??-??T??:??*) printf '%s %sZ' "${t:0:10}" "${t:11:5}" ;; *) printf '%s' "${t:--}" ;; esac
}
iso_to_epoch() { # BSD date, then GNU date; empty on failure
  local t="${1%%.*}"; t="${t%Z}Z"
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$t" +%s 2>/dev/null || date -u -d "$t" +%s 2>/dev/null || true
}
# json_fields FILE key... → tab-separated values ("-" when missing); one jq call, N node calls
json_fields() {
  local f="$1" out="" k v; shift
  if [ "$ENGINE" = jq ]; then
    jq -r --arg ks "$*" '[ ($ks | split(" "))[] as $k | (.[$k] // "-" | tostring | gsub("[\t\n]"; " ")) ] | join("\t")' "$f" 2>/dev/null || true
    return 0
  fi
  for k in "$@"; do
    v=$(sdd_json_get "$f" ".$k // empty") || v=""
    v="${v//$'\t'/ }"
    out="${out:+$out	}${v:--}"
  done
  printf '%s\n' "$out"
}

# ── Reducer: state + activity + bench → TSV lines (one process) ──────────────
# STATE present currentStage done total | STATE absent
# STAGE name status lastRun
# HANDOFF stage to sentAt result
# ACT present N | ACT none
# NOW session role skill args elapsed in_agent via          (skill-start not closed by stop/session-end)
# AGENT type id description session role elapsed             (subagent-start without subagent-stop)
# AGENTS_HOUR N
# RECENT hh:mm:ss event role detail session stage task       (last 8)
# BENCH none | BENCHROW hh:mm:ss role fase stream event task sha  (last 5)
JQ_PROG='
def order: ["requirements-engineer","specifications-engineer","spec-auditor","test-planner","plan-architect","task-generator","task-implementer"];
def obj: if type == "object" then . else {} end;
def nz: if . == null or . == "" then "-" else tostring end;
def tsv: map(nz | gsub("[\t\n\r]"; " ")) | join("\t");
def ep: ((.ts // "") | tostring | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | (try fromdateiso8601 catch null));
def lines: split("\n") | map(select(length > 0) | (fromjson? // empty)) | map(select(type == "object"));
($now | tonumber) as $nowe
| (($state | fromjson?) // null) as $st
| (if ($st | type) != "object" then (["STATE", "absent"] | tsv) else
    ($st.stages | obj) as $sg
    | (order + (($sg | keys) - order)) as $names
    | ([ order[] | select(($sg[.] | obj | .status) == "done") ] | length) as $done
    | (["STATE", "present", ($st.currentStage // "-"), $done, (order | length)] | tsv),
      ($names[] | . as $n | ($sg[$n] | obj) as $s | ["STAGE", $n, ($s.status // "pending"), ($s.lastRun // "-")] | tsv),
      ($names[] | . as $n | ($sg[$n] | obj | .summary | obj | .handoff) as $h | select(($h | type) == "object")
        | ["HANDOFF", $n, $h.to, $h.sentAt, $h.result] | tsv)
  end)
, (($act | lines) | to_entries | map(.value + {i: .key, e: (.value | ep)})) as $ev
| (if ($ev | length) == 0 then (["ACT", "none"] | tsv) else
    (["ACT", "present", ($ev | length)] | tsv),
    # Una skill se cierra con skill-end (o session-end); la de un subagente, con su subagent-stop.
    # `stop` NO cierra: se dispara al final de CADA turno y la skill sigue viva tras una pregunta.
    ( [ $ev[] | select(.event == "skill-start" or .event == "skill-end" or .event == "session-end" or .event == "subagent-stop")
        | . + {k: (if .event == "subagent-stop" then ((.session // "-") + "/" + (.agent_id // "-"))
                   else ((.session // "-") + "/" + (.in_agent // "-")) end)} ]
      | group_by(.k) | map(max_by(.i)) | map(select(.event == "skill-start"))
      | map(select(. as $s | ([ $ev[] | select(.event == "session-end" and .session == $s.session and .i > $s.i) ] | length) == 0))
      | .[] | ["NOW", .session, .role, .skill, .args, (if .e == null then "-" else ($nowe - .e) end), .in_agent, .via] | tsv ),
    ( [ $ev[] | select(.event == "subagent-start") ]
      | map(select(. as $s | ([ $ev[] | select(.i > $s.i and ((.event == "subagent-stop" and .agent_id == $s.agent_id)
                                                          or (.event == "session-end" and .session == $s.session))) ] | length) == 0))
      | .[] | . as $s
      | ([ $ev[] | select(.event == "agent-start" and .i < $s.i and .session == $s.session and .agent_type == $s.agent_type) ]
         | last | if . == null then "-" else (.description // "-") end) as $d
      | ["AGENT", $s.agent_type, $s.agent_id, $d, $s.session, $s.role, (if $s.e == null then "-" else ($nowe - $s.e) end)] | tsv ),
    (["AGENTS_HOUR", ([ $ev[] | select(.event == "subagent-start" and .e != null and .e >= ($nowe - 3600)) ] | length)] | tsv),
    ( $ev[-8:][] | ["RECENT", ((.ts // "") | tostring | .[11:19]), .event, .role,
        (if .event == "skill-start" then ("/" + (.skill // "?") + (if .args then " " + (.args | tostring) else "" end)
                                          + (if .in_agent then " (in " + (.in_agent | tostring) + ")" else "" end))
         elif .event == "skill-end" then ("/" + (.skill // "?") + " · " + ((.seconds // 0) | tostring) + "s (" + (.reason // "?") + ")")
         elif .event == "agent-start" then ((.agent_type // "?") + (if .description then ": " + (.description | tostring) else "" end))
         elif .event == "subagent-start" or .event == "subagent-stop" then ((.agent_type // "?") + " " + (.agent_id // "" | tostring))
         elif .event == "session-start" then (.source // "")
         elif .event == "session-end" then (.reason // "")
         else "" end), .session, .stage, .task] | tsv )
  end)
, (($bench | lines) as $b | if ($b | length) == 0 then (["BENCH", "none"] | tsv) else
    ($b[-5:][] | ["BENCHROW", ((.ts // "") | tostring | .[11:19]), .role, .fase, .stream, .event, .task, .sha] | tsv) end)'

NODE_PROG='
const fs = require("fs");
const order = ["requirements-engineer","specifications-engineer","spec-auditor","test-planner","plan-architect","task-generator","task-implementer"];
const obj = (v) => (v && typeof v === "object" && !Array.isArray(v)) ? v : {};
const nz = (v) => (v === null || v === undefined || v === "") ? "-" : String(v);
const tsv = (a) => a.map((v) => nz(v).replace(/[\t\n\r]/g, " ")).join("\t");
const read = (f) => { try { return fs.readFileSync(f, "utf8"); } catch (e) { return ""; } };
const lines = (t) => t.split("\n").filter((l) => l.length > 0).map((l) => { try { return JSON.parse(l); } catch (e) { return null; } }).filter((o) => o && typeof o === "object" && !Array.isArray(o));
const ep = (o) => { const t = Date.parse(String(o.ts || "")); return Number.isFinite(t) ? Math.floor(t / 1000) : null; };
const now = Number(process.env.SDD_W_NOW) || Math.floor(Date.now() / 1000);
const out = [];
let st = null; try { st = JSON.parse(read(process.env.SDD_W_STATE)); } catch (e) { st = null; }
if (!st || typeof st !== "object" || Array.isArray(st)) out.push(tsv(["STATE", "absent"]));
else {
  const sg = obj(st.stages);
  const names = order.concat(Object.keys(sg).filter((k) => !order.includes(k)));
  const done = order.filter((s) => obj(sg[s]).status === "done").length;
  out.push(tsv(["STATE", "present", st.currentStage, done, order.length]));
  for (const n of names) { const s = obj(sg[n]); out.push(tsv(["STAGE", n, s.status || "pending", s.lastRun])); }
  for (const n of names) { const h = obj(obj(sg[n]).summary).handoff; if (h && typeof h === "object") out.push(tsv(["HANDOFF", n, h.to, h.sentAt, h.result])); }
}
const ev = lines(read(process.env.SDD_W_ACT)).map((o, i) => Object.assign({}, o, { i, e: ep(o) }));
if (ev.length === 0) out.push(tsv(["ACT", "none"]));
else {
  out.push(tsv(["ACT", "present", ev.length]));
  const last = {};
  for (const x of ev) {
    // skill-end / session-end cierran la skill; `stop` (fin de turno) no. Ver el comentario en JQ_PROG.
    if (!["skill-start", "skill-end", "session-end", "subagent-stop"].includes(x.event)) continue;
    const k = x.event === "subagent-stop" ? `${x.session ?? "-"}/${x.agent_id ?? "-"}` : `${x.session ?? "-"}/${x.in_agent ?? "-"}`;
    last[k] = x;
  }
  for (const k of Object.keys(last).sort()) {
    const s = last[k];
    if (s.event !== "skill-start") continue;
    if (ev.some((y) => y.event === "session-end" && y.session === s.session && y.i > s.i)) continue;
    out.push(tsv(["NOW", s.session, s.role, s.skill, s.args, s.e == null ? "-" : now - s.e, s.in_agent, s.via]));
  }
  for (const s of ev.filter((x) => x.event === "subagent-start")) {
    if (ev.some((y) => y.i > s.i && ((y.event === "subagent-stop" && y.agent_id === s.agent_id) || (y.event === "session-end" && y.session === s.session)))) continue;
    const a = ev.filter((y) => y.event === "agent-start" && y.i < s.i && y.session === s.session && y.agent_type === s.agent_type).pop();
    out.push(tsv(["AGENT", s.agent_type, s.agent_id, a ? (a.description ?? "-") : "-", s.session, s.role, s.e == null ? "-" : now - s.e]));
  }
  out.push(tsv(["AGENTS_HOUR", ev.filter((x) => x.event === "subagent-start" && x.e !== null && x.e >= now - 3600).length]));
  for (const x of ev.slice(-8)) {
    let d = "";
    if (x.event === "skill-start") d = "/" + (x.skill ?? "?") + (x.args ? " " + x.args : "") + (x.in_agent ? " (in " + x.in_agent + ")" : "");
    else if (x.event === "skill-end") d = "/" + (x.skill ?? "?") + " · " + (x.seconds ?? 0) + "s (" + (x.reason ?? "?") + ")";
    else if (x.event === "agent-start") d = (x.agent_type ?? "?") + (x.description ? ": " + x.description : "");
    else if (x.event === "subagent-start" || x.event === "subagent-stop") d = (x.agent_type ?? "?") + " " + (x.agent_id ?? "");
    else if (x.event === "session-start") d = x.source ?? "";
    else if (x.event === "session-end") d = x.reason ?? "";
    out.push(tsv(["RECENT", String(x.ts ?? "").slice(11, 19), x.event, x.role, d, x.session, x.stage, x.task]));
  }
}
const b = lines(read(process.env.SDD_W_BENCH));
if (b.length === 0) out.push(tsv(["BENCH", "none"]));
else for (const x of b.slice(-5)) out.push(tsv(["BENCHROW", String(x.ts ?? "").slice(11, 19), x.role, x.fase, x.stream, x.event, x.task, x.sha]));
process.stdout.write(out.join("\n") + "\n");'

reduce() {
  local now statef="$STATE" actf="$ACT" benchf="$BENCH"
  now=$(date -u +%s)
  [ -f "$statef" ] || statef=/dev/null
  [ -f "$actf" ] || actf=/dev/null
  [ -f "$benchf" ] || benchf=/dev/null
  if [ "$ENGINE" = jq ]; then
    jq -n -r --arg now "$now" --rawfile state "$statef" --rawfile act "$actf" --rawfile bench "$benchf" "$JQ_PROG" 2>/dev/null || true
  else
    SDD_W_NOW="$now" SDD_W_STATE="$statef" SDD_W_ACT="$actf" SDD_W_BENCH="$benchf" node -e "$NODE_PROG" 2>/dev/null || true
  fi
}

# ── Sections computed in bash ────────────────────────────────────────────────
# worktrees: "path<TAB>branch" (ROOT alone when not a git repo)
worktree_rows() {
  local line wt="" br="" any=0
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) wt="${line#worktree }" ;;
      "branch "*)   br="${line#branch }"; br="${br#refs/heads/}" ;;
      "")           if [ -n "$wt" ]; then printf '%s\t%s\n' "$wt" "${br:--}"; any=1; fi; wt=""; br="" ;;
    esac
  done <<< "$(git -C "$ROOT" worktree list --porcelain 2>/dev/null)"
  if [ -n "$wt" ]; then printf '%s\t%s\n' "$wt" "${br:--}"; any=1; fi
  [ "$any" = 1 ] || printf '%s\t-\n' "$ROOT"
}
# task_rows → "label<TAB>branch<TAB>taskId<TAB>stream<TAB>role<TAB>startedAt"
task_rows() {
  local wt br f label
  while IFS=$'\t' read -r wt br; do
    [ -n "$wt" ] || continue
    f="$wt/.sdd/current-task.json"
    [ -f "$f" ] || continue
    if [ "$wt" = "$ROOT" ]; then label="."; else label="$(basename "$wt")"; fi
    printf '%s\t%s\t%s\n' "$label" "${br:--}" "$(json_fields "$f" taskId stream role startedAt)"
  done <<< "$(worktree_rows)"
}
# session_rows → "name<TAB>status<TAB>role<TAB>pid" for live sessions of this repo (all pids, ours included)
session_rows() {
  local mine f pid name status cwd common role
  mine=$(sdd_git_common_dir "$ROOT") || return 0
  for f in "${HOME:-}"/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    pid=$(sdd_json_get "$f" '.pid // empty') || pid=""
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$pid" 2>/dev/null || continue
    cwd=$(sdd_json_get "$f" '.cwd // empty') || cwd=""
    [ -n "$cwd" ] && [ -d "$cwd" ] || continue
    common=$(sdd_git_common_dir "$cwd") || continue
    [ "$common" = "$mine" ] || continue
    name=$(sdd_json_get "$f" '.name // empty') || name=""
    status=$(sdd_json_get "$f" '.status // empty') || status=""
    role=$(sdd_role_by_name "$name") || role=""
    printf '%s\t%s\t%s\t%s\n' "${name:-pid$pid}" "${status:-?}" "${role:--}" "$pid"
  done
}
# question_rows → "file<TAB>open"
question_rows() {
  local q n line
  for q in "$ROOT"/.sdd/questions-*.md; do
    [ -f "$q" ] || continue
    n=0
    while IFS= read -r line; do
      case "$line" in "## Q-"*"[OPEN]"*) n=$((n + 1)) ;; esac
    done < "$q"
    printf '%s\t%s\n' "$(basename "$q")" "$n"
  done
}

# ── Render ───────────────────────────────────────────────────────────────────
render() {
  local data now_epoch tag a b c d e f g h
  local st_present=absent cur="-" done_n=0 total=7 stages="" handoffs="" running=""
  local now_skill="" now_args="" now_since=""
  local act_present=none act_n=0 nows="" agents="" agents_n=0 agents_hour=0 recent="" bench="" bench_present=none
  data=$(reduce)
  now_epoch=$(date -u +%s)

  while IFS=$'\t' read -r tag a b c d e f g h; do
    case "$tag" in
      STATE)
        st_present="$a"
        if [ "$a" = present ]; then cur="$b"; done_n="$c"; total="$d"; fi ;;
      STAGE)
        stages="$stages$(printf '  %-26s %s%-8s%s %s' "$a" "$(status_color "$b")" "$b" "$C_R" "$(fmt_ts "$c")")"$'\n'
        [ "$b" = running ] && [ -z "$running" ] && running="$a" ;;
      HANDOFF)
        handoffs="$handoffs$(printf '  %-26s → %-22s %-22s %s' "$a" "$b" "$d" "$(fmt_ts "$c")")"$'\n' ;;
      ACT) act_present="$a"; act_n="${b:-0}" ;;
      NOW)
        now_skill="${c##*:}"; now_since="$e"
        now_args="$d"; [ "${#now_args}" -gt 44 ] && now_args="${now_args:0:44}…"
        nows="$nows$(printf '  skill  %s/%s%s%s  sesión %s [%s]  desde %s%s' "$C_B$C_CYN" "$now_skill" "$([ "$d" != - ] && printf ' %s' "$now_args")" "$C_R" "$a" "$b" "$(fmt_dur "$e")" "$([ "$f" != - ] && printf '  (en subagente %s)' "$f")")"$'\n' ;;
      AGENT)
        agents_n=$((agents_n + 1))
        agents="$agents$(printf '  %-18s %-14s %-40s %s [%s]  %s' "$a" "$b" "$([ "$c" != - ] && printf '%s' "${c:0:40}" || printf -- '-')" "$d" "$e" "$(fmt_dur "$f")")"$'\n' ;;
      AGENTS_HOUR) agents_hour="$a" ;;
      RECENT)
        recent="$recent$(printf '  %s %-15s %s%s%s' "$a" "$b" "$([ "$d" != - ] && printf '%s  ' "$d")" "$e" "$([ "$c" != - ] && printf '  [%s]' "$c")")"$'\n' ;;
      BENCH) bench_present="$a" ;;
      BENCHROW)
        bench_present=present
        bench="$bench$(printf '  %s %-10s F%s/%-2s %-14s %-12s %s' "$a" "$b" "$c" "$d" "$e" "$f" "$g")"$'\n' ;;
    esac
  done <<< "$data"

  local stage_src="pipeline-state"
  if [ -z "$running" ] && [ -n "$now_skill" ]; then
    case "$now_skill" in
      sdd-requirements-engineer)   running=requirements-engineer ;;
      sdd-specifications-engineer) running=specifications-engineer ;;
      sdd-spec-auditor)            running=spec-auditor ;;
      sdd-test-planner)            running=test-planner ;;
      sdd-plan-architect)          running=plan-architect ;;
      sdd-task-generator)          running=task-generator ;;
      sdd-task-implementer)        running=task-implementer ;;
      sdd-security-auditor)        running=security-auditor ;;
      sdd-tech-designer)           running=tech-designer ;;
      sdd-ux-designer)             running=ux-designer ;;
      sdd-gap-detector)            running=gap-detector ;;
      sdd-req-change)              running=req-change ;;
    esac
    [ -n "$running" ] && stage_src="skill en curso"
  fi

  # --brief: una línea, pensada para `!bash …/sdd-watch.sh --brief --root <proyecto>` desde otra terminal
  if [ "$BRIEF" = true ]; then
    local b_open=0 b_q b_n
    b_q=$(question_rows) || b_q=""
    if [ -n "$b_q" ]; then
      while IFS=$'\t' read -r _ b_n; do
        case "$b_n" in ''|*[!0-9]*) ;; *) b_open=$((b_open + b_n)) ;; esac
      done <<< "$b_q"
    fi
    printf '%s  %s/%s done' "$(basename "$ROOT")" "$done_n" "$total"
    if [ -n "$running" ]; then printf ' · %s%s' "$running" "$([ -n "$now_since" ] && [ "$now_since" != - ] && printf ' %s' "$(fmt_dur "$now_since")")"; fi
    printf ' · %s agente%s' "$agents_n" "$([ "$agents_n" = 1 ] || printf 's')"
    [ "$b_open" -gt 0 ] && printf ' · %s pregunta(s) abiertas' "$b_open"
    printf '\n'
    return 0
  fi

  printf '%sSDD watch%s  %s  %s%s%s\n' "$C_B" "$C_R" "$ROOT" "$C_D" "$(date '+%Y-%m-%d %H:%M:%S')" "$C_R"
  if [ "$ONCE" = false ]; then printf '%s(cada %ss · Ctrl+C para salir)%s\n' "$C_D" "$INTERVAL" "$C_R"; fi
  printf '\n'

  # Pipeline
  if [ "$st_present" = present ]; then
    printf '%sPipeline%s  %s/%s done · currentStage: %s\n' "$C_B" "$C_R" "$done_n" "$total" "$cur"
    printf '%s' "$stages"
  else
    printf '%sPipeline%s  %ssin pipeline-state.json en %s%s\n' "$C_B" "$C_R" "$C_D" "$ROOT" "$C_R"
  fi
  printf '\n'

  # Ahora
  printf '%sAhora%s\n' "$C_B" "$C_R"
  if [ -n "$running" ]; then printf '  etapa  %s%s%s (%s)\n' "$C_YEL" "$running" "$C_R" "$stage_src"; else printf '  etapa  %sninguna etapa running%s\n' "$C_D" "$C_R"; fi
  if [ -n "$nows" ]; then printf '%s' "$nows"; else printf '  skill  %sninguna skill en curso%s\n' "$C_D" "$C_R"; fi
  local trows
  trows=$(task_rows) || trows=""
  if [ -n "$trows" ]; then
    while IFS=$'\t' read -r a b c d e f; do
      [ -n "$a" ] || continue
      g=$(iso_to_epoch "$f")
      if [ -n "$g" ]; then g="desde $(fmt_dur $((now_epoch - g)))"; else g="${f:--}"; fi
      printf '  task   %s [%s]  %s%s%s  stream %s  %s  %s\n' "$a" "$b" "$C_CYN" "$c" "$C_R" "$d" "$e" "$g"
    done <<< "$trows"
  else
    printf '  task   %sningún .sdd/current-task.json (principal ni worktrees)%s\n' "$C_D" "$C_R"
  fi
  printf '\n'

  # Agentes
  printf '%sAgentes%s  %s activo(s) · %s lanzado(s) en la última hora\n' "$C_B" "$C_R" "$agents_n" "$agents_hour"
  if [ -n "$agents" ]; then printf '%s' "$agents"; else printf '  %sningún subagente activo%s\n' "$C_D" "$C_R"; fi
  printf '\n'

  # Sesiones
  printf '%sSesiones%s\n' "$C_B" "$C_R"
  local srows
  srows=$(session_rows) || srows=""
  if [ -n "$srows" ]; then
    while IFS=$'\t' read -r a b c d; do
      [ -n "$a" ] || continue
      case "$b" in busy|waiting) e="$C_YEL" ;; idle) e="$C_GRN" ;; ''|null|'?') b=headless; e="$C_D" ;; *) e="$C_D" ;; esac
      printf '  %-24s %s%-8s%s %-12s pid %s\n' "$a" "$e" "$b" "$C_R" "$c" "$d"
    done <<< "$srows"
  else
    printf '  %sninguna sesión viva de este repo (~/.claude/sessions)%s\n' "$C_D" "$C_R"
  fi
  printf '\n'

  # Handoffs
  printf '%sHandoffs%s\n' "$C_B" "$C_R"
  if [ -n "$handoffs" ]; then printf '%s' "$handoffs"; else printf '  %sninguno registrado (summary.handoff)%s\n' "$C_D" "$C_R"; fi
  printf '\n'

  # Preguntas
  printf '%sPreguntas%s\n' "$C_B" "$C_R"
  local qrows
  qrows=$(question_rows) || qrows=""
  if [ -n "$qrows" ]; then
    while IFS=$'\t' read -r a b; do
      [ -n "$a" ] || continue
      if [ "$b" -gt 0 ] 2>/dev/null; then e="$C_B$C_RED"; else e="$C_D"; fi
      printf '  %-32s %s%s [OPEN]%s\n' "$a" "$e" "$b" "$C_R"
    done <<< "$qrows"
  else
    printf '  %sninguna (.sdd/questions-*.md)%s\n' "$C_D" "$C_R"
  fi
  printf '\n'

  # Bench
  if [ "$bench_present" = present ]; then
    printf '%sBench%s  últimos 5 de .sdd/bench/events.jsonl\n' "$C_B" "$C_R"
    printf '%s' "$bench"
    printf '\n'
  fi

  # Actividad reciente
  printf '%sActividad reciente%s  (UTC'"$([ "$act_present" = present ] && printf ' · %s eventos' "$act_n")"')\n' "$C_B" "$C_R"
  if [ "$act_present" = present ]; then printf '%s' "$recent"; else printf '  %ssin actividad registrada (.sdd/activity.jsonl)%s\n' "$C_D" "$C_R"; fi
}

if [ "$ONCE" = true ]; then
  render
  exit 0
fi

trap 'printf "\n"; exit 0' INT TERM
while :; do
  frame=$(render 2>&1) || frame="sdd-watch: render failed"
  if [ -t 1 ]; then printf '\033[H\033[2J'; fi
  printf '%s\n' "$frame"
  sleep "$INTERVAL"
done
