# E2E-SCENARIOS.md template (sdd-test-planner Mode 5, step 10)

Write `test/E2E-SCENARIOS.md` with this shape. Keep only the sections of the detected project type: WEB-APP (with or
without `ux/`) uses the WF sections; API-ONLY uses "Scenarios for API-ONLY projects" instead of the WF scenario
sections; CLI uses the WF sections with a command in `Action` and stdout/stderr/exit code in `Assertion`, no
viewport matrix, no locators and no axe-core rows. Smoke and Critical tiers in full, Full tier as a list.

Every scenario and variation cites the acceptance scenarios it proves (`AC-NNN-NN`, or `REQ-X-NNN ACn`) in its
`Acceptance` line or `Spec Ref` cell, and the implemented test title carries the E2E id followed by those ids —
`test("E2E-WF-001-01 AC-001-01 AC-002-01 create a task and see it listed", …)` — because `sdd accept` binds results to
criteria only through ids in the test name. A step or row that proves no criterion (navigation, fixture) needs none.

A row that proves a REQ-F criterion quotes the criterion's example text in `Assertion` (`heading "Mis tareas"`,
`row 1 = "Comprar leche"`), never only "visible", and names its screenshot in `Evidence` (`AC-001-01.png`, stored under
`evidencias/FASE-{N}/`); the rules are SKILL.md § Visual Evidence. With `visual_evidence: off` drop the `Evidence`
columns.

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
| Visual evidence | screenshot per REQ-F criterion `evidencias/FASE-{N}/{AC id}.png`, video per user-facing WF with `WF-{NNN}` in its name and in the journey's title · or `off` (Stack Profile) |
| Target environment | local build for PR tiers · `{staging_url}` for `smoke-deploy` · or `none` |

### Tiered Execution

| Tier | Scenarios | Run time | Trigger |
|------|-----------|----------|---------|
| Smoke | P0 happy paths only | < 2 min | Every PR |
| Critical | P0 + P1 paths | < 10 min | Every merge to main |
| Full | All E2E scenarios | < 30 min | Nightly / release |
| smoke-deploy | 2-3 `@smoke-deploy` journeys (below) | < 3 min | post-deploy, against the target environment |

The `smoke-deploy` tier proves that the deployed increment works, not that the code does: real login with the smoke
user, the central write of the product, and one path through each external integration (payment, email, storage).
Its data is idempotent, so a rerun on the same environment neither piles up records nor depends on the previous run
(fixed smoke account, a record it creates and deletes, or an upsert on a known key). Test titles carry
`@smoke-deploy`, a tag of its own because `@smoke` is the PR tier and runs on a local build; the Stack Profile's
`smoke` command selects `@smoke-deploy` and the CI template `sdd-smoke` runs it with `SMOKE_BASE_URL`. Without a `staging_url` in the Stack Profile, keep the row
with `Target environment: none` and write no scenarios.

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
- **Acceptance:** AC-{NNN}-01, AC-{NNN}-01 (test title: `E2E-WF-{NNN}-01 AC-{NNN}-01 AC-{NNN}-01 {title}`)
- **Requirements (transitive):** REQ-F-{NNN}, REQ-F-{NNN}
- **Priority:** P0
- **Tier:** smoke
- **Auth fixture:** {authenticated | admin | unauthenticated}
- **Fields covered:** ALL ({N} fields from inventory)
- **Video:** `evidencias/FASE-{N}/WF-{NNN}-….webm` (the whole journey; the WF id in the test title names it)

#### Elements Referenced (when ux/ exists)

| Element | Locator hint | Source |
|---------|-------------|--------|
| {name} | getByRole("{role}", { name: /{pattern}/i }) | WIREFRAMES §SCR-{NNN} |
| {name} | getByLabel("{label}") | WIREFRAMES §SCR-{NNN} |

#### Steps

> One step per field in inventory, in wireframe presentation order. No field may be skipped.

