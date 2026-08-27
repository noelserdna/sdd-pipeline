# Perfilado de una etapa: `sdd-spec-auditor` (2026-08-25)

Herramienta: `scripts/sdd-profile.sh` (ejecuta la skill con `claude -p --output-format stream-json --verbose` y desglosa el flujo de eventos; `--analyze FILE.jsonl` sobre una captura existente).

Caso: re-auditoría de `spec/` del todo-app (7 UC, 4 contratos, 7 ADR, dominio, NFR) en modo solo auditoría.

| Métrica | Valor |
|---|---|
| Duración total | **21,4 min**, de los que **21,1 min son tiempo de API** (el modelo generando o leyendo; los hooks y el disco son despreciables) |
| Turnos | 57 (56 llamadas a herramientas, todas `Bash`: `cat`/`echo` en modo `-p`) |
| Tokens de salida | **112.093** |
| Tokens de entrada nuevos | 5.161 · caché leída 3,64 M · caché creada 375 k |
| Leído por herramientas | 423.102 chars (~106 k tokens): los ficheros de `spec/` completos, uno a uno (resultados de hasta 28 k chars) |
| Escrito | 94.565 chars (el informe `AUDIT-BASELINE.md` y auxiliares) |
| Coste | ~16,8 $ |

## Dónde se va el tiempo

1. **Generación de salida (dominante).** 112 k tokens de salida a la velocidad típica del modelo explican por sí solos la mayor parte de los 21 min. El informe de auditoría de un proyecto de 10 requisitos ocupa ~95 k caracteres: la plantilla de la skill pide demasiado texto (restituye contenido de las specs, tablas exhaustivas por documento, hallazgos bajos redactados en extenso).
2. **Lectura completa del corpus.** ~106 k tokens de specs entran en contexto antes de escribir nada. Es caché (barato en tiempo por turno), pero obliga a 57 turnos con un contexto de ~64 k tokens y a que la primera pasada sea secuencial.
3. **Secuencialidad.** La auditoría por dimensiones (DOM/UC/CON/NFR) que la skill ya describe como "protocolo multi-agente" no se activa en modo `-p`: todo lo hace un único hilo.

## Recortes recomendados (estimación)

| Acción | Dónde | Ganancia estimada |
|---|---|---|
| Plantilla de informe compacta: solo hallazgos P0-P2 en detalle, P3 como tabla de una línea, sin restituir specs, sin secciones vacías | `skills/sdd-spec-auditor` (y misma revisión en test-planner, plan-architect, specifications-engineer, que también generan >80 k chars) | −40…−60 % de salida → −8…−12 min |
| Lectura por índice: leer primero IDs/títulos y solo abrir las secciones que cada dimensión necesita | referencias de las skills de auditoría | −30…−50 % de contexto; menos `cache_create` |
| Fan-out por dimensión con subagentes (Workflow) también en `-p`: 4 auditores en paralelo con contexto pequeño + consolidación | `sdd-spec-auditor` Mode multi-agente por defecto cuando `spec/` > N ficheros | tiempo de pared ≈ la dimensión más lenta (5-7 min) |
| Modelo más rápido para etapas mecánicas (`test-planner` matrices, `task-generator`, subagentes `[P]`) vía `CLAUDE_CODE_SUBAGENT_MODEL` / `--model` | ejecución | ×2-3 en esas etapas |
| Medir siempre: `scripts/sdd-profile.sh` en `tests/e2e` para cada release y guardar aquí la tabla | proceso | evita regresiones de coste |

Orden sugerido: 1 (mayor ganancia, solo texto de skills) → 3 → 2 → 4.

## Antes / después (mismo proyecto, mismo prompt: re-auditoría de `spec/` en modo solo auditoría)

| | 4.0.0 (secuencial) | 4.0.1 (plantilla compacta + fan-out + índice) |
|---|---|---|
| Tiempo de pared | **21,4 min** | **9,9 min** (−54 %) |
| Modo | 1 hilo, 57 turnos, 56 `cat` | 4 auditores sonnet en paralelo (DOM, UC, CON, NFR; 6-7 min cada uno) + consolidación en el principal (6 turnos) |
| Informe `AUDIT-BASELINE.md` | ~95 000 chars | **24 019 chars** (−75 %) |
| Tokens de salida | 112 k | ~97 k en total, repartidos entre los 4 auditores (JSON de hallazgos) y el principal (informe) |
| Tiempo de API acumulado | 21 min | 57 min (4 hilos en paralelo + principal) |
| Coste | ~16,8 $ | ~18 $ |

