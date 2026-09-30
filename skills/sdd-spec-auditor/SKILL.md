---
name: sdd-spec-auditor
description: "Audits specs for defects: ambiguities, implicit rules, dangerous silences, contradictions, weak invariants, decisions without ADRs; Mode Fix repairs. Does NOT propose implementations. Triggers: 'audit specs', 'review specifications', 'spec quality', 'find ambiguities', 'fix specs', 'auditar especificaciones', 'revisar specs', 'calidad de specs'."
hooks:
  Stop:
    - type: prompt
      prompt: "If this session did not run sdd-spec-auditor Mode Fix (--fix), answer YES: a discovery audit leaves findings open for triage by design. If Mode Fix ran, answer YES only if every P0 (Critical) and P1 (High) finding with FIX disposition was corrected, or carries an explicit user disposition (ACCEPT, DEFER, WONT_FIX) in the Baseline tables of audits/AUDIT-BASELINE.md."
      once: true
---

# SDD Spec Auditor

> Auditing validates the specification as a contract, not as code. Unspecified behaviour is never assumed; implementations are never proposed.

Finds defects in `spec/` by systematic, cross-document analysis and writes a compact finding index (`audits/AUDIT-BASELINE.md`) with exact location, the problem, and the spec-level correction or the question that unblocks it. Mode Fix (`--fix`) applies triaged corrections.

## Core Principles

- **No assumptions:** write "it is not specified what happens when…", never "it probably means…".
- **No implementation:** "the contract of X is missing" or "what must happen when…?", never "implement it with…".
- **Cross-document evidence:** every finding cites `doc:line` and the related documents that contradict or complement it; quotes ≤ 12 words.

## Defect Categories

Signals and one example finding per category: [references/defect-categories.md](references/defect-categories.md) (read it before Phase 5; auditors get the pointer).

| Cat | Prefix | Defect | Severity cap |
|---|---|---|---|
| CAT-01 | `AMB-` | Ambiguity: vague qualifiers, missing quantifiers, unclear referents | — |
| CAT-02 | `IMP-` | Implicit rule: behaviour assumed but stated nowhere | — |
| CAT-03 | `SIL-` | Dangerous silence: a specific scenario not handled (error, timeout, edge case, dead state, replay of a write) | — |
| CAT-04 | `SEM-` | Semantic ambiguity: synonyms, same term with different meanings | naming/format ≤ P3 |
| CAT-05 | `CON-` | Contradiction between documents | — |
| CAT-06 | `INC-` | Incomplete: empty section, TBD, broken reference, open `[NEEDS CLARIFICATION]` | — |
| CAT-07 | `INV-` | Rule in prose without formal invariant, or invariant without validation | — |
| CAT-08 | `EVO-` | Future evolution risk (closed enums, hard-coding, coupling, unversioned API) | ≤ P2 |
| CAT-09 | `ADR-` | Material decision without ADR | — |
| CAT-10 | `TRN-` | Transport/UI mechanics no REQ demands | ≤ P2; P1 when it blocks required behaviour |

### Category Disambiguation Rules

Each finding gets exactly one category.

| Overlap | Rule |
|---|---|
| CAT-01 vs CAT-04 | Vague word → CAT-01. Two documents using different words for one concept → CAT-04. |
| CAT-02 vs CAT-07 | Rule not mentioned anywhere → CAT-02. Mentioned in prose but without an INV id → CAT-07. |
| CAT-03 vs CAT-06 | A specific scenario missing from a populated section → CAT-03. A whole section/field missing, empty or TBD → CAT-06. |
| CAT-09 materiality | Only material decisions (data store, auth, infrastructure platform, protocol, encryption, tenancy, id format). Industry defaults (HTTP, JSON, UTF-8) need no ADR. |
| CAT-09 vs CAT-10 | Material decision lacking its ADR → CAT-09 (fix: write it). Transport/UI mechanics no REQ demands → CAT-10 (fix: move to `design/OPERATION-MAPPING.md`, no ADR). |
| CAT-10 vs SEC-CAT-10 | Unrelated: `SEC-CAT-10` (`sdd-security-auditor`) is a security decision without ADR. A mechanic a security control demands (CSRF token, `SameSite`) is not CAT-10. |

