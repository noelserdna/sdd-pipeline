# Action Plan Templates — SDD Adoption by Scenario

> Templates de planes de acción para cada uno de los 8 escenarios detectados por `sdd-onboarding`. Cada template se personaliza en la Fase 7 según los hallazgos específicos del proyecto.

---

## 1. Greenfield

**Preconditions:** No code, no docs, or minimal boilerplate only.

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-setup` | Initialize pipeline state | — | `pipeline-state.json` | — | S | 5/100 |
| 2 | `sdd-requirements-engineer` | Elicit and document requirements | User input | `requirements/` | — | M-L | 25/100 |
| 3 | `sdd-specifications-engineer` | Generate full specification suite | `requirements/` | `spec/` | — | L | 45/100 |
| 4 | `sdd-spec-auditor` | Audit + fix spec quality | `spec/` | `audits/`, corrected `spec/` | — | M | 50/100 |
| 5 | `sdd-test-planner` | Create test plan and matrices | `spec/`, `audits/` | `test/` | — | M | 60/100 |
| 6 | `sdd-plan-architect` | Architecture and implementation plan | `spec/`, `audits/`, `test/` | `plan/` | — | L | 75/100 |
| 7 | `sdd-task-generator` | Generate implementation tasks | `plan/` | `task/` | — | M | 80/100 |
| 8 | `sdd-task-implementer` | Implement code and tests | `task/`, `spec/`, `plan/` | `src/`, `tests/` | — | XL | 95/100 |

**Total effort:** XL
**Risk factors:** Requirements elicitation quality is the primary risk. Recommend iterative refinement.

---

## 2. Brownfield Bare

**Preconditions:** Code exists but no documentation, no tests (or minimal).

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-setup` | Initialize pipeline state | — | `pipeline-state.json` | — | S | 5/100 |
| 2 | `sdd-reverse-engineer` | Extract SDD artifacts from code | `src/` | `requirements/`, `spec/`, `test/`, `plan/`, `task/`, `findings/` | Existing code structure, patterns | XL | 55/100 |
| 3 | `sdd-spec-auditor` | Audit generated specs | `spec/` | `audits/`, corrected `spec/` | — | M | 60/100 |
| 4 | `sdd-test-planner` | Enhance test plan | `spec/`, `audits/` | updated `test/` | Existing tests (if any) | M | 70/100 |
| 5 | `sdd-plan-architect` | Validate/enhance architecture plan | `spec/`, `audits/`, `test/` | updated `plan/` | Existing architecture | M | 78/100 |
| 6 | `sdd-security-auditor` | Security assessment | `spec/`, `src/` | `audits/SECURITY-AUDIT-BASELINE.md` | — | M | 82/100 |
| 7 | Review findings | Address dead code, tech debt, workarounds | `findings/` | Cleanup tasks | — | L | 90/100 |

**Total effort:** XL
**Risk factors:** Reverse engineering accuracy depends on code quality. Inferred requirements need validation.
**Leverage points:** ORM schemas → domain model, routes → API contracts, test names → use cases.

---

## 3. SDD Drift

