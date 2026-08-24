# Alignment Audit Checklist

> Reference document for Phase 7 (Alignment Audit) of `sdd-req-change`.
> Defines the focused mini-audit checks executed after changes are applied.
> This is NOT a full cross-document audit (use `sdd-spec-auditor` for that).

---

## 1. Scope Definition

The alignment audit is **focused**: it only checks documents that were modified or created during the change execution (Phase 6). It does NOT audit the entire specification repository.

### Documents in Scope

```
Documents modified in Phase 6 execution
+ Documents newly created in Phase 6
+ REQUIREMENTS.md (always in scope)
+ CHANGELOG.md (always in scope)
```

### Documents Out of Scope

```
All spec documents NOT touched by the current change
Previous audit findings (handled by sdd-spec-auditor)
Security-specific checks (handled by sdd-security-auditor)
```

---

## 2. Alignment Checks (AA-01 through AA-10)

### AA-01: REQ → Spec Forward Coverage (Critical)

**Question:** Does every new/modified requirement have at least one specification backing it?

**Procedure:**
1. List all REQs added or modified in this change session
2. For each REQ, verify the `Source` field in traceability points to existing spec documents
3. Verify those spec documents contain the referenced content

**Pass criteria:** Every REQ has at least one valid spec source
**Fail example:** REQ-EXT-015 lists `Source: UC-042` but UC-042.md doesn't exist

**Auto-fixable:** No (requires creating the missing spec)

---

### AA-02: Spec → REQ Backward Coverage (Critical)

**Question:** Does every modified spec section contribute to at least one requirement?

**Procedure:**
1. List all spec sections added or modified
2. For each section, verify at least one REQ references it in traceability
3. Check REQUIREMENTS.md §10 (Coverage) includes the document

**Pass criteria:** Every modified spec section is covered by at least one REQ
**Fail example:** New section in UC-001 "Bulk Upload Flow" has no REQ pointing to it

**Auto-fixable:** No (requires creating a REQ or updating traceability)

---

### AA-03: Traceability Chain Completeness (High)

**Question:** Does every new/modified REQ have complete traceability links?

**Procedure:**
For each REQ, verify ALL four directions have at least one entry:

| Direction | Required | Check |
|-----------|----------|-------|
| Source | Yes | At least one spec file (UC, WF, ADR, etc.) |
| Implements | Yes | At least one UC or WF |
| Verifies | Yes | At least one BDD scenario |
| Guarantees | Conditional | At least one INV (if constraint exists) |

**Pass criteria:** All mandatory directions populated with valid references
**Fail example:** REQ-EXT-015 has no `Verifies` entry (no BDD scenario)

**Auto-fixable:** Partially (can add placeholder BDD reference, but scenario must be created)

---

### AA-04: Cross-Reference Validity (Critical)

**Question:** Do all cross-references in modified documents resolve to existing targets?

**Procedure:**
1. For each modified document, extract all references (UC-NNN, WF-NNN, INV-AREA-NNN, ADR-NNN, RN-NNN, REQ-SUB-NNN, BDD-feature)
2. Verify each reference resolves to an existing document/section
3. Check for dangling references (pointing to deleted/deprecated content)

**Pattern matching:**
```regex
UC-\d{3}           → verify spec/use-cases/UC-{NNN}.md exists
WF-\d{3}           → verify spec/workflows/WF-{NNN}.md exists
INV-[A-Z]+-\d{3}   → verify exists in spec/domain/05-INVARIANTS.md
ADR-\d{3}          → verify spec/adr/ADR-{NNN}*.md exists
RN-\d{3}           → verify exists in spec/CLARIFICATIONS.md
REQ-[A-Z]+-\d{3}   → verify exists in requirements/REQUIREMENTS.md
BDD-[a-z-]+        → verify spec/tests/BDD-{name}.md exists
API-[a-z-]+        → verify spec/contracts/API-{name}.md exists
```

**Pass criteria:** All references resolve to existing content
**Fail example:** UC-001.md references INV-EXT-015 but INVARIANTS.md only goes up to INV-EXT-014

