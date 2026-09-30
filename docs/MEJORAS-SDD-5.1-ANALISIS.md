# Análisis de las mejoras propuestas para sdd-pipeline 5.1

> Verificación de `docs/MEJORAS-SDD-5.1.md` contra el código de la versión 5.0.0, hecha por seis agentes en solo lectura
> (uno por área: aceptación adversarial, test-planner, task-generator, task-implementer, CLI de aceptación y smoke
> post-deploy). Cada afirmación del «Hoy» se contrastó con el código. Los dos bugs de la sección 1 se confirmaron a mano.
> Sep-2026.

## 0. Veredicto por mejora

| Mejora | ¿El «Hoy» es cierto? | Coste real | Nota |
|--------|----------------------|------------|------|
| M1 Ronda adversarial | Cierta | M | Nada compara la letra del requisito con el código; el veredicto es solo binding por id |
| M2 Contract-test mock↔real | Parcial | M | El generador no conoce puertos ni mocks: salen del plan como componentes sueltos |
| M3 «VE X» ⇒ journey | Parcial | S texto + M adjuntos | La plantilla no prescribe `toBeVisible` del contenedor, pero el ejemplo canónico del implementer sí lo usa |
| M4 Replay/carrera | Cierta en test-planner | S | specifications-engineer pregunta por concurrencia, pero nunca por la segunda ejecución idéntica |
| M5 Smoke post-deploy | Parcial | M (no «Bajo») | El CI del plugin no construye ni despliega: el job no tiene dónde engancharse sin tocar el CI del proyecto |
| M6 Letra literal en el test | Cierta | S texto + M lint | El implementer nunca abre `requirements/REQUIREMENTS.md` |
| M7.1 Orden commit → evidencia | Parcial | S | `sdd-acceptance` lo pide, pero Phase 9 del implementer y la CLI no lo imponen |
| M7.2 Recursos de la máquina | Cierta | S | No existe ninguna regla; hasta 4 agentes por lote y estaciones `impl-*` sin tope |

## 1. Bugs de 5.0.0 encontrados durante la verificación

Estos no son mejoras: son defectos actuales que conviene corregir antes que nada.

1. **Ficheros sin versionar no ensucian el árbol** (`scripts/lib/acceptance.mjs:219`). `gitContext` usa
   `git status --porcelain --untracked-files=no`. Un fichero nuevo en `src/` o `tests/`, sin `git add`, del que dependen
   los tests no marca `codeDirty`. El JUnit cuenta como fresco y el ledger da VERIFIED sobre un `evaluated_sha` donde
   ese fichero no existe. Lo encontraron dos agentes por separado. `sdd-acceptance/SKILL.md:94` repite el mismo
   `--untracked-files=no` en su Step 1.
   **Arreglo:** `--untracked-files=all` limitado a `code_paths` + `test_paths`, y exportar `untracked_paths` en el ledger.
   Test nuevo en `tests/acceptance/run.sh`.

2. **El loop de aceptación genera tareas que el implementer no ejecuta** (`skills/sdd-task-implementer/SKILL.md:32`).
   `--loop` llama a `/sdd-task-generator --incremental`, que escribe fix-tasks con `Source: ACCEPTANCE-LOOP` o
   `Source: FEEDBACK-FASE-{N}` (`sdd-task-generator/SKILL.md:47`). Después llama a `/sdd-task-implementer --new-tasks-only`,
   cuyo Mode 6 selecciona **solo** `Source: CASCADE-{id}`. Las fix-tasks del loop quedan fuera del filtro.
   **Arreglo:** Mode 6 acepta `Source: CASCADE-*|ACCEPTANCE-*|FEEDBACK-FASE-*`. M1 añadiría `ACCEPTANCE-ADVERSARIAL-*`.

3. **Un registro humano sobre código sin commitear nace desanclado** (`scripts/lib/acceptance-cli.mjs:168`).
   `accept record demo|measurement|inspection` fija `head` = HEAD sin comprobar el árbol. Si lo observado incluye
   cambios sin commitear, el registro es stale desde que se graba y sigue stale tras el commit. Es el caso exacto que
   M7.1 describe como «desancla el gate humano».

