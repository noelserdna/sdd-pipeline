# BDD-UC-001 — Create a task

> Refs: UC-001; REQ-F-001, REQ-F-006.

Scenario: AC-001-01 — add to an empty list [REQ-F-001 AC1]
  Given an empty task list
  When the user runs `todo add "Buy milk"`
  Then task 1 "Buy milk" is stored with status pending

Scenario: AC-001-02 — next incremental id [REQ-F-001 AC2]
  Given a task list with 3 tasks
  When the user adds a task
  Then the new task gets id 4

Scenario: AC-001-03 — empty title [REQ-F-001 AC3]
  When the user runs `todo add ""`
  Then the command exits 2 with `title must not be empty`

Scenario: AC-001-04 — first write creates the file [REQ-F-006 AC1]
  Given a fresh checkout
  When the user runs `todo add "A"`
  Then `data/todos.json` exists and contains one task
