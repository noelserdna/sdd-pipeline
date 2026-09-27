# Migración

## De 4.x a 5.0

5.0 retira piezas, cambia cómo se escriben los commits y hace verticales las FASEs. Los proyectos que ya usan 4.x siguen funcionando; estos son los cambios que notarás.

**Pasos:**

1. Actualiza el plugin (`/plugin marketplace update noelserdna`, `/plugin update sdd-pipeline@noelserdna`) y abre una sesión nueva.
2. En cada proyecto, ejecuta `/sdd-setup` otra vez. Reinstala el hook `commit-msg`, **copia el validador a `.claude/sdd/`** (versiónalo: el hook y el CI lo usan), comprueba git ≥ 2.32 y limpia las status lines de 4.x (`.claude/sdd-status-line.sh`, `.claude/sdd-subagent-status.sh`, `~/.claude/sdd/status-line.sh`, `active-runs.json` y la entrada `statusLine` que los ejecutaba). Un `statusLine` ajeno al plugin se conserva.
3. Opcional: añade al SDD Stack Profile las claves nuevas (abajo). `sdd-setup --tracker` instala las plantillas de CI y de issues/PRs si usas GitHub o GitLab.

**Skills y comandos retirados:**

| Antes | Ahora |
|---|---|
| `/sdd-traceability-check` | `/sdd-acceptance --check` (incluye la integridad de la cadena de IDs) |
| `/sdd-dashboard` y el HTML | `python3 scripts/sdd-graph.py` construye `dashboard/traceability-graph.json` para el MCP y los hooks; la vista compartible es `acceptance/ACCEPTANCE-REPORT.md` o la página de `/sdd-acceptance --publish` |
| `/sdd-code-index` (GitNexus) | `sdd trace why <fichero>[:línea]` |
| `/sdd-watch`, `sdd-watch.sh`, status lines, `install-global-statusline.sh` | La tabla de estaciones de `/sdd-lead`, `pipeline-state.json`, las issues/PRs de cada FASE |
| Hooks `sdd-trace-map-updater.sh`, `sdd-activity-log.sh`, `sdd-runs-line.sh` | Nada: los commits con `Task:` llevan la información. Quedan 5 hooks |
| `.sdd/current-task.json`, `.sdd/trace-map.json`, `.sdd/activity*.jsonl` | `migrate-hooks-v3.sh` (lo propone `/sdd-setup`) los borra |
| `scripts/sdd-task-lint.mjs` | `scripts/sdd.mjs` (el nombre antiguo sigue como alias) |

**Commits.** Los trailers se escriben con `git commit --trailer` y el hook valida con `sdd verify`: `fix` y `perf` aceptan `Task:` o `Change:` (antes siempre pedían `Refs:`/`Task:`), y un bloque de trailers roto se señala por línea. Los commits antiguos sin bloque válido se leen del cuerpo y aparecen como `legacy` en `sdd trace`. El trabajo nuevo empieza en una rama y se integra con merge commit, nunca squash. Ver [git.md](git.md).

**Estado de tareas.** Los proyectos nuevos usan `task_state: trailers` (una tarea está hecha si hay un commit con su `Task:`). Un proyecto 4.x sin esa clave sigue con `checkbox`; cámbialo cuando quieras en el Stack Profile.

**Claves nuevas del SDD Stack Profile** (todas opcionales, ver [stacks.md](stacks.md)):

| Clave | Para qué | Por defecto |
|---|---|---|
| `test_report` | Comando que escribe JUnit XML con los tests nombrados por escenario (`AC-NNN-NN`) | `none` |
| `test_report_path` | Dónde leer ese JUnit | `.sdd/junit/` |
| `acceptance_gate` | Modo de `sdd gate`: `off`, `warn`, `enforce` | `enforce`; usa `warn` al adoptar SDD en un proyecto existente |
| `tracker` | `github`, `gitlab` u `off` para `sdd issue` / `sdd pr-body` | `off` |
| `default_branch` | Rama por defecto si no es la de `origin/HEAD` | detectada |

**Planes y requisitos existentes.** Un `plan/PLAN.md` sin `Plan-Style: vertical` se sigue tratando como horizontal: sus FASEs se conservan y las nuevas se añaden en vertical después de la última verificada (`Plan-Style: vertical (from FASE-N)`). Los requisitos sin `Needs:` ni `Verification:` siguen siendo válidos, pero `sdd lint --needs` los señala y `sdd-acceptance` los trata como huecos de spec hasta que declaren cómo se verifican.

