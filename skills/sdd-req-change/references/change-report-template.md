# Change Report Template — sdd-req-change Phase 8

Output: `changes/CHANGE-REPORT-{CHG-ID}.md` (CHG-ID = `CHG-YYYY-MM-DD-NNN`). Downstream skills read it by that name: `sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{CHG-ID}.md`, `sdd-task-generator --incremental` (annotates `Source: CASCADE-{CHG-ID}`), `sdd-plan-architect` (§7.1). Keep the section numbers: §7.1 and §7.7 are parsed by Phase 9.

```markdown
# Change Report — {Short Title}

> **Report ID:** {CHG-ID}
> **Date:** YYYY-MM-DD
> **Spec version:** v{before} → v{after} · **REQUIREMENTS.md version:** {before} → {after}
> **Change Requests:** {N} (ADD:{N} MODIFY:{N} DEPRECATE:{N}) · **Documents modified:** {N}
> **Alignment audit:** {ALIGNED | N gaps} · **Breaking changes:** {Yes (N) | No}
> **Origin:** {user | CHANGE-REQUEST.md | feedback/IMPL-FEEDBACK-FASE-N.md (IF-…)}

## 1. Executive Summary
{2-3 paragraphs: what changed and why, for a reader who will not open every document.}

| # | CR-ID | Type | REQ-ID(s) | Category | Priority | Complexity | Status |
|---|-------|------|-----------|----------|----------|------------|--------|
| 1 | CR-001 | ADD | REQ-F-{NNN} | F | Must | Medium | Applied |

## 2. Changes Applied

### 2.1 New Requirements
#### REQ-F-{NNN}: {Title}
Statement, acceptance criteria, traceability (Source / Implements UC / Verifies BDD / Guarantees INV), specs created or modified (document, change).

### 2.2 Requirements Modified
#### REQ-{…}: {Title}
**Before:** {statement} · **After:** {statement} · **Reason:** {from clarification}
| Document | Section | Before | After |
|----------|---------|--------|-------|

### 2.3 Requirements Deprecated
#### REQ-{…}: {Title} [DEPRECATED]
Previous statement, reason, migration steps, sections removed per document.

## 3. New Artifacts
| Type | ID | Title | Source CR |
|------|----|-------|-----------|

## 4. Impact Summary
### 4.1 Documents Modified
| # | Document | CRs | Changes | Version |
|---|----------|-----|---------|---------|
### 4.2 Breaking Changes
| Change | Impact | Migration Required |
|--------|--------|--------------------|
### 4.3 Cross-Reference Updates
| From | To | Type | Status |
|------|----|------|--------|

## 5. Alignment Audit Results
{Phase 7 results, alignment-audit-checklist.md §3 Step 4 format; open items listed here.}

## 6. Clarification Decisions
{Clarification Log from Phase 3, including batch defaults.}

## 7. Context for Planning & Implementation

### 7.1 Affected FASEs
| FASE | Impact | Description |
|------|--------|-------------|
| FASE-1 | Direct | {…} |
| FASE-3 | Indirect | depends on FASE-1 services |

### 7.2 Architecture Impact
{new operations, entities, events, modified data flows}

### 7.3 Implementation Considerations
| Consideration | Detail |
|---------------|--------|
| New / changed operations (API-…) | {list} |
| Data model changes | {list} |
| New event types | {list} |
| Modified business logic | {list} |
| New test coverage needed | {BDD scenarios} |

### 7.4 Risk Assessment
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|

### 7.5 Maintenance Classification (ISO 14764)
| CR-ID | ISO Category | Urgency | Notes |
|-------|--------------|---------|-------|

### 7.6 Technical Debt (if any)
| TD-ID | Source CR | Type | Description | Priority | Target FASE |
|-------|-----------|------|-------------|----------|-------------|

### 7.7 Pipeline Cascade Plan
| Step | Skill | Scope |
|------|-------|-------|
| 1 | sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{CHG-ID}.md | {N} modified documents |
| 2 | sdd-test-planner, Mode 4 (Audit Test Coverage) | changed UCs / NFRs |
| 3 | sdd-plan-architect --regenerate-fases --affected={N,M} | FASE-{N}, FASE-{M} |
| 4 | sdd-task-generator --fase={N} --incremental (one run per FASE) | FASE-{N}, FASE-{M} |
| 5 | sdd-task-implementer --fase {N} --new-tasks-only (auto mode only) | FASE-{N} |

> Cascade mode: {auto | manual | dry-run | plan-only} · Stages marked stale: {list}

## 8. Commits
| # | Hash | Subject | Refs |
|---|------|---------|------|
| 1 | {hash} | docs(specs): add REQ-F-{NNN} {summary} | CR-001, REQ-F-{NNN}, UC-{NNN} |

## 9. Statistics
| Metric | Value |
|--------|-------|
| Change requests / applied / skipped | {N} / {N} / {N} |
| Documents modified | {N} |
| Requirements new / modified / deprecated | {N} / {N} / {N} |
| New INV / ADR / RN / BDD | {N} / {N} / {N} / {N} |
| Alignment checks passed | {N}/{N} |
| Open items | {N} |
```

## Final console summary

```
Change Execution Complete — {CHG-ID}
Change Requests:    {N} (ADD:{N} MODIFY:{N} DEPRECATE:{N})
Maintenance:        Corrective:{N} Adaptive:{N} Perfective:{N} Preventive:{N}
Applied / Skipped:  {N} / {N}
Documents modified: {N}
New artifacts:      REQ:{N} INV:{N} ADR:{N} RN:{N} BDD:{N}
Alignment audit:    {ALIGNED | GAPS DETECTED ({N})}
Commits:            {N}
Change Report:      changes/CHANGE-REPORT-{CHG-ID}.md
Cascade ({mode}):   stale: {list} · affected FASEs: {list}
                    [manual] recommended commands, in order
                    [auto/plan-only] executed {N}/{N} · {COMPLETE | PARTIAL} · changes/CASCADE-REPORT-{CHG-ID}.md
```
