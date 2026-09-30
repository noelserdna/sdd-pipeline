# Plan de implementación 5.1

Fuente: `docs/MEJORAS-SDD-5.1.md` (propuesta) y `docs/MEJORAS-SDD-5.1-ANALISIS.md` (verificación y diseño). Este
documento fija el reparto de trabajo y los **contratos compartidos**, para que los paquetes se implementen en paralelo
sin pisarse. Todo lo que un paquete necesita de otro está en la sección 2; si un agente necesita algo que no está aquí,
lo decide dentro de su paquete y lo anota en su informe.

Rama de integración: `feat/v5.1-evidence-adversarial`. Cada paquete trabaja en su worktree y su rama y hace commits
atómicos. Integración con merge `--no-ff`. No se sube versión ni se crea tag en este plan.

## 1. Decisiones por defecto (revisables)

| Tema | Decisión |
|------|----------|
| Evidencia visual en REQ-F | Obligatoria: captura por criterio y vídeo por workflow de cara al usuario (`FASE-N` cuando la FASE no nombra workflows). Sin ella, el criterio queda `unshown` y el requisito no es VERIFIED |
| Dónde | `evidencias/` en la raíz del proyecto, fuera de git (bloque gestionado de `templates/gitignore.sdd`) |
| REQ-F sin pantalla propia | Captura de la pantalla donde se ve el efecto; sin exención |
| Puerta adversarial | `adversarial_gate: enforce` por defecto: un hallazgo abierto en un Must impide la firma |
| Jev en la ronda adversarial | Solo prioriza criterios y elige la muestra de limpios que se contraverifica. Nunca juzga ni decide |
| Contraverificación | Todos los hallazgos, más una muestra de veredictos limpios elegida por prioridad |
| Marcador «ve X» | THEN que empieza por «el usuario ve» / «the user sees», fijado en requirements; el léxico ES/EN solo propone candidatos |
| Replay | En toda operación de escritura, salvo exención justificada en §3 del TEST-PLAN |
| Árbol sucio | Error con `--junit-sha` y en `accept record`/`measure` (salvo `--allow-dirty`); aviso sin `--junit-sha` |
| `fase-acceptance` | Sigue caducando solo por el texto del requisito (sin cambio) |
| `test_slots` | Convención documental, sin lock |
| `CONTRACT-` | Solo puertos hacia sistemas externos |
| Smoke GitHub | Plantilla con `workflow_call`, documentando `workflow_run` como alternativa |

## 2. Contratos compartidos

### 2.1 Claves nuevas del SDD Stack Profile

| Clave | Valores | Defecto | Lee |
|-------|---------|---------|-----|
| `visual_evidence` | `required \| warn \| off` | `required` | CLI de aceptación, test-planner, implementer |
| `evidence_dir` | ruta | `evidencias` | CLI, implementer, kits |
| `adversarial_gate` | `off \| warn \| enforce` | `enforce` | CLI (`sdd gate`), sdd-acceptance |
| `test_slots` | entero | `2` | implementer, lead, sdd-acceptance `--adversarial` |
| `staging_url` | URL o `none` | `none` | plantillas smoke, test-planner |
| `smoke` | comando o `none` | `none` | plantillas smoke |
| `smoke_report_path` | ruta | `.sdd/junit/smoke` | plantillas smoke (la CLI lee solo `test_report_path`) |
| `env_required` | lista de nombres | vacío | implementer (compara las variables de cada tarea; falta una → `IF-` `ENV-REQUIRED`), tech-designer (propone los nombres; los escribe una persona) |
| `deploy` | texto informativo | `none` | nadie la ejecuta |

El parser (`scripts/lib/git-log.mjs` `stackProfile`) es genérico: no hay que tocarlo. `stack-profile.md` §1 las documenta.

### 2.2 Evidencia visual

- Rutas: `evidencias/FASE-{N}/{AC-NNN-NN | REQ-F-NNN-ACn}.png` y `evidencias/FASE-{N}/{WF-NNN | FASE-N}…webm` (el id en el nombre)
  (también se aceptan `.mp4` y `.jpg`).
