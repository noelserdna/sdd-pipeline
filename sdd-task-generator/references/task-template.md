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
> **Parallel capacity:** {max concurrent streams}
> **Critical path:** {count} tasks

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | {N} |
| Parallelizable | {N} ({%}) |
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

**Stream A:** TASK-F{N}-003, TASK-F{N}-004, TASK-F{N}-007
**Stream B:** TASK-F{N}-002, TASK-F{N}-005, TASK-F{N}-008
**Stream C:** TASK-F{N}-006, TASK-F{N}-009

### Rollback Checkpoints

| Checkpoint | After Task | Safe Revert Point | Verified By |
|-----------|------------|-------------------|-------------|
| CP-1 | TASK-F{N}-{X} | git tag fase-{N}-cp-1 | {verification command} |
| CP-2 | TASK-F{N}-{Y} | git tag fase-{N}-cp-2 | {verification command} |
```

---

## Task Entry Format (Quick Reference)

```markdown
- [ ] {TASK-ID} [P?] {Description} | `{file_path}`
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
| File path | YES | Exact path from project root |
| Commit | YES | Conventional commit format |
| Acceptance | YES | At least 1 criterion, specific values |
| Refs | YES | At least FASE reference |
| Revert | YES | Category + impact |
| Review | YES | At least 2 checks |
