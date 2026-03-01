# Mapping Rules — External Format → SDD Artifacts

> Reglas de mapeo de campos de cada formato externo a campos SDD, conversión a EARS syntax, reglas de prioridad, deduplicación y merge. Utilizado por la Fase 3 de `sdd-import`.

---

## 1. Format → SDD Artifact Mapping

### Jira → SDD

| Jira Concept | SDD Artifact | SDD Location |
|-------------|-------------|-------------|
| Epic | Requirement group header | `requirements/REQUIREMENTS.md` §group |
| Story | Use case + requirement | `spec/use-cases.md` + `requirements/REQUIREMENTS.md` |
| Task | Implementation note (informational) | Not imported as requirement; noted in import report |
| Bug | Defect entry (if active) or resolved note | `requirements/REQUIREMENTS.md` if bug represents a missing requirement |
| Sub-task | Sub-requirement or acceptance criterion | Nested under parent requirement |
| Component | Business domain grouping | Requirement group prefix |
| Label | Tag on requirement | `attributes.tags` |
| Fix Version | Version constraint | Requirement metadata |
| Acceptance Criteria | BDD scenario | `spec/use-cases.md` acceptance criteria section |
| Comment (relevant) | Additional context | Requirement notes |

**Jira Story → EARS Conversion:**

```
Jira: "As a [user], I want to [action], so that [benefit]"
EARS: "WHEN a [user] [triggers action] THE system SHALL [provide capability] SO THAT [benefit]"

Example:
  Jira: "As an admin, I want to export user data, so that I can comply with GDPR"
  EARS: "WHEN an admin requests a user data export THE system SHALL generate a downloadable archive of all user data"
  NFR:  "THE system SHALL comply with GDPR data portability requirements (Art. 20)"
```

### OpenAPI → SDD

| OpenAPI Concept | SDD Artifact | SDD Location |
|----------------|-------------|-------------|
| info.description | Project-level context | `requirements/REQUIREMENTS.md` preamble |
| path + method | API contract + functional requirement | `spec/contracts.md` + `requirements/REQUIREMENTS.md` |
| operation.summary | Requirement title | `requirements/REQUIREMENTS.md` |
| operation.description | Requirement detail + use case description | Both |
| operation.parameters | Request specification | `spec/contracts.md` |
| operation.requestBody | Request schema | `spec/contracts.md` |
| operation.responses | Response specification + error handling reqs | `spec/contracts.md` + requirements |
| schemas (with ID) | Domain entity | `spec/domain.md` |
| schemas (DTO) | Value object / API model | `spec/domain.md` |
| securitySchemes | Security NFRs | `spec/nfr.md` |
| servers | Deployment NFRs | `spec/nfr.md` |
| tags | Feature grouping | Requirement group |

**OpenAPI → EARS Conversion:**

```
OpenAPI: POST /api/orders
  summary: "Create a new order"
  security: [bearerAuth]
  requestBody: OrderCreateRequest
  responses:
    201: OrderResponse
    400: ValidationError
    401: Unauthorized

EARS Requirements:
  REQ-ORD-001: "WHEN an authenticated user submits a valid order creation request THE system SHALL create the order and return the order details with status 201"
  REQ-ORD-002: "WHEN an unauthenticated user attempts to create an order THE system SHALL reject the request with status 401"
  REQ-ORD-003: "WHEN a user submits an invalid order creation request THE system SHALL reject the request with validation errors and status 400"
```

### Markdown → SDD

| Markdown Element | SDD Artifact | SDD Location |
|-----------------|-------------|-------------|
| H1 heading | Document section / requirement group | Group header |
| H2 heading | Requirement or use case title | `requirements/REQUIREMENTS.md` |
| H3 heading | Sub-requirement or detail | Nested requirement |
| Bullet list | Individual requirements or criteria | Depends on context |
| Numbered list | Workflow steps or ordered process | `spec/workflows.md` |
| Table | Structured data (entities, params) | `spec/domain.md` or `spec/contracts.md` |
| Code block | Technical spec or example | `spec/contracts.md` or notes |
| Blockquote | Constraint or note | NFR or constraint requirement |

### Notion → SDD

| Notion Concept | SDD Artifact | SDD Location |
|---------------|-------------|-------------|
| Database row | Requirement or use case | Depends on database structure |
| Status property | Requirement status | Metadata |
| Priority property | Requirement priority | Priority field |
| Tags/Select property | Requirement classification | Tags and grouping |
| Relation property | Traceability link | Cross-references |
| Page content | Specification detail | Appropriate spec document |
| Sub-page | Sub-requirement or child artifact | Nested structure |

### CSV / Excel → SDD

Mapping depends on column headers. Apply generic column mapping rules from `format-parsers.md`, then:

| Detected Column Role | SDD Field | Location |
|---------------------|-----------|----------|
| Title/Name/Summary | Requirement title | `requirements/REQUIREMENTS.md` |
| Description/Details | EARS statement (converted) or description | Same |
| Type/Category | Artifact type selector | Routes to appropriate document |
| Priority | Priority field | Requirements metadata |
| Status | Status field | Requirements metadata |
| Group/Module/Area | Requirement group | Group prefix |
| Acceptance Criteria | BDD scenario | Use case section |
| ID/Key/Ref | Source reference | Import tracking |

