# Tasks: FASE-1 — Bold ids (legacy shape)

## Phase 1: Setup

- [x] **TASK-F1-001** Scaffold the app with pinned dependencies | `Gemfile`
  - **Commit:** `chore(bootstrap): scaffold app`
  - **Acceptance:** the app boots
  - **Refs:** FASE-1, ADR-001

## Phase 3: Slices

- [ ] **TASK-F1-002** [P] Create task (API-001-01), test-first | `app/controllers/tasks_controller.rb`, `test/controllers/tasks_controller_test.rb`
  - **Commit:** `feat(tasks): create task`
  - **Acceptance:** a blank title is rejected (AC-001-02)
  - **Refs:** FASE-1, UC-001, API-001-01

- **TASK-F1-003** List tasks (API-001-02), test-first | `app/views/tasks/index.html.erb`
  - **Commit:** `feat(tasks): list tasks`
  - **Acceptance:** tasks are listed in creation order (INV-TSK-004)
  - **Refs:** FASE-1, UC-002, API-001-02
