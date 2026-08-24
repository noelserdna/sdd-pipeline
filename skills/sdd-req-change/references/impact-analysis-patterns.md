# Impact Analysis Patterns

> Reference document for Phase 2 (Impact Analysis) of `sdd-req-change`.
> Maps change types to affected document categories and provides traceability chain patterns.

---

## 1. Traceability Chain Reference

The full traceability chain in the ReadPDF spec repository:

```
REQ-{SUB}-{NNN}
  ↕ Source/Implements
UC-{NNN} / WF-{NNN}
  ↕ Implements/Defines
API-{module} endpoint / EVENTS-{domain} event
  ↕ Verifies
BDD-{feature} scenario
  ↕ Guarantees/Enforces
INV-{AREA}-{NNN}
  ↕ Documents/Justifies
ADR-{NNN}
  ↕ Clarifies
RN-{NNN} (CLARIFICATIONS.md)
```

### Bidirectional Navigation

| Starting Point | Forward (downstream) | Backward (upstream) |
|---------------|---------------------|---------------------|
| REQ | → UC → WF → API → BDD | ← stakeholder need |
| UC | → API → BDD → INV | ← REQ ← business need |
| INV | → UC enforcement → API validation | ← domain rule ← ADR |
| ADR | → INV → UC behavior | ← design decision ← problem |
| RN | → UC → API behavior | ← clarification ← ambiguity |

---

## 2. Impact Patterns by Change Type

### 2.1 ADD Functional Requirement

**Typical impact footprint:**

```
NEW REQ-{SUB}-{NNN}
  → requirements/REQUIREMENTS.md (§4/5/6/7/8 + §9 traceability + §10 coverage)
  → use-cases/UC-{NNN}.md (new UC or new flow in existing UC)
  → workflows/WF-{NNN}.md (if new async process needed)
  → contracts/API-{module}.md (new endpoint or parameter)
  → contracts/EVENTS-{domain}.md (if new domain event)
  → tests/BDD-{feature}.md (new scenario)
  → domain/02-ENTITIES.md (if new entity or field)
  → domain/03-VALUE-OBJECTS.md (if new VO)
  → domain/04-STATES.md (if new state or transition)
  → domain/05-INVARIANTS.md (if new constraint)
  → CLARIFICATIONS.md (if new business rule)
  → CHANGELOG.md
```

**Checklist for ADD:**

| Check | Question | If Yes |
|-------|----------|--------|
| New entity? | Does this requirement introduce a new domain concept? | Modify ENTITIES, GLOSSARY, possibly STATES |
| New endpoint? | Does this require a new API? | Modify API contract, PERMISSIONS-MATRIX |
| New event? | Does this trigger async processing? | Modify EVENTS, possibly new WF |
| New role behavior? | Does this affect a specific role differently? | Modify PERMISSIONS-MATRIX, UC |
| New invariant? | Does this introduce a constraint that must always hold? | Add to INVARIANTS |
| New ADR needed? | Does this require a design decision? | Create new ADR |
| Cross-org impact? | Does this affect tenant isolation? | Verify multi-tenant implications |
| GDPR impact? | Does this involve PII? | Verify GDPR compliance, encryption |

### 2.2 MODIFY Functional Requirement

**Typical impact footprint:**

```
MODIFIED REQ-{SUB}-{NNN}
  → requirements/REQUIREMENTS.md (update REQ + traceability)
  → ALL documents in existing traceability chain of the REQ:
    → UC-{NNN}.md (modify existing flow)
    → WF-{NNN}.md (modify step)
    → API-{module}.md (modify endpoint/parameter/response)
    → BDD-{feature}.md (modify scenario)
    → INV-{AREA}-{NNN} (modify constraint if applicable)
  → documents referencing the modified REQ indirectly:
    → other UCs that reference modified UC
    → other REQs that depend on modified behavior
  → CHANGELOG.md
```

**Checklist for MODIFY:**

| Check | Question | If Yes |
|-------|----------|--------|
| Threshold change? | Is a numeric limit/timeout/rate changing? | Update nfr/LIMITS.md, INVs, RNs |
| Behavior change? | Is the system doing something different? | Update UC flow, BDD, API contract |
| Scope change? | Is the requirement applying to more/fewer cases? | Update UC preconditions, API validation |
| Actor change? | Is a different role now involved? | Update PERMISSIONS-MATRIX, UC actors |
| Breaking change? | Does this change existing API contracts? | Flag as breaking, document migration |

### 2.3 MODIFY Non-Functional Requirement

