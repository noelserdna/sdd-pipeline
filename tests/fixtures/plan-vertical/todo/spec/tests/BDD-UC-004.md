# BDD-UC-004 — Delete a task

> Refs: UC-004; REQ-F-004.

Scenario: AC-004-01 — delete keeps the other ids [REQ-F-004 AC1]
  Then `todo list` shows tasks 1 and 3 only

Scenario: AC-004-02 — unknown id [REQ-F-004 AC2]
  Then the system exits 3 with `task 9 not found`
