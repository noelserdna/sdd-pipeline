#!/usr/bin/env bash
# B3 — smoke del pipeline sobre examples/todo-app con el plugin cargado por --plugin-dir (usa el modelo: cuesta tokens y minutos).
# Uso: tests/e2e/20-smoke.sh [--until <stage>] [--from <stage>] [--dir <proyecto>] [--keep]
#   stages en orden: setup | specs | audit | test | plan | tasks | impl
#   --until  última etapa a ejecutar (por defecto impl = FASE-0)
#   --from   primera etapa a ejecutar (por defecto setup); útil con --dir para continuar un proyecto ya generado
#   --dir    reutiliza un proyecto existente en vez de copiar examples/todo-app a un temporal (implica --keep)
# Requiere sesión de Claude Code autenticada (usa el CLAUDE_CONFIG_DIR del usuario; el plugin NO se instala, solo --plugin-dir).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UNTIL="impl"; FROM="setup"; DIR=""; KEEP=""
while [ $# -gt 0 ]; do case "$1" in
  --until) UNTIL="$2"; shift 2;; --from) FROM="$2"; shift 2;; --dir) DIR="$2"; KEEP=1; shift 2;; --keep) KEEP=1; shift;; *) shift;; esac; done
command -v claude >/dev/null || { echo "claude CLI no disponible"; exit 2; }

STAGES=(setup specs audit test plan tasks impl)
idx() { local i=0; for s in "${STAGES[@]}"; do [ "$s" = "$1" ] && { echo "$i"; return; }; i=$((i+1)); done; echo 99; }
FROM_I=$(idx "$FROM"); UNTIL_I=$(idx "$UNTIL")
active() { local i; i=$(idx "$1"); [ "$i" -ge "$FROM_I" ] && [ "$i" -le "$UNTIL_I" ]; }
finished_before() { [ "$(idx "$1")" -gt "$UNTIL_I" ]; }

if [ -n "$DIR" ]; then
  WORK="$DIR"; cd "$WORK"
else
  WORK="$(mktemp -d)/todo-app"
  cp -R "$ROOT/examples/todo-app" "$WORK" && cd "$WORK"
  git init -q -b main . && git config user.email e2e@example.com && git config user.name e2e && git add -A && git commit -qm "chore: toy project"
  [ -n "$KEEP" ] || trap 'rm -rf "$(dirname "$WORK")"' EXIT
fi
echo "proyecto: $WORK (from=$FROM until=$UNTIL)"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
t0=$(date +%s); lap() { local now; now=$(date +%s); echo "     [$1: $(( (now - t0) / 60 )) min]"; t0=$now; }
run() { echo; echo "== $1"; claude --plugin-dir "$ROOT" -p "$2" --output-format text 2>&1 | tail -15; lap "$1"; }
ignored() { local p; for p in "$@"; do git check-ignore -q --no-index "$p" || return 1; done; }
stop_if_done() { finished_before "$1" && { echo; echo "B3 (hasta $UNTIL): $([ $fail -eq 0 ] && echo todo ok || echo hay fallos)"; exit $fail; }; true; }

if active setup; then
  run setup "/sdd-setup — run non-interactively: accept all defaults, no status line, no multisession."
  jq -e '.stages["requirements-engineer"]' pipeline-state.json >/dev/null && ok "pipeline-state.json creado" || bad "pipeline-state.json"
  jq -e '.hooksVersion == 3' pipeline-state.json >/dev/null && ok "hooksVersion 3" || bad "hooksVersion"
  [ -x "$(git rev-parse --git-path hooks)/commit-msg" ] && ok "commit-msg instalado" || bad "commit-msg"
  ignored pipeline-state.json .sdd/x .claude/worktrees/x && ok ".gitignore policy" || bad ".gitignore policy"
  git commit -q --allow-empty -m "feat: sin trailer" 2>/dev/null && bad "commit-msg no rechaza feat sin trailer" || ok "commit-msg rechaza feat sin trailer"
  # requisitos ya escritos y aprobados: marcar la etapa como done sin ejecutar la skill
  tmp=$(mktemp); jq '.stages["requirements-engineer"].status="done" | .stages["requirements-engineer"].lastRun=(now|todate) | .currentStage="specifications-engineer"' pipeline-state.json > "$tmp" && mv "$tmp" pipeline-state.json
fi
stop_if_done specs
if active specs; then
  run specs "/sdd-specifications-engineer — requirements/REQUIREMENTS.md is approved. Generate spec/ completely without asking questions; take the recommended option for any clarification and record it in spec/CLARIFICATIONS.md."
  [ -d spec/use-cases ] && ok "spec/use-cases" || bad "spec/use-cases"
