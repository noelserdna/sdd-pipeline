---
name: sdd-specifications-engineer
description: "Transforms requirements into formal specs (SRS) per SWEBOK v4: analyzes gaps and ambiguities first, builds the spec/ folder structure, proposes fixes to deficient requirements. Triggers: 'create specifications', 'write specs', 'requirements to specifications', 'SRS document', 'translate requirements', 'spec from requirements', 'especificaciones'."
---

# Specifications Engineer (SWEBOK v4)

Professional specifications engineering skill that transforms software requirements into formal, structured specification documents following IEEE SWEBOK v4.

## Critical Workflow

**ALWAYS follow this sequence:**

1. **Read and understand** the existing requirements
2. **Analyze** them for quality, gaps, and ambiguities
3. **Ask the user** for decisions on every gap, ambiguity, or issue found
4. **If requirements are deficient**, generate a modification proposal before proceeding
5. **Create** the specification documents and folder structure
6. **Validate** the resulting specifications

---

## Modes of Operation

Determine which mode based on user intent:

### Mode 1: Analyze Requirements for Specification Readiness

Use when the user provides requirements and wants to move toward specifications.

1. Read [references/gap-analysis-checklist.md](references/gap-analysis-checklist.md) for the full analysis framework
2. Locate and read ALL requirement documents in the project
3. For each requirement, evaluate specification readiness:
   - Is it unambiguous enough to specify? If not, flag with options
   - Is it testable enough to derive acceptance criteria? If not, flag
   - Is it atomic enough to map to a single spec? If not, propose decomposition
   - Is the scope clear enough to define boundaries? If not, ask
4. Identify **gaps** in the requirements:
   - Missing stakeholder perspectives
   - Missing error/exception handling
   - Missing security requirements
   - Missing nonfunctional constraints (performance, scalability, availability)
   - Missing boundary conditions
   - Missing data lifecycle (CRUD + archiving)
   - Missing integration/interface requirements
5. Identify **ambiguities**:
   - Terms used inconsistently
   - Vague qualifiers ("fast", "easy", "user-friendly")
   - Unstated assumptions
   - Multiple valid interpretations
6. Identify **conflicts**:
   - Requirements that contradict each other
   - Requirements that are infeasible together
7. For EVERY issue found:
   - Present the issue clearly to the user
   - Provide 2-4 resolution options with a recommended option marked
   - Use `AskUserQuestion` to let the user decide
   - Record the decision for traceability
8. Produce a **Specification Readiness Report** — one short table (console, or `requirements/READINESS-REPORT.md` only if the user asks for a file; ≤ 2,500 chars):

```
# Specification Readiness Report — YYYY-MM-DD
Requirements: N · ready: N · need clarification: N · need modification: N · missing: N

| # | Severity | REQ | Issue (≤ 15 words) | Options (recommended first) | Decision |
|---|---|---|---|---|---|
| 1 | Critical | REQ-F-003 | "done" on an already completed task? | A no-op, exit 0 · B error, exit 3 | A → RN-010 |

Gaps: [category → what is missing → recommendation], one line each.
```

Decisions are recorded **once**, as RN rows in `spec/CLARIFICATIONS.md` (Template 16); the report cites the RN id and does not repeat options or rationale.

### Mode 2: Create Specifications

Use when requirements are ready (after Mode 1 analysis or user indicates readiness).

1. Read [references/specification-workflow.md](references/specification-workflow.md) for the full specification process
2. Read [references/document-templates.md](references/document-templates.md) for available templates
3. Read [references/template-checklist-alignment.md](references/template-checklist-alignment.md) for the template↔auditor alignment matrix
4. **Check previous audit feedback:** If `pipeline-state.json` exists and has a previous `spec-auditor` summary with `topFindingCategories` or `templateImprovements`, read them and apply extra scrutiny to those areas during spec writing. This feedback loop prevents repeating the same defect patterns across projects.
5. **Ask the user** which specification format(s) to use:
   - **SRS (IEEE 830-style)**: Formal specification document
   - **Use Case specifications**: For complex workflows
   - **User Stories + BDD Scenarios**: For agile teams
   - **Actor-Action specifications**: For contractual/regulatory contexts
   - **Model-based**: For architecturally complex systems
   - Recommend the most appropriate based on project context
