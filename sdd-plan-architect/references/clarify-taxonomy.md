# Clarify Taxonomy — Implementation Gap Categories

> Reference document for sdd-plan-architect Phase 2 (Clarify for Implementation).
> Each category defines what it detects, how to detect it, context-aware checks, and question templates.

---

## Overview

The Clarify Taxonomy defines **10 implementation-gap categories** that bridge the distance between "what the system does" (specs) and "how to build it" (plan). Unlike audit categories that detect spec defects, clarify categories detect **decisions not yet made** for implementation.

### Classification

For each category, specs are classified as:

| Status | Meaning |
|--------|---------|
| **Resolved** | Decision exists in ADR, spec, or CLARIFICATIONS.md |
| **Partial** | Some aspects decided, others missing |
| **Missing** | No decision found anywhere in specs |

### Rules

1. **Context-aware**: Read ADRs and existing decisions BEFORE generating questions
2. **Max 10 candidates**: Generate at most 10 candidate questions across all categories
3. **Max 5 asked**: Present at most 5 questions to the user (prioritize by impact)
4. **One at a time**: Present ONE question with recommended answer + alternatives
5. **Early termination**: Accept "done", "proceed", "skip" to end clarify phase

---

## CL-TECH: Technology Stack

### What It Detects

Missing or incomplete technology choices for implementation: languages, frameworks, runtimes, package managers, build tools.

### Detection Rules

```
SCAN FOR:
- ADR with tag "technology" or "stack" or "framework" → Resolved
- CLAUDE.md "Active Technologies" section → Resolved
- FASE files mentioning specific technologies → Partial
- Specs referencing technology without selection → Missing
- [DECISION PENDIENTE] related to tech choices → Missing

SKIP IF:
- ADR exists selecting language + framework + runtime
- CLAUDE.md has "Active Technologies" with specific versions
```

### Context-Aware Checks

1. Read all ADR files with `technology|stack|framework|runtime|language` in content
2. Read CLAUDE.md for "Active Technologies" section
3. Read FASE-0 (bootstrap) for technology decisions
4. Read nfr/ for technology constraints (compatibility, licensing)

### Question Templates

```markdown
**CL-TECH-001: Primary Language & Runtime**
El spec define contratos de API y modelos de dominio pero no especifica
lenguaje/runtime de implementación.

| Opción | Descripción |
|--------|-------------|
| TypeScript + Node.js (Recomendado) | Alineado con ecosystem Cloudflare Workers |
| TypeScript + Deno | Alternative runtime with built-in TypeScript |
| Go | Performance-oriented, strong typing |
| Rust + WASM | Maximum performance on Workers |

**Contexto:** [ADRs encontrados], [tecnologías ya decididas]
```

```markdown
**CL-TECH-002: HTTP Framework**
Los contratos API definen {N} endpoints pero no hay selección de framework HTTP.

| Opción | Descripción |
|--------|-------------|
| Hono (Recomendado) | Lightweight, Workers-native, TypeScript-first |
| itty-router | Minimal, Workers-optimized |
| Express (vía adapter) | Familiar but heavier |

**Contexto:** [runtime seleccionado], [constraints de plataforma]
```

---

## CL-ARCH: Architecture Topology

### What It Detects

Undefined deployment topology, scaling strategy, and service boundaries.

### Detection Rules

```
SCAN FOR:
- ADR with "architecture" or "deployment" or "monolith" or "microservice" → Resolved
- System context diagram with deployment info → Partial
- NFR/PERFORMANCE with scaling targets but no topology → Missing
- Bounded contexts defined but not mapped to services → Missing

SKIP IF:
- ADR exists defining service topology (monolith vs micro vs modular monolith)
- Deployment view documented in architecture artifacts
```

### Context-Aware Checks

1. Read 01-SYSTEM-CONTEXT.md for bounded contexts
2. Read ADRs with `architecture|topology|deploy|scale|monolith|microservice`
3. Read nfr/PERFORMANCE.md for scaling targets
4. Read FASE-0 for deployment platform decisions

### Question Templates

```markdown
**CL-ARCH-001: Service Topology**
El spec define {N} bounded contexts. ¿Cómo se mapean a servicios desplegables?

| Opción | Descripción |
|--------|-------------|
| Modular Monolith (Recomendado) | Un desplegable, módulos internos por bounded context |
| Microservices | Un servicio por bounded context |
| Serverless Functions | Una función por use case o grupo de UCs |

**Contexto:** [bounded contexts], [plataforma target], [escala esperada]
```

