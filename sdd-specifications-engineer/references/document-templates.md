# Specification Document Templates

## Template 1: SRS Document (IEEE 830-inspired)

```markdown
# Software Requirements Specification (SRS)

## Document Information
| Field | Value |
|-------|-------|
| Project | [Project Name] |
| Version | [X.Y] |
| Date | [YYYY-MM-DD] |
| Status | [Draft / Under Review / Approved] |
| Author | [Name] |

## Revision History
| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1 | [Date] | [Author] | Initial draft |

---

## 1. Introduction

### 1.1 Purpose
[Describe the purpose of this SRS and the intended audience]

### 1.2 Scope
[Describe the software product, its purpose, and what is in/out of scope]

### 1.3 Definitions, Acronyms, and Abbreviations
| Term | Definition |
|------|-----------|
| [Term] | [Definition] |

### 1.4 References
| Reference | Description |
|-----------|-------------|
| [Ref] | [Description] |

### 1.5 Overview
[Describe the structure of the rest of this document]

---

## 2. Overall Description

### 2.1 Product Perspective
[Context: standalone, part of larger system, replacement for existing system]

### 2.2 Product Functions (Summary)
[High-level summary of major functions]

### 2.3 User Classes and Characteristics
| User Class | Description | Frequency | Technical Skill | Privileges |
|-----------|-------------|-----------|-----------------|------------|
| [Class] | [Desc] | [Freq] | [Skill] | [Privs] |

### 2.4 Operating Environment
[Hardware, OS, browsers, dependencies, integrations]

### 2.5 Design and Implementation Constraints
[Technology mandates, regulatory, standards, language, platform]

### 2.6 Assumptions and Dependencies
| # | Assumption/Dependency | Type | Impact if Invalid |
|---|----------------------|------|-------------------|
| 1 | [Description] | [Assumption/Dependency] | [Impact] |

---

## 3. Specific Requirements

### 3.1 Functional Requirements

#### 3.1.1 [Module Name]

##### SPEC-[MOD]-F-001: [Title]
- **Traces to**: REQ-001, REQ-002
- **Priority**: [Must/Should/Nice]
- **Description**: [Detailed specification text]
- **Preconditions**: [What must be true before]
- **Trigger**: [What initiates this behavior]
- **Normal Flow**:
  1. [Step 1]
  2. [Step 2]
  3. [Step 3]
- **Alternative Flows**:
  - AF1: [Alternative path description]
- **Exception Flows**:
  - EF1: [Error scenario and handling]
- **Postconditions**: [What must be true after]
- **Acceptance Criteria**:
  - Given [context], When [action], Then [expected result]
  - Given [context], When [error condition], Then [error handling]

### 3.2 Nonfunctional Requirements

#### 3.2.1 Performance
| SPEC-ID | Metric | Target | Measurement Method |
|---------|--------|--------|-------------------|
| SPEC-PERF-001 | [Metric] | [Target value] | [How to measure] |

#### 3.2.2 Security
| SPEC-ID | Control | Description | Standard |
|---------|---------|-------------|----------|
| SPEC-SEC-001 | [Control] | [Description] | [Standard ref] |

#### 3.2.3 Availability
| SPEC-ID | Metric | Target |
|---------|--------|--------|
| SPEC-AVL-001 | [Metric] | [Target] |

#### 3.2.4 Scalability
| SPEC-ID | Dimension | Current | Target | Growth Rate |
|---------|-----------|---------|--------|-------------|
| SPEC-SCL-001 | [Dimension] | [Current] | [Target] | [Rate] |

### 3.3 Interface Requirements

#### 3.3.1 User Interfaces
[UI requirements, wireframe references, UX specifications]

#### 3.3.2 API Interfaces
| SPEC-ID | Endpoint | Method | Auth | Request | Response |
|---------|----------|--------|------|---------|----------|
| SPEC-API-001 | [Path] | [Method] | [Auth] | [Schema] | [Schema] |

#### 3.3.3 External System Interfaces
| SPEC-ID | System | Protocol | Direction | Data | Frequency |
|---------|--------|----------|-----------|------|-----------|
| SPEC-EXT-001 | [System] | [Protocol] | [In/Out/Both] | [Data] | [Freq] |

### 3.4 Data Requirements

#### 3.4.1 Data Model
[Entities, relationships, cardinality]

#### 3.4.2 Data Dictionary
| Entity | Field | Type | Required | Constraints | Description |
|--------|-------|------|----------|-------------|-------------|
| [Entity] | [Field] | [Type] | [Y/N] | [Constraints] | [Desc] |

#### 3.4.3 Data Lifecycle
| Entity | Create | Read | Update | Delete | Archive | Retention |
|--------|--------|------|--------|--------|---------|-----------|
| [Entity] | [Rules] | [Rules] | [Rules] | [Rules] | [Rules] | [Period] |

---

## 4. Appendices

### 4.1 Traceability Matrix
[Reference to traceability-matrix.md]

### 4.2 Decisions Log
[Reference to decisions-log.md]

### 4.3 Glossary
[Extended glossary if needed]
```

---

## Template 2: Use Case Specification