6. **Ask the user** about the project structure preferences:
   - Monolithic document vs. modular documents per feature/module
   - Naming conventions
   - Output directory
7. Create the folder structure with one command: `mkdir -p spec/{domain,use-cases,workflows,contracts,adr,tests,nfr}` (`runbooks/` only when a requirement asks for an operational procedure — see § Output Economy).
8. Write the specifications following § **Generation Order** (shared homes first, then one pass per requirement, no re-reading) and § **Output Economy** (cite ids, never copy requirement text). For each requirement:
   - Map it to its UC / WF / contract operation ids from the id plan
   - Apply the **Error Flow Forcing Function** (step 6a) and **Invariant Extraction** (step 6b) *while drafting*, before the file is written
   - Write the UC and its `tests/BDD-UC-NNN.md` back to back (the BDD file defines the AC-NNN-NN ids the UC cites)
   - Traceability = the UC's `Refs` row + one row in `TRACEABILITY-MATRIX.md`

   #### Step 6a: Error Flow Forcing Function

   For EVERY step in a UC's main flow, answer these 5 questions while planning the UC; each "yes" becomes one row of the `Exceptions & errors` table (Template 2):

   | Question | If yes, create... |
   |---|---|
   | 1. What if this step fails (network, timeout, service down)? | Exception course with error code + HTTP status |
   | 2. What if the input is invalid or missing? | Exception course with VALIDATION_ERROR + 400 |
   | 3. What if authorization is denied? | Exception course with 403 + specific permission |
   | 4. What if there is a concurrent conflict? | Exception course with 409 + conflict resolution |
   | 5. What if a precondition was met when checked but became false during execution? | Exception course with race condition handling |

   A "no" or "not applicable" answer produces **no text**: no N/A cells, no comments, no forcing-function matrix in the document. The goal is a non-empty exceptions table, not a record of the questions.

   Each exception row also yields, in the same pass (never as a later patch to a written file):
   - Its error code in the error catalog (`domain/03-VALUE-OBJECTS.md`, the only place with message/class/HTTP) and one row in the contract's single Errors table
   - One scenario in `tests/BDD-UC-NNN.md`, whose AC id the exception row cites
   - Exceptions shared by every UC (global error handler, storage failure) are described once — in the workflow or the contract — and cited by id from the UC

   **Tier Classification:** For each exception course generated, classify its traceability tier:

   | Tier | Condition | Action |
   |---|---|---|
   | **Tier 2** | The exception is a technical detail of a UC that already traces to a REQ (e.g., adding 404 to an existing endpoint) | Register in `spec/DERIVED-SPECS.md` as `[Derived from REQ-X]` — no REQ needed |
   | **Tier 1** | The exception implies new user-visible behavior NOT covered by any REQ (e.g., a new retry workflow, a new notification to the user) | **STOP** — present to user, ask if a new REQ should be created via `sdd-req-change` |
   | **Tier 3** | Structural/cosmetic (e.g., reordering error codes in a table) | No registration needed |

   > Most error flows are **Tier 2** — they are technical details derived from existing requirements. Only flag as Tier 1 if the error handling introduces user-visible behavior that no REQ anticipated.

   #### Step 6b: Invariant Extraction

   While drafting each UC (before its file is written), scan the requirement and the planned flow for constraint language and formalize as invariants:

   1. Search for: "must", "shall not", "always", "never", "at most", "at least", "between X and Y", "unique", "only if", "requires", "cannot exceed", "minimum", "maximum"
   2. For each constraint found:
      - Check if a formal invariant already exists in `domain/05-INVARIANTS.md` (written in Generation Order phase B; append a row if the invariant is new)
      - If not: create an INV-{AREA}-{NNN} row with declarative rule and validation (Template 10 — one row, no prose)
      - Cite the INV-ID inline in the UC step or postcondition (e.g., "(INV-SRV-003)") — the rule text itself is never repeated in the UC
   3. Present extracted invariants to the user for confirmation before finalizing

   **Tier Classification:** For each invariant extracted, classify:

   | Tier | Condition | Action |
   |---|---|---|
   | **Tier 2** | The invariant formalizes a constraint already stated or implied by an existing REQ | Register in `spec/DERIVED-SPECS.md` as `[Derived from REQ-X]` |
   | **Tier 1** | The invariant introduces a NEW business rule not present in any REQ | **STOP** — present to user, ask if a new REQ is needed |
   | **Tier 3** | The invariant already existed in `05-INVARIANTS.md` (just back-annotated) | No registration needed |

   #### Step 6c: Register Derived Specifications

   Keep a running list of derived items while writing; after the last UC, write `spec/DERIVED-SPECS.md` **once** (Template 15):

   1. For every Tier 2 artifact created (exception courses, invariants, BDD scenarios, API error codes), add a row — grouped by pattern (one row per error family across UCs, one row per invariant range), never one row per UC per code
   2. For every Tier 1 artifact, add a row marked as **`[PENDING REQ]`**
   3. If >3 Tier 1 items exist without REQs, **alert the user**: "There are {N} specification artifacts that introduce new user-visible behavior without corresponding requirements. Consider running `/sdd-req-change` to create REQs before proceeding."

   > **Research Questions:** When specifying technical decisions that require evaluation
   > of alternatives (e.g., REST vs GraphQL, encryption algorithm selection, database
   > engine choice), document the open question instead of assuming an answer.
   > Create `spec/RESEARCH-QUESTIONS.md` listing each question with its context,
   > the specification(s) it blocks, and candidate options identified so far.
   > These questions are consumed by `sdd-plan-architect` Phase 3 (Research)
   > for deeper investigation. This enables early identification of research
   > needs during specification, avoiding costly rework downstream.

