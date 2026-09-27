# Phase Templates — sdd-req-change

Formats used in Phases 0-6. Read the section for the phase you are in. Example IDs (`REQ-F-012`, `INV-TASK-003`) are illustrative; use the project's real IDs.

---

## 1. Phase 0 — Inventory summary (console)

```
Inventory Complete
==================
Spec files:        {N}
Requirements:      {N} (F:{N} NF:{N} C:{N})
Current version:   v{X.Y.Z}
Audit gate:        {PASS | CONDITIONAL | BLOCKED | not run}
Pipeline state:    {fresh | plan exists (FASE 1-N) | tasks exist (FASE 1-N) | implementation started}
Change source:     {text | CHANGE-REQUEST.md | IMPL-FEEDBACK | both}
Pending deltas:    {N DRAFT | N REVIEWED | none}
```

---

## 2. Phase 1 — Change Request Summary

```markdown
## Change Request Summary — {CHG-ID}

| # | Type | Maintenance | Category | Description | Affected REQs | Complexity |
|---|------|-------------|----------|-------------|---------------|------------|
| CR-001 | ADD | Perfective | F | {description} | - | Medium |
| CR-002 | MODIFY | Corrective (P2) | NF | {description} | REQ-NF-004 | Low |
| CR-003 | DEPRECATE | Preventive | F | {description} | REQ-F-011 | High |
```

---

## 3. Phase 2 — Impact Matrix (one per CR)

```markdown
## Impact Matrix — CR-{NNN}

### Direct Impact (MUST change)
| Document | Section | Change Type | Description |
|----------|---------|-------------|-------------|
| requirements/REQUIREMENTS.md | Functional Requirements | ADD | New REQ-F-{NNN} |
| spec/use-cases/UC-001-{slug}.md | Main flow | MODIFY | {step change} |

### Indirect Impact (SHOULD review)
| Document | Reason |
|----------|--------|

### Conflicts Detected
| Conflict | Severity | Resolution Needed |
|----------|----------|-------------------|

### Complexity: {Low | Medium | High | Very High} (score {N}, impact-analysis-patterns.md §5)

### Regression Risk
| Area | Risk Level | Existing Tests | Mitigation |
|------|-----------|----------------|------------|

### Downstream Pipeline Impact
| Artifact | Current Status | Action Needed |
|----------|---------------|---------------|
| plan/fases/FASE-{N}-{SLUG}.md | {done/stale} | {Regenerate / No change} |
| task/TASK-FASE-{N}.md | {done/stale} | {Incremental regeneration / No change} |
| code (FASE-{N}) | {—} | {New tasks needed / No change} |

### Code & Commit Impact (when git is available)
| Artifact | Commits | Last Commit | Files Affected |
|----------|---------|-------------|----------------|

Blast radius: {N} commits, {M} source files, {K} test files
```

Symbol-level detail, when `sdd_impact` / code intelligence is available:

```markdown
| Symbol | File | Depth | Callers | Risk |
|--------|------|-------|---------|------|
| {symbol} | {file} | d=1 WILL_BREAK | {N} | HIGH |
| {symbol} | {file} | d=2 LIKELY_AFFECTED | {N} | MEDIUM |
| {symbol} | {file} | d=3 MAY_NEED_REVIEW | {N} | LOW |
```

---

## 4. Phase 3 — Question and Clarification Log

Question (asked one batch at a time, ≤ 4 per call):

```markdown
### Question {N} of {M}: CR-{NNN} — {Short Title}

**Context:** {why this matters}
**Conflict/Gap:** {what is unclear or conflicting}

| Option | Description | Pros | Cons | Recommendation |
|--------|-------------|------|------|----------------|
| A | {description} | {pros} | {cons} | **Recommended** |
| B | {description} | {pros} | {cons} | |

**Why A:** {rationale}   **Impact on specs:** {brief}
```

Clarification Log (copied into the Change Report §6):

```markdown
## Clarification Log — {CHG-ID}

> Date: YYYY-MM-DD · Questions asked: {N} · Answered: {N} · Batch defaults: {N}

### Q-001: {Title}
**Change Request:** CR-{NNN}
**Question:** {text}
**Answer:** {user's choice + rationale | "batch default: Option A (recommended)"}
**Decision:** {what this means for the plan}
**Needs new ADR / INV / RN:** {Yes/No each}
```

---

