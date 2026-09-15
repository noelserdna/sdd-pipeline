# TASK-FASE-1 — Headings (legacy shape)

## Phase 3 — Domain (`TaskService`)

### TASK-F1-001 — `TaskService.create` + `TaskService.list` — [x] Done

Implements `web/src/domain/task-service.ts`.

- **Commit:**
  ```
  feat(domain): create and list

  Refs: FASE-1, UC-001
  Task: TASK-F1-001
  ```
- **Acceptance:**
  - a blank title is rejected (INV-TSK-002)
- **Refs:** FASE-1, UC-001, UC-002, INV-TSK-002
- **Revert:** SAFE — new module without consumers

### TASK-F1-002 — `POST /tareas` (API-001-01) — [ ] Pending

**Commit**
```
feat(api): POST /tareas

Task: TASK-F1-002
```

**Acceptance**
- 303 redirect on success

**Refs:** FASE-1, API-001-01

#### Notes

A sub-heading stays inside the task.

## Phase 7 — Verification

### TASK-F1-003 — Verify FASE-1 — [x] Done

**Commit:** N/A — verification only

**Acceptance**
- every criterion passes

## Stream Ownership

| Stream | Tareas | Owns (write-set) | Runs in |
|---|---|---|---|
| `base` | — | — | — |
| `A` | TASK-F1-001 .. TASK-F1-002 | `web/src/**` | main checkout |
| `verificación` | TASK-F1-003 | — | main checkout |