9. Create `spec/TRACEABILITY-MATRIX.md` (Template 5) from the id plan: forward table only (REQ → UC/WF, API, INV, ADR, BDD/PROP, NFR, RN), a ≤ 6-word summary instead of the requirement description, one coverage line. No reverse table (every artifact carries `Refs`), no per-acceptance-criterion table (BDD scenario titles carry the `[REQ-X ACn]` tag). Written from memory, without re-reading the generated files.

10. At each decision point during specification writing, ask the user:
   - When multiple design approaches exist
   - When specification granularity is unclear
   - When acceptance criteria could vary
   - When interface boundaries are ambiguous

### Mode 3: Propose Requirements Modifications

Use when Mode 1 analysis reveals significant deficiencies in the requirements.

**IMPORTANT**: This mode activates AUTOMATICALLY when:
- More than 30% of requirements have critical issues
- Missing requirements exceed 20% of existing count
- Fundamental conflicts exist between requirements
- Core functionality is underspecified

1. Create a **Requirements Modification Proposal** using Template 8 in `references/document-templates.md`: one table of MOD/ADD/REM rows (REQ, issue, proposed text, one-clause rationale) and one impact line — no executive summary, no approval table.
2. Present the proposal to the user with clear explanation
3. Ask the user whether to:
   - Proceed with specifications despite issues (document risks)
   - Go back to requirements phase (recommend using requirements-engineer skill)
   - Address only critical issues and proceed

### Mode 4: Validate Specifications

Use when the user has existing specification documents to review.

1. Read all specification documents
2. Check against [references/gap-analysis-checklist.md](references/gap-analysis-checklist.md) Phase 3
3. Verify each specification:
   - Has clear acceptance criteria
   - Is traceable to a requirement
   - Uses consistent terminology
   - Is implementation-ready (a developer could build from it)
   - Has no ambiguity
4. Verify the specification collection:
   - Complete coverage of all requirements
   - No orphan specifications (specs without requirements)
   - No orphan requirements (requirements without specs)
   - Consistent format and structure
5. Produce a **Specification Validation Report**

### Mode 5: Brownfield Specification

Use when the user has an **existing codebase** and wants to add specifications incrementally, rather than specifying everything from scratch.

**When to activate:**
- User mentions an existing project, legacy code, or working software
- There is source code but no `spec/` directory (or a partial one)
- User wants to formalize only specific modules or components

**Process:**

