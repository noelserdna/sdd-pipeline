---
name: sdd-test-planner
description: "Test planning per SWEBOK v4: strategy, matrices, coverage per FASE, performance (NFRs) and E2E acceptance scenarios. Triggers: 'test plan', 'test strategy', 'test matrix', 'performance tests', 'test coverage', 'e2e scenarios', 'acceptance tests', 'playwright', 'plan de pruebas', 'estrategia de testing', 'cobertura de tests', 'tests de aceptacion'."
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

## Reading Strategy (index first)

Generation time is dominated by output tokens; reading the whole corpus only adds cache and turns (see `docs/perfilado.md`). Never `cat` the whole `spec/` tree. Build an index, then open only the sections a mode needs.

1. **Index** — one command (~2-4 k chars for a 10-requirement project):
   ```bash
   grep -rn -E '^#{1,4} |^\| *(UC|WF|INV|API|AC|PROP|RN|REQ|SPEC|SEC|SLO)-[A-Z0-9-]+ *\|' spec/ requirements/ 2>/dev/null | cut -c1-160
   ```
   Every heading and every id-bearing table row with `file:line`. Add `plan/fases/FASE-*.md` (per-FASE targets) and `audits/SECURITY-AUDIT-BASELINE.md` (finding ids) when they exist.
2. **Open by section** with `sed -n 'A,Bp' file` from the line numbers of the index:

   | Need | Open only |
   |------|-----------|
   | Levels, gaps (Mode 1) | UC acceptance-criteria / exception-flow blocks; BDD scenario titles; `spec/nfr/*` target rows; INV table (id + one line) |
   | Matrix for UC-NNN (Mode 2) | the UC's inputs/parameters table, main and exception flow steps, its BDD file, the contract section of its endpoint/function (`grep -n 'UC-NNN' spec/contracts/`), its state machine in `04-STATES.md` |
   | PERF (Mode 3) | rows with a number and a unit in `PERFORMANCE.md` / `LIMITS.md` (`grep -n -E '[0-9]+ *(ms|s|req|MB|%)'`) |
   | E2E (Mode 5) | WF step lists, UC input-parameter tables, contract request-body tables, `ux/WIREFRAMES.md` interactive elements |

   Never open `01-GLOSSARY.md`, ADR bodies, runbooks or `CLARIFICATIONS.md` in full: grep the id you cite (`grep -n -A3 'RN-007' spec/CLARIFICATIONS.md`).
3. If the `sdd_context` / `sdd_query` MCP tools are available (index built by `sdd-dashboard`), use them for id lookups instead of grep.

## Output Budget

Indicative for a ~10-requirement project (7 UC, 1-2 WF); scale with UC/WF count, never with prose.

| File | Budget (chars) | What stays out |
|------|----------------|----------------|
| `TEST-PLAN.md` | ≤ 12 000 | prose that restates a table; per-test assertions (they live in matrices / E2E); N/A sections longer than one row |
| `TEST-MATRIX-UC-NNN.md` | ≤ 5 000 (≤ 8 000 with a state machine) | UC description, restated contract, exhaustive mechanical enumerations, a trailing Traceability section (the `Refs` column is the traceability) |
| `PERF-SCENARIOS.md` | ≤ 4 000 | scenario types no NFR quantifies; harness prose |
| `E2E-SCENARIOS.md` | ≤ 15 000 (+3 000 per extra user-facing WF) | Full-tier scenarios as step tables; boundary rows already in a matrix |
| **Total `test/`** | **≤ 65 000** | |

Report the total as `metrics.test_chars` (`wc -c test/*.md`) in Persist Summary and add a highlight when a file exceeds its budget by more than 25 %.

## Full Run Order

1. Gates → index `spec/` (Reading Strategy).
2. Mode 1 `TEST-PLAN.md` in the main thread; write §3 Design Decisions first — it is the convention contract the matrix subagents must not repeat.
3. Mode 2 matrices: fan-out to subagents (see Mode 2). They run in the background.
4. Mode 3 `PERF-SCENARIOS.md` and Mode 5 `E2E-SCENARIOS.md` in the main thread while the agents run (Mode 5 owns the field-inventory cross-validation, which may STOP).
5. Consolidate: agent summaries → TEST-PLAN §4 gaps / §10 metrics; Persist Summary; Handoff.

---

## Modes of Operation

### Mode 1: Generate Test Strategy

Use when the user wants a comprehensive test plan for the project.

**Readiness Gates:**
- G1: `spec/` directory exists with at least `domain/`, `use-cases/`, `contracts/`
- G2: `spec/tests/BDD-*.md` files exist (at least partially)
- G3: `spec/nfr/*.md` files exist (at least PERFORMANCE.md)

**Process:**

