# Instalación y primeros pasos

## 1. Requisitos

| Componente | Versión | Para qué |
|---|---|---|
| Claude Code | ≥ 2.1.224 | plugins con hooks y MCP; mensajería entre sesiones (multi-sesión) |
| Node.js | ≥ 18 | servidor MCP (`server/dist/server.js`), hook `sdd-augment-hook.js`, fallback de los hooks sin `jq` |
| git | ≥ 2.32 | `git commit --trailer` (lo usan todos los commits SDD), hook `commit-msg`, `sdd trace`, worktrees |
| bash | 3.2+ (macOS) / 4+ (Linux) | hooks y scripts |
| jq | recomendado | hooks más rápidos; sin jq se usa `node -e` |
| python3 | opcional | `scripts/sdd-graph.py` (grafo JSON para el servidor MCP y los hooks) |
| gh / glab | opcional | issues y PRs con `tracker: github\|gitlab` (`sdd issue`, `sdd pr-body`) |
| tmux | opcional | `sdd-up.sh` (lanzar estaciones multi-sesión) |

macOS y Linux. En Windows, usa WSL 2 (los hooks son bash).

## 2. Instalar el plugin

Dentro de Claude Code:

```
/plugin marketplace add noelserdna/sdd-pipeline
/plugin install sdd-pipeline@noelserdna
```

Desde el terminal (útil para equipos, con `--scope project` queda en `.claude/settings.json` del repo):

```bash
claude plugin marketplace add noelserdna/sdd-pipeline
claude plugin install sdd-pipeline@noelserdna --scope project
```

Comprueba la instalación:

```
/plugin list                # sdd-pipeline@noelserdna · enabled
claude plugin details sdd-pipeline   # 21 skills, 5 hooks, MCP y coste de contexto (sin agentes)
```

Al abrir la primera sesión Claude Code pedirá aprobar el servidor MCP `sdd`. Las skills aparecen como `/sdd-<nombre>` (namespace `sdd-pipeline:`).

## 3. Inicializar un proyecto

En la raíz del proyecto (repositorio git):

```
/sdd-setup
```

Qué hace (y qué no):

- Crea `pipeline-state.json` (7 etapas en `pending`, `sddVersion`, `hooksVersion: 3`). Nunca lo sobrescribe.
- Instala el hook git `commit-msg` en el `.git` común (compartido por los worktrees) y copia el validador (`sdd.mjs` y sus módulos) a `.claude/sdd/`; versiona esa carpeta, porque el CI y los compañeros sin el plugin usan la misma copia. El hook ejecuta `sdd verify`: `feat`, `test` y `refactor` necesitan un trailer `Task:`; `fix` y `perf`, `Task:` o `Change:`; `docs(specs)` lleva `Refs:`. Deja pasar el resto de `docs`, `chore`, `ci`, `style`, `build`, merges, `Revert "…"` y los `fixup!`/`squash!`/`amend!` de autosquash. Los trailers se escriben con `git commit --trailer` (ver [git.md](git.md)).
- Comprueba git ≥ 2.32 y escribe un SDD Stack Profile mínimo con `task_state: trailers` en `CLAUDE.md` aunque no instales un kit.
- Añade a `.gitignore` el bloque `# sdd-begin … # sdd-end`: `pipeline-state.json`, `.sdd/`, `.claude/worktrees/`, `.claude/settings.local.json`, `dashboard/traceability-graph.json`. Recomienda versionar `.claude/settings.json`.
- Opcional: quality gates H7/H8, un kit por stack (`--stack=rails|nextjs-prisma`) y `--multisession` (roles en `.claude/sdd-sessions.json` + `.claude/sdd/sdd-up.sh`).
- En instalaciones 4.x, borra las status lines que instalaba (`.claude/sdd-status-line.sh`, `~/.claude/sdd/status-line.sh`) y su entrada `statusLine`.
- **No** copia hooks al proyecto: corren desde el plugin (`${CLAUDE_PLUGIN_ROOT}`).

