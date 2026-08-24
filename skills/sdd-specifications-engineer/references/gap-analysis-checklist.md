# Gap Analysis Checklist for Specification Readiness

## How to Use This Checklist

Apply this checklist to requirements BEFORE writing specifications. The goal is to identify every gap, ambiguity, and issue that would prevent producing high-quality specifications. Every issue found must be resolved with the user before proceeding.

---

## Phase 1: Individual Requirement Readiness

For EACH requirement, evaluate specification readiness:

### 1.1 Precision for Specification

- [ ] **Specific enough to specify**: The requirement describes a concrete behavior, not a vague goal
- [ ] **Bounded**: The scope of the requirement is clear (what's included and what's not)
- [ ] **Measurable**: Any quality attributes have specific numbers (response time in ms, uptime in %)
- [ ] **No forbidden words**: "fast", "easy", "user-friendly", "efficient", "flexible", "robust", "intuitive", "seamless", "adequate", "reasonable", "appropriate", "simple", "quickly", "etc.", "and/or"
- [ ] **No undefined acronyms or terms**: All domain-specific terms are defined
- [ ] **Single interpretation**: Cannot be read in more than one way

### 1.2 Decomposability

- [ ] **Atomic**: Can be mapped to a single specification (not a compound requirement)
- [ ] **Independent enough**: Can be specified without circular dependencies
- [ ] **Right level of abstraction**: Not too high-level (epic) nor too low-level (implementation detail)

### 1.3 Specification Input Completeness

- [ ] **Actor identified**: Who or what triggers this behavior
- [ ] **Trigger identified**: What event initiates this behavior
- [ ] **Input defined**: What data/parameters are needed
- [ ] **Output defined**: What result is produced
- [ ] **Normal path clear**: What happens when everything goes right
- [ ] **Error paths identified**: What happens when things go wrong (at least the main ones)
- [ ] **Business rules stated**: Any rules or constraints that govern this behavior

### 1.4 Testability for Acceptance Criteria

- [ ] **Observable outcome**: The result can be seen, measured, or detected
- [ ] **Quantifiable where needed**: Numbers, thresholds, and limits are specified
- [ ] **BDD-derivable**: A "Given/When/Then" scenario can be written from this requirement
- [ ] **Edge cases identifiable**: Boundary values and special cases can be determined

---

## Phase 2: Collection-Level Readiness

### 2.1 Functional Coverage Gaps

Check if requirements exist for:

**User Management:**
- [ ] User registration/onboarding
- [ ] Authentication (login/logout)
- [ ] Password management (reset, change, policies)
- [ ] User profile management
- [ ] User roles and permissions
- [ ] Session management (timeout, concurrent sessions)
- [ ] Account deactivation/deletion

**Core Domain:**
- [ ] All CRUD operations for each entity
- [ ] Business rule enforcement
- [ ] Workflow/state transitions
- [ ] Search, filter, sort, paginate
- [ ] Batch operations (if applicable)
- [ ] Import/export of data

**Communication:**
- [ ] Notifications (email, push, in-app)
- [ ] Notification preferences
- [ ] Templates and customization
- [ ] Delivery confirmation

**Reporting:**
- [ ] Standard reports
- [ ] Custom/ad-hoc reporting
- [ ] Data export formats
- [ ] Scheduled reports
- [ ] Dashboard requirements

**Administration:**
- [ ] System configuration
- [ ] User management (admin perspective)
- [ ] Audit logs viewing
- [ ] System health monitoring

### 2.2 Nonfunctional Coverage Gaps

**Performance:**
- [ ] Page load time targets
- [ ] API response time targets
- [ ] Database query time targets
- [ ] File upload/download limits and times
- [ ] Background job processing times

**Capacity:**
- [ ] Concurrent users (normal, peak)
- [ ] Data storage growth rate
- [ ] Transaction volume (per second, per day)
- [ ] File size limits

**Availability:**
- [ ] Uptime target (99.9%, 99.99%, etc.)
- [ ] Planned maintenance windows
- [ ] Recovery Time Objective (RTO)
- [ ] Recovery Point Objective (RPO)
- [ ] Failover strategy
- [ ] Geographic distribution

**Security:**
- [ ] Authentication method (password, MFA, SSO, OAuth)
- [ ] Authorization model (RBAC, ABAC)
- [ ] Data classification (public, internal, confidential, restricted)
- [ ] Encryption requirements (at rest, in transit)
- [ ] Audit logging (what events, retention period)
- [ ] Compliance requirements (GDPR, HIPAA, SOC2, PCI-DSS)
- [ ] Vulnerability management
- [ ] Penetration testing requirements