1. **Analyze existing codebase** — Scan project structure, entry points, and dependencies to build a component map. Identify bounded contexts, modules, and integration boundaries.
2. **Identify and prioritize modules** — Present the user a table of discovered modules with a recommended specification order based on: (a) business criticality, (b) change frequency, (c) dependency count, (d) risk level. Let the user reorder or exclude modules.
3. **Generate specs incrementally** — For each prioritized module:
   - Create only the relevant `spec/` subdirectories (not all are required)
   - Derive specs from code behavior (contracts, state machines, invariants)
   - Mark inferred specs with `[INFERRED]` — user must confirm or correct
   - Ask the user for acceptance criteria that the code does not make explicit
4. **Create `spec/COVERAGE.md`** — A living tracker of specification progress:

```markdown
# Specification Coverage

| Module | Domain | Use Cases | Contracts | NFR | Tests | Status |
|--------|--------|-----------|-----------|-----|-------|--------|
| auth   | done   | done      | done      | —   | done  | SPECIFIED |
| billing| —      | partial   | —         | —   | —     | IN PROGRESS |
| reports| —      | —         | —         | —   | —     | PENDING |

Last updated: YYYY-MM-DD
```

5. **Integrate with other modes** — Mode 1 (Analyze) and Mode 4 (Validate) can run on partial `spec/` directories. Downstream skills (`sdd-spec-auditor`, `sdd-plan-architect`, `sdd-task-generator`) should scope their work to modules with status `SPECIFIED` in `COVERAGE.md`.

**Partial spec tolerance:** Not all `spec/` subdirectories need to exist. A brownfield project may have `spec/contracts/` and `spec/domain/` but no `spec/workflows/` yet. This is valid — downstream skills must check `COVERAGE.md` to know which modules are ready.

---

## Specification Folder Structure

**CRITICAL:** This is the canonical folder structure that ALL downstream skills expect. The folder is `spec/` (singular, no 's').

```
spec/
├── README.md                              # Navigation table only (Template 18)
├── requirements/                          # Do NOT copy REQUIREMENTS.md here: cite ../requirements/REQUIREMENTS.md
├── domain/
│   ├── 01-GLOSSARY.md                     # Ubiquitous language (terms, definitions)
│   ├── 02-ENTITIES.md                     # Domain entities with attributes and relationships
│   ├── 03-VALUE-OBJECTS.md                # Value objects, enums, typed values
│   ├── 04-STATES.md                       # State machines for all stateful entities
│   └── 05-INVARIANTS.md                   # Business rules as formal invariants (INV-XXX-NNN)
├── use-cases/
│   └── UC-NNN-{slug}.md                   # One file per use case (UC-001, UC-002...)
├── workflows/
│   └── WF-NNN-{slug}.md                   # Multi-step processes spanning use cases
├── contracts/
│   ├── API-{module}.md                    # REST/GraphQL API contracts per module
│   ├── EVENTS-{module}.md                 # Domain events and async contracts
│   └── PERMISSIONS-MATRIX.md              # Role-based access control matrix
├── adr/
│   └── ADR-NNN-{slug}.md                  # One per decision actually taken (Nygard short, Template 6)
├── tests/
│   ├── BDD-UC-NNN.md                      # BDD scenarios per use case — the only home of AC-NNN-NN
│   └── PROPERTY-TESTS.md                  # Property-based test specifications
├── nfr/
│   ├── PERFORMANCE.md                     # Performance targets (p99, throughput)
│   ├── LIMITS.md                          # Rate limits, quotas, thresholds
│   ├── SECURITY.md                        # Security requirements and controls
│   └── OBSERVABILITY.md                   # Logging, metrics, alerting specs
├── runbooks/                              # ONLY when a REQ/NFR/ADR requires an operational procedure
│   └── RB-NNN-{slug}.md
├── CLARIFICATIONS.md                      # Business rules (RN-NNN) from user decisions — the decisions log
├── CLARIFICATIONS-PENDING.md              # Open [NEEDS CLARIFICATION] markers (always present)
├── VALUE-REGISTRY.md                      # Canonical shared values (timeouts, limits, enums)
├── DERIVED-SPECS.md                       # Tier 1/2 artifacts not directly traced to REQs
├── TRACEABILITY-MATRIX.md                 # REQ → artifacts, forward table only
└── RESEARCH-QUESTIONS.md                  # Open technical questions for sdd-plan-architect (only if any)
```

