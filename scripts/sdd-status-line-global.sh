#!/usr/bin/env bash
# sdd-status-line-global.sh — status line GLOBAL, de USUARIO (settings.json del usuario), no de proyecto.
#
# La barra del plugin (scripts/sdd-status-line.sh) resuelve el estado desde el cwd de la sesión que la
# ejecuta: si el pipeline corre en OTROS procesos (`claude -p`) sobre OTRO proyecto, no muestra nada.
# Esta lee el índice global que escribe hooks/sdd-activity-log.sh y pinta UNA línea:
#
#   SDD ▸ todo-app  5/7 done · task-generator 12m 30s · 3 agentes
#   SDD ▸ todo-app  5/7 done · task-generator 21m 04s · 3 agentes · sin latido (>90s)
#   SDD ▸ todo-app  7/7 done · terminado
#
# Objetivo (a qué run mira), en orden:
#   1. <config>/sdd/watch-target  — fichero con UNA ruta: fija el proyecto a mirar (override explícito).
#   2. el cwd de la sesión si su checkout principal tiene pipeline-state.json (comportamiento local).
#   3. la entrada más reciente (last_seen) de <config>/sdd/active-runs.json.
# Sin ninguna de las tres NO imprime nada y sale con 0: la barra del usuario no debe meter ruido en
# proyectos sin SDD.
#
# Reglas: solo skills del pipeline (nombre `sdd-*`, sin el prefijo `plugin:`; se pinta sin el `sdd-`); `· sin latido (>Ns)`
# cuando hay skill en curso y el último evento del run es más viejo que SDD_RUN_STALE_SECS (90 s);
# `· terminado` cuando el estado del run es `done`; el denominador son las etapas REALES de
# pipeline-state.json, no 7 fijo. jq preferido, node como alternativa; sin ninguno, silencio.
#
# Instalación: scripts/install-global-statusline.sh la copia a <config>/sdd/status-line.sh (ruta
# estable, independiente de la versión del plugin) y añade el bloque statusLine al settings del
# usuario. Este script NO depende de hooks/lib/sdd-common.sh: la copia vive fuera del plugin.
#
# Entrada: el JSON de status line por stdin ({cwd, workspace:{current_dir}, …}). Salida: una línea.
set -uo pipefail

IN=$(cat 2>/dev/null) || IN=""

CFG="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
RUNS="$CFG/sdd/active-runs.json"
TARGET_FILE="$CFG/sdd/watch-target"
STALE="${SDD_RUN_STALE_SECS:-90}"

have() { command -v "$1" >/dev/null 2>&1; }
if have jq; then ENGINE=jq; elif have node; then ENGINE=node; else exit 0; fi