```markdown
**CL-ARCH-002: Scaling Strategy**
NFR define {targets} pero no hay estrategia de escalado.

| Opción | Descripción |
|--------|-------------|
| Horizontal auto-scale (Recomendado) | Workers scale automáticamente |
| Vertical (upgrade tier) | Simple, limited ceiling |
| Queue-based load leveling | Para cargas async (extractions) |

**Contexto:** [NFR targets], [workload profile]
```

---

## CL-DATA: Physical Data Model

### What It Detects

Gaps between the logical domain model (entities, VOs, states) and physical storage implementation (tables, indexes, partitioning, migrations).

### Detection Rules

```
SCAN FOR:
- ADR with "database" or "storage" or "schema" or "migration" → Resolved
- domain/ entities with storage annotations → Partial
- Entities without primary key strategy → Missing
- Multi-tenant isolation strategy undefined → Missing
- No migration strategy specified → Missing

SKIP IF:
- ADR exists selecting database technology + schema strategy
- Physical data model documented in architecture artifacts
```

### Context-Aware Checks

1. Read domain/02-ENTITIES.md for entity list and relationships
2. Read domain/03-VALUE-OBJECTS.md for embedded vs referenced VOs
3. Read ADRs with `database|storage|d1|sqlite|r2|kv|migration`
4. Read domain/05-INVARIANTS.md for uniqueness/referential constraints
5. Read CLAUDE.md for selected storage technologies

### Question Templates

```markdown
**CL-DATA-001: Multi-Tenant Data Isolation**
El spec define multi-tenancy con Organizaciones pero no especifica
estrategia de aislamiento a nivel de datos.

| Opción | Descripción |
|--------|-------------|
| Row-level (org_id column) (Recomendado) | Simple, un DB, filtrado por org_id |
| Schema-per-tenant | Aislamiento fuerte, complejidad en migrations |
| Database-per-tenant | Máximo aislamiento, máxima complejidad |

**Contexto:** [tecnología DB], [número esperado de tenants], [requisitos de aislamiento]
```

```markdown
**CL-DATA-002: ID Generation Strategy**
Las entidades definen IDs pero no el mecanismo de generación.

| Opción | Descripción |
|--------|-------------|
| UUIDv7 (Recomendado) | Sortable by time, no coordination needed |
| ULID | Similar to UUIDv7, string-sortable |
| CUID2 | Collision-resistant, URL-safe |
| Auto-increment | Simple but leaks info, not distributed |

**Contexto:** [entities count], [distributed requirements], [URL exposure]
```

---

## CL-INTEG: Integration Patterns

### What It Detects

Undefined communication protocols, message formats, error handling, and retry strategies for external system integrations.

### Detection Rules

```
SCAN FOR:
- contracts/ with external system references → check for protocol details
- workflows/ with external calls → check for error handling
- ADR with "integration" or "api-client" or "webhook" → Resolved
- Event schemas without delivery guarantee → Missing
- External system timeout/retry not specified → Missing

SKIP IF:
- Integration contracts fully specify protocol + error handling + retries
- ADR exists for each external system integration
```

### Context-Aware Checks

1. Read contracts/ for external API references
2. Read workflows/ for external system interactions
3. Read ADRs with `integration|webhook|callback|external|llm|anthropic`
4. Read domain events for delivery guarantees

### Question Templates

```markdown
**CL-INTEG-001: LLM API Integration Pattern**
El spec define extracción vía LLM con primary→fallback pero no especifica
el patrón de integración concreto.

| Opción | Descripción |
|--------|-------------|
| Direct HTTP + Circuit Breaker (Recomendado) | Simple, resiliente, observable |
| SDK wrapper | Usa @anthropic-ai/sdk con retry built-in |
| Queue-mediated | Desacopla request de processing |

**Contexto:** [LLM provider], [timeout specs], [fallback strategy]
```

---

## CL-PERF: Performance Strategy

### What It Detects

NFR performance targets without concrete implementation strategies (caching, connection pooling, query optimization, CDN).

### Detection Rules

```
SCAN FOR:
- nfr/PERFORMANCE.md with targets → check for strategies
- nfr/LIMITS.md with rate limits → check for implementation
- ADR with "cache" or "performance" or "optimization" → Resolved
- Latency targets without caching strategy → Missing
- Throughput targets without capacity plan → Missing

SKIP IF:
- Performance ADRs cover caching, connection management, query optimization
- Implementation strategies documented for each NFR target
```

