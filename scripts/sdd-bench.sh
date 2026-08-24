#!/usr/bin/env bash
# sdd-bench.sh — measures each SDD FASE from .sdd/bench/events.jsonl (git as fallback). Read-only on the repo.
#
# Usage: sdd-bench.sh [--fase N] [--root DIR] [--no-save]
#   --fase N     only FASE N (default: every FASE found in the events, in Task: trailers or in fase-*-verified tags)
#   --root DIR   main checkout (default: $SDD_STATE_ROOT, else the parent of the git common dir, else the cwd)
#   --no-save    print the table only (by default it also writes $ROOT/.sdd/bench/BENCH-FASE-N.md, one per FASE)
#
# Sources
#   events  $ROOT/.sdd/bench/events.jsonl — one JSON object per line, written by sdd-task-implementer:
#           {"ts","role","fase","stream","event","task","sha"[,"file"]}
#           event = task-start | task-commit | pause | merge | merge-conflict | fase-verified
#   git     fallback: wall = first commit with `Task: TASK-FN-*` -> tag fase-N-verified; commits = Task: trailers
#           reachable from HEAD; merges = "(FASE-N Stream X)" merge subjects. Only HEAD counts (never --all).
#
# Columns: FASE | modo (subagentes = no Stream events, worktrees = Stream events or merges) | streams | wall
#          | tasks (task-commit) | commits | merges | conflictos (merge-conflict; files listed under the table)
#          | PAUSE (total and per role) | tasks/h
#
# Portable: bash 3.2, awk, sed, git; jq preferred with a node fallback (SDD_BENCH_JSON=jq|node forces one).
set -euo pipefail

FASE_FILTER=""
ROOT=""
SAVE=true

usage() { sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "sdd-bench: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --fase|--wave)     shift; FASE_FILTER="${1:-}" ;;
    --fase=*|--wave=*) FASE_FILTER="${1#*=}" ;;
    --root)            shift; ROOT="${1:-}" ;;
    --root=*)          ROOT="${1#*=}" ;;
    --no-save)         SAVE=false ;;
    -h|--help)         usage; exit 0 ;;
    *)                 echo "sdd-bench: unknown argument '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
if [ -n "$FASE_FILTER" ]; then
  case "$FASE_FILTER" in *[!0-9]*|'') echo "sdd-bench: --fase expects a number" >&2; exit 2 ;; esac
fi

