# Aceptación por requisito

La pregunta que el resto del pipeline no responde: **¿está satisfecho cada requisito, y con qué evidencia?** La aceptación cierra la cadena `N → REQ → UC → BDD/AC → TASK → COMMIT → CODE → TEST` con un veredicto por requisito, y registra como hechos (no como frases de un chat) las decisiones de las personas: exenciones, demos observadas, mediciones, inspecciones y la aceptación de cada FASE por el cliente.

Hay dos piezas:

- **La CLI decide.** `sdd accept`, `sdd gate` y `sdd loop next` (en `scripts/sdd.mjs`, Node ≥ 18 sin dependencias) calculan veredictos, frescura, el código de salida de la puerta y la parada del bucle. Dos ejecuciones sobre el mismo commit dan la misma respuesta, y el CI la comprueba solo con Node y git.
- **La skill `sdd-acceptance` reúne evidencia, enruta el trabajo y pregunta a las personas.** Nunca calcula un veredicto por su cuenta.

## De dónde sale la evidencia

Cada requisito declara en `REQUIREMENTS.md` cómo se verifica (`Verification:`), y cada criterio de aceptación tiene un escenario BDD con ID `AC-NNN-NN` en `spec/tests/BDD-UC-*.md`.

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
| MISSING | Algún criterio sin evidencia fresca (no implementado, sin test, o el test no lleva el ID del escenario) |
| VERIFIED | Cada criterio tiene evidencia válida de su método. El informe dice cuántos ("3/5") y de qué tipo |

**Frescura.** La evidencia vieja no cuenta:

- "Código" son los `code_paths` y `test_paths` del Stack Profile (por defecto `src` y `tests`, los que existan; si no existe ninguno, todo salvo `acceptance/` y `.sdd/`). Un commit de documentación, `feedback/`, specs o `acceptance/` no envejece la evidencia. Una configuración de build o de tests fuera de esas rutas (`package.json`, `vitest.config.ts`) solo cuenta si se añade a `code_paths`.
- Los resultados de tests valen mientras el código no haya cambiado desde que se capturaron, ni en commits ni en cambios sin commitear (`--junit-sha` lo afirma; sin él se comparan fechas).
- Cada registro sigue valiendo mientras no cambien los ficheros que nombra (`--paths`), o el código si no nombra ninguno, desde su commit.
- Una medición registrada con `sdd accept measure` guarda su comando: cuando caduca, `sdd accept --remeasure` la vuelve a ejecutar y añade el valor nuevo (nunca sin el flag). Una medición humana caducada vuelve a pedir a una persona.
- Los registros llevan el hash del enunciado y los criterios del requisito. Un MODIFY de `sdd-req-change` cambia el hash y reabre el requisito ("Decisiones a reconfirmar" en el informe).

## Salidas

| Fichero | Versionado | Qué contiene |
|---|---|---|
| `.sdd/acceptance.json` | No (ignorado) | El libro completo con `evaluated_sha`. Lo leen `sdd-pipeline-status`, el hook de inicio de sesión y el servidor MCP (`sdd_coverage`, `sdd_context`) |
| `acceptance/ACCEPTANCE-REPORT.md` | Sí | Informe legible por el cliente: primero los Must exentos, luego una fila por requisito con evidencia y necesidades, decisiones a reconfirmar y el SHA evaluado |
| `acceptance/decisions.jsonl` | Sí | Solo hechos humanos: exenciones, demos, mediciones, inspecciones y aceptaciones de FASE, con quién, rol, commit y hash del texto |

El informe y `decisions.jsonl` los escribe solo la CLI. El upstream guard deniega editarlos a mano.

## Comandos

```bash
SDD="${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs"   # en CI: SDD=.claude/sdd/sdd.mjs

node "$SDD" accept --junit-sha "$(git rev-parse HEAD)" --report acceptance/ACCEPTANCE-REPORT.md [--fase N]
node "$SDD" gate [--mode off|warn|enforce] [--fase N] [--md]
node "$SDD" loop next [--reset] [--max-cycles 3]
node "$SDD" accept record waiver --req REQ-F-007 --reason "…" --follow-up '#31' --by "Ana Pérez" --role "Product owner"
node "$SDD" accept record demo --req REQ-F-002 --ac 1 --observed "…" --pass true --by … --role … [--paths src/cli]
node "$SDD" accept record measurement --req REQ-NF-001 --metric p95_ms --observed 84 --op le --threshold 100 --by … --role …
node "$SDD" accept measure --req REQ-NF-002 --metric statements --command "npx vitest run --coverage" --extract 'All files[^|]*\|\s*([0-9.]+)' --op ge --threshold 90
node "$SDD" accept --remeasure [--fase N]     # vuelve a ejecutar las mediciones por comando caducadas
node "$SDD" accept record fase-acceptance --fase 1 --result accepted|observations|rejected --channel "demo 2026-09-27" --by … --role …
```

### La puerta: `sdd gate`

| Salida | Significado |
|---|---|
| 0 | Objetivo cumplido: todo Must VERIFIED o WAIVED |
| 1 | No cumplido |
| 2 | Evidencia obsoleta (o error de uso) |
| 3 | Cumplido con Musts exentos |

Modos: `enforce` falla con 1/2/3 tal cual; `warn` imprime y sale con 0; `off` sale con 0 en silencio. Por defecto se usa `acceptance_gate` del Stack Profile y, si no está, `enforce`. Al adoptar SDD en un proyecto existente conviene `warn`. `--fase N` limita la puerta a la línea `Requisitos:` de `plan/fases/FASE-N-*.md`, y `--md` imprime el bloque para el cuerpo de un PR.