4. **(Decisión de diseño, no bug)** `fase-acceptance` solo caduca por el hash del texto del requisito
   (`acceptance.mjs:412-420`). Un commit de código posterior a la firma deja el acta como «Current: yes» aunque la
   evidencia de debajo ya esté stale. El siguiente `gate` sale con 2, así que no hay riesgo de aceptar en falso, pero el
   informe engaña.

## 2. Análisis por mejora

### M1 — Ronda adversarial

**Hoy.**
- El veredicto se calcula en `acceptance.mjs:401-405` solo por binding: un JUnit fresco en `pass` cuyo nombre contiene
  `AC-NNN-NN` o `REQ-X-NNN ACn` da VERIFIED.
- El único juicio semántico es `test-adequacy.json` (Jev), que es consultivo y solo mira Musts ya VERIFIED.
- `gap-detector --semantic` no sirve como base directa:
  - excluye los tests a propósito (`verification-prompt.md:51-52`);
  - deja fuera los requisitos con un codeRef de confianza ≥ 0.8, que es justo donde vive P3;
  - no prohíbe citar `spec/` ni `acceptance/`;
  - no alimenta el loop.
- No existe crítico de cobertura. Nadie comprueba que la unión de los `Requisitos:` de las FASEs cubra todos los
  requisitos activos.

**Solución.** Un modo `sdd-acceptance --adversarial [--fase N]`, no una etapa nueva. `acceptance` ya es lateral y está
exenta de stale, y una etapa lineal obligaría a tocar `SDD_STAGE_ORDER`, la plantilla de estado, los contadores del
session-start y la ruta adaptativa.

1. `sdd accept adversarial plan` hace de crítico de cobertura mecánico. Lista los requisitos activos que no están en
   ninguna FASE, las FASEs sin cabecera y los criterios sin test ligado.
2. Un verificador por FASE, en contexto limpio y solo lectura, con las cuatro reglas del documento y la regla de recursos
   de M7.2. Por criterio devuelve `clean` o `finding` con categoría (`WEAKENED-ASSERT`, `MOCK-ONLY`, `UNWIRED`,
   `BYPASS-PATH`, `NOT-IMPLEMENTED`, `SPEC-QUESTION`), la cita literal y la evidencia `path:línea`.
3. Un contraverificador recibe cada hallazgo sin el razonamiento del primero e intenta refutarlo. El resultado es
   `confirmed`, `refuted` o `inconclusive`; `inconclusive` va a un humano.
4. Los hallazgos confirmados se registran en un fichero nuevo, `acceptance/challenges.jsonl`, con
   `sdd accept challenge add`. `validateChallenge` rechaza evidencia bajo `acceptance/`, `feedback/`, `spec/`,
   `requirements/`, `plan/` o `task/`, de modo que la regla 1 del documento queda aplicada en código.
5. **El veredicto no cambia.** El ledger añade `challenges[]` por requisito y `summary.must_challenged`. `sdd loop next`
   los devuelve como target con la ruta `adversarial-finding`. Descartar uno es un registro humano
   (`challenge-dismissal`), que el tool guard ya intercepta.
6. **Jev no decide nada en esta ronda (sección 6).** Solo ordena qué criterios miran primero los verificadores.
7. La puerta es configurable con `adversarial_gate: off|warn|enforce` en el Stack Profile. Con `enforce`, un challenge
   abierto en un Must hace salir a `sdd gate` con 4.

**Contratos afectados.**
- Métricas de §9 de cascade-patterns y tabla de salidas de `docs/aceptacion.md`.
- `status-page.md`, `fase-gate.md` del orquestador, despacho QA de `sdd-lead` y upstream guard para `challenges.jsonl`.
- Tipos en `server/src/acceptance.ts` y el filtro de Mode 6 (bug 2).

### M2 — Contract-test mock ↔ provider real

**Hoy.**
- Phase 2 del generador descompone por componente, entidad, operación y wiring (`sdd-task-generator/SKILL.md:129-138`).
  Las palabras port, adapter, mock y provider no aparecen.
- El único «contract test» del plugin valida el schema de una operación entrante (`tdd-workflow.md` Category 3).
- `construction-protocol.md:439` recomienda mockear servicios externos sin pedir paridad con el real.

