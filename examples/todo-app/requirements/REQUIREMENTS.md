# Requirements Document

> **Project:** todo-app
> **Version:** 1.0
> **Last updated:** 2026-08-24
> **Status:** Approved

## Functional Requirements

### REQ-F-001: Create a task
- **Statement:** WHEN the user runs `todo add <title>` THE system SHALL create a task with a unique incremental id, the given title, status `pending` and the creation timestamp.
- **Category:** Functional
- **Priority:** Must have
- **Source:** Product owner
- **Rationale:** Capturing tasks is the core purpose of the tool.
- **Acceptance criteria:**
  - GIVEN an empty task list WHEN the user runs `todo add "Buy milk"` THEN a task with id 1, title "Buy milk" and status `pending` is stored
  - GIVEN a task list with 3 tasks WHEN the user adds a task THEN the new task gets id 4
  - GIVEN any state WHEN the user runs `todo add ""` THEN the system rejects the command with exit code 2 and the message `title must not be empty`
- **Dependencies:** None

### REQ-F-002: List tasks
- **Statement:** WHEN the user runs `todo list` THE system SHALL print all tasks ordered by id, one per line, in the format `<id> [ ] <title>` for pending tasks and `<id> [x] <title>` for completed tasks.
- **Category:** Functional
- **Priority:** Must have
- **Source:** Product owner
- **Rationale:** Users need to see their tasks at a glance.
- **Acceptance criteria:**
  - GIVEN tasks 1 (pending) and 2 (completed) WHEN the user runs `todo list` THEN the output is exactly two lines: `1 [ ] …` and `2 [x] …`
  - GIVEN an empty task list WHEN the user runs `todo list` THEN the output is `No tasks` and the exit code is 0
- **Dependencies:** REQ-F-001

### REQ-F-003: Complete a task
- **Statement:** WHEN the user runs `todo done <id>` THE system SHALL set the status of the task to `completed` and record the completion timestamp.
- **Category:** Functional
- **Priority:** Must have
- **Source:** Product owner
- **Rationale:** Tracking progress requires marking tasks as done.
- **Acceptance criteria:**
  - GIVEN task 1 is pending WHEN the user runs `todo done 1` THEN task 1 is completed and `todo list` shows `1 [x] …`
  - GIVEN task 1 is already completed WHEN the user runs `todo done 1` THEN the system prints `task 1 is already completed` and exits with code 0
  - GIVEN no task with id 9 WHEN the user runs `todo done 9` THEN the system exits with code 3 and the message `task 9 not found`
- **Dependencies:** REQ-F-001

### REQ-F-004: Delete a task
- **Statement:** WHEN the user runs `todo rm <id>` THE system SHALL remove the task permanently without renumbering the remaining tasks.
- **Category:** Functional
- **Priority:** Must have
- **Source:** Product owner
- **Rationale:** Users must be able to discard tasks created by mistake.
- **Acceptance criteria:**
  - GIVEN tasks 1, 2 and 3 WHEN the user runs `todo rm 2` THEN `todo list` shows tasks 1 and 3 only
  - GIVEN no task with id 9 WHEN the user runs `todo rm 9` THEN the system exits with code 3 and the message `task 9 not found`
- **Dependencies:** REQ-F-001

### REQ-F-005: Filter tasks by status
- **Statement:** WHEN the user runs `todo list --status <pending|completed>` THE system SHALL print only the tasks with that status, in the same format as REQ-F-002.
- **Category:** Functional
- **Priority:** Should have
- **Source:** Product owner
- **Rationale:** Long lists need to be narrowed down to what is left to do.
- **Acceptance criteria:**
  - GIVEN tasks 1 (pending) and 2 (completed) WHEN the user runs `todo list --status pending` THEN only `1 [ ] …` is printed
  - GIVEN any state WHEN the user runs `todo list --status other` THEN the system exits with code 2 and the message `status must be pending or completed`
- **Dependencies:** REQ-F-002

### REQ-F-006: Persist tasks between runs
- **Statement:** WHEN any command modifies the task list THE system SHALL persist the full list to `data/todos.json` before exiting, and WHEN any command starts THE system SHALL load the list from that file if it exists.
- **Category:** Functional
- **Priority:** Must have
- **Source:** Product owner
- **Rationale:** A task list that disappears between invocations is useless.
- **Acceptance criteria:**
  - GIVEN a fresh checkout WHEN the user runs `todo add "A"` THEN `data/todos.json` exists and contains one task
  - GIVEN `data/todos.json` with 2 tasks WHEN the user runs `todo list` in a new process THEN both tasks are printed
  - GIVEN a corrupted `data/todos.json` WHEN any command runs THEN the system exits with code 4 and the message `data/todos.json is not valid JSON` without overwriting the file
- **Dependencies:** REQ-F-001

## Nonfunctional Requirements

### REQ-NF-001: Command latency
- **Statement:** THE system SHALL complete any command over a list of up to 1,000 tasks in less than 200 ms of wall-clock time on the reference machine.
- **Category:** Performance
- **Priority:** Should have
- **Metric:** p95 < 200 ms with 1,000 tasks, measured by the test suite
- **Acceptance criteria:**
  - GIVEN `data/todos.json` with 1,000 tasks WHEN the user runs `todo list` THEN the command finishes in under 200 ms (p95 over 20 runs)

### REQ-NF-002: Test coverage
- **Statement:** THE system SHALL keep automated test coverage of the `api` module at 90 % of statements or higher.
- **Category:** Usability
- **Priority:** Must have
- **Metric:** vitest coverage report, statements ≥ 90 % for `src/api/**`
- **Acceptance criteria:**
  - GIVEN the test suite WHEN `npm test -- --coverage` runs THEN statements coverage of `src/api/**` is ≥ 90 %

## Constraints

### REQ-C-001: Runtime and language
- **Statement:** The system is implemented in TypeScript (ESM) on Node.js ≥ 18, tested with vitest, with no runtime dependencies.
- **Type:** Technical
- **Source:** Team standard (see README.md)

### REQ-C-002: Module boundaries
- **Statement:** Business logic lives in `src/api/` (pure functions and the JSON repository) and the command-line interface in `src/cli/`; `src/cli/` may import `src/api/` but never the reverse.
- **Type:** Technical
- **Source:** Architecture guideline (enables independent implementation streams)

## Traceability

| REQ ID | Type | Priority | Source | Acceptance Criteria |
|--------|------|----------|--------|---------------------|
| REQ-F-001 | Functional | Must | Product owner | Yes |
| REQ-F-002 | Functional | Must | Product owner | Yes |
| REQ-F-003 | Functional | Must | Product owner | Yes |
| REQ-F-004 | Functional | Must | Product owner | Yes |
| REQ-F-005 | Functional | Should | Product owner | Yes |
| REQ-F-006 | Functional | Must | Product owner | Yes |
| REQ-NF-001 | Nonfunctional | Should | Team standard | Yes |
| REQ-NF-002 | Nonfunctional | Must | Team standard | Yes |
| REQ-C-001 | Constraint | Must | Team standard | — |
| REQ-C-002 | Constraint | Must | Architecture guideline | — |
