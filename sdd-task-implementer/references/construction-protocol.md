# Construction Protocol by Task Type

> Reference for implementation patterns per task type.
> Each pattern maps SWEBOK §4.3 Practical Considerations to concrete coding steps.

---

## Protocol: Entity / Value Object Tasks

**Input:** `spec/domain/02-ENTITIES.md` or `03-VALUE-OBJECTS.md`

```
1. READ entity schema from spec
2. CREATE type/interface matching schema exactly
   - All required fields with correct types
   - Optional fields marked appropriately
   - Timestamps as ISO 8601 strings
   - IDs using specified format (UUID v4, ULID, etc.)
3. IMPLEMENT invariants as validation methods
   - Read INV-* from spec/domain/05-INVARIANTS.md
   - Add validation in constructor or factory method
   - Throw typed errors on violation
4. IMPLEMENT factory method (create) or builder
   - Accept raw input, validate, return typed entity
5. IMPLEMENT serialization (toJSON / fromJSON)
   - Match contract schemas for API responses
6. WRITE tests:
   - Valid construction with all required fields
   - Each invariant violation produces correct error
   - Serialization round-trip preserves data
   - Edge cases: null, empty string, boundary values
```

**Anti-patterns:**
- Adding fields not in the spec
- Skipping invariant validation "for now"
- Using `any` type instead of spec-defined types

---

## Protocol: API Endpoint Tasks

**Input:** `spec/contracts/API-*.md`

```
1. READ contract from spec/contracts/
   - HTTP method, path, query params
   - Request body schema
   - Response body schema (success + error)
   - Authentication requirements
   - Rate limiting requirements
2. CREATE route handler
   - Register route with exact path from contract
   - Apply auth middleware per relevant INV-SYS-* or INV-AUTH-* invariant
   - Apply rate limiting per relevant ADR and nfr/LIMITS.md
3. IMPLEMENT request validation
   - Parse and validate request body against contract schema
   - Return 400 with structured error per error-handling ADR if invalid
4. IMPLEMENT business logic
   - Call service layer (never inline domain logic in handler)
   - Apply tenant isolation filter per relevant INV-SYS-* invariant (if multi-tenant)
5. IMPLEMENT response
   - Format response matching contract schema exactly
   - Include proper HTTP status codes
   - Set appropriate headers (Content-Type, Cache-Control)
6. IMPLEMENT error handling
   - Map domain errors to HTTP status codes
   - Follow project's error response ADR format
   - Never expose internal errors to client
7. WRITE tests:
   - Happy path: valid request → expected response
   - Auth: missing token → 401, invalid token → 401
   - Validation: invalid body → 400 with details
   - Tenant: request for other org → 403 or filtered
   - Rate limiting: exceed limit → 429 with Retry-After
   - Each error case from UC exception flows
```

**Anti-patterns:**
- Different route path than contract specifies
- Missing auth middleware on protected endpoint
- Business logic directly in route handler
- Response schema not matching contract

---

## Protocol: Middleware Tasks

**Input:** `spec/contracts/*.md` + ADRs referenciados

```
1. READ middleware requirements from spec/contracts and ADRs
2. CREATE middleware function
   - Accept request, context, next handler
   - Process request (validate, extract, transform)
   - Call next handler on success
   - Return error response on failure
3. IMPLEMENT specific logic:
   For auth middleware:
     - Extract token from Authorization header
     - Validate token (signature, expiry, claims)
     - Set user context (user_id, org_id, role)
     - Return 401 on failure
   For rate limiting:
     - Read limits from config (relevant rate-limiting ADR + nfr/LIMITS.md)
     - Track request count per key (session/user/IP)
     - Return 429 with Retry-After on limit exceeded
   For tenant isolation:
     - Extract org_id from auth context
     - Inject org_id filter into request context
     - Prevent cross-tenant queries
4. DOCUMENT middleware order
   - Auth before rate limiting before business logic
5. WRITE tests:
   - Middleware calls next on valid input
   - Middleware returns error on invalid input
   - Middleware does not swallow errors
   - Rate limits enforced at correct thresholds
   - PII not exposed in logs
```

**Anti-patterns:**
- Swallowing errors silently (no next() call, no error response)
- Logging PII (tokens, passwords, email addresses)
- Hardcoding limit values instead of reading from config

---

## Protocol: Database Migration Tasks

**Input:** `spec/domain/02-ENTITIES.md` + entity relationships

```
1. READ entity schema and relationships from spec
2. CREATE up() migration
   - Table name matching entity name (snake_case plural)
   - Column types matching entity field types
   - NOT NULL constraints matching required fields
   - Default values where specified
   - Foreign keys matching entity relationships
   - Indexes for common query patterns (from contracts)
   - Tenant isolation column if multi-tenant (per relevant INV-SYS-* invariant)
   - created_at, updated_at timestamps
3. CREATE down() migration
   - Reversible: DROP TABLE or ALTER TABLE
   - No data loss for non-destructive operations
   - Document data loss risk for destructive operations
4. WRITE tests (if applicable):
   - Migration runs without errors (up)
   - Migration reverses cleanly (down)
   - Schema matches entity spec after migration
```

**Anti-patterns:**
- Missing down() migration
- Missing org_id for tenant isolation
- Column types not matching entity spec
- Missing indexes for query patterns defined in contracts

---

## Protocol: Domain Event Tasks

**Input:** `spec/contracts/EVENTS-*.md`

