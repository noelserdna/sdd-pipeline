# Requirements Elicitation Guide

## Stakeholder Classes

Identify every class before eliciting; a missing class is the most common source of missing requirements.

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

## The 5-Whys for Finding True Requirements

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
- True requirement: "WHEN the user reviews the order THE system SHALL display the total price including shipping before the user confirms it"