- Playwright de la suite de aceptación: `screenshot: 'on'`, `video: 'on'`, y el test adjunta la captura final con
  `testInfo.attach(name, { path })`, de modo que el JUnit lleva `[[ATTACHMENT|ruta]]` en `<system-out>`.
- El ledger guarda por adjunto `{ path, sha256, bytes, kind: image|video|trace|other, present }`.
- Regla del ledger: con `visual_evidence: required`, un criterio de un `REQ-F` en `pass` sin ningún adjunto `image`
  presente pasa a estado **`unshown`**. El requisito queda `MISSING` con `reason: "no visual evidence"`. Métrica
  `summary.unshown`. Con `warn` se informa y no cambia el estado. Con `off`, nada.
- Vídeo por workflow: `sdd gate --fase N` exige, con `required`, un vídeo cuyo nombre contenga cada `WF-NNN` de la
  línea de cabecera `> **Workflows:** WF-…` de la FASE (workflows de cara al usuario, la escribe plan-architect); sin
  esa línea, los citados en `## Demo`; sin ninguno, `FASE-N`. Cuenta cualquier vídeo bajo `evidence_dir` con el id en
  el nombre (adjunto del JUnit, fichero o `--attach`), incluida una grabación manual de la demo. Falta de vídeo →
  objetivo no cumplido (exit 1), listado como `missing_videos`.
- El título del journey lleva el `WF-NNN` (o `FASE-N`); el helper de vídeo toma el primer `WF-\d{3}` del título o un
  id explícito (`test.use({ videoId })`).
- Todo comando `{acceptance}` del implementer exporta `SDD_FASE={N}` y `SDD_EVIDENCE_DIR={evidence_dir}`.
- Ruta del loop nueva: **`capture-evidence`** (volver a ejecutar el journey con captura; no genera tarea de código).
  `sdd loop next` emite un target `{video, fase, route_hint: "capture-evidence"}` por vídeo que falta y los cuenta en
  `progress.videos_missing`; con `warn` van a `others`.
- `sdd accept pack --fase N`: empaqueta `evidencias/FASE-N/` y un `manifest.json` (ruta, sha256, bytes, criterio,
  `evaluated_sha`) en `.sdd/entregas/FASE-N-evidencias.tar.gz` con `tar`.

### 2.3 CLI de aceptación: flags y comandos nuevos

- `sdd accept record demo|inspection|measurement|fase-acceptance … --attach P…` (ficheros bajo `evidence_dir`; se
  guardan con sha256 y `kind`). `waiver` y `challenge-dismissal` no aceptan `--attach`.
- `--allow-dirty` en `accept record` y `accept measure`: graba `dirty: true`. Sin él, con cambios sin commitear en el
  código → exit 2 con «commit first». `waiver` y `challenge-dismissal` están exentos (no observan el código).
- `sdd accept --junit-sha SHA` con código sucio → exit 2. Sin `--junit-sha` y árbol sucio → `warning:` en stderr.
- Los ficheros sin versionar bajo `code_paths` + `test_paths` cuentan como sucios (`untracked_paths` en el ledger).
- `sdd req show <REQ-ID> [--ac N] [--json]`: enunciado y criterios literales de `requirements/REQUIREMENTS.md`.

### 2.4 Ronda adversarial (CLI)

- Fichero versionado `acceptance/challenges.jsonl`, escrito solo por la CLI. Una línea por hallazgo:
  `{ id: "CH-NNN", req, ac, category, quote, evidence: [{path, line}], verifier, counter: confirmed|inconclusive,
  head, reqHash, paths, at }`. Un hallazgo `refuted` no se graba (la CLI lo rechaza): se lista en el resumen de la
  ronda. Una captura de `evidencias/` se cita sin línea y se guarda su sha256.
