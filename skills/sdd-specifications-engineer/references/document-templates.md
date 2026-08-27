# Specification Document Templates

> Each template is the **maximum** shape of a document, not a form to fill in. Omit optional sections that would be empty; write `None.` (one line, no justification) for a mandatory section that is legitimately empty; cite IDs instead of restating facts. Per-artifact budgets: SKILL.md § Output Budget.

## 0. Writing rules (apply to every template)

| # | Rule |
|---|---|
| W1 | **One home per fact.** Requirement text → `requirements/REQUIREMENTS.md`. Terms → `domain/01-GLOSSARY.md`. Shared values → `VALUE-REGISTRY.md`. Error code → message → class → HTTP/exit → error catalog in `domain/03-VALUE-OBJECTS.md`. Rules → `domain/05-INVARIANTS.md` (INV) and `CLARIFICATIONS.md` (RN). Given/When/Then → `tests/BDD-UC-NNN.md` (AC-NNN-NN ids are *defined* there). Decisions → `adr/`. Every other document cites the ID. |
| W2 | **ID + at most one clause.** `REQ-F-001 (create task)` is the maximum context. Never copy a requirement statement or its acceptance criteria into a UC, contract, ADR, BDD or matrix. |
| W3 | **Table or list, never prose repeating it.** A TypeScript/YAML schema block replaces an attribute table. A transitions table replaces a state diagram unless the machine has more than 5 states. |
| W4 | **Empty = `None.`** Mandatory section: `None.`; optional section: omit the heading. Never explain why something does not apply — the justification, if one exists, is an ADR/RN id in `Refs`. |
| W5 | **`Refs` once.** One `Refs` row in the header of each document holds all traceability ids (REQ, UC, WF, API, INV, RN, ADR, BDD, PROP). No trailing "Traceability" section; no separate "Business rules" / "Invariants" / "Related" lists. Ids are also cited inline exactly where they apply. |
| W6 | **No narrative sections.** No "Description" longer than 2 sentences, no "Implementation notes", "UI/UX notes", "Notes", "Rationale", "Evolution", "Prevention", "Interface notes". Rationale is an ADR; a rule is an RN/INV. |
| W7 | **Boilerplate once per file, not per item.** Auth, rate limit, version: once per contract. Actors: one header row per UC (no per-actor responsibility table). Standard errors: one table per contract with an "Operations" column, not one table per endpoint. Exceptions shared by every UC (global error handler, storage failure): specified once in the workflow or contract, cited by id in the UC. |
| W8 | **Error rows cite the code.** UC/contract/BDD rows carry `E_CODE` + HTTP/exit + condition; message text, class and description live only in the error catalog. Quote a literal message only where a REQ acceptance criterion quotes it. |
| W9 | **Write each file once.** Plan ids, invariants and exception rows before writing; never patch an already-written file to add a cross-reference. |

---

## Template 1: SRS Document (monolithic — only when the user explicitly chooses it over the modular `spec/` layout)

````markdown
# SRS — [Project]

| Field | Value |
|---|---|
| Version / Date / Status | X.Y / YYYY-MM-DD / Draft |
| Refs | requirements/REQUIREMENTS.md vX |

## 1. Scope
[≤ 5 lines: product, in/out of scope]

## 2. Context
| Aspect | Value |
|---|---|
| Users | [class → privileges] |
| Environment | [OS, runtime, integrations] |
| Constraints | REQ-C-NNN, … |
| Assumptions | [one line each] |

## 3. Functional specifications
### SPEC-[MOD]-F-001 — [Title]
| Field | Value |
|---|---|
| Refs | REQ-NNN; INV-…; BDD-… |
| Pre / Post | [pre] / [post] |
| Flow | 1. … 2. … 3. … |
| Exceptions | E1 [condition] → `E_CODE` (HTTP) |

## 4. Nonfunctional specifications
| SPEC-ID | Metric | Target | Measurement | Refs |
|---|---|---|---|---|

## 5. Interfaces and data
[API: → contracts/. Data: → domain/. One line each; no copies.]
````

---

## Template 2: Use Case Specification (`use-cases/UC-NNN-{slug}.md`, ≤ 3,500 chars)

````markdown
# UC-NNN — [Name]

