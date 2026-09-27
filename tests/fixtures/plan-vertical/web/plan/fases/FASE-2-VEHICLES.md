# FASE 2: Vehículos de un cliente

> **Estado:** Implementable
> **Incremento:** Registrar los vehículos de un cliente
> **Requisitos:** REQ-F-004
> **Escenarios:** AC-005-01, AC-005-02
> **Necesidades:** N-003
> **Dependencias:** Fase 1

---

## Criterios de Éxito

### UC-005 — Gestionar vehículos
- [ ] Añadir matrícula; matrícula repetida → error (AC-005-01, AC-005-02)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | en Ana Ruiz, añadir 1234-ABC | aparece en sus vehículos | AC-005-01 · N-003 |
| 2 | añadir 1234-ABC otra vez | `Plate already registered` | AC-005-02 · N-003 |
