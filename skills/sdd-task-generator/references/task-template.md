# Task Document Template

> Reference template for per-FASE task documents.
> Every `TASK-FASE-{N}.md` MUST follow this structure.

---

## Template: TASK-FASE-{N}.md

```markdown
# Tasks: FASE-{N} - {Title}

> **Input:** plan/fases/FASE-{N}-{slug}.md + plan/PLAN-FASE-{N}.md
> **Generated:** {YYYY-MM-DD}
> **Total tasks:** {count}
> **Parallel capacity:** {number of work Streams from Stream Ownership}
> **Critical path:** {count} tasks

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | {N} |
| Parallelizable | {N} ({%}) |
| Work Streams | {N} (A: {n} tasks, B: {n} tasks) |
| Setup phase | {N} tasks |
| Foundation phase | {N} tasks |
| Domain phase | {N} tasks |
| Contract phase | {N} tasks |
| Integration phase | {N} tasks |
| Test phase | {N} tasks |
| Verification phase | {N} tasks |

## Traceability

| Spec Reference | Task Coverage |
|---------------|---------------|
| {UC-XXX} | {TASK-F{N}-XXX, ...} |
| {ADR-XXX} | {TASK-F{N}-XXX, ...} |
| {INV-XXX-XXX} | {TASK-F{N}-XXX, ...} |
| {REQ-XXX-XXX} | {TASK-F{N}-XXX, ...} |

---

## Phase 1: Setup

**Purpose:** Project structure, dependencies, configuration.
**Checkpoint:** Project initializes and builds successfully.

- [ ] TASK-F{N}-001 [P] {Description} | `{file_path}`
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:**
    - {criterion_1}
    - {criterion_2}
  - **Refs:** {FASE-N}, {UC-XXX}, {ADR-XXX}, {INV-XXX-XXX}
  - **Revert:** {SAFE|COUPLED|MIGRATION|CONFIG} — {impact description}
  - **Review:**
    - [ ] Code compiles without errors
    - [ ] Follows ubiquitous language
    - [ ] {domain_specific_check}

---

## Phase 2: Foundation

**Purpose:** Shared infrastructure blocking all subsequent phases.
**Checkpoint:** Foundation services pass smoke tests.

- [ ] TASK-F{N}-{SEQ} {Description} | `{file_path}`
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:**
    - {criterion}
  - **Refs:** {references}
  - **Revert:** {category} — {impact}
  - **Review:**
    - [ ] {check}

---

## Phase 3: Domain

**Purpose:** Entities, value objects, domain logic.
**Checkpoint:** Domain model unit tests pass.

{Same task format as above}

---

## Phase 4: Contracts

**Purpose:** API endpoints, event schemas, handlers.
**Checkpoint:** Contract tests pass against spec.

{Same task format as above}

---

## Phase 5: Integration

**Purpose:** Wiring, event handlers, cross-cutting concerns.
**Checkpoint:** Integration tests pass.

{Same task format as above}

---

## Phase 6: Tests

**Purpose:** Remaining test coverage (BDD, property, e2e).
**Checkpoint:** All test suites green.

{Same task format as above}

### Test Exclusions

Files excluded from unit test coverage (from PLAN-FASE §7.4 Exclusions):

| File | Reason | Verified By |
|------|--------|-------------|
| {file_path} | {reason} | {integration test / E2E test / N/A - infrastructure} |

> Task generator MUST verify that every source file with testable logic either has a test task in this phase or appears in this exclusions table.

---

## Phase 7: Verification

**Purpose:** End-to-end validation against FASE Criterios de Exito.
**Checkpoint:** All FASE acceptance criteria verified.

- [ ] TASK-F{N}-{LAST} Verify all FASE-{N} Criterios de Exito
  - **Commit:** `test({scope}): verify FASE-{N} acceptance criteria`
  - **Acceptance:** All criteria from FASE-{N} marked as verified
  - **Refs:** FASE-{N}
  - **Revert:** SAFE
  - **Review:**
    - [ ] All criteria checked
    - [ ] Evidence documented

---

## Dependencies

### Task Dependency Graph

```mermaid
graph TD
    TASK-F{N}-001 --> TASK-F{N}-002
    TASK-F{N}-001 --> TASK-F{N}-003
    TASK-F{N}-002 --> TASK-F{N}-005
    TASK-F{N}-003 --> TASK-F{N}-005
    TASK-F{N}-004 --> TASK-F{N}-006