| Field | Value |
|---|---|
| Version | 1.0 / YYYY-MM-DD |
| Refs | REQ-F-NNN (primary), REQ-F-NNN; WF-NNN steps 1–5; API-NNN-NN, API-NNN-NN; INV-XXX-NNN, INV-XXX-NNN; RN-NNN; ADR-NNN; BDD-UC-NNN |
| Actors | Primary: [actor]. Secondary: [component / external system], [component] |
| Trigger | [event, one line] |
| Priority / Status | Must / Approved |

[≤ 2 sentences: what the primary actor obtains. Do not restate the REQ.]

## Input / Output

```typescript
interface XxxInput  { field: Type /* VO-NNN, INV-XXX-NNN */; optional?: Type }
interface XxxOutput { field: Type }
```

## Preconditions
1. [state that must hold] (INV-XXX-NNN)

## Postconditions
- Success: [observable state change] (INV-XXX-NNN); [output produced].
- Failure: [what is guaranteed untouched] (INV-XXX-NNN); error per the Exceptions table.

## Main flow
1. [Actor]: [action].
2. System: [validation / state change / response] (RN-NNN, INV-XXX-NNN).
3. …

## Extensions
- 2a. [condition] → [what differs]; resume at 3. (AC-NNN-NN)
- 4a. [condition] → [what differs]. (AC-NNN-NN)

## Exceptions & errors

| # | Step | Condition | Error code | HTTP / exit | Effect | AC |
|---|---|---|---|---|---|---|
| E1 | 2 | [invalid or missing input] | `E_CODE` | 400 | [state unchanged (INV-…)]; [recovery] | AC-NNN-NN |
| E2 | 3 | [authorization denied] | `E_CODE` | 403 | … | AC-NNN-NN |
| E3 | 4 | [dependency failure / timeout] | `E_CODE` | 503 | [retry / abort] | AC-NNN-NN |
| E4 | 4 | [concurrent modification] | `E_CODE` | 409 | [resolution] | AC-NNN-NN |
| E5 | 5 | [precondition no longer holds] | `E_CODE` | 409 | … | AC-NNN-NN |

## Open questions
- NC-NNN: … *(omit the section when there are none)*
````

Rules: main flow ≤ 10 steps, each `Actor: action` or `System: result`. Extensions and exceptions are one line/row each; the `AC` column points to the scenario in `BDD-UC-NNN` that verifies it — no Given/When/Then in the UC. Exception rows are the output of the Error Flow Forcing Function (SKILL.md Step 6a): questions that yield no exception produce **no text**. The `Refs` header row is the traceability section; the `Exceptions & errors` table is both the exception flows and the error list.

---

## Template 3: User Story + BDD (only when the user chooses stories over use cases)

````markdown
# STORY-NNN — [Title]

| Field | Value |
|---|---|
| Story | As a [role] I want [capability] so that [benefit] |
| Refs | REQ-NNN; INV-…; RN-…; BDD-STORY-NNN |
| Priority | Must |
| Depends on | STORY-NNN *(omit if none)* |

Scenarios: `tests/BDD-STORY-NNN.md` (Template 13). Rules: RN-NNN, INV-XXX-NNN (cited, not restated).
````

---

## Template 4: Actor-Action Specification (contractual / regulatory)

````markdown
# Actor-Action Specifications — [Module]

| Refs | REQ-[ids] |
|---|---|

| SPEC-ID | Trigger | Actor | Shall | Condition | Error | Refs |
|---|---|---|---|---|---|---|
| SPEC-[MOD]-F-001 | [event] | [actor] | [action] | [qualifier] | If [cond] → `E_CODE` | REQ-NNN, AC-NNN-NN |
````

---

## Template 5: Traceability Matrix (`TRACEABILITY-MATRIX.md`, ≤ 3,000 chars)

````markdown
# Traceability Matrix

> REQ → spec artifacts. Reverse direction is derivable (every artifact carries `Refs`); artifacts without a REQ are listed in `DERIVED-SPECS.md`.

| REQ | Summary (≤ 6 words) | UC / WF | API | INV | ADR | BDD / PROP | NFR | RN |
|---|---|---|---|---|---|---|---|---|
| REQ-F-001 | create task | UC-001; WF-001 | API-002-02 | INV-TSK-001..006 | ADR-003 | BDD-UC-001; PROP-001 | — | RN-001..005 |