Lectura: la pared se reduce a la mitad y el informe a la cuarta parte; el coste no baja porque cada auditor lee su ámbito completo (755 k chars leídos en total frente a 423 k) y los cuatro producen hallazgos estructurados. Para bajar también el coste, el siguiente paso es acotar la lectura de cada auditor a las secciones de su índice (hoy leen su ámbito entero) y bajar el modelo del principal en la consolidación cuando no haya P0/P1.

Verificado también en la consola: con `refreshInterval: 5` la status line muestra `[sdd-spec] SDD [7/7] · spec-auditor 2m · 4 agentes` y el panel de agentes lista cada auditor con descripción, tiempo y tokens (`subagentStatusLine` del plugin).

## Evidencia: el fan-out sí baja tiempo y coste, pero solo con lectura acotada

Misma auditoría del mismo `spec/` del todo-app, tres versiones del plugin (detalle en [`medidas.md`](medidas.md)):

| | 4.0.0 secuencial | 4.0.2 secuencial + plantilla compacta + índice | 4.0.3 fan-out + lectura por secciones |
|---|---|---|---|
| Tiempo de pared | **21 min** | **11 min** | **5 min** |
| Coste | **16,8 $** | — | **8,19 $** |
| Modo registrado | `metrics.mode = sequential` | `metrics.mode = sequential` | `metrics.mode = fanout`, 4 auditores sonnet |

Las dos palancas son necesarias juntas: en 4.0.2 el fan-out **no se activó ni una vez** (0 eventos `subagent-start`) porque la skill leía su propia instrucción como una preferencia frente a la política del entorno sobre lanzar subagentes; y el fan-out sin acotar de la primera prueba bajó la pared a 9,9 min pero subió el coste a ~18 $, porque cada auditor leía su ámbito entero. Declarar el fan-out como **parte del contrato de la skill** (no una expansión de alcance) más leer por índice/secciones da los 5 min **y** los 8,19 $: menos de la mitad del coste del secuencial original.

## Paralelismo por etapa

Cinco etapas paralelizan trabajo mecánico dentro de una sola sesión. El vocabulario es el mismo en todas: el fan-out es **parte del contrato de la skill** por encima de su umbral (invocarla sobre una entrada de ese tamaño *es* la petición explícita de los subagentes), nunca se degrada "por prudencia", y cuando se degrada el motivo queda escrito.

| Etapa | Unidad paralelizada | Umbral por defecto | Forzar | Desactivar | Qué queda en el hilo principal | Métrica que lo registra |
|---|---|---|---|---|---|---|
| `sdd-specifications-engineer` | carriles R de 2-3 requisitos funcionales (UC + BDD + decisiones de contrato) + un carril transversal X (`nfr/`, `adr/`, `PROPERTY-TESTS`) | más de 4 requisitos funcionales | `--fanout` | `--sequential` | Modo 1, catálogo de ids (fase A) y documentos compartidos (`domain/01..05`, `VALUE-REGISTRY`, `CLARIFICATIONS`); luego contratos, workflows, `DERIVED-SPECS`, `TRACEABILITY-MATRIX`, `README`, gate y Persist Summary | `metrics.mode` + `metrics.spec_agents` |
| `sdd-spec-auditor` | dimensión del corpus: 4 auditores fijos (DOM, UC/WF, CON/BDD, NFR/ADR) | `spec/` con > 8 ficheros **o** > 40 k chars | `--fanout` | `--sequential` | índice, referencias cruzadas, cobertura REQ y huérfanos, marcadores, SC03/SH05, baseline y regresión, deduplicación, revisión de la evidencia de cada P0/P1, Gate e informe | `metrics.mode` = `fanout` \| `sequential` |
| `sdd-test-planner` | grupo de 2-3 UC → una `TEST-MATRIX-UC-*.md` cada uno; además los tiers Critical/Full de E2E cuando son el camino crítico (> 1 workflow o > 20 escenarios) | más de 3 UC | `--fanout` | `--sequential` | `TEST-PLAN.md` (y su §3 Design Decisions, escrita **antes** de lanzar: es el contrato de convenciones), `PERF-SCENARIOS.md`, `E2E-SCENARIOS.md`, verificación de ficheros e ids, plegado de gaps en §4 | `summary.highlights` (el motivo de la degradación) |
| `sdd-task-generator` | una FASE → un `task/TASK-FASE-N.md` cada uno (máx. 4 simultáneos) | 2 o más FASEs con artefactos de plan | `--fanout` | `--sequential` | contrato transversal fijado **antes** del fan-out (numeración `TASK-F{N}-{SEQ}`, convenciones de commit, rutas, glosario, plantillas y la tabla *Módulos y Conjuntos de Escritura* de cada FASE, semilla de sus Streams); después, `TASK-INDEX.md` y `TASK-ORDER.md` (Waves, dependencias cross-FASE, matriz de trazabilidad) y las validaciones globales V-04, V-09, V-11 y V-15..V-18 sobre los JSON devueltos | `metrics.mode` + `metrics.task_agents` |
| `sdd-task-implementer` | una task marcada `[P]` (máx. 4 simultáneos por lote) | hay tasks `[P]` con sus dependencias satisfechas en el lote | `--parallel` | `--sequential` | la Phase 7 (checklist de revisión) de cada task, **todos los commits** (git no admite commits en paralelo) y la verificación de FASE (Phase 9) | `metrics.mode` = `parallel` \| `sequential` |

