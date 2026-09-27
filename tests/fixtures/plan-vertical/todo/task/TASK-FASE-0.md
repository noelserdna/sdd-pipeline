# Tasks: FASE-0 — Esqueleto
> **Critical path:** TASK-F0-001 → TASK-F0-002 → TASK-F0-003 → TASK-F0-004 → TASK-F0-005

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F0-001 | package.json | main checkout, before worktrees (checkpoint `fase-0-foundation`) |
| A | TASK-F0-002, TASK-F0-003, TASK-F0-004 | src/**, tests/**, demo/** | main checkout (serial) |
| integración | — | — | — |
| verificación | TASK-F0-005 | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Verified | TASK-F0-005 | `fase-0-verified` | main checkout |

## Setup

- [ ] TASK-F0-001 Scaffold the TypeScript CLI with vitest and coverage | `package.json`, `tsconfig.json`
  - **Commit:** `build(todo): scaffold the TypeScript CLI`
  - **Acceptance:** `npm test` runs an empty suite; `npm run build` emits `dist/`
  - **Refs:** FASE-0, REQ-C-001

## Slices

### UC-001 — Crear tarea

- [ ] TASK-F0-002 Add a task persisted to data/todos.json, test-first | `src/api/tasks.ts`, `src/api/repository.ts`, `tests/api/tasks.test.ts`
  - **Commit:** `feat(tasks): add a task and persist the list`
  - **Acceptance:** Test first: `AC-001-01`, `AC-001-02`, `AC-001-03`, `AC-001-04` in the test names
  - **Refs:** FASE-0, REQ-F-001, REQ-F-006, UC-001

### UC-002 — Listar tareas

- [ ] TASK-F0-003 List tasks from the file, test-first | `src/api/list.ts`, `tests/api/list.test.ts`
  - blocked-by: TASK-F0-002
  - **Commit:** `feat(tasks): list tasks in id order`
  - **Acceptance:** Test first: `AC-002-01`, `AC-002-02`, `AC-002-03`, `AC-002-04`
  - **Refs:** FASE-0, REQ-F-002, REQ-F-006, UC-002

- [ ] TASK-F0-004 CLI commands add and list with the demo seed | `src/cli/main.ts`, `tests/cli/main.test.ts`, `demo/seed-fase-0.json`
  - blocked-by: TASK-F0-003
  - **Commit:** `feat(cli): todo add and todo list`
  - **Acceptance:** Test first: exit codes of AC-001-03 and AC-002-04 through the CLI
  - **Refs:** FASE-0, UC-001, UC-002

## Verification

- [ ] TASK-F0-005 Coverage gate and FASE-0 criteria | `tests/`
  - **Commit:** `test(todo): verify FASE-0 criteria and coverage`
  - **Acceptance:** `REQ-NF-002 AC1` statements of src/api ≥ 90 %
  - **Refs:** FASE-0, REQ-NF-002
