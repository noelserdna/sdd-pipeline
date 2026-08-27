# Multi-sesión: roles, worktrees y handoffs

Modo opcional para ejecutar partes del pipeline en varias sesiones de Claude Code con nombre que se envían mensajes (Claude Code ≥ 2.1.224). Sin `SDD_ROLE` todo se comporta como una sesión única.

## Conceptos

| Concepto | Qué es |
|---|---|
| **Rol** (`SDD_ROLE`) | Clave de `.claude/sdd-sessions.json` que identifica la sesión: qué rutas posee (`owns`) y qué etapas ejecuta (`stages`) |
| **Sesión** | `claude -n <proyecto>-<rol>`; el nombre es la dirección para `SendMessage` |
| **Checkout principal** (`SDD_STATE_ROOT`) | Donde vive `pipeline-state.json` y `.sdd/trace-map.json`; los worktrees comparten ese estado |
| **Stream** | Subconjunto de tasks de una FASE con write-set disjunto; se implementa en un worktree propio |
| **Lead** | La sesión `sdd-lead`: toma todas las decisiones de puerta, despacha etapas y responde preguntas |

## Puesta en marcha

```
/sdd-setup --multisession              # .claude/sdd-sessions.json + .claude/sdd/sdd-up.sh
.claude/sdd/sdd-up.sh sdd-lead         # tmux: claude -n <proyecto>-lead con SDD_ROLE=sdd-lead
.claude/sdd/sdd-up.sh sdd-spec         # otra estación
.claude/sdd/sdd-up.sh impl-f1a         # crea el worktree ../<proyecto>-f1a desde fase-1-foundation y lanza la sesión
tmux attach -t <proyecto>-lead         # Ctrl+B, D para salir sin cerrar
```

`sdd-up.sh` se niega a lanzar dos sesiones con el mismo nombre (lee `~/.claude/sessions/*.json`) y pone el color del rol con `/color`. Para retomar una estación: `SDD_ROLE=impl-f1a claude --resume`.

Roles por defecto (`templates/sdd-sessions.example.json`):

| Rol | Posee | Etapas |
|---|---|---|
| `sdd-lead` | `requirements/*`, `changes/*`, `feedback/*`, `.claude/*`, `pipeline-state.json` **y el write-set de integración** (`src/*`, `tests/*`, `.github/*`, `package.json`, `*.config.*`, `task/TASK-FASE-*.md`, `.sdd/*`, `dashboard/*`), porque ejecuta `--integrate` en el principal | requirements-engineer, req-change, task-implementer (solo `--stream base` e `--integrate`) |
| `sdd-spec` | `spec/*`, `audits/AUDIT-*`, `audits/UPSTREAM-*`, `audits/CORRECTIONS-*`, `changes/*` | specifications-engineer, spec-auditor, req-change |
| `sdd-plan` | `design/*`, `ux/*`, `test/*`, `plan/*`, `task/*`, `audits/SECURITY-*` | tech-designer, ux-designer, security-auditor, test-planner, plan-architect, task-generator |
| `impl-f1a` | `src/*`, `tests/*`, `feedback/*`, `task/TASK-FASE-*.md`, `.sdd/*` | task-implementer (fase 1, stream A, worktree `../<proyecto>-f1a`) |
| `sdd-qa` | `.sdd/*`, `audits/GAP-*`, `dashboard/*` | gap-detector, traceability-check, dashboard |

`sdd-spec` y `sdd-plan` no aportan paralelismo (la cadena es secuencial); su valor es aislar el contexto de etapas largas y poder retomarlas. Las estaciones que sí se ejecutan en paralelo son las `impl-*`.

## Qué hacen los hooks con un rol

- **SessionStart**: muestra `Rol: <rol> (posee …; stages …) | Pares vivos: …` y el último handoff; exporta `SDD_PLUGIN_ROOT` y `SDD_STATE_ROOT` a la sesión.
- **Guardia upstream**: deniega escribir fuera de las rutas que el rol posee (aunque no haya etapa en marcha); la etapa "en marcha" que considera es la primera `running` **del rol**, no la global.
- **Estado y trace-map**: se escriben siempre en el checkout principal, bajo lock (`mkdir`), también desde un worktree o desde `.claude/worktrees/`. `.sdd/current-task.json` es por worktree.

## Implementación por Streams

1. `sdd-task-generator` calcula los Streams de cada FASE (componentes conexas por write-set; el wiring compartido va al Stream `integración`) y los publica en la tabla *Stream Ownership* de `task/TASK-FASE-N.md` y en `task/TASK-ORDER.md`.
2. Las tasks `base` (Setup + Foundation) se implementan en el principal → checkpoint `fase-N-foundation`.
3. Cada Stream: `sdd-up.sh impl-fNx` → en el worktree, `/sdd-task-implementer --fase N --stream X`. Solo ve sus tasks; no crea tags; al terminar hace *Stream Complete* (tests, push de la rama) y envía el handoff.
4. El lead, en el principal: `/sdd-task-implementer --integrate --fase N` → `git merge --no-ff` por rama, tasks de `integración`, `--verify`, tag `fase-N-verified`, Persist Summary, push.

## Handoffs y preguntas

