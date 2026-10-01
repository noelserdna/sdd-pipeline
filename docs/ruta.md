# Ruta adaptativa

No todos los proyectos necesitan todas las etapas. En la ejecución real del todo-app (una CLI con 6 requisitos funcionales y una sola usuaria), 70 de los 134 minutos previos al código se fueron en specs formales, auditoría de specs y plan de tests, que en un proyecto así aportan poco. La ruta adaptativa hace que el pipeline proponga, justo después de aprobar los requisitos, qué etapas opcionales necesita **este** proyecto. Una persona la confirma con una sola pregunta.

No es un modo "lite" que haya que elegir a mano. Es una decisión con motivos legibles, que se registra y se vuelve a evaluar cuando cambian los requisitos.

## Cómo se decide

`sdd route` (`scripts/sdd.mjs`) combina dos tipos de información:

- **Hechos contados** en `requirements/REQUIREMENTS.md` y `CUSTOMER-NEEDS.md`: número de REQ-F, REQ-NF, REQ-C y Must, necesidades y necesidades fuera de alcance, y si ya hay código o un Stack Profile.
- **Siete juicios estrechos** sobre el texto de las necesidades y los requisitos, cada uno una probabilidad entre 0 y 1:

| Factor | Pregunta |
|---|---|
| `external_customer` | ¿Quien pide es alguien distinto de quien construye y tiene que aceptar la entrega? |
| `sensitive_data` | ¿Maneja datos personales, credenciales, pagos o información regulada? |
| `multi_actor` | ¿Hay varios tipos de usuario con permisos distintos? |
| `integrations` | ¿Depende de sistemas o APIs externos? |
| `ui_flows` | ¿Tiene interfaz de usuario con pantallas o recorridos? |
| `long_lived` | ¿Se espera mantenerlo y hacerlo evolucionar durante meses? |
| `complex_state` | ¿Hay concurrencia, procesos largos, estados con muchas transiciones o consistencia entre sistemas? |

Con `TYPESAFE_API_KEY`, Jev responde los siete factores (`scripts/jev/route.json`). Sin Jev, `sdd route` sale con código 3 y el LLM de la sesión (orquestador o lead) los responde en un fichero, `.sdd/route-answers.json` (`{"factors": {"external_customer": 0.7, …}}`), que se pasa con `--answers`. La consigna es responder con honestidad y escribir 0,5 cuando el texto no lo dice.

**Umbrales:** p ≥ 0,65 es sí; p ≤ 0,35 es no; en medio hay **duda, y la duda cuenta como sí**. Las dudas se nombran en la pregunta de confirmación, porque son justo lo que la persona puede aclarar.

A Jev nunca se le pregunta "¿hace falta SDD completo?": es una decisión de varios pasos, y ahí es donde un juicio rápido falla. Las preguntas son estrechas y las combina el código.

## Reglas por etapa

Están en `scripts/lib/route-rules.mjs`, cada una con su motivo en texto:

| Etapa | Se ejecuta si… |
|---|---|
| specifications-engineer | REQ-F > 8, o multi_actor, integrations, sensitive_data o complex_state |
| spec-auditor | se ejecutan specs, y además REQ-F > 5, sensitive_data o external_customer |
| test-planner | se ejecutan specs, y además ui_flows, REQ-F > 8 o external_customer |
| security-auditor | sensitive_data |
| ux-designer | ui_flows |
| tech-designer | integrations, complex_state, o no hay stack declarado |
| gap-detector | se ejecutan specs (sin specs, `--semantic` cuando hay código) |
| requirements, plan, tasks, implementer, acceptance | siempre (núcleo) |

## Confirmación

Es la etapa 1b del orquestador y del lead, después de la puerta 1 (requisitos aprobados):

1. `node "$SDD" route --json` (con `--answers .sdd/route-answers.json` si Jev está apagado).
2. Una sola pregunta: "Ruta recomendada: requisitos → plan vertical → tareas → implementación → aceptación. Se saltan specs formales (6 REQ-F, un solo tipo de usuario, sin integraciones), auditoría de specs y plan de tests. Dudas: long_lived. ¿Aceptas?". Las opciones son **Aceptar** (recomendada), **Pipeline completo** y **Ajustar** (qué etapas añadir o quitar).
3. `node "$SDD" route --write --confirm "<nombre> (<rol>)"`, con `--full` para el pipeline completo o `--set <etapa>=run|skip` por cada ajuste.

