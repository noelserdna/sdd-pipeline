# Dimension Catalog — 12 Technical Design Dimensions

> Reference document for sdd-tech-designer Phase 3 (12-Dimension Analysis).
> Each dimension defines detection rules, contextual questions, common patterns, and anti-patterns.

---

## Overview

The 12 dimensions cover the complete technical design space for a software system. Not all dimensions apply to all systems — detection rules determine applicability.

### Applicability Classification

| Status | Meaning |
|--------|---------|
| **Applicable** | Dimension is relevant to this system type |
| **Resolved** | Decision exists in ADR, spec, or CLAUDE.md |
| **Partial** | Some aspects decided, others missing |
| **Missing** | No decision found, dimension is applicable |
| **N/A** | Dimension does not apply to this system type |

---

## Dimension 1: Delivery Channels

### What It Covers

How end users interact with the system: web browser, mobile app, command-line interface, API-only (headless), desktop application, embedded UI.

### Detection Rules

```
APPLICABLE WHEN:
- Use cases involve human actors (not just system-to-system)
- Specs mention "user", "screen", "form", "dashboard", "view"
- ANY actor in system context is a human

RESOLVED WHEN:
- ADR exists selecting delivery channel(s)
- CLAUDE.md specifies frontend framework
- System context diagram shows user-facing channels

N/A WHEN:
- All actors are external systems (pure backend/integration service)
- Spec explicitly states "API-only, no UI"
```

### Question Templates

```markdown
**DIM-1-001: Primary Delivery Channel**
El sistema tiene {N} actores humanos pero no especifica cómo interactúan.

| Opción | Descripción |
|--------|-------------|
| Web SPA | Single-Page Application — rich interactivity, JS framework |
| Web SSR | Server-Side Rendered — SEO, fast first load, server-centric |
| Mobile Native | iOS/Android apps — platform APIs, offline, push notifications |
| Mobile Cross-Platform | React Native/Flutter — code sharing, native-like |
| CLI | Command-line — developers/ops, scriptable, no GUI |
| API-only | Sin UI propia — consumido por clientes externos |
| Desktop | Electron/Tauri — offline-first, native OS integration |

**Contexto:** [actores], [complejidad de interacción], [plataforma target]
```

```markdown
**DIM-1-002: Frontend Framework**
Canal web seleccionado pero sin framework.

| Opción | Descripción |
|--------|-------------|
| React + Next.js | Full-featured, SSR/SSG, grande ecosystem |
| Vue + Nuxt | Buena DX, curva menor, progressive |
| Svelte + SvelteKit | Mínimo bundle, excelente performance |
| Astro | Content-first, islands architecture, multi-framework |
| HTMX + templates | Minimal JS, hypermedia-driven |

**Contexto:** [tipo de app], [complejidad UI], [team expertise]
```

### Common Patterns

- **SPA + API Backend**: Most common for interactive apps. Clear separation of concerns.
- **SSR + Hydration**: Best for content-heavy sites with interactivity. Next.js, Nuxt, SvelteKit.
- **API-only + External consumers**: Microservice or platform play. Focus on API contracts.
- **BFF (Backend for Frontend)**: When multiple channels need different API shapes.

### Red Flags

- Specs describe complex user interactions but no UI channel is selected
- Multiple channels mentioned casually without explicit support plan
- Mobile mentioned but no offline/sync strategy
- "Web" assumed without considering accessibility and responsiveness

---

## Dimension 2: Architecture Style

### What It Covers

High-level structural organization: monolith, microservices, serverless, modular monolith, event-driven, CQRS, hexagonal.

### Detection Rules

```
APPLICABLE WHEN:
- System has more than one bounded context
- Scale targets exceed single-process capacity
- Team size > 3 developers
- Multiple deployment environments needed

RESOLVED WHEN:
- ADR exists defining service topology
- Architecture view documented with deployment strategy
- CLAUDE.md specifies architecture approach

N/A WHEN:
- System is a simple script or CLI tool
- Single-purpose utility with no scaling needs
```

### Question Templates

```markdown
**DIM-2-001: Architecture Style**
El sistema tiene {N} bounded contexts y {scale targets}. ¿Qué estilo arquitectónico?

| Opción | Descripción |
|--------|-------------|
| Modular Monolith | Un desplegable, módulos internos bien separados |
| Microservices | Servicios independientes por bounded context |
| Serverless Functions | Funciones individuales por operación/evento |
| Event-Driven | Componentes desacoplados vía eventos/mensajes |
| Hexagonal / Ports & Adapters | Core aislado, adaptadores intercambiables |

**Contexto:** [bounded contexts], [escala], [team size], [deployment platform]
```

