# Import Report Template

> Template del informe de importación generado por `sdd-import`. Utilizado por la Fase 7 para generar `import/IMPORT-REPORT.md`.

---

## Template

```markdown
# Import Report

> Generated: {ISO-8601}
> Project: {project-name}
> Mode: {default | format | target | merge}

---

## 1. Source Files

| File | Format | Size | Items Found |
|------|--------|------|-------------|
| `{path}` | {format} | {size} | {N} |
| ... | ... | ... | ... |

**Total source items:** {N}

---

## 2. Import Statistics

| Metric | Count | Percentage |
|--------|-------|-----------|
| Items parsed | {N} | 100% |
| Items mapped to SDD | {N} | {X}% |
| Items skipped | {N} | {X}% |
| Parse errors | {N} | {X}% |
| Duplicates detected | {N} | {X}% |
| EARS conversions successful | {N} | {X}% |
| EARS conversions failed (UNCONVERTED) | {N} | {X}% |

---

## 3. Artifact Generation Summary

### Requirements Generated

| Group | Count | Source | EARS Converted |
|-------|-------|--------|---------------|
| {GROUP-ID} | {N} | {format: section/sheet} | {N}/{total} |
| ... | ... | ... | ... |

**Total requirements:** {N}

### Specifications Generated

| Document | Items Added | Source |
|----------|------------|--------|
| `spec/domain.md` | {N} entities | {format: schemas/tables} |
| `spec/use-cases.md` | {N} use cases | {format: stories/pages} |
| `spec/contracts.md` | {N} endpoints | {format: paths/API docs} |
| `spec/nfr.md` | {N} NFRs | {format: security/config} |
| `spec/workflows.md` | {N} workflows | {format: sequences/flows} |

---

## 4. Mapping Details

### Sample Mappings

| # | Original (Source) | SDD Artifact | Conversion |
|---|-------------------|-------------|-----------|
| 1 | {original text/title} | REQ-{ID}: {EARS statement} | {auto/manual/unconverted} |
| 2 | ... | ... | ... |
| ... | ... | ... | ... |

_(Showing first 10 mappings. Full mapping in generated artifacts.)_

### Priority Distribution

| Priority | Count | Percentage |
|----------|-------|-----------|
| CRITICAL | {N} | {X}% |
| HIGH | {N} | {X}% |
| MEDIUM | {N} | {X}% |
| LOW | {N} | {X}% |

---

## 5. Skipped Items

| # | Source Item | Reason |
|---|-----------|--------|
| 1 | {title/id} | {reason: empty description, duplicate, task type, etc.} |
| ... | ... | ... |

---

## 6. Parse Errors

| # | File | Line/Row | Error | Item |
|---|------|---------|-------|------|
| 1 | `{file}` | {line} | {error description} | {partial item info} |
| ... | ... | ... | ... | ... |

---

## 7. Merge Report (if --merge)

### Duplicates Handled

| # | Imported Item | Existing Artifact | Action | Confidence |
|---|-------------|------------------|--------|-----------|
| 1 | {imported title} | REQ-{ID} | {Skip/Merge/Replace} | {X}% |
| ... | ... | ... | ... | ... |

### New Items Added

| # | Artifact ID | Title | Source |
|---|------------|-------|--------|
| 1 | REQ-{ID} | {title} | {source ref} |
| ... | ... | ... | ... |

---

## 8. Quality Assessment

### Completeness

| Check | Status | Details |
|-------|--------|---------|
| All items have IDs | {PASS/FAIL} | {details} |
| All requirements have EARS syntax | {PASS/WARN} | {N} unconverted |
| Use cases have actors | {PASS/WARN} | {N} missing actors |
| API contracts have schemas | {PASS/WARN} | {N} missing schemas |
| Cross-references consistent | {PASS/FAIL} | {details} |

### Traceability Readiness

| Link Type | Coverage | Details |
|-----------|----------|---------|
| REQ → UC | {X}% | {N} linked, {N} unlinked |
| UC → API | {X}% | {N} linked, {N} unlinked |
| REQ → Domain | {X}% | {N} linked, {N} unlinked |

### Quality Score

| Dimension | Score | Notes |
|-----------|-------|-------|
| Parse success rate | {X}/10 | Based on error rate |
| EARS conversion rate | {X}/10 | Based on conversion success |
| Completeness | {X}/10 | Based on field coverage |
| Traceability readiness | {X}/10 | Based on cross-reference coverage |
| **Overall** | **{X}/40** | {quality level: Good/Acceptable/Needs Review} |

---

## 9. Items Needing Manual Review

| # | Artifact ID | Issue | Recommended Action |
|---|------------|-------|-------------------|
| 1 | REQ-{ID} | EARS conversion failed | Convert to EARS syntax manually |
| 2 | REQ-{ID} | Ambiguous priority | Confirm priority with stakeholder |
| 3 | UC-{ID} | Missing actor | Identify the primary actor |
| ... | ... | ... | ... |

---

## 10. Pipeline State Impact

| Stage | Previous Status | New Status | Reason |
|-------|----------------|-----------|--------|
| requirements-engineer | {status} | {status} | {requirements imported} |
| specifications-engineer | {status} | {status} | {specs imported} |
| spec-auditor | {status} | {status} | {needs audit} |
| ... | ... | ... | ... |

### Recommended Next Steps

1. {First action — e.g., "Review UNCONVERTED requirements and convert to EARS syntax"}
2. {Second action — e.g., "Run `sdd-spec-auditor` to audit imported specifications"}
3. {Third action — e.g., "Run `sdd-reverse-engineer` to fill gaps from code analysis"}
```

---

## Usage Notes

1. Replace all `{placeholders}` with actual values during report generation
2. Omit empty sections (e.g., if no parse errors, skip section 6)
3. The Quality Assessment section helps users understand import reliability
4. The "Items Needing Manual Review" section is critical — users should address these before proceeding
5. For `--merge` mode, section 7 is especially important
