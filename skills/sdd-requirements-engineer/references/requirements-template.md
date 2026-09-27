# REQUIREMENTS.md — template

`requirements/REQUIREMENTS.md` is parsed by downstream skills and scripts (`sdd-specifications-engineer`, `sdd-jev.mjs`, `sdd lint --needs`), so keep the field labels exactly as below.

```markdown
# Requirements Document

> **Project:** {project name}
> **Version:** {X.Y}
> **Last updated:** {YYYY-MM-DD}
> **Status:** Draft | Review | Approved
> **Customer needs:** [CUSTOMER-NEEDS.md](CUSTOMER-NEEDS.md)
> **Examples reviewed by:** {name (role)}, {YYYY-MM-DD}      ← optional: covers every requirement reviewed in one batch
> **Must list confirmed by:** {name (role)}, {YYYY-MM-DD} — {N of M Must, and why when > 60 %}
> **Approved by:** {name (role)}, {YYYY-MM-DD}               ← written at approval; the tag requirements-v{Version} is the proof

## Functional Requirements

### REQ-F-001: {Title}
- **Statement:** WHEN {trigger} THE {system} SHALL {behavior}
- **Category:** Functional
- **Priority:** Must have | Should have | Nice to have
- **Needs:** N-001, N-003
- **Verification:** test
- **Source:** {stakeholder or document}
- **Rationale:** {why this requirement exists}
- **Acceptance criteria:**
  - GIVEN {context with concrete data} WHEN {action with concrete input} THEN {observable outcome with concrete values}
  - GIVEN {…} WHEN {…} THEN {…}
- **Examples reviewed by:** {name (role)}, {YYYY-MM-DD}      ← omit when the header line covers it
- **Dependencies:** {REQ-F-NNN, or "None"}

## Nonfunctional Requirements

### REQ-NF-001: {Title}
- **Statement:** THE {system} SHALL {behavior} {quantified constraint}
- **Category:** Performance | Security | Scalability | Availability | Usability
- **Priority:** Must have | Should have | Nice to have
- **Needs:** N-00X
- **Verification:** measurement — {metric}, threshold {value}, measured by {tool / test / procedure}
- **Metric:** {measurable target, e.g., "p95 < 200 ms with 1,000 records"}
- **Acceptance criteria:**
  - GIVEN {load condition with numbers} WHEN {action} THEN {measurable outcome}

## Constraints

### REQ-C-001: {Title}
- **Statement:** {constraint description}
- **Type:** Technical | Business | Regulatory
- **Source:** {origin of constraint}
- **Needs:** N-00X | — (team/architecture source)
- **Verification:** test — {what the static check reads, e.g. package.json, import graph} | inspection — {what is reviewed}

## Traceability

| REQ ID | Type | Priority | Source | Needs | Verification | Dependencies |
|--------|------|----------|--------|-------|--------------|--------------|
| REQ-F-001 | Functional | Must | {source} | N-001 | test | None |
| REQ-NF-001 | Nonfunctional | Must | {source} | N-004 | measurement | REQ-F-001 |
| REQ-C-001 | Constraint | — | {source} | — | test | — |
| REQ-C-002 | Constraint | — | {source} | — | inspection | — |
```

## Field rules

- **Needs:** customer need IDs from `CUSTOMER-NEEDS.md`. Every REQ-F / REQ-NF cites at least one: a requirement no customer asked for is gold plating and needs a conversation, not a silent keep. A REQ-C imposed by the team or the architecture writes `— (team/architecture source)`.
- **Verification:** how acceptance will be proven; the acceptance stage later asks for evidence of exactly this kind, so choose the method the customer would accept as proof.

  | Method | Use for | Evidence later |
  |---|---|---|
  | `test` | behaviour (the default for REQ-F) | an automated test per criterion, named with its scenario ID |
  | `demo` | UI/UX look and flow a test cannot judge | the observed output, shown to the customer |
  | `measurement` | NFR with a threshold — state metric, threshold and how it is measured on the same line | a recorded value compared with the threshold |
  | `test` for a constraint | a constraint code can check: dependency lists, import boundaries, runtime/engine versions, forbidden APIs | a static test per constraint, named `REQ-C-NNN AC1 …` (a constraint has one implicit criterion, AC1) |
  | `inspection` | process, legal and organisational constraints, documentation, or anything no test can observe | a recorded human review |

  A constraint whose compliance a test can read should say `test`: a static check runs on every commit and never goes stale, while an inspection is a human record that expires whenever the files it names change. Keep `inspection` for what only a person can judge.

- **Acceptance criteria** carry real example data (names, amounts, IDs, exact messages, exit codes), not placeholders: "GIVEN a cart with 2 × 12.50 € WHEN …" instead of "GIVEN a cart with items". Customers can check a concrete example; they cannot check an abstraction. Cover the normal path, the main alternative and at least one error.
- **Examples reviewed by:** who on the customer side read the examples and agreed, and when. Per requirement, or once in the header when a whole batch was reviewed together.
- **Deprecated** requirements stay in place with `- **Status:** Deprecated (YYYY-MM-DD) — {reason}` (written by `sdd-req-change`); they are ignored by the coverage checks.