### Common Patterns

- **Modular Monolith**: Best starting point for most projects. Migrate to microservices later if needed.
- **Microservices**: When bounded contexts have independent scaling/deployment needs and team can handle operational complexity.
- **Serverless**: Cost-effective for bursty workloads. Cold start trade-off.
- **CQRS + Event Sourcing**: When audit trail is critical or read/write patterns diverge significantly.

### Red Flags

- Choosing microservices for a small team or simple system (over-engineering)
- Monolith without internal module boundaries (will become a big ball of mud)
- Serverless for long-running processes or stateful workflows
- No architecture style selected with 5+ bounded contexts

---

## Dimension 3: Tech Stack

### What It Covers

Programming languages, frameworks, runtimes, package managers, build tools.

### Detection Rules

```
APPLICABLE WHEN:
- Always applicable (every system needs a tech stack)

RESOLVED WHEN:
- ADR exists selecting language + framework + runtime
- CLAUDE.md has "Active Technologies" with specific versions
- Existing codebase already uses a stack

N/A WHEN:
- Never N/A
```

### Question Templates

```markdown
**DIM-3-001: Primary Language & Runtime**
No hay selección de lenguaje/runtime de implementación.

| Opción | Descripción |
|--------|-------------|
| TypeScript + Node.js | Amplio ecosystem, full-stack capability |
| Python + FastAPI | Rápido para APIs, ML ecosystem |
| Go | Performance, concurrency, simple deployment |
| Rust | Maximum performance, memory safety |
| Java + Spring Boot | Enterprise-grade, mature ecosystem |
| C# + .NET | Microsoft ecosystem, enterprise |

**Contexto:** [tipo de sistema], [team expertise], [platform constraints]
```

```markdown
**DIM-3-002: Backend Framework**
Lenguaje seleccionado ({lang}) pero sin framework backend.

| Opción | Descripción |
|--------|-------------|
| {Framework options based on selected language} |

**Contexto:** [runtime], [tipo de API], [complejidad]
```

### Common Patterns

- **TypeScript everywhere**: Frontend + Backend sharing types/validation. Most popular for web.
- **Python for data**: When ML/AI/data processing is core. Use TypeScript for web layer.
- **Go for infrastructure**: Microservices, CLIs, high-concurrency backends.

### Red Flags

- Selecting a language the team doesn't know without training plan
- Multiple languages without clear justification (polyglot tax)
- Outdated framework versions or deprecated frameworks
- No build tool or package manager decision

---

## Dimension 4: Data Strategy

### What It Covers

Database selection, schema design approach, migration strategy, caching, data lifecycle.

### Detection Rules

```
APPLICABLE WHEN:
- System persists data (entities, state, files)
- Specs define domain entities or data models
- NFRs mention data retention or storage limits

RESOLVED WHEN:
- ADR exists selecting database technology
- Physical data model documented
- Migration strategy defined

N/A WHEN:
- Stateless system (pure transformation/proxy)
- All state managed by external systems
```

### Question Templates

```markdown
**DIM-4-001: Primary Database**
El domain model define {N} entities pero no hay selección de base de datos.

| Opción | Descripción |
|--------|-------------|
| PostgreSQL | Relacional completo, JSON support, extensible |
| MySQL/MariaDB | Relacional popular, replicación madura |
| MongoDB | Document store, flexible schema |
| SQLite / Turso | Lightweight, edge-compatible |
| DynamoDB | Serverless, auto-scaling, AWS-native |

**Contexto:** [entity count], [query patterns], [scale], [platform]
```

```markdown
**DIM-4-002: Migration Strategy**
Base de datos seleccionada pero sin estrategia de migrations.

| Opción | Descripción |
|--------|-------------|
| SQL migrations (up/down) | Explicit SQL files, version-controlled |
| ORM migrations | Generated from entity definitions (Prisma, Drizzle) |
| Schema-as-code | Declarative schema, diffed on deploy |

**Contexto:** [database], [ORM/query builder], [deploy strategy]
```

```markdown
**DIM-4-003: Caching Strategy**
NFR define targets de latencia pero no hay estrategia de caching.

| Opción | Descripción |
|--------|-------------|
| Redis / Valkey | Full-featured, pub/sub, TTL |
| In-memory (application) | Simple, per-instance, no shared state |
| CDN / Edge cache | For static or semi-static content |
| No caching needed | Latency targets met without cache |

**Contexto:** [latency targets], [data access patterns], [read/write ratio]
```

### Common Patterns

