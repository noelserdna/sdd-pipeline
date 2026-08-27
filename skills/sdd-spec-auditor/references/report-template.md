# Compact Report Templates (AUDIT-BASELINE.md, CORRECTIONS-PLAN)

> The report is a **finding index**, not a restatement of the specs. Every finding carries `doc:line`; anyone
> (human, Mode Fix, `sdd-test-planner`) reopens the document from the id. Detail that is not in the report is
> not lost: it lives in the spec at the cited line, and Mode Fix works on the findings (Where / What / Fix),
> never on the report's prose.

## 1. Size budget

| Corpus | Report budget (`wc -c audits/AUDIT-BASELINE.md`) |
|---|---|
| ≤ 15 requirements (typical: ≤ 45 spec docs) | **≤ 25 000 chars** |
| > 15 requirements | 25 000 + 1 000 per extra requirement, hard cap **60 000** |
| > 40 spec docs | additionally collapse the zero-finding rows of the Coverage table into one `Clean (n)` row |

Per-item caps: a P0–P2 block ≤ 900 chars (≈ 8 lines); a P3 row ≤ 220 chars; the header ≤ 1 200 chars.
Over budget → shorten *What/Why*, batch same-pattern findings (Phase 7.1), collapse Coverage. **Never drop a finding to fit.**
Record the final size in `pipeline-state.json` as `metrics.report_chars`.

## 2. What the report must NOT contain (the filler that made reports reach 95 k chars)

- Per-category summary tables with zero rows → one `Top categories` line in the header.
- Per-document prose, "no issues found in X", or per-document checklists → the Coverage table only.
- Restated spec content: quote **≤ 12 words** as evidence; never paragraphs, tables, schemas or flows from the spec.
- A "Recommendations by priority" list that repeats the ids (findings are already ordered by severity).
- Empty or trivial sections (`Excluded by baseline: 0`, `Documents not analyzed: none`) → a count in the header, or nothing.
- P3 findings written as blocks; a `Question` separate from `Fix`; `Related docs` lists longer than 3 refs.
- A 3C paragraph that restates every passing check → only failing checks are listed, with the finding ids.
- A second copy of the report (`AUDIT-vX.Y.md`): the History table is the per-run record. If a snapshot is wanted,
  `cp` it with Bash (costs no tokens).
- Post-fix tables of 10–20 rows (documents touched one by one, verification per document) → the ≤ 8-line `Fix cycle`
  and ≤ 6-line `Verification` blocks of §3.

## 3. `audits/AUDIT-BASELINE.md` (Mode Audit output; single file, rewritten each audit)

```markdown
# Audit Baseline — {project}

> **Audit:** AUDIT-v{X.Y} · **Date:** {YYYY-MM-DD} · **Specs:** `spec/` {version or date} · **Docs audited:** {N} · **Mode:** {fanout|sequential} · **Cycles:** 1 Discovery{ → 2 Fix → 3 Verification}
> **Gate:** **{PASS | CONDITIONAL PASS | FAIL}** — {one clause: e.g. "0 P0, 2 P1 documented, 4 P2"}
> **Findings:** {T} · P0 {n} · P1 {n} · P2 {n} · P3 {n} · batched {n} · cross-validated {n} · excluded by baseline {n}
> **Delta vs {AUDIT-vX.Y | none (first audit)}:** new {n} · persistent {n} · regression {n} · resolved since {n}
> **Top categories:** {CAT-05 (n), CAT-03 (n), CAT-06 (n)}

## Gate detail

| Check | Result |
|---|---|
| 3C Completeness (SC01–SC05) | {PASS 5/5 \| FAIL: SC04 → INC-001, INC-002} |
| 3C Correctness (SR01–SR05) | {PASS \| FAIL: SR02 → CON-001} |
| 3C Coherence (SH01–SH05) | {PASS \| WARN: SH01 → SEM-002} |
| Spec defect density | {n} P0/doc (target < 2) {PASS/FAIL} |
| Traceability coverage | {n}% (100%) {PASS/FAIL} |
| Orphan rate | {n}% (0%) {PASS/FAIL} |
| Clarification density | {n}/doc (0) {PASS/FAIL} |
| Audit pass rate | {n}% (> 90%) {PASS/FAIL} |
| Cross-reference validity | {n}% (100%) {PASS/FAIL} |

## Findings P0–P2

### {ID}: {title ≤ 12 words} — P{0|1|2} · CAT-{nn} · {new|persistent|regression}{ · [CROSS-VALIDATED]}{ · [CASCADE-DEP: ID]}
- **Where:** `{doc}:{line}`{ · `{doc}:{line}`}
- **What:** {1–2 sentences: the exact text or value that is wrong; quote ≤ 12 words}
- **Why:** {1 sentence: the consequence, plus the contradicting or missing evidence as `doc:line`}
- **Fix:** {≤ 3 lines: the spec-level correction — or the question the owner must answer before it can be written}

## Findings P3

| ID | Cat | Where | What | Fix |
|---|---|---|---|---|
| {SEM-001} | CAT-04 | `{doc}:{line}` | {≤ 12 words} | {≤ 12 words} |

## Coverage

| Document | P0 | P1 | P2 | P3 | IDs |
|---|---|---|---|---|---|
| {use-cases/UC-001-add-task.md} | 0 | 1 | 0 | 1 | CON-001, SIL-003 |
| {domain/01-GLOSSARY.md} | 0 | 0 | 0 | 0 | — |
{one row per audited document; > 40 docs: replace the zero rows by `| Clean ({n}) | 0 | 0 | 0 | 0 | {names} |`}

## Not audited
{only when non-empty; one line per document: `path — reason`}

## Baseline

### Accepted
| ID | Short description | Reason | Audit |
|---|---|---|---|

### Won't fix
| ID | Short description | Reason | Audit |
|---|---|---|---|

### Deferred
| ID | Short description | Reason | Audit | Re-evaluate on |
|---|---|---|---|---|

### Resolved (last 2 audits)
| ID | Short description | Resolved in | Audit |
|---|---|---|---|

## History

| Audit | Date | Docs | Total | P0 | P1 | P2 | P3 | Gate | Mode | Report chars |
|---|---|---|---|---|---|---|---|---|---|---|
```