**Auto-fixable:** No (broken reference must be corrected to valid target)

---

### AA-05: Glossary Compliance (High)

**Question:** Do modified sections use only ubiquitous language terms?

**Procedure:**
1. Load `spec/domain/01-GLOSSARY.md` term list
2. For each modified section, scan for known synonym violations:

| Forbidden Term | Correct Term |
|---------------|-------------|
| job, task, proceso | Extraction |
| resume, hoja de vida | CV |
| tenant, empresa | Organizacion |
| nota, calificacion | Score de dimension |
| Match, Score (standalone) | MatchResult |
| Job, Vacancy, Position | JobOffer |
| aplicante, postulante | Candidato |
| datos personales | PII |
| screening | (check specific glossary) |
| interview (as process) | (check specific glossary) |

3. Flag any violations in modified text

**Pass criteria:** No glossary violations in modified sections
**Fail example:** New UC section uses "tenant" instead of "Organizacion"

**Auto-fixable:** Yes (replace synonym with correct term)

---

### AA-06: Contradiction Check (Critical)

**Question:** Does any modified section contradict another document section?

**Procedure:**
1. For each modified section, identify the assertion (what it claims)
2. Search for the same topic in other documents
3. Verify no conflicting assertions exist

**Common contradiction patterns:**
- Different timeout values in different documents
- Different state names for same entity
- Different role permissions in UC vs PERMISSIONS-MATRIX
- Different field types in ENTITIES vs API contracts
- Different enum values in different documents

**Pass criteria:** No contradictions detected between modified and existing content
**Fail example:** UC-001 says timeout is 480s but nfr/LIMITS.md still says 360s

**Auto-fixable:** No (requires deciding which is correct)

---

### AA-07: EARS Pattern Compliance (Medium)

**Question:** Do all new/modified requirements use valid EARS pattern?

**Procedure:**
1. For each new/modified REQ, extract the EARS statement
2. Verify it matches one of the 6 valid patterns:

| Pattern | Regex Signal |
|---------|-------------|
| Ubiquitous | `^The .+ shall .+\.$` |
| Event-Driven | `^WHEN .+, the .+ SHALL .+\.$` |
| State-Driven | `^WHILE .+, the .+ SHALL .+\.$` |
| Optional | `^WHERE .+, the .+ SHALL .+\.$` |
| Unwanted | `^IF .+, THEN the .+ SHALL .+\.$` |
| Complex | `^WHILE .+, WHEN .+, the .+ SHALL .+\.$` |

3. Verify statement is specific and testable (not vague)

**Pass criteria:** All EARS statements match a valid pattern and are specific
**Fail example:** "The system should handle bulk uploads" (missing SHALL, vague)

**Auto-fixable:** Partially (can suggest corrected EARS statement)

---

### AA-08: Acceptance Criteria Testability (Medium)

**Question:** Are all new/modified Gherkin scenarios concrete and testable?

**Procedure:**
1. For each new/modified acceptance criteria, verify Gherkin structure:
   - `Given` has concrete precondition (not vague)
   - `When` has specific action (not generic)
   - `Then` has verifiable outcome (not subjective)

2. Check for anti-patterns:

| Anti-Pattern | Example | Problem |
|-------------|---------|---------|
| Vague precondition | `Given the system is running` | Always true, adds no value |
| Generic action | `When the user does something` | Not specific enough to test |
| Subjective outcome | `Then the result is good` | Not measurable |
| Missing precondition | `When POST /api/...` (no Given) | No context for test |
| No assertion | `Then the system processes it` | No verifiable outcome |

**Pass criteria:** All Gherkin scenarios are concrete, specific, and verifiable
**Fail example:** `Then the system handles the error appropriately` (subjective)

**Auto-fixable:** No (requires domain knowledge to make concrete)

---

### AA-09: No Orphan References — DEPRECATE only (Critical)

**Question:** After deprecation, does any remaining active document still reference the deprecated content?