### Folder Structure Rules

1. **Always `spec/`** — never `specs/`, `specifications/`, or any variant
2. **Numbered domain files** — `01-GLOSSARY.md` through `05-INVARIANTS.md` are mandatory
3. **ID-prefixed files** — Use cases (`UC-NNN`), workflows (`WF-NNN`), ADRs (`ADR-NNN`) use sequential numbering
4. **Module-scoped contracts** — One API contract per bounded context/module
5. **CLARIFICATIONS.md at root** — Collects all business rules (RN-NNN) from user decisions during specification

### Input Requirements

This skill reads `requirements/REQUIREMENTS.md` (output of `sdd-requirements-engineer`) as its primary input. If this file does not exist:
- **Brownfield path:** Ask the user if they have an existing codebase to specify. If yes, activate **Mode 5** to derive specs from code. No formal requirements file is needed — specs are inferred from the codebase and confirmed with the user.
- **Greenfield path:** Recommend running `sdd-requirements-engineer` first to produce formal requirements before specifying.

When `REQUIREMENTS.md` exists but only covers part of the system (e.g., new features on an existing codebase), combine Mode 2 (for new requirements) with Mode 5 (for existing code without requirements).

### Creating the Structure

`mkdir -p spec/{domain,use-cases,workflows,contracts,adr,tests,nfr}` — add `runbooks/` only when required (§ Output Economy rule 5).

## Key Principles (Always Apply)

### Ask Before Assuming
NEVER make assumptions silently. Every decision point must be presented to the user with options. Use `AskUserQuestion` for every ambiguity, gap, or choice.

### Glossary-First Writing
The glossary (`domain/01-GLOSSARY.md`) is a controlled vocabulary. Once created, it governs ALL spec writing:
- **Before using any domain term** in any spec document, verify it exists in the glossary
- **If a new term is needed**, add it to the glossary FIRST, then use it in spec documents
- **Never use synonyms** listed in the glossary's "Do not use" ("NO usar") column
- **After completing all spec documents**, run a final glossary compliance pass with `grep -rniw` over `spec/`: for each "Do not use" synonym, verify zero occurrences (no re-reading of files)

### Value Registry
Before writing specifications, create `spec/VALUE-REGISTRY.md` (Template 14: one table) listing every shared value (timeouts, limits, rate limits, enum values, thresholds) with its canonical value and the ids that use it. During spec writing, every numeric value or enum used in more than one document MUST be registered and cited **by name** (`TITLE_MAX_LENGTH`) in the other documents. This prevents the #1 source of cross-document contradictions.

### Traceability is Non-Negotiable
Every specification MUST trace back to one or more requirements. Every requirement MUST have at least one specification. Orphans in either direction must be flagged.

### Iterative, Not Waterfall
If issues are found, stop and address them. Do not produce specifications over broken requirements. Better to go back than to build on a weak foundation.

### Implementation-Ready, Not Verbose
Each specification must be detailed enough that a developer unfamiliar with the project could implement it correctly without additional clarification. Detail means precise ids, values, schemas and error rows — not prose, restated requirements or explanations of what does not apply.

### Leverage Existing Skills
When requirements need modification, explicitly recommend `sdd-requirements-engineer` and explain how it can help.

## Output Economy (Non-Redundancy)

Stage time is almost entirely output tokens (~5k tokens ≈ 1 min): every duplicated fact is paid for twice and later contradicts itself. Rules (per-template shapes in `references/document-templates.md` § 0):