## La skill `sdd-acceptance`

```
/sdd-acceptance --check                 # captura tests, libro + informe, integridad de la cadena (por defecto)
/sdd-acceptance --fase N                # lo mismo, limitado a la FASE N
/sdd-acceptance --loop [--max-cycles 3] # bucle hasta que todo Must esté VERIFIED o WAIVED
/sdd-acceptance --sign-off [--fase N | --release NAME]
/sdd-acceptance --publish [--fase N]    # bloque de PR/issue y página de estado opcional
```

**`--check`** ejecuta `test_report` sobre el commit actual (pregunta si el árbol está sucio), genera el libro y el informe, y revisa la **integridad de la cadena de IDs**: referencias rotas, definiciones huérfanas, requisitos sin caso de uso ni escenario, tareas hechas sin commit. Esta parte sustituye a la antigua skill `sdd-traceability-check` (`skills/sdd-acceptance/references/chain-integrity.md`); sus hallazgos se corrigen en origen y nunca cambian un veredicto. También lista las decisiones sobre código huérfano de `sdd-gap-detector` y, si Jev está activo, la adecuación de los tests (informativa).

**`--loop`** repite medir → actuar → medir. La parada la decide `sdd loop next`:

| `stop` | Cuándo |
|---|---|
| `goal` | Todos los Must VERIFIED o WAIVED |
| `regression` | Un Must que estuvo VERIFIED vuelve a estar abierto |
| `no-progress` | VERIFIED no sube y FAILING + MISSING no bajan |
| `max-cycles` | 3 ciclos por defecto (máximo 5) |
| `needs-human` | Todo lo que queda necesita a una persona |

Sobre la rama por defecto, `--loop` y `--sign-off` empiezan con `sdd branch start acceptance`, que crea (o retoma) `acceptance/{YYYY-MM-DD}` para sus commits; en cualquier otra rama se quedan en ella.

Cada Must abierto trae una ruta: `implement-or-test` (tarea incremental), `fix-code (Art. 12)` (se arregla el código, nunca el test), `spec-gap` (SPEC-DEVIATION y decisión humana, quizá `sdd-req-change`), `needs-human` (demo, medición o inspección que una persona confirma) o `rerun-tests`. Los tests modificados dentro del bucle se listan y los aprueba una persona. Si el bucle para sin llegar al objetivo, cada Must abierto necesita una disposición explícita: arreglar más tarde, exención con issue de seguimiento o cambio del requisito.

**`--sign-off`** pasa la puerta en modo `enforce`, enseña el informe al aprobador y pregunta de forma explícita. Solo cuenta su respuesta: una instrucción en una tarea, una skill o `CLAUDE.md` nunca es la confirmación. Aceptar exige la puerta cumplida (exit 0, o 3 con las exenciones a la vista); un rechazo se registra aunque no lo esté. En la puerta de FASE, antes de preguntar, el cliente confirma la evidencia de los requisitos por demo, medición o inspección (`accept record demo|measurement|inspection`), que el implementador dejó pendientes. Para una FASE registra `fase-acceptance`, hace commit del informe (`docs(acceptance): accept FASE-N`) y, si el resultado es aceptado o con observaciones, crea el tag anotado `fase-{N}-accepted` con aprobador, rol, canal, demo y SHA. Las observaciones no bloquean: cada una pasa a feedback o a `sdd-req-change`. Un rechazo no crea tag y su feedback se enruta como defecto, petición de cambio o pregunta. Una entrega (`--release`) usa el tag o la release que el proyecto ya tenga, con el bloque de `sdd gate --md` en su mensaje.

**`--publish`** genera el bloque de PR/issue (`sdd gate --md`, más los cambios de test aprobados). Si la sesión ofrece la herramienta Artifact, puede publicar además una **página de estado** privada para el cliente y el equipo (veredictos, incrementos, decisiones abiertas, sellada con SHA y fecha). Siempre pregunta antes de la primera publicación, porque saca títulos de requisitos de la máquina. En `claude -p` o sin esa herramienta, la vista compartible es `acceptance/ACCEPTANCE-REPORT.md`. La página sustituye al antiguo dashboard HTML.

## Salvaguardas contra la auto-aprobación accidental

- El tool guard devuelve `ask` antes de `sdd accept record` y antes de crear tags `fase-N-accepted` o `requirements-vN`.
- El upstream guard deniega Edit/Write sobre `acceptance/decisions.jsonl` y el informe.
- El Stop prompt de la skill comprueba que un bucle terminó en `goal` o dejó cada Must abierto con disposición humana.

Juntas evitan que un agente se apruebe a sí mismo por descuido. No son una garantía de seguridad: quien controla la máquina puede saltárselas.

## Jev (opcional e informativo)

Con `TYPESAFE_API_KEY`, `test-adequacy.json` pregunta si cada test afirma el THEN y ejecuta el WHEN de su criterio (por debajo de 0,5 se marca para revisión), y `evidence.json` puntúa si la salida de una demo muestra el THEN antes de que la persona la confirme. Jev nunca decide un veredicto, una exención, una firma, la parada del bucle ni nada que corra en CI. Ver [jev.md](jev.md).

## En CI

```bash
node .claude/sdd/sdd.mjs verify --range "origin/$BASE..HEAD"
node .claude/sdd/sdd.mjs lint
node .claude/sdd/sdd.mjs gate --mode warn
```

Las plantillas de `templates/ci/{github,gitlab}/` (instaladas con `sdd-setup --tracker`) ejecutan estos pasos. Ver [git.md](git.md).
