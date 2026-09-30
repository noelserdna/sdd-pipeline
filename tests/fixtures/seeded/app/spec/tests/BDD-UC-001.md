# BDD-UC-001 — Consultar y descargar el CV

> Refs: UC-001; REQ-F-001; REQ-F-002; REQ-F-003; REQ-F-007; REQ-F-008. Workflow: WF-001 (pasos 5-6).

Scenario: AC-001-01 — cabecera con nombre y email [REQ-F-001 AC1]
  Given la alumna "Lucía Pérez" con email "lucia@campus.test"
  When abre `/cv`
  Then la cabecera muestra su nombre y su email

Scenario: AC-001-02 — sección de proyectos [REQ-F-002 AC1]
  Given un alumno con el proyecto "Agenda P2P"
  When abre `/cv`
  Then ve la sección de proyectos con "Agenda P2P"

Scenario: AC-001-03 — estado antes de la confirmación [REQ-F-003 AC1]
  Given un CV generado sin confirmar
  When el alumno abre `/cv/estado`
  Then ve que su CV está pendiente de revisión

Scenario: AC-001-04 — aviso en el panel [REQ-F-007 AC1]
  Given un CV publicado
  When el alumno abre `/panel`
  Then ve el aviso de CV publicado

Scenario: AC-001-05 — nombre del fichero descargado [REQ-F-008 AC1]
  Given la alumna "Lucía Pérez" con el CV publicado
  When abre `/cv/descargar`
  Then recibe "cv-lucia-perez.txt"

Scenario: AC-001-06 — contenido del fichero descargado [REQ-F-008 AC2]
  Given la alumna "Lucía Pérez" con el CV publicado
  When abre `/cv/descargar`
  Then la primera línea es su nombre