**Solución.**
- **Detección explícita, no heurística.** plan-architect añade a `PLAN-FASE §4` una tabla «Puertos con doble»:
  `| Puerto | Interfaz | Doble | Provider real | Observable del contrato |`. Un mock en §7.2 sin fila de puerto → `[PLAN GAP]`.
- El generador emite por cada puerto una tarea hermana `CONTRACT-<puerto>`, bloqueada por la del doble y la del provider,
  en el Stream del provider, con Revert SAFE.
- El implementer añade una Category 3b en `tdd-workflow.md`:
  - un `describe.each([double, real])`;
  - el real con un transporte fake que captura la request;
  - asserts sobre la forma de la request: campos del prompt, instrucciones, partes del contexto y fuente de la config.
- Para que cuente en el ledger, el test se llama `CONTRACT-<puerto> REQ-F-078 AC1 …`.
- Aviso opcional V-21 en `plan-lint.mjs`: un puerto de §4.x sin tarea `CONTRACT-`.

### M3 — «El usuario VE X» ⇒ journey E2E

**Hoy.**
- No hay regla que ligue un AC visual con un E2E. Mode 5 del test-planner se dispara por workflow, no por el texto del AC.
- El ejemplo del implementer usa `expect(page.getByText('Welcome')).toBeVisible()` (`tdd-workflow.md:234`).
- Las reglas de testing de los dos kits dicen «No browser tests when the project has a shared acceptance suite», lo que
  se lee como prohibición.
- Screenshots solo `only-on-failure`. El parser JUnit ignora `<system-out>`, incluido el `[[ATTACHMENT|…]]` de Playwright
  que ya trae el fixture `tests/fixtures/acceptance/junit/playwright.xml`.
- La review checklist no llega a los proyectos con los kits: usan `task_format: compact`, que no lleva bloque Review.

**Solución.**
- **Detección:** un marcador explícito en el requisito. El THEN empieza por «ENTONCES el usuario ve …» o
  «THEN the user sees …», decidido con el cliente en requirements-engineer. El léxico ES/EN queda como red de seguridad
  para listar candidatos y preguntar.
- **test-planner:** convención fija en §3 Design Decisions y paso nuevo en Mode 5. El E2E:
  1. entra por la ruta del usuario;
  2. asserta el texto del ejemplo del criterio con `toHaveText`/`toContainText`;
  3. guarda un screenshot nombrado con los ids.

  Un criterio visual sin ese escenario es un gap `MISSING-E2E`.
- **task-generator:** una tarea de journey por FASE en el Stream `verificación`, que cita los escenarios «VE X» y el
  primer paso de la Demo. Esto también cubre P2 (pieza no cableada), porque convierte el cableado en un test rojo. La
  regla va en Phase 2 y en Acceptance, que sí viajan en formato compact, no solo en la checklist.
- **implementer:** sustituir el ejemplo de `tdd-workflow.md:234`. Corregir `rules/testing.md` de ambos kits.
- **Adjuntos al ledger:**
  - `junit.mjs` extrae `[[ATTACHMENT|…]]`.
  - La evidencia `test` gana `attachments: [{path, sha256, bytes, kind}]`.
  - `accept record` acepta `--attach`.
  - Los adjuntos de tests van a `.sdd/evidence/` (git-ignored). Los de decisiones humanas van a `acceptance/evidence/`,
    versionados, solo imágenes y con límite de tamaño.
  - Nunca se versionan traces de Playwright, que contienen cookies y storage.
  - **Decisión (sección 6):** en un REQ-F, un criterio sin captura o vídeo no cuenta como cumplido.
  - El MCP no se rompe: trata `evidence` como `Record<string, unknown>`.

### M4 — Replay y carrera

**Hoy.**
- Mode 2 enumera exactamente EP, BVA, tabla de decisión y transición (`sdd-test-planner/SKILL.md:258-266`).
- specifications-engineer pregunta por «concurrent conflict» (`SKILL.md:71`), pero no por la segunda ejecución idéntica,
  y un «no» no deja rastro.
- spec-auditor menciona «duplicates, concurrent access» en CAT-03 como juicio. Puede estar fuera de la ruta.

