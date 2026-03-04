---
name: sdd-req-change
description: "Manages the full lifecycle of requirements changes AND pipeline cascade: ADD, MODIFY, and DEPRECATE requirements with bidirectional propagation through all specification documents and optional downstream pipeline re-execution. Use this skill when: (1) Adding new features or requirements, (2) Modifying existing requirements and propagating changes, (3) Deprecating requirements with proper impact analysis, (4) Requesting a new feature that needs to flow through the entire pipeline, (5) Handling corrective/adaptive/preventive maintenance changes, (6) Triggering re-planning and re-tasking after spec changes. Triggers on phrases like 'change requirement', 'add requirement', 'deprecate requirement', 'modify requirement', 'new feature', 'I need', 'fix this', 'update dependency', 'retire feature', 'cambiar requisito', 'nuevo requisito', 'deprecar', 'nueva funcionalidad', 'necesito que', 'requirements change', 'pipeline cascade'."
version: "2.0.0"
---

# Skill: sdd-req-change — Requirements Change Manager & Pipeline Cascade Trigger

> **Version:** 2.0.0
> **Pipeline position:** Lateral — can be invoked anytime after specs exist; triggers downstream cascade
> **Complementary to:** `sdd-spec-auditor` Mode Fix (audit-driven fixes)
> **SWEBOK v4 alignment:** Chapter 01 (Software Requirements) — Change Management, Traceability, Conflict Resolution; Chapter 05 (Software Maintenance) — Maintenance Classification, Impact Analysis, Feature Retirement

---

## 1. Purpose & Scope

Manages the full lifecycle of requirements changes: **ADD**, **MODIFY**, and **DEPRECATE** requirements, propagating changes bidirectionally through all specification documents. Classifies changes using **ISO 14764 maintenance categories** (corrective, adaptive, perfective, preventive) and optionally triggers **downstream pipeline cascade** to re-plan, re-task, and re-implement affected FASEs. Ensures zero gaps between requirements and specifications after every change.

### What This Skill Does

1. Receives a change request (text free or structured `CHANGE-REQUEST.md`)
2. **Classifies** the change by maintenance category (ISO 14764) and urgency
3. Performs **impact analysis** across the full traceability chain (REQ ↔ UC ↔ WF ↔ API ↔ BDD ↔ INV ↔ ADR ↔ RN)
4. **Asks the user** every question needed with options and recommendations to eliminate ambiguities
5. Plans all changes with before/after for every affected document
6. Executes changes **atomically** across all specs and requirements
7. Runs a **focused alignment audit** on affected documents
8. Generates a **Change Report** with full context for planning, tasks, and implementation
9. **Triggers pipeline cascade** (Phase 9) — updates `pipeline-state.json` and optionally invokes downstream skills

### What This Skill Does NOT Do

- Does NOT generate implementation code (delegates to `sdd-task-implementer` via cascade)
- Does NOT create implementation plans from scratch (delegates to `sdd-plan-architect` via cascade)
- Does NOT create tasks from scratch (delegates to `sdd-task-generator` via cascade)
- Does NOT run full cross-document audits (use `sdd-spec-auditor`)
- Does NOT derive requirements from scratch (use `sdd-requirements-engineer`)
- Does NOT assume behavior not backed by user answers
- Does NOT modify files outside `spec/`, `changes/`, `requirements/`, and `pipeline-state.json`
- Does NOT handle runtime operational maintenance (monitoring, incident response, runtime rollback)
- Does NOT estimate effort in person-hours (project management concern, Ch07)

### Core Principle

> "Every requirement change must propagate completely through the specification chain AND trigger downstream pipeline re-execution. No orphan specs. No orphan requirements. No gaps. No stale plans. No ambiguities introduced."

Aligned with SWEBOK v4 Ch01 (Software Requirements), Change Management and Ch05 (Software Maintenance): the skill that initiates changes owns the cascade through the full pipeline.

---

## 2. Invocation Modes

```bash
/sdd-req-change                                    # Interactive mode (text free from user)
/sdd-req-change --file changes/CHANGE-REQUEST.md   # From structured file
/sdd-req-change --dry-run                          # Plan only, no execution (stops after Phase 4)
/sdd-req-change --batch                            # Auto-apply recommended solutions (skip Phase 5 interactive)
/sdd-req-change --cascade=auto                     # Full pipeline cascade after changes (Phase 9)
/sdd-req-change --cascade=manual                   # (default) Advisory cascade output only
/sdd-req-change --cascade=dry-run                  # Preview cascade scope without executing
/sdd-req-change --cascade=plan-only                # Cascade through planning but not implementation
/sdd-req-change --maintenance=TYPE                 # Pre-classify as corrective/adaptive/perfective/preventive
```

### Cascade Modes

| Mode | Behavior | When to Use |
|------|----------|-------------|
| `--cascade=manual` (default) | Update `pipeline-state.json`, print recommended commands | User wants control over each step |
| `--cascade=auto` | Invoke downstream skills in sequence after Phase 8 | Full pipeline automation |
| `--cascade=dry-run` | Compute invalidation scope but change nothing | Impact preview before committing |
| `--cascade=plan-only` | Cascade through planning skills, stop before implementation | Updated plans + tasks without code changes |

### Input Sources

| Source | Description | When to Use |
|--------|-------------|-------------|
| **Text free** | User describes change in natural language | Quick changes, exploratory |
| **CHANGE-REQUEST.md** | Structured file with predefined format | Planned changes, batch processing |
| **Both** | File provides base, user adds context | Complex changes needing discussion |

---

## 3. Phases

### Phase 0: Inventory & Context Loading

**Goal:** Build complete understanding of current spec state.

**Steps:**
1. Glob all `.md` files under `spec/` — build manifest with IDs, types, versions
2. Read `spec/requirements/REQUIREMENTS.md` — extract all REQ IDs, categories, traceability
3. Read `spec/domain/01-GLOSSARY.md` — load ubiquitous language (MANDATORY reference)
4. Read `spec/CLARIFICATIONS.md` — load business rules (RN-*)
5. Read `spec/CHANGELOG.md` — identify current spec version
6. Read `audits/AUDIT-BASELINE.md` — know current audit state
7. Read `pipeline-state.json` — load current pipeline state (create default if absent)
8. Scan `changes/` for existing DRAFT/REVIEWED deltas — warn if unapplied deltas exist
9. If `--file` provided: Read and parse `CHANGE-REQUEST.md`
10. Build internal index:
    - `REQ-ID → [source specs]` (forward traceability)
    - `spec-file → [REQ-IDs]` (backward traceability)
    - `REQ-ID → [dependent REQ-IDs]` (dependency graph)
    - `stage → status` (pipeline staleness map from pipeline-state.json)

**Readiness Gates:**

| Gate | Check | Action if Fails |
|------|-------|-----------------|
| G1: Specs exist | `spec/domain/`, `spec/use-cases/`, `spec/contracts/` present | STOP: "Run sdd-specifications-engineer first" |
| G2: REQUIREMENTS.md exists | `spec/requirements/REQUIREMENTS.md` present | STOP: "Run sdd-requirements-engineer first" |
| G3: Glossary exists | `spec/domain/01-GLOSSARY.md` present | STOP: "Cannot proceed without ubiquitous language" |
| G4: Audit-clean (warning only) | `AUDIT-BASELINE.md` has 0 open findings | WARN: "Specs have open audit findings. Changes may conflict." |
| G5: Pipeline state (info only) | `pipeline-state.json` exists and is readable | INFO: "No pipeline state found. Will create after changes." |

**Output:** Internal manifest (not written to disk). Console summary:

```
Inventory Complete
==================
Spec files:        {N}
Requirements:      {N} (FUN:{N} NFR:{N} OPS:{N} REG:{N} DER:{N})
Current version:   v{X.Y.Z}
Audit state:       {clean | N open findings}
Pipeline state:    {fresh | plan exists (FASE 1-N) | tasks exist (FASE 1-N) | implementation started}
Cascade impact:    {N stages would be invalidated}
Change source:     {text free | CHANGE-REQUEST.md | both}
Pending deltas:    {N DRAFT | N REVIEWED | none}
```

---

### Phase 1: Change Request Intake & Classification

**Goal:** Parse, classify, and structure each change request.

**Steps:**
1. Parse user input (natural language) and/or structured file
2. For each change, classify:

| Classification | Signal | Example |
|----------------|--------|---------|
| **ADD** | New capability, feature, constraint not in current REQs | "Necesitamos soporte para bulk export de CVs" |
| **MODIFY** | Change to existing REQ behavior, threshold, scope | "El timeout de extraccion debe ser 480s en vez de 360s" |
| **DEPRECATE** | Remove or sunset existing REQ | "Ya no necesitamos el matching por percentil" |

