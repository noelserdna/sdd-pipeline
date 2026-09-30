# Jev en el pipeline SDD (2026-09-27)

[Jev](https://docs.typesafe.ai) es el modelo "System One" de TypeSafe. No genera texto: recibe un estado de texto (hasta ~32k tokens) y preguntas tipadas, y devuelve un **Noul** (probabilidad de "sí"), una **Choice** (una opción de hasta 255, con probabilidades y confianza) o un **Score** (un nivel de una rúbrica ordenada). Tarda unos 100 ms por petición, cuesta 0,042 $ por millón de tokens de entrada y sus probabilidades están calibradas.

En este plugin, Jev hace **pre-pasadas masivas**. Juzga muchos elementos pequeños a la vez (requisitos, líneas de spec, trozos de código) y el LLM solo lee lo marcado o lo incierto. Jev nunca decide solo. `scripts/sdd-jev.mjs` devuelve probabilidades, y la skill aplica umbrales documentados y escala al LLM lo que queda en medio.

## Activación (opt-in)

```bash
export TYPESAFE_API_KEY=...        # sin ella, todo sigue como antes (exit 3 → la skill usa el LLM)
export SDD_JEV=off                 # desactiva Jev aunque haya key
node "$SDD_PLUGIN_ROOT/scripts/sdd-jev.mjs" status
```

El texto de specs y de código viaja a `api.typesafe.ai`, así que no conviene activarlo en proyectos donde eso no esté permitido. La key vive en el entorno del usuario y nunca en el repo.

| Comando | Qué hace | Quién lo usa |
|---|---|---|
| `req-lint [REQUIREMENTS.md]` | Por requisito: término vago, compuesto, no verificable, fuga de implementación y patrón EARS (las restricciones `REQ-C-*` no pasan por EARS ni por fuga de implementación) | `sdd-requirements-engineer` Mode 2 |
| `needs [CUSTOMER-NEEDS.md] [REQUIREMENTS.md]` (`need-coverage.json`) | Cobertura de necesidades del cliente. Primero la comprobación mecánica, sin red (con `--mechanical` se queda ahí: exit 1 si hay errores). Después, con Jev, dos pasadas de Choice: por necesidad sobre los IDs de requisito más `none`, y por cada requisito que ninguna necesidad eligió, sobre las necesidades más `none` | `sdd-requirements-engineer` Mode 1 y puerta 1 (`references/approval.md`) |
| `judge --questions scripts/jev/spec-triage.json --items hits.jsonl` | Triaje de los hits de los patrones de detección: CAT-01/02/03/04/06/07/09 o `not_a_defect` | `sdd-spec-auditor` Fase 1 |
| `judge --questions scripts/jev/coverage.json --items pares.jsonl` | ¿Este trozo de código implementa este requisito? (`implements`, `partial`, `related`) | `sdd-gap-detector --semantic` |
| `chunks FICHERO…` | Parte el código en fronteras de nivel superior (≤24k chars) para `judge` | `sdd-gap-detector --semantic` |
| `judge --questions scripts/jev/feedback-route.json --items feedback.jsonl` | Puerta de FASE: una Choice por cada comentario del cliente sobre el incremento (`defect`, `change_request`, `question`). Solo propone: una persona confirma la ruta, y por debajo de 0,7 de confianza se pregunta sin propuesta | `sdd-orchestrator` y `sdd-lead` (`skills/sdd-orchestrator/references/fase-gate.md`) |
| `judge --questions scripts/jev/test-adequacy.json --items pares.jsonl` | Por (criterio, test que lo verifica): dos Noul, ¿el test afirma el THEN? y ¿ejecuta el WHEN? Por debajo de 0,5 en cualquiera se marca para revisión. Informativo: un test que pasa sigue VERIFIED. En la ronda adversarial es además una pre-pasada sobre **todos** los criterios con test ligado (no solo los Must VERIFIED): ordena qué miran primero los verificadores y elige la muestra de veredictos limpios que se contraverifica | `sdd-acceptance --check` (y `--sign-off`; sin Jev lo contesta un subagente independiente) y `sdd-acceptance --adversarial` (sin Jev ordena el LLM) |
| `judge --questions scripts/jev/evidence.json --items demos.jsonl` | Por (criterio, demo observada): un Score de 3 niveles, ¿la salida muestra el THEN? (no / parcial / sí). Ayuda a la persona antes de `sdd accept record demo`; lo que se registra es su respuesta | `sdd-acceptance --loop` (ruta `needs-human`) |

Los umbrales de cada conjunto viven dentro de su JSON (`thresholds`). Los dos de aceptación (`test-adequacy`, `evidence`) tienen fixtures etiquetados en `tests/jev/fixtures/` y la suite comprueba su forma sin red; medición real (jev-1.13.0, 2026-09-27): `test-adequacy` 6/6 (un test sin aserción da `asserts_then` = 0,06; uno que comprueba otro resultado, 0,02; los adecuados, ≥ 0,96), `evidence` 4/4 y `feedback-route` 6/6 sobre feedback real en español (defecto, petición de cambio y pregunta, todos con confianza ≥ 0,81). Son muestras pequeñas: sirven para comprobar que la pregunta está bien planteada, no como calibración definitiva. Amplía los fixtures con casos de tus proyectos (`SDD_JEV_CALIBRATE_KEY=… bash tests/jev/run.sh`).

Los conjuntos de preguntas están en `scripts/jev/*.json`. Si cambias una pregunta, cambias el comportamiento: pruébalo antes con casos etiquetados, como en el experimento de requisitos de abajo.

## Qué se midió en la revisión del repo con Jev

| Pasada | Tamaño | Tiempo | Tokens (coste) | Resultado |
|---|---|---|---|---|
| Secciones de las 24 skills (propósito, conocimiento genérico, material de referencia, ambigüedad, énfasis, claridad) | 355 secciones | 6,6 s | 530k (~0,02 $) | Casi nada de "conocimiento genérico". Entre el 32 % y el 53 % de las 4 skills grandes era material de referencia de un solo paso, y eso guio el recorte. |
| Enrutado: descripciones de las skills contra 56 peticiones parafraseadas (ES/EN) | 56 peticiones | 1,8 s | 192k | **55/56** correctas. El único fallo, "ponte a programar las tareas", es ambiguo en español y se corrigió añadiendo triggers. |
| Solapamiento entre skills (276 pares, un Noul por par) | 276 preguntas | <1 s | — | Un solo par por encima de 0,4: `gap-detector` y `verify-coverage` (0,50). Se fusionaron. |
| Cribado de código (hooks, scripts, servidor, dashboard; el dashboard HTML ya no existe en 5.0) | 171 trozos | 3,4 s | 296k | Cero marcas de inyección, coste en ruta caliente o portabilidad. Las marcas de "error silenciado" eran en su mayoría fail-open intencionado. |
| Requisitos con defectos sembrados (8 limpios de `examples/todo-app` + 12 mutantes) | 20 requisitos | 0,75 s | 14k | 0 falsos positivos en los limpios. Recall del 100 % en vago, compuesto, no verificable y fuga de implementación. |
| `req-lint` sobre el REQUIREMENTS.md real del ejemplo | 10 requisitos | 0,42 s | 7k | Marcó `REQ-F-006` como compuesto (p = 0,92). Es correcto: tiene dos cláusulas WHEN independientes (persistir y cargar). |

### Cobertura de necesidades (`needs`)

La comprobación que decide es mecánica: toda necesidad `N-NNN` de `CUSTOMER-NEEDS.md` está citada en algún `Needs:` o está `out-of-scope` con su decisión, todo `REQ-F`/`REQ-NF` activo cita una necesidad (los `REQ-C` de equipo pueden llevar `Needs: —`), todo requisito tiene `Verification: test | demo | measurement | inspection`, y se avisa si más del 60 % son Must sin la lista Must confirmada. `parseRequirements` y `checkNeedCoverage` están exportados para que otras herramientas (`sdd lint --needs`) usen el mismo parser.

Jev solo sugiere. Las opciones de la Choice dependen del documento, así que las construye el código: la clave de cada opción es el ID del requisito y su criterio es el enunciado. Las instrucciones estáticas y el umbral de confianza (0,5) están en `scripts/jev/need-coverage.json`. La primera prueba, con una sola pasada, marcaba como gold plating requisitos legítimos: una necesidad suele repartirse entre varios requisitos (ver y filtrar la lista) y una Choice elige solo uno. Por eso hay una segunda pasada inversa, solo para los requisitos que nadie eligió.

Resultado sobre `examples/todo-app` (6 necesidades, una fuera de alcance; 10 requisitos), `jev-1.13.0`, 8,5k tokens:

| Pasada | Resultado |
|---|---|
| Por necesidad | 4 de 5 con confianza ≥ 0,84. `N-003` ("marcar hechas y tirar las añadidas por error") queda en 0,49 entre `REQ-F-004` y `REQ-F-003`: la necesidad es compuesta y los dos la cubren |
| Inversa | `REQ-F-002` → `N-002` (1,00) y `REQ-F-003` → `N-003` (0,77), bien. `REQ-NF-002` (cobertura de tests del 90 %) → `none` (0,89): candidato a gold plating. Es discutible, porque la cita "no rompáis lo que ya funciona" lo justifica solo de forma indirecta. Es justo la conversación que la herramienta debe provocar |

### Límites observados

- **No sustituye a la revisión profunda.** El bug más grave encontrado, el parser de commits de `generate.py` (hoy `scripts/sdd-graph.py`) que descartaba casi todos los commits, no lo marcó el cribado de Jev. Es un error de lógica de varios pasos, justo lo que Jev declara como punto débil, y lo encontró la revisión con el LLM. Úsalo para priorizar, no para dar por buena una zona.
- **Preguntas de una sola línea.** Una línea aislada no permite juzgar la sobreespecificación de transporte (CAT-10), porque depende de si algún requisito exige la ruta. Tampoco permite juzgar contradicciones entre documentos (CAT-05). Por eso esas categorías no están en el triaje y van directas al auditor.
- **Cobertura repartida.** Si un requisito se implementa entre varios ficheros, cada trozo puede puntuar bajo. Un `implements` bajo nunca prueba ausencia: esos casos van al LLM.
- **Idioma.** Jev rinde mejor en inglés. Las preguntas están en inglés aunque el estado (la spec) esté en español.

## Dónde no usar Jev

- **Decisiones de permiso en hooks** (upstream guard, tool guard). Deben ser deterministas, no depender de la red y no abrirse ante un timeout.
- **commit-msg.** Los hooks de git corren fuera de Claude, y una llamada de red bloquearía el commit.
- **Sugerir una skill en cada prompt** (UserPromptSubmit). Las descripciones ya enrutan 55/56. Además añadiría red y latencia a cada prompt y enviaría todos los prompts a un tercero.
- **Contar, comparar fechas o hacer aritmética.** Eso lo hace el código.
- **Veredictos de aceptación, exenciones, firmas, la parada del bucle o cualquier cosa que corra en CI.** Los decide `sdd accept` / `sdd gate` / `sdd loop next` o una persona; Jev solo añade una marca informativa.
- **La ronda adversarial, salvo para priorizar.** Verificar y contraverificar exige recorrer el código (seguir callers, buscar la ruta que esquiva la implementación, comparar el mock con el provider real), y una puntuación baja nunca prueba ausencia. Lo hacen agentes Claude en contexto limpio; la CLI registra los hallazgos (`challenges.jsonl`) y calcula la puerta (`adversarial_gate`); descartar un hallazgo es cosa de una persona. Una puntuación alta no marca nada como limpio.
- **Evidencia visual.** Jev no ve imágenes ni vídeo: no juzga si una captura de `evidencias/` muestra el criterio. Eso lo comprueban los verificadores adversariales, que sí leen capturas, y al final el cliente en la puerta de FASE.

## Próximos candidatos (no implementados)

Salieron de la revisión y encajan con el patrón "muchos juicios estrechos":

- `sdd-req-change` Fase 2: un Noul por (CR × sección de spec) como filtro de impacto directo.
- `sdd-reconcile`: una Choice por divergencia sobre sus clases, con la confianza decidiendo entre "auto" y "preguntar".
- `sdd-import`: una Choice por fila o ticket (FR/NFR/restricción/AC/defecto/ruido).
- `sdd-security-auditor`: un Noul por (capítulo ASVS × documento) como mapa de calor previo.
- `sdd-test-planner` Mode 5: una Choice por campo sobre los elementos del wireframe.