**Solución (dos dueños, para no violar el Art. 12).**
- **specifications-engineer es el dueño del comportamiento.** Nueva pregunta 6 en Step 6a: «¿qué pasa si la misma
  escritura se ejecuta otra vez con la misma entrada? ¿qué se conserva?». Cada «sí» produce su `AC-NNN-NN`.
  - En la ruta sin specs, requirements-engineer añade un AC de replay a todo requisito que escribe estado.
- **test-planner es el dueño de la derivación.** Técnica «e. Replay and race» en Mode 2 y tipos `replay · race` en la
  matriz. Las filas siguen siendo `T0N` y citan el AC de replay.
  - Sin escenario que defina el resultado, la fila se escribe con `Refs: —` y abre un hallazgo para spec-auditor en vez
    de inventar la semántica.
- spec-auditor: toda operación con efecto de escritura sin fila E de replay → silencio peligroso.
- task-generator y implementer: una línea cada uno. Las filas `race` se prueban con dos promesas concurrentes sobre la
  misma fixture, sin sleeps.

### M5 — Smoke post-deploy

**Hoy.**
- `templates/ci/github/sdd.yml` solo hace `verify`, `lint`, `lint --plan` y `gate --mode warn`. No ejecuta ni los tests.
  La plantilla de GitLab es igual.
- El Stack Profile solo tiene claves locales: no hay `deploy`, `staging_url` ni `smoke`.
- FASE-0 se demuestra «from a clean checkout», nunca desplegada.
- El tier «Smoke» de `e2e-template.md` es un smoke de PR.
- Tech-designer marca «no staging» como red flag, pero no pide config por entorno ni verificación tras el deploy.
- Ningún eslabón habría expresado «credenciales como JSON en variable» ni «cron detrás del basic auth de Traefik».

**Solución (mínimo viable: capas 1-4).**
1. **Plantillas CI nuevas** `sdd-smoke.yml` y `sdd-smoke.gitlab-ci.yml`, separadas del check de PR.
   - GitHub con `workflow_run` o `workflow_call`.
   - GitLab con `needs: deploy:staging`.
   - `SMOKE_BASE_URL` desde variables; secretos del usuario de smoke; JUnit como artifact; el job falla si falla el smoke.
   - `sdd-setup` las copia sin tocar el workflow de deploy del proyecto e imprime la línea que el humano debe añadir.
2. **Stack Profile:** claves `staging_url`, `smoke`, `smoke_report_path` y `env_required` (solo nombres), más `deploy`
   como dato informativo.
3. **test-planner:** 2-3 escenarios `@smoke` con tier `smoke-deploy`:
   - login real;
   - la escritura central;
   - un camino que toque cada integración externa.

   Solo datos idempotentes.
4. **tech-designer:** preguntas DIM-7 «config por entorno» (forma de credenciales, proxy o auth delante de endpoints de
   máquina) y DIM-8 «verificación post-deploy», ambas candidatas a ADR. Esto es lo que habría obligado a escribir los dos
   bugs del caso real.
5. **Opt-in:**
   - un REQ-C de operabilidad con `Verification: test`, cuyos tests `@smoke` entran al ledger por id;
   - un criterio opcional «desplegado y smoke verde» en FASE-0 cuando hay staging.

**Límite con Known Gaps (Ch05).** El plugin verifica que el incremento desplegado cumple los requisitos. No hace
monitorización, synthetic checks programados ni rollback.

### M6 — Letra literal en el test

**Hoy.** La letra solo vive en `REQUIREMENTS.md`, y por diseño ningún eslabón la copia (W1 «one home per fact»). El
problema es que el implementer tampoco vuelve a la fuente:

| Eslabón | Qué lleva del criterio |
|---------|------------------------|
| REQUIREMENTS.md | Letra literal con ejemplo |
| BDD `spec/tests` | Resumen propio de ≤ 6 líneas más la etiqueta `[REQ-X ACn]` |
| FASE | Una línea de ≤ 140 caracteres e ids |
| Tarea | Id más una paráfrasis del generador |
| Implementer | Lee tarea, BDD y UC; nunca REQUIREMENTS |
| Test | Id en el nombre; el cuerpo es la interpretación del autor |
| Ledger | Solo el id |

