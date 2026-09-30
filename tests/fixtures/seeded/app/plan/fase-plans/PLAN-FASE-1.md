# Implementation Plan — FASE-1: CV

> Spec v1.1 · 2026-09-08 · Depends on: — · Enables: —

## 1. Alcance

REQ-F-001 … REQ-F-008 · UC-001, UC-002, UC-003 · WF-001.

## 4. Component Implementation

### 4.1 `src/store.js` y `src/api/cv.js` (A)

**Responsibility:** REQ-F-005, REQ-F-006. Almacén en memoria de alumnos y CVs; operaciones `generar`, `editar` y
`confirmar`.

### 4.2 `src/ui/*.js` y `src/routes.js` (B)

**Responsibility:** REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-007, REQ-F-008. Una función por pantalla;
el router monta cada una en su ruta.

| Ruta | Pantalla | Fichero |
|------|----------|---------|
| `/cv` | CV del alumno | `src/ui/cv.js` |
| `/cv/estado` | Estado del CV | `src/ui/estado.js` |
| `/cv/descargar` | Descarga en texto | `src/ui/descarga.js` |
| `/panel` | Panel del alumno | `src/ui/panel.js` |
| `/staff/cv/:id` | Revisión del staff (editor y comparativa) | `src/ui/revision.js`, `src/ui/comparativa.js` |

### 4.3 Puertos con doble

| Puerto | Interfaz (fichero) | Doble | Provider real | Observable del contrato |
|--------|--------------------|-------|---------------|-------------------------|
| `CvGenerator` | `src/ports/cv-generator.js` | `src/providers/mock-cv-generator.js` | `src/providers/vertex-cv-generator.js` | el resumen se redacta con el perfil y las respuestas del cuestionario (REQ-F-005 AC1) |

## 7. Test Strategy

### 7.1 Unit Tests

| Scenario | Test ids (tests/) | Setup | Block |
|----------|-------------------|-------|-------|
| cabecera, proyectos, estado, panel, descarga | REQ-F-001 AC1, REQ-F-002 AC1, REQ-F-003 AC1, REQ-F-007 AC1, REQ-F-008 AC1, REQ-F-008 AC2 | almacén en memoria | B |
| comparativa | REQ-F-004 AC1 | — | B |

### 7.2 Integration Tests

| Scenario | Test ids (tests/) | Setup | Block |
|----------|-------------------|-------|-------|
| generar con el cuestionario | REQ-F-005 AC1 | doble `CvGenerator` (`src/providers/mock-cv-generator.js`) | A |
| confirmar | REQ-F-006 AC1, REQ-F-006 AC2 | almacén en memoria | A |

### 7.3 Evidencia visual

Capturas en `evidencias/FASE-1/REQ-F-NNN-ACn.png`; vídeo del recorrido en `evidencias/FASE-1/`.