# ── cwd de la sesión ─────────────────────────────────────────────────────────
CWD=""
if [[ "$IN" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then CWD="${BASH_REMATCH[1]}"; fi
if [ -z "$CWD" ] && [[ "$IN" =~ \"current_dir\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then CWD="${BASH_REMATCH[1]}"; fi
[ -n "$CWD" ] && [ -d "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"

# Checkout principal del cwd (raíz del .git común: los worktrees comparten pipeline-state.json).
local_root() {
  local d="$CWD" c
  [ -d "$d" ] || return 0
  if [ -f "$d/pipeline-state.json" ]; then printf '%s\n' "$d"; return 0; fi
  c=$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || c=""
  [ -n "$c" ] || return 0
  c=$(dirname "$c")
  if [ -f "$c/pipeline-state.json" ]; then printf '%s\n' "$c"; fi
  return 0
}

FORCED=""
if [ -f "$TARGET_FILE" ]; then
  IFS= read -r FORCED < "$TARGET_FILE" 2>/dev/null || FORCED=""
  FORCED="${FORCED%$'\r'}"
  case "$FORCED" in "~"/*) FORCED="${HOME:-}${FORCED#\~}" ;; esac
  [ -d "$FORCED" ] || FORCED=""
fi
LOCAL=""
[ -n "$FORCED" ] || LOCAL=$(local_root) || LOCAL=""

# ── Entrada del índice: root, project, skill, elapsed, age, agents, state ────
JQ_PICK='
def obj: if type == "object" then . else {} end;
def ep: (tostring | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | (try fromdateiso8601 catch null));
def nz: if . == null or . == "" then "-" else tostring end;
($now | tonumber) as $nowe
| (.runs | obj) as $runs
| (if $forced != "" then $forced elif $local != "" then $local
   else ([ $runs[] | obj | select((.root // "") != "") ] | sort_by(.last_seen // "") | last | (.root // "")) end) as $root
| if ($root | not) or $root == "" then empty else
    ($runs[$root] | obj) as $e
    | (($e.skill // "") | tostring | sub("^[A-Za-z0-9_-]+:"; "")) as $skill
    | [ $root,
        ($e.project // ($root | split("/") | last)),
        (if ($skill | startswith("sdd-")) then ($skill | sub("^sdd-"; "")) else "" end),
        (if ($e.started_at // "") == "" then -1 else (($e.started_at | ep) as $s | if $s == null then -1 else ($nowe - $s) end) end),
        (if ($e.last_seen // "") == "" then -1 else (($e.last_seen | ep) as $s | if $s == null then -1 else ($nowe - $s) end) end),
        ($e.agents // 0),
        ($e.state // "") ] | map(nz) | @tsv
  end'

pick_run() {
  local now="$1" src="$RUNS"
  [ -f "$src" ] || src=""
  if [ "$ENGINE" = jq ]; then
    if [ -n "$src" ]; then
      jq -r --arg forced "$FORCED" --arg local "$LOCAL" --arg now "$now" "$JQ_PICK" "$src" 2>/dev/null || true
    else
      printf '{}' | jq -r --arg forced "$FORCED" --arg local "$LOCAL" --arg now "$now" "$JQ_PICK" 2>/dev/null || true
    fi
    return 0
  fi
  SDD_RUNS="$src" SDD_FORCED="$FORCED" SDD_LOCAL="$LOCAL" SDD_NOW="$now" node -e '
    const fs = require("fs"), E = process.env;
    const obj = (v) => (v && typeof v === "object" && !Array.isArray(v)) ? v : {};
    let idx = {}; try { if (E.SDD_RUNS) idx = JSON.parse(fs.readFileSync(E.SDD_RUNS, "utf8")); } catch (e) { idx = {}; }
    const runs = obj(obj(idx).runs), now = Number(E.SDD_NOW);
    let root = E.SDD_FORCED || E.SDD_LOCAL || "";
    if (!root) {
      const all = Object.keys(runs).map((k) => obj(runs[k])).filter((r) => r.root);
      all.sort((a, b) => String(a.last_seen || "").localeCompare(String(b.last_seen || "")));
      root = all.length ? all[all.length - 1].root : "";
    }
    if (!root) process.exit(0);
    const e = obj(runs[root]);
    const age = (v) => { if (!v) return -1; const t = Date.parse(String(v)); return Number.isFinite(t) ? now - Math.floor(t / 1000) : -1; };
    let skill = String(e.skill || "").replace(/^[A-Za-z0-9_-]+:/, "");
    skill = skill.startsWith("sdd-") ? skill.slice(4) : "";
    const nz = (v) => (v === null || v === undefined || v === "") ? "-" : String(v);
    process.stdout.write([root, e.project || root.split("/").pop(), skill,
      age(e.started_at), age(e.last_seen), e.agents === undefined ? 0 : e.agents, e.state || ""].map(nz).join("\t") + "\n");
  ' 2>/dev/null || true
}

# ── Etapas hechas / totales de pipeline-state.json (denominador real) ────────
stage_counts() {
  local f="$1"
  [ -f "$f" ] || return 0
  if [ "$ENGINE" = jq ]; then
    jq -r '(.stages // {}) | (if type == "object" then . else {} end) as $s
           | [ ([ $s[] | select(type == "object" and .status == "done") ] | length), ($s | length) ] | @tsv' "$f" 2>/dev/null || true
    return 0
  fi
  SDD_STATE_FILE="$f" node -e '
    const fs = require("fs");
    try {
      const st = JSON.parse(fs.readFileSync(process.env.SDD_STATE_FILE, "utf8"));
      const s = (st && typeof st.stages === "object" && st.stages) || {};
      const keys = Object.keys(s);
      const done = keys.filter((k) => s[k] && typeof s[k] === "object" && s[k].status === "done").length;
      process.stdout.write(done + "\t" + keys.length + "\n");
    } catch (e) {}
  ' 2>/dev/null || true
}

fmt_dur() { # segundos → "1h 05m" | "12m 30s" | "40s"
  local s="$1"
  case "$s" in ''|*[!0-9]*) return 0 ;; esac
  if [ "$s" -ge 3600 ]; then printf '%dh %02dm' $((s / 3600)) $(((s % 3600) / 60))
  elif [ "$s" -ge 60 ]; then printf '%dm %02ds' $((s / 60)) $((s % 60))
  else printf '%ds' "$s"; fi
}

NOW=$(date -u +%s)
ROW=$(pick_run "$NOW") || ROW=""
[ -n "$ROW" ] || exit 0
IFS=$'\t' read -r ROOT PROJECT SKILL ELAPSED AGE AGENTS STATE <<< "$ROW"
# El programa rellena los campos vacíos con "-" (IFS=TAB los colapsaría en `read`).
[ "${PROJECT:-}" = "-" ] && PROJECT=""
[ "${SKILL:-}" = "-" ] && SKILL=""
[ "${ELAPSED:-}" = "-" ] && ELAPSED=""
[ "${AGE:-}" = "-" ] && AGE=""
[ "${AGENTS:-}" = "-" ] && AGENTS=0
[ "${STATE:-}" = "-" ] && STATE=""
[ -n "${ROOT:-}" ] || exit 0

COUNTS=$(stage_counts "$ROOT/pipeline-state.json") || COUNTS=""
DONE=""; TOTAL=""
if [ -n "$COUNTS" ]; then IFS=$'\t' read -r DONE TOTAL <<< "$COUNTS"; fi

# Ni etapas ni run: nada que contar (proyecto sin SDD) → silencio.
if [ -z "$TOTAL" ] || [ "$TOTAL" = 0 ]; then
  [ -n "$SKILL" ] || [ "${STATE:-}" = "running" ] || exit 0
fi

OUT="SDD ▸ ${PROJECT:-$(basename "$ROOT")}"
if [ -n "$TOTAL" ] && [ "$TOTAL" != 0 ]; then OUT="$OUT  $DONE/$TOTAL done"; fi
if [ -n "$SKILL" ]; then
  OUT="$OUT · $SKILL"
  case "${ELAPSED:-}" in ''|-1|*[!0-9]*) ;; *) OUT="$OUT $(fmt_dur "$ELAPSED")" ;; esac
fi
case "${AGENTS:-0}" in
  ''|*[!0-9]*) AGENTS=0 ;;
esac
if [ "$AGENTS" -gt 0 ] || [ -n "$SKILL" ]; then
  if [ "$AGENTS" = 1 ]; then OUT="$OUT · 1 agente"; else OUT="$OUT · $AGENTS agentes"; fi
fi
if [ -n "$SKILL" ]; then
  case "${AGE:-}" in
    ''|-1|*[!0-9]*) ;;
    *) [ "$AGE" -gt "$STALE" ] && OUT="$OUT · sin latido (>${STALE}s)" ;;
  esac
fi
[ "${STATE:-}" = "done" ] && OUT="$OUT · terminado"

printf '%s' "$OUT"
exit 0
