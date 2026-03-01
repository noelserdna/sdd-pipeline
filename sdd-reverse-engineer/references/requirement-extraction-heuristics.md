# Requirement Extraction Heuristics

> Reglas para convertir patrones de código en requirements SDD con EARS syntax, prioridad inferida, niveles de confianza y criterios de granularidad. Utilizado por la Fase 5 de `sdd-reverse-engineer`.

---

## 1. Code Pattern → Requirement Type Mapping

### Functional Requirements

| Code Pattern | Requirement Type | EARS Template | Confidence |
|-------------|-----------------|---------------|-----------|
| Route/endpoint handler | Feature requirement | `WHEN <HTTP method + path> THE system SHALL <handler behavior>` | HIGH |
| CRUD operations on entity | Data management | `THE system SHALL allow <actor> to <create/read/update/delete> <entity>` | HIGH |
| Event handler/listener | Event-driven behavior | `WHEN <event> is received THE system SHALL <reaction>` | HIGH |
| Scheduled job/cron | Temporal behavior | `WHILE <schedule active> THE system SHALL <periodic action>` | MEDIUM |
| Background worker/queue | Async processing | `WHEN <message> is queued THE system SHALL <processing>` | MEDIUM |
| State transition function | State behavior | `WHEN <entity> is in <state> AND <event> occurs THE system SHALL <transition>` | HIGH |
| Conditional business logic | Business rule | `IF <condition> THEN THE system SHALL <behavior>` | MEDIUM |
| Integration/API call | External integration | `THE system SHALL integrate with <external system> to <purpose>` | HIGH |

### Non-Functional Requirements

| Code Pattern | NFR Category | EARS Template | Confidence |
|-------------|-------------|---------------|-----------|
| Timeout configuration | Performance | `THE system SHALL respond within <timeout>ms` | MEDIUM |
| Rate limiter | Scalability | `THE system SHALL handle <rate> requests per <period>` | HIGH |
| Cache implementation | Performance | `THE system SHALL cache <data> for <TTL>` | MEDIUM |
| Auth middleware | Security | `THE system SHALL authenticate users via <mechanism>` | HIGH |
| Role/permission check | Security | `THE system SHALL restrict <action> to <role>` | HIGH |
| Input validation | Security/Data | `THE system SHALL validate that <field> <constraint>` | HIGH |
| Retry logic | Reliability | `WHEN <operation> fails THE system SHALL retry up to <N> times` | MEDIUM |
| Circuit breaker | Reliability | `WHEN <service> is unavailable THE system SHALL <fallback>` | MEDIUM |
| Encryption usage | Security | `THE system SHALL encrypt <data> using <algorithm>` | HIGH |
| Audit logging | Compliance | `THE system SHALL log <event> with <details>` | MEDIUM |

### Constraint Requirements

| Code Pattern | Constraint Type | EARS Template | Confidence |
|-------------|----------------|---------------|-----------|
| Max file size check | Operational | `THE system SHALL reject uploads exceeding <size>` | HIGH |
| Character limit validation | Data | `THE system SHALL limit <field> to <N> characters` | HIGH |
| Required field check | Data integrity | `THE system SHALL require <field> for <operation>` | HIGH |
| Unique constraint | Data integrity | `THE system SHALL ensure <field> is unique across <scope>` | HIGH |
| Format validation (regex) | Data format | `THE system SHALL validate <field> matches <format>` | HIGH |
| Range check | Business rule | `THE system SHALL ensure <field> is between <min> and <max>` | HIGH |

---

## 2. EARS Syntax Conversion Rules

### From Imperative Code

```
Code:    if (!user.isActive) throw new ForbiddenError('Account inactive')
EARS:    WHEN a user attempts to access the system THE system SHALL verify the user account is active
Inverse: IF the user account is inactive THEN THE system SHALL reject access with a Forbidden error
```

### From Validation Schema

```
Code:    email: z.string().email().max(255)
EARS:    THE system SHALL validate that the email field is a valid email address not exceeding 255 characters
```

### From Route Handler

```
Code:    router.post('/orders', authMiddleware, validateOrder, createOrder)
EARS:    WHEN an authenticated user submits a valid order THE system SHALL create the order and return confirmation
Sub-reqs:
  - THE system SHALL authenticate the user before processing order creation
  - THE system SHALL validate order data according to the order schema
```

### From Event Handler

```
Code:    eventBus.on('payment.completed', async (event) => { await updateOrderStatus(event.orderId, 'paid') })
EARS:    WHEN a payment.completed event is received THE system SHALL update the corresponding order status to paid
```

