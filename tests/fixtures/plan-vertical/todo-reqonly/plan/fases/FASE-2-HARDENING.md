# FASE 2: Latencia con 1 000 tareas

> **Estado:** Implementable
> **Incremento:** Latencia con 1 000 tareas
> **Requisitos:** REQ-NF-001
> **Escenarios:** REQ-NF-001 AC1
> **Necesidades:** N-005
> **Dependencias:** Fase 1

---

## Criterios de Éxito

### N-005 — Rápida con listas grandes
- [ ] `todo list` con 1 000 tareas, p95 < 200 ms en 20 ejecuciones (REQ-NF-001 AC1)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `npm run perf` | p95 < 200 ms con 1 000 tareas | REQ-NF-001 AC1 · N-005 |
