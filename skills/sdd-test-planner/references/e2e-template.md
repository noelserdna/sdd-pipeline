# E2E-SCENARIOS.md template (sdd-test-planner Mode 5, step 9)

Write `test/E2E-SCENARIOS.md` with this shape. Keep only the sections of the detected project type: WEB-APP (with or
without `ux/`) uses the WF sections; API-ONLY uses "Scenarios for API-ONLY projects" instead of the WF scenario
sections; CLI uses the WF sections with a command in `Action` and stdout/stderr/exit code in `Assertion`, no
viewport matrix, no locators and no axe-core rows. Smoke and Critical tiers in full, Full tier as a list.

````markdown
# E2E Acceptance Scenarios

> **Project:** {project name}
> **Project type:** {WEB-APP | API-ONLY | CLI}
> **Generated from:** spec/workflows/, spec/use-cases/, spec/contracts/
> **UX enrichment:** {Yes — from ux/ | No — abstract scenarios}

## E2E Strategy

| Dimension | Value |
|-----------|-------|
| Framework | {E2E runner from the SDD Stack Profile; Playwright recommended for WEB-APP} |
| Selector strategy | getByRole > getByLabel > getByText > getByTestId (fallback) |
| Auth strategy | storageState reuse (1 login test, others reuse state) |
| Data strategy | {transaction-rollback | snapshot-restore | unique-per-test} |
| Accessibility | axe-core scan at each navigation (WCAG 2.2 AA) |
| Parallelism | {runner sharding across N workers} |

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

> Cross-referenced from: UC-{NNN} inputs, API-{NNN}-{NN} operation input, WIREFRAMES §SCR-{NNN}

| Field | UC input | Operation input | Wireframe element | Required | Type | Validation rules | Conditional? |
|-------|----------|-----------------|-------------------|----------|------|-----------------|--------------|
| {field1} | UC-{NNN}.1 | API-{NNN}-{NN}.{f1} | {element desc} | Yes | {type} | {rules} | No |
| {field2} | UC-{NNN}.2 | API-{NNN}-{NN}.{f2} | {element desc} | Yes | {type} | {rules} | Yes: when {trigger} |
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
- **Requirements (transitive):** REQ-F-{NNN}, REQ-F-{NNN}
- **Priority:** P0
- **Tier:** smoke
- **Auth fixture:** {authenticated | admin | unauthenticated}
- **Fields covered:** ALL ({N} fields from inventory)

#### Elements Referenced (when ux/ exists)

| Element | Locator hint | Source |
|---------|-------------|--------|
| {name} | getByRole("{role}", { name: /{pattern}/i }) | WIREFRAMES §SCR-{NNN} |
| {name} | getByLabel("{label}") | WIREFRAMES §SCR-{NNN} |

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
| E2E-WF-{NNN}-V01 | {field1} | All valid | Submit | `{E_CODE}` shown next to {field1}; state unchanged | UC-{NNN} E{N}, AC-{NNN}-{NN} |
| E2E-WF-{NNN}-V02 | {field2} | All valid | Submit | `{E_CODE}` shown next to {field2}; state unchanged | UC-{NNN} E{N}, AC-{NNN}-{NN} |

### E2E-WF-{NNN} — Invalid-Value Scenarios (P1)

> One variation per field with validation rules. All other fields filled with valid values.

| Variant ID | Field | Invalid value | Other fields | Expected behavior | Spec Ref |
|------------|-------|---------------|-------------|-------------------|----------|
| E2E-WF-{NNN}-IV01 | {field} | {invalid value} | All valid | `{E_CODE}` shown; state unchanged | UC-{NNN} E{N}, AC-{NNN}-{NN} |

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
| E2E-WF-{NNN}-EX01 | Step {N} | {precondition not met} | {error code → message shown or fallback; state unchanged} | UC-{NNN} E{N} |

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

> Post-generation completeness check (SKILL.md Mode 5 step 7).

### WF-{NNN}

| Field | Happy path step? | Empty variation? | Invalid variation? | Conditional tested? | Interaction tested? | Status |
|-------|-----------------|------------------|-------------------|--------------------|--------------------|--------|
| {field1} | Step {N} ✅ | V01 ✅ | IV01 ✅ | N/A | FI01 ✅ | COMPLETE |
| {field2} | Step {N} ✅ | V02 ✅ | N/A | CD01 ✅ | N/A | COMPLETE |

Status rules: SKILL.md Mode 5 step 7.

---

## Scenarios for API-ONLY projects

### E2E-API-{NNN}-01: {Workflow title} — Happy Path

- **Workflow:** WF-{NNN}
- **Use Cases:** UC-{NNN}, UC-{NNN}
- **Type:** API E2E (no browser)

#### Request Body Field Inventory

| Field | Required | Type | Validation | Source |
|-------|----------|------|-----------|--------|
| {field1} | Yes | {type} | {rules} | API-{NNN}-{NN}, UC-{NNN} |

#### Steps

| # | Method | Endpoint | Body/Params | Assert status | Assert body | Spec Ref |
|---|--------|----------|-------------|---------------|-------------|----------|
| 1 | POST | /api/{resource} | {ALL required fields} | 201 | {schema} | API-{NNN}-01 |
| 2 | GET | /api/{resource}/{id} | — | 200 | {all fields present} | API-{NNN}-02 |

#### Required-Field Validation (API)

| Variant | Missing field | Assert status | Assert body | Spec Ref |
|---------|--------------|---------------|-------------|----------|
| E2E-API-{NNN}-V01 | {field1} | 400 | error code `{E_CODE}` for {field1} | API-{NNN}-{NN}, Errors table |

#### Invalid-Value Validation (API)

| Variant | Field | Invalid value | Assert status | Assert body | Spec Ref |
|---------|-------|---------------|---------------|-------------|----------|
| E2E-API-{NNN}-IV01 | {field1} | {invalid} | 400/422 | error code `{E_CODE}` | API-{NNN}-{NN}, Errors table |

---

## Coverage Matrix

| REQ ID | Type | E2E Coverage | Justification if excluded |
|--------|------|-------------|---------------------------|
| REQ-F-{NNN} | UI-func | E2E-WF-{NNN}-01 + {N} variations | — |
| REQ-F-{NNN} | API-only | — | EXEMPT-BACKEND: no user-facing flow |
| REQ-NF-{NNN} | Perf | — | EXEMPT-NFR: covered by PERF-SCENARIOS.md |
| REQ-F-{NNN} | UI-func | — | GAP: needs WF or E2E scenario |
````
