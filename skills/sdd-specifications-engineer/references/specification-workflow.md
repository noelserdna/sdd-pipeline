# Specification Workflow Guide

## Overview

This guide describes the complete workflow for transforming requirements into formal specifications, following SWEBOK v4 Chapter 1, Section 5 (Requirements Specification) and Chapter 2 (Software Design).

---

## Phase 1: Requirements Intake

### 1.1 Locate Requirements

Search for requirements in:
- `requirements/` directory
- `docs/requirements/` directory
- `reqs/` directory
- Any `.md`, `.docx`, `.xlsx` files with "requirement" in name
- Jira/Confluence if configured
- README or project documentation

### 1.2 Inventory Requirements

Create an inventory of all found requirements:

```
| ID | Description (summary) | Type | Source | Priority | Has Acceptance Criteria | Spec-Ready |
|----|----------------------|------|--------|----------|------------------------|------------|
```

### 1.3 Classify Requirements

For each requirement determine:
- **Functional**: Observable behaviors (policies, processes) - Apply Perfect Technology Filter
- **Nonfunctional - Technology**: Specific technology mandates/prohibitions
- **Nonfunctional - QoS**: Quality of service constraints (performance, reliability, etc.)
- **Interface**: External system interactions
- **Data**: Data model, lifecycle, and integrity rules
- **Constraint**: Business or technical limitations

---

## Phase 2: Gap Analysis

### 2.1 Completeness Check

For each category, verify requirements exist:

**Functional Completeness:**
- [ ] All user-facing features identified
- [ ] All business rules/policies specified
- [ ] All workflows/processes documented
- [ ] All user roles and permissions defined
- [ ] CRUD operations for all data entities
- [ ] Search/filter/sort capabilities
- [ ] Reporting/analytics needs
- [ ] Notification/alerting requirements

**Nonfunctional Completeness:**
- [ ] Response time targets
- [ ] Throughput/capacity targets
- [ ] Availability/uptime targets
- [ ] Data retention policies
- [ ] Backup/recovery requirements
- [ ] Concurrent user capacity
- [ ] Browser/device/OS compatibility
- [ ] Accessibility standards (WCAG)
- [ ] Internationalization/localization

**Security Completeness:**
- [ ] Authentication method
- [ ] Authorization model (RBAC, ABAC, etc.)
- [ ] Data encryption (at rest, in transit)
- [ ] Audit logging
- [ ] Session management
- [ ] Input validation rules
- [ ] Rate limiting
- [ ] Data privacy/GDPR compliance

**Integration Completeness:**
- [ ] All external system interfaces identified
- [ ] API contracts defined (request/response)
- [ ] Authentication for external systems
- [ ] Error handling for external failures
- [ ] Data synchronization strategy
- [ ] Fallback behavior when integrations fail

### 2.2 Ambiguity Detection

Scan for these patterns:

**Vague Qualifiers:**
- "fast", "quick", "responsive" -> Ask: "What specific response time in milliseconds?"
- "easy", "intuitive", "user-friendly" -> Ask: "What specific UX criteria? Number of clicks? Error rate?"
- "secure" -> Ask: "What specific security controls? Against what threats?"
- "reliable" -> Ask: "What specific uptime %? What is acceptable downtime?"
- "scalable" -> Ask: "What specific load? How many concurrent users? What growth rate?"
- "flexible" -> Ask: "What specific configurability? What parameters must be adjustable?"

**Implicit Assumptions:**
- Technology stack not stated
- Deployment environment not defined
- User skill level assumed
- Network conditions assumed
- Data volume assumptions
- Browser/device assumptions

**Missing Boundary Conditions:**
- Maximum values not defined
- Minimum values not defined
- Empty/null handling not specified
- Overflow behavior not specified
- Timeout values not defined

### 2.3 Conflict Detection

Check for:
- Requirements that mandate contradictory behaviors
- Nonfunctional requirements that make functional requirements infeasible
- Priority conflicts (two "must-have" features that are mutually exclusive)
- Scope conflicts (requirements that exceed stated project boundaries)

---

## Phase 3: Decision Collection

### 3.1 Decision Framework

For every issue found, present it to the user with the Decision Request Template in `gap-analysis-checklist.md` (≤ 12 lines, one line per option) through `AskUserQuestion`.

### 3.2 Decision Log

