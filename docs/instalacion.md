# Instalación y primeros pasos

## 1. Requisitos

| Componente | Versión | Para qué |
|---|---|---|
| Claude Code | ≥ 2.1.224 | plugins con hooks y MCP; mensajería entre sesiones (multi-sesión) |
| Node.js | ≥ 18 | servidor MCP (`server/dist/server.js`), hook `sdd-augment-hook.js`, fallback de los hooks sin `jq` |
| git | cualquiera reciente (≥ 2.31 para worktrees con `--git-common-dir`) | hook `commit-msg`, trazabilidad por commits, worktrees |
| bash | 3.2+ (macOS) / 4+ (Linux) | hooks y scripts |
| jq | recomendado | hooks más rápidos; sin jq se usa `node -e` |
| python3 | opcional | `sdd-dashboard` |
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
claude plugin details sdd-pipeline   # 23 skills, 5 agentes, hooks, MCP y coste de contexto
```

Al abrir la primera sesión Claude Code pedirá aprobar el servidor MCP `sdd`. Las skills aparecen como `/sdd-<nombre>` (namespace `sdd-pipeline:`).

## 3. Inicializar un proyecto

En la raíz del proyecto (repositorio git):

```
/sdd-setup
```

Qué hace (y qué no):

- Crea `pipeline-state.json` (7 etapas en `pending`, `sddVersion`, `hooksVersion: 3`). Nunca lo sobrescribe.
- Instala el hook git `commit-msg` en el `.git` común (compartido por los worktrees): exige `Refs:`/`Task:` en commits `feat|fix|perf|test|refactor`.
- Añade a `.gitignore` el bloque `# sdd-begin … # sdd-end`: `pipeline-state.json`, `.sdd/`, `.claude/worktrees/`, `.claude/settings.local.json`, `dashboard/traceability-graph.json`. Recomienda versionar `.claude/settings.json`.
- Opcional: status line (`.claude/sdd-status-line.sh` + `statusLine` en `.claude/settings.json`, con `refreshInterval: 5` para que se repinte cada 5 s también mientras la sesión espera a subagentes; muestra rol, etapas, skill en curso, minutos y agentes activos), quality gates H7/H8, y `--multisession` (roles en `.claude/sdd-sessions.json` + `.claude/sdd/sdd-up.sh`).
- **No** copia hooks ni agentes al proyecto: corren desde el plugin (`${CLAUDE_PLUGIN_ROOT}`).

Si detecta una instalación antigua (hooks en `.claude/hooks/sdd-*`, `sdd-upstream-guard` en `settings.json`, plugin `sdd@…` o `sdd-pipeline@sdd-pipeline-local`), propone ejecutar `scripts/migrate-hooks-v3.sh` — ver [migracion.md](migracion.md).

## 4. Primer recorrido

```
/sdd-requirements-engineer       → requirements/REQUIREMENTS.md (Status: Approved)
/sdd-specifications-engineer     → spec/
/sdd-spec-auditor                → audits/AUDIT-BASELINE.md (gate PASS / CONDITIONAL / BLOCKED)
/sdd-test-planner                → test/
/sdd-plan-architect              → plan/ (arquitectura, FASEs)
/sdd-task-generator              → task/
/sdd-task-implementer --fase=0   → src/, tests/, commits
/sdd-pipeline-status             → estado, stale, siguiente paso
```

O pide al agente `sdd-orchestrator` que lo conduzca: *"ejecuta el pipeline SDD para este proyecto"*. Para proyectos existentes empieza por `/sdd-onboarding`.

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

Orden de magnitud con el todo-app de ejemplo (10 requisitos): specs 35 min, auditoría 21, tests 30, plan 27, tasks 24, FASE-0 27, FASE-1 por Streams ~60 (`docs/medidas.md`).