- Categorías: `WEAKENED-ASSERT`, `MOCK-ONLY`, `UNWIRED`, `BYPASS-PATH`, `CROSSING`, `NOT-IMPLEMENTED`, `SPEC-QUESTION`,
  `WRONG-CAPTURE`.
- Evidencia prohibida: rutas bajo `acceptance/`, `feedback/`, `spec/`, `requirements/`, `plan/`, `task/`, `test/`,
  `audits/`, `changes/`, `.sdd/` → exit 2. Excepción: `test/` cuando está en los `test_paths` del perfil (Rails).
- Comandos:
  - `sdd accept challenge add --req ID --ac N --category CAT --quote TEXT --evidence path:line… --verifier NAME --counter R`
  - `sdd accept challenge list [--open] [--json]`
  - `sdd accept record challenge-dismissal --challenge CH-NNN --reason TEXT --by NAME --role ROLE` (humano; el tool guard
    ya pregunta ante `accept record`)
  - `sdd accept adversarial plan [--fase N] [--json]`: crítico de cobertura mecánico. Devuelve por FASE los requisitos,
    su texto literal, sus criterios, los tests ligados y los ficheros candidatos, más `uncovered` (requisitos activos
    fuera de toda FASE), `fases_without_header` y `criteria_without_test`.
- Ledger: `requirements[].challenges[]` con estado `open | stale | dismissed` (stale por `unchangedSince(head, paths)`
  o `reqHash`); `summary.must_challenged`. **El veredicto no cambia.**
- Gate: con `adversarial_gate: enforce`, un challenge abierto en un Must → **exit 4**, que impide `--sign-off` y la
  aceptación de FASE hasta que el loop lo arregla o una persona lo descarta. `warn` lo imprime y no cambia el código
  de salida. `off` lo ignora. Precedencia de salida: 2 > 1 > 4 > 3 > 0.
- Loop: challenges abiertos y confirmados salen en `targets` con la ruta **`adversarial-finding`** (y `category`); los
  `inconclusive`, con la ruta `needs-human`.
- Métricas de `acceptance` en `pipeline-state.json`: `adversarial_findings`, `adversarial_confirmed`,
  `adversarial_refuted`, `adversarial_open`, `adversarial_agents`, `coverage_gaps`, `unshown`.

### 2.5 Tareas y cadena

- Valores de `Source:` de una tarea: `CASCADE-{id}`, `FEEDBACK-FASE-{N}`, `ACCEPTANCE-LOOP`,
  `ACCEPTANCE-ADVERSARIAL-FASE-{N}`. El Mode 6 del implementer (`--new-tasks-only`) acepta todos.
- Test de contrato: un fichero bajo `test_paths`, en `contract/`, con la convención del stack
  (`<port>.contract.test.ts` en JS/TS, `<port>_contract_test.rb` en Rails); nombre `CONTRACT-<port> REQ-F-NNN ACn …`.
- Cita literal sobre el assert: `// REQ-F-081 AC1: "…THEN su título es 'Proyectos personales'"`.
- Tipos nuevos de fila de matriz: `replay`, `race`. Tipos nuevos de gap del test-planner: `MISSING-E2E`,
  `MISSING-REPLAY-SPEC`.
- Tabla nueva de PLAN-FASE: `§4.x Puertos con doble` con columnas
  `| Puerto | Interfaz (fichero) | Doble | Provider real | Observable del contrato |`.
- Tarea de journey por FASE en el Stream `verificación`: entra por la ruta del usuario, asserta texto y captura; su
  título lleva el `WF-NNN` de la línea `Workflows:` (o `FASE-N`).
- Cabecera de FASE nueva: `> **Workflows:** WF-001, WF-002` (workflows de cara al usuario; la lee `sdd gate --fase N`).
- Smoke post-deploy: los escenarios del tier `smoke-deploy` se etiquetan **`@smoke-deploy`** (`@smoke` queda para el
  tier de PR); el comando `smoke` del perfil los selecciona.

## 3. Paquetes de trabajo

