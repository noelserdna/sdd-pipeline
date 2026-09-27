# FASE 5: Listado de citas rápido

> **Estado:** Implementable
> **Incremento:** Listado de citas rápido con 10 000 citas
> **Requisitos:** REQ-NF-001
> **Escenarios:** REQ-NF-001 AC1
> **Necesidades:** N-004
> **Dependencias:** Fase 3

---

## Criterios de Éxito

### Transversal
- [ ] p95 del listado de citas < 300 ms con 10 000 citas (REQ-NF-001 AC1)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `bin/rails perf:seed[10000] && bin/rails test test/perf` | p95 < 300 ms | REQ-NF-001 AC1 · N-004 |
