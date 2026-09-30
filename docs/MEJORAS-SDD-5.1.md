# Propuesta de mejoras para sdd-pipeline 5.1

> Origen: retro de la feature «CV enriquecido» (Campus CodeCrypto, issue #27, sep-2026).
> El pipeline 5.0.0 entregó 35/35 requisitos trazados, 69 tareas atómicas y 344 tests en verde —
> y aun así **tres rondas de verificación independiente encontraron 12 huecos reales** que los
> tests no veían (8 en la primera, 4 residuales en la segunda, ~2 casos borde conocidos en la
> tercera). Ninguno fue «código mal escrito»: todos siguen cinco patrones estructurales que el
> pipeline puede cerrar. Cada mejora indica el patrón que ataca, el caso real que la motiva,
> el cambio concreto en el plugin y cómo saber que funciona.

---

## Los cinco patrones de fallo observados

| # | Patrón | Casos reales (issue #27) |
|---|--------|--------------------------|
| P1 | **El mock sustituye a la realidad**: los tests pasan contra el mock de un puerto, pero el provider real no cumple el mismo contrato observable | El prompt real de Vertex no pedía preguntas por métrica ni usaba las respuestas del alumno (REQ-F-078/079); el recorte del PDF real recibía metadatos vacíos (REQ-F-094); `getBucket()` reventaba solo con credenciales JSON-en-variable (staging) |
| P2 | **Pieza construida pero no cableada**: cada tarea atómica verifica su pieza; nadie verifica que el flujo del usuario la monta | La vista antes/después existía y estaba testeada, pero ningún caller le pasaba la prop (REQ-F-073); el aviso emergente solo se montaba en la home (REQ-F-074) |
| P3 | **La letra literal se diluye en la cadena** requisito → spec → plan → task → test: cada eslabón resume, una palabra se cae y el test codifica la versión debilitada, que se autovalida en verde para siempre | «Proyectos personales» quedó como «Proyectos» en PDF, UI y tests (REQ-F-081); «con capturas» quedó en pasos escritos (REQ-F-066); la tipografía exigida quedó en Helvetica (REQ-F-093) |
| P4 | **Los cruces no tienen dueño**: replay, carreras y multi-ruta no pertenecen a ninguna tarea | Un replay de `confirmar` pisaba la edición del staff (REQ-F-088); dos fetches competían por un endpoint que consumía avisos atómicamente y el aviso se perdía sin mostrarse (REQ-F-074) |
| P5 | **Local ≠ desplegado**: configuración que solo existe en el entorno real | `GOOGLE_APPLICATION_CREDENTIALS` con el JSON en línea → `ENAMETOOLONG` → 500; el cron respondía 401 detrás del basic auth de Traefik porque `Authorization: Basic` impedía llegar al fallback `x-cron-secret` |

---

## Mejora 1 — Ronda adversarial como fase del pipeline (P1–P4)

**Hoy**: la verificación independiente fue un workflow ad hoc de 18 agentes. Encontró lo que
344 tests en verde no veían, precisamente porque tenía **prohibido usar los propios artefactos
de aceptación como evidencia**.

**Cambio**: nueva fase (o modo de `sdd-acceptance`) — `sdd-acceptance --adversarial` — que se
ejecuta tras el implementer y antes del gate humano:

- Un verificador por grupo de requisitos (por FASE), con estas reglas en el prompt:
  - prohibido citar `acceptance/`, `feedback/` o `spec/` como evidencia de cumplimiento —
    solo código de producción y tests;
  - releer la letra completa del requisito en `requirements/REQUIREMENTS.md`;
  - comprobar que los asserts de los tests codifican el criterio **de verdad**, no una
    versión debilitada;
  - buscar activamente el camino de producción que esquiva la implementación (otra ruta,
    otro caller, el provider real vs el mock).
- Contraverificación adversarial de todo veredicto no limpio (un segundo agente intenta
  refutar al primero).
- Un crítico de cobertura que confirma que el universo de requisitos evaluado es completo.
- El resultado alimenta el loop existente (`--loop` genera fix-tasks con `Source: ACCEPTANCE-LOOP`).

`sdd-gap-detector --semantic` ya apunta en esta dirección: la propuesta es convertirlo en
**gate obligatorio** del cierre de entrega, con contraverificación.

**Sabremos que funciona cuando**: el gate humano nunca sea la primera vez que alguien lee la
letra del requisito contra el código.

---

## Mejora 2 — Contract-test mock ↔ provider real (P1)

**Hoy**: `sdd-task-generator` genera el puerto, el mock y el provider real como tareas; nada
exige que ambos cumplan el mismo contrato observable.

**Cambio** (en `sdd-task-generator`, Phase 2): toda tarea que cree un puerto con mock genera
automáticamente **una tarea hermana de test de contrato simétrico**: la misma batería de casos
corre contra el mock y contra el provider real (este último puede verificarse a nivel de
*forma* — qué campos pide el prompt, qué instrucciones lleva, qué partes del contexto usa —
sin llamar a la API externa). Si el mock genera preguntas y el real no las pide, el contrato
rompe en CI, no en producción.

**Sabremos que funciona cuando**: un comportamiento que solo existe en el mock haga fallar un
test con nombre `CONTRACT-<puerto>`.

---

## Mejora 3 — Criterio «el usuario VE X» ⇒ test de journey (P2)

**Hoy**: los E2E assertaban `toBeVisible()` del contenedor. El dato podía llegar al DOM y
quedar oculto (truncado por un clamp), o el componente entero podía estar sin cablear, y el
test seguía verde.

**Cambio** (en `sdd-test-planner` §3 Design Decisions y en la review checklist del
task-generator): convención obligatoria — todo AC cuyo enunciado contenga «ve / muestra /
visible / aparece» exige un E2E que:

1. entre por la ruta del usuario (no monte el componente aislado),
2. asserte el **contenido** visible (texto esperado, no presencia del contenedor),
3. capture screenshot como evidencia adjunta al ledger.

**Sabremos que funciona cuando**: desconectar la prop de un componente «terminado» ponga en
rojo un E2E, no una demo humana semanas después.

---

## Mejora 4 — Replay e idempotencia como técnica estándar de las matrices (P4)

**Hoy**: las matrices de `sdd-test-planner` usan EP, BVA, tablas de decisión y transiciones de
estado. El caso «esto se ejecuta dos veces» no es técnica estándar y nadie es su dueño.

**Cambio** (en `sdd-test-planner` Mode 2): toda operación de **escritura** recibe por defecto
dos filas más en su matriz:

- `T-replay`: segunda ejecución idéntica — ¿qué debe conservarse? (ediciones manuales,
  marcas, respuestas ya dadas);
- `T-carrera`: dos callers concurrentes sobre el mismo recurso consumible — ¿quién puede
  consumirlo y quién solo leerlo?

**Sabremos que funciona cuando**: un `POST /confirmar` repetido tenga un test con su nombre
antes de que exista el bug.

---

## Mejora 5 — Smoke E2E post-deploy como job de CI (P5)

**Hoy**: el pipeline de CI construye y despliega; nadie ejecuta un flujo real contra el
entorno desplegado. Los dos bugs de configuración (credenciales GCS, cron tras Traefik) eran
**invisibles para tests, build y revisión de código** — solo existían desplegados.

**Cambio**: job `smoke:staging` tras `deploy:staging` que ejecute 2–3 journeys reales con
Playwright contra el entorno vivo (login por magic link, la operación de escritura central de
la feature, una descarga). La infraestructura ya existe (los E2E de la feature). Falla el
pipeline si falla el smoke.

**Sabremos que funciona cuando**: un `.env` de despliegue distinto del local rompa el
pipeline, no la demo con el cliente.

---

## Mejora 6 — Citar la letra exacta del criterio dentro del test (P3)

**Hoy**: el test se llama `REQ-F-081 AC1 · ...` (el id engancha el ledger), pero el cuerpo
asserta lo que el autor del test entendió. `titulo: 'Proyectos'` convivió meses con un
requisito que decía «Proyectos personales» y nadie lo vio, porque para verlo había que abrir
dos ficheros a la vez.

**Cambio** (en `references/tdd-workflow.md` del implementer y en la review checklist): el test
que verifica un criterio lleva como comentario **la frase literal** del criterio, copiada de
`requirements/REQUIREMENTS.md`, encima del assert que la codifica. La debilitación se vuelve
visible en el propio diff (`// AC1: "...su título es 'Proyectos personales'"` sobre un assert
que dice `'Proyectos'` canta solo).

**Sabremos que funciona cuando**: la ronda adversarial (Mejora 1) deje de encontrar «versión
debilitada del criterio» como categoría.

---

## Mejora 7 — Higiene operativa del propio pipeline

Dos lecciones pagadas en carne:

1. **Orden commit → evidencia** (en `sdd-task-implementer` Phase 9 y `sdd-acceptance`): la
   evidencia (JUnit + decisiones humanas) se ancla al HEAD evaluado. Capturarla con el árbol
   sucio o commitear después la invalida y desancla el gate humano. El skill debe imponer el
   orden: commit de código primero, evidencia después, ledger al final — y avisar si el árbol
   está sucio al capturar.
2. **Recursos de la máquina** (en los prompts de fan-out del implementer y del acceptance):
   dos agentes paralelos corriendo suites con Mongo-en-memoria agotaron la RAM del host y
   forzaron un reinicio. Regla para subagentes: tests **de uno en uno** (`node --test <un
   fichero>`), nunca suites completas, y no paralelizar más de un agente pesado con suites
   por máquina.

---

## Prioridad sugerida

| Orden | Mejora | Coste | Retorno observado en issue #27 |
|-------|--------|-------|-------------------------------|
| 1 | M5 · Smoke post-deploy | Bajo (infra ya existe) | Habría cazado 2 bugs de producción solos |
| 2 | M1 · Ronda adversarial | Medio (workflow ya probado) | Encontró 12 huecos que 344 tests no veían |
| 3 | M6 · Letra literal en el test | Muy bajo (convención) | Habría evitado 3 de los 12 |
| 4 | M3 · Journey para «VE X» | Bajo | Habría evitado 2 (y el clamp del gate) |
| 5 | M4 · Replay/carrera en matrices | Bajo | Habría evitado 2 |
| 6 | M2 · Contract-test mock↔real | Medio | Habría evitado 3 |
| 7 | M7 · Higiene operativa | Muy bajo | Dos tardes de re-trabajo y un reinicio |

---

*Redactado desde la retro de la issue #27 (Campus CodeCrypto): evidencia completa en el ledger
de aceptación de `feat/cv-alumnos`, los journals de los workflows de verificación y el informe
de entrega. Sep-2026.*
