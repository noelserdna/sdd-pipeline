# Aviso de archivado para los repositorios antiguos

Texto a colocar como **primera sección** del `README.md` (y `README.es.md`) de `noelserdna/sdd-skills` y `noelserdna/claude-plugin-sdd`
antes de ejecutar `gh repo archive`. El repositorio GitLab `recursos/sdd-plugin` recibe el mismo aviso.

---

> ## ⚠️ ARCHIVED (2026-08) — development continues at [noelserdna/sdd-pipeline](https://github.com/noelserdna/sdd-pipeline)
>
> This repository is read-only at **v3.1.0**. Version 4.0.0+ of the SDD pipeline (23 skills, 5 agents, hooks, MCP server and
> multi-session implementation) lives in a single distributable plugin:
>
> ```
> /plugin marketplace add noelserdna/sdd-pipeline
> /plugin install sdd-pipeline@noelserdna
> ```
>
> Migrating from `sdd@noelserdna-claude-plugin-sdd` or from hooks copied by `install-sdd-automation.sh`:
> see [docs/migracion.md](https://github.com/noelserdna/sdd-pipeline/blob/main/docs/migracion.md).

---

> ## ⚠️ ARCHIVADO (2026-08) — el desarrollo continúa en [noelserdna/sdd-pipeline](https://github.com/noelserdna/sdd-pipeline)
>
> Este repositorio queda en solo lectura en **v3.1.0**. La versión 4.0.0+ del pipeline SDD (23 skills, 5 agentes, hooks,
> servidor MCP e implementación multi-sesión) vive en un único plugin distribuible:
>
> ```
> /plugin marketplace add noelserdna/sdd-pipeline
> /plugin install sdd-pipeline@noelserdna
> ```
>
> Migración desde `sdd@noelserdna-claude-plugin-sdd` o desde hooks copiados por `install-sdd-automation.sh`:
> [docs/migracion.md](https://github.com/noelserdna/sdd-pipeline/blob/main/docs/migracion.md).

## Pasos (F4)

1. En `claude-plugin-sdd`: añadir el aviso, publicar **3.1.1** cuyo `scripts/sdd-session-start.sh` inyecta en `additionalContext`
   la línea `SDD: this plugin is archived — migrate to sdd-pipeline@noelserdna (see docs/migracion.md)` (única vía visible
   dentro de Claude Code para usuarios con auto-update), y después `gh repo archive noelserdna/claude-plugin-sdd -y`.
2. En `sdd-skills`: añadir el aviso y `gh repo archive noelserdna/sdd-skills -y`.
3. En GitLab `recursos/sdd-plugin`: añadir el aviso y archivar desde la interfaz.