| # | Action | Target | Assertion (expected text) | Evidence | Spec Ref |
|---|--------|--------|---------------------------|----------|----------|
| 1 | Open the entry screen {url} as the user does | — | Page title = "{title}" | — | WF-{NNN} step 1 |
| 2 | axe-core scan | full page | No violations | — | ACCESSIBILITY-SPEC |
| 3 | Fill/Select {field1} | {element} | Field accepts input, {interaction effect if any} | — | UC-{NNN} §main.{N} |
| 4 | Fill/Select {field2} | {element} | Field accepts input, {conditional fields appear if applicable} | — | UC-{NNN} §main.{N} |
| ... | (one step per field from inventory) | ... | ... | ... | ... |
| N | Click submit | {button} | {role} has text "{literal from the criterion}" | AC-{NNN}-01.png | UC-{NNN} §main.{N}, AC-{NNN}-01 |
| N+1 | Assert final state | — | {postcondition with its literal values} | AC-{NNN}-02.png | WF-{NNN} postcondition, AC-{NNN}-02 |

### E2E-WF-{NNN} — Required-Field Validation (P0)

> One variation per required field. All other fields filled with valid values.

| Variant ID | Empty field | Other fields | Action | Expected behavior | Evidence | Spec Ref |
|------------|-------------|-------------|--------|-------------------|----------|----------|
| E2E-WF-{NNN}-V01 | {field1} | All valid | Submit | `{E_CODE}`: "{message the criterion quotes}" next to {field1}; state unchanged | AC-{NNN}-{NN}.png | UC-{NNN} E{N}, AC-{NNN}-{NN} |
| E2E-WF-{NNN}-V02 | {field2} | All valid | Submit | `{E_CODE}` shown next to {field2}; state unchanged | AC-{NNN}-{NN}.png | UC-{NNN} E{N}, AC-{NNN}-{NN} |

### E2E-WF-{NNN} — Invalid-Value Scenarios (P1)

> One variation per field with validation rules. All other fields filled with valid values.

| Variant ID | Field | Invalid value | Other fields | Expected behavior | Evidence | Spec Ref |
|------------|-------|---------------|-------------|-------------------|----------|----------|
| E2E-WF-{NNN}-IV01 | {field} | {invalid value} | All valid | `{E_CODE}` shown; state unchanged | AC-{NNN}-{NN}.png | UC-{NNN} E{N}, AC-{NNN}-{NN} |

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

| Variant ID | Diverges at step | Input change | Expected behavior | Evidence | Spec Ref |
|------------|------------------|-------------|-------------------|----------|----------|
| E2E-WF-{NNN}-EX01 | Step {N} | {precondition not met} | {error code → message shown or fallback; state unchanged} | AC-{NNN}-{NN}.png | UC-{NNN} E{N}, AC-{NNN}-{NN} |

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

### smoke-deploy (@smoke-deploy) — list only

| Scenario ID | Journey | Idempotent data | Assertion (expected text) | Spec Ref |
|-------------|---------|-----------------|---------------------------|----------|
| E2E-SMOKE-01 | real login with the smoke user | fixed account `{smoke user}` | "{text of the landing screen}" | AC-{NNN}-{NN} |
| E2E-SMOKE-02 | central write, then read it back | creates and deletes `{marker record}` | "{text of the created record}" | AC-{NNN}-{NN} |
| E2E-SMOKE-03 | path through {external integration} | {sandbox key / known record} | "{text that proves the round trip}" | AC-{NNN}-{NN}, REQ-C-{NNN} |

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
| REQ-F-{NNN} | UI-effect | E2E-WF-{NNN}-EX02 (admin list shows the result) | — |
| REQ-F-{NNN} | API-only | — | EXEMPT-BACKEND: `visual_evidence: off` only |
| REQ-NF-{NNN} | Perf | — | EXEMPT-NFR: covered by PERF-SCENARIOS.md |
| REQ-F-{NNN} | UI-func | — | GAP: needs WF or E2E scenario |
````