Fase A en paralelo (ficheros disjuntos). Fase B cuando A termine. Fase C la hace el hilo principal.

| Paquete | Fase | Ficheros que posee | Contenido |
|---------|------|--------------------|-----------|
| A · CLI de evidencia | A | `scripts/lib/acceptance.mjs`, `acceptance-cli.mjs`, `junit.mjs`, `scripts/sdd.mjs`, `server/**`, `tests/acceptance/**`, `tests/fixtures/acceptance/**`, `templates/gitignore.sdd` | Bugs 1 y 3, M7.1 CLI, adjuntos, regla `unshown`, vídeo por FASE, `accept pack`, `req show`, tipos MCP |
| B · Diseño de tests | A | `skills/sdd-test-planner/**`, `skills/sdd-specifications-engineer/**`, `skills/sdd-spec-auditor/**`, `skills/sdd-requirements-engineer/**` | M3 marcador y journey, evidencia visual, M4 replay/carrera, W8 literales, smoke-deploy tier |
| C · Tareas y plan | A | `skills/sdd-task-generator/**`, `skills/sdd-plan-architect/**`, `scripts/lib/plan-lint.mjs`, `tests/plan/**`, `tests/tasks/**` | M2 puertos y `CONTRACT-`, tarea de journey (P2), checklist M3/M4/M6, `Source` adversarial, V-21 (warn) |
| D · Implementer y kits | A | `skills/sdd-task-implementer/**`, `templates/stacks/**`, `scripts/install-stack-kit.sh`, `docs/stacks.md`, `docs/multisesion.md`, `skills/sdd-lead/**`, `tests/setup/**` | Bug 2 (Mode 6), M6 cita, Category 3b, Phase 9 paso 4.0, C13, `test_slots`, Playwright con captura, claves del perfil |
| E · Smoke y CI | A | `templates/ci/**`, `skills/sdd-setup/**`, `skills/sdd-tech-designer/**`, `tests/tracker/**` | Plantillas `sdd-smoke`, instalación en setup, DIM-7/DIM-8 |
| F · CLI adversarial | B | los de A más `hooks/sdd-upstream-guard.sh`, `tests/hooks/**` | Sección 2.4 completa |
| G · Skill de aceptación y docs | B | `skills/sdd-acceptance/**`, `skills/sdd-orchestrator/**`, `skills/sdd-gap-detector/**`, `skills/sdd-req-change/references/cascade-patterns.md`, `docs/aceptacion.md`, `docs/jev.md`, `scripts/jev/test-adequacy.json` | `--adversarial` y `references/adversarial-protocol.md`, rutas `capture-evidence`/`adversarial-finding`, orden commit→evidencia, página de estado con capturas, métricas §9 |
| Integración | C | `CLAUDE.md`, `CHANGELOG.md`, `scripts/validate-plugin.mjs`, lo que falle | Merge, CHANGELOG `[Unreleased]`, CLAUDE.md, cross-auditor, CI completa |

## 4. Reglas para cada agente

- Leer primero este plan, `docs/MEJORAS-SDD-5.1-ANALISIS.md` (su sección del paquete) y `CLAUDE.md`.
- Tocar solo los ficheros de su paquete. Si algo fuera de él necesita cambio, anotarlo en el informe.
- Estilo de skills: una regla, una vez, con su razón; plantillas en `references/`; `description` ≤ 400 caracteres.
- Tests de uno en uno: solo las suites de su paquete, con `env -u SDD_STATE_ROOT bash tests/<suite>/run.sh`. Nunca la
  CI completa. Nada de procesos en segundo plano.
- Commits atómicos con Conventional Commits y trailers vía `git commit --trailer`:
  `Change: M51-<paquete>` en feat/fix/test/refactor, `Refs: MEJORAS-5.1` en docs. Terminar con
  `--trailer "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`.
- Al terminar: `git status` limpio, sin `pipeline-state.json` ni `.sdd/` en el índice, e informe con commits, tests
  ejecutados y su resultado, y lo que quede pendiente.