3. For each change, classify by **ISO 14764 Maintenance Category**:

   | Classification | Sub-classification | Signal |
   |---------------|-------------------|--------|
   | ADD | Perfective | New capability |
   | ADD | Adaptive | New external integration, dependency addition |
   | MODIFY | Corrective | Bug fix, incorrect behavior |
   | MODIFY | Perfective | Feature enhancement |
   | MODIFY | Adaptive | External API change, dependency update, platform migration |
   | MODIFY | Preventive | Tech debt reduction, code health improvement |
   | DEPRECATE | Perfective | Feature simplification |
   | DEPRECATE | Adaptive | External dependency removal |
   | DEPRECATE | Preventive | Removing tech debt source |

   > If `--maintenance=TYPE` was provided, use it directly. Otherwise, auto-detect from change description.
   > See `references/maintenance-classification.md` for the full decision tree.

   **Corrective** changes additionally get urgency-based priority:

   | Urgency | Criteria | Response |
   |---------|----------|----------|
   | P0 (Critical) | Data loss risk, core feature completely broken | Immediate |
   | P1 (High) | Major feature broken, no workaround | Same day |
   | P2 (Medium) | Feature broken, workaround exists | Next sprint |
   | P3 (Low) | Minor defect, cosmetic issue | Backlog |

4. For each change, identify:
   - **Category** (FUN/NFR/OPS/REG/DER)
   - **Subcategory** (EXT/CVA/MAT/GDP/USR/ORG/OFF/CAN/SEL/DSH/SYS/PERF/SEC/etc.)
   - **Affected existing REQs** (if MODIFY or DEPRECATE)
   - **Related existing REQs** (that may need updating due to dependency)
   - **Priority estimate** (Must/Should/Could)
   - **Stability estimate** (Stable/Moderate/Volatile)
   - **Maintenance category** (Corrective/Adaptive/Perfective/Preventive)

5. Apply SWEBOK 5-Whys technique for unclear requests:
   - Ask "Why is this needed?" recursively (2-3 cycles)
   - Converge on the true requirement vs. proposed solution
   - Goal: identify the stakeholder need, not the implementation

6. Generate structured Change Request Summary:

```markdown
## Change Request Summary

| # | Type | Maintenance | Category | Subcategory | Description | Affected REQs | Complexity |
|---|------|-------------|----------|-------------|-------------|----------------|-----------|
| CR-001 | ADD | Perfective | FUN | EXT | Bulk PDF extraction | - | Medium |
| CR-002 | MODIFY | Corrective (P2) | NFR | PERF | Increase timeout to 480s | REQ-PERF-001 | Low |
| CR-003 | DEPRECATE | Preventive | FUN | CAN | Remove percentile feature | REQ-CAN-011 | High |
```

**Present to user for confirmation before proceeding.**

---

### Phase 2: Impact Analysis

**Goal:** Identify ALL documents affected by each change. SWEBOK v4 Ch01 (Software Requirements), Traceability: *"Establish footprint for volume of work to incorporate change."*

**Steps per change request:**

1. **Direct Impact** — Documents that MUST change:

| Change Type | Direct Impact Sources |
|-------------|----------------------|
| ADD REQ | REQUIREMENTS.md, target UC(s), target contract(s), target BDD(s), possibly domain model, possibly new INV(s) |
| MODIFY REQ | REQUIREMENTS.md, all docs in REQ traceability chain |
| DEPRECATE REQ | REQUIREMENTS.md, all docs in REQ traceability chain, dependent REQs |

2. **Indirect Impact** — Documents that SHOULD be reviewed:

| Change Type | Indirect Impact |
|-------------|-----------------|
| ADD REQ | Related UCs (shared entities), CLARIFICATIONS.md, FASE files referencing related specs |
| MODIFY REQ | Downstream REQs depending on modified behavior, related BDD scenarios |
| DEPRECATE REQ | REQs that reference deprecated REQ, BDD tests validating deprecated behavior |

3. **Trace the full chain per affected REQ:**

```
REQ-{id} → UC-{nnn} → WF-{nnn} → API-{module} → BDD-{feature} → INV-{area}-{nnn} → ADR-{nnn} → RN-{nnn}
```

4. **Conflict Detection:**
   - Check if change contradicts existing INVs
   - Check if change conflicts with existing ADR decisions
   - Check if change breaks existing BDD scenarios
   - Check if change violates CLARIFICATIONS business rules

5. **Complexity Rating:**

| Complexity | Criteria |
|------------|----------|
| **Low** | 1-3 documents affected, no conflicts, no new entities |
| **Medium** | 4-8 documents affected, minor conflicts resolvable, possibly new INVs |
| **High** | 9-15 documents affected, ADR decisions needed, new entities or states |
| **Very High** | 16+ documents affected, cross-domain impact, breaking changes |

6. **Generate Impact Matrix:**

```markdown
## Impact Matrix — CR-{NNN}

### Direct Impact (MUST change)
| Document | Section | Change Type | Description |
|----------|---------|-------------|-------------|
| requirements/REQUIREMENTS.md | §4.1 | ADD | New REQ-EXT-{NNN} |
| use-cases/UC-001.md | Flujo Principal | MODIFY | Add bulk step |
| contracts/API-pdf-reader.md | POST /extract | MODIFY | Add batch param |
| tests/BDD-extraction.md | Scenarios | ADD | New bulk scenario |

### Indirect Impact (SHOULD review)
| Document | Reason |
|----------|--------|
| domain/02-ENTITIES.md | May need BulkExtraction entity |
| nfr/LIMITS.md | May need bulk rate limits |

### Conflicts Detected
| Conflict | Severity | Resolution Needed |
|----------|----------|-------------------|
| INV-EXT-003 limits single PDF | Medium | Clarify: bulk bypasses or respects limit? |

### Complexity: {Low | Medium | High | Very High}
### Estimated documents to modify: {N}

### Regression Risk Matrix

| Area | Risk Level | Existing Tests | Mitigation |
|------|-----------|----------------|------------|
| {feature area} | {Low/Medium/High} | {BDD-xxx: N scenarios} | {existing coverage sufficient / needs new scenarios} |

### Downstream Pipeline Impact

| Artifact | Current Status | Action Needed |
|----------|---------------|---------------|
| plan/fases/FASE-{N}.md | {Fresh/Stale} | {Regenerate / No change} |
| task/TASK-FASE-{N}.md | {Fresh/Stale} | {Regenerate after plan update / No change} |
| src/ (FASE-{N} code) | {Fresh/Stale} | {New tasks needed / No change} |

### Code & Commit Impact

| Artifact | Commits | Last Commit | Files Affected |
|----------|---------|-------------|----------------|
| UC-002 | abc1234, def5678 | 2026-02-27 | src/auth/middleware.ts, src/auth/jwt.ts |
| INV-SYS-001 | ghi9012 | 2026-02-26 | src/middleware/tenant.ts |

Blast radius: {N} commits, {M} source files, {K} test files
```

7. **Commit Impact Analysis** (if git available):

   Check git availability first:
   ```bash
   git rev-parse --is-inside-work-tree 2>/dev/null
   ```

   If git is available, for each artifact in the Direct Impact list:
   ```bash
   git log --all --oneline --grep='Refs:.*{ARTIFACT-ID}'
   ```

   Build a commit impact map:
   - **Artifact → commits**: Which commits reference this artifact via `Refs:` trailers
   - **Commits → files**: Which source files were touched by those commits (`git diff-tree --no-commit-id --name-only -r {SHA}`)
   - **Last commit date**: When was the most recent commit for this artifact

   Estimate blast radius:
   - Total unique commits referencing affected artifacts
   - Total unique source files touched by those commits
   - Total unique test files touched by those commits

   **Graceful degradation**: If git is not available, skip this step and note "Git not available — commit impact analysis skipped" in the Impact Matrix.

8. **Code Intelligence Impact Analysis** (if SDD MCP server available):

   IF the SDD MCP server is available (tool `sdd_impact` exists):
   ```
   result = sdd_impact({ artifact_id: "{ARTIFACT-ID}", direction: "downstream", maxDepth: 3 })
   ```

   Classify by depth:
   - **d=1 (WILL_BREAK)**: Direct implementors — these symbols/files implement the artifact
   - **d=2 (LIKELY_AFFECTED)**: Callers of implementors — functions that call the affected code
   - **d=3 (MAY_NEED_REVIEW)**: Transitive callers — indirect dependents needing testing

   IF `codeIntelligence` data available in the graph (from `/sdd-code-index`):
   - Enrich the Impact Matrix with symbol-level detail:

   ```markdown
   | Symbol | File | Depth | Callers | Risk |
   |--------|------|-------|---------|------|
   | validateUser() | src/auth/validator.ts | d=1 | 3 direct | HIGH |
   | handleLogin() | src/routes/auth.ts | d=2 | 2 direct | MEDIUM |
   | authMiddleware() | src/middleware/auth.ts | d=3 | 5 direct | LOW |
   ```

   ELSE:
   - Fallback to git-based analysis from Step 7 (commit blast radius only)

   **Graceful degradation**: If MCP server not available, rely entirely on Step 7's git-based analysis.