Coverage: N/N requirements specified (100 %). Orphans: none.
````

No reverse table, no per-acceptance-criterion table: each BDD scenario title carries the `[REQ-X ACn]` tag it verifies.

---

## Template 6: Architecture Decision Record (`adr/ADR-NNN-{slug}.md`, Nygard short, ≤ 1,500 chars)

````markdown
# ADR-NNN — [Decision stated as a sentence]

| Field | Value |
|---|---|
| Status | Accepted · YYYY-MM-DD *(Proposed / Deprecated / Superseded by ADR-NNN)* |
| Refs | REQ-…; UC-…; INV-…; RN-… |

## Context
[≤ 5 lines: the forces. Cite ids; do not restate them.]

## Decision
[1–3 sentences, or a numbered list of ≤ 4 items.]

## Alternatives
| Option | Why not |
|---|---|
| [B] | [one clause] |
| [C] | [one clause] |

## Consequences
- + [positive]
- − [negative or accepted risk; mitigation id if any]
````

One ADR per decision actually taken during specification (format, storage, error model, ordering rules…). Decisions that are business rules are RNs in `CLARIFICATIONS.md`, not ADRs. There is no separate decisions log: `CLARIFICATIONS.md` (Template 16) is the log.

---

## Template 7: Nonfunctional Specification (`nfr/*.md`, ≤ 2,500 chars each)

````markdown
# NFR — [Performance | Limits | Security | Observability | Maintainability]

> Refs: REQ-NF-…; values by name from VALUE-REGISTRY.md.

| ID | Metric / Control | Target | Fail point | Measurement / Enforcement | Refs |
|---|---|---|---|---|---|
| SPEC-PERF-001 | p95 latency of [operation] under [load] | < `PERF_P95_LATENCY` | ≥ 200 ms | [how, where] | REQ-NF-001, WF-NNN |
| SPEC-LIM-001 | `TITLE_MAX_LENGTH` | 1000 chars | — | API validation → `E_TITLE_TOO_LONG` | RN-003 |
| SEC-001 | Authentication | Not applicable (ADR-NNN) | — | — | ADR-NNN |
| SEC-002 | Input validation | all arguments validated before I/O | — | API-NNN-NN | INV-… |
````

One table per file. A category that does not apply (auth, encryption, audit…) is **one row** whose Target is `Not applicable (ADR-NNN)` — no paragraph. `LIMITS.md` cites values by registry name; `VALUE-REGISTRY.md` owns the number.

---

## Template 8: Requirements Modification Proposal (Mode 3)

````markdown
# Requirements Modification Proposal — YYYY-MM-DD

Severity: [Critical | Major | Minor]. Trigger: readiness analysis ([N] critical issues / [N] requirements).

| # | Action | REQ | Issue | Proposed text | Rationale |
|---|---|---|---|---|---|
| MOD-001 | Modify | REQ-NNN | [issue] | "[new statement]" | [one clause] |
| ADD-001 | Add | REQ-NEW-001 | [gap] | "[statement]" | [one clause] |
| REM-001 | Remove / merge into REQ-NNN | REQ-NNN | [reason] | — | — |

Impact: scope [±], schedule [±], risk [±] (one line each).
Next: review → apply via `sdd-requirements-engineer` → re-run readiness analysis.
````

---

## Template 9: State Machine (`domain/04-STATES.md`, ≤ 3,500 chars)

````markdown
# 04 — State Machines

## SM-NNN: [Entity]

| State | Initial | Final | Description |
|---|---|---|---|
| [state] | Yes/No | Yes/No | [≤ 8 words] |

| From | To | Trigger | Guard | Action / Events | Timeout |
|---|---|---|---|---|---|
| [from] | [to] | [event] | [condition or —] | [side effect; event name or —] | [duration or —] |

Refs: INV-XXX-NNN, UC-NNN.
````

A Mermaid diagram only when the machine has more than 5 states. Derived-state rules (composite entities) as a third table with `Rule | Priority | Condition | Derived state`.

---

## Template 10: Invariants (`domain/05-INVARIANTS.md`, ≤ 6,000 chars)

````markdown
# 05 — Invariants

> Areas: [TSK, STO, …]. Enforcement points: API | REPO | DB | CLI.

