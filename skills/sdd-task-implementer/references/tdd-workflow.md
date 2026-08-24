# Test-First Development Workflow

> Reference for the TDD cycle within sdd-task-implementer.
> Maps SWEBOK §4.4.16 (Test-First Programming) and §4.3.4 (Construction Testing)
> to the task-by-task implementation loop.

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
Location: tests/unit/{module}.test.ts
```

**Naming convention:**

```typescript
describe('{ModuleName}', () => {
  describe('{methodName}', () => {
    it('should {expected behavior} when {condition}', () => {
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
describe('{API-Name} Contract', () => {
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
describe('BDD: {Scenario Name}', () => {
  it('GIVEN {precondition} WHEN {action} THEN {expected outcome}', async () => {
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
- E2E tests require a running server — document in task how to start it

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
└── NO (config, setup, wrangler.toml, env variables)
    └── Define manual verification steps instead:
        "Verification: {command} produces {expected result}"
```

---

## Writing Tests from Acceptance Criteria

The task document provides acceptance criteria. Each criterion maps to one or more tests.

**Example task:**

```markdown
- [ ] TASK-F0-003 Create auth middleware | `src/middleware/auth.ts`
  - **Acceptance:**
    - Extracts user_id, org_id, role from valid JWT
    - Returns 401 with error body when token missing
    - Returns 401 when token expired
    - Enforces INV-SYS-001 (tenant isolation via org_id)
```

**Generated tests:**

```typescript
describe('AuthMiddleware', () => {
  // Criterion 1: Extracts user context from valid JWT
  it('should extract user_id, org_id, role from valid JWT', async () => {
    const token = createValidJWT({ user_id: 'u1', org_id: 'o1', role: 'recruiter' });
    const req = createRequest({ authorization: `Bearer ${token}` });
    const ctx = await authMiddleware(req);
    expect(ctx.user_id).toBe('u1');
    expect(ctx.org_id).toBe('o1');
    expect(ctx.role).toBe('recruiter');
  });

  // Criterion 2: Returns 401 when token missing
  it('should return 401 when Authorization header is missing', async () => {
    const req = createRequest({ /* no auth header */ });
    const res = await authMiddleware(req);
    expect(res.status).toBe(401);
    expect(await res.json()).toHaveProperty('error');
  });

  // Criterion 3: Returns 401 when token expired
  it('should return 401 when token is expired', async () => {
    const token = createExpiredJWT();
    const req = createRequest({ authorization: `Bearer ${token}` });
    const res = await authMiddleware(req);
    expect(res.status).toBe(401);
  });

  // Criterion 4: Enforces INV-SYS-001
  it('should enforce tenant isolation via org_id (INV-SYS-001)', async () => {
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
// INV-SYS-001: Tenant isolation — every query must include org_id
it('should include org_id filter in all queries (INV-SYS-001)', () => {
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
[ ] Test name describes behavior, not implementation
    WRONG: "should call validateToken function"
    RIGHT: "should return 401 when token is expired"

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

For configuration and setup tasks, define explicit verification:

```markdown
### TASK-F0-001: Configure wrangler.toml
Verification:
  1. `npx wrangler dev` starts without errors
  2. Health endpoint responds at localhost:8787/health
  3. KV namespace binding resolves

### TASK-F0-002: Initialize TypeScript project
Verification:
  1. `npm install` completes without errors
  2. `npx tsc --noEmit` compiles without errors
  3. `npm run lint` passes

### TASK-F0-010: Configure D1 database binding
Verification:
  1. `npx wrangler d1 list` shows the database
  2. `npx wrangler d1 execute DB --command "SELECT 1"` returns result
```

---

## Test Execution Strategy

### During Task Implementation (per-task)

```bash
# Run only tests for current task
npx vitest run tests/middleware/auth.test.ts

# Or pattern-based
npx vitest run --grep "AuthMiddleware"
```

### After Task Complete (regression check)

```bash
# Run full test suite to catch regressions
npx vitest run

# Or run only tests for current FASE
npx vitest run tests/
```

### At Phase Checkpoint

```bash
# Full suite with coverage
npx vitest run --coverage
```

**Per-file coverage verification:**
After running coverage, check the report for each source file listed in PLAN-FASE §7.4 Coverage Map:
- If any mapped source file shows 0% → stop and create missing test
- If any domain logic file (entity, service, state-machine) shows < 80% lines → add tests before proceeding
- Files in the Exclusions table with valid justification can be skipped
- Report coverage summary in the FASE completion output

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