---

## 2. EARS Syntax Conversion Rules

### From User Story Format

```
Pattern: "As a {actor}, I want to {action}, so that {benefit}"
EARS:    "WHEN {actor} {triggers action} THE system SHALL {provide capability}"
         + NFR/context: "{benefit}" documented as requirement rationale
```

### From Imperative Statements

```
Pattern: "The system must {do something}"
EARS:    "THE system SHALL {do something}" (ubiquitous EARS)

Pattern: "Users should be able to {action}"
EARS:    "THE system SHALL enable users to {action}"

Pattern: "{feature} is required"
EARS:    "THE system SHALL provide {feature}"
```

### From Conditional Statements

```
Pattern: "If {condition}, then {behavior}"
EARS:    "IF {condition} THEN THE system SHALL {behavior}" (state-driven EARS)

Pattern: "When {event} happens, {reaction}"
EARS:    "WHEN {event} happens THE system SHALL {reaction}" (event-driven EARS)

Pattern: "While {state}, {behavior}"
EARS:    "WHILE {state} THE system SHALL {behavior}" (while EARS)
```

### From API Descriptions

```
Pattern: "GET /resource — Returns a list of resources"
EARS:    "WHEN a client sends a GET request to /resource THE system SHALL return a list of resources"

Pattern: "POST /resource — Creates a new resource"
EARS:    "WHEN a client sends a valid POST request to /resource THE system SHALL create a new resource and return it with status 201"
```

### Unconvertible Cases

If a description cannot be reliably converted to EARS syntax:

```markdown
### REQ-{GROUP}-{NNN}: {Title} [IMPORTED][UNCONVERTED]

> {Original description — preserved as-is}

- **Note:** Automatic EARS conversion not possible. Manual conversion recommended.
- **Original format:** {format name}
- **Reason:** {why conversion failed: too vague, multiple behaviors, narrative style, etc.}
```

---

## 3. Priority Mapping by Format

### Jira Priority → SDD Priority

| Jira | SDD |
|------|-----|
| Highest / Blocker | CRITICAL |
| High | HIGH |
| Medium | MEDIUM |
| Low | LOW |
| Lowest | LOW |

### Numeric Priority (CSV/Excel) → SDD Priority

| Range | SDD |
|-------|-----|
| 1 (or P1) | CRITICAL |
| 2 (or P2) | HIGH |
| 3 (or P3) | MEDIUM |
| 4-5 (or P4, P5) | LOW |

### MoSCoW (any format) → SDD Priority

| MoSCoW | SDD |
|--------|-----|
| Must have | CRITICAL or HIGH |
| Should have | MEDIUM |
| Could have | LOW |
| Won't have | Not imported (or LOW with note) |

### No Priority Available

If source has no priority information:
- API endpoints → MEDIUM (default)
- Security items → HIGH (default)
- Domain entities → MEDIUM (default)
- User stories with acceptance criteria → MEDIUM (default)
- Items without details → LOW (default)

---

## 4. Deduplication Rules

### When Merging (`--merge`)

1. **ID-based match:** If imported item has an ID that matches existing SDD ID → potential duplicate
2. **Title similarity:** Levenshtein distance < 20% of shorter title → potential duplicate
3. **Semantic similarity:** If imported description covers same behavior as existing requirement → potential duplicate

### Duplicate Resolution

```
For each potential duplicate:

1. Calculate match confidence:
   - Exact ID match → 100%
   - Title match (>80% similar) → 80%
   - Description overlap (>60% similar) → 60%

2. If confidence >= 80%:
   Present to user: "This appears to be a duplicate of {existing ID}. Options: Skip / Merge / Replace"

3. If confidence 50-79%:
   Present to user: "This might be related to {existing ID}. Options: Import as new / Merge / Skip"

4. If confidence < 50%:
   Import as new item (not a duplicate)
```

### Merge Strategy

When merging a duplicate:
```markdown
### REQ-{GROUP}-{NNN}: {Title} [MERGED]

> {Best EARS statement — prefer existing if already in EARS syntax, else use imported}

- **Original source:** {existing source info}
- **Import source:** {new import source info}
- **Merged:** {ISO-8601}
- **Merge notes:** {what was added/updated from import}
```

Fields merged:
- Description: use the more complete version
- Priority: use the higher priority
- Tags: union of both tag sets
- References: union of both reference sets
- Status: prefer the more current status

---

## 5. Group/Domain Assignment

### From Jira

```
Priority: Component > Epic name > Label > Project key prefix
Example:
  Component: "Authentication" → group: AUTH
  Epic: "User Management" → group: USER
  Label: "api" → group: API (if no component/epic)
```

### From OpenAPI

```
Priority: Tag > Path prefix > Schema namespace
Example:
  Tag: "orders" → group: ORD
  Path: /api/users/* → group: USER
  Schema: UserProfile → group: USER
```

### From Markdown

```
Priority: H1 heading > Directory structure > Filename
Example:
  # Authentication → group: AUTH
  docs/api/users.md → group: API-USER
```

### Group ID Generation

```
1. Take the group name (e.g., "Authentication")
2. Convert to uppercase abbreviation (AUTH)
3. If abbreviation conflicts with existing group, append number (AUTH-2)
4. Maximum 5 characters for group prefix
```
