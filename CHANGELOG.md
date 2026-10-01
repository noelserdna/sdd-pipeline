# Changelog

All notable changes to the SDD plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [5.2.0] - 2026-10-01

### 5.2: página de estado viva del proyecto

Motivación: el cliente no técnico tenía que preguntar dónde estaba el proyecto. En 5.1 la «página viva» existía solo en prosa: nada la creaba al empezar, ninguna etapa la actualizaba, el LLM la recomponía cada vez, su URL vivía en `.sdd/status-page.json` (sin versionar, así que otro clon o una estación creaba otra), no había historia (el `summary` se sobrescribe en cada re-ejecución), los requisitos no se explicaban en lenguaje llano y las guías la llamaban «opcional en `--publish`». Plan y contrato de datos en `docs/design/plan-5.2-status-page.md`.

#### Changed (incompatible)
- **La página de estado deja de ser opcional cuando la sesión tiene la herramienta Artifact.** `sdd-setup` (o el orquestador o el lead al empezar o reanudar) la crea tras una sola pregunta, y todas las etapas y puertas la actualizan; «no» queda registrado con `sdd status page decline` y no se vuelve a preguntar. Sin la herramienta (`claude -p`, CI, estaciones) se construye en local en `.sdd/status-page/index.html`.
  - **Migración:** el `.sdd/status-page.json` de 5.1 se mueve a `status/page.json` (versionado) la primera vez que corre `sdd status page`; la misma URL se sigue actualizando.
- **El procedimiento se mueve a la raíz del plugin:** `skills/sdd-acceptance/references/status-page.md` desaparece; todas las skills remiten a `references/status-page.md`.

#### Added
- **Página determinista:** plantilla fija `templates/status-page/` más los datos de `sdd status build` (contrato `sdd-status-v1`): dónde estamos y qué necesitamos del cliente, lo que pidió (citas literales), cada requisito (funciones, calidad, condiciones) con su explicación llana y su evidencia en la misma tarjeta (capturas por criterio, vídeo, pruebas, mediciones, demos registradas), las entregas, el diario, una sección por feature, detalles técnicos plegados y glosario. Las capturas y vídeos se publican como ficheros de la página.
- **Diario versionado** `status/journal.jsonl` (`sdd journal add|list`): una línea llana por hecho, en el idioma del cliente. Cada skill de etapa escribe `start` al empezar y `done` en su Persist; el orquestador y el lead, `gate` y `decision` en cada puerta (`--stage orchestrator` / `--stage lead`) y, en las puertas de FASE y la firma, un `feedback` por comentario o feedback encauzado (`--stage acceptance`); la aprobación de requisitos y la firma, su `decision` con quién y cuándo; `sdd-req-change`, `change`; `sdd route --write`, un `skip` con el motivo por etapa saltada y una `decision` con quién confirmó la ruta; la aceptación, `evidence`. `sdd status build` deriva como `decision` la aprobación de requisitos y la aceptación de cada FASE si faltan. El `summary` de `pipeline-state.json` sigue siendo el registro técnico (`cascade-patterns.md` §10).
- **Registro** `status/page.json` (`sdd status page [set|decline|feature add|asset]`): URL, features y evidencias publicadas.
- **Línea «Para el cliente»** en cada requisito (`REQ-F`, `REQ-NF`, `REQ-C`): una o dos frases sin jerga que el cliente revisa junto a los ejemplos en la puerta 1; `sdd-req-change` la mantiene en ADD/MODIFY.
- **Comentarios del cliente:** en cada puerta de FASE y en la firma se leen los comentarios de la página, se tratan como feedback (defecto / cambio / pregunta, con confirmación humana), se responden en su hilo y quedan en el diario. La demo de la puerta se enseña sobre la página.
- **Features nuevas:** un ADD de una capacidad nueva crea su sección en la página (`sdd status page feature add`).
- `sdd-pipeline-status` muestra el enlace de la página y la última línea del diario; `sdd-setup` marca `status/journal.jsonl merge=union` en `.gitattributes` para que las ramas no choquen al añadir líneas.
- Suite `tests/status`.

#### Changed
- `sdd-orchestrator`: la regla 5 pasa a una columna «Status page» de la tabla Flow. `sdd-lead` es el único que publica (las estaciones escriben el diario) y su fila 11 deja de tratar la página como opcional.
- `sdd-acceptance --publish` actualiza la página común (o la crea, preguntando) además del bloque de PR/issue.

## [5.1.0] - 2026-09-30

### 5.1: evidencia visual, ronda adversarial y verificación del entorno desplegado

