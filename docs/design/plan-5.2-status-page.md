# Plan: página de estado viva del proyecto (sdd-pipeline 5.2)

## Contexto

El usuario quiere un único artefacto por proyecto que exista **desde el primer momento** (proyecto nuevo o feature nueva), que cuente en todo momento **qué se está haciendo y qué se ha hecho**, que acabe mostrando **cada requisito (funcional, no funcional, restricción) junto a su evidencia**, que lo registre todo con **enlaces entre las partes** y que lo entienda **un cliente no técnico**.

Verificación del estado actual (5.1.0):
- La «página viva» existe solo en prosa: `skills/sdd-acceptance/references/status-page.md` y la regla 5 de `skills/sdd-orchestrator/SKILL.md:18`. No hay comando que la genere, ni plantilla, ni tests.
- Nada la crea al empezar: el orquestador pregunta una vez tras la etapa 0; `sdd-setup` y `sdd-req-change` no la conocen; `sdd-lead/SKILL.md:70` la deja como opcional al final (contradice al orquestador). Las guías y `docs/aceptacion.md:203` dicen «opcional en `--publish`».
- Ninguna fila de etapa dispara la actualización; el LLM recompone la página cada vez.
- La URL vive en `.sdd/status-page.json`, que no se versiona: otro clon o una estación de multisesión crean otra página.
- No hay diario: `summary` se sobrescribe en cada re-ejecución y `.sdd/activity.jsonl` se retiró en 5.0. Las decisiones tomadas no se cuentan.
- No explica los requisitos en lenguaje llano, no enlaza necesidad → requisito → entrega → commit → evidencia, pone las capturas en la sección de entregas y no junto al requisito, y usa jerga (SHA, `unshown`, challenges, waived).
- Las features nuevas no tienen sección propia.

Decisiones del usuario: **una página por proyecto** con una sección por feature; **capturas y vídeos dentro de la página** (ficheros de la propia página, compartibles con el cliente); **explicación llana escrita en requisitos y revisada por el cliente**; **los comentarios del cliente en la página se leen en cada puerta**.

## Diseño

### Principio

La página es **determinista**: una plantilla fija del plugin + un `data.json` que construye la CLI. El LLM no compone HTML en cada etapa; solo escribe frases llanas en el diario y ejecuta un procedimiento de publicación. Así la página es igual entre sesiones, testeable y no depende de quién la publique.

### Piezas

1. **Diario versionado** `status/journal.jsonl` (nuevo, en git). Una línea por hecho: `{at, feature, stage, kind: start|done|gate|decision|change|skip|evidence|feedback, text (lenguaje llano, idioma del cliente), refs[], by?}`.
   - CLI: `sdd journal add --stage S --kind K --text "…" [--feature F] [--refs ID…] [--by "Nombre (rol)"]` y `sdd journal list [--json]`.
   - Lo escriben las skills en su paso Persist (una línea `done`), el orquestador y el lead en cada puerta (`gate`, `decision`), `sdd-req-change` (`change`), `sdd route --write` (`skip` con motivo) y la aceptación (`evidence`, `feedback`).
   - `sdd status build` completa huecos a partir de tags con fecha, `decisions.jsonl` y `route`, para que un paso olvidado no deje el diario cojo.
2. **Registro de la página** `status/page.json` (en git): `{url, createdAt, features: [{id, title, createdAt, chg?}], assets: {sha256: url}}`. Sustituye a `.sdd/status-page.json` (migración: si existe el viejo, se mueve).
3. **Datos** `sdd status build [--out .sdd/status-page] [--json]` (nuevo `scripts/lib/status.mjs`). Reutiliza, sin recalcular:
   - `parseNeeds` / `checkNeedCoverage` (`scripts/sdd-jev.mjs:211`, `:275`) → necesidades literales y `coveredBy`.
   - Parser de requisitos (`sdd req show`, `scripts/sdd.mjs:829`) → enunciado, prioridad, tipo, criterios, línea «Para el cliente».
   - `parseFase` (`scripts/lib/plan-lint.mjs:87`) → Incremento, Requisitos, Necesidades, Workflows, Demo.
   - `buildLedger` (`scripts/lib/acceptance.mjs`) → veredictos, criterios, adjuntos, `unshown`/`weakened`, challenges, `missing_videos`, `fase_acceptances`, waivers.
   - `sdd tasks status` y `trace` (`scripts/sdd.mjs:549`, `:566-621`) → progreso por entrega y commits por requisito.
   - `pipeline-state.json` (`stages`, `summary.metrics`, `route`), tags con fecha, `changes/CHANGE-REPORT-*.md` (`changeSource`, `scripts/lib/tracker.mjs:241`).
   - `detectProvider` (`scripts/lib/tracker.mjs:92`) → **URLs web** de commits, tags, issues y PR (nuevo helper `webUrl({kind, sha|tag|path})`, GitHub y GitLab).
   - Copia a `--out/evidencias/` solo los adjuntos `present` con sha256 coincidente; excluye trazas y vídeos > 15 MB (los lista como «entregado aparte»).
   - Escribe `--out/index.html` = plantilla con `data.json` incrustado (`<script type="application/json" id="sdd-data">`), de modo que el mismo fichero se abre en local sin Artifact.