### Context-Aware Checks

1. Read nfr/PERFORMANCE.md for targets (p99, throughput)
2. Read nfr/LIMITS.md for rate limits and system limits
3. Read ADRs with `cache|performance|latency|throughput|rate-limit`
4. Cross-check: each target should have at least one strategy

### Question Templates

```markdown
**CL-PERF-001: Caching Strategy**
NFR define p99 latency targets pero no hay estrategia de caching.

| Opción | Descripción |
|--------|-------------|
| Cloudflare KV + Cache API (Recomendado) | Edge caching, global distribution |
| In-memory (Workers) | Request-scoped only, no persistence |
| External Redis | Full-featured, extra hop |

**Contexto:** [latency targets], [data access patterns], [platform]
```

---

## CL-SEC: Security Implementation

### What It Detects

Security specifications (encryption, auth, RBAC) without concrete library/pattern selection.

### Detection Rules

```
SCAN FOR:
- nfr/SECURITY.md specifying controls → check for library selection
- ADR-002 (encryption) → check for specific library
- Auth specs → check for JWT/session library
- RBAC specs → check for enforcement mechanism
- Audit logging → check for storage + format

SKIP IF:
- Security ADRs specify concrete libraries and patterns
- Security implementation documented in architecture
```

### Context-Aware Checks

1. Read nfr/SECURITY.md for security requirements
2. Read ADR-002 and related security ADRs
3. Read domain/05-INVARIANTS.md for security invariants
4. Read runbooks/ for operational security procedures

### Question Templates

```markdown
**CL-SEC-001: Authentication Library**
El spec define autenticación JWT multi-tenant pero no selecciona biblioteca.

| Opción | Descripción |
|--------|-------------|
| jose (Recomendado) | Standards-compliant, Workers-compatible |
| jsonwebtoken | Popular, needs polyfills for Workers |
| Custom HMAC | Minimal, full control, more testing |

**Contexto:** [auth spec], [platform constraints], [token requirements]
```

---

## CL-CICD: Build & Deploy Pipeline

### What It Detects

Missing CI/CD pipeline definition, deployment strategy, environment management.

### Detection Rules

```
SCAN FOR:
- .github/workflows/ or CI config → Resolved
- ADR with "cicd" or "deploy" or "pipeline" → Resolved
- FASE files mentioning deploy steps → Partial
- No CI/CD config and no ADR → Missing
- Multiple environments mentioned but not defined → Missing

SKIP IF:
- CI/CD pipeline defined in code or ADR
- Deployment strategy documented (blue-green, canary, rolling)
```

### Context-Aware Checks

1. Check for .github/workflows/, .gitlab-ci.yml, or similar
2. Read ADRs with `cicd|pipeline|deploy|release|environment`
3. Read runbooks/ for deployment procedures
4. Read FASE-0 for bootstrap/deploy decisions

### Question Templates

```markdown
**CL-CICD-001: Deployment Strategy**
No hay estrategia de deployment definida.

| Opción | Descripción |
|--------|-------------|
| Wrangler direct deploy (Recomendado) | Simple, Cloudflare-native |
| GitHub Actions + Wrangler | Automated CI/CD pipeline |
| Terraform + Wrangler | Infrastructure as Code |

**Contexto:** [platform], [environment count], [team size]
```

---

## CL-OBS: Observability & Ops

### What It Detects

Missing monitoring, logging, alerting, and operational readiness specifications.

### Detection Rules

```
SCAN FOR:
- nfr/OBSERVABILITY.md or similar → check completeness
- ADR with "logging" or "monitoring" or "alerting" → Resolved
- runbooks/ with operational procedures → Partial
- SLOs defined but no SLI implementation → Missing
- Error codes defined but no alerting rules → Missing

SKIP IF:
- Observability stack selected and documented
- SLOs have corresponding SLI implementation strategy
- Alerting rules mapped to error conditions
```

### Context-Aware Checks

1. Read nfr/ for observability/monitoring specs
2. Read runbooks/ for operational procedures
3. Read ADRs with `logging|monitoring|observability|alert|slo|sli`
4. Read contracts/ for error code definitions

### Question Templates