**Preconditions:** SDD artifacts exist, code exists, but they have diverged.

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-reconcile` | Detect and resolve drift | `spec/`, `requirements/`, `src/` | `reconciliation/`, updated `spec/`, `requirements/` | Both specs and code exist | L | 65/100 |
| 2 | `sdd-spec-auditor` | Re-audit reconciled specs | `spec/` | `audits/` | Previous audit baseline | M | 72/100 |
| 3 | `sdd-test-planner` | Update test plan for changes | `spec/`, `audits/` | updated `test/` | Existing test plan | M | 80/100 |
| 4 | `sdd-traceability-check` | Verify full traceability chain | All artifacts | Report | — | S | 82/100 |
| 5 | `sdd-plan-architect` | Update architecture if needed | `spec/`, `audits/`, `test/` | updated `plan/` | Existing plan | M | 88/100 |
| 6 | `sdd-task-generator` | Generate tasks for gaps | `plan/` | `task/` | — | S | 92/100 |

**Total effort:** L-XL
**Risk factors:** Behavioral changes may require user decision. Extensive drift may approach brownfield effort.
**Leverage points:** Existing SDD artifacts provide strong foundation — only deltas need work.

---

## 4. Partial SDD

**Preconditions:** Some SDD artifacts exist but pipeline is incomplete (e.g., requirements done but no specs).

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | Identify gap | Determine where pipeline stopped | `pipeline-state.json` | Gap analysis | — | S | {current}/100 |
| 2 | Resume from gap | Run next pending skill in pipeline | Previous stage outputs | Next stage outputs | All completed stages | M-L | +15-20 pts |
| 3 | Continue pipeline | Run remaining skills sequentially | Each stage feeds next | Full artifact suite | — | Varies | Incremental |
| 4 | `sdd-traceability-check` | Verify chain integrity | All artifacts | Report | — | S | +3-5 pts |

**Total effort:** M-L (depends on gap size)
**Risk factors:** Partial artifacts may have drifted from code since last pipeline run. Consider reconcile if code changed.
**Leverage points:** Maximum leverage — completed stages are reused entirely.

**Note:** The specific skills in steps 2-3 depend on where the pipeline stopped. The onboarding report specifies the exact sequence.

---

## 5. Brownfield with Docs

**Preconditions:** Code exists with non-SDD documentation (OpenAPI, Jira exports, markdown docs, etc.).

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-setup` | Initialize pipeline state | — | `pipeline-state.json` | — | S | 5/100 |
| 2 | `sdd-import` | Convert existing docs to SDD format | External docs | `requirements/`, `spec/` (partial) | OpenAPI→contracts, Jira→requirements | M | 30/100 |
| 3 | `sdd-reverse-engineer` | Fill gaps from code analysis | `src/`, imported artifacts | Complete `requirements/`, `spec/`, `test/`, `plan/`, `task/` | Imported artifacts as starting point | L | 55/100 |
| 4 | `sdd-reconcile --dry-run` | Verify imported+reverse-engineered match code | `spec/`, `src/` | Divergence report | — | M | 60/100 |
| 5 | `sdd-spec-auditor` | Audit and fix merged specs | `spec/` | `audits/`, corrected `spec/` | — | M | 68/100 |
| 6 | `sdd-test-planner` | Create comprehensive test plan | `spec/`, `audits/` | `test/` | Existing tests | M | 78/100 |
| 7 | `sdd-plan-architect` | Architecture plan | `spec/`, `audits/`, `test/` | `plan/` | Existing architecture docs | M | 85/100 |
| 8 | `sdd-traceability-check` | Verify full chain | All artifacts | Report | — | S | 88/100 |

**Total effort:** XL
**Risk factors:** Import quality varies by source format. Multiple sources may conflict.
**Leverage points:** OpenAPI → API contracts (high fidelity), Jira epics → requirement groups, DB schemas → domain model, existing diagrams → architecture.

---

## 6. Tests-as-Spec