4. **Plantilla fija** `templates/status-page/index.html` (+ `README.md` con el contrato de datos). Cumple el contrato de artifact-design: `<title>` de 2–4 palabras, tokens en `:root` con modo oscuro, sin scripts externos salvo los CDN permitidos, 16 px de margen en móvil, sin scroll horizontal. Todo el texto de interfaz en el idioma del cliente (`es` por defecto, tomado de `CUSTOMER-NEEDS.md`), con un diccionario de etiquetas.
5. **Procedimiento de publicación** `references/status-page.md` en la raíz del plugin (movido desde `sdd-acceptance`), único para todas las skills:
   - Crear si falta: `sdd status build` → `Artifact publish file_path .sdd/status-page/index.html, files {evidencias/…}` → guardar `url` en `status/page.json` y commitear `docs(status)`.
   - Actualizar: mismo procedimiento con `url` de `status/page.json`; solo se suben evidencias nuevas (sha256).
   - Sin herramienta Artifact (`claude -p`, estación sin ella): se construye igual y se deja `.sdd/status-page/index.html` para abrir en local; se anota en el diario.
   - Capturas con datos personales: la skill las lista y pregunta antes de la primera publicación de cada una.
6. **Línea «Para el cliente»** en cada requisito (`REQ-F`, `REQ-NF`, `REQ-C`): `- **Para el cliente:** …` (una o dos frases llanas, sin jerga). La escribe `sdd-requirements-engineer` y el cliente la revisa en la aprobación (`references/approval.md` §3, junto a los ejemplos). `sdd lint --needs` avisa si falta. `sdd-req-change` la mantiene en ADD/MODIFY.
7. **Comentarios del cliente**: en cada puerta de FASE, el orquestador y el lead leen los comentarios de la página (`ArtifactComments`), los tratan como feedback con la ruta existente (`feedback-route`: defecto / cambio / pregunta, confirmación humana), responden en el hilo y anotan en el diario `feedback`.

### Qué muestra la página (secciones fijas; las vacías dicen qué aparecerá y cuándo)

1. **Dónde estamos**: una frase («Estamos construyendo la entrega 2 de 4: …»), barra de fases en lenguaje llano (Entender lo que necesitas → Acordar qué se construye → Diseñar → Planificar entregas → Construir → Comprobar → Entregar), **qué estamos haciendo ahora** y **qué necesitamos de ti** (decisiones pendientes del cliente).
2. **Lo que nos pediste**: cada necesidad con la cita literal, quién y cuándo, su estado, y enlaces a los requisitos que la cubren.
3. **Qué vamos a construir y cómo lo demostramos**: tres grupos (Funciones · Calidad · Condiciones). Tarjeta por requisito: explicación «Para el cliente», ejemplo del criterio, prioridad, necesidades que cubre, entrega, estado llano (Pendiente · En construcción · Demostrado · No cumple aún · Aplazado con acuerdo) y **su evidencia en la misma tarjeta**: capturas por criterio, vídeo del flujo, resultado de pruebas (n de n), medición (valor frente a umbral), inspección o demo registrada (quién y cuándo). Avisos llanos: «falta la captura», «la prueba no comprueba el texto exacto», «un revisor independiente encontró un problema».
4. **Entregas**: una por FASE: qué incluye, pasos de la demo, vídeo, progreso de tareas, quién la aceptó y cuándo, enlace a la issue.
5. **Diario**: cronología de `status/journal.jsonl` agrupada por día y filtrable por feature: etapas empezadas y terminadas, aprobaciones, decisiones, etapas que no se hicieron y por qué, cambios pedidos, feedback y cómo se trató.
6. **Features**: una sección por feature (la inicial y cada ADD), con su propio resumen y filtro que aplica a todas las secciones.
7. **Detalles técnicos** (plegado): ids, SHAs con enlace al commit, tests por nombre, tags, informe de aceptación.
8. **Glosario** de los estados y términos que aparecen.

