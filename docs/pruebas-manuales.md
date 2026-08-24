# Pruebas manuales (B4 paso 5): sesiones reales con tmux

Lo que no puede automatizarse sin el modelo: dos sesiones de Claude Code con rol que se envían un handoff.

## Preparación

```bash
cp -R examples/todo-app /tmp/todo-app && cd /tmp/todo-app && git init -q -b main . && git add -A && git commit -qm "chore: toy"
claude --plugin-dir /ruta/a/sdd-pipeline            # o con el plugin instalado
/sdd-setup --multisession                            # roles todo-lead, todo-spec, todo-plan, todo-impl-f1a, todo-qa
```

## Pasos

1. `.claude/sdd/sdd-up.sh sdd-lead` y `.claude/sdd/sdd-up.sh sdd-spec` (dos sesiones tmux; `tmux ls` las muestra).
2. `tmux attach -t todo-lead` → en el lead: `ListAgents` (pídelo: "lista las sesiones") → debe aparecer `todo-spec`.
   El prompt del lead muestra `[sdd-lead]` en la status line y el hook de arranque `Rol: sdd-lead … Pares vivos: todo-spec(idle)`.
3. En el lead: `/sdd-lead` → modo Dispatch → responde a la pregunta de puerta → el lead envía `GO stage=specifications-engineer` a `todo-spec` con `notify_when_idle`.
4. `tmux attach -t todo-spec` → la estación recibe `<cross-session-message from-name="todo-lead">`, ejecuta la skill y, al terminar, envía `stage=specifications-engineer status=done …` al lead.
5. En el lead llega el mensaje y el aviso de idle; `jq '.stages["specifications-engineer"].summary.handoff' pipeline-state.json` → `{to:"todo-lead", sentAt, result:"sent"}`.
6. Pregunta bloqueante: en `todo-spec` provoca una (p. ej. requisito ambiguo) → aparece `.sdd/questions-sdd-spec.md` con `[OPEN]` y el handoff `status=blocked questions=1`; en el lead `/sdd-lead` modo Answer → escribe `Answer:` → la estación relee y continúa.
7. Worktree: `.claude/sdd/sdd-up.sh impl-f1a` crea `../todo-f1a` desde `fase-1-foundation` (o HEAD si no existe) y lanza `todo-impl-f1a` en rojo; `/sdd-task-implementer --fase 1 --stream A` solo ve las tasks del Stream A.
8. Integración: en el lead, `/sdd-task-implementer --integrate --fase 1`.

## Qué anotar en `docs/coste-contexto.md` / `.sdd/bench`

Tiempo por etapa, nº de PAUSE, si el handoff llegó (`result`), y cualquier mensaje bloqueado por el clasificador de permisos.

## Salir sin cerrar

`Ctrl+B, D` desconecta de tmux sin matar la sesión. `tmux kill-session -t <nombre>` la cierra.