## Spec-Level Verification (3C Protocol)

A structural pass/fail gate that complements CAT-01..10.

**Completeness**
- CHECK-SC01: every REQ in `requirements/REQUIREMENTS.md` traces to at least one spec artifact (UC, WF, operation or INV).
- CHECK-SC02: no orphan specs — every artifact traces to a REQ or has a `DERIVED-SPECS.md` row.
- CHECK-SC03: the mandatory directories `domain/`, `use-cases/`, `contracts/` and `tests/` each contain at least one document (`workflows/`, `adr/`, `nfr/`, `runbooks/` are conditional and may be absent).
- CHECK-SC04: no placeholder sections — no TBD, TODO or empty sections.
- CHECK-SC05: traceability chain intact — REQ → UC → WF → API → BDD → INV → ADR linkable end to end.

**Correctness**
- CHECK-SR01: each spec reflects the intent of its traced REQ, not just the letter.
- CHECK-SR02: no two documents assert conflicting facts about the same concept.
- CHECK-SR03: every INV id referenced in UCs/WFs/contracts exists in `domain/05-INVARIANTS.md` with a complete definition.
- CHECK-SR04: states referenced in UCs and WFs match `domain/04-STATES.md` exactly.
- CHECK-SR05: roles and permissions in UCs match `contracts/PERMISSIONS-MATRIX.md`.

**Coherence**
- CHECK-SH01: all documents use only glossary terms.
- CHECK-SH02: the same concept has the same name everywhere.
- CHECK-SH03: every reference (UC, WF, ADR, INV, API, AC, RN) resolves.
- CHECK-SH04: shared values are identical in every document that mentions them.
- CHECK-SH05: documents of the same type follow the same template structure.

Report the 3C result as the first three rows of the `Gate detail` table (`references/report-template.md` §3): `PASS n/n` or `FAIL: {failing check ids → finding ids}`. A FAIL in Completeness or Correctness makes the Gate FAIL (it blocks `sdd-test-planner`); Coherence failures are warnings. In fan-out mode each check has one owner (`references/fanout-protocol.md` §4).

## Audit Process

### Execution Strategy

Full protocol: [references/fanout-protocol.md](references/fanout-protocol.md) (mode table, index commands, budgets, scopes and prefixes, launch, auditor prompt, JSON shape, consolidation).

1. **Index before files.** Phase 1 builds `$IDX` with one `grep -rn` over `spec/`. Everything else is opened by section (`sed -n 'a,bp'`, ≤ 60 lines) from the index line numbers. The main thread never `cat`s a spec file; a file ≤ 8 k chars may be read whole only by the thread that owns it.
2. **Budget.** The main thread holds at most ~30 k tokens of spec content (index summaries, baseline ids, grep output, spot checks of P0/P1 evidence).
3. **Fan-out above the threshold is part of this skill's contract.** When `spec/` has more than 8 files or more than 40 k chars, Phases 2–5 run in four read-only dimension auditors (Domain `DOM-`, Use cases + workflows `UC-`, Contracts + BDD `CON-`, NFR + ADR + runbooks `NFR-`) launched with the `Agent` tool (also under `claude -p`). Do not downgrade out of caution; downgrade only for a reason in `fanout-protocol.md` §1 and record it in `metrics.mode` and `summary.highlights`. `--fanout` forces the auditors; `--sequential` forces one thread.
4. **Compact output.** Findings are collected in the JSON shape of `fanout-protocol.md` §6 before anything is written; the report follows `references/report-template.md`.

### Phase 0: Baseline Loading

Check for `audits/AUDIT-BASELINE.md` (its `Baseline` and `History` sections are the tracking tables).

