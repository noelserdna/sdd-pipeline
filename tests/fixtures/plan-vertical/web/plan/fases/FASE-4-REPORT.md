# FASE 4: Informe mensual

> **Estado:** Implementable
> **Incremento:** El administrador ve el informe mensual
> **Requisitos:** REQ-F-006
> **Escenarios:** AC-007-01, AC-007-02
> **Necesidades:** N-005
> **Dependencias:** Fase 3

---

## Criterios de Éxito

### UC-007 — Informe mensual
- [ ] Citas por día del mes; personal sin rol admin → acceso denegado (AC-007-01, AC-007-02)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `bin/rails db:seed` (admin, 3 citas el 5 de octubre) · entrar como admin · Informe octubre | el día 5 muestra 3 | AC-007-01 · N-005 |
| 2 | entrar como demo@taller.test y abrir el informe | acceso denegado | AC-007-02 · N-005 |
