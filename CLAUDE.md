# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A **Claude Code plugin** (`sdd-pipeline`, version in `.claude-plugin/plugin.json`) that implements a Specification-Driven Development pipeline based on SWEBOK v4:

- 23 skills: 7 pipeline, 4 lateral, 3 brownfield, 9 utility (including the interactive orchestrator and the multi-session lead)
- 8 hook scripts (14 event registrations)
- an MCP server for live traceability queries
- an optional TypeSafe Jev integration for bulk judgments

Most of the product is prompt text (skills and their references). The executable parts are:

- the hooks (bash + one Node script)
- `scripts/` (bash/Node helpers and validators)
- `skills/sdd-dashboard/generate.py`
- the TypeScript MCP server in `server/`, bundled with esbuild into the committed `server/dist/server.js`

## Pipeline

```
sdd-requirements-engineer    →  requirements/REQUIREMENTS.md
sdd-specifications-engineer  →  spec/ (domain, use-cases, workflows, contracts, tests, nfr, adr)
sdd-spec-auditor             →  audits/AUDIT-BASELINE.md  (--fix applies accepted corrections to spec/)
sdd-test-planner             →  test/ (TEST-PLAN, TEST-MATRIX-*, PERF-SCENARIOS, E2E-SCENARIOS)
sdd-plan-architect           →  plan/ (PLAN.md, ARCHITECTURE.md, fases/FASE-{N}-{SLUG}.md, fase-plans/PLAN-FASE-{N}.md)
sdd-task-generator           →  task/TASK-FASE-{N}.md
sdd-task-implementer         →  code/test paths from the SDD Stack Profile (default src/, tests/), one commit per task
```

**Lateral** (any time):
- `sdd-tech-designer` → `design/`, including `OPERATION-MAPPING.md`, which plan-architect writes itself when tech-designer was not run.
- `sdd-ux-designer` → `ux/`, read by plan-architect and test-planner.
- `sdd-security-auditor` → `audits/SECURITY-AUDIT-BASELINE.md`. Its fixes go through req-change.
- `sdd-req-change` → ADD/MODIFY/DEPRECATE with ISO 14764 classification and an optional cascade (`--cascade=auto|manual|dry-run|plan-only`). It writes `changes/CHANGE-REPORT-{CHG-ID}.md`.

**Brownfield:**
- `sdd-reverse-engineer`: code → artifacts; seeds from `[IMPORTED]` items.
- `sdd-reconcile`: drift. It amends specs only, writes CR entries, and reads `.sdd/gap-analysis.json`.
- `sdd-import`: Jira, OpenAPI (→ `Style: http`), Markdown, Notion, CSV, Excel.

**Utility:**
- `sdd-setup`: state file, git hook, status line, stack kits `--stack=<rails|nextjs-prisma>`, multi-session.
- `sdd-pipeline-status`: `--diagnose` classifies an existing project into 8 adoption scenarios.
- `sdd-traceability-check`
- `sdd-gap-detector`: `--semantic` checks requirement coverage in the code.
- `sdd-dashboard`: `generate.py` builds `dashboard/traceability-graph.json` and the HTML.
- `sdd-code-index`: GitNexus bridge.
- `sdd-session-summary`
- `sdd-orchestrator`: drives the whole pipeline from the main conversation.
- `sdd-lead`: multi-session, see `docs/multisesion.md`.

## Repository Layout

```
.claude-plugin/        plugin.json, marketplace.json
skills/sdd-*/          SKILL.md + references/ (loaded on demand at the step that names them)
hooks/                 hooks.json, lib/sdd-common.sh, sdd-*.sh, sdd-augment-hook.js, sdd-commit-msg-hook.sh (git hook)
scripts/               sdd-state.sh (locked stage status), sdd-jev.mjs + jev/*.json, sdd-task-lint.mjs,
                       install-*.sh, status lines, sdd-watch/up/bench/profile, validate-plugin.mjs, check-*.sh, release.sh
server/                src/{index,server,graph-loader,resources,prompts,hints}.ts, src/tools/{query,impact,context,coverage,trace,gaps}.ts
templates/             pipeline-state template, gitignore policy, optional quality gates, stacks/<kit>/
references/            sdd-constitution.md (12 articles), handoff-protocol.md, async-questions.md
commands/              /sdd-watch
.claude/agents/        maintainer agents for THIS repo (sdd-pipeline-auditor, sdd-cross-auditor), not shipped
examples/todo-app/     toy project used by the pipeline auditor
tests/                 hooks, setup, tasks, dashboard, jev, bench, e2e
docs/                  guides (Spanish), stacks, multisession, jev, measurements
```

