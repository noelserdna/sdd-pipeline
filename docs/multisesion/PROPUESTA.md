# Propuesta: encajar sesiones con nombre, mensajería entre sesiones, subagentes/Workflow, worktrees y (opcionalmente) Agent Teams en el pipeline SDD

## Hechos verificados hoy (Claude Code v2.1.241, macOS)
- Sesiones con nombre: `claude -n <nombre>` o `/rename <nombre>`. Persisten en el transcript como `{"type":"custom-title"}` y `{"type":"agent-name"}` y en `<sessionDir>/custom-title.json`. Se retoman con `claude --resume`.
- `/color red|blue|green|yellow|purple|orange|pink|cyan|default` persiste como `{"type":"agent-color"}`. No hay flag `--color`.
- Mensajería entre sesiones (desde v2.1.224, activa por defecto): herramientas `ListAgents` y `SendMessage {to:"<nombre>", message, notify_when_idle}`. Transporte: socket Unix `/tmp/cc-socks/<pid>.sock`; registro de sesiones vivas en `~/.claude/sessions/<pid>.json` (name, status busy/idle, cwd, tmux pane). El mensaje llega al receptor como `<cross-session-message from="uds:..." from-name="...">`; si está idle, arranca un turno nuevo; si está ocupado, se encola entre tool calls. `notify_when_idle: true` da UN aviso cuando la sesión destino queda idle. Setting `crossSessionInbound: accept|hold|refuse`. Un mensaje de un par NO puede aprobar prompts de permisos ni actuar como consentimiento del usuario (permission laundering bloqueado; en auto mode el clasificador revisa cada mensaje).
- Se puede lanzar una sesión desde otra: `tmux new-session -d -s database -c <dir> 'claude -n database'` + `tmux send-keys -t database '/color red' Enter`. ListAgents la muestra con su pane tmux. Probado: front→database tarea, database ejecuta (con 5 subagentes en paralelo), responde a front, front verifica; aviso de idle recibido.
- Subagentes (tool Agent) y tool Workflow (orquestación determinista por fases) funcionan sin flags. Los subagentes devuelven el resultado al que los lanzó.
- Agent Teams: experimental, requiere `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Desde v2.1.178 no existen TeamCreate/TeamDelete: un subagente al que Claude pone `name` se lanza como teammate. Lista de tareas compartida en `~/.claude/tasks/session-xxxxxxxx/` con dependencias, auto-reclamación y file locking; buzones en `~/.claude/teams/<team>/inboxes/<agent>.json`. Hooks `TeammateIdle`, `TaskCreated`, `TaskCompleted`. Limitaciones documentadas: `/resume` no restaura teammates; un equipo por sesión; sin equipos anidados; teammates in-process no pueden lanzar subagentes en background; con el flag activo "an orchestration flow that waits on subagent results can stall" (afecta a Workflows).
- Worktrees: `claude -w <nombre>` crea worktree+rama para la sesión; `--tmux` (requiere `--worktree`) abre pane.

## Idea central
El pipeline SDD es una cadena secuencial con puertas (req → spec → audit → laterales → test → plan → task → impl) con paralelismo dentro de etapa. Nada de lo anterior cambia la cadena; cambia DÓNDE corre cada etapa y CÓMO se avisa el paso de testigo. `pipeline-state.json` + artefactos siguen siendo la única fuente de verdad; los mensajes son punteros + resumen, nunca contenido de spec.

| Capa | Papel en SDD |
|---|---|
| Sesiones con nombre (larga vida, resume) | Una por tramo del pipeline; cada una "posee" unos directorios |
| Subagentes / Workflow | Paralelismo intra-etapa ya existente (laterales, auditoría por dimensión, TECH/PATTERN, tasks [P]) |
| Mensajería entre sesiones | Cada puerta dispara un mensaje a la sesión siguiente |
| Worktrees + sesiones | Un worktree por Wave/Stream de TASK-ORDER.md para implementación paralela real |
| Agent Teams | Opcional, solo implementación; no activar aún |

## Estaciones propuestas (empezar con 3, crecer a 5-6)
- `sdd-lead`: el humano + sdd-orchestrator + las 12 decisiones humanas (sdd-orchestrator.md:85-184). Todas las decisiones de puerta siguen aquí.
- `sdd-spec` (azul): requirements-engineer, specifications-engineer, spec-auditor, req-change. Posee requirements/ spec/ audits/ changes/.
- `sdd-plan` (verde): test-planner, plan-architect, task-generator; laterales (tech-designer, ux-designer, security-auditor) como subagentes en background. Posee design/ ux/ test/ plan/ task/.
- `impl-f0`, `impl-f1a`, `impl-f1b` (rojo): task-implementer por FASE/Stream, cada uno en su worktree.
- `sdd-qa` (gris): gap-detector, traceability-check, dashboard; solo lectura.
Justificación: aislamiento de contexto por tramo (la conversación de escribir 60 UC no debe cargar al implementador); persistencia (`--resume sdd-spec` semanas después para un req-change); encaja con hook H2 upstream-guard (posesión de directorios por rol); las decisiones humanas no se delegan a pares.

## Handoffs como mensajes (puntero + resumen; el receptor relee pipeline-state.json)
| Puerta | De → A | Mensaje |
|---|---|---|
| REQUIREMENTS.md Status: Approved | lead → sdd-spec | "requirements-engineer=done. Ejecuta specifications-engineer." |
| AUDIT-BASELINE Gate PASS | sdd-spec → sdd-plan (+lead) | "spec-auditor=done, gate PASS, 0 P0. Lanza laterales y test-planner." |
| Gate CONDITIONAL/BLOCKED | sdd-spec → lead | "Gate BLOCKED: 4 Tier-1 sin REQ. Necesito decisión." |
| TASK-INDEX + TASK-ORDER | sdd-plan → lead | "task-generator=done. Waves: F0 → {F1,F2} → F3. Streams F1: A,B." |
| Lead lanza implementadores | lead → impl-fN (+notify_when_idle) | "Implementa FASE-1 Stream A en tu worktree. Avísame al verificar." |
| git tag fase-0-verified | impl-f0 → impl-f1a, impl-f1b | "FASE-0 verificada. Podéis empezar tasks con dependencia cross-FASE." |
| feedback/FB-xxx.md | impl → sdd-spec | "UC-012 ambiguo en paso 4; feedback/FB-003.md" |
| CHANGE-REPORT APPROVED | sdd-spec → dueñas de stages invalidados | "CHG-... APPROVED. Stale: plan, task. impl-f2: para tasks que referencian UC-012." |
| Fin de sesión | cualquiera → lead | sdd-session-summary por mensaje |
Regla: si el mensaje se pierde, el pipeline no se rompe (estado en disco; H1 SessionStart ya dice "N/7 done, next: X").

## Implementación paralela con worktrees
TASK-ORDER.md ya calcula Waves de FASEs, Cross-FASE Dependencies y Streams A/B/C sin ficheros compartidos. La regla "los commits se crean secuencialmente" (sdd-task-implementer/SKILL.md:609) está pensada para subagentes en UN repo; con worktrees cada sesión commitea en su rama y se integra en la frontera de Wave. Comando: `claude -w fase-1-a -n impl-f1a` + `/color red` + prompt "/sdd-task-implementer --fase=1 --stream=A; al verificar FASE (tag fase-1-verified) avisa a sdd-lead".
Problemas a resolver: (1) pipeline-state.json y .sdd/ en worktrees: si están versionados, cada worktree tiene su copia y los hooks H3/H9 divergen → los hooks deben resolver la ruta al worktree principal (git rev-parse --git-common-dir) o usar SDD_STATE_ROOT. (2) `currentStage` es escalar; con dos sesiones activas hay dos stages running → currentStage pasa a informativo y H2 decide por nombre de sesión (rol).

## Agent Teams
Encaja en un solo sitio: implementación de una Wave, con impl como lead, un teammate por Stream y la lista de tareas compartida cargada con las tasks [P] de la FASE (dependencias + auto-reclamación), mapeo casi 1:1 con el "Parallel Execution Plan". H8 opt-in (TaskCompleted) es el hook de teams. Pero: experimental, sin resume, y el flag puede colgar Workflows. Worktrees + sesiones dan el 80% sin esos riesgos. Dejar Teams como experimento aislado.

## Cambios concretos propuestos al plugin
- C1. `sdd-setup --multisession`: genera `sdd-sessions.json` (rol → nombre, color, directorios que posee, stage que dispara) y un lanzador tmux `sdd-up.sh` que abre las estaciones con `claude -n` + `/color`.
- C2. Bloque "Persist Summary" de cada skill (ya escribe status: done + nextStep): añadir "si existe en ListAgents la sesión dueña del nextStep, envíale nextStep por SendMessage". O una sola vez en el orquestador.
- C3. H1 SessionStart: además de "N/7 done, next: X", inyectar "eres sdd-spec: posees spec/…; pares vivos: sdd-lead, sdd-plan" leyendo sdd-sessions.json y ~/.claude/sessions/*.json.
- C4. H2 upstream-guard: decidir el rol por nombre de sesión, no por currentStage.
- C5. `sdd-task-implementer --stream=X`: relaja "commits secuenciales" a "secuenciales por worktree"; al verificar FASE, mensaje a lead y a FASEs dependientes (leyendo Cross-FASE Dependencies).
- C6. `sdd-req-change`: al pasar a APPROVED, difundir a las sesiones dueñas de los stages invalidados.
- C7. `sdd-session-summary`: enviar el resumen a sdd-lead al terminar.

## Guion de prueba (un día)
1. `claude -n sdd-lead` → /sdd-setup, requisitos, aprobar.
2. Lead lanza sdd-spec por tmux y le pide specifications-engineer + spec-auditor con notify_when_idle.
3. sdd-spec audita con Workflow por dimensiones (DOM/UC/CON/NFR → verificar → consolidar), escribe AUDIT-BASELINE, avisa.
4. Lead decide el gate; manda a sdd-plan: laterales como 3 subagentes background, test-planner, plan-architect, task-generator.
5. Lead lee TASK-ORDER y abre impl-f0; al llegar fase-0-verified, abre impl-f1a e impl-f1b en worktrees.
6. sdd-qa corre gap-detector y traceability-check sobre el worktree principal tras cada merge de Wave.