Enlaces: cada necesidad, requisito, entrega y evidencia tiene ancla (`#N-001`, `#REQ-F-002`, `#FASE-1`); cada tarjeta enlaza hacia arriba (necesidad) y hacia abajo (entrega, commits, evidencia), y fuera (commit, tag, issue, PR) cuando hay remoto.

### Cómo queda después de cada etapa

| Momento | Qué aparece o cambia |
|---|---|
| `sdd-setup` / inicio del orquestador o lead | **Se crea la página.** Dónde estamos: «Empezamos: vamos a entender lo que necesitas». Diario: «Proyecto iniciado». El resto de secciones explica qué aparecerá. |
| Requisitos capturados | Lo que nos pediste con las citas. Diario: necesidades recogidas. |
| Requisitos aprobados (`requirements-vN`) | Tarjetas de requisitos con «Para el cliente» y ejemplos, estado Pendiente. Diario: quién aprobó y cuándo. |
| Ruta decidida | Diario: qué etapas se harán y cuáles no, con el motivo y quién lo confirmó. |
| Especificaciones, auditoría, plan de pruebas | Diario con una frase llana por etapa (p. ej. «Definimos 40 escenarios de prueba»). Tarjetas sin cambio. |
| Plan (FASEs) | Entregas con su frase, requisitos y pasos de demo; cada tarjeta muestra a qué entrega pertenece. |
| Tareas | Progreso 0/n por entrega. |
| Implementación de una FASE | Progreso de tareas, requisitos de esa entrega pasan a En construcción; al verificar la FASE, capturas, vídeo y resultados de pruebas en sus tarjetas. |
| Ronda adversarial | Avisos llanos en las tarjetas afectadas; qué se hizo con cada uno en el diario. |
| Puerta de FASE | Entrega aceptada (quién, cuándo, canal) o feedback y su tratamiento; comentarios del cliente respondidos. |
| Feature nueva (`req-change` ADD) | Nueva sección de feature con sus necesidades y requisitos; el diario la registra; el filtro la incluye. |
| Aceptación final y firma | Todos los requisitos con su evidencia; resumen «n de n demostrados, k aplazados con acuerdo»; enlace al paquete de evidencias; diario con la firma. |

### Quién la actualiza (disparadores explícitos)

- `sdd-setup`: crea la página si `status/page.json` no existe y hay herramienta Artifact (pregunta una vez; «no» queda anotado en `status/page.json` como `declined`).
- Cada skill de etapa, en su Persist: `sdd journal add … --kind done` y, si existe la página, el procedimiento de actualización.
- `sdd-orchestrator` y `sdd-lead`: comprueban al empezar o reanudar que la página existe (crean si falta), y actualizan tras cada puerta; se alinea `sdd-lead/SKILL.md:70` con el orquestador.
- `sdd-req-change`: ADD de feature nueva → añade la feature a `status/page.json` y actualiza.
- `sdd-task-implementer` Phase 9 y `sdd-acceptance` (`--fase`, `--adversarial`, `--loop`, `--sign-off`, `--publish`): actualizan.
- `sdd-pipeline-status` muestra la URL de la página.

## Ficheros críticos

- Nuevos: `scripts/lib/status.mjs`, `scripts/lib/journal.mjs`, `templates/status-page/index.html`, `templates/status-page/README.md`, `references/status-page.md` (movido y reescrito), `tests/status/run.sh`.
- CLI: `scripts/sdd.mjs` (comandos `status build`, `journal add|list`, cabecera de uso), `scripts/lib/tracker.mjs` (helper `webUrl`).
- Skills (patrón repetido: una línea en Persist + referencia al procedimiento): `sdd-setup`, `sdd-orchestrator` (regla 5 → columna explícita en la tabla Flow; comentarios en `references/fase-gate.md`), `sdd-lead` (alinear fila 11 y puertas), `sdd-requirements-engineer` (plantilla «Para el cliente» y `references/approval.md`), `sdd-req-change` (feature nueva), `sdd-task-implementer` Phase 9, `sdd-acceptance` (`--publish` apunta al procedimiento común), `sdd-pipeline-status`, `sdd-route` vía `scripts/lib/route.mjs` (línea `skip` en el diario).
- `sdd-jev.mjs` / `sdd lint --needs`: aviso si falta «Para el cliente».
- `templates/gitignore.sdd`: mantener `.sdd/status-page/` fuera; `status/` versionado.
- Docs: `docs/aceptacion.md`, `docs/guia-paso-a-paso.md`, `docs/guia-completa-extendida.md`, `CLAUDE.md`, `CHANGELOG.md`, `cascade-patterns.md` §9 (contrato del diario).

