# Findings Taxonomy

> Taxonomía completa de hallazgos del reverse engineering: categorías, markers, criterios de detección, severidad y acciones recomendadas. Utilizado por la Fase 10 de `sdd-reverse-engineer`.

---

## 1. Finding Categories

### `[DEAD-CODE]` — Unreachable or Unused Code

Code that exists in the repository but is not executed in any production path.

| Subtype | Detection Criteria | Severity | Action |
|---------|-------------------|----------|--------|
| **Unused export** | Exported symbol not imported by any module | INFO | Document; recommend removal |
| **Unreachable function** | No call path from any entry point | MEDIUM | Document; verify not used via reflection |
| **Commented-out code** | Block of `//` or `#` comments > 5 lines that appear to be code | LOW | Document; recommend removal (git has history) |
| **Dead branch** | Conditional that always evaluates to same value | MEDIUM | Document; recommend simplification |
| **Deprecated code** | Marked with `@deprecated` or deprecation comment | INFO | Document; check for remaining callers |
| **Orphan file** | Source file not imported/required by any other file | MEDIUM | Verify if it's an entry point; if not, dead code |
| **Unused dependency** | Package in dependencies never imported | LOW | Document; recommend removal |
| **Dead route** | Route defined but handler is a no-op or always returns 404 | MEDIUM | Document; recommend removal |

### `[TECH-DEBT]` — Suboptimal Implementation

Code that works but should be improved for maintainability, performance, or correctness.

| Subtype | Detection Criteria | Severity | Action |
|---------|-------------------|----------|--------|
| **TODO/FIXME** | Comment containing TODO, FIXME, XXX, HACK | Varies by age | Document; categorize and prioritize |
| **Complexity hotspot** | Cyclomatic complexity > 10 or nesting > 4 levels | MEDIUM | Document; recommend refactoring |
| **Code duplication** | Similar code blocks (>10 lines) in multiple locations | MEDIUM | Document; recommend extraction |
| **Large file** | Single file > 500 lines | LOW | Document; recommend splitting |
| **Large function** | Single function > 50 lines | LOW | Document; recommend decomposition |
| **Magic numbers** | Numeric literals without named constant | LOW | Document; recommend named constants |
| **Type suppression** | `as any`, `type: ignore`, `@SuppressWarnings` | MEDIUM | Document; recommend proper typing |
| **Missing error handling** | Async operation without try/catch or .catch() | HIGH | Document; recommend error handling |
| **Inconsistent patterns** | Same concern handled differently across modules | LOW | Document; recommend standardization |
| **Outdated dependencies** | Dependencies with known vulnerabilities or major version behind | HIGH | Document; recommend update |

### `[WORKAROUND]` — Temporary Fixes

Code that addresses a problem through a non-ideal solution, typically with an intent to fix properly later.

| Subtype | Detection Criteria | Severity | Action |
|---------|-------------------|----------|--------|
| **Explicit workaround** | Comment containing "workaround", "temporary", "hack" | MEDIUM | Document; track for resolution |
| **Environment hack** | Code path only for specific environment (not config-driven) | MEDIUM | Document; recommend config-driven approach |
| **Version pin** | Specific version check or pin due to upstream bug | MEDIUM | Document; track upstream fix |
| **Monkey patch** | Runtime modification of existing objects/prototypes | HIGH | Document; recommend proper solution |
| **Error swallowing** | Empty catch block or catch that only logs | MEDIUM | Document; recommend proper error handling |
| **Retry without backoff** | Retry loop without exponential backoff or limit | MEDIUM | Document; recommend proper retry strategy |
| **Hardcoded config** | Values that should be configurable but are inline | LOW | Document; recommend externalization |
| **Compatibility shim** | Code that exists solely for backward compatibility | LOW | Document; track for removal |

### `[INFRASTRUCTURE]` — Cross-Cutting Patterns

Patterns that represent infrastructure concerns rather than business logic. Not necessarily problems — documented for SDD completeness.

| Subtype | Detection Criteria | Severity | Action |
|---------|-------------------|----------|--------|
| **Logging pattern** | Logger usage and configuration | INFO | Document as NFR |
| **Error handling pattern** | Global error handler, error middleware | INFO | Document as NFR |
| **Auth pattern** | Authentication/authorization mechanism | INFO | Document as security requirement |
| **Caching pattern** | Cache usage and strategy | INFO | Document as NFR |
| **Rate limiting** | Rate limiter configuration | INFO | Document as NFR |
| **Health check** | Health/readiness endpoints | INFO | Document as operational requirement |
| **Metrics/monitoring** | Metrics collection and reporting | INFO | Document as operational requirement |
| **Background processing** | Queue workers, cron jobs, schedulers | INFO | Document as requirements |

### `[ORPHAN]` — Code Without Traceable Requirement

