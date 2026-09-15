# Tasks: FASE-3 — Invalid on purpose

## Phase 3: Slices

- [ ] TASK-F3-001 Create task without write-set
  - **Commit:** `feat(tasks): create task`
  - **Acceptance:** a blank title is rejected

- [ ] TASK-F3-002 Missing commit message | `app/models/task.rb`
  - **Acceptance:** something observable

- [ ] TASK-F3-003 Missing acceptance criteria | `app/models/filter.rb`
  - **Commit:** `feat(filters): add filter`

- [ ] TASK-F3-002 Duplicate id | `app/views/tasks/index.html.erb`
  - **Commit:** `feat(tasks): duplicate`
  - **Acceptance:** duplicate

- [ ] TASK-F3-04 Short sequence | `app/views/tasks/_row.html.erb`
  - **Commit:** `feat(tasks): short sequence`
  - **Acceptance:** short

- [ ] TASK-F3-005 Unindented field line | `config/routes.rb`
**Commit:** `feat(tasks): unindented`
  - **Acceptance:** unindented

  - [ ] TASK-F3-006 Indented task line | `config/locales/es.yml`
  - **Commit:** `feat(i18n): indented`
  - **Acceptance:** indented

- [ ] TASK-F3-007 [PLAN GAP] Token format not specified
  - **Gap:** PLAN-FASE-3 does not specify the token format
  - **Commit:** N/A (blocked)

- [ ] TASK-F3-008 Paths without backticks | app/models/task.rb
  - **Commit:** `feat(tasks): no backticks`
  - **Acceptance:** no backticks

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F3-001 | — | main checkout |
| A | TASK-F3-002, TASK-F3-003, TASK-F3-099 | `app/**` | worktree `feat/fase-3-a` |
| B | TASK-F3-003 | `config/**` | worktree `feat/fase-3-b` |
| verificación | — | — | main checkout, Phase 9 |
