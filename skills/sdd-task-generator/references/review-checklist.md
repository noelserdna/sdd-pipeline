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
- [ ] Every assert that encodes an acceptance criterion has the criterion's literal text above it, opened from requirements/REQUIREMENTS.md (`// REQ-F-081 AC1: "…THEN su título es 'Proyectos personales'"`), and every quoted literal appears in the assert
```

The quote keeps the customer's words next to the check that claims to verify them: a paraphrase in the task or the BDD summary is where a title or a label drifts unnoticed.

---

## Domain-Specific Review Items

### Entity / Value Object Tasks

```markdown
- [ ] Schema matches spec/domain/02-ENTITIES.md or 03-VALUE-OBJECTS.md
- [ ] All required fields present with correct types
- [ ] Validation constraints from invariants enforced
- [ ] Timestamps use ISO 8601 format
- [ ] IDs use specified format (UUID v4, ULID, etc.)
- [ ] Tenant isolation field present (e.g. org_id) when the domain is multi-tenant
```

### API Endpoint / Operation Tasks

```markdown
- [ ] Operation satisfies its API-op semantics in spec/contracts/*.md (input VOs, effect/post INV, domain error codes)
- [ ] Transport matches design/OPERATION-MAPPING.md (idiom, route/action, verb, success, validation error, no-JS fallback, accessible element) (written by sdd-tech-designer, or by sdd-plan-architect when the tech designer did not run)
- [ ] Method + path equal the contract only when it declares `Style: http` (pre-4.3 contracts with `Method | Path` columns count as http)
- [ ] Request/response schemas match contract
- [ ] Authentication required where the spec demands it
- [ ] Rate limiting applied per ADR-025 *(example id — cite the project's own ADR)*
- [ ] Error responses follow ADR-026 format *(example id — cite the project's own ADR)*
- [ ] API versioning prefix /api/v1/ per ADR-033 *(example id; `Style: http` only)*
- [ ] Tenant isolation in queries (multi-tenant domains)
- [ ] The operation has a caller on the user's route (the page, route or command the FASE Demo uses), not only a test that calls it directly *(full format; in compact the FASE journey task covers it)*
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
- [ ] Tests cover the acceptance criteria as written in requirements/REQUIREMENTS.md, not the FASE file's one-line summary
- [ ] Every `replay` and `race` row of the test matrix for this operation has its test; a race row runs two concurrent calls on the same fixture, without sleeps
- [ ] Happy path tested
- [ ] Error/exception paths tested
- [ ] Edge cases from spec tested
- [ ] Test names describe behavior, not implementation
- [ ] No hardcoded values that should come from spec
- [ ] Assertions are specific (not just "truthy")
```

### Journey Tasks (one per FASE)

```markdown
- [ ] Enters through the user's route (Demo step 1: URL, screen or command), never an internal entry point
- [ ] Asserts the example text of each criterion on the element that shows it (`toHaveText` / `toContainText`), not the visibility of a container
- [ ] Saves a screenshot per REQ-F criterion and a video per workflow under evidencias/FASE-{N}/, attached to the test
- [ ] Test names carry every REQ-F scenario id of the FASE's Escenarios, and the journey's title the WF-NNN of the FASE's `Workflows:` line (else of its Demo; FASE-{N} when it names none), which names the video
```

### Contract Tasks (`CONTRACT-<port>`)

```markdown
- [ ] The same assertions run on the double and on the real provider (real one through a fake transport that captures the request)
- [ ] Asserts the observable of the port's row in PLAN-FASE §4 Puertos con doble
- [ ] Test name `CONTRACT-<port> REQ-F-NNN ACn …`, in a file under `test_paths` `contract/` named by the stack's convention (`<port>.contract.test.ts`, `<port>_contract_test.rb`)
```

### PII / Encryption Tasks

```markdown
- [ ] Encryption follows the project's crypto ADR *(e.g. ADR-002 AES-256-GCM — example id)*
- [ ] IV never reused (INV-SEC-001, INV-SEC-002)
- [ ] PII fields identified and encrypted
- [ ] Decryption only with proper authorization
- [ ] Key material not logged or exposed
- [ ] Encrypted fields marked in schema
```

### Multi-Tenant Tasks

```markdown
- [ ] Tenant isolation enforced in all queries (the project's tenancy invariant)
- [ ] org_id filter applied at repository/data layer
- [ ] No cross-tenant data leakage possible
- [ ] Tenant context propagated through call chain
```

### Background Job Tasks

```markdown
- [ ] Job follows the project's background-job ADR *(example: ADR-023)*
- [ ] Idempotency guaranteed (safe to retry)
- [ ] DLQ configured for failed jobs
- [ ] Timeout within the limit the NFRs/invariants set
- [ ] Progress tracking if long-running
```

### Configuration Tasks

```markdown
- [ ] Environment variables documented
- [ ] Secrets use proper secret management (not env vars)
- [ ] Default values are production-safe
- [ ] Configuration validation at startup
- [ ] Runtime/deploy config valid for the project's stack — the Stack Profile commands pass (`skills/sdd-task-implementer/references/stack-profile.md`); e.g. `config/database.yml` + credentials (Rails), `next.config.*` + env (Next.js)
```

### Integration / Wiring Tasks

```markdown
- [ ] Dependencies injected, not hard-coded
- [ ] Event handlers registered correctly
- [ ] Service initialization order correct
- [ ] Every component this FASE adds is reachable from the user's route after the wiring *(full format)*
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
- [ ] [CRITICAL] Encryption follows the project's crypto ADR
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
