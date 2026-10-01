---
name: sdd-specifications-engineer
description: "Transforms requirements into formal specs (SRS) per SWEBOK v4: analyzes gaps and ambiguities first, builds the spec/ folder structure, proposes fixes to deficient requirements. Triggers: 'create specifications', 'write specs', 'requirements to specifications', 'SRS document', 'translate requirements', 'spec from requirements', 'especificaciones'."
---

# Specifications Engineer (SWEBOK v4)

Second stage of the SDD pipeline: turns `requirements/REQUIREMENTS.md` into the `spec/` tree that every downstream skill reads. Requirements are analysed and every open decision is settled with the user before anything is written; then the id ledger and the shared domain are written, the per-requirement pass runs (in parallel lanes above the threshold), and a grep-based gate validates the result.

**Journal.** When a run begins, tell the customer in one plain sentence what it is about to do: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage specifications-engineer --kind start --text "Vamos a describir con detalle cómo se comportará cada función"`. Persist adds the `done` line (plugin-root `references/status-page.md` §1).

## Asking the User

Decisions belong to the user; the skill never settles an ambiguity silently.

- **Interactive session:** `AskUserQuestion`, at most 4 questions per call, in severity order (BLOCKER → CRITICAL → MAJOR → MINOR), each with 2–4 options and the recommended one first. Only the main thread asks.
- **Station** (`SDD_ROLE` set, or a role resolved from `.claude/sdd-sessions.json`, and the role is not `sdd-lead`): follow the plugin-root `references/async-questions.md` — write each decision as a `Q-<role>-NNN [OPEN]` block, keep generating what does not depend on it (unresolved spots get an `NC` marker, Tier 1 items stay `[PENDING REQ]` in `DERIVED-SPECS.md`), and hand off `status=blocked` when nothing unblocked remains.
- **Non-interactive run with no role** (`claude -p` with nobody to answer): leave each open decision as an `NC` marker listed in `CLARIFICATIONS-PENDING.md`, Tier 1 items as `[PENDING REQ]`, continue, and list them in `summary.highlights`.

**Lane contract** (fan-out mode). A lane never asks the user, never decides an open question, never writes outside its own files (`spec/domain/`, `spec/contracts/`, `spec/workflows/` and `pipeline-state.json` are off limits), never runs Persist Summary or Handoff and never launches subagents. What it cannot settle it returns in its JSON: an ambiguity as an `NC-{L}NN` marker in `gaps`, a missing glossary term as `{"term","def"}` in `gaps`, uncovered behaviour in `tier1`, new invariants in `inv_new`, operations and error codes in `ops` / `errs`. The main thread raises all of it once, in phase D. Every decision a lane needs must therefore be taken in Mode 1 / phase A, before the lanes start.

## Modes of Operation

### Mode 1: Analyze Requirements for Specification Readiness

Use when the user provides requirements and wants to move toward specifications.

1. Read [references/gap-analysis-checklist.md](references/gap-analysis-checklist.md).
2. Locate and read all requirement documents.
3. For each requirement, evaluate readiness: unambiguous enough to specify, testable enough to derive acceptance criteria, atomic enough for one spec (else propose a decomposition), scope clear enough to set boundaries.
4. Identify gaps (stakeholder perspectives, error handling, security, nonfunctional constraints, boundaries, data lifecycle, integrations), ambiguities (inconsistent terms, vague qualifiers per the list in `../sdd-requirements-engineer/references/audit-checklist.md` §1.1, unstated assumptions, multiple interpretations) and conflicts.
5. Ask only about the gaps the stated scope implies — not every generic checklist item — batched as in § Asking the User. MINOR items may proceed with a documented assumption.
6. Record each decision once, as an RN row in `spec/CLARIFICATIONS.md` (Template 16).
7. Produce the **Specification Readiness Report** — one short table (console, or `requirements/READINESS-REPORT.md` only if the user asks for a file; ≤ 2,500 chars):

```
# Specification Readiness Report — YYYY-MM-DD
Requirements: N · ready: N · need clarification: N · need modification: N · missing: N