## 5. Phase 4 — Change Plan (`changes/CHANGE-PLAN-{CHG-ID}.md`)

```markdown
# Change Plan — {CHG-ID}

> Generated: YYYY-MM-DD · Source: {text | CHANGE-REQUEST.md | IMPL-FEEDBACK-FASE-N.md}
> Change Requests: {N} (ADD:{N} MODIFY:{N} DEPRECATE:{N}) · Documents affected: {N}
> Complexity: {Low | Medium | High | Very High} · Spec version: v{current} → v{proposed}

## Summary Table
| # | CR-ID | Type | REQ-ID | Documents | Breaking | Delta file |
|---|-------|------|--------|-----------|----------|------------|
| 1 | CR-001 | ADD | REQ-F-{new} | 5 | No | changes/CR-001-{slug}.md |

## Application Order
DEPRECATE deltas → MODIFY deltas → ADD deltas; one commit per CR.

| Step | CR | Files (in requirements-first order) | Commit subject |
|------|----|-------------------------------------|----------------|
| 1 | CR-003 | requirements/REQUIREMENTS.md, spec/use-cases/UC-007-{slug}.md, … | docs(specs): deprecate REQ-F-011 {summary} |

## Version Impact
- Spec version: v{current} → v{proposed}; REQUIREMENTS.md: {current} → {proposed}
- Documents with version bumps: {list}
```

---

## 6. Delta file (`changes/CR-NNN-{slug}.md`)

One per CR; it holds the full proposal before any spec is modified.

```markdown
# Delta Proposal — CR-{NNN}: {Title}

> **Change:** {CHG-ID} · **Type:** ADD | MODIFY | DEPRECATE
> **Status:** DRAFT | REVIEWED | APPROVED | APPLIED | REJECTED
> **Created:** YYYY-MM-DD · **Complexity:** {…} · **Breaking:** {Yes | No}
> **Origin:** {user | CHANGE-REQUEST.md | IF-{FASE}-{SEQ}}

## Affected Files
| # | File | Action | Section |
|---|------|--------|---------|
| 1 | requirements/REQUIREMENTS.md | ADD | Functional Requirements |

## New / Modified Requirement (ADD, MODIFY)

### REQ-F-{NNN}: {Title}
- **Statement:** WHEN {trigger} THE {system} SHALL {behavior}
- **Category:** Functional
- **Priority:** Must have | Should have | Nice to have
- **Source:** CR-{NNN}, Q-{NNN}
- **Rationale:** {why}
- **Acceptance criteria:**
  - GIVEN {context} WHEN {action} THEN {outcome}
- **Dependencies:** {REQ-…, or "None"}

(For MODIFY show the current statement as **Before** and the new one as **After**.)
(For DEPRECATE: current statement, deprecation reason, migration or "None — clean removal".)

## Deltas

### Delta 1: {file}
**Action:** ADD | MODIFY | REMOVE · **Section:** {section}
**Before:**
> {current text, or "(new section)"}
**After:**
> {proposed text}
**Rationale:** {why, linked to CR-{NNN}}

## New Artifacts
| Type | ID | Title | Origin |
|------|----|-------|--------|

## Breaking Changes (if any)
| Change | Impact | Migration |
|--------|--------|-----------|

## Impact Summary
| Dimension | Value |
|-----------|-------|
| Direct / indirect documents | {N} / {N} |
| Conflicts | {N} |
| New artifacts | INV:{N} ADR:{N} RN:{N} BDD:{N} |
| Depends on CRs | {list or "None"} |

## Clarification Decisions
| Q# | Question | Answer | Decision |
|----|----------|--------|----------|
```

Multi-REQ deprecations (a whole feature) add a Feature Sunset Plan: `maintenance-classification.md` §6.

---

## 7. CHANGELOG entry (`spec/CHANGELOG.md`, created if absent)

```markdown
## v{X.Y.Z} — YYYY-MM-DD ({CHG-ID})

### Added
- REQ-F-{NNN}: {title} (CR-{NNN})

### Changed
- UC-{NNN}: {description} (CR-{NNN})

### Deprecated
- REQ-F-{NNN}: {title} — {reason} (CR-{NNN})

See `changes/CHANGE-REPORT-{CHG-ID}.md`.
```

Version bumps: spec documents ADD → patch, MODIFY or DEPRECATE → minor, several → the highest; REQUIREMENTS.md → minor for any change.