### From State Machine

```
Code:    case 'PENDING': if (action === 'APPROVE') return 'ACTIVE'
EARS:    WHEN an entity in PENDING state receives an APPROVE action THE system SHALL transition it to ACTIVE state
```

---

## 3. Priority Inference Rules

Since brownfield code lacks explicit priority markers, infer priority from code signals:

| Priority | Inference Signals |
|----------|------------------|
| **CRITICAL** | Auth/security checks, data integrity constraints, payment processing, error handling for data loss prevention |
| **HIGH** | Core CRUD operations, main business workflows, external integration points, state transitions |
| **MEDIUM** | Secondary features, reporting, notification sending, caching strategies, logging |
| **LOW** | Admin utilities, configuration endpoints, health checks, metrics, dev-only features |

### Priority Boosters

- Feature has comprehensive test coverage → +1 priority level
- Feature is in the critical path (many dependents) → +1 priority level
- Feature has error handling with custom error types → suggests importance

### Priority Reducers

- Feature has `@deprecated` marker → set to LOW
- Feature is behind a feature flag → reduce by 1 level
- Feature is in `utils/`, `helpers/`, `common/` → typically MEDIUM or LOW

---

## 4. Granularity Criteria

### When to Create a Single Requirement

- One cohesive behavior (single responsibility)
- Can be tested independently
- Has clear preconditions and postconditions
- Maps to one or few source functions

### When to Split into Multiple Requirements

- Handler performs multiple distinct actions
- Multiple validation rules on same endpoint
- State machine with multiple transitions
- CRUD with different auth rules per operation

### When to Group into a Requirement Group

- Multiple endpoints for same entity (CRUD group)
- Related business rules for a domain concept
- Configuration cluster (related settings)

### Granularity Rules

```
1. One requirement per distinct user-observable behavior
2. One requirement per validation rule (they can be tested independently)
3. One requirement per state transition
4. Group CRUD operations under one requirement group with sub-requirements
5. Group related NFRs by category (performance, security, reliability)
6. Never combine functional and non-functional aspects in one requirement
```

---

## 5. Confidence Levels

### Tag Assignment

| Level | Tag | Criteria |
|-------|-----|---------|
| **Definite** | (no tag) | Directly observable: validation message, error text, explicit check |
| **High** | `[INFERRED]` | Strong pattern match: standard CRUD, clear state machine, typed schemas |
| **Medium** | `[INFERRED]` | Pattern match with some ambiguity: complex conditionals, implicit flows |
| **Low** | `[INFERRED][IMPLICIT-RULE]` | Business logic embedded in code without clear documentation or naming |

### Confidence Upgrade Signals

- Test exists that validates the behavior → upgrade confidence by 1 level
- Comment/docstring explains the purpose → upgrade confidence by 1 level
- Error message describes the business rule → upgrade confidence by 1 level
- Multiple code paths enforce the same rule → upgrade confidence by 1 level

### Confidence Downgrade Signals

- Code has TODO/FIXME near the logic → downgrade: may be incomplete
- Dead code or commented alternatives exist → downgrade: may be outdated
- Feature flag controls the behavior → downgrade: may be experimental
- Exception/error is generic (not domain-specific) → downgrade: unclear intent

---

## 6. Source Location Cross-Reference Format

Every extracted requirement MUST include a source reference:

```markdown
### REQ-AUTH-001: User Authentication

> WHEN a user submits credentials THE system SHALL authenticate via JWT token validation

- **Source:** `src/middleware/auth.ts:15-42`
- **Tests:** `tests/middleware/auth.test.ts:10-85`
- **Confidence:** HIGH [INFERRED]
- **Priority:** CRITICAL
- **Signals:** Auth middleware, JWT decode, token validation, 401 response
```

---

## 7. Edge Cases

### Feature Flags
- Document the feature as a requirement with note: `[FEATURE-FLAG: flag_name]`
- If flag is always ON in production config → treat as normal requirement
- If flag is always OFF → mark as `[DEAD-CODE]` finding, not a requirement

### A/B Tests
- Document both variants as alternative requirements
- Note: `[A/B-TEST: experiment_name]` — may be temporary

### Third-Party Wrappers
- If the code wraps a third-party service, document the integration requirement, not the library behavior
- Focus on: what data goes in, what comes out, error handling, SLA expectations

### Generated Code
- If code is generated (ORM models from schema, API clients from OpenAPI), trace to the source of truth
- Requirements come from the generator input, not the generated output