**Solución.**
- **No copiar el AC en la tarea.** Rompe W1, cuesta miles de tokens en una FASE grande y crea una copia que un MODIFY
  deja desactualizada. El eslabón que arrastra la letra es el test.
- **`tdd-workflow.md`:** sección «The criterion's letter sits above its assert».
  - Cita literal del criterio, en su idioma, abierta por id desde `REQUIREMENTS.md`.
  - Si es largo, se elide el GIVEN/WHEN, pero nunca un literal.
  - Todo literal de la cita debe aparecer en el assert. Si no puede, se registra un `SPEC-DEVIATION`.
- **Implementer:** Phase 0 y el prompt de subagente leen las secciones de `REQUIREMENTS.md` de los REQ que cita la tarea.
  Para abaratarlo, un comando nuevo `sdd req show REQ-F-081 [--ac 1]` (coste S).
- **Review checklist:** «from FASE file» pasa a «from requirements/REQUIREMENTS.md», más un ítem Universal de cita.
- **Lint opcional `sdd lint --quotes`** (aviso, nunca veredicto):
  - Q-01: sin cita.
  - Q-02: la cita no es subcadena del criterio actual (desactualizada tras un MODIFY).
  - Q-03: un literal entrecomillado del criterio no aparece en el fichero de test. Es el que habría cazado
    «Proyectos personales».
- **Fuera del implementer:** extender W8 de specifications-engineer para que un Then conserve literales visibles
  (etiquetas, títulos, fuentes), no solo mensajes de error.

### M7.1 — Orden commit → evidencia

**Hoy.**
- La evidencia sí se ancla: un JUnit capturado con código sucio o antes del último commit de código sale stale, y
  `gate` da 2. Hay tests que lo cubren.
- Lo que falla son los bugs 1 y 3 de la sección 1.
- Phase 9 del implementer captura sin comprobar el árbol y sin `--junit-sha`, así que la frescura cae a la comparación
  de fechas.

**Solución.**
- **CLI:**
  - `accept --junit-sha` con código sucio → exit 2 («commit first»).
  - Sin `--junit-sha` → aviso por stderr.
  - `accept record demo|measurement|inspection|fase-acceptance` y `accept measure` con código sucio → exit 2, salvo
    `--allow-dirty`, que queda grabado como `dirty: true` en el registro.
  - `waiver` queda exento.
- **Phase 9, paso 4.0:**
  1. `git status --porcelain --untracked-files=all` vacío sobre code y test paths;
  2. `SHA=$(git rev-parse HEAD)`;
  3. `{test_report}`;
  4. `sdd accept --junit-sha "$SHA"`.

  Un FAIL arreglado dentro de Phase 9 exige commit y volver a capturar.
- **verification-protocol:** CHECK-C13 «evidence anchored».
- `sdd-acceptance` Step 1 cambia de «preguntar» a «la CLI rechaza».
- Opcional (M): `sdd accept --run-tests`, que comprueba el árbol, ejecuta `test_report` y fija `junitSha` él mismo.

### M7.2 — Recursos de la máquina

**Hoy.**
- El implementer lanza hasta 4 agentes por lote (`SKILL.md:245`). El prompt ya limita a `{test_file}`, pero no limita
  cuántos corren a la vez.
- Phase 9-S corre `{test}` completo en cada worktree.
- Las estaciones `impl-*` de multisesión corren en paralelo sin tope.

**Solución.**
- **Clave nueva del Stack Profile:** `test_slots: <n>`, con 2 por defecto y 1 para bases de datos en memoria, navegadores
  o contenedores.
- **Prompt de subagente:** tests de uno en uno con `{test_file}`; nunca `{test}`, `{acceptance}` sin `--grep`,
  `{coverage}` ni modo watch; no levantar servidores ni bases de datos fuera del runner.
- **Hilo principal:** un lote `[P]` lanza como mucho `test_slots` agentes que ejecutan tests. Con `test_slots: 1`, los
  agentes escriben en paralelo y el hilo principal ejecuta sus tests en secuencia.
- **E2E:** `workers: 1` en local con `test_slots: 1`.
- **`docs/multisesion.md`:** sección «Recursos de la máquina». El lead pregunta antes de despachar una segunda estación
  de implementación en la misma máquina.

