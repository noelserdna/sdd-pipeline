# BDD-UC-002 — Generar el CV

> Refs: UC-002; REQ-F-005. Workflow: WF-001 (pasos 1-2). Puerto: `CvGenerator`.

Scenario: AC-002-01 — el resumen recoge las respuestas del cuestionario [REQ-F-005 AC1]
  Given un alumno que respondió "Me motiva la ciberseguridad" a "¿Qué te motiva?"
  When pide generar su CV (`POST /api/cv/generar`)
  Then el resumen del borrador recoge su respuesta
