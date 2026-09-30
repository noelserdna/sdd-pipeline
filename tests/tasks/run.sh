#!/usr/bin/env bash
# Tests de scripts/sdd-task-lint.mjs (sin modelo): gramática V-19 y formas legadas (negrita, encabezados), V-09/V-05/V-06/V-16,
# formato compacto, ficheros [RETROACTIVE], índice derivado y estado por trailers Task: en un repo git temporal
# (revert, revert de un revert, commit sin trailer, divergencias de checkbox, task_state del Stack Profile, --rev).
# Fixtures en tests/fixtures/tasks y tests/tasks/fixtures (tarea CONTRACT- y journey en compact); contratos 5.1 de
# sdd-task-generator y sdd-plan-architect (CONTRACT-, journey, cita literal, Source adversarial, Puertos con doble). Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere git y node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LINT="$ROOT/scripts/sdd-task-lint.mjs"
FIX="$ROOT/tests/fixtures/tasks"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
# run ARGS… → salida (stdout+stderr) en $out y código de salida en $rc
run() { rc=0; out=$(node "$LINT" "$@" 2>&1) || rc=$?; }
# lines TEXT → líneas de $out que contienen TEXT (literal)
lines() { printf '%s\n' "$out" | grep -cF -- "$1" || true; }
# js EXPR → evalúa EXPR con j = JSON.parse($out)
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if contains "$out" "$2"; then pass "$1"; else bad "$1 (no contiene: $2)"; fi; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"

# ---------------------------------------------------------------- 1. sintaxis y contrato compartido
if node --check "$LINT" 2>/dev/null; then pass "node --check sdd-task-lint.mjs"; else bad "node --check sdd-task-lint.mjs"; fi
[ -x "$LINT" ] && pass "sdd-task-lint.mjs ejecutable" || bad "sdd-task-lint.mjs sin +x"
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
GRAMMAR='^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$'
for f in scripts/sdd-task-lint.mjs skills/sdd-task-generator/SKILL.md skills/sdd-task-generator/references/task-template.md; do
  if grep -qF -- "$GRAMMAR" "$ROOT/$f"; then pass "gramática V-19 literal en $f"; else bad "gramática V-19 ausente o distinta en $f"; fi
done
run --help; expect "--help sale 0" "$rc" 0; has "--help documenta status" "--require-done"

# ---------------------------------------------------------------- 1b. contratos 5.1 en los ficheros de las skills
grepf() { if grep -qF -- "$2" "$ROOT/$1"; then pass "$3"; else bad "$3 ($1 no contiene: $2)"; fi; }
TG=skills/sdd-task-generator
grepf "$TG/SKILL.md" '**Contract task per port.**' "task-generator Phase 2: tarea CONTRACT- por puerto"
grepf "$TG/SKILL.md" 'CONTRACT-<port> REQ-F-NNN ACn' "task-generator: nombre del test de contrato"
grepf "$TG/SKILL.md" '`[PLAN GAP]` (Handling Plan Gaps): without the row' "task-generator: doble sin fila de puerto → PLAN GAP"
grepf "$TG/SKILL.md" '**Journey task per FASE.**' "task-generator Phase 2: tarea de journey por FASE"
grepf "$TG/SKILL.md" 'evidencias/FASE-{N}/{AC-NNN-NN | REQ-F-NNN-ACn}.png' "task-generator: captura por criterio"
grepf "$TG/SKILL.md" 'Source: ACCEPTANCE-ADVERSARIAL-FASE-{N}' "task-generator Mode 5: Source adversarial"
grepf "$TG/SKILL.md" '| V-21 |' "task-generator: V-21"
grepf "$TG/references/task-template.md" '## Contract task (`CONTRACT-<port>`)' "task-template: plantilla CONTRACT-"
grepf "$TG/references/task-template.md" '## Journey task (one per FASE with REQ-F scenarios)' "task-template: plantilla de journey"
grepf "$TG/references/task-template.md" 'Enters through Demo step 1' "task-template: journey entra por la ruta del usuario (en Acceptance)"
grepf "$TG/references/review-checklist.md" 'opened from requirements/REQUIREMENTS.md' "review-checklist: cita literal sobre el assert"
grepf "$TG/references/review-checklist.md" 'as written in requirements/REQUIREMENTS.md' "review-checklist: criterios desde REQUIREMENTS.md"
grepf "$TG/references/review-checklist.md" 'Every `replay` and `race` row' "review-checklist: filas replay/race"
grepf "$TG/references/review-checklist.md" 'not the visibility of a container' "review-checklist: texto, no contenedor"
grepf "$TG/references/review-checklist.md" "has a caller on the user's route" "review-checklist: caller en la ruta del usuario"
if grep -qF 'from FASE file' "$ROOT/$TG/references/review-checklist.md"; then bad "review-checklist aún dice 'from FASE file'"; else pass "review-checklist sin 'from FASE file'"; fi
grepf skills/sdd-plan-architect/references/plan-templates.md '| Puerto | Interfaz (fichero) | Doble | Provider real | Observable del contrato |' "plan-templates: tabla Puertos con doble"
grepf skills/sdd-plan-architect/SKILL.md '**Puertos con doble**' "plan-architect: regla de puertos"
grepf scripts/lib/plan-lint.mjs 'CONTRACT-' "plan-lint: V-21 busca CONTRACT-"
run bogus; expect "comando desconocido → 2" "$rc" 2