## 3. Decisiones compartidas entre mejoras

Varias mejoras tocan el mismo contrato. Conviene decidirlas una vez:

| Tema | Mejoras | Propuesta unificada |
|------|---------|---------------------|
| Filtro `Source:` de Mode 6 | M1, loop actual | Aceptar `CASCADE-*`, `ACCEPTANCE-*`, `FEEDBACK-FASE-*` (bug 2) |
| Marcador «VE X» | M3 (planner y generator) | Lo fija requirements-engineer en el THEN; test-planner lo propaga; el generador no usa regex propia |
| Adjuntos al ledger | M3, M5, M1 | Un solo esquema `attachments[]`; obligatorio en REQ-F para el VERIFIED (sección 6) |
| Límite de concurrencia | M1, M7.2 | Los verificadores adversariales respetan `test_slots` |
| Literales visibles | M3, M6, W8 | La cita en el test (M6) más W8 extendido, más Q-03 como aviso |
| Árbol limpio antes de capturar | M7.1, M5, M1 | Misma regla en CLI; el smoke de staging se ancla al SHA desplegado |

Después de tocar estos contratos hay que ejecutar `sdd-cross-auditor` y actualizar CLAUDE.md, la tabla de §9 de
cascade-patterns y `docs/aceptacion.md`.

## 4. Orden de implementación recomendado

El orden cambia respecto al del documento original. Primero van los bugs y las bases que otras mejoras necesitan.

| Paso | Qué | Coste | Por qué en este orden |
|------|-----|-------|------------------------|
| 1 | Bugs 1-3 (untracked, filtro de Mode 6, `record` con árbol sucio) | S | Son defectos actuales; M1 depende del 2 |
| 2 | M7.1 (CLI y Phase 9) y M7.2 (`test_slots`) | S | Base de evidencia fiable y de concurrencia segura para M1 |
| 3 | M6 (texto y `sdd req show`) | S | La convención más barata; alimenta a M1 y a Q-03 |
| 4 | M4 y M3 en su parte de texto (planner, specs, generator, kits) | S | Solo prompts y plantillas |
| 5 | M5 capas 1-4 | M | Independiente; la mayor ganancia en producción |
| 6 | M3 adjuntos y M2 contract-test | M | Tocan parser, ledger y plan |
| 7 | M1 ronda adversarial | M | Reutiliza todo lo anterior |
| 8 | Lints opcionales (`--quotes`, V-21, filas replay) | M | Solo avisos, cuando la convención ya esté asentada |

## 5. Preguntas abiertas para decidir

1. **M1:** ¿puerta `warn` o `enforce` por defecto en 5.1? ¿Se contraverifica también una muestra de veredictos limpios?
   ¿`challenges.jsonl` versionado o en `.sdd/`?
2. **M3:** ¿marcador explícito en el requisito o basta el léxico? (La obligatoriedad de la captura ya está decidida:
   sección 6.)
3. **M4:** ¿replay en toda escritura o solo en las no idempotentes por naturaleza, con exención justificada?
4. **M5:** ¿`workflow_run` o `workflow_call` en GitHub? ¿La evidencia de staging cuenta para el sign-off? ¿El REQ-C de
   operabilidad es Must por defecto cuando hay staging?
5. **M7.1:** sin `--junit-sha` y con árbol sucio, ¿error o aviso? ¿`fase-acceptance` debe caducar por cambios de código?
6. **M7.2:** ¿`test_slots` como convención documental (S) o con un lock real por máquina (L)?
7. **M2:** ¿se exige `CONTRACT-` también para puertos internos (repositorio en memoria frente a Prisma)?

## 6. Decisiones tomadas tras el análisis

### 6.1 Jev en la ronda adversarial: filtro previo, nunca juez ni puerta

Jev no puede tomar la decisión del gate adversarial, por tres razones:

1. **La política del plugin lo prohíbe.** `docs/jev.md:69` excluye expresamente veredictos, exenciones, firmas, la parada
   del bucle y cualquier cosa en CI.
