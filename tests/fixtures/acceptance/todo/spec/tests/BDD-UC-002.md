# BDD-UC-002 — List, filter and delete

> Refs: UC-002; REQ-F-002; REQ-F-003; REQ-F-005.

Scenario: AC-002-01 — list in id order [REQ-F-002 AC1]
  Then two lines are printed

Scenario: AC-002-02 — empty list [REQ-F-002 AC2]
  Then the output is `No tasks`

Scenario: AC-002-03 — filter pending [REQ-F-003 AC1]
  Then only task 1 is printed

Scenario: AC-002-04 — delete keeps ids [REQ-F-005 AC1]
  Then tasks 1 and 3 remain
