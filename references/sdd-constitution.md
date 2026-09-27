# SDD Constitution

> The governing principles of the Specification-Driven Development pipeline.
> Every SDD skill MUST comply with these articles. Violations are defects.

---

## Article 1 — Spec Is the Source of Truth

**Principle:** Specifications are the single authoritative description of system behavior. All downstream artifacts (plans, tasks, code, tests) are derived from specs and must conform to them.

**Rationale:** Without a single source of truth, contradictions propagate silently across the pipeline and surface as production defects.

**Enforced by:** all skills. `sdd-task-implementer` and `sdd-plan-architect` read specs but NEVER modify them. `sdd-spec-auditor` validates spec integrity.

## Article 2 — Never Assume, Always Ask

**Principle:** No skill may silently fill gaps, resolve ambiguities, or invent behavior. Every decision point must be presented to the user with structured options and a recommended default.

**Rationale:** Silent assumptions create invisible requirements that bypass traceability and review.

**Enforced by:** all skills. `sdd-specifications-engineer` asks per gap. `sdd-spec-auditor` flags unspecified behavior. `sdd-task-implementer` issues PAUSE on ambiguity.

## Article 3 — Traceability Is Non-Negotiable

**Principle:** Every artifact must trace to its origin: REQ <> UC <> WF <> API <> BDD <> INV <> ADR <> RN. Orphans in any direction are defects.

**Rationale:** Traceability enables impact analysis, change propagation, and audit. Without it, changes break the system silently.

**Enforced by:** `sdd-specifications-engineer` (REQ-to-spec matrix), `sdd-spec-auditor` (orphan detection), `sdd-req-change` (full-chain propagation), `sdd-task-implementer` (Refs trailers in commits).

## Article 4 — Upstream Immutability

**Principle:** A skill NEVER modifies artifacts owned by an upstream skill. Specs are read-only to plan-architect, task-generator, and task-implementer. Plans are read-only to task-generator and task-implementer.

**Rationale:** Uncontrolled upstream edits bypass audits, break traceability, and create feedback cycles that destabilize the pipeline.

**Enforced by:** `sdd-task-implementer` (never writes to spec/ or plan/), `sdd-plan-architect` (never writes to spec/), `sdd-task-generator` (never writes to spec/ or plan/). Spec corrections go through `sdd-spec-auditor` Mode Fix or `sdd-req-change`.

## Article 5 — Implementation-Ready Quality

**Principle:** Every specification must be detailed enough that a developer unfamiliar with the project can implement it without additional clarification. Vague qualifiers ("fast", "appropriate", "reasonable") are defects.

**Rationale:** Ambiguous specs force implementers to guess, creating implicit requirements outside the traceability chain.

**Enforced by:** `sdd-specifications-engineer` (implementation-ready check), `sdd-spec-auditor` (CAT-01 ambiguities, CAT-03 dangerous silences).

## Article 6 — Baseline Auditing

**Principle:** The first audit establishes a baseline. Subsequent audits report only new, persistent, or regression findings. Resolved and accepted findings are excluded. Design decisions documented in ADRs are not defects.

**Rationale:** Without baselines, audits produce noise that grows linearly with spec size, making the audit process unsustainable.

**Enforced by:** `sdd-spec-auditor` (Phase 0 baseline loading, Audit Stability Rules).

## Article 7 — One Task, One Atomic Commit

**Principle:** Each task produces exactly one commit. The commit includes only the files listed in the task — the backticked paths of the task line plus its `Files:` bullet — uses the prescribed Conventional Commit message, and carries Refs/Task trailers. A vertical slice may span several paths (e.g. migration, model, controller, view and their test) as long as all of them are listed. The system must remain functional after every commit, and every task declares how it reverts (SAFE/COUPLED/MIGRATION/CONFIG); in compact task format an absent Revert line means SAFE.

**Rationale:** Atomic commits enable safe reverts, bisect debugging, and clear audit trails from code back to specs.

**Enforced by:** `sdd-task-implementer` (Phase 7 commit protocol), `sdd-task-generator` (defines commit messages and file scope per task; V-19 task-line grammar checked by `scripts/sdd-task-lint.mjs`).

## Article 8 — Test-First Construction

**Principle:** Tests are written before implementation, inside the same task that implements the behavior, and are committed with it. Each test derives from a spec acceptance criterion, invariant, or exception flow. Tests that pass without implementation are themselves defects. A test-only task scheduled after the code it covers contradicts this article; separate test tasks exist only for cross-Stream suites, BDD/E2E journeys and justified Coverage Map exclusions.

