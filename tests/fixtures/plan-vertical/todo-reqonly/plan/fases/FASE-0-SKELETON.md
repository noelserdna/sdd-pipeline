# FASE 0: Esqueleto — apuntar tareas y verlas de nuevo

> **Estado:** Implementable
> **Incremento:** Apuntar tareas y verlas en otra ejecución
> **Requisitos:** REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002
> **Escenarios:** REQ-F-001 AC1, REQ-F-001 AC2, REQ-F-001 AC3, REQ-F-002 AC1, REQ-F-002 AC2, REQ-F-006 AC1, REQ-F-006 AC2, REQ-F-006 AC3, REQ-NF-002 AC1
> **Necesidades:** N-001, N-002, N-004, N-005
> **Dependencias:** Ninguna (fase inicial)

---

## Objetivo

Permitir que un **usuario** apunte tareas con `todo add` y las vea con `todo list`, también en otra ejecución (write → observe → persist).

## Criterios de Éxito

### N-001 — Apuntar tareas
- [ ] `todo add` crea la tarea con id incremental y estado pending (REQ-F-001 AC1, REQ-F-001 AC2)
- [ ] Título vacío → exit 2, `title must not be empty` (REQ-F-001 AC3)

### N-002, N-004 — Verlas en otra ejecución
- [ ] Una línea por tarea en orden de id; lista vacía → `No tasks` (REQ-F-002 AC1, REQ-F-002 AC2)
- [ ] Persiste en `data/todos.json`; fichero corrupto → exit 4 sin tocarlo (REQ-F-006 AC1, REQ-F-006 AC2, REQ-F-006 AC3)

### Transversal
- [ ] Sin dependencias en tiempo de ejecución (REQ-C-001)
- [ ] Cobertura de sentencias de `src/api/**` ≥ 90 % (REQ-NF-002 AC1)

## Requisitos a Leer

| Documento | Sección | Para qué |
|-----------|---------|----------|
| requirements/REQUIREMENTS.md | REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002 | criterios de esta FASE |

## Módulos y Conjuntos de Escritura

| Bloque | Módulo / directorio | Escribe (write-set) | No escribe | Depende de |
|--------|---------------------|---------------------|------------|------------|
| A | — | `package.json`, `src/**`, `tests/**`, `demo/seed-fase-0.json` | — | — |

## Demo

> Desde un checkout limpio: `npm ci && npm run build`.

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `rm -rf data && todo list` | `No tasks`, exit 0 | REQ-F-002 AC2 · N-002 |
| 2 | `todo add "Buy milk"` | tarea 1 pending; `data/todos.json` con una tarea | REQ-F-001 AC1, REQ-F-006 AC1 · N-001, N-004 |
| 3 | `todo add ""` | exit 2, `title must not be empty` | REQ-F-001 AC3 · N-001 |
| 4 | `cp demo/seed-fase-0.json data/todos.json && todo list` | `1 [ ] …` y `2 [x] …` | REQ-F-002 AC1, REQ-F-006 AC2 · N-002, N-004 |
| 5 | `printf '{' > data/todos.json && todo list` | exit 4, el fichero no cambia | REQ-F-006 AC3 · N-004 |
| 6 | `npm test -- --coverage` | sentencias de `src/api/**` ≥ 90 % | REQ-NF-002 AC1 · N-005 |