| ID | Rule | Enforced at | UCs | Violation error | Validation |
|---|---|---|---|---|---|
| INV-TSK-001 | `id` unique within a store | API, REPO | UC-001, UC-006 | `E_STORE_INVALID_STRUCTURE` | `new Set(ids).size === ids.length` |
| INV-TSK-003 | `title` trimmed, 1..`TITLE_MAX_LENGTH`, no `\n`/`\r` | CLI, API, REPO | UC-001 | `E_TITLE_*` | see below |

### INV-TSK-003 validation
```typescript
const validTitle = (v: unknown): v is string => typeof v === 'string' && v === v.trim() && v.length >= 1 && v.length <= 1000 && !/[\r\n]/.test(v);
```
```sql
CHECK (length(title) BETWEEN 1 AND 1000)
```
````

One row per invariant; a code block below the table only when the validation does not fit one cell. No summary table plus detail blocks, no "Notes"; the derivation tier is recorded in `DERIVED-SPECS.md`, not here.

---

## Template 11: Workflow (`workflows/WF-NNN-{slug}.md`, ≤ 4,000 chars)

````markdown
# WF-NNN — [Name]

| Field | Value |
|---|---|
| Trigger | [event] |
| Total timeout | `WF_TOTAL_BUDGET` |
| Actors | [who / what] |
| Refs | REQ-…; UC-…; INV-… |

## Steps

| # | Name | Type | Timeout | Retry | Input → Output | On failure | Compensation |
|---|---|---|---|---|---|---|---|
| 1 | [step] | sync/async/manual | [duration] | [n × backoff or —] | [schema ref] → [schema ref] | [abort / skip / retry] | [rollback or —] |

## Error scenarios

| Error | Step | Action | Result state |
|---|---|---|---|
| `E_CODE` | 2 | abort | [state] |

## Events emitted
None. *(or a table: Event | Step | Payload | Consumers)*

## Metrics
| Metric | Target |
|---|---|
| Duration p95 | [value] |
| Success rate | [value] |
````

---

## Template 12: API Contract (`contracts/API-{module}.md`, ≤ 6,000 chars per module)

````markdown
# API-{module}

| Field | Value |
|---|---|
| Base / Version | `/api/v1` · v1 |
| Auth | JWT bearer *(or: Not applicable — in-process calls, ADR-NNN)* |
| Rate limit | `RATE_LIMIT_USER` per user *(or: Not applicable)* |
| Refs | REQ-…; UC-…; ADR-… |
| Errors | catalog in `domain/03-VALUE-OBJECTS.md` § ErrorCode |

## Operations

| ID | Method | Path | Auth | Refs |
|---|---|---|---|---|
| API-NNN-01 | POST | `/tasks` | user | UC-001 |
| API-NNN-02 | GET | `/tasks/{id}` | user | UC-002 |

## API-NNN-01 — [name]

```typescript
// request
{ title: string /* VO-002 */ }
// response 201
{ id: number; title: string; status: TaskStatus; createdAt: string }
```
Behaviour: see UC-001 main flow. Pre/post: INV-TSK-001..006.

## API-NNN-02 — [name]
Path params: `id: number` (VO-001). Query: `status?: TaskStatus` (default: all).
```typescript
// response 200
{ items: Task[] }
```

## Errors

| HTTP | Code | Operations | Condition |
|---|---|---|---|
| 400 | `VALIDATION_ERROR` | 01, 02 | [invalid field] |
| 401 | `UNAUTHORIZED` | all | missing / invalid token |
| 403 | `FORBIDDEN` | 01 | [missing permission] |
| 404 | `NOT_FOUND` | 02 | no resource with `id` |
| 409 | `CONFLICT` | 01 | concurrent modification |
| 429 | `RATE_LIMIT_EXCEEDED` | all | limit exceeded |
````

Rule: 400 if the operation accepts input, 401 if authenticated, 403 if role-restricted, 404 if it addresses a resource by id, 409 on concurrent modification, 429 if rate-limited. Omit rows that do not apply — no justification. Per-operation sections hold only the schema and one behaviour line; a function-level (non-HTTP) contract uses `Signature` instead of `Method/Path` and `exit code` instead of `HTTP`.

---

## Template 13: BDD Scenarios (`tests/BDD-UC-NNN.md`, ≤ 2,500 chars)

````markdown
# BDD-UC-NNN — [Use case name]

