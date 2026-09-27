#!/bin/bash
# H1: SDD Pipeline Status Injection at Session Start
# Hook type: SessionStart (startup|resume|compact) | Timeout: 10s
# Lee $STATE_ROOT/pipeline-state.json (raíz del .git común, compartida por todos los
# worktrees) e inyecta el contexto del pipeline. Lee dashboard/traceability-graph.json
# (si existe) para la cobertura. Con rol (SDD_ROLE o registro de sesiones) añade
# "Rol: … | Pares vivos: …" y exporta SDD_STATE_ROOT / SDD_PLUGIN_ROOT vía CLAUDE_ENV_FILE.
# Sin pipeline-state.json, sin .sdd/ y sin rol (repositorio que no usa SDD) no emite nada.

set -euo pipefail

SDD_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"
if [ ! -f "$SDD_LIB" ]; then echo "sdd-session-start: falta $SDD_LIB" >&2; exit 0; fi
# shellcheck source=lib/sdd-common.sh
. "$SDD_LIB"

INPUT=$(cat)
sdd_roots "$INPUT"
PIPELINE_STATE="$STATE_ROOT/pipeline-state.json"
GRAPH_FILE="$STATE_ROOT/dashboard/traceability-graph.json"

ROLE=$(sdd_role) || ROLE=""
ROLE_FROM_REGISTRY=0
if [ -n "$ROLE" ] && [ -z "${SDD_ROLE:-}" ]; then ROLE_FROM_REGISTRY=1; fi