## Verificación

1. `tests/status/run.sh` (nueva suite, en `CLAUDE.md` y `.github/workflows/ci.yml`):
   - `journal add/list` validan campos y escriben JSONL estable.
   - `status build` sobre el banco sembrado (`tests/fixtures/seeded/app`) y sobre `tests/fixtures/acceptance/todo`: `data.json` con las 8 secciones, cada requisito con su evidencia en la tarjeta, anclas y enlaces coherentes, URLs de commit con un `origin` de GitHub y otro de GitLab, sin secretos ni trazas, evidencias copiadas solo si `present` y sha256 coincide.
   - Simulación por etapas: el mismo proyecto recortado a «solo requisitos», «con plan», «FASE verificada» y «firmado» produce la sección «Dónde estamos» y los estados esperados en cada momento.
   - La plantilla pasa las reglas de artifact-design (sin scripts externos no permitidos, tokens y modo oscuro, `<title>` corto).
2. Suites existentes: `acceptance`, `quotes`, `seeded`, `setup`, `tracker`, `plan`, `hooks`, más `validate-plugin`, `check-paths`, shellcheck y servidor.
3. `sdd-cross-auditor` sobre los contratos nuevos (diario, `status/page.json`, línea «Para el cliente», disparadores por skill).
4. **Prueba real para el usuario**: construir la página del banco sembrado en tres momentos (requisitos aprobados, FASE-1 verificada con sus defectos, tras arreglos) y publicarla como Artifact privado en la misma URL para que el usuario la revise antes de fusionar. Leer un comentario de prueba con `ArtifactComments` para validar el canal del cliente.
5. Release como 5.2.0 solo cuando el usuario lo apruebe.

## Contrato de datos `sdd-status-v1` (fijo entre la CLI y la plantilla)

`sdd status build` escribe `data.json` y lo incrusta en `index.html` dentro de
`<script type="application/json" id="sdd-data">…</script>` (sustituye el marcador `<!--SDD-DATA-->` de la plantilla).
Todos los textos de este JSON ya están en el idioma del cliente cuando vienen de los artefactos; las etiquetas de la
interfaz las pone la plantilla (diccionario por `project.lang`, `es` y `en`).

