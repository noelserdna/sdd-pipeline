# BDD-UC-002 — List tasks

> Refs: UC-002; REQ-F-002, REQ-F-006.

Scenario: AC-002-01 — pending and completed lines [REQ-F-002 AC1]
  Given tasks 1 (pending) and 2 (completed)
  When the user runs `todo list`
  Then the output is `1 [ ] …` and `2 [x] …`

Scenario: AC-002-02 — empty list [REQ-F-002 AC2]
  When the user runs `todo list` on an empty list
  Then the output is `No tasks` and the exit code is 0

Scenario: AC-002-03 — list from the file in a new process [REQ-F-006 AC2]
  Given `data/todos.json` with 2 tasks
  When the user runs `todo list` in a new process
  Then both tasks are printed

Scenario: AC-002-04 — corrupted file [REQ-F-006 AC3]
  Given a corrupted `data/todos.json`
  When any command runs
  Then it exits 4 with `data/todos.json is not valid JSON` and leaves the file untouched
