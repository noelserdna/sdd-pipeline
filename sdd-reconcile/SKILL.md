---
name: sdd-reconcile
description: "Detects drift between existing SDD artifacts (requirements, specifications) and the current codebase, classifies each divergence (new functionality, removed feature, behavioral change, refactoring, bug/defect, ambiguous), applies automatic reconciliation rules where safe, and asks the user for decisions on ambiguous cases. Updates specs and requirements to match reality without ever modifying source code. Triggers on phrases like 'reconcile specs', 'detect drift', 'sync specs with code', 'spec-code alignment', 'fix drift', 'reconcile SDD'."
version: "1.0.0"
---

# Skill: sdd-reconcile — Spec-Code Drift Detection & Alignment

> **Version:** 1.0.0
> **Pipeline position:** Lateral — requires both SDD artifacts AND code to exist
> **Reads from:** `requirements/`, `spec/`, `src/`, `tests/`
> **Invoked by:** `sdd-onboarding` (scenario 3: SDD drift)
> **SWEBOK v4 alignment:** Chapter 01 (Requirements), Chapter 05 (Maintenance), Chapter 09 (Models & Methods)

---

## 1. Purpose & Scope

### What This Skill Does

- **Compares** existing SDD artifacts (requirements, specifications) against the current codebase to detect divergences
- **Classifies** each divergence into one of 6 types using a deterministic algorithm with clear rules
- **Auto-resolves** safe divergences (new functionality, removed features, refactoring) by updating SDD artifacts
- **Flags** unsafe divergences (behavioral changes, potential bugs, ambiguous cases) for user decision
- **Generates** a reconciliation report documenting all findings and actions taken
- **Updates** the pipeline state to reflect reconciled artifact status

### What This Skill Does NOT Do

- Does NOT modify source code (`src/` and `tests/` are read-only)
- Does NOT perform deep code analysis from scratch (use `sdd-reverse-engineer` for that)
- Does NOT create SDD artifacts from nothing (requires existing specs to compare against)
- Does NOT handle security audit (use `sdd-security-auditor` for that)
- Does NOT apply changes without presenting a summary first (even auto-resolvable ones)

---

## 2. Invocation Modes

```bash
# Full reconciliation (default)
/sdd-reconcile

# Dry run — detect and classify only, do not apply changes
/sdd-reconcile --dry-run

# Scope to specific paths
/sdd-reconcile --scope=src/api,src/models

# Code wins — all divergences resolved toward code (no user prompts)
/sdd-reconcile --code-wins
```

| Mode | Behavior | Use Case |
|------|----------|----------|
| **default** | Classify, auto-resolve safe types, ask user for unsafe types | Normal reconciliation |
| `--dry-run` | Classify and report only, no modifications | Assessment before committing to changes |
| `--scope=paths` | Only compare specified paths against their specs | Partial reconciliation |
| `--code-wins` | All divergences resolved by updating specs to match code | Post-release sync where code is authoritative |

---

## 3. Process — 8 Phases

### Phase 1: Context Loading

**Objetivo:** Load all SDD artifacts and establish comparison baseline.

1. Verify SDD artifacts exist: `requirements/REQUIREMENTS.md`, `spec/` directory
   - If missing → ABORT with message: "No SDD artifacts found. Use `sdd-reverse-engineer` to generate them first."
2. Verify source code exists: `src/` or equivalent
   - If missing → ABORT with message: "No source code found. Nothing to reconcile."
3. Load `pipeline-state.json` — check for stale stages
4. Load `reconciliation/RECONCILIATION-REPORT.md` if previous reconciliation exists (for delta comparison)
5. Parse all requirements: extract REQ IDs, EARS statements, traceability references
6. Parse all specifications: use cases, workflows, API contracts, domain model, NFRs
7. Build a spec artifact index: `{ REQ-ID → requirement text, UC-ID → use case description, ... }`

**Output:** Loaded context with indexed spec artifacts.

### Phase 2: Code Scan

**Objetivo:** Analyze current code to build a feature inventory.

1. Scan all source files in scope:
   - Extract endpoints/routes with their handlers
   - Extract entities/models with their fields
   - Extract business logic: validations, state transitions, calculations
   - Extract external integrations
   - Extract configuration-driven behaviors
2. Scan test files to understand tested behavior
3. Build a code feature index: `{ feature-key → { behavior, location, tests } }`
4. Map code features to spec artifacts via:
   - `Refs:` comments in code → direct REQ/UC mapping
   - Naming conventions → inferred mapping
   - Endpoint paths → API contract mapping
   - Entity names → domain model mapping