---

### Phase 3: Clarification & Decision

**Goal:** Eliminate ALL ambiguities before planning changes. Every gap gets a question with options and a recommendation.

**Methodology:** SWEBOK v4 §3.1 (7 desirable properties) + §3.4 (Conflict Resolution)

**Steps:**

1. For each change request, evaluate against 7 SWEBOK properties:

| Property | Check | Question if Fails |
|----------|-------|-------------------|
| **Unambiguous** | Interpretable in only one way? | "This could mean X or Y. Which interpretation?" |
| **Testable** | Can be verified with concrete criteria? | "How would we verify this? Propose acceptance criteria." |
| **Binding** | Stakeholder confirms it's essential? | "Is this Must Have, Should Have, or Could Have?" |
| **Atomic** | Represents single decision? | "This seems to include multiple changes. Split into CR-{A} and CR-{B}?" |
| **True** | Represents actual stakeholder need? | "Is the real need X (capability) or Y (implementation)?" |
| **Stakeholder vocabulary** | Uses ubiquitous language? | "The term '{X}' isn't in our glossary. Did you mean '{Y}'?" |
| **Acceptable** | No conflicts with existing decisions? | "This conflicts with ADR-{N}. Override decision or adapt requirement?" |

2. For each ambiguity/gap, present options with recommendation:

```markdown
### Question {N} of {M}: CR-{NNN} — {Short Title}

**Context:** {Why this question matters}
**Conflict/Gap:** {What's unclear or conflicting}

**Options:**
| Option | Description | Pros | Cons | Recommendation |
|--------|-------------|------|------|----------------|
| A | {description} | {pros} | {cons} | **Recommended** |
| B | {description} | {pros} | {cons} | |
| C | {description} | {pros} | {cons} | |

**Why Option A is recommended:** {rationale}
**Impact of each option on specs:** {brief}
```

3. For DEPRECATE changes, additional questions:
   - "What happens to data/behavior currently governed by this requirement?"
   - "Should deprecated REQ be marked as `Won't Have` or physically removed?"
   - "Are there migration steps needed for existing data?"

4. For ADD changes, formulate EARS statement:
   - Present EARS pattern options (Ubiquitous/Event/State/Optional/Unwanted/Complex)
   - Draft EARS statement and ask user to validate
   - Draft acceptance criteria (Gherkin) and ask user to validate

5. For MODIFY changes:
   - Show current EARS statement
   - Show proposed new EARS statement
   - Ask user to validate the delta

6. Collect all answers. Generate Clarification Log:

```markdown
## Clarification Log — Change Request Session

> Date: YYYY-MM-DD
> Change Requests: {N}
> Questions Asked: {N}
> Questions Answered: {N}

### Q-001: {Title}
**Change Request:** CR-{NNN}
**Question:** {text}
**Answer:** {user's choice + rationale}
**Decision:** {what this means for the plan}
**Needs New ADR:** {Yes/No}
**Needs New INV:** {Yes/No}
**Needs New RN:** {Yes/No}
```

---

### Phase 4: Change Plan Generation

**Goal:** Generate a complete, reviewable plan showing every change to every document with before/after.

**Steps:**

1. For each ADD change:
   - Generate new REQ with full template (ID, Category, EARS, Acceptance Criteria, Traceability)
   - Assign next available REQ-{SUB}-{NNN} ID (scan existing IDs to avoid collision)
   - Draft new UC sections / new UC if needed
   - Draft new API contract sections if needed
   - Draft new BDD scenarios if needed
   - Draft new INVs if needed (assign next available INV-{AREA}-{NNN})
   - Draft new ADRs if needed (assign next available ADR-{NNN})
   - Draft new RNs if needed (assign next available RN-{NNN})

2. For each MODIFY change:
   - Show current state (before) of every affected section
   - Show proposed state (after) of every affected section
   - Track cascading changes through traceability chain

3. For each DEPRECATE change:
   - Mark REQ as `Deprecated` with reason and date
   - Identify all spec sections to update/remove
   - Identify migration steps if applicable
   - Show deprecation plan for each affected document
   - For **multi-REQ deprecations** (entire feature removal), generate a **Feature Sunset Plan**:

   ```markdown
   ### Feature Sunset Plan — {Feature Name}

   > Applies to: {list of REQ-IDs being deprecated}
   > Replacement: {replacement feature or "None — clean removal"}

   | Phase | Timeline | Action | Artifacts |
   |-------|----------|--------|-----------|
   | Announce | Sprint N | Mark as deprecated in API docs, add deprecation warnings | API contracts, CHANGELOG |
   | Disable New | Sprint N+1 | Prevent new usage of deprecated feature | API validation rules |
   | Migrate | Sprint N+2..N+4 | Migrate existing users/data to replacement | Migration scripts, communication |
   | Remove | Sprint N+5 | Remove code, specs, and all references | Full spec chain cleanup |

   **Sunset Checklist:**
   - [ ] Replacement feature exists and is stable
   - [ ] Migration path documented
   - [ ] All consumers notified
   - [ ] Data migration tested
   - [ ] Rollback plan exists
   ```

   > See `references/maintenance-classification.md` §7 for the full sunset template.

4. Apply **Atomic Cross-Check Rule** (from `sdd-spec-auditor` Mode Fix):

| If you modify... | Also check and update... |
|-------------------|--------------------------|
| `domain/02-ENTITIES.md` | `03-VALUE-OBJECTS.md`, `04-STATES.md`, `05-INVARIANTS.md`, UCs, contracts |
| `domain/03-VALUE-OBJECTS.md` | `02-ENTITIES.md`, UCs, contracts using those VOs |
| `domain/04-STATES.md` | `05-INVARIANTS.md`, UCs with state transitions, WFs |
| `domain/05-INVARIANTS.md` | UCs enforcing INVs, contracts validating them |
| `contracts/PERMISSIONS-MATRIX.md` | ALL `contracts/API-*.md` |
| `CLARIFICATIONS.md` | UCs referenced by modified RNs |
| `requirements/REQUIREMENTS.md` | Traceability matrix section (§9), Coverage section (§10) |

5. Group changes by document for atomic execution:
   - Each document gets ONE edit pass (no revisiting)
   - Changes ordered: **REQUIREMENTS → domain → invariants → UCs → contracts → tests → NFR → ADRs → CLARIFICATIONS → CHANGELOG**
   - Requirements FIRST: the REQ defines the change; specs propagate it

6. Generate `changes/CHANGE-PLAN-{id}.md`:

```markdown
# Change Plan — {Change Request ID}

> Generated: YYYY-MM-DD
> Source: {text free | CHANGE-REQUEST.md | both}
> Change Requests: {N} (ADD:{N} MODIFY:{N} DEPRECATE:{N})
> Documents affected: {N}
> Estimated complexity: {Low | Medium | High | Very High}
> Spec version: v{current} → v{proposed}

## Summary Table

| # | CR-ID | Type | REQ-ID | Severity | Documents | Breaking |
|---|-------|------|--------|----------|-----------|----------|
| 1 | CR-001 | ADD | REQ-EXT-{new} | - | 5 | No |
| 2 | CR-002 | MODIFY | REQ-PERF-001 | Medium | 3 | No |
| 3 | CR-003 | DEPRECATE | REQ-CAN-011 | High | 8 | Yes |

## Detailed Changes

### CR-001: {Title} [ADD]

#### New Requirement: REQ-{SUB}-{NNN}

| Field | Value |
|-------|-------|
| **ID** | REQ-{SUB}-{NNN} |
| **Category** | {Functional | Non-Functional | Operational | Regulatory | Derived} |
| **Subcategory** | {area} |
| **Priority** | {Must Have | Should Have | Could Have} |
| **Stability** | {Stable | Moderate | Volatile} |
| **Source** | {CR-001, answered questions} |

**EARS Statement:**
> {EARS-formatted requirement}

**Acceptance Criteria:**
```gherkin
Given {precondition}
When {action}
Then {expected result}
```

**Traceability:**
| Direction | Artifact |
|-----------|----------|
| Source | {spec sources to create/modify} |
| Implements | UC-{NNN} |
| Verifies | BDD-{feature} |
| Guarantees | INV-{AREA}-{NNN} |

#### Spec Changes for CR-001

##### 1. {document path}
**Section:** {section name}
**Action:** {ADD section | MODIFY section | REMOVE section}

**Before:**
> {current text, or "(new section)" for ADD}

**After:**
> {proposed text}

**Rationale:** {why this change is needed for CR-001}

##### 2. {next document}
[... repeat for each affected document ...]

#### New Artifacts for CR-001

| Type | ID | Title | Origin |
|------|-----|-------|--------|
| INV | INV-{AREA}-{NNN} | {title} | CR-001, Q-{NNN} |
| ADR | ADR-{NNN} | {title} | CR-001, conflict resolution |

#### Dependencies
{Other CRs that must be applied first, or "None"}

---

### CR-002: {Title} [MODIFY]
[... same structure with before/after for existing REQ ...]

### CR-003: {Title} [DEPRECATE]

#### Deprecated Requirement: REQ-CAN-011

**Current EARS Statement:**
> {current statement}

**Deprecation Reason:** {user's stated reason}
**Migration:** {migration steps if applicable, or "None — clean removal"}

#### Spec Changes for CR-003
[... before/after for each document, showing removals ...]

#### Breaking Changes
| Change | Impact | Migration |
|--------|--------|-----------|
| {description} | {what breaks} | {how to adapt} |

---

## Execution Order

| Step | Document | CRs Applied | Action |
|------|----------|-------------|--------|
| 1 | requirements/REQUIREMENTS.md | CR-001,CR-002,CR-003 | ADD+MODIFY+DEPRECATE REQs |
| 2 | domain/02-ENTITIES.md | CR-001 | Add entity section |
| 3 | domain/05-INVARIANTS.md | CR-001 | Add INV-{AREA}-{NNN} |
| 4 | use-cases/UC-001.md | CR-001, CR-002 | Modify flow |
| ... | ... | ... | ... |

## Version Impact
- Spec version: v{current} → v{proposed}
- REQUIREMENTS.md version: {current} → {proposed}
- Documents with version bumps: {list}
```

**If `--dry-run`: STOP HERE. Present plan and exit.**

---

### Phase 5: User Review & Approval

**Goal:** Get explicit user approval before modifying any file.

**Steps:**

1. Present the Change Plan summary to user
2. Ask workflow mode:

| Mode | Description |
|------|-------------|
| **Batch** (default with `--batch`) | Apply all recommended changes. User already answered all questions in Phase 3. |
| **Interactive** | Present each CR separately. User approves/modifies/rejects per CR. |

3. For **Interactive mode**, per CR:
   - Show full before/after
   - Ask: "Apply this change? (Yes / Modify / Skip)"
   - If Modify: collect new input, re-run Phase 3-4 for that CR only
   - If Skip: mark as skipped in report

4. For **Batch mode**:
   - Show summary table
   - Ask: "Apply all {N} changes? (Yes / Review individually)"

**Approval required before any file modification.**

---

### Phase 6: Change Execution

**Goal:** Apply all approved changes atomically across all documents.

**Execution Order (MANDATORY — requirements-first, then propagate to specs):**

> **IMPORTANT:** Unlike `sdd-spec-auditor` Mode Fix (which goes specs-first because it fixes specs from audit findings),
> this skill is a **Requirements Change Manager**. The requirement is the source of truth for the change.
> Therefore: define the requirement FIRST, then propagate to specifications.

```
1. requirements/REQUIREMENTS.md (ADD/MODIFY/DEPRECATE REQs — the SOURCE of the change)
2. domain/01-GLOSSARY.md       (new terms if needed by the REQ)
3. domain/02-ENTITIES.md       (new/modified entities derived from REQ)
4. domain/03-VALUE-OBJECTS.md  (new/modified VOs derived from REQ)
5. domain/04-STATES.md         (new/modified states derived from REQ)
6. domain/05-INVARIANTS.md     (new INVs derived from REQ)
7. use-cases/UC-*.md           (new/modified UCs implementing REQ)
8. workflows/WF-*.md           (new/modified WFs implementing REQ)
9. contracts/API-*.md           (new/modified contracts implementing REQ)
10. contracts/EVENTS-*.md       (new/modified events)
11. contracts/PERMISSIONS-MATRIX.md (if roles affected)
12. tests/BDD-*.md              (new/modified BDD scenarios verifying REQ)
13. tests/PROPERTIES.md         (if property tests affected)
14. nfr/*.md                    (if NFRs affected)
15. adr/ADR-*.md                (new ADRs for decisions needed by REQ)
16. runbooks/*.md               (if operational procedures affected)
17. CLARIFICATIONS.md           (new RNs derived from REQ)
18. CHANGELOG.md                (record all changes)
```

> **Rationale:** The requirement defines WHAT changes. Specifications define HOW it manifests.
> By writing the requirement first, every subsequent spec edit can reference the authoritative
> REQ-ID, EARS statement, and acceptance criteria as the source of truth for the change.

**Per-document execution rules:**

1. Read current file content
2. Apply ALL changes for that file in single pass
3. Increment document version if file has version header
4. Update any cross-reference tables within the file
5. Verify ubiquitous language compliance (glossary terms only)

**REQUIREMENTS.md specific rules:**

For ADD:
- Insert new REQ in correct subcategory section (maintain alphabetical order within subcategory)
- Update §3 Executive Summary counts
- Update §9 Traceability Matrix
- Update §10 Coverage section
- Update Appendix Statistics

For MODIFY:
- Replace REQ content in-place
- Update traceability if sources changed
- Update §9 if traceability changed

