# BDD-UC-001 — Create a task

> Refs: UC-001; REQ-F-001.

Scenario: AC-001-01 — add a task [REQ-F-001 AC1]
  Given an empty list
  When the user runs `todo add "Buy milk"`
  Then task 1 "Buy milk" is pending

Scenario: AC-001-02 — empty title [REQ-F-001 AC2]
  When the user runs `todo add ""`
  Then exit code 2

Scenario: AC-001-03 — extension without a criterion tag
  When the user adds a task with a long title
  Then it is stored
