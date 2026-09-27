# Mapping Rules — External Format → SDD Artifacts

> Field mapping, EARS conversion, priority, deduplication and grouping rules for `sdd-import` Phase 3.

---

## 1. Format → SDD Artifact Mapping

Targets are the canonical `spec/` tree (sdd-specifications-engineer) and `requirements/REQUIREMENTS.md` with `REQ-F/NF/C-NNN` IDs. The source grouping goes in the requirement's `Group` field.

### Jira → SDD

| Jira | SDD artifact | Location |
|------|-------------|----------|
| Epic | Group | `Group` field of its requirements |
| Story | Requirement + use case | `REQUIREMENTS.md` + `spec/use-cases/UC-NNN-{slug}.md` |
| Acceptance criteria | BDD scenarios | `spec/tests/BDD-UC-NNN.md` |
| Sub-task | Acceptance criterion of the parent | Parent requirement |
| Task | Implementation note | Import report only |
| Bug | Defect entry | Import report § Defects; also a requirement when it reveals missing behaviour |
| Component / Label / Fix Version | Group / tag / version | Requirement fields |

Story → EARS: "As an admin, I want to export user data, so that I can comply with GDPR" → `WHEN an admin requests a user data export THE system SHALL generate a downloadable archive of the user's data`; the benefit becomes the Rationale (or a `REQ-NF` when it states a quality/legal constraint).

### OpenAPI → SDD

| OpenAPI | SDD artifact | Location |
|---------|-------------|----------|
| tag (or path prefix) | Contract module | `spec/contracts/API-{module}.md`, `Style: http` |
| path + method | Operation `API-NNN-NN` (specifications-engineer id scheme) + functional requirement | Contract + `REQUIREMENTS.md` |
| parameters / requestBody / responses | Request/response shapes, error rows (HTTP + `E_CODE`) | Contract; error codes also in `spec/domain/03-VALUE-OBJECTS.md` § ErrorCode |
| schema with identity field | Entity | `spec/domain/02-ENTITIES.md` |
| schema without identity (DTO) | Value object | `spec/domain/03-VALUE-OBJECTS.md` |
| securitySchemes | Security NFR (`SEC-NNN` row) + `REQ-NF` | `spec/nfr/SECURITY.md` |
| servers | Deployment note | `spec/nfr/LIMITS.md` or report |

Example — `POST /api/orders` (bearer auth; 201, 400, 401):
- `REQ-F-020`: WHEN an authenticated user submits a valid order THE system SHALL create the order and return it
- `REQ-F-021`: WHEN an unauthenticated client attempts to create an order THE system SHALL reject the request
- `REQ-F-022`: WHEN the order data is invalid THE system SHALL reject it with validation errors

Status codes stay in the `Style: http` contract, not in requirement statements.

### Markdown → SDD

| Element | Location |
|---------|----------|
| H1 | Group |
| H2 / H3 | Requirement or use case / detail |
| Bullets | Requirements or acceptance criteria |
| Numbered list | `spec/workflows/WF-NNN-{slug}.md` |
| Table | `spec/domain/02-ENTITIES.md` or the contract |
| Blockquote with a constraint | `REQ-C` or `REQ-NF` |

### Notion → SDD

Database rows → requirements or use cases (by a Type property); Status/Priority/Tags → fields; Relation → cross-references; page content → the matching spec document; sub-pages → children.

### CSV / Excel → SDD

After column-role detection (format-parsers.md §2): title → requirement title; description → EARS statement; type → routes the row to the target document; priority/status/group → fields; acceptance criteria → BDD scenarios; id → `Source`.

---

## 2. EARS Conversion

| Source pattern | EARS |
|----------------|------|
| "As a {actor}, I want {action}, so that {benefit}" | `WHEN {actor} {action trigger} THE system SHALL {capability}`; benefit → Rationale |
| "The system must / Users should be able to / X is required" | `THE system SHALL …` (ubiquitous) |
| "When {event}, {reaction}" | `WHEN {event} THE system SHALL {reaction}` |
| "While {state}, {behavior}" | `WHILE {state} THE system SHALL {behavior}` |
| "If {condition}, then {behavior}" (unwanted behaviour) | `IF {condition} THEN THE system SHALL {behavior}` |
| API summary ("Creates a resource") | `WHEN a client submits a valid {resource} THE system SHALL create it` |

When conversion is unreliable (vague, several behaviours, narrative), keep the original text as the Statement, add `[UNCONVERTED]` to the heading and a `Reason` field; the item goes to Items Needing Manual Review.

## 3. Priority → `Must have | Should have | Nice to have`

| Source | Must have | Should have | Nice to have |
|--------|-----------|-------------|--------------|
| Jira | Highest, Blocker, High | Medium | Low, Lowest |
| Numeric / P-levels | 1–2, P1–P2 | 3, P3 | 4–5, P4–P5 |
| MoSCoW | Must | Should | Could (Won't → not imported, listed in report) |

No priority in the source: security items → Must have; endpoints, entities, stories with criteria → Should have; items without detail → Nice to have. Record the original value in the report.

## 4. Deduplication (`--merge`)

Match confidence: exact ID or `Source` match 100%; title > 80% similar 80%; description covering the same behaviour 60%.
- ≥ 80%: ask Skip / Merge / Replace (with `--yes`: Skip).
- 50–79%: ask Import as new / Merge / Skip (with `--yes`: Import as new, listed for review).
- < 50%: import as new.

A merged entry keeps its existing ID and gets `[MERGED]`, both `Source` values, and a `Merge notes` field. Field rules: longer description, higher priority, union of tags and references, most recent status; prefer the existing statement when it is already EARS.

## 5. Groups

The group is a label in the requirement's `Group` field and the module name of contracts (`API-{module}.md`), never part of a REQ ID. Precedence — Jira: Component > Epic > Label; OpenAPI: tag > path prefix > schema namespace; Markdown: H1 > directory > filename.
