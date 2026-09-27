# FASE 3: Latencia con 1 000 tareas

> **Estado:** Implementable
> **Incremento:** Los comandos siguen siendo instantáneos con 1 000 tareas
> **Requisitos:** REQ-NF-001
> **Escenarios:** REQ-NF-001 AC1
> **Necesidades:** N-005
> **Dependencias:** Fase 1, Fase 2

---

## Criterios de Éxito

### Transversal
- [ ] p95 de `todo list` con 1 000 tareas < 200 ms en 20 ejecuciones (REQ-NF-001 AC1)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `node tests/perf/seed.mjs 1000 && npm run test:perf` | p95 < 200 ms | REQ-NF-001 AC1 · N-005 |
