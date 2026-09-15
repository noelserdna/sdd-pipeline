# Tasks: FASE-1 — Task list

> **Input:** plan/fases/FASE-1-tasks.md + plan/fase-plans/PLAN-FASE-1.md
> **Total tasks:** 6
> **Parallel capacity:** 2
> **Critical path:** TASK-F1-001 → TASK-F1-002 → TASK-F1-003 → TASK-F1-005 → TASK-F1-006

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | 6 |
| Parallelizable | 2 (33%) |
| Work Streams | 2 (A: 1 task, B: 1 task) |

## Traceability

| Spec Reference | Task Coverage |
|---------------|---------------|
| UC-001 | TASK-F1-003 |
| INV-TSK-002 | TASK-F1-002, TASK-F1-003 |

---

## Phase 1: Setup

**Purpose:** Project structure, dependencies, configuration.

- [x] TASK-F1-001 Scaffold the app with pinned dependencies | `Gemfile`, `Gemfile.lock`
  - **Commit:** `chore(bootstrap): scaffold app with pinned dependencies`
  - **Acceptance:** the app boots and every dependency version is pinned
  - **Refs:** FASE-1, ADR-001
  - **Revert:** COUPLED — every later task writes inside the app
  - **Review:** [ ] versions pinned [ ] no extra generators

## Phase 2: Foundation

- [x] TASK-F1-002 Create the tasks table and the Task model with title invariants, test-first | `db/migrate/001_create_tasks.rb`, `app/models/task.rb`, `test/models/task_test.rb`
  - blocked-by: TASK-F1-001
  - **Files:** `db/schema.rb`
  - **Commit:** `feat(tasks): add Task model with title invariants`
  - **Acceptance:**
    - Test first: a blank title is invalid (INV-TSK-002)
    - `created_at` orders the list (INV-TSK-004)
  - **Refs:** FASE-1, ENT-001, INV-TSK-002, INV-TSK-004
  - **Revert:** MIGRATION — roll the migration back before reverting
  - **Review:**
    - [ ] The model test fails before the model exists

## Phase 3: Slices

Example kept inside a fence (must be ignored by the parser):

```markdown
### TASK-F1-099 — not a task
- [ ] TASK-F1-098 Not a task either | `nowhere.rb`
```

- [ ] TASK-F1-003 [P] Create task (API-001-01) with server-side validation, test-first | `app/controllers/tasks_controller.rb`, `app/views/tasks/_form.html.erb`, `test/controllers/tasks_create_test.rb`
  - blocked-by: TASK-F1-002
  - **Commit:** `feat(tasks): create task with server-side title validation`
  - **Acceptance:**
    - Test first: a blank title re-renders the form with the alert (AC-001-02)
    - A valid title redirects to the list (UC-001)
  - **Refs:** FASE-1, UC-001, API-001-01, INV-TSK-002
  - **Revert:** SAFE — the create form disappears
  - **Review:** [ ] test fails first [ ] messages match API-001-01

- [!] TASK-F1-004 [P] Rename task (API-001-03), test-first | `app/controllers/titles_controller.rb`, `test/controllers/titles_controller_test.rb`
  - blocked-by: TASK-F1-002
  - **Commit:** `feat(tasks): rename task keeping position and status`
  - **Acceptance:** Test first: renaming keeps `created_at` and status (INV-TSK-006)
  - **Refs:** FASE-1, UC-003, API-001-03, INV-TSK-006
  - **Revert:** SAFE — rename is no longer available
  - **Review:** [ ] test fails first

## Phase 4: Integration

- [ ] TASK-F1-005 Register the task routes and the layout alert region | `config/routes.rb`, `app/views/layouts/application.html.erb`
  - blocked-by: TASK-F1-003, TASK-F1-004
  - **Commit:** `feat(tasks): wire task routes and layout alert region`
  - **Acceptance:** `GET /` lists tasks; create and rename are reachable (UC-001, UC-003)
  - **Refs:** FASE-1, UC-001, UC-003
  - **Revert:** COUPLED — revert TASK-F1-003 and TASK-F1-004 after this one
  - **Review:** [ ] routes match design/OPERATION-MAPPING.md

## Phase 5: Verification

- [ ] TASK-F1-006 Verify the FASE-1 Criterios de Éxito and the WF-001 journey | `test/system/tasks_flow_test.rb`
  - blocked-by: TASK-F1-005
  - **Commit:** `test(tasks): verify FASE-1 acceptance criteria`
  - **Acceptance:** every FASE-1 criterion passes with evidence (WF-001)
  - **Refs:** FASE-1, WF-001
  - **Revert:** SAFE
  - **Review:** [ ] all criteria checked [ ] evidence documented

---

## Dependencies

### Critical Path

1. TASK-F1-001 → TASK-F1-002 → TASK-F1-003 → TASK-F1-005 → TASK-F1-006

### Parallel Execution Plan

**Stream A:** create — see Stream Ownership
**Stream B:** rename — see Stream Ownership

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F1-001, TASK-F1-002 | `Gemfile`, `Gemfile.lock`, `db/**`, `app/models/task.rb`, `test/models/**` | main checkout, before worktrees (checkpoint `fase-1-foundation`) |
| A | TASK-F1-003 | `app/controllers/tasks_controller.rb`, `app/views/tasks/**`, `test/controllers/tasks_create_test.rb` | worktree `feat/fase-1-a` |
| B | TASK-F1-004 | `app/controllers/titles_controller.rb`, `test/controllers/titles_controller_test.rb` | worktree `feat/fase-1-b` |
| integración | TASK-F1-005 | `config/routes.rb`, `app/views/layouts/application.html.erb` | main checkout, after `--integrate --fase 1` |
| verificación | TASK-F1-006 | `test/system/**` | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Foundation | TASK-F1-002 | `fase-1-foundation` | main checkout |
| Verified | TASK-F1-006 | `fase-1-verified` | main checkout |