1. **One home per fact, ids everywhere else.** Requirement text stays in `requirements/REQUIREMENTS.md`; UCs, contracts, ADRs, BDD files and matrices cite `REQ-F-001` (+ at most one clause), never the statement or its acceptance criteria. Same for terms (`01-GLOSSARY.md`), values (`VALUE-REGISTRY.md`), error code → message → class → HTTP/exit (error catalog in `03-VALUE-OBJECTS.md`), rules (INV in `05-INVARIANTS.md`, RN in `CLARIFICATIONS.md`), scenarios (`tests/BDD-UC-NNN.md`, where AC-NNN-NN ids are defined) and decisions (ADR / CLARIFICATIONS — there is no separate decisions log).
2. **Empty = `None.`** A mandatory section with nothing to say is the single line `None.`; an optional section is omitted. No "not applicable because…" paragraphs, no N/A matrices, no absence justifications (the ADR id is the justification).
3. **Tables, not prose.** Never a table plus prose repeating it; a schema block instead of an attribute table; one `Refs` row per document instead of a trailing traceability section plus "business rules" and "invariants" lists; a UC has one `Exceptions & errors` table, not exception subsections plus an errors table plus a forcing-function matrix.
4. **Boilerplate once per file.** Auth / rate limit / version once per contract, one Errors table per contract with an "Operations" column, no per-actor responsibility table in UCs; exceptions shared by every UC (global handler, storage failure) are described once and cited.
5. **Runbooks, events and permissions only when the requirements ask for them.** Otherwise `runbooks/` does not exist and `EVENTS-*.md` / `PERMISSIONS-MATRIX.md` are a one-line absence declaration (Template 20).
6. **Write each file once.** Plan ids, invariants and exception rows first (§ Generation Order); never re-open a written file to add a cross-reference, and never re-read written files except through `grep` in the Self-Validation Gate.

## Output Budget

Indicative ceilings in characters (`wc -c`). Exceeding one by more than 20 % means the document repeats something that already has an id: cut, do not reflow.

| Artifact | Max chars |
|---|---|
| `use-cases/UC-NNN` | 3,500 |
| `tests/BDD-UC-NNN` | 2,500 |
| `workflows/WF-NNN` | 4,000 |
| `contracts/API-{module}` | 6,000 |
| `adr/ADR-NNN` | 1,500 |
| `domain/` 01 GLOSSARY · 02 ENTITIES · 03 VALUE-OBJECTS · 04 STATES · 05 INVARIANTS | 4,000 · 4,000 · 5,000 · 3,500 · 6,000 |
| `nfr/*.md` (each) | 2,500 |
| `CLARIFICATIONS.md` | 6,000 (≤ 25 RN; +200 per extra RN) |
| `VALUE-REGISTRY.md` · `DERIVED-SPECS.md` · `TRACEABILITY-MATRIX.md` | 3,000 · 4,000 · 3,000 |
| `README.md` · `RESEARCH-QUESTIONS.md` · `tests/PROPERTY-TESTS.md` | 2,500 · 2,000 · 4,000 |
| `EVENTS-*.md` · `PERMISSIONS-MATRIX.md` when not applicable | 300 each |
| `runbooks/RB-NNN` (only when required) | 3,000 |

**Total: ≤ 120,000 chars for ≤ 15 requirements.** Above 15, add 5,000 chars per additional functional requirement (one UC, its BDD file and its share of contract rows). Measure at the end with `find spec -name '*.md' -print0 | xargs -0 wc -c | tail -1` and report it as `metrics.spec_chars` (Persist Summary).

## Generation Order

Shared context first, one pass per requirement, no re-reading of written files.

| Phase | Write (once) | Source |
|---|---|---|
| A. Plan (in memory, nothing written) | Id plan: REQ → UC ids, WF ids, contract modules and `API-NNN-NN` operation ids, INV areas, ADR ids, RN counter | `requirements/REQUIREMENTS.md` read once + user decisions (Mode 1) |
| B. Shared homes | `domain/01..05` (glossary, entities, value objects + error catalog, states, invariants for all requirements — Step 6b), `VALUE-REGISTRY.md` | Plan A |
| C. Per module, per requirement | For each UC: Step 6a in memory → write `UC-NNN` then `BDD-UC-NNN`. After the module's last UC: its `API-{module}` in one write. Keep running lists: RN decisions, derived items, research questions, ADR candidates | Plan A + B already in context — do not re-open written files |
| D. Cross-cutting | `WF-NNN`, `adr/` (only decisions actually taken), `nfr/*`, `CLARIFICATIONS.md`, `DERIVED-SPECS.md`, `RESEARCH-QUESTIONS.md`, `TRACEABILITY-MATRIX.md`, `README.md`, `CLARIFICATIONS-PENDING.md`, and `EVENTS-*` / `PERMISSIONS-MATRIX` (one line when N/A) | Running lists from C |
| E. Gate | Self-Validation Gate with `grep` / `wc`; fix only what fails; short console table | `spec/` via grep, never `cat` |

