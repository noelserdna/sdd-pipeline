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
| `judge --questions scripts/jev/spec-triage.json --items hits.jsonl` | Triaje de los hits de los patrones de detección: CAT-01/02/03/04/06/07/09 o `not_a_defect` | `sdd-spec-auditor` Fase 1 |
| `judge --questions scripts/jev/coverage.json --items pares.jsonl` | ¿Este trozo de código implementa este requisito? (`implements`, `partial`, `related`) | `sdd-gap-detector --semantic` |
| `chunks FICHERO…` | Parte el código en fronteras de nivel superior (≤24k chars) para `judge` | `sdd-gap-detector --semantic` |

Los conjuntos de preguntas están en `scripts/jev/*.json`. Si cambias una pregunta, cambias el comportamiento: pruébalo antes con casos etiquetados, como en el experimento de requisitos de abajo.

## Qué se midió en la revisión del repo con Jev

| Pasada | Tamaño | Tiempo | Tokens (coste) | Resultado |
|---|---|---|---|---|
| Secciones de las 24 skills (propósito, conocimiento genérico, material de referencia, ambigüedad, énfasis, claridad) | 355 secciones | 6,6 s | 530k (~0,02 $) | Casi nada de "conocimiento genérico". Entre el 32 % y el 53 % de las 4 skills grandes era material de referencia de un solo paso, y eso guio el recorte. |
| Enrutado: descripciones de las skills contra 56 peticiones parafraseadas (ES/EN) | 56 peticiones | 1,8 s | 192k | **55/56** correctas. El único fallo, "ponte a programar las tareas", es ambiguo en español y se corrigió añadiendo triggers. |
| Solapamiento entre skills (276 pares, un Noul por par) | 276 preguntas | <1 s | — | Un solo par por encima de 0,4: `gap-detector` y `verify-coverage` (0,50). Se fusionaron. |
| Cribado de código (hooks, scripts, servidor, dashboard) | 171 trozos | 3,4 s | 296k | Cero marcas de inyección, coste en ruta caliente o portabilidad. Las marcas de "error silenciado" eran en su mayoría fail-open intencionado. |
| Requisitos con defectos sembrados (8 limpios de `examples/todo-app` + 12 mutantes) | 20 requisitos | 0,75 s | 14k | 0 falsos positivos en los limpios. Recall del 100 % en vago, compuesto, no verificable y fuga de implementación. |
| `req-lint` sobre el REQUIREMENTS.md real del ejemplo | 10 requisitos | 0,42 s | 7k | Marcó `REQ-F-006` como compuesto (p = 0,92). Es correcto: tiene dos cláusulas WHEN independientes (persistir y cargar). |

### Límites observados

- **No sustituye a la revisión profunda.** El bug más grave encontrado, el parser de commits de `generate.py` que descartaba casi todos los commits, no lo marcó el cribado de Jev. Es un error de lógica de varios pasos, justo lo que Jev declara como punto débil, y lo encontró la revisión con el LLM. Úsalo para priorizar, no para dar por buena una zona.
- **Preguntas de una sola línea.** Una línea aislada no permite juzgar la sobreespecificación de transporte (CAT-10), porque depende de si algún requisito exige la ruta. Tampoco permite juzgar contradicciones entre documentos (CAT-05). Por eso esas categorías no están en el triaje y van directas al auditor.
- **Cobertura repartida.** Si un requisito se implementa entre varios ficheros, cada trozo puede puntuar bajo. Un `implements` bajo nunca prueba ausencia: esos casos van al LLM.
- **Idioma.** Jev rinde mejor en inglés. Las preguntas están en inglés aunque el estado (la spec) esté en español.

## Dónde no usar Jev

- **Decisiones de permiso en hooks** (upstream guard, tool guard). Deben ser deterministas, no depender de la red y no abrirse ante un timeout.
- **commit-msg.** Los hooks de git corren fuera de Claude, y una llamada de red bloquearía el commit.
- **Sugerir una skill en cada prompt** (UserPromptSubmit). Las descripciones ya enrutan 55/56. Además añadiría red y latencia a cada prompt y enviaría todos los prompts a un tercero.
- **Contar, comparar fechas o hacer aritmética.** Eso lo hace el código.

## Próximos candidatos (no implementados)

Salieron de la revisión y encajan con el patrón "muchos juicios estrechos":

- `sdd-req-change` Fase 2: un Noul por (CR × sección de spec) como filtro de impacto directo.
- `sdd-reconcile`: una Choice por divergencia sobre sus clases, con la confianza decidiendo entre "auto" y "preguntar".
- `sdd-import`: una Choice por fila o ticket (FR/NFR/restricción/AC/defecto/ruido).
- `sdd-security-auditor`: un Noul por (capítulo ASVS × documento) como mapa de calor previo.
- `sdd-test-planner` Mode 5: una Choice por campo sobre los elementos del wireframe.