fi
stop_if_done audit
if active audit; then
  run audit "/sdd-spec-auditor --fanout — audit spec/ and apply Mode Fix for P0/P1 without asking; write audits/AUDIT-BASELINE.md. Launching the four dimension auditors is requested explicitly: they are part of this skill's contract."
  [ -f audits/AUDIT-BASELINE.md ] && ok "AUDIT-BASELINE.md" || bad "AUDIT-BASELINE.md"
  grep -qiE 'gate.*(PASS|CONDITIONAL)' audits/AUDIT-BASELINE.md && ok "gate PASS/CONDITIONAL" || echo "WARN gate no PASS (revisar)"
  amode=$(jq -r '.stages["spec-auditor"].summary.metrics.mode // "?"' pipeline-state.json 2>/dev/null)
  nsub=$(grep -c '"event":"subagent-start"' .sdd/activity.jsonl 2>/dev/null || echo 0)
  if [ "$amode" = fanout ] || [ "${nsub:-0}" -gt 0 ]; then ok "auditoría en fan-out (mode=$amode, $nsub subagentes)"; else echo "WARN auditoría secuencial (mode=$amode): el fan-out no se activó; ver docs/medidas.md"; fi
fi
stop_if_done test
if active test; then
  run test "/sdd-test-planner — generate test/ from spec/ without asking questions."
  [ -f test/TEST-PLAN.md ] && ok "TEST-PLAN.md" || bad "TEST-PLAN.md"
  nsub2=$(grep -c '"event":"subagent-start"' .sdd/activity.jsonl 2>/dev/null || echo 0)
  [ "${nsub2:-0}" -gt "${nsub:-0}" ] && ok "matrices en subagentes ($((nsub2 - ${nsub:-0})) lanzados)" || echo "WARN matrices sin fan-out"
fi
stop_if_done plan
if active plan; then
  run plan "/sdd-plan-architect --skip-clarify — generate plan/ with FASE-0 (foundation) and FASE-1 split so that src/api and src/cli can be implemented independently."
  [ -f plan/ARCHITECTURE.md ] && ok "ARCHITECTURE.md" || bad "ARCHITECTURE.md"
  ls plan/fases/FASE-*.md >/dev/null 2>&1 && ok "plan/fases" || bad "plan/fases"
  pc=$(jq -r '.stages["plan-architect"].summary.metrics.plan_chars // 0' pipeline-state.json 2>/dev/null)
  pb=$(jq -r '.stages["plan-architect"].summary.metrics.plan_budget_chars // 0' pipeline-state.json 2>/dev/null)
  if [ "${pb:-0}" -gt 0 ] && [ "${pc:-0}" -gt 0 ]; then
    # tolerancia del 15 %: el techo es orientativo y depende del tamaño real de cada FASE
    lim=$(( pb * 115 / 100 ))
    [ "$pc" -le "$lim" ] && ok "plan/ dentro del presupuesto ($pc ≤ $pb +15%)" || echo "WARN plan/ sobre presupuesto ($pc > $lim)"
  fi
fi
stop_if_done tasks
if active tasks; then
  run tasks "/sdd-task-generator — generate task/ for all FASEs without asking questions."
  [ -f task/TASK-ORDER.md ] && ok "TASK-ORDER.md" || bad "TASK-ORDER.md"
  grep -q "## Stream Ownership" task/TASK-FASE-1.md 2>/dev/null && ok "Stream Ownership en TASK-FASE-1" || echo "WARN sin tabla Stream Ownership"
  grep -q "Streams:" task/TASK-ORDER.md && ok "Streams: en TASK-ORDER" || echo "WARN sin línea Streams:"
fi
stop_if_done impl
if active impl; then
  run impl "/sdd-task-implementer --fase=0 — implement FASE-0 completely, test-first, one commit per task with Refs:/Task: trailers, without asking questions (take recommended options)."
  st=$(jq -r '.stages["task-implementer"].status' pipeline-state.json); done0=$(jq -r '.stages["task-implementer"].summary.metrics.tasks_completed // 0' pipeline-state.json)
  if [ "$st" = "done" ] || { [ "$st" = "running" ] && [ "$done0" -gt 0 ]; }; then ok "task-implementer $st (FASE-0: $done0 tasks; running = quedan FASEs)"; else bad "task-implementer status=$st tasks_completed=$done0"; fi
  [ "$(grep -c '^- \[x\] TASK-' task/TASK-FASE-0.md)" = "$(grep -c '^- \[[ x]\] TASK-' task/TASK-FASE-0.md)" ] && ok "todas las tasks de FASE-0 marcadas" || bad "tasks de FASE-0 sin marcar"
  n=$(git log --format=%B | grep -cE '^(Refs|Task):' || true); [ "$n" -ge 2 ] && ok "trailers Refs:/Task: ($n)" || bad "trailers"
  git tag -l 'fase-0-verified' | grep -q . && ok "tag fase-0-verified" || echo "WARN sin tag fase-0-verified"
fi
echo; echo "B3: $([ $fail -eq 0 ] && echo todo ok || echo hay fallos)"; exit $fail
