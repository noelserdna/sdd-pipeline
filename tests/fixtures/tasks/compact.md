# Tasks: FASE-2 — Filters

> **Critical path:** TASK-F2-001 → TASK-F2-002 → TASK-F2-004

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F2-001 | `app/models/filter.rb`, `test/models/filter_test.rb` | main checkout, before worktrees (checkpoint `fase-2-foundation`) |
| A | TASK-F2-002, TASK-F2-003 | `app/controllers/tasks_controller.rb`, `app/views/tasks/**`, `test/controllers/**` | worktree `feat/fase-2-a` |
| integración | — | — | main checkout, after `--integrate --fase 2` |
| verificación | TASK-F2-004 | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Foundation | TASK-F2-001 | `fase-2-foundation` | main checkout |
| Verified | TASK-F2-004 | `fase-2-verified` | main checkout |

## Foundation

- [ ] TASK-F2-001 Parse the `estado` filter with a silent fallback, test-first | `app/models/filter.rb`, `test/models/filter_test.rb`
  - **Commit:** `feat(filters): parse estado with fallback to all`
  - **Acceptance:** Test first: unknown values fall back to `todas` (VO-004)
  - **Refs:** FASE-2, VO-004

## Slices

- [ ] TASK-F2-002 [P] Filter the list (API-001-02), test-first | `app/controllers/tasks_controller.rb`, `app/views/tasks/index.html.erb`, `test/controllers/tasks_index_test.rb`
  - blocked-by: TASK-F2-001
  - **Commit:** `feat(filters): filter the task list by estado`
  - **Acceptance:** Test first: `?estado=completadas` lists only completed tasks (UC-006)
  - **Refs:** FASE-2, UC-006, API-001-02

- [ ] TASK-F2-003 Keep the filter across mutations (API-001-03, API-001-04), test-first | `app/views/tasks/_row.html.erb`, `test/controllers/tasks_filter_test.rb`
  - blocked-by: TASK-F2-002
  - **Commit:** `feat(filters): keep estado across mutations`
  - **Acceptance:** Test first: rename and toggle redirect with the same `estado`
  - **Refs:** FASE-2, UC-003, UC-004
  - **Revert:** COUPLED — revert before TASK-F2-002

## Verification

- [ ] TASK-F2-004 Verify the FASE-2 Criterios de Éxito | `test/system/filters_test.rb`
  - blocked-by: TASK-F2-003
  - **Commit:** `test(filters): verify FASE-2 acceptance criteria`
  - **Acceptance:** every FASE-2 criterion passes with evidence
  - **Refs:** FASE-2, UC-006