1. **Index, then open sections** (Reading Strategy). From the index, without opening whole files:
   - UC ids, titles, actors, exception-flow headings (`grep -n -E '^#|Exception|Excepci' spec/use-cases/UC-*.md`)
   - BDD scenario titles per UC (`grep -n -E '^ *(Scenario|Escenario)' spec/tests/BDD-*.md`) → main/exception flow coverage
   - INV ids + one line (`grep -n -E '^\| *INV-' spec/domain/05-INVARIANTS.md`); PROP ids in `spec/tests/PROPERTY-TESTS.md`
   - Quantified NFR rows (`grep -n -E '[0-9]+ *(ms|s|req|MB|%|users)' spec/nfr/*.md`); security control ids (`SEC-*`)
   - Contract endpoint/function ids (`grep -n -E '^\| *API-|^### ' spec/contracts/API-*.md`); event names in `EVENTS-*.md`
   - `audits/SECURITY-AUDIT-BASELINE.md` finding ids (if exists)

   Open a section only when the id line is not enough (e.g. an exception flow whose BDD coverage is unclear).

2. **Classify test types needed per spec element** (keep only the rows present in this project when writing the plan):

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
   - UCs without BDD file → `MISSING-BDD`
   - UCs with BDD but missing exception flows → `INCOMPLETE-BDD`
   - Invariants without property tests → `MISSING-PROPERTY-TEST`
   - Quantified NFRs without a scenario → `MISSING-NFR-TEST`
   - User-facing WFs without E2E scenarios → `MISSING-E2E` (addressed by Mode 5)

4. **Define coverage targets per FASE:**
   - Ask user for overall coverage target (recommend 80% minimum)
   - Map test types to FASEs using `plan/fases/FASE-*.md` (if exists); otherwise group by bounded context and mark the table as a proposal

5. **Write `test/TEST-PLAN.md`** with the template below. Tables, not prose; every row carries ids; budget ≤ 12 000 chars. Write §3 before launching matrix subagents.

```markdown
# Test Plan — {project}

> Spec v{X.Y} (audit-clean) · SWEBOK v4 Ch04 · Project type: {WEB-APP | API-ONLY | CLI | LIBRARY}
> Companion files: TEST-MATRIX-UC-*.md ({N}), PERF-SCENARIOS.md, E2E-SCENARIOS.md

## 1. Strategy Summary

| Dimension | Target | Current | Source |
|-----------|--------|---------|--------|
| UC main + exception flows with BDD | 100% | {N}% | spec/tests/ |
| Invariants with property tests | 100% of INV-* | {N}% | domain/05-INVARIANTS.md |
| Contract endpoints/functions with contract tests | 100% | {N}% | spec/contracts/ |
| Quantified NFRs with a scenario | 100% | {N}% | spec/nfr/ |
| Applicable security controls | 100% | {N}% | nfr/SECURITY.md, audits/ |
| User-facing WF-* with E2E | 100% | {N}% | spec/workflows/ |

## 2. Test Levels

| Level | Scope (spec elements) | Technique | Framework / runner | Coverage target | Runs on |
|-------|----------------------|-----------|--------------------|-----------------|---------|
| Unit | INV-*, VO-*, pure logic | property-based + examples | {framework} | {N}% line, domain layer | every commit |
| Integration | UC flows, contracts, events, persistence | BDD (Given/When/Then), contract tests | {framework}; fixtures from entity schemas | 100% main flows, {N}% exception flows | every commit |
| E2E | user-facing WF-* (E2E-SCENARIOS.md) | tiered scenarios Smoke / Critical / Full | {Playwright | APIRequestContext | subprocess}; isolated contexts; axe-core when WEB-APP | 100% user-facing WF | PR / main / nightly |
| Performance | quantified NFRs (PERF-SCENARIOS.md) | latency sampling, load | {tool} | every quantified target | FASE completion |
| Security | nfr/SECURITY.md controls + audit findings | OWASP ASVS v4 checklist, error guessing | {tool} | applicable controls | release candidate |

A level that does not apply keeps its row with a one-line reason (e.g. "E2E — LIBRARY project, exempt").

## 3. Design Decisions

One row per decision the implementer needs (clock injection, I/O fault injection, isolation and determinism, platform skips, fixtures, error-precedence rules). No prose; ≤ 160 chars per decision.

| ID | Decision | Applies to | Refs |
|----|----------|------------|------|
| D-T-001 | {decision} | {levels / test ids} | {SPEC/INV/ADR/RN ids} |

## 4. Gaps

| Gap ID | Type | Spec element | Missing (≤ 100 chars) | Priority |
|--------|------|--------------|------------------------|----------|
| GAP-001 | MISSING-BDD | UC-{NNN} | No BDD file | High |
| GAP-002 | INCOMPLETE-BDD | UC-{NNN} | Exception flow {N} not covered | Medium |
| GAP-003 | MISSING-PROPERTY-TEST | INV-{PREFIX}-{NNN} | No property test | Medium |
| GAP-004 | MISSING-NFR-TEST | SPEC-PERF-{NNN} | No scenario for the p99 target | High |
| GAP-005 | MISSING-E2E | WF-{NNN} | No E2E for user-facing workflow | High |

## 5. Per-FASE Targets

| FASE | Unit | Integration | E2E | Perf |
|------|------|-------------|-----|------|
| FASE-{N} | {INV/PROP ids} | {UC ids} | {tier or E2E ids} | {PERF ids} |

## 6. Traceability REQ → tests

| REQ | UC / WF | Matrix rows | E2E | Perf / Sec |
|-----|---------|-------------|-----|------------|
| REQ-{ID} | UC-{NNN} | TEST-MATRIX-UC-{NNN} T01..T09 | E2E-WF-{NNN}-01, V01 | PERF-001 |

## 7. Cross-cutting Test IDs

Only tests that belong to no single UC matrix or E2E scenario (integration harness, security, maintainability/meta). One line each; the detailed assertion lives in the matrix or scenario that uses it.

| ID | Object | Verifies (≤ 120 chars) | Refs |
|----|--------|-------------------------|------|
| INT-T-001 | {function/module} | {assertion} | {ids} |
| SEC-T-001 | {control} | {assertion} | SEC-{NNN}, CWE-{NNN} |
| MNT-T-001 | {meta check} | {assertion} | SPEC-MNT-{NNN} |

## 8. Regression Policy

| Trigger | Runs |
|---------|------|
| every commit | unit + affected integration |
| FASE completion | full integration + E2E Critical |
| release candidate | full suite + performance + security |

## 9. Inputs for sdd-plan-architect

Design requirements the plan must honour (injection points, module boundaries, test locations). One row each.

| ID | Requirement (≤ 140 chars) | Needed by | Refs |
|----|----------------------------|-----------|------|
| R-1 | {requirement} | {test ids} | {ids} |

## 10. Metrics

| Metric | Value |
|--------|-------|
| Matrices / cases | {N} / {N} |
| E2E scenarios Smoke / Critical / Full | {N} / {N} / {N} |
| PERF scenarios | {N} |
| Gaps | {N} |
| Chars: this file / test/ total | {N} / {N} |
```

