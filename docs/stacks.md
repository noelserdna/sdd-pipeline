# Stack kits y SDD Stack Profile

El pipeline no da por hecho ningún stack. Cada comando que ejecutan las skills de implementación (tests, typecheck,
lint, build, reset de la base de datos, servidor, suite de aceptación) sale del **SDD Stack Profile**, una sección del
`CLAUDE.md` raíz del proyecto. Un **stack kit** es un perfil ya probado para un stack concreto, junto con unas
convenciones cortas que se cargan en cada turno y cinco reglas por ruta. Se instala con `/sdd-setup --stack=<kit>`.

Origen: la carrera del 2026-09-15 implementó la misma especificación con Next.js 16 + Prisma 7 y con Rails 8.1 (app en
`web/`). Lo que hizo funcionar las dos pistas fue un `CLAUDE.md` por pista (tecnologías, layout, comandos y overrides del
implementer) y cinco reglas cortas por stack. Los kits son ese material, corregido (ver
[Qué no contiene nunca un kit](#qué-no-contiene-nunca-un-kit)).

## Contrato: `## SDD Stack Profile` v1

```
## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=<kit> -->
- stack: <kit>
- app_dir: web
- code_paths: web/app, web/config, web/db, web/lib
- test_paths: web/test
- install: bundle install
- test: bin/rails test
- test_file: bin/rails test {file}
- test_name: bin/rails test {file} -n "/{pattern}/"
- typecheck: none
- lint_files: bin/rubocop {files}
- lint: bin/rubocop
- build: none
- coverage: none
- db_reset_safe: bin/rails db:reset
- server: bin/rails server -p {port} -b 127.0.0.1 -P tmp/pids/sdd-server.pid
- port: 3000
- acceptance: none
- test_report: MINITEST_REPORTER=JUnitReporter MINITEST_REPORTERS_REPORTS_DIR="$(git rev-parse --show-toplevel)/.sdd/junit/minitest" bin/rails test
- acceptance_gate: enforce
- tracker: off
- e2e_scaffold: allowed
- task_state: trailers
- task_format: compact
- visual_evidence: required
- evidence_dir: evidencias
- adversarial_gate: enforce
- literal_gate: enforce
- floor_gate: enforce
- prove_it: warn
- test_slots: 2
- staging_url: none
- smoke: none
- smoke_report_path: .sdd/junit/smoke
- env_required: none
- deploy: none
```

| Clave | Qué es |
|---|---|
| `stack` | Nombre del kit (o `custom` si el perfil está escrito a mano) |
| `app_dir` | Directorio de la app, relativo a la raíz; `.` es la raíz |
| `code_paths`, `test_paths` | Rutas de código y de tests, relativas a la raíz y separadas por comas |
| `install` | Instalar dependencias |
| `test` | Suite propia completa |
| `test_file` | Un fichero de test (`{file}`) |
| `test_name` | Un test por nombre o regex (`{pattern}`), o `none` |
| `typecheck` | Comprobación de tipos, o `none` |
| `lint_files` | Lint de los ficheros cambiados (`{files}`), o `none` |
| `lint` | Lint completo, o `none` |
| `build` | Build de verificación final, o `none` |
| `coverage` | Cobertura, o `none` (los kits nunca instalan herramientas de cobertura) |
| `db_reset_safe` | Recrear la base de datos local sin comandos destructivos que exijan consentimiento humano, o `none` |
| `server` | Servidor local para iterar (`{port}`), o `none` |
| `port` | Puerto |
| `acceptance` | Suite de aceptación compartida; se ejecuta desde la raíz y el filtro por ID se añade como `--grep <ID>`; `none` si no hay |
| `test_report` | Suite completa escribiendo **JUnit XML** en `.sdd/junit/` (o en `test_report_path`), o `none`. Lo ejecuta `sdd-acceptance` antes de `sdd accept`; el nombre de cada test empieza por el ID del escenario (`AC-NNN-NN`) para que el libro de aceptación lo ate a su criterio |
| `test_report_path` | Opcional. Fichero, directorio o `dir/*.xml` (separados por comas) donde `sdd accept` y `sdd gate` leen el JUnit; sin la clave, `.sdd/junit/`. Los kits no la declaran |
| `acceptance_gate` | Modo de `sdd gate`: `enforce` (falla si algún Must no está VERIFIED ni WAIVED), `warn` (informa y sale con 0) u `off`. Sin la clave vale `enforce`; en un proyecto brownfield conviene `--set acceptance_gate=warn` hasta cerrar la adopción |
| `tracker` | `github`, `gitlab` u `off`: proveedor de issues y PRs de `sdd issue`/`sdd pr-body`. Todo push, issue o PR sigue preguntando a la persona |
| `e2e_scaffold` | `allowed` o `never`: si el implementer puede montar un proyecto E2E propio |
| `task_state` | `trailers` (el trailer `Task:` del commit es el estado) o `checkbox`. Sin la clave vale `checkbox`; `/sdd-setup` escribe `trailers` en los proyectos nuevos, con kit o sin él |
| `task_format` | `compact` (Review y Revert opcionales) o `full` |
| `default_branch` | Opcional. Rama por defecto para la regla de rama (`sdd.mjs branch start`) y el destino del merge; sin la clave: `origin/HEAD`, luego `init.defaultBranch`, luego `main`/`master`. Los kits no la declaran |
| `visual_evidence` | `required` (por defecto): un criterio de un REQ-F que pasa sin captura queda `unshown` y el requisito no es VERIFIED; `warn` solo lo informa; `off`, solo para proyectos sin interfaz (API pura, CLI) y por decisión de una persona |
| `evidence_dir` | Carpeta de capturas y vídeos, `<dir>/FASE-N/`, fuera de git; por defecto `evidencias` |
| `adversarial_gate` | Cómo trata `sdd gate` un hallazgo abierto de la ronda adversarial en un Must: `off`, `warn` (lo imprime) o `enforce` (por defecto; sale con 4) |
| `literal_gate` | Cómo trata `sdd accept` un test que nombra un criterio sin llevar su letra (`sdd lint --quotes`: Q-02 cita desactualizada, Q-03 literal ausente): `enforce` (por defecto) deja un criterio de un Must en `weakened` y el requisito no es VERIFIED; `warn` solo lo informa; `off` no lo comprueba |
| `floor_gate` | Opcional. Cómo trata `sdd lint --floor` lo que baja el listón desde su base (un gate de este perfil rebajado, un skip/only/focus añadido a un test ligado o ya existente, un fichero de test con ids de criterio borrado): `enforce` (por defecto) sale con 1, `warn` lo imprime y sale con 0, `off` no lo comprueba. El modo se lee de la base, así que bajarlo es otro hallazgo. Los kits la escriben (`enforce`), porque F-07 solo protege las claves que la base escribe. Ver [El listón](aceptacion.md#el-listón) |
| `prove_it` | Opcional. Cómo trata `sdd verify --range` un commit `fix` que cambia `code_paths` sin tocar ningún test: `warn` (por defecto) lo imprime, `enforce` falla, `off` no lo mira. Exentos: merges, reverts, `fixup!`, `[skip-sdd]`, `perf` y fixes sin código. Los kits la escriben (`warn`) para que F-07 la proteja |
| `test_slots` | Procesos de test que pueden correr a la vez en la máquina (por defecto `2`; `1` con base de datos en memoria o compartida, navegadores o contenedores). Ver [Recursos de la máquina](multisesion.md#recursos-de-la-máquina) |
| `staging_url` | URL del entorno de staging para las plantillas de smoke, o `none` |
| `smoke` | Comando del smoke post-deploy contra `staging_url`: ejecuta los tests etiquetados `@smoke-deploy` (`@smoke` es el tier de PR), p. ej. `npx playwright test --grep @smoke-deploy --reporter=junit`; o `none` |
| `smoke_report_path` | Dónde escribe el smoke su JUnit; lo leen las plantillas `sdd-smoke` (la CLI de aceptación lee solo `test_report_path`). Por defecto `.sdd/junit/smoke` |
| `env_required` | Nombres (nunca valores) de las variables de entorno que necesita la app, separados por comas, o `none`. El tech-designer los propone y una persona los escribe; el implementer abre una entrada `IF-` `ENV-REQUIRED` cuando una tarea lee una variable que no está en la lista |
| `deploy` | Nota informativa de cómo se despliega; ninguna skill la ejecuta. `none` si no hay |

Reglas del contrato:

- Todos los comandos se ejecutan desde `app_dir`, salvo `acceptance`, que se ejecuta desde la raíz. `test_report` también
  corre desde `app_dir`; los kits escriben en `$(git rev-parse --show-toplevel)/.sdd/junit/` para que el JUnit quede en la
  raíz aunque la app viva en un subdirectorio.
- `none` salta el paso con un `WARN <clave>: n/a (stack profile)`; nunca es un fallo.
- Toda ejecución de `acceptance` exporta `SDD_FASE={N}` y `SDD_EVIDENCE_DIR={evidence_dir}`: la suite los lee para
  dejar capturas y vídeos en `{evidence_dir}/FASE-{N}/`.
- Las claves de 5.1 (de `visual_evidence` a `deploy`) no son comandos: las leen la CLI de aceptación, las skills y las
  plantillas de smoke. Un perfil sin ellas toma los valores por defecto de la tabla; los kits las escriben explícitas.
- Marcadores en tiempo de ejecución: `{file}`, `{files}`, `{pattern}` y `{port}`. Las rutas que reciben son relativas a
  `app_dir`.
- `{app_dir}` solo aparece en las plantillas de los kits y se resuelve al instalar.
- Sin kit, `/sdd-setup` escribe un perfil mínimo con solo `- task_state: trailers`; el resto de claves toma los valores
  detectados o por defecto.

La referencia completa para el implementer (sustitución, cadencia de verificación, helper del servidor, `task_state`) está
en `skills/sdd-task-implementer/references/stack-profile.md`.

## Orden de resolución

`sdd-task-implementer` resuelve el perfil una vez por sesión. La primera fuente que da un `stack` gana, y las siguientes
solo rellenan las claves que falten:

| # | Fuente | `profile_source` |
|---|---|---|
| 1 | Sección `## SDD Stack Profile` del `CLAUDE.md` raíz (la escribe este kit o el usuario) | `declared` |
| 2 | Detección de ficheros en la raíz y en los directorios de primer nivel, con los `defaults` de `templates/stacks/<kit>/kit.json` | `detected` |
| 3 | Heurística de texto sobre `CLAUDE.md` de antes de 4.3 (`ts-workers`, `python`) | `legacy` |
| 4 | Un stack con kit citado en `plan/ARCHITECTURE.md` | `architecture` |
| — | Nada: la puerta G-08 pregunta qué stack usa el proyecto | — |

Instalar el kit convierte las fuentes 2-4, que son suposiciones, en la 1, que es una declaración.

## Kits incluidos

| Kit | Stack | Detección (`auto`) | Capas (`layers`) | Ficheros de unión (`wiring`) | Reglas |
|---|---|---|---|---|---|
| `rails` | Rails 8.x, Ruby 3.3+, Minitest con fixtures, Hotwire, Importmap, SQLite | `Gemfile` + `config/application.rb` | migration > model > controller > views | `config/routes.rb`, `db/schema.rb`, `app/views/layouts/application.html.erb` | models, controllers, views, migrations, testing |
| `nextjs-prisma` | Next.js 15/16 App Router, TypeScript, Prisma 7 con driver adapter, SQLite, Vitest | `package.json` + `next.config.*` | schema > domain/data > server actions > components/page | `src/app/layout.tsx`, `prisma/schema.prisma` | server-actions, api-routes, domain, prisma, testing |

| Clave | `rails` | `nextjs-prisma` |
|---|---|---|
| `test_file` | `bin/rails test {file}` | `npx vitest run {file}` |
| `typecheck` | `none` | `npx tsc --noEmit` |
| `lint_files` | `bin/rubocop {files}` | `npx eslint {files}` |
| `build` | `none` | `npm run build` (solo verificación final) |
| `db_reset_safe` | `bin/rails db:reset` | borra los `*.db` locales dentro de `app_dir` (profundidad 2) y luego `npx prisma migrate deploy && npx prisma generate` |
| `server` | `bin/rails server -p {port} -b 127.0.0.1 -P tmp/pids/sdd-server.pid` | `npx next dev -p {port} -H 127.0.0.1` (la verificación final hace build + `next start`) |
| `test_report` | `MINITEST_REPORTER=JUnitReporter MINITEST_REPORTERS_REPORTS_DIR=".../.sdd/junit/minitest" bin/rails test`; requiere la gema `minitest-reporters` (grupo `:test`) y `Minitest::Reporters.use! if ENV["MINITEST_REPORTER"]` en `test/test_helper.rb` | `npx vitest run --reporter=junit --outputFile=".../.sdd/junit/vitest.xml"` (reporter incluido en Vitest) |
| E2E con captura | en la suite compartida (`acceptance`) o en `test/system/` | en la suite compartida (`acceptance`) o en `tests/e2e/` (Playwright) |
| Tests de contrato de puertos | `test/contract/` | `tests/contract/` |

`wiring` son los ficheros que casi todas las tareas tocan (rutas, esquema, layout). `layers` es el orden de capas en que
`sdd-plan-architect` y `sdd-task-generator` trocean una operación de la spec.

Estructura de un kit:

```
templates/stacks/<kit>/
├── kit.json         # name, version, detect{all,any}, defaults (claves del perfil), rules, wiring, layers
├── profile.md       # la sección ## SDD Stack Profile con {app_dir} y {port}
├── conventions.md   # sección ## Stack Conventions (≤ 2.500 caracteres: se carga en cada turno)
├── rules/*.md       # reglas por ruta de Claude Code: frontmatter paths: con globs {app_dir}/…, ~20 líneas, sin código
└── NOTICE           # (rails) atribución: reglas adaptadas de rails_ai_agents, MIT, commit 03622f2
```

En `kit.json`, `defaults` repite los valores de `profile.md` (con `{app_dir}` en `code_paths` y `test_paths`), y
`defaults.app_dir` y `defaults.port` dan los valores por omisión de los marcadores. Quien lea `defaults` sin pasar por el
instalador tiene que sustituir `{app_dir}/` por `<app_dir>/`, o quitarlo si la app está en la raíz.
`scripts/validate-plugin.mjs` (§7) comprueba que ambos coinciden.

## Instalación

Desde Claude Code:

```
/sdd-setup --stack=rails --app-dir web
/sdd-setup --stack=nextjs-prisma --port 3001
/sdd-setup --stack=auto
```

Con el script, que es lo que ejecuta el paso 4b de `/sdd-setup`:

```bash
bash "$SDD_PLUGIN_ROOT/scripts/install-stack-kit.sh" --stack rails --app-dir web --dry-run   # enseña el bloque, no escribe
bash "$SDD_PLUGIN_ROOT/scripts/install-stack-kit.sh" --stack rails --app-dir web
bash "$SDD_PLUGIN_ROOT/scripts/install-stack-kit.sh"                                          # refresca el kit instalado
bash "$SDD_PLUGIN_ROOT/scripts/install-stack-kit.sh" --uninstall
```

Qué hace:

- Escribe en el `CLAUDE.md` raíz un bloque delimitado por `<!-- sdd-stack-begin kit=<kit> v<versión> -->` y
  `<!-- sdd-stack-end -->`, con el perfil y las convenciones ya renderizados. Si el bloque ya existe lo sustituye en su
  sitio; si no, lo añade al final. El texto de fuera del bloque no se toca.
- Copia las reglas a `.claude/rules/sdd-<kit>-<regla>.md` con los globs resueltos y una línea de cabecera
  `<!-- sdd-stack-kit managed … -->` justo después del frontmatter. Solo sobrescribe ficheros que tengan esa cabecera, y
  borra las reglas gestionadas que ya no pertenecen al kit (por ejemplo, al cambiar de kit).
- Es idempotente: una segunda ejecución no cambia ningún byte. Al subir la versión del kit, el bloque y las reglas se
  refrescan en su sitio.
- `auto` busca en la raíz y en los directorios de primer nivel (sin `node_modules`, `vendor`, `tmp` ni `log`) y fija
  `app_dir` en el directorio donde encuentra el stack. Si no encuentra nada termina con código 1 y pide `--stack`; si
  encuentra varios candidatos pide `--stack` y `--app-dir`.
- `app_dir` se toma, por este orden, de `--app-dir`, del bloque existente del mismo kit, de la detección, y si no, `.`.
  `port` se toma de `--port`, del bloque existente o del kit (3000).
- Resuelve el kit relativo a la ubicación del script, así que funciona igual desde el repo del plugin y desde el plugin
  instalado. Busca la raíz del proyecto con `git rev-parse --show-toplevel` (o usa `--project DIR`).
- Códigos de salida: 0 ok, 1 no se pudo (nada detectado, bloque con marcas desparejadas), 2 uso incorrecto o kit
  desconocido.

Hay que versionar `CLAUDE.md` y `.claude/rules/sdd-*.md`: son la declaración del stack para todo el equipo y para los
worktrees.

## Personalizar

**`--set key=value`** sustituye una clave del perfil. Ejemplo típico, con una suite de aceptación compartida en
`acceptance/`:

```bash
bash "$SDD_PLUGIN_ROOT/scripts/install-stack-kit.sh" --stack rails --app-dir web --port 3001 \
  --set "acceptance=cd acceptance && BASE_URL=http://127.0.0.1:{port} npx playwright test"
```

- La sustitución se guarda dentro del bloque como `<!-- sdd-stack-set acceptance=… -->` y se vuelve a aplicar en cada
  refresco, también tras subir la versión del kit.
- `--set key=` (sin valor) la olvida y la clave vuelve al valor del kit.
- `{port}` y `{app_dir}` también se sustituyen en los valores de `--set`.
- Si `acceptance` no es `none`, `e2e_scaffold` pasa a `never` salvo que se fije explícitamente con `--set e2e_scaffold=allowed`.
- Solo acepta claves del perfil. Un valor no puede contener saltos de línea ni `-->`, y el valor no debe llevar ` #`
  porque el perfil lo lee como comentario.

**Cambios dentro del bloque**: se pierden en el siguiente refresco. Para un perfil muy distinto, desinstala el kit
(`--uninstall`) y escribe tu propia sección `## SDD Stack Profile` siguiendo el contrato: el perfil es el contrato y el
kit solo lo genera.

**Reglas**: borra la línea `<!-- sdd-stack-kit managed … -->` de la regla y el instalador la dejará en paz
(`skipped … left untouched`). Si lo que quieres es otra regla, créala con otro nombre en `.claude/rules/`.

## Qué no contiene nunca un kit

Defectos del material de la carrera que no se trasladan, y que `validate-plugin.mjs` §7 vigila cuando es posible:

- **Resets destructivos con consentimiento para IA.** `prisma migrate reset` está bloqueado para agentes en Prisma 7, y en
  la carrera el agente acabó fabricando el consentimiento. `db_reset_safe` borra el SQLite local dentro de `app_dir` y
  aplica las migraciones con `migrate deploy`. Las cadenas `CONSENT` y `migrate reset` están prohibidas en los kits.
- **Etiquetas que no existen**, como `@restart`: cadena prohibida.
- **Reglas propias del experimento**: carpetas de solo lectura, "no preguntes nunca", "no hagas push", puertos o ramas
  fijas. `Never ask` y `Never push` están prohibidas.
- **`npm run build` antes de cada ejecución E2E.** El build es solo verificación final; para iterar se usa `next dev`.
- **Globs que no casan.** La regla de dominio de TS apuntaba a `web/src/lib/**` con el dominio en `web/src/domain`; el kit
  usa `{app_dir}/src/{lib,domain,server}/**`. Todos los globs empiezan por `{app_dir}/`.
- **Reglas que se contradicen.** "Formularios con server actions" convivía con otra regla que cubría `route.ts`. Ahora los
  formularios van con Server Actions, y `route.ts` solo existe para APIs HTTP que pida la spec (regla `api-routes`).
- **Consejos de Rails que chocaban con la spec**: un estado "unprocessable" sin nombre (ahora `:unprocessable_content`
  con `redirect_to … status: :see_other`) y Frames/Streams por defecto (ahora Turbo Drive por defecto, Frames solo si el
  flujo de página completa sigue funcionando y Streams solo con alternativa HTML).
- **Contenido de dominio** (entidades o textos de una spec concreta) y bloques de código en las reglas.

## Límites conocidos

- Un kit y una app por repositorio. Un monorepo con varias apps necesita un perfil escrito a mano.
- La detección del instalador para `nextjs-prisma` no exige `prisma/schema.prisma`, y la del implementer sí (sin él
  resuelve `nextjs`). Para Next.js sin Prisma, usa `--set db_reset_safe=none` y trata como informativas las reglas
  `prisma` y `domain`.
- Las reglas por ruta solo entran en contexto cuando Claude trabaja con ficheros que casan con sus `paths:`. Lo que debe
  valer siempre va en `conventions.md`.
- Las convenciones asumen Rails 8.x y Next.js 15/16 con Prisma 7. Con versiones anteriores (`:unprocessable_entity`
  antes de Rack 3.1, `searchParams` síncrono antes de Next.js 15, Prisma sin driver adapter) hacen falta `--set` o reglas
  propias.
- El `db_reset_safe` de `nextjs-prisma` borra cualquier `*.db`, `*.db-journal`, `*.db-wal` o `*.db-shm` hasta profundidad 2
  dentro de `app_dir`. Si la app guarda otros SQLite ahí, sustitúyelo con `--set`.
- `scripts/test-result-parser.py` (lo usa `scripts/sdd-graph.py` para el grafo; los veredictos de aceptación leen JUnit, ver `test_report`) entiende la salida verbose de Minitest (`bin/rails test -v >
  .sdd/test-results-raw.txt`, lanzado desde `app_dir`) y el JSON de RSpec. Detecta el runner en el `app_dir` del perfil, y
  solo considera RSpec si hay `.rspec` o `spec/rails_helper.rb`, porque `spec/` es la carpeta de especificación del SDD.