- **PostgreSQL + Prisma/Drizzle**: Most versatile for web apps. SQL migrations.
- **Redis for caching + sessions**: Fast, flexible, widely supported.
- **Event sourcing + projections**: When audit trail is business-critical.
- **Multi-database**: OLTP + OLAP separation for analytics-heavy systems.

### Red Flags

- NoSQL selected without understanding query patterns (may need joins later)
- No migration strategy (schema changes will be painful)
- Caching everything without invalidation strategy
- No backup/restore strategy for production data

---

## Dimension 5: Auth & Security

### What It Covers

Authentication model, authorization model, encryption, compliance requirements, security patterns.

### Detection Rules

```
APPLICABLE WHEN:
- System has user authentication
- System handles sensitive data
- NFRs mention security, compliance, or encryption
- Security audit exists with findings

RESOLVED WHEN:
- ADR exists for auth model (JWT, session, OAuth)
- Security architecture documented
- Encryption strategy defined

N/A WHEN:
- Internal tool with no authentication
- Public read-only API with no sensitive data
```

### Question Templates

```markdown
**DIM-5-001: Authentication Model**
El spec define usuarios pero no especifica mecanismo de autenticación.

| Opción | Descripción |
|--------|-------------|
| JWT (stateless) | Tokens auto-contenidos, scalable |
| Session-based | Server-side sessions, simpler revocation |
| OAuth 2.0 / OIDC | Delegated auth, social login, SSO |
| API Keys | Simple, for service-to-service |
| Passwordless (magic links) | No passwords, email/SMS based |

**Contexto:** [tipo de usuarios], [multi-tenant], [compliance requirements]
```

```markdown
**DIM-5-002: Authorization Model**
Autenticación definida pero sin modelo de autorización detallado.

| Opción | Descripción |
|--------|-------------|
| RBAC (Role-Based) | Roles con permisos predefinidos |
| ABAC (Attribute-Based) | Policies basadas en atributos |
| ACL (Access Control Lists) | Per-resource permissions |
| Simple (admin/user) | Dos niveles, suficiente para apps simples |

**Contexto:** [roles definidos], [complejidad de permisos], [multi-tenant]
```

### Common Patterns

- **JWT + RBAC**: Most common for web APIs. Stateless, scalable.
- **OAuth 2.0 + OIDC**: When SSO or third-party login is needed.
- **mTLS + API Keys**: For service-to-service communication.

### Red Flags

- No encryption at rest for sensitive data
- JWT without rotation/revocation strategy
- Missing CSRF protection on state-changing endpoints
- No security audit or threat model

---

## Dimension 6: API Design

### What It Covers

API style, versioning, documentation, rate limiting, error handling conventions.

### Detection Rules

```
APPLICABLE WHEN:
- System exposes APIs (internal or external)
- Contracts/ directory exists with endpoint definitions
- Multiple clients consume the API

RESOLVED WHEN:
- API contracts fully specify style, versioning, errors
- ADR exists for API design decisions
- OpenAPI/GraphQL schema exists

N/A WHEN:
- No API (standalone CLI, desktop app, embedded system)
```

### Question Templates

```markdown
**DIM-6-001: API Style**
Los contratos definen {N} endpoints pero no especifican estilo de API.

| Opción | Descripción |
|--------|-------------|
| REST (JSON) | Universal, well-understood, cacheable |
| GraphQL | Flexible queries, single endpoint, typed |
| gRPC | High-performance, binary, strongly typed |
| tRPC | End-to-end type safety, TypeScript-native |

**Contexto:** [client types], [query complexity], [performance needs]
```

### Common Patterns

- **REST + OpenAPI**: Standard for public APIs. Well-tooled.
- **GraphQL**: When clients need flexible data fetching (mobile, dashboards).
- **tRPC**: TypeScript monorepos where client and server share types.

### Red Flags

- No API versioning strategy
- Missing error response conventions
- No rate limiting for public APIs
- Inconsistent endpoint naming

---

## Dimension 7: Infrastructure

### What It Covers

Cloud provider, compute model, containerization, Infrastructure as Code.

### Detection Rules

```
APPLICABLE WHEN:
- System needs deployment (always, unless pure library)
- Scale targets defined in NFRs
- Multi-environment needed (dev, staging, prod)

RESOLVED WHEN:
- ADR exists for cloud provider and compute model
- Deployment configuration exists (Dockerfile, terraform, etc.)
- CLAUDE.md specifies hosting platform

N/A WHEN:
- Library or package (no deployment)
- Deployed by consumer (npm package, etc.)
```

### Question Templates

