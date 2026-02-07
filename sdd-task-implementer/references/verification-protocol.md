# Verification Protocol

> Reference for verifying that implementation matches specifications.
> Three-dimensional verification: Completeness, Correctness, Coherence.
> Inspired by OpenSpec's verify command and SWEBOK §4.3.6 Construction Quality.

---

## Dimension 1: Completeness

Verify that ALL tasks have been implemented with all required artifacts.

### Per-Task Completeness Check

For each task marked `[x]` in `task/TASK-FASE-{N}.md`:

```
CHECK-C01: Source files exist
  - Files listed in task description exist at expected paths
  - Files are not empty

CHECK-C02: Test files exist
  - Corresponding test files exist (if task type requires tests)
  - Test file is not empty or stub-only

CHECK-C03: Commit exists
  - Git log contains commit matching task's Commit message
  - Commit modifies only the files listed in the task

CHECK-C04: Acceptance criteria addressable
  - Each acceptance criterion from the task has corresponding code
  - No acceptance criterion left unimplemented
```

### FASE-Level Completeness Check

```
CHECK-C10: All tasks implemented
  - Count: {completed}/{total} tasks
  - Any blocked tasks? List with reasons

CHECK-C11: Criterios de Exito met
  - Each criterio from plan/fases/FASE-{N}-*.md verified
  - Evidence documented for each

CHECK-C12: Checkpoint tags placed
  - Internal phase checkpoints exist
  - Final FASE checkpoint exists
```

### Completeness Report Format

```markdown
## Completeness: {completed}/{total} ({percentage}%)

| Task | Files | Tests | Commit | Status |
|------|-------|-------|--------|--------|
| TASK-F0-001 | ✓ | N/A | abc1234 | COMPLETE |
| TASK-F0-002 | ✓ | ✓ (3 tests) | def5678 | COMPLETE |
| TASK-F0-003 | ✓ | ✓ (5 tests) | — | INCOMPLETE |
| TASK-F0-004 | ✗ | ✗ | — | MISSING |

Missing files: src/middleware/rate-limiter.ts
Missing tests: tests/middleware/rate-limiter.test.ts
```

---

## Dimension 2: Correctness

Verify that implementation behavior matches specification intent.

### Per-Task Correctness Check

For each completed task:

```
CHECK-R01: Acceptance criteria satisfaction
  For each criterion in task's Acceptance field:
    - Locate implementing code
    - Verify code logic satisfies the criterion
    - Note specific file:line references

CHECK-R02: Spec fidelity
  For each Ref in task's Refs field:
    - Read the referenced spec (UC, ADR, INV, REQ)
    - Verify implementation follows spec exactly
    - Flag any deviations

CHECK-R03: Contract compliance
  If task implements an API endpoint:
    - HTTP method matches contract
    - Path matches contract
    - Request schema matches contract
    - Response schema matches contract
    - Error responses match contract
    - Status codes match contract

CHECK-R04: Invariant enforcement
  For each INV-* in task's Refs:
    - Locate validation code enforcing the invariant
    - Verify validation covers all cases
    - Verify error handling on violation

CHECK-R05: State machine compliance
  If task touches an entity with state machine:
    - Valid transitions match spec/domain/04-STATES.md
    - Invalid transitions are rejected
    - State change events emitted correctly

CHECK-R06: Test coverage
  - Tests exist for each acceptance criterion
  - Tests exist for each exception flow
  - Tests pass currently
  - No tests are skipped or disabled
```

### Correctness Report Format

```markdown
## Correctness: {pass}/{total} checks pass

### TASK-F0-003: Create auth middleware
| Check | Criterion | Code Location | Status |
|-------|-----------|---------------|--------|
| R01-a | Extracts user from JWT | src/middleware/auth.ts:23 | PASS |
| R01-b | Returns 401 on invalid token | src/middleware/auth.ts:35 | PASS |
| R02 | Follows ADR-003 | src/middleware/auth.ts:12 | PASS |
| R04 | Enforces INV-SYS-003 | src/middleware/auth.ts:8 | PASS |
| R04 | Enforces INV-SYS-001 | src/middleware/auth.ts:28 | WARN: implicit, not explicit |
| R06 | Tests exist | tests/middleware/auth.test.ts | PASS (5 tests) |
```

---

## Dimension 3: Coherence

Verify implementation quality, consistency, and adherence to project conventions.

### Architecture Coherence

