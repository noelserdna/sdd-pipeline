# AUDIT-HISTORY — todo-app

Resultados del `sdd-pipeline-auditor` sobre este proyecto, por versión del plugin. Cada ejecución añade una sección.

| Fecha | Pipeline version | Resultado | Bugs | Mejoras | Notas |
|---|---|---|---|---|---|
| 2026-08-25 | 4.0.0-beta.1 | smoke (`tests/e2e/20-smoke.sh` hasta FASE-0): OK | 0 | 1 (bug del script check-ignore, corregido) | gate PASS; FASE-1 con Streams A∥B; 105 tests; sin intervención humana. Pendiente: ejecución completa del `sdd-pipeline-auditor` |
| 2026-08-25 | 4.0.0 | streams (`tests/e2e/50-streams.sh` FASE-1 en 2 worktrees + integrate): OK | 1 (rol sdd-lead sin write-set de integración, corregido) | 0 | 0 conflictos; 659 tests; fase-1-verified; pipeline completo |
