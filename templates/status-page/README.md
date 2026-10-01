# Plantilla de la página de estado

`index.html` es la plantilla **fija** de la página de estado viva del proyecto (sdd-pipeline 5.2). La página es
para el cliente: lenguaje llano, sin ids en primer plano, y cada requisito con su evidencia en la misma tarjeta.
El LLM no escribe HTML: `sdd status build` construye `data.json` (contrato `sdd-status-v1`, en
`docs/design/plan-5.2-status-page.md`) y lo incrusta en una copia de esta plantilla.

## Ficheros

| Fichero | Qué es |
|---|---|
| `index.html` | La plantilla. Un solo fichero con CSS y JS en línea, sin dependencias externas. |
| `sample-data.json` | Datos de ejemplo `sdd-status-v1` que cubren todos los casos (ver abajo). |
| `preview.sh` | Incrusta un `data.json` en una copia y genera capturas de relleno para abrirla en el navegador. |

## El marcador

La plantilla contiene exactamente una vez:

```html
<script type="application/json" id="sdd-data"><!--SDD-DATA--></script>
```

Quien construya la página sustituye `<!--SDD-DATA-->` por el JSON. Hay que escapar `<` como `<` en todo el
JSON (`JSON.stringify(data).replace(/</g, "\\u003c")`): así ningún texto del proyecto puede cerrar el bloque con
`</script>` ni abrir un comentario. Usa una función de reemplazo (`html.replace(marker, () => json)`) para que los
`$` del JSON no se interpreten.

Si el marcador no se sustituyó, la página muestra un estado vacío que explica qué comando la rellena. Si el JSON no
se puede leer, dice que hay que regenerarla.

El fichero no lleva `<!doctype>`, `<html>`, `<head>` ni `<body>`: al publicarlo como Artifact se envuelve en ese
esqueleto. Empieza por `<meta charset>`, `<meta viewport>` y `<title>`, de modo que también se abre bien desde disco.
El `<title>` estático es «Estado del proyecto»; en el navegador el script lo cambia a «{proyecto} · Estado del
proyecto». La CLI puede sustituir también el texto del `<title>` por el nombre del proyecto si quiere que la galería
de Artifacts lo muestre.

## Idioma y diccionario

Todo el texto de interfaz sale del objeto `DICT` del script, con dos idiomas: `es` y `en`. Se elige con
`project.lang` (por defecto `es`). Los textos que vienen en los datos (citas, «Para el cliente», diario, demo) ya
están en el idioma del cliente y se muestran tal cual. Para añadir un idioma, copia el bloque `es` completo con otra
clave y tradúcelo entero: una clave que falte se ve como texto vacío.

Correspondencias que fija el diccionario:

- Estado del requisito: `pending` Pendiente · `building` En construcción · `shown` Demostrado · `failing` No cumple
  aún · `deferred` Aplazado con acuerdo · `deprecated` Retirado.
- Avisos: `unshown` «Falta la captura que lo demuestra» · `weakened` «La prueba no comprueba el texto exacto que
  pediste» · `challenge` «Un revisor independiente encontró un problema» · `missing_video` «Falta el vídeo del
  recorrido» · `stale` «La evidencia es anterior al último cambio» · `failing` «Una prueba falla». El `text`
  técnico del aviso se muestra debajo, pequeño.
- Fases: Entender lo que necesitas → Acordar qué se construye → Diseñar → Planificar entregas → Construir →
  Comprobar → Entregar.
- Criterios: `GIVEN/WHEN/THEN/AND/BUT` se muestran como «Si / cuando / entonces / y / pero».

## Secciones (fijas, en este orden)

1. **Dónde estamos**: frase grande, recuento de requisitos por estado, barra de fases (las saltadas con su motivo),
   «Ahora estamos…», «Después…» y «Necesitamos de ti».
2. **Lo que nos pediste**: cita literal, quién y cuándo, estado y requisitos que la cubren.
3. **Qué vamos a construir y cómo lo demostramos**: Funciones · Calidad · Condiciones; una tarjeta por requisito con
   «Para el cliente» (o el título si es `null`), ejemplos, prioridad, necesidades, entrega, estado y su evidencia:
   capturas que se amplían, vídeo, pruebas n de n, medición frente al límite, demo o inspección, avisos y acuerdo
   de aplazamiento.
