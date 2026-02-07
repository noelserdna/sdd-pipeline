---
name: sdd-test-planner
description: "Professional software test planning skill based on SWEBOK v4 Chapter 04 (Software Testing). Generates comprehensive test strategies, test matrices, and performance scenarios from specifications. Use this skill when: (1) Creating test plans from specifications, (2) Generating test matrices with input combinations and boundary values, (3) Defining test coverage targets per FASE, (4) Creating performance test scenarios from NFRs, (5) Auditing test coverage of existing specs. Triggers on phrases like 'test plan', 'test strategy', 'test matrix', 'performance tests', 'test coverage', 'plan de pruebas', 'estrategia de testing', 'cobertura de tests'."
version: "1.0.0"
---

# SDD Test Planner Skill

> **Principio:** Un plan de testing no es una lista de tests — es una estrategia que garantiza que cada requisito,
> cada invariante y cada contrato tiene verificación adecuada en el tipo, nivel y momento correcto.
> SWEBOK v4 Ch04: "Testing is the dynamic verification that a program provides expected behaviors."

## Purpose

Generate comprehensive test strategies, test matrices, and performance scenarios from specification documents. Bridge the gap between BDD scenarios (in `spec/tests/`) and actionable test tasks (in `task/`).

## When to Use This Skill

- Specifications exist in `spec/` and have been audited by `sdd-spec-auditor`
- You need a test strategy before generating implementation plans
- You want to define test coverage targets per FASE
- You need performance test scenarios derived from NFRs
- You want to audit test completeness of existing BDD specs
- You want to generate test matrices for complex use cases

## When NOT to Use This Skill

