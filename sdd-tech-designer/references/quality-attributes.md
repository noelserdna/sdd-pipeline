# Quality Attributes Reference — ATAM-lite

> Reference document for sdd-tech-designer Phase 2 (Quality Attributes).
> Provides a simplified Architecture Tradeoff Analysis Method (ATAM) for evaluating
> and prioritizing quality attributes in the technical design.

---

## Quality Attribute Catalog (ISO 25010 Simplified)

| ID | Attribute | Definition | Typical Drivers |
|----|-----------|-----------|-----------------|
| QA-01 | **Performance** | Response time, throughput, resource utilization | p99 latency targets, TPS requirements |
| QA-02 | **Security** | Confidentiality, integrity, availability of data | Compliance (GDPR, HIPAA), threat model |
| QA-03 | **Scalability** | Ability to handle growing load | User growth projections, traffic patterns |
| QA-04 | **Reliability** | Uptime, fault tolerance, data durability | SLA targets, business criticality |
| QA-05 | **Maintainability** | Ease of modification, debugging, extension | Team size, expected change frequency |
| QA-06 | **Usability** | Ease of use, learnability, user satisfaction | Target audience, UX requirements |
| QA-07 | **Testability** | Ease of testing, observability during test | Test coverage goals, CI/CD maturity |
| QA-08 | **Deployability** | Ease of deployment, rollback capability | Deployment frequency, downtime tolerance |
| QA-09 | **Cost Efficiency** | Infrastructure cost relative to value | Budget constraints, growth projections |
| QA-10 | **Portability** | Ability to run on different platforms/environments | Multi-cloud, vendor lock-in concerns |

---

## Scoring Guidelines

### Importance Score (1-5)

| Score | Meaning | Criteria |
|-------|---------|----------|
| 5 | **Critical** | Failure directly causes business loss or legal issues |
| 4 | **High** | Significant impact on user experience or operations |
| 3 | **Medium** | Important but manageable through workarounds |
| 2 | **Low** | Nice to have, can be deferred |
| 1 | **Minimal** | Not relevant for this system |

### How to Derive Scores

1. **From NFRs:** Explicit quality targets → score 4-5
2. **From Use Cases:** Implicit quality needs (e.g., real-time updates → Performance 4) → score 3-4
3. **From Invariants:** Constraints that imply quality needs → score 3-5
4. **From Domain:** Industry norms (e.g., fintech → Security 5) → score 4-5
5. **From Stakeholders:** User interview priorities → score as stated
6. **Default:** If no evidence, score 2 (present but not critical)

---

## Trade-off Matrix Template

The trade-off matrix captures which quality attributes are prioritized over others when they conflict.

### Known Trade-off Pairs

| Attribute A | vs | Attribute B | Typical Conflict |
|-------------|---|-------------|-----------------|
| Performance | ↔ | Security | Encryption/validation adds latency |
| Performance | ↔ | Maintainability | Optimized code is harder to read |
| Security | ↔ | Usability | Strict auth flows reduce convenience |
| Scalability | ↔ | Cost Efficiency | Scaling infrastructure costs more |
| Reliability | ↔ | Deployability | More safeguards slow deployment |
| Maintainability | ↔ | Performance | Abstractions add overhead |
| Testability | ↔ | Performance | Test instrumentation has cost |
| Portability | ↔ | Performance | Abstraction layers reduce optimization |

### Matrix Format

```markdown
## Trade-off Matrix

| When | Conflicts With | Decision | Rationale |
|------|---------------|----------|-----------|
| Performance (4) | Security (5) | Security wins | Compliance requirements non-negotiable |
| Performance (4) | Maintainability (3) | Performance wins | p99 latency SLA critical |
| Scalability (4) | Cost Efficiency (3) | Scalability wins | Growth projections demand elastic capacity |
| Security (5) | Usability (3) | Security wins, mitigate UX | SSO to balance security + convenience |
```

---

## ATAM-lite Evaluation Method

### Step 1: Identify Scenarios

For each quality attribute with score ≥ 3, create 1-3 concrete scenarios:

```markdown
### Scenario: QA-01-S1 (Performance)

**Stimulus:** 1000 concurrent users submit extraction requests
**Source:** End users via web UI
**Environment:** Normal production load
**Response:** System processes each request within 2 seconds (p99)
**Measure:** p99 latency < 2000ms at 1000 concurrent users
```

### Step 2: Map Scenarios to Architecture

For each scenario, identify which architectural decisions support or hinder it:

```markdown
### QA-01-S1 Analysis

| Architecture Decision | Impact | Notes |
|----------------------|--------|-------|
| Modular monolith | Neutral | No network hops, but single bottleneck |
| PostgreSQL + connection pool | Positive | Efficient DB access |
| No caching layer | Negative | Every request hits DB |
| JWT auth | Positive | Stateless, no session lookup |

**Risk:** Without caching, p99 target may fail at 1000 concurrent.
**Mitigation:** Add Redis cache for hot paths.
```

### Step 3: Identify Sensitivity Points

Sensitivity points are architectural decisions that significantly affect multiple quality attributes:

```markdown
### Sensitivity Points

| Decision | Affects | Direction |
|----------|---------|-----------|
| Database selection | Performance, Scalability, Cost | High sensitivity |
| Auth model | Security, Usability, Performance | High sensitivity |
| Caching strategy | Performance, Cost, Reliability | Medium sensitivity |
| Deployment model | Deployability, Reliability, Cost | Medium sensitivity |
```

### Step 4: Identify Trade-off Points

Trade-off points are decisions where improving one attribute necessarily degrades another:

```markdown
### Trade-off Points

| Decision | Improves | Degrades | Resolution |
|----------|----------|----------|-----------|
| Add encryption at rest | Security | Performance (-5% write throughput) | Accept: compliance requires it |
| Add circuit breaker | Reliability | Performance (+50ms on failure path) | Accept: resilience is higher priority |
| Use ORM | Maintainability | Performance (-10% query speed) | Accept: maintainability critical for small team |
```

### Step 5: Generate Recommendations

Based on the analysis, generate concrete recommendations:

```markdown
### Recommendations

1. **Add caching layer** (Redis) for read-heavy paths — addresses QA-01-S1 risk
2. **Implement circuit breaker** for external integrations — addresses QA-04 reliability
3. **Use connection pooling** with max 20 connections — balances QA-01 and QA-09
4. **Deploy in 2 regions** — addresses QA-04 with acceptable QA-09 trade-off
```

---

## Quick Decision Guide

For teams that don't need full ATAM-lite, use this quick guide:

### Priority Archetypes

| System Type | Top 3 Attributes | Typical Trade-offs |
|------------|------------------|-------------------|
| **B2B SaaS** | Security, Reliability, Maintainability | Performance for security |
| **Consumer Web App** | Performance, Usability, Scalability | Maintainability for performance |
| **Internal Tool** | Maintainability, Usability, Cost | Performance not critical |
| **API Platform** | Reliability, Performance, Security | Cost for reliability |
| **Data Pipeline** | Reliability, Performance, Scalability | Usability not relevant |
| **Mobile App** | Performance, Usability, Reliability | Maintainability for UX |
| **E-commerce** | Security, Reliability, Performance | Cost for reliability |

### Minimum Viable Quality Assessment

If time is limited, evaluate only:

1. **Top 3 attributes** for the system type (from table above)
2. **1 trade-off** between the top 2 attributes
3. **1 scenario** for the most critical attribute

This produces a focused quality profile sufficient for plan-architect.