## Development Loop

The same commands CI runs:

```bash
node scripts/validate-plugin.mjs && bash scripts/check-paths.sh && bash scripts/check-version.sh
bash tests/hooks/run.sh && bash tests/setup/run.sh && bash tests/tasks/run.sh
bash tests/dashboard/run.sh && bash tests/jev/run.sh && bash tests/bench/run.sh
shellcheck -S warning hooks/*.sh scripts/*.sh tests/hooks/*.sh
cd server && npm run check && npm run build && npm test   # commit dist/server.js with src changes
```

Hooks run in this checkout too (the plugin is enabled here). The session start hook may export `SDD_STATE_ROOT`, so run fixture tests with `env -u SDD_STATE_ROOT`, and check that `git status` shows no `pipeline-state.json` or `.sdd/` before committing.

## Key Conventions

- **EARS** statements for REQ-F/REQ-NF: `WHEN <trigger> THE <system> SHALL <behavior>`. Constraints (REQ-C) are plain statements.
- **IDs:** REQ-F/NF/C-NNN · UC-NNN · WF-NNN · operations API-NNN-NN (module number from the id ledger) · BDD-UC-NNN · INV-{AREA}-NNN · ADR-NNN · RN (business rules) · TASK-F{N}-NNN · UX screens SCR-NNN.
- **Traceability chain:** REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST.
- **Commits:**
  - Implementation: 1 task = 1 commit, Conventional Commits with `Refs:` and `Task:` trailers.
  - Spec edits by skills: `docs(specs): …` with `Refs:`.
  - The git `commit-msg` hook enforces this. It exempts docs/chore/ci/style/build, Merge, Revert, fixup!, squash! and amend!.
- **Code references in the graph (v6):** `codeRefs[].origin` ∈ direct, commit-inferred, task-inferred (confidence 0.5), blame-inferred, propagated, hook-captured, code-index, llm-verified, manual-override. `.sdd/overrides.json` pins or suppresses refs.
- **Clarification-first:** skills ask with `AskUserQuestion` (at most 4 questions per call). In station or `claude -p` mode they follow `references/async-questions.md`.
- **Baseline auditing:** the first audit creates the baseline; later audits report new findings and regressions. Excluded: Accepted, Won't fix, unexpired Deferred.
- **Revert strategies** per task: SAFE, COUPLED, MIGRATION, CONFIG. With `task_format: compact`, a task without a Revert block is SAFE.
- **Specs are the source of truth** (Article 12, below).

## Article 12: Specification Primacy

This is the foundational principle, and the last article of `references/sdd-constitution.md`.

1. **Tests verify specifications, never the code.** When a test fails, the defect is in the code. Never adapt a test to match code that deviates from the spec.
2. **Specs may be wrong, but only humans decide.** An implementer (human or LLM) who finds a spec impractical or contradictory implements it **as written** and records a `SPEC-DEVIATION` entry in `feedback/IMPL-FEEDBACK-FASE-{N}.md` (spec ID and text, where it was observed, the proposed change and its impact, a recommendation of AMEND, KEEP or NEEDS-DISCUSSION). It must not silently change the spec, the test or the behaviour.
3. **The cascade is: human decision → `sdd-req-change` → spec → tests → code.** Never the reverse.

## Pipeline State

`pipeline-state.json` lives at the project root (the main checkout when worktrees are used). The authoritative schema is `skills/sdd-req-change/references/cascade-patterns.md` §9, and the template is `templates/pipeline-state.template.json`.