1. Read only ids and short descriptions: `grep -E '^### [A-Z]+-[0-9]+|^\| [A-Z]+-[0-9]+' audits/AUDIT-BASELINE.md`.
2. **Exclusion set** (the only one — the fan-out consolidation and every other rule use it): rows of `Accepted`, `Won't fix`, and `Deferred` whose `Re-evaluate on` date has not passed. A matching finding (same document + same defect) is not re-reported; count it for the header. An expired `Deferred` row is re-evaluated and may be reported again. `Resolved` rows are not excluded: a resolved finding detected again is a `regression`.
3. Findings of the previous body that are in no Baseline table are **open**: detected again → `persistent` (Persistence Escalation Rule).
4. Carry `Baseline` and `History` forward; the body is rewritten. In fan-out mode pass the exclusion set (`ID — short description`) to each auditor as "known findings".
5. No baseline → first audit: `Delta vs none (first audit)`; every finding is `new`.

### Phase 1: Inventory and Index

1. Measure `FILES` and `CHARS` of `spec/**/*.md` and choose the mode (`fanout-protocol.md` §1).
2. Build the index (§2) and read only its summaries: headings per file (structure, numbering gaps, SH05) and the id set (referenced ids that do not exist → SH03).
3. Record every document path for the Coverage table; versions and dates come from the index lines.
4. Fan-out: launch the four auditors now (one message, four `Agent` calls, or `run_in_background`), then run the main-thread checks of §4 (cross-references, REQ coverage, markers, SC03, SH05, baseline, regression) while they work. Sequential: run Phases 2–5 in dimension order (§8).

### Phase 2: Glossary Compliance

Extract the terms of `domain/01-GLOSSARY.md`; scan all documents for terms missing from the glossary, "Do not use" synonyms and inconsistent capitalization.

### Phase 3: Cross-Reference Analysis

Build the reference graph; find broken references, orphan documents and pairs of documents that say different things about the same topic.

### Phase 3.5: Value Registry Verification

With `spec/VALUE-REGISTRY.md`: grep every registry name and value over `spec/`; flag any document using a different value for the same metric. Without it: one CAT-06 finding recommending it, listing the shared values found (timeouts, limits, rate limits, enums).

### Phase 4: Completeness Check

1. Every UC section filled; every WF step with error handling; every INV with a validation; no ADR left `Proposed` indefinitely.
2. **`[NEEDS CLARIFICATION]` markers:** each open `<!-- [NEEDS CLARIFICATION] NC-NNN: … -->` is one CAT-06 finding (`INC-NNN`) located at the marker, quoting its question; severity at least P2, P1 when it blocks a UC main flow or a contract definition; fix = "decide, remove the marker and record the RN in CLARIFICATIONS.md". Cross-check `spec/CLARIFICATIONS-PENDING.md` against the markers and report discrepancies either way.

### Phase 5: Defect Detection

For each document type: open the sections the index lists (whole file only if ≤ 8 k chars), apply its checklist in `references/audit-checklists.md` (that section only) and the patterns in `references/detection-patterns.md`, and record findings as `{id, sev, cat, doc, line, also, claim, why, fix}`. Neighbour evidence comes from `grep -n` / `sed -n` on the cited lines, never by reading the neighbour whole.

**Optional Jev triage of pattern hits** (opt-in; sends the hit lines to TypeSafe). The CAT-01/02/03/04/06/07/09 patterns in `detection-patterns.md` match many correct lines. When `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-jev.mjs" status` exits 0 and there are more than ~30 hits, write one JSONL item per hit (`{"id":"<file>:<line>","state":{"hit":{"file","line","text","context"}}}`, context = the line ±3) and run `sdd-jev.mjs judge --questions scripts/jev/spec-triage.json --items hits.jsonl --out .sdd/jev/spec-triage.json` (question file under the plugin root). Drop a hit only when the answer is `not_a_defect` with confidence ≥ 0.8. Every other hit goes through the normal check, starting with the ones Jev labelled with a category. Hits for CAT-05, CAT-08 and CAT-10 skip the triage: they need other documents. Exit code 3 means Jev is off: check every hit.

### Phase 6: Regression Verification

With a previous audit:

1. Modified files since then: `git diff --name-only AUDIT-vX.Y-resolved..HEAD -- spec/` (the tag suggested by the last Mode Fix); without the tag, `git log --since=<last report date> --name-only -- spec/`; without git, file timestamps against the report date.
2. For each modified file: the fix did not introduce new inconsistencies, matches the original finding's intent, and cross-references still resolve.
3. High-coupling files — check all their dependents when modified: `02-ENTITIES.md` → 03, 04, 05 and UCs using the entities; `03-VALUE-OBJECTS.md` → 02 field types, UCs and contracts using the VOs; `04-STATES.md` → 05, UCs with transitions, WFs; `05-INVARIANTS.md` → enforcing UCs and validating contracts; `PERMISSIONS-MATRIX.md` → every contract; `CLARIFICATIONS.md` → UCs citing the modified RNs.
4. Enum/VO sync: a changed enum is grepped over `spec/`; every occurrence has the same values.
5. Status of each finding: `new` (never reported), `persistent` (reported and still open), `regression` (not open before, and located in a file modified by a previous fix, or matching a `Resolved` row).

### Phase 7: Finding Consolidation

In fan-out mode this starts by merging the auditors' JSON (`fanout-protocol.md` §7: deduplication, baseline filter, final ids, severity review of every P0/P1 against the cited lines). Then, in both modes:

- **Pattern batching:** the same defect type across several documents is ONE finding listing every location (e.g. "Missing BDD scenarios for UC-003, UC-005, UC-007").
- **Family grouping:** these families are discovered and reported whole in a single pass, never incrementally across cycles — missing BDD (every UC has ≥ 1 happy + 1 error scenario); missing standard errors (every `Style: http` operation: 401/403/404/409/429 where applicable); terminology ("Do not use" terms over `spec/`); value inconsistencies (every registry/LIMITS/PERFORMANCE value over `spec/`); unformalized constraints (UC constraint language without INV id).
- **Cascade dependency:** when fixing X resolves Y, mark Y `[CASCADE-DEP: X]`; it is not tracked separately.

## Severity Classification

| Label | Criterion | Key question |
|---|---|---|
| **P0** (Critical) | Blocks implementation or causes undefined production behaviour | Does it block implementation? |
| **P1** (High) | Risk of significant bugs or a violated requirement | Does it cause bugs or violate a REQ? |
| **P2** (Medium) | Inconsistency that hinders maintenance or comprehension | Does it hinder understanding? |
| **P3** (Low) | Clarity or style improvement without functional impact | Is it only style? |

Reports, JSON and `pipeline-state.json` use P0–P3 (the `critical`/`high`/`medium`/`low` metric keys are unchanged).

### Signal Filters

Apply before assigning severity:

1. **Evidence:** a finding needs concrete evidence from two or more documents, or from the document plus the element that is missing from it (an absent section, error row, invariant or scenario). A single document read subjectively is not a finding.
2. **Caps:** CAT-08 at most P2; naming, capitalization and formatting findings at most P3; CAT-10 per its row above.
3. **Implementation-blocking test:** blocks implementation → P0 if behaviour in production is undefined, P1 if bugs are likely but a workaround exists; does not block → P2 if it hinders comprehension or maintenance, P3 if style only.

### Persistence Escalation Rule

| Persistence | Action |
|---|---|
| Found in 1 audit, not yet fixed | Severity unchanged |
| Open across 2 audits | Escalate one level (P3 → P2, P2 → P1), never above the finding's cap (Signal Filter 2) and never to P0 |
| Open across 3+ audits | The user assigns an explicit disposition (FIX, ACCEPT, DEFER, WONT_FIX); it cannot stay open |

## Audit Stability Rules

- **Rule 1 — Baseline:** excluded findings are exactly the Phase 0 exclusion set.
- **Rule 2 — Respect design decisions:** behaviour explained by an ADR in `adr/` or an RN in `CLARIFICATIONS.md` is a decision, not a defect.
- **Rule 3 — Minority rule for contradictions:** when N documents agree on a value and one differs, the defect is located in the divergent document — one finding, not N.

## Convergence Protocol

