# FASE 1: Completar, borrar y filtrar tareas

> **Estado:** Implementable
> **Incremento:** Completar, borrar y filtrar tareas
> **Requisitos:** REQ-F-003, REQ-F-004, REQ-F-005
> **Escenarios:** REQ-F-003 AC1, REQ-F-003 AC2, REQ-F-003 AC3, REQ-F-004 AC1, REQ-F-004 AC2, REQ-F-005 AC1, REQ-F-005 AC2
> **Necesidades:** N-002, N-003
> **Dependencias:** Fase 0

---

## Criterios de Éxito

### N-003 — Cerrar las tareas que tengo
- [ ] `todo done 1` completa; repetir avisa y sale 0; id desconocido → exit 3 (REQ-F-003 AC1, REQ-F-003 AC2, REQ-F-003 AC3)
- [ ] `todo rm 2` borra sin renumerar; id desconocido → exit 3 (REQ-F-004 AC1, REQ-F-004 AC2)

### N-002 — Ver lo que queda
- [ ] `todo list --status pending` filtra; estado desconocido → exit 2 (REQ-F-005 AC1, REQ-F-005 AC2)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `rm -rf data && todo add A && todo add B && todo add C` | tareas 1, 2 y 3 | REQ-F-001 AC2 · N-001 |
| 2 | `todo done 1 && todo list` | `1 [x] A` | REQ-F-003 AC1 · N-003 |
| 3 | `todo done 1` | `task 1 is already completed`, exit 0 | REQ-F-003 AC2 · N-003 |
| 4 | `todo done 9` | exit 3, `task 9 not found` | REQ-F-003 AC3 · N-003 |
| 5 | `todo rm 2 && todo list` | solo las tareas 1 y 3 | REQ-F-004 AC1 · N-003 |
| 6 | `todo rm 9` | exit 3, `task 9 not found` | REQ-F-004 AC2 · N-003 |
| 7 | `todo list --status pending` | solo `3 [ ] C` | REQ-F-005 AC1 · N-002 |
| 8 | `todo list --status other` | exit 2, `status must be pending or completed` | REQ-F-005 AC2 · N-002 |
