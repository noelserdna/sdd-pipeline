# FASE 1: Completar y borrar tareas

> **Estado:** Implementable
> **Incremento:** Completar y borrar tareas
> **Requisitos:** REQ-F-003, REQ-F-004
> **Escenarios:** AC-003-01, AC-003-02, AC-003-03, AC-004-01, AC-004-02
> **Necesidades:** N-003
> **Dependencias:** Fase 0

---

## Criterios de Éxito

### UC-003 — Completar tarea
- [ ] `todo done 1` completa la tarea; repetir avisa y sale 0; id desconocido → exit 3 (AC-003-01, AC-003-02, AC-003-03)

### UC-004 — Borrar tarea
- [ ] `todo rm 2` borra sin renumerar; id desconocido → exit 3 (AC-004-01, AC-004-02)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `rm -rf data && todo add A && todo add B && todo add C` | tareas 1, 2 y 3 | AC-001-01 · N-001 |
| 2 | `todo done 1 && todo list` | `1 [x] A` | AC-003-01 · N-003 |
| 3 | `todo done 1` | `task 1 is already completed`, exit 0 | AC-003-02 · N-003 |
| 4 | `todo done 9` | exit 3, `task 9 not found` | AC-003-03 · N-003 |
| 5 | `todo rm 2 && todo list` | solo las tareas 1 y 3 | AC-004-01 · N-003 |
| 6 | `todo rm 9` | exit 3, `task 9 not found` | AC-004-02 · N-003 |
