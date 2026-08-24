# Migración a `sdd-pipeline@noelserdna` (4.0.0)

## ¿Qué instalación tienes?

| Situación | Señales |
|---|---|
| **P1** plugin `sdd@noelserdna-claude-plugin-sdd` (v1.5–3.1) | `/plugin list` muestra `sdd@noelserdna-claude-plugin-sdd` |
| **P2** plugin local `sdd-pipeline@sdd-pipeline-local` (17 skills) | `/plugin list` muestra `sdd-pipeline@sdd-pipeline-local`; `extraKnownMarketplaces` en `~/.claude/settings.json` |
| **P3** hooks copiados al proyecto por `install-sdd-automation.sh` (hooks v1/v2) | `.claude/hooks/sdd-*.sh`, `.claude/agents/sdd-*.md`, `sdd-upstream-guard` en `.claude/settings.json`, `pipeline-state.json` sin `hooksVersion` o con valor < 3 |

Las tres pueden coexistir. Si conviven dos plugins tendrás skills `sdd-pipeline:*` duplicadas; si conviven hooks copiados y el plugin, la guardia upstream y la actualización de estado se ejecutarán dos veces. Por eso el orden importa.

## Pasos

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

## Qué hace `migrate-hooks-v3.sh`

- Elimina de `.claude/settings.json` los hooks cuyo `command` contiene `sdd-` (H1, H2, H3, H5, H9 copiados) y **conserva** `statusLine` y cualquier hook ajeno.
- Borra `.claude/hooks/sdd-*.sh|.js` y `.claude/agents/sdd-*.md` (el plugin los aporta), con copia en `.claude/backups/<fecha>/`.
- Si la status line apuntaba a `.claude/hooks/sdd-status-line.sh`, copia la nueva a `.claude/sdd-status-line.sh` y actualiza la ruta.
- Reinstala el hook git `commit-msg` desde el plugin (`scripts/install-git-hooks.sh`).
- Pone `sddVersion` (versión del plugin) y `hooksVersion: 3` en `pipeline-state.json`; aplica la política `.gitignore`.
- Idempotente; `--dry-run` no toca nada. Manual: `bash "$SDD_PLUGIN_ROOT/scripts/migrate-hooks-v3.sh" [--dry-run]`.

## Cambios que afectan a lo que ya tenías

- `/sdd:<skill>` → `/sdd-<skill>` (el prefijo `sdd-` forma parte del nombre de la skill; el namespace es `sdd-pipeline:`).
- `version:` desaparece del frontmatter de las skills; la versión es la del plugin.
- El servidor MCP ya no se configura a mano en `.mcp.json` del proyecto: lo registra el plugin como `sdd`. Si tenías una entrada manual apuntando a `sdd-skills/server/dist/index.js`, bórrala para no tener dos servidores.
- `pipeline-state.json` deja de versionarse (política `.gitignore`); si estaba trackeado, `git rm --cached pipeline-state.json`.

## Solo para el autor de los repos antiguos

Marketplaces locales en `~/.claude/settings.json` (`sdd-pipeline-local` y el marketplace roto que apuntaba a un directorio ya inexistente) → `/plugin marketplace remove`; symlink `~/.claude/plugins/sdd-pipeline` → borrar; instalar desde el remoto.
