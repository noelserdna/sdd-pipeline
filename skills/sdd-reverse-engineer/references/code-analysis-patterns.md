# Code Analysis Patterns — Language-Specific Detection

> Patrones de detección de entidades, rutas, state machines, invariantes, código muerto y otros artefactos por lenguaje y framework. Utilizado por la Fase 3 de `sdd-reverse-engineer`.

---

## 1. Entity Detection

### TypeScript / JavaScript

```
Pattern: class/interface/type declarations
Signals:
  - `class {Name}` with properties → Entity
  - `interface {Name}` / `type {Name} = {` → Value Object or DTO
  - Decorators: @Entity, @Model, @Table → ORM Entity
  - `enum {Name}` → Enumeration / State set
  - `extends` / `implements` → Inheritance hierarchy
  - Properties with validation decorators → Invariants
```

### Python

```
Pattern: class definitions, dataclasses, Pydantic models
Signals:
  - `class {Name}(Base):` with SQLAlchemy → ORM Entity
  - `@dataclass` → Value Object or DTO
  - `class {Name}(BaseModel):` → Pydantic model (API schema)
  - `class {Name}(Enum):` → Enumeration
  - `__init__` with validation → Invariants
  - `@property` → Computed fields
```

### Rust

```
Pattern: struct/enum/trait definitions
Signals:
  - `struct {Name}` with `#[derive(...)]` → Entity or Value Object
  - `enum {Name}` with variants → State machine or Enumeration
  - `impl {Name}` → Methods and behavior
  - `trait {Name}` → Interface contract
  - `pub` vs private → Visibility boundary = module API
```

### Go

```
Pattern: struct/interface definitions
Signals:
  - `type {Name} struct` → Entity
  - `type {Name} interface` → Contract
  - Methods: `func (r *{Name}) Method()` → Behavior
  - Embedded structs → Composition (not inheritance)
  - Unexported fields → Encapsulation boundary
```

### Java / Kotlin

```
Pattern: class/interface/record definitions
Signals:
  - `@Entity` annotation → JPA Entity
  - `record {Name}` → Value Object / DTO
  - `interface {Name}` → Contract
  - `abstract class` → Base entity
  - `@Embeddable` → Value Object in DDD sense
```

---

## 2. Route / Endpoint Detection

### Express.js / Fastify / Koa

```
Patterns:
  - `router.get('/path', handler)` → GET endpoint
  - `app.post('/path', middleware, handler)` → POST with middleware
  - `Router()` usage → Route group
  - Middleware chain: auth, validation, rate limiting
Extract:
  - HTTP method, path, path parameters
  - Middleware stack (auth, validation)
  - Request body type (from TypeScript types or validation schema)
  - Response type (from return type or res.json calls)
```

### FastAPI / Django / Flask

```
Patterns:
  - `@app.get('/path')` → FastAPI endpoint
  - `@api_view(['GET'])` → DRF endpoint
  - `path('url/', view)` in urls.py → Django URL
  - `@app.route('/path', methods=['GET'])` → Flask endpoint
Extract:
  - Pydantic models in parameters → request/response schemas
  - Depends() → dependency injection (auth, DB session)
  - status_code parameter → expected responses
```

### Spring Boot

```
Patterns:
  - `@GetMapping("/path")` → GET endpoint
  - `@RestController` → Controller class
  - `@RequestBody` → Request schema
  - `@PathVariable`, `@RequestParam` → Parameters
Extract:
  - DTO classes → Request/Response schemas
  - @PreAuthorize → Authorization rules
  - @Validated → Validation constraints
```

### Gin / Echo / Fiber (Go)

```
Patterns:
  - `r.GET("/path", handler)` → Gin endpoint
  - `e.POST("/path", handler)` → Echo endpoint
  - Middleware groups → Route-level concerns
Extract:
  - Context binding → Request schema
  - c.JSON(status, response) → Response schema
```

---

## 3. State Machine Detection

### Explicit State Machines

```
Signals:
  - Enum of states: `enum Status { PENDING, ACTIVE, CLOSED }`
  - Transition functions: `function transition(current, event)`
  - Switch/match on state: `switch(state) { case PENDING: ... }`
  - State pattern: classes per state with handle() methods
  - XState definitions: `createMachine({ states: { ... } })`
```

### Implicit State Machines

```
Signals:
  - Status field updates: `entity.status = 'active'`
  - Guard conditions: `if (order.status !== 'pending') throw`
  - Sequential processing: state changes in specific order
  - Event-driven transitions: event handlers that change state
Extract:
  - All possible states (from enum, string literals, or DB values)
  - Valid transitions (from code paths)
  - Guards (from conditional checks before transition)
  - Actions (side effects during transition)
```

---

## 4. Invariant Detection

```
Signals by type:

Validation Rules:
  - Joi/Zod/Yup schemas → Field-level constraints
  - Class-validator decorators → Entity constraints
  - Manual validation: if (!value) throw → Guard clause
  - Pydantic validators → Field + model-level rules

Business Rules:
  - Conditional throws: if (balance < amount) throw InsufficientFunds
  - Assertions: assert(quantity > 0)
  - Early returns with error: if (!authorized) return 403
  - Complex conditionals encoding business logic

Referential Integrity:
  - Foreign key constraints (ORM definitions)
  - Cascade rules (onDelete, onUpdate)
  - Unique constraints

Temporal Invariants:
  - createdAt/updatedAt patterns
  - TTL/expiry checks
  - Sequential ordering constraints
```

---

## 5. Dead Code Detection

### Call Graph Analysis

```
Method:
1. Build export graph: what each module exports
2. Build import graph: what each module imports
3. Find unreferenced exports (exported but never imported)
4. Find unreachable functions (defined but never called)
5. Check entry points: main, route handlers, event listeners (these are roots)

Signals:
  - Function defined but no callers in import graph
  - Export not imported by any other module
  - Commented-out code blocks (> 5 lines)
  - Code behind always-false conditions
  - Deprecated markers: @deprecated, # deprecated, TODO: remove
  - Feature flags with permanent off state
```

### Classification

| Subtype | Signal | Confidence |
|---------|--------|-----------|
| Unused export | Exported, zero imports | HIGH |
| Unreachable function | No call path from entry point | MEDIUM (may be reflection/dynamic) |
| Commented code | `//` or `#` block > 5 lines | HIGH |
| Dead branch | `if (false)`, `if (0)`, feature flag always off | HIGH |
| Deprecated | `@deprecated` marker, deprecation comment | HIGH |
| Orphan file | Source file not imported anywhere | MEDIUM (may be entry point) |

---

## 6. Tech Debt Detection

```
Signals:
  - TODO comments: `// TODO: ...`
  - FIXME comments: `// FIXME: ...`
  - HACK comments: `// HACK: ...`
  - XXX comments: `// XXX: ...`
  - Complexity indicators: deeply nested conditionals (> 4 levels)
  - Duplication: similar code blocks across files
  - Large files: > 500 lines in a single file
  - Large functions: > 50 lines in a single function
  - Magic numbers: unexplained numeric literals
  - Type assertions / casts: `as any`, `type: ignore`
  - Suppressed warnings: `eslint-disable`, `noqa`, `@SuppressWarnings`
```

---

## 7. Workaround Detection

```
Signals:
  - Comments containing: "workaround", "temporary", "hack", "hotfix"
  - Environment-specific code: `if (process.env.NODE_ENV === 'production')`
  - Version-pinned patches: specific version checks
  - Monkey-patching: prototype modification, dynamic property injection
  - Try/catch that swallows errors: empty catch blocks
  - Retry loops without proper backoff
  - Hardcoded values that should be configurable
```

---

## 8. Infrastructure Pattern Detection

```
Patterns:
  - Logging: logger.info/warn/error, console.log usage
  - Error handling: global error handler, error middleware
  - Authentication: JWT decode, session check, OAuth flow
  - Authorization: role checks, permission guards
  - Caching: Redis client, in-memory cache, cache decorators
  - Rate limiting: rate limiter middleware, token bucket
  - Health checks: /health endpoint, readiness probes
  - Metrics: Prometheus, StatsD, custom metrics
  - Configuration: env loading, config files, feature flags
  - Background jobs: queue workers, cron jobs, schedulers
```

---

## 9. Configuration Interpretation

| Config Type | SDD Implication |
|------------|----------------|
| Database connection pool size | NFR: concurrent connections |
| Request timeout values | NFR: response time |
| Cache TTL | NFR: data freshness |
| Rate limit values | NFR: throughput |
| Retry count/backoff | NFR: reliability |
| Max file upload size | Constraint requirement |
| CORS origins | Security requirement |
| JWT expiry | Security requirement |
| Log level configuration | Operational requirement |
| Feature flag defaults | Business rule documentation |
