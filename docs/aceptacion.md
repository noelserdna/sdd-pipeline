# Aceptación por requisito

La pregunta que el resto del pipeline no responde: **¿está satisfecho cada requisito, y con qué evidencia?** La aceptación cierra la cadena `N → REQ → UC → BDD/AC → TASK → COMMIT → CODE → TEST` con un veredicto por requisito, y registra como hechos (no como frases de un chat) las decisiones de las personas: exenciones, demos observadas, mediciones, inspecciones y la aceptación de cada FASE por el cliente.

Hay dos piezas:

- **La CLI decide.** `sdd accept`, `sdd gate` y `sdd loop next` (en `scripts/sdd.mjs`, Node ≥ 18 sin dependencias) calculan veredictos, frescura, el código de salida de la puerta y la parada del bucle. Dos ejecuciones sobre el mismo commit dan la misma respuesta, y el CI la comprueba solo con Node y git.
- **La skill `sdd-acceptance` reúne evidencia, enruta el trabajo y pregunta a las personas.** Nunca calcula un veredicto por su cuenta.

## De dónde sale la evidencia

Cada requisito declara en `REQUIREMENTS.md` cómo se verifica (`Verification:`), y cada criterio de aceptación tiene un escenario BDD con ID `AC-NNN-NN` en `spec/tests/BDD-UC-*.md`. Si la ruta adaptativa saltó las specs ([ruta.md](ruta.md)), no hay escenarios: el criterio es el contrato y el test lleva `REQ-X-NNN ACn` en el nombre.

| Método | Evidencia válida | Cómo se obtiene |
|---|---|---|
| `test` | Un caso JUnit que pasa y cuyo nombre contiene el ID del escenario (`AC-001-03`, o `REQ-X-NNN ACn` para un requisito sin escenario BDD) | El comando `test_report` del Stack Profile escribe JUnit XML en `.sdd/junit/` |
| `demo` | Salida observada que una persona confirmó | `sdd accept record demo` |
| `measurement` | Un valor registrado que la CLI compara con su umbral | Métricas objetivas (cobertura, un benchmark): `sdd accept measure --command … --extract …`, que ejecuta el comando y se vuelve a medir sola con `sdd accept --remeasure`. Valores que confirma una persona: `sdd accept record measurement` |
| `inspection` | Una revisión humana registrada | `sdd accept record inspection` |

**Restricciones comprobables por código.** Una restricción (`REQ-C`) cuyo cumplimiento puede leer un test (lista de dependencias, fronteras de importación, versión del runtime, APIs prohibidas) declara `Verification: test`, con un test estático llamado `REQ-C-NNN AC1 …` (una restricción tiene un único criterio implícito, AC1). Ese test corre en cada commit y no caduca; una inspección es un registro humano que caduca cada vez que cambian los ficheros que nombra. `inspection` queda para restricciones de proceso, legales u organizativas, o para lo que ningún test puede observar. En la ejecución real de todo-app, 8 tests estáticos en verde no contaban porque las dos restricciones decían `inspection`.

Por eso los tests llevan en el nombre el ID de su escenario (lo exigen `sdd-test-planner` y el TDD del implementer). Los `Refs:` a nivel de fichero **no** cuentan como evidencia: atan un fichero entero a un requisito y darían VERIFIED falsos. Lectores JUnit probados: vitest, jest, pytest, rspec, playwright, minitest y mocha. La tabla de comandos por runner está en `skills/sdd-acceptance/references/test-report.md`.

## Veredictos