**Rationale:** Test-first construction proves the spec is implementable and catches spec defects at the earliest possible moment (SWEBOK v4 Ch04 S4.16).

**Enforced by:** `sdd-task-implementer` (Phase 4 RED-GREEN-REFACTOR cycle).

## Article 9 — Structured Feedback Loops

**Principle:** When a downstream skill discovers a spec-level issue, it does not fix the spec. It records the issue in a structured feedback artifact (`feedback/IMPL-FEEDBACK-FASE-*.md`) and routes it to the appropriate upstream skill (`sdd-req-change` or `sdd-spec-auditor`).

**Rationale:** Separation of concerns between discovery and correction preserves pipeline integrity and audit trails (SWEBOK v4 Ch04 S4.17).

**Enforced by:** `sdd-task-implementer` (feedback protocol), `sdd-req-change` (processes feedback files), `sdd-spec-auditor` Mode Fix (applies audit corrections).

## Article 10 — Context-Aware Operation

**Principle:** Skills must read existing decisions (ADRs, CLARIFICATIONS.md, CLAUDE.md, baselines) before asking questions or making proposals. Redundant questions about already-decided matters are defects in skill behavior.

**Rationale:** Repeating settled decisions wastes user time and signals that the pipeline does not respect its own artifacts.

**Enforced by:** `sdd-plan-architect` (reads ADRs before clarification), `sdd-spec-auditor` (respects design decisions per Stability Rule 2), `sdd-req-change` (loads full inventory before analysis).

## Article 11 — Iterative Over Waterfall

**Principle:** If a skill detects that its input is deficient, it stops and recommends the appropriate upstream skill rather than producing low-quality output over a broken foundation.

**Rationale:** Garbage in, garbage out. Proceeding over deficient inputs multiplies defects downstream.

**Enforced by:** `sdd-specifications-engineer` (Mode 3 activates on deficient requirements), `sdd-task-implementer` (PAUSE protocol), `sdd-plan-architect` (readiness gates).

## Article 12 — Specification Primacy

**Principle:** Tests verify the specification, never the code. A failing test means the code is wrong: fix the code, and never adapt a test to code behavior that departs from the spec. A spec that looks impractical, contradictory or simply worse than an alternative is still implemented as written; the implementer records the disagreement as a `SPEC-DEVIATION` entry in `feedback/IMPL-FEEDBACK-FASE-{N}.md` (entry format: `skills/sdd-task-implementer/references/recovery-and-report.md` — `Spec`, `Deviation`, `Impact`, `Recommendation: AMEND | KEEP | NEEDS-DISCUSSION`, `Status: PENDING-REVIEW`). A human decides: **KEEP** closes the entry with no change; **AMEND** goes through `sdd-req-change`. The order is always human decision → req-change → spec → tests → code, never the reverse.

**Rationale:** Silently changing a spec, a test, or the implemented behavior to match "better" code is how specs drift from code until the code becomes the only documentation. Routing every amendment through a human and req-change keeps the spec authoritative and the change traceable.

**Enforced by:** `sdd-task-implementer` (implements the spec as written, writes SPEC-DEVIATION entries, fixes code not tests), `sdd-req-change` (processes SPEC-DEVIATION entries after the human decision and cascades spec → tests → code), `sdd-reconcile` (code never drives specs; unimplemented spec items are gaps, not deprecations).

---

## Glossary of Pipeline Terms

| Term | Scope | Definition |
|------|-------|------------|
| **FASE** | Macro-level | An implementation phase generated by `sdd-plan-architect`. Represents a bounded context or major module. Named FASE-0, FASE-1, ..., FASE-N. Each FASE maps to a git branch, a set of tasks, and a PR. |
| **Phase** | Micro-level | An internal step within a skill's execution workflow (e.g., Phase 0: Load Baseline, Phase 1: Detect Defects). Not related to FASEs. |
| **Stage** | Pipeline-level | A step in the SDD pipeline (e.g., requirements-engineer stage, spec-auditor stage). Tracked in `pipeline-state.json`. |

> **Disambiguation:** "FASE" always refers to implementation phases in `plan/fases/FASE-{N}.md`. "Phase" refers to internal skill execution steps. "Stage" refers to pipeline progression. Never interchange these terms.
