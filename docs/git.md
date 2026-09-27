# Git en el pipeline SDD

El historial de git es la evidencia de que una tarea se hizo y de que un requisito se entregó. Por eso cada regla de esta guía existe para que esa evidencia se pueda leer con una máquina. La referencia normativa, en inglés y la que leen las skills, es [`references/git-conventions.md`](../references/git-conventions.md). Esta página explica el porqué y cómo consultarlo.

## Commits: trailers escritos con `--trailer`

Cada commit de implementación es una tarea (`1 tarea = 1 commit`) y lo dice en su bloque de trailers:

| Trailer | Valor | Obligatorio en |
|---|---|---|
| `Task` | un único `TASK-F{N}-NNN` | `feat`, `test`, `refactor`; `fix`/`perf` necesitan `Task` **o** `Change` |
| `Refs` | IDs de spec separados por comas (`REQ-F-001, UC-003, AC-003-02`) | `docs(specs)` |
| `Change` | `CHG-YYYY-MM-DD-NNN`, `CR-N` o un hallazgo (`SEC-12`, `AUD-7`) | `fix`/`perf` sin tarea (hotfix, corrección de auditoría) |

Exentos: el resto de `docs`, `chore`, `ci`, `style`, `build`, los merges, `Revert "…"`, `fixup!`/`squash!`/`amend!` y cualquier mensaje con `[skip-sdd]`.

Git solo reconoce los trailers del **último párrafo** del mensaje, y solo si todas sus líneas son trailers. Un `Closes #12` metido en el bloque o una línea de atribución en un párrafo aparte convierten el bloque entero en texto, y la tarea deja de contar como hecha. `git commit --trailer` (git ≥ 2.32) siempre construye un bloque válido, así que las skills escriben así:

```bash
git commit -m "feat(tasks): completar una tarea" \
  --trailer "Task: TASK-F1-002" \
  --trailer "Refs: UC-003, AC-003-01, AC-003-02"

git commit -m "fix(auth): rechazar tokens de reset caducados" --trailer "Change: CHG-2026-09-27-001" --trailer "Refs: REQ-F-014"
git commit -m "docs(specs): aclarar la ventana de reintento de RN-004" --trailer "Refs: CR-12, REQ-F-004, UC-002"
```

`validate-plugin.mjs` rechaza en las skills los ejemplos de commit con trailers en heredoc y las claves fuera del vocabulario.

### El hook commit-msg y el CI validan lo mismo

`/sdd-setup` instala el hook `commit-msg` y copia el validador (`scripts/sdd.mjs` y sus módulos) a `.claude/sdd/` del proyecto. Versiona esa carpeta: el hook, los compañeros sin el plugin y el CI ejecutan la misma copia.

```bash
node .claude/sdd/sdd.mjs verify --message .git/COMMIT_EDITMSG   # lo que hace el hook
node .claude/sdd/sdd.mjs verify --range origin/main..HEAD        # lo que hace el CI en un PR
```

`verify` parsea los trailers con el propio git (`git interpret-trailers --parse`), acepta las claves sin distinguir mayúsculas (avisa si no se escriben `Task`, `Refs`, `Change`), nombra la línea de un bloque roto y valida el formato de los IDs. Sin Node, el hook recurre a una versión en bash sobre `git interpret-trailers`. Escape puntual: `[skip-sdd]` en el mensaje o `SDD_SKIP_VERIFY=1`.

## Ramas: se trabaja en rama por defecto

| Trabajo | Rama |
|---|---|
| FASE N | `fase-{N}-{slug}` |
| Cambio de requisito | `change/{CHG-ID}-{slug}` |
| Correcciones de auditoría | `audit/fix-{YYYY-MM-DD}` |

Con una issue, el número va delante (`42-fase-3-billing`), porque GitLab enlaza ramas por ese prefijo.

La regla, antes de cualquier commit: en la rama por defecto se crea la rama de trabajo (`git switch -c`, los cambios sin commitear viajan con ella); en una rama de trabajo se sigue en ella; con HEAD suelto se para y se pregunta. La aplican `sdd-req-change`, `sdd-task-implementer`, el Mode Fix del auditor, `sdd-reconcile`, las re-ejecuciones de specs e import, y el orquestador al reanudar.

```bash
node scripts/sdd.mjs branch status                  # rama actual, rama por defecto, HEAD suelto, worktree
node scripts/sdd.mjs branch start fase 1 lifecycle  # fase-1-lifecycle
node scripts/sdd.mjs branch start change CHG-2026-09-27-001 filtro --issue 42
```

La rama por defecto no se supone `main`: se lee de `default_branch` en el SDD Stack Profile, después de `origin/HEAD`, de `init.defaultBranch` y, por último, de `main`/`master`. Los worktrees de Streams (`--stream`) y su integración (`--integrate`) gestionan sus propias ramas y no pasan por esta regla.

## Merges: solo merge commits

Un squash o un rebase merge reescribe los commits de cada tarea en uno, y eso borra todos los trailers `Task:`. Se integra con merge commit, en local y en la plataforma (desactiva squash y rebase merge en la configuración del repositorio). `sdd verify --range base..head` falla cuando un rango toca rutas de código sin ningún `Task:`, que es como se ve un squash en el CI.