Reglas comunes a las cinco:

- **Modelo:** los subagentes se lanzan con `model: sonnet` salvo que `CLAUDE_CODE_SUBAGENT_MODEL` esté definido, en cuyo caso no se pasa `model` y decide el entorno. La consolidación, las decisiones de puerta y los commits los hace siempre el hilo principal con su propio modelo.
- **Acotados:** `subagent_type: general-purpose` (nunca `fork`: el objetivo es un contexto pequeño y nuevo), sin anidar, cada uno escribe como mucho un fichero que ningún otro toca, y ninguno escribe `pipeline-state.json` ni envía handoffs.
- **Degradación:** solo por estar bajo el umbral, por el flag de desactivar, o porque el tool `Agent` no está en la lista. El motivo va siempre en `summary.highlights` (y en `metrics.mode` donde existe).
- **Reintento:** un subagente que falla o devuelve JSON inválido se relanza una vez; si vuelve a fallar, el principal hace ese trozo en secuencial y lo deja escrito.
- **Eje distinto:** `--stream X` de `sdd-task-implementer` **no** es fan-out: son sesiones y worktrees separados sobre write-sets disjuntos ([`multisesion.md`](multisesion.md)). Los dos ejes se componen — dentro de un worktree de Stream, sus tasks `[P]` siguen yendo a subagentes.
- **Comprobar que se activó:** la status line y `scripts/sdd-watch.sh` muestran los subagentes vivos como `N agentes`; en el log, un evento `subagent-start` por cada uno en `.sdd/activity.jsonl`.

## Lección de la tercera medición (2026-08-27): paralelizar lo que está en el camino crítico

`sdd-test-planner` con fan-out activo (3 subagentes de matrices, 2-4,5 min cada uno) tardó **11 min**, frente a los
10 min de la pasada secuencial: las matrices no eran el cuello de botella. El hilo principal seguía escribiendo
`TEST-PLAN`, `PERF-SCENARIOS` y 40 escenarios E2E mientras los agentes ya habían terminado. Corregido delegando también
los tiers Critical/Full de E2E (`skills/sdd-test-planner/SKILL.md`, Full Run Order paso 4).

En `sdd-spec-auditor` ocurrió lo contrario y conviene no confundirlo: los 17 min de la tercera pasada frente a los 11 de
la segunda **no** son una regresión del fan-out — el descubrimiento en paralelo tardó ~8 min (el carril más lento) y el
resto fue el ciclo de corrección de un **P0 real** que la pasada secuencial no había encontrado (`add` validaba el
título después de cargar el almacén, dejando `AC-006-08` insatisfacible; se resolvió con un ADR y una operación nueva).
Al comparar etapas hay que mirar `audit_cycle` y el número de hallazgos, no solo el reloj.

Desequilibrio observado en los carriles del auditor: contratos 5 min frente a ~8 min de dominio, casos de uso y NFR.
Repartir por tamaño de ámbito en vez de por dimensión fija daría algo más de margen.
