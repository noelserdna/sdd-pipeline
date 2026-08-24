# Reconciliation Strategies

> Estrategias detalladas para aplicar reconciliación por tipo de divergencia, incluyendo templates de actualización de specs, patrones de deprecación e impacto en pipeline. Utilizado por las Fases 5 y 7 de `sdd-reconcile`.

---

## 1. Strategy: NEW_FUNCTIONALITY → Update Specs

### Requirements Update

Add new requirement to `requirements/REQUIREMENTS.md`:

```markdown
### REQ-{GROUP}-{NNN}: {Feature Name} [RECONCILED]

> {EARS statement derived from code behavior}

- **Source:** Reconciliation — code feature without spec coverage
- **Priority:** {inferred from code: CRITICAL/HIGH/MEDIUM/LOW}
- **Reconciled:** {ISO-8601}
- **Code reference:** `{file}:{lines}`
- **Test reference:** `{test_file}:{lines}` (or "No tests found")
```

### Specification Updates

**Use Cases** (`spec/use-cases.md`):
```markdown
### UC-{NNN}: {Use Case Name} [RECONCILED]

**Actor:** {inferred from auth/entry point}
**Preconditions:** {from code guards and validations}
**Main Flow:**
1. {Step derived from handler logic}
2. ...
**Postconditions:** {from return values and side effects}
**Alternative Flows:** {from error handling paths}

> Reconciled: {date} — Feature found in code without prior specification.
```

**API Contracts** (`spec/contracts.md`):
```markdown
### {METHOD} {path} [RECONCILED]

**Request:**
- Headers: {from middleware requirements}
- Body: {from request schema/validation}

**Response:**
- 200: {from successful return}
- 4XX: {from validation errors}
- 5XX: {from error handling}

> Reconciled: {date} — Endpoint found in code without prior contract.
```

**Domain Model** (`spec/domain.md`):
```markdown
### {Entity Name} [RECONCILED]

| Field | Type | Constraints | Notes |
|-------|------|------------|-------|
| {field} | {type} | {validation rules} | Reconciled: {date} |

> Reconciled: {date} — Entity found in code without prior domain documentation.
```

---

## 2. Strategy: REMOVED_FEATURE → Deprecate in Specs

### Requirements Deprecation

```markdown
### REQ-{GROUP}-{NNN}: {Original Name} ~~[ACTIVE]~~ [DEPRECATED]

> ~~{original EARS statement}~~

- **Status:** DEPRECATED
- **Deprecated:** {ISO-8601}
- **Reason:** Feature no longer present in codebase (detected by reconciliation)
- **Last known code:** {git commit SHA where code was last seen, if traceable}
- **Impact:** {downstream specs that reference this requirement}
```

### Specification Deprecation

For each spec document referencing the removed feature:

```markdown
### UC-{NNN}: {Use Case Name} [DEPRECATED]

> **Status:** Deprecated — Feature removed from codebase.
> **Deprecated:** {ISO-8601}
> **Previous implementation:** {brief description}

{Original content preserved but struck through or marked clearly as deprecated}
```

### Cascade Deprecation

When a requirement is deprecated, also deprecate:
1. Use cases that ONLY serve this requirement
2. Workflow steps that ONLY support this use case
3. API contracts for endpoints that no longer exist
4. BDD scenarios for the deprecated behavior
5. Test plan entries referencing the deprecated feature

Do NOT deprecate shared artifacts (used by multiple requirements).

---

## 3. Strategy: BEHAVIORAL_CHANGE → User Decision

### Option A: Code Is Correct (update spec)

```markdown
### REQ-{GROUP}-{NNN}: {Feature Name} [UPDATED]

> {NEW EARS statement matching current code behavior}

- **Previous:** {old EARS statement}
- **Updated:** {ISO-8601}
- **Reason:** Reconciliation — code behavior changed from original specification
- **Change type:** Behavioral
- **Decision:** Code is authoritative (user confirmed)
```

### Option B: Spec Is Correct (flag as defect)