```
Cycle 1  DISCOVERY     full audit (Phases 0–7), all categories, all documents
         TRIAGE        user assigns dispositions
Cycle 2  FIX           Mode Fix on FIX findings
Cycle 3  VERIFICATION  narrow re-check of the fixes only
```

After Cycle 3, if P0 findings remain, ask the user: fix them and run one more verification pass, or accept the risk with a documented acknowledgment. **Hard limit: 5 cycles.** At the limit, open P2/P3 findings move to `Deferred`; open P1 findings stay open and are listed by id in the report header and `summary.highlights`, and the Gate is computed as usual (≤ 2 → CONDITIONAL PASS); open P0 findings need an explicit user disposition.

### Quality Gate

Counts are **open** findings: not resolved and not in the Phase 0 exclusion set (a user ACCEPT/DEFER/WONT_FIX moves a finding there). P3 never affects the Gate. Evaluate in order; the first match wins:

| Gate | Condition | Downstream (`sdd-test-planner`) |
|---|---|---|
| **FAIL** | P0 ≥ 1, or P1 > 2, or a 3C Completeness/Correctness FAIL, or a BLOCKED Upstream/Reconciliation gate (`references/mode-fix.md`) | Blocked — fix or accept first |
| **PASS** | P1 = 0 and P2 ≤ 5 | Proceeds |
| **CONDITIONAL PASS** | every other case (0 P0, ≤ 2 P1, any P2): list the open P1 ids; add an advisory when P2 > 10 | Proceeds with advisory |

The auditor recommends the Gate; the user decides whether to proceed. Downstream skills read it from `stages["spec-auditor"].summary.metrics.gate_result` (`PASS` | `CONDITIONAL` | `FAIL`).

### Verification Rules (Cycle 3)

Verify each fixed finding is resolved, check regressions in the documents the fixes modified and their immediate dependents (Propagation Checklist in `references/mode-fix.md`). Do not sweep unchanged documents, open new categories, or go deeper than Discovery. New findings: P0 → report and require a fix (extends verification by exactly that finding); P1 → report and add to the baseline for the next full audit; P2/P3 → advisory note, not counted. Output: the ≤ 6-line `Verification (cycle 3)` block of `report-template.md` §3; sequential, main thread.

### Triage

After Discovery and before Fix, present all findings to the user with their default disposition:

| Disposition | Meaning | Default for |
|---|---|---|
| `FIX` | Correct before proceeding | P0, P1, P2 (user may override P2) |
| `ACCEPT` | Known limitation, documented | — |
| `DEFER` | Address later (set a `Re-evaluate on` date) | — |
| `WONT_FIX` | By design in this context | — |

P3: user's choice. Only `FIX` findings go to Mode Fix; the others go to the Baseline tables.

## Audit Report

Read [references/report-template.md](references/report-template.md) before writing `audits/AUDIT-BASELINE.md` (sections, per-item caps, budget ≤ 25 k chars for ≤ 15 requirements, what the report must not contain). Record `wc -c` as `metrics.report_chars`.

### Quality Metrics

Computed and rendered as the last six rows of the `Gate detail` table:

| Metric | Formula | Target |
|---|---|---|
| Spec defect density | `(P0 + P1 findings) / total_documents` | < 2 per document |
| Traceability coverage | `reqs_with_spec / total_reqs × 100` (spec = UC, WF or operation) | 100% |
| Orphan rate | `orphan_specs / total_specs × 100` | 0% |
| Clarification density | `open NC/TBD markers / total_documents` | 0 before downstream |
| Audit pass rate | `docs with no P0/P1 / total_documents × 100` | > 90% |
| Cross-reference validity | `valid_refs / total_refs × 100` | 100% |

## Mode Fix (`--fix`)

When invoked with `--fix` (or asked to apply audit corrections), read [references/mode-fix.md](references/mode-fix.md) and follow it: corrections plan, execution with the Propagation Checklist, `docs(specs)` commits with `Change:` (the finding id) and `Refs:` trailers, baseline update, upstream impact analysis by tier (Step 4.5 decision, station path), post-audit traceability reconciliation. Mode Fix never writes `requirements/`.