**Output:** Code feature index with spec mappings.

### Phase 3: Spec-Code Comparison

**Objetivo:** Compare spec artifacts against code features to find divergences.

For each spec artifact (requirement, use case, workflow, contract):

1. **Find matching code:** Use the mapping from Phase 2
2. **Compare behavior:**
   - API contracts: method, path, params, request/response shape, status codes
   - Business rules: validation conditions, thresholds, error messages
   - State machines: states, transitions, guards
   - Domain model: entity fields, types, relationships, constraints
3. **Detect spec items without code** (spec says it exists, code doesn't have it)
4. **Detect code without spec** (code has it, spec doesn't mention it)
5. **Detect behavioral differences** (both exist but behave differently)

For each code feature not in specs:
1. Verify it's genuinely new (not just a renamed/moved feature)
2. Check if tests validate it (stronger evidence it's intentional)

**Output:** Raw divergence list with evidence.

### Phase 4: Divergence Classification

**Objetivo:** Classify each divergence using deterministic rules.

Load [references/divergence-classification.md](references/divergence-classification.md) and classify each divergence:

| Type | Signal | Resolution |
|------|--------|-----------|
| `NEW_FUNCTIONALITY` | Code exists without spec; has tests or is actively used | **Auto:** Update specs (code wins) |
| `REMOVED_FEATURE` | Spec exists without code; no recent commits touching it | **Auto:** Deprecate in specs (code wins) |
| `BEHAVIORAL_CHANGE` | Both exist but behavior differs | **Ask user:** Is code correct or is it a bug? |
| `REFACTORING` | Structure changed but behavior is equivalent (tests still pass) | **Auto:** Update technical specs only |
| `BUG_OR_DEFECT` | Code behavior contradicts spec AND tests fail or are missing | **Ask user:** Fix code or update spec? |
| `AMBIGUOUS` | Cannot determine type with confidence | **Ask user:** Classify manually |

Classification confidence:
- **HIGH**: Clear match to one type based on signals
- **MEDIUM**: Likely match but some counter-signals
- **LOW**: Multiple types could apply → classify as `AMBIGUOUS`

**Output:** Classified divergence list with resolution actions.

### Phase 5: Reconciliation Plan

**Objetivo:** Build the reconciliation plan before applying any changes.

Load [references/reconciliation-strategies.md](references/reconciliation-strategies.md) and:

1. Group divergences by type and resolution
2. For auto-resolvable types, prepare the spec changes:
   - `NEW_FUNCTIONALITY`: Draft new requirements (EARS syntax) and spec entries
   - `REMOVED_FEATURE`: Mark specs as deprecated with removal date
   - `REFACTORING`: Update technical references, file paths, method names
3. For user-decision types, prepare the question with context:
   - Show the spec expectation
   - Show the code reality
   - Show test status (passing, failing, missing)
   - Present options with recommendations
4. Calculate pipeline cascade impact:
   - Which downstream stages become stale
   - Effort estimate for cascade

**Output:** Reconciliation plan ready for review.

### Phase 6: User Review

**Objetivo:** Present the reconciliation plan and get user decisions.

Present summary:

```
Reconciliation Summary:
━━━━━━━━━━━━━━━━━━━━━━
Auto-resolve (code wins):
  • NEW_FUNCTIONALITY: {n} items → update specs
  • REMOVED_FEATURE: {n} items → deprecate in specs
  • REFACTORING: {n} items → update technical refs

Requires your decision:
  • BEHAVIORAL_CHANGE: {n} items
  • BUG_OR_DEFECT: {n} items
  • AMBIGUOUS: {n} items

Pipeline impact: stages {X, Y, Z} will become stale
```

For each item requiring decision, present:

```
DIVERGENCE #{N}: {title}
  Spec says: {EARS statement or spec excerpt}
  Code does: {observed behavior}
  Tests: {pass/fail/missing}

  Options:
  (A) Code is correct → update spec to match code
  (B) Spec is correct → flag code as defect (create task)
  (C) Both need changes → create change request
  (D) Skip for now → leave divergence documented
```

In `--code-wins` mode: skip this phase, auto-resolve everything toward code.
In `--dry-run` mode: present summary but do NOT ask for decisions, just report.

### Phase 7: Apply Changes

**Objetivo:** Apply the reconciliation decisions to SDD artifacts.

1. For `NEW_FUNCTIONALITY`:
   - Add new requirements to `requirements/REQUIREMENTS.md`
   - Add new use cases to `spec/use-cases.md`
   - Add new API contracts to `spec/contracts.md` (if applicable)
   - Add new entries to relevant spec documents
   - Mark as `[RECONCILED]` with source reference

2. For `REMOVED_FEATURE`:
   - Mark requirement as `[DEPRECATED]` with date and reason
   - Update use case status to "deprecated"
   - Add removal note to spec documents
   - Do NOT delete — preserve for traceability

3. For `REFACTORING`:
   - Update file paths and method references in specs
   - Update API contract if endpoint structure changed
   - Update architecture references in plan documents

4. For user-decided `BEHAVIORAL_CHANGE` (option A: code wins):
   - Update requirement EARS statement
   - Update use case description and acceptance criteria
   - Add ADR if the change is architecturally significant

5. For user-decided `BUG_OR_DEFECT` (option B: spec wins):
   - Create a defect task entry (but do NOT modify code)
   - Flag in reconciliation report for future `sdd-task-implementer` action

6. Apply all changes atomically (all or nothing per divergence)

**Output:** Updated SDD artifacts.

### Phase 8: Pipeline State Update

**Objetivo:** Update pipeline state to reflect reconciliation.

1. Recalculate hashes for modified artifact directories
2. Mark affected stages as needing re-run:
   - If `requirements/` changed → `spec-auditor` and downstream become stale
   - If `spec/` changed → `test-planner` and downstream become stale
   - If `plan/` changed → `task-generator` and downstream become stale
3. Update `pipeline-state.json` with new hashes and stale markers
4. Generate `reconciliation/RECONCILIATION-REPORT.md`

**Output:** Updated `pipeline-state.json`, reconciliation report.

---

## 4. Output Format

### File: `reconciliation/RECONCILIATION-REPORT.md`

Load [references/reconciliation-report-template.md](references/reconciliation-report-template.md) for the full template.

Key sections:
- Executive summary with divergence counts by type
- Detailed divergence listing with classification evidence
- Actions taken (auto-resolved and user-decided)
- Pending items (deferred decisions, defect tasks created)
- Pipeline cascade impact
- Traceability chain changes

---

## 5. Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-onboarding` | Recommends reconcile for SDD drift scenario (scenario 3) |
| `sdd-reverse-engineer` | Use instead when NO SDD artifacts exist; reconcile requires existing specs |
| `sdd-spec-auditor` | Run after reconcile to audit the updated specs |
| `sdd-req-change` | For intentional changes, use req-change; reconcile handles unintentional drift |
| `sdd-traceability-check` | Run after reconcile to verify chain integrity |
| `sdd-task-implementer` | Defect tasks from reconcile feed into task-implementer |
| `sdd-pipeline-status` | Shows stale stages that may indicate drift |

---

## 6. Pipeline Integration

### Reads
- `requirements/REQUIREMENTS.md` (required)
- `spec/` directory (required)
- `src/` and source code directories (read-only)
- `tests/` and test directories (read-only)
- `pipeline-state.json`
- `reconciliation/RECONCILIATION-REPORT.md` (previous, if exists)

### Writes
- `requirements/REQUIREMENTS.md` (updates)
- `spec/` documents (updates)
- `reconciliation/RECONCILIATION-REPORT.md`
- `pipeline-state.json` (stale markers, hash updates)

### Pipeline State Effects
- Does NOT add new pipeline stages
- May mark existing stages as stale due to artifact updates
- Stages affected depend on which artifact directories were modified

---

## 7. Constraints

1. **Source read-only**: NEVER modify files in `src/` or `tests/`. These are the source of truth for current behavior.
2. **Requires SDD artifacts**: Cannot run without existing `requirements/` and `spec/`. Abort if missing.
3. **Summary first**: ALWAYS present the reconciliation summary before applying changes, even for auto-resolvable items.
4. **Atomic per divergence**: Each divergence is resolved independently. A failure in one does not block others.
5. **Deprecate, don't delete**: Removed features are marked deprecated, never deleted from specs (traceability preservation).
6. **Evidence-based**: Every classification must cite the code location, spec reference, and test status.
7. **No cascading execution**: Reconcile updates artifacts and marks stages stale but does NOT invoke downstream skills.
8. **Consistent with req-change**: Spec update format follows the same patterns used by `sdd-req-change` for consistency.
9. **Language-adaptive**: Output language follows the user's language. Technical terms remain in English.