| Veredicto | Regla (la primera que se cumple) |
|---|---|
| DEPRECATED | Requisito deprecado: se lista aparte y nunca bloquea |
| WAIVED | Exención humana vigente para el texto actual del requisito. Un Must exento exige motivo, rol e issue de seguimiento, y hace que la puerta salga con 3 |
| FAILING | Alguna evidencia fresca falla |
| MISSING | Algún criterio sin evidencia fresca (no implementado, sin test, o el test no lleva el ID del escenario), un criterio de un `REQ-F` que pasa sin captura (`unshown`, ver [Evidencia visual](#evidencia-visual)) o un criterio de un Must cuyo test no lleva su letra (`weakened`, ver [Letra literal](#letra-literal)) |
| VERIFIED | Cada criterio tiene evidencia válida de su método. El informe dice cuántos ("3/5") y de qué tipo |

**Frescura.** La evidencia vieja no cuenta:

- "Código" son los `code_paths` y `test_paths` del Stack Profile (por defecto `src` y `tests`, los que existan; si no existe ninguno, todo salvo `acceptance/` y `.sdd/`). Un commit de documentación, `feedback/`, specs o `acceptance/` no envejece la evidencia. Una configuración de build o de tests fuera de esas rutas (`package.json`, `vitest.config.ts`) solo cuenta si se añade a `code_paths`.
- Los resultados de tests valen mientras el código no haya cambiado desde que se capturaron, ni en commits ni en cambios sin commitear, incluidos los ficheros nuevos sin `git add` (`untracked_paths` en el libro). `--junit-sha` lo afirma y la CLI lo comprueba (ver [Orden de captura](#orden-de-captura)); sin él se comparan fechas.
- Cada registro sigue valiendo mientras no cambien los ficheros que nombra (`--paths`), o el código si no nombra ninguno, desde su commit.
- Una medición registrada con `sdd accept measure` guarda su comando: cuando caduca, `sdd accept --remeasure` la vuelve a ejecutar y añade el valor nuevo (nunca sin el flag). Una medición humana caducada vuelve a pedir a una persona.
- Los registros llevan el hash del enunciado y los criterios del requisito. Un MODIFY de `sdd-req-change` cambia el hash y reabre el requisito ("Decisiones a reconfirmar" en el informe).

## Evidencia visual

Un requisito funcional está hecho cuando se le puede **enseñar** al cliente. Por eso, con `visual_evidence: required` en el Stack Profile (el valor por defecto), cada criterio de un `REQ-F` necesita, además de su test en verde y fresco, una imagen ligada a ese criterio.

| Qué | Dónde | Quién la produce |
|---|---|---|
| Una captura por criterio | `evidencias/FASE-{N}/{AC-NNN-NN \| REQ-F-NNN-ACn}.png` (también `.jpg`) | El test E2E de la suite de aceptación (Playwright con `screenshot: 'on'`), que la adjunta con `testInfo.attach`; el JUnit la lleva como `[[ATTACHMENT\|ruta]]`. Con un runner que no escribe adjuntos (Minitest), la imagen se liga por el id de su nombre |
| Un vídeo por workflow de cara al usuario | bajo `evidencias/FASE-{N}/`, con el `WF-NNN` en el nombre (`.webm` o `.mp4`); cuando la FASE no nombra workflows, uno con `FASE-N` en el nombre, el recorrido del `## Demo` | El journey de la FASE (`video: 'on'`), cuyo título lleva el id; o una grabación manual de la demo con el id en el nombre |
| Capturas o grabación de una demo humana | bajo `evidencias/` | `sdd accept record demo … --attach F…` |

- Sin imagen, el criterio queda **`unshown`** y el requisito `MISSING` con `reason: "no visual evidence"`; el resumen lo cuenta en `summary.unshown`. Con `warn` solo se informa; con `off` (sin interfaz: una API o una CLI, decidido por una persona) no se comprueba. No aplica a `REQ-NF` ni a `REQ-C`.
- Un resultado sin pantalla propia (un cron, un webhook) se captura donde el cliente lo ve: el panel de administración, el correo recibido, el PDF abierto. Si no se ve en ningún sitio, es una pregunta sobre el requisito, no una exención.
- `sdd gate --fase N` exige un vídeo cuyo nombre contenga cada `WF-NNN` de la línea de cabecera `> **Workflows:** WF-…` del fichero de la FASE (la escribe `sdd-plan-architect` con los workflows de cara al usuario); sin esa línea, los `WF-NNN` citados en su `## Demo`; y si no hay ninguno, `FASE-N`. Cuenta cualquier vídeo bajo `evidence_dir` con el id en el nombre, incluida una grabación manual de la demo. Lo que falta sale en `missing_videos` y la puerta da 1; `sdd loop next` emite por cada uno un target `{video, fase, route_hint: "capture-evidence"}` y lo cuenta en `progress.videos_missing` (con `visual_evidence: warn` esos targets van a `others`).
- `evidencias/` (clave `evidence_dir`) está **fuera de git**, en el bloque gestionado de `.gitignore`. El libro guarda por adjunto la ruta, el `sha256`, el tamaño y si está presente: si alguien sustituye o borra un fichero, la CLI lo ve y el criterio vuelve a `unshown`. La consecuencia es que la evidencia solo existe en la máquina que ejecutó el journey; en CI la puerta sigue en `warn` y la comprobación visual se informa como no disponible.
- Los traces de Playwright nunca se adjuntan ni se copian a `evidencias/`: contienen cookies y storage.
- Tras aceptar una FASE, `sdd accept pack --fase N` empaqueta `evidencias/FASE-N/` y un `manifest.json` (ruta, sha256, bytes, criterio, `evaluated_sha`) en `.sdd/entregas/FASE-N-evidencias.tar.gz`. El equipo decide dónde entregarlo o guardarlo.
- La presencia la comprueba la CLI. Que la captura muestre de verdad el literal del criterio lo comprueban los verificadores de la [ronda adversarial](#ronda-adversarial) y, al final, el cliente en la puerta de FASE, que ve el vídeo y las capturas. Jev no ve imágenes.

## Letra literal

El caso que la motivó: el requisito pedía «Proyectos personales», el test asertaba «Proyectos» y la trazabilidad por id lo dio por VERIFIED. Cada eslabón (BDD, FASE, tarea) parafrasea el criterio; el test es el que lleva la letra al código, con la cita encima del assert (`// REQ-F-081 AC1: "…"`, sacada de `sdd req show`). `sdd lint --quotes` lo comprueba sin modelo:

- **Pares.** Un fichero fuente bajo `test_paths` (por defecto `tests`) nombra un criterio cuando su código, sin comentarios, lleva `REQ-X-NNN ACn` o un id de escenario `AC-NNN-NN` que una etiqueta BDD de `spec/tests/BDD-*.md` liga a `[REQ-X-NNN ACn]`. Cada par (criterio, fichero) se comprueba.
- **Q-01 (aviso):** el fichero no tiene la cita `REQ-X-NNN ACn: "…"` en un comentario.
- **Q-02 (error):** la cita no es el texto actual del criterio. Se normalizan espacios y tipos de comilla (`' " « » “ ” ‘ ’` y el acento grave); las mayúsculas no. `…` elide: cada trozo entre elipsis debe estar en el criterio, en orden. Así se ve una cita inventada o una que un MODIFY dejó atrás.
- **Q-03 (error):** un literal del criterio no aparece en el código del test fuera de los comentarios (la cita no cuenta), con la misma normalización.
- **Qué es un literal:** el texto entre `"…"`, `'…'`, `«…»`, `“…”` o `‘…’` en cualquier parte del criterio (un apóstrofo como en *user's* no abre comilla), y el texto entre acentos graves **solo a partir del THEN/ENTONCES**, donde es una salida o un mensaje esperado (`` `No tasks` ``). Un fragmento entre acentos graves antes del THEN es el comando o la ruta que el test ejecuta (`` `todo add "Buy milk"` ``, `` `/projects` ``); lo construye un helper, así que no se exige literal, y tampoco las comillas que lleva dentro. Los literales vacíos (`""`) se ignoran.
- Salida `fichero:línea Q-0N REQ-X-NNN ACn mensaje` y un resumen; `--json` da `{findings: [{code, severity, req, ac, file, line, literal?, quote?, exception?, message}], summary}`. Sale con 1 si hay algún error no exceptuado. `--fase N` limita a los requisitos de la FASE.

**En el libro.** `sdd accept` añade por criterio `literal_gaps` (los Q-02/Q-03 no exceptuados, con fichero y línea) y los cuenta en `summary.literal_gaps`. La clave del Stack Profile `literal_gate` decide qué pasa:

| `literal_gate` | Efecto |
|---|---|
| `enforce` (por defecto) | Un criterio de un **Must** que pasa con un hueco queda **`weakened`**; el requisito no es VERIFIED (`MISSING`, `reason: "test does not carry the criterion's literal"`) y `sdd gate` da 1. `sdd loop next` lo enruta como **`weakened-test`**, con los huecos en el target |
| `warn` | Se informa en `sdd accept`, `sdd gate` y el informe; el estado no cambia |
| `off` | No se comprueba |

La ruta `weakened-test` es una edición de test: arreglar la cita y asertar el literal exacto. Si entonces el test falla, el defecto está en el código (`fix-code`). Como toda edición de test dentro del bucle, la aprueba una persona (Art. 12).

**Excepción humana.** Cuando un helper construye el literal y nunca aparece tal cual en el test, una persona lo registra: `sdd accept record literal-exception --req REQ-F-001 --ac 2 --literal "title must not be empty" --reason "msg() lo toma de i18n/es.json" --by … --role …`. El literal tiene que ser uno del criterio. El Q-03 pasa a `excepted` mientras el texto del requisito conserve su `reqHash`; tras un MODIFY la excepción caduca y sale en «Decisiones a reconfirmar». El tool guard pregunta antes de cualquier `accept record`.

## Orden de captura

La evidencia describe un commit, así que el orden es siempre **commit → evidencia → libro → commit `docs(acceptance)`**:

1. `git status --porcelain --untracked-files=all -- <code_paths> <test_paths>` vacío. Los ficheros sin versionar cuentan: un fichero nuevo del que dependen los tests no está en `HEAD`.
2. `SHA=$(git rev-parse HEAD)` y el comando `test_report` (y el journey con captura).
3. `sdd accept --junit-sha "$SHA" --report acceptance/ACCEPTANCE-REPORT.md`.
4. Commit del informe (`docs(acceptance): …`), que no toca código y por eso no envejece la evidencia.

La CLI no pregunta: rechaza.

- `sdd accept --junit-sha SHA` con código sucio → exit 2 («commit first»). Sin `--junit-sha` y con el árbol sucio, avisa por stderr y la evidencia cuenta como obsoleta.
- `sdd accept record …` (salvo `waiver`, `challenge-dismissal` y `literal-exception`, que no observan nada del código) y `sdd accept measure` con código sucio → exit 2. `--allow-dirty` lo permite y queda grabado como `dirty: true` en el registro.
- Un FAIL arreglado después de capturar es código nuevo: commit y volver al paso 1.

## Ronda adversarial

Un test ligado por nombre y en verde prueba que *una* aserción se cumplió, no que se cumpla la letra del requisito. En la retro de 5.0 (35 requisitos trazados, 344 tests en verde) tres rondas de verificación independiente encontraron 12 huecos reales: asserts que codificaban una versión debilitada del criterio, mocks que el provider real no cumplía, piezas construidas que ningún flujo montaba y caminos que esquivaban la implementación. `sdd-acceptance --adversarial [--fase N]` hace esa verificación como parte del pipeline, después del implementer y antes de enseñar la FASE al cliente (el orquestador la lanza sin preguntar).

1. **Crítico de cobertura mecánico:** `sdd accept adversarial plan [--fase N] --json` lista por FASE los requisitos (con su texto literal), sus criterios, los tests ligados y los ficheros candidatos, y además los requisitos activos fuera de toda FASE (`uncovered`), las FASEs sin cabecera y los criterios sin test.
2. **Prioridad:** Jev (`test-adequacy` sobre todos los criterios con test) o el LLM ordenan qué se mira primero y eligen la muestra de veredictos limpios que se contraverifica. Nunca marcan nada como limpio.
3. **Un verificador por FASE**, un agente en contexto limpio y de solo lectura, con cuatro reglas: no citar `acceptance/`, `feedback/` ni `spec/` como evidencia (solo código de producción y tests); releer la letra completa del requisito (`sdd req show`); comprobar que los asserts codifican el criterio de verdad; y buscar el camino de producción que esquiva la implementación. Además lee las capturas de `evidencias/` y comprueba que muestran el literal. Se lanzan como mucho `test_slots` a la vez, con los tests de uno en uno.
4. **Contraverificación** de todos los hallazgos y de una muestra de limpios, por agentes nuevos que no ven el razonamiento del primero: `confirmed`, `refuted` o `inconclusive` (este último lo decide una persona).
5. **Crítico de cobertura LLM:** confirma que el universo evaluado está completo.
6. **Registro:** `sdd accept challenge add` escribe cada hallazgo confirmado o no concluyente en `acceptance/challenges.jsonl`. La CLI rechaza (exit 2) la evidencia bajo `acceptance/`, `feedback/`, `spec/`, `requirements/`, `plan/`, `task/`, `audits/`, `changes/` o `.sdd/`, y bajo `test/` cuando no está en los `test_paths` del perfil (en Rails los tests viven ahí). También rechaza un fichero citado sin commitear o una línea que no existe. Una captura de `evidencias/` se cita sin línea (`WRONG-CAPTURE`) y se guarda su sha256.

| Categoría | Qué encontró el verificador |
|---|---|
| `WEAKENED-ASSERT` | El test asserta una versión debilitada del criterio |
| `MOCK-ONLY` | Pasa contra un mock cuyo contrato el provider real no cumple |
| `UNWIRED` | La pieza existe y tiene test, pero ningún flujo del usuario la monta |
| `BYPASS-PATH` | Otra ruta, otro caller u otro punto de entrada esquiva el comportamiento |
| `CROSSING` | Falla con replay, concurrencia o una segunda ruta que ninguna tarea tenía |
| `NOT-IMPLEMENTED` | El comportamiento no está |
| `SPEC-QUESTION` | El criterio no se puede cumplir tal como está escrito: pregunta para una persona |
| `WRONG-CAPTURE` | La captura no muestra el literal del criterio |

**El veredicto no cambia.** El libro añade `challenges[]` por requisito (`open`, `stale` cuando cambia el código que citan o el texto del requisito, `dismissed`) y `summary.must_challenged`. El bucle devuelve los abiertos y confirmados con la ruta `adversarial-finding`, y los no concluyentes con la ruta `needs-human`, y genera tareas con `Source: ACCEPTANCE-ADVERSARIAL-FASE-{N}`; un `SPEC-QUESTION` va a `sdd-req-change`. Descartar un hallazgo es un registro humano: `sdd accept record challenge-dismissal --challenge CH-NNN --reason … --by … --role …`. Los verificadores no escriben código, specs, tests ni `decisions.jsonl`.

La puerta la fija `adversarial_gate` en el Stack Profile: `off` lo ignora, `warn` (por defecto en 5.1) lo imprime sin cambiar el código de salida, `enforce` sale con **4** si hay un challenge abierto en un Must. El protocolo completo está en `skills/sdd-acceptance/references/adversarial-protocol.md`.

## Salidas

| Fichero | Versionado | Qué contiene |
|---|---|---|
| `.sdd/acceptance.json` | No (ignorado) | El libro completo con `evaluated_sha`. Lo leen `sdd-pipeline-status`, el hook de inicio de sesión y el servidor MCP (`sdd_coverage`, `sdd_context`) |
| `acceptance/ACCEPTANCE-REPORT.md` | Sí | Informe legible por el cliente: primero los Must exentos, luego una fila por requisito con evidencia y necesidades, decisiones a reconfirmar y el SHA evaluado |
| `acceptance/decisions.jsonl` | Sí | Solo hechos humanos: exenciones, demos, mediciones, inspecciones, aceptaciones de FASE y descartes de challenges, con quién, rol, commit y hash del texto |
| `acceptance/challenges.jsonl` | Sí | Hallazgos de la ronda adversarial: requisito, criterio, categoría, cita, evidencia `ruta:línea`, verificador, contraverificación, `HEAD` y hash del texto |
| `evidencias/FASE-N/` | No (ignorado) | Capturas y vídeos; el libro guarda su `sha256` |
| `.sdd/entregas/FASE-N-evidencias.tar.gz` | No (ignorado) | El paquete de evidencia de una FASE aceptada, con su manifiesto |

El informe, `decisions.jsonl` y `challenges.jsonl` los escribe solo la CLI. El upstream guard deniega editarlos a mano.

## Comandos

```bash
SDD="${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs"   # en CI: SDD=.claude/sdd/sdd.mjs

node "$SDD" accept --junit-sha "$(git rev-parse HEAD)" --report acceptance/ACCEPTANCE-REPORT.md [--fase N]
node "$SDD" gate [--mode off|warn|enforce] [--fase N] [--md]
node "$SDD" loop next [--reset] [--max-cycles 3]
node "$SDD" accept record waiver --req REQ-F-007 --reason "…" --follow-up '#31' --by "Ana Pérez" --role "Product owner"
node "$SDD" accept record demo --req REQ-F-002 --ac 1 --observed "…" --pass true --by … --role … [--paths src/cli] [--attach evidencias/FASE-1/demo.webm] [--allow-dirty]
node "$SDD" accept record measurement --req REQ-NF-001 --metric p95_ms --observed 84 --op le --threshold 100 --by … --role …
node "$SDD" accept measure --req REQ-NF-002 --metric statements --command "npx vitest run --coverage" --extract 'All files[^|]*\|\s*([0-9.]+)' --op ge --threshold 90
node "$SDD" accept --remeasure [--fase N]     # vuelve a ejecutar las mediciones por comando caducadas
node "$SDD" accept record fase-acceptance --fase 1 --result accepted|observations|rejected --channel "demo 2026-09-27" --by … --role …
node "$SDD" accept pack --fase 1              # evidencias/FASE-1/ + manifest.json → .sdd/entregas/FASE-1-evidencias.tar.gz
node "$SDD" req show REQ-F-004 [--ac 2] [--json]   # enunciado y criterios literales
node "$SDD" lint --quotes [--fase N] [--json]       # cita y literales de cada criterio en sus tests (Q-01..Q-03)
node "$SDD" accept record literal-exception --req REQ-F-004 --ac 2 --literal "…" --reason "…" --by … --role …
node "$SDD" accept adversarial plan [--fase N] [--json]
node "$SDD" accept challenge add --req REQ-F-004 --ac 2 --category WEAKENED-ASSERT --quote "…" --evidence src/x.ts:41 --verifier … --counter confirmed
node "$SDD" accept challenge list [--open] [--json]
node "$SDD" accept record challenge-dismissal --challenge CH-001 --reason "…" --by … --role …
```

### La puerta: `sdd gate`

| Salida | Significado |
|---|---|
| 0 | Objetivo cumplido: todo Must VERIFIED o WAIVED |
| 1 | No cumplido |
| 2 | Evidencia obsoleta (o error de uso) |
| 3 | Cumplido con Musts exentos |
| 4 | Challenge adversarial abierto en un Must, con `adversarial_gate: enforce` |

Si se cumplen varias condiciones sale la más grave: 2 > 1 > 4 > 3 > 0 (un challenge nunca oculta un requisito sin evidencia, y pesa más que una exención porque pone en duda un veredicto que cuenta como cumplido). Con `enforce`, un 4 impide `--sign-off` y la aceptación de la FASE hasta que el bucle lo arregla o una persona lo descarta (`challenge-dismissal`); con `warn` se muestra y el aprobador decide con él a la vista. Con `--fase N`, el 1 incluye también los vídeos que faltan (`missing_videos`). Modos: `enforce` falla con 1/2/3/4 tal cual; `warn` imprime y sale con 0; `off` sale con 0 en silencio. Por defecto se usa `acceptance_gate` del Stack Profile y, si no está, `enforce`. Al adoptar SDD en un proyecto existente conviene `warn`. `--fase N` limita la puerta a la línea `Requisitos:` de `plan/fases/FASE-N-*.md`, y `--md` imprime el bloque para el cuerpo de un PR.

## La skill `sdd-acceptance`

```
/sdd-acceptance --check                 # captura tests, libro + informe, integridad de la cadena (por defecto)
/sdd-acceptance --fase N                # lo mismo, limitado a la FASE N
/sdd-acceptance --adversarial [--fase N]  # ronda adversarial: verificadores independientes contra la letra
/sdd-acceptance --loop [--max-cycles 3] # bucle hasta que todo Must esté VERIFIED o WAIVED
/sdd-acceptance --sign-off [--fase N | --release NAME]
/sdd-acceptance --publish [--fase N]    # bloque de PR/issue y página de estado opcional
```

**`--check`** ejecuta `test_report` sobre el commit actual (con el árbol sucio se detiene: primero el commit, ver [Orden de captura](#orden-de-captura)), genera el libro y el informe, y revisa la **integridad de la cadena de IDs**: referencias rotas, definiciones huérfanas, requisitos sin caso de uso ni escenario, tareas hechas sin commit. Esta parte sustituye a la antigua skill `sdd-traceability-check` (`skills/sdd-acceptance/references/chain-integrity.md`); sus hallazgos se corrigen en origen y nunca cambian un veredicto. También lista las decisiones sobre código huérfano de `sdd-gap-detector` y, si Jev está activo, la adecuación de los tests (informativa).

**`--loop`** repite medir → actuar → medir. La parada la decide `sdd loop next`:

| `stop` | Cuándo |
|---|---|
| `goal` | Todos los Must VERIFIED o WAIVED |
| `regression` | Un Must que estuvo VERIFIED vuelve a estar abierto |
| `no-progress` | VERIFIED no sube y FAILING + MISSING no bajan |
| `max-cycles` | 3 ciclos por defecto (máximo 5) |
| `needs-human` | Todo lo que queda necesita a una persona |

Sobre la rama por defecto, `--loop` y `--sign-off` empiezan con `sdd branch start acceptance`, que crea (o retoma) `acceptance/{YYYY-MM-DD}` para sus commits; en cualquier otra rama se quedan en ella.

Cada Must abierto trae una ruta: `implement-or-test` (tarea incremental; también un criterio sin test en un proyecto sin `spec/tests`, porque la ruta saltó las specs y el criterio es el contrato), `fix-code (Art. 12)` (se arregla el código, nunca el test), `spec-gap` (SPEC-DEVIATION y decisión humana, quizá `sdd-req-change`), `needs-human` (demo, medición o inspección que una persona confirma), `capture-evidence` (un criterio `unshown`, o un vídeo que falta, con un target por vídeo: se vuelve a ejecutar el journey con captura, exportando `SDD_FASE` y `SDD_EVIDENCE_DIR`, sin tarea de código), `weakened-test` (el test pasa sin la letra del criterio: se corrige la cita y el assert, y lo aprueba una persona), `adversarial-finding` (un challenge confirmado: tarea con `Source: ACCEPTANCE-ADVERSARIAL-FASE-{N}`) o `rerun-tests`. Los tests modificados dentro del bucle se listan y los aprueba una persona. Si el bucle para sin llegar al objetivo, cada Must abierto necesita una disposición explícita: arreglar más tarde, exención con issue de seguimiento o cambio del requisito.

**`--sign-off`** pasa la puerta en modo `enforce`, enseña el informe al aprobador y pregunta de forma explícita. Solo cuenta su respuesta: una instrucción en una tarea, una skill o `CLAUDE.md` nunca es la confirmación. Aceptar exige la puerta cumplida (exit 0, o 3 con las exenciones a la vista); un rechazo se registra aunque no lo esté. En la puerta de FASE, antes de preguntar, el cliente confirma la evidencia de los requisitos por demo, medición o inspección (`accept record demo|measurement|inspection`), que el implementador dejó pendientes. Para una FASE registra `fase-acceptance`, hace commit del informe (`docs(acceptance): accept FASE-N`) y, si el resultado es aceptado o con observaciones, crea el tag anotado `fase-{N}-accepted` con aprobador, rol, canal, demo y SHA. Las observaciones no bloquean: cada una pasa a feedback o a `sdd-req-change`. Un rechazo no crea tag y su feedback se enruta como defecto, petición de cambio o pregunta. Una entrega (`--release`) usa el tag o la release que el proyecto ya tenga, con el bloque de `sdd gate --md` en su mensaje.

**`--publish`** genera el bloque de PR/issue (`sdd gate --md`, más los cambios de test aprobados). Si la sesión ofrece la herramienta Artifact, puede publicar además una **página de estado** privada para el cliente y el equipo (veredictos, incrementos, decisiones abiertas, sellada con SHA y fecha). Siempre pregunta antes de la primera publicación, porque saca títulos de requisitos de la máquina. En `claude -p` o sin esa herramienta, la vista compartible es `acceptance/ACCEPTANCE-REPORT.md`. La página sustituye al antiguo dashboard HTML.

## Salvaguardas contra la auto-aprobación accidental

- El tool guard devuelve `ask` antes de `sdd accept record` y antes de crear tags `fase-N-accepted` o `requirements-vN`.
- El upstream guard deniega Edit/Write sobre `acceptance/decisions.jsonl`, `acceptance/challenges.jsonl` y el informe.
- El Stop prompt de la skill comprueba que un bucle terminó en `goal` o dejó cada Must abierto con disposición humana.

Juntas evitan que un agente se apruebe a sí mismo por descuido. No son una garantía de seguridad: quien controla la máquina puede saltárselas.

## Jev (opcional e informativo)

Con `TYPESAFE_API_KEY`, `test-adequacy.json` pregunta si cada test afirma el THEN y ejecuta el WHEN de su criterio (por debajo de 0,5 se marca para revisión), y `evidence.json` puntúa si la salida de una demo muestra el THEN antes de que la persona la confirme. En la ronda adversarial, `test-adequacy` corre sobre todos los criterios con test solo para ordenar a los verificadores y elegir la muestra de limpios. Jev nunca decide un veredicto, una exención, una firma, la parada del bucle, la puerta adversarial ni nada que corra en CI, y no ve imágenes ni vídeo. Ver [jev.md](jev.md).

## En CI

```bash
node .claude/sdd/sdd.mjs verify --range "origin/$BASE..HEAD"
node .claude/sdd/sdd.mjs lint
node .claude/sdd/sdd.mjs gate --mode warn
```

Las plantillas de `templates/ci/{github,gitlab}/` (instaladas con `sdd-setup --tracker`) ejecutan estos pasos. Ver [git.md](git.md).
