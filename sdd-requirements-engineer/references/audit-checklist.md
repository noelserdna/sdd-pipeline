# Requirements Audit Checklist

## How to Use This Checklist

Apply this checklist to each requirement or set of requirements provided by the user. Score each criterion as PASS, WARN, or FAIL. Provide specific, actionable feedback for any WARN or FAIL.

---

## Phase 1: Individual Requirement Audit

For EACH requirement, evaluate:

### 1.1 Clarity and Ambiguity

- [ ] **Single interpretation**: Can this be read in only one way?
- [ ] **No vague terms**: Avoid "fast", "user-friendly", "efficient", "flexible", "robust", "easy", "intuitive", "seamless", "adequate", "reasonable", "appropriate", "etc.", "and/or", "if applicable"
- [ ] **No pronouns without clear referents**: "it", "they", "this" must have unambiguous antecedents
- [ ] **Quantified where needed**: performance, capacity, timing have specific numbers
- [ ] **Defined domain terms**: technical or business terms are defined or use stakeholder vocabulary

### 1.2 Testability

- [ ] **Observable outcome**: describes something that can be seen, measured, or detected
- [ ] **Acceptance criteria exist or can be derived**: "Given X, when Y, then Z" can be written
- [ ] **No subjective terms**: avoid "should look good", "must be easy", "should feel fast"
- [ ] **Measurable quality attributes**: response time in ms, uptime in %, capacity in units

### 1.3 Atomicity

- [ ] **Single concern**: the requirement addresses one thing, not multiple bundled together
- [ ] **No compound statements**: avoid "and" or "or" joining distinct behaviors
- [ ] **One decision**: represents a single design/implementation decision

### 1.4 Necessity and Binding

- [ ] **Stakeholder-validated**: a real stakeholder wants and needs this
- [ ] **Not a premature solution**: describes WHAT, not HOW (apply 5-Whys if suspected)
- [ ] **ROI justified**: the value of implementing this exceeds its cost
- [ ] **Not gold-plating**: does not add capability beyond what stakeholders need

### 1.5 Completeness of Individual Requirement

- [ ] **Normal case covered**: the expected behavior is specified
- [ ] **Edge cases addressed**: boundary conditions, empty inputs, max values
- [ ] **Error cases addressed**: what happens when things go wrong
- [ ] **Security considered**: CIA (Confidentiality, Integrity, Availability) implications

### 1.6 Categorization

- [ ] **Correctly classified**: functional vs. nonfunctional (use Perfect Technology Filter)
- [ ] **If nonfunctional, subcategorized**: technology constraint vs. quality of service
- [ ] **Source identified**: which stakeholder or source imposed this requirement

---

## Phase 2: Collection-Level Audit

For the ENTIRE set of requirements, evaluate:

### 2.1 Completeness

- [ ] **All stakeholder classes identified**: clients, customers, users (by class), SMEs, operations, support, regulators
- [ ] **Functional coverage**: all policies and processes identified
- [ ] **Nonfunctional coverage**: technology constraints and quality of service constraints
- [ ] **Security requirements**: authentication, authorization, data protection, audit logging
- [ ] **Boundary conditions**: system limits, edge cases
- [ ] **Exception handling**: error scenarios, failure modes, recovery procedures
- [ ] **Data lifecycle**: creation, reading, updating, deletion, archiving
- [ ] **Regulatory/legal**: applicable laws, standards, compliance requirements

### 2.2 Consistency

- [ ] **No internal conflicts**: no requirement contradicts another
- [ ] **No external conflicts**: requirements align with source documents, standards
- [ ] **Terminology consistent**: same term means same thing throughout
- [ ] **Scope aligned**: requirements match the stated project scope

### 2.3 Feasibility

- [ ] **Technically feasible**: can be implemented with available or attainable technology
- [ ] **Economically feasible**: cost to implement is justified by value
- [ ] **Schedule feasible**: can be delivered within time constraints
- [ ] **Quality of service economics considered**: perfection point and fail point identified for QoS constraints

### 2.4 Organization

- [ ] **Prioritized**: each requirement has a priority (must/should/nice or numerical)
- [ ] **Traceable**: requirements can be traced to sources and forward to design/tests
- [ ] **Stability assessed**: volatile requirements identified for change-tolerant design
- [ ] **Grouped logically**: related requirements organized together

---

## Phase 3: Specification Quality Audit

### 3.1 Format

- [ ] **Appropriate for audience**: technical and non-technical consumers can find what they need
- [ ] **Consistent structure**: all requirements follow the same format/template
- [ ] **Configuration managed**: version control and change tracking applied
- [ ] **Uniquely identified**: each requirement has a unique tag/ID

### 3.2 Attributes

- [ ] **Required attributes present**: ID, description, source, priority, acceptance criteria
- [ ] **Rationale documented**: why each requirement exists
- [ ] **Dependencies mapped**: relationships between requirements noted
- [ ] **Status tracked**: draft, approved, implemented, verified

---

## Severity Levels

**FAIL** - Must fix before proceeding:
- Ambiguous requirement with multiple valid interpretations
- Untestable requirement
- Conflicting requirements
- Missing critical security or safety requirements
- Premature solution masquerading as requirement

**WARN** - Should fix, significant risk if ignored:
- Vague quality attributes without quantification
- Missing edge/error cases
- Unstated assumptions
- Incomplete stakeholder coverage
- Missing traceability

**PASS** - Acceptable quality:
- Clear, testable, atomic, necessary, complete requirement
- Well-categorized and prioritized
- Traceable and consistent with collection

---

## Audit Report Template

```
# Requirements Audit Report

## Summary
- Total requirements audited: [N]
- PASS: [N] | WARN: [N] | FAIL: [N]

## Critical Issues (FAIL)
1. [REQ-ID]: [Issue description] -> [Recommended fix]

## Warnings (WARN)
1. [REQ-ID]: [Issue description] -> [Recommended fix]

## Missing Requirements (Gaps)
1. [Category]: [Description of what's missing]

## Recommendations
1. [Specific actionable recommendation]
```
