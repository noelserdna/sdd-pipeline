# Template-Checklist Alignment Matrix

> This matrix maps every spec-engineer template to the corresponding auditor checklist.
> For every document you create, verify it contains ALL mandatory sections listed here.
> This alignment ensures specs pass auditor verification on first pass.

## Alignment Matrix

| Document Type | Engineer Template | Auditor Checklist Section | Mandatory Sections |
|---|---|---|---|
| Glossary | (domain guidance) | Glossary checklist | entries, definitions, "NO usar" column, examples |
| Entities | (domain guidance) | Entities checklist | ID, attributes with types, required/optional markers, relationships with cardinality |
| Value Objects | Template 14 (Value Registry) | Value Objects checklist | name, fields with types, validation constraints, equality semantics |
| States | Template 9 | States checklist | state list with initial/final markers, transition table (from→to, trigger, guard, action, events), timeout transitions |
| Invariants | Template 10 | Invariants checklist | INV-ID (INV-{AREA}-{NNN}), declarative rule, SQL CHECK or Zod validation, enforcement point, related UCs, violation error code |
| Use Cases | Template 2 | Use Case checklist | actors, preconditions, postconditions (success + failure), normal/alternative/exception flows, error codes with HTTP status, INV-ID references, BDD-UC-NNN reference |
| Workflows | Template 11 | Workflow checklist | trigger, total timeout, steps with individual timeout + retry policy + I/O schema, error handling per step, compensation, metrics |
| API Contracts | Template 12 | API Contract checklist | method, path, auth, rate limit, version, request schema (params + body), success response, error responses (401/403/404/409/429 where applicable) |
| Permissions Matrix | (built into API contracts) | Permissions checklist | role × endpoint × action grid, row-level security rules |
| BDD Tests | Template 13 | BDD Test checklist | Feature (As/I want/So that), Background, Scenarios: happy path + alternative + error + edge case + invariant enforcement, AC-ID references |
| ADRs | Template 6 (Decisions Log) | ADR checklist | ID, status, context, decision, alternatives considered, consequences |
| NFR Performance | Template 7 | NFR-Performance checklist | metric, target, fail point, measurement method |
| NFR Security | Template 7 | NFR-Security checklist | control, description, standard reference |
| NFR Limits | Template 7 | NFR-Limits checklist | limit name, value with unit, enforcement point |
| Value Registry | Template 14 | Cross-document checklist | all shared values, canonical definitions, documents-using cross-references |

## How to Use

1. **When creating a new spec document:** Look up its type in the matrix above. Use the referenced template. Before saving, verify ALL mandatory sections are populated (not empty, not TBD).
2. **When modifying an existing spec document:** After modification, re-check the mandatory sections for the document type.
3. **Self-audit pre-flight:** The Self-Validation Gate (in SKILL.md) uses this matrix to verify structural completeness.
