# SWEBOK v4 - Software Requirements Knowledge Base

## Table of Contents

1. [Fundamentals](#1-software-requirements-fundamentals)
2. [Categories](#2-categories-of-software-requirements)
3. [Elicitation](#3-requirements-elicitation)
4. [Analysis](#4-requirements-analysis)
5. [Specification](#5-requirements-specification)
6. [Validation](#6-requirements-validation)
7. [Management](#7-requirements-management)
8. [Prioritization](#8-requirements-prioritization)
9. [Tracing](#9-requirements-tracing)
10. [Quality Criteria Checklist](#10-quality-criteria-checklist)

---

## 1. Software Requirements Fundamentals

### Definition

A software requirement is:
- A condition or capability needed by a user to solve a problem or achieve an objective
- A condition or capability that must be met by a system to satisfy a contract, standard, or specification
- A documented representation of the above

### Two primary problems in requirements

1. **Incompleteness**: stakeholder requirements and necessary detail exist but are not revealed/communicated
2. **Ambiguity**: requirements are open to multiple interpretations, with only one being correct

### Key insight

Each requirement leads to many design decisions. Each design decision leads to many code-level decisions. Missing or incorrect requirements induce exponentially cascading rework.

---

## 2. Categories of Software Requirements

### Software Product vs. Project Requirements

- **Product requirements**: specify the software's form, fit, or function
- **Project requirements** (process/business): constrain the project (cost, schedule, staffing, environments, training, maintenance)

### Functional Requirements

Observable behaviors the software is to provide: policies to be enforced and processes to be carried out.

Examples:
- "An account shall always have at least one customer as its owner"
- "The balance of an account shall never be negative"

### Nonfunctional Requirements

Constrain the technologies used in implementation. Divided into:

**Technology Constraints**: mandate or prohibit specific technologies (platforms, languages, browsers, databases).

**Quality of Service Constraints**: specify acceptable performance levels (response time, throughput, accuracy, reliability, scalability). Reference ISO/IEC 25010 for quality characteristics.

### The Perfect Technology Filter

Functional requirements = those that would still need to be stated even if a computer with infinite speed, unlimited memory, zero cost, no failures existed. All other product requirements are nonfunctional.

### System vs. Software Requirements

System requirements apply to larger systems (hardware + software + people). Software requirements apply to the software element. Some software requirements are derived from system requirements.

### Derived Requirements

Requirements imposed inside the development team (not by external stakeholders). Example: an architect's decision to use pipes-and-filters becomes a requirement for sub-teams.

---

## 3. Requirements Elicitation

### Stakeholder Classes

- **Clients**: pay for the software
- **Customers**: decide whether software will be put into service
- **Users**: interact with the software (can be broken into classes by frequency, tasks, skill, privilege)
- **Subject matter experts (SMEs)**
- **Operations staff**
- **Product support staff**
- **Regulatory agencies**
- **Special interest groups**
- **People negatively affected if project succeeds**
- **Developers**

### Stakeholder Elicitation Techniques

- Interviews
- Meetings/brainstorming
- JAD (Joint Application Development) / JRP (Joint Requirements Planning) / facilitated workshops
- Protocol analysis
- Focus groups
- Questionnaires and market surveys
- Exploratory prototyping (low and high fidelity)
- User story mapping

### Non-Stakeholder Sources and Techniques

- Previous system versions
- Defect tracking databases
- Interfacing systems
- Competitive benchmarking
- Literature search
- QFD (Quality Function Deployment) House of Quality
- Observation (study work and environment)
- Apprenticing (learn by doing the work)
- Usage scenario descriptions
- Decomposition (capabilities > epics > features > stories)
- Task analysis
- Design thinking (empathize, define, ideate, prototype, test)
- ISO/IEC 25010 quality models
- Security requirements (CIA triad)
- Applicable standards and regulations

### Key Elicitation Challenges

- Users may have difficulty describing tasks
- Important information may be left unstated
- Stakeholders may be unwilling or unable to cooperate
- Many requirements are tacit or hidden

---

## 4. Requirements Analysis

### Desirable Properties of Individual Requirements

Each requirement should be:
- **Unambiguous**: interpretable in only one way
- **Testable** (quantified): compliance can be clearly demonstrated
- **Binding**: clients are willing to pay for it and unwilling not to have it
- **Atomic**: represents a single decision
- **Stakeholder-aligned**: represents true, actual stakeholder needs
- **Uses stakeholder vocabulary**
- **Acceptable to all stakeholders**

### Desirable Properties of the Overall Collection

- **Complete**: adequately addresses boundary conditions, exception conditions, security needs
- **Concise**: no extraneous content
- **Internally consistent**: no requirement conflicts with any other
- **Externally consistent**: no requirement conflicts with source material
- **Feasible**: a viable, cost-effective solution can be created within constraints

### The 5-Whys Technique

Repeatedly ask "Why is this the requirement?" to converge on the true problem. Repetition stops when the answer is "If that isn't done, then the stakeholder's problem has not been solved." Usually reached in 2-3 cycles.

### Economics of Quality of Service

- **Perfection point**: most favorable performance level, beyond which there is no additional benefit
- **Fail point**: least favorable performance level, beyond which there is no further reduction in benefit
- **Most cost-effective level**: maximum positive difference between value and cost to achieve

### Addressing Conflict

Two approaches:
1. **Negotiate resolution** among conflicting stakeholders (avoid unilateral decisions)
2. **Product family development**: separate invariant requirements (all agree) from variant requirements (conflict exists), design for both

---

## 5. Requirements Specification

### Specification Techniques

#### 5.1 Unstructured Natural Language

Simple "The system shall..." statements. Example: "A student cannot register in next semester's courses if there remain any unpaid tuition fees."

#### 5.2 Structured Natural Language

Imposes constraints on expression for precision.

**Actor-Action format**: `[Triggering event], [Actor] shall [Action] [Condition/qualification]`
Example: "When an order is shipped, the system shall create an Invoice unless the Order Terms are 'Prepaid'"

**Use Case specification template**:
- Use case number and name
- Triggering event(s)
- Parameters
- Requires (preconditions)
- Guarantees (postconditions)
- Normal course
- Alternative course(s)
- Exceptions

**User Story format**: "As a [role] I want [capability] so that [benefit]"

#### 5.3 Acceptance Criteria-Based (ATDD/BDD)

**ATDD process**:
1. Select a unit of functionality
2. Engineers + domain experts + QA agree on test cases before construction
3. At least one test case must fail; engineer creates/modifies code to pass all

**BDD format**:
- Story: "As a [role] I want [capability] so that [benefit]"
- Scenario: "Given [context] [and more context], when [stimulus] then [outcome] [and more outcomes]"

#### 5.4 Model-Based

Structural models (policies): class diagrams, conceptual data models, entity-relationship diagrams.
Behavioral models (processes): use case modeling, interaction diagrams, state modeling, activity diagrams, data-flow modeling.

Formality levels: Agile modeling (sketches) < Semiformal (UML/SysML) < Formal (Z, VDM, SDL).

### Additional Attributes of Requirements

- Tag (for tracing)
- Description (additional details)
- Rationale (why important)
- Source (which stakeholder)
- Use case or triggering event
- Type (functional, QoS, etc.)
- Dependencies
- Conflicts
- Acceptance criteria
- Priority
- Stability
- Common vs. variant
- Supporting materials
- Change history

---

## 6. Requirements Validation

### Methods

#### 6.1 Requirements Reviews

Multiple perspectives:
- Clients/customers/users: check wants and needs are represented
- Requirements specialists: check clarity and standards conformance
- Architects/designers/developers: check sufficiency for their work

Use checklists, quality criteria, or "definition of done."

#### 6.2 Simulation and Execution

Hand-interpret formal specifications with demonstration scenarios.

#### 6.3 Prototyping

Build a prototype demonstrating important dimensions. Dangers: cosmetic issues can distract from core functionality.

---

## 7. Requirements Management

### 7.1 Requirements Scrubbing

Find the smallest set of simply stated requirements. Eliminate those that:
- Are out of scope
- Would not yield adequate ROI
- Are not that important
Also: simplify unnecessarily complicated requirements.

### 7.2 Change Control

Process must include:
- Means to request changes
- Impact analysis stage (optional)
- Responsible person/group to accept, reject, or defer
- Notification to affected stakeholders
- Tracking accepted changes to closure

### 7.3 Scope Matching

Ensure requirements scope does not exceed cost/schedule/staffing constraints. When it does: reduce scope, increase capacity, or negotiate a combination.

---

## 8. Requirements Prioritization

### Factors for Priority

- Value/desirability/satisfaction
- Undesirability/dissatisfaction (Kano model)
- Cost to deliver
- Cost to maintain
- Technical risk
- Risk users won't use it

### Kano Model

Consider both satisfaction from having a feature AND dissatisfaction from lacking it. Example: users are happier with a spam filter than attachment handling, but the inability to handle attachments causes more unhappiness than lacking a spam filter.

### Priority Formula Example

`Priority = Value * (1 - Risk) / Cost`

### Priority Scales

- Enumerated: must have, should have, nice to have
- Numerical: 1 to 10
- Ordered lists: sorted by decreasing priority

---

## 9. Requirements Tracing

### Forward Tracing

Requirements -> Design elements -> Code -> Test cases -> User manual sections

### Backward Tracing

Source documents (system requirements, standards) -> Software requirements

### Purposes

1. **Consistency accounting**: verify each requirement has design elements and vice versa
2. **Impact analysis**: trace a proposed change through requirements -> design -> code -> tests

---

## 10. Quality Criteria Checklist

### Per-Requirement Checklist

| Criterion | Question |
|-----------|----------|
| Unambiguous | Can this be interpreted in only one way? |
| Testable | Can compliance be demonstrated with a specific test? |
| Binding | Is the client willing to pay for this and unwilling to not have it? |
| Atomic | Does this represent a single decision? |
| True need | Does this represent an actual stakeholder need (not a premature solution)? |
| Stakeholder vocab | Is it written in stakeholder language? |
| Acceptable | Do all relevant stakeholders agree? |

### Collection Checklist

| Criterion | Question |
|-----------|----------|
| Complete | Are boundary, exception, and security conditions addressed? |
| Concise | Is there extraneous content that can be removed? |
| Internally consistent | Do any requirements conflict with each other? |
| Externally consistent | Do any requirements conflict with source material? |
| Feasible | Can a solution be created within cost, schedule, and staffing constraints? |
| Prioritized | Are requirements prioritized considering value AND dissatisfaction? |
| Traceable | Can each requirement be traced to source and forward to design/test? |

### Specification Quality Checklist

| Criterion | Question |
|-----------|----------|
| Audience-appropriate | Is the specification formatted for its consumers? |
| Configuration managed | Is versioning and change control applied? |
| Unambiguous format | Is a structured or formal specification used where needed? |
| Acceptance criteria | Are acceptance criteria defined for each requirement? |
