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
   - Operation ID (API-NNN-NN) and `Style: operations|http`
   - Inputs (params, body schema), outputs (success + error), errors
   - HTTP method + path (literal only when `Style: http`)
   - Authentication requirements
   - Rate limiting requirements
1b. READ transport for the operation
   - design/OPERATION-MAPPING.md row: | API-op | Idiom | Route / action | Verb | Success | Validation error | No-JS fallback | Accessible element |
   - `Style: operations` → the stack idiom from the mapping (Server Action, Rails resource route, Route Handler…)
   - `Style: http` → method + path exactly as the contract
   - no mapping row and `Style: operations` → PAUSE: Conflict (transport undefined), never invent a custom route
2. CREATE handler in the mapped idiom
   - Register route/action as the mapping (or, for `Style: http`, the contract) says
   - Apply auth per the relevant auth invariant (INV-*)
   - Apply rate limiting per the relevant ADR and spec/nfr/ limits
3. IMPLEMENT request validation
   - Parse and validate request body against contract schema
   - Return 400 with structured error per error-handling ADR if invalid
4. IMPLEMENT business logic
   - Call service layer (never inline domain logic in handler)
   - Apply the tenant isolation filter per the relevant INV-* (if multi-tenant)
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
- Different route path than contract specifies (`Style: http`) or than OPERATION-MAPPING specifies (`Style: operations`)
- Adding custom routes/endpoints (member POST routes, extra Route Handlers) the mapping does not list
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
     - Read limits from config (relevant rate-limiting ADR + spec/nfr/ limits)
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
   - Tenant isolation column if multi-tenant (per the relevant INV-*)
   - created_at, updated_at timestamps
3. CREATE down() migration
   - Reversible: DROP TABLE or ALTER TABLE
   - No data loss for non-destructive operations
   - Document data loss risk for destructive operations
   - Apply locally with the stack's non-destructive migrate command; a clean local DB comes from `{db_reset_safe}`,
     never from a reset the tool refuses to run for an AI agent (SKILL.md → AI Tool Guardrails: never set consent
     variables such as PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION)
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

**Input:** `plan/fase-plans/PLAN-FASE-{N}.md`, ADRs

```
1. READ configuration requirements from plan and ADRs
2. CREATE configuration files
   - Framework/runtime config of the stack (package.json, tsconfig.json, Gemfile, config/*.rb, next.config.ts, etc.)
   - Environment variables documented
   - Secrets use proper secret management (not env vars)
3. VALIDATE configuration
   - Config parses correctly
   - Build succeeds with config
   - Dev server starts without errors
4. VERIFICATION (instead of unit tests; Stack Profile keys, `none` → skipped with WARN):
   - `{install}` completes without errors
   - `{server}` starts successfully (server helper, references/stack-profile.md §8 — stopped at the end)
   - `{typecheck}` compiles without errors
   - `{lint_files}` passes on the changed files
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

## Protocol: E2E Browser Test Tasks

**Input:** `test/E2E-SCENARIOS.md`, `spec/workflows/WF-*.md`, optionally `ux/WIREFRAMES.md`

```
0. REUSE an existing suite (always first)
   - An acceptance suite exists when the profile `acceptance` ≠ none, or acceptance/playwright.config.*,
     e2e/ or test/system/ exists (repo root or app_dir) → NEVER scaffold Playwright (skip steps 2-3)
   - Write the scenario inside that suite with its conventions (fixtures, page objects, helpers)
   - Done = `{acceptance} --grep <E2E-ID>` passes (step 7)
   - `e2e_scaffold: never` and no suite found → PAUSE: Ambiguity (where should E2E tests live?), no scaffold
1. READ E2E scenario from test/E2E-SCENARIOS.md
   - Identify scenario ID (E2E-WF-NNN-NN)
   - Identify steps, elements, assertions
   - Identify auth fixture needed
   - Identify tier (smoke/critical/full)