2. **No es el tipo de tarea que Jev resuelve.** Jev juzga un estado de texto de hasta ~32k tokens con preguntas
   estrechas. La ronda adversarial necesita recorrer el código: seguir callers, buscar la otra ruta que esquiva la
   implementación y comparar el mock con el provider real en varios ficheros. El propio `docs/jev.md:60` advierte que
   una puntuación baja de `implements` nunca prueba ausencia.
3. **No ve imágenes ni vídeo**, así que no puede juzgar la evidencia visual de 6.2.

Donde sí aporta es en la **pre-pasada barata sobre todo el universo**:
- ejecutar `test-adequacy` (`asserts_then`, `exercises_when`) sobre **todos** los criterios ligados, no solo sobre los
  Must VERIFIED, como hace hoy;
- ordenar por probabilidad baja qué criterios revisan primero los verificadores;
- elegir con ella la muestra de veredictos limpios que se contraverifica, que resuelve la pregunta abierta 1 de M1.

Reparto final de responsabilidades:

| Paso | Quién |
|------|-------|
| Priorizar criterios y elegir la muestra de limpios | Jev (o el LLM si Jev está apagado) |
| Verificar y contraverificar | Agentes Claude en contexto limpio, que sí leen capturas de pantalla |
| Registrar hallazgos y calcular la puerta | La CLI, de forma determinista (`challenges.jsonl`, `sdd gate`) |
| Descartar un hallazgo | Una persona (`challenge-dismissal`) |

### 6.2 Evidencia visual obligatoria en los requisitos funcionales

**Decisión del equipo:** un requisito funcional sin captura o vídeo no está hecho, porque no se le puede mostrar al
cliente que está terminado. Pasa de «adjunto informativo» a **condición del VERIFIED**.

**Regla.**
- Todo criterio de un `REQ-F` necesita, además de su test en verde y fresco, al menos una evidencia visual
  (imagen o vídeo) ligada a ese criterio.
- Sin ella, el criterio queda en un estado nuevo `unshown` y el requisito no pasa a VERIFIED.
- Aplica también a los `REQ-F` verificados por `demo`: el registro humano lleva `--attach` con la grabación o las capturas.
- No aplica a `REQ-NF` ni a `REQ-C`, que siguen con test, medición o inspección.

**Cambios en la CLI.**
- `acceptance.mjs`, en el cálculo por criterio (hacia la línea 366): si el requisito es `REQ-F` y el criterio está en
  `pass` sin ningún adjunto `image` o `video` presente y fresco, el estado pasa a `unshown`.
- El veredicto del requisito queda en `MISSING`, con `reason: "no visual evidence"`, y la métrica nueva
  `summary.unshown` indica cuántos.
- `sdd gate` sale con 1 (objetivo no cumplido). `sdd loop next` devuelve el target con la ruta nueva `capture-evidence`,
  que no genera tarea de código: solo vuelve a ejecutar el journey con captura.
- Cada adjunto guarda `sha256` y `present`. Si el fichero ya no existe cuando se evalúa, cuenta como ausente.
- Clave del Stack Profile `visual_evidence: required|warn|off`, con `required` por defecto. `off` solo para proyectos
  sin interfaz (API pura, CLI), como decisión explícita de una persona.

**De dónde sale la evidencia.**
- **Tests E2E:** Playwright con `screenshot: 'on'` y `video: 'on'` en la suite de aceptación, con `outputDir` apuntando a
  `evidencias/FASE-{N}/`. Hoy
  `construction-protocol.md:410` tiene `only-on-failure`, que no sirve. `junit.mjs` extrae los `[[ATTACHMENT|…]]` y los
  liga a los criterios del nombre del test. Un vídeo de un journey cubre todos los criterios cuyos ids lleva el test.
- **Demos humanas:** `accept record demo --attach <fichero>`.
- **REQ-F sin pantalla propia** (un cron, un webhook): la captura muestra el efecto donde el cliente lo ve, por ejemplo
  la pantalla de administración o el correo recibido. Si no existe ningún sitio visible, esa es una pregunta para el
  requisito, no una exención silenciosa.

**Qué se captura (decisión del equipo).**
- **Una captura por criterio** de cada REQ-F, sin excepción. Es la condición del VERIFIED de ese criterio.
- **Un vídeo por workflow** (`WF-NNN`) que recorre el flujo completo. En la ruta sin especificaciones no hay `WF-NNN`, así
  que el vídeo es por FASE: su journey, que es el mismo recorrido del `## Demo`.
