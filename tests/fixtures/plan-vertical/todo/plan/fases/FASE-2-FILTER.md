# FASE 2: Filtrar por estado

> **Estado:** Implementable
> **Incremento:** Ver solo lo que queda por hacer
> **Requisitos:** REQ-F-005
> **Escenarios:** AC-005-01, AC-005-02
> **Necesidades:** N-002
> **Dependencias:** Fase 0

---

## Criterios de Éxito

### UC-005 — Filtrar tareas
- [ ] `--status pending` muestra solo las pendientes; otro valor → exit 2 (AC-005-01, AC-005-02)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `cp demo/seed-fase-0.json data/todos.json && todo list --status pending` | solo `1 [ ] …` | AC-005-01 · N-002 |
| 2 | `todo list --status other` | exit 2, `status must be pending or completed` | AC-005-02 · N-002 |