Rules:
- The body (`Findings P0–P2`, `Findings P3`, `Coverage`) is the Discovery snapshot of **this** audit. Status lives in
  the `Baseline` tables: a finding not listed there is **open**. Phase 0 of the next audit reads only the ids and
  short descriptions (`grep -E '^### [A-Z]+-[0-9]+|^\| [A-Z]+-[0-9]+' audits/AUDIT-BASELINE.md`), carries the
  `Baseline` and `History` sections forward, and rewrites the body.
- Severity labels: P0 = Critical, P1 = High, P2 = Medium, P3 = Low (Severity Classification in SKILL.md).
- Order: P0 first, then P1, then P2; inside a severity, CON (contradictions) first, then SIL, then the rest.
- Batched findings (Phase 7.1) list every location in `Where` and count once.
- After Mode Fix: append ` — RESOLVED ({artifact, e.g. ADR-006})` to the heading of each fixed P0–P2 finding, move it
  to `Resolved`, and append the two blocks below (nothing else changes in the body):

```markdown
## Fix cycle (AUDIT-v{X.Y})
- Fixed {n} ({ids}) · skipped {n} ({ids}: reason) · open P2 {n} · deferred P3 {n}
- New artifacts: {paths}
- Documents modified: {n} · breaking changes: {n} ({one clause each}) · commits: {n} | not made ({reason}) · tag: {AUDIT-vX.Y-resolved | —}

## Verification (cycle 3)
- {ID} — verified: {evidence `doc:line`, ≤ 10 words}
- Regressions: {n} ({ids} or —) · cross-references: {n}/{n} resolve · residual old values: 0
- New findings during verification: {n} ({ids, severity} or —)
```

- Post-audit `Traceability Reconciliation` (SKILL.md) is the 5-row table defined there, appended after `Verification`;
  the `Upstream Impact` table (Fix Step 4.4) is appended only when Tier 1 items exist, one row per item.
- `--focused` audits write `audits/AUDIT-FOCUSED-{change-report-id}.md` with the same template minus `Baseline`
  and `History`; the header states the scope (`Docs audited: {n} (change set CR-xxx)`).

## 4. `audits/CORRECTIONS-PLAN-AUDIT-v{X.Y}.md` (Mode Fix, Fix Phase 1)

Only findings with `FIX` disposition and severity P0–P2 get a block. Every other finding is one row of the
`Dispositions` table (Fix Constraint 6: nothing is skipped, but nothing is restated). Reference the finding by id;
do not copy `What/Why` from the report.

```markdown
# Corrections Plan — AUDIT-v{X.Y}

> **Source:** `audits/AUDIT-BASELINE.md` (AUDIT-v{X.Y}) · **Mode:** {batch|interactive} · **Scope:** {n} FIX ({P0} P0, {P1} P1, {P2} P2) · {n} other dispositions

| Severity | Total | FIX | ACCEPT | DEFER | WONT_FIX |
|---|---|---|---|---|---|

## Corrections (P0–P2, FIX)

### {ID} — P{n} · {SPEC CHANGE | NEW INVARIANT | ADR REQUIRED | SEMANTIC CLARIFICATION}
- **Decision:** {the answer or chosen option; `[NO ANSWER]` → the finding stays open, no change}
- **Change:** {≤ 3 lines: what is added or rewritten, in which documents (`doc:line`)}
- **Before → After:** {only the changed sentence or value, ≤ 4 lines; omit for new sections or new ADRs}
- **Also update:** {dependents from the Propagation Checklist, by path}
- **Rejected alternative:** {one line} · **Depends on:** {ids | —} · **Upstream:** Tier {1|2|3}

## Dispositions (all other findings)

| ID | Sev | Disposition | Reason / re-evaluate on |
|---|---|---|---|
```

Rules: budget ≤ 12 000 chars for ≤ 15 requirements (same scaling as §1); commit messages go in the commits, not in
the plan (list them in the plan only when commits are not made, e.g. `spec/` is not versioned).