- To write or execute tests → use `sdd-task-implementer`
- To audit specs for quality → use `sdd-spec-auditor`
- To generate task files → use `sdd-task-generator`
- To create specs → use `sdd-specifications-engineer`

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-specifications-engineer` | **Upstream**: produces `spec/tests/BDD-*.md` and `spec/nfr/*.md` |
| `sdd-spec-auditor` | **Upstream**: validates spec quality before test planning |
| `sdd-security-auditor` | **Lateral**: security findings feed into security test scenarios |
| **`sdd-test-planner`** | **THIS SKILL**: produces test strategy and matrices |
| `sdd-plan-architect` | **Downstream**: consumes test strategy for FASE planning |
| `sdd-task-generator` | **Downstream**: consumes test matrices to generate test tasks |

### Pipeline Position

```
Requisitos → sdd-specifications-engineer → sdd-spec-auditor →
                                                    ↓
                                            sdd-test-planner ← YOU ARE HERE
                                                    ↓
                                             sdd-plan-architect
                                                    ↓
                                            sdd-task-generator
                                                    ↓
                                           sdd-task-implementer

Lateral: sdd-security-auditor → feeds security test scenarios
```

> **SWEBOK v4 alignment:**
> - Ch04 §1: Testing Fundamentals (levels, types, techniques)
> - Ch04 §2: Test Process (planning, design, execution, evaluation)
> - Ch04 §3: Test Techniques (black-box, white-box, experience-based)
> - Ch04 §4: Test Measurement (coverage, defect metrics)
> - Ch04 §5: Test Management (planning, estimation, monitoring)

---

## Modes of Operation

### Mode 1: Generate Test Strategy

Use when the user wants a comprehensive test plan for the project.

**Readiness Gates:**
- G1: `spec/` directory exists with at least `domain/`, `use-cases/`, `contracts/`
- G2: `spec/tests/BDD-*.md` files exist (at least partially)
- G3: `spec/nfr/*.md` files exist (at least PERFORMANCE.md)

**Process:**

1. **Read all specification documents:**
   - `spec/use-cases/UC-*.md` → extract main flows, exception flows, actors
   - `spec/tests/BDD-*.md` → extract existing BDD scenarios
   - `spec/nfr/PERFORMANCE.md` → extract performance targets
   - `spec/nfr/SECURITY.md` → extract security requirements
   - `spec/nfr/LIMITS.md` → extract rate limits and thresholds
   - `spec/domain/05-INVARIANTS.md` → extract all invariants
   - `spec/contracts/API-*.md` → extract endpoint contracts
   - `spec/contracts/EVENTS-*.md` → extract event schemas
   - `audits/SECURITY-AUDIT-BASELINE.md` → extract security findings (if exists)

2. **Classify test types needed per spec element:**

   | Spec Element | Test Types | Level |
   |-------------|------------|-------|
   | Entity invariants (INV-*) | Unit tests (property-based) | Unit |
   | UC main flows | BDD scenarios (Given/When/Then) | Integration |
   | UC exception flows | Negative BDD scenarios | Integration |
   | API contracts | Contract tests (request/response schema) | Integration |
   | Event schemas | Event contract tests (schema validation) | Integration |
   | Workflows (WF-*) | End-to-end scenarios | E2E |
   | NFR Performance | Load tests, stress tests | Performance |
   | NFR Security | Penetration tests, auth bypass tests | Security |
   | NFR Limits | Rate limit tests, quota enforcement | Integration |
   | Cross-UC flows | Saga/choreography tests | E2E |

3. **Identify gaps in existing BDD specs:**
   - UCs without BDD file → flag as `MISSING-BDD`
   - UCs with BDD but missing exception flows → flag as `INCOMPLETE-BDD`
   - Invariants without property tests → flag as `MISSING-PROPERTY-TEST`
   - NFRs without measurable test scenarios → flag as `MISSING-NFR-TEST`

4. **Define coverage targets per FASE:**
   - Ask user for overall coverage target (recommend 80% minimum)
   - Map test types to FASEs using `plan/fases/FASE-*.md` (if exists)
   - If plan doesn't exist yet, group by bounded context

5. **Generate `test/TEST-PLAN.md`:**

```markdown
# Test Plan

> **Project:** {project name}
> **Version:** {X.Y}
> **Generated from:** spec/ (audit-clean)
> **SWEBOK alignment:** Ch04 — Software Testing

## Test Strategy Summary

| Metric | Target | Current |
|--------|--------|---------|
| BDD scenario coverage (UCs) | 100% of main + exception flows | {N}% |
| Invariant test coverage | 100% of INV-* | {N}% |
| Contract test coverage | 100% of API endpoints | {N}% |
| NFR test coverage | 100% of measurable NFRs | {N}% |
| Security test coverage | 100% of OWASP Top 10 applicable | {N}% |

## Test Levels

### Unit Tests
- **Scope:** Entity invariants, value object validation, pure business logic
- **Technique:** Property-based testing for invariants, example-based for logic
- **Framework:** {recommend based on tech stack or ask user}
- **Coverage target:** {N}% line coverage on domain layer

### Integration Tests
- **Scope:** UC flows via API endpoints, event handling, database operations
- **Technique:** BDD scenarios (Given/When/Then), contract testing
- **Data:** Test fixtures derived from spec entity schemas
- **Coverage target:** 100% of UC main flows, {N}% of exception flows

### End-to-End Tests
- **Scope:** Multi-UC workflows, cross-service flows
- **Technique:** Scenario-based testing following WF-* specs
- **Environment:** Staging environment with test data
- **Coverage target:** 100% of WF-* workflows

### Performance Tests
- **Scope:** Response time (p99), throughput, concurrent users
- **Technique:** Load testing, stress testing, soak testing
- **Targets:** From spec/nfr/PERFORMANCE.md
- **Schedule:** Run on every FASE completion

### Security Tests
- **Scope:** Authentication bypass, authorization escalation, injection, data exposure
- **Technique:** OWASP ASVS v4 checklist + automated scanning
- **Targets:** From spec/nfr/SECURITY.md + security audit findings

## Test Gaps Identified

| Gap ID | Type | Spec Element | Missing Test | Priority |
|--------|------|-------------|--------------|----------|
| GAP-001 | MISSING-BDD | UC-{NNN} | No BDD file exists | High |
| GAP-002 | INCOMPLETE-BDD | UC-{NNN} | Exception flow {N} not covered | Medium |
| GAP-003 | MISSING-PROPERTY-TEST | INV-{PREFIX}-{NNN} | No property test defined | Medium |
| GAP-004 | MISSING-NFR-TEST | PERFORMANCE p99 target | No load test scenario | High |

## Per-FASE Test Targets

| FASE | Unit Tests | Integration Tests | E2E Tests | Perf Tests |
|------|-----------|-------------------|-----------|------------|
| FASE-0 | INV-SYS-* | Auth flows | Health check | Baseline |
| FASE-1 | INV-{PREFIX}-* | UC-{NNN} flows | WF-{NNN} | Load targets |
| ... | ... | ... | ... | ... |

## Regression Strategy

- **On every commit:** Unit tests + affected integration tests
- **On FASE completion:** Full integration + E2E suite
- **On release candidate:** Full suite + performance + security
```

---

### Mode 2: Generate Test Matrices

Use when the user wants detailed input/output matrices for complex use cases.

**Process:**

1. **Read target UC spec** (`spec/use-cases/UC-NNN-*.md`)
2. **Extract inputs:** All parameters, preconditions, actor roles
3. **Apply test design techniques** (SWEBOK v4 Ch04 §3):

   **a. Equivalence Partitioning:**
   - For each input, identify valid and invalid partitions
   - Select one representative value per partition

   **b. Boundary Value Analysis:**
   - For each numeric/range input, identify boundary values
   - Include: min-1, min, min+1, max-1, max, max+1

   **c. Decision Table:**
   - For UCs with multiple conditions, build condition/action table
   - Each row = one test case

   **d. State Transition:**
   - For entities with state machines (`spec/domain/04-STATES.md`)
   - Generate tests for each valid transition AND each invalid transition

4. **Generate `test/TEST-MATRIX-UC-{NNN}.md`:**

```markdown
# Test Matrix: UC-{NNN} — {title}

## Inputs

| Input | Type | Valid Partitions | Invalid Partitions | Boundaries |
|-------|------|------------------|--------------------|------------|
| {param} | {type} | {valid ranges} | {invalid values} | {boundary values} |

## Decision Table

| # | Cond1 | Cond2 | Cond3 | Expected Action | Expected Status |
|---|-------|-------|-------|-----------------|-----------------|
| T1 | true | true | true | {action} | {status} |
| T2 | true | true | false | {action} | {status} |
| ... | | | | | |

## State Transition Tests (if applicable)

| Current State | Event | Expected Next State | Postconditions |
|---------------|-------|---------------------|----------------|
| {state} | {event} | {next_state} | {postconditions} |
| {state} | {invalid_event} | {same_state} | Error: {message} |

## Traceability

| Test Case | Covers | Spec Ref |
|-----------|--------|----------|
| T1 | Main flow step 3 | UC-{NNN} §main.3 |
| T2 | Exception flow 1 | UC-{NNN} §exception.1 |
```

---

### Mode 3: Generate Performance Scenarios

Use when the user needs performance test scenarios derived from NFR specs.

**Process:**

1. **Read NFR documents:**
   - `spec/nfr/PERFORMANCE.md` → response time targets, throughput
   - `spec/nfr/LIMITS.md` → rate limits, quotas, thresholds
   - `spec/contracts/API-*.md` → endpoint patterns and expected load

2. **Generate scenarios per NFR target:**

   | Scenario Type | Purpose | Duration |
   |---------------|---------|----------|
   | **Smoke** | Verify baseline functionality under minimal load | 1 min |
   | **Load** | Verify p99 targets under expected concurrent users | 10 min |
   | **Stress** | Find breaking point beyond expected load | 15 min |
   | **Soak** | Detect memory leaks under sustained load | 1 hour |
   | **Spike** | Verify recovery from sudden traffic bursts | 5 min |

3. **Generate `test/PERF-SCENARIOS.md`:**

```markdown
# Performance Test Scenarios

> Derived from: spec/nfr/PERFORMANCE.md, spec/nfr/LIMITS.md

## Targets (from specs)

| Metric | Target | Source |
|--------|--------|--------|
| API response time (p99) | < {N}ms | PERFORMANCE.md |
| Throughput | {N} req/s | PERFORMANCE.md |
| Concurrent users | {N} | PERFORMANCE.md |
| Rate limit (per user) | {N} req/min | LIMITS.md |

## Scenarios

### PERF-001: API Load Test
- **Type:** Load
- **Target endpoint:** {most critical endpoint from contracts}
- **Concurrent users:** {from NFR}
- **Duration:** 10 minutes
- **Success criteria:** p99 < {target}ms, 0% error rate
- **Ramp-up:** Linear over 2 minutes

### PERF-002: Rate Limit Enforcement
- **Type:** Stress
- **Target:** Rate limit threshold
- **Method:** Single user exceeding {N} req/min
- **Success criteria:** 429 returned after limit, Retry-After header present

### PERF-003: Database Query Performance
- **Type:** Load
- **Target:** Queries with complex joins or full-text search
- **Dataset:** {N} records (10x expected production size)
- **Success criteria:** p99 < {target}ms
```

---

### Mode 4: Audit Test Coverage

Use when the user wants to verify that existing test specs are complete.

**Process:**

1. **Build traceability matrix:**
   - List ALL UCs, invariants, contracts, workflows, NFRs
   - For each, check if a corresponding test exists in `spec/tests/`

2. **Compute coverage metrics:**

   | Dimension | Formula | Target |
   |-----------|---------|--------|
   | UC Coverage | UCs with BDD / total UCs | 100% |
   | Exception Coverage | Exception flows tested / total exception flows | ≥ 80% |
   | Invariant Coverage | INVs with property tests / total INVs | 100% |
   | Contract Coverage | Endpoints with contract tests / total endpoints | 100% |
   | NFR Coverage | Measurable NFRs with test scenarios / total measurable NFRs | 100% |

3. **Output coverage report with gaps and recommendations**

---

## Key Principles

### Test Independence
Each test must be independent — no shared mutable state, no execution order dependency. SWEBOK v4 Ch04 §1.

### Traceability
Every test traces to a spec element (UC, INV, NFR, API contract). No test exists without a spec justification. No spec element exists without a test.

### Risk-Based Prioritization
Not all tests are equal. Prioritize by:
1. **Business criticality** of the UC
2. **Failure impact** (data loss > UX issue)
3. **Probability of defect** (complex logic > simple CRUD)

### Shift-Left Testing
Test planning happens at spec time, not at implementation time. This skill exists precisely to move testing left in the pipeline.

---

## Pipeline Integration

This skill is **Step 3.5** of the SDD pipeline (between spec-auditor and plan-architect):

```
sdd-requirements-engineer → requirements/REQUIREMENTS.md
        ↓
sdd-specifications-engineer → spec/
        ↓
sdd-spec-auditor → audits/AUDIT-BASELINE.md
        ↓
sdd-test-planner → test/TEST-PLAN.md, test/TEST-MATRIX-*.md, test/PERF-SCENARIOS.md (THIS SKILL)
        ↓
sdd-plan-architect → plan/
        ↓
sdd-task-generator → task/ (includes test tasks from test plan)
        ↓
sdd-task-implementer → src/, tests/
```

**Input:** `spec/` (audit-clean), optionally `audits/SECURITY-AUDIT-BASELINE.md`
**Output:** `test/TEST-PLAN.md`, `test/TEST-MATRIX-UC-*.md`, `test/PERF-SCENARIOS.md`
**Next step:** Run `sdd-plan-architect` which reads test strategy for FASE planning

## Output Language

Respond in the same language the user uses. If the user writes in Spanish, respond in Spanish. If in English, respond in English.
