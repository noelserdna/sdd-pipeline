# Dimension Catalog — 12 Technical Design Dimensions (Phase 3)

Each dimension lists detection rules (Applicable / Resolved / N/A), its question IDs (`DIM-{d}-{nnn}`) with the
option set to offer, and red flags to raise. Write question text and option notes in the user's language; add a
one-clause note per option only where the trade-off is not obvious. Always put the recommended option first and
fill the **Context** line from the specs.

Status per dimension: **Resolved** (decision exists in an ADR, spec, CLAUDE.md or code) · **Partial** (some
questions resolved) · **Missing** (applicable, nothing decided) · **N/A**.

**Stack already decided.** With a Stack Profile (CLAUDE.md `## SDD Stack Profile`), an installed kit
(`templates/stacks/<kit>`, `## Stack Conventions`) or an accepted stack ADR, DIM-1-002, DIM-3-001 and DIM-3-002
are Resolved: show the evidence, recommend what was chosen and do not reopen the question. Recommendations in the
other dimensions (data, auth, CI, infra) must be compatible with that stack.

Order when several dimensions are open: 1 → 12 (delivery and style shape everything after them).

---

## DIM-1 Delivery Channels

- **Applicable:** any human actor in the use cases; specs mention screens, forms, dashboards, views.
- **Resolved:** ADR selecting channels; CLAUDE.md names a frontend framework; context diagram shows user channels.
- **N/A:** all actors are external systems; spec says "API-only, no UI".

| ID | Question | Options |
|----|----------|---------|
| DIM-1-001 | Primary delivery channel ({N} human actors, channel unspecified) | Web SPA · Web SSR · Mobile native · Mobile cross-platform · CLI · API-only · Desktop (Electron/Tauri) |
| DIM-1-002 | Frontend framework (web chosen, no framework) | Next.js App Router full-stack (Server Components + Server Actions, progressive-enhancement forms; no own HTTP API without external clients) · Rails + Hotwire full-stack (forms work without JS) · React/Next.js SPA/SSG + API · Vue/Nuxt · SvelteKit · Astro · HTMX + templates |

Context: actors, interaction complexity, target platform, team expertise.

Red flags: complex interactions with no UI channel chosen; several channels mentioned without a support plan;
mobile without an offline/sync strategy.

## DIM-2 Architecture Style

- **Applicable:** >1 bounded context; scale beyond one process; team > 3; several deployment environments.
- **Resolved:** ADR defining service topology; documented deployment view; CLAUDE.md states the approach.
- **N/A:** simple script or single-purpose CLI.

| ID | Question | Options |
|----|----------|---------|
| DIM-2-001 | Architecture style ({N} bounded contexts, {scale}) | Modular monolith · Microservices · Serverless functions · Event-driven · Hexagonal |

Context: bounded contexts, scale, team size, deployment platform.

Red flags: microservices for a small team or simple system; monolith without module boundaries; serverless for
long-running or stateful workflows; no style chosen with 5+ bounded contexts.

## DIM-3 Tech Stack

- **Applicable:** always.
- **Resolved:** stack ADR; CLAUDE.md "Active Technologies" with versions, `## SDD Stack Profile` or
  `## Stack Conventions`; installed kit; existing codebase.

| ID | Question | Options |
|----|----------|---------|
| DIM-3-001 | Language & runtime | TypeScript/Node · Ruby/Rails · Python/FastAPI · Go · Rust · Java/Spring Boot · C#/.NET |
| DIM-3-002 | Backend framework for {lang} | Ruby: Rails (REST resources, Active Record, Hotwire; `form_with`/`button_to` without JS) · Sinatra/Hanami. TypeScript: Next.js App Router (Route Handlers only for external HTTP clients) · Fastify/Hono/NestJS (pure HTTP API, `Style: http` contracts). Others: the language's mainstream options |

Context: system type, team expertise, platform constraints.

Red flags: language the team does not know without a plan; polyglot without justification; deprecated
framework versions; no package manager / build tool decision.

## DIM-4 Data Strategy

- **Applicable:** the system persists data; specs define entities; NFRs mention retention or storage.
- **Resolved:** database ADR; physical data model; migration strategy defined.
- **N/A:** stateless transformation/proxy; all state held by external systems.

