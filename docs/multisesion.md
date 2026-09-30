# Multi-sesión: roles, worktrees y handoffs

Modo opcional para ejecutar partes del pipeline en varias sesiones de Claude Code con nombre que se envían mensajes (Claude Code ≥ 2.1.224). Sin `SDD_ROLE` todo se comporta como una sesión única.

## Conceptos

| Concepto | Qué es |
|---|---|
| **Rol** (`SDD_ROLE`) | Clave de `.claude/sdd-sessions.json` que identifica la sesión: qué rutas posee (`owns`) y qué etapas ejecuta (`stages`) |
| **Sesión** | `claude -n <proyecto>-<rol>`; el nombre es la dirección para `SendMessage` |
| **Checkout principal** (`SDD_STATE_ROOT`) | Donde vive `pipeline-state.json`; los worktrees comparten ese estado |
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
| `sdd-lead` | `requirements/*`, `changes/*`, `feedback/*`, `.claude/*`, `pipeline-state.json` **y el write-set de integración** (`src/*`, `tests/*`, `.github/*`, `package.json`, `*.config.*`, `task/TASK-FASE-*.md`, `.sdd/*`, `dashboard/*`), porque ejecuta `--integrate` en el principal; también `acceptance/*` (compartido con `sdd-qa`), porque la firma escribe `acceptance/decisions.jsonl` y el informe | requirements-engineer, req-change, task-implementer (solo `--stream base` e `--integrate`), acceptance (solo `--sign-off`) |
| `sdd-spec` | `spec/*`, `audits/AUDIT-*`, `audits/UPSTREAM-*`, `audits/CORRECTIONS-*`, `changes/*` | specifications-engineer, spec-auditor, req-change |
| `sdd-plan` | `design/*`, `ux/*`, `test/*`, `plan/*`, `task/*`, `audits/SECURITY-*` | tech-designer, ux-designer, security-auditor, test-planner, plan-architect, task-generator |
| `impl-f1a` | `src/*`, `tests/*`, `feedback/*`, `task/TASK-FASE-*.md`, `.sdd/*` | task-implementer (fase 1, stream A, worktree `../<proyecto>-f1a`) |
| `sdd-qa` | `.sdd/*`, `audits/GAP-*`, `acceptance/*`, `dashboard/*`, `feedback/*` | gap-detector, acceptance (`/sdd-acceptance --check`/`--loop`; la firma del cliente, `--sign-off`, la hace el lead tras la puerta de FASE) |

Una ruta puede tener varios dueños (`src/*` es del lead y de cada `impl-*`; `acceptance/*` del lead y de `sdd-qa`): la guardia solo comprueba que el rol que escribe la posea.

**El bucle de aceptación en multi-sesión.** `sdd-qa` no posee `task/` ni el código, así que su `/sdd-acceptance --loop` no ejecuta `sdd-task-generator` ni `sdd-task-implementer`: escribe las entradas de feedback del ciclo (`feedback/IMPL-FEEDBACK-FASE-N.md`) y envía un handoff `status=blocked` con la lista de rutas (`routes: REQ-F-004 implement-or-test FASE-2; …`). El lead despacha `task-generator --incremental` a `sdd-plan` y `task-implementer --new-tasks-only` a la estación de implementación, y luego devuelve el bucle a `sdd-qa`, que sigue desde `.sdd/acceptance-loop.json`. Lo que necesita a una persona (demo, medición, inspección, hueco de spec) llega al lead como pregunta en `.sdd/questions-sdd-qa.md`.

`sdd-spec` y `sdd-plan` no aportan paralelismo (la cadena es secuencial); su valor es aislar el contexto de etapas largas y poder retomarlas. Las estaciones que sí se ejecutan en paralelo son las `impl-*`.

## Recursos de la máquina

Las estaciones `impl-*`, los subagentes de un lote `[P]` y los verificadores de la ronda adversarial comparten la misma
máquina: CPU, memoria, el fichero de la base de datos, los puertos y los navegadores. Dos suites completas a la vez no
terminan antes; se ralentizan, agotan sus tiempos de espera y dan fallos intermitentes que parecen defectos del código.

La clave `test_slots` del SDD Stack Profile (por defecto `2`; `1` cuando los tests usan una base de datos en memoria o
compartida, navegadores o contenedores) fija cuántos procesos de test corren a la vez en la máquina. Es una convención,
no un lock: la respetan las skills.

- **Subagentes del implementer.** Como mucho `test_slots` agentes de un lote `[P]` ejecutan tests, siempre de uno en
  uno con `{test_file}`; nunca `{test}`, `{acceptance}` sin `--grep`, `{coverage}` ni modo watch, y nunca levantan
  servidores ni bases de datos fuera del runner. Con `test_slots: 1` los agentes escriben en paralelo y el hilo
  principal ejecuta sus tests en secuencia.
- **E2E.** Con `test_slots: 1`, Playwright corre con un solo worker en local (`--workers=1`); CI conserva su ajuste.
- **Streams.** Con `test_slots: 1`, *Stream Complete* (Phase 9-S) ejecuta solo los ficheros de test del Stream; la
  suite completa corre tras cada merge de `--integrate`, en el principal.