4. **Entregas**: qué incluye, pasos de la demo, vídeo, progreso de tareas, aceptación, issue y tags.
5. **Diario**: por día, lo más reciente arriba; las líneas `derived` en tono más suave.
6. **Funciones** (features): tarjeta por feature con su resumen; el filtro aplica a todas las secciones. El filtro
   se recuerda en `localStorage` si el navegador lo permite (opcional, en `try/catch`).
7. **Detalles técnicos** (`<details>` plegado): versión, resultado de la puerta, ids, commits con enlace, tests por
   nombre, tags, etapas y ficheros de evidencia.
8. **Glosario**.

Cada sección vacía dice qué aparecerá y cuándo. Anclas: `#N-001`, `#REQ-F-002`, `#REQ-F-002-1` (criterio),
`#FASE-1`, y `#s-where`, `#s-needs`, `#s-reqs`, `#s-fases`, `#s-journal`, `#s-features`, `#s-tech`, `#s-glossary`.
Un enlace a algo que el filtro oculta quita el filtro antes de saltar.

Las rutas de evidencia son relativas (`evidencias/FASE-1/…`) porque se publican como ficheros de la página. Solo se
enlaza fuera con URLs `http(s)`; cualquier otro esquema se descarta. Una captura o vídeo con `published: false` se
muestra como recuadro con el motivo de `evidence.files[].reason`; un fichero que no carga se sustituye por un aviso.

## Qué ve el cliente en cada momento

| Momento | Qué aparece o cambia |
|---|---|
| `sdd-setup` / inicio del orquestador o lead | **Se crea la página.** Dónde estamos: «Empezamos: estamos entendiendo lo que necesitas». Diario: «Proyecto iniciado». El resto de secciones explica qué aparecerá. |
| Requisitos capturados | Lo que nos pediste con las citas. Diario: necesidades recogidas. |
| Requisitos aprobados (`requirements-vN`) | Tarjetas de requisitos con «Para el cliente» y ejemplos, estado Pendiente. Diario: quién aprobó y cuándo. |
| Ruta decidida | Barra de fases con las saltadas y su motivo. Diario: qué etapas se harán y cuáles no, y quién lo confirmó. |
| Especificaciones, auditoría, plan de pruebas | Diario con una frase llana por etapa. Tarjetas sin cambio. |
| Plan (FASEs) | Entregas con su frase, requisitos y pasos de demo; cada tarjeta muestra a qué entrega pertenece. |
| Tareas | Progreso 0 de n por entrega. |
| Implementación de una FASE | Progreso de tareas; los requisitos de esa entrega pasan a En construcción; al verificar la FASE, capturas, vídeo y resultados de pruebas en sus tarjetas. |
| Ronda adversarial | Avisos llanos en las tarjetas afectadas; qué se hizo con cada uno, en el diario. |
| Puerta de FASE | Entrega aceptada (quién, cuándo, canal) o el feedback y su tratamiento. |
| Feature nueva (`req-change` ADD) | Nueva tarjeta de función con sus necesidades y requisitos; el diario la registra; el filtro la incluye. |
| Aceptación final y firma | Todos los requisitos con su evidencia; «n de n requisitos demostrados · aplazados con acuerdo: k»; el diario con la firma. |

## Vista previa

```bash
bash templates/status-page/preview.sh                      # sample-data.json → $TMPDIR/sdd-status-preview/index.html
bash templates/status-page/preview.sh data.json --out dir  # otros datos
```

`preview.sh` escribe capturas PNG de relleno para cada captura publicada que nombran los datos (con `--no-images`
no lo hace). No genera vídeos: la página muestra «No se pudo reproducir el vídeo aquí».

## Casos que cubre `sample-data.json`

Proyecto «Citas del Taller Ruiz», construyendo la entrega 2 de 3, con la fase de diseño saltada:

- `REQ-F-001` demostrado con capturas por criterio y vídeo; `REQ-F-002` con una captura que falta y evidencia
  anterior al último cambio; `REQ-F-003` con «la prueba no comprueba el texto exacto», vídeo que falta y una captura
  no publicada por datos personales; `REQ-F-004` con hallazgo de revisor independiente y una prueba que falla;
  `REQ-F-005` de la feature nueva, pendiente y sin «Para el cliente»; `REQ-F-006` aplazado con acuerdo;
  `REQ-F-007` retirado; `REQ-NF-001` con medición; `REQ-C-001` con inspección.
- Dos features, tres entregas (aceptada, en construcción, pendiente), una necesidad fuera de alcance con su decisión,
  diario de varios días con los ocho tipos y una línea `derived`, tres decisiones pendientes del cliente.