| ID | Question | Options |
|----|----------|---------|
| DIM-4-001 | Primary database ({N} entities) | PostgreSQL · MySQL/MariaDB · MongoDB · SQLite/Turso · DynamoDB |
| DIM-4-002 | Migration strategy | SQL up/down files · ORM-generated (Prisma, Drizzle, Active Record) · Declarative schema-as-code |
| DIM-4-003 | Caching (latency targets exist) | Redis/Valkey · In-process · CDN/edge · None needed |

Context: entity count, query patterns, read/write ratio, scale, platform.

Red flags: NoSQL chosen without knowing query patterns; no migration strategy; caching without invalidation; no
backup/restore strategy.

## DIM-5 Auth & Security

- **Applicable:** user authentication; sensitive data; NFRs mention security/compliance/encryption; a security
  audit exists.
- **Resolved:** auth ADR; security architecture documented; encryption strategy defined.
- **N/A:** unauthenticated internal tool; public read-only API with no sensitive data.

If `audits/SECURITY-AUDIT-BASELINE.md` exists, cite its open findings in the Context line of these questions.

| ID | Question | Options |
|----|----------|---------|
| DIM-5-001 | Authentication model | Session-based · JWT (with rotation/revocation) · OAuth 2.0/OIDC · API keys (service-to-service) · Passwordless |
| DIM-5-002 | Authorization model | RBAC · ABAC · ACL per resource · Simple admin/user |

Context: user types, multi-tenancy, compliance, roles in `contracts/PERMISSIONS-MATRIX.md`.

Red flags: sensitive data without encryption at rest; JWT without rotation/revocation; state-changing endpoints
without CSRF protection; no threat model.

## DIM-6 API Design

- **Applicable:** the system exposes an API to external clients; `Style: http` contracts exist.
- **Resolved:** contracts fix style, versioning and errors; API ADR; OpenAPI/GraphQL schema exists.
- **N/A:** no API; every contract is `Style: operations` (no external HTTP clients) — the transport of a
  server-rendered or client UI app is not API design, it goes to `design/OPERATION-MAPPING.md`.

| ID | Question | Options |
|----|----------|---------|
| DIM-6-001 | API style ({N} operations for external clients) | REST/JSON · GraphQL · gRPC · tRPC |

Context: client types, query complexity, performance needs.

Red flags: no versioning strategy; no error-response convention; public API without rate limiting; inconsistent
resource naming.

## DIM-7 Infrastructure

- **Applicable:** anything deployed; scale targets; several environments.
- **Resolved:** hosting/compute ADR; deployment config (Dockerfile, IaC) exists; CLAUDE.md names the platform.
- **N/A:** library or package deployed by its consumer.

| ID | Question | Options |
|----|----------|---------|
| DIM-7-001 | Compute model | PaaS (Fly, Render, Railway, Heroku) · Containers (Docker/K8s) · Serverless functions · Edge runtime · VPS |
| DIM-7-002 | Config per environment: shape of each credential and secret ({N} external integrations, service accounts) | Mounted file, variable holds its path (`GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/gcs.json`) · Single-line variable (tokens, API keys) · Secret manager injected at start |
| DIM-7-003 | Auth in front of machine endpoints ({cron jobs, webhooks, health checks}) | Machine paths excluded from the proxy's human auth, the app checks its own secret (header or HMAC) · Internal route or port not published through the proxy · Proxy auth on everything, callers send the proxy credentials |

Context: scale targets, budget, team ops expertise. For DIM-7-002 and DIM-7-003, list each variable and machine
endpoint with its form locally and in staging: that table is where a difference between environments becomes
visible before deploy. The variable names (never values) are a proposal for the profile key `env_required`: show
the list to a person, who writes it (`install-stack-kit.sh --set env_required=…` or by hand), since this skill does
not edit `CLAUDE.md`. The implementer then compares each task's variables with it.

Applies to DIM-7-002 when the specs name an external integration, a service account or a scheduled job, and to
DIM-7-003 when a cron, webhook or other non-human caller reaches the app through a reverse proxy or gateway.
Both are ADR-DRAFT candidates: they fail only in the deployed environment, so the decision has to be written down
where the implementer and the smoke tests can read it.

Red flags: manual deployment without IaC; single region for global users; no disaster-recovery plan;
over-provisioning for the expected load; a credential whose form differs between local and staging (a JSON
document placed in a variable the library reads as a file path fails with `ENAMETOOLONG`); a machine endpoint
behind the proxy's basic auth (the proxy answers 401 before the app ever checks its own secret).

