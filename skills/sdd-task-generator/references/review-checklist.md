# Review Checklist Patterns

> Reference for generating per-task review checklists.
> Each task MUST include actionable review items for human reviewers.

---

## Universal Review Items

Every task, regardless of type, includes these base checks:

```markdown
- [ ] Code compiles without errors
- [ ] Follows ubiquitous language from domain/01-GLOSSARY.md
- [ ] Satisfies acceptance criteria listed above
- [ ] No secrets, credentials, or API keys in code
- [ ] No TODO/FIXME left unresolved
```

---

## Domain-Specific Review Items

### Entity / Value Object Tasks

```markdown
- [ ] Schema matches spec/domain/02-ENTITIES.md or 03-VALUE-OBJECTS.md
- [ ] All required fields present with correct types
- [ ] Validation constraints from invariants enforced
- [ ] Timestamps use ISO 8601 format
- [ ] IDs use specified format (UUID v4, ULID, etc.)
- [ ] Tenant isolation field present (org_id) per INV-SYS-001
```

### API Endpoint Tasks

```markdown
- [ ] Route matches spec/contracts/*.md exactly
- [ ] HTTP method and path correct
- [ ] Request/response schemas match contract
- [ ] Authentication required per INV-SYS-003
- [ ] Rate limiting applied per ADR-025
- [ ] Error responses follow ADR-026 format
- [ ] API versioning prefix /api/v1/ per ADR-033
- [ ] Tenant isolation in queries per INV-SYS-001
```

### Middleware Tasks

```markdown
- [ ] Middleware order documented and correct
- [ ] Does not swallow errors silently
- [ ] Passes through to next handler on success
- [ ] Rate limits match spec/nfr/LIMITS.md values
- [ ] Logging does not expose PII
```

### Database Migration Tasks

```markdown
- [ ] Has reversible down() migration alongside up()
- [ ] Column types match entity spec
- [ ] Indexes added for query patterns in contracts
- [ ] Foreign keys match entity relationships
- [ ] Default values specified where required
- [ ] NOT NULL constraints match required fields
- [ ] No data loss in down() migration
```

### Domain Event Tasks

```markdown
- [ ] Event schema matches spec/contracts/EVENTS-domain.md
- [ ] Event name follows {Entity}{Action} pattern
- [ ] All required fields from spec present
- [ ] aggregate_id field present for FIFO ordering
- [ ] Event versioning considered
```

### Service / Business Logic Tasks

```markdown
- [ ] Implements behavior from use case spec exactly
- [ ] Business rules from CLARIFICATIONS.md (RN-*) enforced
- [ ] Error cases from UC exception flows handled
- [ ] Domain events emitted at correct points
- [ ] Audit log entries created per INV-AUD-003
```

### Test Tasks

```markdown
- [ ] Tests cover acceptance criteria from FASE file
- [ ] Happy path tested
- [ ] Error/exception paths tested
- [ ] Edge cases from spec tested
- [ ] Test names describe behavior, not implementation
- [ ] No hardcoded values that should come from spec
- [ ] Assertions are specific (not just "truthy")
```

### PII / Encryption Tasks

```markdown
- [ ] Encryption follows ADR-002 (AES-256-GCM)
- [ ] IV never reused (INV-SEC-001, INV-SEC-002)
- [ ] PII fields identified and encrypted
- [ ] Decryption only with proper authorization
- [ ] Key material not logged or exposed
- [ ] Encrypted fields marked in schema
```

### Multi-Tenant Tasks

```markdown
- [ ] Tenant isolation enforced in all queries (INV-SYS-001)
- [ ] org_id filter applied at repository/data layer
- [ ] No cross-tenant data leakage possible
- [ ] Tenant context propagated through call chain
```

### Background Job Tasks

```markdown
- [ ] Job follows ADR-023 patterns
- [ ] Idempotency guaranteed (safe to retry)
- [ ] DLQ configured for failed jobs
- [ ] Timeout within limits (INV-SYS-004: 360s max)
- [ ] Progress tracking if long-running
```

### Configuration Tasks

```markdown
- [ ] Environment variables documented
- [ ] Secrets use proper secret management (not env vars)
- [ ] Default values are production-safe
- [ ] Configuration validation at startup
- [ ] wrangler.toml bindings correct
```

### Integration / Wiring Tasks

```markdown
- [ ] Dependencies injected, not hard-coded
- [ ] Event handlers registered correctly
- [ ] Service initialization order correct
- [ ] Error propagation across boundaries handled
- [ ] Circuit breaker / retry patterns where appropriate
```

---

## Review Severity Indicators

Add severity hints to help reviewers prioritize:

| Indicator | Meaning | When to Use |
|-----------|---------|-------------|
| `[CRITICAL]` | Security or data integrity | PII, auth, encryption, tenant isolation |
| `[IMPORTANT]` | Correctness | Business logic, state machines, invariants |
| `[NICE]` | Quality | Code style, naming, documentation |

Example:
```markdown
- [ ] [CRITICAL] Encryption follows ADR-002 (AES-256-GCM)
- [ ] [IMPORTANT] Business rules from RN-181 enforced
- [ ] [NICE] Variable names follow glossary conventions
```

---

## Checklist Size Guidelines

| Task Complexity | Review Items |
|----------------|-------------|
| Simple (config, docs) | 3-5 items |
| Medium (entity, endpoint) | 5-8 items |
| Complex (service, integration) | 8-12 items |
| Critical (security, PII) | 10-15 items |

If a checklist exceeds 15 items, the task is probably too broad — consider splitting.
