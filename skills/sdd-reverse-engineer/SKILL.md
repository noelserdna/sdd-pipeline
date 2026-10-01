---
name: sdd-reverse-engineer
description: "Bootstraps SDD from existing code and tests: generates requirements, specs, test plan, architecture and retroactive tasks with traceability; extracts entities, routes, state machines, invariants, tech debt. Triggers: 'reverse engineer', 'extract specs from code', 'bootstrap SDD', 'code to requirements', 'analyze existing code', 'brownfield to SDD'."
---

# Skill: sdd-reverse-engineer — Code → SDD Artifact Generator

> **Pipeline position:** Lateral — bootstrap entry point (not a linear stage)
> **Feeds into:** `sdd-spec-auditor` (next), then `sdd-test-planner`, `sdd-plan-architect`
> **Recommended by:** `sdd-pipeline-status --diagnose` (Brownfield bare/with docs, Tests-as-spec, Multi-team, Fork/migration)

## 1. Scope

Scans the codebase and its tests, extracts entities, routes, state machines, invariants and business rules, and generates SDD artifacts in the exact formats of the forward-pipeline skills, with `file:line` evidence and findings (dead code, debt, workarounds, orphans, implicit rules).

Code and test paths come from the SDD Stack Profile (`code_paths` / `test_paths` in the project's `CLAUDE.md`, see `skills/sdd-task-implementer/references/stack-profile.md`); without a profile, detect them (`src/`, `tests/` are only defaults). These paths are read-only for this skill: it documents code, it never edits it, and it does not run tests or builds.

Out of scope: security analysis (`sdd-security-auditor`), drift between existing SDD artifacts and code (`sdd-reconcile`).

## 2. Invocation Modes

| Mode | Phases | Use case |
|------|--------|----------|
| default | 1-10 | Full brownfield bootstrap |
| `--scope=path1,path2` | 1-10, filtered to those paths | Module-level reverse engineering |
| `--inventory-only` | 1-4, stop at Checkpoint 1 | Quick codebase assessment |
| `--findings-only` | 1-4 + Phase 10 step 2 | Code health report without specs |
| `--continue` | Resume after the last checkpoint | Continue after a review pause |

## 3. Process

### Phase 1: Pre-Flight

1. Check existing SDD artifacts (`requirements/`, `spec/`, `test/`, `plan/`, `task/`):
   - None → normal run.
   - Only `requirements/REQUIREMENTS.md` (and optionally `spec/`) whose items are marked `[IMPORTED]` / `[IMPORTED-REPLACED]` (written by `sdd-import`) → **seed mode**: imported items are the starting point and are merged, not overwritten (see Phase 5 and 6).
   - Artifacts that were not produced by `sdd-import` → stop and recommend `sdd-reconcile` (drift scenario); continue only if the user explicitly asks to regenerate, and then back up the existing directories first.
2. Read `pipeline-state.json`. If it does not exist, create it from the plugin template, as `sdd-setup` Step 1 does (`templates/pipeline-state.template.json`, substituting `__SDD_VERSION__` and `__NOW__`).
3. Detect languages, frameworks, package manager, and resolve code/test paths (Stack Profile, else detection).
4. Create `reverse-engineering/` for intermediate outputs.

**Gate:** stop if no source directory is found.

### Phase 2: Scan & Inventory

1. Inventory source files by language and directory (files, LOC, entry points, config files).
2. Module dependency graph (imports) and external dependency tree.
3. Architectural layers: routes/controllers → API; services → domain; repositories → data access; models → domain model; middleware → cross-cutting; utilities → infrastructure.
4. Architectural style (MVC, layered, CQRS, event-driven, microservices).
5. Database schema from ORM models, migrations or schema files.
6. Test files: framework, structure, naming, coverage.

**Output:** `reverse-engineering/INVENTORY.md`

### Phase 3: Code Analysis

Read [references/code-analysis-patterns.md](references/code-analysis-patterns.md), then per module extract: entities and relationships; routes (method, path, params, schemas, middleware); state machines (explicit and implicit); invariants (validation, guards, constraints); dependencies; dead code; tech-debt markers; workarounds; implicit business rules; infrastructure patterns (logging, errors, auth, caching, rate limiting).

**Output:** `reverse-engineering/ANALYSIS.md` (by module)

### Phase 4: Test Analysis

From tests extract: suite structure; assertions → invariants/postconditions; setup → preconditions; mocks → external contracts; test data → input boundaries; BDD-like patterns. Map coverage to modules, classify tests (unit/integration/e2e/perf), list untested modules.

**Output:** `reverse-engineering/TEST-ANALYSIS.md`

### Checkpoint 1 — after Phase 4

Present: inventory summary, architectural style, findings counts, test coverage, proposed requirement grouping. Ask whether to continue with artifact generation. `--inventory-only` stops here.

### Phase 5: Requirements Extraction

Read [references/requirement-extraction-heuristics.md](references/requirement-extraction-heuristics.md), then:

1. Map features to EARS requirements (`WHEN <trigger> THE <system> SHALL <behavior>`): routes → functional; validation → constraints; auth, performance, reliability config → nonfunctional.
2. IDs follow `sdd-requirements-engineer`: `REQ-F-NNN`, `REQ-NF-NNN`, `REQ-C-NNN`. Group by business domain with section headings, not with the ID.
3. Tag confidence: no tag = directly observable; `[INFERRED]` = derived from patterns; `[IMPLICIT-RULE]` = business logic buried in conditionals.
4. Priority from usage, dependency count and error-handling presence.
5. Each requirement cites `Source: file:line` (and `Tests:` when present).
6. Each requirement carries its `- **Para el cliente:**` line (`sdd-requirements-engineer` `references/requirements-template.md`): one or two plain sentences on what the user can do or count on, drafted from what the code does. The code shows behaviour, not what the customer meant, so the line is a draft pending the customer's review: it has no `Examples reviewed by` until the customer reads it with the examples at approval (approval §3), and Checkpoint 2 lists these drafts as pending review with the customer.

**Seed mode:** keep every `[IMPORTED]` requirement with its ID and text. When code confirms it, add the `Source:` evidence; when code contradicts or does not implement it, keep the text and list it under a "Conflicts with code" section for the user (the imported document states intent; code does not override it). New requirements found only in code get the next free ID and `[INFERRED]`.

**Output:** `requirements/REQUIREMENTS.md` (format of `sdd-requirements-engineer`)

### Phase 6: Specification Generation

Generate the canonical tree of `sdd-specifications-engineer` ("Specification Folder Structure" in its SKILL.md, templates in its `references/document-templates.md`):

| Target | Derived from |
|--------|--------------|
| `spec/domain/01-GLOSSARY.md` … `05-INVARIANTS.md` | Entities, value objects/enums, state machines, invariants (`INV-{AREA}-NNN`) |
| `spec/use-cases/UC-NNN-{slug}.md` | One per user-facing feature; actors from auth roles; pre/postconditions from tests; alternative flows from error paths |
| `spec/workflows/WF-NNN-{slug}.md` | Multi-step processes, event flows |
| `spec/contracts/API-{module}.md` | Routes, schemas, error codes, auth. Code-derived contracts describe a real transport, so use `Style: http` |
| `spec/tests/BDD-UC-NNN.md` | Scenarios from existing tests and use cases |
| `spec/nfr/PERFORMANCE.md`, `LIMITS.md`, `SECURITY.md`, `OBSERVABILITY.md` | Timeouts, pools, TTLs, rate limits, auth patterns, logging/metrics |
| `spec/adr/ADR-NNN-{slug}.md` | One per major detected decision (framework, database, auth); status `[INFERRED]` because the rationale is guessed |
| `spec/TRACEABILITY-MATRIX.md`, `CLARIFICATIONS-PENDING.md`, `VALUE-REGISTRY.md` | REQ → artifacts; open questions; shared values |

In seed mode, existing `[IMPORTED]` spec files are extended (add sections, evidence) rather than replaced.

### Checkpoint 2 — after Phase 6

Present: requirements count by group and confidence, spec files generated, items needing a user decision (including the `Para el cliente:` drafts to review with the customer), and a REQ → UC → WF → API preview. Ask whether to proceed with test plan, plan and tasks.

### Phase 7: Test Plan Mapping

Map existing tests to requirements/UCs, list coverage gaps, and write `test/TEST-PLAN.md`, `test/TEST-MATRIX-*.md` per area, and `test/PERF-SCENARIOS.md` if performance tests or config exist (formats of `sdd-test-planner`).

### Phase 8: Plan Reconstruction

Write, in the formats of `sdd-plan-architect`: `plan/ARCHITECTURE.md` (C4 context/container/component, stack, deployment from Docker/CI), `plan/PLAN.md` with `> **Plan-Style:** vertical`, and `plan/fases/FASE-{N}-{SLUG}.md` with the source-to-test mapping table.

Retroactive FASEs are vertical, as new ones would be (`sdd-plan-architect/references/phase-assignment-rules.md`): one FASE per functional area (a user journey over its UCs, never a technical layer), ordered by the first commit that touched the area (`git log --reverse --format=%as -- <area paths> | head -1`); the oldest area is FASE-0. Each FASE header carries `Incremento`, `Requisitos` (the reconstructed REQs of the area, whole), `Escenarios` (their scenario ids) and `Necesidades` when known. Its `## Demo` is written from the existing behaviour, with every step marked `[INFERRED]` in the Resultado esperado cell: nobody has watched it yet, so the first FASE gate after onboarding runs it and confirms or corrects it. New work after onboarding goes into new FASEs after the last one.

### Phase 9: Task Reconstruction

Read [references/retroactive-task-template.md](references/retroactive-task-template.md) and write `task/TASK-FASE-{N}.md` per FASE: each task `[x]` + `[RETROACTIVE]`, real commit SHA from git history or `[NO-COMMIT]`, actual source/test files, links to REQ/UC.

### Phase 10: Traceability & Findings

1. Build REQ → UC → WF → API → BDD → INV → ADR → TASK → CODE, marking gaps. Proposed `// Refs:` markers are listed in the report, not written into code.
2. Compile `findings/FINDINGS-REPORT.md` with [references/findings-taxonomy.md](references/findings-taxonomy.md) (markers below).
3. Update `pipeline-state.json`: set to `done` only the stages whose artifacts this run produced — `requirements-engineer`, `specifications-engineer`, and, when Phases 7-9 ran, `test-planner`, `plan-architect`, `task-generator` — with `lastRun`, `outputHash` and a `summary` (`highlights` includes "reverse-engineered, pending audit"). `spec-auditor` stays `pending` because no audit ran, and `task-implementer` is untouched. Set `currentStage` to `spec-auditor` and `summary.nextStep` to `Run /sdd-spec-auditor`. Fixes from that audit change `spec/` and will mark downstream stages stale through the normal cascade.
4. Commit the artifacts this run wrote: `git add requirements/ spec/ reverse-engineering/ findings/` plus `test/`, `plan/`, `task/` when Phases 7-9 ran, then `docs(specs): reverse-engineer SDD artifacts from code` with `Refs:` the REQ ids, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed). Code is never part of this commit.

