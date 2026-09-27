# Specification Workflow Guide

## Overview

The phases from requirements intake to deliverables. Gap analysis and decision collection (Mode 1) follow `gap-analysis-checklist.md`; this guide covers what happens after.

## Phase 1–3: Intake, gap analysis, decisions

- **Locate requirements** in `requirements/` first; otherwise `docs/requirements/`, `reqs/`, any file with "requirement" in its name, the README.
- **Gap analysis:** `gap-analysis-checklist.md` Phases 1–2 (readiness per requirement, collection coverage). Ask only about the gaps the stated scope implies.
- **Decisions:** each issue goes to the user with the Decision Request Template of `gap-analysis-checklist.md` (SKILL.md § Asking the User: ≤ 4 questions per `AskUserQuestion`, severity order).
- **Decision log:** `spec/CLARIFICATIONS.md` (Template 16) **is** the log: one D-NNN row per format/structure decision, one RN-NNN row per business rule (source REQ, question, rule adopted, rejected options in one clause each, tier). No other log; the readiness report and every spec document cite the RN id.

---

## Phase 4: Specification Writing

### 4.0 Generation Order, Execution Mode and Budget

Follow SKILL.md § Generation Order (id ledger → shared domain homes → one pass per requirement writing UC + BDD together → cross-cutting files → grep-based gate) and § Output Budget (≤ 120k chars for ≤ 15 requirements). Write each file once; never re-read a written file except through `grep` in the gate.

Decide the execution mode before writing anything (SKILL.md § Execution Strategy, `fanout-protocol.md`): with more than 4 functional requirements the per-requirement pass runs in parallel lanes of 2-3 requirements each, plus one cross-cutting lane for `nfr/` and `adr/`, every id having been reserved in the ledger beforehand; at or below the threshold, or with `--sequential`, one thread does the same work in the same order. Decision collection always runs before the fan-out (SKILL.md Lane contract).

### 4.1 Specification technique

The default is the modular `spec/` tree with use cases + BDD scenarios (Templates 2 and 13). User stories (Template 3), actor-action statements (Template 4) or a monolithic SRS (Template 1) are used only when the user chooses them in Mode 2 step 3.

### 4.2 Specification Writing Rules

1. **One specification per atomic requirement** (or group of closely related requirements)
2. **Use active voice**: "The system shall..." not "It should be..."
3. **Be specific**: quantities, units, thresholds, formats
4. **Include all paths**: normal, alternative, exception
5. **Define preconditions and postconditions** for every behavior
6. **Specify error handling explicitly**: what happens when things fail
7. **Cross-reference related specifications** with IDs — and only with IDs: never copy a requirement statement, a rule text or a value into a second document (`document-templates.md` § 0, W1–W2)
8. **Include acceptance criteria** for every specification: at minimum one happy-path and one error scenario, written once in `tests/BDD-UC-NNN.md` (AC-NNN-NN ids defined there) and cited from the UC
9. **Empty means `None.`** — one line, no justification; optional sections are omitted (W4)
10. **Tables and schema blocks, not prose** — no section that restates a table; no "Notes", "Implementation notes" or "Rationale" paragraphs (W3, W6)
11. **Boilerplate once per file** — auth/rate limit/version, standard errors, actors (W7)
12. **Write each file once** — plan ids, invariants and exception rows before writing (W9)

### 4.3 Specification IDs

Use the ids of SKILL.md § Specification Folder Structure and the id ledger: `UC-NNN`, `WF-NNN`, `API-NNN-NN`, `INV-{AREA}-NNN`, `AC-NNN-NN`, `RN-NNN`, `ADR-NNN`, `NC-NNN`, and in `nfr/` the row ids of Template 7.

### 4.4 Specification Attributes

Each specification must include:

| Attribute | Required | Where / shape |
|-----------|----------|---------------|
| ID + Title | Yes | Heading (`UC-NNN — Name`) |
| Refs | Yes | One header row: REQ (+ WF, API, INV, RN, ADR, BDD ids). This is the traceability section |
| Priority | Yes | Header row, inherited from the requirement |
| Description | Yes | ≤ 2 sentences; never the requirement statement |
| Input / Output | Yes | One TypeScript/YAML block with constraints as VO/INV ids |
| Preconditions | Yes | Short list, ids for the rules |
| Postconditions | Yes | Success / failure, one bullet each |
| Main flow | Yes | Numbered `Actor: action` / `System: result`, ≤ 10 steps |
| Extensions | If applicable | One line each, AC id at the end |
| Exceptions & errors | Yes | One table: step, condition, code, HTTP/exit (HTTP only with `Style: http`, exit for a CLI), effect, AC id |
| Acceptance criteria | Yes | In `tests/BDD-UC-NNN.md` only; the UC cites AC ids |
| Open questions | If applicable | `NC-NNN` lines; section omitted when none |

