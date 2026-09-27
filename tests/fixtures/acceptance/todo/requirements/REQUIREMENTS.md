# Requirements Document

> **Project:** todo (acceptance fixture)
> **Examples reviewed by:** Laura Gómez (product owner), 2026-08-22

## Functional Requirements

### REQ-F-001: Create a task
- **Statement:** WHEN the user runs `todo add <title>` THE system SHALL create a pending task with the next id.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN an empty list WHEN the user runs `todo add "Buy milk"` THEN task 1 "Buy milk" is pending
  - GIVEN any state WHEN the user runs `todo add ""` THEN the command exits 2 with `title must not be empty`

### REQ-F-002: List tasks
- **Statement:** WHEN the user runs `todo list` THE system SHALL print every task ordered by id.
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN tasks 1 and 2 WHEN the user runs `todo list` THEN two lines are printed in id order
  - GIVEN an empty list WHEN the user runs `todo list` THEN the output is `No tasks`

### REQ-F-003: Filter by status
- **Statement:** WHEN the user runs `todo list --status pending` THE system SHALL print only pending tasks.
- **Priority:** Should have
- **Needs:** N-002
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN tasks 1 (pending) and 2 (completed) WHEN the user runs `todo list --status pending` THEN only task 1 is printed

### REQ-F-004: Export to CSV
- **Statement:** WHEN the user runs `todo export` THE system SHALL write tasks.csv.
- **Priority:** Should have
- **Needs:** N-003
- **Verification:** test
- **Status:** Deprecated (2026-09-01) — replaced by the JSON file
- **Acceptance criteria:**
  - GIVEN tasks WHEN the user runs `todo export` THEN tasks.csv exists

### REQ-F-005: Delete a task
- **Statement:** WHEN the user runs `todo rm <id>` THE system SHALL remove the task without renumbering.
- **Priority:** Must have
- **Needs:** N-003
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN tasks 1, 2 and 3 WHEN the user runs `todo rm 2` THEN tasks 1 and 3 remain
  - GIVEN no task 9 WHEN the user runs `todo rm 9` THEN the command exits 3 with `task 9 not found`

### REQ-F-006: Readable output
- **Statement:** THE system SHALL print the list with aligned columns that the product owner finds readable.
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** demo
- **Acceptance criteria:**
  - GIVEN 5 tasks WHEN the product owner runs `todo list` THEN columns are aligned

## Nonfunctional Requirements

### REQ-NF-001: Command latency
- **Statement:** THE system SHALL complete `todo list` over 1,000 tasks in under 200 ms (p95).
- **Priority:** Should have
- **Needs:** N-004
- **Verification:** measurement — p95 of `todo list` over 20 runs with 1,000 tasks, threshold 200 ms
- **Acceptance criteria:**
  - GIVEN 1,000 tasks WHEN the user runs `todo list` THEN p95 < 200 ms

### REQ-NF-002: Test coverage
- **Statement:** THE system SHALL keep statement coverage of `src/` at 90 % or higher.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** measurement — statements coverage of src/, threshold 90 %
- **Acceptance criteria:**
  - GIVEN the suite WHEN coverage runs THEN statements ≥ 90 %

## Constraints

### REQ-C-001: No runtime dependencies
- **Statement:** The system has no runtime dependencies.
- **Needs:** — (team/architecture source)
- **Verification:** inspection — review of `package.json`