| # | Severity | REQ | Issue (≤ 15 words) | Options (recommended first) | Decision |
|---|---|---|---|---|---|
| 1 | Critical | REQ-F-003 | "done" on an already completed task? | A no-op, exit 0 · B error, exit 3 | A → RN-010 |

Gaps: [category → what is missing → recommendation], one line each.
```

The report cites the RN id; it does not repeat options or rationale.

### Mode 2: Create Specifications

Use when requirements are ready (after Mode 1, or the user says so).

1. Read [references/specification-workflow.md](references/specification-workflow.md), [references/document-templates.md](references/document-templates.md), [references/template-checklist-alignment.md](references/template-checklist-alignment.md), [references/fanout-protocol.md](references/fanout-protocol.md) (id ledger, lanes, consolidation) and [references/tier-classification.md](references/tier-classification.md).
2. **Previous audit feedback:** if `pipeline-state.json` has a `spec-auditor` summary with `topFindingCategories` or `templateImprovements` (left by an earlier audit of this project, e.g. before a re-run after a requirements change), apply extra scrutiny to those areas.
3. **Ask** (one `AskUserQuestion` call) the specification format — modular `spec/` tree with use cases (default, recommended), user stories + BDD, actor-action for contractual contexts, model-based, or a monolithic SRS (Template 1) — and structure preferences (naming, output directory) when they differ from the defaults.
4. Create the folders: `mkdir -p spec/{domain,use-cases,workflows,contracts,adr,tests,nfr}` (`runbooks/` only when required — § Output Economy rule 5).
5. **Decide the execution mode** before writing anything (§ Execution Strategy, `fanout-protocol.md` §1). Record the choice, and the reason for a downgrade, for Persist Summary.
6. Write the specifications following § Generation Order and § Output Economy. For each requirement — in the main thread in sequential mode, in its lane in fan-out mode:
   - Map it to its UC / WF / operation ids from the id ledger (`.sdd/spec-id-plan.md`); never invent an id that is not in it.
   - Apply Step 6a and Step 6b while drafting, before the file is written.
   - Write the UC and its `tests/BDD-UC-NNN.md` back to back (the BDD file defines the AC-NNN-NN ids the UC cites).
   - Traceability = the UC's `Refs` row + one row in `TRACEABILITY-MATRIX.md`.

   #### Step 6a: Error Flow Forcing Function

   For every step of a UC's main flow answer six questions while planning the UC; each "yes" becomes one row of the `Exceptions & errors` table (Template 2):

   | Question | If yes, create... |
   |---|---|
   | 1. What if this step fails (network, timeout, service down)? | Exception with a domain error code (+ HTTP status only with `Style: http`, exit code for a CLI) |
   | 2. What if the input is invalid or missing? | Exception with a validation code (e.g. `E_TITLE_EMPTY`) |
   | 3. What if authorization is denied? | Exception with an authorization code + the specific permission |
   | 4. What if there is a concurrent conflict? For a consumable resource (stock, seat, quota, balance, one-time code): who consumes it, and who reads it while it is being consumed? | Exception with a conflict code + its resolution (who wins, what the other actor sees) |
   | 5. What if a precondition held when checked but became false during execution? | Exception with race-condition handling |
   | 6. What if the same write runs again with the same input (retry, double click, re-sent message)? What is kept? | Row with condition `replay` and the outcome: the existing record returned unchanged, a domain code, or a second record by design |

   A "no" produces no text: no N/A cells, no forcing-function matrix in the document. Question 6 is the exception: every step that writes state gets its `replay` row, even when the answer is "a second record, by design", because a retried write is the outcome clients hit most and nobody specifies, and `sdd-spec-auditor` and `sdd-test-planner` check each write operation for that row.

   **Contract style** (per module, recorded in the id ledger): `Style: operations` by default (Template 12b — domain codes and user-visible outcomes; routes, verbs, statuses and form mechanics go to `design/OPERATION-MAPPING.md`); `Style: http` (Template 12) only when a REQ demands an HTTP API for external clients — cite it.

   Each exception row also yields, in the same pass: its error code in the error catalog (`domain/03-VALUE-OBJECTS.md`, the only place with message/class/HTTP-or-exit) and one row in the contract's single Errors table (a lane returns the code in `errs`, `new: true` when the catalog lacks it, and the main thread writes both in phase D); one scenario in `tests/BDD-UC-NNN.md` whose AC id the row cites. Exceptions shared by every UC (global error handler, storage failure) are described once — in the workflow or the contract — and cited.

   Classify each exception course by tier ([references/tier-classification.md](references/tier-classification.md)); most are Tier 2. A Tier 1 item is raised with the user (§ Asking the User) before `DERIVED-SPECS.md` is written.

   #### Step 6b: Invariant Extraction

   While drafting each UC, scan the requirement and the planned flow for constraint language — "must", "shall not", "always", "never", "at most", "at least", "between X and Y", "unique", "only if", "requires", "cannot exceed", "minimum", "maximum" (and their equivalents in the document's language):

   - If `domain/05-INVARIANTS.md` (written in phase B) already has it, cite that id.
   - If not, mint an `INV-{AREA}-{NNN}` id from the block the ledger reserved for this thread (main `…-0NN`, lane *L* `…-{L}NN`) as one Template 10 row. Sequential mode appends the row; a lane returns it in `inv_new`.
   - Cite the INV id inline in the UC step or postcondition (e.g. "(INV-TSK-003)"); never repeat the rule text.
   - Present the new invariants to the user for confirmation (in fan-out mode once, in phase D, over the consolidated list).
   - Classify by tier: formalises an existing REQ constraint → Tier 2; a new business rule → Tier 1; already existed → Tier 3.

   #### Step 6c: Register Derived Specifications

   Keep a running list of derived items; after the last UC, write `spec/DERIVED-SPECS.md` once (Template 15) — Tier 2 rows grouped by pattern, Tier 1 rows as `[PENDING REQ]`, and the > 3 Tier 1 alert of `tier-classification.md`. In fan-out mode the main thread writes it in phase D from the lanes' `derived` / `inv_new` / `tier1`.

   **Research questions:** a technical decision that needs evaluation of alternatives (encryption algorithm, database engine, REST vs GraphQL for a `Style: http` module) is recorded as an open question in `spec/RESEARCH-QUESTIONS.md` (context, specs it blocks, candidate options) instead of assumed. `sdd-plan-architect` Phase 3 (Research) consumes it.

7. Create `spec/TRACEABILITY-MATRIX.md` (Template 5) from the id ledger (plus the lanes' `ids_used` / `ids_ref`): forward table only (REQ → UC/WF, API, INV, ADR, BDD/PROP, NFR, RN), a ≤ 6-word summary instead of the requirement text, one coverage line. No reverse table and no per-acceptance-criterion table (scenario titles carry `[REQ-X ACn]`). Written from memory, without re-reading the generated files.
8. Decision points met while writing (competing design approaches, unclear granularity, variable acceptance criteria, ambiguous interface boundaries) are asked per § Asking the User — in fan-out mode they should already have been settled in Mode 1 / phase A.
9. Run the § Self-Validation Gate, then Persist Summary.

### Mode 3: Propose Requirements Modifications

Activates automatically when Mode 1 finds that more than 30 % of requirements have critical issues, missing requirements exceed 20 % of the existing count, requirements conflict fundamentally, or core functionality is underspecified.

1. Write a **Requirements Modification Proposal** (Template 8): one table of MOD/ADD/REM rows (REQ, issue, proposed text, one-clause rationale) and one impact line.
2. Present it and ask whether to proceed with specifications despite the issues (risks documented), go back to `sdd-requirements-engineer`, or address only the critical issues and proceed. Once `spec/` exists, requirement changes go through `sdd-req-change`.

### Mode 4: Validate Specifications

Use when the user has existing specification documents to review (full or partial `spec/` trees).

1. Read the specification documents and check them against `references/gap-analysis-checklist.md` Phase 3.
2. Verify each specification: acceptance criteria, traceability to a requirement, consistent terminology, implementation-ready, unambiguous.
3. Verify the collection: every requirement covered, no orphan specs or requirements, consistent format.
4. Produce a **Specification Validation Report** (console table: check · result · ids).

### Brownfield projects

Deriving specs from existing code is `sdd-reverse-engineer`'s job (and `sdd-pipeline-status --diagnose` picks the adoption path); `sdd-import` converts external documents. When one of them left a partial `spec/` tree (and `spec/COVERAGE.md`), run Mode 1/Mode 2 only for the requirements not yet specified and Mode 4 over the result. When `REQUIREMENTS.md` does not exist and there is no code, recommend `sdd-requirements-engineer` first.

---

## Specification Folder Structure

The canonical tree every downstream skill expects. The folder is always `spec/` (singular).

```
spec/
├── README.md                              # Navigation table only (Template 18)
├── domain/
│   ├── 01-GLOSSARY.md                     # Ubiquitous language (terms, definitions, "Do not use")
│   ├── 02-ENTITIES.md                     # Domain entities with attributes and relationships
│   ├── 03-VALUE-OBJECTS.md                # Value objects, enums, error catalog
│   ├── 04-STATES.md                       # State machines for all stateful entities
│   └── 05-INVARIANTS.md                   # Business rules as formal invariants (INV-{AREA}-NNN)
├── use-cases/
│   └── UC-NNN-{slug}.md                   # One file per use case
├── workflows/
│   └── WF-NNN-{slug}.md                   # Multi-step processes spanning use cases
├── contracts/
│   ├── API-{module}.md                    # Operation contract per module (Style: operations | http)
│   ├── EVENTS-{module}.md                 # Domain events (one-line absence declaration when none)
│   └── PERMISSIONS-MATRIX.md              # Role × operation grid (one row when single role)
├── adr/
│   └── ADR-NNN-{slug}.md                  # One per decision actually taken (Nygard short, Template 6)
├── tests/
│   ├── BDD-UC-NNN.md                      # BDD scenarios per use case — the only home of AC-NNN-NN
│   └── PROPERTY-TESTS.md                  # Property-based tests (when invariants make them meaningful)
├── nfr/
│   ├── PERFORMANCE.md · LIMITS.md · SECURITY.md
│   └── OBSERVABILITY.md · MAINTAINABILITY.md   # Only when a REQ-NF covers them
├── runbooks/                              # Only when a REQ/NFR/ADR requires an operational procedure
│   └── RB-NNN-{slug}.md
├── CLARIFICATIONS.md                      # Decisions log: D-NNN (format) and RN-NNN (business rules)
├── CLARIFICATIONS-PENDING.md              # Open [NEEDS CLARIFICATION] markers (always present)
├── VALUE-REGISTRY.md                      # Canonical shared values (timeouts, limits, enums)
├── DERIVED-SPECS.md                       # Tier 1/2 artifacts not directly traced to REQs
├── TRACEABILITY-MATRIX.md                 # REQ → artifacts, forward table only
└── RESEARCH-QUESTIONS.md                  # Open technical questions for sdd-plan-architect (only if any)
```

Rules:

1. `domain/01-GLOSSARY.md` … `05-INVARIANTS.md` are mandatory. Do not copy `REQUIREMENTS.md` into `spec/`; cite `../requirements/REQUIREMENTS.md`.
2. Use cases, workflows, ADRs and runbooks use sequential `NNN` numbering in file names.
3. One contract per bounded context/module. **Operation ids are `API-NNN-NN`**: `API-NNN` is the three-digit number the id ledger assigns to the contract module (e.g. `API-001` = module `tasks`, file `contracts/API-tasks.md`, declared in the contract's `Module` header row) and `NN` the operation within it. The dashboard, MCP `sdd_trace`, `sdd-gap-detector`, `sdd-test-planner` and the task files key on this shape.
4. `CLARIFICATIONS.md` at the root collects every user decision.

## Key Principles

- **Glossary-first writing.** `domain/01-GLOSSARY.md` is a controlled vocabulary: a new term goes into the glossary before it is used; synonyms in its "Do not use" column never appear elsewhere (checked by `grep -rniw` in the gate). The phase-B glossary covers all requirements so lanes rarely need a new term.
- **Value registry.** `spec/VALUE-REGISTRY.md` (Template 14) is written in phase B and lists every value used in more than one document (timeouts, limits, rate limits, enums, thresholds); other documents cite it by name (`TITLE_MAX_LENGTH`). Duplicated numbers are the main source of cross-document contradictions.
- **Traceability both ways.** Every spec traces to at least one requirement (or a `DERIVED-SPECS.md` row), every requirement has at least one spec; orphans are flagged.
- **Do not build on broken requirements.** When analysis shows deficient requirements, stop and resolve them (Mode 3) rather than specifying over them.
- **Implementation-ready, not verbose.** A developer new to the project can implement from the spec without further questions; detail means precise ids, values, schemas and error rows — not prose.

## Output Economy (Non-Redundancy)

Stage time is almost entirely output tokens: every duplicated fact is paid twice and later contradicts itself. Per-template shapes in `references/document-templates.md` § 0.

1. **One home per fact, ids everywhere else.** Requirement text stays in `requirements/REQUIREMENTS.md`; UCs, contracts, ADRs, BDD files and matrices cite `REQ-F-001` (+ at most one clause). Same for terms (glossary), values (`VALUE-REGISTRY.md`), error code → message → class → HTTP/exit (error catalog in `03-VALUE-OBJECTS.md`), rules (INV in `05-INVARIANTS.md`, RN in `CLARIFICATIONS.md`), scenarios (`tests/BDD-UC-NNN.md`) and decisions (ADR / CLARIFICATIONS — there is no other decisions log).
2. **Empty = `None.`** A mandatory section with nothing to say is the single line `None.`; an optional section is omitted. No "not applicable because…" paragraphs (the ADR id is the justification).
3. **Tables, not prose.** Never a table plus prose repeating it; a schema block instead of an attribute table; one `Refs` row per document instead of trailing traceability / rules / invariants lists; one `Exceptions & errors` table per UC.
4. **Boilerplate once per file.** Auth / rate limit / version once per contract; one Errors table per contract with an "Operations" column; no per-actor responsibility table in UCs.
5. **Runbooks, events and permissions only when the requirements ask for them.** Otherwise `runbooks/` does not exist and `EVENTS-*.md` / `PERMISSIONS-MATRIX.md` are a one-line absence declaration (Template 20).
6. **Write each file once.** Plan ids, invariants and exception rows first; never re-open a written file to add a cross-reference, and never re-read written files except through `grep` in the gate. The only exceptions are the four phase-D appends (new INV rows, new error-catalog rows, missing glossary terms, resolved RN rows) and targeted `Edit`s that fix a gate failure — both located with `grep -n`.

## Output Budget

Indicative ceilings in characters (`wc -c`). Exceeding one by more than 20 % means the document repeats something that already has an id: cut, do not reflow.

| Artifact | Max chars |
|---|---|
| `use-cases/UC-NNN` | 3,500 |
| `tests/BDD-UC-NNN` | 2,500 |
| `workflows/WF-NNN` | 4,000 |
| `contracts/API-{module}` | 6,000 |
| `adr/ADR-NNN` | 1,500 |
| `domain/` 01 GLOSSARY · 02 ENTITIES · 03 VALUE-OBJECTS · 04 STATES · 05 INVARIANTS | 4,000 · 4,000 · 5,000 · 3,500 · 6,000 |
| `nfr/*.md` (each) | 2,500 |
| `CLARIFICATIONS.md` | 6,000 (≤ 25 RN; +200 per extra RN) |
| `VALUE-REGISTRY.md` · `DERIVED-SPECS.md` · `TRACEABILITY-MATRIX.md` | 3,000 · 4,000 · 3,000 |
| `README.md` · `RESEARCH-QUESTIONS.md` · `tests/PROPERTY-TESTS.md` | 2,500 · 2,000 · 4,000 |
| `EVENTS-*.md` · `PERMISSIONS-MATRIX.md` when not applicable | 300 each |
| `runbooks/RB-NNN` (only when required) | 3,000 |

**Total: ≤ 120,000 chars for ≤ 15 requirements**, plus 5,000 per additional functional requirement. Measure at the end with `find spec -name '*.md' -print0 | xargs -0 wc -c | tail -1` and report it as `metrics.spec_chars`.

## Execution Strategy

Full protocol: [references/fanout-protocol.md](references/fanout-protocol.md) (mode table, lane sizing, ledger format, reservation rules, launch parameters, lane prompts, consolidation checks). The rules that govern every run:

1. **Fan-out above 4 functional requirements is part of this skill's contract.** Invoking the skill on such a set is the request for the requirement lanes; do not downgrade out of caution. Downgrade only for a reason in `fanout-protocol.md` §1 (≤ 4 functional REQs, `--sequential`, Modes 3/4, no `Agent` tool) and record it in `metrics.mode` and `summary.highlights`. `--fanout` forces lanes; `--sequential` forces one thread.
2. **Lanes:** R lanes of 2–3 functional requirements grouped by shared entity/module, writing only their `UC-NNN` + `BDD-UC-NNN` files, plus at most one X lane for `nfr/*`, `adr/` and `tests/PROPERTY-TESTS.md`; ≤ 4 agents at a time, never nested; each follows the Lane contract (§ Asking the User).
3. **The id ledger makes it safe:** every UC, AC range, `API-NNN-NN`, WF skeleton and ADR id is allocated in phase A; ids a lane mints carry its lane digit (`INV-{AREA}-{L}NN`, `NC-{L}NN`); lanes never mint `RN-NNN`.
4. **Cite by id, never open another lane's file.** The main thread never re-reads what the lanes wrote: consolidation, matrix and gate run on the returned JSON plus `grep` / `wc`.

## Generation Order

Shared context first, one pass per requirement, no re-reading of written files.

| Phase | Thread | Write (once) | Source |
|---|---|---|---|
| A. Plan | main | **Id ledger** → `.sdd/spec-id-plan.md` (outside `spec/`): REQ → UC ids + titles, AC ranges, WF ids with their numbered step skeleton, contract modules (`API-NNN` number, name, `Style`) and every `API-NNN-NN` operation id with its owner, INV areas, ADR ids, RN counter and, in fan-out mode, the lane table with each lane's reserved blocks and write set | `requirements/REQUIREMENTS.md` read once + Mode 1 decisions |
| B. Shared homes | main | `domain/01..05` (glossary, entities, value objects + error catalog, states, invariants for all requirements), `VALUE-REGISTRY.md`, `CLARIFICATIONS.md` (the RN rows decided in Mode 1, so lanes can cite them) | Ledger |
| C. Per requirement | lanes (or main, sequential) | For each UC: Step 6a in memory → `UC-NNN` then `BDD-UC-NNN`. Lane X: `nfr/*`, `adr/`, `PROPERTY-TESTS.md`. Operations, new invariants, derived items, gaps and Tier 1 items are returned as JSON (sequential mode keeps running lists) | Ledger + phase B on disk |
| D. Cross-cutting | main | `contracts/API-{module}` (Template 12b or 12), `WF-NNN` (skeleton + `wf` digests), `adr/`+`nfr/*` if there was no lane X, `DERIVED-SPECS.md`, `RESEARCH-QUESTIONS.md`, `TRACEABILITY-MATRIX.md`, `README.md`, `CLARIFICATIONS-PENDING.md`, `EVENTS-*` / `PERMISSIONS-MATRIX`. Raise the lanes' Tier 1 items, new invariants and gaps with the user. Sanctioned appends (rows only, one Edit each): INV rows, error-catalog rows, glossary terms, RN rows for resolved gaps | Lanes' JSON or running lists |
| E. Gate | main | § Self-Validation Gate with `grep` / `wc`; fix only what fails | `spec/` via grep, never `cat` |

## Needs Clarification Markers

When a decision cannot be obtained now (user unavailable, non-interactive run, a lane), embed a marker right after the ambiguous text instead of deciding:

```
<!-- [NEEDS CLARIFICATION] NC-NNN: {concise question} -->
```

- `NC-NNN` is three digits: the main thread uses `NC-0NN`; lane *L* uses only its reserved `NC-{L}NN` block.
- Insert one when a requirement is ambiguous and no decision was given this session, when a design choice has several valid readings and no ADR/RN covers it, or when an external dependency detail is unknown.
- Asking is preferred whenever someone can answer (§ Asking the User); a marker is the fallback.

`spec/CLARIFICATIONS-PENDING.md` is always written (downstream skills rely on it existing), with a `(No pending clarifications)` line when empty:

```markdown
# Pending Clarifications

| ID     | Document                        | Question                            | Inserted   | Resolved |
|--------|---------------------------------|-------------------------------------|------------|----------|
| NC-001 | use-cases/UC-005-upload-file.md | Max file size: 10MB or 25MB?        | YYYY-MM-DD | —        |
```

When a marker is resolved later: remove the comment, set `Resolved` to the date, and record the decision as an RN row in `CLARIFICATIONS.md`.

---

## Pipeline Integration

```
sdd-requirements-engineer   → requirements/REQUIREMENTS.md
sdd-specifications-engineer → spec/                       (THIS SKILL)
sdd-spec-auditor            → audits/AUDIT-BASELINE.md    (+ Mode Fix on spec/)
sdd-test-planner            → test/
sdd-plan-architect          → plan/
sdd-task-generator          → task/
sdd-task-implementer        → code/test paths from the SDD Stack Profile
```

**Input:** `requirements/REQUIREMENTS.md`. **Output:** the complete `spec/` tree. **Next step:** `sdd-spec-auditor`.

**Branch.** When `spec/` already exists on the default branch (a re-run after delivery), start a work branch before writing: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" branch start change {CHG-ID or date} specs` (branch rule in the plugin-root `references/git-conventions.md`).

## Self-Validation Gate

The last step of Mode 2, before Persist Summary. It runs on `grep` / `wc` output, not on re-reading the generated files.

### Step 0: Fan-out consolidation checks (fan-out mode only)

On the lanes' JSON and `ls` / `grep` (`fanout-protocol.md` §7): every promised file exists, is non-empty and within budget (a missing file → relaunch the lane once, then write it in the main thread); no id collisions (the definition-site `uniq -d` checks of §7.2 print nothing); no dangling references (union of `ids_ref` minus defined ids is empty); every minted id lies inside its lane's block.

### Step 1: Structural validation

- `grep -rhoE '(UC|WF|ADR|RN|NC)-[0-9]{3}|INV-[A-Z]+-[0-9]{3}|API-[0-9]{3}-[0-9]{2}|AC-[0-9]{3}-[0-9]{2}' spec | sort -u` — every id has a definition (file name, heading or table row); every REQ id of `REQUIREMENTS.md` appears in `TRACEABILITY-MATRIX.md` with at least one artifact.
- No orphan specifications (every file has a `Refs` row with a REQ, or a `DERIVED-SPECS.md` row).
- `grep -rniE 'TBD|TODO|FIXME' spec` is empty; no heading followed directly by another heading, except sections marked `[NEEDS CLARIFICATION]` that are listed in `CLARIFICATIONS-PENDING.md`.

### Step 2: Pre-flight defect scan

These mirror the most frequent `sdd-spec-auditor` findings (its `references/detection-patterns.md` has the grep patterns for CAT-01, CAT-04, CAT-06 and CAT-10):

1. **Glossary compliance:** zero occurrences of any "Do not use" synonym.
2. **Value consistency:** every `VALUE-REGISTRY.md` number, grepped over `spec/`, appears only with its registry name and the same value.
3. **BDD coverage:** every UC has `tests/BDD-UC-NNN.md` with at least one happy-path and one error scenario, and every AC id cited in the UC is defined there.
4. **Error flows:** every UC's `Exceptions & errors` table has at least one row.
5. **Invariant formalization:** constraint language in UC text without an INV reference is flagged.
6. **Cross-references:** every `UC-NNN`, `WF-NNN`, `INV-{AREA}-NNN`, `ADR-NNN`, `RN-NNN` resolves.
7. **Standard errors** (`Style: http` only): 401 for authenticated, 403 for role-restricted, 404 for by-id, 429 for rate-limited operations.
8. **Derived specs:** everything produced by Steps 6a–6b is in `DERIVED-SPECS.md` with its tier; more than 3 `[PENDING REQ]` → alert the user.
9. **Transport neutrality** (`Style: operations` modules): `grep -rnE '\| *(Method|Path|HTTP) *\||\b(GET|POST|PUT|PATCH|DELETE) +/|(status|HTTP) *[1-5][0-9]{2}|redirect' spec/contracts spec/use-cases spec/tests spec/workflows` shows no Method/Path/status columns, verbs, routes, statuses or redirects, except a URL a REQ mandates (quoted with its REQ id). Rewrite hits as operation semantics (auditor CAT-10).

### Step 3: Fix pre-flight findings

Fix them now, without asking (they are mechanical, self-inflicted defects), then re-run only the failed checks. A fix inside a lane's file is a targeted `Edit` located with `grep -n`, never a re-read or a relaunch.

### Step 4: Completion

Mode 2 is complete when structural checks pass, pre-flight checks pass (or the remainder is marked `[NEEDS CLARIFICATION]`), the traceability matrix is complete and the total size is within § Output Budget (or the excess is explained in one `highlights` line). Report the gate as one console table (`check | result | fixed`).

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["specifications-engineer"].status` = `"done"`
3. Set `stages["specifications-engineer"].lastRun` = current ISO-8601
4. Set `stages["specifications-engineer"].summary`:
   - `artifacts`: list of files created in `spec/` with labels (e.g., `{"file": "spec/use-cases/UC-001-create-task.md", "label": "Create task"}`)
   - `metrics`: `{ "use_cases": N, "workflows": N, "api_contracts": N, "bdd_scenarios": N, "invariants": N, "adrs": N, "spec_chars": N, "spec_budget_chars": N, "mode": "fanout" | "sequential", "spec_agents": N }` — `spec_chars` from the final `wc -c` over `spec/**/*.md` (or the sum of the lanes' reported `chars` plus the main thread's own files), `spec_budget_chars` from § Output Budget, `mode` and `spec_agents` from § Execution Strategy (`spec_agents` = lanes actually launched, 0 in sequential mode)
   - `highlights`: top 3-5 notable observations (e.g., "41 use cases across 8 domains", "spec/ 98k chars, within the 120k budget"). When `mode` is `sequential` above the threshold, the first highlight is the reason for the downgrade; open NC markers and `[PENDING REQ]` items are listed when present
   - `nextStep`: `"Run /sdd-spec-auditor"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Commit the files this run wrote: `git add spec/`, then `docs(specs): …` with `Refs:` the REQ ids covered and the main UC/API ids, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed). Before the commit, write the customer's journal line and stage it too (`git add status/journal.jsonl`): `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage specifications-engineer --kind done --text "Describimos 6 recorridos de uso y las reglas que cumplen"`, with this run's real numbers; after the commit, update the status page when `status/page.json` has a `url` (plugin-root `references/status-page.md` §1, §3), except in station mode (a role other than `sdd-lead`), where the station only writes the journal and the lead publishes.
7. Display summary table to user (console output)
8. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).

## Output Language

Write specs and respond in the user's language; technical terms, ids and EARS/Gherkin keywords stay in English.
