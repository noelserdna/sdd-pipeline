# Architecture Patterns — Reference Guide

> Reference document for sdd-plan-architect Phase 4 (Architecture Design).
> Common architecture views, C4 model guidance, and deployment patterns.

---

## 1. C4 Model Guide

### 1.1 What is C4

C4 (Context, Containers, Components, Code) is a hierarchical approach to software architecture diagrams. Each level zooms into more detail.

### 1.2 Level 1 — System Context

**Purpose:** Show the system as a black box within its environment.

**Elements:**
- The system under design (single box)
- Actors (persons who use it)
- External systems (systems it integrates with)
- Arrows showing data flow direction

**ASCII Convention:**

```
                    ┌──────────┐
  [Recruiter] ────→ │  ReadPDF  │ ────→ [Anthropic API]
  [OrgAdmin]  ────→ │  System   │ ────→ [Email Service]
  [Candidate] ────→ │           │
                    └──────────┘
```

**Rules:**
- One box for the entire system
- Label arrows with data/action description
- Include ALL actors from spec/01-SYSTEM-CONTEXT.md
- Include ALL external systems from contracts/

### 1.3 Level 2 — Container Diagram

**Purpose:** Show high-level technology choices and how containers communicate.

**Elements:**
- Containers (deployable units): API servers, databases, message queues, file stores
- Technologies labeled on each container
- Communication protocols on arrows

**ASCII Convention:**

```
[Browser SPA]                    [API Worker]
  (React)    ──── HTTPS/REST ───→  (Hono)
                                     │
                        ┌────────────┼────────────┐
                        ↓            ↓            ↓
                    [D1 DB]     [R2 Store]    [KV Cache]
                   (SQLite)     (Objects)     (Key-Value)
```

**Rules:**
- One box per deployable unit
- Technology in parentheses
- Protocol on arrows
- Group related stores together

### 1.4 Level 3 — Component Diagram

**Purpose:** Show internal structure of a container.

**Elements:**
- Components (modules, packages, namespaces) within a container
- Interfaces between components
- External calls from components

**ASCII Convention:**

```
┌─────────────────── API Worker ───────────────────┐
│                                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   Auth    │  │Extraction│  │  CV Analysis  │   │
│  │ Module    │→ │  Module  │→ │   Module      │   │
│  └──────────┘  └──────────┘  └──────────────┘   │
│       │              │              │              │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  GDPR    │  │ Matching │  │  Dashboard    │   │
│  │ Module   │  │  Module  │  │   Module      │   │
│  └──────────┘  └──────────┘  └──────────────┘   │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Rules:**
- One diagram per container
- Group components by bounded context
- Show inter-component dependencies with arrows
- Mark external calls distinctly

---

## 2. Deployment Patterns

### 2.1 Serverless Edge (Cloudflare Workers)

```
                    ┌─ Edge Location A ─┐
[Client] ──CDN──→  │   Worker Instance  │ ──→ [D1] [R2] [KV]
                    └───────────────────┘
                    ┌─ Edge Location B ─┐
[Client] ──CDN──→  │   Worker Instance  │ ──→ [D1] [R2] [KV]
                    └───────────────────┘
```

**Characteristics:**
- No server management
- Auto-scaling per request
- Edge-distributed (low latency globally)
- Stateless handlers (state in D1/R2/KV)
- Cold start: < 5ms (V8 isolates)

**When to use:** SaaS APIs, document processing, multi-tenant systems

**Constraints:**
- CPU time limits per request (varies by plan)
- Memory limits per isolate
- No persistent connections (WebSocket via Durable Objects)
- Limited native module support

### 2.2 Modular Monolith

```
┌──────────────────────────────────────────┐
│              Single Deployable           │
│  ┌────────┐ ┌────────┐ ┌────────────┐  │
│  │ Module │ │ Module │ │  Module    │  │
│  │   A    │ │   B    │ │    C       │  │
│  └────────┘ └────────┘ └────────────┘  │
│       ↕           ↕           ↕         │
│  ┌─────────────────────────────────┐    │
│  │        Shared Kernel            │    │
│  │  (auth, tenant, error, logging) │    │
│  └─────────────────────────────────┘    │
└──────────────────────────────────────────┘
```

**Characteristics:**
- Single deployment unit
- Modules communicate in-process
- Shared kernel for cross-cutting concerns
- Can be split into services later if needed

**When to use:** Early-stage products, teams < 10, specs with clear bounded contexts

**Module boundary rules:**
- Modules only communicate via defined interfaces
- No direct database access across modules
- Shared kernel is the only shared code

### 2.3 Queue-Mediated Processing

```
[API Handler] ──enqueue──→ [Queue] ──dequeue──→ [Processor]
                                                      │
                                                      ↓
                                               [Store Result]
                                                      │
                                                      ↓
                                              [Notify Client]
```

**Characteristics:**
- Decouples request from processing
- Handles long-running tasks (extraction, analysis)
- Natural retry semantics
- Backpressure management

**When to use:** PDF extraction, LLM calls, batch processing

---

## 3. Common Architecture Views

### 3.1 Authentication & Authorization View

```
Request
  │
  ↓