- **Si un resultado no tiene pantalla propia**, la captura muestra la pantalla donde el efecto se ve: el panel de
  administración con el registro creado, el correo recibido, el PDF descargado abierto. No hay exención por «no tiene UI».

**Dónde se guarda (decisión del equipo): en el propio proyecto, fuera de git.**
- La carpeta es `evidencias/` en la raíz del proyecto, **no dentro de `spec/`**, por cuatro motivos comprobados:
  1. `sdd-upstream-guard.sh` deniega al implementer escribir en `spec/`.
  2. `sdd-pipeline-state-updater.sh:102` marca `specifications-engineer` como running ante cualquier escritura en `spec/`.
     Un cambio en `spec/` además vuelve stale todo lo que va desde spec-auditor.
  3. En Rails, `spec/` es la carpeta de RSpec (`sdd-pipeline-state-updater.sh:134`).
  4. En la ruta sin especificaciones, `spec/` no existe.
- `evidencias/` se añade al bloque gestionado de `templates/gitignore.sdd`, así que `sdd-setup` la ignora en todos los
  proyectos.
- Estructura:

  ```
  evidencias/FASE-{N}/WF-{NNN}.webm
  evidencias/FASE-{N}/{AC-NNN-NN | REQ-F-NNN-ACn}.png
  ```

- El ledger guarda por adjunto la ruta, el `sha256`, el tamaño y el `evaluated_sha`. Git no guarda el fichero, pero el
  ledger sí guarda su huella: si alguien lo sustituye o lo borra, la CLI lo detecta y el criterio vuelve a `unshown`.
- Los traces de Playwright no se copian a `evidencias/`, porque contienen cookies y storage.

**Consecuencias de no versionarla.**
- La evidencia solo existe en la máquina que ejecutó el journey. En otra máquina o en CI, `sdd gate` vería los adjuntos
  como ausentes. El gate que cuenta para la entrega es el local de quien presenta al cliente. En CI el gate sigue en
  `warn` (como hoy en `templates/ci/github/sdd.yml`) y la comprobación visual se informa como «no disponible en esta
  máquina» en vez de fallar.
- Para no perderla tras la firma, `sdd accept --sign-off` empaqueta `evidencias/FASE-{N}/` en un zip con el manifiesto
  de hashes. El equipo lo entrega al cliente o lo guarda donde decida. La página de estado (`--publish`) enseña las
  capturas y los vídeos como assets del artifact. Hay que actualizar `status-page.md:22`, que hoy prohíbe el contenido
  de ficheros.

**Quién comprueba que la captura muestra lo pedido.**
- La presencia la comprueba la CLI.
- El contenido lo comprueban los verificadores adversariales, que pueden leer imágenes y cotejarlas con la letra del
  criterio (M6), y en último término el cliente en el gate de FASE.
- Jev no interviene.

**Aguas abajo.**
- test-planner: todo criterio de REQ-F tiene un escenario E2E que lo captura. Esto generaliza la regla «VE X» de M3 a
  todos los funcionales.
- implementer: la configuración de Playwright y el ejemplo de `tdd-workflow.md`.
- Kits: `rules/testing.md` de ambos.
- `docs/aceptacion.md`, `cascade-patterns` §9 (métrica `unshown`), tipos de `server/src/acceptance.ts` y
  `sdd-cross-auditor`.

**Migración.** En un proyecto 5.0 con requisitos ya VERIFIED, todos los REQ-F pasarían a `unshown` al actualizar. El
cambio necesita:
- una nota en el CHANGELOG;
- que `sdd-setup` pregunte al actualizar;
- una ejecución del journey con captura antes del siguiente gate.

**Coste:** M-L. Afecta a la CLI, al parser, al ledger, a la página de estado, a tres skills, a los kits y a sus tests.
Se implementa junto a M3 y adelanta al paso 5 del orden del apartado 4.

**Decisiones cerradas:** almacenamiento local en `evidencias/` fuera de git, un vídeo por workflow, una captura por
criterio, y la pantalla del resultado cuando no hay pantalla propia.
