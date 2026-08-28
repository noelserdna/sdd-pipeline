#!/bin/bash
# H11: SDD runs line
# Hook type: UserPromptSubmit — síncrono (el mensaje debe llegar con el turno) | Timeout: 5s
# Cuando el usuario escribe algo, recuerda en UNA línea por run vivo qué está haciendo el pipeline en
# OTROS procesos/proyectos (el índice global que escribe hooks/sdd-activity-log.sh):
#
#   SDD ▸ todo-app 5/7 · task-generator 12m · 3 agentes · último evento 40s
#
# Sale por `systemMessage` (lo ve el humano, NO entra en el contexto del modelo). Silencio absoluto si
# no hay índice, si no hay runs recientes (SDD_RUNS_LINE_MAX_AGE, 3600 s) o si falta jq y node.
# Nunca falla: exit 0 siempre. No lee ni escribe nada del proyecto.
set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
[ -f "$SDD_LIB" ] || exit 0
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

cat >/dev/null 2>&1 || true   # consumir el stdin del hook

RUNS=$(sdd_runs_file)
[ -f "$RUNS" ] || exit 0
sdd_has_jq || sdd_has_node || exit 0

NOW=$(date -u +%s)
MAXAGE="${SDD_RUNS_LINE_MAX_AGE:-3600}"

# root, project, skill (sin `sdd-`), segundos de skill, agentes, antigüedad del último evento, estado
JQ_LIST='
def obj: if type == "object" then . else {} end;
def nz: if . == null or . == "" then "-" else tostring end;
def ep: (tostring | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | (try fromdateiso8601 catch null));
($now | tonumber) as $nowe
| (.runs | obj) as $runs
| [ $runs[] | obj | select((.root // "") != "") ] | sort_by(.last_seen // "") | reverse | .[]
| ((.last_seen // "") | if . == "" then -1 else (ep as $s | if $s == null then -1 else ($nowe - $s) end) end) as $age
| select($age >= 0 and $age <= ($maxage | tonumber))
| ((.skill // "") | tostring | sub("^[A-Za-z0-9_-]+:"; "")) as $skill
| [ .root, (.project // (.root | split("/") | last)),
    (if ($skill | startswith("sdd-")) then ($skill | sub("^sdd-"; "")) else "" end),
    ((.started_at // "") | if . == "" then -1 else (ep as $s | if $s == null then -1 else ($nowe - $s) end) end),
    (.agents // 0), $age, (.state // "") ] | map(nz) | @tsv'

list_runs() {
  if sdd_has_jq; then
    jq -r --arg now "$NOW" --arg maxage "$MAXAGE" "$JQ_LIST" "$RUNS" 2>/dev/null || true
    return 0
  fi
  SDD_RUNS_FILE="$RUNS" SDD_NOW="$NOW" SDD_MAXAGE="$MAXAGE" node -e '
    const fs = require("fs"), E = process.env;
    const obj = (v) => (v && typeof v === "object" && !Array.isArray(v)) ? v : {};
    let idx = {}; try { idx = JSON.parse(fs.readFileSync(E.SDD_RUNS_FILE, "utf8")); } catch (e) { process.exit(0); }
    const runs = obj(obj(idx).runs), now = Number(E.SDD_NOW), maxage = Number(E.SDD_MAXAGE);
    const nz = (v) => (v === null || v === undefined || v === "") ? "-" : String(v);
    const age = (v) => { if (!v) return -1; const t = Date.parse(String(v)); return Number.isFinite(t) ? now - Math.floor(t / 1000) : -1; };
    const all = Object.keys(runs).map((k) => obj(runs[k])).filter((r) => r.root);
    all.sort((a, b) => String(b.last_seen || "").localeCompare(String(a.last_seen || "")));
    const out = [];
    for (const r of all) {
      const a = age(r.last_seen);
      if (a < 0 || a > maxage) continue;
      let skill = String(r.skill || "").replace(/^[A-Za-z0-9_-]+:/, "");
      skill = skill.startsWith("sdd-") ? skill.slice(4) : "";
      out.push([r.root, r.project || r.root.split("/").pop(), skill, age(r.started_at), r.agents || 0, a, r.state || ""].map(nz).join("\t"));
    }
    if (out.length) process.stdout.write(out.join("\n") + "\n");
  ' 2>/dev/null || true
}

fmt_min() { # segundos → "12m" | "1h 05m" | "40s"
  local s="$1"
  case "$s" in ''|*[!0-9]*) return 0 ;; esac
  if [ "$s" -ge 3600 ]; then printf '%dh %02dm' $((s / 3600)) $(((s % 3600) / 60))
  elif [ "$s" -ge 60 ]; then printf '%dm' $((s / 60))
  else printf '%ds' "$s"; fi
}

MSG=""
ROWS=$(list_runs) || ROWS=""
[ -n "$ROWS" ] || exit 0
while IFS=$'\t' read -r root project skill elapsed agents age state; do
  [ -n "${root:-}" ] || continue
  [ "$project" = "-" ] && project="$(basename "$root")"
  [ "$skill" = "-" ] && skill=""
  [ "$agents" = "-" ] && agents=0
  [ "$state" = "-" ] && state=""
  line="SDD ▸ $project"
  counts=$(sdd_stage_counts "$root/pipeline-state.json") || counts=""
  if [ -n "$counts" ]; then
    done_n=${counts%%$'\t'*}; total_n=${counts#*$'\t'}
    [ -n "$total_n" ] && [ "$total_n" != 0 ] && line="$line $done_n/$total_n"
  fi
  if [ -n "$skill" ]; then
    line="$line · $skill"
    case "$elapsed" in ''|-|-1|*[!0-9]*) ;; *) line="$line $(fmt_min "$elapsed")" ;; esac
  fi
  case "$agents" in ''|*[!0-9]*) agents=0 ;; esac
  if [ "$agents" -gt 0 ]; then
    if [ "$agents" = 1 ]; then line="$line · 1 agente"; else line="$line · $agents agentes"; fi
  fi
  case "$age" in ''|-|-1|*[!0-9]*) ;; *) line="$line · último evento $(fmt_min "$age")" ;; esac
  [ "$state" = "done" ] && line="$line · terminado"
  MSG="${MSG}${MSG:+$'\n'}$line"
done <<< "$ROWS"

[ -n "$MSG" ] || exit 0
printf '{"systemMessage":%s}\n' "$(sdd_json_string "$MSG")"
exit 0