[Rate Limiter] ──exceeded──→ 429
  │ ok
  ↓
[JWT Validator] ──invalid──→ 401
  │ valid
  ↓
[Tenant Resolver] ──not found──→ 403
  │ resolved
  ↓
[RBAC Enforcer] ──denied──→ 403
  │ allowed
  ↓
[Handler]
```

**Components:**
| Component | Responsibility | Spec Reference |
|-----------|---------------|----------------|
| Rate Limiter | Enforce rate limits per session/user | ADR-025, nfr/LIMITS.md |
| JWT Validator | Validate token signature and expiry | nfr/SECURITY.md |
| Tenant Resolver | Extract org_id from token, validate tenant | INV-SYS-xxx |
| RBAC Enforcer | Check role permissions for endpoint | 01-SYSTEM-CONTEXT.md roles |

### 3.2 Data Flow View

```
[Upload PDF] → [Validate] → [Store R2] → [Extract LLM] → [Parse MD]
                                              │
                                    [Primary Model]
                                         │ fail
                                    [Fallback Model]
                                              │
                                              ↓
                                      [Store Result]
                                              │
                                              ↓
                                    [Trigger Analysis]
```

**Key patterns:**
- Primary → Fallback for LLM calls
- Store-then-process for durability
- Event-driven triggers between stages

### 3.3 Multi-Tenant Data View

```
┌──────────────── Database ────────────────┐
│                                           │
│  Every table has:                         │
│  ┌────────┬────────┬──────────────────┐  │
│  │   id   │ org_id │   ... columns    │  │
│  └────────┴────────┴──────────────────┘  │
│                                           │
│  Every query includes:                    │
│  WHERE org_id = :current_org_id          │
│                                           │
│  Indexes:                                 │
│  idx_{table}_org ON {table}(org_id)      │
│                                           │
└───────────────────────────────────────────┘
```

**Enforcement layers:**
1. **Middleware**: Inject org_id from JWT into request context
2. **Repository**: Always include org_id in WHERE clauses
3. **Database**: Index on org_id for performance
4. **Invariant**: No query without org_id filter (except super_admin)

### 3.4 Error Handling View

```
[Handler]
  │ throws AppError
  ↓
[Error Middleware]
  │
  ├─ ValidationError  → 400 + {code, message, details}
  ├─ AuthError        → 401 + {code, message}
  ├─ ForbiddenError   → 403 + {code, message}
  ├─ NotFoundError    → 404 + {code, message}
  ├─ ConflictError    → 409 + {code, message}
  ├─ RateLimitError   → 429 + {code, message, retryAfter}
  └─ InternalError    → 500 + {code, message} (no internal details)
       │
       ↓
  [Log to Audit Trail]
```

**Conventions:**
- All errors extend a base AppError class
- Error codes are machine-readable strings (e.g., `EXTRACTION_TIMEOUT`)
- Messages are human-readable
- Internal details never leaked in 5xx responses
- All 5xx errors logged with full context

---

## 4. Pattern Selection Guide

### When to Apply Each Pattern

| Scenario | Recommended Pattern | Rationale |
|----------|-------------------|-----------|
| Multi-tenant SaaS | Row-level isolation + modular monolith | Balance simplicity with isolation |
| Long-running tasks | Queue-mediated processing | Decouple request from processing |
| External API calls | Circuit breaker + retry | Resilience against external failures |
| Auth across all endpoints | Middleware chain | Consistent, reusable, testable |
| Structured errors | Typed error hierarchy | Type-safe, consistent responses |
| Multi-model LLM | Primary→Fallback chain | Spec-defined resilience |

### Anti-Patterns to Avoid

| Anti-Pattern | Why It's Bad | Alternative |
|-------------|-------------|-------------|
| Shared mutable state | Workers are stateless | Use D1/KV/R2 |
| Cross-module DB access | Breaks module boundaries | Use module interfaces |
| Catching all errors silently | Hides bugs | Let errors propagate, handle at boundary |
| Tenant filter in handler | Easy to forget | Enforce in middleware/repository |
| Synchronous LLM calls in request | Timeout risk | Queue + async processing |

---

## 5. SWEBOK v4 Alignment

### Ch02: Software Architecture

| SWEBOK Topic | How Addressed |
|-------------|---------------|
| Architecture Views | C4 Levels 1-3 + deployment + data views |
| Architecture Styles | Modular monolith + serverless edge |
| Quality Attributes | Mapped from NFR specs |
| Architecture Evaluation | Traceability matrix in PLAN.md |

### Ch03: Software Design

| SWEBOK Topic | How Addressed |
|-------------|---------------|
| Design Principles | Separation of concerns via modules |
| Design Patterns | Auth middleware, error hierarchy, circuit breaker |
| Design Rationale | ADRs + CLARIFY-LOG decisions |

### Ch04: Software Construction

| SWEBOK Topic | How Addressed |
|-------------|---------------|
| Construction Planning | Per-FASE plans with component details |
| Construction Design | Interface sketches in PLAN-FASE-N |
| Construction Testing | Test strategy per FASE |
