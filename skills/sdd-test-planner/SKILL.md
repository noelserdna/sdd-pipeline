---
name: sdd-test-planner
description: "Test planning per SWEBOK v4: strategy, matrices, coverage per use case, performance (NFRs) and E2E acceptance scenarios. Triggers: 'test plan', 'test strategy', 'test matrix', 'performance tests', 'test coverage', 'e2e scenarios', 'acceptance tests', 'playwright', 'plan de pruebas', 'estrategia de testing', 'cobertura de tests', 'tests de aceptacion'."
---

# SDD Test Planner

> A test plan is not a list of tests: it is the strategy that gives every requirement, invariant and contract the right verification at the right level and time.

Turns the audited `spec/` into a test strategy (`test/TEST-PLAN.md`), per-UC test matrices, performance scenarios and E2E acceptance scenarios. Runs after `sdd-spec-auditor` and before `sdd-plan-architect` (which reads TEST-PLAN §9) and `sdd-task-generator` (which turns matrices into test tasks). Optional inputs: `audits/SECURITY-AUDIT-BASELINE.md` (security test ids) and `ux/` (E2E enrichment: page objects, accessibility assertions). It writes no test code (`sdd-task-implementer` does) and never edits `spec/` (spec defects go to the matrices' "Findings for sdd-spec-auditor").

## Reading Strategy (index first)

Generation time is dominated by output tokens; reading the whole corpus only adds turns. Never `cat` the whole `spec/` tree: build an index, then open only the sections a mode needs.

1. **Index** — one command (~2-4 k chars for a 10-requirement project):
   ```bash
   grep -rn -E '^#{1,4} |^\| *(UC|WF|INV|API|AC|PROP|RN|REQ|SPEC|SEC|SLO)-[A-Z0-9-]+ *\|' spec/ requirements/ 2>/dev/null | cut -c1-160
   ```
   Every heading and every id-bearing table row with `file:line`. Add `audits/SECURITY-AUDIT-BASELINE.md` (finding ids) when it exists, and `plan/fases/FASE-*.md` only on a re-run after planning (to show which FASE each use case landed in).
2. **Open by section** with `sed -n 'A,Bp' file` from the line numbers of the index:

   | Need | Open only |
   |------|-----------|
   | Levels, gaps (Mode 1) | UC acceptance-criteria / exception-flow blocks; BDD scenario titles; `spec/nfr/*` target rows; INV table (id + one line) |
   | Matrix for UC-NNN (Mode 2) | the UC's inputs/parameters table, main and exception flow steps, its BDD file, its operation rows in the contract (`grep -n 'UC-NNN' spec/contracts/`), its state machine in `04-STATES.md` |
   | PERF (Mode 3) | rows with a number and a unit in `PERFORMANCE.md` / `LIMITS.md` (`grep -n -E '[0-9]+ *(ms|s|req|MB|%)'`) |
   | E2E (Mode 5) | WF step lists, UC input tables, the `Input (VO)` cells of the contract operations (or request-body schemas with `Style: http`), `ux/WIREFRAMES.md` interactive elements |

   Never open `01-GLOSSARY.md`, ADR bodies, runbooks or `CLARIFICATIONS.md` in full: grep the id you cite (`grep -n -A3 'RN-007' spec/CLARIFICATIONS.md`).
3. If the `sdd_context` / `sdd_query` MCP tools are available (index built by `scripts/sdd-graph.py`), use them for id lookups instead of grep.

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

1. Readiness gates (below) → index `spec/` (Reading Strategy).
2. Mode 1 `TEST-PLAN.md` in the main thread; write §3 Design Decisions first — it is the convention contract the matrix subagents must not repeat.
3. Mode 2 matrices: fan-out to subagents (see Mode 2). They run in the background.
4. **Mode 5 `E2E-SCENARIOS.md` is delegated too when it is the critical path** — more than 1 workflow, or more than 20
   expected scenarios: one subagent writes the Critical and Full tiers from the WF step lists and the §3 conventions
   (same launch rules as the matrices), while the main thread keeps the Smoke tier and the **field-inventory
   cross-validation**, which may stop for a user decision and therefore never leaves the main thread. Below that
   threshold, or with `--sequential`, Mode 5 stays in the main thread. (The critical path is the main thread's own
   writing; parallelising only the matrices does not shorten the stage.)
5. Mode 3 `PERF-SCENARIOS.md` in the main thread while the agents run.
6. Consolidate: agent summaries → TEST-PLAN §4 gaps / §10 metrics; Persist Summary; Handoff.

## Readiness Gates

| Gate | Check | On failure |
|---|---|---|
| G0 | `pipeline-state.json` → `stages["spec-auditor"].summary.metrics.gate_result` ∈ {`PASS`, `CONDITIONAL`} | `stages["spec-auditor"].status == "skipped"` (the confirmed route left the audit out, `docs/ruta.md`) → n/a, no question. Missing or `FAIL`: tell the user and ask whether to run `sdd-spec-auditor` first (recommended) or plan against the unaudited spec; in the latter case add a first highlight "planned against spec with audit gate {FAIL|missing}" |
| G1 | `spec/domain/`, `spec/use-cases/`, `spec/contracts/` exist and are non-empty | Stop: nothing to plan from; recommend `sdd-specifications-engineer` |
| G2 | `spec/tests/BDD-UC-*.md` exist (at least partially) | Continue; every UC without a BDD file becomes a `MISSING-BDD` gap |
| G3 | `spec/nfr/*.md` exist | Continue; Mode 3 writes only "Not planned" and TEST-PLAN §4 gets a `MISSING-NFR-TEST` gap per quantified NFR expected by a REQ-NF |
| G4 (Mode 5) | `spec/workflows/WF-*.md` exist | No WF → no E2E scenarios; user-facing UCs are listed as `MISSING-E2E` gaps (G1 already guarantees UCs) |

**Asking without a human.** A question or stop in this skill (G0, V-FIELD errors, INCOMPLETE fields, coverage target) is asked with `AskUserQuestion` in an interactive session. A station (`SDD_ROLE` set, or a role resolved from `.claude/sdd-sessions.json`, and the role is not `sdd-lead`) follows the plugin-root `references/async-questions.md`: write the `Q-<role>-NNN [OPEN]` block, continue with the work that does not depend on it (e.g. other workflows), and hand off `status=blocked` when nothing unblocked remains. A non-interactive run with no role takes the recommended option, records the open item as a gap in TEST-PLAN §4 and lists it in `summary.highlights`.

---

## Modes of Operation

### Mode 1: Generate Test Strategy

Use when the user wants a comprehensive test plan for the project.

Gates G0–G3 apply.


1. **Index, then open sections** (Reading Strategy). From the index, without opening whole files:
   - UC ids, titles, actors, exception-flow headings (`grep -n -E '^#|Exception|Excepci' spec/use-cases/UC-*.md`)
   - BDD scenario titles per UC (`grep -n -E '^ *(Scenario|Escenario)' spec/tests/BDD-*.md`) → main/exception flow coverage
   - INV ids + one line (`grep -n -E '^\| *INV-' spec/domain/05-INVARIANTS.md`); PROP ids in `spec/tests/PROPERTY-TESTS.md`
   - Quantified NFR rows (`grep -n -E '[0-9]+ *(ms|s|req|MB|%|users)' spec/nfr/*.md`); security control ids (`SEC-*`)
   - Contract operation ids (`grep -n -E '^\| *API-[0-9]{3}-[0-9]{2}' spec/contracts/API-*.md`) and each module's `Style`; event names in `EVENTS-*.md`
   - `audits/SECURITY-AUDIT-BASELINE.md` finding ids (if exists)

   Open a section only when the id line is not enough (e.g. an exception flow whose BDD coverage is unclear).

2. **Classify test types needed per spec element** (keep only the rows present in this project when writing the plan):

   | Spec Element | Test Types | Level |
   |-------------|------------|-------|
   | Entity invariants (INV-*) | Unit tests (property-based) | Unit |
   | UC main flows | BDD scenarios (Given/When/Then) | Integration |
   | UC exception flows | Negative BDD scenarios | Integration |
   | Operation contracts (API-NNN-NN) | Contract tests (input → effect / domain errors; request/response schema only with `Style: http`) | Integration |
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
   - Write operations whose replay (or, with shared records, race) outcome no scenario defines → `MISSING-REPLAY-SPEC` (Mode 2, technique e)
   - User-facing WFs without E2E scenarios, and REQ-F criteria without a capturing E2E scenario (§ Visual Evidence) → `MISSING-E2E` (addressed by Mode 5)

4. **Define coverage targets by use case:**
   - Ask user for overall coverage target (recommend 80% minimum)
   - Group the targets by use case (§5): this skill runs before `sdd-plan-architect`, which cuts vertical FASEs from these groups (one user journey = 1-3 use cases). On a re-run after planning, add the FASE each use case landed in as a column; never group by technical layer

5. **Write `test/TEST-PLAN.md`** with the template below. Tables, not prose; every row carries ids; budget ≤ 12 000 chars. Write §3 before launching matrix subagents.

```markdown
# Test Plan — {project}

> Spec v{X.Y} · audit gate {PASS|CONDITIONAL} · Project type: {WEB-APP | API-ONLY | CLI | LIBRARY}
> Companion files: TEST-MATRIX-UC-*.md ({N}), PERF-SCENARIOS.md, E2E-SCENARIOS.md

## 1. Strategy Summary

| Dimension | Target | Current | Source |
|-----------|--------|---------|--------|
| UC main + exception flows with BDD | 100% | {N}% | spec/tests/ |
| Invariants with property tests | 100% of INV-* | {N}% | domain/05-INVARIANTS.md |
| Contract operations (API-NNN-NN) with contract tests | 100% | {N}% | spec/contracts/ |
| Quantified NFRs with a scenario | 100% | {N}% | spec/nfr/ |
| Applicable security controls | 100% | {N}% | nfr/SECURITY.md, audits/ |
| User-facing WF-* with E2E | 100% | {N}% | spec/workflows/ |
| REQ-F criteria with a capturing E2E (§ Visual Evidence) | 100% | {N}% | spec/tests/, requirements/ |

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

One row per decision the implementer needs (clock injection, I/O fault injection, isolation and determinism, platform skips, fixtures, error-precedence rules), and one per write operation exempted from the `replay` row (Mode 2, technique e) with its reason. No prose; ≤ 160 chars per decision.

| ID | Decision | Applies to | Refs |
|----|----------|------------|------|
| D-T-001 | {decision} | {levels / test ids} | {SPEC/INV/ADR/RN ids} |
| D-T-E2E | Each REQ-F criterion: E2E from the user's route, asserts its example text, screenshot `evidencias/FASE-{N}/{AC id}.png`; one video per WF | E2E | § Visual Evidence |

## 4. Gaps

| Gap ID | Type | Spec element | Missing (≤ 100 chars) | Priority |
|--------|------|--------------|------------------------|----------|
| GAP-001 | MISSING-BDD | UC-{NNN} | No BDD file | High |
| GAP-002 | INCOMPLETE-BDD | UC-{NNN} | Exception flow {N} not covered | Medium |
| GAP-003 | MISSING-PROPERTY-TEST | INV-{PREFIX}-{NNN} | No property test | Medium |
| GAP-004 | MISSING-NFR-TEST | SPEC-PERF-{NNN} | No scenario for the p99 target | High |
| GAP-005 | MISSING-E2E | WF-{NNN} | No E2E for user-facing workflow | High |
| GAP-006 | MISSING-E2E | AC-{NNN}-{NN} | REQ-F-{NNN} AC{n}: no E2E asserting its text with a screenshot | High |
| GAP-007 | MISSING-REPLAY-SPEC | API-{NNN}-{NN} | Replay of the same input has no defined outcome | High |

## 5. Targets by Use Case

One row per use case, in the order of its dependencies; `sdd-plan-architect` maps groups of rows to FASEs. Scenario ids are the ones test names must carry (Test Naming).

| UC | REQs | Scenarios (AC ids) | Unit | Integration | E2E | Perf |
|----|------|--------------------|------|-------------|-----|------|
| UC-{NNN} | REQ-F-{NNN} | AC-{NNN}-01, AC-{NNN}-02 | {INV/PROP ids} | {matrix rows} | {E2E ids} | {PERF ids} |

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
| FASE completion (increment demo) | full integration + E2E Critical (with screenshots and videos) |
| post-deploy (when `staging_url` is set) | E2E `smoke-deploy` (`@smoke-deploy`) against the deployed environment |
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

**Fan-out above 3 UCs is part of this skill's contract.** Matrices are mechanical and independent, so parallel
subagents write them (read-only over `spec/`, one per 2-3 UCs, no nesting, each writing only its own
`TEST-MATRIX-UC-*.md`) while the main thread keeps TEST-PLAN, PERF and E2E. Do not downgrade out of caution; downgrade
only with `--sequential`, at ≤ 3 UCs, or without the `Agent` tool, and say why in `summary.highlights`. `--fanout` forces it.

1. Group UCs 2-3 per agent, by shared entity or contract, so each agent reads a contract once.
2. Launch all groups in ONE message with the `Agent` tool. Pass `model: sonnet` unless the environment variable `CLAUDE_CODE_SUBAGENT_MODEL` is set — then omit `model` and let the environment decide. Do not use `subagent_type: "fork"`: a fresh agent with a small context is the point.
3. Agent prompt (fill the braces; paste the step-4 template verbatim):

   ```
   You generate test matrices for the SDD pipeline (sdd-test-planner Mode 2). Write in {project language}.
   Read ONLY (grep -n for ids first, then sed -n the sections):
   - spec/use-cases/{UC files}: inputs/parameters, main and exception flows, acceptance criteria
   - spec/tests/{BDD files}: scenario titles and AC ids
   - spec/contracts/{contract file}: only the operation rows and Errors rows of these UCs (grep -n 'UC-{NNN}\|API-{NNN}-{NN}')
   - spec/domain/04-STATES.md: only the SM-* driven by these UCs; spec/domain/05-INVARIANTS.md: ids + one line
   - test/TEST-PLAN.md §3 (conventions; never repeat them in the matrix)
   For each UC write test/TEST-MATRIX-UC-{NNN}.md following this template exactly:
   {template}
   Rules: one row per case; every row's Refs cites the scenario id it verifies (AC-NNN-NN, or REQ-X-NNN ACn) — the implemented test is named with it; every write operation has a replay row and, when records are shared, a race row — with no scenario defining the outcome, Refs `—`, Expected `undefined in spec` and a finding (never invent the semantics), unless TEST-PLAN §3 exempts the operation; expected = domain error code + observable outcome, HTTP status only with `Style: http`, exit code for a CLI; equivalence classes grouped with one representative; mechanical expansions written as `expand: …`; the Refs column is the traceability (no Traceability section); no UC description; budget ≤ 5 000 chars (≤ 8 000 with a state machine).
   Return only, per UC: file path, case count, chars (wc -c), gap ids found, findings for sdd-spec-auditor (id + one line). No file bodies.
   ```
4. Main thread: continue with Mode 3 (and with Mode 5's Smoke tier and field-inventory cross-validation when Mode 5 is delegated) while the agents run; when all have reported, verify that every file exists and case ids are unique per file (`grep -c '^| T' test/TEST-MATRIX-UC-*.md`), fold gaps and findings into TEST-PLAN §4, and sum chars for `metrics.test_chars`.

Subagents never write `pipeline-state.json`, never send handoff messages, never touch `spec/`. With ≤ 3 UCs, or when `Agent` is unavailable, the main thread writes the matrices with the same rules.

**Process (per UC, in the main thread or in a subagent):**

1. **Read the UC by section** — inputs, preconditions, main/exception flows, AC ids; then its BDD file, its operation rows in the contract, and its state machine (if any)
2. **Extract inputs:** every parameter, precondition, actor role, and the persisted state the UC depends on
3. **Apply test design techniques and group the results:**

   **a. Equivalence Partitioning:** one entry per class with one representative value — never every value of the class.

   **b. Boundary Value Analysis:** state the rule (`len ∈ [1,1000]`) and the points that matter (`0, 1, 1000, 1001`). When the expansion is mechanical (all BVA points of a range, every enum value, every error code of one family) write `expand: BVA(min,max)` / `expand: enum(TaskStatus)` and leave the expansion to the implementer.

   **c. Decision Table:** for UCs with several conditions, encode the condition vector in the row's Precondition cell (`C1=no · C2=—`): one row per distinct outcome, not one row per combination with the same outcome.

   **d. State Transition:** for entities with state machines (`spec/domain/04-STATES.md`), one row per valid transition and one per invalid-transition class.

   **e. Replay and race:** every operation with a write effect gets one `replay` row (the same write again with the same input: what is kept), and one `race` row when two actors can write the same record or consume the same resource (two concurrent calls on one fixture: who wins, what the other sees). They are ordinary `T0N` rows citing the scenario that defines the outcome: the UC's `replay` or conflict exception row and its AC, or `REQ-X-NNN ACn` in a requirement criterion. `sdd-specifications-engineer` owns that behaviour and this skill only derives tests from it, so when no scenario defines the outcome, write the row with `Refs: —` and Expected `undefined in spec`, add a finding for `sdd-spec-auditor` and a `MISSING-REPLAY-SPEC` gap, and never pick a semantics yourself (Art. 12). An operation that needs no replay row (a pure read, or an overwrite whose replay is trivially the same state) is exempted by one TEST-PLAN §3 row with its reason.

4. **Write `test/TEST-MATRIX-UC-{NNN}.md`** — dense tables, no prose, no restated UC text, no trailing traceability section:

```markdown
# Test Matrix: UC-{NNN} — {title}

> Refs: UC-{NNN}, API-{NNN}-{NN}, BDD-UC-{NNN} (AC-{NNN}-01..{NN}), {INV/PROP/RN ids}{, SM-NNN}
> Techniques: EP, BVA, decision table{, state transition}, replay{, race} · Default level: {unit | integration | E2E} · Conventions: TEST-PLAN.md §3

## Inputs

| Input | Type | Valid classes | Invalid classes | Boundaries |
|-------|------|---------------|-----------------|------------|
| {param} | {type} | {class: representative} · {class: representative} | {class: representative} · … | {rule} → BVA({points}) or `expand: BVA(min,max)` |
| {state / fixture} | {kind} | {class} · … | {class} · … | {sizes} |

## Cases

`Type`: happy · error · boundary · state · replay · race · derived (no AC of its own — cite the rule in Refs). The test implementing a row is named with the row's scenario id (Test Naming).

| ID | Precondition / Input | Expected (status · output · state) | Type | Refs |
|----|----------------------|-------------------------------------|------|------|
| T01 | {C1=no} `{input}` · {store state} | `{E_CODE}` {+ exit (CLI) or HTTP status (Style http only)} · {message/stdout/body or —} · {store effect or unchanged} | error | AC-{NNN}-03, RN-{NNN} |
| T02 | `{input}` · {store state} | {status} · {output} · {effect} | happy | AC-{NNN}-01 |
| T03 | {rule} `expand: BVA(1,1000)` | {status} per point | boundary | AC-{NNN}-09 |
| T04 | T02's input sent again · {store after T02} | {status} · {same output} · {no second record} | replay | AC-{NNN}-06 |
| T05 | two concurrent calls on {one fixture} | one succeeds · the other `{E_CODE}` · {final state} | race | AC-{NNN}-05 |
| T06 | {operation} sent twice | undefined in spec | replay | — |

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
| PERF-002 | stress | {rate-limit threshold} | single client exceeding {N} req/min | `{E_RATE_LIMITED}` after the limit (429 + Retry-After only with `Style: http`) | yes | {ids} |

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

Use when the user wants to verify that the planned (and, if present, implemented) tests cover the spec.

1. **List the spec elements** from the index: UCs and their exception rows, INV ids, contract operations (`API-NNN-NN`), user-facing WFs, quantified NFRs.
2. **Find their tests** where each kind lives:
   - BDD scenarios and property tests: `spec/tests/BDD-UC-NNN.md` (AC ids), `spec/tests/PROPERTY-TESTS.md` (INV ids).
   - Contract, boundary and state tests: `test/TEST-MATRIX-UC-*.md` (the `Refs` column cites the operation and AC ids).
   - NFR and E2E scenarios: `test/PERF-SCENARIOS.md`, `test/E2E-SCENARIOS.md`.
   - Implemented tests, when code exists: grep the ids (`AC-`, `INV-`, `API-`, `E2E-`, `PERF-`) under the `test_paths` of the SDD Stack Profile (`../sdd-task-implementer/references/stack-profile.md`; default `tests/`).
3. **Compute coverage:**

   | Dimension | Formula | Target |
   |-----------|---------|--------|
   | UC coverage | UCs with BDD / total UCs | 100% |
   | Exception coverage | exception rows with a scenario or matrix case / total exception rows | ≥ 80% |
   | Invariant coverage | INVs with a property test / total INVs | 100% |
   | Contract coverage | operations with a contract test / total operations | 100% |
   | NFR coverage | quantified NFRs with a scenario / total quantified NFRs | 100% |
   | E2E coverage | user-facing WFs with E2E scenarios / total user-facing WFs | 100% |
   | Visual criteria coverage | REQ-F criteria with a capturing E2E scenario (§ Visual Evidence) / total REQ-F criteria | 100% |

4. **Write `test/TEST-AUDIT.md`** (≤ 6 000 chars): the coverage table with current values and PASS/FAIL, then one gap row per uncovered element (`Gap ID | Type | Spec element | Missing | Priority`, same types as TEST-PLAN §4) and, when implemented tests were checked, one row per planned test id with no implementation. No prose.

### Mode 5: Generate E2E Acceptance Scenarios

Use for end-to-end acceptance scenarios that validate complete user journeys, traceable from workflows back to requirements. Gates G2 and G4 apply.

1. **Detect the project type** (first match wins):

   ```
   IF ux/WIREFRAMES.md exists                                              → WEB-APP (browser E2E with page objects)
   ELIF the system is a CLI — an `exit` column in the contracts' Errors tables,
        a CLI in plan/ARCHITECTURE.md or design/TECHNICAL-DESIGN.md, or a
        command-line interface named by a REQ                              → CLI (subprocess E2E)
   ELIF a contract is `Style: http` (or pre-4.3 `Method | Path`) and no ux/ → API-ONLY (HTTP E2E, no browser)
   ELIF contracts are `Style: operations` and a user-facing WF exists      → WEB-APP without UX enrichment (locators from REQ roles/names)
   ELSE                                                                    → LIBRARY
   ```

   LIBRARY: add the E2E exemption to TEST-PLAN §2 and stop Mode 5.

2. **Index, then open sections only** (Reading Strategy): WF step lists, actors and UCs (`grep -n -E '^#|^\| *[0-9]+ *\||UC-[0-9]+'`); for each UC in a WF, its complete input table (every input with type and required/optional) and exception rows; BDD scenario titles and AC ids (reuse, do not duplicate); the operation rows of the WF's operations — every input with its VO, required/optional and validation (with `Style: http`, the request-body schema); REQ ids and the UCs they cite (transitive REQ → UC → WF mapping); boundary row ids of `test/TEST-MATRIX-UC-*.md` if already generated (reference, never restate).

3. **UX artifacts** (WEB-APP with `ux/`): `WIREFRAMES.md` (component inventory, interactive elements per screen), `INTERACTION-MODEL.md` (states, loading and error states, conditional visibility), `ACCESSIBILITY-SPEC.md` (keyboard matrix, ARIA mappings).

4. **Field inventory per workflow** (required). For each WF with E2E scenarios, list every field from three sources and cross-reference them — UC input (`UC-003.2`), operation input (`API-001-01.title`), wireframe element (`SCR-002.title`) — with required, type, validation rules and whether it is conditional (table shape in the template).

   Cross-validation:
   - `V-FIELD-01` (ERROR): every required input of the operation appears in the inventory with a UC input source.
   - `V-FIELD-02` (ERROR): every UC input appears in the inventory.
   - `V-FIELD-03` (ERROR): every data-entry element of the wireframe (buttons excluded) appears in the inventory.
   - `V-FIELD-04` (WARN): in UC/operation but not in the wireframe → `MISSING-UI` for user review.
   - `V-FIELD-05` (WARN): in the wireframe but not in UC/operation → `UI-ONLY`, may need an interaction step.

   An ERROR is a spec inconsistency: show the table and ask the user to resolve it before generating that workflow's scenarios (station or non-interactive run: § Readiness Gates, "Asking without a human" — the affected WF is skipped and recorded as a gap; other WFs continue).

5. **Field behavioral matrix** (required). Per field: VALID (happy value → positive behaviour), EMPTY (required left blank → validation error or blocked submit), INVALID (wrong type/format/value → validation error), BOUNDARY (edge values; reuse the matrix rows), CONDITIONAL (visibility/value changes triggered by other fields). Every required field has at least VALID + EMPTY; every field with validation rules at least one INVALID; every conditional field a CONDITIONAL behaviour per trigger value; interaction chains (selecting X loads Y) are documented.

6. **Scenarios, driven by the behavioral matrix** (not by a narrative walkthrough):
   - a. **Happy path (P0):** one step per inventory field with VALID values in presentation order, then submit and assert the postcondition. A field without a step makes the scenario incomplete.
   - b. **Required-field validation (P0):** per required field, leave it empty with all others valid and submit; assert the UC exception row's error code and its catalog message (HTTP 400 only with `Style: http`). One variation table.
   - c. **Invalid values (P1):** per INVALID behaviour, same pattern; one variation table.
   - d. **Conditional behaviour (P1):** changing the trigger shows/hides/resets the dependent fields, including reset of already-filled conditional fields.
   - e. **Field interactions (P1):** each interaction chain end to end.
   - f. **UC exception flows (P1/P2):** one row per exception row of the constituent UCs — business errors, in addition to field validation.
   - g. **Accessibility (WEB-APP):** axe-core scan at each major navigation step; keyboard-only completion (tab through all fields, submit with Enter).
   - h. **Detail by tier:** Smoke (P0) and Critical (P1) in full (steps or variation tables); Full tier (P2) as a one-line list (id · given · action · expected · refs). BOUNDARY variations cite the matrix row (`TEST-MATRIX-UC-001 T14`) and keep only boundaries that change the journey. Assertion cells ≤ 100 chars; payloads and fixtures go to a shared `Fixtures` line, referenced by name.

7. **Field coverage verification** (required, after generation). Per field: happy-path step, empty variation, invalid variation, conditional scenario, interaction scenario → status. A required field without happy step + empty variation, a validated field without an invalid variation, or a conditional field without a conditional scenario is `INCOMPLETE`; for each, ask the user whether to add the scenario or record an exemption with its justification.

8. **Transitive coverage:** map each scenario to its REQs (`E2E-WF-001-01 → WF-001 → {UC-003, UC-004} → {REQ-F-010, REQ-F-011}`). A REQ with no E2E scenario is `EXEMPT-NFR` (a REQ-NF or REQ-C covered by performance, security or static tests) or `GAP` (review). A REQ-F is never exempt while `visual_evidence` is on (step 9); `EXEMPT-BACKEND` exists only with `visual_evidence: off`.

9. **Visual evidence per criterion** (§ Visual Evidence). List every criterion of every REQ-F: the BDD scenarios tagged `[REQ-F-NNN ACn]` and the REQ-F criteria no scenario covers. A criterion whose THEN starts with the marker `the user sees` / `el usuario ve` (fixed with the customer in `requirements/REQUIREMENTS.md`) states a visible result: the literal after the marker is the text its E2E asserts on screen, so quote it in the `Assertion` cell. Give each criterion an E2E scenario or variation that satisfies the three rules below, reusing the scenarios of steps 6-8 where they already reach the screen; a criterion left without one is a `MISSING-E2E` gap with the AC id as its spec element. Then add the `smoke-deploy` tier (2-3 `@smoke-deploy` journeys, template § Tiered Execution) when the SDD Stack Profile has a `staging_url`; without one, write the tier with `Target environment: none` and no scenarios.

10. **Write `test/E2E-SCENARIOS.md`** — read [references/e2e-template.md](references/e2e-template.md) first. Budget ≤ 15 000 chars for one user-facing WF, +3 000 per additional WF.

---

## Test Naming (scenario ids)

Every planned test carries the scenario it verifies in its name, because `sdd accept` binds JUnit results to acceptance criteria by that id and ignores file-level `Refs:` (a file-level ref would mark every criterion of the file as verified). The name contains `AC-NNN-NN` (BDD scenario) or, for a requirement criterion without a scenario (measured NFR, constraint check), `REQ-X-NNN ACn`: `it("AC-001-03 rejects an empty title with exit 2")`, `test_AC_001_03_rejects_empty_title`, `test "REQ-NF-001 AC1 list p95 under 200 ms"`. Matrix rows and E2E scenarios therefore cite at least one scenario id in their `Refs` column; a row that verifies no criterion (derived, harness) says so. The implementer copies the id into the test name (`sdd-task-implementer/references/tdd-workflow.md`).

## Visual Evidence

Every criterion of a REQ-F is shown to the customer with a screenshot, and every user-facing workflow with a video, because `sdd accept` keeps a criterion whose test passes without an image `unshown` (not VERIFIED) while `visual_evidence` is `required`, the default of the SDD Stack Profile. A green test that never reached the screen is the defect this rule catches: a heading nobody wired, a list that renders from a mock. The E2E scenario that proves a criterion:

1. **Enters through the user's route**: it starts where the user starts (entry screen, login) and navigates as they do. Seeding fixtures is fine; deep-linking into internal state or calling the operation directly skips the wiring under test.
2. **Asserts the criterion's example text**: the literal title, label, message or value of the criterion's THEN (`the user sees …`), with a text assertion (`toHaveText` / `toContainText` in Playwright). That a container is visible proves nothing about what it shows. The `Assertion` cell of the template quotes the expected text.
3. **Saves its screenshot** as `evidencias/FASE-{N}/{AC-NNN-NN}.png` (`REQ-F-NNN-ACn.png` for a criterion without a scenario) and attaches it to the test, so the JUnit report carries the path. One video per user-facing workflow records the happy-path journey, with the `WF-NNN` in its file name (`evidencias/FASE-{N}/WF-NNN-….webm`) and in the test title: `sdd gate --fase N` asks for a video per WF of the FASE's `Workflows:` header line (written by `sdd-plan-architect`; without it, per WF cited in its `## Demo`) and finds it by that id.

The template's `Evidence` column names each file; `evidencias/` is the Stack Profile's `evidence_dir` (default), `{N}` is the FASE the plan later assigns, and the runner configuration that captures belongs to `sdd-task-implementer`. With `visual_evidence: off` (a project without an interface, decided by a person) the rule, step 9 of Mode 5 and the `D-T-E2E` row are omitted and §3 says so. Without specifications this stage does not run; the FASE journey task of `sdd-task-generator` carries the same rules, with one video named `FASE-N` when the FASE names no workflow.

## Observable Outcomes, Not Transport

Expected results are domain error codes (`E_TITLE_EMPTY`) and what the user or caller observes: message shown, accessible role/name, state after reload or restart, exit code for a CLI. An HTTP status, route or redirect is expected only when the contract declares `Style: http` (pre-4.3 contracts with `Method | Path` columns count as http); with `Style: operations` transport lives in `design/OPERATION-MAPPING.md` and is never a test oracle, except a URL a REQ mandates. Every test traces to a spec element and stays independent of other tests (no shared mutable state, no ordering).

**Next step:** `sdd-plan-architect` (reads TEST-PLAN §5 targets by use case and §9 design requirements).

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["test-planner"].status` = `"done"`
3. Set `stages["test-planner"].lastRun` = current ISO-8601
4. Set `stages["test-planner"].summary`:
   - `artifacts`: list of files created in `test/` with labels (e.g., `{"file": "test/TEST-PLAN.md", "label": "Test Strategy"}`)
   - `metrics`: `{ "bdd_scenarios": N, "test_matrices": N, "matrix_cases": N, "perf_scenarios": N, "e2e_scenarios": N, "e2e_fields_total": N, "e2e_fields_complete": N, "e2e_field_coverage_pct": N, "visual_criteria": N, "visual_criteria_covered": N, "smoke_deploy_scenarios": N, "replay_rows": N, "race_rows": N, "invariants_mapped": N, "test_gaps": N, "test_chars": N, "mode": "fanout"|"sequential", "matrix_agents": N }` — `replay_rows` / `race_rows` count the matrix rows of each type (Mode 2, technique e); `visual_criteria` counts the REQ-F criteria that need a screenshot (0 with `visual_evidence: off`) and `visual_criteria_covered` those with a capturing E2E scenario (§ Visual Evidence); `test_chars` is the total of `wc -c test/*.md` (Output Budget); `mode` records whether the matrices were generated in parallel subagents and `matrix_agents` how many were launched (0 in sequential mode). When `mode` is `sequential` above the threshold, the first `summary.highlights` entry states why
   - `highlights`: top 3-5 notable observations (e.g., "101 BDD scenarios cover 85% of requirements", "3 gaps in NFR testing", "TEST-MATRIX-UC-006 at 9 800 chars, over budget")
   - `nextStep`: `"Run /sdd-plan-architect"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Commit the files this run wrote: `git add test/`, then `docs(test-plan): …` with `Refs:` the UC and REQ ids the plan covers, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed).
7. Display summary table to user (console output)
8. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Write the test documents and respond in the user's language; ids and technical terms stay in English.