Para poner trailers en el propio merge:

```bash
git merge --no-ff --no-commit fase-1-lifecycle
git commit -m "Merge fase-1-lifecycle: FASE-1 completar y borrar" --trailer "Refs: FASE-1, REQ-F-003, REQ-F-004"
```

Hacer merge a la rama por defecto o hacer push siempre pregunta a la persona.

## Tags

Anotados siempre (`git tag -a`) y firmados (`-s`) cuando hay clave configurada:

| Tag | Qué marca | Quién lo crea |
|---|---|---|
| `requirements-v{N}` | Aprobación de los requisitos: aprobador, rol y hash de los documentos | La puerta 1, tras un sí explícito |
| `fase-{N}-accepted` | Aceptación del incremento por el cliente: aprobador, rol, canal, SHA, demo | `sdd-acceptance --sign-off` (aceptado o con observaciones) |
| `fase-N-foundation`, `fase-N-verified` | Streams: base terminada; FASE integrada y verificada | `sdd-task-implementer` |

El tool guard pide confirmación antes de crear `requirements-v*` y `fase-*-accepted`: evita la auto-aprobación accidental, no es una garantía. Un tag de aceptación no se mueve nunca. Cuando existe algún `fase-*-accepted`, todo trabajo nuevo empieza en rama.

## Consultas

Wrappers de SDD (coincidencia exacta de IDs, reverts descontados, commits antiguos sin bloque de trailers leídos del cuerpo y marcados `legacy`):

```bash
node scripts/sdd.mjs trace req REQ-F-004            # commits cuyo Task/Refs/Change contiene ese ID exacto
node scripts/sdd.mjs trace why src/tasks.ts:42      # blame → commit → trailers → IDs
node scripts/sdd.mjs trace delivered REQ-F-004      # tags y ramas que contienen ese trabajo
node scripts/sdd.mjs trace commits --files --json   # índice completo de trailers
node scripts/sdd.mjs tasks status --require-done    # tarea hecha = trailer Task en un commit alcanzable y no revertido
```

`REQ-F-01` ya no casa con `REQ-F-012`. `sdd trace why` sustituye a la antigua skill `sdd-code-index`: el enlace entre una línea de código y un requisito pasa por el commit que la escribió.

Git nativo, para lo demás:

```bash
git log --format='%h %(trailers:key=Task,valueonly,separator=%x2C) %s'   # tarea por commit
git log --first-parent main                                              # una línea por rama integrada
git log -S'retryWindow' --oneline                                        # commits que añadieron o quitaron un texto
git log -L '/function validate/,+20:src/tasks.ts'                        # historia de una función
git tag --contains <sha>                                                 # qué entregas llevan un commit
```

### Encontrar el commit que rompió algo

```bash
git bisect start HEAD fase-2-accepted     # malo, y el último punto bueno conocido
git bisect run npm test -- -t "AC-003-02" # el test del escenario que falla
git bisect reset
```

El commit que devuelve lleva su `Task:` y sus `Refs:`, así que dice qué tarea y qué requisito tocó.

## Issues, PRs y CI (GitHub y GitLab)


Con `tracker: github|gitlab` en el SDD Stack Profile (si no está, se deduce del host de `origin`), la CLI usa `gh api` / `glab api`:

```bash
node scripts/sdd.mjs issue open fase 1 [--dry-run]    # una issue por FASE: incremento, requisitos, escenarios, necesidades, demo
node scripts/sdd.mjs issue open change CHG-2026-09-27-001
node scripts/sdd.mjs issue update fase 1              # regenera solo el bloque entre <!-- sdd:begin --> y <!-- sdd:end -->
node scripts/sdd.mjs issue close fase 1               # solo si existe fase-1-accepted
node scripts/sdd.mjs issue read 42                    # título, cuerpo, etiquetas y comentarios como dato (entrada de un cambio)
node scripts/sdd.mjs pr-body --fase 1                 # cuerpo del PR/MR con la tabla de sdd gate --md
```

- Sin caché: las issues se localizan por la etiqueta `sdd` y un marcador oculto (`<!-- sdd:FASE-1 -->`). `update` no toca el texto humano fuera de su bloque.
- La issue de una FASE se cierra al aceptar la FASE, no al hacer merge: el PR de FASE lleva `Refs #N`; el de un cambio, `Closes #N`.
- `pr-body` solo imprime; nunca abre el PR. Todo push, issue, PR o merge pregunta antes.
- `sdd-setup --tracker` copia las plantillas de `templates/ci/{github,gitlab}/` y de PR e issue (`templates/tracker/`). El CI ejecuta `sdd verify --range` con historial completo (`fetch-depth: 0`), `sdd lint` y `sdd gate --mode warn`.

## Por qué no se usa `git notes`

Las notas no se envían ni se descargan por defecto y GitHub no las muestra, así que la evidencia guardada ahí se pierde. Toda la trazabilidad vive en trailers, tags y artefactos SDD.