# ── Root ─────────────────────────────────────────────────────────────────────
if [ -z "$ROOT" ]; then
  if [ -n "${SDD_STATE_ROOT:-}" ]; then
    ROOT="$SDD_STATE_ROOT"
  else
    common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git rev-parse --git-common-dir 2>/dev/null || true)"
    if [ -n "$common" ]; then
      case "$common" in /*) ;; *) common="$PWD/$common" ;; esac
      ROOT="$(dirname "$common")"
    else
      ROOT="$PWD"
    fi
  fi
fi
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || die "directory not found: $ROOT"
EVENTS="$ROOT/.sdd/bench/events.jsonl"
OUT_DIR="$ROOT/.sdd/bench"

HAS_GIT=false
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && git -C "$ROOT" rev-parse -q --verify HEAD >/dev/null 2>&1; then
  HAS_GIT=true
fi

ENGINE="${SDD_BENCH_JSON:-}"
if [ -z "$ENGINE" ]; then
  if command -v jq >/dev/null 2>&1; then ENGINE=jq
  elif command -v node >/dev/null 2>&1; then ENGINE=node
  else ENGINE=none; fi
fi

# ── Event aggregation → one TSV line per FASE ────────────────────────────────
# fase mode streams start end tasks commits merges conflicts cfiles pauses prole snames  ("-" = empty)
JQ_PROG='
def ep: (.ts // "" | tostring | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | (try fromdateiso8601 catch null));
def nz: if . == null or . == "" then "-" else tostring end;
def lettered: map(.stream // "-" | tostring)
  | map(select(. != "-" and . != "" and . != "base" and . != "integración" and . != "integracion" and . != "verificación" and . != "verificacion"))
  | unique;
split("\n") | map(select(length > 0)) | unique | map(fromjson? // empty)
| map(select(type == "object")) | map(.fase = (.fase | tonumber? // null)) | map(select(.fase != null))
| map(. + {e: ep})
| group_by(.fase) | map(
    (.[0].fase) as $f
    | lettered as $streams
    | ([.[] | select(.event == "task-start" and .e != null) | .e] | min) as $start
    | ([.[] | select(.event == "fase-verified" and .e != null) | .e] | max) as $end
    | [.[] | select(.event == "task-commit")] as $tc
    | [.[] | select(.event == "merge-conflict")] as $mc
    | [.[] | select(.event == "pause")] as $pz
    | ([.[] | select(.event == "merge")] | length) as $merges
    | [ $f,
        (if ($streams | length) > 0 or $merges > 0 then "worktrees" else "subagentes" end),
        ($streams | length),
        ($start | nz), ($end | nz),
        ($tc | map(.task // "-" | tostring) | unique | length),
        ($tc | map((.sha // "") | tostring | select(. != "")) | unique | length),
        $merges,
        ($mc | length),
        ($mc | map(.file // "?" | tostring) | unique | join(",") | nz),
        ($pz | length),
        ($pz | group_by(.role // "-") | map("\(.[0].role // "-"):\(length)") | join(",") | nz),
        ($streams | join(",") | nz)
      ] | map(tostring) | join("\t")
  ) | .[]'

NODE_PROG='
const fs = require("fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n").filter((l) => l.length > 0);
const seen = new Set(); const evs = [];
for (const l of lines) {
  if (seen.has(l)) continue; seen.add(l);
  let o; try { o = JSON.parse(l); } catch (e) { continue; }
  if (!o || typeof o !== "object") continue;
  const f = Number(o.fase); if (!Number.isFinite(f)) continue; o.fase = f;
  const t = Date.parse(o.ts || ""); o.e = Number.isFinite(t) ? Math.floor(t / 1000) : null;
  evs.push(o);
}
const nz = (v) => (v === null || v === undefined || v === "") ? "-" : String(v);
const NONLET = new Set(["-", "", "base", "integración", "integracion", "verificación", "verificacion"]);
const fases = [...new Set(evs.map((e) => e.fase))].sort((a, b) => a - b);
for (const f of fases) {
  const es = evs.filter((e) => e.fase === f);
  const streams = [...new Set(es.map((e) => String(e.stream ?? "-")).filter((s) => !NONLET.has(s)))].sort();
  const st = es.filter((e) => e.event === "task-start" && e.e !== null).map((e) => e.e);
  const en = es.filter((e) => e.event === "fase-verified" && e.e !== null).map((e) => e.e);
  const start = st.length ? Math.min(...st) : null, end = en.length ? Math.max(...en) : null;
  const tc = es.filter((e) => e.event === "task-commit"), mc = es.filter((e) => e.event === "merge-conflict"), pz = es.filter((e) => e.event === "pause");
  const merges = es.filter((e) => e.event === "merge").length;
  const tasks = new Set(tc.map((e) => String(e.task ?? "-"))).size;
  const commits = new Set(tc.map((e) => String(e.sha ?? "")).filter((s) => s !== "")).size;
  const cfiles = [...new Set(mc.map((e) => String(e.file ?? "?")))].sort();
  const byRole = {}; for (const p of pz) { const r = String(p.role ?? "-"); byRole[r] = (byRole[r] || 0) + 1; }
  const prole = Object.keys(byRole).sort().map((r) => r + ":" + byRole[r]).join(",");
  console.log([f, (streams.length > 0 || merges > 0) ? "worktrees" : "subagentes", streams.length, nz(start), nz(end),
    tasks, commits, merges, mc.length, nz(cfiles.join(",")), pz.length, nz(prole), nz(streams.join(","))].join("\t"));
}'

AGG=""
if [ -s "$EVENTS" ]; then
  case "$ENGINE" in
    jq)   AGG="$(jq -R -s -r "$JQ_PROG" "$EVENTS" 2>/dev/null)" || die "jq could not read $EVENTS" ;;
    node) AGG="$(node -e "$NODE_PROG" "$EVENTS" 2>/dev/null)" || die "node could not read $EVENTS" ;;
    *)    echo "sdd-bench: WARN neither jq nor node found — ignoring $EVENTS, using git only" >&2 ;;
  esac
fi

# ── git helpers (empty/0 when git is unavailable) ────────────────────────────
git_task_stats() { # FASE → "first_epoch commits tasks" from Task: trailers reachable from HEAD
  [ "$HAS_GIT" = true ] || { echo "0 0 0"; return 0; }
  git -C "$ROOT" log HEAD --reverse --format='%ct%x09%H%x09%(trailers:key=Task,valueonly)' 2>/dev/null |
    awk -F'\t' -v re="^TASK-F$1-" '
      NF >= 2 { ep = $1; h = $2; v = $3 }
      NF < 2  { v = $1 }
      v ~ re  { if (!(h in seen)) { seen[h] = 1; nc++; if (first == "") first = ep }
                if (!(v in tseen)) { tseen[v] = 1; nt++ } }
      END     { print first + 0, nc + 0, nt + 0 }'
}
git_tag_epoch() { # FASE → epoch of fase-N-verified (tagger date, else commit date); empty if absent
  local t=""
  [ "$HAS_GIT" = true ] || return 0
  git -C "$ROOT" rev-parse -q --verify "refs/tags/fase-$1-verified" >/dev/null 2>&1 || return 0
  t="$(git -C "$ROOT" for-each-ref --format='%(taggerdate:unix)' "refs/tags/fase-$1-verified" 2>/dev/null || true)"
  [ -n "$t" ] || t="$(git -C "$ROOT" log -1 --format=%ct "refs/tags/fase-$1-verified" 2>/dev/null || true)"
  printf '%s\n' "$t"
}
git_merge_streams() { # FASE → Stream names from "(FASE-N Stream X)" merge subjects, one per line
  [ "$HAS_GIT" = true ] || return 0
  git -C "$ROOT" log HEAD --merges --format=%s 2>/dev/null | sed -n "s/.*(FASE-$1 Stream \([^)]*\)).*/\1/p" | sort -u
}
all_fases() {
  {
    if [ -n "$AGG" ]; then printf '%s\n' "$AGG" | cut -f1; fi
    if [ "$HAS_GIT" = true ]; then
      git -C "$ROOT" log HEAD --format='%(trailers:key=Task,valueonly)' 2>/dev/null | sed -n 's/^TASK-F\([0-9][0-9]*\)-.*/\1/p'
      git -C "$ROOT" tag -l 'fase-*-verified' 2>/dev/null | sed -n 's/^fase-\([0-9][0-9]*\)-verified$/\1/p'
    fi
  } | grep -E '^[0-9]+$' | sort -un || true
}