---

### Mode 2: Generate Test Matrices

Use when the user wants detailed input/output matrices for use cases.

**Scope:** If the user does not specify a UC, generate matrices for ALL use cases in `spec/use-cases/`. One file per UC: `test/TEST-MATRIX-UC-NNN.md`.

**Fan-out (default when there are more than 3 UCs):** matrices are mechanical and independent, so generate them in parallel subagents with a fast model; the main thread keeps TEST-PLAN, PERF and E2E.

1. Group UCs 2-3 per agent, by shared entity or contract, so each agent reads a contract once.
2. Launch all groups in ONE message with the `Agent` tool. Pass `model: sonnet` unless the environment variable `CLAUDE_CODE_SUBAGENT_MODEL` is set — then omit `model` and let the environment decide. Do not use `subagent_type: "fork"`: a fresh agent with a small context is the point.
3. Agent prompt (fill the braces; paste the step-4 template verbatim):

   ```
   You generate test matrices for the SDD pipeline (sdd-test-planner Mode 2). Write in {project language}.
   Read ONLY (grep -n for ids first, then sed -n the sections):
   - spec/use-cases/{UC files}: inputs/parameters, main and exception flows, acceptance criteria
   - spec/tests/{BDD files}: scenario titles and AC ids
   - spec/contracts/{contract file}: only the sections of these UCs (grep -n 'UC-{NNN}\|{function}')
   - spec/domain/04-STATES.md: only the SM-* driven by these UCs; spec/domain/05-INVARIANTS.md: ids + one line
   - test/TEST-PLAN.md §3 (conventions; never repeat them in the matrix)
   For each UC write test/TEST-MATRIX-UC-{NNN}.md following this template exactly:
   {template}
   Rules: one row per case; equivalence classes grouped with one representative; mechanical expansions written as `expand: …`; the Refs column is the traceability (no Traceability section); no UC description; budget ≤ 5 000 chars (≤ 8 000 with a state machine).
   Return only, per UC: file path, case count, chars (wc -c), gap ids found, findings for sdd-spec-auditor (id + one line). No file bodies.
   ```
4. Main thread: continue with Mode 3 and Mode 5 while the agents run; when all have reported, verify that every file exists and case ids are unique per file (`grep -c '^| T' test/TEST-MATRIX-UC-*.md`), fold gaps and findings into TEST-PLAN §4, and sum chars for `metrics.test_chars`.

Subagents never write `pipeline-state.json`, never send handoff messages, never touch `spec/`. With ≤ 3 UCs, or when `Agent` is unavailable, the main thread writes the matrices with the same rules.

**Process (per UC, in the main thread or in a subagent):**

