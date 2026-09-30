# Requirements Document

> **Project:** cv-alumnos
> **Version:** 1.1
> **Examples reviewed by:** Marta Ibáñez (coordinación académica), 2026-09-04
> **Approved:** tag `requirements-v1`

## Functional Requirements

### REQ-F-001: Cabecera con los datos del alumno
- **Statement:** WHEN el alumno abre su CV en `/cv` THE sistema SHALL mostrar su nombre completo y su email en la cabecera.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN la alumna "Lucía Pérez" con email "lucia@campus.test" WHEN abre su CV THEN el usuario ve "Lucía Pérez" y "lucia@campus.test" en la cabecera

### REQ-F-002: Sección de proyectos
- **Statement:** WHEN el alumno abre su CV en `/cv` y tiene proyectos registrados THE sistema SHALL listarlos en una sección propia del CV.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN un alumno con el proyecto "Agenda P2P" WHEN abre su CV THEN el usuario ve una sección titulada "Proyectos personales" que contiene "Agenda P2P"

### REQ-F-003: Estado del CV para el alumno
- **Statement:** WHEN el alumno abre el estado de su CV en `/cv/estado` THE sistema SHALL mostrar en qué punto del proceso de revisión está.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN un CV generado que el staff aún no ha confirmado WHEN el alumno abre el estado de su CV THEN el usuario ve "Pendiente de revisión por el equipo"

### REQ-F-004: Comparativa del borrador y la versión editada
- **Statement:** WHEN el staff abre la revisión de un CV en `/staff/cv/:id` THE sistema SHALL mostrar, junto al editor, la comparativa entre el resumen generado y el resumen editado.
- **Priority:** Must have
- **Needs:** N-003
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN el CV 7 con resumen generado "Desarrollador junior" y resumen editado "Desarrolladora full-stack junior" WHEN el staff abre la revisión del CV 7 THEN el usuario ve "Antes: Desarrollador junior" y "Después: Desarrolladora full-stack junior"

### REQ-F-005: Resumen a partir del cuestionario
- **Statement:** WHEN el alumno pide generar su CV THE sistema SHALL redactar el resumen profesional a partir de su perfil y de sus respuestas al cuestionario.
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN un alumno que respondió "Me motiva la ciberseguridad" a la pregunta "¿Qué te motiva?" WHEN genera su CV THEN el resumen del CV recoge "Me motiva la ciberseguridad"

### REQ-F-006: Confirmar y publicar el CV
- **Statement:** WHEN el staff confirma un CV con `POST /api/cv/:id/confirmar` THE sistema SHALL publicarlo conservando las correcciones del staff.
- **Priority:** Must have
- **Needs:** N-003
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN un CV generado WHEN el staff lo confirma THEN el CV queda en estado "publicado"
  - GIVEN un CV confirmado cuyo resumen el staff cambió después a "Perfil orientado a backend" WHEN se vuelve a confirmar el mismo CV THEN el resumen publicado sigue siendo "Perfil orientado a backend"

### REQ-F-007: Aviso de CV publicado
- **Statement:** WHEN el CV del alumno pasa a publicado THE sistema SHALL avisarle en su panel `/panel`.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN un CV publicado WHEN el alumno abre su panel THEN el usuario ve el aviso "Tu CV ya está publicado"

### REQ-F-008: Descarga del CV en texto
- **Statement:** WHEN el alumno descarga su CV desde `/cv/descargar` THE sistema SHALL entregarle el CV publicado como fichero de texto plano.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN la alumna "Lucía Pérez" con el CV publicado WHEN descarga su CV THEN recibe un fichero llamado "cv-lucia-perez.txt"
  - GIVEN la alumna "Lucía Pérez" con el CV publicado WHEN descarga su CV THEN la primera línea del fichero es "Lucía Pérez"