2. SETUP Playwright project (only if step 0 found no suite, `e2e_scaffold` ≠ never, and this is the first E2E task)
   - e.g. `npm init playwright@latest` in npm projects, or add Playwright to the existing test setup
   - Configure playwright.config.ts:
     - baseURL from environment
     - projects: chromium (default), firefox + webkit (for full tier)
     - retries: 2 in CI, 0 locally
     - workers: parallel by default
     - evidence: screenshot and video on, outputDir under {evidence_dir}/FASE-{N}/, JUnit into .sdd/junit/
       (template below)
3. CREATE auth fixture (if first E2E task)
   - tests/e2e/fixtures/auth.setup.ts
   - Perform login once, save storageState
   - All subsequent tests reuse stored auth
4. CREATE page objects (from scenario Elements table)
   - One page object per screen/view
   - Use role-based locators (getByRole, getByLabel)
   - Encapsulate multi-step actions as methods
   - Location: tests/e2e/pages/{page}.page.ts
5. IMPLEMENT test scenario
   - Follow steps table from E2E-SCENARIOS.md exactly
   - Each step maps to a Playwright action + assertion
   - Include axe-core scan at navigation steps:
     import AxeBuilder from '@axe-core/playwright';
     const results = await new AxeBuilder({ page }).analyze();
     expect(results.violations).toEqual([]);
   - Tag with tier: test.describe.configure({ tag: '@smoke' })
   - Each criterion's THEN is asserted on its text (`toHaveText`/`toContainText` with the literal the criterion
     quotes); `toBeVisible()` alone proves that an element exists, not what the customer reads
   - Right after that assert, capture the screen for the criterion with `captureCriterion` (below): one image per
     criterion of every REQ-F, since without it the acceptance ledger reads the criterion as `unshown`
6. IMPLEMENT error variations
   - Each row in the Variations table → a separate test
   - Reuse page objects, change inputs/preconditions
7. VERIFY
   - `{acceptance} --grep <E2E-ID>` → all pass (new suite without the key: npx playwright test {scenario-file})
   - `{acceptance} --grep @smoke` → smoke tier passes (only when the suite tags tiers)
   - The run left `{evidence_dir}/FASE-{N}/<criterion>.png` for each criterion and a video whose name carries the
     WF-NNN (FASE-N without specifications); `{evidence_dir}` is the profile's `evidence_dir`, default `evidencias`
   - No flaky failures on 3 consecutive runs of the filtered scenario
   - Never the full suite per task and never a manual server start + curl + kill: the suite's webServer (or the
     server helper, stack-profile.md §8) runs the app
8. COMMIT with traceability
   - Refs: WF-NNN, UC-NNN
   - Task: TASK-F{N}-{SEQ}
```

**Playwright config template** (new suites only — step 2; an existing suite gets the `use`, `outputDir` and
`reporter` lines below in its own E2E setup task, because every REQ-F criterion needs its capture to be VERIFIED):

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';
import { execSync } from 'node:child_process';
import path from 'node:path';

const root = execSync('git rev-parse --show-toplevel').toString().trim();
const fase = process.env.SDD_FASE ?? '0';                          // Phase 9 exports SDD_FASE={N}
export const evidenceDir = path.join(root, process.env.SDD_EVIDENCE_DIR ?? 'evidencias', `FASE-${fase}`);

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,                         // test_slots: 1 → write 1 here
  outputDir: path.join(evidenceDir, '.playwright'),                  // raw per-test artifacts, git-ignored
  reporter: [
    [process.env.CI ? 'html' : 'list'],
    ['junit', { outputFile: path.join(root, '.sdd/junit/playwright.xml') }], // read by sdd accept
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    screenshot: 'on',
    video: 'on',
    trace: 'off',            // traces hold cookies and storage: never under evidencias/ (use --trace on locally)
  },
  projects: [
    // Auth setup — runs once before all tests
    { name: 'setup', testMatch: /.*\.setup\.ts/ },
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], storageState: './tests/e2e/.auth/user.json' },
      dependencies: ['setup'],
    },
    // Full tier includes additional browsers
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'], storageState: './tests/e2e/.auth/user.json' },
      dependencies: ['setup'],
      grep: /@full/,
    },
  ],
  webServer: {
    command: 'npm run dev', // e.g. — the profile's {server} with {port} substituted, run from app_dir
    url: 'http://localhost:3000', // {port}
    reuseExistingServer: !process.env.CI,
  },
});
```