**Preconditions:** Good test suite exists, poor or no documentation.

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-setup` | Initialize pipeline state | — | `pipeline-state.json` | — | S | 5/100 |
| 2 | `sdd-reverse-engineer --scope=tests` | Extract specs from tests first | `tests/`, `src/` | `requirements/`, `spec/`, `test/`, `plan/`, `task/` | Test descriptions → use cases, assertions → invariants | L | 60/100 |
| 3 | `sdd-spec-auditor` | Audit test-derived specs | `spec/` | `audits/`, corrected `spec/` | — | M | 67/100 |
| 4 | `sdd-test-planner` | Formalize test plan from existing tests | `spec/`, `audits/` | `test/` | Existing test structure maps directly | M | 78/100 |
| 5 | `sdd-plan-architect` | Architecture plan | `spec/`, `audits/`, `test/` | `plan/` | — | M | 85/100 |
| 6 | `sdd-traceability-check` | Verify chain | All artifacts | Report | — | S | 90/100 |

**Total effort:** L
**Risk factors:** Tests may not cover all requirements. Untested code paths need attention.
**Leverage points:** Test descriptions → use case names, assertions → invariants/business rules, test structure → requirement grouping, mocks → external dependency contracts.

---

## 7. Multi-team

**Preconditions:** Monorepo or microservices with different modules in different states.

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-setup` | Initialize pipeline state | — | `pipeline-state.json` | — | S | 5/100 |
| 2 | Per-module assessment | Run `sdd-onboarding --quick` per module/service | Each module | Per-module reports | — | M | 10/100 |
| 3 | Prioritize modules | Rank modules by business criticality and effort | Module reports | Adoption roadmap | — | S | 12/100 |
| 4 | Module 1: Apply scenario template | Run appropriate plan for highest-priority module | Varies by module scenario | Module 1 artifacts | — | L-XL | 30-40/100 |
| 5 | Module 2+: Repeat | Apply appropriate plan per module | Varies | Per-module artifacts | Cross-module patterns | L per module | Incremental |
| 6 | Cross-module integration | `sdd-traceability-check` across modules | All artifacts | Integration report | — | M | +5-10 pts |

**Total effort:** XL (scales with module count)
**Risk factors:** Cross-module dependencies may cause cascading changes. Team coordination needed.
**Leverage points:** Shared libraries/contracts between modules. First module sets patterns for others.

---

## 8. Fork/Migration

**Preconditions:** Project is forked or migrated from another codebase.

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | `sdd-setup` | Initialize pipeline state | — | `pipeline-state.json` | — | S | 5/100 |
| 2 | Upstream assessment | Analyze upstream project for reusable artifacts | Upstream repo/docs | Assessment notes | Upstream docs/specs | S | 8/100 |
| 3 | `sdd-import` (if upstream has docs) | Import upstream documentation | Upstream docs | `requirements/`, `spec/` (partial) | Upstream artifacts | M | 25/100 |
| 4 | Delta analysis | Identify what changed from upstream | `git diff upstream...HEAD` | Change inventory | — | M | 28/100 |
| 5 | `sdd-reverse-engineer --scope=delta` | Document delta changes | Changed files | Delta requirements, specs | Upstream as baseline | L | 50/100 |
| 6 | `sdd-spec-auditor` | Audit combined specs | `spec/` | `audits/` | — | M | 58/100 |
| 7 | Continue standard pipeline | test-planner → plan-architect → tasks | Previous outputs | Full artifact suite | — | L | 85/100 |

**Total effort:** L-XL (depends on delta size)
**Risk factors:** Upstream changes may invalidate local specs. Need clear boundary between upstream and local.
**Leverage points:** Upstream documentation, upstream test suites, upstream architecture.

---

## 9. Health Score Estimation Formulas

### Per-Step Health Score Calculation

```
health_after_step = health_before + step_contribution

step_contribution depends on:
  - artifacts_generated: number of SDD artifact types produced
  - coverage_increase: percentage of codebase now covered by SDD
  - quality_factor: audit pass rate, traceability completeness
```

### Standard Contributions by Artifact Type

| Artifact | Contribution |
|----------|-------------|
| `pipeline-state.json` | +5 |
| `requirements/` (complete) | +20 |
| `spec/` (complete) | +20 |
| `audits/` (passed) | +5 |
| `test/` (complete) | +15 |
| `plan/` (complete) | +15 |
| `task/` (complete) | +5 |
| Full traceability chain verified | +10 |
| Security audit passed | +5 |

### Leverage Discount

When existing assets are leveraged (import, reverse-engineer), the effort estimate is reduced:

| Leverage Type | Effort Reduction |
|--------------|-----------------|
| OpenAPI → API contracts | -30% of spec effort |
| Jira export → requirements | -40% of requirements effort |
| DB schema → domain model | -20% of spec effort |
| Test suite → test plan | -50% of test plan effort |
| Existing architecture docs → plan | -30% of plan effort |
| Upstream fork docs → all | -20-50% depending on delta size |