Motivación: la retro de la feature «CV enriquecido» (Campus CodeCrypto, issue #27). El pipeline 5.0.0 entregó 35/35 requisitos trazados y 344 tests en verde, y tres rondas de verificación independiente encontraron aun así 12 huecos reales. Todos seguían cinco patrones: el mock sustituye al provider real, piezas construidas sin cablear, la letra del requisito se diluye en la cadena, los cruces (replay, carreras) no tienen dueño, y local ≠ desplegado. Propuesta en `docs/MEJORAS-SDD-5.1.md`, verificación y diseño en `docs/MEJORAS-SDD-5.1-ANALISIS.md`, reparto en `docs/design/plan-5.1.md`.

#### Changed (incompatible)
- **Evidencia visual obligatoria en los requisitos funcionales.** Un criterio de un `REQ-F` con su test en verde pero sin captura queda `unshown`, y el requisito no es VERIFIED. Cada workflow de cara al usuario necesita además su vídeo para `sdd gate --fase N`: los `WF-NNN` de la línea de cabecera nueva `> **Workflows:**` del fichero de FASE (escrita por plan-architect; sin ella, los citados en `## Demo`), o uno con `FASE-N` en el nombre cuando la FASE no nombra ninguno. Cuenta cualquier vídeo bajo `evidencias/` con el id en el nombre, también una grabación manual de la demo; lo que falta sale en `missing_videos` (exit 1) y `sdd loop next` emite un target `capture-evidence` por vídeo. Las evidencias viven en `evidencias/FASE-{N}/`, fuera de git; el ledger guarda su sha256. Clave del Stack Profile `visual_evidence: required|warn|off` (por defecto `required`).
  - **Migración:** en un proyecto 5.0, los REQ-F que eran VERIFIED pasan a `unshown` hasta que se vuelva a ejecutar su journey con captura. Un proyecto sin interfaz declara `visual_evidence: off`.
- **Un test que no lleva la letra del criterio no verifica un Must.** Con `literal_gate: enforce` (por defecto), un criterio de un Must cuyo test pasa sin la cita actual o sin uno de sus literales queda `weakened` y el requisito no es VERIFIED.
  - **Migración:** en un proyecto 5.0 los tests no llevan cita (solo aviso Q-01), pero un literal del criterio ausente del test (Q-03) retiene el Must: `sdd lint --quotes` los lista. `literal_gate: warn` lo deja en aviso mientras se ponen al día.
- **La CLI de aceptación rechaza evidencia sobre código sin commitear.** `sdd accept --junit-sha` y `sdd accept record demo|inspection|measurement|fase-acceptance` / `accept measure` salen con 2 («commit first») si hay cambios sin commitear en el código, salvo `--allow-dirty`, que queda grabado como `dirty: true`. Sin `--junit-sha`, un árbol sucio imprime un aviso.

#### Added
- **Ronda adversarial**, `sdd-acceptance --adversarial [--fase N]` (`references/adversarial-protocol.md`): un verificador independiente por FASE lee la letra de cada requisito contra el código de producción y los tests, sin poder citar `spec/`, `acceptance/` ni `feedback/` como evidencia; un segundo agente intenta refutar cada hallazgo y una muestra de veredictos limpios. Los hallazgos confirmados van a `acceptance/challenges.jsonl` (`sdd accept challenge add|list`, `sdd accept adversarial plan` como crítico de cobertura) y al loop por la ruta `adversarial-finding`; descartar uno es un registro humano (`challenge-dismissal`). El veredicto no cambia; `adversarial_gate: off|warn|enforce` (por defecto `enforce`) decide si un hallazgo abierto en un Must hace salir a `sdd gate` con 4. El orquestador y el lead la ejecutan antes de cada puerta de FASE. Jev solo prioriza qué criterios se revisan primero.
- **Adjuntos en el ledger:** `[[ATTACHMENT|…]]` del JUnit (Playwright), imágenes nombradas con el id del criterio bajo `evidencias/` (Minitest) y `accept record … --attach`. `sdd accept pack --fase N` empaqueta las evidencias de la FASE con su manifiesto de hashes para entregarlas al cliente; la página de estado las muestra.
- **`sdd req show <REQ-ID> [--ac N]`**: el texto literal de un requisito, para citarlo en el test.
- **Letra literal en el test:** el test cita el criterio de `requirements/REQUIREMENTS.md` encima de su assert; el implementer lee la fuente y no la paráfrasis de la tarea. W8 de specifications-engineer conserva los literales visibles en los Then.
- **`sdd lint --quotes [--fase N] [--json]`** (`scripts/lib/quotes.mjs`): por cada criterio y cada fichero de test que lo nombra (`REQ-X-NNN ACn`, o un `AC-NNN-NN` que la etiqueta BDD liga al criterio), Q-01 sin cita (aviso), Q-02 la cita no es el texto actual del criterio (error; cita inventada o desactualizada tras un MODIFY) y Q-03 un literal del criterio no está en el código del test fuera de los comentarios (error). Literal: texto entre comillas de cualquier tipo, y entre acentos graves solo a partir del THEN (antes es el comando o la ruta). Es la comprobación que habría cazado «Proyectos» frente a «Proyectos personales». Phase 9 del implementer la ejecuta antes de capturar.
- **Clave `literal_gate: off|warn|enforce`** (por defecto `enforce`): `sdd accept` lista `literal_gaps` por criterio y en `summary.literal_gaps`; con `enforce` un criterio de un Must con un Q-02/Q-03 queda `weakened` y el requisito no es VERIFIED (`reason: "test does not carry the criterion's literal"`), ruta `weakened-test` en `sdd loop next`. Excepción humana `sdd accept record literal-exception --req --ac --literal --reason`, que caduca con el reqHash. Informe, `gate --md`, la sesión y `sdd_context` (hueco `WEAKENED_ACn`) lo muestran.
- **Marcador «el usuario ve» / «the user sees»** en los criterios visuales; test-planner planifica un E2E que entra por la ruta del usuario, asserta el texto y captura (gap `MISSING-E2E`); task-generator añade una tarea de journey por FASE.
- **Replay y carrera:** pregunta 6 de specifications-engineer (segunda ejecución idéntica), técnica «Replay and race» en las matrices (gap `MISSING-REPLAY-SPEC`), criterio de replay en todo requisito que escribe estado y hallazgo CAT-03 en spec-auditor.
- **Tests de contrato de puertos:** tabla «Puertos con doble» en PLAN-FASE §4, tarea hermana `CONTRACT-<port>` que corre los mismos casos contra el doble y el provider real, y aviso V-21 en `sdd lint --plan`.
- **Ruta `capture-evidence`** en el loop de aceptación: un criterio `unshown` o un vídeo que falta se resuelve volviendo a ejecutar el journey con captura (con `SDD_FASE` y `SDD_EVIDENCE_DIR` exportados, como en todo comando `acceptance` del implementer), sin tarea de código.
- **Smoke post-deploy:** plantillas `templates/ci/github/sdd-smoke.yml` y `templates/ci/gitlab/sdd-smoke.gitlab-ci.yml`, ofrecidas por `sdd-setup --tracker`; tier `smoke-deploy` en test-planner, con sus escenarios etiquetados `@smoke-deploy` (`@smoke` sigue siendo el tier de PR); preguntas de configuración por entorno y verificación tras el deploy en tech-designer. El implementer abre una entrada `IF-` `ENV-REQUIRED` cuando una tarea lee una variable que `env_required` no lista.
- **Claves del Stack Profile:** `visual_evidence`, `evidence_dir`, `adversarial_gate`, `literal_gate`, `test_slots`, `staging_url`, `smoke`, `smoke_report_path`, `env_required`, `deploy` (kits v1.2.0; `validate-plugin` las comprueba).
- **Recursos de la máquina:** `test_slots` limita los procesos de test concurrentes; los subagentes ejecutan tests de uno en uno.
- Phase 9 del implementer ancla la evidencia a un commit limpio (paso 4.0, CHECK-C13).

#### Fixed
- Los ficheros sin versionar bajo `code_paths` + `test_paths` no marcaban el árbol como sucio, y el ledger podía dar VERIFIED sobre un commit donde no existían.
- El Mode 6 del implementer (`--new-tasks-only`) solo ejecutaba tareas `Source: CASCADE-*`: las fix-tasks del loop de aceptación y de la puerta de FASE se quedaban sin implementar.

## [5.0.0] - 2026-09-28


### v5: customer needs, vertical FASEs, native git and acceptance per requirement

Motivación: una revisión con Fable encontró cinco huecos. Las FASEs eran horizontales (FASE-0 de infraestructura y luego una FASE por módulo). Nada respondía "¿está satisfecho REQ-X y con qué evidencia?". Git estaba infrautilizado. Había infraestructura sin retorno (code-index, trace-map, dashboard HTML y panel multi-sesión). Y Jev solo actuaba al principio. Resultado: 21 skills, 5 hooks y una sola CLI.

#### Removed (incompatible)
- Skills `sdd-code-index`, `sdd-dashboard` y `sdd-traceability-check` (23 → 21 skills contando `sdd-acceptance`, que es nueva).
  - `sdd-traceability-check` → `sdd-acceptance --check`, que incluye la integridad de la cadena de IDs.
  - `sdd-code-index` → `sdd trace why <fichero>[:línea]` (blame → commit → trailers).
  - `sdd-dashboard` → `scripts/sdd-graph.py` sigue construyendo `dashboard/traceability-graph.json` para el servidor MCP y los hooks, sin página HTML. `test-result-parser.py` pasa a `scripts/`. La vista compartible es `sdd-acceptance --publish`.
- Panel multi-sesión: hooks `sdd-activity-log.sh` y `sdd-runs-line.sh`, `sdd-watch` y `/sdd-watch`, las status lines (proyecto, global y subagente) y `install-global-statusline.sh`. Marcar una etapa `running` al arrancar su skill pasa al hook de estado (PreToolUse `Skill` y UserPromptExpansion).
- Hook `sdd-trace-map-updater.sh` y `.sdd/current-task.json`: los commits atómicos con `Task:` llevan la misma información.
- 8 → 5 hooks (14 → 7 registros de evento). El plugin sigue sin distribuir agentes.
- Los veredictos de cobertura del servidor MCP ya no se infieren de la existencia de enlaces en el grafo.

#### Added
- **`scripts/sdd.mjs`, una sola CLI** (Node ≥ 18, sin dependencias; `scripts/sdd-task-lint.mjs` queda como alias):
  - `lint`, `tasks json|status|index` (lo que hacía sdd-task-lint);
  - `trace commits|req|why|delivered`: coincidencia exacta de IDs (`REQ-F-01` ya no casa con `REQ-F-012`), reverts descontados y lectura `legacy` de commits sin bloque de trailers;
  - `verify --message|--range`: trailers parseados por git, bloques rotos señalados por línea, detección de squash en rangos de PR;
  - `branch status|start fase|change|audit`: detecta la rama por defecto (no asume `main`);
  - `lint --needs` y `lint --plan` (V8/V9);
  - `accept`, `accept record`, `gate` y `loop next` (abajo).
- **Git nativo** (`references/git-conventions.md`, `docs/git.md`): trailers `Task`/`Refs`/`Change` escritos con `git commit --trailer` (git ≥ 2.32); `fix`/`perf` aceptan `Task` o `Change` para no bloquear un hotfix; el hook commit-msg ejecuta `sdd verify` desde el validador vendorizado en `.claude/sdd/` (fallback bash con `git interpret-trailers` sin Node); rama de trabajo por defecto en req-change, implementer, Mode Fix, reconcile y reanudaciones; solo merge commits; tags anotados; receta de `git bisect`; sin `git notes`.
- **Captura con el cliente** (`sdd-requirements-engineer`): `requirements/CUSTOMER-NEEDS.md` con necesidades `N-NNN` literales releídas con el cliente; `Needs:` y `Verification: test | demo | measurement | inspection` en cada requisito; ejemplo concreto revisado por criterio de aceptación; aviso por encima del 60 % de Must; recorrido ASCII opcional; aprobación como tag anotado `requirements-v{N}` con aprobador, rol y hash, solo tras un sí explícito. Jev `need-coverage` sugiere; `sdd lint --needs` decide.
- **FASEs verticales** (`sdd-plan-architect`): FASE-0 es el esqueleto andante (escribir → observar → persistir del caso de uso central); cada FASE es un recorrido de usuario (máximo 3 casos de uso y unas 15 tareas); seguridad en la primera FASE que expone el recurso; `FASE-N-HARDENING` solo para NFR medidos; Streams como excepción. Cabecera con `Incremento`, `Requisitos`, `Escenarios`, `Necesidades` y `## Demo` de hasta 10 pasos; `Plan-Style: vertical` en `PLAN.md` (sin la marca, el plan se trata como horizontal y sigue funcionando). Los tests llevan en el nombre el ID del escenario `AC-NNN-NN`.
- **Puerta de FASE = aceptación del cliente** (orquestador y lead): se presenta la demo y el veredicto por requisito; aceptado o con observaciones → tag `fase-{N}-accepted`; rechazado → feedback clasificado como defecto, petición de cambio o pregunta (Jev `feedback-route` opcional; una persona confirma).
- **Aceptación por requisito** (`sdd accept`, `docs/aceptacion.md`): veredictos VERIFIED / FAILING / MISSING / WAIVED (deprecados aparte) desde JUnit XML (vitest, jest, pytest, rspec, playwright, minitest, mocha) y `acceptance/decisions.jsonl`, atado al hash del texto del requisito (un MODIFY reabre la aceptación); frescura limitada a los `code_paths` + `test_paths` del Stack Profile (un commit de docs o `feedback/` no envejece la evidencia); mediciones por comando (`sdd accept measure --command … --extract …`, re-ejecutadas con `sdd accept --remeasure` y ruta `remeasure` del bucle, sin pedir a una persona); `.sdd/acceptance.json` y `acceptance/ACCEPTANCE-REPORT.md` legible por el cliente.
- **`sdd gate`**: salida 0 objetivo cumplido · 1 no cumplido · 2 evidencia obsoleta · 3 cumplido con Musts exentos; `--mode off|warn|enforce`; `--md` para el cuerpo del PR.
- **`sdd loop next`**: el código decide la parada (`goal`, `regression`, `needs-human`, `no-progress`, `max-cycles`; 3 ciclos por defecto, máximo 5) y propone la ruta.
- **Skill `sdd-acceptance`**: `--check`, `--fase N`, `--loop`, `--sign-off` (registro `fase-acceptance` y tag) y `--publish` (bloque de PR/issue y, si la sesión ofrece la herramienta Artifact, una página de estado compartible tras preguntar; si no, `ACCEPTANCE-REPORT.md`). Stop prompt tras `--loop`. Etapa `acceptance` en `pipeline-state.json`, nunca marcada stale por una cascada.
- **Guardas contra la auto-aprobación accidental**: el tool guard pide confirmación (`ask`) antes de `sdd accept record` y de los tags `fase-N-accepted` / `requirements-vN`; el upstream guard deniega editar `acceptance/decisions.jsonl` y el informe. Se documenta como prevención, no como garantía.
- **Claves del SDD Stack Profile**: `test_report`, `test_report_path`, `acceptance_gate`, `tracker`, `default_branch` (en los dos kits y en `docs/stacks.md`). `sdd-setup` escribe `task_state: trailers` en proyectos nuevos aunque no haya kit.
- **Ejecución real en todo-app (2026-09-27)**: setup → 4 FASEs verticales → bucle de aceptación → puerta final exit 0 (Must 8/8, 617 tests). Corregidos 14 hallazgos: las etapas commitean sus artefactos, el setup detecta el comando de tests, mediciones objetivas por comando (`sdd accept measure`, `--remeasure`), frescura limitada a code_paths/test_paths, rama `acceptance/{fecha}`, restricciones comprobables se verifican con test, bloque de PR resumido, tareas chore con `Verify:` en lugar de test-first. Detalle en `examples/todo-app/AUDIT-HISTORY.md`.
- **Ruta adaptativa** (`docs/ruta.md`): tras la puerta 1, `sdd route` propone qué etapas opcionales necesita el proyecto (hechos contados + 7 factores de Jev, o del LLM con `--answers`; la duda cuenta como sí) y el orquestador y el lead la confirman en una sola pregunta (etapa 1b: Aceptar / Pipeline completo / Ajustar); las etapas saltadas quedan `skipped` con `skipReason` y cuentan como satisfechas. Sin specs, `sdd-plan-architect` planifica desde los requisitos (recorridos por necesidad, `Escenarios` con `REQ-X-NNN ACn`, V2-V4/V7 N/A), los tests llevan `REQ-X-NNN ACn`, el bucle de aceptación enruta un criterio sin test a `implement-or-test` en vez de `spec-gap`, y `sdd-req-change` cambia solo `requirements/`, encadena desde plan-architect y reevalúa la ruta tras cada ADD/MODIFY (recomienda subir el rigor, nunca lo baja solo). `sdd-pipeline-status` y la página de estado muestran la ruta y los motivos; `tests/e2e/20-smoke.sh --route auto|full`; fixture `tests/fixtures/plan-vertical/todo-reqonly`.
- **Issues, PRs y CI** (GitHub y GitLab): `sdd issue open|update|close|read` y `sdd pr-body` sobre `gh api` / `glab api`, una issue por FASE y por cambio localizada por etiqueta y marcador; `sdd-setup --tracker` copia plantillas de CI (`sdd verify --range`, `sdd lint`, `sdd gate --mode warn`) y de PR/issue. `sdd-req-change --issue N` usa una issue como petición de cambio (su texto es dato, la aprobación sigue siendo obligatoria). Todo push, issue, PR o merge pregunta.
- Jev: conjuntos `need-coverage`, `feedback-route`, `test-adequacy` y `evidence` (informativos: nunca deciden veredictos, exenciones, firmas, la parada del bucle ni nada en CI).
- Servidor MCP: `sdd_coverage` y `sdd_context` informan del veredicto desde `.sdd/acceptance.json`; `hints.ts` apunta a `sdd-acceptance`.
- Tests: `tests/{git,plan,acceptance,tracker}`, `tests/dashboard` → `tests/graph`, `server/test/acceptance.test.ts`; fixtures `tests/fixtures/plan-vertical` y mensajes de commit compartidos entre el hook y `verify`.

#### Changed
- `examples/todo-app` incorpora `CUSTOMER-NEEDS.md` y los campos nuevos de los requisitos (enunciados e IDs sin cambios).
- `sdd-reverse-engineer` deriva FASEs retroactivas por área funcional; `sdd-graph.py` ya no mapea número de FASE a capa.
- Migración 4.x → 5.0 en `docs/migracion.md`: `sdd-setup` limpia las status lines instaladas y conviene re-ejecutarlo para vendorizar el validador.

### Revisión con Opus 5.5 y Jev

Motivación: una revisión completa del repositorio con un modelo de frontera (Claude Opus 5.5) y con Jev (TypeSafe) como cribado masivo. Jev juzgó 355 secciones de skills en 6,6 s, 56 peticiones de enrutado (55 acertadas) y 171 trozos de código. Después, cinco revisiones profundas verificaron sus marcas, y encontraron la mayoría de los bugs de contrato que se corrigen aquí. Detalle y límites en `docs/jev.md`. Incluye cambios incompatibles, que también entran en 5.0.0.

#### Removed (incompatible)
- `sdd-verify-coverage` → `sdd-gap-detector --semantic`, que trocea ficheros completos (antes leía solo 200 líneas), usa los origins reales del grafo y opcionalmente usa Jev como juez. Su salida anterior no tenía consumidor.
- `sdd-onboarding` → `sdd-pipeline-status --diagnose`: una hoja de hechos y una tabla de primera coincidencia sobre los 8 escenarios. La matriz de pesos dividía por cero y nunca clasificaba Greenfield.
- Agentes `sdd-context-keeper` y `sdd-constitution-enforcer`: nadie los invocaba y se solapaban con session-summary, la memoria de Claude Code y el hook H2.
- `sdd-cross-auditor` y `sdd-pipeline-auditor` pasan a `.claude/agents/`: auditan este repositorio y ya no se distribuyen.
- El plugin ya no distribuye agentes.

#### Added
- **`scripts/sdd-jev.mjs`**, integración opcional con Jev. Solo actúa con `TYPESAFE_API_KEY`; sin ella sale con código 3 y las skills usan el LLM.
  - Comandos: `status`, `judge`, `req-lint` y `chunks`. Las preguntas están en `scripts/jev/*.json`.
  - Lo usan requirements-engineer (Mode 2), spec-auditor (triaje de hits de patrones) y `gap-detector --semantic`.
  - Tests con un mock local en `tests/jev/run.sh`.
- **`sdd-orchestrator` como skill.** Era un agente, y un subagente no puede preguntar al usuario en cada puerta.
- `scripts/sdd-state.sh set|get`: cambia el estado de una etapa con el mismo lock que los hooks.
- Artículo 12 (Specification Primacy) en `references/sdd-constitution.md`.
- `plan-architect` escribe `design/OPERATION-MAPPING.md` cuando no se ejecutó tech-designer.

#### Fixed
- **Hooks:**
  - H3 creaba `pipeline-state.json` en cualquier repo git. Con el plugin activo globalmente, el guard llegaba a denegar ediciones en proyectos ajenos.
  - El guard aplicaba la primera etapa `running` por orden de fichero, y bloqueaba a req-change.
  - Las etapas `done` volvían a `running` y se quedaban así.
  - `SDD_STATE_ROOT` se filtraba a otros repos, y `STATE_ROOT` salía del cwd en lugar del fichero editado.
  - La sesión mostraba "9/7 done".
  - A la salida del augment-hook le faltaba `hookEventName`.
  - commit-msg rechazaba commits Revert y fixup!.
- **`generate.py`:**
  - El parser de commits descartaba casi todos los commits, porque los ficheros caían en el registro siguiente.
  - El trace-map del hook nunca se fusionaba.
  - Los rangos inventaban IDs: "NFR-001 — 150 ms" daba 150 referencias.
  - "BDD-style" contaba como ID.
  - Los escaneos ignoraban el Stack Profile y solo cubrían `.ts/.js` con vitest.
  - El clasificador usaba el mapa de dominios de otro proyecto.
  - El JSON inline no se escapaba.
- **Servidor MCP:** tipos y cobertura alineados con el grafo v6 (todos los origins).
- **Contratos entre skills:**
  - task-implementer leía `plan/PLAN-FASE-N.md` (la G-02 paraba siempre); la ruta real es `plan/fase-plans/`.
  - Las plantillas de commit de req-change y del Mode Fix de spec-auditor eran rechazadas por el hook commit-msg. Ahora son `docs(specs)` con `Refs:`.
  - El gate G2 de plan-architect exigía "0 hallazgos". Ahora lee `gate_result`.
  - spec-auditor descartaba los hallazgos de ausencia, y el lead despachaba Streams sin el Stream `base`.
  - reverse-engineer, import y reconcile escribían un árbol `spec/` plano obsoleto.
  - reconcile deprecaba automáticamente lo no implementado, lo que viola el Art. 12. Ahora existe la clase `NOT_IMPLEMENTED`.
  - Rutas `src/` fijas en lugar del Stack Profile.
  - IDs de operación unificados en `API-NNN-NN`; pantallas UX en `SCR-NNN`, que chocaba con `WF-NNN`.
- **Estándares:** WCAG 2.2 AA; INP sustituye a FID; ASVS fijado en 4.0.3.

#### Changed
- **Skills recortadas para un modelo de frontera.**
  - Se mueven a `references/` las plantillas de un solo paso.
  - Se eliminan duplicados, teoría de manual, énfasis en mayúsculas y restos de proyectos anteriores (ADR-025/026, INV-SYS, ReadPDF, CV/JobOffer).
  - `sdd-req-change`: 66k → 18k caracteres. `sdd-spec-auditor`: 62k → 23k. `sdd-task-implementer`: 61k → 31k. Laterales: 329k → 197k.
- `CLAUDE.md` y los README se reescriben según el árbol real (no existía `automation/`, y el esquema de estado y los origins estaban desfasados).

## [4.3.0] - 2026-09-15

Motivación: una carrera con la misma spec SDD implementada en paralelo con Next.js + Prisma y con Rails 8.1 (Sonnet 5, headless) terminó en empate, pero casi toda la fricción venía del propio pipeline: comandos npm/vitest fijos, rutas y códigos HTTP impuestos por las plantillas de contrato, tareas de test separadas del código, formato de tarea distinto en cada ejecución, subagentes para tareas triviales, hooks ciegos con la app en `web/` y un agente que fabricó el consentimiento de Prisma 12 veces.

### Added
- **SDD Stack Profile**: sección `## SDD Stack Profile` en el CLAUDE.md del proyecto con los comandos del stack (`test`, `test_file`, `test_name`, `typecheck`, `lint_files`, `lint`, `build`, `coverage`, `db_reset_safe`, `server`, `port`, `acceptance`), rutas (`app_dir`, `code_paths`, `test_paths`) y modo de tareas (`task_state`, `task_format`). Contrato en `skills/sdd-task-implementer/references/stack-profile.md`. Resolución: sección declarada → detección por ficheros (Rails, Next.js + Prisma, Workers, Python) → heurística anterior → `plan/ARCHITECTURE.md`.
- **Kits por stack** `templates/stacks/{rails,nextjs-prisma}`: perfil, convenciones (≤ 2,5k caracteres, cargadas en cada turno) y reglas por ruta. Se instalan con `scripts/install-stack-kit.sh` o `/sdd-setup --stack=`. Guía en `docs/stacks.md`.
- **`scripts/sdd-task-lint.mjs`**: `lint` (gramática de línea de tarea V-19, además de V-05/V-06/V-09/V-16), `json`, `status` (estado real por trailers `Task:`, descontando reverts) e `index` (deriva `TASK-INDEX.md`).
- **Contratos de comportamiento**: Template 12b *Operations Contract* (`Style: operations`) en specifications-engineer; `design/OPERATION-MAPPING.md` en tech-designer (operación → ruta o acción, verbo, éxito, error de validación, fallback sin JS, elemento accesible); **CAT-10 Sobreespecificación de transporte** (prefijo `TRN-`) en spec-auditor.
- task-generator `--compact` (sin bloque Review, Revert solo si no es SAFE, sin `TASK-INDEX.md`) y `task_state: trailers` en task-implementer (no edita casillas).
- Parsers: Minitest y RSpec en `sdd-dashboard/test-result-parser.py`; rutas Rails (`bin/rails routes --expanded`) y Server Actions de Next.js en gap-detector; operaciones `API-NNN-NN` en filas de tabla en el grafo del dashboard.
- Catálogos: Rails + Hotwire y Next.js App Router en tech-designer y plan-architect; "Recomendado" solo si coincide con un ADR, el perfil o un kit.
- Pruebas: `tests/tasks/run.sh`, `tests/dashboard/run.sh`, perfil y tool-guard en `tests/hooks/run.sh`, instalación de kits en `tests/setup/run.sh`. `validate-plugin.mjs` valida los kits y avisa de flags sin documentar, comandos de stack fijos y SKILL.md de más de 62k caracteres.
- `scripts/release.sh X.Y.Z --no-push`: commit y tag locales.

### Changed
- **Granularidad de tareas**: los tests van dentro de la tarea que implementa el comportamiento (test-first dentro de la tarea, Art. 8); cortes verticales por operación siguiendo las capas del kit; fases internas Setup → Foundation → Slices → Integration → Verification (se siguen aceptando las antiguas). La fase "Tests después de Contracts" contradecía el Art. 8.
- **task-implementer sin stack fijo**: usa los comandos del perfil; tests acotados por tarea, suite completa solo en el checkpoint Foundation y en la verificación, build solo en la verificación; reutiliza la suite E2E existente (`{acceptance} --grep`) en lugar de montar Playwright o hacer smoke con curl; subagentes solo para lotes de al menos 2 tareas `[P]` no triviales, siempre en primer plano. `SKILL.md` no crece (60,7k caracteres): Stack Detection, verificación, recuperación e informe pasan a referencias.
- **Transporte**: specifications-engineer exige HTTP solo con `Style: http`; review-checklist, task-implementer y test-planner comprueban la semántica contra el contrato y el transporte contra `OPERATION-MAPPING`; ux-designer no fija HTTP ni URLs que no exija un REQ, y la validación de cliente no puede bloquear los mensajes del servidor. **Las baselines de auditoría existentes recibirán hallazgos CAT-10 nuevos.**
- Hooks: state-updater, trace-map, upstream-guard y augment-hook usan `code_paths`/`test_paths` del perfil (app en `web/`, Minitest en `test/`).
- `TASK-INDEX.md` es opcional y `sdd-pipeline-status` ya no marca INCONSISTENT sin él. La numeración de artículos del constitution-enforcer se alinea con `references/sdd-constitution.md`.

### Fixed
- La tabla de flags de task-implementer no listaba `--parallel` ni `--sequential`.
- `generate.py` no leía tareas con el ID en negrita ni operaciones `API-NNN-NN`.
- Los hooks no registraban la implementación con la app fuera de `src/` (p. ej. `web/`) y bloqueaban `test/` de Minitest con la app en la raíz.
- **`sdd_gaps` no entendia el fichero que escribe su propia skill.** `executeGaps` esperaba `{summary, findings[]}` con `category` en cada hallazgo, pero `sdd-gap-detector` escribe `sdd-gap-analysis-v1`: los hallazgos repartidos en `endpoints.{missing,orphan,mismatch}` y `bddCoverage.missing`, mas un bloque `statistics`. Con el fichero real `data.findings` era `undefined` y **las tres rutas lanzaban TypeError** —el filtro por categoria, `format: "detail"` y `format: "summary"`—, no solo el filtro. No se notaba porque un proyecto sin `.sdd/gap-analysis.json` cae antes en el "No gap analysis found".
  - La traduccion va campo a campo. Los huerfanos **no traen identificador**, asi que se sintetiza de metodo y ruta (`ORPHAN-GET-/api/legacy`) y no del indice del array: un `ORPHAN-0` cambiaria de significado en cuanto se anadiera una ruta por delante, de modo que el mismo hallazgo tendria identificadores distintos entre ejecuciones.
  - `bddCoverage.missing` **no son endpoints**. Comparten la categoria `missing` porque las dos cosas faltan —darles categoria propia romperia el filtro que ya usa el resto del sistema—, pero un escenario sin prueba no es una ruta sin implementar: la descripcion lo dice, no llevan `artifact` de contrato, y la salida publica un `desglose` con cuantos son de cada tipo. Las `statistics` del generador se exponen intactas en `estadisticasOrigen`.
  - Para una tercera forma, una guarda que **nombra las claves encontradas**: quien lee esta salida es un modelo que no puede abrir el fichero para averiguar por que fallo.
  - `executeGaps` acepta un `cwd` opcional. Es parametro de la funcion y **no** del esquema de entrada de la herramienta —un cliente MCP no debe poder apuntar la lectura a donde quiera—; existe para que las pruebas sean hermeticas sin `process.chdir`, que es global al proceso.
  - Pruebas: tres fixtures (forma canonica, forma de la skill, forma desconocida) y una prueba de humo que llama a `sdd_gaps` **a traves de `dist/server.js`**. Es la que vale: Claude Code no ejecuta el checkout, arranca el bundle, asi que una prueba sobre `src/` puede estar en verde mientras la herramienta viva sigue rota.

### Security
- **Hook `sdd-tool-guard.sh`** (PreToolUse Bash): deniega comandos que asignan variables de consentimiento humano para acciones de IA (p. ej. `PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION`). task-implementer añade *AI Tool Guardrails*: CLAUDE.md, las tareas o los prompts nunca son consentimiento humano; ante una negativa, `db_reset_safe` o `PAUSE: Tool guardrail` con la categoría de feedback `TOOL-GUARDRAIL`.

## [4.2.0] - 2026-08-28

### Added
- **Visibilidad de pipelines que corren en otro proceso y otro proyecto** (`docs/multisesion.md` §"Ver qué está pasando"). Hasta ahora todo lo que pintaba el plugin se resolvía desde el `cwd` de la sesión, así que una sesión interactiva no veía nada de un pipeline lanzado con `claude -p` sobre otro checkout.
  - Índice global de ejecuciones `~/.claude/sdd/active-runs.json` que mantiene `hooks/sdd-activity-log.sh` bajo lock: una entrada por **checkout principal** (clave `root`, nunca el nombre de sesión) con `{root, project, stage, skill, started_at, last_seen, agents, state, sessions}`; se borra al terminar la última sesión de ese root y nunca registra proyectos sin `pipeline-state.json` ni `.sdd/`.
  - `scripts/sdd-status-line-global.sh`: status line **de usuario** (`SDD ▸ todo-app  5/7 done · task-generator 12m 30s · 3 agentes`, con `· sin latido (>90s)` y `· terminado`), con `~/.claude/sdd/watch-target` para fijar el proyecto vigilado. Silencio absoluto sin runs; < 0,2 s. Se instala con `scripts/install-global-statusline.sh` (copia a la ruta estable `~/.claude/sdd/status-line.sh` y escribe `statusLine` en el settings del usuario con copia de seguridad; `--uninstall` lo revierte) y se ofrece como paso 3b opcional de `/sdd-setup`.
  - Comando `/sdd-watch`: una línea por run vivo (`scripts/sdd-watch.sh --brief` sin argumentos recorre el índice; con una ruta, ese checkout).
  - Hook `UserPromptSubmit` (`hooks/sdd-runs-line.sh`): al escribir un prompt, una línea de `systemMessage` por run vivo (`SDD ▸ todo-app 5/7 · task-generator 12m · 3 agentes · último evento 40s`), silencio si no hay ninguno.
- Evento `skill-end` en `.sdd/activity.jsonl` (`skill`, `seconds`, `reason`), emitido por `Stop` y `SessionEnd`.

### Fixed
- **La barra perdía la skill y el reloj a mitad de etapa** (medido: 14 de los 19 minutos de una etapa): `scripts/sdd-status-line.sh` y `scripts/sdd-watch.sh` trataban cualquier `stop` como fin de skill, pero `Stop` se dispara al final de CADA turno y una skill que pregunta al humano sigue en curso. Ahora cierran con `skill-end` (y `session-end` como respaldo). El cierre es conservador: en `SessionEnd` siempre; en `Stop` solo si la sesión es headless (`claude -p`, detectado por `entrypoint` en `~/.claude/sessions/*.json`) o si lleva más de `SDD_SKILL_IDLE_SECS` (900 s) sin eventos.

## [4.1.1] - 2026-08-27

## [4.1.0] - 2026-08-27

### Added
- **Paralelismo como contrato de la skill en todo el pipeline** (`docs/perfilado.md` §"Paralelismo por etapa"): `sdd-specifications-engineer` (carriles de 2-3 requisitos + carril transversal, con catálogo de ids y esqueletos de WF/ADR fijados antes en el hilo principal), `sdd-task-generator` (un subagente por FASE; índice, orden y validaciones globales en el principal), `sdd-task-implementer` (tasks `[P]` en lotes de 4, sin commitear) y `sdd-test-planner` (además de las matrices, los tiers Critical/Full de E2E cuando son el camino crítico). Flags `--fanout`/`--parallel` y `--sequential` en todas; `metrics.mode` y el número de agentes en Persist Summary.

### Fixed
- Presupuesto de `plan/` escalado también por Stream de trabajo (`+4 000` por Stream adicional): el exceso medido estaba concentrado en la FASE con dos Streams, no repartido. El smoke tolera un 15 % antes de avisar.
- `scripts/check-paths.sh` fallaba dentro de un worktree enlazado (ahí `.git` es un fichero con ruta absoluta).


## [4.0.3] - 2026-08-27

### Fixed
- **El fan-out no se activaba en la práctica**: la instrucción de la skill se leía como una preferencia frente a la política del entorno sobre lanzar subagentes. `sdd-spec-auditor` y `sdd-test-planner` declaran ahora que los auditores/generadores paralelos son **parte del contrato de la skill** (lectura sola, acotados, sin anidar), con la evidencia medida, y añaden el flag `--fanout` (y `--sequential` para forzar un hilo). El motivo de cualquier degradación queda en `metrics.mode` y en `summary.highlights`.
- Presupuesto total de `plan/` escalado por FASE (`34 k + 17 k por FASE`) en vez del techo plano de 70 k: con 3 FASEs la ejecución real dio 88 k cumpliendo todos los presupuestos por fichero. Se reporta `metrics.plan_budget_chars`.
- Fan-out con coste acotado: por encima de 8 k chars, cada auditor también trabaja por secciones con el índice en vez de leer el documento entero.

### Added
- `tests/e2e/20-smoke.sh` comprueba (como aviso, no fallo) que la auditoría corrió en fan-out y que las matrices se generaron en subagentes, y que `plan/` respeta su presupuesto; la etapa de auditoría se invoca con `--fanout`.
- `docs/medidas.md`: comparación 4.0.0 → 4.0.2 en el mismo proyecto (2 h 46 → 1 h 39, −40 %; salida por etapa −51/−67 %).


## [4.0.2] - 2026-08-27

### Changed
- `subagentStatusLine`: cada fila muestra el modelo del subagente y su actividad actual (`label`), además de descripción, tiempo y tokens.

## [4.0.1] - 2026-08-27

### Added
- Visibilidad en la consola: hook `sdd-activity-log` (`.sdd/activity.jsonl`: sesiones, skills, agentes y subagentes, paradas), status line con `refreshInterval: 5` que muestra rol, etapas, skill en curso, minutos y subagentes activos, `subagentStatusLine` con tipo · descripción · tiempo · tokens por subagente (instalados por `/sdd-setup`), y panel de terminal `scripts/sdd-watch.sh`.
- `scripts/sdd-profile.sh` y `docs/perfilado.md`: perfilado de una skill (duración, turnos, tokens, herramientas, volumen leído/escrito).
- `sdd-up.sh`: `SDD_CLAUDE_ARGS` (p. ej. `--plugin-dir`), worktrees por defecto en `.claude/worktrees/<rol>` (heredan la confianza de carpeta), espera al prompt antes de `/color` y detecta el diálogo de confianza.
- `tests/e2e/50-streams.sh`: FASE por Streams en dos worktrees con roles + `--integrate` + bench; `docs/medidas.md` con las ejecuciones reales.

### Changed
- Rendimiento de las etapas largas: `sdd-spec-auditor` con informe compacto (≤ 25 k chars), fan-out por dimensión en 4 subagentes sonnet y lectura por índice (21,4 → 9,9 min de pared, informe −75 %); `sdd-specifications-engineer` sin redundancia y con presupuesto por artefacto (−55 % de salida estimado); `sdd-test-planner` (matrices densas por UC en subagentes sonnet, E2E por niveles) y `sdd-plan-architect` (lectura por índice, RESEARCH solo bajo demanda, sección obligatoria "Módulos y Conjuntos de Escritura"); subagentes `[P]` del implementer con `model: sonnet` salvo `CLAUDE_CODE_SUBAGENT_MODEL`.
- `sdd-lead` posee el write-set de integración (las tasks de verificación de `--integrate` escriben en `tests/`, `.github/` y configuración).

### Removed
- `skills/sdd-specifications-engineer/scripts/create-spec-structure.ps1` (obsoleto).

## [4.0.0] - 2026-08-25

### Repositorio unificado `noelserdna/sdd-pipeline`

**Breaking**
- Nuevo id de plugin: `sdd-pipeline@noelserdna` (antes `sdd@noelserdna-claude-plugin-sdd` y `sdd-pipeline@sdd-pipeline-local`). Desinstala el antiguo antes de instalar (ver `docs/migracion.md`).
- Los hooks los aporta el plugin (`hooks/hooks.json` con `${CLAUDE_PLUGIN_ROOT}`); `sdd-setup` ya no copia hooks ni agentes al proyecto. `pipeline-state.json` pasa a `hooksVersion: 3`.
- `version:` desaparece del frontmatter de las skills; la única fuente de versión es `.claude-plugin/plugin.json`.

**Added**
- Fusión de `sdd-skills` (upstream), `claude-plugin-sdd` (empaquetado) y el fork `sdd-pipeline`: 24 skills (incluido el bloque brownfield y la nueva `sdd-lead`), 5 agentes (`sdd-orchestrator`, `sdd-pipeline-auditor`, `sdd-context-keeper`, `sdd-constitution-enforcer`, `sdd-cross-auditor`), dashboard agrupado por fases, gap-detector con revisión humana.
- Servidor MCP como bundle único `server/dist/server.js` (esbuild, sin `node_modules`), versión inyectada en build, tests (`npm test`).
- Validación y CI: `scripts/validate-plugin.mjs`, `check-paths.sh`, `check-version.sh`, `tests/hooks`, `tests/e2e`, GitHub Actions (ubuntu + macos, node 18/22).
- `examples/todo-app/`: proyecto de juguete con requisitos aprobados para las pruebas E2E.
- `docs/legacy/INVENTARIO.md`, `docs/coste-contexto.md` (always-on ~3.4k tok con 24 skills + 5 agentes tras recortar las descripciones a ≤ 350 chars), `docs/medidas.md` (smoke real: ~2 h 45 min hasta FASE-0 implementada sin intervención humana).
- **Multi-sesión**: `SDD_ROLE` como identidad de sesión (`.claude/sdd-sessions.json`, `templates/sdd-sessions.example.json`); hooks con dos raíces (`PROJECT_DIR` del worktree, `STATE_ROOT` común por `git-common-dir`) y lock portable (`hooks/lib/sdd-common.sh`); H1 muestra rol, pares vivos y último handoff y exporta `SDD_PLUGIN_ROOT`/`SDD_STATE_ROOT`; H2 aplica la posesión por rol; status line con `[rol]`.
- **Streams**: `sdd-task-generator` Phase 3b (tabla *Stream Ownership*, `Streams:` en TASK-ORDER, V-15..V-18, G-04 HALT); `sdd-task-implementer` Mode 7 `--fase N --stream X` (worktree, sin tags, Phase 9-S) y Mode 8 `--integrate --fase N` (`references/integration-protocol.md`); freno `stale` antes de cada task; eventos de medición y `scripts/sdd-bench.sh`.
- **Coordinación**: skill `sdd-lead` (despacho tras cada puerta humana, recepción de handoffs, respuestas), `references/handoff-protocol.md` (paso Handoff en 12 skills, `summary.handoff` en pipeline-state), `references/async-questions.md` (preguntas bloqueantes a `.sdd/questions-<rol>.md`), `scripts/sdd-up.sh` (tmux + `claude -n` + `/color`).
- `sdd-setup` reducido al modelo plugin: estado, hook git `commit-msg` (`scripts/install-git-hooks.sh`), política `.gitignore`, status line opcional, `--multisession`, detección de instalaciones antiguas; `scripts/migrate-hooks-v3.sh`.
- `scripts/release.sh` (versión única en `plugin.json`), `tests/setup`, `tests/bench`, `tests/e2e/{20-smoke,30-multisession,40-migration}`, `docs/{instalacion,migracion,multisesion,pruebas-manuales,archivado}.md`.

**Changed**
- Hook H5 (`sdd-augment-hook.js`) ya no se dispara en `Grep|Glob`.
- Comandos `/sdd:<skill>` → `/sdd-<skill>` en docs y en el servidor MCP.

**Removed**
- `install-sdd-automation.sh`, `automation/INSTALL.md`, `settings-template.json`, rutas del autor (`~/programacion/sdd-skills`, cache `noelserdna-plugins`).


## [3.1.0] - 2026-03-16

### Added
- **Pipeline Status Line**: Always-visible pipeline progress at the bottom of Claude Code CLI (`scripts/sdd-status-line.sh`). Shows active stage, completion count, stale/error warnings. Zero API cost, display-only. Installed opt-in via `/sdd-setup` Step 5.7.5.
- **Dashboard: Functional & E2E test stages**: Pipeline bar now shows two new stages — `functional-tests` and `e2e-tests` — after `task-implementer`, with auto-derived status and counts from scanned test files.
- **Dashboard: E2E test discovery**: `scan_test_refs()` now detects E2E tests via directory (`e2e/`, `playwright/`, `cypress/`) and filename (`*.e2e.ts`, `*.pw.ts`) conventions. Each test ref carries `testType: "e2e"|"functional"`.
- **Dashboard: test_stats breakdown**: 6 new fields in `testStats` — `functionalFiles`, `functionalTests`, `functionalWithRefs`, `e2eFiles`, `e2eTests`, `e2eWithRefs`.

### Fixed
- **Dashboard: codeRefs/testRefs propagation to REQs**: New `propagate_refs_to_req_artifacts()` BFS fills `codeRefs`/`testRefs` on REQ nodes from downstream artifacts (UC, INV, API). Previously, REQs showed ✗ in Code/Test columns despite having transitive coverage. Propagated refs marked with `origin: "propagated"`.
- **H3 (pipeline-state-updater)**: Now transitions `done → running` when new artifact writes are detected. Previously, stages marked "done" stayed "done" even when actively writing files, causing false `SDD [7/7] OK` status during ongoing implementation.

## [2.3.0] - 2026-03-05

### Added
- **Commit-based traceability inference**: Enriches code coverage automatically from git commit trailers (`Refs:`, `Task:`) — no manual `// Refs:` comments needed
  - 4 origin states: `linked` (direct), `inferred` (commit), `suggested` (task-only), `uncovered` — with shape+color+text for colorblind accessibility
  - Single `git log --all --name-only` call with null-byte delimiters (~0.5s vs 160s for per-commit approach)
  - BFS N-hop propagation (max depth 3) replaces 1-hop for REQ coverage chains
  - Manual overrides via `.sdd/overrides.json` (pin/suppress operations)
- **Graph schema v6**: Backward-compatible extension with `origin`, `inferredFrom`, `files[]`, inference stats on `codeStats`
- **code-index Phase 4.5**: Commit-Symbol Bridge — maps git diff hunks to symbol ranges for symbol-level inference
- **traceability-check Step 5b**: Inferred Reference Verification — validates commit SHAs, file freshness, task linkage; classifies as valid/stale/broken

### Fixed
- **dashboard**: Pipe delimiter in `scan_commits()` broke when commit subject contained `|` — now uses `%x00` null bytes
- **dashboard**: `Refs:` regex captured prose from commit body — now uses `%(trailers:key=Refs,valueonly)`
- **dashboard**: Ref ID validation accepted any string — now validates against `ARTIFACT_ID_RE` pattern
- **dashboard**: ZeroDivisionError when `total_functional_reqs` is 0
- **dashboard**: `open(file, "w")` truncated immediately on crash — now uses tempfile + `os.replace()` for crash-safe writes

### Changed
- **dashboard generate.py**: Rewritten `scan_commits()`, new `infer_code_refs_from_commits()`, `propagate_refs_to_reqs()` (BFS), `apply_overrides()`, `_refine_with_code_intelligence()`
- **dashboard html-template**: 4-state origin indicators (Linked/Inferred/Suggested/Uncovered) with shape+color+text, inference paths, legend
- **MCP server**: Updated TypeScript types (`origin`, `inferredFrom` on CodeRef, `files` on CommitRef), coverage tool shows inference breakdown, trace tool includes origin, context tool separates direct vs inferred refs
- **dashboard SKILL.md**: Documents inference engine and 5 origin types
- **graph-schema.md**: Schema v6 with migration notes from v5

## [2.2.0] - 2026-03-04

### Added
- **tech-designer** (v1.0.0): New lateral skill — 12-dimension technical architecture exploration (delivery channels, architecture style, tech stack, data strategy, auth, API, infrastructure, CI/CD, observability, cost, DX, i18n). Outputs `design/TECHNICAL-DESIGN.md`, `design/QUALITY-ATTRIBUTES.md`, `design/ADR-DRAFT-*.md`. ATAM-lite quality attribute analysis.
- **ux-designer** (v1.0.0): New lateral skill — 12-dimension UI/UX design system (brand, tokens, components, responsive, accessibility, interaction, forms, navigation, frontend security, performance, mobile, theming). Outputs `ux/UI-DESIGN-SYSTEM.md`, `ux/WIREFRAMES.md`, `ux/ACCESSIBILITY-SPEC.md`, `ux/INTERACTION-MODEL.md`, `ux/DESIGN-TOKENS.json`. WCAG 2.1 AA compliance.
- **GUIA-PASO-A-PASO.md**: Step-by-step guide in Spanish for new users

### Fixed
- **dashboard**: Tolerate `[x]` in TASK headings and fix multi-ref context bug
- **dashboard**: Use summary metrics fallback when artifact count is 0
- **dashboard**: Infer domain/layer from title for generic REQ prefixes
- **dashboard**: Use functional-only denominators for implementation coverage metrics
- **Install command**: Fixed installation instructions (`/plugin marketplace add` + `/plugin install`)
- **marketplace.json**: Version synced to match plugin.json (was 1.8.0, now 2.2.0)

### Changed
- **plan-architect** (v1.2.0): Phase 2.0 System Vision Gate, Phase 2.9 Coverage Gate, 13 clarify categories (+CL-UI, CL-DX, CL-ENV), consumes `design/` and `ux/` directories
- **cascade-patterns.md**: Includes tech-designer and ux-designer as lateral stages
- **graph-schema.md**: Includes tech-designer and ux-designer in lateralStages
- Plugin version bumped from 2.1.0 to 2.2.0 (22 skills)

## [2.0.0] - 2026-03-01

### Added
- **MCP Server** (`server/`): TypeScript server exposing the SDD traceability graph via Model Context Protocol
  - 5 tools: `sdd_query` (text search with scoring), `sdd_impact` (BFS blast radius by depth), `sdd_context` (360° artifact view), `sdd_coverage` (gap analysis by domain/layer), `sdd_trace` (full chain traversal REQ→...→TEST with break detection)
  - 7 resources via `sdd://` protocol: `pipeline/status`, `pipeline/stages`, `artifacts/{type}`, `artifacts/{type}/{id}`, `graph/schema`, `graph/stats`, `coverage/gaps`
  - 2 workflow prompts: `analyze_impact` (pre-change workflow), `generate_status_report` (pipeline health)
  - Next-step hints on every tool response (GitNexus pattern)
  - Reads `dashboard/traceability-graph.json` with file watcher and graceful degradation
  - Registered via `.mcp.json` at plugin root
- **Context Augmentation Hook** (`hooks/sdd-augment-hook.js`): PreToolUse hook injecting SDD traceability context
  - Intercepts: Grep, Glob, Read, Edit, Write
  - Matches by file path (codeRefs), artifact ID patterns (regex), and symbols (code intelligence)
  - Formats: traceability chain, coverage status, last commit, callers/callees/processes when code intelligence available
  - Silent failure — never breaks tool calls
- **Code Index Skill** (`skills/code-index/` v1.0.0): GitNexus bridge for deep code intelligence
  - Modes: Full (GitNexus AST), Lite (regex, no call graph), Status, Refresh
  - Maps GitNexus symbols to SDD artifacts via `Refs:` annotations and transitive inference (max depth 2, confidence ≥0.7)
  - Enriches `traceability-graph.json` with `codeIntelligence` block (symbols, callGraph, processes, stats)
  - Reference: `bridge-patterns.md` (mapping rules, confidence calculation, community→domain mapping)
- **Graph Schema v4** (`graph-schema.md`): backward-compatible extension for code intelligence
  - New block: `codeIntelligence` with `symbols[]`, `callGraph[]`, `processes[]`, `stats`
  - New fields: `codeRefs[].inferred` (boolean), `codeRefs[].confidence` (0-1)
  - New relationship type: `inferred-implements`
  - Absent by default — all existing dashboards work without changes

### Changed
- **req-change**: New Step 8 "Code Intelligence Impact Analysis" — uses `sdd_impact` for symbol-level blast radius when MCP server available, with fallback to existing git log approach
- **traceability-check**: New Step 5.5 "Code & Test Chain Verification" — validates codeRef/testRef existence, detects orphaned annotations and uncovered code paths
- **reconcile**: New Phase 2 Step 5 "Code Intelligence Enrichment" — uses MCP server for scalable code scan instead of manual file-by-file reading
- **dashboard**: Enhanced Step 5 with code intelligence — uses `codeIntelligence.symbols[]` for precise data when available, adds `inferred-implements` relationships
- Plugin version bumped from 1.8.0 to 2.0.0

## [1.8.0] - 2026-03-01

### Dashboard v5 — Interactive Prompts & Live Status (Phase 1)
- **Contextual Prompt Generation**: `getStagePrompt()` and `getNextAction()` produce Spanish-language, context-aware prompts based on pipeline state and coverage gaps — paste directly into Claude Code
- **Copy-to-Clipboard**: All prompts have "Copy" buttons with toast notification feedback (clipboard API with fallback)
- **Next Action Card**: Prominent card at top of Summary view showing the single most important next step with reason and copy-ready prompt
- **Hero Recommendation Copy Buttons**: Each recommendation in the Health Score hero now has a copy button with a full contextual prompt (not just "/sdd:X" commands)
- **Pipeline Stage Popovers**: Click any pipeline stage to see popover with status, last run date, artifact count, stage-specific prompt with copy button, and "Filter by Stage" action
- **Activity Feed Panel**: Scrollable feed in Summary view showing real-time pipeline activity entries with timestamps, stage names, and status icons
- **JSONP Live Status Polling**: Loads `./live-status.js` every 5 seconds via `<script>` tag injection (works with `file://` protocol, no server needed)
  - `window.__SDD_LIVE_UPDATE(data)` callback updates activity feed and pipeline indicators
  - Live dot indicator: pulsing green (active), yellow (stale), hidden (no file)
  - Stale detection: heartbeat >60s + status=running shows "Possibly stalled" warning
  - Graceful degradation: silent no-op on 404, live dot hidden after 3 failures, race condition guard via timestamp comparison
- **New reference**: `live-status-template.md` — JSONP schema, field reference, idle seed template, skill integration instructions
- **SKILL.md v4.0.0**: New Step 9.5 "Generate Live Status Seed File" writes `dashboard/live-status.js` on dashboard generation
- **New output**: `dashboard/live-status.js` (JSONP seed file for live activity feed)
- **7 new CSS components**: `.toast`, `.copy-btn`, `.next-action-card`, `.prompt-block`, `.activity-panel`/`.activity-feed`, `.stage-popover`, `.live-dot`

## [1.7.0] - 2026-03-01

### Dashboard v4.0.0
- **Bug fixes**: 3 CRITICAL (pipeline null crash, NaN stats, XSS in summary), 4 HIGH (undefined file, NaN gaps, filter conflict, ARIA), 3 MEDIUM (empty missing render, sticky CSS, misleading coverage pct)
- **Visual modernization**: Shadow system, gradient background, Inter font, SVG health ring chart, improved progress bars, CSS pipeline arrows, view transitions, staggered animations, custom tooltips, bento summary grid, styled scrollbars, focus-visible styles
- **Adoption view**: New 5th tab showing onboarding status — journey stepper, scenario card, health dimensions, findings panel, reconciliation panel, import panel; graceful empty states per sub-panel
- **Schema v3**: New `adoption` block with `onboarding`, `reverseEngineering`, `reconciliation`, `import` sub-blocks; new `adoptionStats` in statistics; backward-compatible (defaults to `{ present: false }`)
- **SKILL.md v3.0.0**: New Step 2.5 scanning onboarding artifacts (5 report types from 5 directories); updated Step 8 assembly and Step 10 report for v3

### Guide v2.0.0
- **3-part structure**: Part 2 "Adopting SDD in Existing Projects" (new)
- **Onboarding skills**: Brownfield decision tree, 8 project scenarios table, 4 skill descriptions (onboarding, reverse-engineer, reconcile, import)
- **Adoption View section**: Journey stepper, scenario card, dimensions, findings, reconciliation, import panels
- **Updated traceability chain**: 11 nodes (added COMMIT with orange styling)
- **Updated pipeline skills**: 19 skills count, commit traceability references
- **Expanded glossary**: 18 new terms (COMMIT, SHA, Brownfield, Greenfield, Scenario, Drift, Reconciliation, finding markers, Health Score, Blast Radius, Coverage Map, ISO 14764)

## [1.6.0] - 2026-03-01

### Added
- **4 Onboarding Skills** for adopting SDD in existing projects (brownfield, drift, migration scenarios)
  - **`onboarding`** (v1.0.0): Project detector and SDD adoption planner
    - 7-phase diagnostic: environment check, SDD artifact scan, non-SDD doc scan, code/test analysis, scenario classification, health score estimation, action plan generation
    - 8 scenarios: greenfield, brownfield bare, SDD drift, partial SDD, brownfield with docs, tests-as-spec, multi-team, fork/migration
    - Health score 0-100 with per-dimension breakdown (requirements, specs, tests, architecture, traceability, code quality, pipeline state)
    - Modes: default (full), `--quick`, `--reassess`
    - Output: `onboarding/ONBOARDING-REPORT.md`
    - References: `detection-matrix.md` (25+ signals, weighted classification matrix), `action-plan-templates.md` (8 scenario templates with effort/health projections)
  - **`reverse-engineer`** (v1.0.0): Code to SDD artifact generator
    - 10-phase process with 2 user checkpoints (after inventory/analysis, after artifact generation)
    - Generates complete SDD artifacts: requirements (EARS syntax), specs, test plan, architecture plan, retroactive tasks, findings report
    - Findings taxonomy with 7 markers: `[DEAD-CODE]`, `[TECH-DEBT]`, `[WORKAROUND]`, `[INFRASTRUCTURE]`, `[ORPHAN]`, `[INFERRED]`, `[IMPLICIT-RULE]`
    - Language-specific analysis patterns: TypeScript, Python, Rust, Go, Java
    - Modes: default (full), `--scope=paths`, `--inventory-only`, `--continue`, `--findings-only`
    - Output: `requirements/`, `spec/`, `test/`, `plan/`, `task/`, `findings/`, `reverse-engineering/`
    - References: `code-analysis-patterns.md`, `requirement-extraction-heuristics.md`, `findings-taxonomy.md`, `retroactive-task-template.md`
  - **`reconcile`** (v1.0.0): Spec-code drift detection and alignment
    - 8-phase process: context loading, code scan, spec-code comparison, divergence classification, reconciliation plan, user review, apply changes, pipeline state update
    - 6 divergence types: `NEW_FUNCTIONALITY` (auto), `REMOVED_FEATURE` (auto), `BEHAVIORAL_CHANGE` (ask), `REFACTORING` (auto), `BUG_OR_DEFECT` (ask), `AMBIGUOUS` (ask)
    - Automatic resolution for safe types; user decision for ambiguous cases
    - Modes: default (full), `--dry-run`, `--scope=paths`, `--code-wins`
    - Output: `reconciliation/RECONCILIATION-REPORT.md` + updated specs/requirements
    - References: `divergence-classification.md`, `reconciliation-strategies.md`, `reconciliation-report-template.md`
  - **`import`** (v1.0.0): External documentation to SDD format converter
    - 7-phase process: format detection, parse input, mapping preview, user confirmation, generate SDD artifacts, quality check, pipeline state update
    - 6 formats supported: Jira (JSON/CSV), OpenAPI/Swagger (YAML/JSON), Markdown, Notion (markdown/CSV), CSV, Excel (.xlsx)
    - Auto-detect format with content inspection fallback
    - EARS syntax conversion from user stories, imperative statements, conditionals, API descriptions
    - Modes: default (auto-detect), `--format=TYPE`, `--target=requirements|specs|both`, `--merge`
    - Output: `requirements/`, `spec/`, `import/IMPORT-REPORT.md`
    - References: `format-parsers.md`, `mapping-rules.md`, `import-report-template.md`

## [1.5.0] - 2026-02-28

### Added
- **Commit Traceability Integration**: commits are now a first-class link in the SDD traceability chain
  - Extended chain: `REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST`
  - task-implementer Phase 7: SHA capture via `git rev-parse --short HEAD` after each atomic commit
  - task-implementer Phase 8: progress reports include SHA (`→ commit abc1234`)
  - task-implementer Phase 9: completion report includes full commit log table (Task/SHA/Message/Refs)
  - CHECK-C03: full implementation procedure (search by Task trailer → fallback subject → verify file scope → graceful degradation)
  - commit-conventions.md: new "SHA Capture & Traceability" section documenting the extended chain
  - Dashboard graph schema: `commitRefs[]` on artifacts, `implemented-by-commit` relationship type
  - Dashboard statistics: `commitStats` (totalCommits, commitsWithRefs, commitsWithTasks, uniqueTasksCovered) and `reqsWithCommits` coverage metric
  - Dashboard Step 5.5: "Scan Commit References" — scans git log for `Refs:` and `Task:` trailers, builds commitRef objects, propagates to REQs
  - Dashboard HTML: "Commits" and "Requirements with Commits" stat cards, progress bar in Summary view, commit stats in Code Coverage view
  - traceability-check Step 5: "Commit Chain Verification" — TASK→commit mapping, gap detection (tasks without commits, commits without refs, broken refs), commit coverage metric
  - traceability-patterns.md: TASK ID pattern (`TASK-F\d{1,2}-\d{3,4}`), "Commit Reference Patterns" section (Task/Refs trailers, git log extraction)
  - req-change Phase 2 step 7: "Commit Impact Analysis" — artifact→commits→files blast radius estimation via git log

### Changed
- Dashboard schema remains v2 (backward compatible): `commitRefs` defaults to `[]`, `commitStats` to zeros
- All git checks include graceful degradation (skip if not inside a git repository)
- Session Report table expanded with SHA and Commit Message columns

## [1.4.0] - 2026-02-28

### Added
- **SDD System Guide**: self-contained HTML documentation page (`guide.html`) generated alongside the dashboard
  - Part 1: Full SDD system documentation (9 pipeline skills, traceability chain, automation hooks/agents, utility skills)
  - Part 2: Dashboard interpretation guide (all views, metrics, health score formula, color legend, glossary)
  - Sticky sidebar navigation with scroll-spy active tracking
  - Same dark theme as dashboard, responsive at 768px
  - "Guide" button in dashboard header linking to `guide.html`; "Back to Dashboard" link in guide
  - New reference: `guide-template.md`
- **Per-file Test Coverage Map** across pipeline skills
  - plan-architect: Coverage Map §7.4 in FASE templates (source file → test file mapping with classification)
  - task-generator: 1 test task per source file from Coverage Map; new validations V-13, V-14
  - task-implementer: per-file coverage verification (0% = CRITICAL, <80% domain logic = WARNING), coverage in completion report
  - New verification dimension: Dimension 4 (Coverage) with CHECK-COV-01 through CHECK-COV-04

### Changed
- Dashboard SKILL.md Step 9 now generates both `index.html` and `guide.html`
- Dashboard output artifacts: added `dashboard/guide.html`

## [1.3.0] - 2026-02-28

### Changed
- **Dashboard v3.0.0 — Comprehension Dashboard**: UX overhaul for non-technical stakeholders
  - New Executive Summary view as default tab: coverage progress bars, top gaps, artifact breakdown, pipeline status
  - Health Score hero banner: weighted letter grade (A-F) with actionable recommendations
  - Humanized all labels: UC → Use Cases, WF → Workflows, BDD → Acceptance Tests, INV → Business Rules, ADR → Decisions
  - Status labels: Full → Complete, Partial → In Progress, Spec Only → Specified, Untraced → Not Started
  - Color legend below stats cards for status dot meanings
  - WCAG AA contrast fixes: improved --text2, --text3, --yellow, --gray color values
  - Contextual tooltips on all stats cards and zero-count matrix cells
  - Responsive hero banner (column layout on mobile)
  - No schema changes — all improvements are UI/presentation only

## [1.2.0] - 2026-02-27

### Changed
- **Dashboard v2.0.0 — Comprehension Dashboard**: Major upgrade to the traceability dashboard skill
  - Traces REQs to source code: scans `src/` for `Refs:` comments in JSDoc, inline comments, and decorators
  - Traces REQs to tests: scans `tests/` for artifact references in test descriptions and file headers
  - Auto-classifies REQs by business domain (from prefix), technical layer (from FASE), and functional category (from section headers)
  - New graph schema v2: `codeRefs[]`, `testRefs[]`, `classification{}` on artifacts; `codeStats`, `testStats`, `classificationStats` in statistics
  - New relationship types: `implemented-by-code` (code→artifact), `tested-by` (test→artifact)
  - New HTML dashboard views: Matrix (enhanced), Classification (domain grouping), Code Coverage (file-level detail)
  - Redesigned detail panel with 5 tabs: Story (narrative), Trace Chain, Code, Tests, Documents
  - New filters: Domain, Layer, Category dropdowns
  - New status calculation: Full (REQ+UC+BDD+TASK+Code+Tests), Partial, Spec Only, Untraced
  - Symbol extraction from code: functions, classes, consts with fallback to filename:line
  - Test framework detection: vitest, jest, pytest, jasmine
  - Reference documents updated: `id-patterns-extended.md`, `graph-schema.md`, `html-template.md`

## [1.1.0] - 2026-02-27

### Added
- New utility skill: `dashboard` — generates a visual HTML traceability dashboard from SDD pipeline artifacts
  - Scans all pipeline directories for artifact definitions (REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK)
  - Extracts cross-references and relationship types (implements, verifies, orchestrates, etc.)
  - Builds `dashboard/traceability-graph.json` with full artifact graph and statistics
  - Generates self-contained `dashboard/index.html` (no external dependencies)
  - Interactive features: pipeline status bar, traceability matrix, filters, detail panel
  - Extended ID patterns supporting compound IDs (REQ-EXT-001, INV-SYS-001, API-pdf-reader)
- Reference documents: `id-patterns-extended.md`, `graph-schema.md`, `html-template.md`
- New agent: Requirements Watcher (A4) — detects changes in requirements since last dashboard generation
- New agent: Spec Compliance Checker (A5) — verifies src/ implements what spec/ declares
- New agent: Test Coverage Monitor (A6) — calculates % of REQs with BDD/test coverage
- New agent: Traceability Validator (A7) — suspect link detection inspired by IBM DOORS
- New agent: Pipeline Health Monitor (A8) — health score 0-100 with actionable recommendations
- New utility skill: `sync-notion` — bidirectional sync of SDD artifacts with Notion databases
  - Push: creates/updates Notion databases with relations for REQ, UC, WF, API, BDD, INV, ADR, TASK
  - Pull: detects Notion changes and applies them to local markdown (with confirmation)
  - Rate-limited API calls (3 req/s), idempotent push, conflict resolution
  - Reference documents: `notion-schema.md`, `sync-protocol.md`

## [1.0.0] - 2026-02-07

### Added
- Initial plugin release migrated from sdd-skills repository
- 9 pipeline skills: requirements-engineer, specifications-engineer, spec-auditor, test-planner, plan-architect, task-generator, task-implementer, security-auditor, req-change
- 3 utility skills: pipeline-status, traceability-check, session-summary
- 1 setup skill: setup (initializes pipeline-state.json)
- 3 agents: constitution-enforcer (A1), cross-auditor (A2), context-keeper (A3)
- 4 hooks: session-start (H1), upstream-guard (H2), state-updater (H3), stop-hook (H4)
- SDD Constitution as shared reference
- All skills namespaced under `sdd:` (e.g., `/sdd:requirements-engineer`)