## Needs Clarification Markers

When writing specifications, if a requirement is ambiguous and the user is unavailable or the session ends before resolution, embed a clarification marker directly in the spec text.

### Marker Format

```
<!-- [NEEDS CLARIFICATION] NC-NNN: {concise question about the ambiguity} -->
```

- **NC-NNN** uses a global sequential counter across all spec documents (NC-001, NC-002, ...).
- Place the marker **immediately after** the ambiguous spec text it refers to.
- Markers are HTML comments so they do not affect rendered output but survive across sessions.
- A marker is never a substitute for asking the user — always prefer `AskUserQuestion` first.

### When to Insert

- The requirement was ambiguous and the user did not provide a decision during the current session.
- A design choice has multiple valid interpretations and no ADR or `CLARIFICATIONS.md` entry covers it.
- An external dependency or integration detail is unknown at specification time.

### Tracking File: `spec/CLARIFICATIONS-PENDING.md`

Maintain a living index of all open markers:

```markdown
# Pending Clarifications

| ID     | Document                        | Question                          | Inserted | Resolved |
|--------|---------------------------------|-----------------------------------|----------|----------|
| NC-001 | use-cases/UC-005-upload-cv.md   | Max file size: 10MB or 25MB?      | YYYY-MM-DD | —      |
| NC-002 | contracts/API-extraction.md     | Retry policy: exponential or fixed? | YYYY-MM-DD | —    |
```

When a marker is resolved in a future session, remove the HTML comment from the spec, move the row's `Resolved` column to the resolution date, and record the decision in `spec/CLARIFICATIONS.md` as a business rule (RN-NNN).

**Always create this file**, even if empty (no pending clarifications). This prevents downstream skills from having to check for file existence:

```markdown
# Pending Clarifications

| ID | Document | Question | Inserted | Resolved |
|----|----------|----------|----------|----------|

(No pending clarifications)
```

---

## Pipeline Integration

This skill is **Step 2** of the SDD pipeline:

```
sdd-requirements-engineer → requirements/REQUIREMENTS.md
        ↓
sdd-specifications-engineer → spec/ (THIS SKILL)
        ↓
sdd-spec-auditor → audits/AUDIT-BASELINE.md (Mode Audit + Mode Fix)
        ↓
sdd-plan-architect → plan/
        ↓
sdd-task-generator → task/
        ↓
sdd-task-implementer → src/, tests/
```

**Input:** `requirements/REQUIREMENTS.md` (from `sdd-requirements-engineer`)
**Output:** Complete `spec/` directory with all subdirectories populated
**Next step:** Run `sdd-spec-auditor` to validate the generated specifications

## Self-Validation Gate

**MANDATORY**: Before declaring Mode 2 complete and updating pipeline-state.json, the specifications engineer MUST execute the following validation gate. This is NOT optional and NOT a separate mode invocation — it is the final step of Mode 2.

The gate runs on `grep` / `wc` output, **not** on re-reading the generated files (they are already in context from writing them).

### Step 1: Structural Validation (Mode 4 Auto-Check)

- Extract every cited id once: `grep -rhoE '(UC|WF|ADR|RN|NC)-[0-9]{3}|INV-[A-Z]+-[0-9]{3}|API-[0-9]{3}-[0-9]{2}|AC-[0-9]{3}-[0-9]{2}' spec | sort -u` — every id must have a definition (file name, heading or table row); every REQ id in `requirements/REQUIREMENTS.md` must appear in `TRACEABILITY-MATRIX.md` with at least one artifact
- No orphan specifications (every file has a `Refs` row with a REQ or a `DERIVED-SPECS.md` row)
- `grep -rniE 'TBD|TODO|FIXME' spec` → empty; no heading followed directly by another heading (empty section) except sections marked `[NEEDS CLARIFICATION]`, which must be listed in `CLARIFICATIONS-PENDING.md`