> Refs: UC-NNN; REQ-F-NNN; INV-XXX-NNN. Convention: [one line, only if needed — how the system is invoked, what "unchanged" means]

Feature: [name] — As a [actor] I want [capability] so that [benefit]

Background:
  Given [common setup]

Scenario: AC-NNN-01 — [happy path] [REQ-F-NNN AC1]
  Given [precondition]
  When [action]
  Then [outcome]
  And [side effect / state]

Scenario: AC-NNN-02 — [extension 2a]
  When [action]
  Then [outcome]

Scenario: AC-NNN-03 — [exception E1] [REQ-F-NNN AC3]
  When [action]
  Then error `E_CODE` with status 400
  And [state unchanged]

Scenario: AC-NNN-04 — [edge case / invariant INV-XXX-NNN]
  Given [boundary setup]
  When [action]
  Then [outcome]
````

Rules: exactly one scenario per main flow, per extension, per exception row and per edge case; AC ids are defined **here** and cited by the UC. ≤ 6 lines per scenario; the `[REQ-X ACn]` tag marks which requirement acceptance criterion it satisfies. Assert error code + status, not message text (W8). No separate "invariant enforcement" scenario when an exception row already covers that invariant.

---

## Template 14: Value Registry (`VALUE-REGISTRY.md`, ≤ 3,000 chars)

````markdown
# Value Registry

> Canonical source for every value used in 2+ documents. Other documents cite the **name**.

| Name | Value | Unit | Category | Source | Used in (ids) |
|---|---|---|---|---|---|
| `TITLE_MAX_LENGTH` | 1000 | UTF-16 units | limit | RN-003 | INV-TSK-003, UC-001, API-002 |
| `PERF_P95_LATENCY` | 200 | ms | performance | REQ-NF-001 | SPEC-PERF-001, WF-001 |
| `TASK_STATUS` | pending, completed | enum | enum | VO-003 | UC-002, UC-005 |
| `RATE_LIMIT_USER` | 100 | req/min | rate limit | RN-NNN | API-001 |
````

One table (category as a column), ids not file paths in "Used in".

---

## Template 15: Derived Specifications (`DERIVED-SPECS.md`, ≤ 4,000 chars)

````markdown
# Derived Specifications

> Artifacts that do not trace literally to a REQ. Tier 1 = new user-visible behaviour (needs a REQ via `sdd-req-change` or explicit acceptance). Tier 2 = technical detail derived from an existing REQ. Tier 3 = cosmetic (not tracked).

| Metric | Value | Threshold | Status |
|---|---|---|---|
| Tier 1 pending REQ | N | ≤ 3 | PASS / FAIL |
| Tier 1 accepted without REQ | N | — | Advisory |
| Tier 2 registered | N | — | Info |

## Spec-engineer derived

| Artifact | Type | Derived from | Tier | Justification (≤ 8 words) | Status |
|---|---|---|---|---|---|
| INV-TSK-001..006 | Invariant | REQ-F-001 | 2 | formalises "unique incremental id" | Registered |
| `E_STORE_*` rows in UC-001..005 | Exception flow | REQ-F-006 | 2 | storage failure propagated | Registered |
| RN-003 / `E_TITLE_TOO_LONG` | Rule + exception | — | 1 | new visible limit | **[PENDING REQ]** / ACCEPTED (RN-003) |

## Audit derived
None. *(filled by `sdd-spec-auditor` Fix mode: Artifact | Finding | Derived from | Tier | Justification | Status)*

## Resolution log
None. *(Date | Artifact | From → To | Action)*
````

Group rows by pattern (one row per error family across UCs, one row per invariant range), never one row per UC per code.

---

## Template 16: Clarifications (`CLARIFICATIONS.md`, ≤ 6,000 chars for ≤ 25 rules)

````markdown
# Clarifications (business rules)

> Decided by: [user | user delegated to the recommended option] · YYYY-MM-DD. Each RN is binding for all of `spec/` and downstream skills.

## Format and structure decisions

| # | Question | Decision | Rejected |
|---|---|---|---|
| D-001 | Specification format | modular UC + BDD + contracts + invariants | monolithic SRS; stories only |

## Business rules

