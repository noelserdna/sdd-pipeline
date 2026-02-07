# Test Techniques Reference (SWEBOK v4 Ch04 §3)

> Quick reference for test design techniques used by the test planner.

---

## Black-Box Techniques (Specification-Based)

### Equivalence Partitioning
Divide input domain into classes where all values in a class are expected to behave identically.
- **When:** Every input parameter
- **How:** Identify valid partitions (accepted values) and invalid partitions (rejected values)
- **Minimum tests:** One per partition

### Boundary Value Analysis
Test at the edges of equivalence partitions where defects concentrate.
- **When:** Numeric ranges, string lengths, date ranges, collection sizes
- **Values:** min-1, min, min+1, nominal, max-1, max, max+1
- **Minimum tests:** 7 per boundary (or 5 if min-1/max+1 are invalid)

### Decision Tables
Enumerate all combinations of conditions and their resulting actions.
- **When:** Multiple boolean conditions determine behavior (e.g., permission checks)
- **How:** Columns = conditions + actions, Rows = test cases
- **Optimization:** Collapse don't-care conditions

### State Transition Testing
Test all valid (and key invalid) transitions in entity state machines.
- **Input:** `spec/domain/04-STATES.md`
- **Cover:** Every valid transition, every invalid transition from each state
- **Depth:** 0-switch (single transitions) minimum, 1-switch (transition pairs) for critical entities

### Use Case Testing
Derive tests from UC main and exception flows.
- **Input:** `spec/use-cases/UC-*.md`
- **Cover:** Main flow (happy path), every exception flow, every precondition violation

---

## White-Box Techniques (Structure-Based)

### Statement Coverage
Every line of code is executed at least once.
- **Target:** ≥ 80% for domain logic, ≥ 60% for infrastructure

### Branch Coverage
Every decision point (if/else, switch) takes each possible path.
- **Target:** ≥ 70% for domain logic

### Path Coverage
Every unique execution path is tested.
- **When:** Critical business logic with multiple decision points
- **Note:** Combinatorial explosion — use for high-risk code only

---

## Experience-Based Techniques

### Error Guessing
- Test for common defects: null inputs, empty strings, negative numbers, zero, max int, SQL injection strings, XSS payloads
- Derive from `spec/nfr/SECURITY.md` and OWASP Top 10

### Exploratory Testing
- Structured exploration of the system guided by risk areas
- Document as charters: "Explore {area} to discover {risk}"
- Time-boxed sessions (60-90 min)

---

## Property-Based Testing

For invariants (`spec/domain/05-INVARIANTS.md`):
- Generate random valid inputs
- Assert invariant holds for ALL generated inputs
- Configure minimum 100 test cases per invariant
- Focus on: commutativity, associativity, idempotency, round-trip, domain boundaries

Template:
```
PROPERTY: {INV-PREFIX-NNN description}
  FOR ALL valid {entity} inputs:
    ASSERT {invariant condition} IS TRUE
  SHRINK on failure to find minimal counterexample
```

---

## Test Type Selection Matrix

| Spec Element | Primary Technique | Secondary Technique | Test Level |
|-------------|-------------------|---------------------|------------|
| Entity invariant | Property-based | Boundary value | Unit |
| Value object validation | Equivalence partition | Boundary value | Unit |
| UC main flow | Use case testing | Decision table | Integration |
| UC exception flow | Use case testing | Error guessing | Integration |
| API endpoint | Contract testing | Equivalence partition | Integration |
| State machine | State transition | Boundary value | Unit/Integration |
| Workflow (multi-UC) | Use case testing | Exploratory | E2E |
| Performance target | Load testing | Stress testing | Performance |
| Security requirement | OWASP checklist | Error guessing | Security |
| Rate limit | Boundary value | Stress testing | Integration |