- Al terminar una etapa (tras Persist Summary y tras la pregunta de puerta local), la estación envía **un** mensaje al lead: `stage=<x> status=done|blocked gate=<…> artifacts=<n> root=<STATE_ROOT>; reread pipeline-state.json`. Se registra en `pipeline-state.json` como `stages.<x>.summary.handoff {to, sentAt, result}`. Nunca se envía "ejecuta X" a otra estación: los GO los emite el lead tras preguntar al humano.
- Un mensaje entre sesiones **no** es una aprobación del usuario ni puede contestar prompts de permisos (Claude Code lo bloquea).
- Una estación que necesitaría preguntar al humano escribe la pregunta en `$SDD_STATE_ROOT/.sdd/questions-<rol>.md`, sigue con lo que no está bloqueado y, al agotar trabajo, envía `status=blocked questions=<n>` y termina el turno. El lead (`/sdd-lead`) pregunta al humano, escribe `Answer:` en el fichero y avisa; la estación relee el fichero (disco = verdad).

Protocolos detallados: [`references/handoff-protocol.md`](../references/handoff-protocol.md), [`references/async-questions.md`](../references/async-questions.md). Diseño y revisión: [`multisesion/`](multisesion/).

## Ver qué está pasando

Con varias estaciones abiertas no se ve desde fuera qué skill corre en cada una, cuántos subagentes hay lanzados ni desde cuándo. Para eso el hook `hooks/sdd-activity-log.sh` deja una línea JSON por evento en `$SDD_STATE_ROOT/.sdd/activity.jsonl` (siempre en el checkout principal, también desde un worktree) y `scripts/sdd-watch.sh` la pinta en un panel que se repinta solo.

```
tmux split-window -h -t <proyecto>-lead \
  "bash <plugin>/scripts/sdd-watch.sh --root /ruta/al/checkout/principal"   # panel junto a la sesión lead
scripts/sdd-watch.sh --root ../todo-app --interval 2                          # en otra terminal
scripts/sdd-watch.sh --once --root ../todo-app                                # una sola pasada, para pegar en un informe
```

`<plugin>` es la ruta de instalación (`~/.claude/plugins/…/sdd-pipeline` o el checkout con `--plugin-dir`). Sin `--root` usa `SDD_STATE_ROOT` o la raíz del `.git` común del cwd. Cada `N` segundos (5 por defecto) limpia la pantalla y muestra:

| Sección | Qué muestra | Fuente |
|---|---|---|
| **Pipeline** | cada stage `done/running/stale/pending` con `lastRun`, contador `N/7`, `currentStage` | `pipeline-state.json` |
| **Ahora** | etapa `running`; skill en curso por sesión (último `skill-start` sin `stop` posterior) y desde cuándo; task actual del principal y de cada worktree de `git worktree list` | `activity.jsonl`, `.sdd/current-task.json` |
| **Agentes** | subagentes activos (`subagent-start` sin `subagent-stop`): tipo, descripción, sesión/rol, duración; total lanzados en la última hora | `activity.jsonl` |
| **Sesiones** | sesiones vivas del mismo repo: nombre, estado (`busy/idle/waiting`), rol, pid | `~/.claude/sessions/*.json`, `.claude/sdd-sessions.json` |
| **Handoffs** | stages con `summary.handoff`: destino, resultado, hora | `pipeline-state.json` |
| **Preguntas** | ficheros `.sdd/questions-<rol>.md` con su nº de `[OPEN]` | `.sdd/` |
| **Bench** | últimos 5 eventos (si existe) | `.sdd/bench/events.jsonl` |
| **Actividad reciente** | últimas 8 líneas del log (`HH:MM:SS evento detalle [rol]`, UTC) | `activity.jsonl` |

Eventos registrados (campo `event`) y de qué hook salen:

| `event` | Hook | Campos propios |
|---|---|---|
| `session-start` / `session-end` | `SessionStart` (`startup\|resume`) / `SessionEnd` | `source` / `reason` |
| `skill-start` | `PreToolUse` con `tool_name=Skill` (Claude invoca la skill) y `UserPromptExpansion` (el humano teclea `/skill`; ese camino **no** pasa por `PreToolUse`) | `skill`, `args`, `via=tool\|prompt`, `in_agent` si ocurre dentro de un subagente |
| `agent-start` | `PreToolUse` con `tool_name=Agent` (o `Task`, nombre antiguo) | `agent_type` (`subagent_type`), `description` |
| `subagent-start` / `subagent-stop` | `SubagentStart` / `SubagentStop` | `agent_type`, `agent_id` |
| `stop` | `Stop` (fin de turno del agente principal) | — |

Campos comunes: `ts` (ISO UTC), `session` (8 primeros caracteres de `session_id`), `role` (`SDD_ROLE` o registro de sesiones; `-` sin rol), `cwd` (relativo al principal), `stage` (primer stage `running`), `task` (`taskId` del `.sdd/current-task.json` del worktree). El hook no escribe nada en proyectos sin `.sdd/` ni `pipeline-state.json`, siempre sale con 0 y rota el fichero a `activity.1.jsonl` al superar 5 MB. Como `SubagentStart` no trae la descripción, el panel la toma del `agent-start` anterior de la misma sesión y tipo (heurística). Una skill que termina el turno para preguntar al humano deja de contar como "en curso" hasta la siguiente invocación.

## Límites conocidos

- `~/.claude/sessions/<pid>.json`, `CLAUDE_PID` y el socket de mensajería no están documentados por Claude Code: los hooks degradan a "sin rol" si cambian.
- Nombres de sesión duplicados obligan a desambiguar con el `[ref]` que muestra `ListAgents`; `sdd-up.sh` los evita.
- Agent Teams (experimental) no se usa: los teammates comparten checkout y no resuelven la serialización de commits.
