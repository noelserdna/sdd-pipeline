# todo-app — proyecto de juguete para las pruebas E2E del plugin `sdd-pipeline`

Proyecto mínimo con las **necesidades del cliente y los requisitos ya escritos** para ejecutar el pipeline completo de forma
reproducible: specs → auditoría → plan vertical → tasks → implementación por FASE → aceptación por requisito.

- `requirements/CUSTOMER-NEEDS.md`: 6 necesidades `N-NNN` en palabras del cliente (una fuera de alcance, con su decisión).
- `requirements/REQUIREMENTS.md` (`Status: Approved`): 10 requisitos, cada uno con `Needs:`, `Verification:` y criterios
  con ejemplos concretos.

El plan esperado es vertical (referencia: `tests/fixtures/plan-vertical/todo`): FASE-0 es el esqueleto andante
(`todo add` + `todo list` + persistencia en `data/todos.json`), después completar y borrar, filtrar por estado y, al final,
`FASE-3-HARDENING` para la latencia medida con 1 000 tareas. Cada FASE termina con su demo y `sdd-acceptance --fase N`.

La implementación paralela en worktrees (`--stream`, `--integrate`) ya no se prueba con este proyecto, porque sus FASEs
verticales no tienen conjuntos de escritura disjuntos: la cubre `tests/e2e/50-streams.sh` con `tests/fixtures/plan-mini`.

## Stack fijo (no lo cambies: `AUDIT-HISTORY.md` compara ejecuciones entre versiones)

- Node ≥ 18, TypeScript, ESM
- Tests: vitest (JUnit para la aceptación: `npx vitest run --reporter=junit --outputFile=.sdd/junit/vitest.xml`)
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

`AUDIT-HISTORY.md` registra los resultados del agente `sdd-pipeline-auditor` por versión del plugin. Es una herramienta de mantenimiento local del repositorio (`.claude/agents/sdd-pipeline-auditor.md`), no se distribuye con el plugin.