```
CHECK-H01: Project structure follows plan
  - Files placed in directories matching plan/ARCHITECTURE.md
  - No files in unexpected locations
  - Folder hierarchy makes logical sense

CHECK-H02: Dependency direction correct
  - Controllers depend on services (not reverse)
  - Services depend on repositories (not reverse)
  - Domain entities have no external dependencies
  - Layered architecture respected
```

### Naming Coherence

```
CHECK-H03: Ubiquitous language
  - Variable/function/class names use glossary terms
  - No legacy terminology (screening → selection, job → JobOffer, etc.)
  - Consistent naming across all files

CHECK-H04: Naming conventions
  - Files follow project convention (camelCase, kebab-case, etc.)
  - Functions follow convention
  - Types/interfaces follow convention
  - Constants follow convention
```

### Code Quality Coherence

```
CHECK-H05: Complexity limits
  - No function exceeds 50 lines
  - No file exceeds 500 lines
  - No deeply nested logic (>3 levels)
  - Cyclomatic complexity reasonable

CHECK-H06: Error handling consistency
  - All error handling follows same pattern
  - Error types are domain-specific (not generic)
  - Error messages are actionable
  - No swallowed errors (empty catch blocks)

CHECK-H07: Security hygiene
  - No hardcoded secrets or credentials
  - No PII in log statements
  - Input validation at system boundaries
  - SQL injection prevention (parameterized queries)
  - XSS prevention in output encoding
```

### Pattern Coherence

```
CHECK-H08: Design pattern consistency
  - Same pattern used for same problem across codebase
  - Repository pattern consistent across entities
  - Middleware pattern consistent across concerns
  - Event handling pattern consistent

CHECK-H09: Code duplication
  - No copy-paste duplication across files
  - Shared logic extracted to utilities
  - But: three similar lines better than premature abstraction
```

### Coherence Report Format

```markdown
## Coherence: {pass}/{total} checks, {observations} observations

### Architecture
- ✓ Project structure follows plan
- ✓ Dependency direction correct

### Naming
- ✓ Ubiquitous language used consistently
- ⚠ src/services/extraction.ts:12 uses "job" instead of "Extraction"

### Code Quality
- ✓ No function exceeds 50 lines
- ✓ No file exceeds 500 lines
- ✓ No hardcoded secrets

### Patterns
- ✓ Repository pattern consistent
- ⚠ Two different error handling approaches in auth vs extraction middleware
```

---

## Verification Severity Levels

| Severity | Symbol | Meaning | Action Required |
|----------|--------|---------|----------------|
| CRITICAL | ✗ | Missing implementation, broken tests, security issue | Must fix before proceeding |
| WARNING | ⚠ | Deviation from spec, inconsistency, missing edge case | Should fix, document if deferring |
| OBSERVATION | ○ | Style issue, potential improvement, minor inconsistency | Nice to fix, no action required |

### Severity Rules

```
IF task marked [x] but files don't exist → CRITICAL
IF acceptance criterion not satisfied → CRITICAL
IF invariant not enforced → CRITICAL
IF security issue (PII leak, no auth) → CRITICAL
IF contract schema mismatch → WARNING
IF glossary term violation → WARNING
IF complexity limit exceeded → WARNING
IF naming inconsistency → OBSERVATION
IF code duplication (< 5 lines) → OBSERVATION
```

---

## Full Verification Report Template

```markdown
# Verification Report: FASE-{N}

**Date:** {YYYY-MM-DD}
**Scope:** {N} tasks verified
**Verdict:** {PASS | PASS WITH WARNINGS | FAIL}

## Summary

| Dimension | Score | Critical | Warning | Observation |
|-----------|-------|----------|---------|-------------|
| Completeness | {X}/{Y} tasks | {N} | {N} | {N} |
| Correctness | {X}/{Y} checks | {N} | {N} | {N} |
| Coherence | {X}/{Y} checks | {N} | {N} | {N} |

## Critical Issues (must fix)
{list with file:line references}

## Warnings (should fix)
{list with file:line references}

## Observations (nice to fix)
{list}

## Recommendations
{prioritized list of actions}
```

---

## Graceful Degradation

Verification adapts to available context:

| Available Artifacts | Verification Scope |
|--------------------|-------------------|
| Only task/TASK-FASE-{N}.md | Completeness only (checkbox parsing) |
| + source code | Completeness + basic correctness (files exist) |
| + spec/ files | Full correctness (spec-implementation alignment) |
| + plan/ artifacts | Full coherence (architecture adherence) |
| + tests | Full verification with test execution |

Never skip verification because artifacts are missing — just narrow the scope.
