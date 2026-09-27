# Mode Fix: Apply Audit Corrections (`--fix`)

> Fixing is integrating verified answers into the specification, not inventing behaviour.

Run after an audit whose findings have been triaged (SKILL.md § Triage) and whose questions have been answered.

## Fix principles

1. **No invention** — every change traces to a finding plus a validated answer.
2. **No code** — only specification text, invariants, ADRs and clarifications.
3. **Full traceability** — every correction records finding id, answer, documents modified and correction type.
4. **No silent conflict resolution** — a non-trivial decision is recorded (ADR if architectural, RN if a business rule).
5. **Nothing skipped** — every finding appears in the corrections plan: P0–P2 with FIX as a block, all others as one
   row of the Dispositions table.
6. **Requirements are read-only** — upstream impact is detected and delegated to `sdd-req-change` (Constitution Art. 4).

## Correction types

| Finding | Correction type | Primary action |
|---|---|---|
| AMB | SPEC CHANGE | Rewrite vague text with precise, quantified language |
| IMP | NEW INVARIANT + SPEC CHANGE | Formalize the implicit behaviour as an invariant |
| SIL | SPEC CHANGE | Add the missing flow, error handling or edge case |
| SEM | SEMANTIC CLARIFICATION | Align terminology with the glossary |
| CON | SPEC CHANGE + decision record | Resolve the conflict in every document; record the decision as an ADR if architectural, an RN in `CLARIFICATIONS.md` if a business rule |
| INC | SPEC CHANGE | Complete missing sections, resolve markers |
| INV | NEW INVARIANT | Formalize the rule with id, validation and enforcement point |
| EVO | ADR REQUIRED | Document the extensibility strategy |
| ADR | ADR REQUIRED | Create the ADR with context, decision, alternatives |
| TRN | SPEC CHANGE | Rewrite as operation semantics + "transport: see design/OPERATION-MAPPING.md"; keep REQ-mandated transport, citing the REQ (rewrite table in `detection-patterns.md` § CAT-10) |

## Fix Phase 0: Locate the audit report

1. Open `audits/AUDIT-BASELINE.md` (a `--focused` fix reads `audits/AUDIT-FOCUSED-*.md`). It is ≤ 25 k chars: read it whole.
2. Extract every finding: id, severity, category, **Where**, **What**, **Why**, **Fix**, disposition and the answer
   received (user, questions file, or `[NO ANSWER]`). The working set is the cited lines — open them with `sed -n`
   when applying a correction — not the report's prose.
3. Count findings by severity and disposition and confirm the scope with the user (or apply a delegated scope, e.g.
   "P0/P1 without asking").
