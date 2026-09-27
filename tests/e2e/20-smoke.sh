#!/usr/bin/env bash
# B3 — smoke del pipeline sobre examples/todo-app con el plugin cargado por --plugin-dir (usa el modelo: cuesta tokens y minutos).
# Uso: tests/e2e/20-smoke.sh [--until <stage>] [--from <stage>] [--dir <proyecto>] [--keep] [--route auto|full]
#   stages en orden: setup | route | specs | audit | test | plan | tasks | impl
#   --route  auto (por defecto): la ruta adaptativa decide qué etapas opcionales se ejecutan (`sdd route`, docs/ruta.md);
#            full: pipeline completo (`route --write --full`). Las etapas specs/audit/test saltadas por la ruta no se
#            ejecutan. Factores: Jev si TYPESAFE_API_KEY está definida; si no, tests/fixtures/route/todo-answers.json.
#   --until  última etapa a ejecutar (por defecto impl = FASE-0)
#   --from   primera etapa a ejecutar (por defecto setup); útil con --dir para continuar un proyecto ya generado
#   --dir    reutiliza un proyecto existente en vez de copiar examples/todo-app a un temporal (implica --keep)
# Requiere sesión de Claude Code autenticada (usa el CLAUDE_CONFIG_DIR del usuario; el plugin NO se instala, solo --plugin-dir).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UNTIL="impl"; FROM="setup"; DIR=""; KEEP=""; ROUTE="auto"
while [ $# -gt 0 ]; do case "$1" in
  --until) UNTIL="$2"; shift 2;; --from) FROM="$2"; shift 2;; --dir) DIR="$2"; KEEP=1; shift 2;; --keep) KEEP=1; shift;;
  --route) ROUTE="$2"; shift 2;; *) shift;; esac; done
case "$ROUTE" in auto|full) ;; *) echo "--route debe ser auto o full"; exit 2;; esac
command -v claude >/dev/null || { echo "claude CLI no disponible"; exit 2; }

STAGES=(setup route specs audit test plan tasks impl)
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
echo "proyecto: $WORK (from=$FROM until=$UNTIL route=$ROUTE)"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
t0=$(date +%s); lap() { local now; now=$(date +%s); echo "     [$1: $(( (now - t0) / 60 )) min]"; t0=$now; }
# Las sesiones hijas cargan SOLO el plugin de este checkout: si hay una versión instalada, se desactiva para ellas
# (dos versiones a la vez mezclarían skills y hooks). SDD_E2E_LOG_DIR guarda la salida completa de cada etapa.
CHILD_SETTINGS=${SDD_E2E_SETTINGS:-'{"enabledPlugins":{"sdd-pipeline@noelserdna":false}}'}
LOG_DIR=${SDD_E2E_LOG_DIR:-}
run() {
  echo; echo "== $1"
  if [ -n "$LOG_DIR" ]; then mkdir -p "$LOG_DIR"
    claude --plugin-dir "$ROOT" --settings "$CHILD_SETTINGS" -p "$2" --output-format text > "$LOG_DIR/$1.log" 2>&1 || true
    tail -15 "$LOG_DIR/$1.log"
  else claude --plugin-dir "$ROOT" --settings "$CHILD_SETTINGS" -p "$2" --output-format text 2>&1 | tail -15; fi
  lap "$1"; }
