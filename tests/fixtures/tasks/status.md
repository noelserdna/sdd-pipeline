# Tasks: FASE-1 — Trailer state scenarios

> **Critical path:** TASK-F1-001 → TASK-F1-006

## Slices

- [x] TASK-F1-001 Committed with a Task trailer and checked | `a.txt`
  - **Commit:** `feat(s): a`
  - **Acceptance:** trailer reachable from HEAD → done
  - **Refs:** FASE-1

- [x] TASK-F1-002 Committed, checked, then reverted | `b.txt`
  - **Commit:** `feat(s): b`
  - **Acceptance:** revert → not done → checked-without-trailer
  - **Refs:** FASE-1

- [ ] TASK-F1-003 Commit without trailer mentions the id in its subject | `c.txt`
  - **Commit:** `feat(s): c`
  - **Acceptance:** no trailer → pending
  - **Refs:** FASE-1

- [ ] TASK-F1-004 Committed with a trailer but the box is unchecked | `d.txt`
  - **Commit:** `feat(s): d`
  - **Acceptance:** done → trailer-without-checkbox (only with task_state checkbox)
  - **Refs:** FASE-1

- [!] TASK-F1-005 Blocked by an external dependency | `e.txt`
  - **Commit:** `feat(s): e`
  - **Acceptance:** blocked
  - **Refs:** FASE-1

- [x] TASK-F1-006 Reverted and the revert reverted again | `f.txt`
  - **Commit:** `feat(s): f`
  - **Acceptance:** revert of a revert → done
  - **Refs:** FASE-1
