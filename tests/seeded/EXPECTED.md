# Banco con defectos sembrados: clave de respuestas

> Proyecto: `tests/fixtures/seeded/app` («CV de alumnos», Node ≥ 18 sin dependencias, 25 tests en verde).
> Script: `tests/seeded/run.sh` (capas mecánicas) + `tests/seeded/check.mjs` (esta tabla en código).
> Este fichero está **fuera** del proyecto a propósito: la ronda adversarial se ejecuta a ciegas y no debe leerlo.

Cada defecto reproduce un caso real de la issue #27 (`docs/MEJORAS-SDD-5.1.md`) y, como allí, tiene su test en verde.
Dos requisitos limpios sirven de control de falsos positivos.

## Tabla

| Defecto | Patrón | Requisito / criterio | Dónde está sembrado | Capa que debe cazarlo | Por qué las demás no lo ven |
|---------|--------|----------------------|---------------------|-----------------------|-----------------------------|
| D1 literal debilitado | P3 | REQ-F-002 AC1 («Proyectos personales») | `src/ui/cv.js:7` pinta `<h2>Proyectos</h2>`; `tests/ui/cv.test.js:20` asserta `Proyectos`; la cita de la línea 19 copia bien el criterio | `lint --quotes` **Q-03** (el literal no está en el test fuera de la cita) · ledger `weakened` con `literal_gate: enforce` | La cita es correcta (sin Q-02); test verde, captura presente: el ledger sin literales daría VERIFIED |
| D2 cita desactualizada | P3 | REQ-F-003 AC1 («Pendiente de revisión por el equipo») | `tests/ui/estado.test.js:9` cita el texto anterior a un MODIFY («En revisión») y la línea 10 asserta ese literal viejo; `src/ui/estado.js:6` lo pinta | `lint --quotes` **Q-02** (la cita no es subcadena del criterio actual); también Q-03 (falta el literal actual) · ledger `weakened` | Test verde con la captura: VERIFIED para el ledger sin literales |
| D3 pieza no cableada | P2 | REQ-F-004 AC1 (comparativa antes/después en `/staff/cv/:id`) | `src/ui/comparativa.js` existe y `tests/ui/comparativa.test.js` la monta aislada; `src/routes.js` monta en `/staff/cv/:id` solo `renderRevision` (`src/ui/revision.js`), que no la incluye. Hay captura `REQ-F-004-AC1.png` (del componente aislado) | **solo ronda adversarial** (categoría `UNWIRED`, o `WRONG-CAPTURE` para la captura) | Cita y literales correctos (sin Q), test verde con captura (VERIFIED); sin suite E2E en el perfil (`acceptance: none`), V-21 no pide tarea de journey |
| D4 mock ≠ real | P1 | REQ-F-005 AC1 (el resumen recoge «Me motiva la ciberseguridad») | `src/providers/mock-cv-generator.js` añade las respuestas al resumen; `src/providers/vertex-cv-generator.js` `buildPrompt({ perfil })` no las pone en el prompt; `tests/api/generar.test.js` usa solo el doble; PLAN-FASE-1 §4.3 tiene la fila `CvGenerator` y no hay tarea `CONTRACT-CvGenerator` | `lint --plan` **V-21** (puerto sin tarea de contrato) + **ronda adversarial** para el hueco en sí (`MOCK-ONLY`) | V-21 solo ve que falta el test de contrato, no que el provider real incumple; el ledger da VERIFIED |
| D5 replay | P4 | REQ-F-006 AC2 (volver a confirmar conserva la corrección del staff) | `src/api/cv.js` `confirmar` copia siempre `editado` a `publicado`, y `editar` sobre un CV publicado solo toca `publicado`: la segunda confirmación pisa la corrección. `tests/api/confirmar.test.js` («REQ-F-006 AC2») confirma una sola vez, edita y comprueba; no hay test de replay | **solo ronda adversarial** (`CROSSING`, o `WEAKENED-ASSERT`: la cita dice «se vuelve a confirmar» y el test nunca lo hace) | La cita es exacta y su literal «Perfil orientado a backend» está en el assert (sin Q); test verde con captura: VERIFIED |
| D6 sin captura | M3 | REQ-F-007 AC1 («Tu CV ya está publicado») | Test verde (`tests/ui/panel.test.js`), ninguna imagen `REQ-F-007-AC1` / `AC-001-04` en `evidencias/` | ledger **`unshown`** → REQ-F-007 MISSING «no visual evidence»; `sdd gate` exit 1 | — |
| D7 sin vídeo | M3 | FASE-1 `> **Workflows:** WF-001` | En `evidencias/FASE-1/` solo hay `AC-001-05-descarga.webm` (sin `WF-001` en el nombre) | `sdd gate --fase 1` / `sdd accept --fase 1`: **`missing_videos: ["WF-001"]`** | — |
| C1 control | — | REQ-F-001 AC1 (cabecera) | Cableado por `/cv`, cita exacta, literales en el assert, captura | ninguna: VERIFIED y sin hallazgos | — |
| C2 control | — | REQ-F-008 AC1, AC2 (descarga) | Cableado por `/cv/descargar`, citas exactas, literales en los asserts, capturas | ninguna: VERIFIED y sin hallazgos | — |

