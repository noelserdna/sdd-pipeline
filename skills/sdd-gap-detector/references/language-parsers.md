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

Pattern:
```regex
API-\d{3,4}
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
| `/static/*`, `/assets/*`, `/public/*` | Static file serving |
