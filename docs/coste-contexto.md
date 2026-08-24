# Coste de contexto del plugin

Medido con `claude plugin details sdd-pipeline` tras instalar desde el marketplace en un `CLAUDE_CONFIG_DIR` limpio (Claude Code 2.1.241).

| Versión | Fecha | Skills | Agentes | Always-on | Mayor on-invoke | Nota |
|---|---|---|---|---|---|---|
| sdd-pipeline 3.1.0 (local) | 2026-08-24 | 17 | 3 | ~5.743 tok | — | baseline previa a la fusión |
| sdd-pipeline 4.0.0-alpha.1 | 2026-08-24 | 23 | 5 | **~4.806 tok** | sdd-req-change ~16,2k | hooks y MCP no cuentan como contexto |
| sdd-pipeline 4.0.0-alpha.2 | 2026-08-24 | 24 | 5 | ~4.880 tok | sdd-req-change ~16,2k | + sdd-lead |
| sdd-pipeline 4.0.0-beta.1 (+descripciones ≤ 350) | 2026-08-24 | 24 | 5 | **~3.390 tok** | sdd-req-change ~16,2k | tras recortar 19 descriptions (de 403-934 a ≤ 350 chars) |

Per-componente (always-on, alpha.1): las 23 skills entre ~90 y ~240 tok; agentes: `sdd-pipeline-auditor` ~550, `sdd-orchestrator` ~410, resto ≤ ~50.

Umbral acordado: si el always-on supera **8.000 tok**, dividir en `sdd-pipeline` (core) + `sdd-brownfield` en el mismo marketplace. Con 4.806 no procede.

Cómo repetir la medida:

```bash
export CLAUDE_CONFIG_DIR=$(mktemp -d)
claude plugin marketplace add /ruta/al/repo      # o noelserdna/sdd-pipeline
claude plugin install sdd-pipeline@noelserdna
claude plugin details sdd-pipeline
```

## Experimento: conflictos en `task/TASK-FASE-N.md` con dos Streams (2026-08-24)

`docs/experimentos/exp-2-worktrees.sh 5`: dos ramas marcan `[x]` tasks alternas (una por commit) sobre bloques de task de 7 líneas,
10 merges `--no-ff` → **0 conflictos**; todas las marcas llegan a `main`. La variante adversa (checkboxes en líneas contiguas, sin
bloque) sí conflictúa: por eso el formato de task de `sdd-task-generator` (bloque Commit/Acceptance/Refs/Revert/Review por task) es
requisito del modo Stream, y el implementer mantiene "checkbox-first" (el `[x]` viaja en el commit de cada task).