**Typical impact footprint:**

```
MODIFIED REQ-{NFR-SUB}-{NNN}
  → requirements/REQUIREMENTS.md (update REQ)
  → nfr/{PERFORMANCE|SECURITY|LIMITS|OBSERVABILITY}.md
  → related INVs enforcing the constraint
  → related ADRs justifying the value
  → related RNs in CLARIFICATIONS.md
  → possibly: API contracts (if timeout/rate limit exposed in API)
  → CHANGELOG.md
```

### 2.4 DEPRECATE Requirement

**Typical impact footprint (LARGEST):**

```
DEPRECATED REQ-{SUB}-{NNN}
  → requirements/REQUIREMENTS.md (move to §12 Deprecated + update §3 counts)
  → ALL documents in traceability chain:
    → UC-{NNN}.md (remove sections or mark deprecated)
    → WF-{NNN}.md (remove steps)
    → API-{module}.md (remove endpoint or mark deprecated)
    → EVENTS-{domain}.md (remove event types)
    → BDD-{feature}.md (remove scenarios)
    → INV-{AREA}-{NNN} (deprecate constraint)
  → ALL documents referencing deprecated REQ:
    → other REQs depending on it (must update or deprecate too)
    → other UCs referencing deprecated behavior
    → PERMISSIONS-MATRIX (if role-specific)
  → domain/ files if entity/VO/state no longer needed
  → adr/ files (mark as superseded if entire feature removed)
  → CLARIFICATIONS.md (mark RNs as deprecated)
  → CHANGELOG.md
```

**Checklist for DEPRECATE:**

| Check | Question | If Yes |
|-------|----------|--------|
| Dependent REQs? | Do other REQs depend on this one? | Must update or deprecate dependents |
| Shared UC? | Is the UC shared with other REQs? | Only remove specific sections, not entire UC |
| Shared entity? | Is the entity used by other REQs? | Only remove specific fields, not entire entity |
| Data migration? | Does existing data need migration? | Document migration steps |
| API breaking? | Does this remove a public API endpoint? | Flag as breaking, version API |
| GDPR data? | Does deprecated feature involve PII? | Document data deletion/retention |

---

## 3. Document Dependency Graph

### Primary Dependencies (editing one REQUIRES checking the other)

```
01-GLOSSARY.md ←─── ALL documents (ubiquitous language)
02-ENTITIES.md ←──→ 03-VALUE-OBJECTS.md
02-ENTITIES.md ←──→ 04-STATES.md
02-ENTITIES.md ←──→ 05-INVARIANTS.md
02-ENTITIES.md ←──→ UC-*.md
04-STATES.md   ←──→ 05-INVARIANTS.md
05-INVARIANTS.md ←→ UC-*.md (enforcement)
UC-*.md        ←──→ API-*.md (implementation)
UC-*.md        ←──→ WF-*.md (orchestration)
UC-*.md        ←──→ BDD-*.md (verification)
API-*.md       ←──→ PERMISSIONS-MATRIX.md
API-*.md       ←──→ EVENTS-*.md
nfr/LIMITS.md  ←──→ 05-INVARIANTS.md
nfr/SECURITY.md ←─→ PERMISSIONS-MATRIX.md
CLARIFICATIONS.md ←→ UC-*.md (business rules)
```

### Cascade Patterns (change in A FORCES change in B)

| If A changes... | Then B MUST update... |
|----------------|----------------------|
| Entity field added/removed | VOs referencing entity, INVs validating field, API contracts exposing field |
| State added/removed | State machine diagram, INVs per-state, UC flows with state transitions |
| Invariant added | UC that enforces it, API validation, BDD that tests it |
| Invariant removed | UC enforcement section, API validation, BDD scenarios |
| API endpoint added | PERMISSIONS-MATRIX, BDD scenarios, UC implementation notes |
| Event type added | Event schema, WF that handles it, UC that triggers it |
| Role permission changed | PERMISSIONS-MATRIX, ALL API contracts, UC authorization sections |
| Business rule (RN) added | UC flows implementing it, possibly INV formalizing it |
| Timeout/limit changed | LIMITS.md, related INVs, WF step timeouts, API response docs |

---

## 4. Conflict Detection Patterns

### Pattern 1: Contradicts Existing Invariant

**Signal:** New/modified REQ behavior would violate an existing INV.
**Example:** "Allow PDFs over 50MB" contradicts INV-EXT-001 (max 50MB).
**Resolution options:**
- A) Modify the invariant (cascading impact)
- B) Make the requirement respect the invariant
- C) Create exception rule with ADR

