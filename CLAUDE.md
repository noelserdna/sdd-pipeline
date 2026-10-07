# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A **Claude Code plugin** (`sdd-pipeline`, version in `.claude-plugin/plugin.json`) that implements a Specification-Driven Development pipeline based on SWEBOK v4. Its goal: capture the customer's needs, turn them into verifiable requirements, and show with evidence that every requirement was delivered.

- 21 skills: 7 pipeline, 4 lateral, 3 brownfield, 7 utility (including acceptance, the interactive orchestrator and the multi-session lead)
- 5 hook scripts (7 event registrations) plus the git `commit-msg` hook
- one CLI, `scripts/sdd.mjs` (tasks, git traceability, commit verification, branches, need coverage, plan lint, literal lint, floor lint, adaptive route, acceptance ledger and gate, customer journal and status page)
- an MCP server for live traceability queries
- an optional TypeSafe Jev integration for bulk judgments

Most of the product is prompt text (skills and their references). The executable parts are:

- the hooks (bash + one Node script)
- `scripts/` (Node CLI and libraries, bash helpers, validators, `sdd-graph.py`)
- the TypeScript MCP server in `server/`, bundled with esbuild into the committed `server/dist/server.js`

## Pipeline

```
sdd-requirements-engineer    →  requirements/CUSTOMER-NEEDS.md, REQUIREMENTS.md  (approval tag requirements-v{N})
sdd-specifications-engineer  →  spec/ (domain, use-cases, workflows, contracts, tests, nfr, adr)
sdd-spec-auditor             →  audits/AUDIT-BASELINE.md  (--fix applies accepted corrections to spec/)
sdd-test-planner             →  test/ (TEST-PLAN, TEST-MATRIX-*, PERF-SCENARIOS, E2E-SCENARIOS)
sdd-plan-architect           →  plan/ (PLAN.md with Plan-Style: vertical, ARCHITECTURE.md, fases/FASE-{N}-{SLUG}.md, fase-plans/)
sdd-task-generator           →  task/TASK-FASE-{N}.md
sdd-task-implementer         →  code/test paths from the SDD Stack Profile, one commit per task, FASE demo in Phase 9
sdd-acceptance               →  acceptance/ACCEPTANCE-REPORT.md, decisions.jsonl, challenges.jsonl; tag fase-{N}-accepted at sign-off
```

**Status page** (`references/status-page.md`, `docs/aceptacion.md`): one page per project for the customer, created at setup (or when the orchestrator or lead starts) when the session has the Artifact tool, and updated after every stage and gate. It is deterministic: the fixed template `templates/status-page/` filled by `sdd status build` from the artifacts. Skills only write plain-language lines to the journal (`sdd journal add`, `status/journal.jsonl`: a `start` line when a run begins, a `done` line in Persist) and run the publish procedure; the URL, features and published evidence live in `status/page.json`. Both are versioned. Each requirement carries a `- **Para el cliente:**` line the customer reviews at approval; customer comments on the page are read at every FASE gate.

FASEs are **vertical**: FASE-0 is a walking skeleton (write → observe → persist of the central use case), then one user journey per FASE with a `## Demo` of at most 10 steps. The FASE gate is the customer's acceptance of that increment.

