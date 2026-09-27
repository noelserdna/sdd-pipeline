#!/usr/bin/env bash
# Tests de `sdd lint --plan` (scripts/lib/plan-lint.mjs, sin modelo): planes verticales de tests/fixtures/plan-vertical
# (todo-app y web) que pasan, una mutación por cada fallo (P-HEADER, P-AC, V8, V9, P-SIZE, V-20), plan horizontal
# (legado) y mixto, más los contratos de las skills que leen la marca `Plan-Style: vertical` y la validez de
# scripts/jev/feedback-route.json. Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
FIX="$ROOT/tests/fixtures/plan-vertical"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
run() { rc=0; out=$(node "$SDD" "$@" 2>&1) || rc=$?; }
lines() { printf '%s\n' "$out" | grep -cF -- "$1" || true; }
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if contains "$out" "$2"; then pass "$1"; else bad "$1 (no contiene: $2)"; fi; }
grepf() { if grep -qF -- "$2" "$ROOT/$1"; then pass "$3"; else bad "$3 ($1 no contiene: $2)"; fi; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true

# fresh NAME SRC → copia limpia del fixture en $tmp/NAME (todo: con los requisitos de examples/todo-app)
fresh() {
  rm -rf "${tmp:?}/$1"; mkdir -p "$tmp/$1"; cp -R "$FIX/$2/." "$tmp/$1/"
  if [ "$2" = todo ]; then mkdir -p "$tmp/$1/requirements"; cp "$ROOT/examples/todo-app/requirements/"*.md "$tmp/$1/requirements/"; fi
  P="$tmp/$1"
}
# sub FILE PERL-EXPR → edita en sitio (perl: igual en macOS y Linux)
sub() { perl -0pi -e "$2" "$1"; }

# ---------------------------------------------------------------- 1. sintaxis y ayuda
node --check "$ROOT/scripts/lib/plan-lint.mjs" && pass "node --check plan-lint.mjs" || bad "node --check plan-lint.mjs"
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
run --help; has "--help documenta lint --plan" "sdd lint --plan"

# ---------------------------------------------------------------- 2. planes que pasan
fresh todo todo
run lint --plan --repo "$P"; expect "todo: lint --plan sale 0" "$rc" 0
has "todo: 4 FASEs sin errores ni avisos" "vertical, 4 FASE(s), 0 error(s), 0 warning(s)"
run lint --plan --repo "$P" --json
expect "todo --json: FASE-0 = skeleton add+list+persistencia+cobertura" "$(js 'j.fases[0].requirements.join(",")')" "REQ-F-001,REQ-F-002,REQ-F-006,REQ-NF-002"
expect "todo --json: FASE-0 con 2 UCs, 6 pasos de demo y 5 tareas" "$(js '[j.fases[0].useCases.length,j.fases[0].demoSteps,j.fases[0].tasks].join(" ")')" "2 6 5"
expect "todo --json: FASE-3 HARDENING escenario REQ-NF-001 AC1" "$(js 'j.fases[3].scenarios')" 1
fresh web web
run lint --plan --repo "$P"; expect "web: lint --plan sale 0" "$rc" 0
has "web: 6 FASEs sin errores" "vertical, 6 FASE(s), 0 error(s), 0 warning(s)"
( cd "$P" && node "$SDD" lint --plan --dir plan >/dev/null ) && pass "web: --dir plan relativo al cwd" || bad "web: --dir plan relativo al cwd"

# ---------------------------------------------------------------- 3. plan horizontal (legado), sin plan, mixto
fresh legacy todo; sub "$P/plan/PLAN.md" 's/^> \*\*Plan-Style:\*\* vertical\n//m'
sub "$P/plan/fases/FASE-1-LIFECYCLE.md" 's/^> \*\*Requisitos:.*\n//m'
run lint --plan --repo "$P"; expect "legado: sin marca → sale 0" "$rc" 0; has "legado: nota de plan horizontal" "horizontal (legacy) plan, skipped"
run lint --plan --repo "$ROOT/tests/fixtures/plan-mini"; expect "plan-mini (Streams, sin PLAN.md) → sale 0" "$rc" 0; has "plan-mini: nada que revisar" "nothing to lint"
fresh mixed todo; sub "$P/plan/PLAN.md" 's/Plan-Style:\*\* vertical/Plan-Style:** vertical (from FASE-1)/'
printf '# FASE 0: Bootstrap\n\n> **Estado:** Implementado\n\n## Objetivo\n\nInfraestructura, REQ-F-001, REQ-F-002, REQ-F-006 y REQ-NF-002.\n' > "$P/plan/fases/FASE-0-SKELETON.md"
run lint --plan --repo "$P"; expect "mixto: FASE-0 horizontal no se revisa y sus REQ cuentan para V9" "$rc" 0; has "mixto: nota" "mixed plan: 1 horizontal FASE(s) before FASE-1"

# ---------------------------------------------------------------- 4. fallos (uno por mutación)
F0=plan/fases/FASE-0-SKELETON.md; F1=plan/fases/FASE-1-LIFECYCLE.md
fresh m1 todo; sub "$P/$F1" 's/^> \*\*Requisitos:.*\n//m'
run lint --plan --repo "$P"; expect "sin Requisitos: sale 1" "$rc" 1
has "sin Requisitos: P-HEADER" "P-HEADER header has no \`> **Requisitos:** REQ-…\` line"
has "sin Requisitos: V9 por REQ-F-003 y REQ-F-004" "V9 Must requirement REQ-F-004 is not in any FASE Requisitos line"
fresh m2 todo; sub "$P/$F1" 's/^> \*\*Escenarios:.*\n//m'
run lint --plan --repo "$P"; expect "sin Escenarios: sale 1" "$rc" 1; has "sin Escenarios: P-HEADER" "P-HEADER header has no \`> **Escenarios:** AC-…\` line"
fresh m3 todo; sub "$P/$F1" 's/(Escenarios:\*\* AC-003-01)/$1, AC-003-09/'
run lint --plan --repo "$P"; expect "AC inexistente en Escenarios: sale 1" "$rc" 1; has "AC inexistente: P-AC" "P-AC Escenarios: AC-003-09 is not a scenario of spec/tests/BDD-*.md"
fresh m4 todo; sub "$P/$F1" 's/\| AC-004-02 · N-003 \|/| AC-004-07 · N-003 |/'
run lint --plan --repo "$P"; expect "demo con AC inexistente: sale 1" "$rc" 1; has "demo AC inexistente: P-AC" "P-AC demo step 6: AC-004-07 is not a scenario"
fresh m5 todo; sub "$P/$F1" 's/\| AC-004-02 · N-003 \|/| N-003 |/'
run lint --plan --repo "$P"; expect "demo sin escenario: sale 1" "$rc" 1; has "demo sin escenario: V8" "V8 demo step 6 cites no scenario id"
fresh m6 todo
for i in 7 8 9 10 11; do printf '| %s | `todo list` | igual | AC-004-01 · N-003 |\n' "$i" >> "$P/$F1"; done
run lint --plan --repo "$P"; expect "demo de 11 pasos: sale 1" "$rc" 1; has "demo > 10: V8" "V8 demo has 11 steps (max 10)"
fresh m7 todo; sub "$P/plan/fases/FASE-2-FILTER.md" 's/## Demo.*//s'
run lint --plan --repo "$P"; expect "sin Demo: sale 1" "$rc" 1; has "sin Demo: V8" "V8 no \`## Demo\` section"
fresh m8 todo; sub "$P/plan/fases/FASE-2-FILTER.md" 's/ \(AC-005-01, AC-005-02\)//'
run lint --plan --repo "$P"; expect "criterios sin ids: sale 1" "$rc" 1; has "criterios sin ids: V8" "V8 no success criterion cites a REQ or scenario id"
fresh m9 todo; sub "$P/plan/fases/FASE-2-FILTER.md" 's/## Criterios de Éxito/## Otra cosa/'
run lint --plan --repo "$P"; expect "sin Criterios de Éxito: sale 1" "$rc" 1; has "sin Criterios: V8" "V8 no \`## Criterios de Éxito\` section"
fresh m10 todo; sub "$P/$F0" 's/- \[ \] Una línea por tarea en orden de id; lista vacía → `No tasks` \(AC-002-01, AC-002-02\)/- [ ] Una línea por tarea en orden de id/'
run lint --plan --repo "$P"; expect "un criterio sin ids: aviso, sale 0" "$rc" 0; has "un criterio sin ids: aviso V8" "V8 warning: criterion cites no REQ or scenario id"
fresh m11 todo; sub "$P/$F1" 's/REQ-F-003, REQ-F-004/REQ-F-003/'
run lint --plan --repo "$P"; expect "Must sin FASE: sale 1" "$rc" 1; expect "Must sin FASE: un V9 (REQ-F-004)" "$(lines 'V9 Must requirement')" 1
has "Must sin FASE: REQ-F-004" "V9 Must requirement REQ-F-004"
fresh m12 todo; sub "$P/$F1" 's/REQ-F-003, REQ-F-004/REQ-F-003, REQ-F-004, REQ-F-099/'
run lint --plan --repo "$P"; expect "REQ desconocido: sale 1" "$rc" 1; has "REQ desconocido: P-AC" "P-AC Requisitos: REQ-F-099 is not in requirements/REQUIREMENTS.md"
fresh m13 todo; sub "$P/plan/fases/FASE-3-HARDENING.md" 's/\*\* REQ-NF-001 AC1/** REQ-NF-001 AC5/'
run lint --plan --repo "$P"; expect "REQ ACn inexistente: sale 1" "$rc" 1; has "REQ ACn: P-AC" "P-AC Escenarios: REQ-NF-001 has no acceptance criterion 5"
fresh m14 todo; sub "$P/$F1" 's/(Escenarios:\*\* )/$1AC-001-01, AC-002-01, AC-005-01, /'
run lint --plan --repo "$P"; expect "5 UCs: aviso, sale 0" "$rc" 0; has "5 UCs: aviso P-SIZE" "P-SIZE warning: 5 use cases (UC-001, UC-002, UC-003, UC-004, UC-005)"
fresh m15 todo
{ printf '# Tasks: FASE-1\n\n## Slices\n\n'; for i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16; do printf -- '- [ ] TASK-F1-0%s Task %s AC-003-01 AC-003-02 AC-003-03 AC-004-01 AC-004-02 | `src/f%s.ts`\n' "$i" "$i" "$i"; done; } > "$P/task/TASK-FASE-1.md"
run lint --plan --repo "$P"; expect "16 tareas: aviso, sale 0" "$rc" 0; has "16 tareas: aviso P-SIZE" "task/TASK-FASE-1.md:1 P-SIZE warning: 16 tasks"
fresh m16 todo; sub "$P/task/TASK-FASE-0.md" 's/`AC-002-01`, `AC-002-02`, //'
run lint --plan --repo "$P"; expect "escenario sin tarea: aviso, sale 0" "$rc" 0
has "escenario sin tarea: V-20 AC-002-01" "V-20 warning: scenario AC-002-01 (Escenarios of plan/fases/FASE-0-SKELETON.md) is cited by no task"
fresh m17 todo; rm -rf "$P/requirements"
run lint --plan --repo "$P"; expect "sin REQUIREMENTS.md: sale 0 con nota" "$rc" 0; has "sin REQUIREMENTS.md: nota" "REQ ids and V9 not checked"
fresh m18 web; sub "$P/plan/fases/FASE-0-SKELETON.md" 's/^> \*\*Incremento:.*\n//m; s/^> \*\*Necesidades:.*\n//m'
run lint --plan --repo "$P"; expect "sin Incremento/Necesidades: avisos, sale 0" "$rc" 0; expect "sin Incremento/Necesidades: 2 avisos P-HEADER" "$(lines 'P-HEADER warning')" 2
run lint --plan --repo "$P" --bogus; expect "opción desconocida → 2" "$rc" 2

# ---------------------------------------------------------------- 5. el alcance de sdd gate --fase coincide con Requisitos
fresh gate todo
out=$(cd "$P" && node -e 'import(process.argv[1]).then((m)=>console.log(JSON.stringify(m.faseScope(".",0))))' "$ROOT/scripts/lib/acceptance.mjs" 2>&1)
expect "faseScope(0) lee la línea Requisitos del fixture" "$(js 'j.requirements.join(",")')" "REQ-F-001,REQ-F-002,REQ-F-006,REQ-NF-002"

# ---------------------------------------------------------------- 6. tareas agrupadas por UC siguen siendo Slices (V-19 intacta)
run lint "$FIX/todo/task/TASK-FASE-0.md"; expect "TASK-FASE-0 vertical: sdd lint sale 0" "$rc" 0
run tasks json "$FIX/todo/task/TASK-FASE-0.md"
expect "### UC-NNN no cambia la fase interna (Slices)" "$(js 'j.tasks.filter(t=>t.phase==="Slices").length')" 3

# ---------------------------------------------------------------- 7. contratos entre skills y reglas
grepf skills/sdd-plan-architect/references/plan-templates.md '> **Plan-Style:** vertical' "plan-templates: marca Plan-Style en PLAN.md"
for l in '> **Incremento:**' '> **Requisitos:**' '> **Escenarios:**' '> **Necesidades:**' '## Demo' '| # | Acción | Resultado esperado | Escenario |'; do
  grepf skills/sdd-plan-architect/references/fase-template.md "$l" "fase-template: $l"
done
grepf skills/sdd-plan-architect/SKILL.md "V8: Backed increments" "plan-architect: V8 en Phase 6"
grepf skills/sdd-plan-architect/SKILL.md "V9: Must assigned" "plan-architect: V9 en Phase 6"
grepf skills/sdd-plan-architect/SKILL.md "FASE-0-SKELETON.md" "plan-architect: FASE-0-SKELETON"
grepf skills/sdd-task-generator/SKILL.md "Plan-Style" "task-generator lee la marca"
grepf skills/sdd-task-generator/SKILL.md "### UC-NNN" "task-generator: Slices por caso de uso"
grepf skills/sdd-task-generator/SKILL.md "| V-20 |" "task-generator: V-20"
grepf skills/sdd-task-implementer/SKILL.md "accept --fase {N} --report acceptance/ACCEPTANCE-REPORT.md" "implementer Phase 9: sdd accept --fase"
grepf skills/sdd-task-implementer/SKILL.md "Plan-Style" "implementer lee la marca"
grepf skills/sdd-task-implementer/references/tdd-workflow.md "AC-001-03 rejects an empty title" "tdd-workflow: nombres con AC id"
grepf skills/sdd-test-planner/SKILL.md "## Test Naming (scenario ids)" "test-planner: nomenclatura"
grepf skills/sdd-test-planner/SKILL.md "## 5. Targets by Use Case" "test-planner: objetivos por caso de uso"
grepf skills/sdd-test-planner/references/e2e-template.md 'E2E-WF-001-01 AC-001-01' "e2e-template: título con AC id"
grepf skills/sdd-orchestrator/SKILL.md "references/fase-gate.md" "orquestador: puerta de FASE"
grepf skills/sdd-lead/SKILL.md "skills/sdd-orchestrator/references/fase-gate.md" "lead: puerta de FASE (espejo)"
grepf skills/sdd-orchestrator/SKILL.md "sdd-acceptance --loop" "orquestador: sdd-acceptance --loop"
grepf skills/sdd-orchestrator/SKILL.md "sdd-acceptance --sign-off" "orquestador: sdd-acceptance --sign-off"
grepf skills/sdd-orchestrator/references/fase-gate.md "scripts/jev/feedback-route.json" "fase-gate usa feedback-route.json"
for f in skills/sdd-orchestrator/SKILL.md skills/sdd-lead/SKILL.md; do
  if grep -q "traceability-check\|dashboard" "$ROOT/$f"; then bad "$f aún cita traceability-check o dashboard"; else pass "$f sin traceability-check ni dashboard"; fi
done
[ ! -e "$ROOT/skills/sdd-plan-architect/references/phase-assignment-rules.example.md" ] && pass "phase-assignment-rules.example.md eliminado" || bad "phase-assignment-rules.example.md sigue existiendo"
if grep -rqF "phase-assignment-rules.example" "$ROOT/skills" "$ROOT/docs"; then bad "quedan punteros a phase-assignment-rules.example.md"; else pass "sin punteros al .example"; fi
n=$(wc -l < "$ROOT/skills/sdd-plan-architect/references/phase-assignment-rules.md" | tr -d ' ')
[ "$n" -le 140 ] && pass "phase-assignment-rules.md ≤ 140 líneas ($n)" || bad "phase-assignment-rules.md tiene $n líneas"

# ---------------------------------------------------------------- 8. Jev feedback-route.json
out=$(node -e '
const q = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
const r = q.questions && q.questions.route;
const keys = r && r.criteria ? Object.keys(r.criteria).sort().join(",") : "";
const okCrit = r && Object.values(r.criteria).every((v) => typeof v === "string" && v.length > 40);
console.log(JSON.stringify({ type: r && r.type, keys, okCrit, thr: q.thresholds && q.thresholds.confidence,
  instr: Boolean(r && /feedback/.test(r.instructions)), desc: /human/.test(q.description || "") }));' "$ROOT/scripts/jev/feedback-route.json" 2>&1)
expect "feedback-route: Choice" "$(js 'j.type')" "choice"
expect "feedback-route: opciones defect / change_request / question" "$(js 'j.keys')" "change_request,defect,question"
expect "feedback-route: cada opción con criterio" "$(js 'j.okCrit')" "true"
expect "feedback-route: umbral 0.7" "$(js 'j.thr')" "0.7"
expect "feedback-route: instrucciones sobre el feedback y confirmación humana" "$(js 'j.instr && j.desc')" "true"

echo
if [ "$fail" -eq 0 ]; then echo "plan: todo ok"; else echo "plan: hay fallos"; exit 1; fi
