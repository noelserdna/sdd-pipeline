# Test-First Development Workflow

> Reference for the TDD cycle within sdd-task-implementer.
> Maps SWEBOK §4.4.16 (Test-First Programming) and §4.3.4 (Construction Testing)
> to the task-by-task implementation loop.

---

## Test names carry the scenario id

Every test that verifies an acceptance criterion has the criterion's scenario id in its name: `AC-NNN-NN` (the BDD
scenario of `spec/tests/BDD-UC-NNN.md`), or `REQ-X-NNN ACn` for a requirement criterion without a scenario (measured
NFR, constraint check). `sdd accept` reads the JUnit report (Stack Profile `test_report`) and binds each result to a
criterion only through that id; file-level `Refs:` comments never count, since they would mark every criterion of the
file as verified. The id may sit in the test name or its enclosing `describe`/class; `-` or `_` both work.
When the route skipped the specifications there is no `spec/` and no `AC-NNN-NN`: every test that verifies a
criterion carries `REQ-X-NNN ACn` (`REQ-F-003 AC2 rejects an empty title`), the ids the FASE's `Escenarios` and the
task's Acceptance cite.

| Stack | Example |
|-------|---------|
| vitest / jest / mocha | `it("AC-001-03 rejects an empty title with exit 2", …)` |
| playwright | `test("E2E-WF-001-01 AC-001-01 AC-002-01 create a task and see it listed", …)` |
| pytest | `def test_AC_001_03_rejects_empty_title():` |
| rspec / minitest | `it "AC-001-03 rejects an empty title"` · `test "AC-001-03 rejects an empty title"` |
| measured NFR | `it("REQ-NF-001 AC1 list p95 under 200 ms with 1000 tasks", …)` |

Tests with no criterion of their own (invariant property tests, helpers, harness) keep their descriptive names and
their INV/ADR ids.

---

## The RED-GREEN-REFACTOR Cycle

For each task with testable behavior:

```
┌─────────────────────────────────────────────┐
│  1. RED: Write failing test                 │
│     - Test each acceptance criterion        │
│     - Test each exception flow              │
│     - Test each applicable invariant        │
│     - Run tests → verify ALL FAIL           │
│                                             │
│  2. GREEN: Write minimal implementation     │
│     - Implement ONLY what makes tests pass  │
│     - Follow spec contracts exactly         │
│     - Apply defensive programming           │
│     - Run tests → verify ALL PASS           │
│                                             │
│  3. REFACTOR: Improve code quality          │
│     - Remove duplication                    │
│     - Improve naming (glossary terms)       │
│     - Simplify logic                        │
│     - Run tests → verify STILL PASS         │
└─────────────────────────────────────────────┘
```

---

## Test Categories by Task Type

### Category 1: Unit Tests

**When:** Entity, Value Object, Service, Business Logic tasks

```
Purpose: Test isolated behavior of a single module
Dependencies: Mocked or stubbed
Speed: < 1 second per test
Location: {test_paths}/unit/{module}.test.ts (stack convention wins: e.g. test/models/ in Rails)
```

**Naming convention:**

```typescript
describe('{ModuleName}', () => {
  describe('{methodName}', () => {
    it('AC-{NNN}-{NN} should {expected behavior} when {condition}', () => {
      // Arrange
      // Act
      // Assert
    });

    it('should throw {ErrorType} when {invalid condition} (INV-{XXX})', () => {
      // Arrange
      // Act + Assert
    });
  });
});
```

### Category 2: Integration Tests

**When:** API Endpoint, Middleware, Database, Event Handler tasks

```
Purpose: Test interaction between components
Dependencies: Real (or close to real) — prefer real DB over mocks
Speed: < 5 seconds per test
Location: tests/integration/{feature}.test.ts
```

**Structure:**

```typescript
describe('{FeatureName} Integration', () => {
  // Setup: create test database, seed data
  beforeAll(async () => { ... });

  // Cleanup: reset state
  afterEach(async () => { ... });

  it('should {end-to-end behavior}', async () => {
    // Use real HTTP client or test helper
    // Assert on HTTP status, response body, side effects
  });
});
```

### Category 3: Contract Tests

**When:** API Endpoint tasks (validating request/response schemas)

```
Purpose: Verify implementation matches API contract from spec
Dependencies: Contract schema from spec/contracts/*.md
Speed: < 2 seconds per test
Location: tests/contract/{api-name}.test.ts
```

**Structure:**