The decision log **is** `spec/CLARIFICATIONS.md` (Template 16): one D-NNN row per format/structure decision, one RN-NNN row per business rule (source REQ, question, rule adopted, rejected options in one clause each, tier). No other log, no per-decision prose; the readiness report and every spec document cite the RN id.

### 3.3 Decision Categories

**Architecture Decisions**: affect the overall system structure
**Interface Decisions**: define how components/systems interact
**Data Decisions**: define data structures, storage, and lifecycle
**Quality Decisions**: set specific quality targets
**Scope Decisions**: include or exclude functionality
**Format Decisions**: choose specification formats and structure

---

## Phase 4: Specification Writing

### 4.0 Generation Order and Budget

Follow SKILL.md § Generation Order (plan ids → shared domain homes → one pass per requirement writing UC + BDD together → cross-cutting files → grep-based gate) and § Output Budget (≤ 120k chars for ≤ 15 requirements). Write each file once; never re-read a written file except through `grep` in the gate.

### 4.1 Choose Specification Technique

Based on SWEBOK v4, select the most appropriate technique(s):

**Unstructured Natural Language ("The system shall...")**
- Use for: Simple, standalone requirements
- Pros: Easy to write and read
- Cons: Prone to ambiguity
- Mitigate by: Adding acceptance criteria

**Structured Natural Language (Actor-Action)**
- Format: `[Triggering event], [Actor] shall [Action] [Condition]`
- Use for: Formal documents, contractual requirements
- Pros: Consistent, traceable
- Cons: Can be rigid

**Use Case Specifications**
- Template: Event, Parameters, Preconditions, Postconditions, Normal/Alternative/Exception courses
- Use for: Complex workflows, multi-step interactions
- Pros: Comprehensive, covers all paths
- Cons: Verbose, may be redundant for simple features

**User Stories + BDD Scenarios**
- Story: `As a [role] I want [capability] so that [benefit]`
- Scenario: `Given [context], When [stimulus], Then [outcome]`
- Use for: Agile teams, iterative development
- Pros: User-centered, directly testable
- Cons: May miss system-level concerns

**Model-Based Specifications**
- Structural: Class diagrams, ERD, data models (as markdown tables)
- Behavioral: State diagrams, activity flows, sequence descriptions
- Use for: Architecturally complex systems
- Pros: Precise, visual
- Cons: Requires modeling skills to read

### 4.2 Specification Writing Rules

1. **One specification per atomic requirement** (or group of closely related requirements)
2. **Use active voice**: "The system shall..." not "It should be..."
3. **Be specific**: quantities, units, thresholds, formats
4. **Include all paths**: normal, alternative, exception
5. **Define preconditions and postconditions** for every behavior
6. **Specify error handling explicitly**: what happens when things fail
7. **Cross-reference related specifications** with IDs — and only with IDs: never copy a requirement statement, a rule text or a value into a second document (`document-templates.md` § 0, W1–W2)
8. **Include acceptance criteria** for every specification: at minimum one happy-path and one error scenario, written once in `tests/BDD-UC-NNN.md` (AC-NNN-NN ids defined there) and cited from the UC
9. **Empty means `None.`** — one line, no justification; optional sections are omitted (W4)
10. **Tables and schema blocks, not prose** — no section that restates a table; no "Notes", "Implementation notes" or "Rationale" paragraphs (W3, W6)
11. **Boilerplate once per file** — auth/rate limit/version, standard errors, actors (W7)
12. **Write each file once** — plan ids, invariants and exception rows before writing (W9)

### 4.3 Specification ID Scheme

```
SPEC-[MODULE]-[TYPE]-[NUMBER]

MODULE: 3-letter module code (e.g., AUTH, USR, PAY, ORD)
TYPE: F (functional), N (nonfunctional), I (interface), D (data)
NUMBER: sequential within module+type

Examples:
SPEC-AUTH-F-001: First functional spec for authentication module
SPEC-PAY-N-001: First nonfunctional spec for payments module
SPEC-USR-I-001: First interface spec for user module
```

### 4.4 Specification Attributes

Each specification must include:

