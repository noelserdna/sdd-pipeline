# Medidas del smoke real del pipeline (`tests/e2e/20-smoke.sh`)

Proyecto: `examples/todo-app` (10 requisitos aprobados). Plugin cargado con `--plugin-dir`, modelo por defecto de la sesión, sin intervención humana (`without asking questions`).

## Ejecución 2026-08-24/25 · plugin 4.0.0-beta.1 (+ descripciones recortadas)

| Etapa | Skill | Duración | Resultado |
|---|---|---|---|
| setup | `sdd-setup` | ~2 min | `pipeline-state.json` (hooksVersion 3), hook `commit-msg`, política `.gitignore`; detectó el plugin 3.1.0 antiguo registrado y lo avisó |
| specs | `sdd-specifications-engineer` | 35 min | 7 UC, 1 WF, 4 contratos API, 7 ADR, dominio, NFR, runbooks, BDD, CLARIFICATIONS |
| audit | `sdd-spec-auditor` | 21 min | **Gate PASS** (0 críticos, 0 altos, 4 medios abiertos, 9 bajos diferidos), Mode Fix aplicado |
| test | `sdd-test-planner` | 30 min | TEST-PLAN, 7 matrices, PERF-SCENARIOS, E2E |
| plan | `sdd-plan-architect --skip-clarify` | 27 min | ARCHITECTURE, FASE-0-FOUNDATION, FASE-1-CORE con Stream A (`src/api`) ∥ Stream B (`src/cli`) → Integración |
| tasks | `sdd-task-generator` | _pendiente_ | |
| impl (FASE-0) | `sdd-task-implementer --fase=0` | _pendiente_ | |

Total hasta `plan`: ~1 h 55 min. Todas las comprobaciones del script en verde salvo un bug del propio script (`git check-ignore -q` con varias rutas), corregido después.

Cómo repetir: `tests/e2e/20-smoke.sh --until plan --keep` y continuar con `tests/e2e/20-smoke.sh --dir <proyecto> --from tasks`.