`--write` guarda el bloque `route` en `pipeline-state.json` (`decidedAt`, factores, hechos, etapas con su motivo, dudas, `confirmedBy` y `reqHash`) y deja cada etapa saltada con `status: "skipped"` y su `skipReason`. Una etapa `done` o `running` nunca pasa a `skipped`.

Una etapa `skipped` cuenta como satisfecha: no aparece como siguiente paso, las etapas posteriores pueden ejecutarse y el estado se resume como "N/M done, K skipped". `sdd-pipeline-status` enseña la ruta y los motivos, y `--write` anota en el diario de la página de estado (`status/journal.jsonl`) una línea `skip` por etapa saltada, con su motivo, y una `decision` con quién confirmó la ruta. La barra de fases de la página marca «Diseñar» como saltada solo cuando la ruta salta todo el diseño (specs, auditoría de specs y plan de tests, sin diseño técnico ni UX); las demás etapas saltadas se ven en el diario. La regla del orquestador "nunca saltar una etapa sin que el usuario lo sepa" se cumple con esta confirmación.

## El camino sin specs formales

Cuando la ruta salta `specifications-engineer`, los requisitos y sus criterios numerados son el contrato:

- **Cada promesa del enunciado necesita un criterio.** Sin specs, lo que solo dice el enunciado no lo prueba nadie: en el todo-app, "id único incremental" y "timestamp de completado" no tenían criterio y la implementación reutilizó ids. La puerta de aprobación de requisitos lo comprueba (`skills/sdd-requirements-engineer/references/approval.md` §3): con Jev, `sdd-jev.mjs req-lint` lo marca como `uncovered` (p ≥ 0,85); sin Jev, lo revisa el LLM. Se resuelve añadiendo un criterio con un ejemplo concreto o acotando el enunciado.
- **`sdd-plan-architect`** planifica desde `REQUIREMENTS.md` y `CUSTOMER-NEEDS.md` (modo Requirements-only). Los recorridos se agrupan por necesidad del cliente, no por caso de uso. Los `Escenarios` y la Demo citan `REQ-X-NNN ACn`. `ARCHITECTURE.md` se sigue escribiendo, aunque mínima. En el informe de validación, V2-V4 y V7 salen como N/A. `sdd lint --plan` comprueba que cada requisito tiene el criterio que se cita. Ejemplo: `tests/fixtures/plan-vertical/todo-reqonly`.
- **`sdd-task-generator` y `sdd-task-implementer`** no necesitan `spec/`. Las tareas citan los REQ y sus criterios, y los tests llevan `REQ-X-NNN ACn` en el nombre, que es por donde `sdd accept` los ata.
- **El bucle de aceptación** enruta un criterio sin test a `implement-or-test` cuando no existe `spec/tests`, porque no hay escenario que escribir. Con `spec/tests`, un criterio sin escenario sigue siendo `spec-gap`.
- **Las puertas** que dependían de etapas saltadas pasan a n/a: G1, G2, G5 y G6 de plan-architect, G0 de test-planner y G1, G3 y G4 de req-change.

## Reevaluación

Los requisitos cambian: aparecen pagos en una CLI, llega un segundo tipo de usuario. Por eso `sdd-req-change` vuelve a ejecutar `sdd route --json` tras cada ADD o MODIFY aprobado:

- Si la nueva ruta sube el rigor, informa de las `escalations` (etapas que ahora tocan y están `skipped`) con su motivo y recomienda ejecutarlas. Si la persona acepta, se registra con `route --write --set <etapa>=run --confirm …` y esas etapas se ejecutan antes que el plan.
- **Nunca baja el rigor solo.** Una etapa que ya se ejecutó sigue en la ruta aunque la nueva evaluación la saltaría.
- Mientras las specs sigan saltadas, el cambio se aplica solo a `requirements/` y la cascada empieza en `plan-architect` (`skills/sdd-req-change/references/cascade-patterns.md` §2).

`sdd-pipeline-status` avisa cuando `route.reqHash` ya no coincide con los requisitos actuales.

## Probarlo

- `tests/route/run.sh`: reglas, umbrales, dudas y respuestas sin Jev.
- `tests/e2e/20-smoke.sh --route auto|full`: la etapa `route` se ejecuta después de `setup`, con Jev si hay clave y, si no, con `tests/fixtures/route/todo-answers.json`. Las etapas specs, audit y test saltadas no se ejecutan, y la etapa plan acepta escenarios `REQ ACn`.