# Salidas de etapa versionadas (git-conventions.md § Stage outputs are committed): algo trackeado y nada pendiente
committed() { local d; for d in "$@"; do [ -n "$(git ls-files -- "$d" | head -1)" ] && [ -z "$(git status --porcelain -- "$d")" ] || return 1; done; }
check_committed() { if committed "$@"; then ok "$* commiteado"; else bad "$* sin commitear"; git status --porcelain -- "$@" | head -5; fi; }
ignored() { local p; for p in "$@"; do git check-ignore -q --no-index "$p" || return 1; done; }
# skipped KEY → la ruta confirmada saltó esa etapa (status skipped en pipeline-state.json)
skipped() { jq -e --arg k "$1" '.stages[$k].status == "skipped"' pipeline-state.json >/dev/null 2>&1; }
skip_note() { echo; echo "== $1: saltada por la ruta ($(jq -r --arg k "$2" '.stages[$k].skipReason // "sin motivo"' pipeline-state.json))"
  jq -e --arg k "$2" '(.stages[$k].skipReason // "") | length > 0' pipeline-state.json >/dev/null && ok "$2 skipped con skipReason" || bad "$2 skipped sin skipReason"; }
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
stop_if_done route
if active route; then
  echo; echo "== route ($ROUTE)"
  SDD_CLI="$ROOT/scripts/sdd.mjs"
  answers=()
  if [ -n "${TYPESAFE_API_KEY:-}" ]; then judge=jev; else judge=fixture; answers=(--answers "$ROOT/tests/fixtures/route/todo-answers.json"); fi
  rrc=0; route_json=$(node "$SDD_CLI" route --json ${answers[@]+"${answers[@]}"} 2>&1) || rrc=$?
  if [ "$rrc" -eq 0 ]; then ok "sdd route --json ($judge)"; else bad "sdd route --json ($judge) exit $rrc: $(printf '%s' "$route_json" | head -3 | tr '\n' ' ')"; fi
  if [ "$rrc" -eq 0 ]; then
    printf '%s' "$route_json" | jq -r '.stages | to_entries[] | "     \(.key): \(if .value.run then "run" else "skip" end) — \(.value.reason)"' 2>/dev/null || true
    printf '%s' "$route_json" | jq -r '"     dudas: \((.doubts // []) | join(", ")) · ahorro estimado: \(.saved_minutes_estimate // "?") min"' 2>/dev/null || true
    # con Jev, la segunda llamada reutiliza sus factores como respuestas (misma ruta, sin volver a llamar a Jev)
    if [ "$judge" = jev ]; then
      mkdir -p .sdd; answers_file=".sdd/route-answers.json"; printf '%s' "$route_json" | jq '{factors: (.factors | map_values(.p))}' > "$answers_file"
      answers=(--answers "$answers_file")
    fi
    full=(); [ "$ROUTE" = full ] && full=(--full)
    wrc=0; wout=$(node "$SDD_CLI" route ${answers[@]+"${answers[@]}"} --write --confirm "e2e-proxy (test harness)" ${full[@]+"${full[@]}"} 2>&1) || wrc=$?
    if [ "$wrc" -eq 0 ]; then ok "sdd route --write --confirm"; else bad "sdd route --write exit $wrc: $(printf '%s' "$wout" | head -3 | tr '\n' ' ')"; fi
    jq -e '.route.confirmedBy == "e2e-proxy (test harness)"' pipeline-state.json >/dev/null && ok "route.confirmedBy registrado" || bad "route.confirmedBy"
    if [ "$ROUTE" = full ]; then
      skipped specifications-engineer && bad "--route full y specifications-engineer skipped" || ok "--route full: specs en la ruta"
    elif skipped specifications-engineer; then
      ok "ruta ligera: specs saltadas ($judge)"
      # auditoría y plan de tests dependen de que haya specs (scripts/lib/route-rules.mjs)
      if skipped spec-auditor && skipped test-planner; then ok "auditoría y plan de tests saltados con las specs"; else bad "specs saltadas pero spec-auditor/test-planner no"; fi
    elif [ "$judge" = fixture ]; then bad "ruta con las respuestas del fixture: se esperaba specifications-engineer skipped"
    else echo "WARN Jev puso las specs en la ruta del todo-app (revisar factores)"; fi
  fi
  lap route
fi
stop_if_done specs
if active specs && skipped specifications-engineer; then skip_note specs specifications-engineer
elif active specs; then
  run specs "/sdd-specifications-engineer --fanout — launching the requirement lanes is requested explicitly. requirements/REQUIREMENTS.md is approved. Generate spec/ completely without asking questions; take the recommended option for any clarification and record it in spec/CLARIFICATIONS.md."
  [ -d spec/use-cases ] && ok "spec/use-cases" || bad "spec/use-cases"
  check_committed spec