**Adaptive route** (`docs/ruta.md`): after gate 1, `sdd route` proposes which optional stages this project needs (specifications, spec audit, test plan, the laterals, gap-detector), from counted facts of the requirements and seven narrow factor judgments (Jev, or the session's LLM through `--answers` when Jev is off; a doubt counts as yes). The rules and their reasons live in `scripts/lib/route-rules.mjs`. A person confirms it in one question (orchestrator/lead stage 1b), and `route --write --confirm` stores the `route` block and marks the stages it leaves out `skipped` with a `skipReason`. Without specifications, plan-architect plans from the requirements (journeys by customer need, `Escenarios` as `REQ-X-NNN ACn`), tests carry `REQ-X-NNN ACn`, and req-change edits only `requirements/`, cascades from plan-architect and re-evaluates the route after every approved ADD/MODIFY. It recommends the stages that escalate and never lowers the rigor by itself.

**Lateral** (any time):
- `sdd-tech-designer` → `design/`, including `OPERATION-MAPPING.md`, which plan-architect writes itself when tech-designer was not run.
- `sdd-ux-designer` → `ux/`, read by plan-architect and test-planner.
- `sdd-security-auditor` → `audits/SECURITY-AUDIT-BASELINE.md`. Its fixes go through req-change.
- `sdd-req-change` → ADD/MODIFY/DEPRECATE with ISO 14764 classification and an optional cascade (`--cascade=auto|manual|dry-run|plan-only`). It writes `changes/CHANGE-REPORT-{CHG-ID}.md`; a MODIFY reopens that requirement's acceptance.

**Brownfield:** `sdd-reverse-engineer` (code → artifacts, retroactive FASEs by functional area), `sdd-reconcile` (drift; amends specs only, reads `.sdd/gap-analysis.json`), `sdd-import` (Jira, OpenAPI, Markdown, Notion, CSV, Excel).

**Utility:**
- `sdd-setup`: state file, git hook and vendored validator, journal and status page, stack kits `--stack=<rails|nextjs-prisma>`, multi-session, cleanup of 4.x status lines.
- `sdd-pipeline-status`: stage report, acceptance summary, status page link and last journal line; `--diagnose` classifies an existing project into 8 adoption scenarios.
- `sdd-acceptance`: `--check` (ledger + chain integrity), `--fase N`, `--adversarial` (independent verifiers against the letter of each requirement, run before every FASE gate), `--loop`, `--sign-off`, `--publish`. See `docs/aceptacion.md`.
- `sdd-gap-detector`: spec vs code gaps; `--semantic` checks requirement coverage in the code.
- `sdd-session-summary`
- `sdd-orchestrator`: drives the whole pipeline from the main conversation.
- `sdd-lead`: multi-session, see `docs/multisesion.md`.

## Repository Layout

```
.claude-plugin/        plugin.json, marketplace.json
skills/sdd-*/          SKILL.md + references/ (loaded on demand at the step that names them)
hooks/                 hooks.json, lib/sdd-common.sh, sdd-*.sh, sdd-augment-hook.js, sdd-commit-msg-hook.sh (git hook)
scripts/               sdd.mjs (+ lib/: git-log, acceptance, acceptance-cli, quotes, junit, plan-lint, tracker, route, route-rules, status, journal, floor), sdd-task-lint.mjs (alias),
                       sdd-state.sh, sdd-jev.mjs + jev/*.json, sdd-graph.py + test-result-parser.py (graph JSON),
                       install-*.sh, migrate-hooks-v3.sh, sdd-up/bench/profile, validate-plugin.mjs, check-*.sh, release.sh
server/                src/{index,server,graph-loader,acceptance,resources,prompts,hints}.ts, src/tools/{query,impact,context,coverage,trace,gaps}.ts
templates/             pipeline-state template, gitignore policy, sessions example, optional quality gates, stacks/<kit>/, status-page/ (page template + data contract)
references/            sdd-constitution.md (12 articles), git-conventions.md, handoff-protocol.md, async-questions.md, status-page.md
.claude/agents/        maintainer agents for THIS repo (sdd-pipeline-auditor, sdd-cross-auditor), not shipped
examples/todo-app/     toy project (customer needs + requirements) used by the pipeline auditor
tests/                 hooks, setup, tasks, graph, jev, bench, git, plan, acceptance, quotes, seeded (seeded-defect bench), tracker, route, status, floor, triggers (description routing cases), e2e, fixtures
docs/                  guides (Spanish), git, acceptance, stacks, multisession, jev, measurements, design/
```

## Development Loop

The same commands CI runs:

```bash
node scripts/validate-plugin.mjs && bash scripts/check-paths.sh && bash scripts/check-version.sh
bash tests/e2e/00-validate.sh
for t in hooks setup tasks graph jev bench git plan acceptance quotes seeded tracker route status floor triggers; do bash tests/$t/run.sh || break; done
shellcheck -S warning hooks/*.sh scripts/*.sh tests/hooks/*.sh
cd server && npm run check && npm run build && npm test   # commit dist/server.js with src changes
```

Hooks run in this checkout too (the plugin is enabled here). The session start hook may export `SDD_STATE_ROOT`, so run fixture tests with `env -u SDD_STATE_ROOT`, and check that `git status` shows no `pipeline-state.json` or `.sdd/` before committing.

## Key Conventions

- **EARS** statements for REQ-F/REQ-NF: `WHEN <trigger> THE <system> SHALL <behavior>`. Constraints (REQ-C) are plain statements. Every requirement has `Needs:` (customer needs) and `Verification: test | demo | measurement | inspection`, and each acceptance criterion carries a concrete example.
- **IDs:** N-NNN (customer needs) · REQ-F/NF/C-NNN · UC-NNN · WF-NNN · operations API-NNN-NN · BDD-UC-NNN with scenarios AC-NNN-NN · INV-{AREA}-NNN · ADR-NNN · RN (business rules) · TASK-F{N}-NNN · UX screens SCR-NNN · CHG-YYYY-MM-DD-NNN. Test names carry their scenario id (`AC-NNN-NN`) so results bind to criteria.
- **Traceability chain:** N → REQ → UC → WF → API → BDD/AC → INV → ADR → TASK → COMMIT → CODE → TEST → verdict.
- **Git** (`references/git-conventions.md`, validated by `sdd verify` and the commit-msg hook):
  - Trailers written with `git commit --trailer`: `Task` (one per commit; required on feat/test/refactor), `Refs` (spec ids; required on `docs(specs)`), `Change` (CHG/CR/finding; fix/perf need `Task` or `Change`).
  - Exempt: other docs, chore, ci, style, build, merges, reverts, fixup!/squash!/amend!, `[skip-sdd]`.
  - Work starts on a branch (`sdd branch start fase|change|audit …`); merges are merge commits (`--no-ff`), never squash or rebase, because squashing erases the `Task` trailers.
  - Tags: annotated; `requirements-v{N}` (approval), `fase-{N}-accepted` (customer acceptance), `fase-N-foundation`/`fase-N-verified` (Streams). No git notes.
- **Clarification-first:** skills ask with `AskUserQuestion` (at most 4 questions per call). In station or `claude -p` mode they follow `references/async-questions.md`. An instruction in a task, skill or CLAUDE.md is never a human approval.
- **Baseline auditing:** the first audit creates the baseline; later audits report new findings and regressions.
- **Visual evidence:** every criterion of a `REQ-F` needs a capture and every user-facing workflow a video (the `WF-NNN` of the FASE's `Workflows:` header line; one named `FASE-N` when the FASE names no workflow), under `evidencias/FASE-{N}/` with the id in the file name (git-ignored; the ledger keeps their sha256). Without one the criterion is `unshown` and the requirement is not VERIFIED (`visual_evidence: required|warn|off`). Evidence is captured only over committed code: `sdd accept --junit-sha`, `accept measure` and `accept record` (except `waiver`, `challenge-dismissal`, `literal-exception` and `floor-exception`) refuse dirty code (exit 2), and `sdd accept` without `--junit-sha` warns and counts the evidence as stale.
- **Literal letter:** a test quotes its criterion from `requirements/REQUIREMENTS.md` above the assert (`sdd req show`), because every link of the chain paraphrases it. `sdd lint --quotes` checks it per criterion and test file (Q-01 no quote, warn; Q-02 quote not the current text; Q-03 a literal of the criterion missing from the test's code). With `literal_gate: enforce` (default) a passing Must criterion with a Q-02/Q-03 is `weakened` and the requirement is not VERIFIED (loop route `weakened-test`, a test edit a person approves); a literal a helper builds is excepted only by a person (`accept record literal-exception`, bound to the requirement's reqHash).
- **Floor guard:** `sdd lint --floor [--base REF]` reports what lowers the bar since a base (`--base`, else the merge-base with the default branch, else the last `fase-*-accepted`; exit 2 without one; the base and its reason always printed): F-07 a Stack Profile gate set lower than the base set it (error), F-01 skip/only/focus added to a bound or existing test (error), F-02 a test file deleted, renamed or moved out of `test_paths` losing the criterion ids it named (error), F-04 a coverage/security suppression (warn). Raising the bar is never a finding. `floor_gate: off|warn|enforce` (default enforce) is read from the base. Phase 9 runs it without `--base`; the acceptance loop's test-edit report is `lint --floor --base <cycle-1 sha> --json` (`testEdits` with A/M/D/R); CI runs it against the PR base. A criterion whose bound tests are all skipped is MISSING with `reason: "bound test skipped"` (route `weakened-test`). Only a person excepts a finding (`accept record floor-exception`, bound to file, exact line and base sha).
- **Prove-It:** a fix task from the FASE gate or the adversarial round carries `Reproduce first:` (the test that reproduces the defect fails before the fix; a green test of the criterion does not count), except a `WEAKENED-ASSERT` or `WRONG-CAPTURE` finding, where the code is right and the test is fixed, an edit a person approves. `sdd verify --range` flags a `fix` commit that touches `code_paths` without any test (`prove_it: warn` default, `enforce`, `off`). No trailer and no separate red commit, because a failing commit breaks bisect and a task is one commit.
- **Revert strategies** per task: SAFE, COUPLED, MIGRATION, CONFIG. With `task_format: compact`, a task without a Revert block is SAFE.
- **Specs are the source of truth** (Article 12, below).

## Article 12: Specification Primacy

This is the foundational principle, and the last article of `references/sdd-constitution.md`.

1. **Tests verify specifications, never the code.** When a test fails, the defect is in the code. Never adapt a test to match code that deviates from the spec; a test edited inside the acceptance loop is listed and approved by a human.
2. **Specs may be wrong, but only humans decide.** An implementer (human or LLM) who finds a spec impractical or contradictory implements it **as written** and records a `SPEC-DEVIATION` entry in `feedback/IMPL-FEEDBACK-FASE-{N}.md` (spec ID and text, where it was observed, the proposed change and its impact, a recommendation of AMEND, KEEP or NEEDS-DISCUSSION). It must not silently change the spec, the test or the behaviour.
3. **The cascade is: human decision → `sdd-req-change` → spec → tests → code.** Never the reverse.

## Pipeline State

`pipeline-state.json` lives at the project root (the main checkout when worktrees are used). The authoritative schema is `skills/sdd-req-change/references/cascade-patterns.md` §9, and the template is `templates/pipeline-state.template.json`.

- Top-level fields: `sddVersion`, `hooksVersion` (3), `currentStage`, `lastUpdated`, `stages`.
- Each stage has `status` (pending | running | done | stale | error | skipped), `lastRun`, `outputHash`, `staleReason`, `skipReason` (with skipped) and, on completion, `summary` (artifacts, metrics, highlights, nextStep, generatedAt).
- `route` (written by `sdd route --write`): `decidedAt`, `factors`, `facts`, `stages` ({run, reason} per stage), `doubts`, `confirmedBy`, `reqHash`. A `skipped` stage counts as satisfied (gates, lead dispatch, next step), is never marked stale, and runs again only when a person puts it back on the route; a done or running stage is never switched to skipped.
- Lateral skills and `acceptance` add their own keys. `acceptance` is never marked stale by a cascade: `sdd accept` recomputes freshness itself (evidence against `evaluated_sha`, human decisions against the requirement's text hash).
- Only `sdd-setup` creates the file; hooks never create it.
- The state hook moves a stage pending/stale/done → running when its skill starts, and pending/stale → running on writes under its directory.
- Skills set done/stale/error, preferably with `bash "$SDD_PLUGIN_ROOT/scripts/sdd-state.sh" set <stage> <status>`, which takes the same lock as the hooks.
- Staleness cascades downstream. A change in `requirements/` means re-running from specifications-engineer (from plan-architect when the route skipped the specifications), `spec/` from spec-auditor, `plan/` from task-generator, `task/` from task-implementer.
- Gates on the spec audit read `stages["spec-auditor"].summary.metrics.gate_result` ∈ {PASS, CONDITIONAL}; a skipped spec-auditor makes them n/a.
- `status/journal.jsonl` and `status/page.json` (versioned, cascade-patterns §10) are the customer's plain record and the status page register; they have no stage key and a cascade never marks them stale. `summary` stays the technical record.
- `.sdd/acceptance.json` (git-ignored) holds the last ledger; `acceptance/` (versioned) holds the report, the human decisions (`decisions.jsonl`) and the adversarial challenges (`challenges.jsonl`).

## Automation

Hooks are declared in `hooks/hooks.json` and run from `${CLAUDE_PLUGIN_ROOT}`. Nothing is copied into projects. They fail open, and all except the guards are silent in projects without SDD state.

| Hook | Event (matcher) | Purpose |
|------|-----------------|---------|
| `sdd-session-start.sh` | SessionStart (startup/resume/compact) | Injects `N/M done, K skipped`, stale stages, next step, session role and the acceptance summary |
| `sdd-upstream-guard.sh` | PreToolUse (Edit/Write) | Art. 4: denies downstream stages editing upstream artifacts; denies hand edits of `acceptance/decisions.jsonl`, `acceptance/challenges.jsonl` and the acceptance report |
| `sdd-tool-guard.sh` | PreToolUse (Bash) | Denies assigning human-consent variables for AI-gated tools; asks before `sdd accept record` and `fase-N-accepted`/`requirements-vN` tags |
| `sdd-augment-hook.js` | PreToolUse (Read/Edit/Write) | Adds up to 2 traceability lines for the file from the graph |
| `sdd-pipeline-state-updater.sh` | PreToolUse (Skill), UserPromptExpansion, PostToolUse (Write); async | Marks the stage running when its skill starts or a file under its directory is written |

Also:
- The git `commit-msg` hook, installed by `sdd-setup`: it runs `sdd verify` from the validator vendored into `.claude/sdd/` (commit it; CI uses it too).
- `scripts/sdd-graph.py` builds `dashboard/traceability-graph.json`, read by the MCP server, the augment hook and session start. There is no HTML dashboard.
- Optional quality gates in `templates/settings-optional-quality-gates.json`.
- Environment variables: `SDD_ROLE`, `SDD_STATE_ROOT` (honoured only when it belongs to the target repo), `SDD_PLUGIN_ROOT`.
- Skill-level Stop prompts: `sdd-spec-auditor` (after Mode Fix) and `sdd-acceptance` (after `--loop`).
- The guards prevent accidental self-approval; they are not a security guarantee.

## Jev (optional)

`scripts/sdd-jev.mjs` sends small typed questions to TypeSafe's Jev when `TYPESAFE_API_KEY` is set (`SDD_JEV=off` disables it). Without the key it exits 3 and skills do the work with the LLM. Uses: `req-lint` and `needs` (need-coverage) in requirements-engineer, pattern-hit triage in spec-auditor, the coverage judge in `gap-detector --semantic`, `feedback-route` at the FASE gate, and the advisory `test-adequacy`/`evidence` sets in sdd-acceptance (test-adequacy also ranks the criteria the adversarial verifiers read first; Jev never sees images or video).

Question sets live in `scripts/jev/*.json`, thresholds inside each file. Jev returns probabilities and only suggests: mechanical checks (`sdd lint --needs`), the `sdd` CLI and humans decide. Never use it for permission decisions (guards, commit-msg), verdicts, waivers, sign-offs, the loop's stop or anything in CI. See `docs/jev.md`.

## Modifying Skills

- Keep the YAML front matter. The `description` (≤ 400 chars, validated) carries the trigger phrases that route requests. When you change a description, update its cases in `tests/triggers/cases.json` and run `bash tests/triggers/run.sh`, since a new phrase can steal requests from another skill.
- Write for a frontier model:
  - State each rule once, calmly, with its reason.
  - Put single-step templates and catalogs in `references/`, with a pointer at the step that needs them.
  - Leave out generic advice, textbook theory and leftovers from past projects.
- Commit examples in skills use `git commit --trailer` (validate-plugin flags heredoc trailers and unknown trailer keys).
- Cross-skill contracts (paths, IDs, state keys, metric keys in cascade-patterns §9, formats enforced by `sdd lint` and `sdd verify`, FASE header labels read by `sdd lint --plan` and `sdd gate --fase`) must stay consistent. Run `.claude/agents/sdd-cross-auditor.md` after contract changes.

## Standards Referenced

SWEBOK v4 · OWASP ASVS 4.0.3 · CWE · IEEE 830 · ISO 14764 · C4 Model · Gherkin/BDD · JUnit XML · WCAG 2.2 AA.

## Known Gaps

- SWEBOK Ch05 production operations (monitoring, incident response, runtime rollback), Ch07 engineering management and Ch10 economics are out of scope.
- Skills rely on bash (grep, git) as provided by Claude Code; porting to non-CLI hosts needs that abstracted.

## Language

Skills are written in English with some Spanish contextual text (FASE header labels stay in Spanish because tools parse them). Output follows the user's language, and technical terms stay in English.