# ---------------------------------------------------------------- 2. lint sobre fixtures
run lint "$FIX/canonical.md"; expect "canonical: lint sale 0" "$rc" 0; has "canonical: 6 tasks sin errores" "6 task(s), 0 error(s), 0 warning(s)"
run lint "$FIX/compact.md"; expect "compact: lint sale 0 (sin Review, Revert ausente = SAFE)" "$rc" 0; has "compact: 4 tasks" "4 task(s), 0 error(s)"
CFIX="$ROOT/tests/tasks/fixtures/contract-compact.md"
run lint "$CFIX"; expect "contract-compact: CONTRACT- y journey en compact pasan sdd lint" "$rc" 0; has "contract-compact: 4 tasks sin avisos" "4 task(s), 0 error(s), 0 warning(s)"
run json "$CFIX"
expect "contract-compact: CONTRACT- en el Stream del provider, Revert SAFE (ausente)" "$(js 'const t=j.tasks[2]; [t.stream,t.revert===null,t.blockedBy.join(",")].join(" ")')" "A true TASK-F4-001,TASK-F4-002"
expect "contract-compact: journey en verificación" "$(js 'j.tasks[3].stream+" "+j.tasks[3].phase')" "verificación Verification"
run lint "$FIX/bold.md"; expect "bold: lint sale 1" "$rc" 1; expect "bold: 3 × V-19 negrita" "$(lines 'V-19 bold task id')" 3
run lint "$FIX/heading.md"; expect "heading: lint sale 1" "$rc" 1; expect "heading: 3 × V-19 encabezado" "$(lines 'V-19 heading task `###')" 3
run lint "$FIX/retroactive.md"; expect "retroactive: lint sale 0" "$rc" 0; has "retroactive: se salta con warning" "V-19 warning: file marked [RETROACTIVE]: skipped"
run lint "$FIX/invalid.md"; expect "invalid: lint sale 1" "$rc" 1
expect "invalid: V-19 sin write-set (2)" "$(lines 'V-19 missing ` | `<path>``')" 2
expect "invalid: V-19 línea indentada" "$(lines 'V-19 task line must start at column 0')" 1
expect "invalid: V-19 campo sin indentar" "$(lines 'field line must be indented two spaces')" 1
expect "invalid: V-19 gramática genérica" "$(lines 'V-19 task line does not match the grammar')" 1
expect "invalid: V-05 sin Commit" "$(lines 'V-05 TASK-F3-002: missing **Commit:**')" 1
expect "invalid: V-06 sin Acceptance (PLAN GAP exento)" "$(lines 'V-06 ')" 1
expect "invalid: V-09 id duplicado" "$(lines 'V-09 duplicate id TASK-F3-002')" 1
expect "invalid: V-09 secuencia de 2 dígitos" "$(lines 'V-09 TASK-F3-04: id must be')" 1
expect "invalid: V-16 task desconocida en la tabla" "$(lines 'V-16 unknown task TASK-F3-099 in Stream A')" 1
expect "invalid: V-16 task en dos Streams" "$(lines 'V-16 TASK-F3-003 listed in Streams A and B')" 1
expect "invalid: V-16 tasks fuera de la tabla" "$(lines 'missing from ## Stream Ownership')" 5
expect "invalid: [PLAN GAP] sin ruta es warning" "$(lines 'V-19 warning: [PLAN GAP] task without write-set path')" 1
run lint --json "$FIX/invalid.md"; expect "lint --json: 16 errores" "$(js 'j.errors.length')" 16

