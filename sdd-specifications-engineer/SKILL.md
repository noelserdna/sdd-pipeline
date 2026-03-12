---
name: sdd-specifications-engineer
description: "Professional software specifications engineer based on SWEBOK v4. Transforms requirements into formal specification documents. Use this skill when: (1) Translating requirements into technical specifications, (2) Creating Software Requirements Specification (SRS) documents, (3) Analyzing requirements for gaps and ambiguities before specification, (4) Building specification folder structures and documents, (5) Proposing modifications to deficient requirements. Triggers on phrases like 'create specifications', 'write specs', 'requirements to specifications', 'SRS document', 'specification document', 'translate requirements', 'spec from requirements', 'especificaciones', 'crear especificaciones'."
version: "1.1.0"
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
8. Produce a **Specification Readiness Report**:

```
# Specification Readiness Report

## Summary
- Total requirements analyzed: [N]
- Ready for specification: [N]
- Need clarification: [N]
- Need modification: [N]
- Missing requirements identified: [N]

## Issues Found
### Critical (blocks specification)
1. [REQ-ID]: [Issue] -> Options: [A, B, C] -> User decided: [X]

### Important (degrades specification quality)
1. [REQ-ID]: [Issue] -> Options: [A, B, C] -> User decided: [X]

## Gaps Identified
1. [Category]: [What's missing] -> [Recommendation]

## Decisions Log
| # | Issue | Options Presented | User Decision | Rationale |
|---|-------|-------------------|---------------|-----------|
| 1 | ...   | ...               | ...           | ...       |
```

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
7. Create the folder structure using the script or manually:
   - Run `scripts/create-spec-structure.ps1` for PowerShell environments
   - Or create the structure manually based on the template
8. For each requirement, create the corresponding specification:
   - Map requirement to specification section
   - Choose the appropriate specification technique
   - Write formal, unambiguous specification text
   - Include acceptance criteria
   - Include traceability (REQ -> SPEC mapping)
   - Apply the **Error Flow Forcing Function** (step 6a below)
   - Apply the **Invariant Extraction** process (step 6b below)

   #### Step 6a: Error Flow Forcing Function

   For EVERY step in a UC's Normal Flow, systematically answer these 5 questions and document each answer as an Exception Course entry:

   | Question | If yes, create... |
   |---|---|
   | 1. What if this step fails (network, timeout, service down)? | Exception course with error code + HTTP status |
   | 2. What if the input is invalid or missing? | Exception course with VALIDATION_ERROR + 400 |
   | 3. What if authorization is denied? | Exception course with 403 + specific permission |
   | 4. What if there is a concurrent conflict? | Exception course with 409 + conflict resolution |
   | 5. What if a precondition was met when checked but became false during execution? | Exception course with race condition handling |

   If any answer is "not applicable" for a specific step, document WHY in a comment. The goal is zero empty Exception Flows sections.

   For each exception course created, also add:
   - The corresponding error code to the API contract's error response table
   - A BDD error scenario in the corresponding `tests/BDD-UC-NNN.md`

   #### Step 6b: Invariant Extraction

   After writing each UC, scan its text for constraint language and formalize as invariants:

   1. Search for: "must", "shall not", "always", "never", "at most", "at least", "between X and Y", "unique", "only if", "requires", "cannot exceed", "minimum", "maximum"
   2. For each constraint found:
      - Check if a formal invariant already exists in `domain/05-INVARIANTS.md`
      - If not: create an INV-{AREA}-{NNN} entry with declarative rule and validation
      - Back-annotate the UC text with the INV-ID reference (e.g., "(see INV-SRV-003)")
   3. Present extracted invariants to the user for confirmation before finalizing

   > **Research Questions:** When specifying technical decisions that require evaluation
   > of alternatives (e.g., REST vs GraphQL, encryption algorithm selection, database
   > engine choice), document the open question instead of assuming an answer.
   > Create `spec/RESEARCH-QUESTIONS.md` listing each question with its context,
   > the specification(s) it blocks, and candidate options identified so far.
   > These questions are consumed by `sdd-plan-architect` Phase 3 (Research)
   > for deeper investigation. This enables early identification of research
   > needs during specification, avoiding costly rework downstream.

9. Create the **Traceability Matrix**:

```
| Requirement ID | Requirement Description | Specification ID | Specification Section | Status |
|----------------|------------------------|-------------------|----------------------|--------|
| REQ-001        | ...                    | SPEC-001          | 3.1.1                | Done   |
```

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

1. Create a **Requirements Modification Proposal** document:

```
# Requirements Modification Proposal

## Executive Summary
[Brief description of why modifications are needed]

## Current State Assessment
- Total requirements: [N]
- Critical issues: [N] ([%])
- Missing requirements: [N]
- Conflicts: [N]

## Proposed Modifications

### Modified Requirements
| Original REQ | Issue | Proposed Modification | Rationale |
|-------------|-------|----------------------|-----------|
| REQ-001     | ...   | ...                  | ...       |

### New Requirements to Add
| Proposed REQ | Description | Category | Priority | Rationale |
|-------------|-------------|----------|----------|-----------|
| REQ-NEW-001 | ...         | ...      | ...      | ...       |

### Requirements to Remove/Merge
| REQ to Remove | Reason | Merge Into |
|--------------|--------|------------|
| REQ-005      | ...    | REQ-003    |

## Impact Analysis
[Description of how these changes affect scope, schedule, and cost]

## Recommended Next Steps
1. Review this proposal with stakeholders
2. Use the requirements-engineer skill (/requirements-engineer) to re-elicit
3. Re-run specification readiness analysis
```

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
├── README.md                              # Overview and navigation guide
├── requirements/
│   └── REQUIREMENTS.md                    # Input from sdd-requirements-engineer
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
│   └── ADR-NNN-{slug}.md                  # Architecture Decision Records
├── tests/
│   ├── BDD-UC-NNN.md                      # BDD scenarios per use case
│   └── PROPERTY-TESTS.md                  # Property-based test specifications
├── nfr/
│   ├── PERFORMANCE.md                     # Performance targets (p99, throughput)
│   ├── LIMITS.md                          # Rate limits, quotas, thresholds
│   ├── SECURITY.md                        # Security requirements and controls
│   └── OBSERVABILITY.md                   # Logging, metrics, alerting specs
├── runbooks/
│   └── RB-NNN-{slug}.md                   # Operational runbooks
└── CLARIFICATIONS.md                      # Business rules (RN-NNN) from user decisions
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

