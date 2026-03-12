---
name: sdd-test-planner
description: "Professional software test planning skill based on SWEBOK v4 Chapter 04 (Software Testing). Generates comprehensive test strategies, test matrices, performance scenarios, and E2E acceptance scenarios from specifications. Use this skill when: (1) Creating test plans from specifications, (2) Generating test matrices with input combinations and boundary values, (3) Defining test coverage targets per FASE, (4) Creating performance test scenarios from NFRs, (5) Auditing test coverage of existing specs, (6) Generating E2E acceptance scenarios from workflows. Triggers on phrases like 'test plan', 'test strategy', 'test matrix', 'performance tests', 'test coverage', 'e2e scenarios', 'end to end', 'acceptance tests', 'playwright', 'plan de pruebas', 'estrategia de testing', 'cobertura de tests', 'tests e2e', 'tests de aceptacion'."
version: "2.0.0"
---

# SDD Test Planner Skill

> **Principio:** Un plan de testing no es una lista de tests — es una estrategia que garantiza que cada requisito,
> cada invariante y cada contrato tiene verificación adecuada en el tipo, nivel y momento correcto.
> SWEBOK v4 Ch04: "Testing is the dynamic verification that a program provides expected behaviors."

## Purpose

Generate comprehensive test strategies, test matrices, performance scenarios, and E2E acceptance scenarios from specification documents. Bridge the gap between BDD scenarios (in `spec/tests/`) and actionable test tasks (in `task/`), including end-to-end user journey validation.

## When to Use This Skill

- Specifications exist in `spec/` and have been audited by `sdd-spec-auditor`
- You need a test strategy before generating implementation plans
- You want to define test coverage targets per FASE
- You need performance test scenarios derived from NFRs
- You want to audit test completeness of existing BDD specs
- You want to generate test matrices for complex use cases
- You need E2E acceptance scenarios derived from workflows (WF-*)

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
| `sdd-ux-designer` | **Lateral (optional)**: enriches E2E scenarios with page objects and a11y assertions |
| **`sdd-test-planner`** | **THIS SKILL**: produces test strategy, matrices, and E2E scenarios |
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
Lateral: sdd-ux-designer → enriches E2E scenarios (optional)
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
   - WFs without E2E scenarios → flag as `MISSING-E2E` (addressed by Mode 5)

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
| E2E workflow coverage | 100% of user-facing WF-* | {N}% |

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
- **Scope:** Multi-UC workflows, cross-service user journeys
- **Technique:** Scenario-based testing following WF-* specs (see `test/E2E-SCENARIOS.md` if Mode 5 was run)
- **Framework:** Playwright recommended (browser), APIRequestContext (API-only), subprocess (CLI)
- **Environment:** Staging environment with test data, isolated browser contexts
- **Data strategy:** {transaction-rollback | snapshot-restore | unique-per-test}
- **Accessibility:** axe-core scan at each navigation step (WCAG 2.1 AA)
- **Coverage target:** 100% of user-facing WF-* workflows
- **Tiered execution:**
  - Smoke (P0 happy paths): every PR, < 2 min
  - Critical (P0+P1): every merge to main, < 10 min
  - Full E2E suite: nightly / release, < 30 min

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
| GAP-005 | MISSING-E2E | WF-{NNN} | No E2E scenario for user-facing workflow | High |

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
   | E2E Coverage | User-facing WFs with E2E scenarios / total user-facing WFs | 100% |

3. **Output coverage report with gaps and recommendations**

---

### Mode 5: Generate E2E Acceptance Scenarios

Use when the user needs end-to-end acceptance test scenarios that validate complete user journeys through the system. Produces actionable scenarios traceable from workflows back to requirements.

**Readiness Gates:**
- G1: `spec/workflows/WF-*.md` files exist (at least one)
- G2: `spec/use-cases/UC-*.md` files exist
- G3: `spec/tests/BDD-*.md` files exist (at least partially)

**Process:**