# ── Formatting ───────────────────────────────────────────────────────────────
fmt_dur() { # seconds → "1h 05m" | "12m" | "40s"
  local s="$1" h m
  h=$((s / 3600)); m=$(((s % 3600) / 60))
  if [ "$h" -gt 0 ]; then printf '%dh %02dm' "$h" "$m"
  elif [ "$m" -gt 0 ]; then printf '%dm' "$m"
  else printf '%ds' "$s"; fi
}
fmt_iso() { # epoch → ISO-8601 UTC (BSD date, then GNU date, then the epoch itself)
  date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '%s\n' "$1"
}
join_commas() { printf '%s' "$1" | sed 's/,/, /g'; }

HEADER='| FASE | modo | streams | wall | tasks | commits | merges | conflictos | PAUSE | tasks/h |'
SEP='|---|---|---|---|---|---|---|---|---|---|'

FASES="$(all_fases)"
if [ -n "$FASE_FILTER" ]; then
  FASES="$(printf '%s\n' "$FASES" | grep -x "$FASE_FILTER" || true)"
  [ -n "$FASES" ] || die "no data for FASE-$FASE_FILTER (no events in $EVENTS, no Task: TASK-F$FASE_FILTER-* trailers, no fase-$FASE_FILTER-verified tag)"
fi
[ -n "$FASES" ] || die "no data (no events in $EVENTS and no Task: trailers or fase-*-verified tags in git)"

TABLE="$HEADER
$SEP"
NOTES=""
SAVED=""
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

