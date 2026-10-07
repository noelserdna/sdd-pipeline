# Plan 5.3 — cuatro mejoras inspiradas en addyosmani/agent-skills

Origen: análisis de https://github.com/addyosmani/agent-skills (v0.6.12) frente a sdd-pipeline 5.2.0. Cada mejora la
diseñó un especialista en solo lectura con evidencia del repo; el texto siguiente resume sus diseños y su
«especificación para implementar». Estado: **revisado** (sección final); se implementa lo aprobado, en el orden de la revisión.

## M1 · Guardia del listón (`sdd lint --floor`) — ADAPTAR, coste M

Problema real (evidencia): `lint --quotes` mira el texto, no la ejecución: un `test.skip` conserva sus literales. Un
test ligado saltado deja el criterio `missing` y el loop lo enruta a `implement-or-test` (causa equivocada); con dos
tests y uno saltado sale VERIFIED. Nadie impide rebajar los gates del Stack Profile en `CLAUDE.md`
(`literal_gate: off`, `visual_evidence: off`, `adversarial_gate: off`, `acceptance_gate: warn`). «Test edits inside
the loop» solo registra `M` y `R`, no `D` ni `A`. Supresiones de cobertura y umbrales rebajados no los ve nadie.

Diseño: `sdd lint --floor [--base REF] [--json]` en `scripts/lib/floor.mjs`. Base: `--base` → merge-base con la rama
por defecto → último `fase-*-accepted` ancestro → exit 2. Solo líneas añadidas/quitadas; endurecer nunca es hallazgo.
F-01 skip/only/todo/focus añadido en `test_paths` (error) · F-02 fichero de test con ids de criterio borrado (error;
warn sin ids) · F-03 menos asserts en un test ligado (error; warn si el total en test_paths no baja) · F-04 supresión
de cobertura/seguridad añadida (error) · F-05 supresión de tipos/lint (warn) · F-06 umbral de cobertura rebajado
(error) · F-07 gate del Stack Profile rebajado frente a la base (error) · F-08 catch vacío / stub not-implemented
(warn). Patrones JS/TS, Python, Ruby en lista fija. Clave `floor_gate: off|warn|enforce` (defecto enforce; bajarla es
un F-07). Excepción humana `sdd accept record floor-exception --code --file --match --reason --by --role` (sin --req;
vale mientras la línea exista; el tool guard ya pregunta). Sin marcadores en línea. Ejecución: Phase 9 paso 4.0.1b,
`sdd-acceptance --check` y fin de `--loop` con base el sha del ciclo 1, CI (plantillas), `gate --md`/`pr-body`.
Ledger: si todos los tests frescos de un criterio están `skip` → `c.skipped`, `reason: "bound test skipped"`, ruta
`weakened-test`. Tests `tests/floor/run.sh`; defecto sembrado D8 en una segunda etapa del banco (parche
`test.skip` en `tests/api/confirmar.test.js`, solo floor lo caza). Vendorizar `floor.mjs` en `.claude/sdd/`.

## M2 · Revisión de código por FASE con mutación de bolsillo — ADAPTAR, coste M

Problema real: nadie comprueba si los tests matan mutantes (D5 sale VERIFIED en las capas mecánicas); la seguridad
del código no la revisa nadie independiente (`sdd-security-auditor` solo audita specs); `--verify` (Coherence
H01-H09, H07 Security hygiene) existe pero solo corre dentro de `--integrate` y en el mismo contexto que implementó.

Diseño: (a) categoría nueva `UNKILLED-MUTANT` en `--adversarial`, con la mutación ejecutada por la CLI:
`sdd accept mutate candidates --fase N` (líneas de candidate files bajo code_paths atribuidas por blame a commits
`TASK-F{N}-`, con operadores de una tabla fija: `===↔!==`, `<↔>=`, `&&↔||`, `true↔false`, `if (X)→if (true)` …);
`sdd accept mutate run --req --ac --at file:line --from --to --test file [--name]` en un `git worktree add --detach`
en tmpdir (symlinks `mutation_links`, defecto node_modules), baseline primero (`baseline-failed` = sin conclusión),
`{test_name}`/`{test_file}` nunca `{test}`, timeout 120 s (`timeout` cuenta como matado), resultados en
`.sdd/mutants.jsonl`, comprobación final de que el checkout principal no cambió; `accept mutate clean`. Máximo 1
mutante por criterio Must y 8 por verificador. `challenge add --mutant M-NNN` obligatorio con UNKILLED-MUTANT
(survived, mismo HEAD, línea vigente). El contraverificador juzga equivalencia. Arreglo: reforzar el test (edición de
test aprobada por persona). (c) Phase 9 paso 2b: subagente fresco `--verify --fase N` (Correctness + Coherence); un
CRITICAL sin criterio es FAIL de Phase 9 (fix con Task:, o SPEC-DEVIATION si choca con la spec); WARNING/OBSERVATION
solo informe. Descarta `--review` y skill nueva. Banco: D8 con mutante superviviente + control matado.

## M3 · Prove-It: el arreglo trae su test — ADAPTAR, coste M

Problema real, estrecho: rojo-antes-de-verde ya está escrito para tareas normales (solo texto); el ledger ya prueba
el rojo de un criterio FAILING. Quedan descubiertos: fix-tasks `ACCEPTANCE-ADVERSARIAL-FASE-N` (el test está verde
por definición; tras el arreglo el challenge queda `stale` y nada protege de la regresión), `FEEDBACK-FASE-N`, y
hotfix `fix(...)` con `Change:` sin `Task:`.