```typescript
describe('{API-NNN-NN} {operation} Contract', () => {
  it('should accept valid request body', () => {
    const body = { /* valid per contract */ };
    const result = validateRequest(body);
    expect(result.valid).toBe(true);
  });

  it('should reject request missing required field', () => {
    const body = { /* missing required field */ };
    const result = validateRequest(body);
    expect(result.valid).toBe(false);
    expect(result.errors).toContain(/* specific error */);
  });

  it('should produce response matching contract schema', async () => {
    const response = await handler(validRequest);
    expect(response).toMatchSchema(/* contract response schema */);
  });
});
```

### Category 4: BDD / Acceptance Tests

**When:** Verification tasks, end-to-end scenario tasks

```
Purpose: Validate business scenarios from spec/tests/BDD-*.md
Dependencies: Full system (or realistic simulation)
Speed: < 30 seconds per test
Location: tests/acceptance/{scenario}.test.ts
```

**Structure (Given-When-Then):**

```typescript
describe('BDD-UC-{NNN}', () => {
  it('AC-{NNN}-{NN} GIVEN {precondition} WHEN {action} THEN {expected outcome}', async () => {
    // GIVEN
    const context = await setupPrecondition();

    // WHEN
    const result = await performAction(context);

    // THEN
    expect(result).toSatisfy(expectedOutcome);
  });
});
```

### Category 5: Property Tests

**When:** Tasks involving data transformation, validation, or algorithms

```
Purpose: Test with randomized inputs to find edge cases
Dependencies: Property testing library (fast-check, etc.)
Speed: Variable
Location: tests/property/{module}.property.test.ts
```

### Category 6: E2E Browser Tests

**When:** E2E scenario tasks, workflow validation tasks, acceptance test tasks referencing `test/E2E-SCENARIOS.md`

```
Purpose: Validate complete user journeys end-to-end in a real browser
Dependencies: Running dev/staging server, seeded test data
Speed: < 30 seconds per scenario
Location: tests/e2e/{workflow}.spec.ts
Page objects: tests/e2e/pages/{page}.page.ts
Fixtures: tests/e2e/fixtures/{fixture}.ts
```

**Structure (Playwright):**

```typescript
import { test, expect } from '@playwright/test';
import { LoginPage } from './pages/login.page';

// Auth fixture: reuse storageState for all tests except the login test itself
test.use({ storageState: './tests/e2e/.auth/user.json' });

test.describe('E2E-WF-001: User Registration Flow', () => {
  test('Happy path: complete registration', async ({ page }) => {
    // Step 1: Navigate
    await page.goto('/register');
    await expect(page).toHaveTitle(/Create Account/i);

    // Step 2: Accessibility scan
    // (axe-core check — see construction-protocol.md for setup)

    // Step 3: Fill form (use role-based locators)
    await page.getByLabel('Email').fill('test@example.com');
    await page.getByLabel('Password').fill('SecurePass123!');

    // Step 4: Submit
    await page.getByRole('button', { name: /register/i }).click();

    // Step 5: Wait for result
    await expect(page.getByText('Welcome')).toBeVisible();

    // Step 6: Assert final state
    await expect(page).toHaveURL(/\/dashboard/);
  });

  test('Error variation: duplicate email', async ({ page }) => {
    await page.goto('/register');
    await page.getByLabel('Email').fill('existing@example.com');
    await page.getByLabel('Password').fill('SecurePass123!');
    await page.getByRole('button', { name: /register/i }).click();

    // Assert error feedback
    await expect(page.getByRole('alert')).toContainText('already in use');
  });
});
```

**Page Object pattern:**

```typescript
// tests/e2e/pages/login.page.ts
import { Page, Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorAlert: Locator;

  constructor(private page: Page) {
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: /sign in/i });
    this.errorAlert = page.getByRole('alert');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string) {
    await expect(this.errorAlert).toContainText(message);
  }
}
```

**Selector priority (same as test/E2E-SCENARIOS.md):**
1. `getByRole()` — preferred, tests accessibility
2. `getByLabel()` — form fields
3. `getByText()` — content assertions
4. `getByTestId()` — fallback with justification

