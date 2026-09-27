# sdd-pipeline

> **[Read in English](README.md)**

[![ci](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Pipeline de Specification-Driven Development para [Claude Code](https://code.claude.com), basado en SWEBOK v4 — empaquetado como un único plugin instalable.**

De los requisitos al código en producción: un pipeline estructurado, auditable y trazable que convierte requisitos en lenguaje natural en software implementado, con hooks que protegen el proceso y un servidor MCP que responde preguntas sobre el grafo de trazabilidad.

- **23 skills** — el pipeline de 7 etapas, skills laterales, adopción brownfield, utilidades, el orquestador interactivo y el lead multi-sesión
- **8 hooks** (14 registros de evento) — estado del pipeline al arrancar, guardia de inmutabilidad upstream, guardia contra el consentimiento fabricado en herramientas que exigen a un humano, actualización de estado y trace-map, contexto de trazabilidad, el registro de actividad que alimenta la status line y `sdd-watch`, y un recordatorio de una línea con los runs vivos en cada prompt
- **Servidor MCP** — 6 tools, 7 recursos y 2 prompts sobre `dashboard/traceability-graph.json`
- **Implementación multi-sesión** — sesiones con rol (`SDD_ROLE`), Streams paralelos en worktrees de git, handoffs al lead

## Instalación

```
/plugin marketplace add noelserdna/sdd-pipeline
/plugin install sdd-pipeline@noelserdna
```

Usa `--scope project` (o `claude plugin install sdd-pipeline@noelserdna --scope project`) para compartir el plugin con el equipo a través de `.claude/settings.json`.

**Requisitos:** Claude Code ≥ 2.1.224 · Node.js ≥ 18 · git · bash · `jq` (recomendado; los hooks degradan a `node`) · `python3` (solo dashboard). macOS y Linux; Windows a través de WSL.

En el primer uso Claude Code pide aprobar el servidor MCP `sdd`. Tras actualizar el plugin ejecuta `/reload-plugins` o abre una sesión nueva.

¿Vienes de `sdd@noelserdna-claude-plugin-sdd`, de `sdd-pipeline@sdd-pipeline-local` o de hooks copiados en `.claude/hooks/`? Lee [docs/migracion.md](docs/migracion.md).

## Primeros pasos

```
/sdd-setup                       # pipeline-state.json, hook git commit-msg, política .gitignore, status line opcional
/sdd-setup --stack=rails --app-dir=web   # kit por stack opcional: SDD Stack Profile, convenciones, reglas por ruta (docs/stacks.md)
/sdd-requirements-engineer       # elicitar y escribir requirements/REQUIREMENTS.md
/sdd-specifications-engineer     # spec/ (dominio, casos de uso, workflows, contratos, ADRs, BDD)
/sdd-spec-auditor                # audits/AUDIT-BASELINE.md — puerta PASS / CONDITIONAL / BLOCKED
/sdd-test-planner                # test/
/sdd-plan-architect              # plan/ (arquitectura, FASEs)
/sdd-task-generator              # task/ (tareas atómicas, grafo de dependencias, streams)
/sdd-task-implementer --fase 0   # src/, tests/, commits con trailers Refs:/Task:
/sdd-pipeline-status             # dónde estoy, qué está stale, qué toca ahora
```

O deja que la skill `sdd-orchestrator` conduzca el pipeline completo de forma interactiva: *"ejecuta el pipeline SDD para este proyecto"*.

## El pipeline

```
sdd-requirements-engineer   →  requirements/REQUIREMENTS.md
sdd-specifications-engineer →  spec/ (domain, use-cases, workflows, contracts, nfr, adr, tests)
sdd-spec-auditor            →  audits/AUDIT-BASELINE.md + spec/ corregido
   ↳ laterales (opcionales): sdd-security-auditor, sdd-tech-designer, sdd-ux-designer
sdd-test-planner            →  test/TEST-PLAN.md, TEST-MATRIX-*.md, E2E-SCENARIOS.md
sdd-plan-architect          →  plan/ (ARCHITECTURE.md, PLAN.md, fases/)
sdd-task-generator          →  task/TASK-FASE-*.md, TASK-ORDER.md (TASK-INDEX.md opcional)
sdd-task-implementer        →  src/, tests/, commits git
```

Cada artefacto se traza de extremo a extremo: `REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST`.

El estado vive en `pipeline-state.json` (un fichero, única fuente de verdad); los cambios fluyen hacia delante con `sdd-req-change`, que marca las etapas posteriores como `stale`.

## Skills

### Pipeline (7)

| # | Skill | Entrada | Salida |
|---|-------|---------|--------|
| 1 | `sdd-requirements-engineer` | el usuario | `requirements/` |
| 2 | `sdd-specifications-engineer` | `requirements/` | `spec/` |
| 3 | `sdd-spec-auditor` | `spec/` | `audits/`, `spec/` corregido |
| 4 | `sdd-test-planner` | `spec/`, `ux/` | `test/` |
| 5 | `sdd-plan-architect` | `spec/`, `design/`, `ux/`, `audits/` | `plan/` |
| 6 | `sdd-task-generator` | `plan/` | `task/` |
| 7 | `sdd-task-implementer` | `task/`, `spec/`, `plan/` | `src/`, `tests/`, commits |

### Laterales (4)

| Skill | Propósito | Salida |
|-------|-----------|--------|
| `sdd-security-auditor` | Auditoría de seguridad de las specs (OWASP ASVS v4 / CWE) | `audits/SECURITY-AUDIT-BASELINE.md` |
| `sdd-req-change` | ADD / MODIFY / DEPRECATE de requisitos con cascada por el pipeline (ISO 14764) | `requirements/`, `spec/`, `changes/` |
| `sdd-tech-designer` | Decisiones de arquitectura y stack en 12 dimensiones (ATAM-lite) | `design/` |
| `sdd-ux-designer` | Sistema de diseño, wireframes, accesibilidad, modelo de interacción | `ux/` |

### Brownfield (3)

| Skill | Propósito |
|-------|-----------|
| `sdd-reverse-engineer` | Código → artefactos SDD (requisitos, specs, tareas, hallazgos) |
| `sdd-reconcile` | Detecta y resuelve la deriva spec ↔ código |
| `sdd-import` | Jira, OpenAPI, Markdown, Notion, CSV, Excel → formato SDD |

### Utilidades (9)

| Skill | Propósito |
|-------|-----------|
| `sdd-setup` | Inicializa el proyecto: estado, hook git, política `.gitignore`, status line, roles multi-sesión |
| `sdd-pipeline-status` | Informe de etapas, staleness y siguiente acción; `--diagnose` clasifica un proyecto existente (8 escenarios de adopción) y lista las skills a ejecutar |
| `sdd-traceability-check` | Verificación de la cadena completa, huérfanos y enlaces rotos |
| `sdd-gap-detector` | Endpoints ausentes, código huérfano, desajustes de esquema — con documento de revisión humana; `--semantic` comprueba si el código implementa cada requisito (juez Jev si está activo, LLM si no) |
| `sdd-dashboard` | Dashboard HTML interactivo de trazabilidad agrupado por fase de ingeniería |
| `sdd-session-summary` | Resume la sesión y actualiza la memoria del proyecto |
| `sdd-orchestrator` | Ejecuta el pipeline completo de forma interactiva desde la conversación principal, pidiendo las decisiones de puerta |
| `sdd-code-index` | Referencias de código a nivel de símbolo (puente opcional con [GitNexus](https://github.com/nicobailon/gitnexus)) |
| `sdd-lead` | Lead multi-sesión: despacha etapas a las sesiones con rol tras cada puerta humana, recibe handoffs, responde preguntas de las estaciones |

## Opcional: juicios masivos con Jev

Con `TYPESAFE_API_KEY` definida, `scripts/sdd-jev.mjs` permite a las skills cribar muchos elementos pequeños de una pasada con Jev de TypeSafe (respuestas sí/no, elección y puntuación calibradas en ~100 ms). Lo usan tres skills: `sdd-requirements-engineer` para la calidad de los requisitos, `sdd-spec-auditor` para el triaje de los patrones de detección y `sdd-gap-detector --semantic` para la cobertura de requisitos. El LLM solo lee lo que Jev marca o lo que le deja dudas. Sin la key (o con `SDD_JEV=off`) todas las skills funcionan como antes. El texto de specs y código se envía a TypeSafe, así que actívalo solo donde esté permitido: ver [docs/jev.md](docs/jev.md).

Los agentes de mantenimiento que auditan este repositorio (`sdd-pipeline-auditor`, `sdd-cross-auditor`) viven en `.claude/agents/` y no se distribuyen con el plugin.

## Hooks

Declarados en [`hooks/hooks.json`](hooks/hooks.json) y ejecutados desde el directorio del plugin: no se copia nada a tu proyecto.

| Hook | Evento | Qué hace |
|------|--------|----------|
| `sdd-session-start.sh` | SessionStart | Inyecta el estado del pipeline (`N/7 done`, stages stale, siguiente paso, rol de la sesión y pares vivos) |
| `sdd-upstream-guard.sh` | PreToolUse Edit/Write | Deniega escrituras en artefactos upstream mientras corre una etapa posterior (art. 4 de la constitución); aplica la posesión por rol |
| `sdd-augment-hook.js` | PreToolUse Read/Edit/Write | Añade contexto de trazabilidad del fichero que se toca |
| `sdd-tool-guard.sh` | PreToolUse Bash | Deniega comandos que asignan variables de consentimiento humano para acciones de IA (p. ej. `PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION`): el consentimiento lo da una persona, nunca CLAUDE.md, las tareas ni los prompts |
| `sdd-pipeline-state-updater.sh` | PostToolUse Write | Marca como `running` la etapa dueña de la ruta escrita (con lock, consciente de worktrees) |
| `sdd-trace-map-updater.sh` | PostToolUse Write/Edit | Acumula mapeos fichero → task/refs en `.sdd/trace-map.json` |
| `sdd-activity-log.sh` | SessionStart/End, PreToolUse Skill/Agent, UserPromptExpansion, SubagentStart/Stop, Stop | Añade una línea JSON por evento a `.sdd/activity.jsonl` (skill, subagentes, sesión, rol, etapa, task) para el panel en vivo `scripts/sdd-watch.sh`, cierra la skill en curso con `skill-end` y mantiene el índice global de ejecuciones `~/.claude/sdd/active-runs.json` |
| `sdd-runs-line.sh` | UserPromptSubmit | Una línea de `systemMessage` por run vivo de ese índice (silencio si no hay ninguno) |

`sdd-setup` instala además un hook git `commit-msg` que exige trailers `Refs:` / `Task:` en commits `feat`, `fix`, `perf`, `test` y `refactor` (bypass: `[skip-sdd]` o `SDD_SKIP_VERIFY=1`), y puede añadir una status line opcional y quality gates opt-in (`Stop`, `TaskCompleted`).

Para ver un pipeline que corre en **otros procesos y otros proyectos** (`claude -p`): `/sdd-watch` imprime una línea por run vivo y `bash scripts/install-global-statusline.sh` instala una status line de usuario (`SDD ▸ todo-app  5/7 done · task-generator 12m 30s · 3 agentes`) que lee ese mismo índice global — ver [`docs/multisesion.md`](docs/multisesion.md#ver-qué-está-pasando).

## Servidor MCP

`server/dist/server.js` es un único fichero empaquetado (sin `node_modules`) registrado como `sdd`:

| Tool | Propósito |
|------|-----------|
| `sdd_query` | Buscar artefactos por texto, id, tipo o dominio |
| `sdd_impact` | Radio de impacto por profundidad (WILL_BREAK / LIKELY_AFFECTED / MAY_NEED_REVIEW) |
| `sdd_context` | Vista 360° de un artefacto |
| `sdd_coverage` | Huecos por dominio de negocio o capa técnica |
| `sdd_trace` | Recorrido de la cadena completa con detección de roturas |
| `sdd_gaps` | Hallazgos de `sdd-gap-detector` |

Más los recursos `sdd://pipeline/*`, `sdd://graph/*`, `sdd://coverage/gaps`, `sdd://artifacts/{type}[/{id}]` y los prompts `analyze_impact` / `generate_status_report`. El servidor busca `dashboard/traceability-graph.json` desde el directorio de trabajo hacia arriba y degrada sin error cuando no existe: ejecuta `/sdd-dashboard` para generarlo.

## Implementación multi-sesión

Sesiones de Claude Code con nombre y larga vida pueden poseer partes distintas del pipeline y enviarse mensajes (Claude Code ≥ 2.1.224):

```
/sdd-setup --multisession        # escribe .claude/sdd-sessions.json (rol → nombre de sesión, color, rutas que posee, stages)
.claude/sdd/sdd-up.sh sdd-lead   # lanza una sesión tmux `claude -n <proyecto>-lead` con SDD_ROLE=sdd-lead
.claude/sdd/sdd-up.sh impl-f1a   # worktree + sesión para FASE 1 / Stream A
```

- **`SDD_ROLE`** identifica la sesión; el hook de arranque muestra el rol y sus pares vivos, y la guardia upstream deniega escrituras fuera de las rutas que el rol posee.
- **Streams**: `sdd-task-generator` divide cada FASE en streams con write-sets disjuntos; `sdd-task-implementer --stream=A` trabaja en su propio worktree y `--integrate --fase N` reintegra los streams en el checkout principal (`git merge --no-ff`, verificación, tag `fase-N-verified`).
- **Handoffs**: cuando una estación termina una etapa envía `stage=<x> status=done gate=<…>` a la sesión lead (nunca "ejecuta X"; el humano sigue tomando cada decisión de puerta en `sdd-lead`). Las preguntas que bloquearían a una estación se escriben en `.sdd/questions-<rol>.md` y se responden desde el lead.
- Todo degrada al comportamiento de sesión única cuando `SDD_ROLE` no está definido.

Protocolo completo en [docs/multisesion.md](docs/multisesion.md); la revisión de diseño que lo sustenta, en [docs/multisesion/](docs/multisesion/).

## Estructura del repositorio

```
.claude-plugin/   plugin.json, marketplace.json      hooks/       hooks.json + scripts (+ lib/sdd-common.sh)
skills/           23 skills                          scripts/     ayudantes de setup, sdd-state.sh, sdd-jev.mjs, validadores
.claude/agents/   auditores de mantenimiento         server/      servidor MCP (src/, dist/server.js, tests)
references/       constitución, protocolo de handoff templates/   pipeline-state, gitignore, sesiones, quality gates
examples/todo-app proyecto de juguete para E2E       tests/       hooks, setup, tasks, dashboard, jev, bench, e2e   docs/  guías, migración, diseño
```

## Desarrollo

```bash
node scripts/validate-plugin.mjs        # manifiestos, skills, hooks, mcp, kits de stack
bash tests/hooks/run.sh                 # comportamiento de los hooks (roles, worktrees, lock, activity log)
bash tests/tasks/run.sh                 # gramática de línea de tarea (V-19) y estado por trailers
bash tests/dashboard/run.sh             # generate.py (inferencia por commits, rangos, Stack Profile) y parsers de resultados
bash tests/jev/run.sh                   # sdd-jev.mjs contra un mock local de la API (sin key ni red)
scripts/sdd-watch.sh --root ../mi-app   # panel en vivo: etapas, skill en curso, subagentes, sesiones, handoffs, preguntas (--once para una foto)
scripts/sdd-watch.sh --brief            # una línea por run vivo del índice global (lo que ejecuta /sdd-watch)
bash tests/e2e/run-all.sh               # B1 validación estática + B2 instalación real en un CLAUDE_CONFIG_DIR aislado
cd server && npm ci && npm run check && npm run build && npm test
claude --plugin-dir . -p "/sdd-pipeline-status"   # probar el plugin sin instalarlo
scripts/release.sh 4.0.0                # sube plugin.json/marketplace/server, CHANGELOG, tag sdd-pipeline--v4.0.0
```

La CI ejecuta lint (shellcheck), validación, tests de hooks y la matriz de build/test del servidor (ubuntu + macos, node 18/22), y comprueba que `server/dist/server.js` es reproducible.

## Documentación

- [docs/instalacion.md](docs/instalacion.md) — instalación y primeros pasos
- [docs/stacks.md](docs/stacks.md) — SDD Stack Profile y kits por stack (Rails, Next.js + Prisma)
- [docs/migracion.md](docs/migracion.md) — migración desde los plugins anteriores y los hooks copiados
- [docs/multisesion.md](docs/multisesion.md) — protocolo multi-sesión
- [docs/guia-paso-a-paso.md](docs/guia-paso-a-paso.md) — guía paso a paso
- [docs/coste-contexto.md](docs/coste-contexto.md) — coste de contexto por versión
- [docs/perfilado.md](docs/perfilado.md) — dónde se va el tiempo de una etapa y cómo acortarlo (`scripts/sdd-profile.sh`)
- [docs/jev.md](docs/jev.md) — integración opcional con Jev, mediciones y límites
- [references/sdd-constitution.md](references/sdd-constitution.md) — los 12 artículos que siguen todas las skills
- [CHANGELOG.md](CHANGELOG.md)

## Historia

Este repositorio unifica [sdd-skills](https://github.com/noelserdna/sdd-skills) (upstream), [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd) (el plugin distribuible anterior) y un fork interno reducido. Los dos repositorios públicos quedan archivados en v3.1.0; en [docs/legacy/INVENTARIO.md](docs/legacy/INVENTARIO.md) está el origen de cada pieza.

## Licencia

[MIT](LICENSE) — Andres Leon