- **Estaciones.** El lead pregunta antes de despachar una segunda estación de implementación mientras otra está
  trabajando en la misma máquina. Con `test_slots: 1` recomienda esperar.
- **Ronda adversarial.** `sdd-acceptance --adversarial` no lanza más verificadores que ejecuten tests que `test_slots`.

Para más paralelismo real, cada estación en su propia máquina (o contenedor) con su propio checkout.

## Qué hacen los hooks con un rol

- **SessionStart**: muestra `Rol: <rol> (posee …; stages …) | Pares vivos: …` y el último handoff; exporta `SDD_PLUGIN_ROOT` y `SDD_STATE_ROOT` a la sesión.
- **Guardia upstream**: deniega escribir fuera de las rutas que el rol posee (aunque no haya etapa en marcha); la etapa "en marcha" que considera es la primera `running` **del rol**, no la global.
- **Estado**: `pipeline-state.json` se escribe siempre en el checkout principal, bajo lock (`mkdir`), también desde un worktree o desde `.claude/worktrees/`. Una etapa pasa a `running` cuando arranca su skill o cuando se escribe un fichero bajo su directorio.

## Implementación por Streams

En un plan vertical los Streams son la excepción: solo cuando una FASE se parte en conjuntos de escritura disjuntos. La mayoría de FASEs se implementan en secuencia en su rama `fase-{N}-{slug}`.

1. `sdd-task-generator` calcula los Streams de cada FASE (componentes conexas por write-set; el wiring compartido va al Stream `integración`) y los publica en la tabla *Stream Ownership* de `task/TASK-FASE-N.md` y en `task/TASK-ORDER.md`. `task/TASK-INDEX.md` es opcional (no existe en formato compacto): `node scripts/sdd.mjs tasks index` lo deriva y `tasks status` da el estado real por trailers `Task:`.
2. Las tasks `base` (Setup + Foundation) se implementan en el principal → checkpoint `fase-N-foundation`.
3. Cada Stream: `sdd-up.sh impl-fNx` → en el worktree, `/sdd-task-implementer --fase N --stream X`. Solo ve sus tasks; no crea tags; al terminar hace *Stream Complete* (tests y push de la rama, que pregunta) y envía el handoff.
4. El lead, en el principal: `/sdd-task-implementer --integrate --fase N` → `git merge --no-ff` por rama, tasks de `integración`, `--verify`, tag `fase-N-verified`, Persist Summary (el push pregunta).
5. Con un plan vertical, el lead presenta la demo de la FASE y los veredictos por requisito, y pregunta al cliente si acepta el incremento; con un sí explícito ejecuta `/sdd-acceptance --sign-off --fase N` (tag `fase-{N}-accepted`).

## Handoffs y preguntas

- Al terminar una etapa (tras Persist Summary y tras la pregunta de puerta local), la estación envía **un** mensaje al lead: `stage=<x> status=done|blocked gate=<…> artifacts=<n> root=<STATE_ROOT>; reread pipeline-state.json`. Se registra en `pipeline-state.json` como `stages.<x>.summary.handoff {to, sentAt, result}`. Nunca se envía "ejecuta X" a otra estación: los GO los emite el lead tras preguntar al humano.
- Un mensaje entre sesiones **no** es una aprobación del usuario ni puede contestar prompts de permisos (Claude Code lo bloquea).
- Una estación que necesitaría preguntar al humano escribe la pregunta en `$SDD_STATE_ROOT/.sdd/questions-<rol>.md`, sigue con lo que no está bloqueado y, al agotar trabajo, envía `status=blocked questions=<n>` y termina el turno. El lead (`/sdd-lead`) pregunta al humano, escribe `Answer:` en el fichero y avisa; la estación relee el fichero (disco = verdad).

Protocolos detallados: [`references/handoff-protocol.md`](../references/handoff-protocol.md), [`references/async-questions.md`](../references/async-questions.md). Diseño y revisión: [`multisesion/`](multisesion/).

## Ver qué está pasando

La observación en vivo de varias sesiones (panel `sdd-watch`, log de actividad, índice global de runs y status lines) ya no forma parte del plugin. Para saber qué hace cada estación:

- la tabla de estaciones de `/sdd-lead` (lee `pipeline-state.json`, los handoffs y las preguntas abiertas);
- `claude agents` o `ListAgents` desde la sesión lead, para ver qué sesiones están vivas;
- los issues y PRs de cada FASE o Stream en la plataforma de git.

Que el fan-out de una etapa se activó queda en `pipeline-state.json`: `summary.metrics.mode` (`fanout` o `sequential`) y `summary.metrics.task_agents` (agentes lanzados; `0` en secuencial), con el motivo de una degradación en `summary.highlights`.

## Límites conocidos

- `~/.claude/sessions/<pid>.json`, `CLAUDE_PID` y el socket de mensajería no están documentados por Claude Code: los hooks degradan a "sin rol" si cambian.
- Nombres de sesión duplicados obligan a desambiguar con el `[ref]` que muestra `ListAgents`; `sdd-up.sh` los evita.
- Agent Teams (experimental) no se usa: los teammates comparten checkout y no resuelven la serialización de commits.
