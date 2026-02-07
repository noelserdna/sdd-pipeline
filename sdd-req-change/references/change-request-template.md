# Change Request Template

> Use this template when invoking `sdd-req-change --file changes/CHANGE-REQUEST.md`
> Each change request (CR) describes a single atomic change to the requirements.
> Multiple CRs can be included in one file for batch processing.

---

## File Format

```markdown
# Change Request

> **Date:** YYYY-MM-DD
> **Author:** {name or team}
> **Context:** {brief context: why this batch of changes is needed}
> **Related Audit:** {AUDIT-vX.X if triggered by audit findings, or "N/A"}
> **Related ADR:** {ADR-NNN if triggered by architecture decision, or "N/A"}

---

## CR-001: {Descriptive Title}

### Classification

| Field | Value |
|-------|-------|
| **Type** | ADD / MODIFY / DEPRECATE |
| **Category** | FUN / NFR / OPS / REG / DER |
| **Subcategory** | EXT / CVA / MAT / GDP / USR / ORG / OFF / CAN / SEL / DSH / SYS / PERF / SEC / SCAL / AVAIL / TECH / DEP / MON / REC / MNT / GDPR / DPR / AUT / RET / DER |
| **Priority** | Must Have / Should Have / Could Have |
| **Stability** | Stable / Moderate / Volatile |
| **Affected REQs** | REQ-{SUB}-{NNN}, ... (for MODIFY/DEPRECATE) or "None" (for ADD) |
| **Related REQs** | REQ-{SUB}-{NNN}, ... (REQs that may need review) or "None" |

### Description

{Natural language description of the change. Be specific about:
- What capability is being added/modified/removed
- Who benefits (which actor/role)
- What business value it provides
- Any constraints or limitations}

### Motivation

{Why this change is needed. Include:
- Business driver or stakeholder request
- Problem being solved
- Opportunity being captured
- Audit finding being addressed (if applicable)}

### Draft EARS Statement (optional, skill will refine)

> {EARS pattern attempt. If unsure, leave blank and the skill will help formulate.}
>
> Patterns available:
> - Ubiquitous: "The system shall {action}."
> - Event-Driven: "WHEN {trigger}, the system SHALL {action}."
> - State-Driven: "WHILE {state}, the system SHALL {action}."
> - Optional: "WHERE {feature} is enabled, the system SHALL {action}."
> - Unwanted: "IF {condition}, THEN the system SHALL {action}."
> - Complex: "WHILE {state}, WHEN {trigger}, the system SHALL {action}."

### Draft Acceptance Criteria (optional)

```gherkin
Given {precondition}
When {action}
Then {expected result}
```

### Constraints

{Any constraints on the change:
- Must not break existing behavior X
- Must be compatible with ADR-{NNN}
- Must respect INV-{AREA}-{NNN}
- Performance constraint: {metric}
- Security constraint: {requirement}
- "None" if no specific constraints}

### Additional Context (optional)

{Any additional information:
- Links to external documents
- Screenshots or diagrams
- Stakeholder quotes
- Related discussion threads}

---

## CR-002: {Title}

[Repeat same structure for each additional change]

---

## Batch Processing Notes (optional)

### Dependencies Between CRs

| CR | Depends On | Reason |
|----|-----------|--------|
| CR-002 | CR-001 | Modifies entity created by CR-001 |

### Execution Order Preference

{If CRs must be applied in specific order, note here. Otherwise "Any order"}

### Rollback Strategy

{If any CR fails, should all be rolled back? Or apply successful ones?}
| Strategy | Description |
|----------|-------------|
| All-or-nothing | If any CR fails, roll back all |
| Best-effort | Apply as many as possible, report failures |
```

---

## Examples

### Example 1: ADD Functional Requirement

```markdown
## CR-001: Bulk PDF Extraction

### Classification

| Field | Value |
|-------|-------|
| **Type** | ADD |
| **Category** | FUN |
| **Subcategory** | EXT |
| **Priority** | Should Have |
| **Stability** | Moderate |
| **Affected REQs** | None |
| **Related REQs** | REQ-EXT-001, REQ-EXT-002, REQ-PERF-001 |

### Description

Allow users to upload multiple PDFs (up to 20) in a single request for batch extraction. The system should process them sequentially using the same extraction pipeline (primary-model with fallback) and return a consolidated result with individual status per PDF.

### Motivation

Recruiters frequently need to process batches of CVs received from job fairs or bulk applications. Currently they must upload one at a time, which is tedious for 10-20 CVs.

### Draft EARS Statement

> WHEN the user submits a batch of up to 20 PDFs via the bulk extraction endpoint, the system SHALL create individual Extraction records for each PDF, process them sequentially through WF-001, and return a BulkExtractionResult with per-PDF status.

### Draft Acceptance Criteria

```gherkin
Given a recruiter with role=recruiter
And a batch of 5 valid PDFs under 50MB each
When POST /api/v1/candidates/extract/bulk is invoked
Then 5 individual Extraction records are created
And each is processed through WF-001
And a BulkExtractionResult is returned with status per PDF
```

### Constraints

- Must respect existing per-PDF 50MB limit (INV-EXT-001)
- Must respect existing rate limits (ADR-025)
- Must handle deduplication per PDF (REQ-EXT-002 applies individually)
- Total batch timeout: configurable, default 30 minutes
```

### Example 2: MODIFY Non-Functional Requirement

```markdown
## CR-002: Increase Extraction Timeout

### Classification

| Field | Value |
|-------|-------|
| **Type** | MODIFY |
| **Category** | NFR |
| **Subcategory** | PERF |
| **Priority** | Must Have |
| **Stability** | Stable |
| **Affected REQs** | REQ-PERF-001 |
| **Related REQs** | REQ-EXT-003 (fallback), RN-181 |

### Description

Increase the extraction timeout from 360s (180s+180s) to 480s (240s+240s) to accommodate larger PDFs with complex layouts that are timing out in production.

### Motivation

Production telemetry shows 3% of extractions timing out at 180s per model. These are typically 40-50MB PDFs with embedded images. Increasing to 240s per model reduces timeout rate to <0.5%.

### Constraints

- Must maintain the dual-model architecture (primary + fallback)
- Must update RN-181, INV-EXT-002, nfr/LIMITS.md, WF-001
- Must NOT change rate limits
```

### Example 3: DEPRECATE Functional Requirement

```markdown
## CR-003: Remove Profile Percentile Feature

### Classification

| Field | Value |
|-------|-------|
| **Type** | DEPRECATE |
| **Category** | FUN |
| **Subcategory** | CAN |
| **Priority** | - |
| **Stability** | - |
| **Affected REQs** | REQ-CAN-011 |
| **Related REQs** | REQ-CAN-010, REQ-MAT-003 |

### Description

Remove the anonymous percentile comparison feature from the Candidate Dashboard. The feature shows candidates how their CV analysis scores compare to other candidates as an anonymous percentile.

### Motivation

Legal review determined that even anonymous percentile comparisons could be considered automated profiling under GDPR Art. 22, requiring explicit consent mechanisms that add complexity. The feature has low usage (< 5% of candidates interact with it) and high legal risk.

### Constraints

- Must remove UC-025 or the relevant sections
- Must remove ADR-021 or mark as superseded
- Must clean all references in BDD-candidate-dashboard.md
- Must NOT affect other Candidate Dashboard features
- Data migration: existing percentile data can be deleted (no retention required)
```
