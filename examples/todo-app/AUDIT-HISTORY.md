# AUDIT-HISTORY — todo-app

Resultados del `sdd-pipeline-auditor` sobre este proyecto, por versión del plugin. Cada ejecución añade una sección.

| Fecha | Pipeline version | Resultado | Bugs | Mejoras | Notas |
|---|---|---|---|---|---|
| 2026-08-25 | 4.0.0-beta.1 | smoke (`tests/e2e/20-smoke.sh` hasta FASE-0): OK | 0 | 1 (bug del script check-ignore, corregido) | gate PASS; FASE-1 con Streams A∥B; 105 tests; sin intervención humana. Pendiente: ejecución completa del `sdd-pipeline-auditor` |
| 2026-08-25 | 4.0.0 | streams (`tests/e2e/50-streams.sh` FASE-1 en 2 worktrees + integrate): OK | 1 (rol sdd-lead sin write-set de integración, corregido) | 0 | 0 conflictos; 659 tests; fase-1-verified; pipeline completo |
| 2026-09-27 | 4.3.0 + rama `feat/v5-vertical-acceptance` (`781f048`; F13–F16 en el commit siguiente) | pipeline completo real: setup → 4 FASEs verticales → bucle de aceptación → puerta final exit 0: OK | 11 (F2, F3, F5–F10, F12–F14; F4 sin confirmar) | 3 (F11, F15, F16) | Must 8/8 VERIFIED; 617 tests; p95 37–52 ms (< 200); puertas humanas firmadas por un proxy e2e. Detalle abajo |

## 2026-09-27 — primera ejecución real completa (v5)

Pipeline 4.3.0 con la rama `feat/v5-vertical-acceptance` (commit `781f048`; F13–F16 arreglados después, en la misma rama).
Resultado: setup → requisitos aprobados → specs → auditoría → plan de tests → plan vertical (FASE-0..3) → tareas →
implementación de las 4 FASEs → `sdd-acceptance --loop` → puerta final `sdd gate --mode enforce` exit 0.
Must 8/8 VERIFIED, 617 tests en verde, cobertura de `src/api/**` 98,4 %, latencia p95 37–52 ms (umbral 200 ms), E2E completo 8/8.

**Las puertas humanas las firmó un proxy e2e** (`e2e-proxy`, rol "test harness (not a real customer)"): aprobación de
requisitos, aceptaciones de FASE e inspecciones. Sirve para probar el mecanismo, no es comparable a una aceptación real
de cliente.

| Etapa | Duración |
|---|---|
| setup | 2 min |
| specs | 29 min |
| auditoría | 17 min |
| plan de tests | 24 min |
| plan | 28 min |
| tareas | 18 min |
| FASE-0 | 61 min |
| FASE-1 | ≈ 28 min (tiempos de los logs) |
| FASE-2 | ≈ 17 min |
| FASE-3 | ≈ 10 min |
| aceptación (`--check` tras FASE-0 ≈ 4 min; `--loop` ≈ 4 min) | ≈ 8 min |

| Hallazgo | Severidad | Estado |
|---|---|---|
| F2 setup sin kit no detecta `test`/`test_report` (sin JUnit no hay aceptación) | major | arreglado en esta rama |
| F3 `approval.md` falla con "nothing to commit" si los requisitos ya estaban commiteados | minor | arreglado en esta rama |
| F4 el hook marcó `tech-designer` running al escribir `design/OPERATION-MAPPING.md` | minor | sin confirmar (no se reprodujo; volvió solo a pending) |
| F5 ninguna etapa commiteaba sus artefactos | major | arreglado en esta rama |
| F6 `coverage/` fuera de `.gitignore` | minor | arreglado en esta rama |
| F7 tool guard: falso positivo con `accept record` dentro de una cadena | minor | arreglado en esta rama |
| F8 `SDD="node ruta"` no funciona en zsh | minor | arreglado en esta rama (`node "$SDD"`) |
| F9 sdd-graph.py: ids de módulo API-001/API-002 como referencias rotas | minor | arreglado en esta rama |
| F10 sdd-graph.py no indexa ids de NFR (SEC-NNN, SPEC-MNT-NNN) | minor | arreglado en esta rama |
| F11 una medición objetiva caducaba en cada FASE y pedía otro registro humano | major | arreglado en esta rama (`accept measure`, `--remeasure`) |
| F12 un commit de `feedback/` volvía obsoleta la evidencia JUnit | minor | arreglado en esta rama (frescura por `code_paths`/`test_paths`) |
| F13 tareas chore/build con test-first y sin test en su write-set | minor | arreglado en esta rama (chore/build declaran `Verify:`) |
| F14 sin tipo de rama para la aceptación global | minor | arreglado en esta rama (`sdd branch start acceptance`) |
| F15 restricciones comprobables por código declaradas `inspection` | mejora | arreglado en esta rama (guía: `test` con `REQ-C-NNN AC1`) |
| F16 bloque de PR / celda de evidencia de 31 KB para 10 requisitos | mejora | arreglado en esta rama (resumen por criterio; 4,3 KB en el mismo proyecto) |

## 2026-09-27 — comparación: vibe coding, ruta adaptativa y pipeline completo

Misma app, mismos `requirements/`, medida con un juego neutral de 19 criterios de caja negra derivado solo de `REQUIREMENTS.md`. Puertas humanas firmadas por un proxy de prueba.

| Enfoque | Tiempo | Criterios | Tests propios | ID único tras borrar la última tarea | Trazabilidad |
|---|---|---|---|---|---|
| Vibe coding (1 prompt, sin plugin) | 6 min | 19/19 | 117 | no (reutiliza el ID) | ninguna |
| Ruta adaptativa (Jev: sin specs, auditoría ni plan de tests) | 1 h 53 | 19/19 | 149 | no (reutiliza el ID) | completa, puerta final exit 0 |
| Pipeline completo | ≈ 4 h 15 | 19/19 | 617 | sí | completa |

- Ruta adaptativa: setup 2 min, ruta < 1, plan 14 (desde requisitos), tareas 32, FASE-0 23, FASE-1 ≈ 13, FASE-2 ≈ 11, FASE-3 ≈ 14, aceptación 3.
- Lo que solo atrapó el pipeline completo: la promesa "id único incremental" de REQ-F-001, que ningún criterio comprobaba; las specs la convirtieron en regla. Desde este run `req-lint` pregunta a Jev por promesas sin criterio (REQ-F-001 0,95; REQ-F-003 0,90).
- Hallazgos del run adaptativo: F19 (setup no commiteaba lo suyo; los merges de FASE fallaron) y F20 (las FASE siguientes se apilaron en la rama de FASE-0), corregidos en `b8ab2be`.