1. **Detect project type:**

   ```
   IF ux/ directory exists AND ux/WIREFRAMES.md is present:
     → project_type = WEB-APP (full browser E2E with page objects)
   ELIF spec/contracts/API-*.md exists AND no ux/:
     → project_type = API-ONLY (API E2E via HTTP, no browser)
   ELIF project is CLI tool (detected from plan/ARCHITECTURE.md or CLAUDE.md):
     → project_type = CLI (subprocess E2E)
   ELSE:
     → project_type = LIBRARY (skip E2E, document exemption)
   ```

   If `project_type = LIBRARY`, output a note in TEST-PLAN.md explaining E2E exemption and stop.

2. **Read workflow and spec artifacts:**
   - `spec/workflows/WF-*.md` → extract user journeys, steps, actors, cross-UC flows
   - `spec/use-cases/UC-*.md` → extract main flows, exception flows, parameters
   - `spec/tests/BDD-*.md` → extract existing acceptance criteria (reuse, don't duplicate)
   - `spec/contracts/API-*.md` → extract endpoints involved in each workflow
   - `requirements/REQUIREMENTS.md` → build transitive REQ→UC→WF mapping for traceability

3. **Read UX artifacts (if `project_type = WEB-APP` and `ux/` exists):**
   - `ux/WIREFRAMES.md` → extract component inventory, interactive elements per screen
   - `ux/INTERACTION-MODEL.md` → extract state diagrams, loading states, error states
   - `ux/ACCESSIBILITY-SPEC.md` → extract keyboard navigation matrix, ARIA mappings

4. **Generate E2E scenarios per workflow:**

   For each WF-* that involves user interaction:
   - **Happy path scenario:** Walk the entire workflow from trigger to completion
   - **Error variations:** One row per exception flow in the constituent UCs (use variation table, not separate scenarios)
   - **Element references:** Inline the UI elements needed with role-based locator hints (when UX artifacts exist)
   - **Accessibility gate:** Include axe-core scan assertion at each major navigation step

5. **Build transitive coverage matrix:**

   Map each E2E scenario back to the REQs it covers transitively:
   ```
   E2E-WF-001-01 → WF-001 → {UC-003, UC-004} → {REQ-FUNC-010, REQ-FUNC-011}
   ```

   For REQs not covered by any E2E scenario, classify as:
   - `EXEMPT-BACKEND`: Internal/infrastructure REQ, no user-facing flow
   - `EXEMPT-NFR`: Non-functional REQ, covered by performance/security tests
   - `GAP`: User-facing REQ with no transitive E2E coverage → flag for review

6. **Generate `test/E2E-SCENARIOS.md`:**

```markdown
# E2E Acceptance Scenarios

> **Project:** {project name}
> **Project type:** {WEB-APP | API-ONLY | CLI}
> **Generated from:** spec/workflows/, spec/use-cases/
> **UX enrichment:** {Yes — from ux/ | No — abstract scenarios}

## E2E Strategy

| Dimension | Value |
|-----------|-------|
| Framework | Playwright (recommended) |
| Selector strategy | getByRole > getByLabel > getByText > getByTestId (fallback) |
| Auth strategy | storageState reuse (1 login test, others reuse state) |
| Data strategy | {transaction-rollback | snapshot-restore | unique-per-test} |
| Accessibility | axe-core scan at each navigation (WCAG 2.1 AA) |
| Parallelism | Playwright sharding across {N} workers |

### Tiered Execution

| Tier | Scenarios | Run time | Trigger |
|------|-----------|----------|---------|
| Smoke | P0 happy paths only | < 2 min | Every PR |
| Critical | P0 + P1 paths | < 10 min | Every merge to main |
| Full | All E2E scenarios | < 30 min | Nightly / release |

### Viewport Matrix (WEB-APP only, derived from ux/DESIGN-TOKENS.json)

| Viewport | Width | Run |
|----------|-------|-----|
| Mobile | 375px | P0 + P1 scenarios |
| Desktop | 1280px | All scenarios |

---

## Scenarios

### E2E-WF-{NNN}-01: {Workflow title} — Happy Path

- **Workflow:** WF-{NNN}
- **Use Cases:** UC-{NNN}, UC-{NNN}
- **Requirements (transitive):** REQ-FUNC-{NNN}, REQ-FUNC-{NNN}
- **Priority:** P{0|1|2}
- **Tier:** {smoke | critical | full}
- **Auth fixture:** {authenticated | admin | unauthenticated}

#### Elements Referenced (when ux/ exists)

| Element | Locator hint | Source |
|---------|-------------|--------|
| {name} | getByRole("{role}", { name: /{pattern}/i }) | WIREFRAMES §{screen} |
| {name} | getByLabel("{label}") | WIREFRAMES §{screen} |

#### Steps

| # | Action | Target | Assertion | Spec Ref |
|---|--------|--------|-----------|----------|
| 1 | Navigate to {url} | — | Page title = "{title}" | WF-{NNN} step 1 |
| 2 | axe-core scan | full page | No violations | ACCESSIBILITY-SPEC |
| 3 | Fill {field} | {element} | Field accepts input | UC-{NNN} §main.2 |
| 4 | Click {button} | {element} | {expected feedback} | UC-{NNN} §main.3 |
| 5 | Wait for {condition} | — | {assertion} | INTERACTION-MODEL §{state} |
| 6 | Assert final state | — | {postcondition} | WF-{NNN} postcondition |

#### Error Variations

| Variant ID | Diverges at step | Input change | Expected behavior | Spec Ref |
|------------|------------------|-------------|-------------------|----------|
| E2E-WF-{NNN}-02 | Step 3 | {invalid input} | Error: "{message}" | UC-{NNN} §exception.1 |
| E2E-WF-{NNN}-03 | Step 4 | {precondition not met} | Redirect to {page} | UC-{NNN} §exception.2 |

---

## Scenarios for API-ONLY projects

### E2E-API-{NNN}-01: {Workflow title} — Happy Path

- **Workflow:** WF-{NNN}
- **Use Cases:** UC-{NNN}, UC-{NNN}
- **Type:** API E2E (no browser)

#### Steps

| # | Method | Endpoint | Body/Params | Assert status | Assert body | Spec Ref |
|---|--------|----------|-------------|---------------|-------------|----------|
| 1 | POST | /api/{resource} | {payload} | 201 | {schema} | API-{NNN} |
| 2 | GET | /api/{resource}/{id} | — | 200 | status = "{expected}" | API-{NNN} |

---

## Coverage Matrix

| REQ ID | Type | E2E Coverage | Justification if excluded |
|--------|------|-------------|---------------------------|
| REQ-FUNC-{NNN} | UI-func | E2E-WF-{NNN}-01 | — |
| REQ-FUNC-{NNN} | API-only | — | EXEMPT-BACKEND: no user-facing flow |
| REQ-NFR-{NNN} | Perf | — | EXEMPT-NFR: covered by PERF-SCENARIOS.md |
| REQ-FUNC-{NNN} | UI-func | — | GAP: needs WF or E2E scenario |
```

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
sdd-test-planner → test/TEST-PLAN.md, test/TEST-MATRIX-*.md, test/PERF-SCENARIOS.md, test/E2E-SCENARIOS.md (THIS SKILL)
        ↓
sdd-plan-architect → plan/
        ↓
sdd-task-generator → task/ (includes test tasks from test plan)
        ↓
sdd-task-implementer → src/, tests/
```

**Input:** `spec/` (audit-clean), optionally `audits/SECURITY-AUDIT-BASELINE.md`, optionally `ux/` (enriches E2E scenarios)
**Output:** `test/TEST-PLAN.md`, `test/TEST-MATRIX-UC-*.md`, `test/PERF-SCENARIOS.md`, `test/E2E-SCENARIOS.md`
**Next step:** Run `sdd-plan-architect` which reads test strategy for FASE planning

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["test-planner"].status` = `"done"`
3. Set `stages["test-planner"].lastRun` = current ISO-8601
4. Set `stages["test-planner"].summary`:
   - `artifacts`: list of files created in `test/` with labels (e.g., `{"file": "test/TEST-PLAN.md", "label": "Test Strategy"}`)
   - `metrics`: `{ "bdd_scenarios": N, "test_matrices": N, "perf_scenarios": N, "e2e_scenarios": N, "invariants_mapped": N, "test_gaps": N }`
   - `highlights`: top 3-5 notable observations (e.g., "101 BDD scenarios cover 85% of requirements", "3 gaps in NFR testing")
   - `nextStep`: `"Run /sdd-plan-architect"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)

## Output Language

Respond in the same language the user uses. If the user writes in Spanish, respond in Spanish. If in English, respond in English.
