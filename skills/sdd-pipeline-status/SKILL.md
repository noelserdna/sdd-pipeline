---
name: sdd-pipeline-status
description: "Pipeline status, artifact checks, staleness and next action; --diagnose plans SDD adoption for new or existing projects. Triggers: 'pipeline status', 'what stage', 'next step', 'check staleness', 'que sigue', 'estado del pipeline', 'onboard project', 'adopt SDD', 'start SDD', 'diagnose project', 'project assessment', 'SDD readiness'."
allowed-tools: Read, Grep, Glob, Bash(node:*), Bash(git rev-parse:*), Bash(git log:*), Bash(git rev-list:*), Bash(git shortlog:*), Bash(git remote:*), Bash(git merge-base:*), Bash(ls:*)
---

# SDD Pipeline Status

Reports where the project stands and what to run next. Two modes:

- **Status** (default): pipeline progress from `pipeline-state.json`.
- **Diagnose** (`--diagnose`): adoption plan for a project that does not use SDD yet or only partly. Runs
  automatically when there is no `pipeline-state.json` and none of `requirements/`, `spec/`, `plan/`, `task/`, or
  when the user asks to onboard/adopt/diagnose.

Both modes are read-only: they report and recommend, and never run pipeline stages.

`STATE_ROOT` is where `pipeline-state.json` and `.sdd/` live: `$SDD_STATE_ROOT` if set, else the main checkout
(`dirname "$(git rev-parse --path-format=absolute --git-common-dir)"`, which is also correct from a worktree), else
the current directory.

## Status mode

1. **Read `$STATE_ROOT/pipeline-state.json`.** Missing → switch to Diagnose mode.
2. **Verify artifacts** of every `done` stage; a `done` stage without them is **INCONSISTENT**:

   | Stage | Expected artifacts |
   |-------|--------------------|
   | requirements-engineer | `requirements/REQUIREMENTS.md` |
   | specifications-engineer | `spec/` with `domain/`, `use-cases/UC-*.md`, `contracts/`, `nfr/`, and `workflows/WF-*.md` when the requirements define user journeys |
   | spec-auditor | `audits/AUDIT-BASELINE.md` |
   | test-planner | `test/TEST-PLAN.md`, `test/TEST-MATRIX-*.md` |
   | plan-architect | `plan/PLAN.md`, `plan/ARCHITECTURE.md`, `plan/fases/FASE-*.md` |
   | task-generator | `task/TASK-FASE-*.md`, `task/TASK-ORDER.md` (`task/TASK-INDEX.md` optional: absent with `task_format: compact`) |
   | task-implementer | files under the SDD Stack Profile `code_paths`/`test_paths` (default `src/`, `tests/`) |

3. **Staleness.** Report stages with `status: "stale"` and their `staleReason` (the hooks and `sdd-req-change`
   set them). Also flag a `done` stage as *potentially stale* when an input directory changed after its `lastRun`:
   `git log -1 --format=%cI -- <input dirs>` newer than `lastRun` (inputs per stage: CLAUDE.md "Stage I/O
   mapping"). Uncommitted edits do not show up this way; mention `git status` if the user expects them to count.
4. **Errors.** Stages with `status: "error"`, with `staleReason` if present.
4b. **Route.** When pipeline-state has a `route` block (`sdd route --write`, `docs/ruta.md`), show who confirmed it
   (`confirmedBy`, or "not confirmed" when null), `decidedAt`, and the `doubts`. List each stage with
   `status: "skipped"` and its `skipReason`. A skipped stage counts as satisfied: it is neither pending nor next, the
   stages after it may run, and it has no artifacts to verify. When `route.reqHash` no longer matches the current
   requirements, say that the route was decided on an earlier version and recommend re-evaluating it
   (`node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" route --json`); `sdd-req-change` does this after every approved ADD or MODIFY.
5. **Acceptance.** Read `$STATE_ROOT/.sdd/acceptance.json` (written by `sdd accept`, `sdd gate` and `sdd loop next`;
   git-ignored) when it exists: `summary.must_verified`/`must_total`, `must_waived` (`waived_musts`), `by_verdict`
   (FAILING, MISSING), `stale_evidence`, `goal`, `unshown` (criteria that pass without a capture), `missing_videos`
   (with a FASE scope) and `must_challenged` (Musts with an open adversarial challenge), plus `evaluated_sha` and
   `generatedAt`. It answers "is each requirement delivered, with what evidence", which stage statuses cannot. If
   `evaluated_sha` differs from `git rev-parse HEAD`, say the summary predates the last commit. `goal` true with
   `must_challenged` > 0 and `adversarial_gate: enforce` (the ledger's, else the Stack Profile's) is what `sdd gate`
   reports as exit 4: say "goal blocked by open challenges", never "goal met". Do not run `sdd accept` yourself: this
   skill only reads.
5b. **Status page.** Read `status/page.json` (versioned, at the project root): its `url`, or `declined`, or absent.
   Show the last line of the customer's journal (`node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal list --json`, the
   last entry: date, text, who). Absent page in an interactive project → recommend creating it (plugin-root
   `references/status-page.md` §2); this skill only reads and never publishes.