# --- CLAUDE_ENV_FILE (solo SessionStart): variables para el resto de la sesión ---
env_quote() { printf '"%s"' "$(printf '%s' "$1" | sed -e 's/[\\"$`]/\\&/g')"; }
write_env_file() {
  local f="${CLAUDE_ENV_FILE:-}"
  [ -n "$f" ] || return 0
  if [ -e "$f" ]; then [ -w "$f" ] || return 0; else [ -w "$(dirname "$f")" ] || return 0; fi
  {
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
      printf 'export SDD_PLUGIN_ROOT=%s\n' "$(env_quote "$CLAUDE_PLUGIN_ROOT")"
    fi
    printf 'export SDD_STATE_ROOT=%s\n' "$(env_quote "$STATE_ROOT")"
    if [ "$ROLE_FROM_REGISTRY" = 1 ]; then
      # Rol deducido del registro de sesiones (~/.claude/sessions/<pid>.json → .name → sdd-sessions.json).
      # Ese registro NO está documentado por Claude Code; la vía oficial es `SDD_ROLE=<rol> claude`.
      printf 'export SDD_ROLE=%s\n' "$(env_quote "$ROLE")"
    fi
  } >> "$f" 2>/dev/null || true
}
# Proyectos sin SDD (ni pipeline-state.json ni .sdd/ ni rol): silencio total, sin variables.
# Los hooks del plugin son globales; no hay que pedir /sdd-setup en cada repositorio.
if [ ! -f "$PIPELINE_STATE" ] && [ ! -d "$STATE_ROOT/.sdd" ] && [ -z "$ROLE" ]; then
  exit 0
fi

# SDD_STATE_ROOT se exporta para las skills (worktrees); si se hereda a otro repositorio,
# sdd_roots la ignora (solo vale dentro del mismo git-common-dir).
write_env_file

# --- Contexto de rol (solo si hay rol) ---
role_context() {
  [ -n "$ROLE" ] || return 0
  local owns stages peers
  owns=$(sdd_role_owns "$ROLE" | tr '\n' ' ') || owns=""
  owns="${owns% }"
  stages=$(sdd_role_stages "$ROLE" | tr '\n' ' ') || stages=""
  stages="${stages% }"
  peers=$(sdd_peers | tr '\n' ',' | sed -e 's/,$//' -e 's/,/, /g') || peers=""
  printf 'Rol: %s (posee: %s; stages: %s) | Pares vivos: %s' "$ROLE" "${owns:--}" "${stages:--}" "${peers:-ninguno}"
}

emit() {
  local context="$1" rc escaped
  rc=$(role_context) || rc=""
  [ -n "$rc" ] && context="$context | $rc"
  context="${context:0:10000}"
  escaped=$(sdd_json_string "$context")
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":$escaped}}"
  exit 0
}

# If no pipeline-state.json, report fresh pipeline
if [ ! -f "$PIPELINE_STATE" ]; then
  emit "SDD Pipeline: No pipeline-state.json found. Fresh pipeline — all stages pending. Run /sdd-setup to initialize automation."
fi

# Progreso sobre las etapas lineales no saltadas (las laterales no cuentan; las `skipped` por la ruta adaptativa
# salen del total y se nombran aparte: "N/M done, K skipped"); listas en orden de pipeline.
build_context() {
  local sum done_n total running stale errors next current skipped msg k
  sum=$(sdd_stage_summary "$PIPELINE_STATE") || sum=""
  [ -n "$sum" ] || return 0
  IFS='|' read -r done_n total running stale errors next current skipped <<< "$sum"
  msg="SDD Pipeline [${current:-unknown}]: ${done_n}/${total} done"
  if [ -n "$skipped" ]; then
    # shellcheck disable=SC2086  # contar palabras de la lista
    set -- $skipped
    k=$#
    msg="$msg, $k skipped (${skipped// /, })"
  fi
  [ -n "$stale" ] && msg="$msg. STALE: ${stale// /, }"
  [ -n "$running" ] && msg="$msg. RUNNING: ${running// /, }"
  [ -n "$errors" ] && msg="$msg. ERROR: ${errors// /, }"
  if [ -n "$next" ]; then msg="$msg. Next: $next"
  elif [ "$done_n" = "$total" ]; then msg="$msg. Next: all complete"
  fi
  printf '%s\n' "$msg"
}

CONTEXT=$(build_context) || CONTEXT=""

[ -z "$CONTEXT" ] && CONTEXT="SDD Pipeline: could not parse pipeline-state.json"

# Try to append traceability coverage stats from graph
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
    SDD_GRAPH_FILE="$GRAPH_FILE" node -e "
      const fs = require('fs');
      try {
        const g = JSON.parse(fs.readFileSync(process.env.SDD_GRAPH_FILE, 'utf8'));
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

# Resumen de aceptación del último `sdd accept` / `sdd gate` / `sdd loop next` (.sdd/acceptance.json, ignorado por git)
ACCEPT_FILE="$STATE_ROOT/.sdd/acceptance.json"
if [ -f "$ACCEPT_FILE" ]; then
  acceptance_with_jq() {
    jq -r '.summary as $s | select($s != null)
      | "| Acceptance: Must " + ($s.must_verified | tostring) + "/" + ($s.must_total | tostring) + " verified"
        + (if ($s.must_waived // 0) > 0 then ", " + ($s.must_waived | tostring) + " waived" else "" end)
        + (if $s.goal then " (goal met)" else " (open: /sdd-acceptance --loop)" end)
        + (if ($s.stale_evidence // 0) > 0 then ", stale evidence " + ($s.stale_evidence | tostring) else "" end)
        + " @" + ((.evaluated_sha // "no-git") | .[0:7])' "$ACCEPT_FILE" 2>/dev/null
  }
  acceptance_with_node() {
    SDD_ACCEPT_FILE="$ACCEPT_FILE" node -e "
      try {
        const l = JSON.parse(require('fs').readFileSync(process.env.SDD_ACCEPT_FILE, 'utf8')); const s = l.summary;
        if (s) console.log('| Acceptance: Must ' + s.must_verified + '/' + s.must_total + ' verified'
          + (s.must_waived ? ', ' + s.must_waived + ' waived' : '') + (s.goal ? ' (goal met)' : ' (open: /sdd-acceptance --loop)')
          + (s.stale_evidence ? ', stale evidence ' + s.stale_evidence : '') + ' @' + String(l.evaluated_sha || 'no-git').slice(0, 7));
      } catch (e) {}
    " 2>/dev/null
  }
  ACCEPTANCE=$(acceptance_with_jq) || ACCEPTANCE=""
  [ -n "$ACCEPTANCE" ] || ACCEPTANCE=$(acceptance_with_node) || ACCEPTANCE=""
  [ -n "$ACCEPTANCE" ] && CONTEXT="$CONTEXT $ACCEPTANCE"
fi

# Handoff del último stage done que lo registre (stages[*].summary.handoff = {to, sentAt, result})
handoff_with_jq() {
  jq -r '
    [ (.stages // {}) | to_entries[] | select(.value.status == "done")
      | ((.value.summary? | objects | .handoff?) // null) as $h | select($h != null)
      | "handoff: " + (($h.to // "?") | tostring) + " " + (($h.result // "?") | tostring) ]
    | last // empty
  ' "$PIPELINE_STATE" 2>/dev/null
}

handoff_with_node() {
  SDD_STATE_FILE="$PIPELINE_STATE" node -e "
    const fs = require('fs');
    try {
      const state = JSON.parse(fs.readFileSync(process.env.SDD_STATE_FILE, 'utf8'));
      const done = Object.values(state.stages || {}).filter((v) => v && v.status === 'done'
        && v.summary && typeof v.summary === 'object' && v.summary.handoff);
      if (done.length) {
        const h = done[done.length - 1].summary.handoff;
        console.log('handoff: ' + (h.to == null ? '?' : h.to) + ' ' + (h.result == null ? '?' : h.result));
      }
    } catch(e) {}
  " 2>/dev/null
}

HANDOFF=$(handoff_with_jq) || HANDOFF=$(handoff_with_node) || HANDOFF=""
[ -n "$HANDOFF" ] && CONTEXT="$CONTEXT | $HANDOFF"

emit "$CONTEXT"
