---
name: sdd-requirements-engineer
description: "Requirements: capture customer needs verbatim, write EARS requirements with reviewed examples, verification and priority, review and audit requirement quality (vague, untestable), approve with a git tag. Triggers: 'gather requirements', 'customer needs', 'review requirements', 'audit requirements', 'acceptance criteria', 'approve requirements', 'revisar requisitos', 'necesidades del cliente'."
---

# Requirements Engineer (SWEBOK v4)

Requirements engineering based on SWEBOK v4 Chapter 1. First stage of the SDD pipeline: its outputs, `requirements/CUSTOMER-NEEDS.md` and `requirements/REQUIREMENTS.md`, are the input of `sdd-specifications-engineer`.

**Journal.** When a run begins, tell the customer in one plain sentence what it is about to do: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage requirements-engineer --kind start --text "Vamos a escuchar lo que necesitas y anotarlo con tus palabras"`. Persist adds the `done` line (plugin-root `references/status-page.md` §1).

## Modes of Operation

Pick the mode from the user's intent.

### Mode 1: Elicit Requirements

Use when the user wants help gathering, discovering, or creating requirements. The order matters: needs first, in the customer's words, confirmed by the customer, and only then requirements, so that every requirement can be traced to something the customer actually asked for and nothing they asked for gets lost in translation.

1. Read [references/elicitation-guide.md](references/elicitation-guide.md) (stakeholder classes, 5-Whys) and ask about the project context: problem being solved, stakeholders, constraints.
2. **Capture needs verbatim** in `requirements/CUSTOMER-NEEDS.md` following [references/customer-needs-template.md](references/customer-needs-template.md): `N-NNN`, the exact quote, who, when, `Status: captured`.
3. **Read them back** to the customer (`AskUserQuestion`, one question per need, at most 4 per call) and mark each `confirmed`, reworded, or `out-of-scope` with the decision. Do not write requirements from unconfirmed needs. Then tell the journal, so the customer sees their requests on the status page: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage requirements-engineer --kind done --text "Anotamos tus 8 peticiones con tus palabras y las confirmaste una a una" --refs N-001 …`.
4. **Derive requirements** from the confirmed needs. Apply the 5-Whys where a need sounds like a solution, categorize each requirement (functional / nonfunctional / constraint), and write it with the template in [references/requirements-template.md](references/requirements-template.md): EARS statement, `Para el cliente:` (what it means for the customer in one or two plain sentences, template "Field rules"), `Needs:`, `Verification:`, priority, source, rationale and acceptance criteria with concrete data. When a criterion's outcome is something on screen, propose the `the user sees` / `el usuario ve` form of its THEN (template, "Visual criteria"); the customer confirms it at the examples review.
5. **Check coverage** mechanically: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-jev.mjs" needs requirements/CUSTOMER-NEEDS.md requirements/REQUIREMENTS.md --mechanical` must report 0 errors (orphan needs, requirements without needs, missing verification method). Then check that every promise of each statement has a criterion that exercises it ([references/approval.md](references/approval.md) §3, "Uncovered promises").
6. Write the document with `Status: Review`, then run the approval gate in [references/approval.md](references/approval.md): examples review, priority validation, optional UI walkthrough, explicit approval, commit and tag `requirements-v{Version}`. When `sdd-orchestrator` or `sdd-lead` drives the pipeline, or you run as a subagent, stop at `Review`: their gate 1 runs that procedure with the customer.

### Mode 2: Audit Requirements

Use when the user provides existing requirements for review.