Create the folder structure manually or use the PowerShell script:
```powershell
.\scripts\create-spec-structure.ps1 -ProjectPath .
```

## Key Principles (Always Apply)

### Ask Before Assuming
NEVER make assumptions silently. Every decision point must be presented to the user with options. Use `AskUserQuestion` for every ambiguity, gap, or choice.

### Glossary-First Writing
The glossary (`domain/01-GLOSSARY.md`) is a controlled vocabulary. Once created, it governs ALL spec writing:
- **Before using any domain term** in any spec document, verify it exists in the glossary
- **If a new term is needed**, add it to the glossary FIRST, then use it in spec documents
- **Never use synonyms** listed in the glossary's "NO usar" column
- **After completing all spec documents**, run a final glossary compliance pass: for each "NO usar" synonym, verify zero occurrences across all spec/ files

### Value Registry
Before writing specifications, create `spec/VALUE-REGISTRY.md` listing every shared value (timeouts, limits, rate limits, enum values, thresholds) with its canonical definition and the list of documents that reference it. During spec writing, every numeric value or enum used in more than one document MUST be registered. This prevents the #1 source of cross-document contradictions.

### Traceability is Non-Negotiable
Every specification MUST trace back to one or more requirements. Every requirement MUST have at least one specification. Orphans in either direction must be flagged.

### Iterative, Not Waterfall
If issues are found, stop and address them. Do not produce specifications over broken requirements. Better to go back than to build on a weak foundation.

### Implementation-Ready
Each specification must be detailed enough that a developer unfamiliar with the project could implement it correctly without additional clarification.

### Leverage Existing Skills
When requirements need modification, explicitly recommend `sdd-requirements-engineer` and explain how it can help.

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

### Step 1: Structural Validation (Mode 4 Auto-Check)

Run the Mode 4 validation process on the just-generated specifications:
- Verify every requirement has at least one specification artifact (UC, WF, contract, or INV)
- Verify no orphan specifications exist (specs without requirement traceability)
- Verify consistent terminology across all documents
- Verify all cross-references (UC-NNN, WF-NNN, INV-XXX-NNN, ADR-NNN) resolve to existing documents
- Verify no TBD/TODO/empty mandatory sections remain (except those marked with `[NEEDS CLARIFICATION]`)

### Step 2: Pre-Flight Defect Scan

> **Detection patterns reference:** These checks are derived from `sdd-spec-auditor/references/detection-patterns.md`. If available, also load the auditor's grep patterns for CAT-01 (ambiguity words), CAT-04 (glossary synonyms), and CAT-06 (TBD/empty sections) to augment the checks below.

Run these lightweight checks against ALL generated spec documents to catch the most common audit findings BEFORE handing off to sdd-spec-auditor:

1. **Glossary compliance**: For every term in `domain/01-GLOSSARY.md` "NO usar" column, verify zero occurrences in any spec document. Flag violations.
2. **Value consistency**: For every numeric value in `nfr/LIMITS.md` and `nfr/PERFORMANCE.md`, grep all spec documents. Flag any document using a different value for the same metric.
3. **BDD coverage**: For every UC, verify at least one BDD scenario exists in `tests/BDD-UC-NNN.md` with both a happy-path and an error-path scenario. Flag UCs without BDD.
4. **Error flow completeness**: For every UC, verify the "Exception Courses" or "Exception Flows" section is non-empty. Flag UCs with empty exception sections.
5. **Invariant formalization**: Scan all UC text for constraint language ("must", "shall not", "always", "never", "at least", "at most", "between X and Y", "unique", "only if", "requires") that does NOT have a corresponding INV-ID reference. Flag unformalized constraints.
6. **Cross-reference validity**: Verify every `UC-NNN`, `WF-NNN`, `INV-XXX-NNN`, `ADR-NNN`, `RN-NNN` reference resolves to an existing document or section.
7. **API error responses**: For every API contract endpoint, verify standard error responses are documented (401 for auth endpoints, 403 for protected endpoints, 404 for resource endpoints, 429 for rate-limited endpoints). Flag missing standard errors.

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

Only then proceed to update `pipeline-state.json`.

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["specifications-engineer"].status` = `"done"`
3. Set `stages["specifications-engineer"].lastRun` = current ISO-8601
4. Set `stages["specifications-engineer"].summary`:
   - `artifacts`: list of files created in `spec/` with labels (e.g., `{"file": "spec/use-cases/UC-001.md", "label": "Extract PDF"}`)
   - `metrics`: `{ "use_cases": N, "workflows": N, "api_contracts": N, "bdd_scenarios": N, "invariants": N, "adrs": N }`
   - `highlights`: top 3-5 notable observations (e.g., "41 use cases across 8 domains", "55 invariants defined")
   - `nextStep`: `"Run /sdd-spec-auditor"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)

## Output Language

Respond in the same language the user uses. If the user writes in Spanish, respond in Spanish. If in English, respond in English.