```
1. READ event schema from spec/contracts/EVENTS-{domain}.md
2. CREATE event class/type
   - Event name follows {Entity}{Action} pattern
   - All required fields from spec present
   - aggregate_id field for FIFO ordering
   - timestamp in ISO 8601
   - event_version field
3. IMPLEMENT event publisher
   - Use event bus / queue from tech stack
   - Emit event at correct points in service logic
4. IMPLEMENT event handler (if this task covers it)
   - Idempotent handling (safe to retry)
   - Error handling with DLQ
5. WRITE tests:
   - Event schema matches spec
   - Event emitted at correct business logic point
   - Handler processes event correctly
   - Handler is idempotent (duplicate event → same result)
```

---

## Protocol: Service / Business Logic Tasks

**Input:** `spec/use-cases/UC-*.md`

```
1. READ use case from spec
   - Pre-conditions, post-conditions
   - Main flow (step by step)
   - Exception flows (each alternative path)
   - Business rules from CLARIFICATIONS.md (RN-*)
2. CREATE service class/module
   - Inject dependencies (repository, event bus, external services)
   - Never hardcode dependencies
3. IMPLEMENT main flow
   - Each step of the UC main flow → a code block
   - Apply business rules (RN-*) at appropriate points
   - Emit domain events at state transitions
4. IMPLEMENT exception flows
   - Each exception flow → error handling branch
   - Return typed errors (not generic exceptions)
5. IMPLEMENT audit logging
   - Per INV-AUD-003 or equivalent audit invariant
   - Log who did what when, without PII
6. WRITE tests:
   - Happy path: main flow end-to-end
   - Each exception flow
   - Business rules (RN-*) enforcement
   - Audit log entries created
   - Domain events emitted
```

**Anti-patterns:**
- Implementing behavior not in the UC
- Missing exception flow handling
- Hardcoded dependencies
- Missing audit log entries

---

## Protocol: Configuration / Setup Tasks

**Input:** `plan/PLAN-FASE-{N}.md`, ADRs

```
1. READ configuration requirements from plan and ADRs
2. CREATE configuration files
   - wrangler.toml, package.json, tsconfig.json, etc.
   - Environment variables documented
   - Secrets use proper secret management (not env vars)
3. VALIDATE configuration
   - Config parses correctly
   - Build succeeds with config
   - Dev server starts without errors
4. VERIFICATION (instead of unit tests):
   - `npm install` completes without errors
   - `npx wrangler dev` starts successfully
   - TypeScript compiles without errors
   - Lint passes
```

---

## Protocol: Test Tasks

**Input:** `spec/tests/BDD-*.md` or acceptance criteria

```
1. READ test specifications from spec/tests/
2. IDENTIFY test type:
   - Unit test: isolated, mocked dependencies
   - Integration test: real dependencies, database
   - BDD/acceptance test: end-to-end scenarios
   - Property test: randomized input testing
3. IMPLEMENT tests
   - Test names describe behavior, not implementation
   - Use Given-When-Then structure for BDD
   - No hardcoded values that should come from spec
   - Assertions are specific (not just "truthy")
4. VERIFY tests pass
5. CHECK coverage
   - Happy path tested
   - Error/exception paths tested
   - Edge cases from spec tested
```

---

## Protocol: PII / Encryption Tasks

**Input:** Project's encryption/PII ADR (`spec/adr/ADR-*-encryption*.md`), security specs

```
1. READ encryption requirements from the project's encryption ADR
2. IDENTIFY PII fields from entity specs
3. IMPLEMENT encryption
   - Algorithm: as specified in encryption ADR (e.g., AES-256-GCM)
   - IV: unique per encryption operation (per relevant INV-SEC-* invariants)
   - Key management: read from secure storage, never hardcode
4. IMPLEMENT decryption
   - Only with proper authorization check
   - Never log decrypted PII
5. MARK encrypted fields in schema
6. WRITE tests:
   - Encryption produces different ciphertext each time (unique IV)
   - Decryption recovers original plaintext
   - Unauthorized decryption attempt fails
   - Key material not in logs
   - Encrypted fields marked in stored data
```

**CRITICAL — Security Anti-patterns:**
- Reusing IV (violates unique-IV invariant)
- Logging decrypted PII
- Hardcoding encryption keys
- Using weak algorithms (not AES-256-GCM)

---

## Protocol: Integration / Wiring Tasks

**Input:** Multiple specs, plan architecture

```
1. READ integration requirements from plan/ARCHITECTURE.md
2. IMPLEMENT dependency injection
   - Wire services, repositories, middleware
   - Initialization order correct
3. IMPLEMENT event handler registration
   - Connect event publishers to handlers
4. IMPLEMENT error propagation
   - Errors cross boundaries correctly
   - No lost errors, no swallowed exceptions
5. IMPLEMENT circuit breaker / retry (if specified)
6. WRITE tests:
   - Integration test: components communicate correctly
   - Error propagation: errors bubble up properly
   - Event flow: events reach handlers
```

---

## Universal Pre-Implementation Checklist

Before writing ANY code for any task type:

```
[ ] Read the task entry from task/TASK-FASE-{N}.md
[ ] Read ALL spec files listed in Refs field
[ ] Understand acceptance criteria — can you restate each in your own words?
[ ] Identify which invariants apply (INV-*)
[ ] Know the file path(s) to create/modify
[ ] Know the commit message to use
[ ] Know the revert strategy
[ ] No [DECISION PENDIENTE] in referenced specs
```

## Universal Post-Implementation Checklist

After implementing ANY task:

```
[ ] All acceptance criteria verified
[ ] Review checklist items all pass
[ ] Tests exist and pass (or manual verification documented)
[ ] Build succeeds (no compilation errors)
[ ] Lint passes (no format issues)
[ ] No secrets or PII in code or logs
[ ] Commit message matches task exactly
[ ] Only task-specified files modified
[ ] System still functional (no regressions)
```
