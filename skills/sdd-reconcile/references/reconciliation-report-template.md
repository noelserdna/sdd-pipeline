# Reconciliation Report Template

> Used by Phase 8 of `sdd-reconcile` to write `reconciliation/RECONCILIATION-REPORT.md`.

---

## Template

```markdown
# Reconciliation Report

> Generated: {ISO-8601}
> Project: {project-name}
> Mode: {default | dry-run | code-wins | scoped}
> Scope: {full | paths}
> Previous reconciliation: {date or "None"}
> Gap input: {.sdd/gap-analysis.json {generatedAt} | code scan}
> Tests: {command run | not run}
> Change requests: changes/CR-RECONCILE-{date}.md

---

## 1. Executive Summary

| Metric | Value |
|--------|-------|
| Total divergences found | {N} |
| Auto-resolved | {N} |
| User-decided | {N} |
| Deferred | {N} |
| Defects recorded | {N} |
| Not implemented (gaps) | {N} |

### By Type

| Type | Count | Resolution |
|------|-------|-----------|
| NEW_FUNCTIONALITY | {N} | Specs updated |
| REMOVED_FEATURE | {N} | Specs deprecated |
| NOT_IMPLEMENTED | {N} | Reported as gaps |
| BEHAVIORAL_CHANGE | {N} | {N} A (spec amended), {N} B (defect), {N} C (req-change), {N} D (deferred) |
| REFACTORING | {N} | Technical refs updated |
| BUG_OR_DEFECT | {N} | {N} defects recorded |
| AMBIGUOUS | {N} | {N} resolved, {N} deferred |

### Health Impact

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Spec-code alignment | {X}% | {Y}% | +{Z}% |
| Requirements with code | {X}/{total} | {Y}/{total} | +{Z} |
| Code with requirements | {X}/{total} | {Y}/{total} | +{Z} |

---

## 2. Auto-Resolved Divergences

### 2.1 New Functionality (specs updated)

| # | Feature | Code Location | New Requirement | Confidence |
|---|---------|--------------|-----------------|-----------|
| 1 | {name} | `{file}:{line}` | REQ-F-{NNN} (CR-{NNN}) | {HIGH/MEDIUM} |
| ... | ... | ... | ... | ... |

### 2.2 Removed Features (specs deprecated)

| # | Feature | Original Requirement | Last Code Commit | Deprecation Note |
|---|---------|---------------------|-----------------|-----------------|
| 1 | {name} | REQ-{ID} | `{SHA}` ({date}) | {reason} |
| ... | ... | ... | ... | ... |

### 2.3 Refactoring (technical refs updated)

| # | Change | Old Reference | New Reference | Affected Docs |
|---|--------|--------------|---------------|--------------|
| 1 | {description} | `{old_path}` | `{new_path}` | {doc list} |
| ... | ... | ... | ... | ... |

---

## 3. User-Decided Divergences

### 3.1 Behavioral Changes

#### DIV-{NNN}: {Title}

- **Type:** BEHAVIORAL_CHANGE
- **Confidence:** {level}
- **Spec says:** {EARS statement or spec excerpt}
- **Code does:** {observed behavior}
- **Code location:** `{file}:{lines}`
- **Test status:** {pass/fail/missing}
- **Decision:** {A spec amended (CR-NNN) / B defect / C req-change / D deferred}
- **Action taken:** {description of change applied}

### 3.2 Potential Bugs/Defects

#### DIV-{NNN}: {Title}

- **Type:** BUG_OR_DEFECT
- **Confidence:** {level}
- **Spec says:** {EARS statement}
- **Code does:** {observed behavior}
- **Test status:** FAILING — `{test_file}:{line}`
- **Decision:** {A spec amended (CR-NNN) / B defect / C req-change / D deferred}
- **Next:** {/sdd-task-generator --fase=N --incremental}

### 3.3 Ambiguous Cases

#### DIV-{NNN}: {Title}

- **Type:** AMBIGUOUS
- **Reason for ambiguity:** {why classification was unclear}
- **Evidence for:** {possible type A with signals}
- **Evidence against:** {counter-signals}
- **Decision:** {final classification and action}

---

## 4. Implementation Gaps (NOT_IMPLEMENTED)

| # | Requirement | Spec artifact | Evidence of absence | Next |
|---|-------------|---------------|---------------------|------|
| 1 | REQ-F-{NNN} | UC-{NNN} / API-{NNN}-{NN} | {no symbol/route/commit ever matched} | /sdd-task-generator --fase={N} --incremental |

## 5. Deferred Items

| # | Title | Type | Reason for Deferral | Revisit Recommendation |
|---|-------|------|--------------------|-----------------------|
| 1 | {name} | {type} | {reason} | {when to revisit} |
| ... | ... | ... | ... | ... |

---

## 6. Artifacts Modified

### Requirements Changes

| File | Changes | Lines Modified |
|------|---------|---------------|
| `requirements/REQUIREMENTS.md` | +{N} new, {N} deprecated, {N} updated | {N} |

### Specification Changes

| File | Changes | Lines Modified |
|------|---------|---------------|
| `spec/use-cases/UC-{NNN}-{slug}.md` | {description} | {N} |
| `spec/contracts/API-{module}.md` | {description} | {N} |
| `spec/domain/02-ENTITIES.md` | {description} | {N} |
| `spec/tests/BDD-UC-{NNN}.md` | {description} | {N} |
| `spec/TRACEABILITY-MATRIX.md` | {description} | {N} |

### Artifacts to Regenerate (not edited by reconcile)

| File | Stale reference | Owner |
|------|-----------------|-------|
| `plan/ARCHITECTURE.md` | `{old_path}` → `{new_path}` | sdd-plan-architect |
| `task/TASK-FASE-{N}.md` | `{old_path}` → `{new_path}` | sdd-task-generator |
| `test/TEST-PLAN.md` | `{old_path}` → `{new_path}` | sdd-test-planner |

---

## 7. Pipeline Cascade Impact

### Stages Invalidated

| Stage | Reason | Recommended Action |
|-------|--------|--------------------|
| `specifications-engineer` | {only if requirements/ changed} | Re-run specifications |
| `spec-auditor` … `task-implementer` | {spec/ changed} | Re-run from spec-auditor |

### Recommended Next Steps

1. {First recommended action with exact command}
2. {Second recommended action}
3. ...

---

## 8. Traceability Impact

### New Traceability Links

| From | To | Relationship | Created By |
|------|----|-------------|-----------|
| REQ-{ID} | UC-{ID} | traces-to | Reconciliation |
| ... | ... | ... | ... |

### Broken Traceability Links

| From | To | Reason | Action Needed |
|------|----|--------|---------------|
| REQ-{ID} | UC-{ID} | Requirement deprecated | Deprecate UC |
| ... | ... | ... | ... |

### Traceability Coverage

| Chain Level | Before | After | Delta |
|------------|--------|-------|-------|
| REQ → UC | {X}% | {Y}% | +{Z}% |
| UC → WF | {X}% | {Y}% | +{Z}% |
| UC → API | {X}% | {Y}% | +{Z}% |
| REQ → Code | {X}% | {Y}% | +{Z}% |
| REQ → Test | {X}% | {Y}% | +{Z}% |
```

---

## Usage Notes

1. Replace all `{placeholders}` with actual values during report generation
2. Omit empty sections (e.g., if no defects found, skip section 3.2)
3. In `--dry-run` mode, sections 2 and 6 show "Would apply" instead of "Applied"
4. In `--code-wins` mode, section 3 lists only BUG_OR_DEFECT items with failing tests
5. The Executive Summary should be sufficient for a quick review — details below for deep dive
