# FASE 0: Esqueleto — apuntar tareas y verlas de nuevo

> **Estado:** Implementable
> **Incremento:** Apuntar tareas y verlas en otra ejecución
> **Requisitos:** REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002
> **Escenarios:** AC-001-01, AC-001-02, AC-001-03, AC-001-04, AC-002-01, AC-002-02, AC-002-03, AC-002-04, REQ-NF-002 AC1
> **Necesidades:** N-001, N-002, N-004, N-005
> **Dependencias:** Ninguna (fase inicial)

---

## Objetivo

Permitir que un **usuario** apunte tareas con `todo add` y las vea con `todo list`, también en otra ejecución (write → observe → persist).

## Criterios de Éxito

### UC-001 — Crear tarea
- [ ] `todo add` crea la tarea con id incremental y estado pending (AC-001-01, AC-001-02)
- [ ] Título vacío → exit 2 con el mensaje del catálogo (AC-001-03)
- [ ] La primera escritura crea `data/todos.json` (AC-001-04)

### UC-002 — Listar tareas
- [ ] Una línea por tarea en orden de id; lista vacía → `No tasks` (AC-002-01, AC-002-02)
- [ ] Lee `data/todos.json` en un proceso nuevo; fichero corrupto → exit 4 sin tocarlo (AC-002-03, AC-002-04)

### Transversal
- [ ] `src/cli/` importa `src/api/`, nunca al revés (REQ-C-002)
- [ ] Cobertura de sentencias de `src/api/**` ≥ 90 % (REQ-NF-002 AC1)

## Módulos y Conjuntos de Escritura

| Bloque | Módulo / directorio | Escribe (write-set) | No escribe | Depende de |
|--------|---------------------|---------------------|------------|------------|
| A | — | `package.json`, `src/**`, `tests/**`, `demo/seed-fase-0.json` | — | — |

## Demo

> Desde un checkout limpio: `npm ci && npm run build`.

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `rm -rf data && todo list` | `No tasks`, exit 0 | AC-002-02 · N-002 |
| 2 | `todo add "Buy milk"` | tarea 1 pending; `data/todos.json` con una tarea | AC-001-01, AC-001-04 · N-001, N-004 |
| 3 | `todo add ""` | exit 2, `title must not be empty` | AC-001-03 · N-001 |
| 4 | `cp demo/seed-fase-0.json data/todos.json && todo list` | `1 [ ] …` y `2 [x] …` | AC-002-01, AC-002-03 · N-002, N-004 |
| 5 | `printf '{' > data/todos.json && todo list` | exit 4, el fichero no cambia | AC-002-04 · N-004 |
| 6 | `npm test -- --coverage` | sentencias de `src/api/**` ≥ 90 % | REQ-NF-002 AC1 · N-005 |

## Alcance

| Incluye | Excluye |
|---------|---------|
| UC-001, UC-002 (sin filtro) | completar/borrar → FASE-1; filtro → FASE-2 |
