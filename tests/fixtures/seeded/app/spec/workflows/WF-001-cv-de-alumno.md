# WF-001 — Del cuestionario al CV publicado

> Refs: UC-001, UC-002, UC-003; REQ-F-001…REQ-F-008. Actores: alumno, staff.

## Pasos

| # | Actor | Paso | Ruta / operación | Estado del CV |
|---|-------|------|------------------|---------------|
| 1 | alumno | Responde el cuestionario de su perfil | — | — |
| 2 | alumno | Pide generar su CV | `POST /api/cv/generar` → `CvGenerator.generate` | `generado` |
| 3 | staff | Abre la revisión y compara el resumen generado con el editado | `/staff/cv/:id` | `generado` |
| 4 | staff | Confirma el CV (y puede retocarlo y confirmarlo otra vez) | `POST /api/cv/:id/editar`, `POST /api/cv/:id/confirmar` | `publicado` |
| 5 | alumno | Ve el estado de su CV y el aviso en su panel | `/cv/estado`, `/panel` | `publicado` |
| 6 | alumno | Abre su CV y lo descarga | `/cv`, `/cv/descargar` | `publicado` |

## Estados

`generado` → `publicado`. Confirmar un CV ya publicado es válido: vuelve a publicar la versión que el staff tiene en
el editor.

## Reglas

- RN-01: el resumen del borrador lo redacta el `CvGenerator` con el perfil y las respuestas del cuestionario.
- RN-02: lo que el staff corrige en el editor prevalece sobre el borrador generado.