**Procedure:**
1. List all deprecated REQ IDs, INV IDs, UC IDs, etc.
2. Search ALL modified documents for references to deprecated IDs
3. Search REQUIREMENTS.md active sections (§4-§8) for deprecated references
4. If found, these are orphan references that must be cleaned

**Pass criteria:** Zero references to deprecated content in active sections
**Fail example:** REQ-MAT-003 still references deprecated REQ-CAN-011 in traceability

**Auto-fixable:** Partially (can remove reference, but may need replacement)

---

### AA-10: Dependent REQ Update — DEPRECATE only (High)

**Question:** Have all requirements that depended on the deprecated requirement been updated?

**Procedure:**
1. From Phase 2 impact analysis, identify all dependent REQs
2. Verify each dependent REQ has been:
   - Updated to remove dependency, OR
   - Updated with alternative dependency, OR
   - Also deprecated (if the dependency was essential)

**Pass criteria:** All dependent REQs addressed
**Fail example:** REQ-CAN-010 depends on REQ-CAN-011 (deprecated) but wasn't updated

**Auto-fixable:** No (requires user decision on how to update dependent)

---

## 3. Audit Execution Protocol

### Step 1: Collect Scope

```
affected_documents = [files modified in Phase 6]
new_reqs = [REQs added]
modified_reqs = [REQs modified]
deprecated_reqs = [REQs deprecated]
new_artifacts = [INVs, ADRs, RNs, BDDs created]
```

### Step 2: Execute Checks

```
For each check AA-01 through AA-08:
  run check against affected_documents
  if check fails:
    record finding with location, severity, details
    if auto-fixable:
      apply fix
      mark as "Auto-Fixed"
    else:
      mark as "Open Item"

If deprecated_reqs is not empty:
  run AA-09 and AA-10
```

### Step 3: Re-verify Auto-Fixes

```
For each auto-fixed finding:
  re-run the original check
  if still fails:
    escalate to "Open Item"
  else:
    mark as "Resolved (Auto-Fix)"
```

### Step 4: Generate Results

```markdown
## Alignment Audit Results

> Scope: {N} documents audited
> Checks executed: {8 | 10}
> Total findings: {N}
> Auto-fixed: {N}
> Open items: {N}

### Check Results

| # | Check | Status | Findings | Auto-Fixed |
|---|-------|--------|----------|------------|
| AA-01 | REQ → Spec Forward | {PASS/FAIL} | {N} | {N} |
| AA-02 | Spec → REQ Backward | {PASS/FAIL} | {N} | {N} |
| ... | ... | ... | ... | ... |

### Findings Detail (if any)

| # | Check | Severity | Location | Problem | Resolution |
|---|-------|----------|----------|---------|------------|
| 1 | AA-05 | High | UC-001.md:45 | Uses "tenant" instead of "Organizacion" | Auto-Fixed |
| 2 | AA-04 | Critical | UC-001.md:78 | References INV-EXT-099 (doesn't exist) | Open Item |

### Verdict

{ALIGNED} — All checks passed (with {N} auto-fixes applied)
{GAPS DETECTED} — {N} open items require attention
```

---

## 4. Severity Escalation Rules

| Situation | Action |
|-----------|--------|
| 0 findings | Report ALIGNED |
| Only auto-fixed findings | Report ALIGNED (with auto-fixes noted) |
| 1-2 open items, all Medium/Low | Report ALIGNED with warnings |
| Any Critical open item | Report GAPS DETECTED, list in Change Report §5 |
| Any High open item | Report GAPS DETECTED, list in Change Report §5 |
| 3+ Medium open items | Report GAPS DETECTED |

---

## 5. Post-Audit Actions

| Verdict | Action |
|---------|--------|
| ALIGNED | Proceed to Phase 8 (Change Report) |
| GAPS DETECTED (auto-fixable only) | Apply fixes, re-audit, then Phase 8 |
| GAPS DETECTED (open items) | Include in Change Report §5, recommend `sdd-spec-auditor` for full audit |