---

## Phase 5: Specification Validation

### 5.1 Self-Validation Checklist

Before presenting specifications to the user:

- [ ] Every requirement has at least one specification
- [ ] Every specification traces to at least one requirement
- [ ] No orphan specifications exist
- [ ] All acceptance criteria are concrete and testable
- [ ] All error paths are specified
- [ ] Terminology is consistent throughout
- [ ] A developer could implement from this spec alone
- [ ] No ambiguous terms remain
- [ ] All decisions are documented in `spec/CLARIFICATIONS.md` (RN rows)
- [ ] The traceability matrix is complete
- [ ] `wc -c` over `spec/**/*.md` is within SKILL.md § Output Budget

### 5.2 Coverage Report

There is no separate coverage report: coverage is the last line of `spec/TRACEABILITY-MATRIX.md` (`Coverage: N/N requirements specified. Orphans: none.`) and the gate result is one console table (`check | result | fixed`).

---

## Phase 6: Deliverables

### 6.1 Required Deliverables

Templates and ceilings: `document-templates.md`, SKILL.md § Output Budget.

1. **spec/README.md** — Navigation table only (Template 18)
2. **spec/domain/01-GLOSSARY.md** — Terms, ≤ 20-word definitions, "Do not use" synonyms (Template 17)
3. **spec/domain/02-ENTITIES.md** — Entities as schema blocks + one relationships line (Template 17)
4. **spec/domain/03-VALUE-OBJECTS.md** — Value objects, enums, and the **error catalog** (the only home of code → message → class → HTTP/exit) (Template 17)
5. **spec/domain/04-STATES.md** — State machines as tables (Template 9)
6. **spec/domain/05-INVARIANTS.md** — One table row per invariant (Template 10)
7. **spec/use-cases/UC-NNN-{slug}.md** — One file per use case (Template 2)
8. **spec/workflows/WF-NNN-{slug}.md** — Multi-step processes spanning use cases (Template 11)
9. **spec/contracts/API-{module}.md** — One contract per module, one Errors table: `Style: operations` (Template 12b, default) or `Style: http` when a REQ demands an HTTP API for external clients (Template 12)
10. **spec/contracts/PERMISSIONS-MATRIX.md** — Role × operation grid; one row when there is a single role (Template 20)
11. **spec/tests/BDD-UC-NNN.md** — Scenarios per use case; defines the AC-NNN-NN ids (Template 13)
12. **spec/nfr/PERFORMANCE.md**, **LIMITS.md**, **SECURITY.md** — One table each; N/A categories are one row (Template 7)
13. **spec/CLARIFICATIONS.md** — D/RN decision tables; the only decisions log (Template 16)
14. **spec/CLARIFICATIONS-PENDING.md** — Open marker index, always present even if empty (SKILL.md)
15. **spec/VALUE-REGISTRY.md** — One table of canonical values (Template 14)
16. **spec/DERIVED-SPECS.md** — Tier 1/2 rows grouped by pattern (Template 15)
17. **spec/TRACEABILITY-MATRIX.md** — Forward table + coverage line (Template 5)

### 6.2 Conditional Deliverables (create only when the condition holds)

- **spec/contracts/EVENTS-{module}.md** — when the system emits domain/async events; otherwise a one-line absence declaration (Template 20)
- **spec/adr/ADR-NNN-{slug}.md** — one per decision actually taken during specification (Template 6)
- **spec/nfr/OBSERVABILITY.md**, **MAINTAINABILITY.md** — when a REQ-NF covers them
- **spec/runbooks/RB-NNN-{slug}.md** — only when a REQ/NFR requires an operational procedure or an ADR names a manual recovery (Template 19)
- **spec/tests/PROPERTY-TESTS.md** — when pure functions / invariants make property tests meaningful
- **spec/RESEARCH-QUESTIONS.md** — when open technical questions exist for `sdd-plan-architect`