```markdown
### DEFECT-{NNN}: {Feature Name} behavioral regression

- **Requirement:** REQ-{GROUP}-{NNN}
- **Expected (per spec):** {EARS statement from spec}
- **Actual (in code):** {observed behavior}
- **Location:** `{file}:{lines}`
- **Tests:** {failing/missing}
- **Severity:** {based on impact}
- **Created by:** Reconciliation ({ISO-8601})
```

This defect entry goes to `reconciliation/RECONCILIATION-REPORT.md` and optionally creates a task for `sdd-task-implementer`.

### Option C: Both Need Changes

Trigger `sdd-req-change` with the divergence details. This enters the formal change management process.

### Option D: Skip/Defer

Document in reconciliation report as "Deferred" with reason.

---

## 4. Strategy: REFACTORING → Update Technical Refs

### File Path Updates

Search and replace in all spec documents:
```
Old: `src/old/path/module.ts`
New: `src/new/path/module.ts`
```

Affected documents:
- `spec/contracts.md` (implementation references)
- `spec/use-cases.md` (implementation notes)
- `plan/fases/FASE-*.md` (file listings)
- `task/TASK-FASE-*.md` (file references)
- `test/TEST-PLAN.md` (test file paths)

### Method/Function Rename Updates

```
Old reference: `UserService.createUser()`
New reference: `UserService.registerUser()`
```

### API Path Updates (structural, not behavioral)

If endpoint path changed but behavior is identical:
```markdown
### POST /api/v2/users (previously POST /api/v1/users) [REFACTORED]

> Path updated from v1 to v2. Behavior unchanged.
> Refactored: {ISO-8601}
```

### Architecture Updates

If module/package structure changed:
- Update `plan/ARCHITECTURE.md` component diagrams
- Update module descriptions
- Preserve behavioral descriptions (they didn't change)

---

## 5. Strategy: BUG_OR_DEFECT → Flag for Decision

Present to user with full context:

```
DEFECT CANDIDATE: {title}

What the spec says:
  REQ-{ID}: {EARS statement}

What the code does:
  {observed behavior}
  Location: {file}:{lines}

Test status:
  {test_file}: FAILING ← confirms spec is correct
  OR: No tests exist for this behavior

Options:
(A) This is a bug — create defect task (spec is right, code is wrong)
(B) This is intentional — update spec (code is right, spec is outdated)
(C) Need more investigation — defer
```

---

## 6. Cascade Implications

### Which Stages Become Stale After Reconciliation

| Artifact Modified | Stages Invalidated |
|-------------------|-------------------|
| `requirements/REQUIREMENTS.md` | `specifications-engineer`, `spec-auditor`, `test-planner`, `plan-architect`, `task-generator` |
| `spec/domain.md` | `spec-auditor`, `test-planner`, `plan-architect`, `task-generator` |
| `spec/use-cases.md` | `spec-auditor`, `test-planner`, `plan-architect`, `task-generator` |
| `spec/contracts.md` | `spec-auditor`, `test-planner` |
| `spec/nfr.md` | `spec-auditor`, `test-planner` |
| `spec/workflows.md` | `spec-auditor`, `test-planner`, `plan-architect` |
| `plan/` documents | `task-generator` |
| `task/` documents | `task-implementer` |

### Minimizing Cascade

- `REFACTORING` changes (path/name updates) should NOT trigger full cascade — only refresh hashes
- `DEPRECATED` markers should trigger cascade only if the deprecated item was in active use
- `NEW_FUNCTIONALITY` additions always trigger cascade (new content needs audit, test plan, etc.)

---

## 7. Reconciliation Markers

All reconciled artifacts receive markers for traceability:

| Marker | Meaning | Applied To |
|--------|---------|-----------|
| `[RECONCILED]` | New item added during reconciliation | New reqs, specs |
| `[DEPRECATED]` | Feature removed from code | Existing reqs, specs |
| `[UPDATED]` | Content changed to match code | Modified reqs, specs |
| `[REFACTORED]` | Technical reference updated | Path/name changes |
| `[DEFECT]` | Potential bug flagged | Divergence items |
| `[DEFERRED]` | Decision postponed | Ambiguous items |