### Step 2: Pre-Flight Defect Scan

> **Detection patterns reference:** These checks are derived from `sdd-spec-auditor/references/detection-patterns.md`. If available, also load the auditor's grep patterns for CAT-01 (ambiguity words), CAT-04 (glossary synonyms), and CAT-06 (TBD/empty sections) to augment the checks below.

Run these lightweight grep checks against ALL generated spec documents to catch the most common audit findings BEFORE handing off to sdd-spec-auditor:

1. **Glossary compliance**: For every term in `domain/01-GLOSSARY.md` "Do not use" column, verify zero occurrences in any spec document. Flag violations.
2. **Value consistency**: For every value in `VALUE-REGISTRY.md`, grep the number across `spec/`; any document stating a different number for the same metric, or the number without the registry name, is a violation.
3. **BDD coverage**: For every UC, verify `tests/BDD-UC-NNN.md` exists with at least one happy-path and one error scenario, and that every AC id cited in the UC is defined there.
4. **Error flow completeness**: For every UC, verify the `Exceptions & errors` table has at least one row. Flag UCs with an empty table.
5. **Invariant formalization**: Scan all UC text for constraint language ("must", "shall not", "always", "never", "at least", "at most", "between X and Y", "unique", "only if", "requires") that does NOT have a corresponding INV-ID reference. Flag unformalized constraints.
6. **Cross-reference validity**: Verify every `UC-NNN`, `WF-NNN`, `INV-XXX-NNN`, `ADR-NNN`, `RN-NNN` reference resolves to an existing document or section.
7. **API error responses**: For every API contract endpoint, verify standard error responses are documented (401 for auth endpoints, 403 for protected endpoints, 404 for resource endpoints, 429 for rate-limited endpoints). Flag missing standard errors.
8. **Derived specs registration**: Verify that ALL artifacts generated by Step 6a (Error Flow Forcing), Step 6b (Invariant Extraction), and Step 6c are registered in `spec/DERIVED-SPECS.md` with correct Tier classification. Flag any Tier 1 items marked `[PENDING REQ]` — if >3 exist, alert the user before proceeding.

### Step 3: Fix Pre-Flight Findings

If the pre-flight scan finds issues:
- **Fix them immediately** before completing Mode 2 (these are self-inflicted defects, not user decisions)
- Do NOT ask the user — these are mechanical completeness fixes
- After fixing, re-run only the checks that failed

### Step 4: Completion Gate

Mode 2 is complete ONLY when:
- All structural validations pass
- All pre-flight defect scans pass (or remaining issues are marked with `[NEEDS CLARIFICATION]`)
- The traceability matrix is complete
- `find spec -name '*.md' -print0 | xargs -0 wc -c | tail -1` is within § Output Budget (or the excess is explained in one `highlights` line)

Report the gate to the console as one table (`check | result | fixed`), not as a document. Only then proceed to update `pipeline-state.json`.

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["specifications-engineer"].status` = `"done"`
3. Set `stages["specifications-engineer"].lastRun` = current ISO-8601
4. Set `stages["specifications-engineer"].summary`:
   - `artifacts`: list of files created in `spec/` with labels (e.g., `{"file": "spec/use-cases/UC-001.md", "label": "Extract PDF"}`)
   - `metrics`: `{ "use_cases": N, "workflows": N, "api_contracts": N, "bdd_scenarios": N, "invariants": N, "adrs": N, "spec_chars": N, "spec_budget_chars": N }` — `spec_chars` from the final `wc -c` over `spec/**/*.md`, `spec_budget_chars` from § Output Budget
   - `highlights`: top 3-5 notable observations (e.g., "41 use cases across 8 domains", "55 invariants defined", "spec/ 98k chars, within the 120k budget")
   - `nextStep`: `"Run /sdd-spec-auditor"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Respond in the same language the user uses. If the user writes in Spanish, respond in Spanish. If in English, respond in English.