fi
stop_if_done audit
if active audit && skipped spec-auditor; then skip_note audit spec-auditor
elif active audit; then
  run audit "/sdd-spec-auditor --fanout — audit spec/ and apply Mode Fix for P0/P1 without asking; write audits/AUDIT-BASELINE.md. Launching the four dimension auditors is requested explicitly: they are part of this skill's contract."
  [ -f audits/AUDIT-BASELINE.md ] && ok "AUDIT-BASELINE.md" || bad "AUDIT-BASELINE.md"
  check_committed audits spec
  grep -qiE 'gate.*(PASS|CONDITIONAL)' audits/AUDIT-BASELINE.md && ok "gate PASS/CONDITIONAL" || echo "WARN gate no PASS (revisar)"
  amode=$(jq -r '.stages["spec-auditor"].summary.metrics.mode // "?"' pipeline-state.json 2>/dev/null)
  # prueba de fan-out: summary.metrics.mode que persiste la skill
  if [ "$amode" = fanout ]; then ok "auditoría en fan-out (mode=$amode)"; else echo "WARN auditoría secuencial (mode=$amode): el fan-out no se activó; ver docs/medidas.md"; fi
fi
stop_if_done test
if active test && skipped test-planner; then skip_note test test-planner
elif active test; then
  run test "/sdd-test-planner --fanout — launching the matrix and E2E subagents is requested explicitly. generate test/ from spec/ without asking questions."
  [ -f test/TEST-PLAN.md ] && ok "TEST-PLAN.md" || bad "TEST-PLAN.md"
  check_committed test
  tmode=$(jq -r '.stages["test-planner"].summary.metrics.mode // "?"' pipeline-state.json 2>/dev/null)
  tagents=$(jq -r '.stages["test-planner"].summary.metrics.matrix_agents // 0' pipeline-state.json 2>/dev/null)
  if [ "$tmode" = fanout ] && [ "${tagents:-0}" -gt 0 ]; then ok "matrices en subagentes ($tagents lanzados)"; else echo "WARN matrices sin fan-out (mode=$tmode, matrix_agents=$tagents)"; fi
