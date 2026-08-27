# Template-Checklist Alignment Matrix

> Maps every spec-engineer template to the auditor checklist it must satisfy, and names the **compact form** that satisfies it. A document passes the auditor on the first pass when the mandatory items are present — as ids, table rows or one-line entries, never as prose. Never add a section to "look complete": `None.` is a valid, auditable answer.

## Alignment Matrix

| Document | Template | Auditor checklist | Mandatory items | Compact form that satisfies them |
|---|---|---|---|---|
| Glossary | 17 | Glossary | term, definition, "Do not use" synonyms | one table, ≤ 20-word definitions |
| Entities | 17 | Entities | id, attributes with types, required/optional, relationships with cardinality | schema block with `?` optionals + one relationships line |
| Value Objects | 17 | Value Objects | name, type, constraints, error catalog | typed aliases with INV/VO comments; error catalog table (code, class, HTTP/exit, message, raised by) |
| States | 9 | States | states with initial/final, transitions (from → to, trigger, guard, action, events), timeouts | two tables; diagram only above 5 states |
| Invariants | 10 | Invariants | INV-{AREA}-{NNN}, declarative rule, validation (SQL/TS), enforcement point, related UCs, violation error | one row per invariant; code block only when the validation does not fit a cell |
| Use Cases | 2 | Use Case | id, version/date, actors, pre/postconditions (success + failure), main/extension/exception flows, error codes with HTTP/exit, INV ids, BDD reference | header `Refs` row (= traceability section) · numbered main flow · one-line extensions · one `Exceptions & errors` table (= exception flows + errors) · AC ids cited, scenarios in BDD file |
| Workflows | 11 | Workflow | trigger, total timeout, steps with timeout + retry + I/O, error handling per step, compensation, metrics | header row + steps table + error table + metrics table; `Events emitted: None.` when none |
| API Contracts | 12 | API Contract | method, path, auth, rate limit, version, request/response schema, error responses 400/401/403/404/409/429 where applicable, unique codes | auth/rate limit/version once in the header · operations table · schema block per operation · **one** Errors table with an "Operations" column |
| Permissions Matrix | 20 | Permissions | role × operation grid, row-level rules | one table; one row when there is a single role |
| Events | 20 | (none) | events, payload, consumers | table, or `None.` + ADR id |
| BDD Tests | 13 | BDD Test | Feature (As / I want / So that), Background, happy + alternative + error + edge scenarios, AC ids on every scenario | scenario title = `AC-NNN-NN — name [REQ-X ACn]`; ≤ 6 lines per scenario; error asserted by code + status |
| ADRs | 6 | ADR | id, status, date, context, decision, alternatives with pros/cons, consequences (+/−), risks | Nygard short: context ≤ 5 lines, alternatives table (`Option | Why not`), consequences bullets (risk = a `−` bullet) |
| NFR Performance / Security / Limits | 7 | NFR-* | metric, target, fail point, measurement / control, standard, enforcement, behaviour when exceeded | one table per file; N/A category = one row `Not applicable (ADR-NNN)` |
| Value Registry | 14 | Cross-document | every shared value, canonical definition, cross-references | one table; "Used in" holds ids, other documents cite the value **name** |
| Derived Specs | 15 | Traceability | tier, derived-from REQ, status, gate ≤ 3 Tier 1 pending | gate table + rows grouped by pattern |
| Clarifications | 16 | Traceability / silences | question, options, decision, tier, source REQ | one RN row per decision; no "affects" column, no prose |
| Traceability Matrix | 5 | Traceability | REQ → artifacts, coverage, orphans | forward table + one coverage line |
| Runbook (conditional) | 19 | (none) | trigger, symptoms, steps, verification | header + symptom table + verify line |

## How to Use

1. **When creating a document:** look up its row, use the template, and check the mandatory items are present in the compact form. Do not add sections beyond the template.
2. **When a checklist item does not apply** (no auth, no events, no rate limit): satisfy it with `None.` or a `Not applicable (ADR-NNN)` row — never with a justification paragraph.
3. **Self-audit pre-flight:** the Self-Validation Gate (SKILL.md) verifies these items with `grep`, not by re-reading the documents.
