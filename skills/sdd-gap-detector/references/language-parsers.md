# Language Parsers — Route Extraction Patterns

Reference document for `sdd-gap-detector`. Contains regex patterns for extracting route/endpoint definitions from supported web frameworks, and patterns for extracting API specs from SDD contract documents.

> **Principle**: All patterns are regex-based. No AST parser dependencies. Patterns are designed to be tolerant of formatting variations (spaces, quotes, line breaks).

---

## 1. Express.js

**Detection**: `package.json` contains `"express"` in `dependencies` or `devDependencies`.

**Route patterns**:

```regex
app\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

```regex
router\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

**Handler extraction**: The function name is typically the next identifier after the path argument:
```regex
app\.(get|post|put|patch|delete)\s*\(\s*['"`][^'"`]+['"`]\s*,\s*(\w+)
```

Or inline arrow/function:
```regex
app\.(get|post|put|patch|delete)\s*\(\s*['"`][^'"`]+['"`]\s*,\s*(?:async\s+)?(?:function\s+)?(\w+)?
```

**Middleware router mount** (for prefix detection):
```regex
app\.use\s*\(\s*['"`]([^'"`]+)['"`]\s*,\s*(\w+)
```
When a router is mounted with a prefix, prepend the prefix to all routes defined on that router.

**Files to scan**: `src/**/*.{js,ts}`, `routes/**/*.{js,ts}`, `api/**/*.{js,ts}`

---

## 2. Fastify

**Detection**: `package.json` contains `"fastify"` in `dependencies`.

**Route patterns**:

```regex
fastify\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

```regex
server\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

**Schema-based routes** (Fastify uses JSON Schema for validation):
```regex
fastify\.route\s*\(\s*\{[^}]*method\s*:\s*['"`](\w+)['"`][^}]*url\s*:\s*['"`]([^'"`]+)['"`]
```

**Files to scan**: `src/**/*.{js,ts}`, `routes/**/*.{js,ts}`, `plugins/**/*.{js,ts}`

---

## 3. Hono

**Detection**: `package.json` contains `"hono"` in `dependencies`.

**Route patterns**:

```regex
app\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

**Grouped routes**:
```regex
app\.route\s*\(\s*['"`]([^'"`]+)['"`]
```

**Files to scan**: `src/**/*.{ts,js}`, `app/**/*.{ts,js}`

---

## 4. Next.js App Router

**Detection**: `package.json` contains `"next"` in `dependencies`, OR `app/api/` directory exists.

**Route extraction is file-based**, not regex-based on route definitions:

1. Find all files matching: `app/api/**/route.{ts,js,tsx,jsx}`
2. The directory path determines the URL path:
   - `app/api/users/route.ts` → `/api/users`
   - `app/api/users/[id]/route.ts` → `/api/users/[id]`
   - `app/api/posts/[slug]/comments/route.ts` → `/api/posts/[slug]/comments`
3. Extract exported function names to determine HTTP methods:

```regex
export\s+(?:async\s+)?function\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)
```

```regex
export\s+const\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s*=
```

**Path parameter normalization**: Convert `[param]` to `:param` for comparison with spec paths.

**Files to scan**: `app/api/**/route.{ts,js,tsx,jsx}`, `src/app/api/**/route.{ts,js,tsx,jsx}`

---

## 4b. Next.js Server Actions

**Detection**: `package.json` contains `"next"` AND a file under `app/`, `src/app/` or `src/` contains the `"use server"` directive.

Server Actions have **no stable URL** (Next.js posts to the current page with an internal action id), so they are recorded as **actions**, not routes, and matched by name against the `Route / action` column of `design/OPERATION-MAPPING.md` (§8b).

**Module-level actions** — the directive is the first statement of the file; every exported async function is an action:

```regex
^\s*['"]use server['"];?\s*$
```

```regex
export\s+(?:default\s+)?async\s+function\s+(\w+)
```

```regex
export\s+const\s+(\w+)\s*=\s*async\b
```

**Inline actions** — the directive is the first statement of a function body (inside a Server Component):

```regex
async\s+function\s+(\w+)\s*\([^)]*\)\s*(?::\s*[^{]+)?\{\s*['"]use server['"]
```

**Usage sites** (page and element that trigger the action):

```regex
<form[^>]*\baction=\{\s*(\w+)\s*\}
```

```regex
\bformAction=\{\s*(\w+)\s*\}
```

```regex
useActionState\(\s*(\w+)
```

**Record**: `method: "ACTION"`, `path: "action:<name>"`, `handler: <name>`, `codeFile`, `line`; add `page: <route>` when a usage site lives in `app/**/page.{tsx,jsx}` (route from the directory as in §4, route groups `(group)` removed).

**Pages** (needed only for requirement-mandated URLs such as `?estado=`): `app/**/page.{tsx,jsx,ts,js}` → `GET` + directory path; `searchParams` reads (`searchParams.estado`, `searchParams.get('estado')`) give the query parameters.

**Files to scan**: `app/**/*.{ts,tsx,js,jsx}`, `src/app/**/*.{ts,tsx,js,jsx}`, `src/**/actions.{ts,js}`; exclude `.next/` and `node_modules/`.

---

## 5. Flask

**Detection**: `pyproject.toml` or `requirements.txt` contains `flask` (case-insensitive).

**Route patterns**:

Decorator with methods list:
```regex
@app\.route\s*\(\s*['"`]([^'"`]+)['"`].*methods\s*=\s*\[([^\]]+)\]
```
Extract individual methods from the list: `['GET', 'POST']` → GET, POST.

Shorthand decorators:
```regex
@app\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

Blueprint routes:
```regex
@(\w+)\.route\s*\(\s*['"`]([^'"`]+)['"`].*methods\s*=\s*\[([^\]]+)\]
```

```regex
@(\w+)\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

**Handler extraction**: The function defined immediately after the decorator:
```regex
@app\.route.*\ndef\s+(\w+)
```

**Files to scan**: `src/**/*.py`, `app/**/*.py`, `**/*.py` (Flask projects vary widely)

---

## 6. FastAPI

**Detection**: `pyproject.toml` or `requirements.txt` contains `fastapi` (case-insensitive).

**Route patterns**:

App-level:
```regex
@app\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

Router-level:
```regex
@router\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

Generic router variable names:
```regex
@(\w+)\.(get|post|put|patch|delete)\s*\(\s*['"`]([^'"`]+)['"`]
```

**Handler extraction**:
```regex
@(?:app|router|\w+)\.\w+.*\n(?:async\s+)?def\s+(\w+)
```

**Request body fields** (FastAPI uses Pydantic models):
```regex
class\s+(\w+)\s*\(.*BaseModel.*\):\s*\n((?:\s+\w+\s*:.*\n)+)
```

**Files to scan**: `src/**/*.py`, `app/**/*.py`, `routers/**/*.py`, `api/**/*.py`

---

## 7. Django

**Detection**: `manage.py` exists in project root, OR any file contains `django.urls`.

**URL patterns**:

```regex
path\s*\(\s*['"`]([^'"`]+)['"`]
```

```regex
re_path\s*\(\s*['"`]([^'"`]+)['"`]
```

**ViewSet routes** (Django REST Framework):
```regex
router\.register\s*\(\s*['"`]([^'"`]+)['"`]\s*,\s*(\w+)
```
ViewSets auto-generate list (GET), create (POST), retrieve (GET /:id), update (PUT /:id), partial_update (PATCH /:id), destroy (DELETE /:id).

**Handler extraction**:
```regex
path\s*\(\s*['"`][^'"`]+['"`]\s*,\s*(\w+)
```

**Files to scan**: `**/urls.py`, `**/views.py`, `**/viewsets.py`

---

## 7b. Rails

**Detection**: `Gemfile` contains `gem "rails"` (or `gem 'rails'`) AND `config/routes.rb` exists.

### Preferred source: `bin/rails routes --expanded`

Rails resolves `resources`, nesting, scopes and engines itself, so its output is authoritative. Run it from the project root when the app boots, or reuse `.sdd/rails-routes.txt` if it already exists (e.g. produced by the implementer with `bin/rails routes --expanded > .sdd/rails-routes.txt`). Each route is one block; the header is padded with `-` to the console width:

```text
--[ Route 7 ]-------------------------------------------------------------------
Prefix            | edit_task
Verb              | GET
URI               | /tasks/:id/edit(.:format)
Controller#Action | tasks#edit
Source Location   | config/routes.rb:7
```

**Block patterns** (lines outside a block, e.g. starting with `#`, are ignored):

```regex
^--\[ Route (\d+) \]-*$
```

```regex
^(Prefix|Verb|URI|Controller#Action|Source Location)\s*\|\s?(.*?)\s*$
```

**Normalization per block:**
1. **Verb** empty → mounted Rack app or engine (`mount ActionCable.server => "/cable"`): `method: "MOUNT"`. `GET|POST` (from `match … via:`) → one record per verb.
2. **URI** → strip `(.:format)` and any other optional group `(…)`; keep `:param` and `*glob` segments (§9 normalizes them).
3. **Prefix** empty is normal: Rails names only the first route of a name (`update` prints `PATCH` with prefix and `PUT` without). Every block is a record.
4. **handler** = `Controller#Action` (`tasks#update`, `admin/users#index`); for a mount, the class inside `#<…:0x…>`. **codeFile** = `Source Location` (Rails ≥ 7.1 in development; engine routes show `gem (version) config/routes.rb:N`), else `config/routes.rb`; the controller is `app/controllers/<controller>_controller.rb`.
5. Drop the §10 exclusions (`/up`, `/rails/*`, `/cable`, `/assets/*`, `turbo/native/navigation#*`).

**Fixture**: `references/fixtures/rails-routes-expanded.txt` — raw expanded output of a TODO app followed by its expected normalized table (in `#` comment lines, ignored by the block patterns).

### Static fallback: `config/routes.rb`

Used when the app cannot boot (no bundle, missing credentials). Best-effort: mark the manifest `source: "static"` and lower the confidence of MISMATCH findings. Parse line by line with a **scope stack**: push on a line ending in `do` (or `do |…|`), pop on a bare `end`. When `draw(:name)` appears, also parse `config/routes/name.rb`.

| DSL | Routes produced |
|---|---|
| `resources :tasks` | `GET /tasks` index · `POST /tasks` create · `GET /tasks/new` new · `GET /tasks/:id/edit` edit · `GET /tasks/:id` show · `PATCH` and `PUT /tasks/:id` update · `DELETE /tasks/:id` destroy — controller `tasks` |
| `only:` / `except:` | keep / drop the listed actions (`%i[index create]`, `[:index, :create]`, `:index`) |
| `resource :profile` (singular) | `GET /profile/new` · `POST /profile` · `GET /profile` · `GET /profile/edit` · `PATCH` and `PUT /profile` · `DELETE /profile` — no `:id`, no index; controller **plural** (`profiles`) |
| nesting `resources :tasks do … end` | children prefixed with `/tasks/:task_id` (singular parent + `_id`); `resource :completion, only: %i[create destroy]` inside → `POST` and `DELETE /tasks/:task_id/completion` → `completions#create` / `completions#destroy` |
| `member do post :archive end` · `post :archive, on: :member` | `POST /tasks/:id/archive` → `tasks#archive` |
| `collection do get :search end` · `get :search, on: :collection` | `GET /tasks/search` → `tasks#search` |
| `namespace :admin do` | path prefix `/admin` **and** controller prefix `admin/` |
| `scope "/es" do` · `scope path: "es"` · `scope module: :admin` | string / `path:` → path prefix only; `module:` → controller prefix only |
| `root "tasks#index"` · `root to: "tasks#index"` | `GET /` → `tasks#index` |
| `get "about", to: "pages#about"` · `post "/x" => "y#z"` (also `put`, `patch`, `delete`) | that verb + scoped path → controller#action |
| `match "x", to: "y#z", via: [:get, :post]` | one route per verb; `via: :all` → `ANY` |
| `mount Engine => "/path"` · `mount X, at: "/path"` | `MOUNT /path` (orphan candidate unless excluded in §10) |

Shape-changing options: `path: "tareas"` (segment renamed, controller unchanged), `controller: "x"`, `param: :slug` (`:slug` instead of `:id`), `shallow: true` (child member routes lose the parent prefix), `concerns: [:c]` (expand `concern :c do … end`). `constraints(…) do` and `defaults(…) do` are pass-through scopes.

**Regexes** (Ruby literals may use `"…"`, `'…'`, `%i[…]` or `[:a, :b]`):

```text
resources / resource   ^\s*(resources?)\s+((?::\w+\s*,?\s*)+)(.*?)(\bdo\b.*)?$
only / except          \b(only|except):\s*(?:%i\[([^\]]*)\]|\[([^\]]*)\]|:(\w+))
member / collection    ^\s*(member|collection)\s+do\b
verb on member/coll.   ^\s*(get|post|put|patch|delete)\s+:(\w+)(?:.*\bon:\s*:(member|collection))?
namespace              ^\s*namespace\s+:(\w+)
scope                  ^\s*scope\s+(.*?)\s*do\b
root                   ^\s*root\s+(?:to:\s*)?['"]([\w/]+)#(\w+)['"]
verb helper            ^\s*(get|post|put|patch|delete)\s+['"]([^'"]+)['"]\s*(?:,\s*to:\s*|=>\s*)['"]([\w/]+)#(\w+)['"]
match                  ^\s*match\s+['"]([^'"]+)['"].*\bvia:\s*(?:\[([^\]]*)\]|:(\w+))
mount                  ^\s*mount\s+([\w:.]+)(?:\s*=>\s*|,\s*at:\s*)['"]([^'"]+)['"]
draw                   ^\s*draw\s*\(?\s*:(\w+)
block end              ^\s*end\s*$
```

**Files to scan**: `config/routes.rb`, `config/routes/*.rb`; `app/controllers/**/*_controller.rb` (a public `def <action>` confirms the handler exists).

---

## 8. Extracting API Specs from `spec/contracts/*.md`

SDD contract files document endpoints in markdown tables. The gap detector should look for tables with these patterns:

### Table Header Detection

Look for markdown table headers containing endpoint-related columns:

```regex
\|\s*Method\s*\|\s*(?:Path|Endpoint|Route)\s*\|
```

```regex
\|\s*(?:HTTP\s+)?Method\s*\|\s*(?:URL|URI|Path)\s*\|\s*Description\s*\|
```

### Table Row Extraction

After finding a header, extract data rows:

```regex
\|\s*(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s*\|\s*([^\|]+?)\s*\|
```

### API ID Extraction

API identifiers may appear:
- In the table: `| API-005 | POST | /api/users | ... |`
- As section headers: `### API-005: Create User`
- Inline references: `Endpoint API-005`

Pattern (SDD operation ids are `API-NNN-NN`; the bare module prefix `API-NNN` also occurs):
```regex
API-\d{3,4}(?:-\d{2})?
```

### Request/Response Field Extraction

Field definitions typically appear in code blocks or sub-tables after an endpoint:

```regex
\|\s*(\w+)\s*\|\s*(string|number|boolean|integer|array|object)\s*\|\s*(required|optional)?\s*\|
```

Or in JSON schema code blocks:
```regex
"(\w+)"\s*:\s*\{?\s*"type"\s*:\s*"(string|number|boolean|integer|array|object)"
```

---

## 8b. Operations-Style Contracts and `design/OPERATION-MAPPING.md`

**Style per contract file:**

```regex
^\|\s*Style\s*\|\s*(operations|http)\b
```

No `Style` row: `http` when the file has a `Method | Path` header (§8 — pre-4.3 contract), otherwise `operations`. `Style: http` contracts keep the §8 method + path comparison unchanged.

**Operations table** (`Style: operations`, header `| ID | Operation | Actor | Input (VO) | Effect / post (INV) | Domain errors | UC |`):

```regex
^\|\s*ID\s*\|\s*Operation\s*\|\s*Actor\s*\|
```

```regex
^\|\s*(API-\d{3}-\d{2})\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|
```

Record `{id, operation, actor, specFile}`; domain error codes of the row: `` `(E_[A-Z0-9_]+)` ``.

**Mapping table** (`design/OPERATION-MAPPING.md`, section *Mapping*):

```regex
^\|\s*API-op\s*\|\s*Idiom\s*\|\s*Route\s*/\s*action\s*\|\s*Verb\s*\|
```

```regex
^\|\s*(API-\d{3}-\d{2})[^|]*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|
```

Groups: API-op, Idiom, Route / action, Verb. From **every cell** of the row collect references — routes `\b(GET|POST|PUT|PATCH|DELETE)\s+(/[^\s`]*)`, Rails handlers `\b([a-z_]+(?:/[a-z_]+)*#[a-z_]+)\b`, action names `` `(\w+)` `` followed by `in` / `@` and a file, `action=\{(\w+)\}`. The *Requirement-mandated transport* section adds its URLs as specified endpoints.

**Three-way comparison** (each API-op yields at most one finding):

| Contract (API-op) | Mapping row | Code (routes / actions) | Result |
|---|---|---|---|
| present | missing | — | **MISSING** — `issue: "no OPERATION-MAPPING row"` |
| present | present | referenced route/action not found | **MISSING** — `issue: "mapped route/action not implemented"` |
| present | present | found with another verb or path | **MISMATCH** |
| absent | row with an unknown API-op | — | **MISMATCH** — `issue: "mapping row without contract operation"` |
| — | — | route/action cited by no mapping row, not excluded by §10 | **ORPHAN** |

Code matching: Rails by `handler` first (`tasks#update`), then verb + normalized path; the `PUT` twin of a mapped `PATCH` update and a `root` route whose handler is mapped are not orphans. Next.js Server Actions by action name (§4b); pages by path. A route cited in any cell of a row (e.g. the `edit` form page in *Validation error*) counts as mapped. Worked example: end of `fixtures/rails-routes-expanded.txt`.

**No mapping file:** compare operation names with handler / action names only, mark every endpoint result `confidence: "low"` and add the highlight "design/OPERATION-MAPPING.md missing — run /sdd-tech-designer".

**JSON** stays `sdd-gap-analysis-v1`: in `endpoints.*[]`, `id` = API-op, `method` = the mapping Verb (`ACTION` for Server Actions), `path` = route or `action:<name>`, plus `"style": "operations"`.

---

## 9. Path Normalization Rules

When comparing spec paths against code paths, normalize both sides:

| Spec Format | Code Format | Normalized |
|-------------|-------------|------------|
| `/users/:id` | `/users/:id` | `/users/:param` |
| `/users/{id}` | `/users/:id` | `/users/:param` |
| `/users/<int:id>` | `/users/:id` | `/users/:param` |
| `/users/[id]` | `/users/[id]` | `/users/:param` |
| `/api/v1/users` | `/users` | Try both with and without common prefixes |

**Normalization algorithm**:
1. Strip trailing slashes
2. Convert all parameter syntaxes to `:param`: `{name}` → `:name`, `[name]` → `:name`, `<type:name>` → `:name`
3. Lowercase the path
4. If no match found, retry after stripping common prefixes: `/api`, `/api/v1`, `/api/v2`

---

## 10. Common Infrastructure Routes (Excluded from Orphan Detection)

These routes are commonly added by frameworks or infrastructure and should NOT be flagged as orphans:

| Pattern | Purpose |
|---------|---------|
| `/health`, `/healthz`, `/healthcheck` | Health checks |
| `/ready`, `/readiness` | Readiness probes |
| `/live`, `/liveness` | Liveness probes |
| `/ping` | Simple ping |
| `/metrics`, `/prometheus` | Metrics endpoints |
| `/docs`, `/swagger`, `/openapi`, `/redoc` | API documentation |
| `/favicon.ico` | Browser favicon |
| `/_next/*`, `/__next/*` | Next.js internals |
| `/static/*`, `/assets/*`, `/public/*` | Static file serving (incl. Rails Propshaft / Sprockets) |
| `/up` (`rails/health#show`) | Rails health check |
| `/rails/*` (`active_storage/*`, `action_mailbox/*`, `rails/conductor/*`, `rails/pwa#*`) | Rails engines: Active Storage, Action Mailbox, conductor, PWA manifest / service worker |
| `/cable` (`MOUNT`) | Action Cable |
| `/recede_historical_location`, `/resume_historical_location`, `/refresh_historical_location` (`turbo/native/navigation#*`) | Turbo Native (turbo-rails) |