**Evidence helper** (one per suite, next to the fixtures). `testInfo.attach` with a `path` makes the JUnit reporter
write `[[ATTACHMENT|<path>]]` into the test's `<system-out>`; `sdd accept` reads it, hashes the file and binds it to the
criterion ids in the test name.

```typescript
// tests/e2e/fixtures/evidence.ts
import { test as base, type Page, type TestInfo } from '@playwright/test';
import path from 'node:path';
import { evidenceDir } from '../../../playwright.config';

// One image per criterion: evidencias/FASE-{N}/AC-004-01.png (or REQ-F-081-AC1.png without specifications)
export async function captureCriterion(page: Page, testInfo: TestInfo, criterion: string) {
  const file = path.join(evidenceDir, `${criterion.replace(/\s+/g, '-')}.png`);
  await page.screenshot({ path: file, fullPage: true });
  await testInfo.attach(criterion, { path: file, contentType: 'image/png' });
}

// One video per test, named after its workflow: evidencias/FASE-{N}/E2E-WF-004-01.webm (FASE-{N}-<title> without WF)
export const test = base.extend({
  page: async ({ page }, use, testInfo) => {
    await use(page);
    const video = page.video();
    if (!video) return;
    await page.close();
    const id = testInfo.title.match(/E2E-WF-\d{3}-\d{2}/)?.[0]
      ?? `FASE-${process.env.SDD_FASE ?? '0'}-${testInfo.title.slice(0, 40).replace(/[^A-Za-z0-9-]+/g, '-')}`;
    const file = path.join(evidenceDir, `${id}.webm`);
    await video.saveAs(file);
    await testInfo.attach(id, { path: file, contentType: 'video/webm' });
  },
});
export { expect } from '@playwright/test';
```

**Network interception (for third-party APIs):**

```typescript
// Mock external services, keep internal APIs real
await page.route('**/api.stripe.com/**', route =>
  route.fulfill({ status: 200, json: { id: 'pi_mock', status: 'succeeded' } })
);
// Internal API calls hit the real backend — do NOT mock these
```

A double that replaces an external port in unit and slice tests needs its `CONTRACT-<port>` test against the real
adapter (`references/tdd-workflow.md` → Category 3b); without it the double can drift from the provider unnoticed.

**Anti-patterns:**
- Mocking internal APIs in E2E (defeats the purpose)
- Using `page.waitForTimeout()` instead of auto-retrying assertions
- Sharing browser context between tests
- Login-through-UI in every test instead of `storageState`
- CSS selectors or XPath instead of role-based locators
- Running E2E tests without a running server
- `toBeVisible()` as the only assert of a criterion (assert its text), or a criterion of a REQ-F without its capture

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
[ ] Know the revert strategy (compact task without Revert = SAFE)
[ ] No [DECISION PENDIENTE] in referenced specs
```

## Universal Post-Implementation Checklist

After implementing ANY task:

```
[ ] All acceptance criteria verified
[ ] Review checklist items all pass
[ ] Tests exist and pass — `{test_file}` (or manual verification documented)
[ ] `{typecheck}` clean (no compilation errors); `{build}` is Phase 9 only
[ ] `{lint_files}` clean on the changed files
[ ] No secrets or PII in code or logs
[ ] Commit message matches task exactly
[ ] Only task-specified files modified
[ ] System still functional (no regressions)
```
