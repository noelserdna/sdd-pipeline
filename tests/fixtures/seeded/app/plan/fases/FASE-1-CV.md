# FASE 1: El alumno obtiene su CV revisado por el staff

> **Estado:** Implementable
> **Incremento:** El alumno genera su CV desde el cuestionario, el staff lo revisa y lo confirma, y el alumno lo ve publicado y lo descarga
> **Requisitos:** REQ-F-001, REQ-F-002, REQ-F-003, REQ-F-004, REQ-F-005, REQ-F-006, REQ-F-007, REQ-F-008
> **Escenarios:** AC-001-01, AC-001-02, AC-001-03, AC-001-04, AC-001-05, AC-001-06, AC-002-01, AC-003-01, AC-003-02, AC-003-03
> **Workflows:** WF-001
> **Necesidades:** N-001, N-002, N-003, N-004
> **Dependencias:** Ninguna (fase inicial)

---

## Criterios de Éxito

### UC-002 — Generar el CV
- [ ] El resumen del borrador recoge las respuestas del cuestionario (AC-002-01)

### UC-003 — Revisar y confirmar el CV
- [ ] La revisión muestra el resumen de antes y el de después (AC-003-01)
- [ ] Confirmar publica el CV y confirmar otra vez conserva las correcciones (AC-003-02, AC-003-03)

### UC-001 — Consultar y descargar el CV
- [ ] El CV muestra la cabecera y la sección de proyectos (AC-001-01, AC-001-02)
- [ ] El alumno ve el estado y el aviso de publicación (AC-001-03, AC-001-04)
- [ ] La descarga entrega el fichero de texto con su nombre (AC-001-05, AC-001-06)

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | Lucía responde el cuestionario y pulsa «Generar CV» | el borrador recoge «Me motiva la ciberseguridad» | AC-002-01 · N-002 |
| 2 | Lucía abre `/cv/estado` | ve que su CV está pendiente de revisión | AC-001-03 · N-004 |
| 3 | El staff abre `/staff/cv/7` y edita el resumen | ve el resumen de antes y el de después | AC-003-01 · N-003 |
| 4 | El staff confirma el CV | estado «publicado» | AC-003-02 · N-003 |
| 5 | El staff retoca el resumen y confirma otra vez | el resumen publicado es el retocado | AC-003-03 · N-003 |
| 6 | Lucía abre `/panel` | ve el aviso de CV publicado | AC-001-04 · N-004 |
| 7 | Lucía abre `/cv` | cabecera con su nombre y email, y sus proyectos | AC-001-01, AC-001-02 · N-001 |
| 8 | Lucía pulsa «Descargar» | `cv-lucia-perez.txt` con su nombre en la primera línea | AC-001-05, AC-001-06 · N-001 |