Resultado mecánico esperado del conjunto: `sdd lint` 0 · `sdd lint --plan` 0 errores y un único aviso (V-21
`CvGenerator`) · `sdd accept --fase 1` con 7/8 Must VERIFIED sin `lint --quotes` (REQ-F-007 MISSING), y 5/8 con la
capa literal (REQ-F-002 y REQ-F-003 además, `summary.literal_gaps` = 2) · `sdd gate --fase 1` exit 1.
`sdd lint --quotes` exit 1 con Q-03 en REQ-F-002 AC1 y Q-02 (+ Q-03) en REQ-F-003 AC1, y ningún hallazgo más: los
demás tests citan su criterio literalmente y conservan sus literales, así que cualquier otro Q es un falso positivo.

## Ronda adversarial a ciegas

`sdd-acceptance --adversarial` debe acabar con al menos un challenge `confirmed` en REQ-F-004 (D3), REQ-F-005 (D4) y
REQ-F-006 AC2 (D5), y con REQ-F-001 y REQ-F-008 sin challenges (controles). D1 y D2 también son hallazgos válidos
(`WEAKENED-ASSERT`) para la ronda. Preparación:

```bash
env -u SDD_STATE_ROOT bash tests/seeded/run.sh --prepare /tmp/seeded-round   # repo con un commit en /tmp/seeded-round/app
```

Da a los verificadores solo `/tmp/seeded-round/app` (no la ruta de este repositorio, donde están esta clave y el
historial de git del banco).

## Mantenimiento

- Tras cambiar `src/` o `tests/` del proyecto, regenera el JUnit desde `tests/fixtures/seeded/app`:
  `node --test --test-reporter=junit --test-reporter-destination=junit/fase-1.xml`, y deja el atributo `file` relativo
  al proyecto (el reporter escribe rutas absolutas).
- `evidencias/` está en el `.gitignore` raíz del plugin: sus ficheros del banco se añaden con `git add -f`.
- Las capturas y el vídeo son rellenos pequeños (PNG 16×12 y una cabecera WebM); el ledger solo mira nombre,
  existencia y sha256.

## Resultado medido (2026-09-30, 5.1 en `feat/v5.1-evidence-adversarial`)

Capas mecánicas (`tests/seeded/run.sh`): D1 y D2 por `lint --quotes` (Q-03; Q-02 y Q-03) con el criterio `weakened`,
D4 por V-21, D6 por `unshown`, D7 por `missing_videos`. D3 y D5 salen VERIFIED, como se esperaba. Controles limpios.

Ronda adversarial a ciegas: un verificador para los 10 criterios de la FASE-1, sobre una copia con un solo commit y
sin esta clave. Protocolo de `skills/sdd-acceptance/references/adversarial-protocol.md` §3-4, sin cambios.

| Criterio | Verificador | Contraverificador | Defecto |
|----------|-------------|-------------------|---------|
| REQ-F-001 AC1 | clean | clean (muestra) | C1 |
| REQ-F-002 AC1 | WEAKENED-ASSERT | confirmed | D1 |
| REQ-F-003 AC1 | WEAKENED-ASSERT | confirmed | D2 |
| REQ-F-004 AC1 | UNWIRED | confirmed | D3 |
| REQ-F-005 AC1 | MOCK-ONLY | confirmed | D4 |
| REQ-F-006 AC1 | clean | — | — |
| REQ-F-006 AC2 | CROSSING | confirmed | D5 |
| REQ-F-007 AC1 | clean (captura ausente: no es su hallazgo) | — | D6, del ledger |
| REQ-F-008 AC1-2 | clean | clean (muestra) | C2 |

Cinco de cinco defectos de su ámbito cazados y confirmados, ningún falso positivo. Juntas, las dos capas cazan los
siete defectos. Es una sola ejecución sobre un banco pequeño con defectos plantados: mide que el protocolo funciona,
no su tasa de acierto en un proyecto real.
