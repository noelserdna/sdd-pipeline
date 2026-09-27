# Import Report Template

> Template for `import/IMPORT-REPORT.md` (sdd-import Phase 7). Omit empty sections.

---

## Template

```markdown
# Import Report

> Generated: {ISO-8601}
> Project: {project-name}
> Mode: {default | --format | --target | --merge | --yes}

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
| {group} | {N} | {format: section/sheet} | {N}/{total} |
| ... | ... | ... | ... |

**Total requirements:** {N}

### Specifications Generated

| Document | Items Added | Source |
|----------|------------|--------|
| `spec/domain/02-ENTITIES.md`, `03-VALUE-OBJECTS.md` | {N} entities / value objects | {schemas/tables} |
| `spec/use-cases/UC-NNN-*.md` | {N} use cases | {stories/pages} |
| `spec/tests/BDD-UC-NNN.md` | {N} scenarios | {acceptance criteria} |
| `spec/contracts/API-{module}.md` (`Style: http`) | {N} operations | {OpenAPI paths} |
| `spec/nfr/*.md` | {N} rows | {security/config} |
| `spec/workflows/WF-NNN-*.md` | {N} workflows | {ordered lists} |
| `spec/COVERAGE.md` | {N} modules ({N} SPECIFIED, {N} IMPORTED) | — |

---

## 4. Mapping Details

### Sample Mappings

| # | Original (Source) | SDD Artifact | Conversion |
|---|-------------------|-------------|-----------|
| 1 | {original text/title} | REQ-F-NNN: {EARS statement} | {auto/manual/unconverted} |
| 2 | ... | ... | ... |
| ... | ... | ... | ... |

_(Showing first 10 mappings. Full mapping in generated artifacts.)_

### Priority Distribution

| Priority | Count | Percentage |
|----------|-------|-----------|
| Must have | {N} | {X}% |
| Should have | {N} | {X}% |
| Nice to have | {N} | {X}% |

---

## 5. Skipped Items

| # | Source Item | Reason |
|---|-----------|--------|
| 1 | {title/id} | {reason: empty description, duplicate, task type, etc.} |
| ... | ... | ... |

---

## 6. Defects (Jira bugs)

| # | Source key | Summary | Status | Became requirement? |
|---|-----------|---------|--------|---------------------|
| 1 | {key} | {summary} | {open/resolved} | {REQ-F-NNN or No} |

---

## 7. Parse Errors

| # | File | Line/Row | Error | Item |
|---|------|---------|-------|------|
| 1 | `{file}` | {line} | {error description} | {partial item info} |
| ... | ... | ... | ... | ... |

---

## 8. Merge Report (if --merge)

### Duplicates Handled

| # | Imported Item | Existing Artifact | Action | Confidence |
|---|-------------|------------------|--------|-----------|
| 1 | {imported title} | REQ-F-NNN | {Skip/Merge/Replace} | {X}% |
| ... | ... | ... | ... | ... |

### New Items Added

| # | Artifact ID | Title | Source |
|---|------------|-------|--------|
| 1 | REQ-F-NNN | {title} | {source ref} |
| ... | ... | ... | ... |

---

## 9. Quality Assessment

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

## 10. Items Needing Manual Review

| # | Artifact ID | Issue | Recommended Action |
|---|------------|-------|-------------------|
| 1 | REQ-F-NNN | EARS conversion failed | Convert to EARS syntax manually |
| 2 | REQ-F-NNN | Ambiguous priority | Confirm priority with stakeholder |
| 3 | UC-NNN | Missing actor | Identify the primary actor |
| ... | ... | ... | ... |

---

## 11. Pipeline State Impact

| Stage | Previous Status | New Status | Reason |
|-------|----------------|-----------|--------|
| requirements-engineer | {status} | {status} | {requirements imported} |
| specifications-engineer | {status} | {done \| pending} | {full tree + COVERAGE all SPECIFIED, or "partial import"} |
| spec-auditor | {status} | {status} | {needs audit} |
| ... | ... | ... | ... |

### Recommended Next Steps

1. {First action — e.g., "Review UNCONVERTED requirements and convert to EARS syntax"}
2. {Second action — e.g., "Run `sdd-specifications-engineer` to complete spec/" (partial) or "Run `sdd-spec-auditor`" (complete)}
3. {Third action — e.g., "Run `sdd-reverse-engineer` to fill gaps from code analysis"}
```