```jsonc
{
  "$schema": "sdd-status-v1",
  "generatedAt": "ISO-8601",
  "project": { "name": "…", "lang": "es|en", "repo": { "provider": "github|gitlab|null", "web": "https://…|null" } },
  "sha": "abc1234",                        // HEAD corto evaluado
  "where": {
    "phase": "understand|agree|design|plan|build|verify|deliver|done",
    "phases": [ { "id": "understand", "state": "done|current|pending|skipped", "reason": "…?" } ],
    "fase": { "n": 2, "of": 4, "title": "…" } | null,   // entrega en curso
    "now": "texto llano: qué se está haciendo",        // de la última línea start del diario o de currentStage
    "next": "texto llano: qué viene después" | null,
    "needFromYou": [ { "text": "…", "anchor": "REQ-F-002|FASE-1|…" } ]  // decisiones pendientes del cliente
  },
  "features": [ { "id": "initial|CHG-…", "title": "…", "createdAt": "…", "summary": "…" } ],
  "needs": [ { "id": "N-001", "quote": "…", "who": "…", "when": "…", "status": "captured|confirmed|out-of-scope",
               "decision": "…?", "feature": "initial", "requirements": ["REQ-F-001"] } ],
  "requirements": [ {
    "id": "REQ-F-001", "kind": "F|NF|C", "title": "…", "plain": "…|null", "statement": "…",
    "priority": "Must|Should|Could|Won't", "feature": "initial", "needs": ["N-001"], "fase": 1 | null,
    "status": "pending|building|shown|failing|deferred|deprecated",
    "verification": "test|demo|measurement|inspection",
    "criteria": [ {
      "n": 1, "text": "GIVEN … WHEN … THEN …", "status": "pending|pass|fail|missing|unshown|weakened|stale",
      "captures": [ { "path": "evidencias/FASE-1/REQ-F-001-AC1.png", "published": true } ],
      "tests": { "pass": 1, "total": 1, "names": ["…"] },
      "measurement": { "metric": "…", "observed": 0, "op": "le", "threshold": 0 } | null,
      "record": { "type": "demo|inspection", "by": "…", "at": "…", "note": "…" } | null
    } ],
    "videos": [ { "path": "evidencias/FASE-1/WF-001.webm", "published": true } ],
    "warnings": [ { "code": "unshown|weakened|challenge|stale|failing", "text": "…técnico corto…", "ac": 1 } ],
    "waiver": { "reason": "…", "by": "…", "followUp": "#12" } | null,
    "links": { "commits": [ { "sha": "abc1234", "url": "…|null", "subject": "…" } ], "issue": { "number": 3, "url": "…" } | null }
  } ],
  "fases": [ {
    "n": 1, "title": "…", "increment": "…", "requirements": ["REQ-F-001"], "needs": ["N-001"], "workflows": ["WF-001"],
    "demo": [ { "step": 1, "action": "…", "expected": "…" } ],
    "videos": [ { "path": "…", "published": true } ],
    "missingVideos": ["WF-001"],             // vídeos de recorrido que faltan (aviso de la entrega, no de cada requisito)
    "tasks": { "done": 3, "total": 8 },
    "status": "pending|building|verified|accepted|rejected|observations",
    "acceptance": { "by": "…", "role": "…", "at": "…", "channel": "…" } | null,
    "issue": { "number": 4, "url": "…" } | null,
    "tags": [ { "name": "fase-1-accepted", "date": "…", "url": "…|null" } ]
  } ],
  "journal": [ { "at": "ISO", "feature": "initial", "stage": "requirements-engineer", "kind": "start|done|gate|decision|change|skip|evidence|feedback",
                 "text": "…llano…", "refs": ["REQ-F-001"], "by": "…?", "derived": false } ],
  "evidence": { "files": [ { "path": "…", "sha256": "…", "bytes": 0, "kind": "image|video", "criteria": ["REQ-F-001#1"], "published": true,
                             "reason": "too-large|personal-data|missing|null" } ],
                "pack": ".sdd/entregas/FASE-1-evidencias.tar.gz|null" },
  "technical": { "sha": "…", "gate": { "code": 0, "label": "…" } | null, "tags": [ { "name": "…", "date": "…", "url": "…|null" } ],
                 "report": "acceptance/ACCEPTANCE-REPORT.md|null", "pipeline": [ { "stage": "…", "status": "…", "lastRun": "…" } ] },
  "page": { "url": "…|null", "comments": true }
}
```

Mapeo de `where.phase` desde `pipeline-state.json`: `understand` = requirements-engineer sin `requirements-vN`;
`agree` = requisitos escritos pendientes de aprobación; `design` = specifications/spec-auditor/test-planner/tech/ux;
`plan` = plan-architect/task-generator; `build` = task-implementer; `verify` = acceptance/gap-detector antes de la
firma; `deliver` = firma en curso; `done` = firmado (todas las FASEs `accepted`). Las etapas `skipped` salen como
`skipped` con su `reason`.

Estado llano del requisito: `deprecated` → deprecated; `WAIVED` → deferred; `FAILING` → failing; `VERIFIED` → shown;
`MISSING` con alguna FASE suya `building|verified` o tareas hechas → building; resto → pending.

Ficheros del diario y registro: `status/journal.jsonl` y `status/page.json` (versionados). Salida: `.sdd/status-page/`
(`index.html`, `data.json`, `evidencias/…`), git-ignorada.

Ajustes tras la prueba real (2026-10-01): una FASE cuya puerta sigue bloqueada (challenge abierto en un Must con
`adversarial_gate: enforce`, criterio sin captura o vídeo que falta con `visual_evidence: required`) sale como
`building`, no `verified`, y no se pide al cliente que la pruebe; un requisito Must `VERIFIED` con un challenge abierto
bajo `enforce` sale como `building`; el aviso de vídeo que falta va en `fases[].missingVideos`, no en cada requisito.