```markdown
# Use Case: [UC-ID] [Use Case Name]

## Overview
| Field | Value |
|-------|-------|
| ID | UC-[MODULE]-[NUMBER] |
| Traces to | REQ-[IDs] |
| Primary Actor | [Actor name] |
| Priority | [Must/Should/Nice] |
| Status | [Draft/Approved] |

## Description
[Brief description of what this use case accomplishes]

## Triggering Event
[What causes this use case to start]

## Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| [Param] | [Type] | [Y/N] | [Desc] |

## Preconditions
1. [Precondition 1]
2. [Precondition 2]

## Postconditions (Guarantees)
### On Success
1. [Postcondition 1]
2. [Postcondition 2]

### On Failure
1. [Failure postcondition 1]

## Normal Course (Main Success Scenario)
| Step | Actor | System |
|------|-------|--------|
| 1 | [Actor action] | |
| 2 | | [System response] |
| 3 | [Actor action] | |
| 4 | | [System response] |

## Alternative Courses
### AC1: [Alternative name]
**Condition**: [When this alternative applies]
| Step | Actor | System |
|------|-------|--------|
| 3a | [Actor action] | |
| 3b | | [System response] |

### AC2: [Alternative name]
**Condition**: [When this alternative applies]
| Step | Actor | System |
|------|-------|--------|
| 2a | | [System response] |

## Exception Courses
### EC1: [Exception name]
**Condition**: [When this exception occurs]
| Step | Actor | System |
|------|-------|--------|
| *a | | [System error handling] |
| *b | | [System notification/recovery] |

## Business Rules
1. [BR-001]: [Business rule description]
2. [BR-002]: [Business rule description]

## Acceptance Criteria
- Given [precondition], When [trigger/action], Then [expected outcome]
- Given [precondition], When [alternative condition], Then [alternative outcome]
- Given [precondition], When [error condition], Then [error handling outcome]

## UI/UX Notes
[Any relevant UI/UX considerations, wireframe references]

## Open Questions
- [ ] [Question 1]
- [ ] [Question 2]
```

---

## Template 3: User Story + BDD Specification

```markdown
# [STORY-ID]: [Story Title]

## User Story
**As a** [role/persona]
**I want** [capability/action]
**So that** [benefit/value]

## Details
| Field | Value |
|-------|-------|
| Traces to | REQ-[IDs] |
| Priority | [Must/Should/Nice] |
| Story Points | [Estimate] |
| Sprint | [Sprint number/TBD] |

## Acceptance Criteria

### Scenario 1: [Happy path name]
```gherkin
Given [initial context]
  And [additional context]
When [action/event]
Then [expected outcome]
  And [additional outcome]
```

### Scenario 2: [Alternative path name]
```gherkin
Given [initial context]
When [alternative action]
Then [alternative outcome]
```

### Scenario 3: [Error path name]
```gherkin
Given [initial context]
When [error-triggering action]
Then [error handling outcome]
  And [user feedback]
```

### Scenario 4: [Edge case name]
```gherkin
Given [edge case context]
When [action]
Then [edge case outcome]
```

## Business Rules
- [BR-001]: [Rule description]

## Technical Notes
- [Any relevant technical constraints or considerations]

## Dependencies
- [STORY-ID]: [Dependency description]

## Definition of Done
- [ ] All acceptance criteria pass
- [ ] Code reviewed
- [ ] Unit tests written
- [ ] Integration tests pass
- [ ] Documentation updated
```

---

## Template 4: Actor-Action Specification

```markdown
# Actor-Action Specifications: [Module Name]

## Overview
| Field | Value |
|-------|-------|
| Module | [Module name] |
| Traces to | REQ-[IDs] |
| Version | [X.Y] |

## Specifications

### SPEC-[MOD]-F-[NNN]: [Title]

**Trigger**: [Event that initiates this action]
**Actor**: [Who/what performs the action]
**Action**: [What the actor does]
**Condition**: [Under what circumstances]

> [Triggering event], [Actor] shall [Action] [Condition/qualification].

**Acceptance Test**: Given [context], When [trigger], Then [observable outcome].

**Error Handling**: If [error condition], [Actor] shall [error action].

---
```

---

## Template 5: Traceability Matrix

```markdown
# Requirements-to-Specifications Traceability Matrix

## Forward Tracing (Requirements -> Specifications)

| Requirement ID | Requirement Summary | Specification ID(s) | Status | Notes |
|----------------|--------------------|--------------------|--------|-------|
| REQ-001 | [Summary] | SPEC-XXX-F-001 | Specified | |
| REQ-002 | [Summary] | SPEC-XXX-F-002, SPEC-XXX-F-003 | Specified | Split into 2 specs |
| REQ-003 | [Summary] | - | NOT SPECIFIED | [Reason] |

## Reverse Tracing (Specifications -> Requirements)

| Specification ID | Specification Summary | Requirement ID(s) | Notes |
|-----------------|---------------------|--------------------|-------|
| SPEC-XXX-F-001 | [Summary] | REQ-001 | |
| SPEC-XXX-F-002 | [Summary] | REQ-002 | |
| SPEC-ORPHAN-001 | [Summary] | NONE | ORPHAN - needs requirement |

## Coverage Summary

| Category | Total Requirements | Specified | Not Specified | Coverage |
|----------|-------------------|-----------|---------------|----------|
| Functional | [N] | [N] | [N] | [%] |
| Nonfunctional | [N] | [N] | [N] | [%] |
| Interface | [N] | [N] | [N] | [%] |
| Data | [N] | [N] | [N] | [%] |
| Security | [N] | [N] | [N] | [%] |
| **TOTAL** | **[N]** | **[N]** | **[N]** | **[%]** |
```