## De los plugins anteriores a `sdd-pipeline@noelserdna` (4.0.0)

### ¿Qué instalación tienes?

| Situación | Señales |
|---|---|
| **P1** plugin `sdd@noelserdna-claude-plugin-sdd` (v1.5–3.1) | `/plugin list` muestra `sdd@noelserdna-claude-plugin-sdd` |
| **P2** plugin local `sdd-pipeline@sdd-pipeline-local` (17 skills) | `/plugin list` muestra `sdd-pipeline@sdd-pipeline-local`; `extraKnownMarketplaces` en `~/.claude/settings.json` |
| **P3** hooks copiados al proyecto por `install-sdd-automation.sh` (hooks v1/v2) | `.claude/hooks/sdd-*.sh`, `.claude/agents/sdd-*.md`, `sdd-upstream-guard` en `.claude/settings.json`, `pipeline-state.json` sin `hooksVersion` o con valor < 3 |

Las tres pueden coexistir. Si conviven dos plugins tendrás skills `sdd-pipeline:*` duplicadas; si conviven hooks copiados y el plugin, la guardia upstream y la actualización de estado se ejecutarán dos veces. Por eso el orden importa.

### Pasos

1. Desinstala lo antiguo (dentro de Claude Code):
   ```
   /plugin uninstall sdd@noelserdna-claude-plugin-sdd        # P1
   /plugin uninstall sdd-pipeline@sdd-pipeline-local         # P2
   /plugin marketplace remove noelserdna-claude-plugin-sdd   # P1
   /plugin marketplace remove sdd-pipeline-local             # P2
   ```
2. Instala el nuevo:
   ```
   /plugin marketplace add noelserdna/sdd-pipeline
   /plugin install sdd-pipeline@noelserdna
   ```
3. Abre una sesión nueva en cada proyecto y ejecuta `/sdd-setup`. El Step 0 detecta las señales de P3 y ejecuta `scripts/migrate-hooks-v3.sh --dry-run`; revisa la tabla y confirma para aplicar.

### Qué hace `migrate-hooks-v3.sh`

- Elimina de `.claude/settings.json` los hooks cuyo `command` contiene `sdd-` (H1, H2, H3, H5, H9 copiados) y **conserva** cualquier hook ajeno.
- Borra `.claude/hooks/sdd-*.sh|.js` y `.claude/agents/sdd-*.md` (los hooks los aporta el plugin; los agentes copiados ya no existen: `sdd-orchestrator` es ahora una skill y el resto se retiró), con copia en `.claude/backups/<fecha>/`.
- Elimina las status lines copiadas y la entrada `statusLine` que ejecutaba un script SDD (desde 5.0 el plugin ya no trae status lines).
- Reinstala el hook git `commit-msg` desde el plugin (`scripts/install-git-hooks.sh`).
- Pone `sddVersion` (versión del plugin) y `hooksVersion: 3` en `pipeline-state.json`; aplica la política `.gitignore`.
- Idempotente; `--dry-run` no toca nada. Manual: `bash "$SDD_PLUGIN_ROOT/scripts/migrate-hooks-v3.sh" [--dry-run]`.

### Cambios que afectan a lo que ya tenías

- `/sdd:<skill>` → `/sdd-<skill>` (el prefijo `sdd-` forma parte del nombre de la skill; el namespace es `sdd-pipeline:`).
- `version:` desaparece del frontmatter de las skills; la versión es la del plugin.
- El servidor MCP ya no se configura a mano en `.mcp.json` del proyecto: lo registra el plugin como `sdd`. Si tenías una entrada manual apuntando a `sdd-skills/server/dist/index.js`, bórrala para no tener dos servidores.
- `pipeline-state.json` deja de versionarse (política `.gitignore`); si estaba trackeado, `git rm --cached pipeline-state.json`.

### Solo para el autor de los repos antiguos

Marketplaces locales en `~/.claude/settings.json` (`sdd-pipeline-local` y el marketplace roto que apuntaba a un directorio ya inexistente) → `/plugin marketplace remove`; symlink `~/.claude/plugins/sdd-pipeline` → borrar; instalar desde el remoto.