**Compatibility:**
- [ ] Supported browsers and versions
- [ ] Supported devices and screen sizes
- [ ] Supported operating systems
- [ ] Supported API versions (backward compatibility)
- [ ] Supported integrations

**Usability:**
- [ ] Accessibility standards (WCAG 2.1 AA/AAA)
- [ ] Language/internationalization
- [ ] Maximum number of clicks for key workflows
- [ ] Error message standards
- [ ] Help/documentation requirements

### 2.3 Interface/Integration Gaps

- [ ] All external systems identified
- [ ] Communication protocol defined (REST, GraphQL, SOAP, gRPC, messaging)
- [ ] Authentication method for each integration
- [ ] Data format and schema for each integration
- [ ] Error handling for each integration (retry, circuit breaker, fallback)
- [ ] Rate limits and throttling
- [ ] Data synchronization strategy (real-time, batch, eventual consistency)
- [ ] Integration testing strategy

### 2.4 Data Gaps

- [ ] All data entities identified
- [ ] Relationships between entities defined
- [ ] Data validation rules specified
- [ ] Data format constraints (string lengths, number ranges, date formats)
- [ ] Required vs. optional fields
- [ ] Default values
- [ ] Data retention policies
- [ ] Data migration requirements (from existing systems)
- [ ] Data archival strategy

---

## Phase 3: Specification Document Quality

For EXISTING specification documents, verify:

### 3.1 Structure

- [ ] Follows a consistent template/format
- [ ] Organized by module or feature area
- [ ] Has a table of contents or navigation guide
- [ ] Uses consistent terminology throughout
- [ ] Has a glossary of terms

### 3.2 Completeness

- [ ] Every requirement has a corresponding specification
- [ ] Every specification has acceptance criteria
- [ ] Error paths are specified for every feature
- [ ] Preconditions and postconditions are stated
- [ ] Dependencies between specifications are documented

### 3.3 Traceability

- [ ] Traceability matrix exists (REQ -> SPEC)
- [ ] Every specification references its source requirement(s)
- [ ] Every requirement is accounted for in the matrix
- [ ] No orphan specifications (specs without requirements)
- [ ] Bidirectional tracing possible (forward and backward)

### 3.4 Quality

- [ ] A developer could implement from these specs alone
- [ ] No ambiguous specifications remain
- [ ] All decisions are documented with rationale
- [ ] All assumptions are documented
- [ ] Open questions are flagged clearly

---

## Issue Classification

### BLOCKER - Cannot proceed to specification
- Requirement is unintelligible or meaningless
- Fundamental business logic is missing
- Critical security requirements absent
- Core functionality undefined
- Irreconcilable conflicts between requirements

### CRITICAL - Specification will be deficient
- Ambiguous requirement with multiple valid interpretations
- Missing error handling for critical paths
- Nonfunctional requirements without measurable targets
- Missing acceptance criteria for complex behaviors
- Undefined integration contracts

### MAJOR - Specification will be incomplete
- Missing edge cases
- Missing secondary workflows
- Incomplete user role definitions
- Missing data validation rules
- Undefined notification/alerting behavior

### MINOR - Can proceed with documented assumptions
- Missing nice-to-have details
- Formatting inconsistencies
- Minor terminology variations
- Missing rationale (but requirement is clear)

---

## Decision Request Template

For each issue, present to the user:

```
## Issue [#]: [Short title]

**Severity**: [BLOCKER | CRITICAL | MAJOR | MINOR]
**Requirement**: [REQ-ID] - [Summary]
**Problem**: [Clear description of the issue]

### Why this matters
[Explain the impact on specifications and downstream development]

### Options

**A) [Option name]** (Recommended)
- Description: [What this option means]
- Pros: [Benefits]
- Cons: [Drawbacks]
- Impact: [How this affects the specification]

**B) [Option name]**
- Description: [What this option means]
- Pros: [Benefits]
- Cons: [Drawbacks]
- Impact: [How this affects the specification]

**C) [Option name]**
- Description: [What this option means]
- Pros: [Benefits]
- Cons: [Drawbacks]
- Impact: [How this affects the specification]

### My recommendation
[Detailed explanation of why option X is recommended]
```