1. **Read the UC by section** — inputs, preconditions, main/exception flows, AC ids; then its BDD file, the contract section of its endpoint/function, and its state machine (if any)
2. **Extract inputs:** every parameter, precondition, actor role, and the persisted state the UC depends on
3. **Apply test design techniques** (SWEBOK v4 Ch04 §3) **and group the results:**

   **a. Equivalence Partitioning:** one entry per class with one representative value — never every value of the class.

   **b. Boundary Value Analysis:** state the rule (`len ∈ [1,1000]`) and the points that matter (`0, 1, 1000, 1001`). When the expansion is mechanical (all BVA points of a range, every enum value, every error code of one family) write `expand: BVA(min,max)` / `expand: enum(TaskStatus)` and leave the expansion to the implementer.

   **c. Decision Table:** for UCs with several conditions, encode the condition vector in the row's Precondition cell (`C1=no · C2=—`): one row per distinct outcome, not one row per combination with the same outcome.

   **d. State Transition:** for entities with state machines (`spec/domain/04-STATES.md`), one row per valid transition and one per invalid-transition class.

4. **Write `test/TEST-MATRIX-UC-{NNN}.md`** — dense tables, no prose, no restated UC text, no trailing traceability section:

```markdown
# Test Matrix: UC-{NNN} — {title}

> Refs: UC-{NNN}, {API id}, BDD-UC-{NNN} (AC-{NNN}-01..{NN}), {INV/PROP/RN ids}{, SM-NNN}
> Techniques: EP, BVA, decision table{, state transition} · Default level: {unit | integration | E2E} · Conventions: TEST-PLAN.md §3

## Inputs

| Input | Type | Valid classes | Invalid classes | Boundaries |
|-------|------|---------------|-----------------|------------|
| {param} | {type} | {class: representative} · {class: representative} | {class: representative} · … | {rule} → BVA({points}) or `expand: BVA(min,max)` |
| {state / fixture} | {kind} | {class} · … | {class} · … | {sizes} |

## Cases

`Type`: happy · error · boundary · state · derived (no AC of its own — cite the rule in Refs).

| ID | Precondition / Input | Expected (status · output · state) | Type | Refs |
|----|----------------------|-------------------------------------|------|------|
| T01 | {C1=no} `{input}` · {store state} | {exit/status} · {stdout/body or —} · {store effect or unchanged} | error | AC-{NNN}-03, RN-{NNN} |
| T02 | `{input}` · {store state} | {status} · {output} · {effect} | happy | AC-{NNN}-01 |
| T03 | {rule} `expand: BVA(1,1000)` | {status} per point | boundary | AC-{NNN}-09 |

## State Transitions (only if the UC drives a state machine)

| SM | From | Event / guard | To | Postcondition (≤ 80 chars) | Cases |
|----|------|---------------|----|-----------------------------|-------|
| SM-{NNN} | {state} | {event} | {state} | {postcondition} | T02, T05 |

## Findings for sdd-spec-auditor (only if any)

| ID | Observation (≤ 120 chars) | Suggested action |
|----|----------------------------|------------------|
```

Budget per matrix: ≤ 5 000 chars, ≤ 8 000 with a State Transitions section. A cell longer than 160 chars means classes are being enumerated instead of grouped.

---

### Mode 3: Generate Performance Scenarios

Use when the user needs performance test scenarios derived from NFR specs.

**Process:**

1. **Collect quantified targets only** — rows with a number and a unit:
   `grep -n -E '[0-9]+ *(ms|s|min|req|rps|MB|KB|%|users|records)' spec/nfr/PERFORMANCE.md spec/nfr/LIMITS.md spec/VALUE-REGISTRY.md`. Open the surrounding lines only for the measurement method (samples, dataset, environment). An NFR statement without a number produces no scenario: one line in "Not planned", or a `MISSING-NFR-TEST` gap in TEST-PLAN §4 when a target should exist.

2. **One scenario per quantified target.** The type follows the target, not a catalogue: latency/throughput → load; rate limit/quota → stress at the threshold; memory over time → soak; burst → spike. Do not add Smoke/Load/Stress/Soak/Spike scenarios that no NFR quantifies.

3. **Write `test/PERF-SCENARIOS.md`** (budget ≤ 4 000 chars):

