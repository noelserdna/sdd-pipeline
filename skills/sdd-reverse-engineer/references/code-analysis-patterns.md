# Code Analysis Patterns (Phase 3)

Framework idioms (ORM decorators, route declarations, DTOs) are recognised as usual; this file lists only what to extract and how to classify it.

| Artifact | Signals | Classify as |
|----------|---------|-------------|
| Entity | ORM model/annotation, class or struct with identity field | `02-ENTITIES.md` |
| Value object / enum | Immutable type, record/dataclass without identity, enum | `03-VALUE-OBJECTS.md` |
| Route | Router/decorator/mapping declaration | `contracts/API-{module}.md`: method, path, params, request/response schema, middleware (auth, validation, rate limit), status codes |
| State machine | Status enum + guarded assignments (`if status !== X throw`), switch on state, state-pattern classes, XState | `04-STATES.md`: states, transitions, guards, side effects |
| Invariant | Validation schemas (Zod/Joi/Pydantic/class-validator), guard throws, assertions, DB unique/FK/cascade, TTL checks | `05-INVARIANTS.md` |
| Config value | Timeouts, pool size, cache TTL, rate limits, retries, upload size, CORS, token expiry | `nfr/*.md` + `VALUE-REGISTRY.md` |
| Feature flag | Flag lookup around behavior | Requirement with `[FEATURE-FLAG: name]`; always-off → `[DEAD-CODE]` |

## Findings detection

| Marker | Signals | Confidence notes |
|--------|---------|------------------|
| `[DEAD-CODE]` | Export never imported; function with no call path from entry points (main, handlers, listeners, jobs); commented block > 5 lines; always-false branch; `@deprecated` | Unreachable-by-graph and orphan files are MEDIUM: reflection, DI and framework conventions can call them |
| `[TECH-DEBT]` | TODO/FIXME/HACK/XXX; nesting > 4; file > 500 lines; function > 50 lines; duplication; magic numbers; `as any`, `type: ignore`, lint suppressions | Severity by blast radius |
| `[WORKAROUND]` | "workaround/temporary/hotfix" comments; env-specific branches; version checks; monkey-patching; empty catch; retry without backoff; hard-coded values that belong in config | |
| `[INFRASTRUCTURE]` | Logging, global error handler, auth/authz guards, caching, rate limiting, health checks, metrics, config loading, background jobs | |
| `[IMPLICIT-RULE]` | Business conditionals with no named rule, doc or domain error | |

Generated code (ORM from schema, clients from OpenAPI): trace to the generator input, not the output.