Si detecta una instalación antigua (hooks en `.claude/hooks/sdd-*`, `sdd-upstream-guard` en `settings.json`, plugin `sdd@…` o `sdd-pipeline@sdd-pipeline-local`), propone ejecutar `scripts/migrate-hooks-v3.sh` — ver [migracion.md](migracion.md).

## 4. Primer recorrido

```
/sdd-requirements-engineer       → requirements/CUSTOMER-NEEDS.md, REQUIREMENTS.md (tag requirements-v1 al aprobar)
/sdd-specifications-engineer     → spec/
/sdd-spec-auditor                → audits/AUDIT-BASELINE.md (gate PASS / CONDITIONAL / BLOCKED)
/sdd-test-planner                → test/
/sdd-plan-architect              → plan/ (arquitectura, FASE-0 esqueleto + un incremento demostrable por FASE)
/sdd-task-generator              → task/
/sdd-task-implementer --fase=0   → rama fase-0-…, código y tests, un commit por tarea, demo del esqueleto
/sdd-acceptance --fase 0         → veredicto por requisito; --sign-off registra la aceptación del cliente
/sdd-pipeline-status             → estado, stale, siguiente paso
```

O deja que lo conduzca la skill `/sdd-orchestrator`: *"ejecuta el pipeline SDD para este proyecto"*. Para proyectos existentes empieza por `/sdd-pipeline-status --diagnose` (clasifica el proyecto y propone el orden de skills).

## 5. Probar el plugin sin instalarlo

```bash
git clone https://github.com/noelserdna/sdd-pipeline.git
cd tu-proyecto && claude --plugin-dir /ruta/a/sdd-pipeline
```

`/reload-plugins` recarga skills, hooks y MCP tras cambiar el plugin.

## 6. Actualizar

Claude Code busca actualizaciones del marketplace una vez por sesión. Manual: `/plugin marketplace update noelserdna` y `/plugin update sdd-pipeline@noelserdna`; después `/reload-plugins` o nueva sesión. Las versiones y cambios están en [CHANGELOG.md](../CHANGELOG.md).

## 7. Rendimiento: dónde se va el tiempo y cómo acortarlo

Cada etapa del pipeline es una sesión del modelo que lee specs y genera documentos; el tiempo es casi todo **generación de tokens de salida** (unos 5 k tokens ≈ 1 min) y, en menor medida, contexto leído. Ver `docs/perfilado.md` y la herramienta `scripts/sdd-profile.sh` para medir cualquier skill:

```bash
scripts/sdd-profile.sh --plugin-dir /ruta/al/plugin "/sdd-spec-auditor — audit spec/ without asking questions"
scripts/sdd-profile.sh --analyze .sdd/profile-*.jsonl
```

Palancas ya integradas en las skills (4.0.1+): plantillas de informe compactas (detalle solo P0-P2), lectura por índice en vez de `cat` de todo `spec/`, y fan-out en subagentes por dimensión/UC para auditoría y matrices de test.

Palancas del entorno:

| Variable / flag | Efecto |
|---|---|
| `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` (o `haiku`) | Los subagentes que lanzan las skills (auditores por dimensión, matrices por UC, tasks `[P]` del implementer, TECH/PATTERN del plan) corren con un modelo más rápido; la consolidación, las specs y los gates siguen con el modelo principal |
| `claude --model sonnet` | Toda la sesión con un modelo más rápido: útil para `task-generator`, `test-planner` o FASEs mecánicas; no recomendado para `specifications-engineer` ni `spec-auditor` |
| `tests/e2e/20-smoke.sh --until <stage>` | Validar cambios de skills sin recorrer el pipeline completo |

Orden de magnitud con el todo-app de ejemplo (10 requisitos), medido en 4.x con el plan horizontal anterior: specs 35 min, auditoría 21, tests 30, plan 27, tasks 24, FASE-0 27, FASE-1 por Streams ~60 (`docs/medidas.md`).