## 4. Findings Markers

| Marker | Meaning | Severity |
|--------|---------|----------|
| `[DEAD-CODE]` | Unreachable or unused code | INFO–MEDIUM |
| `[TECH-DEBT]` | Suboptimal implementation | LOW–HIGH |
| `[WORKAROUND]` | Temporary fix or hack | MEDIUM–HIGH |
| `[INFRASTRUCTURE]` | Cross-cutting pattern | INFO |
| `[ORPHAN]` | Code with no traceable requirement | LOW–MEDIUM |
| `[INFERRED]` | Derived from code patterns, needs confirmation | INFO |
| `[IMPLICIT-RULE]` | Undocumented business rule in code | MEDIUM–HIGH |

## 5. Outputs

| Directory | Files | Phase |
|-----------|-------|-------|
| `reverse-engineering/` | `INVENTORY.md`, `ANALYSIS.md`, `TEST-ANALYSIS.md` (intermediate) | 2-4 |
| `requirements/` | `REQUIREMENTS.md` | 5 |
| `spec/` | Canonical tree (Phase 6 table) | 6 |
| `test/` | `TEST-PLAN.md`, `TEST-MATRIX-*.md`, `PERF-SCENARIOS.md` | 7 |
| `plan/` | `ARCHITECTURE.md`, `PLAN.md`, `fases/FASE-*.md` | 8 |
| `task/` | `TASK-FASE-*.md` | 9 |
| `findings/` | `FINDINGS-REPORT.md` | 10 |
| root | `pipeline-state.json` (Phase 10 rule) | 1, 10 |

Reads: code and test paths, package/CI/config files, git history, `pipeline-state.json`.

## 6. Related Skills

`sdd-import` may run first to seed requirements (seed mode above); `sdd-reconcile` replaces this skill when SDD artifacts already exist; after this skill run `sdd-spec-auditor`, then `sdd-test-planner` / `sdd-plan-architect` to refine, `sdd-acceptance --check` to verify the chain and the evidence per requirement, `sdd-security-auditor` for security.

## 7. Rules

- Pause at both checkpoints; the user validates inferred content before it drives further artifacts.
- Every generated item cites the code location it came from; inferred items carry `[INFERRED]` or `[IMPLICIT-RULE]`.
- When a pattern is ambiguous, record it as a finding or a `CLARIFICATIONS-PENDING.md` entry instead of guessing.
- Output language follows the user's language; technical terms stay in English.