## Integration with Pipeline

Third stage: after `sdd-specifications-engineer`; next stage `sdd-test-planner` (then `sdd-plan-architect`). Tier 1 upstream impact goes to `sdd-req-change`.

| Mode | Input | Output |
|------|-------|--------|
| Audit (default) | `spec/` + previous `audits/AUDIT-BASELINE.md` | `audits/AUDIT-BASELINE.md` (report + Baseline/History) |
| Fix (`--fix`) | `audits/AUDIT-BASELINE.md` + answers | corrected `spec/`, `audits/CORRECTIONS-PLAN-AUDIT-vX.X.md`, baseline update, upstream impact |
| Focused (`--focused`) | Change Report + affected `spec/` subset | `audits/AUDIT-FOCUSED-{CHG-ID}.md` |

### Invocation

```bash
/sdd-spec-auditor                                                    # Full audit (fan-out when spec/ > 8 files or > 40 k chars)
/sdd-spec-auditor --sequential                                       # Force one thread
/sdd-spec-auditor --fanout                                           # Force the four dimension auditors
/sdd-spec-auditor --fix                                              # Apply corrections from a triaged audit
/sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{CHG-ID}.md   # Audit only the changed documents (sdd-req-change cascade)
```

### Mode Focused

With `--focused --scope=<Change Report>`: audit only the documents in the report's "Documents Modified" section (others are read as context, not audited); check them against each other and their immediate neighbours in the traceability chain instead of a full Phase 1–6 sweep; run the 3C checks scoped to the change set; write `audits/AUDIT-FOCUSED-{CHG-ID}.md` (the `CHG-YYYY-MM-DD-NNN` id of the Change Report) with the compact template minus `Baseline` and `History`. Sequential unless the change set exceeds the fan-out threshold. Usually triggered by `sdd-req-change` Phase 9. P0/P1 findings → recommend a full audit.

## Persist Summary

After generating all output artifacts (Mode Audit or Mode Fix), update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["spec-auditor"].status` = `"done"`
3. Set `stages["spec-auditor"].lastRun` = current ISO-8601
4. Set `stages["spec-auditor"].summary`:
   - `artifacts`: list of files created/modified with labels (e.g., `{"file": "audits/AUDIT-BASELINE.md", "label": "Audit Baseline"}`)
   - `metrics`: `{ "total_findings": N, "critical": N, "high": N, "medium": N, "low": N, "batched_findings": N, "gate_result": "PASS"|"CONDITIONAL"|"FAIL", "audit_cycle": N, "topFindingCategories": ["CAT-06", "CAT-03", "CAT-07"], "report_chars": N, "mode": "fanout"|"sequential" }` (top 3 categories by frequency; `report_chars` = `wc -c audits/AUDIT-BASELINE.md`; `mode` = execution mode actually used, `fanout` even when one auditor had to be re-run sequentially — say so in `highlights`)
   - `highlights`: top 3-5 notable observations (e.g., "26 findings: 2 P0, 5 P1", "Gate: CONDITIONAL — 1 P1 open (CON-002)", "fanout: 4 auditors (sonnet), NFR re-run sequentially", "report 18.4 k chars")
   - `nextStep`: `"Run /sdd-test-planner"` (if gate PASS/CONDITIONAL) or `"Run /sdd-spec-auditor --fix"` (if gate FAIL)
   - `templateImprovements`: 1-3 recommendations for the spec engineer based on the most frequent finding categories (e.g., "UC template should require explicit error codes per step"). `sdd-specifications-engineer` reads them on its next run in this project (e.g. a re-run after a requirements change).
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Commit the files this run wrote: `git add audits/`, then `docs(audit): …` with `Refs:` the spec ids with P0/P1 findings (none → the audited REQ ids), skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed). Mode Fix already committed its corrections finding by finding; this commits the report and baseline.
7. Display summary table to user (console output)
8. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Write the report and respond in the user's language; ids, category codes and technical terms stay in English.
