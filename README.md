# sdd-pipeline

> **[Leer en español](README.es.md)**

[![ci](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/noelserdna/sdd-pipeline/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Specification-Driven Development pipeline for [Claude Code](https://code.claude.com), based on SWEBOK v4 — packaged as a single installable plugin.**

From requirements to production code: a structured, auditable, traceable pipeline that turns natural-language requirements into implemented software, with hooks that guard the process and an MCP server that answers questions about the traceability graph.

- **21 skills** — the 7-stage pipeline, per-requirement acceptance, lateral skills, brownfield adoption, utilities, the interactive orchestrator and the multi-session lead
- **One CLI, `scripts/sdd.mjs`** — task lint, git traceability (`sdd trace`), commit verification, work branches, need coverage, plan lint, the acceptance ledger (`sdd accept`) and the release gate (`sdd gate`); Node ≥ 18, no dependencies, runs in CI with only Node and git
- **5 hooks** (7 event registrations) — pipeline status at session start, upstream immutability guard, a guard against fabricated consent and accidental self-approval, traceability context and pipeline-state updates
- **MCP server** — 6 tools, 7 resources and 2 prompts; coverage reports the acceptance verdict of each requirement
- **Multi-session implementation** — role-scoped sessions (`SDD_ROLE`), parallel streams in git worktrees, lead handoffs

## Install

```
/plugin marketplace add noelserdna/sdd-pipeline
/plugin install sdd-pipeline@noelserdna
```

Use `--scope project` (or `claude plugin install sdd-pipeline@noelserdna --scope project`) to share the plugin with a team through `.claude/settings.json`.

**Requirements:** Claude Code ≥ 2.1.224 · Node.js ≥ 18 · git ≥ 2.32 · bash · `jq` (recommended; hooks fall back to `node`) · `python3` (optional: traceability graph for the MCP server). macOS and Linux; Windows through WSL.

On first use Claude Code asks you to approve the `sdd` MCP server. After a plugin update run `/reload-plugins` or start a new session.

Migrating from `sdd@noelserdna-claude-plugin-sdd`, `sdd-pipeline@sdd-pipeline-local` or hooks copied into `.claude/hooks/`? See [docs/migracion.md](docs/migracion.md).

## Quick start

```
/sdd-setup                       # pipeline-state.json, git commit-msg hook + vendored validator, .gitignore policy
/sdd-setup --stack=rails --app-dir=web   # optional stack kit: SDD Stack Profile, conventions, path rules (docs/stacks.md)
/sdd-requirements-engineer       # customer needs (verbatim) → requirements with examples and a verification method
/sdd-specifications-engineer     # spec/ (domain, use cases, workflows, contracts, ADRs, BDD scenarios AC-NNN-NN)
/sdd-spec-auditor                # audits/AUDIT-BASELINE.md — gate PASS / CONDITIONAL / BLOCKED
/sdd-test-planner                # test/
/sdd-plan-architect              # plan/ — walking skeleton, then one demoable increment per FASE
/sdd-task-generator              # task/ (atomic tasks, dependency graph, streams)
/sdd-task-implementer --fase 0   # work branch, test-first, one commit per task with Task/Refs trailers, FASE demo
/sdd-acceptance --fase 0         # verdict per requirement with its evidence; --sign-off records the customer's acceptance
/sdd-pipeline-status             # where am I, what is stale, what is next
```

Or let the `sdd-orchestrator` skill drive the whole pipeline interactively: *"run the SDD pipeline for this project"*.

## The pipeline

```
sdd-requirements-engineer   →  requirements/CUSTOMER-NEEDS.md, REQUIREMENTS.md (tag requirements-v{N} on approval)
sdd-specifications-engineer →  spec/ (domain, use-cases, workflows, contracts, nfr, adr, tests)
sdd-spec-auditor            →  audits/AUDIT-BASELINE.md + corrected spec/
   ↳ lateral (optional): sdd-security-auditor, sdd-tech-designer, sdd-ux-designer
sdd-test-planner            →  test/TEST-PLAN.md, TEST-MATRIX-*.md, E2E-SCENARIOS.md
sdd-plan-architect          →  plan/ (ARCHITECTURE.md, PLAN.md with Plan-Style: vertical, fases/)
sdd-task-generator          →  task/TASK-FASE-*.md, TASK-ORDER.md (TASK-INDEX.md optional)
sdd-task-implementer        →  code and tests (Stack Profile paths), git commits, FASE demo
sdd-acceptance              →  acceptance/ACCEPTANCE-REPORT.md, decisions.jsonl, tag fase-{N}-accepted
```

Every artifact traces end to end: `N → REQ → UC → WF → API → BDD/AC → INV → ADR → TASK → COMMIT → CODE → TEST → verdict`.

**FASEs are vertical.** FASE-0 is a walking skeleton — the smallest write → observe → persist path of the central use case (in the todo example: `todo add`, `todo list` and the JSON file) plus only the infrastructure that path needs. Each later FASE is one user journey with a `## Demo` of at most 10 steps. At the end of a FASE the customer watches the demo and accepts it, accepts it with observations, or rejects it with feedback that is routed as a defect, a change request or a question.

**The route adapts to the project.** Right after the requirements are approved, `sdd route` proposes which optional stages this project needs, from counted facts and seven narrow judgments about the needs (external customer, sensitive data, several roles, integrations, UI flows, long life, complex state). A small CLI skips formal specs, the spec audit and the test plan, and is planned straight from the requirements' acceptance criteria. A person confirms the route in one question, skipped stages are recorded with their reason, and `sdd-req-change` re-evaluates the route after every change, raising the rigor when needed, never lowering it — see [docs/ruta.md](docs/ruta.md).

State lives in `pipeline-state.json` (one file, the single source of truth); changes flow forward through `sdd-req-change`, which marks downstream stages `stale` and reopens the acceptance of a modified requirement.

## Skills

### Pipeline (7)

| # | Skill | Input | Output |
|---|-------|-------|--------|
| 1 | `sdd-requirements-engineer` | the customer | `requirements/` (needs, requirements, approval tag) |
| 2 | `sdd-specifications-engineer` | `requirements/` | `spec/` |
| 3 | `sdd-spec-auditor` | `spec/` | `audits/`, corrected `spec/` |
| 4 | `sdd-test-planner` | `spec/`, `ux/` | `test/` |
| 5 | `sdd-plan-architect` | `spec/`, `design/`, `ux/`, `audits/` | `plan/` (vertical FASEs) |
| 6 | `sdd-task-generator` | `plan/` | `task/` |
| 7 | `sdd-task-implementer` | `task/`, `spec/`, `plan/` | code, tests, commits |

### Lateral (4)

| Skill | Purpose | Output |
|-------|---------|--------|
| `sdd-security-auditor` | OWASP ASVS v4 / CWE security posture audit of the specs | `audits/SECURITY-AUDIT-BASELINE.md` |
| `sdd-req-change` | ADD / MODIFY / DEPRECATE requirements with pipeline cascade (ISO 14764), on a `change/` branch | updated `requirements/`, `spec/`, `changes/` |
| `sdd-tech-designer` | Architecture and stack decisions across 12 dimensions (ATAM-lite) | `design/` |
| `sdd-ux-designer` | Design system, wireframes, accessibility, interaction model | `ux/` |

### Brownfield (3)

| Skill | Purpose |
|-------|---------|
| `sdd-reverse-engineer` | Code → SDD artifacts (requirements, specs, retroactive FASEs by functional area, tasks, findings) |
| `sdd-reconcile` | Detect and resolve spec ↔ code drift |
| `sdd-import` | Jira, OpenAPI, Markdown, Notion, CSV, Excel → SDD format |

### Utilities (7)

| Skill | Purpose |
|-------|---------|
| `sdd-acceptance` | Verdict per requirement (VERIFIED / FAILING / MISSING / WAIVED) with its evidence, ID-chain integrity, a goal loop until every Must is met, the customer's sign-off and updates of the project's status page — see [docs/aceptacion.md](docs/aceptacion.md) |
| `sdd-setup` | Initialise a project: state file, git hook and vendored validator, `.gitignore` policy, stack kits, multi-session roles; cleans up 4.x status lines |
| `sdd-pipeline-status` | Stage report, staleness, acceptance summary, next action; `--diagnose` classifies an existing project (8 adoption scenarios) and lists the skills to run |
| `sdd-gap-detector` | Missing endpoints, orphan code, schema mismatches — with a human review document; `--semantic` checks whether the code implements each requirement (Jev judge when enabled, LLM otherwise) |
| `sdd-session-summary` | Summarise the session and update project memory |
| `sdd-orchestrator` | Runs the whole pipeline interactively from the main conversation, asking for the gate decisions (requirements approval, FASE acceptance) |
| `sdd-lead` | Multi-session lead: dispatches stages to role sessions after each human gate, receives handoffs, answers station questions |

## Git and acceptance

Git history is the evidence that a task was done and a requirement delivered ([docs/git.md](docs/git.md), [`references/git-conventions.md`](references/git-conventions.md)):

- Commits carry `Task`, `Refs` and `Change` trailers written with `git commit --trailer`; the commit-msg hook and CI run the same validator (`sdd verify`).
- Work starts on a branch (`sdd branch start fase 2 lifecycle`); merges are merge commits, never squash, so the per-task trailers survive.
- `sdd trace req REQ-F-004`, `sdd trace why src/tasks.ts:42` and `sdd trace delivered REQ-F-004` answer "which commits", "why is this line here" and "which tags ship it".
- With `tracker: github|gitlab` in the Stack Profile, `sdd issue open|update|close` keeps one issue per FASE and per change (the FASE issue closes at acceptance) and `sdd pr-body` builds the PR description; `/sdd-setup --tracker` adds CI templates that run `sdd verify --range`, `sdd lint` and `sdd gate --mode warn`. Every push, issue, PR or merge asks first.

Acceptance answers "is each requirement satisfied, and with what evidence?" ([docs/aceptacion.md](docs/aceptacion.md)):

```bash
node scripts/sdd.mjs accept --report acceptance/ACCEPTANCE-REPORT.md   # ledger from JUnit + decisions.jsonl
node scripts/sdd.mjs gate --mode enforce    # 0 goal met · 1 not met · 2 stale evidence · 3 met with waived Musts
```

Tests are named with their scenario id (`AC-001-03`) so results bind to acceptance criteria; `demo`, `measurement` and `inspection` evidence is recorded by a named person. Human records and acceptance tags ask for confirmation first (tool guard) and cannot be hand-edited (upstream guard) — this prevents accidental self-approval, it is not a guarantee.

## Optional: Jev bulk judgments

With `TYPESAFE_API_KEY` set, `scripts/sdd-jev.mjs` lets skills screen many small items in one pass with TypeSafe's Jev (calibrated yes/no, choice and score answers in ~100 ms): requirement quality and customer-need coverage in `sdd-requirements-engineer`, detection-pattern triage in `sdd-spec-auditor`, requirement coverage in `sdd-gap-detector --semantic`, feedback routing at the FASE gate, and advisory test-adequacy and demo-evidence checks in `sdd-acceptance`. The LLM reads only what Jev flags or is unsure about, and Jev never decides a verdict, waiver or sign-off. Without the key (or with `SDD_JEV=off`) every skill works as before. Spec and code text is sent to TypeSafe, so enable it only where that is allowed — see [docs/jev.md](docs/jev.md).

The maintainer agents that audit this repository (`sdd-pipeline-auditor`, `sdd-cross-auditor`) live in `.claude/agents/` and are not shipped with the plugin.

## Hooks

Declared in [`hooks/hooks.json`](hooks/hooks.json) and run from the plugin directory — nothing is copied into your project.

| Hook | Event | What it does |
|------|-------|--------------|
| `sdd-session-start.sh` | SessionStart | Injects pipeline status (`N/7 done`, stale stages, next step, session role and live peers) and the last acceptance summary |
| `sdd-upstream-guard.sh` | PreToolUse Edit/Write | Denies writes to upstream artifacts while a downstream stage runs (constitution art. 4); enforces role ownership; denies hand edits of `acceptance/decisions.jsonl` and the acceptance report |
| `sdd-tool-guard.sh` | PreToolUse Bash | Denies commands that assign human-consent variables for AI actions (e.g. `PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION`); asks before `sdd accept record` and `fase-N-accepted` / `requirements-vN` tags |
| `sdd-augment-hook.js` | PreToolUse Read/Edit/Write | Adds traceability context for the file being touched |
| `sdd-pipeline-state-updater.sh` | PreToolUse Skill, UserPromptExpansion, PostToolUse Write | Marks a stage `running` when its skill starts or a file under its directory is written (locked, worktree-aware) |

`sdd-setup` additionally installs a git `commit-msg` hook that runs `sdd verify` from the validator vendored into `.claude/sdd/` (commit it; CI uses the same copy): `feat`, `test` and `refactor` need a `Task` trailer, `fix` and `perf` a `Task` or `Change` (bypass: `[skip-sdd]` or `SDD_SKIP_VERIFY=1`). Opt-in quality gates (`Stop`, `TaskCompleted`) live in `templates/settings-optional-quality-gates.json`.

## MCP server

`server/dist/server.js` is a single bundled file (no `node_modules` needed) registered as `sdd`:

| Tool | Purpose |
|------|---------|
| `sdd_query` | Search artifacts by text, id, type or domain |
| `sdd_impact` | Blast radius by depth (WILL_BREAK / LIKELY_AFFECTED / MAY_NEED_REVIEW) |
| `sdd_context` | 360° view of one artifact; for a requirement, its acceptance verdict with per-criterion evidence |
| `sdd_coverage` | Verdict per requirement from `.sdd/acceptance.json`; without it, link gaps by domain or layer |
| `sdd_trace` | Full chain traversal with break detection |
| `sdd_gaps` | Findings from `sdd-gap-detector` |

Plus `sdd://pipeline/*`, `sdd://graph/*`, `sdd://coverage/gaps`, `sdd://artifacts/{type}[/{id}]` resources and the `analyze_impact` / `generate_status_report` prompts. The graph (`dashboard/traceability-graph.json`) is built by `python3 scripts/sdd-graph.py`; the server looks for it from the working directory upwards and degrades gracefully when there is none.

## Multi-session implementation

Long-lived, named Claude Code sessions can own different parts of the pipeline and message each other (Claude Code ≥ 2.1.224):

```
/sdd-setup --multisession        # writes .claude/sdd-sessions.json (roles → session name, colour, owned paths, stages)
.claude/sdd/sdd-up.sh sdd-lead   # launches a tmux session `claude -n <project>-lead` with SDD_ROLE=sdd-lead
.claude/sdd/sdd-up.sh impl-f1a   # a worktree + session for FASE 1 / Stream A
```

- **`SDD_ROLE`** identifies the session; the session-start hook shows the role and its live peers, and the upstream guard denies writes outside the role's owned paths.
- **Streams** are the exception in a vertical plan: only when a FASE splits into disjoint write-sets. `sdd-task-implementer --stream=A` works in its own worktree and `--integrate --fase N` merges the streams back in the main checkout (`git merge --no-ff`, verification, `fase-N-verified` tag).
- **Handoffs**: when a station finishes a stage it sends `stage=<x> status=done gate=<…>` to the lead session (never "run X"; the human still takes every gate decision in `sdd-lead`). Questions that would block a station are written to `.sdd/questions-<role>.md` and answered from the lead.
- Everything degrades to single-session behaviour when `SDD_ROLE` is not set.

See [docs/multisesion.md](docs/multisesion.md) for the full protocol and [docs/multisesion/](docs/multisesion/) for the design review behind it.

## Repository layout

```
.claude-plugin/   plugin.json, marketplace.json      hooks/       hooks.json + scripts (+ lib/sdd-common.sh)
skills/           21 skills                          scripts/     sdd.mjs CLI (+ lib/), sdd-state.sh, sdd-jev.mjs, sdd-graph.py, validators
.claude/agents/   maintainer auditors (not shipped)  server/      MCP server (src/, dist/server.js, tests)
references/       constitution, git conventions,     templates/   pipeline-state, gitignore, sessions, quality gates, stack kits
                  handoff protocol, async questions
examples/todo-app toy project for E2E tests          tests/       hooks, setup, tasks, graph, jev, bench, git, plan, acceptance, tracker, e2e   docs/  guides, git, acceptance, design
```

## Development

```bash
node scripts/validate-plugin.mjs        # manifests, skills, hooks, mcp, stack kits, commit examples
bash tests/hooks/run.sh                 # hook behaviour (roles, worktrees, locking, guards)
bash tests/tasks/run.sh                 # task-line grammar (V-19) and trailer-based task status
bash tests/git/run.sh                   # sdd trace / verify / branch against temporary repos
bash tests/plan/run.sh                  # sdd lint --plan on the vertical and Streams fixtures
bash tests/acceptance/run.sh            # sdd accept / gate / loop: verdicts, freshness, waivers, JUnit reader
bash tests/graph/run.sh                 # sdd-graph.py (commit parity with sdd trace, Stack Profile scans) and test-result parsers
bash tests/jev/run.sh                   # sdd-jev.mjs against a local API mock (no key, no network)
bash tests/e2e/run-all.sh               # B1 static validation + B2 real install in an isolated CLAUDE_CONFIG_DIR
cd server && npm ci && npm run check && npm run build && npm test
node scripts/sdd.mjs --help             # the CLI (scripts/sdd-task-lint.mjs is an alias)
claude --plugin-dir . -p "/sdd-pipeline-status"   # try the plugin without installing it
scripts/release.sh 5.0.0                # bump plugin.json/marketplace/server, CHANGELOG, tag sdd-pipeline--v5.0.0
```

CI runs lint (shellcheck), validation, the script test suites (`tests/{hooks,setup,bench,tasks,graph,jev,git,acceptance,plan}`) and the server build/test matrix (ubuntu + macos, node 18/22), and checks that `server/dist/server.js` is reproducible.

## Documentation

- [docs/instalacion.md](docs/instalacion.md) — installation and first steps (Spanish)
- [docs/guia-paso-a-paso.md](docs/guia-paso-a-paso.md) — step-by-step guide (Spanish)
- [docs/guia-completa-extendida.md](docs/guia-completa-extendida.md) — extended guide (Spanish)
- [docs/git.md](docs/git.md) — commits, trailers, branches, merges, tags and `sdd trace`
- [docs/aceptacion.md](docs/aceptacion.md) — acceptance per requirement, the gate, the goal loop and sign-off
- [docs/ruta.md](docs/ruta.md) — adaptive route: which stages each project needs, confirmation and re-evaluation (Spanish)
- [docs/stacks.md](docs/stacks.md) — SDD Stack Profile and stack kits (Rails, Next.js + Prisma)
- [docs/migracion.md](docs/migracion.md) — migrating from previous plugins, copied hooks and 4.x
- [docs/multisesion.md](docs/multisesion.md) — multi-session protocol
- [docs/jev.md](docs/jev.md) — optional Jev integration, measurements and limits
- [docs/coste-contexto.md](docs/coste-contexto.md) — context cost per release
- [docs/perfilado.md](docs/perfilado.md) — where the time goes in a stage and how to cut it (`scripts/sdd-profile.sh`)
- [references/sdd-constitution.md](references/sdd-constitution.md) — the 12 articles every skill follows
- [CHANGELOG.md](CHANGELOG.md)

## History

This repository unifies [sdd-skills](https://github.com/noelserdna/sdd-skills) (upstream), [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd) (the previous distributable plugin) and a reduced internal fork. Both public repositories are archived at v3.1.0; see [docs/legacy/INVENTARIO.md](docs/legacy/INVENTARIO.md) for where every piece came from.

## License

[MIT](LICENSE) — Andres Leon