**Critical rules:**
- Each test gets its own browser context (Playwright default — do NOT share `page` across tests)
- Auth via `storageState`, not login-through-UI for every test
- All assertions use locator-based `expect(locator)`, never `expect(await page.textContent(...))`
- Wait for stable state before interacting (no arbitrary `page.waitForTimeout()`)
- E2E tests require a running server — prefer the suite's own `webServer`; otherwise the server helper of `references/stack-profile.md` §8 (`{server}`, log `.sdd/server.log`, stopped at the end of the block)
- When an acceptance suite already exists (`acceptance` key, `acceptance/playwright.config.*`, `e2e/`, `test/system/`) write the scenario inside it and never scaffold a new one; the task is done when `{acceptance} --grep <E2E-ID>` passes

---

## Test-First Decision Tree

```
Is this task testable?
├── YES (entity, endpoint, service, middleware, event handler)
│   ├── Does acceptance criteria define specific behavior?
│   │   ├── YES → Write tests covering each criterion
│   │   └── NO → Write tests based on UC flows + invariants
│   └── Does the task have exception flows?
│       ├── YES → Write tests for each exception
│       └── NO → Write happy path tests only
│
└── NO (config, setup, toolchain files, env variables)
    └── Define manual verification steps instead:
        "Verification: {command} produces {expected result}"
```

---

## Writing Tests from Acceptance Criteria

The task document provides acceptance criteria. Each criterion maps to one or more tests, and a criterion that cites a scenario id puts it in the test name (Test names carry the scenario id).

**Example task:**

```markdown
- [ ] TASK-F0-003 Create auth middleware | `src/middleware/auth.ts`
  - **Acceptance:**
    - Extracts user_id, org_id, role from valid JWT (AC-002-01)
    - Returns 401 with error body when token missing (AC-002-02)
    - Returns 401 when token expired (AC-002-03)
    - Enforces INV-TENANT-001 (tenant isolation via org_id)
```

**Generated tests:**

```typescript
describe('AuthMiddleware', () => {
  // Criterion 1: Extracts user context from valid JWT
  it('AC-002-01 extracts user_id, org_id, role from valid JWT', async () => {
    const token = createValidJWT({ user_id: 'u1', org_id: 'o1', role: 'recruiter' });
    const req = createRequest({ authorization: `Bearer ${token}` });
    const ctx = await authMiddleware(req);
    expect(ctx.user_id).toBe('u1');
    expect(ctx.org_id).toBe('o1');
    expect(ctx.role).toBe('recruiter');
  });

  // Criterion 2: Returns 401 when token missing
  it('AC-002-02 returns 401 when Authorization header is missing', async () => {
    const req = createRequest({ /* no auth header */ });
    const res = await authMiddleware(req);
    expect(res.status).toBe(401);
    expect(await res.json()).toHaveProperty('error');
  });

  // Criterion 3: Returns 401 when token expired
  it('AC-002-03 returns 401 when token is expired', async () => {
    const token = createExpiredJWT();
    const req = createRequest({ authorization: `Bearer ${token}` });
    const res = await authMiddleware(req);
    expect(res.status).toBe(401);
  });

  // Criterion 4: Enforces INV-TENANT-001
  it('should enforce tenant isolation via org_id (INV-TENANT-001)', async () => {
    const token = createValidJWT({ user_id: 'u1', org_id: 'o1', role: 'recruiter' });
    const req = createRequest({ authorization: `Bearer ${token}` });
    const ctx = await authMiddleware(req);
    expect(ctx.org_id).toBeDefined();
    // Verify org_id is propagated to downstream handlers
  });
});
```

---

## Writing Tests from UC Exception Flows

Each exception flow in a Use Case becomes a test:

**Example UC-002 exception flows:**

```
E1: Token no proporcionado → 401 Unauthorized
E2: Token expirado → 401 Unauthorized, header WWW-Authenticate
E3: Token manipulado (firma invalida) → 401 Unauthorized
E4: Rol no autorizado para la operacion → 403 Forbidden
```

**Generated tests:**

```typescript
describe('UC-002 Exception Flows', () => {
  it('E1: should return 401 when token not provided', () => { ... });
  it('E2: should return 401 with WWW-Authenticate when token expired', () => { ... });
  it('E3: should return 401 when token signature is invalid', () => { ... });
  it('E4: should return 403 when role is not authorized', () => { ... });
});
```

---

## Writing Tests from Invariants

Each INV-* referenced in the task becomes a test:

```typescript
// INV-TENANT-001: Tenant isolation — every query must include org_id
it('should include org_id filter in all queries (INV-TENANT-001)', () => {
  const query = repository.buildQuery({ user_id: 'u1' });
  expect(query).toContain('org_id');
});

// INV-SEC-001: IV never reused in encryption
it('should generate unique IV for each encryption (INV-SEC-001)', () => {
  const result1 = encrypt('data', key);
  const result2 = encrypt('data', key);
  expect(result1.iv).not.toBe(result2.iv);
});
```

