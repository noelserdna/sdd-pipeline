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
| tasks | `sdd-task-generator` | 24 min | FASE-0: 23 tasks (serial); FASE-1: 27 tasks con **Stream A (7, `src/api`) ∥ Stream B (8, `src/cli`) → verificación (12)**; V-15..V-18 PASS |
| impl (FASE-0) | `sdd-task-implementer --fase=0` | 27 min | 23/23 tasks, 23 commits con `Refs:`/`Task:`, 105 tests verdes ×3 (Node 18/20/22), tags `fase-0-foundation` y `fase-0-verified`, `feedback/IMPL-FEEDBACK-FASE-0.md`; nextStep `--fase=1 --stream base` |

Total hasta `plan`: ~1 h 55 min; hasta FASE-0 implementada: ~2 h 45 min (sin intervención humana). Todas las comprobaciones del script en verde salvo un bug del propio script (`git check-ignore -q` con varias rutas), corregido después.

Cómo repetir: `tests/e2e/20-smoke.sh --until plan --keep` y continuar con `tests/e2e/20-smoke.sh --dir <proyecto> --from tasks`.

## FASE-1 por Streams en dos worktrees (`tests/e2e/50-streams.sh`, 2026-08-25, plugin 4.0.0)

| Etapa | Duración | Resultado |
|---|---|---|
| `--stream base` (principal) | 3 min | 0 tasks; tag `fase-1-foundation` sobre `fase-0-verified` |
| Stream A ∥ Stream B (worktrees `feat/fase-1-a` / `feat/fase-1-b`, roles `impl-f1a` / `impl-f1b`) | 23 min en paralelo | A: 7/7 tasks, 7 commits; B: 8/8 tasks, 8 commits; sin tags; estado común válido con escrituras concurrentes, sin lock huérfano |
| `--integrate --fase 1` (principal, rol `sdd-lead`) | 31 min + 20 min tras reanudar | 2 merges `--no-ff`, **0 conflictos** (también en `task/TASK-FASE-1.md`); 12 tasks de `verificación`; tag `fase-1-verified`; Persist Summary `done` |

Bench (`scripts/sdd-bench.sh --fase 1`): `| 1 | worktrees | 2 | 1h 03m | 27 | 27 | 2 | 0 | 1 (sdd-lead:1) | 25.5 |`.

Resultado final del todo-app: 50 tasks, 57 commits, 0 `Task:` duplicados, 659 tests verdes ×3 (Node 18/20/22), `src/api/**` 100 % sentencias, PERF-001 p95 < 200 ms, CLI conforme a los 10 requisitos.

**Hallazgo**: el primer `--integrate` hizo PAUSE en TASK-F1-018 porque el rol `sdd-lead` de la plantilla no poseía `tests/*`, `.github/*` ni `vitest.config.ts` (la guardia H2 denegó las escrituras de verificación). Corregido en `templates/sdd-sessions.example.json` (commit 75e3ad2); la reanudación fue idempotente (saltó Streams fusionados y tasks `[x]`).