| Attribute | Required | Where / shape |
|-----------|----------|---------------|
| ID + Title | Yes | Heading (`UC-NNN — Name`) |
| Refs | Yes | One header row: REQ (+ WF, API, INV, RN, ADR, BDD ids). This is the traceability section |
| Priority | Yes | Header row, inherited from the requirement |
| Description | Yes | ≤ 2 sentences; never the requirement statement |
| Input / Output | Yes | One TypeScript/YAML block with constraints as VO/INV ids |
| Preconditions | Yes | Short list, ids for the rules |
| Postconditions | Yes | Success / failure, one bullet each |
| Main flow | Yes | Numbered `Actor: action` / `System: result`, ≤ 10 steps |
| Extensions | If applicable | One line each, AC id at the end |
| Exceptions & errors | Yes | One table: step, condition, code, HTTP/exit, effect, AC id |
| Acceptance criteria | Yes | In `tests/BDD-UC-NNN.md` only; the UC cites AC ids |
| Open questions | If applicable | `NC-NNN` lines; section omitted when none |

---

## Phase 5: Specification Validation

### 5.1 Self-Validation Checklist

Before presenting specifications to the user:

- [ ] Every requirement has at least one specification
- [ ] Every specification traces to at least one requirement
- [ ] No orphan specifications exist
- [ ] All acceptance criteria are concrete and testable
- [ ] All error paths are specified
- [ ] Terminology is consistent throughout
- [ ] A developer could implement from this spec alone
- [ ] No ambiguous terms remain
- [ ] All decisions are documented in `spec/CLARIFICATIONS.md` (RN rows)
- [ ] The traceability matrix is complete
- [ ] `wc -c` over `spec/**/*.md` is within SKILL.md § Output Budget

### 5.2 Coverage Report

There is no separate coverage report: coverage is the last line of `spec/TRACEABILITY-MATRIX.md` (`Coverage: N/N requirements specified. Orphans: none.`) and the gate result is one console table (`check | result | fixed`).

---

## Phase 6: Deliverables

> **IMPORTANT:** The output directory is `spec/` (singular, no 's'). This is the canonical structure expected by all downstream SDD skills.

### 6.1 Required Deliverables

Templates and ceilings: `document-templates.md`, SKILL.md § Output Budget.

1. **spec/README.md** — Navigation table only (Template 18)
2. **spec/domain/01-GLOSSARY.md** — Terms, ≤ 20-word definitions, "Do not use" synonyms (Template 17)
3. **spec/domain/02-ENTITIES.md** — Entities as schema blocks + one relationships line (Template 17)
4. **spec/domain/03-VALUE-OBJECTS.md** — Value objects, enums, and the **error catalog** (the only home of code → message → class → HTTP/exit) (Template 17)
5. **spec/domain/04-STATES.md** — State machines as tables (Template 9)
6. **spec/domain/05-INVARIANTS.md** — One table row per invariant (Template 10)
7. **spec/use-cases/UC-NNN-{slug}.md** — One file per use case (Template 2)
8. **spec/workflows/WF-NNN-{slug}.md** — Multi-step processes spanning use cases (Template 11)
9. **spec/contracts/API-{module}.md** — One contract per module, one Errors table (Template 12)
10. **spec/contracts/PERMISSIONS-MATRIX.md** — Role × operation grid; one row when there is a single role (Template 20)
11. **spec/tests/BDD-UC-NNN.md** — Scenarios per use case; defines the AC-NNN-NN ids (Template 13)
12. **spec/nfr/PERFORMANCE.md**, **LIMITS.md**, **SECURITY.md** — One table each; N/A categories are one row (Template 7)
13. **spec/CLARIFICATIONS.md** — D/RN decision tables; the only decisions log (Template 16)
14. **spec/CLARIFICATIONS-PENDING.md** — Open marker index, always present even if empty (SKILL.md)
15. **spec/VALUE-REGISTRY.md** — One table of canonical values (Template 14)
16. **spec/DERIVED-SPECS.md** — Tier 1/2 rows grouped by pattern (Template 15)
17. **spec/TRACEABILITY-MATRIX.md** — Forward table + coverage line (Template 5)

### 6.2 Conditional Deliverables (create only when the condition holds)

- **spec/contracts/EVENTS-{module}.md** — when the system emits domain/async events; otherwise a one-line absence declaration (Template 20)
- **spec/adr/ADR-NNN-{slug}.md** — one per decision actually taken during specification (Template 6)
- **spec/nfr/OBSERVABILITY.md**, **MAINTAINABILITY.md** — when a REQ-NF covers them
- **spec/runbooks/RB-NNN-{slug}.md** — only when a REQ/NFR requires an operational procedure or an ADR names a manual recovery (Template 19)
- **spec/tests/PROPERTY-TESTS.md** — when pure functions / invariants make property tests meaningful
- **spec/RESEARCH-QUESTIONS.md** — when open technical questions exist for `sdd-plan-architect`