4. Before the first correction commit, work on a branch: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs"
   branch start audit` (`audit/fix-{date}`; branch rule in the plugin-root `references/git-conventions.md`; exit 1 →
   stop and show its message).

## Fix Phase 1: Corrections plan

Write `audits/CORRECTIONS-PLAN-AUDIT-vX.X.md` per `report-template.md` §4 (≤ 12 k chars for ≤ 15 requirements): a
summary table per severity and disposition; one block per P0–P2 finding with FIX (decision, change with `doc:line`,
before → after limited to the changed sentence or value, dependents from the Propagation Checklist, rejected
alternative, dependencies, upstream tier); one Dispositions row for every other finding.

## Fix Phase 1.5: Workflow

Ask the user: batch (apply all recommended corrections in priority order) or interactive (decide one by one).

## Fix Phase 2: Execute corrections

Order: P0 → P1 → P2 → P3; within a severity, CON first, then SIL, then the rest. Show before/after for each change,
limited to the changed sentence or value (≤ 4 lines).

**Propagation Checklist** — update all dependents in the same correction; incomplete propagation is the main cause of
audit regressions:

| If you modify... | Also verify and update... |
|---|---|
| `domain/01-GLOSSARY.md` | every spec document for term usage |
| `domain/02-ENTITIES.md` | `03-VALUE-OBJECTS.md`, `04-STATES.md`, `05-INVARIANTS.md`, UCs and contracts using the entities |
| `domain/03-VALUE-OBJECTS.md` | `02-ENTITIES.md` (field types), UCs and contracts using those VOs, `05-INVARIANTS.md` if the VO has constraints |
| `domain/04-STATES.md` | `05-INVARIANTS.md`, UCs with state transitions, WFs, BDD scenarios on state changes |
| `domain/05-INVARIANTS.md` | UCs that enforce them, contracts that validate them, BDD scenarios that test them |
| `contracts/PERMISSIONS-MATRIX.md` | every contract for operation–permission alignment |
| a UC exception row | the contract's Errors table, the BDD error scenario, the error catalog in `03-VALUE-OBJECTS.md` |
| an enum value | every document referencing the enum (`grep`) |
| `nfr/LIMITS.md` / `nfr/PERFORMANCE.md` / `VALUE-REGISTRY.md` | WFs (timeouts), contracts (rate limits), UCs (limits in text) |
| any terminology change | all of `spec/` for the old term |

After applying fixes, `grep -rn "OLD_TERM\|OLD_VALUE" spec/` for every changed term or value must return nothing.

**Commits** (when `spec/` is versioned): one commit per correction, or per cascade group of findings that resolve
together:

```bash
git commit -m "docs(specs): resolve {FINDING-ID} {brief description}" \
  --trailer "Change: {FINDING-ID}" --trailer "Refs: {affected REQ/UC ids}"
```

`Change:` names the finding, `Refs:` the spec ids it touches (required on `docs(specs)`). `--trailer` keeps them in one
block git can parse; when the harness asks for an attribution line, add it with `--trailer` too. The audit branch
reaches the default branch through a merge commit (`git merge --no-ff`) or a PR; ask before merging or pushing.

## Fix Phase 3: Verification summary and baseline update

1. In `audits/AUDIT-BASELINE.md`: append ` — RESOLVED ({artifact})` to the heading of each fixed P0–P2 finding; add
   one row per fixed finding to `Baseline › Resolved` and one per accepted / deferred / won't-fix disposition to the
   matching table; update the `History` row (Gate after fix).
2. Append the ≤ 8-line `Fix cycle` block (`report-template.md` §3).
3. Suggest the tag `git tag AUDIT-vX.X-resolved` (Phase 6 of the next audit diffs against it).

## Fix Phase 4: Upstream impact analysis

Corrections can show that the requirements are incomplete or misaligned. This phase closes the loop upward without
writing `requirements/`.

### Step 4.1: Classify corrections by tier

Classify every corrected finding with the shared tier file `../sdd-specifications-engineer/references/tier-classification.md`
(path relative to this skill's directory; tier table, decision tree, registration rules — shared with the spec engineer). Typical audit cases: a changed timeout that
a REQ states → Tier 1 MODIFY; a new UC without REQ → Tier 1 ADD; a not-found error added to an existing operation, an
invariant formalised from UC text, an edge-case scenario → Tier 2; glossary, ordering or cross-reference fixes → Tier 3.

### Step 4.2: Cross-reference against requirements

For each Tier 1 and Tier 2 correction, identify the REQ(s) the corrected document traces to (`Refs`, UC → REQ,
INV → REQ).
- **Tier 1 MODIFY:** flag the REQ when its statement contradicts the corrected behaviour, its acceptance criteria miss
  cases the correction added, or its scope is narrower than the correction.
- **Tier 1 ADD:** confirm no REQ covers it (direct references, parent or domain-level REQs); otherwise mark
  `[PENDING REQ]`.
- **Tier 2:** record the derived-from REQ.

### Step 4.3: Update DERIVED-SPECS.md

Add every Tier 1 and Tier 2 correction to the `## Audit derived` section of `spec/DERIVED-SPECS.md` (Template 15):