```markdown
# Performance Test Scenarios — {project}

> Derived from: spec/nfr/PERFORMANCE.md, spec/nfr/LIMITS.md — quantified targets only

## Targets

| ID | Metric | Target | Measurement (from spec) | Source |
|----|--------|--------|--------------------------|--------|
| PERF-001 | {p99 latency of X} | < {N} ms | {samples · dataset · environment} | SPEC-PERF-{NNN}, REQ-{ID} |

## Scenarios

| ID | Type | Target / dataset | Method (≤ 140 chars) | Pass criterion | Blocking | Refs |
|----|------|------------------|-----------------------|----------------|----------|------|
| PERF-001 | load | {endpoint or command} · {N records} | {ramp, duration, samples} | p99 < {N} ms · 0% errors | yes | {ids} |
| PERF-002 | stress | {rate-limit threshold} | single client exceeding {N} req/min | 429 after limit · Retry-After present | yes | {ids} |

## Harness

≤ 10 lines: runner, isolation (serial, warm-up discarded), dataset factory, output file.

## Not planned

| Item | Reason (≤ 80 chars) | Ref |
|------|----------------------|-----|
| {NFR statement or scenario type} | {why no scenario} | {id} |

(max 5 rows)
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

2. **Index workflow and spec artifacts, open sections only** (Reading Strategy):
   - `spec/workflows/WF-*.md` → step lists, actors, UCs involved (`grep -n -E '^#|^\| *[0-9]+ *\||UC-[0-9]+'`)
   - `spec/use-cases/UC-*.md` → the input-parameter table of each UC in the WF (**ALL parameters with type and required/optional**) and the exception-flow headings — not the narrative
   - `spec/tests/BDD-*.md` → scenario titles + AC ids (reuse, don't duplicate)
   - `spec/contracts/API-*.md` → request-body field tables of the endpoints in the WF (**ALL fields with required/optional and validation rules**)
   - `requirements/REQUIREMENTS.md` → REQ ids + the UC each one cites, for the transitive REQ→UC→WF mapping
   - `test/TEST-MATRIX-UC-*.md` (if already generated) → boundary row ids to reference, never to restate

3. **Read UX artifacts (if `project_type = WEB-APP` and `ux/` exists):**
   - `ux/WIREFRAMES.md` → extract component inventory, interactive elements per screen
   - `ux/INTERACTION-MODEL.md` → extract state diagrams, loading states, error states, **conditional visibility rules**
   - `ux/ACCESSIBILITY-SPEC.md` → extract keyboard navigation matrix, ARIA mappings

4. **Build field inventory per workflow (MANDATORY):**

   For each WF-* that will have E2E scenarios, enumerate ALL fields from three sources and cross-reference them:

   ```
   WF-007 Field Inventory (from UC-003, API-SRV-01, WIREFRAMES §WF-007):
   | Field        | UC param | API field | Wireframe element          | Required | Type      | Validation rules         | Conditional? |
   |--------------|----------|-----------|----------------------------|----------|-----------|--------------------------|--------------|
   | clienteId    | UC-003.1 | body.clienteId | Cliente [v Buscar...]  | Yes      | select    | Must exist in system     | No           |
   | tipoServicio | UC-003.2 | body.tipo      | (o) Fibra ( ) Movil    | Yes      | radio     | enum: fibra, movil       | No           |
   | velocidad    | UC-003.3 | body.velocidad | Velocidad [v 300Mb...] | Yes      | select    | depends on tipoServicio  | Yes: only when tipoServicio=fibra |
   | ...          | ...      | ...       | ...                        | ...      | ...       | ...                      | ...          |
   ```

   **Cross-validation rules (STOP on ERROR, warn on WARN):**
   - `V-FIELD-01` (ERROR): Every `required` field in the API contract MUST appear in the inventory with a UC param source
   - `V-FIELD-02` (ERROR): Every UC input parameter MUST appear in the inventory
   - `V-FIELD-03` (ERROR): Every interactive input element in the wireframe MUST appear in the inventory (buttons excluded — only data-entry elements)
   - `V-FIELD-04` (WARN): A field in UC/API but not in the wireframe → flag as `MISSING-UI` for user review
   - `V-FIELD-05` (WARN): A wireframe element not in UC/API → flag as `UI-ONLY`, may need interaction step

   **If any ERROR is found, present the table to the user and STOP. This is a spec inconsistency that must be resolved before generating scenarios.**

5. **Build field behavioral matrix (MANDATORY):**

   For each field in the inventory, define the behavioral scenarios it requires:

   ```
   WF-007 Field Behavioral Matrix:
   | Field        | VALID              | EMPTY              | INVALID                | BOUNDARY           | CONDITIONAL                          |
   |--------------|--------------------|--------------------|-----------------------|--------------------|--------------------------------------|
   | clienteId    | Select existing    | Submit without →   | Non-existent ID →     | —                  | —                                    |
   |              | client → proceed   | blocked/error msg  | error msg             |                    |                                      |
   | tipoServicio | Select fibra →     | Submit without →   | —                     | —                  | fibra → show velocidad, plan fields  |
   |              | show fibra fields  | blocked/error msg  |                       |                    | movil → show linea, portab fields    |
   | velocidad    | Select 300Mb →     | Submit without →   | —                     | —                  | Only visible when tipoServicio=fibra |
   |              | proceed            | blocked/error msg  |                       |                    | Hidden when tipoServicio=movil       |
   ```

   Behavioral categories:
   - **VALID**: Standard happy-path value → expected positive behavior
   - **EMPTY**: Required field left blank → expected validation error or submit block
   - **INVALID**: Wrong type, format, or value → expected validation error message
   - **BOUNDARY**: Edge values (min/max length, min/max numeric) → reuse from TEST-MATRIX if exists
   - **CONDITIONAL**: Field visibility/value changes triggered by other fields → test that field appears/disappears/resets correctly

   **Rules:**
   - Every required field MUST have at least VALID + EMPTY behaviors defined
   - Every field with validation rules MUST have at least one INVALID behavior
   - Every field marked `Conditional? = Yes` MUST have CONDITIONAL behaviors for each trigger value
   - Fields with interactions (e.g., selecting client loads client data) MUST document the interaction chain

6. **Generate E2E scenarios from field behavioral matrix:**

   For each WF-* that involves user interaction, generate scenarios **driven by the field behavioral matrix**, not by narrative walkthrough:

   **a. Happy path scenario (P0):**
   - One step per field in the inventory (ALL of them), filled with VALID values in the order they appear in the wireframe
   - Final submit and assert postcondition
   - **Every MAPPED field MUST have a Fill/Select/Click step.** If a field is missing from the steps, the scenario is incomplete.

   **b. Required-field validation scenarios (P0):**
   - For each required field: leave it empty, fill all others with valid values, attempt submit
   - Assert: specific validation error message for that field (from UC exception flows or API 400 response)
   - Combine into a variation table when possible (one row per required field)

   **c. Invalid-value scenarios (P1):**
   - For each field with INVALID behaviors in the matrix: fill with invalid value, fill all others with valid values, attempt submit
   - Assert: specific validation error for that field
   - Combine into a variation table

   **d. Conditional behavior scenarios (P1):**
   - For each CONDITIONAL field: test that changing the trigger field correctly shows/hides/resets dependent fields
   - Example: select tipoServicio=fibra → assert velocidad field appears; switch to movil → assert velocidad disappears and linea field appears
   - Include "field reset" behavior: if user fills conditional fields, then changes trigger → conditional fields should reset

   **e. Field interaction scenarios (P1):**
   - For each field interaction chain: test the full chain
   - Example: select clienteId → client data loads → dependent fields auto-populate

   **f. UC exception flow scenarios (P1/P2):**
   - One row per exception flow in the constituent UCs (as before)
   - These are ADDITIONAL to field-level scenarios — they cover business logic errors, not field validation

   **g. Accessibility gate:**
   - axe-core scan at each major navigation step
   - Keyboard-only form completion (tab through all fields, submit with Enter)

   **h. Detail by tier (output budget):**
   - Smoke (P0) and Critical (P1) scenarios are written in full (steps table or variation table).
   - Full-tier (P2) scenarios are a one-line list: id · given · action · expected · refs; the implementer expands them.
   - BOUNDARY variations reference the matrix row (`TEST-MATRIX-UC-001 T14`) instead of restating input and expectation; keep only boundaries that change the journey (another screen, message or state) — the rest stay in the matrix.
   - Steps tables: one step per field, but the Assertion cell is one clause (≤ 100 chars). Exact payloads and fixtures go to a shared `Fixtures` list at the top of §Scenarios, referenced by name.

7. **Post-generation completeness check (MANDATORY):**

   After generating all scenarios, build and output this verification matrix:

   ```
   WF-007 Field Coverage Verification:
   | Field        | Happy path step? | Empty variation? | Invalid variation? | Conditional tested? | Interaction tested? | Status |
   |--------------|-----------------|------------------|-------------------|--------------------|--------------------|--------|
   | clienteId    | Step 3 ✅        | Var E2E-02 ✅     | Var E2E-05 ✅      | N/A                | E2E-WF-007-05 ✅   | COMPLETE |
   | tipoServicio | Step 4 ✅        | Var E2E-03 ✅     | N/A                | E2E-WF-007-04 ✅   | N/A                | COMPLETE |
   | velocidad    | Step 5 ✅        | Var E2E-04 ✅     | N/A                | E2E-WF-007-04 ✅   | N/A                | COMPLETE |
   ```

   **Completeness rules:**
   - Every required field MUST have: happy path step + empty variation → otherwise status = `INCOMPLETE`
   - Every field with validation rules MUST have: invalid variation → otherwise status = `INCOMPLETE`
   - Every conditional field MUST have: conditional scenario → otherwise status = `INCOMPLETE`
   - If ANY field has status `INCOMPLETE`, flag as finding and ask user whether to add the missing scenario or document exemption with justification

8. **Build transitive coverage matrix:**

   Map each E2E scenario back to the REQs it covers transitively:
   ```
   E2E-WF-001-01 → WF-001 → {UC-003, UC-004} → {REQ-FUNC-010, REQ-FUNC-011}
   ```

   For REQs not covered by any E2E scenario, classify as:
   - `EXEMPT-BACKEND`: Internal/infrastructure REQ, no user-facing flow
   - `EXEMPT-NFR`: Non-functional REQ, covered by performance/security tests
   - `GAP`: User-facing REQ with no transitive E2E coverage → flag for review

9. **Generate `test/E2E-SCENARIOS.md`** (budget ≤ 15 000 chars for one user-facing WF, +3 000 per additional WF; Smoke/Critical detailed, Full as a list):

```markdown
# E2E Acceptance Scenarios