| RN | Source | Question | Rule adopted | Rejected (≤ 1 clause each) | Tier |
|---|---|---|---|---|---|
| RN-001 | REQ-F-001 | `"   "` and surrounding spaces in title? | `trim()`; empty after trim → `E_TITLE_EMPTY`; store trimmed | reject literal `""` only; store untrimmed | 2 |
| RN-003 | — | maximum title length? | 1000 (`TITLE_MAX_LENGTH`) → `E_TITLE_TOO_LONG` | no limit; silent truncation | 1 (accepted) |
````

No "Affects" column and no per-rule prose: documents that apply a rule cite its RN id, so `grep RN-003 spec/` is the impact list. This file is the only decisions log.

---

## Template 17: Domain documents (`domain/01..03`)

````markdown
# 01 — Glossary
| Term | Definition (≤ 20 words) | Do not use |
|---|---|---|
| Task | Unit of work with id, title, status, timestamps (ENT-001) | todo, item, entry |

# 02 — Entities
```typescript
/** ENT-001 — Task. Lifecycle: SM-001. Invariants: INV-TSK-001..007. */
interface Task { id: number /* VO-001 */; title: string /* VO-002 */; status: TaskStatus; createdAt: string; completedAt: string | null }
/** ENT-002 — Store. Owns Task[] (1..n). Invariants: INV-STO-001..004. */
```
Relationships: ENT-002 contains ENT-001 (1 → 0..n).

# 03 — Value Objects
```typescript
type TaskId = number;        // VO-001: safe integer ≥ 1 (INV-TSK-002)
type Title  = string;        // VO-002: trimmed, 1..TITLE_MAX_LENGTH, no line breaks (INV-TSK-003)
type TaskStatus = 'pending' | 'completed';  // VO-003
```

## Error catalog (VO-NNN)
| Code | Class | HTTP / exit | Message (literal) | Raised by | Refs |
|---|---|---|---|---|---|
| `E_TITLE_EMPTY` | ValidationError | 400 / 2 | `title must not be empty` | API-002-06 | REQ-F-001, RN-001 |
````

A schema block replaces attribute tables (W3); the error catalog is the only place where messages, classes and HTTP/exit mappings are written.

---

## Template 18: README (`spec/README.md`, ≤ 2,500 chars)

````markdown
# Specifications — [project]

> From `requirements/REQUIREMENTS.md` vX (YYYY-MM-DD). Decisions: `CLARIFICATIONS.md`. Language: [prose language]; ids, code and literals in English.

[≤ 3 lines: what the system is.]

| Path | Content | Start here if… |
|---|---|---|
| `domain/` | glossary, entities, value objects + error catalog, states, invariants | …you write or review anything |
| `use-cases/UC-001..NNN` | one per command / feature | …you implement a feature |
| `contracts/` | API-{module}, EVENTS, PERMISSIONS-MATRIX | …you implement an interface |
| `tests/` | BDD-UC-NNN, PROPERTY-TESTS | …you write tests |
| … | … | … |

Notes for `sdd-spec-auditor` *(only if needed, ≤ 5 bullets: known false positives, N/A categories with their ADR)*.
````

No coverage table (in `TRACEABILITY-MATRIX.md`), no metrics (in `pipeline-state.json`).

---

## Template 19: Runbook (`runbooks/RB-NNN-{slug}.md`, conditional, ≤ 3,000 chars)

Create only when a REQ/NFR requires an operational procedure or an ADR names a manual recovery step. Otherwise `runbooks/` does not exist.

````markdown
# RB-NNN — [Procedure]

| Field | Value |
|---|---|
| Trigger | [alert / exit code / symptom] |
| Refs | REQ-…; UC-…; INV-…; ADR-… |

| Symptom | Cause | Steps |
|---|---|---|
| `[message or code]` | [cause] | 1. [command] 2. [check] 3. [fix] |

Verify: `[command]` → [expected].
````

---

## Template 20: Absence declaration (`contracts/EVENTS-{module}.md`, `contracts/PERMISSIONS-MATRIX.md` when they do not apply)

````markdown
# EVENTS-{module}
None. Synchronous single-process system; no asynchronous contracts (ADR-NNN).
````

````markdown
# Permissions Matrix
| Role | Operations | Row-level rule |
|---|---|---|
| [single role] | all (API-NNN-01..04) | none — single local user (ADR-NNN) |
````

≤ 3 lines / one table row. No "Justification", "Evolution" or HTTP-equivalence sections.