for N in $FASES; do
  mode=subagentes; streams=0; start="-"; end="-"; tasks=0; commits=0; merges=0; conflicts=0
  cfiles="-"; pauses=0; prole="-"; snames="-"
  row=""
  if [ -n "$AGG" ]; then row="$(printf '%s\n' "$AGG" | awk -F'\t' -v f="$N" '$1 == f' | head -n 1)"; fi
  if [ -n "$row" ]; then
    IFS=$'\t' read -r _ mode streams start end tasks commits merges conflicts cfiles pauses prole snames <<< "$row"
  fi
  src_events=no; [ -n "$row" ] && src_events=yes
  src_wall="events"

  if [ "$HAS_GIT" = true ]; then
    read -r gstart gcommits gtasks <<< "$(git_task_stats "$N")"
    if [ "$start" = "-" ] && [ "$gstart" != "0" ]; then start="$gstart"; src_wall=git; fi
    if [ "$end" = "-" ]; then
      gend="$(git_tag_epoch "$N")"
      if [ -n "$gend" ]; then end="$gend"; src_wall=git; fi
    fi
    [ "$gcommits" -gt 0 ] && commits="$gcommits"           # HEAD is the truth for commits once integrated
    [ "$tasks" -eq 0 ] && tasks="$gtasks"
    gstreams="$(git_merge_streams "$N")"
    gmerges=0; [ -n "$gstreams" ] && gmerges="$(printf '%s\n' "$gstreams" | wc -l | tr -d ' ')"
    if [ "$merges" -eq 0 ] && [ "$gmerges" -gt 0 ]; then merges="$gmerges"; fi
    if [ "$streams" -eq 0 ] && [ "$gmerges" -gt 0 ]; then
      streams="$gmerges"; snames="$(printf '%s\n' "$gstreams" | paste -sd, -)"; mode=worktrees
    fi
  fi
  [ "$commits" -eq 0 ] && commits="$tasks"

  wall="-"; rate="-"; secs=0
  if [ "$start" != "-" ] && [ "$end" != "-" ] && [ "$end" -ge "$start" ]; then
    secs=$((end - start)); wall="$(fmt_dur "$secs")"
    rate="$(awk -v t="$tasks" -v s="$secs" 'BEGIN { if (s > 0 && t > 0) printf "%.1f", t / (s / 3600); else print "-" }')"
  else
    src_wall="-"
  fi
  pcell="$pauses"; [ "$prole" != "-" ] && pcell="$pauses ($(join_commas "$prole"))"

  line="| $N | $mode | $streams | $wall | $tasks | $commits | $merges | $conflicts | $pcell | $rate |"
  TABLE="$TABLE
$line"

  note="FASE-$N:"
  [ "$snames" != "-" ] && note="$note streams $(join_commas "$snames") ·"
  if [ "$wall" != "-" ]; then note="$note wall $(fmt_iso "$start") → $(fmt_iso "$end") ($src_wall) ·"
  elif [ "$start" != "-" ]; then note="$note started $(fmt_iso "$start"), not verified yet ·"
  else note="$note no wall time (no task-start event, no Task: trailer) ·"; fi
  [ "$cfiles" != "-" ] && note="$note conflicts: $(join_commas "$cfiles") ·"
  note="$note events: $src_events"
  NOTES="$NOTES
$note"

  if [ "$SAVE" = true ]; then
    mkdir -p "$OUT_DIR"
    out="$OUT_DIR/BENCH-FASE-$N.md"
    {
      echo "# BENCH FASE-$N"
      echo
      echo "> Generated by scripts/sdd-bench.sh on $NOW. Root: $ROOT. Events: $([ "$src_events" = yes ] && echo "$EVENTS" || echo none). Git: $HAS_GIT."
      echo
      echo "$HEADER"
      echo "$SEP"
      echo "$line"
      echo
      echo "- Mode: $mode ($([ "$mode" = worktrees ] && echo 'Stream events or merge commits found' || echo 'no Stream events, no merges'))"
      echo "- Streams: $([ "$snames" = - ] && echo none || join_commas "$snames")"
      if [ "$wall" != "-" ]; then echo "- Wall: $(fmt_iso "$start") → $(fmt_iso "$end") = $wall (source: $src_wall)"; else echo "- Wall: not available"; fi
      echo "- Tasks: $tasks · commits: $commits · merges: $merges"
      echo "- Conflicts: $conflicts$([ "$cfiles" != - ] && echo " — $(join_commas "$cfiles")")"
      echo "- PAUSE: $pcell"
      echo "- tasks/h: $rate"
    } > "$out"
    SAVED="$SAVED
saved: $out"
  fi
done

printf '%s\n' "$TABLE"
printf '%s\n' "$NOTES" | sed '/^$/d'
[ -z "$SAVED" ] || printf '%s\n' "$SAVED" | sed '/^$/d'
