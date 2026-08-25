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

## Límites conocidos

- `~/.claude/sessions/<pid>.json`, `CLAUDE_PID` y el socket de mensajería no están documentados por Claude Code: los hooks degradan a "sin rol" si cambian.
- Nombres de sesión duplicados obligan a desambiguar con el `[ref]` que muestra `ListAgents`; `sdd-up.sh` los evita.
- Agent Teams (experimental) no se usa: los teammates comparten checkout y no resuelven la serialización de commits.
