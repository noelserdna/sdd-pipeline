# sdd-pipeline

> **[Read in English](README.md)**

[![ci](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Pipeline de Specification-Driven Development para [Claude Code](https://code.claude.com), basado en SWEBOK v4 — empaquetado como un único plugin instalable.**

De los requisitos al código en producción: un pipeline estructurado, auditable y trazable que convierte requisitos en lenguaje natural en software implementado, con hooks que protegen el proceso y un servidor MCP que responde preguntas sobre el grafo de trazabilidad.

- **21 skills** — el pipeline de 7 etapas, la aceptación por requisito, skills laterales, adopción brownfield, utilidades, el orquestador interactivo y el lead multi-sesión
- **Una CLI, `scripts/sdd.mjs`** — lint de tareas, trazabilidad sobre git (`sdd trace`), verificación de commits, ramas de trabajo, cobertura de necesidades, lint del plan, el libro de aceptación (`sdd accept`) y la puerta de entrega (`sdd gate`); Node ≥ 18 sin dependencias, corre en CI solo con Node y git
- **5 hooks** (7 registros de evento) — estado del pipeline al arrancar, guardia de inmutabilidad upstream, guardia contra el consentimiento fabricado y la auto-aprobación accidental, contexto de trazabilidad y actualización del estado
- **Servidor MCP** — 6 tools, 7 recursos y 2 prompts; la cobertura informa del veredicto de aceptación de cada requisito
- **Implementación multi-sesión** — sesiones con rol (`SDD_ROLE`), Streams paralelos en worktrees de git, handoffs al lead

## Instalación

```
/plugin marketplace add noelserdna/sdd-pipeline
/plugin install sdd-pipeline@noelserdna
```

Usa `--scope project` (o `claude plugin install sdd-pipeline@noelserdna --scope project`) para compartir el plugin con el equipo a través de `.claude/settings.json`.

**Requisitos:** Claude Code ≥ 2.1.224 · Node.js ≥ 18 · git ≥ 2.32 · bash · `jq` (recomendado; los hooks degradan a `node`) · `python3` (opcional: grafo de trazabilidad para el servidor MCP). macOS y Linux; Windows a través de WSL.

En el primer uso Claude Code pide aprobar el servidor MCP `sdd`. Tras actualizar el plugin ejecuta `/reload-plugins` o abre una sesión nueva.

¿Vienes de `sdd@noelserdna-claude-plugin-sdd`, de `sdd-pipeline@sdd-pipeline-local` o de hooks copiados en `.claude/hooks/`? Lee [docs/migracion.md](docs/migracion.md).

## Primeros pasos

```
/sdd-setup                       # pipeline-state.json, hook git commit-msg + validador vendorizado, política .gitignore
/sdd-setup --stack=rails --app-dir=web   # kit por stack opcional: SDD Stack Profile, convenciones, reglas por ruta (docs/stacks.md)
/sdd-requirements-engineer       # necesidades del cliente (literales) → requisitos con ejemplos y método de verificación
/sdd-specifications-engineer     # spec/ (dominio, casos de uso, workflows, contratos, ADRs, escenarios BDD AC-NNN-NN)
/sdd-spec-auditor                # audits/AUDIT-BASELINE.md — puerta PASS / CONDITIONAL / BLOCKED
/sdd-test-planner                # test/
/sdd-plan-architect              # plan/ — esqueleto andante y después un incremento demostrable por FASE
/sdd-task-generator              # task/ (tareas atómicas, grafo de dependencias, streams)
/sdd-task-implementer --fase 0   # rama de trabajo, test primero, un commit por tarea con trailers Task/Refs, demo de la FASE
/sdd-acceptance --fase 0         # veredicto por requisito con su evidencia; --sign-off registra la aceptación del cliente
/sdd-pipeline-status             # dónde estoy, qué está stale, qué sigue
```

O deja que la skill `sdd-orchestrator` conduzca todo el pipeline de forma interactiva: *"ejecuta el pipeline SDD para este proyecto"*.

## El pipeline

```
sdd-requirements-engineer   →  requirements/CUSTOMER-NEEDS.md, REQUIREMENTS.md (tag requirements-v{N} al aprobar)
sdd-specifications-engineer →  spec/ (domain, use-cases, workflows, contracts, nfr, adr, tests)
sdd-spec-auditor            →  audits/AUDIT-BASELINE.md + spec/ corregida
   ↳ laterales (opcionales): sdd-security-auditor, sdd-tech-designer, sdd-ux-designer
sdd-test-planner            →  test/TEST-PLAN.md, TEST-MATRIX-*.md, E2E-SCENARIOS.md
sdd-plan-architect          →  plan/ (ARCHITECTURE.md, PLAN.md con Plan-Style: vertical, fases/)
sdd-task-generator          →  task/TASK-FASE-*.md, TASK-ORDER.md (TASK-INDEX.md opcional)
sdd-task-implementer        →  código y tests (rutas del Stack Profile), commits de git, demo de la FASE
sdd-acceptance              →  acceptance/ACCEPTANCE-REPORT.md, decisions.jsonl, tag fase-{N}-accepted
```

Todo artefacto es trazable de extremo a extremo: `N → REQ → UC → WF → API → BDD/AC → INV → ADR → TASK → COMMIT → CODE → TEST → veredicto`.

**Las FASEs son verticales.** FASE-0 es un esqueleto andante: el camino mínimo escribir → observar → persistir del caso de uso central (en el ejemplo todo: `todo add`, `todo list` y el fichero JSON), más solo la infraestructura que ese camino necesita. Cada FASE posterior es un recorrido de usuario con una `## Demo` de 10 pasos como máximo. Al terminar una FASE el cliente ve la demo y la acepta, la acepta con observaciones o la rechaza con feedback, que se clasifica como defecto, petición de cambio o pregunta.

**La ruta se adapta al proyecto.** Justo después de aprobar los requisitos, `sdd route` propone qué etapas opcionales necesita este proyecto, a partir de hechos contados y siete juicios estrechos sobre las necesidades (cliente externo, datos sensibles, varios roles, integraciones, pantallas, vida larga, estado complejo). Una CLI pequeña se salta las specs formales, la auditoría de specs y el plan de tests, y se planifica directamente desde los criterios de aceptación de los requisitos. Una persona confirma la ruta con una sola pregunta, las etapas saltadas quedan registradas con su motivo y `sdd-req-change` vuelve a evaluar la ruta tras cada cambio: sube el rigor cuando hace falta y nunca lo baja solo. Ver [docs/ruta.md](docs/ruta.md).

El estado vive en `pipeline-state.json` (un único fichero, fuente de verdad); los cambios avanzan a través de `sdd-req-change`, que marca como `stale` las etapas posteriores y reabre la aceptación del requisito modificado.

## Skills

### Pipeline (7)

| # | Skill | Entrada | Salida |
|---|-------|---------|--------|
| 1 | `sdd-requirements-engineer` | el cliente | `requirements/` (necesidades, requisitos, tag de aprobación) |
| 2 | `sdd-specifications-engineer` | `requirements/` | `spec/` |
| 3 | `sdd-spec-auditor` | `spec/` | `audits/`, `spec/` corregida |
| 4 | `sdd-test-planner` | `spec/`, `ux/` | `test/` |
| 5 | `sdd-plan-architect` | `spec/`, `design/`, `ux/`, `audits/` | `plan/` (FASEs verticales) |
| 6 | `sdd-task-generator` | `plan/` | `task/` |
| 7 | `sdd-task-implementer` | `task/`, `spec/`, `plan/` | código, tests, commits |

### Laterales (4)

| Skill | Propósito | Salida |
|-------|-----------|--------|
| `sdd-security-auditor` | Auditoría de la postura de seguridad de las specs según OWASP ASVS v4 / CWE | `audits/SECURITY-AUDIT-BASELINE.md` |
| `sdd-req-change` | ADD / MODIFY / DEPRECATE de requisitos con cascada del pipeline (ISO 14764), en una rama `change/` | `requirements/`, `spec/`, `changes/` actualizados |
| `sdd-tech-designer` | Decisiones de arquitectura y stack en 12 dimensiones (ATAM-lite) | `design/` |
| `sdd-ux-designer` | Sistema de diseño, wireframes, accesibilidad, modelo de interacción | `ux/` |

### Brownfield (3)

| Skill | Propósito |
|-------|-----------|
| `sdd-reverse-engineer` | Código → artefactos SDD (requisitos, specs, FASEs retroactivas por área funcional, tareas, hallazgos) |
| `sdd-reconcile` | Detectar y resolver la deriva spec ↔ código |
| `sdd-import` | Jira, OpenAPI, Markdown, Notion, CSV, Excel → formato SDD |

### Utilidades (7)

| Skill | Propósito |
|-------|-----------|
| `sdd-acceptance` | Veredicto por requisito (VERIFIED / FAILING / MISSING / WAIVED) con su evidencia, integridad de la cadena de IDs, un bucle hasta que todo Must se cumple, la firma del cliente y una página de estado opcional — ver [docs/aceptacion.md](docs/aceptacion.md) |
| `sdd-setup` | Inicializa un proyecto: fichero de estado, hook git y validador vendorizado, política `.gitignore`, kits por stack, roles multi-sesión; limpia las status lines de 4.x |
| `sdd-pipeline-status` | Informe de etapas, staleness, resumen de aceptación y siguiente acción; `--diagnose` clasifica un proyecto existente (8 escenarios de adopción) y lista las skills a ejecutar |
| `sdd-gap-detector` | Endpoints que faltan, código huérfano, discrepancias de esquema — con un documento de revisión humana; `--semantic` comprueba si el código implementa cada requisito (juez Jev si está activo, LLM si no) |
| `sdd-session-summary` | Resume la sesión y actualiza la memoria del proyecto |
| `sdd-orchestrator` | Ejecuta todo el pipeline de forma interactiva desde la conversación principal, preguntando en las puertas (aprobación de requisitos, aceptación de cada FASE) |
| `sdd-lead` | Lead multi-sesión: despacha etapas a las sesiones con rol tras cada puerta humana, recibe handoffs y responde preguntas de las estaciones |

## Git y aceptación

El historial de git es la evidencia de que una tarea se hizo y un requisito se entregó ([docs/git.md](docs/git.md), [`references/git-conventions.md`](references/git-conventions.md)):

- Los commits llevan los trailers `Task`, `Refs` y `Change`, escritos con `git commit --trailer`; el hook commit-msg y el CI ejecutan el mismo validador (`sdd verify`).
- El trabajo empieza en una rama (`sdd branch start fase 2 lifecycle`); los merges son merge commits, nunca squash, para que sobrevivan los trailers de cada tarea.
- `sdd trace req REQ-F-004`, `sdd trace why src/tasks.ts:42` y `sdd trace delivered REQ-F-004` responden "qué commits", "por qué está esta línea" y "qué tags la entregan".
- Con `tracker: github|gitlab` en el Stack Profile, `sdd issue open|update|close` mantiene una issue por FASE y por cambio (la de la FASE se cierra al aceptarla) y `sdd pr-body` genera la descripción del PR; `/sdd-setup --tracker` añade plantillas de CI que ejecutan `sdd verify --range`, `sdd lint` y `sdd gate --mode warn`. Todo push, issue, PR o merge pregunta antes.

La aceptación responde "¿está satisfecho cada requisito, y con qué evidencia?" ([docs/aceptacion.md](docs/aceptacion.md)):

```bash
node scripts/sdd.mjs accept --report acceptance/ACCEPTANCE-REPORT.md   # libro desde JUnit + decisions.jsonl
node scripts/sdd.mjs gate --mode enforce    # 0 objetivo cumplido · 1 no cumplido · 2 evidencia obsoleta · 3 cumplido con Musts exentos
```

Los tests llevan en el nombre el ID de su escenario (`AC-001-03`) para que los resultados se aten a los criterios de aceptación; la evidencia `demo`, `measurement` e `inspection` la registra una persona con nombre. Los registros humanos y los tags de aceptación piden confirmación antes (tool guard) y no se pueden editar a mano (upstream guard): esto evita la auto-aprobación accidental, no es una garantía.

## Opcional: juicios masivos con Jev

Con `TYPESAFE_API_KEY` definida, `scripts/sdd-jev.mjs` permite a las skills cribar muchos elementos pequeños de una pasada con Jev de TypeSafe (respuestas sí/no, elección y puntuación calibradas en ~100 ms): calidad de requisitos y cobertura de necesidades en `sdd-requirements-engineer`, triaje de patrones de detección en `sdd-spec-auditor`, cobertura de requisitos en `sdd-gap-detector --semantic`, clasificación del feedback en la puerta de FASE, y comprobaciones informativas de adecuación de tests y de evidencia de demo en `sdd-acceptance`. El LLM solo lee lo que Jev marca o lo que le deja dudas, y Jev nunca decide un veredicto, una exención ni una firma. Sin la key (o con `SDD_JEV=off`) todas las skills funcionan como antes. El texto de specs y código se envía a TypeSafe, así que actívalo solo donde esté permitido — ver [docs/jev.md](docs/jev.md).

Los agentes de mantenimiento que auditan este repositorio (`sdd-pipeline-auditor`, `sdd-cross-auditor`) viven en `.claude/agents/` y no se distribuyen con el plugin.

## Hooks

Declarados en [`hooks/hooks.json`](hooks/hooks.json) y ejecutados desde el directorio del plugin: no se copia nada a tu proyecto.

| Hook | Evento | Qué hace |
|------|--------|----------|
| `sdd-session-start.sh` | SessionStart | Inyecta el estado del pipeline (`N/7 done`, etapas stale, siguiente paso, rol de la sesión y pares vivos) y el último resumen de aceptación |
| `sdd-upstream-guard.sh` | PreToolUse Edit/Write | Deniega escribir artefactos upstream mientras corre una etapa posterior (art. 4 de la constitución); aplica la propiedad de rutas por rol; deniega editar a mano `acceptance/decisions.jsonl` y el informe de aceptación |
| `sdd-tool-guard.sh` | PreToolUse Bash | Deniega comandos que asignan variables de consentimiento humano para acciones de IA (p. ej. `PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION`); pide confirmación antes de `sdd accept record` y de los tags `fase-N-accepted` / `requirements-vN` |
| `sdd-augment-hook.js` | PreToolUse Read/Edit/Write | Añade contexto de trazabilidad del fichero que se toca |
| `sdd-pipeline-state-updater.sh` | PreToolUse Skill, UserPromptExpansion, PostToolUse Write | Marca una etapa como `running` cuando arranca su skill o se escribe un fichero bajo su directorio (con lock, consciente de worktrees) |

`sdd-setup` instala además un hook git `commit-msg` que ejecuta `sdd verify` desde el validador vendorizado en `.claude/sdd/` (versiónalo; el CI usa la misma copia): `feat`, `test` y `refactor` necesitan un trailer `Task`, `fix` y `perf` un `Task` o un `Change` (escape: `[skip-sdd]` o `SDD_SKIP_VERIFY=1`). Las quality gates opcionales (`Stop`, `TaskCompleted`) están en `templates/settings-optional-quality-gates.json`.

## Servidor MCP

`server/dist/server.js` es un único fichero empaquetado (no necesita `node_modules`) registrado como `sdd`:

| Tool | Propósito |
|------|-----------|
| `sdd_query` | Buscar artefactos por texto, id, tipo o dominio |
| `sdd_impact` | Radio de impacto por profundidad (WILL_BREAK / LIKELY_AFFECTED / MAY_NEED_REVIEW) |
| `sdd_context` | Vista 360° de un artefacto; para un requisito, su veredicto de aceptación con la evidencia por criterio |
| `sdd_coverage` | Veredicto por requisito desde `.sdd/acceptance.json`; sin él, huecos de enlaces por dominio o capa |
| `sdd_trace` | Recorrido completo de la cadena con detección de roturas |
| `sdd_gaps` | Hallazgos de `sdd-gap-detector` |

Además, los recursos `sdd://pipeline/*`, `sdd://graph/*`, `sdd://coverage/gaps`, `sdd://artifacts/{type}[/{id}]` y los prompts `analyze_impact` / `generate_status_report`. El grafo (`dashboard/traceability-graph.json`) lo construye `python3 scripts/sdd-graph.py`; el servidor lo busca desde el directorio de trabajo hacia arriba y degrada con elegancia cuando no existe.

## Implementación multi-sesión

Sesiones de Claude Code con nombre y larga duración pueden poseer partes distintas del pipeline y enviarse mensajes (Claude Code ≥ 2.1.224):

```
/sdd-setup --multisession        # escribe .claude/sdd-sessions.json (roles → nombre de sesión, color, rutas propias, etapas)
.claude/sdd/sdd-up.sh sdd-lead   # lanza una sesión tmux `claude -n <proyecto>-lead` con SDD_ROLE=sdd-lead
.claude/sdd/sdd-up.sh impl-f1a   # un worktree + sesión para la FASE 1 / Stream A
```

- **`SDD_ROLE`** identifica la sesión; el hook de inicio muestra el rol y sus pares vivos, y la guardia upstream deniega escrituras fuera de las rutas del rol.
- **Streams** son la excepción en un plan vertical: solo cuando una FASE se parte en conjuntos de escritura disjuntos. `sdd-task-implementer --stream=A` trabaja en su propio worktree e `--integrate --fase N` fusiona los streams en el checkout principal (`git merge --no-ff`, verificación, tag `fase-N-verified`).
- **Handoffs**: cuando una estación termina una etapa envía `stage=<x> status=done gate=<…>` a la sesión lead (nunca "ejecuta X"; el humano sigue tomando cada decisión de puerta en `sdd-lead`). Las preguntas que bloquearían a una estación se escriben en `.sdd/questions-<rol>.md` y se responden desde el lead.
- Sin `SDD_ROLE` todo se comporta como una sesión única.

Ver [docs/multisesion.md](docs/multisesion.md) para el protocolo completo y [docs/multisesion/](docs/multisesion/) para la revisión de diseño que lo respalda.

## Estructura del repositorio

```
.claude-plugin/   plugin.json, marketplace.json      hooks/       hooks.json + scripts (+ lib/sdd-common.sh)
skills/           21 skills                          scripts/     CLI sdd.mjs (+ lib/), sdd-state.sh, sdd-jev.mjs, sdd-graph.py, validadores
.claude/agents/   auditores de mantenimiento         server/      servidor MCP (src/, dist/server.js, tests)
                  (no se distribuyen)
references/       constitución, convenciones git,    templates/   pipeline-state, gitignore, sesiones, quality gates, kits por stack
                  protocolo de handoff, preguntas asíncronas
examples/todo-app proyecto de juguete para E2E       tests/       hooks, setup, tasks, graph, jev, bench, git, plan, acceptance, tracker, e2e   docs/  guías, git, aceptación, diseño
```

## Desarrollo

```bash
node scripts/validate-plugin.mjs        # manifiestos, skills, hooks, mcp, kits por stack, ejemplos de commit
bash tests/hooks/run.sh                 # comportamiento de los hooks (roles, worktrees, locking, guardias)
bash tests/tasks/run.sh                 # gramática de línea de tarea (V-19) y estado de tareas por trailers
bash tests/git/run.sh                   # sdd trace / verify / branch contra repos temporales
bash tests/plan/run.sh                  # sdd lint --plan sobre los fixtures vertical y de Streams
bash tests/acceptance/run.sh            # sdd accept / gate / loop: veredictos, frescura, exenciones, lector JUnit
bash tests/graph/run.sh                 # sdd-graph.py (paridad de commits con sdd trace, escaneos del Stack Profile) y parsers de resultados
bash tests/jev/run.sh                   # sdd-jev.mjs contra un mock local de la API (sin key, sin red)
bash tests/e2e/run-all.sh               # B1 validación estática + B2 instalación real en un CLAUDE_CONFIG_DIR aislado
cd server && npm ci && npm run check && npm run build && npm test
node scripts/sdd.mjs --help             # la CLI (scripts/sdd-task-lint.mjs es un alias)
claude --plugin-dir . -p "/sdd-pipeline-status"   # probar el plugin sin instalarlo
scripts/release.sh 5.0.0                # sube versión en plugin.json/marketplace/server, CHANGELOG, tag sdd-pipeline--v5.0.0
```

El CI ejecuta lint (shellcheck), validación, las suites de scripts (`tests/{hooks,setup,bench,tasks,graph,jev,git,acceptance,plan}`) y la matriz de build/test del servidor (ubuntu + macos, node 18/22), y comprueba que `server/dist/server.js` es reproducible.

## Documentación

- [docs/instalacion.md](docs/instalacion.md) — instalación y primeros pasos
- [docs/guia-paso-a-paso.md](docs/guia-paso-a-paso.md) — guía paso a paso
- [docs/guia-completa-extendida.md](docs/guia-completa-extendida.md) — guía extendida
- [docs/git.md](docs/git.md) — commits, trailers, ramas, merges, tags y `sdd trace`
- [docs/aceptacion.md](docs/aceptacion.md) — aceptación por requisito, la puerta, el bucle hasta el objetivo y la firma
- [docs/ruta.md](docs/ruta.md) — ruta adaptativa: qué etapas necesita cada proyecto, confirmación y reevaluación
- [docs/stacks.md](docs/stacks.md) — SDD Stack Profile y kits por stack (Rails, Next.js + Prisma)
- [docs/migracion.md](docs/migracion.md) — migrar desde plugins anteriores, hooks copiados y 4.x
- [docs/multisesion.md](docs/multisesion.md) — protocolo multi-sesión
- [docs/jev.md](docs/jev.md) — integración opcional con Jev, mediciones y límites
- [docs/coste-contexto.md](docs/coste-contexto.md) — coste de contexto por versión
- [docs/perfilado.md](docs/perfilado.md) — dónde se va el tiempo en una etapa y cómo acortarlo (`scripts/sdd-profile.sh`)
- [references/sdd-constitution.md](references/sdd-constitution.md) — los 12 artículos que siguen todas las skills
- [CHANGELOG.md](CHANGELOG.md)

## Historia

Este repositorio unifica [sdd-skills](https://github.com/noelserdna/sdd-skills) (upstream), [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd) (el plugin distribuible anterior) y un fork interno reducido. Los dos repositorios públicos quedan archivados en v3.1.0; en [docs/legacy/INVENTARIO.md](docs/legacy/INVENTARIO.md) está el origen de cada pieza.

## Licencia

[MIT](LICENSE) — Andres Leon
