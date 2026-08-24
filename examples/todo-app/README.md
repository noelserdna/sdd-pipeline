# todo-app — proyecto de juguete para las pruebas E2E del plugin `sdd-pipeline`

Proyecto mínimo con los **requisitos ya escritos** (`requirements/REQUIREMENTS.md`, `Status: Approved`) para ejecutar el pipeline
completo de forma reproducible: specs → auditoría → plan → tasks → implementación de FASE-0 y FASE-1.

Está diseñado para que FASE-1 tenga **dos Streams con write-sets disjuntos** (`src/api/` y `src/cli/`) y así probar la
implementación paralela en worktrees (`--stream`, `--integrate`).

## Stack fijo (no lo cambies: `AUDIT-HISTORY.md` compara ejecuciones entre versiones)

- Node ≥ 18, TypeScript, ESM
- Tests: vitest
- Persistencia: fichero JSON en `data/todos.json`
- Sin framework web ni base de datos

## Uso en las pruebas

```bash
cp -R examples/todo-app /tmp/todo-app && cd /tmp/todo-app && git init -q && git add -A && git commit -qm "chore: toy project"
export CLAUDE_CONFIG_DIR=$(mktemp -d)
claude --plugin-dir /ruta/al/plugin -p "/sdd-setup"
claude --plugin-dir /ruta/al/plugin -p "/sdd-specifications-engineer"
# … ver tests/e2e/20-smoke.sh
```

`AUDIT-HISTORY.md` registra los resultados del `sdd-pipeline-auditor` por versión del plugin.