6. **Report** (template below). Next action: the first stage that is stale, errored or pending (never a skipped one), in pipeline order
   (requirements → specifications → spec-auditor → test-planner → plan-architect → task-generator →
   task-implementer). When all of them are done or skipped: no `acceptance.json` → `/sdd-acceptance --check`; open Musts
   (goal false: some Must FAILING or MISSING) → `/sdd-acceptance --loop`; stale evidence only → `/sdd-acceptance
   --check` to re-capture the tests; goal blocked by open challenges (exit 4 above) → `/sdd-acceptance --loop`, or a
   person dismisses them (`challenge-dismissal`); goal met → `/sdd-acceptance --sign-off`.

```
## SDD Pipeline Status

| # | Stage | Status | Last Run | Artifacts | Notes |
|---|-------|--------|----------|-----------|-------|
| 1 | requirements-engineer | done | 2026-01-15 | OK | — |
| 3 | spec-auditor | stale | 2026-01-14 | OK | spec/ changed after the audit |
| 4 | test-planner | skipped | — | — | route: 6 REQ-F, no UI flows, no external customer |

### Route              (only with a `route` block)
- Confirmed by Laura (product owner) on 2026-01-15 · skipped: specifications-engineer, spec-auditor, test-planner · doubts: long_lived

### Last Change          (only with a `lastChange` block)
- Change Report: CHG-2026-01-20-001 · Changed: requirements/, spec/ · Invalidated: plan-architect, task-generator · Cascade: manual

### Acceptance           (only with .sdd/acceptance.json)
- Must 7/9 verified, 1 waived (REQ-NF-002) · FAILING 1 · MISSING 0 · stale evidence 0 · evaluated at a1b2c3d (HEAD) · goal not met
- Unshown 2 · missing videos: WF-003 · Musts with open challenges 1 (REQ-F-006)
- Open Musts: REQ-F-004 (FAILING)

### Status page
- https://claude.ai/… (or "declined", or "not created yet") · last journal line, 2026-01-21: "Planificamos 4 entregas; la primera te dejará crear y ver tareas"

### Handoffs             (multi-session only)
| Stage | To | Sent | Result |

### Recommended Next Action
> Run `/sdd-spec-auditor` to re-audit the updated specifications.

### Warnings
- INCONSISTENT / potentially stale stages
```

- **Handoffs**: only when a stage has `summary.handoff` (plugin-root `references/handoff-protocol.md`); show `to`,
  `sentAt`, `result` (`sent`, `skipped:*`, `failed:*`). Print the session role when `SDD_ROLE` is set.
- If `sddVersion` in pipeline-state is older than the installed plugin, add "run `/sdd-setup` to upgrade".

## Diagnose mode

**1. Fact sheet.** Collect and show these facts (one line each, with the evidence):

| Fact | How |
|------|-----|
| Code | Stack Profile `code_paths` in `CLAUDE.md`, else Glob source files outside `node_modules/`, build output, `.claude/worktrees/` |
| Tests | Glob `test_paths` / `*.test.*`, `*.spec.*`, `test_*.py`, `*_test.go`, `*.feature`; test-to-source file ratio |
| SDD dirs | `ls -d requirements spec audits test plan task design ux`; `$STATE_ROOT/pipeline-state.json` |
| Importable docs | OpenAPI/Swagger (`**/openapi*.{yaml,yml,json}`, `**/swagger*`), Jira/CSV/Excel exports, requirement-like Markdown or Notion exports under `docs/` (README alone does not count) |
| History | `git rev-list --count HEAD`, `git shortlog -sn HEAD` (contributors), `git log -1 --format=%cI` |
| Packages | workspaces (`package.json` `workspaces`, `pnpm-workspace.yaml`, `nx.json`, `turbo.json`, `lerna.json`, `go.work`, Cargo `[workspace]`) or several top-level dirs with their own manifest; CODEOWNERS teams |
| Fork | `git remote -v` has `upstream` or another origin; README/CHANGELOG says "forked from"/"migrated from" |
| Drift | with SDD dirs and code: commits touching `code_paths` after the last commit touching `spec/`/`requirements/` without a `Task:` trailer (`node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" verify --range <that commit>..HEAD --json`: results with `code: true` and an empty `trailers.Task`); `stale` stages; missing/orphan entries in `.sdd/gap-analysis.json` |

