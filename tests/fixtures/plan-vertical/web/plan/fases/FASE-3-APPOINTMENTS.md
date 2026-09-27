# FASE 3: Citas del taller

> **Estado:** Implementable
> **Incremento:** Dar, mover y anular citas
> **Requisitos:** REQ-F-005
> **Escenarios:** AC-006-01, AC-006-02, AC-006-03
> **Necesidades:** N-004
> **Dependencias:** Fase 2

---

## Criterios de Éxito

### UC-006 — Gestionar citas
- [ ] Reservar, hueco ocupado → error, anular libera el hueco (AC-006-01, AC-006-02, AC-006-03)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | reservar 1234-ABC el 2026-10-05 09:00 | la cita aparece en el calendario | AC-006-01 · N-004 |
| 2 | reservar otra cita a la misma hora | `Slot taken` | AC-006-02 · N-004 |
| 3 | anular la primera cita | el hueco queda libre | AC-006-03 · N-004 |