1. Read [references/audit-checklist.md](references/audit-checklist.md).
2. Evaluate each requirement against the individual checklist and the whole set against the collection checklist. With many requirements, screen them first when Jev is enabled (opt-in, sends the statements to TypeSafe): `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-jev.mjs" req-lint requirements/REQUIREMENTS.md --out .sdd/jev/req-lint.json` flags vague, compound, unverifiable and implementation-leaking statements and non-EARS patterns (probability > 0.5), and `uncovered`: a promise of the statement that no acceptance criterion checks (p ≥ 0.85; handling in [references/approval.md](references/approval.md) §3). Read the flagged ones first; the flags are hints, so still confirm each one and apply the checklist to the rest. Exit code 3 means Jev is off: review every requirement yourself.
3. When `requirements/CUSTOMER-NEEDS.md` exists, run the `needs --mechanical` check of Mode 1 step 5 and report its errors and warnings; without it, report the missing needs traceability as a gap.
4. Produce the audit report (template in the checklist) with FAIL / WARN / PASS per issue, a concrete recommendation and, when possible, a rewritten statement.
5. Identify gaps: missing stakeholder perspectives, uncovered edge cases, absent security or error handling.

The audit report is the deliverable. Write or update `requirements/REQUIREMENTS.md` only when the user accepts the rewrites.

### Mode 3: Specify/Format Requirements

Use when the user wants requirements written in a specific format or converted between formats.

In `REQUIREMENTS.md` the **Statement** of every REQ-F / REQ-NF is always EARS (below), because downstream skills parse it. Other formats are additional views, produced on request (in the reply or as an extra section), never a replacement for the EARS statement:

- **User Story**: `As a [role] I want [capability] so that [benefit]` — feature-level, agile teams; always with BDD acceptance criteria.
- **BDD Scenario**: `Given [context], when [stimulus], then [outcome]` — cover normal, alternative and exception paths.
- **Use Case**: triggering event, parameters, preconditions, postconditions, normal/alternative courses, exceptions — complex interactions.
- **Actor-Action**: `[Triggering event], [Actor] shall [Action] [Condition]` — contractual documents.
- **Shall Statement**: `The system shall [behavior]` — traditional SRS, regulatory contexts.

## Key Principles

- **Perfect Technology Filter**: a requirement that would still exist with infinitely fast, free, failure-free computing is functional; everything else is nonfunctional.
- **Quality gates**: every requirement is unambiguous, testable, atomic, binding and stakeholder-aligned; flag and fix the ones that are not. The vague-term list lives in `references/audit-checklist.md` §1.1.
- **Quality-of-service economics**: for each QoS target, identify the perfection point (better brings no value) and the fail point (worse makes the product unusable).
- **Prioritization (Kano-aware)**: weigh both the satisfaction from having a feature and the dissatisfaction from lacking it; a missing basic feature hurts more than a missing delighter. Scale: Must have / Should have / Nice to have. More than 60 % Must means priorities no longer discriminate; the customer confirms the Must list explicitly (approval step 4).
- **Specification by example**: every acceptance criterion carries at least one example with real data, and the customer reviews the examples; a concrete example exposes a misunderstanding that an abstract criterion hides.
- **Verification method**: each requirement states how its acceptance will be proven (`test | demo | measurement | inspection`), decided now with the customer rather than discovered at the end.

## EARS Syntax

The statement format of the SDD pipeline (`sdd-specifications-engineer`, `sdd-spec-auditor` and later skills read it):

| Pattern | Template | Example |
|---------|----------|---------|
| Ubiquitous | `THE <system> SHALL <behavior>` | THE system SHALL store all data encrypted at rest |
| Event-driven | `WHEN <trigger> THE <system> SHALL <behavior>` | WHEN a user submits login credentials THE system SHALL validate them within 2 seconds |
| State-driven | `WHILE <state> THE <system> SHALL <behavior>` | WHILE the system is in maintenance mode THE system SHALL reject all write operations |
| Unwanted | `IF <condition> THEN THE <system> SHALL <behavior>` | IF the database connection fails THEN THE system SHALL retry 3 times with exponential backoff |
| Optional | `WHERE <feature> THE <system> SHALL <behavior>` | WHERE multi-tenancy is enabled THE system SHALL isolate tenant data |
| Complex | `WHILE <state> WHEN <trigger> THE <system> SHALL <behavior>` | WHILE authenticated WHEN session expires THE system SHALL redirect to login |

