# Traceability Tiers (shared by sdd-specifications-engineer and sdd-spec-auditor)

Every spec artifact that does not trace literally to a REQ — an exception course, an invariant, a BDD scenario, an
error code, an audit correction — gets one tier. The tier decides whether it needs a requirement.

| Tier | Condition | Examples | Action |
|---|---|---|---|
| **1** — user-visible behaviour without REQ backing | Introduces user-visible behaviour or a business rule no REQ covers (ADD), or changes behaviour a REQ defines explicitly (MODIFY) | a new retry workflow or notification; a new visible limit; changing a timeout a REQ states; a UC with no REQ | Register in `spec/DERIVED-SPECS.md` as **`[PENDING REQ]`** and raise it with the user: create or amend the REQ via `sdd-req-change`, or accept it as **`[ACCEPTED WITHOUT REQ]`** with a justification |
| **2** — technical detail of an existing REQ | Elaborates behaviour an existing REQ already covers: error flows, invariants that formalise a stated constraint, BDD edge cases, operation details, state transitions | a not-found error on an existing operation; an INV formalising "unique id"; an edge-case scenario for an existing UC | Register in `spec/DERIVED-SPECS.md` as `[Derived from REQ-X]` — no REQ needed |
| **3** — cosmetic / structural | Terminology, format, ordering, cross-reference fixes; filling a gap with information already implied; an invariant that already existed and was only back-annotated | fixing a glossary term; reordering an error table | No registration |

Most exception courses and invariants are Tier 2. Flag Tier 1 only when the behaviour is something no REQ anticipated.

## Decision tree

```
Does the artifact change user-visible behaviour?
├── YES → Does a REQ already define this behaviour?
│   ├── YES → Does the artifact CONTRADICT the REQ?
│   │   ├── YES → Tier 1 (MODIFY: the REQ must be updated)
│   │   └── NO  → Tier 2 (technical elaboration of the REQ)
│   └── NO  → Tier 1 (ADD: a new REQ is needed)
└── NO  → Is it a technical detail (error code, invariant, scenario)?
    ├── YES → Does it trace to an existing REQ, even indirectly?
    │   ├── YES → Tier 2 (derived from REQ-X)
    │   └── NO  → Tier 1 (new business rule without REQ)
    └── NO  → Tier 3 (cosmetic)
```

## Registration and gate

- `DERIVED-SPECS.md` (Template 15 of `document-templates.md`): rows grouped by pattern — one row per error family
  across UCs, one per invariant range — never one row per UC per code. The spec engineer writes `## Spec-engineer
  derived`; `sdd-spec-auditor` Mode Fix writes `## Audit derived` (adds the finding id).
- **More than 3 Tier 1 items `[PENDING REQ]`** → alert the user before the pipeline proceeds: "There are {N}
  specification artifacts that introduce user-visible behaviour without requirements. Consider running
  `/sdd-req-change` to create them." For `sdd-spec-auditor` this blocks the pipeline gate to `sdd-test-planner`.
- Neither skill writes `requirements/`: Tier 1 is detected and delegated to `sdd-req-change`.
- Asking the user about a Tier 1 item is the interactive thread's job. A spec-engineer lane never asks (it returns
  the item in `tier1`); a station (`SDD_ROLE` set, not `sdd-lead`) writes the question to the questions file per the
  plugin-root `references/async-questions.md` and keeps the item `[PENDING REQ]`.
