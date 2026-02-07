# Phase Assignment Rules (Example: CV-Matching Platform)

> This is a project-specific example showing how the generic phase-assignment-rules.md was applied to a recruitment/CV-matching platform. Use it as a reference for how to populate the rules for your own project.

Complete rules for assigning spec files to implementation phases. Rules are applied in priority order; the first match wins.

---

## Priority Order

1. **INV prefix** (strongest signal) - invariant prefix directly maps to phase
2. **UC number** - use case number maps to phase
3. **ADR content** - ADR topic/keywords map to phase
4. **BDD test name** - test file name maps to phase
5. **Contract module** - API contract module maps to phase
6. **Workflow number** - WF number maps to phase
7. **Domain file section** - entity/VO/state section maps to phase
8. **NFR/Runbook/Legal content** - operational docs map to phase
9. **Keyword fallback** - grep for phase-specific keywords

---

## Rule 1: By Invariant Prefix

| INV Prefix | Phase | Rationale |
|------------|-------|-----------|
| `SEC` | FASE-0 | Security infrastructure |
| `KEY` | FASE-0 | Encryption key management |
| `SYS` | FASE-0 | System-level invariants |
| `AUD` | FASE-0 | Audit logging |
| `EXT` | FASE-1 | PDF extraction |
| `FAL` | FASE-1 | Fallback/retry extraction |
| `CVA` (001-006, 014) | FASE-2 | CV analysis core |
| `PRM` | FASE-2 | Prompt management |
| `AUTH` | FASE-3 | Authentication |
| `ROL` | FASE-3 | Role management |
| `USR` | FASE-3 | User management |
| `ORG` | FASE-3 | Organization management |
| `LIM` | FASE-3 | Rate limiting (per-user) |
| `MEM` | FASE-3 | Membership management |
| `SEA` | FASE-4 | Semantic search |
| `EMB` | FASE-4 | Embedding management |
| `MAT` (001-010, 012) | FASE-5 | Matching engine core |
| `OFF` | FASE-5 | JobOffer management |
| `BAT` | FASE-5 | Batch/bulk operations |
| `GDP` | FASE-6 | GDPR operations |
| `CVA-015` | FASE-6 | GDPR mutual exclusion |
| `RET` | FASE-6 | Data retention |
| `CAN` | FASE-7 | Candidate dashboard |
| `CMP` | FASE-7 | Comparison/percentile |
| `PVL` | FASE-7 | Profile view log |
| `SEL` | FASE-8 | Selection process |
| `MAT-011` | FASE-8 | Frozen matches (selection) |
| `REC` | FASE-8 | Recruiter workspace/pipeline |

---

## Rule 2: By Use Case Number

| UC Range | Phase | Description |
|----------|-------|-------------|
| UC-007 | FASE-0 | Security incidents |
| UC-028 | FASE-0 | Platform dashboard |
| UC-029 | FASE-0 | Monitoring & health |
| UC-030 | FASE-0 | Global config |
| UC-001 | FASE-1 | Upload & extract PDF |
| UC-003 (GET only) | FASE-1 | View prompts (read-only) |
| UC-002 | FASE-2 | Analyze CV |
| UC-003 (CRUD) | FASE-2 | Manage prompts (full CRUD) |
| UC-027 | FASE-3 | User management |
| UC-031 | FASE-3 | Organization management |
| UC-038 | FASE-3 | Membership management |
| UC-006 | FASE-4 | Semantic search + filters |
| UC-008 | FASE-5 | Manage JobOffers |
| UC-009 | FASE-5 | Execute matching |
| UC-010 | FASE-5 | Manage MatchResults |
| UC-011 | FASE-5 | Bulk upload CVs |
| UC-004 | FASE-6 | GDPR data access |
| UC-005 | FASE-6 | GDPR data deletion |
| UC-039 | FASE-6 | Consent management |
| UC-015 | FASE-7 | Candidate magic link |
| UC-016 | FASE-7 | Candidate org selection |
| UC-017 | FASE-7 | Candidate dashboard view |
| UC-018 | FASE-7 | Candidate upload CV |
| UC-019 | FASE-7 | Candidate upload certificate |
| UC-020 | FASE-7 | Candidate view matches |
| UC-021 | FASE-7 | Candidate view selection |
| UC-022 | FASE-7 | Candidate calendar |
| UC-023 | FASE-7 | Candidate match alerts |
| UC-024 | FASE-7 | Candidate suggestions |
| UC-025 | FASE-7 | Candidate comparison |
| UC-026 | FASE-7 | Candidate profile views |
| UC-012 | FASE-8 | Export dashboard |
| UC-013 | FASE-8 | Verified profile |
| UC-014 | FASE-8 | Daily summary |
| UC-032 | FASE-8 | Organization dashboard |
| UC-033 | FASE-8 | Organization reports |
| UC-034 | FASE-8 | Organization config |
| UC-035 | FASE-8 | Recruiter dashboard |
| UC-036 | FASE-8 | Candidate pipeline |
| UC-037 | FASE-8 | Recruiter workspace |
| UC-040 | FASE-8 | Email templates |
| UC-041 | FASE-8 | Selection events |