---

## Test Quality Checklist

Before marking a test as complete:

```
[ ] Test name carries the scenario id and describes behavior, not implementation
    WRONG: "should call validateToken function"
    RIGHT: "AC-002-03 returns 401 when token is expired"

[ ] Assertions are specific
    WRONG: expect(result).toBeTruthy()
    RIGHT: expect(result.status).toBe(401)

[ ] No hardcoded magic values
    WRONG: expect(result.limit).toBe(100)
    RIGHT: expect(result.limit).toBe(RATE_LIMIT_BURST) // from config

[ ] Test is independent (no shared mutable state between tests)

[ ] Test covers edge cases from spec

[ ] Error message in assertion is descriptive (if framework supports it)

[ ] No implementation details leaked into test
    WRONG: expect(mockDb.query).toHaveBeenCalledWith('SELECT * FROM...')
    RIGHT: expect(result.users).toHaveLength(3)
```

---

## Non-Testable Tasks: Verification Steps

For configuration and setup tasks, define explicit verification with the Stack Profile keys
(`references/stack-profile.md`; a key resolved to `none` is skipped with `WARN <key>: n/a (stack profile)`):

```markdown
### TASK-F0-001: Configure runtime / framework config
Verification:
  1. `{server}` starts without errors (server helper, stack-profile.md §8)
  2. Health endpoint responds at localhost:{port}/health
  3. Bindings / credentials placeholders resolve

### TASK-F0-002: Initialize project
Verification:
  1. `{install}` completes without errors
  2. `{typecheck}` compiles without errors
  3. `{lint}` passes

### TASK-F0-010: Configure database
Verification:
  1. Migrations apply with the stack's non-destructive command
  2. `{test_file}` on the first repository/model test connects and passes
```

Legacy `ts-workers` values give the pre-4.3 steps, e.g. `npx wrangler dev`, localhost:8787/health, `npm install`, `npx tsc --noEmit`, `npm run lint`, `npx wrangler d1 list` / `npx wrangler d1 execute DB --command "SELECT 1"`.

---

## Test Execution Strategy

Commands are Stack Profile keys, run from `app_dir` (`references/stack-profile.md` §2, cadence §9). Legacy
`ts-workers` values in comments.

### During Task Implementation (per-task)

```bash
# Run only tests for current task
{test_file}                 # e.g. npx vitest run tests/middleware/auth.test.ts

# Or name/pattern-based
{test_name}                 # e.g. npx vitest run -t "AuthMiddleware"
```

### After Task Complete (per-task checks)

```bash
{test_file}                 # the task's tests + existing tests of the changed files
{typecheck}                 # npx tsc --noEmit
{lint_files}                # changed files only
```

The full suite is **not** run per task: regressions are caught at the Foundation checkpoint and in Phase 9. Run it
earlier only when the task changes something shared by many tests (test helpers, DB schema, middleware chain, config).
After a schema/migration change run `{db_reset_safe}` only when the test runner does not prepare the database itself.

### At Foundation Checkpoint and Phase 9

```bash
{test}                      # e.g. npx vitest run — full own suite
{coverage}                  # e.g. npx vitest run --coverage (Phase 9)
{acceptance}                # Phase 9, once; then only failures: {acceptance} --grep <ID>
```

**Per-file coverage verification:**
After running coverage, check the report for each source file listed in PLAN-FASE §7.4 Coverage Map:
- If any mapped source file shows 0% → stop and create missing test
- If any domain logic file (entity, service, state-machine) shows < 80% lines → add tests before proceeding
- Files in the Exclusions table with valid justification can be skipped
- Report coverage summary in the FASE completion output
- `coverage: none` → `WARN coverage: n/a (stack profile)`; report "Coverage: n/a"

### Handling Test Failures

```
IF test fails during RED phase:
  → Expected! This confirms the test is valid. Proceed to GREEN.

IF test fails during GREEN phase:
  → Bug in implementation. Debug and fix. Do NOT modify the test.

IF test fails during REFACTOR phase:
  → Refactoring broke something. Undo last change. Try again.

IF previously-passing test fails after new task:
  → Regression! PAUSE. Investigate interaction between tasks.
  → Check if tasks should have been COUPLED instead of independent.
```
