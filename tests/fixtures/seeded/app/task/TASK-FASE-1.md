# Tasks: FASE-1 — CV

> **Critical path:** TASK-F1-001 → TASK-F1-002 → TASK-F1-003 → TASK-F1-007 → TASK-F1-008

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F1-001 | src/store.js, src/api/**, tests/api/confirmar.test.js | main checkout, before worktrees (checkpoint `fase-1-foundation`) |
| A | TASK-F1-002, TASK-F1-003 | src/ports/**, src/providers/**, src/app.js, tests/api/generar.test.js, tests/providers/** | main checkout (serial) |
| B | TASK-F1-004, TASK-F1-005, TASK-F1-006 | src/ui/**, tests/ui/** | main checkout (serial) |
| integración | TASK-F1-007 | src/routes.js, tests/routes.test.js | main checkout |
| verificación | TASK-F1-008 | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Verified | TASK-F1-008 | `fase-1-verified` | main checkout |

## Base

- [x] TASK-F1-001 Almacén en memoria y operaciones generar, editar y confirmar, test-first | `src/store.js`, `src/api/cv.js`, `tests/api/confirmar.test.js`
  - **Commit:** `feat(cv): almacén de CVs y operaciones generar, editar y confirmar`
  - **Acceptance:** Test first: `REQ-F-006 AC1`, `REQ-F-006 AC2` in the test names (AC-003-02, AC-003-03)
  - **Refs:** FASE-1, REQ-F-006, UC-003, WF-001

## Slices

- [x] TASK-F1-002 Puerto CvGenerator y su doble mock, test-first | `src/ports/cv-generator.js`, `src/providers/mock-cv-generator.js`, `tests/api/generar.test.js`
  - blocked-by: TASK-F1-001
  - **Commit:** `feat(cv): puerto CvGenerator con doble mock`
  - **Acceptance:** Test first: `REQ-F-005 AC1` in the test name (AC-002-01), generating through the double
  - **Refs:** FASE-1, REQ-F-005, UC-002

- [x] TASK-F1-003 Provider real de Vertex para CvGenerator y selección por CV_GENERATOR | `src/providers/vertex-cv-generator.js`, `src/app.js`, `tests/providers/vertex-cv-generator.test.js`
  - blocked-by: TASK-F1-002
  - **Commit:** `feat(cv): provider de Vertex para CvGenerator`
  - **Acceptance:** Test first: la petición lleva el modelo, el perfil del alumno y la respuesta del transporte llega como resumen
  - **Refs:** FASE-1, REQ-F-005, UC-002

- [x] TASK-F1-004 Pantalla del CV y descarga en texto, test-first | `src/ui/cv.js`, `src/ui/descarga.js`, `tests/ui/cv.test.js`, `tests/ui/descarga.test.js`
  - blocked-by: TASK-F1-001
  - **Commit:** `feat(ui): pantalla del CV y descarga en texto`
  - **Acceptance:** Test first: `REQ-F-001 AC1`, `REQ-F-002 AC1`, `REQ-F-008 AC1`, `REQ-F-008 AC2` (AC-001-01, AC-001-02, AC-001-05, AC-001-06)
  - **Refs:** FASE-1, REQ-F-001, REQ-F-002, REQ-F-008, UC-001

- [x] TASK-F1-005 Estado del CV y aviso en el panel, test-first | `src/ui/estado.js`, `src/ui/panel.js`, `tests/ui/estado.test.js`, `tests/ui/panel.test.js`
  - blocked-by: TASK-F1-001
  - **Commit:** `feat(ui): estado del CV y aviso en el panel`
  - **Acceptance:** Test first: `REQ-F-003 AC1`, `REQ-F-007 AC1` (AC-001-03, AC-001-04)
  - **Refs:** FASE-1, REQ-F-003, REQ-F-007, UC-001

- [x] TASK-F1-006 Revisión del staff y comparativa del resumen, test-first | `src/ui/revision.js`, `src/ui/comparativa.js`, `tests/ui/comparativa.test.js`
  - blocked-by: TASK-F1-001
  - **Commit:** `feat(ui): revisión del staff y comparativa del resumen`
  - **Acceptance:** Test first: `REQ-F-004 AC1` (AC-003-01)
  - **Refs:** FASE-1, REQ-F-004, UC-003

## Integración

- [x] TASK-F1-007 Router de pantallas y endpoints | `src/routes.js`, `tests/routes.test.js`
  - blocked-by: TASK-F1-003, TASK-F1-004, TASK-F1-005, TASK-F1-006
  - **Commit:** `feat(cv): router de pantallas y endpoints del CV`
  - **Acceptance:** Verify: cada ruta de PLAN-FASE-1 §4.2 responde y una ruta desconocida devuelve 404
  - **Refs:** FASE-1, WF-001

## Verification

- [x] TASK-F1-008 Evidencia de la FASE-1: JUnit, capturas por criterio y vídeo del recorrido | `junit/fase-1.xml`, `evidencias/FASE-1/`
  - blocked-by: TASK-F1-007
  - **Commit:** `test(cv): evidencia de la FASE-1`
  - **Acceptance:** Verify: `junit/fase-1.xml` generado con `test_report`; una captura `evidencias/FASE-1/REQ-F-NNN-ACn.png` por criterio y el vídeo del recorrido WF-001
  - **Refs:** FASE-1, WF-001