**2. Classify.** Apply the rules top to bottom; the first match wins.

| # | Rule | Scenario |
|---|------|----------|
| 1 | Two or more packages/services with their own manifests | **Multi-team**: classify each package with rules 2-8 and plan per package |
| 2 | An upstream remote or documented origin, and local commits since the fork point | **Fork/migration** |
| 3 | SDD dirs and code, and a drift signal | **SDD drift** |
| 4 | Some SDD dirs or pipeline-state, pipeline incomplete, no drift signal | **Partial SDD** |
| 5 | No code (boilerplate only) | **Greenfield** |
| 6 | Code and importable docs | **Brownfield with docs** |
| 7 | Code and tests with a test-to-source file ratio ≥ 0.3 | **Tests-as-spec** |
| 8 | Code only | **Brownfield bare** |

When a fact is uncertain and changes the outcome (e.g. an `upstream` remote that is just a mirror, a workspace
with one real package), ask the user with the two candidate scenarios instead of guessing. A complete pipeline with
no drift is not an onboarding case: fall back to Status mode.

**3. Plan.** Output the ordered commands for the scenario, adjusted to the facts. Start every plan with
`/sdd-setup` when `pipeline-state.json` is missing (add `--stack=<rails|nextjs-prisma|auto>` when the stack fits a
kit, `--app-dir DIR` when the app is not at the root). For every scenario with existing code, recommend
`acceptance_gate: warn` in the SDD Stack Profile until the adoption is complete: `sdd gate` then reports open Musts
without failing CI (new projects keep the default, `enforce`).

| Scenario | Commands after setup |
|----------|----------------------|
| Greenfield | `/sdd-import <file>` if requirement docs exist · `/sdd-requirements-engineer` · `/sdd-specifications-engineer` · `/sdd-spec-auditor` · `/sdd-test-planner` · `/sdd-plan-architect` (optionally `/sdd-tech-designer`, `/sdd-ux-designer` before it) · `/sdd-task-generator` · `/sdd-task-implementer` |
| Brownfield bare | `/sdd-reverse-engineer --inventory-only` (review Checkpoint 1) · `/sdd-reverse-engineer --continue` · `/sdd-spec-auditor` · `/sdd-gap-detector --semantic` |
| Brownfield with docs | `/sdd-import <file> [--format=openapi\|jira\|csv\|excel\|markdown\|notion] [--target=requirements\|specs\|both]` per source (`--merge` from the second source on) · `/sdd-reverse-engineer` (enriches the `[IMPORTED]` entries) · `/sdd-reconcile --dry-run` · `/sdd-spec-auditor` · `/sdd-gap-detector` |
| Tests-as-spec | `/sdd-reverse-engineer` (assertions become invariants, setups preconditions; review them at Checkpoint 1) · `/sdd-spec-auditor` · `/sdd-test-planner` · `/sdd-gap-detector --semantic` |
| SDD drift | `/sdd-reconcile --dry-run` · `/sdd-reconcile` (`--scope=<paths>` to go module by module) · `/sdd-spec-auditor` · `/sdd-gap-detector` · `/sdd-acceptance --check` |
| Partial SDD | the first missing stage in pipeline order, then the rest; `/sdd-reconcile --dry-run` first if code changed since the last SDD stage |
| Multi-team | per package, the plan of its own scenario with `--scope=<package paths>` on `/sdd-reverse-engineer` and `/sdd-reconcile`; `/sdd-acceptance --check` at the end |
| Fork/migration | `/sdd-import` of the upstream docs or specs if any · `/sdd-reverse-engineer --scope=<paths changed since git merge-base HEAD upstream/<branch>>` · `/sdd-spec-auditor` · then the standard pipeline |

Report: the fact sheet, the scenario with the rule that matched, the plan as a numbered table (command, why,
inputs it relies on), and the first command to run.
