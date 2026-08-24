# Inventario de la fusión (F0) — 2026-08-24

Origen de cada pieza del repositorio unificado `noelserdna/sdd-pipeline` y destino de lo que no se fusiona.

| Repo origen | Commit / tag de referencia |
|---|---|
| `github.com/noelserdna/sdd-skills` (upstream; base del clon) | `294c81c` · tag `v3.1.0-rescue` |
| `github.com/noelserdna/claude-plugin-sdd` (empaquetado 3.0.1/3.1.0) | `8c08168` · tag `v3.1.0` |
| GitLab codecrypto `sdd-plugin` (fork reducido, 17 skills) | `0dfddb3` · tag `v3.1.0-final` (local) |

## Fusionado

| Pieza | Origen | Decisión |
|---|---|---|
| 23 skills (`skills/sdd-*`) | sdd-skills (worktree rescatado) | Base; incluye plan-architect UI, gap-detector Phase 5, task-implementer, test-planner, req-change, specifications-engineer sin publicar |
| `skills/sdd-dashboard/generate.py`, `references/html-template.md` | merge a 3 bandas | Base sdd-skills `cdd9cda` + agrupación por fases (sdd-pipeline) + body-fallback (sdd-skills) |
| `agents/sdd-orchestrator.md` | sdd-pipeline | Único origen |
| `agents/sdd-pipeline-auditor.md` | sdd-pipeline | Namespace `sdd-pipeline:`; la copia de sdd-skills usaba `sdd-lite:` |
| `agents/sdd-context-keeper.md`, `sdd-constitution-enforcer.md`, `sdd-cross-auditor.md` | sdd-skills `automation/agents` | context-keeper con `memory: project` |
| `hooks/*.sh`, `hooks/sdd-augment-hook.js` | sdd-skills `automation/hooks` (idénticos a claude-plugin-sdd) | Unificados en `hooks/` con `${CLAUDE_PLUGIN_ROOT}` |
| `hooks/hooks.json` | reescrito (base claude-plugin-sdd) | Wrapper `description`+`hooks`; sin duplicado `hooks/sdd-session-start.sh`; H5 sin `Grep\|Glob` |
| `.mcp.json` | reescrito (base claude-plugin-sdd) | Apunta al bundle `server/dist/server.js` |
| `server/src` | sdd-skills (== claude-plugin-sdd) | `version` inyectada en build; `/sdd:` → `/sdd-` |
| `server/package-lock.json` | claude-plugin-sdd | Regenerado por `npm install` (zod, esbuild, tsx) |
| `LICENSE`, `CHANGELOG.md` | claude-plugin-sdd | Superset (hasta 3.1.0) |
| `references/sdd-constitution.md`, `schema/` | sdd-skills | Sin cambios |
| `scripts/sdd-status-line.sh` | sdd-skills `automation/status-line` | Se copia al proyecto desde `sdd-setup` |
| `scripts/migrate-hooks-v2.sh` | sdd-skills `automation/scripts` | Base de `migrate-hooks-v3.sh` (F4) |
| `templates/settings-optional-quality-gates.json` | sdd-skills `automation` | Opt-in H7/H8 |
| `docs/guia-paso-a-paso.md`, `docs/guia-completa-extendida.md`, `docs/design/hooks-v2.md` | sdd-skills | Solo documentación |
| `README.md` / `README.es.md` | sdd-skills (reescritos en F4) | — |

## Descartado (queda en la historia git o en los repos archivados)

| Pieza | Motivo |
|---|---|
| `automation/INSTALL.md`, `automation/settings-template.json` | Modelo de copia de hooks al proyecto; el plugin los aporta con `${CLAUDE_PLUGIN_ROOT}` |
| `sdd-setup/scripts/install-sdd-automation.sh` | Rutas del autor; sustituido por `sdd-setup` reducido + `scripts/install-git-hooks.sh` (copia en `docs/legacy/`) |
| `server/dist/*.d.ts`, `*.map`, `server/node_modules` (49 MB en claude-plugin-sdd) | Bundle único reproducible |
| `claude-plugin-sdd/hooks/sdd-session-start.sh` | Duplicado muerto de `scripts/sdd-session-start.sh` |
| `ideas/`, `modulo 2/`, `.DS_Store`, `.orphaned_at`, `.claude/settings.local.json` | Locales / residuos |
| `version:` en el frontmatter de las skills | No detectaba drift; única fuente: `plugin.json` |
| Fallback a `~/.claude/plugins/cache/noelserdna-plugins/sdd/1.8.0` en `generate.py` | Marketplace obsoleto; `SCRIPT_DIR` ya cubre el cache del plugin |
