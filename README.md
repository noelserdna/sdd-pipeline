# sdd-pipeline

> **[Leer en español](README.es.md)**

[![ci](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Specification-Driven Development pipeline for [Claude Code](https://code.claude.com), based on SWEBOK v4 — packaged as a single installable plugin.**

From requirements to production code: a structured, auditable, traceable pipeline that turns natural-language requirements into implemented software, with hooks that guard the process and an MCP server that answers questions about the traceability graph.

- **24 skills** — the 7-stage pipeline, lateral skills, brownfield onboarding, utilities and the multi-session lead
- **5 agents** — interactive orchestrator, end-to-end auditor, context keeper, constitution enforcer, cross-auditor
- **5 hooks** — pipeline status at session start, upstream immutability guard, state and trace-map updates, traceability context
- **MCP server** — 6 tools, 7 resources and 2 prompts over `dashboard/traceability-graph.json`
- **Multi-session implementation** — role-scoped sessions (`SDD_ROLE`), parallel streams in git worktrees, lead handoffs

## Install

```
/plugin marketplace add noelserdna/sdd-pipeline
/plugin install sdd-pipeline@noelserdna
```

Use `--scope project` (or `claude plugin install sdd-pipeline@noelserdna --scope project`) to share the plugin with a team through `.claude/settings.json`.

**Requirements:** Claude Code ≥ 2.1.224 · Node.js ≥ 18 · git · bash · `jq` (recommended; hooks fall back to `node`) · `python3` (dashboard only). macOS and Linux; Windows through WSL.

On first use Claude Code asks you to approve the `sdd` MCP server. After a plugin update run `/reload-plugins` or start a new session.

Migrating from `sdd@noelserdna-claude-plugin-sdd`, `sdd-pipeline@sdd-pipeline-local` or hooks copied into `.claude/hooks/`? See [docs/migracion.md](docs/migracion.md).

## Quick start

```
/sdd-setup                       # pipeline-state.json, git commit-msg hook, .gitignore policy, optional status line
/sdd-requirements-engineer       # elicit and write requirements/REQUIREMENTS.md
/sdd-specifications-engineer     # spec/ (domain, use cases, workflows, contracts, ADRs, BDD)
/sdd-spec-auditor                # audits/AUDIT-BASELINE.md — gate PASS / CONDITIONAL / BLOCKED
/sdd-test-planner                # test/
/sdd-plan-architect              # plan/ (architecture, FASEs)
/sdd-task-generator              # task/ (atomic tasks, dependency graph, streams)
/sdd-task-implementer --fase=0   # src/, tests/, commits with Refs:/Task: trailers
/sdd-pipeline-status             # where am I, what is stale, what is next
```

Or let the `sdd-orchestrator` agent drive the whole pipeline interactively: *"run the SDD pipeline for this project"*.

## The pipeline

```
sdd-requirements-engineer   →  requirements/REQUIREMENTS.md
sdd-specifications-engineer →  spec/ (domain, use-cases, workflows, contracts, nfr, adr, tests)
sdd-spec-auditor            →  audits/AUDIT-BASELINE.md + corrected spec/
   ↳ lateral (optional): sdd-security-auditor, sdd-tech-designer, sdd-ux-designer
sdd-test-planner            →  test/TEST-PLAN.md, TEST-MATRIX-*.md, E2E-SCENARIOS.md
sdd-plan-architect          →  plan/ (ARCHITECTURE.md, PLAN.md, fases/)
sdd-task-generator          →  task/TASK-FASE-*.md, TASK-INDEX.md, TASK-ORDER.md
sdd-task-implementer        →  src/, tests/, git commits
```

Every artifact traces end to end: `REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST`.

State lives in `pipeline-state.json` (one file, the single source of truth); changes flow forward through `sdd-req-change`, which marks downstream stages `stale`.

## Skills

### Pipeline (7)

| # | Skill | Input | Output |
|---|-------|-------|--------|
| 1 | `sdd-requirements-engineer` | user input | `requirements/` |
| 2 | `sdd-specifications-engineer` | `requirements/` | `spec/` |
| 3 | `sdd-spec-auditor` | `spec/` | `audits/`, corrected `spec/` |
| 4 | `sdd-test-planner` | `spec/`, `ux/` | `test/` |
| 5 | `sdd-plan-architect` | `spec/`, `design/`, `ux/`, `audits/` | `plan/` |
| 6 | `sdd-task-generator` | `plan/` | `task/` |
| 7 | `sdd-task-implementer` | `task/`, `spec/`, `plan/` | `src/`, `tests/`, commits |

### Lateral (4)

| Skill | Purpose | Output |
|-------|---------|--------|
| `sdd-security-auditor` | OWASP ASVS v4 / CWE security posture audit of the specs | `audits/SECURITY-AUDIT-BASELINE.md` |
| `sdd-req-change` | ADD / MODIFY / DEPRECATE requirements with pipeline cascade (ISO 14764) | updated `requirements/`, `spec/`, `changes/` |
| `sdd-tech-designer` | Architecture and stack decisions across 12 dimensions (ATAM-lite) | `design/` |
| `sdd-ux-designer` | Design system, wireframes, accessibility, interaction model | `ux/` |

### Brownfield (6)

| Skill | Purpose |
|-------|---------|
| `sdd-onboarding` | Diagnose an existing project (8 scenarios) and produce an adoption plan |
| `sdd-reverse-engineer` | Code → SDD artifacts (requirements, specs, tasks, findings) |
| `sdd-reconcile` | Detect and resolve spec ↔ code drift |
| `sdd-import` | Jira, OpenAPI, Markdown, Notion, CSV, Excel → SDD format |
| `sdd-code-index` | Symbol-level code references (optional [GitNexus](https://github.com/nicobailon/gitnexus) bridge) |
| `sdd-verify-coverage` | LLM-assisted requirement coverage verification with confidence scores |

### Utilities (7)

| Skill | Purpose |
|-------|---------|
| `sdd-setup` | Initialise a project: state file, git hook, `.gitignore` policy, status line, multi-session roles |
| `sdd-pipeline-status` | Stage report, staleness, next action |
| `sdd-traceability-check` | Full chain verification, orphans and broken links |
| `sdd-gap-detector` | Missing endpoints, orphan code, schema mismatches — with a human review document |
| `sdd-dashboard` | Interactive HTML traceability dashboard grouped by engineering phase |
| `sdd-session-summary` | Summarise the session and update project memory |
| `sdd-lead` | Multi-session lead: dispatches stages to role sessions after each human gate, receives handoffs, answers station questions |

## Agents

| Agent | Role |
|-------|------|
| `sdd-orchestrator` | Runs the whole pipeline interactively, asking for the 12 gate decisions |
| `sdd-pipeline-auditor` | Executes every skill on a test project end to end and writes `AUDIT-REPORT.md` / `AUDIT-HISTORY.md` |
| `sdd-context-keeper` | Keeps informal project context (preferences, deferred decisions) out of the formal artifacts |
| `sdd-constitution-enforcer` | Validates work against the 11 articles of the [SDD constitution](references/sdd-constitution.md) |
| `sdd-cross-auditor` | Cross-checks skill contracts (inputs/outputs) for mismatches |

## Hooks

Declared in [`hooks/hooks.json`](hooks/hooks.json) and run from the plugin directory — nothing is copied into your project.

| Hook | Event | What it does |
|------|-------|--------------|
| `sdd-session-start.sh` | SessionStart | Injects pipeline status (`N/7 done`, stale stages, next step, session role and live peers) |
| `sdd-upstream-guard.sh` | PreToolUse Edit/Write | Denies writes to upstream artifacts while a downstream stage runs (constitution art. 4); enforces role ownership |
| `sdd-augment-hook.js` | PreToolUse Read/Edit/Write | Adds traceability context for the file being touched |
| `sdd-pipeline-state-updater.sh` | PostToolUse Write | Marks the stage that owns the written path as `running` (locked, worktree-aware) |
| `sdd-trace-map-updater.sh` | PostToolUse Write/Edit | Accumulates file → task/refs mappings in `.sdd/trace-map.json` |

`sdd-setup` additionally installs a git `commit-msg` hook that requires `Refs:` / `Task:` trailers on `feat`, `fix`, `perf`, `test` and `refactor` commits (bypass: `[skip-sdd]` or `SDD_SKIP_VERIFY=1`), and can add an optional status line and opt-in quality gates (`Stop`, `TaskCompleted`).

## MCP server

`server/dist/server.js` is a single bundled file (no `node_modules` needed) registered as `sdd`:

| Tool | Purpose |
|------|---------|
| `sdd_query` | Search artifacts by text, id, type or domain |
| `sdd_impact` | Blast radius by depth (WILL_BREAK / LIKELY_AFFECTED / MAY_NEED_REVIEW) |
| `sdd_context` | 360° view of one artifact |
| `sdd_coverage` | Gaps by business domain or technical layer |
| `sdd_trace` | Full chain traversal with break detection |
| `sdd_gaps` | Findings from `sdd-gap-detector` |

Plus `sdd://pipeline/*`, `sdd://graph/*`, `sdd://coverage/gaps`, `sdd://artifacts/{type}[/{id}]` resources and the `analyze_impact` / `generate_status_report` prompts. The server looks for `dashboard/traceability-graph.json` from the working directory upwards and degrades gracefully when there is none — run `/sdd-dashboard` to generate it.

## Multi-session implementation

Long-lived, named Claude Code sessions can own different parts of the pipeline and message each other (Claude Code ≥ 2.1.224):

```
/sdd-setup --multisession        # writes .claude/sdd-sessions.json (roles → session name, colour, owned paths, stages)
.claude/sdd/sdd-up.sh sdd-lead   # launches a tmux session `claude -n <project>-lead` with SDD_ROLE=sdd-lead
.claude/sdd/sdd-up.sh impl-f1a   # a worktree + session for FASE 1 / Stream A
```

- **`SDD_ROLE`** identifies the session; the session-start hook shows the role and its live peers, and the upstream guard denies writes outside the role's owned paths.
- **Streams**: `sdd-task-generator` splits each FASE into streams with disjoint write-sets; `sdd-task-implementer --stream=A` works in its own worktree and `--integrate --fase N` merges the streams back in the main checkout (`git merge --no-ff`, verification, `fase-N-verified` tag).
- **Handoffs**: when a station finishes a stage it sends `stage=<x> status=done gate=<…>` to the lead session (never "run X"; the human still takes every gate decision in `sdd-lead`). Questions that would block a station are written to `.sdd/questions-<role>.md` and answered from the lead.
- Everything degrades to single-session behaviour when `SDD_ROLE` is not set.

See [docs/multisesion.md](docs/multisesion.md) for the full protocol and [docs/multisesion/](docs/multisesion/) for the design review behind it.

## Repository layout

```
.claude-plugin/   plugin.json, marketplace.json      hooks/       hooks.json + scripts (+ lib/sdd-common.sh)
skills/           24 skills                          scripts/     setup helpers, sdd-up.sh, release.sh, validators
agents/           5 agents                           server/      MCP server (src/, dist/server.js, tests)
references/       constitution, handoff protocol     templates/   pipeline-state, gitignore, sessions, quality gates
examples/todo-app toy project for E2E tests          tests/       hooks, setup, e2e          docs/  guides, migration, design
```

## Development

```bash
node scripts/validate-plugin.mjs        # manifests, skills, agents, hooks, mcp
bash tests/hooks/run.sh                 # hook behaviour (roles, worktrees, locking)
bash tests/e2e/run-all.sh               # B1 static validation + B2 real install in an isolated CLAUDE_CONFIG_DIR
cd server && npm ci && npm run check && npm run build && npm test
claude --plugin-dir . -p "/sdd-pipeline-status"   # try the plugin without installing it
scripts/release.sh 4.0.0                # bump plugin.json/marketplace/server, CHANGELOG, tag sdd-pipeline--v4.0.0
```

CI runs lint (shellcheck), validation, hook tests and the server build/test matrix (ubuntu + macos, node 18/22) and checks that `server/dist/server.js` is reproducible.

## Documentation

- [docs/instalacion.md](docs/instalacion.md) — installation and first steps (Spanish)
- [docs/migracion.md](docs/migracion.md) — migrating from the previous plugins and copied hooks
- [docs/multisesion.md](docs/multisesion.md) — multi-session protocol
- [docs/guia-paso-a-paso.md](docs/guia-paso-a-paso.md) — step-by-step guide (Spanish)
- [docs/coste-contexto.md](docs/coste-contexto.md) — context cost per release
- [references/sdd-constitution.md](references/sdd-constitution.md) — the 11 articles every skill follows
- [CHANGELOG.md](CHANGELOG.md)

## History

This repository unifies [sdd-skills](https://github.com/noelserdna/sdd-skills) (upstream), [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd) (the previous distributable plugin) and a reduced internal fork. Both public repositories are archived at v3.1.0; see [docs/legacy/INVENTARIO.md](docs/legacy/INVENTARIO.md) for where every piece came from.

## License

[MIT](LICENSE) — Andres Leon