## DIM-8 CI/CD Pipeline

- **Applicable:** any deployed service; team > 1; several environments.
- **Resolved:** CI config exists (`.github/workflows`, etc.); deployment ADR; documented build/test/deploy.
- **N/A:** personal project deployed by hand (flag it as a risk).

| ID | Question | Options |
|----|----------|---------|
| DIM-8-001 | CI/CD platform | GitHub Actions · GitLab CI · CircleCI · Jenkins |
| DIM-8-002 | Deployment strategy | Direct · Rolling · Blue-green · Canary |
| DIM-8-003 | Post-deploy verification (staging: {yes/no}) | Smoke after each deploy to staging: profile keys `staging_url` and `smoke`, `/sdd-setup --tracker` installs the `sdd-smoke` job · Manual check after deploy (a risk) · None (a risk) |

Context: code hosting, availability and rollback needs, infrastructure. The CI test step should run the Stack
Profile `test` command when a profile exists. For DIM-8-003 the smoke covers two or three journeys with
idempotent data (a real login, the central write, one path through each external integration), taken from the
test plan's `smoke-deploy` tier when it exists. It verifies the deployed increment only; monitoring and runtime
rollback stay with the project's operations. DIM-8-003 is an ADR-DRAFT candidate: choosing no smoke is a risk the
user accepts in writing.

Red flags: no automated tests in CI; manual production deploys; no rollback strategy; no staging; staging without
any verification after deploy (configuration that exists only there reaches users untested).

## DIM-9 Observability

- **Applicable:** production runtime; SLO/uptime targets in NFRs; several services or integrations.
- **Resolved:** stack chosen; SLOs mapped to SLIs; alert rules defined (`spec/nfr/OBSERVABILITY.md`).
- **N/A:** dev tool or CLI with no production runtime.

| ID | Question | Options |
|----|----------|---------|
| DIM-9-001 | Observability stack | OpenTelemetry + backend · Grafana/Prometheus/Loki · Sentry + metrics · Datadog · Cloud-native (CloudWatch etc.) |

Context: budget, complexity, SLO targets.

Red flags: no production logging; alerts without runbooks; SLOs with no instrumented SLIs; microservices without
distributed tracing.

## DIM-10 Cost & Scaling

- **Applicable:** hosted service; scale targets; budget constraints.
- **Resolved:** cost estimate documented; scaling strategy and per-environment budgets set.
- **N/A:** open-source library/tool; free tier covers all needs.

| ID | Question | Options |
|----|----------|---------|
| DIM-10-001 | Scaling strategy ({targets}) | Static provisioning · Vertical · Horizontal auto-scale · Platform (serverless) auto-scale |

Context: load targets, cost constraints, traffic pattern.

Red flags: no cost estimate before production; no plan for 10× growth; data-transfer costs ignored.

## DIM-11 Developer Experience

- **Applicable:** team > 1; several modules/packages; onboarding matters.
- **Resolved:** CLAUDE.md setup section or contributing guide; documented build/test commands (Stack Profile).
- **N/A:** solo developer, simple project.

| ID | Question | Options |
|----|----------|---------|
| DIM-11-001 | Repository structure | Single repo · Monorepo with tooling (Turborepo/Nx) · Multi-repo |

Context: package count, team size, independent-deploy needs.

Red flags: undocumented setup; no lint/format automation; inconsistent tooling across modules.

## DIM-12 i18n & Accessibility

- **Applicable:** user-facing UI; several languages/regions; NFRs mention accessibility.
- **Resolved:** i18n strategy and locale list documented; WCAG level specified (or `ux/ACCESSIBILITY-SPEC.md`
  exists — defer to it).
- **N/A:** API-only; single-language internal tool; CLI.

| ID | Question | Options |
|----|----------|---------|
| DIM-12-001 | Internationalization | Full i18n from day 1 · Single language, i18n-ready · Single language |
| DIM-12-002 | Accessibility level | WCAG 2.2 AA (recommended) · WCAG 2.2 A · WCAG 2.2 AAA · Best effort |

Context: target markets, user languages, audience, legal requirements.

Red flags: UI built without i18n that will need several languages; hard-coded strings; no accessibility testing
in CI; no keyboard navigation.