```markdown
**CL-OBS-001: Logging Strategy**
El spec define eventos de dominio y audit trail pero no selecciona
stack de logging.

| Opción | Descripción |
|--------|-------------|
| Workers Logpush + R2 (Recomendado) | Native, cost-effective, queryable |
| Structured JSON → external SIEM | Enterprise-grade, extra cost |
| Console.log + Tail Workers | Minimal, development-friendly |

**Contexto:** [event types], [retention requirements], [compliance needs]
```

---

## CL-TEST: Test Implementation

### What It Detects

Missing test framework, test environment, and test data strategy decisions.

### Detection Rules

```
SCAN FOR:
- tests/ with BDD specs → check for framework selection
- ADR with "test" or "testing" → Resolved
- Property tests defined but no framework selected → Missing
- BDD scenarios without runner/framework → Missing
- No test environment strategy → Missing

SKIP IF:
- Test framework selected and documented
- Test environment (local, CI, staging) defined
- Test data strategy documented
```

### Context-Aware Checks

1. Read tests/ directory structure
2. Read ADRs with `test|testing|bdd|property|coverage`
3. Check for existing test config files (jest.config, vitest.config, etc.)
4. Read FASE files for test-related specs

### Question Templates

```markdown
**CL-TEST-001: Test Framework**
El spec define BDD scenarios y property tests pero no selecciona framework.

| Opción | Descripción |
|--------|-------------|
| Vitest (Recomendado) | Fast, ESM-native, Workers-compatible |
| Jest + miniflare | Popular, needs config for Workers |
| Node test runner | Zero-dep, built-in, limited features |

**Contexto:** [test types defined], [runtime], [BDD scenario count]
```

---

## CL-COST: Cost & Resources

### What It Detects

Missing infrastructure cost estimation, resource budgets, and scaling cost projections.

### Detection Rules

```
SCAN FOR:
- nfr/ with cost targets or budgets → Resolved
- ADR with "cost" or "budget" or "pricing" → Resolved
- nfr/LIMITS.md with scale targets → check for cost projection
- Storage volume estimates → Missing if not quantified
- API call volume estimates → Missing if not costed

SKIP IF:
- Cost estimates documented for selected infrastructure
- Scaling cost projections available
- Resource budgets defined per environment
```

### Context-Aware Checks

1. Read nfr/LIMITS.md for scale targets
2. Read ADRs with `cost|budget|pricing|resource`
3. Read CLAUDE.md for infrastructure selections
4. Cross-reference: scale targets × unit costs

### Question Templates

```markdown
**CL-COST-001: Infrastructure Budget**
NFR define targets de escala pero no hay estimación de costos de infraestructura.

| Opción | Descripción |
|--------|-------------|
| Estimate from LIMITS.md (Recomendado) | Derivar de targets existentes × pricing |
| Fixed budget constraint | Definir presupuesto y ajustar arquitectura |
| Pay-as-you-go uncapped | Sin restricción, optimizar después |

**Contexto:** [scale targets], [platform pricing], [storage volumes]
```

---

## Priority Ordering

When multiple categories have **Missing** status, prioritize by implementation impact:

| Priority | Category | Rationale |
|----------|----------|-----------|
| 1 | CL-TECH | Blocks everything else |
| 2 | CL-DATA | Shapes all persistence |
| 3 | CL-ARCH | Defines system structure |
| 4 | CL-SEC | Security must be built-in |
| 5 | CL-INTEG | External dependencies |
| 6 | CL-PERF | Performance strategies |
| 7 | CL-TEST | Test infrastructure |
| 8 | CL-CICD | Build & deploy |
| 9 | CL-OBS | Operational readiness |
| 10 | CL-COST | Cost awareness |

---

## Deduplication with ADRs

Before generating a question:

1. **Search ADRs**: Glob `adr/ADR-*.md` and grep for category keywords
2. **Search CLARIFICATIONS.md**: Check for relevant RN-xxx rules
3. **Search CLAUDE.md**: Check "Active Technologies" and recent changes
4. **If decision found**: Mark category as Resolved, skip question
5. **If partial**: Generate question only for the undecided portion
6. **Log skipped**: Record in CLARIFY-LOG.md why category was skipped

```markdown
### Skipped Categories

| Category | Status | Evidence |
|----------|--------|----------|
| CL-TECH | Resolved | ADR-001 (TypeScript + Hono), CLAUDE.md Active Technologies |
| CL-DATA | Partial | ADR selects D1/R2 but no migration strategy |
```