Code that functions correctly but has no clear business requirement driving it.

| Subtype | Detection Criteria | Severity | Action |
|---------|-------------------|----------|--------|
| **Orphan endpoint** | API endpoint with no corresponding requirement | MEDIUM | May need requirement creation or removal |
| **Orphan feature** | Functional code not traceable to any business need | MEDIUM | Investigate: undocumented feature or dead code? |
| **Orphan test** | Test that doesn't correspond to any requirement | LOW | May indicate a missing requirement |
| **Orphan config** | Configuration with no clear consumer | LOW | May be dead config |

### `[IMPLICIT-RULE]` — Undocumented Business Logic

Business rules embedded in code without documentation, comments, or clear naming.

| Subtype | Detection Criteria | Severity | Action |
|---------|-------------------|----------|--------|
| **Hidden validation** | Conditional that enforces a business rule without explanatory name | HIGH | Extract as explicit requirement |
| **Magic threshold** | Numeric threshold used in business logic without explanation | HIGH | Document and name the threshold |
| **Implicit state rule** | State transition guard without documented reason | MEDIUM | Document the business rule |
| **Implicit ordering** | Sequential operations where order matters but isn't documented | MEDIUM | Document the dependency |
| **Conditional pricing** | Price/discount logic without business documentation | HIGH | Extract as business requirement |
| **Access control rule** | Permission check without documented authorization matrix | HIGH | Document as security requirement |

---

## 2. Severity Matrix

| Severity | Criteria | Expected Response |
|----------|---------|-------------------|
| **CRITICAL** | Business logic at risk, data integrity threat, security gap | Immediate attention; create task |
| **HIGH** | Significant maintainability issue, missing error handling, undocumented business rule | Create task in next sprint; extract requirement |
| **MEDIUM** | Code quality issue, workaround in place, dead code with side effects | Plan for resolution; document in backlog |
| **LOW** | Minor quality issue, cosmetic, small duplication | Document; address opportunistically |
| **INFO** | Infrastructure pattern documentation, not a problem | Document for SDD completeness only |

### Severity Modifiers

- **In critical path** (auth, payments, data writes): +1 severity level
- **Has tests covering it**: -1 severity level (risk is managed)
- **Recently modified** (< 30 days): no change (actively maintained)
- **Not modified in > 1 year**: +1 severity level (may be forgotten)
- **Multiple contributors touched it**: no change (team awareness exists)
- **Single contributor and they left**: +1 severity level

---

## 3. Findings Report Template

```markdown
# Findings Report — Reverse Engineering

> Generated: {ISO-8601}
> Project: {project-name}
> Scope: {full | scoped paths}

## Executive Summary

- **Total findings:** {count}
- **By severity:** CRITICAL: {n}, HIGH: {n}, MEDIUM: {n}, LOW: {n}, INFO: {n}
- **By category:** Dead code: {n}, Tech debt: {n}, Workarounds: {n}, Infrastructure: {n}, Orphans: {n}, Implicit rules: {n}

## Critical & High Severity Findings

### {FINDING-ID}: {Title}

- **Category:** {marker}
- **Subtype:** {subtype}
- **Severity:** {level}
- **Location:** `{file}:{lines}`
- **Description:** {what was found}
- **Evidence:** {code snippet or pattern description}
- **Recommended action:** {what to do about it}
- **Related requirements:** {REQ-XXX if applicable}

## Medium Severity Findings

{same format, grouped by category}

## Low Severity & Informational

{condensed table format}

| ID | Category | Subtype | Location | Description | Action |
|----|----------|---------|----------|-------------|--------|
| ... | ... | ... | ... | ... | ... |

## Statistics

### Dead Code Inventory

| Subtype | Count | Total Lines | Locations |
|---------|-------|-------------|-----------|
| ... | ... | ... | ... |

### Tech Debt Summary

| Subtype | Count | Oldest | Newest | Avg Age |
|---------|-------|--------|--------|---------|
| ... | ... | ... | ... | ... |

### Workaround Registry

| ID | Description | Location | Workaround Age | Upstream Issue |
|----|-------------|----------|---------------|----------------|
| ... | ... | ... | ... | ... |

## Traceability Impact

Findings that affect the traceability chain:
- Requirements needing creation (from [IMPLICIT-RULE] findings)
- Requirements needing removal (from [DEAD-CODE] findings that map to existing reqs)
- Orphan code requiring requirement assignment or removal decision
```

---

## 4. Finding ID Format

```
FND-{CATEGORY}-{NNN}

Categories:
  DC = Dead Code
  TD = Tech Debt
  WA = Workaround
  IF = Infrastructure
  OR = Orphan
  IR = Implicit Rule

Examples:
  FND-DC-001: Unused export in auth module
  FND-TD-015: TODO comment from 2023 about refactoring
  FND-IR-003: Hidden discount calculation rule
```