> **Project:** {project name}
> **Project type:** {WEB-APP | API-ONLY | CLI}
> **Generated from:** spec/workflows/, spec/use-cases/, spec/contracts/
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

## Field Inventory: WF-{NNN}

> Cross-referenced from: UC-{NNN} params, API-{NNN} body, WIREFRAMES §{screen}

| Field | UC param | API field | Wireframe element | Required | Type | Validation rules | Conditional? |
|-------|----------|-----------|-------------------|----------|------|-----------------|--------------|
| {field1} | UC-{NNN}.1 | body.{f1} | {element desc} | Yes | {type} | {rules} | No |
| {field2} | UC-{NNN}.2 | body.{f2} | {element desc} | Yes | {type} | {rules} | Yes: when {trigger} |
| ... | ... | ... | ... | ... | ... | ... | ... |

### Field Behavioral Matrix: WF-{NNN}

| Field | VALID | EMPTY | INVALID | BOUNDARY | CONDITIONAL |
|-------|-------|-------|---------|----------|-------------|
| {field1} | {valid action → expected result} | {submit without → expected error} | {bad value → expected error} | {edge values if applicable} | {N/A or trigger→effect} |
| {field2} | {valid action → expected result} | {submit without → expected error} | {N/A or bad value → error} | {N/A or edge values} | {trigger changes → field shows/hides/resets} |

