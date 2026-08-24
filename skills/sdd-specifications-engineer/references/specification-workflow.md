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

For every issue found, present to the user using this structure:

```
ISSUE: [Clear description of the problem]
CONTEXT: [Why this matters for specification]
IMPACT: [What happens if not resolved]

OPTIONS:
A) [Option A description] (Recommended) - [Pros] / [Cons]
B) [Option B description] - [Pros] / [Cons]
C) [Option C description] - [Pros] / [Cons]

RECOMMENDATION: Option [X] because [rationale]
```

### 3.2 Decision Log

Record every decision in a structured log:

```
| # | Date | Issue | Options | Decision | Rationale | Impact on Specs |
|---|------|-------|---------|----------|-----------|-----------------|
```

### 3.3 Decision Categories

**Architecture Decisions**: affect the overall system structure
**Interface Decisions**: define how components/systems interact
**Data Decisions**: define data structures, storage, and lifecycle
**Quality Decisions**: set specific quality targets
**Scope Decisions**: include or exclude functionality
**Format Decisions**: choose specification formats and structure

---

## Phase 4: Specification Writing

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
7. **Cross-reference related specifications** with IDs
8. **Include acceptance criteria** for every specification: at minimum one Given/When/Then

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

| Attribute | Required | Description |
|-----------|----------|-------------|
| SPEC-ID | Yes | Unique identifier |
| Title | Yes | Short descriptive name |
| Traces to | Yes | Requirement ID(s) this specification satisfies |
| Priority | Yes | Inherited from requirement, may be adjusted |
| Description | Yes | Full specification text |
| Preconditions | Yes | What must be true before this behavior occurs |
| Postconditions | Yes | What must be true after this behavior occurs |
| Normal flow | Yes | Expected behavior path |
| Alternative flows | If applicable | Other valid paths |
| Exception flows | Yes | Error and failure handling |
| Acceptance criteria | Yes | BDD scenarios or measurable criteria |
| Dependencies | If applicable | Other SPEC-IDs this depends on |
| Assumptions | If applicable | Assumptions made during specification |
| Open questions | If applicable | Unresolved questions for stakeholder review |

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
- [ ] All decisions are documented in the decisions log
- [ ] The traceability matrix is complete

### 5.2 Coverage Report

```
# Specification Coverage Report

## Traceability Summary
- Requirements total: [N]
- Requirements with specifications: [N] ([%])
- Requirements without specifications: [N] ([%])
- Specifications total: [N]
- Specifications without requirements (orphans): [N]

## Coverage by Category
| Category | Requirements | Specifications | Coverage |
|----------|-------------|----------------|----------|
| Functional | [N] | [N] | [%] |
| Nonfunctional | [N] | [N] | [%] |
| Interface | [N] | [N] | [%] |
| Data | [N] | [N] | [%] |
| Security | [N] | [N] | [%] |

## Gaps
[List any uncovered requirements and reason]
```

---

## Phase 6: Deliverables

> **IMPORTANT:** The output directory is `spec/` (singular, no 's'). This is the canonical structure expected by all downstream SDD skills.

### 6.1 Required Deliverables

1. **spec/README.md** — Navigation guide and traceability overview
2. **spec/domain/01-GLOSSARY.md** — Ubiquitous language (terms, definitions, "NO usar" synonyms)
3. **spec/domain/02-ENTITIES.md** — Domain entities with attributes and relationships
4. **spec/domain/03-VALUE-OBJECTS.md** — Value objects, enums, typed values, ErrorResponse catalog
5. **spec/domain/04-STATES.md** — State machines for all stateful entities
6. **spec/domain/05-INVARIANTS.md** — Business rules as formal invariants (INV-XXX-NNN)
7. **spec/use-cases/UC-NNN-{slug}.md** — One file per use case
8. **spec/workflows/WF-NNN-{slug}.md** — Multi-step processes spanning use cases
9. **spec/contracts/API-{module}.md** — REST/GraphQL API contracts per module
10. **spec/contracts/PERMISSIONS-MATRIX.md** — Role-based access control matrix
11. **spec/tests/BDD-UC-NNN.md** — BDD scenarios per use case
12. **spec/nfr/PERFORMANCE.md** — Performance targets (p99, throughput)
13. **spec/nfr/LIMITS.md** — Rate limits, quotas, thresholds
14. **spec/nfr/SECURITY.md** — Security requirements and controls
15. **spec/CLARIFICATIONS.md** — Business rules (RN-NNN) from user decisions
16. **spec/VALUE-REGISTRY.md** — Canonical shared values (timeouts, limits, enums) with cross-references
17. **spec/DERIVED-SPECS.md** — Tier 1/2 spec artifacts not directly traced to REQs (generated by Error Flow Forcing, Invariant Extraction, and audit fixes)

### 6.2 Optional Deliverables

- **spec/contracts/EVENTS-{module}.md** — Domain events and async contracts
- **spec/adr/ADR-NNN-{slug}.md** — Architecture Decision Records
- **spec/nfr/OBSERVABILITY.md** — Logging, metrics, alerting specs
- **spec/runbooks/RB-NNN-{slug}.md** — Operational runbooks
- **spec/tests/PROPERTY-TESTS.md** — Property-based test specifications
- **spec/CLARIFICATIONS-PENDING.md** — Open clarification markers index