### Pattern 2: Contradicts Existing ADR

**Signal:** New/modified REQ conflicts with a design decision.
**Example:** "Use a different LLM provider" contradicts ADR-001 (Anthropic as primary).
**Resolution options:**
- A) Supersede the ADR with new ADR
- B) Adapt the requirement to work within ADR constraint
- C) Add the change as an evolution option in ADR

### Pattern 3: Breaks Existing BDD Scenario

**Signal:** Modified REQ changes expected behavior verified by BDD test.
**Example:** Changing timeout from 360s to 480s breaks BDD-extraction scenarios with 360s assertion.
**Resolution:** Update BDD scenario with new value (cascading but non-conflicting).

### Pattern 4: Creates Orphan Spec Section

**Signal:** Deprecating a REQ leaves a UC section with no requirements backing.
**Example:** Deprecating percentile feature leaves UC-025 with no REQ.
**Resolution options:**
- A) Deprecate entire UC (if all sections are orphaned)
- B) Remove only orphaned sections (if UC has other active REQs)
- C) Reassign section to another REQ

### Pattern 5: Mutual Exclusion

**Signal:** Two CRs in same batch create contradictory requirements.
**Example:** CR-001 adds "allow anonymous access" + CR-002 adds "require authentication for all endpoints".
**Resolution:** STOP. Present to user. Cannot proceed with both.

### Pattern 6: Implicit Dependency

**Signal:** CR relies on capability not yet specified.
**Example:** "Add bulk extraction" assumes batch processing infrastructure exists.
**Resolution options:**
- A) Create additional CRs for prerequisites
- B) Add dependency note and proceed with implementation order
- C) Reduce scope to work within existing infrastructure

---

## 5. Complexity Estimation Heuristics

| Factor | Low (1) | Medium (2) | High (3) | Very High (4) |
|--------|---------|------------|----------|---------------|
| Documents affected | 1-3 | 4-8 | 9-15 | 16+ |
| New entities/VOs | 0 | 0-1 | 2-3 | 4+ |
| New states/transitions | 0 | 0-1 | 2-3 | 4+ |
| ADRs needed | 0 | 0-1 | 1-2 | 3+ |
| Cross-domain impact | None | Same bounded context | 2 contexts | 3+ contexts |
| Breaking changes | 0 | 0 | 1-2 | 3+ |
| Conflicts detected | 0 | 0-1 | 2-3 | 4+ |

**Scoring:**
- Sum all factors
- Low: 7-10 | Medium: 11-16 | High: 17-22 | Very High: 23+

---

## 6. ReadPDF-Specific Impact Maps

### By Subcategory → Typical Documents

| Subcategory | Primary Docs | Secondary Docs |
|-------------|-------------|----------------|
| EXT (Extraction) | UC-001, UC-002, UC-003, WF-001, API-pdf-reader, BDD-extraction | ENTITIES (Extraction), LIMITS, INV-EXT-* |
| CVA (CV Analysis) | UC-004, UC-005, UC-006, WF-002, API-pdf-reader, BDD-cv-analysis | ENTITIES (CVAnalysis), VOs (Dimensions), INV-CVA-* |
| MAT (Matching) | UC-007, UC-008, UC-009, WF-003, API-matching, BDD-matching | ENTITIES (MatchResult, JobOffer), ADR-011, ADR-013 |
| GDP (GDPR) | UC-010-014, API-gdpr, BDD-gdpr | SECURITY, ADR-002, ADR-008, INV-PII-* |
| CAN (Candidate) | UC-015-026, API-candidate, BDD-candidate-dashboard | ENTITIES (Candidate), ADR-018, INV-CAN-* |
| SEL (Selection) | UC-035-041, API-recruiter, BDD-selection-pipeline | ENTITIES (SelectionProcess), STATES, INV-SEL-* |
| OFF (Offers) | UC-020-022, API-matching, BDD-offers | ENTITIES (JobOffer), INV-OFF-* |
| USR (User Mgmt) | UC-027-030, API-admin, API-org | ENTITIES (User), PERMISSIONS-MATRIX, INV-USR-* |
| DSH (Dashboard) | Contracts (API-admin, API-org, API-recruiter) | BDD-dashboards, BDD-export |
| SEC (Security) | nfr/SECURITY, PERMISSIONS-MATRIX, ADR-002 | ALL API contracts, INV-ROL-*, runbooks |
| PERF (Performance) | nfr/PERFORMANCE, nfr/LIMITS | INV-SYS-*, WFs (timeouts) |