```

### Critical Path

1. TASK-F{N}-001 → TASK-F{N}-002 → TASK-F{N}-005 → ... → TASK-F{N}-{LAST}
   ({count} tasks on critical path)

### Parallel Execution Plan

**Stream A:** {what it delivers, e.g. "API surface"} — see Stream Ownership
**Stream B:** {what it delivers, e.g. "CLI"} — see Stream Ownership

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F{N}-001, TASK-F{N}-002 | package.json, src/index.ts | main checkout, before worktrees (checkpoint `fase-{N}-foundation`) |
| A | TASK-F{N}-003, TASK-F{N}-005 | src/api/**, tests/api/** | worktree `feat/fase-{N}-a` |
| B | TASK-F{N}-004, TASK-F{N}-006 | src/cli/**, tests/cli/** | worktree `feat/fase-{N}-b` |
| integración | TASK-F{N}-009 | src/index.ts | main checkout, after `--integrate --fase {N}` |
| verificación | TASK-F{N}-{LAST} | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Foundation | TASK-F{N}-002 | `fase-{N}-foundation` | main checkout |
| Verified | TASK-F{N}-{LAST} | `fase-{N}-verified` | main checkout |
```

### Stream Ownership Rules

| Rule | Detail |
|------|--------|
| Source of truth | `sdd-task-implementer --stream X` filters tasks by this table, never by markers on the task lines |
| Row order | `base`, then work Streams `A`…`Z` (largest first), then `integración`, then `verificación`; empty Streams are listed with `—` |
| `base` | Setup + Foundation tasks; main checkout before any worktree; last commit tagged `fase-{N}-foundation` |
| Work Streams | Connected components of the Domain/Contracts/Integration write-set + `blocked-by` graph (SKILL.md Phase 3b); write-sets pairwise disjoint (V-15) |
| `integración` | Wiring tasks that touch ≥ 2 components (`src/index.ts`, `routes/index.ts`, migration indexes, barrels); main checkout after `--integrate --fase {N}` |
| `verificación` | Verification-phase tasks and cross-Stream test tasks; main checkout, implementer Phase 9 (V-17) |
| Owns | Smallest globs covering the Stream's write-set and no file of another Stream; exact paths when a directory is shared |
| Runs in | `worktree \`feat/fase-{N}-{stream lower-case}\`` for A…Z; `main checkout, …` for the rest |
| Single Stream | Table still written (base + A + integración/verificación); `TASK-ORDER.md` says `Streams: serial` |

---

## Task Entry Format (Quick Reference)

```markdown
- [ ] {TASK-ID} [P?] {Description} | `{file_path}`
  - blocked-by: {TASK-ID, ...}
  - **Files:** `{extra_path}`, `{extra_path}`
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:**
    - {criterion with specific values, not vague}
  - **Refs:** {FASE, UC, ADR, INV, REQ — comma-separated}
  - **Revert:** {SAFE|COUPLED|MIGRATION|CONFIG} — {what breaks}
  - **Review:**
    - [ ] {actionable check for reviewer}
```

### Field Rules

| Field | Required | Notes |
|-------|----------|-------|
| Task ID | YES | Format: `TASK-F{N}-{SEQ}` |
| [P] marker | NO | Only if parallelizable |
| Description | YES | Imperative mood, specific, with file path |
| File path | YES | Exact path from project root; comma-separate several paths after the `\|` when the task touches more than one file |
| blocked-by | NO | Task IDs this task depends on (same FASE or earlier); drives Stream assignment (V-18) |
| Files | NO | Extra paths the task creates/modifies; together with the file path(s) they form the task's write-set (Stream Ownership) |
| Commit | YES | Conventional commit format |
| Acceptance | YES | At least 1 criterion, specific values |
| Refs | YES | At least FASE reference |
| Revert | YES | Category + impact |
| Review | YES | At least 2 checks |
