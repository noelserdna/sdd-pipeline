# cv-alumnos

CV de alumnos del campus: el alumno genera su CV a partir de su perfil y de un cuestionario, el staff lo revisa y lo
confirma, y el alumno lo consulta y lo descarga. Node ≥ 18 sin dependencias. La capa de presentación devuelve el HTML
de cada pantalla (`src/ui/`); `src/routes.js` decide qué pantalla monta cada ruta y qué operación atiende cada
endpoint; `src/app.js` elige el generador de CV según el entorno.

## SDD Stack Profile

- stack: custom
- app_dir: .
- code_paths: src
- test_paths: tests
- install: none
- test: node --test
- test_file: node --test {file}
- test_name: node --test --test-name-pattern {pattern}
- test_report: node --test --test-reporter=junit --test-reporter-destination=junit/fase-1.xml
- test_report_path: junit
- acceptance: none
- acceptance_gate: enforce
- task_format: compact
- task_state: checkbox
- visual_evidence: required
- evidence_dir: evidencias
- literal_gate: enforce
- adversarial_gate: enforce
- test_slots: 1
- staging_url: none
- smoke: none
- env_required: CV_GENERATOR, VERTEX_ENDPOINT
- deploy: none
