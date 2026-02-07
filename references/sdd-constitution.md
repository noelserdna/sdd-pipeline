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

**Principle:** Each task produces exactly one commit. The commit includes only the files listed in the task, uses the prescribed Conventional Commit message, and carries Refs/Task trailers. The system must remain functional after every commit.

**Rationale:** Atomic commits enable safe reverts, bisect debugging, and clear audit trails from code back to specs.

**Enforced by:** `sdd-task-implementer` (Phase 7 commit protocol), `sdd-task-generator` (defines commit messages and file scope per task).

## Article 8 — Test-First Construction

**Principle:** Tests are written before implementation. Each test derives from a spec acceptance criterion, invariant, or exception flow. Tests that pass without implementation are themselves defects.

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

---

## Glossary of Pipeline Terms

| Term | Scope | Definition |
|------|-------|------------|
| **FASE** | Macro-level | An implementation phase generated by `sdd-plan-architect`. Represents a bounded context or major module. Named FASE-0, FASE-1, ..., FASE-N. Each FASE maps to a git branch, a set of tasks, and a PR. |
| **Phase** | Micro-level | An internal step within a skill's execution workflow (e.g., Phase 0: Load Baseline, Phase 1: Detect Defects). Not related to FASEs. |
| **Stage** | Pipeline-level | A step in the SDD pipeline (e.g., requirements-engineer stage, spec-auditor stage). Tracked in `pipeline-state.json`. |

> **Disambiguation:** "FASE" always refers to implementation phases in `plan/fases/FASE-{N}.md`. "Phase" refers to internal skill execution steps. "Stage" refers to pipeline progression. Never interchange these terms.