---

## Scenarios

> Fixtures (named once, referenced by name in the steps): `{name}` = {≤ 80 chars} · `{name}` = {≤ 80 chars}

### E2E-WF-{NNN}-01: {Workflow title} — Happy Path (P0)

- **Workflow:** WF-{NNN}
- **Use Cases:** UC-{NNN}, UC-{NNN}
- **Requirements (transitive):** REQ-FUNC-{NNN}, REQ-FUNC-{NNN}
- **Priority:** P0
- **Tier:** smoke
- **Auth fixture:** {authenticated | admin | unauthenticated}
- **Fields covered:** ALL ({N} fields from inventory)

#### Elements Referenced (when ux/ exists)

| Element | Locator hint | Source |
|---------|-------------|--------|
| {name} | getByRole("{role}", { name: /{pattern}/i }) | WIREFRAMES §{screen} |
| {name} | getByLabel("{label}") | WIREFRAMES §{screen} |

#### Steps

> One step per field in inventory, in wireframe presentation order. No field may be skipped.

| # | Action | Target | Assertion | Spec Ref |
|---|--------|--------|-----------|----------|
| 1 | Navigate to {url} | — | Page title = "{title}" | WF-{NNN} step 1 |
| 2 | axe-core scan | full page | No violations | ACCESSIBILITY-SPEC |
| 3 | Fill/Select {field1} | {element} | Field accepts input, {interaction effect if any} | UC-{NNN} §main.{N} |
| 4 | Fill/Select {field2} | {element} | Field accepts input, {conditional fields appear if applicable} | UC-{NNN} §main.{N} |
| ... | (one step per field from inventory) | ... | ... | ... |
| N | Click submit | {button} | {expected success feedback} | UC-{NNN} §main.{N} |
| N+1 | Assert final state | — | {postcondition} | WF-{NNN} postcondition |

### E2E-WF-{NNN} — Required-Field Validation (P0)

> One variation per required field. All other fields filled with valid values.

| Variant ID | Empty field | Other fields | Action | Expected behavior | Spec Ref |
|------------|-------------|-------------|--------|-------------------|----------|
| E2E-WF-{NNN}-V01 | {field1} | All valid | Submit | Error: "{validation message}" | UC-{NNN} §exception.{N} |
| E2E-WF-{NNN}-V02 | {field2} | All valid | Submit | Error: "{validation message}" | UC-{NNN} §exception.{N} |

### E2E-WF-{NNN} — Invalid-Value Scenarios (P1)

> One variation per field with validation rules. All other fields filled with valid values.

| Variant ID | Field | Invalid value | Other fields | Expected behavior | Spec Ref |
|------------|-------|---------------|-------------|-------------------|----------|
| E2E-WF-{NNN}-IV01 | {field} | {invalid value} | All valid | Error: "{validation message}" | UC-{NNN} §exception.{N} |

### E2E-WF-{NNN} — Conditional Behavior Scenarios (P1)

> One scenario per conditional field trigger. Tests visibility, reset, and dependent field behavior.

| Variant ID | Trigger field | Trigger value | Expected effect | Reset tested? | Spec Ref |
|------------|---------------|---------------|-----------------|---------------|----------|
| E2E-WF-{NNN}-CD01 | {trigger} | {value1} | {fields shown/hidden, values reset} | Yes | UC-{NNN} §main.{N}, INTERACTION-MODEL §{state} |
| E2E-WF-{NNN}-CD02 | {trigger} | {value2} | {different fields shown/hidden} | Yes | UC-{NNN} §main.{N} |

### E2E-WF-{NNN} — Field Interaction Scenarios (P1)

> Tests interaction chains where one field's value affects others (auto-populate, cascading selects, etc.)

