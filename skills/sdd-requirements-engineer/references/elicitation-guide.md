# Requirements Elicitation Guide

## Elicitation Workflow

### Step 1: Stakeholder Identification

Identify all stakeholder classes before eliciting requirements:

| Class | Description | Key Questions |
|-------|-------------|---------------|
| Clients | Pay for the software | What problem needs solving? What are the budget/schedule constraints? |
| Customers | Decide to put software into service | What criteria determine adoption? What are acceptance conditions? |
| Users (by class) | Interact with the software | What tasks do you perform? How often? What frustrates you? |
| SMEs | Domain experts | What business rules apply? What policies must be enforced? |
| Operations | Run/maintain the system | What monitoring, backup, deployment needs exist? |
| Support | First-line troubleshooting | What issues do users report most? What diagnostics are needed? |
| Regulators | Impose compliance | What regulations, standards, certifications apply? |
| Negative stakeholders | Affected adversely by success | Who might resist or be harmed? What mitigation is needed? |
| Developers | Build the system | What technical constraints exist? What is feasible? |

### Step 2: Select Elicitation Techniques

Choose techniques based on stakeholder class:

| Technique | Best For | Output |
|-----------|----------|--------|
| **Interviews** | Deep understanding from individuals | Detailed requirements, context |
| **Workshops (JAD/JRP)** | Cross-functional alignment | Agreed requirements, resolved conflicts |
| **Brainstorming** | Creative exploration, new features | Candidate requirements list |
| **Prototyping** | UI/UX requirements, unclear needs | Visual/interactive requirements |
| **Questionnaires** | Large user populations | Prioritized needs, survey data |
| **Observation** | Understanding real workflows | Tacit requirements, process flows |
| **User story mapping** | Agile contexts, feature planning | Prioritized story map |
| **Design thinking** | Innovative solutions, empathy | User-centered requirements |
| **Document analysis** | Existing systems, regulations | Derived requirements, constraints |

### Step 3: Conduct Elicitation

#### Interview Template

```
Project: [Name]
Stakeholder: [Name, Role, Class]
Date: [Date]
Interviewer: [Name]

Context Questions:
1. What is your role in relation to this project?
2. What problem(s) should this software solve for you?
3. Walk me through a typical day/workflow involving this area.

Functional Questions:
4. What tasks do you need to perform?
5. What information do you need to see/access?
6. What decisions do you make based on this information?
7. What rules or policies govern these activities?

Quality Questions:
8. How quickly do you need the system to respond?
9. How many [users/records/transactions] need to be supported?
10. What happens if the system is unavailable?
11. What security/privacy concerns exist?

Closing:
12. What else should I know that I haven't asked about?
13. Who else should I talk to?
14. What documents should I review?
```

#### User Story Elicitation

Format: "As a [role] I want [capability] so that [benefit]"

Follow-up questions for each story:
- What triggers this need?
- What does success look like?
- What could go wrong?
- How do you handle this today without software?
- Who else is involved or affected?

#### The 5-Whys for Finding True Requirements

When a stakeholder states a requirement that sounds like a solution:

1. "Why is this needed?" -> [Answer 1]
2. "Why is [Answer 1] important?" -> [Answer 2]
3. "Why does [Answer 2] matter?" -> [Answer 3]
4. Continue until: "If that isn't done, the stakeholder's problem has not been solved"

Example:
- Stated: "We need a dropdown with all countries"
- Why? "So users can select their country"
- Why? "So we can calculate shipping costs"
- Why? "So we can show total price before checkout"
- True requirement: "The system shall calculate and display total price including shipping before the user confirms the order"

### Step 4: Document and Validate Elicited Information

After each elicitation session:
1. Record raw information immediately
2. Identify candidate requirements from the information
3. Categorize: functional vs. nonfunctional
4. Identify gaps and conflicts
5. Plan follow-up elicitation to fill gaps

### Common Elicitation Pitfalls

| Pitfall | Mitigation |
|---------|------------|
| Users describe solutions, not problems | Apply 5-Whys technique |
| Dominant stakeholders overshadow others | Conduct separate sessions per stakeholder class |
| Tacit knowledge left unstated | Use observation and apprenticing |
| Assumed requirements not captured | Ask "what else do you take for granted?" |
| Scope creep during elicitation | Define and communicate project boundaries early |
| Analysis paralysis | Set elicitation timeboxes, iterate |
