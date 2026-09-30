# Tasks: FASE-0 — Esqueleto

> **Critical path:** TASK-F0-001 → TASK-F0-002 → TASK-F0-004 → TASK-F0-006

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F0-001 | package.json | main checkout, before worktrees (checkpoint `fase-0-foundation`) |
| A | TASK-F0-002, TASK-F0-003, TASK-F0-004, TASK-F0-005 | src/**, tests/** | main checkout (serial) |
| integración | — | — | — |
| verificación | TASK-F0-006 | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Verified | TASK-F0-006 | `fase-0-verified` | main checkout |

## Setup

- [ ] TASK-F0-001 Scaffold the TypeScript CLI with vitest and Playwright | `package.json`, `tsconfig.json`
  - **Commit:** `build(todo): scaffold the TypeScript CLI`
  - **Acceptance:** Verify: `npm test` runs an empty suite
  - **Refs:** FASE-0, REQ-C-001

## Slices

- [ ] TASK-F0-002 Add a task persisted to data/todos.json, test-first | `src/api/tasks.ts`, `src/api/sync.ts`, `tests/doubles/sync-fake.ts`, `tests/api/tasks.test.ts`
  - **Commit:** `feat(tasks): add a task and persist the list`
  - **Acceptance:** Test first: `REQ-F-001 AC1`, `REQ-F-001 AC2`, `REQ-F-001 AC3`, `REQ-F-006 AC1` in the test names
  - **Refs:** FASE-0, REQ-F-001, REQ-F-006

- [ ] TASK-F0-003 Sync adapter over HTTP, test-first | `src/adapters/http-sync.ts`, `tests/adapters/http-sync.test.ts`
  - blocked-by: TASK-F0-002
  - **Commit:** `feat(sync): HTTP adapter for SyncClient`
  - **Acceptance:** Test first: posts the task to the sync endpoint
  - **Refs:** FASE-0, REQ-F-006

- [ ] TASK-F0-004 List tasks from the file, test-first | `src/api/list.ts`, `tests/api/list.test.ts`
  - blocked-by: TASK-F0-002
  - **Commit:** `feat(tasks): list tasks in id order`
  - **Acceptance:** Test first: `REQ-F-002 AC1`, `REQ-F-002 AC2`, `REQ-F-006 AC2`, `REQ-F-006 AC3`
  - **Refs:** FASE-0, REQ-F-002, REQ-F-006

- [ ] TASK-F0-005 Contract test SyncClient: double and real provider agree | `tests/contract/sync-client.contract.test.ts`
  - blocked-by: TASK-F0-002, TASK-F0-003
  - **Commit:** `test(sync): contract test for the SyncClient double and its real provider`
  - **Acceptance:** Test first: `CONTRACT-SyncClient REQ-F-006 AC1` runs the same assertions on the double and on the real provider through a fake transport; observable: the body carries the task title and status
  - **Refs:** FASE-0, REQ-F-006

## Verification

- [ ] TASK-F0-006 Journey FASE-0: add and list through the CLI with captures | `e2e/fase-0.journey.spec.ts`
  - blocked-by: TASK-F0-004, TASK-F0-005
  - **Commit:** `test(todo): FASE-0 journey from the user's route with captures`
  - **Acceptance:**
    - Test first: named after REQ-F-001 AC1, REQ-F-001 AC2, REQ-F-001 AC3, REQ-F-002 AC1, REQ-F-002 AC2, REQ-F-006 AC1, REQ-F-006 AC2, REQ-F-006 AC3
    - Enters through Demo step 1 (`todo list`), never an internal entry point
    - Asserts the example text of each criterion, not the container's visibility
    - Saves `evidencias/FASE-0/REQ-F-001-AC1.png` per criterion and `evidencias/FASE-0/FASE-0.webm`, attached to the test
  - **Refs:** FASE-0, REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002 AC1