```markdown
| Artifact | Finding | Derived from | Tier | Justification | Status |
|---|---|---|---|---|---|
| INV-TSK-007 | INV-001 | REQ-F-005 | 2 | formalises "priority between 1 and 5" | Registered |
| E4 in UC-004 | SIL-002 | REQ-F-004 | 2 | storage timeout handling | Registered |
| UC-011 (export) | INC-005 | — | 1 | new user-visible operation | **[PENDING REQ]** |
```

### Step 4.4: Impact summary

Present to the user, and append to the report only when Tier 1 items exist:

```markdown
## Upstream Impact Analysis

| # | Finding | Correction | Tier | REQ affected | Action |
|---|---|---|---|---|---|
| 1 | {ID} | {brief} | 1 (MODIFY) | REQ-F-012 | REQ needs update: {what changed} |
| 2 | {ID} | {brief} | 1 (ADD) | [PENDING REQ] | New requirement needed: {what} |
| 3 | {ID} | {brief} | 2 | REQ-F-008 | Registered in DERIVED-SPECS.md |

Totals: {N} Tier 1 · {N} Tier 2 · {N} Tier 3 · Tier 1 pending REQs: {N}
```

### Step 4.5: Pipeline gate and user decision

- ≤ 3 Tier 1 items without REQ: advisory — the pipeline can proceed; items stay `[PENDING REQ]`.
- More than 3: the pipeline is **blocked** before `sdd-test-planner` until REQs exist or the items are accepted.

When Tier 1 items exist, ask:
- **Option 1: Invoke `sdd-req-change` now** (recommended) — pass a CR table (CR-ID, ADD/MODIFY, REQ-ID or "new",
  description, source finding, tier), noting that the specs are already corrected and only requirements need
  updating, plus the audit id.
- **Option 2: Impact report only** — write `audits/UPSTREAM-IMPACT-AUDIT-vX.X.md`; Tier 1 items stay `[PENDING REQ]`.
- **Option 3: Accept risk** — mark the items `[ACCEPTED WITHOUT REQ]` in `DERIVED-SPECS.md` with the user's
  justification.

**Station mode** (`SDD_ROLE` set, or a role resolved from `.claude/sdd-sessions.json`, and the role is not
`sdd-lead`): do not pick an option. Write the Upstream Impact table, leave Tier 1 items as `[PENDING REQ]`, append the
decision as a `Q-<role>-NNN [OPEN]` block (Options 1/2/3 as A/B/C, A recommended; `Blocks:` = pipeline gate to
sdd-test-planner) to `$STATE_ROOT/.sdd/questions-<role>.md` following the plugin-root `references/async-questions.md`,
finish the report and Persist Summary, then hand off with `status=blocked questions=<n> file=<path>` and end the turn.
On resume, apply the `[ANSWERED]` option exactly as if the user had chosen it.

## Post-audit traceability reconciliation

After the audit + fix cycle (Discovery → Fix → Verification), before the pipeline advances to `sdd-test-planner`:

1. List every UC, WF, INV, operation, BDD scenario and ADR in `spec/` (from the index).
2. Classify each: traced to a REQ; Tier 2 in `DERIVED-SPECS.md`; Tier 1 `[ACCEPTED WITHOUT REQ]`; Tier 1
   `[PENDING REQ]` (flag); or untraced (must be classified with the user and registered).
3. Append to the report:

```markdown
## Traceability Reconciliation

| Status | Count |
|---|---|
| Traced to REQ | {N} |
| Derived (Tier 2) | {N} |
| Accepted without REQ (Tier 1) | {N} |
| Pending REQ (Tier 1) | {N} |
| Untraced | {N} |

Pipeline gate: {PASS | BLOCKED}
```

The reconciliation gate is **PASS** when Pending REQ ≤ 3 and Untraced = 0, otherwise **BLOCKED**; a BLOCKED
reconciliation makes the stage's `gate_result` FAIL.