```markdown
**DIM-7-001: Compute Model**
No hay decisión sobre modelo de cómputo.

| Opción | Descripción |
|--------|-------------|
| Containers (Docker + K8s) | Flexible, portable, industry standard |
| Serverless (Lambda/Functions) | Pay-per-use, auto-scale, cold starts |
| PaaS (Heroku, Railway, Fly) | Simple deploy, managed infrastructure |
| Edge (Cloudflare Workers, Vercel) | Global distribution, low latency |
| VPS (traditional) | Full control, predictable cost |

**Contexto:** [scale targets], [budget], [team ops expertise]
```

### Common Patterns

- **Docker + K8s**: Enterprise standard. Complex but powerful.
- **Serverless**: Cost-effective for variable workloads. AWS Lambda, Cloudflare Workers.
- **PaaS**: Best for small teams. Railway, Fly.io, Render.

### Red Flags

- No Infrastructure as Code (manual deployment)
- Single region for global users
- No disaster recovery plan
- Over-provisioned infrastructure for expected load

---

## Dimension 8: CI/CD Pipeline

### What It Covers

Build pipeline, test automation, deployment strategy, environment management.

### Detection Rules

```
APPLICABLE WHEN:
- System will be deployed (always for services)
- Team size > 1 (need consistent builds)
- Multiple environments needed

RESOLVED WHEN:
- CI/CD config exists (.github/workflows, etc.)
- ADR exists for deployment strategy
- Build/test/deploy pipeline documented

N/A WHEN:
- Personal project with manual deployment (not recommended but possible)
```

### Question Templates

```markdown
**DIM-8-001: CI/CD Platform**
No hay pipeline de CI/CD definido.

| Opción | Descripción |
|--------|-------------|
| GitHub Actions | Native to GitHub, YAML-based, extensive marketplace |
| GitLab CI | Built-in, Docker-native, self-hostable |
| CircleCI | Fast, parallelism, Docker layer caching |
| Jenkins | Self-hosted, maximum flexibility |

**Contexto:** [code hosting], [team preference], [complexity needs]
```

```markdown
**DIM-8-002: Deployment Strategy**
CI/CD definido pero sin estrategia de deploy.

| Opción | Descripción |
|--------|-------------|
| Blue-Green | Zero-downtime, instant rollback |
| Canary | Gradual rollout, risk mitigation |
| Rolling | Incremental update, resource efficient |
| Direct deploy | Simple, for low-risk environments |

**Contexto:** [availability requirements], [rollback needs], [infrastructure]
```

### Common Patterns

- **GitHub Actions + Docker**: Most popular for open source and startups.
- **GitLab CI + K8s**: Common for enterprise, self-hosted Git.

### Red Flags

- No automated tests in CI
- Manual deployment to production
- No rollback strategy
- Single environment (no staging)

---

## Dimension 9: Observability

### What It Covers

Logging, monitoring, alerting, distributed tracing, SLOs/SLIs.

### Detection Rules

```
APPLICABLE WHEN:
- System runs in production (any deployed service)
- SLOs or uptime targets defined in NFRs
- Multiple services or external integrations

RESOLVED WHEN:
- Observability stack selected and documented
- SLOs mapped to SLIs
- Alerting rules defined

N/A WHEN:
- Development tool or CLI (no production runtime)
```

### Question Templates

```markdown
**DIM-9-001: Observability Stack**
No hay stack de observabilidad seleccionado.

| Opción | Descripción |
|--------|-------------|
| Datadog | Full-stack, APM, logs, metrics, expensive |
| Grafana + Prometheus + Loki | Open source, flexible, self-managed |
| AWS CloudWatch | AWS-native, integrated, adequate |
| Sentry + custom metrics | Error tracking focus, lightweight |
| OpenTelemetry + backend | Vendor-neutral instrumentation |

**Contexto:** [budget], [complexity], [SLO targets]
```

### Common Patterns

- **OpenTelemetry → Grafana Stack**: Vendor-neutral, open source, flexible.
- **Datadog all-in-one**: Higher cost but lower operational burden.

### Red Flags

- No logging in production
- Alerts without runbooks
- SLOs defined but no SLIs instrumented
- No distributed tracing with microservices

---

## Dimension 10: Cost & Scaling

### What It Covers

Infrastructure cost estimation, scaling strategy, budget constraints.

### Detection Rules

```
APPLICABLE WHEN:
- System will run in production (any hosted service)
- Scale targets defined in NFRs
- Budget constraints exist

RESOLVED WHEN:
- Cost estimates documented
- Scaling strategy defined (horizontal, vertical, auto)
- Resource budgets per environment set

N/A WHEN:
- Open source library or tool
- Free tier covers all needs
```

### Question Templates

