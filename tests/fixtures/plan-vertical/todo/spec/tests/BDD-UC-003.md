# BDD-UC-003 — Complete a task

> Refs: UC-003; REQ-F-003.

Scenario: AC-003-01 — complete a pending task [REQ-F-003 AC1]
  Then task 1 is completed and `todo list` shows `1 [x] …`

Scenario: AC-003-02 — already completed [REQ-F-003 AC2]
  Then the system prints `task 1 is already completed` and exits 0

Scenario: AC-003-03 — unknown id [REQ-F-003 AC3]
  Then the system exits 3 with `task 9 not found`
