# Reconciliation Report Template

> Template del informe de reconciliación generado por `sdd-reconcile`. Utilizado por la Fase 8 para generar `reconciliation/RECONCILIATION-REPORT.md`.

---

## Template

```markdown
# Reconciliation Report

> Generated: {ISO-8601}
> Project: {project-name}
> Mode: {default | dry-run | code-wins | scoped}
> Scope: {full | paths}
> Previous reconciliation: {date or "None"}

---

## 1. Executive Summary

| Metric | Value |
|--------|-------|
| Total divergences found | {N} |
| Auto-resolved | {N} |
| User-decided | {N} |
| Deferred | {N} |
| Defects flagged | {N} |

### By Type

| Type | Count | Resolution |
|------|-------|-----------|
| NEW_FUNCTIONALITY | {N} | Specs updated |
| REMOVED_FEATURE | {N} | Specs deprecated |
| BEHAVIORAL_CHANGE | {N} | {N} code wins, {N} spec wins, {N} deferred |
| REFACTORING | {N} | Technical refs updated |
| BUG_OR_DEFECT | {N} | {N} defect tasks created |
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
| 1 | {name} | `{file}:{line}` | REQ-{ID} | {HIGH/MEDIUM} |
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
- **Decision:** {Code wins / Spec wins / Deferred}
- **Action taken:** {description of change applied}

### 3.2 Potential Bugs/Defects

#### DIV-{NNN}: {Title}

- **Type:** BUG_OR_DEFECT
- **Confidence:** {level}
- **Spec says:** {EARS statement}
- **Code does:** {observed behavior}
- **Test status:** FAILING — `{test_file}:{line}`
- **Decision:** {Defect task created / Spec updated / Deferred}
- **Task:** {TASK-ID if created}

### 3.3 Ambiguous Cases

#### DIV-{NNN}: {Title}

- **Type:** AMBIGUOUS
- **Reason for ambiguity:** {why classification was unclear}
- **Evidence for:** {possible type A with signals}
- **Evidence against:** {counter-signals}
- **Decision:** {final classification and action}

---

## 4. Deferred Items

| # | Title | Type | Reason for Deferral | Revisit Recommendation |
|---|-------|------|--------------------|-----------------------|
| 1 | {name} | {type} | {reason} | {when to revisit} |
| ... | ... | ... | ... | ... |

---

## 5. Artifacts Modified

### Requirements Changes

| File | Changes | Lines Modified |
|------|---------|---------------|
| `requirements/REQUIREMENTS.md` | +{N} new, {N} deprecated, {N} updated | {N} |

### Specification Changes

| File | Changes | Lines Modified |
|------|---------|---------------|
| `spec/domain.md` | {description} | {N} |
| `spec/use-cases.md` | {description} | {N} |
| `spec/contracts.md` | {description} | {N} |
| `spec/workflows.md` | {description} | {N} |
| `spec/nfr.md` | {description} | {N} |

### Other Artifacts

| File | Changes | Lines Modified |
|------|---------|---------------|
| `plan/ARCHITECTURE.md` | {if path refs updated} | {N} |
| `task/TASK-FASE-*.md` | {if path refs updated} | {N} |

---

## 6. Pipeline Cascade Impact

### Stages Invalidated

| Stage | Reason | Recommended Action |
|-------|--------|--------------------|
| `spec-auditor` | {requirements/specs changed} | Re-run audit |
| `test-planner` | {specs changed} | Update test plan |
| `plan-architect` | {specs changed} | Review architecture |
| `task-generator` | {plan changed} | Regenerate tasks |

### Recommended Next Steps

1. {First recommended action with exact command}
2. {Second recommended action}
3. ...

---

## 7. Traceability Impact

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
3. In `--dry-run` mode, sections 2 and 5 show "Would apply" instead of "Applied"
4. In `--code-wins` mode, section 3 is empty (all resolved as auto)
5. The Executive Summary should be sufficient for a quick review — details below for deep dive