```markdown
**DIM-10-001: Scaling Strategy**
NFR define {targets} pero no hay estrategia de escalado.

| Opción | Descripción |
|--------|-------------|
| Horizontal auto-scale | Add instances based on load metrics |
| Vertical scaling | Upgrade instance size |
| Serverless auto-scale | Platform handles scaling automatically |
| Static provisioning | Fixed capacity, sufficient for expected load |

**Contexto:** [load targets], [cost constraints], [traffic patterns]
```

### Common Patterns

- **Start fixed, then auto-scale**: Don't over-engineer scaling day 1.
- **Serverless for variable load**: Cost-effective when traffic is unpredictable.

### Red Flags

- No cost estimation before going to production
- Over-provisioned for actual needs
- No scaling plan for 10x growth
- Ignoring data transfer costs

---

## Dimension 11: Developer Experience

### What It Covers

Repository structure, local development setup, tooling, code quality automation.

### Detection Rules

```
APPLICABLE WHEN:
- Team size > 1 developer
- Multiple modules or packages
- Onboarding new developers is a concern

RESOLVED WHEN:
- CLAUDE.md has development setup section
- Contributing guide exists
- Build/test commands documented

N/A WHEN:
- Solo developer with simple project
```

### Question Templates

```markdown
**DIM-11-001: Repository Structure**
No hay decisión sobre estructura de repositorio.

| Opción | Descripción |
|--------|-------------|
| Monorepo (Turborepo/Nx) | Código compartido, atomic changes, build caching |
| Multi-repo | Independencia total, deploy independiente |
| Monorepo simple | Un repo, sin herramienta de monorepo |

**Contexto:** [number of packages], [team size], [deploy independence needs]
```

### Common Patterns

- **Monorepo + Turborepo**: For TypeScript projects with shared packages.
- **Multi-repo + API contracts**: When teams are independent and services well-bounded.

### Red Flags

- No documented setup process (CLAUDE.md or README)
- No linting or formatting automation
- No pre-commit hooks
- Inconsistent tooling across modules

---

## Dimension 12: i18n & Accessibility

### What It Covers

Internationalization, localization, WCAG accessibility, RTL support.

### Detection Rules

```
APPLICABLE WHEN:
- System has user-facing UI
- Multiple languages or regions mentioned in specs
- NFRs mention accessibility or WCAG compliance
- Users include people with disabilities

RESOLVED WHEN:
- i18n strategy documented (library, string management)
- Accessibility requirements specified (WCAG level)
- Language/locale list defined

N/A WHEN:
- API-only system with no UI
- Internal tool for single-language team
- CLI without accessibility concerns
```

### Question Templates

```markdown
**DIM-12-001: Internationalization**
El sistema tiene usuarios en múltiples regiones/idiomas.

| Opción | Descripción |
|--------|-------------|
| Full i18n from day 1 | i18n library, string keys, locale files |
| English-only, i18n-ready | Code structure supports i18n, add later |
| Single language | No i18n needed |

**Contexto:** [target markets], [user languages], [timeline]
```

```markdown
**DIM-12-002: Accessibility Level**
El sistema tiene UI pero no especifica nivel de accesibilidad.

| Opción | Descripción |
|--------|-------------|
| WCAG 2.1 AA (Recomendado) | Industry standard, legal compliance in many jurisdictions |
| WCAG 2.1 A | Minimum, basic accessibility |
| WCAG 2.1 AAA | Maximum, specialized audiences |
| No specific target | Best-effort accessibility |

**Contexto:** [target audience], [legal requirements], [industry]
```

### Common Patterns

- **react-intl / next-intl**: Standard for React i18n.
- **WCAG 2.1 AA**: Default target for most web apps.

### Red Flags

- UI built without i18n and later needs multiple languages (expensive retrofit)
- No accessibility testing in CI
- Hardcoded strings throughout codebase
- No keyboard navigation support

---

## Dimension Priority Matrix

When multiple dimensions need decisions, prioritize by system impact:

| Priority | Dimension | Rationale |
|----------|-----------|-----------|
| 1 | Delivery Channels | Determines entire frontend architecture |
| 2 | Architecture Style | Shapes system structure |
| 3 | Tech Stack | Blocks all implementation |
| 4 | Data Strategy | Shapes all persistence |
| 5 | Auth & Security | Must be built-in, not bolted-on |
| 6 | API Design | Defines system contracts |
| 7 | Infrastructure | Deployment decisions |
| 8 | CI/CD Pipeline | Development workflow |
| 9 | Observability | Operational readiness |
| 10 | Cost & Scaling | Resource planning |
| 11 | Developer Experience | Team productivity |
| 12 | i18n & Accessibility | UX completeness |
