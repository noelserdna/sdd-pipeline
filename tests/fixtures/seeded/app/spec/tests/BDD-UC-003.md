# BDD-UC-003 — Revisar y confirmar el CV

> Refs: UC-003; REQ-F-004; REQ-F-006. Workflow: WF-001 (pasos 3-4).

Scenario: AC-003-01 — comparativa antes y después [REQ-F-004 AC1]
  Given el CV 7 con resumen generado "Desarrollador junior" y editado "Desarrolladora full-stack junior"
  When el staff abre `/staff/cv/7`
  Then ve el resumen de antes y el de después

Scenario: AC-003-02 — confirmar publica el CV [REQ-F-006 AC1]
  Given un CV generado
  When el staff llama a `POST /api/cv/:id/confirmar`
  Then el estado del CV es "publicado"

Scenario: AC-003-03 — confirmar de nuevo conserva las correcciones [REQ-F-006 AC2]
  Given un CV confirmado cuyo resumen el staff cambió a "Perfil orientado a backend"
  When se llama otra vez a `POST /api/cv/:id/confirmar`
  Then el resumen publicado es "Perfil orientado a backend"