- Top-level fields: `sddVersion`, `hooksVersion` (3), `currentStage`, `lastUpdated`, `stages`.
- Each stage has `status` (pending | running | done | stale | error), `lastRun`, `outputHash`, `staleReason` and, on completion, `summary` (artifacts, metrics, highlights, nextStep, generatedAt).
- Lateral skills add their own keys.
- Only `sdd-setup` creates the file; hooks never create it.
- Hooks only move pending/stale → running on writes.
- Skills set done/stale/error, preferably with `bash "$SDD_PLUGIN_ROOT/scripts/sdd-state.sh" set <stage> <status>`, which takes the same lock as the hooks.
- Staleness cascades downstream. A change in `requirements/` means re-running from specifications-engineer, `spec/` from spec-auditor, `plan/` from task-generator, `task/` from task-implementer.
- Gates on the spec audit read `stages["spec-auditor"].summary.metrics.gate_result` ∈ {PASS, CONDITIONAL}.

## Automation

Hooks are declared in `hooks/hooks.json` and run from `${CLAUDE_PLUGIN_ROOT}`. Nothing is copied into projects. They fail open, and all except the guards are silent in projects without SDD state.

| Hook | Event (matcher) | Purpose |
|------|-----------------|---------|
| `sdd-session-start.sh` | SessionStart (startup/resume/compact) | Injects `N/7 done`, stale stages, next step and session role |
| `sdd-upstream-guard.sh` | PreToolUse (Edit/Write) | Art. 4: denies downstream stages editing upstream artifacts (most downstream running stage wins; a running req-change may edit requirements/ and spec/) |
| `sdd-tool-guard.sh` | PreToolUse (Bash) | Denies assigning human-consent variables for AI-gated tools |
| `sdd-augment-hook.js` | PreToolUse (Read/Edit/Write) | Adds up to 2 traceability lines for the file from the graph |
| `sdd-activity-log.sh` | Session/Skill/Agent/Subagent/Stop events (async) | `.sdd/activity.jsonl` and the global run index `~/.claude/sdd/active-runs.json` |
| `sdd-runs-line.sh` | UserPromptSubmit | One line per live run |
| `sdd-pipeline-state-updater.sh` | PostToolUse (Write, async) | pending/stale → running for the stage owning the written path |
| `sdd-trace-map-updater.sh` | PostToolUse (Write/Edit, async) | Traceability map of written code files |

Also:
- The git `commit-msg` hook, installed by `sdd-setup`.
- Optional quality gates in `templates/settings-optional-quality-gates.json`.
- Three status lines: project, global and subagent (`scripts/`).
- Environment variables: `SDD_ROLE`, `SDD_STATE_ROOT` (honoured only when it belongs to the target repo), `SDD_PLUGIN_ROOT`.
- Skill-level hook: the `sdd-spec-auditor` Stop prompt, which applies after Mode Fix only.

## Jev (optional)

`scripts/sdd-jev.mjs` sends small typed questions to TypeSafe's Jev when `TYPESAFE_API_KEY` is set (`SDD_JEV=off` disables it). Without the key it exits 3 and skills do the work with the LLM. Its uses are:
- `req-lint` in requirements-engineer
- pattern-hit triage in spec-auditor
- the coverage judge in `gap-detector --semantic`

Question sets live in `scripts/jev/*.json`. Jev returns probabilities; skills own the thresholds and escalate the uncertain middle to the LLM. Never use it for permission decisions (guards, commit-msg). See `docs/jev.md`.

## Modifying Skills

- Keep the YAML front matter. The `description` (≤ 400 chars, validated) carries the trigger phrases that route requests.
- Write for a frontier model:
  - State each rule once, calmly, with its reason.
  - Put single-step templates and catalogs in `references/`, with a pointer at the step that needs them.
  - Leave out generic advice, textbook theory and leftovers from past projects.
- Cross-skill contracts (paths, IDs, state keys, metric keys in cascade-patterns §9, formats enforced by `sdd-task-lint.mjs` and the commit-msg hook) must stay consistent. Run `.claude/agents/sdd-cross-auditor.md` after contract changes.

## Standards Referenced

SWEBOK v4 · OWASP ASVS 4.0.3 · CWE · IEEE 830 · ISO 14764 · C4 Model · Gherkin/BDD · WCAG 2.2 AA.

## Known Gaps

- SWEBOK Ch05 production operations (monitoring, incident response, runtime rollback), Ch07 engineering management and Ch10 economics are out of scope.
- Skills rely on bash (grep, git) as provided by Claude Code; porting to non-CLI hosts needs that abstracted.

## Language

Skills are written in English with some Spanish contextual text. Output follows the user's language, and technical terms stay in English.