fi
stop_if_done plan
if active plan; then
  plan_extra=""
  skipped specifications-engineer && plan_extra=" The route skipped the specifications: plan from requirements/ (Requirements-only mode), Escenarios cite REQ-X-NNN ACn."
  run plan "/sdd-plan-architect --skip-clarify — generate plan/ without asking questions; take the recommended option for every decision.$plan_extra"
  [ -f plan/ARCHITECTURE.md ] && ok "ARCHITECTURE.md" || bad "ARCHITECTURE.md"
  ls plan/fases/FASE-*.md >/dev/null 2>&1 && ok "plan/fases" || bad "plan/fases"
  check_committed plan
  # FASEs verticales (phase-assignment-rules.md): marca, esqueleto y lint mecánico V8/V9
  grep -qiE 'Plan-Style:?\**:? *vertical' plan/PLAN.md && ok "PLAN.md con Plan-Style: vertical" || bad "PLAN.md sin Plan-Style: vertical"
  if compgen -G 'plan/fases/FASE-0-[Ss][Kk][Ee][Ll][Ee][Tt][Oo][Nn]*.md' >/dev/null; then ok "FASE-0 es el esqueleto"; else echo "WARN FASE-0 no se llama *-SKELETON"; fi
  if skipped specifications-engineer; then
    # plan desde los requisitos: sin spec/, los escenarios son criterios `REQ-X-NNN ACn` (el lint comprueba que existen)
    [ ! -d spec ] && ok "sin spec/ (specs saltadas)" || bad "spec/ creado aunque la ruta saltó las specs"
    grep -qE 'Escenarios:.*REQ-[A-Z]+-[0-9]+ AC[0-9]+' plan/fases/FASE-0-*.md 2>/dev/null && ok "FASE-0 Escenarios con REQ ACn" || bad "FASE-0 Escenarios sin REQ ACn"
    grep -qE 'N/A' plan/PLAN.md && ok "Validation Report con V2-V4/V7 N/A" || echo "WARN PLAN.md no marca V2-V4/V7 como N/A"
  fi
  if lint_out=$(node "$ROOT/scripts/sdd.mjs" lint --plan 2>&1); then ok "sdd lint --plan limpio ($(printf '%s\n' "$lint_out" | tail -1))"; else bad "sdd lint --plan: $(printf '%s\n' "$lint_out" | grep -v '^note' | head -5 | tr '\n' ' ')"; fi
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
  run tasks "/sdd-task-generator --fanout — launching one subagent per FASE is requested explicitly. generate task/ for all FASEs without asking questions."
  [ -f task/TASK-ORDER.md ] && ok "TASK-ORDER.md" || bad "TASK-ORDER.md"
  check_committed task
  grep -q "## Stream Ownership" task/TASK-FASE-0.md 2>/dev/null && ok "Stream Ownership en TASK-FASE-0" || echo "WARN sin tabla Stream Ownership"
  grep -q "Streams:" task/TASK-ORDER.md && ok "Streams: en TASK-ORDER" || echo "WARN sin línea Streams:"
  gmode=$(jq -r '.stages["task-generator"].summary.metrics.mode // "?"' pipeline-state.json 2>/dev/null)
  gagents=$(jq -r '.stages["task-generator"].summary.metrics.task_agents // 0' pipeline-state.json 2>/dev/null)
  if [ "$gmode" = fanout ] && [ "${gagents:-0}" -gt 0 ]; then ok "tasks en fan-out ($gagents agentes de FASE)"; else echo "WARN tasks sin fan-out (mode=$gmode, task_agents=$gagents)"; fi
  if lint_out=$(node "$ROOT/scripts/sdd-task-lint.mjs" lint --dir task 2>&1); then ok "sdd-task-lint lint (V-19 gramática, V-09, V-05/V-06, V-16)"; else bad "sdd-task-lint lint"; printf '%s\n' "$lint_out" | tail -12; fi
fi
stop_if_done impl
if active impl; then
  run impl "/sdd-task-implementer --fase=0 --parallel — giving the [P] tasks to parallel agents is requested explicitly. implement FASE-0 completely, test-first, one commit per task with Refs:/Task: trailers, without asking questions (take recommended options)."
  st=$(jq -r '.stages["task-implementer"].status' pipeline-state.json); done0=$(jq -r '.stages["task-implementer"].summary.metrics.tasks_completed // 0' pipeline-state.json)
  if [ "$st" = "done" ] || { [ "$st" = "running" ] && [ "$done0" -gt 0 ]; }; then ok "task-implementer $st (FASE-0: $done0 tasks; running = quedan FASEs)"; else bad "task-implementer status=$st tasks_completed=$done0"; fi
  # done = trailer Task: alcanzable desde HEAD y no revertido (vale para task_state checkbox y trailers)
  if st_out=$(node "$ROOT/scripts/sdd-task-lint.mjs" status --fase 0 --require-done 2>&1); then ok "todas las tasks de FASE-0 hechas (trailers Task:)"; else bad "tasks de FASE-0 sin hacer"; fi
  printf '%s\n' "$st_out" | tail -1
  printf '%s\n' "$st_out" | grep -q ' 0 divergence(s)' || echo "WARN divergencias checkbox/trailer en FASE-0 (ver status)"
  n=$(git log --format=%B | grep -cE '^(Refs|Task):' || true); [ "$n" -ge 2 ] && ok "trailers Refs:/Task: ($n)" || bad "trailers"
  git tag -l 'fase-0-verified' | grep -q . && ok "tag fase-0-verified" || echo "WARN sin tag fase-0-verified"
fi
echo; echo "B3: $([ $fail -eq 0 ] && echo todo ok || echo hay fallos)"; exit $fail
