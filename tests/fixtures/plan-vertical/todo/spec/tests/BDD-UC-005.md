# BDD-UC-005 — Filter tasks by status

> Refs: UC-005; REQ-F-005.

Scenario: AC-005-01 — only pending [REQ-F-005 AC1]
  Then only `1 [ ] …` is printed

Scenario: AC-005-02 — invalid status [REQ-F-005 AC2]
  Then the system exits 2 with `status must be pending or completed`