# ---------------------------------------------------------------- 3. json (parser tolerante)
run json "$FIX/canonical.md"
expect "json canonical: 6 tasks (los ids dentro de fences no cuentan)" "$(js 'j.count')" 6
expect "json canonical: [P], 3 rutas y Stream A en TASK-F1-003" "$(js 'const t=j.tasks[2]; [t.id,t.parallel,t.paths.length,t.stream,t.phase].join(" ")')" "TASK-F1-003 true 3 A Slices"
expect "json canonical: Files: suma al write-set" "$(js 'j.tasks[1].paths.includes("db/schema.rb")+" "+j.tasks[1].paths.length')" "true 4"
expect "json canonical: [!] = blocked" "$(js 'j.tasks[3].state+" "+j.tasks[3].blocked')" "! true"
expect "json canonical: blocked-by y revert" "$(js 'j.tasks[4].blockedBy.join(",")+" "+j.tasks[4].revert')" "TASK-F1-003,TASK-F1-004 COUPLED"
run json "$FIX/bold.md"; expect "json bold: 3 tasks parseadas" "$(js 'j.tasks.map(t=>t.shape+":"+t.checked).join(",")')" "bold:true,bold:false,bold:false"
run json "$FIX/heading.md"
expect "json heading: estados desde el encabezado" "$(js 'j.tasks.map(t=>t.checked).join(",")')" "true,false,true"
expect "json heading: rango TASK-F1-001 .. TASK-F1-002 → Stream A" "$(js 'j.tasks[1].stream+" "+j.tasks[2].stream+" "+j.tasks[2].phase')" "A verificación Verification"
run json "$FIX/retroactive.md"; expect "json retroactive: 2 tasks" "$(js 'j.count+" "+j.tasks[0].retroactive')" "2 true"

# ---------------------------------------------------------------- 4. index derivado
run index "$FIX/canonical.md"
has "index: fila de resumen" "| FASE-1 | Task list | 6 | 2 (33%) | 2 |"
has "index: fila plana" "| TASK-F1-003 | 1 | Slices | Create task (API-001-01) with server-side validation, test-first | [P] | [ ] |"
has "index: matriz de trazabilidad" "| API-001-01 | TASK-F1-003 |"

# ---------------------------------------------------------------- 5. --dir, --fase y FASE del nombre de fichero
mkdir -p "$tmp/p/task"
cp "$FIX/canonical.md" "$tmp/p/task/TASK-FASE-1.md"; cp "$FIX/compact.md" "$tmp/p/task/TASK-FASE-2.md"
run lint --repo "$tmp/p"; expect "--repo con task/ por defecto: 0 errores" "$rc" 0; has "--repo: 2 ficheros, 10 tasks" "2 file(s), 10 task(s)"
run json --dir "$tmp/p/task" --fase 2; expect "json --fase 2: solo FASE-2" "$(js 'j.count+" "+j.tasks[0].id')" "4 TASK-F2-001"
cp "$FIX/canonical.md" "$tmp/p/task/TASK-FASE-3.md"
run lint --dir "$tmp/p/task" --fase 3; expect "V-09: id de otra FASE en TASK-FASE-3.md" "$(lines 'belongs to FASE-1 but the file is TASK-FASE-3')" 6
run lint --dir "$tmp/p/task"; expect "V-09: duplicados entre ficheros" "$(lines 'V-09 duplicate id')" 6
run lint --dir "$tmp/nada"; expect "--dir inexistente → 2" "$rc" 2