**Total: 41 UCs mapped**

---

## Rule 3: By ADR

| ADR | Phase | Topic |
|-----|-------|-------|
| ADR-001 | FASE-0, FASE-1 | Hybrid extractor (infra + extraction) |
| ADR-002 | FASE-0, FASE-2, FASE-6 | Encryption PII (infra + analysis + GDPR) |
| ADR-003 | FASE-0, FASE-3 | Multi-tenancy (infra + auth) |
| ADR-004 | FASE-0 | Workflow orchestration |
| ADR-005 | FASE-2 | Scores 0-100 |
| ADR-006 | FASE-2 | Seniority 8 levels |
| ADR-007 | FASE-0 | Security incidents |
| ADR-008 | FASE-6 | GDPR Art. 18/21 |
| ADR-009 | FASE-2, FASE-4 | Semantic search (analysis + search) |
| ADR-010 | FASE-5 | JobOffer aggregate |
| ADR-011 | FASE-5 | Matching engine |
| ADR-012 | FASE-5 | Matching consent GDPR |
| ADR-013 | FASE-5 | Configurable weights |
| ADR-014 | FASE-5 | Matching cooldown |
| ADR-015 | FASE-8 | Candidate notification |
| ADR-017 | FASE-0, FASE-1 | PDF vault storage (infra + extraction) |
| ADR-018 | FASE-7 | Magic link auth |
| ADR-019 | FASE-7 | CV upload rate limit |
| ADR-020 | FASE-5, FASE-7 | Match explanation LLM |
| ADR-021 | FASE-7 | Profile percentile |
| ADR-022 | FASE-0 | Event architecture |
| ADR-023 | FASE-0 | Background jobs |
| ADR-024 | FASE-0 | Observability |
| ADR-025 | FASE-0 | Rate limiting |
| ADR-026 | FASE-0 | Error handling |
| ADR-027 | FASE-0 | Caching |
| ADR-028 | FASE-2, FASE-4 | Embedding lifecycle |
| ADR-029 | FASE-0 | Admin overrides |
| ADR-030 | FASE-3 | (Auth-related) |
| ADR-031 | FASE-3 | (Auth-related) |
| ADR-032 | FASE-8 | Realtime sync |
| ADR-033 | FASE-0 | API versioning |
| ADR-035 | FASE-3, FASE-7 | Session non-renewal |

**Note:** Some ADRs appear in multiple phases. The PRIMARY phase is the first listed; secondary phases reference the ADR for cross-cutting concerns.

---

## Rule 4: By BDD Test File

| Test File | Phase |
|-----------|-------|
| `PROPERTIES.md` | FASE-0 |
| `BDD-extraction.md` | FASE-1 |
| `BDD-cv-analysis.md` | FASE-2 |
| `BDD-dashboards.md` | FASE-3, FASE-8 |
| `BDD-matching.md` | FASE-4 (search section), FASE-5 (matching section) |
| `BDD-offers.md` | FASE-5 |
| `BDD-bulk-upload.md` | FASE-5 |
| `BDD-gdpr.md` | FASE-6 |
| `BDD-candidate-dashboard.md` | FASE-7 |
| `BDD-export.md` | FASE-8 |
| `BDD-verified-profile.md` | FASE-8 |
| `BDD-daily-summary.md` | FASE-8 |

---

## Rule 5: By Contract Module

| Contract File | Phase |
|---------------|-------|
| `API-admin-panel.md` | FASE-0 |
| `API-platform-admin.md` | FASE-3 |
| `API-pdf-reader.md` | FASE-1 |
| `API-cv-analyzer.md` | FASE-2 |
| `API-organization.md` | FASE-3, FASE-8 |
| `API-recruiter.md` | FASE-4 (search), FASE-8 (pipeline/workspace) |
| `API-matching.md` | FASE-5 |
| `API-offers.md` | FASE-5 |
| `API-bulk.md` | FASE-5 |
| `API-gdpr.md` | FASE-6 |
| `API-candidate-dashboard.md` | FASE-7 |
| `PERMISSIONS-MATRIX.md` | FASE-3 |
| `EVENTS-domain.md` | FASE-0 (transversal - referenced by ALL phases) |
| `ERROR-CODES.md` | FASE-0 (transversal) |

---

## Rule 6: By Workflow

| Workflow | Phase |
|----------|-------|
| `WF-001-pdf-extraction.md` | FASE-1 |
| `WF-002-cv-analysis.md` | FASE-2 |
| `WF-003-matching.md` | FASE-5 |
| `WF-004-embedding-regeneration.md` | FASE-2 |

