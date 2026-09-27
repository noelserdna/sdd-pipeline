#!/bin/bash
# sdd-state.sh — lee o cambia el status de una etapa en pipeline-state.json bajo el mismo lock que
# los hooks (hooks/lib/sdd-common.sh: sdd_lock). Para skills: evita read-modify-write a mano que
# pisen las escrituras asíncronas de H3/H10.
#
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/sdd-state.sh" set <stage> <pending|running|done|stale|error|skipped> [--reason TEXT]
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/sdd-state.sh" get <stage>
#   bash "${CLAUDE_PLUGIN_ROOT}/scripts/sdd-state.sh" path
#
# El fichero es <STATE_ROOT>/pipeline-state.json (raíz del .git común del cwd; SDD_STATE_ROOT solo
# dentro del mismo repositorio); `path` lo imprime (`sdd route --write` escribe ahí, bajo el mismo lock).
# `set` crea la clave de la etapa si falta, conserva `summary` y el resto de campos, pone lastRun
# (running/done) y currentStage (running), y limpia staleReason salvo en stale. `skipped` es una etapa que
# la ruta adaptativa deja fuera: --reason se guarda como skipReason (cualquier otro status borra
# skipReason). No crea pipeline-state.json (lo crea /sdd-setup): sin él sale con 1.
set -euo pipefail

LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/lib/sdd-common.sh"
[ -f "$LIB" ] || { echo "sdd-state: falta $LIB" >&2; exit 2; }
# shellcheck source=../hooks/lib/sdd-common.sh
. "$LIB"

usage() { echo "uso: sdd-state.sh set <stage> <pending|running|done|stale|error|skipped> [--reason TEXT] | get <stage> | path" >&2; exit 2; }
[ $# -ge 1 ] || usage
if [ "$1" = path ]; then
  CLAUDE_PROJECT_DIR="$PWD" sdd_roots ""
  f="$STATE_ROOT/pipeline-state.json"
  printf '%s\n' "$f"
  [ -f "$f" ] || exit 1
  exit 0
fi
[ $# -ge 2 ] || usage
cmd="$1" stage="$2" status="${3:-}" reason=""
if [ $# -ge 4 ]; then
  [ "$4" = --reason ] && [ $# -ge 5 ] || usage
  reason="$5"
fi
case "$stage" in ''|*[!a-z0-9-]*) echo "sdd-state: nombre de etapa inválido: $stage" >&2; exit 2 ;; esac

CLAUDE_PROJECT_DIR="$PWD" sdd_roots ""   # the caller's cwd (a worktree resolves to the main checkout)
f="$STATE_ROOT/pipeline-state.json"
[ -f "$f" ] || { echo "sdd-state: no existe $f (ejecuta /sdd-setup)" >&2; exit 1; }

case "$cmd" in
  get)
    if sdd_has_jq; then
      jq -r --arg s "$stage" '(.stages // {})[$s].status // "absent"' "$f"
    else
      SDD_F="$f" SDD_S="$stage" node -e '
        const j = JSON.parse(require("fs").readFileSync(process.env.SDD_F, "utf8"));
        const g = (j.stages || {})[process.env.SDD_S];
        console.log((g && g.status) || "absent");'
    fi
    exit 0 ;;
  set) ;;
  *) usage ;;
esac
case "$status" in pending|running|done|stale|error|skipped) ;; *) usage ;; esac
[ -z "$reason" ] || [ "$status" = skipped ] || { echo "sdd-state: --reason solo vale con skipped" >&2; exit 2; }

sdd_lock "$f" || { echo "sdd-state: no se pudo obtener el lock de $f" >&2; exit 1; }
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
tmp="$f.tmp.$$"
rc=0
if sdd_has_jq; then
  jq --arg s "$stage" --arg st "$status" --arg now "$now" --arg reason "$reason" '
    .stages = ((.stages // {}) | if type == "object" then . else {} end)
    | .stages[$s] = ((.stages[$s] // {outputHash: null, lastRun: null, staleReason: null}) | if type == "object" then . else {} end)
    | .stages[$s].status = $st
    | (if $st == "running" or $st == "done" then .stages[$s].lastRun = $now else . end)
    | (if $st == "stale" then . else .stages[$s].staleReason = null end)
    | (if $st == "running" then .currentStage = $s else . end)
    | (if $st == "skipped" then .stages[$s].skipReason = (if $reason == "" then null else $reason end)
       else del(.stages[$s].skipReason) end)
    | .lastUpdated = $now' "$f" > "$tmp" && mv -f "$tmp" "$f" || { rm -f "$tmp"; rc=1; }
elif sdd_has_node; then
  SDD_F="$f" SDD_S="$stage" SDD_ST="$status" SDD_NOW="$now" SDD_TMP="$tmp" SDD_REASON="$reason" node -e '
    const fs = require("fs"), E = process.env;
    const j = JSON.parse(fs.readFileSync(E.SDD_F, "utf8"));
    if (!j.stages || typeof j.stages !== "object" || Array.isArray(j.stages)) j.stages = {};
    let g = j.stages[E.SDD_S];
    if (!g || typeof g !== "object") g = j.stages[E.SDD_S] = { outputHash: null, lastRun: null, staleReason: null };
    g.status = E.SDD_ST;
    if (E.SDD_ST === "running" || E.SDD_ST === "done") g.lastRun = E.SDD_NOW;
    if (E.SDD_ST !== "stale") g.staleReason = null;
    if (E.SDD_ST === "running") j.currentStage = E.SDD_S;
    if (E.SDD_ST === "skipped") g.skipReason = E.SDD_REASON || null; else delete g.skipReason;
    j.lastUpdated = E.SDD_NOW;
    fs.writeFileSync(E.SDD_TMP, JSON.stringify(j, null, 2) + "\n");
    fs.renameSync(E.SDD_TMP, E.SDD_F);' || { rm -f "$tmp"; rc=1; }
else
  echo "sdd-state: se necesita jq o node" >&2; rc=1
fi
sdd_unlock "$f"
exit "$rc"