Diseño: (a) texto: sección «Prove-It (fix tasks)» en `tdd-workflow.md`, frase en Phase 4 del implementer, línea
`Reproduce first:` en la plantilla de fix-task (Mode 5 del generator) y Review «The reproduction test failed before
the fix»; el test de reproducción se liga a un AC/REQ ACn/INV/CONTRACT; sin criterio que citar → no se arregla:
SPEC-DEVIATION/MISSING-BEHAVIOR → req-change. (b) mínimo mecánico: `sdd verify --range` avisa (o falla con
`prove_it: enforce`) si un commit `fix` toca `code_paths` sin tocar ningún fichero de test (test_paths o nombre
`*.test.*`/`*_spec.rb`/`test_*.py`); exentos los fix sin código, perf, merges, reverts, fixup, `[skip-sdd]`. Clave
`prove_it: off|warn|enforce` (defecto warn). Descarta commits rojo/verde (rompe bisect y «una tarea = un commit»),
trailer `Red:` y JUnit del sha rojo. req-change corrective sin cambio de texto → fix-task FEEDBACK con Reproduce first.

## M4 · Evals de enrutado y de presión — ADAPTAR (nivel 1 S, nivel 2 M)

Problema real: validate-plugin solo mide longitud de description; ningún test de conducta del Artículo 12. Prototipo
TF-IDF sobre las 21 descriptions: rank-1 38/48 (EN 28/30, ES 10/17); sin triggers en español: import, reconcile,
reverse-engineer; colisiones `fix` (req-change/spec-auditor/reconcile), `audit/review`, `acceptance`, cobertura.

Nivel 1 (CI, determinista): `tests/triggers/{cases.json,run.mjs,run.sh}`; ≥3 positivos (ES y EN) y 1 negativo por
skill; rompe CI: falta de casos, `pin` no rank-1, `notExpect` por encima de `expect`, par de descriptions ≥ 0,75,
rank-1 < floor (medido − 0,05); avisa: margen < 0,03, par ≥ 0,5, skill sin trigger ES, palabra en ≥ 3 skills.
Primera tarea: triggers ES para import/reconcile/reverse-engineer y desambiguar `fix`. validate-plugin exige casos por
skill. Nivel 2 (opt-in, facturable, nunca en CI): `claude plugin eval` en `evals/plugin/<caso>` con scaffold desde el
banco sembrado, `scripts/run-evals.sh` (exige `SDD_EVALS=1`, `--max-cost-usd`), `docs/evals.md`; casos: ajustar test
ante Q-03, «ya lo aprobé», marcar FASE aceptada con gate fallido, saltar la ronda adversarial, implementar quitando
parte del requisito, fabricar consentimiento; estimación 2–8 USD por caso.

## Revisión escéptica (resultado)

Un revisor independiente verificó cada afirmación contra el código. Correcciones a los diseños: con dos tests y uno
saltado no sale VERIFIED si al vivo le falta el literal (queda `weakened`); `.only` y el borrado ya dejan MISSING, el
fallo es la ruta, no el veredicto; `--verify` es un modo propio del implementer (Mode 4), no solo de `--integrate`,
aunque Phase 9 no lo invoca; D5 lo caza ya la ronda adversarial (CROSSING) y un mutante no lo cazaría.

| Mejora | Veredicto | Alcance aprobado |
|---|---|---|
| M1 | APROBAR CON CAMBIOS | F-07 (gate del Stack Profile rebajado, solo valores explícitos en la base; modo leído de la base; se calcula aunque HEAD diga `off`), F-01 error solo sobre tests ligados o ya existentes en la base (`todo` aviso), F-02, F-04 como aviso; ledger `bound test skipped` + ruta `weakened-test`; la lista de ediciones de tests del loop incluye `D` y es un solo informe con floor; la base efectiva y su motivo siempre en la salida; Phase 9 no acepta `--base`; `floor-exception` exige fichero, línea exacta y sha de la base. Fuera de v1: F-03, F-05, F-06, F-08 |
| M2 | (c) APROBAR CON CAMBIOS · (a) APLAZAR | (c) subagente fresco con `--verify` limitado a H07 (seguridad) y Correctness de lo que el ledger no ve; hallazgo = entrada IF BLOCKER en `feedback/`, no FAIL automático. (a) mutación aplazada hasta: defecto sembrado que solo la mutación caza, candidatos sin depender de `Task:`, `baseline-failed` visible, operadores Ruby, excepción en §3 del protocolo |
| M3 | APROBAR CON CAMBIOS | una frase en Phase 4, `Reproduce first:` en la plantilla de fix-task (Mode 5), `verify --range` avisa con `prove_it: warn`; excepción: WEAKENED-ASSERT (y UNKILLED-MUTANT) son ediciones de test que aprueba una persona. Sin sección nueva en tdd-workflow ni línea de Review |
| M4 | N1 APROBAR CON CAMBIOS · N2 APLAZAR | N1: rompe CI solo un positivo ES y EN por skill y los `pin` en rank-1; el resto del ranking avisa (evitar optimizar para un proxy). Primero triggers ES de import/reconcile/reverse-engineer y desambiguar `fix`. N2 tras M1 y M3, con el caso adversarial sobre `enforce` |

Orden: defectos existentes → M4 N1 → M1 → M3 → M2(c) → (luego) M4 N2 → M2(a).

Defectos ya existentes encontrados: (1) `adversarial-protocol.md` §8 dice `warn` por defecto (es `enforce`);
(2) `stackProfile` de la CLI ignora `.claude/CLAUDE.md` y no salta bloques de código, a diferencia de los hooks; F-07
debe usar el parser corregido; (3) «Test edits inside the loop» ignora los borrados (`D`); (4) la ruta de un criterio
con tests saltados es `implement-or-test`; (5) el upstream guard permite editar `.claude/sdd/*` (validador vendorizado)
sin preguntar — se anota, fuera de este alcance; (6) premisas de M2 corregidas arriba.