---

## Rule 7: By Domain File Section

### 02-ENTITIES.md

| Section | Phase |
|---------|-------|
| Organization, User | FASE-0 (structure), FASE-3 (full) |
| AuditLog | FASE-0 |
| DomainEvent | FASE-0 |
| Extraction | FASE-1 |
| CVAnalysis, CVFollowup, CVCertificate | FASE-2 |
| Prompt, PromptUsageLog | FASE-2 |
| JobOffer | FASE-5 |
| MatchResult | FASE-5, FASE-8 (state machine) |
| BatchJob | FASE-5 |
| CandidateMagicLink, CandidateSession | FASE-7 |
| CandidateNotification | FASE-8 |
| CandidatePreferences | FASE-7 |
| SelectionEvent | FASE-8 |
| ProfileViewLog | FASE-7 |

### 03-VALUE-OBJECTS.md

| Value Object | Phase |
|--------------|-------|
| SeniorityLevel, DimensionScore | FASE-2 |
| Location, SalaryRange | FASE-5 |
| MatchWeights | FASE-5 |

### 04-STATES.md

| State Machine | Phase |
|---------------|-------|
| ExtractionStatus | FASE-1 |
| CVAnalysisStatus | FASE-2 |
| OfferStatus | FASE-5 |
| MatchResultStatus | FASE-5, FASE-8 |
| GDPRRequestStatus | FASE-6 |
| MagicLinkStatus, SessionStatus | FASE-7 |

### 05-INVARIANTS.md

See Rule 1 (by INV prefix).

### 06-SELECTION-EVENT-SCHEMAS.md

Entire file → FASE-8

### 01-GLOSSARY.md

Transversal document → FASE-0 + ALL phases (always referenced)

---

## Rule 8: By NFR/Runbook/Legal Content

| Document | Phase |
|----------|-------|
| `nfr/LIMITS.md` | FASE-0 |
| `nfr/SECURITY.md` | FASE-0 |
| `nfr/PERFORMANCE.md` | FASE-0 |
| `nfr/OBSERVABILITY.md` | FASE-0 |
| `runbooks/KEY-ROTATION.md` | FASE-0 |
| `runbooks/KEY-RECOVERY.md` | FASE-0 |
| `legal/GDPR-ANONYMIZATION-REVIEW.md` | FASE-6 |

---

## Transversal Documents

These documents are referenced by ALL phases (include in FASE-0 as primary, mention in each phase as needed):

| Document | Why transversal |
|----------|-----------------|
| `00-OVERVIEW.md` | System vision |
| `01-SYSTEM-CONTEXT.md` | Boundaries, actors, contexts |
| `domain/01-GLOSSARY.md` | Ubiquitous language |
| `contracts/EVENTS-domain.md` | All domain events |
| `contracts/ERROR-CODES.md` | All error codes |
| `CLARIFICATIONS.md` | Business rules (RN-*) |
| `CHANGELOG.md` | Change history |

---

## Multi-Phase Specs

Some specs span multiple phases. Handle with section qualifiers:

| Spec | Phases | Qualifier |
|------|--------|-----------|
| `domain/02-ENTITIES.md` | FASE-0 through FASE-8 | Section number qualifier |
| `domain/04-STATES.md` | FASE-1 through FASE-8 | State machine name qualifier |
| `contracts/API-organization.md` | FASE-3, FASE-8 | Section qualifier |
| `contracts/API-recruiter.md` | FASE-4, FASE-8 | Section qualifier (search vs pipeline) |
| `tests/BDD-dashboards.md` | FASE-3, FASE-8 | Feature qualifier |
| `tests/BDD-matching.md` | FASE-4, FASE-5 | Section qualifier (search vs matching) |
| `UC-003` | FASE-1, FASE-2 | Operation qualifier (GET vs CRUD) |

**Template for multi-phase reference:**
```markdown
| `domain/02-ENTITIES.md` | Sección N: {Entity} | {What to extract} |
```

---

## Conflict Resolution

When a spec matches multiple rules pointing to different phases:

1. **INV prefix wins** over UC number (invariants are the strongest signal)
2. **UC number wins** over ADR/keyword (UCs are explicit assignments)
3. **If still ambiguous**: assign to the EARLIEST phase that needs the spec
4. **If truly multi-phase**: list all phases with section qualifiers

---

## New Spec Handling

When a new spec is encountered that doesn't match any rule:

1. Check if its filename contains a mapped UC/ADR/WF number → use that rule
2. Check if its content references INV-* with a mapped prefix → use Rule 1
3. Check if it's referenced by an existing FASE file → use that phase
4. If none of the above: trace the spec's primary entity to a UC → use that UC's phase
5. If still unclear: ask the user which phase it belongs to