# ---------------------------------------------------------------- 6. status por trailers en un repo temporal
repo="$tmp/repo"; mkdir -p "$repo/task"
git -C "$repo" init -q
git -C "$repo" config commit.gpgsign false
cp "$FIX/status.md" "$repo/task/TASK-FASE-1.md"
run status --repo "$repo" --json; expect "status sin commits: 0 done" "$(js 'j.summary.done+"/"+j.summary.total')" "0/6"
n=0
commit() { # commit FICHERO MENSAJE [TRAILER…]
  local file="$1" msg="$2"; shift 2
  n=$((n + 1)); echo "$n" >> "$repo/$file"
  git -C "$repo" add -A
  if [ $# -gt 0 ]; then git -C "$repo" commit -q -m "$msg" -m "$(printf '%s\n' "$@")"; else git -C "$repo" commit -q -m "$msg"; fi
}
commit a.txt "feat(s): a" "Refs: FASE-1" "Task: TASK-F1-001"
commit b.txt "feat(s): b" "Refs: FASE-1" "Task: TASK-F1-002"
before_revert=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" revert --no-edit HEAD >/dev/null
commit c.txt "feat(s): c for TASK-F1-003 without trailer"
commit d.txt "feat(s): d" "Refs: FASE-1" "Task: TASK-F1-004"
commit f.txt "feat(s): f" "Refs: FASE-1" "Task: TASK-F1-006"
git -C "$repo" revert --no-edit HEAD >/dev/null
git -C "$repo" revert --no-edit HEAD >/dev/null
commit z.txt "feat(s): stray" "Refs: FASE-9" "Task: TASK-F9-001"

run status --repo "$repo" --json
expect "status: task_state por defecto checkbox" "$(js 'j.task_state')" "checkbox"
st() { js "const t=j.tasks.find(x=>x.id===\"$1\"); [t.done,t.blocked,t.divergence].join(\" \")"; }
expect "TASK-F1-001 trailer + [x] → done" "$(st TASK-F1-001)" "true false "
expect "TASK-F1-002 revertida → pendiente, checked-without-trailer" "$(st TASK-F1-002)" "false false checked-without-trailer"
expect "TASK-F1-002 guarda el sha revertido" "$(js 'j.tasks[1].reverted.length')" 1
expect "TASK-F1-003 commit sin trailer → pendiente" "$(st TASK-F1-003)" "false false "
expect "TASK-F1-004 trailer sin checkbox → trailer-without-checkbox" "$(st TASK-F1-004)" "true false trailer-without-checkbox"
expect "TASK-F1-005 [!] → blocked" "$(st TASK-F1-005)" "false true "
expect "TASK-F1-006 revert de un revert → done" "$(st TASK-F1-006)" "true false "
expect "status: resumen" "$(js 'const m=j.summary; [m.total,m.done,m.pending,m.blocked,m.divergences].join(" ")')" "6 3 2 1 2"
expect "status: trailer de una task inexistente" "$(js 'j.unknownTrailers.map(u=>u.id).join(",")')" "TASK-F9-001"
run status --repo "$repo"; expect "status texto sale 0" "$rc" 0; has "status texto: línea resumen" "status: 6 task(s) · 3 done · 2 pending · 1 blocked · 2 divergence(s) (task_state: checkbox, rev HEAD)"
run status --repo "$repo" --require-done; expect "--require-done con pendientes → 1" "$rc" 1
run status --repo "$repo" --rev "$before_revert" --json; expect "--rev antes del revert: TASK-F1-002 done" "$(st TASK-F1-002)" "true false "
printf '# Proyecto\n\n## SDD Stack Profile\n\n- stack: rails\n- task_state: `trailers`\n- task_format: compact\n\n## Otra sección\n\n- task_state: checkbox\n' > "$repo/CLAUDE.md"
out=$(cd "$repo" && node "$LINT" status --json 2>&1) || true
expect "Stack Profile task_state: trailers (cwd = repo)" "$(js 'j.task_state')" "trailers"
expect "trailers: casilla sin marcar no es divergencia" "$(st TASK-F1-004)" "true false "
expect "trailers: checked-without-trailer sigue siendo divergencia" "$(js 'j.summary.divergences')" 1
run status --repo "$repo" --state checkbox --json; expect "--state checkbox gana al perfil" "$(js 'j.summary.divergences')" 2
mkdir -p "$tmp/nogit/task" && cp "$FIX/status.md" "$tmp/nogit/task/TASK-FASE-1.md"
run status --repo "$tmp/nogit"; expect "status fuera de git → 2" "$rc" 2

echo
if [ "$fail" -eq 0 ]; then echo "tasks: todo ok"; else echo "tasks: hay fallos"; exit 1; fi