## Output Artifacts

Mode 1 writes both files; Mode 3 updates `REQUIREMENTS.md`; Mode 2 writes only after the user accepts rewrites.

- `requirements/CUSTOMER-NEEDS.md` — template and rules in [references/customer-needs-template.md](references/customer-needs-template.md).
- `requirements/REQUIREMENTS.md` — template and field rules in [references/requirements-template.md](references/requirements-template.md). Read it before writing; downstream skills and scripts parse its labels.

### Rules for Output

1. IDs: `REQ-F-NNN` (functional), `REQ-NF-NNN` (nonfunctional), `REQ-C-NNN` (constraint), unique across the document.
2. Every requirement (REQ-F, REQ-NF and REQ-C) has a `Para el cliente:` line in plain words, because the customer approves and later follows the project through those sentences, not through EARS. Every REQ-F and REQ-NF has an EARS statement, BDD acceptance criteria (Given/When/Then) with concrete data, `Needs:` citing at least one need, and `Verification:`. Constraints (REQ-C) are plain statements with Type, Source and `Verification:` (`test` when code can check it, `inspection` for process, legal or organisational constraints); `Needs: —` is allowed when the source is the team or the architecture.
3. No vague terms; every quality metric is quantified, and a `measurement` requirement states metric, threshold and how it is measured.
4. Every need is covered by some requirement or `out-of-scope` with its decision; the Traceability table lists every requirement with its needs and verification method.
5. **Re-runs keep IDs stable.** Never renumber or reuse an ID; new requirements take the next free number, removed ones are marked deprecated rather than deleted, because specs, tests and commits reference them. After approval (tag `requirements-v{Version}`), changes go through `sdd-req-change` (it classifies the change, cascades staleness and leads to a new approval and tag) instead of re-running this skill.

**Next step:** once approved, tell the user: "Requirements approved (tag `requirements-v{Version}`). Next step: run `sdd-specifications-engineer` to transform them into formal specifications." If the gate is still pending, say what is missing instead.

## Persist Summary

After writing `requirements/REQUIREMENTS.md` (an audit-only Mode 2 run leaves the state untouched), update `pipeline-state.json`. `metrics.approved_tag` stays `null` until the approval gate creates the tag; the gate (here or in the orchestrator) then sets it and `nextStep`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["requirements-engineer"].status` = `"done"`
3. Set `stages["requirements-engineer"].lastRun` = current ISO-8601
4. Set `stages["requirements-engineer"].summary`:
   - `artifacts`: list of files created/modified with labels (e.g., `{"file": "requirements/REQUIREMENTS.md", "label": "Requirements Document"}`, `{"file": "requirements/CUSTOMER-NEEDS.md", "label": "Customer Needs"}`)
   - `metrics`: `{ "total_requirements": N, "functional": N, "nonfunctional": N, "constraints": N, "needs": N, "needs_out_of_scope": N, "must_ratio": 0.NN, "approved_tag": "requirements-v1.0" | null }`
   - `highlights`: top 3-5 notable observations (e.g., "85 requirements across 6 domains", "12 security requirements identified")
   - `nextStep`: `"Run /sdd-specifications-engineer"` once approved, otherwise `"Approve requirements (gate 1)"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Commit what this run wrote, draft included, because specs and commits cite these REQ ids: `git add requirements/` and `docs(requirements): draft requirements v{Version}` with `Refs:` every REQ id, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed). Before the commit, write the customer's journal line and stage it too (`git add status/journal.jsonl`): `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage requirements-engineer --kind done --text "Convertimos tus 8 peticiones en 14 requisitos con ejemplos, listos para que los revises"`, with this run's real numbers; after the commit, update the status page when `status/page.json` has a `url` (plugin-root `references/status-page.md` §1, §3). The approval gate later commits the `Approved` header and tags.
7. Display summary table to user (console output)
8. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Respond and write artifacts in the user's language; technical terms (EARS keywords, IDs) stay in English.