For DEPRECATE:
- Add `**Status:** Deprecated (YYYY-MM-DD) — {reason}` to REQ header
- Move to new §12 "Deprecated Requirements" section (create if doesn't exist)
- Remove from §9 active traceability
- Add to §12 deprecation history
- Update §3 counts (reduce category count, add deprecated count)
- Update Appendix Statistics

**Git Commits:**

One commit per logical change group (1 CR = 1 commit unless very large):

```
feat(specs): add REQ-{SUB}-{NNN} - {brief description}

Change Request: CR-{NNN}
Type: ADD
Documents: {comma-separated list}
Requirements affected: REQ-{SUB}-{NNN}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

```
fix(specs): modify REQ-{SUB}-{NNN} - {brief description}

Change Request: CR-{NNN}
Type: MODIFY
Documents: {comma-separated list}
Requirements affected: REQ-{SUB}-{NNN}
Breaking: {Yes/No}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

```
refactor(specs): deprecate REQ-{SUB}-{NNN} - {brief description}

Change Request: CR-{NNN}
Type: DEPRECATE
Documents: {comma-separated list}
Requirements affected: REQ-{SUB}-{NNN}
Migration: {Yes/No}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

---

### Phase 7: Alignment Audit

**Goal:** Verify that after all changes, requirements and specifications are perfectly aligned. This is a **focused mini-audit** on affected documents only (not a full cross-document audit).

**Audit Checks (8 alignment verifications):**

| # | Check | Description | Severity if Fails |
|---|-------|-------------|-------------------|
| AA-01 | **REQ → Spec Forward Coverage** | Every new/modified REQ has at least one spec source | Critical |
| AA-02 | **Spec → REQ Backward Coverage** | Every modified spec section contributes to at least one REQ | Critical |
| AA-03 | **Traceability Chain Completeness** | Every new/modified REQ has: Source + Implements + Verifies + Guarantees | High |
| AA-04 | **Cross-Reference Validity** | All cross-references in modified documents resolve to existing targets | Critical |
| AA-05 | **Glossary Compliance** | No undefined terms or synonyms introduced in modified sections | High |
| AA-06 | **Contradiction Check** | No modified section contradicts another document section | Critical |
| AA-07 | **EARS Pattern Compliance** | All new/modified REQs use valid EARS pattern | Medium |
| AA-08 | **Acceptance Criteria Testability** | All new/modified Gherkin scenarios are concrete and testable | Medium |

**Additional checks for DEPRECATE:**

| # | Check | Description | Severity if Fails |
|---|-------|-------------|-------------------|
| AA-09 | **No Orphan References** | No remaining document references deprecated REQ | Critical |
| AA-10 | **Dependent REQ Update** | All REQs that depended on deprecated REQ updated or flagged | High |

**Audit Execution:**

1. For each affected document:
   - Re-read the modified file
   - Run checks AA-01 through AA-08 (+ AA-09/AA-10 for deprecations)
   - Record findings

2. Cross-document verification:
   - Verify all new cross-references resolve
   - Verify no broken links created
   - Verify REQUIREMENTS.md traceability matrix consistent with actual spec content

3. Generate audit results:

```markdown
## Alignment Audit Results

> Scope: {N} documents audited (focused on changes only)
> Checks executed: {8 | 10}
> Findings: {N}

| # | Check | Status | Details |
|---|-------|--------|---------|
| AA-01 | REQ → Spec Forward | PASS | All {N} REQs have spec sources |
| AA-02 | Spec → REQ Backward | PASS | All {N} modified sections covered |
| AA-03 | Traceability Complete | PASS | {N}/{N} chains complete |
| AA-04 | Cross-Refs Valid | PASS | {N} references validated |
| AA-05 | Glossary Compliance | PASS | No violations |
| AA-06 | Contradiction Check | PASS | No contradictions |
| AA-07 | EARS Compliance | PASS | {N}/{N} REQs compliant |
| AA-08 | Testability | PASS | {N}/{N} scenarios testable |

### Findings (if any)
| # | Check | Severity | Location | Problem | Auto-Fix Applied |
|---|-------|----------|----------|---------|------------------|
| 1 | AA-04 | Critical | UC-001.md:45 | Reference to non-existent INV-EXT-099 | Yes: corrected to INV-EXT-{correct} |

### Verdict: {ALIGNED | GAPS DETECTED}
```

**If gaps detected:**
- For auto-fixable issues (typos, broken refs): fix immediately and re-audit
- For non-auto-fixable issues: include in Change Report as "Open Items"
- NEVER ignore a failed alignment check

---

### Phase 8: Change Report Generation

**Goal:** Generate a comprehensive document that provides full context for subsequent planning, task creation, and implementation.

**Output:** `changes/CHANGE-REPORT-{YYYY-MM-DD}-{short-id}.md`

**Structure:**

```markdown
# Change Report — {Short Title}

> **Report ID:** CHG-{YYYY-MM-DD}-{NNN}
> **Date:** YYYY-MM-DD
> **Spec version:** v{before} → v{after}
> **REQUIREMENTS.md version:** {before} → {after}
> **Change Requests:** {N} (ADD:{N} MODIFY:{N} DEPRECATE:{N})
> **Documents modified:** {N}
> **Alignment audit:** {ALIGNED | N gaps}
> **Breaking changes:** {Yes (N) | No}

---

## 1. Executive Summary

{2-3 paragraph description of what changed and why. Written for someone who needs to understand the full scope of changes without reading every detail.}

### Change Request Summary

| # | CR-ID | Type | REQ-ID(s) | Category | Priority | Complexity | Status |
|---|-------|------|-----------|----------|----------|------------|--------|
| 1 | CR-001 | ADD | REQ-EXT-{NNN} | FUN | Must | Medium | Applied |
| 2 | CR-002 | MODIFY | REQ-PERF-001 | NFR | Must | Low | Applied |
| 3 | CR-003 | DEPRECATE | REQ-CAN-011 | FUN | - | High | Applied |

---

## 2. Changes Applied

### 2.1 New Requirements Added

#### REQ-{SUB}-{NNN}: {Title}

**EARS Statement:**
> {statement}

**Acceptance Criteria:**
```gherkin
{criteria}
```

**Traceability:**
| Direction | Artifact |
|-----------|----------|
| Source | {sources} |
| Implements | {UCs} |
| Verifies | {BDDs} |
| Guarantees | {INVs} |

**Specs Created/Modified:**
| Document | Change | Lines |
|----------|--------|-------|
| {path} | {description} | {N} |

---

### 2.2 Requirements Modified

#### REQ-{SUB}-{NNN}: {Title}

**Before:**
> {previous EARS statement}

**After:**
> {new EARS statement}

**Reason:** {rationale from clarification}

**Cascade Changes:**
| Document | Section | Before | After |
|----------|---------|--------|-------|
| {path} | {section} | {old} | {new} |

---

### 2.3 Requirements Deprecated

#### REQ-{SUB}-{NNN}: {Title} [DEPRECATED]

**Previous EARS Statement:**
> {statement}

**Deprecation Reason:** {reason}
**Migration Steps:** {steps or "None"}

**Removed from:**
| Document | Section Removed |
|----------|----------------|
| {path} | {section} |

---

## 3. New Artifacts Created

| Type | ID | Title | Source CR |
|------|-----|-------|----------|
| Requirement | REQ-{SUB}-{NNN} | {title} | CR-001 |
| Invariant | INV-{AREA}-{NNN} | {title} | CR-001 |
| ADR | ADR-{NNN} | {title} | CR-002 |
| Business Rule | RN-{NNN} | {title} | CR-001 |
| BDD Scenario | {feature}:{scenario} | {title} | CR-001 |

---

## 4. Impact Analysis Summary

### 4.1 Documents Modified

| # | Document | CRs | Changes | Version |
|---|----------|-----|---------|---------|
| 1 | requirements/REQUIREMENTS.md | CR-001,CR-002,CR-003 | ADD+MODIFY+DEPRECATE | 1.0.0 → 1.1.0 |
| 2 | use-cases/UC-001.md | CR-001 | MODIFY | 4.0.16 → 4.0.17 |
| ... | ... | ... | ... | ... |

### 4.2 Breaking Changes

| Change | Impact | Migration Required |
|--------|--------|--------------------|
| {description} | {what breaks} | {Yes: steps / No} |

### 4.3 Cross-Reference Updates

| From | To | Type | Status |
|------|-----|------|--------|
| REQ-EXT-{NNN} | UC-001 | New link | Created |
| REQ-CAN-011 | UC-025 | Removed link | Cleaned |

---

## 5. Alignment Audit Results

{Full audit results from Phase 7}

---

## 6. Clarification Decisions

{Full clarification log from Phase 3 — preserves all decisions and rationale}

---

## 7. Context for Planning & Implementation

### 7.1 Affected FASE Files

| FASE | Impact | Description |
|------|--------|-------------|
| FASE-1 | Direct | New extraction capability requires implementation |
| FASE-5 | Indirect | Matching weights may need adjustment |

> **Action:** Run `sdd-plan-architect` to regenerate FASE files after this change.

### 7.2 Architecture Impact

{Description of architectural implications: new endpoints, new entities, new events, modified data flows}

### 7.3 Implementation Considerations

| Consideration | Detail |
|---------------|--------|
| New API endpoints | {list with methods} |
| New DB tables/columns | {list} |
| New event types | {list} |
| Modified business logic | {list} |
| New test coverage needed | {list of BDD scenarios} |
| Infrastructure changes | {if any} |

### 7.4 Recommended Next Steps

1. Run `sdd-plan-architect` to regenerate FASE files
2. Run `sdd-plan-architect --fase {N}` to update implementation plan for affected phases
3. Create implementation tasks for each change
4. {Additional recommendations based on change scope}

### 7.5 Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| {risk} | {L/M/H} | {L/M/H} | {mitigation} |

### 7.6 Maintenance Classification (ISO 14764)

| CR-ID | ISO Category | Urgency | Notes |
|-------|-------------|---------|-------|
| CR-001 | Perfective | Normal | New feature request |
| CR-002 | Corrective | P2 | Bug fix with workaround |

### 7.7 Pipeline Cascade Plan

| Step | Skill | Scope | Estimated Impact |
|------|-------|-------|-----------------|
| 1 | sdd-spec-auditor (focused) | {N} modified documents | Low — focused audit |
| 2 | sdd-test-planner (audit) | Updated test coverage | Low — gap detection |
| 3 | sdd-plan-architect | FASE-{list} | Medium — plan structure changes |
| 4 | sdd-task-generator | FASE-{list} | Medium — new tasks for changed REQs |
| 5 | sdd-task-implementer | FASE-{N} new tasks | High — new code needed |

> **Cascade mode:** {auto | manual | dry-run | plan-only}
> **Invalidated stages:** {N}

### 7.8 Technical Debt Impact (if applicable)

| TD-ID | Source CR | Type | Description | Priority | Target FASE |
|-------|----------|------|-------------|----------|-------------|
| TD-001 | CR-{NNN} | {Design/Code/Test/Doc} | {description of debt introduced or resolved} | {Must/Should/Could} | FASE-{N} |

> Track open debt items in the project's technical debt register.
> Preventive maintenance changes should reference and resolve existing TD-* items.

---

## 8. Git Commits

| # | Hash | Message | Files |
|---|------|---------|-------|
| 1 | {hash} | feat(specs): add REQ-EXT-{NNN} | {N} files |
| 2 | {hash} | fix(specs): modify REQ-PERF-001 | {N} files |

---

## 9. Statistics

| Metric | Value |
|--------|-------|
| Total change requests | {N} |
| Changes applied | {N} |
| Changes skipped | {N} |
| Documents modified | {N} |
| New requirements | {N} |
| Modified requirements | {N} |
| Deprecated requirements | {N} |
| New invariants | {N} |
| New ADRs | {N} |
| New business rules | {N} |
| New BDD scenarios | {N} |
| Alignment checks passed | {N}/{N} |
| Open items | {N} |
| Commits created | {N} |
```

---

### Phase 9: Pipeline Cascade Execution

**Goal:** Propagate changes through the downstream pipeline, updating plans, tasks, and optionally implementation to reflect the new/modified/deprecated requirements.

**Precondition:** Phase 8 complete. Change Report generated. `pipeline-state.json` updated with stale markers.

> See `references/cascade-patterns.md` for the full invalidation rules and cascade execution patterns.

**Steps:**

1. **Read cascade mode** from invocation flags (default: `manual`)

2. **Compute invalidation scope:**
   - Parse Change Report Section 7.1 (Affected FASE Files)
   - Parse Change Report Section 7.7 (Pipeline Cascade Plan)
   - Determine which downstream stages need re-execution using invalidation rules:

   | What Changed | Skills to Re-run |
   |-------------|-----------------|
   | ADD requirements + new spec sections | spec-auditor (focused), test-planner, plan-architect, task-generator, task-implementer |
   | MODIFY requirements + changed spec sections | spec-auditor (focused), test-planner, plan-architect (affected FASEs), task-generator (affected FASEs), task-implementer |
   | DEPRECATE requirements + removed spec sections | plan-architect (affected FASEs), task-generator (affected FASEs) |
   | Security-related changes (NFR-SEC-*) | sdd-security-auditor first, then same as above |
   | NFR-only changes | test-planner, plan-architect (architecture may change) |

3. **Update `pipeline-state.json`:**
   - Mark affected stages as `"stale"`
   - Record Change Report ID as `staleReason`
   - Update hashes for `requirements/` and `spec/` directories

4. **Execute based on cascade mode:**

   **If `--cascade=manual` (default):**
   ```
   Pipeline Cascade Summary (MANUAL)
   ==================================
   Invalidated stages: {N}
   Affected FASEs:     {list}

   Recommended commands:
   > sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{id}.md
   > sdd-test-planner --mode=audit
   > sdd-plan-architect --regenerate-fases --affected={list}
   > sdd-task-generator --fase={list} --incremental
   > sdd-task-implementer --fase={N} --new-tasks-only
   ```

   **If `--cascade=dry-run`:**
   - Print full cascade plan with estimated scope
   - Do NOT update `pipeline-state.json`
   - Exit

   **If `--cascade=plan-only`:**
   - Invoke `sdd-spec-auditor --focused` (if audit-relevant changes)
   - Invoke `sdd-test-planner --mode=audit` (if test-relevant changes)
   - Invoke `sdd-plan-architect --regenerate-fases --affected={list}`
   - Invoke `sdd-task-generator --fase={list} --incremental`
   - Update `pipeline-state.json` after each step
   - Exit (do NOT invoke `sdd-task-implementer`)

   **If `--cascade=auto`:**
   - Execute full pipeline:
     a. `sdd-spec-auditor --focused` (if needed)
     b. `sdd-test-planner --mode=audit` (if test coverage affected)
     c. `sdd-plan-architect --regenerate-fases --affected={list}`
     d. `sdd-task-generator --fase={list} --incremental`
     e. `sdd-task-implementer --fase={N} --new-tasks-only` (per affected FASE)
   - After each step: update `pipeline-state.json`
   - If any step fails: **STOP**, report error, leave pipeline-state in partial state
   - Generate `changes/CASCADE-REPORT-{id}.md`

5. **Generate cascade summary** (always, regardless of mode):

   ```
   Pipeline Cascade Summary
   =========================
   Mode:               {auto | manual | dry-run | plan-only}
   Change Report:      changes/CHANGE-REPORT-{id}.md
   Invalidated stages: {N}
   Skills to re-run:   {list}
   Affected FASEs:     {list}

   [If auto/plan-only:]
   Skills executed:    {N}/{N}
   Status:             {COMPLETE | PARTIAL (failed at step {N})}
   Cascade Report:     changes/CASCADE-REPORT-{id}.md

   [If manual:]
   Next action: Run the recommended commands above in order.
   ```

**Cascade Report Artifact** (generated for `auto` and `plan-only` modes):

Output: `changes/CASCADE-REPORT-{id}.md`

```markdown
# Cascade Report — {Change Report ID}

> **Triggered by:** changes/CHANGE-REPORT-{id}.md
> **Mode:** {auto | plan-only}
> **Started:** {timestamp}
> **Completed:** {timestamp | "INCOMPLETE"}
> **Status:** {COMPLETE | PARTIAL (failed at step N)}

## Execution Log

| Step | Skill | Scope | Status | Duration | Notes |
|------|-------|-------|--------|----------|-------|
| 1 | sdd-spec-auditor | focused on {N} docs | PASS | {N}s | {details} |
| 2 | sdd-plan-architect | FASE-{list} | PASS | {N}s | {N} FASEs regenerated |
| 3 | sdd-task-generator | FASE-{list} | PASS | {N}s | {N} new tasks |

## Pipeline State After Cascade

{dump of updated pipeline-state.json}

## Recovery Instructions (if PARTIAL)

{what to fix and how to resume from the failed step}
```

---

## 4. Multi-Agent Protocol

For complex changes (3+ CRs or 15+ affected documents), use parallel agents:

<!-- Standard SDD agent prefix convention: prefixes map to spec/ subdirectories.
     DOM- → domain/, UC- → use-cases/, WF- → workflows/, CON- → contracts/,
     NFR- → nfr/, ADR- → adr/, TEST- → tests/, RUN- → runbooks/.
     All SDD skills sharing multi-agent protocols MUST use these same prefixes. -->

| Agent | Scope | Documents | Prefixes |
|-------|-------|-----------|----------|
| **DOM-agent** | Domain model, Glossary, Entities, VOs, States, Invariants | `spec/domain/*` | `DOM-` |
| **UC-WF-agent** | Use Cases, Workflows | `spec/use-cases/*`, `spec/workflows/*` | `UC-`, `WF-` |
| **CON-agent** | API contracts, Events, Permissions | `spec/contracts/*` | `CON-` |
| **TEST-NFR-agent** | BDD tests, Properties, NFRs, ADRs, Runbooks | `spec/tests/*`, `spec/nfr/*`, `spec/adr/*`, `spec/runbooks/*` | `TEST-`, `NFR-`, `ADR-`, `RUN-` |

**REQUIREMENTS-agent** (always runs in main thread, never parallelized):
- Owns `requirements/REQUIREMENTS.md`
- Applies REQ changes **FIRST, before** dispatching spec changes to other agents
- After all agents complete: updates traceability matrix (§9) and coverage (§10) with new links

> **Rationale:** The requirement defines the change. Spec agents need the authoritative REQ-ID,
> EARS statement, and acceptance criteria to exist before they can reference them in specs.

**Consolidation Rules:**
1. Main thread: update REQUIREMENTS.md FIRST → dispatch spec changes to agents → collect results → update traceability in REQUIREMENTS.md
2. Each agent modifies only its scoped files
3. Cross-agent references (e.g., UC referencing new INV): main thread creates cross-references after agents complete
4. Conflict between agents on same document: STOP, resolve manually

---

## 5. CHANGE-REQUEST.md Format (Structured Input)

When using `--file`, the change request file must follow this format:

```markdown
# Change Request

> **Date:** YYYY-MM-DD
> **Author:** {name}
> **Priority:** {Must | Should | Could}
> **Category:** {FUN | NFR | OPS | REG | DER}

## Changes

### CR-001: {Title}

**Type:** ADD | MODIFY | DEPRECATE
**Category:** {FUN | NFR | OPS | REG | DER}
**Subcategory:** {EXT | CVA | MAT | GDP | etc.}
**Priority:** {Must | Should | Could}
**Affected REQs:** {REQ-{SUB}-{NNN} for MODIFY/DEPRECATE, or "None" for ADD}
**Related REQs:** {REQ-{SUB}-{NNN}, ... or "None"}

**Description:**
{Natural language description of the change. Be as specific as possible.}

**Motivation:**
{Why this change is needed. Business context.}

**Acceptance Criteria (draft):**
```gherkin
Given {precondition}
When {action}
Then {expected result}
```

**Constraints:**
{Any constraints or limitations on the change.}

---

### CR-002: {Title}
[... repeat for each change ...]
```

See `references/change-request-template.md` for full template.

---

## 6. Delta-Based Change Management

> **Inspired by:** OpenSpec's `changes/` directory pattern — modifications are represented as delta proposals (ADDED/MODIFIED/REMOVED) before merging into the main spec. This provides a reviewable, auditable staging area.

### 6.1 Directory Structure

```
changes/
├── CR-001-bulk-pdf-extraction.md        # Active delta proposal
├── CR-002-increase-timeout.md           # Active delta proposal
├── CHANGE-PLAN-{id}.md                  # Generated by Phase 4
├── CHANGE-REPORT-{id}.md                # Generated by Phase 8
└── applied/                             # Archive of merged deltas
    ├── 2025-03-15-CR-001-bulk-pdf-extraction.md
    └── 2025-03-15-CR-002-increase-timeout.md
```

### 6.2 Delta File Format: `changes/CR-NNN-{slug}.md`

Each change request produces one delta file that captures the full proposal before any spec is modified.

```markdown
# Delta Proposal — CR-{NNN}: {Title}

> **Type:** ADD | MODIFY | DEPRECATE
> **Status:** DRAFT | REVIEWED | APPROVED | APPLIED | REJECTED
> **Created:** YYYY-MM-DD
> **Author:** {user or session}
> **Complexity:** {Low | Medium | High | Very High}
> **Breaking:** {Yes | No}

---

## Affected Files

| # | File | Action | Section |
|---|------|--------|---------|
| 1 | requirements/REQUIREMENTS.md | ADD | §4.1 Functional |
| 2 | use-cases/UC-001.md | MODIFY | Flujo Principal, paso 3 |
| 3 | contracts/API-pdf-reader.md | MODIFY | POST /extract |
| 4 | tests/BDD-extraction.md | ADD | New scenario |

---

## Deltas

### Delta 1: requirements/REQUIREMENTS.md

**Action:** ADD
**Section:** §4.1 Functional — Extraction

**Before:**
> (new section — no previous content)

**After:**
```markdown
### REQ-EXT-{NNN}: Bulk PDF Extraction

**EARS Statement:**
> WHEN the user submits multiple PDF files THE system SHALL extract text from all files in parallel AND return aggregated results within the configured timeout.

**Acceptance Criteria:**
...
```

**Rationale:** {Why this delta is needed, linked to CR-{NNN}}

---

### Delta 2: use-cases/UC-001.md

**Action:** MODIFY
**Section:** Flujo Principal, paso 3

**Before:**
> 3. El sistema recibe un archivo PDF y extrae el texto.

**After:**
> 3. El sistema recibe uno o más archivos PDF y extrae el texto de cada uno. Si se reciben múltiples archivos, el procesamiento es paralelo.

**Rationale:** {Support for bulk extraction changes the main flow}

---

[... repeat for each affected file ...]

---

## Impact Analysis Summary

| Dimension | Value |
|-----------|-------|
| Direct impact documents | {N} |
| Indirect impact documents | {N} |
| Conflicts detected | {N} |
| New artifacts needed | INV:{N} ADR:{N} RN:{N} BDD:{N} |
| Dependent CRs | {list or "None"} |

---

## Clarification Decisions

| Q# | Question | Answer | Decision |
|----|----------|--------|----------|
| Q-001 | {question} | {answer} | {what it means for this delta} |
```

### 6.3 Delta Workflow

The delta workflow wraps around the existing execution phases:

```
Phase 1-3 (Intake, Impact, Clarification)
    ↓
Phase 4 → CREATE delta file: changes/CR-NNN-{slug}.md [Status: DRAFT]
    ↓
Phase 5 → USER REVIEWS delta file [Status: DRAFT → REVIEWED → APPROVED]
    ↓
Phase 6 → APPLY deltas atomically to spec files [Status: APPROVED → APPLIED]
    ↓
Phase 7 → Alignment audit on applied changes
    ↓
Phase 8 → ARCHIVE delta to changes/applied/{date}-CR-NNN-{slug}.md
          + Generate Change Report
```

**Workflow rules:**

| Rule | Description |
|------|-------------|
| **One delta per CR** | Each CR-NNN gets exactly one delta file, even if it affects many documents |
| **Draft before apply** | No spec file is modified until the delta has Status: APPROVED |
| **Atomic application** | All deltas in a delta file are applied in a single pass or none at all |
| **Archive after apply** | Applied deltas move to `changes/applied/` with date prefix for auditability |
| **Rejected deltas** | If user rejects, set Status: REJECTED and leave in `changes/` (do not archive) |

### 6.4 Integration with Execution Phases

| Phase | Delta Interaction |
|-------|-------------------|
| **Phase 0** (Inventory) | Scan `changes/` for existing DRAFT/REVIEWED deltas; warn if unapplied deltas exist |
| **Phase 1** (Intake) | Classify changes and assign CR-NNN IDs that will become delta filenames |
| **Phase 2** (Impact) | Populate the "Affected Files" and "Impact Analysis Summary" sections of the delta |
| **Phase 3** (Clarification) | Populate the "Clarification Decisions" section of the delta |
| **Phase 4** (Plan) | **Write** the delta file to `changes/CR-NNN-{slug}.md` with Status: DRAFT. Also generate `CHANGE-PLAN-{id}.md` referencing the deltas |
| **Phase 5** (Review) | User reviews the delta file(s). Status transitions: DRAFT -> REVIEWED -> APPROVED. If `--dry-run`, stop here with deltas in DRAFT |
| **Phase 6** (Execution) | Read each APPROVED delta, apply changes to spec files in the defined execution order. Set Status: APPLIED |
| **Phase 7** (Audit) | Run alignment audit. If audit fails, delta remains APPLIED but Change Report notes open items |
| **Phase 8** (Report) | Move applied deltas to `changes/applied/{YYYY-MM-DD}-CR-NNN-{slug}.md`. Generate Change Report referencing archived deltas |

### 6.5 Delta Application Order

When multiple deltas exist in a batch, apply in this order:

1. **DEPRECATE** deltas first (remove before adding to avoid ID conflicts)
2. **MODIFY** deltas second (update existing content)
3. **ADD** deltas last (insert new content into stable base)

Within each delta, apply file changes in the standard execution order defined in Phase 6 (requirements first, then domain, then specs, then tests, then CHANGELOG).

### 6.6 Resumable Sessions

Delta files enable resumable change sessions:

- If a session is interrupted after Phase 4, the DRAFT deltas persist in `changes/`
- On next invocation, Phase 0 detects existing deltas and offers: **Resume** (continue from Phase 5) or **Discard** (delete drafts and start fresh)
- This eliminates the need to re-run impact analysis and clarification for interrupted sessions

---

## 7. ID Allocation Rules

### Requirement IDs (REQ-{SUB}-{NNN})

1. Scan existing REQUIREMENTS.md for highest NNN in target subcategory
2. Assign next sequential number: `max(existing) + 1`
3. If subcategory is new: start at 001
4. NEVER reuse deprecated REQ IDs

### Invariant IDs (INV-{AREA}-{NNN})

1. Scan `spec/domain/05-INVARIANTS.md` for highest NNN in target area
2. Assign next sequential: `max(existing) + 1`

### ADR IDs (ADR-{NNN})

1. Scan `spec/adr/` directory for highest NNN
2. Check `adr/ADR-GAP-*.md` for reserved ranges
3. Assign next available sequential

### Business Rule IDs (RN-{NNN})

1. Scan `CLARIFICATIONS.md` for highest NNN
2. Assign next sequential: `max(existing) + 1`

### Change Report IDs (CHG-{YYYY-MM-DD}-{NNN})

1. Scan `changes/` directory for existing reports with same date
2. Assign next sequential NNN for that date (001, 002, ...)

---

## 8. Version Bump Rules

### Spec Document Versions

| Change Type | Version Bump | Example |
|-------------|-------------|---------|
| ADD (new section) | Patch (+0.0.1) | v4.0.16 → v4.0.17 |
| MODIFY (behavior change) | Minor (+0.1.0) | v4.0.16 → v4.1.0 |
| DEPRECATE (breaking removal) | Minor (+0.1.0) | v4.0.16 → v4.1.0 |
| Multiple changes | Highest applicable | v4.0.16 → v4.1.0 |

### REQUIREMENTS.md Version

| Change Type | Version Bump |
|-------------|-------------|
| ADD REQs only | Minor (+0.1.0) |
| MODIFY REQs | Minor (+0.1.0) |
| DEPRECATE REQs | Minor (+0.1.0) |
| Mixed changes | Minor (+0.1.0) |

### CHANGELOG.md Entry Format

```markdown
## v{X.Y.Z} — YYYY-MM-DD

### Added
- REQ-{SUB}-{NNN}: {title} (CR-{NNN})
- INV-{AREA}-{NNN}: {title} (CR-{NNN})
- ADR-{NNN}: {title} (CR-{NNN})

### Changed
- REQ-{SUB}-{NNN}: {description of change} (CR-{NNN})
- UC-{NNN}: {description of change} (CR-{NNN})

### Deprecated
- REQ-{SUB}-{NNN}: {title} — {reason} (CR-{NNN})

### Change Report
See `changes/CHANGE-REPORT-{id}.md` for full details.
```

---

## 9. Error Handling & Edge Cases

### Conflicting Changes

If two CRs in the same batch conflict with each other:
1. STOP execution
2. Present conflict to user: "CR-{A} says X but CR-{B} says Y"
3. Ask user to resolve: keep A, keep B, or merge
4. Re-run Phase 4 for affected CRs

### Stale Specs

If specs have been modified since last audit and AUDIT-BASELINE shows open findings:
1. WARN user: "Specs have {N} open audit findings"
2. Ask: "Proceed anyway? Changes may interact with existing issues."
3. If yes: proceed with extra caution, note in Change Report
4. If no: recommend running `sdd-spec-auditor` (Mode Fix) first

### Missing Traceability

If a change affects a document that has incomplete traceability:
1. Document the gap in Change Report §5 (Alignment Audit)
2. Add as open item: "Pre-existing traceability gap in {document}"
3. Do NOT attempt to fix pre-existing issues (out of scope)

### Circular Dependencies

If impact analysis reveals circular dependency between REQs:
1. Flag as warning
2. Present to user with visualization
3. Ask if this is intentional (mutual reinforcement) or a design flaw
4. Document decision in Change Report

---

## 10. Integration with Pipeline

### Upstream Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-specifications-engineer` | Creates initial specs that this skill modifies |
| `sdd-requirements-engineer` | Creates initial REQUIREMENTS.md that this skill updates |
| `sdd-spec-auditor` | Detects issues that may trigger changes |
| `sdd-spec-auditor` (Mode Fix) | Fixes audit findings (complementary: Mode Fix = audit-driven, this = user-driven) |

### Implementation Feedback as Change Source

`sdd-task-implementer` generates structured feedback files when it encounters spec-level issues during implementation. These files serve as a formal change source for this skill:

```bash
/sdd-req-change --file feedback/IMPL-FEEDBACK-FASE-{N}.md
```

**Processing rules for implementation feedback:**

1. Read `feedback/IMPL-FEEDBACK-FASE-{N}.md` and parse each `IF-{FASE}-{SEQ}` entry
2. **BLOCKER** entries become CR candidates requiring full Phase 1-8 processing
3. **WARNING** entries with workarounds become CR candidates at lower priority -- present to user for triage
4. Map each entry's `Affected Specs` to the traceability chain (same as Phase 2 impact analysis)
5. Use the entry's `Suggested Resolution` as initial input for Phase 3 clarification (user still validates)
6. After all CRs from feedback are applied, update the feedback file: set `Status: RESOLVED` per entry
7. Include feedback origin (`IF-{FASE}-{SEQ}`) in the Change Report (Phase 8) for full traceability

**Category mapping (feedback to change type):**

| Feedback Category    | Typical CR Type | Notes |
|----------------------|-----------------|-------|
| AMBIGUITY            | MODIFY          | Clarify existing REQ/spec |
| CONFLICT             | MODIFY          | Resolve contradiction between specs |
| MISSING-BEHAVIOR     | ADD or MODIFY   | Gap in spec coverage |
| INCORRECT-CONTRACT   | MODIFY          | Contract does not match intended behavior |
| STALE-DECISION       | MODIFY          | `[DECISION PENDIENTE]` needs resolution |

> **Bidirectional feedback loop:** Specs drive implementation (`sdd-task-implementer` reads `spec/`),
> and implementation discoveries drive spec corrections (`sdd-req-change` processes `feedback/`).
> Neither skill crosses its boundary -- the feedback file is the formal handoff artifact.

### Downstream Skills (Cascade Targets)

| Skill | When Triggered | Cascade Flag |
|-------|---------------|-------------|
| `sdd-spec-auditor` | Spec documents changed | `--focused --scope=CHANGE-REPORT.md` |
| `sdd-test-planner` | Test coverage affected | `--mode=audit` |
| `sdd-plan-architect` | Always after spec changes | `--regenerate-fases --affected={list}` |
| `sdd-task-generator` | Plans regenerated | `--fase={list} --incremental` |
| `sdd-task-implementer` | Tasks regenerated (auto mode only) | `--fase={N} --new-tasks-only` |
| `sdd-security-auditor` | Security-related REQs changed | (standard invocation) |

### Pipeline Cascade (Phase 9)

The advisory "Recommended Post-Change Pipeline" is now a formal Phase 9 with 4 cascade modes. See Phase 9 above and `references/cascade-patterns.md` for full details.

```
sdd-req-change (Phases 0-8: change specs)
    ↓
Phase 9: Pipeline Cascade
    ├── --cascade=manual (default): print commands
    ├── --cascade=dry-run: preview only
    ├── --cascade=plan-only: plan + tasks, no implementation
    └── --cascade=auto: full pipeline re-execution
         ↓
    sdd-spec-auditor (focused) → sdd-test-planner (audit) → sdd-plan-architect → sdd-task-generator → sdd-task-implementer
```

### Pipeline State Management

This skill reads and writes `pipeline-state.json`:
- **Phase 0:** Reads pipeline state to report current status and estimate cascade impact
- **Phase 8:** Updates pipeline state with stale markers based on changed artifacts
- **Phase 9:** Updates pipeline state after each cascade step execution

> See `references/cascade-patterns.md` for `pipeline-state.json` schema and invalidation rules.

---

## 11. Processing Rules (MANDATORY)

1. **NEVER modify specs without user approval** — Phase 5 approval is mandatory
2. **NEVER invent behavior** — Every change traces to user input or answered question
3. **NEVER skip impact analysis** — Every change goes through Phase 2
4. **NEVER skip alignment audit** — Phase 7 runs after every execution
5. **ALWAYS ask when ambiguous** — Better to ask 10 questions than introduce 1 gap
6. **ALWAYS provide options with recommendations** — Never force a single choice
7. **ALWAYS use ubiquitous language** — All new text uses glossary terms exclusively
8. **ALWAYS update traceability** — REQ ↔ spec links must be complete
9. **ALWAYS update CHANGELOG** — Every change is recorded
10. **ALWAYS generate Change Report** — Phase 8 is mandatory (not optional)
11. **ALWAYS verify cross-references after changes** — Part of Phase 7
12. **ALWAYS present before/after** — User must see what will change
13. **ALWAYS use EARS pattern for requirements** — Consistent with sdd-requirements-engineer
14. **ALWAYS assign sequential IDs** — No gaps, no reuse of deprecated IDs
15. **APPLY Atomic Cross-Check Rule** — When modifying shared artifacts, update all dependents

---

## 12. Console Output Summary

At the end of execution, print:

```
Change Execution Complete
=========================
Change Requests:     {N} (ADD:{N} MODIFY:{N} DEPRECATE:{N})
Maintenance:         {Corrective:{N} Adaptive:{N} Perfective:{N} Preventive:{N}}
Applied:             {N}
Skipped:             {N}
Documents modified:  {N}
New artifacts:       {N} (REQs:{N} INVs:{N} ADRs:{N} RNs:{N} BDDs:{N})
Tech debt items:     {N new | N resolved}
Alignment audit:     {PASS | FAIL ({N} issues)}
Breaking changes:    {N}
Commits created:     {N}
Change Report:       changes/CHANGE-REPORT-{id}.md
Spec version:        v{before} → v{after}

Pipeline Cascade (--cascade={mode})
====================================
Invalidated stages:  {N}
Affected FASEs:      {list}
Cascade mode:        {auto | manual | dry-run | plan-only}

[If manual:]
Recommended commands:
→ sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{id}.md
→ sdd-test-planner --mode=audit
→ sdd-plan-architect --regenerate-fases --affected={list}
→ sdd-task-generator --fase={list} --incremental
→ sdd-task-implementer --fase={N} --new-tasks-only

[If auto/plan-only:]
Skills executed:     {N}/{N}
Status:              {COMPLETE | PARTIAL}
Cascade Report:      changes/CASCADE-REPORT-{id}.md
```

---

## Persist Summary

After generating the change report and optionally executing cascade, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["req-change"].status` = `"done"` (lateral stage — add key if absent)
3. Set `stages["req-change"].lastRun` = current ISO-8601
4. Set `stages["req-change"].summary`:
   - `artifacts`: list of files created/modified with labels (e.g., `{"file": "changes/CHANGE-REPORT-CHG-2026-03-04-001.md", "label": "Change Report"}`)
   - `metrics`: `{ "change_requests": N, "applied": N, "skipped": N, "documents_modified": N, "invalidated_stages": N }`
   - `highlights`: top 3-5 notable observations (e.g., "3 requirements modified", "Cascade invalidated 4 stages")
   - `nextStep`: `"Run cascade commands"` (if manual mode) or `"Cascade complete"` (if auto mode)
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