---

## Template 6: Decisions Log

```markdown
# Specification Decisions Log

## Purpose
This document records all decisions made during the specification process, including the options considered, the decision made, the rationale, and the impact on specifications.

## Decisions

### Decision [#001]: [Short title]
- **Date**: [YYYY-MM-DD]
- **Context**: [Why this decision was needed]
- **Issue**: [The problem or ambiguity found]
- **Related Requirements**: REQ-[IDs]
- **Options Considered**:
  1. [Option A]: [Description, pros, cons]
  2. [Option B]: [Description, pros, cons]
  3. [Option C]: [Description, pros, cons]
- **Decision**: [Which option was chosen]
- **Rationale**: [Why this option was chosen]
- **Decided by**: [Who made the decision]
- **Impact on Specifications**: [Which specs are affected and how]
- **Impact on Requirements**: [If any requirements need modification]

---
```

---

## Template 7: Nonfunctional Specification

```markdown
# Nonfunctional Specifications: [Category]

## [Category Name] (e.g., Performance, Security, Availability)

### SPEC-[CAT]-[NNN]: [Title]

| Field | Value |
|-------|-------|
| Traces to | REQ-[ID] |
| Priority | [Must/Should/Nice] |
| Category | [Subcategory] |

**Metric**: [What is being measured]
**Target**: [Specific measurable target]
**Fail Point**: [Minimum acceptable level - below this is failure]
**Perfection Point**: [Beyond this, no additional benefit]
**Current Baseline**: [Current measurement if available]

**Measurement Method**: [How to measure compliance]
**Test Scenarios**:
1. [Scenario 1]: [Description and expected outcome]
2. [Scenario 2]: [Under load/stress conditions]

**Monitoring**: [How to monitor this in production]
**Alerting**: [When to alert and who to notify]

---
```

---

## Template 8: Requirements Modification Proposal

```markdown
# Requirements Modification Proposal

## Document Information
| Field | Value |
|-------|-------|
| Date | [YYYY-MM-DD] |
| Author | Specifications Engineer (AI-assisted) |
| Triggered by | Specification readiness analysis |
| Severity | [Critical / Major / Minor] |

## Executive Summary
[2-3 sentences explaining why this proposal exists and what it recommends]

## Current State Assessment

### Quality Metrics
| Metric | Value | Threshold | Status |
|--------|-------|-----------|--------|
| Requirements with critical issues | [N] ([%]) | <10% | [PASS/FAIL] |
| Missing requirements identified | [N] | <5 | [PASS/FAIL] |
| Conflicting requirements | [N] | 0 | [PASS/FAIL] |
| Underspecified requirements | [N] ([%]) | <20% | [PASS/FAIL] |

### Issues Summary
- **BLOCKER**: [N] issues
- **CRITICAL**: [N] issues
- **MAJOR**: [N] issues
- **MINOR**: [N] issues

## Proposed Modifications

### 1. Requirements to Modify

#### MOD-001: [Modify REQ-XXX]
- **Current**: "[Current requirement text]"
- **Issue**: [What's wrong]
- **Proposed**: "[Modified requirement text]"
- **Rationale**: [Why this change is needed]

### 2. Requirements to Add

#### ADD-001: [New requirement title]
- **Proposed**: "[New requirement text]"
- **Category**: [Functional/Nonfunctional/etc.]
- **Priority**: [Must/Should/Nice]
- **Rationale**: [Why this is needed - what gap does it fill]
- **Source**: [Specification readiness analysis / stakeholder feedback]

### 3. Requirements to Remove or Merge

#### REM-001: [Remove/Merge REQ-XXX]
- **Current**: "[Current requirement text]"
- **Action**: [Remove / Merge into REQ-YYY]
- **Rationale**: [Why: duplicate, out of scope, infeasible, etc.]

## Impact Analysis

### Scope Impact
[How do these changes affect project scope?]

### Schedule Impact
[Estimated impact on timeline]

### Cost Impact
[Estimated impact on budget/resources]

### Risk Impact
[What risks are introduced or mitigated by these changes]

## Recommended Next Steps

1. [ ] Review this proposal with stakeholders
2. [ ] Approve/reject each proposed modification
3. [ ] Use the **requirements-engineer** skill to re-elicit for any new/modified requirements
4. [ ] Update the requirements documents
5. [ ] Re-run specification readiness analysis
6. [ ] Proceed with specification creation

## Approval

| Stakeholder | Role | Decision | Date | Comments |
|------------|------|----------|------|----------|
| [Name] | [Role] | [Approved/Rejected/Modified] | [Date] | [Comments] |
```