| Variant ID | Source field | Action | Affected fields | Expected effect | Spec Ref |
|------------|-------------|--------|-----------------|-----------------|----------|
| E2E-WF-{NNN}-FI01 | {field} | {select value} | {field2, field3} | {auto-populated/filtered/enabled} | UC-{NNN} §main.{N} |

### E2E-WF-{NNN} — UC Exception Flows (P1/P2)

> Business logic errors beyond field validation (e.g., duplicate detection, insufficient permissions, external service failures).

| Variant ID | Diverges at step | Input change | Expected behavior | Spec Ref |
|------------|------------------|-------------|-------------------|----------|
| E2E-WF-{NNN}-EX01 | Step {N} | {precondition not met} | {error/redirect/fallback} | UC-{NNN} §exception.{N} |

### E2E-WF-{NNN} — Accessibility (P1)

> Keyboard-only and screen-reader scenarios.

| Variant ID | Scenario | Steps | Assertion | Spec Ref |
|------------|----------|-------|-----------|----------|
| E2E-WF-{NNN}-A11Y-01 | Keyboard-only completion | Tab through all {N} fields, fill each, Enter to submit | All fields reachable, submit succeeds | ACCESSIBILITY-SPEC |

### E2E-WF-{NNN} — Full tier (P2) — list only

> Nightly / release scenarios (soak, concurrency, kill-during-write, large datasets). One line each; no steps table — the implementer expands them.

| Variant ID | Given | Action | Expected | Spec Ref |
|------------|-------|--------|----------|----------|
| E2E-WF-{NNN}-F01 | {precondition ≤ 80 chars} | {action ≤ 60 chars} | {outcome ≤ 80 chars} | {ids} |

---

## Field Coverage Verification

> Post-generation completeness check. Every field MUST have COMPLETE status.

### WF-{NNN}

| Field | Happy path step? | Empty variation? | Invalid variation? | Conditional tested? | Interaction tested? | Status |
|-------|-----------------|------------------|-------------------|--------------------|--------------------|--------|
| {field1} | Step {N} ✅ | V01 ✅ | IV01 ✅ | N/A | FI01 ✅ | COMPLETE |
| {field2} | Step {N} ✅ | V02 ✅ | N/A | CD01 ✅ | N/A | COMPLETE |

**Completeness rules:**
- Required field without empty variation → `INCOMPLETE`
- Field with validation rules without invalid variation → `INCOMPLETE`
- Conditional field without conditional scenario → `INCOMPLETE`
- Any `INCOMPLETE` → flag as finding, ask user for exemption or add missing scenario

---

## Scenarios for API-ONLY projects

### E2E-API-{NNN}-01: {Workflow title} — Happy Path

- **Workflow:** WF-{NNN}
- **Use Cases:** UC-{NNN}, UC-{NNN}
- **Type:** API E2E (no browser)

#### Request Body Field Inventory

| Field | Required | Type | Validation | Source |
|-------|----------|------|-----------|--------|
| {field1} | Yes | {type} | {rules} | API-{NNN}, UC-{NNN} |

#### Steps

| # | Method | Endpoint | Body/Params | Assert status | Assert body | Spec Ref |
|---|--------|----------|-------------|---------------|-------------|----------|
| 1 | POST | /api/{resource} | {ALL required fields} | 201 | {schema} | API-{NNN} |
| 2 | GET | /api/{resource}/{id} | — | 200 | {all fields present} | API-{NNN} |

#### Required-Field Validation (API)

| Variant | Missing field | Assert status | Assert body | Spec Ref |
|---------|--------------|---------------|-------------|----------|
| E2E-API-{NNN}-V01 | {field1} | 400 | error.field = "{field1}" | API-{NNN} §validation |

#### Invalid-Value Validation (API)

| Variant | Field | Invalid value | Assert status | Assert body | Spec Ref |
|---------|-------|---------------|---------------|-------------|----------|
| E2E-API-{NNN}-IV01 | {field1} | {invalid} | 400/422 | error: "{message}" | API-{NNN} §validation |

---

## Coverage Matrix

| REQ ID | Type | E2E Coverage | Justification if excluded |
|--------|------|-------------|---------------------------|
| REQ-FUNC-{NNN} | UI-func | E2E-WF-{NNN}-01 + {N} variations | — |
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
   - `metrics`: `{ "bdd_scenarios": N, "test_matrices": N, "matrix_cases": N, "perf_scenarios": N, "e2e_scenarios": N, "e2e_fields_total": N, "e2e_fields_complete": N, "e2e_field_coverage_pct": N, "invariants_mapped": N, "test_gaps": N, "test_chars": N }` — `test_chars` is the total of `wc -c test/*.md` (Output Budget)
   - `highlights`: top 3-5 notable observations (e.g., "101 BDD scenarios cover 85% of requirements", "3 gaps in NFR testing", "TEST-MATRIX-UC-006 at 9 800 chars, over budget")
   - `nextStep`: `"Run /sdd-plan-architect"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Respond in the same language the user uses. If the user writes in Spanish, respond in Spanish. If in English, respond in English.
