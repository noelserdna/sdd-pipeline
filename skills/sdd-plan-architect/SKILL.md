---
name: sdd-plan-architect
description: "Generates implementation plans from specs: FASEs, architecture, per-FASE plans, clarification of gaps. Uses design/ and ux/ if present. Outputs to plan/. Does NOT modify specs. Triggers: 'create plan', 'generate FASEs', 'implementation plan', 'architecture plan', 'plan from specs', 'generar plan', 'planificar implementacion', 'crear fases'."
---

# SDD Plan Architect Skill

> Specs are the source of truth (WHAT). A FASE is the order of work (WHEN). The plan is how it gets built (HOW).
> FASE files are derived navigation indices: they point at specs and can be regenerated from them.

Runs after `sdd-test-planner` (which runs after `sdd-spec-auditor`) and before `sdd-task-generator`. Reads `spec/`, `requirements/`, `audits/`, `test/`, and `design/` / `ux/` when present. Writes `plan/`, plus `design/OPERATION-MAPPING.md` only when it is missing and a contract needs it (Phase 4b). When the confirmed route skipped the specifications (`pipeline-state.json` → `stages["specifications-engineer"].status == "skipped"`, `docs/ruta.md`), it plans from `requirements/` alone: see Requirements-only mode under Phase 1.

**Journal.** When a run begins, tell the customer in one plain sentence what it is about to do: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage plan-architect --kind start --text "Vamos a dividir el trabajo en entregas que puedas ver y probar"`. Persist adds the `done` line (plugin-root `references/status-page.md` §1).

## Principles

1. **Ask only about genuine gaps.** Read ADRs, `CLAUDE.md` (incl. `## SDD Stack Profile`), `CLARIFICATIONS.md` and `design/` before asking; a question about something already decided wastes the user's time.
2. **Specs are read-only.** Derive the plan from what is specified; never invent behaviour or contradict an ADR. A spec gap goes to PLAN.md "Spec Gaps Detected" with a recommendation (`sdd-spec-auditor` Mode Fix or `sdd-req-change`), not into the plan.
3. **Incremental over regenerative.** Existing plan artifacts are the baseline: update affected sections, append a CLARIFY-LOG session, add a Document History entry. FASE files follow the same rule unless a `--regenerate-fases` flag says otherwise (Phase 1B).
4. **Traceable.** Every plan section cites its spec ids; every decision has an ADR, `D-PA-NNN` or `RES-NNN`; UC → plan section → FASE → component is checkable.
5. **Actionable and versionable.** Concrete decisions with their reference, interface sketches derived from contracts, ASCII diagrams only (no Mermaid/PlantUML/images — they need a renderer and do not diff).

## Reading Strategy (index first)

The plan needs ids, titles, dependencies, decisions and invariants — not the full text of every spec. Generation time is dominated by output; reading the corpus in full only adds cache and turns (`docs/perfilado.md`). Do not `cat` the whole `spec/` tree.

1. **Index** — one command in Phase 0:
   ```bash
   grep -rn -E '^#{1,3} |^\*\*(Status|Estado|Decision|Decisión|Depends|Dependencias|Actor|Actores|Style)|^- \*\*(Priority|Prioridad|Needs|Dependencies):|^ *Scenario: AC-|^\| *(UC|WF|INV|ADR|API|RN|REQ|SPEC|SEC)-[A-Z0-9-]+ *\|' spec/ requirements/ design/ ux/ audits/ test/ plan/ 2>/dev/null | cut -c1-160
   ```
   Every heading, every id-bearing table row, the status/decision/dependency/style lines, each requirement's priority, needs and dependencies, and each BDD scenario id, with `file:line`: enough for the manifest, the Vision Gate, the clarify scan and FASE assignment.
2. **Open by section** (`sed -n 'A,Bp' file`) only what a phase needs:

   | Phase | Open only |
   |-------|-----------|
   | 0 / 1B | ADR `## Decision` blocks; INV table (id + one line); UC header block (actor, primary entity, `Refs`/`Depends`); contract operation tables; `01-SYSTEM-CONTEXT.md`; `CLAUDE.md` Active Technologies |
   | 2.0 / 2 | the evidence line per category (`grep -n -i -E 'frontend|framework|database|auth|deploy' spec/adr/*.md design/*.md CLAUDE.md`) — not the files |
   | 4 | entity field tables (`02-ENTITIES.md`, `03-VALUE-OBJECTS.md`), contract sections, NFR target rows, `design/TECHNICAL-DESIGN.md` decision tables |
   | 5B | per FASE: the sections its FASE file lists, the contracts of that FASE, `test/TEST-PLAN.md` §3 / §7 / §9 rows and the §5 rows of its use cases |

3. Never open in full: `01-GLOSSARY.md`, runbooks, BDD files (scenario titles only), `CLARIFICATIONS.md` (grep the RN ids you cite), `test/E2E-SCENARIOS.md` and `test/TEST-MATRIX-*.md` (ids only).
4. If the `sdd_context` / `sdd_query` MCP tools are available (index built by `scripts/sdd-graph.py`), use them for id lookups instead of grep.

## Output Budget

Indicative for a ~10-requirement project (7 UC, 2-3 FASEs); scale with FASE/UC count, never with prose.

| File | Budget (chars) | What stays out |
|------|----------------|----------------|
| `ARCHITECTURE.md` | ≤ 10 000 | ADR content (cite `ADR-NNN`), restated contracts, a "Source Documents" inventory, views that only say "N/A" |
| `PLAN.md` | ≤ 12 000 | technology rows that repeat an ADR's rationale (aspect · decision · ADR id is enough), quickstart longer than 15 lines |
| `CLARIFY-LOG.md` | ≤ 6 000 with no question asked; + ≤ 1 200 per real question | option tables for questions nobody was asked; decisions an ADR already contains |
| `RESEARCH.md` | 5-row table when Phase 3 is skipped; ≤ 1 500 per real item | interface sketches (PLAN-FASE §4 owns them), empirical logs (one line with the result) |
| `fases/FASE-N-*.md` | ≤ 8 000, +2 000 per work Stream beyond the first (a FASE with A ∥ B carries two module blocks) | copied spec content, criteria longer than one line, demos or verification lists longer than 10 steps |
| `fases/README.md` | ≤ 4 000 | "how to use" / "principle" boilerplate |
| `fase-plans/PLAN-FASE-N.md` | ≤ 9 000, +4 000 per work Stream beyond the first | pseudo-code bodies, test assertions already in `test/`, restated FASE criteria |
| **Total `plan/`** | **≤ 34 000 + 17 000 per FASE + 4 000 per work Stream beyond the first in any FASE** (68 k for 2 FASEs, 89 k for 3 when one FASE has two Streams) | |

`design/OPERATION-MAPPING.md` (when written here) is outside the `plan/` total: one row per operation, no prose.

**Scope per FASE** (`references/phase-assignment-rules.md` R4, R8): at most 3 use cases, about 15 tasks, a demo of at most 10 steps. A FASE over these limits is two increments.

Report the total as `metrics.plan_chars` (`find plan -name '*.md' -print0 | xargs -0 wc -c`) and the ceiling as `metrics.plan_budget_chars` in Persist Summary; add a highlight when the total or any single file exceeds its budget by more than 15 %.

---

## Invocation Modes

| Invocation | Effect |
|------------|--------|
| `/sdd-plan-architect` | Global mode: every phase (0, 1, 1B, 2.0, 2, 2.9, 3, 4, 5, 6); 1B and 3 only when their conditions hold |
| `--fase {N}` | Only `plan/fase-plans/PLAN-FASE-{N}.md`. Runs 0, 1, 5B (scoped), 6 (scoped). Without `plan/PLAN.md`, warn, generate a standalone plan with inline context and recommend global mode |
| `--skip-clarify` | Skips Phase 2; uses the existing `plan/CLARIFY-LOG.md`. Decisions taken without asking are logged as table rows |
| `--regenerate-fases` | Rewrites every FASE file from specs (Phase 1B) |
| `--regenerate-fases --affected=1,5` | Cascade mode (invoked by `sdd-req-change` Phase 9): re-reads the changed specs, rewrites only the listed FASE files, then updates `PLAN.md` / `ARCHITECTURE.md` sections and the affected `PLAN-FASE-{N}.md` incrementally when boundaries, dependencies or referenced specs moved. Runs 0, 1B (scoped), 4b (new operations only), 5B (scoped), 6 (scoped) |
| `--audit-fases` | Read-only coverage check of existing FASE files: orphan specs, obsolete references, DAG validity (`references/coverage-report-template.md`) |
| `--research` | Forces Phase 3 even when every NEEDS_RESEARCH item is settled by evidence |
| `--research-only` | Only Phase 3; requires a CLARIFY-LOG.md with NEEDS_RESEARCH items |

---

## Process

### Phase 0: Inventory & Baseline

Build the spec manifest (ids, titles, dependencies, decisions, invariants) and load existing plan artifacts — from the index, not by reading every file.

1. **Index** — the Reading Strategy command. Keep its output as the working index for every later phase.
2. **Context lines** (open by section from the index):
   - `spec/00-OVERVIEW.md` / `01-SYSTEM-CONTEXT.md` → system statement, actors, bounded contexts (heading + first table)
   - `spec/CLARIFICATIONS.md` → RN ids + titles only (`grep -n -E '^#+ *RN-|^\| *RN-'`); open an RN only when you cite it
   - `CLAUDE.md` (all levels) → "Active Technologies" / constraints, `## Stack Conventions` and `## SDD Stack Profile` (stack, app_dir, paths, commands — `skills/sdd-task-implementer/references/stack-profile.md`); with a `stack` whose kit exists (`templates/stacks/{stack}/kit.json`), read its `layers` and `wiring`
   - `spec/domain/01-GLOSSARY.md` → term list, never the definitions
3. **ADRs** — per file: title, `Status`, the `## Decision` block (≤ 15 lines). Not Context / Alternatives / Consequences.
4. **Invariants and contracts** — `05-INVARIANTS.md` rows (id + one line); per `contracts/API-*.md` its `Style:` (`operations` | `http`) and operation ids with their section line; event names.
5. **Use cases** — per UC: title, primary actor, primary entity, `Refs` / `Depends` ids, exception-flow headings. The narrative flow is opened only in Phase 5B, for the FASE that owns the UC.
6. **FASE files** (if `plan/fases/` exists) → number, title, `Dependencias`, ids referenced (`grep -o -E '(UC|ADR|INV|WF|API)-[A-Z0-9-]+' | sort -u`).
7. **Technical design** (if `design/` exists) → decision tables of `TECHNICAL-DESIGN.md`, trade-off table of `QUALITY-ATTRIBUTES.md`, `ADR-DRAFT-*` titles + Decision lines, and the Mapping rows of `OPERATION-MAPPING.md`. They pre-resolve most clarify categories.
8. **UX design** (if `ux/` exists) → page list and component inventory of `WIREFRAMES.md`, token names of `UI-DESIGN-SYSTEM.md`, keyboard/ARIA tables of `ACCESSIBILITY-SPEC.md`, state names of `INTERACTION-MODEL.md`. Pre-resolves CL-UI.
9. **Security findings** (if `audits/SECURITY-AUDIT-BASELINE.md` exists) → finding id + severity + title rows → CL-SEC / CL-NFR in Phase 2.
10. **Test plan** (if `test/TEST-PLAN.md` exists) → §3 Design Decisions, §5 Targets by use case (the groups the FASEs are cut from), §9 Inputs for sdd-plan-architect (R-* rows). They constrain the plan (injection points, module boundaries, test locations).
11. **Baseline** (if `plan/` has artifacts) → headings + Document History of PLAN.md, ARCHITECTURE.md, CLARIFY-LOG.md, RESEARCH.md, PLAN-FASE-*.md; open a section only when updating it. If the spec version is newer than the plan's Document History, warn and run an incremental update.
12. **Manifest** (in memory, not written): per file its type, ids, decisions found and gaps found. For a 10-requirement project the context read in Phase 0 should stay under ~40 k chars.

### Phase 1: Spec Readiness Gate

| Gate | Check | If it fails |
|------|-------|-------------|
| G1: Specs exist | `spec/` has `domain/`, `use-cases/`, `contracts/` | `stages["specifications-engineer"].status == "skipped"` → Requirements-only mode, no stop. Otherwise STOP: "Run sdd-specifications-engineer" |
| G2: Audit gate | `pipeline-state.json` → `stages["spec-auditor"].summary.metrics.gate_result` ∈ {PASS, CONDITIONAL} | `stages["spec-auditor"].status == "skipped"` → n/a, no audit gate. Otherwise WARN: "Spec audit gate is {value or missing} — run sdd-spec-auditor (Mode Fix)"; continue with reduced confidence |
| G3: FASE files exist | `plan/fases/FASE-*.md` | AUTO: run Phase 1B |
| G4: Requirements exist | `requirements/REQUIREMENTS.md` | WARN: "Run sdd-requirements-engineer, recommended". In Requirements-only mode: STOP, since the requirements are the only source |
| G5: Security audit | `audits/SECURITY-AUDIT-BASELINE.md` | `stages["security-auditor"].status == "skipped"` → n/a. Otherwise WARN: "Run sdd-security-auditor, recommended" |
| G6: Test plan | `test/TEST-PLAN.md` | `stages["test-planner"].status == "skipped"` → n/a. Otherwise WARN: "Run sdd-test-planner first (it precedes planning)" |

Show a readiness table (gate · status · evidence) to the user; it is not persisted.

### Requirements-only mode (the route skipped the specifications)

The route judged that formal specs add little to this project (few functional requirements, one kind of user, no integrations, no sensitive data), so the requirements and their numbered acceptance criteria are the contract. The rest of the process still applies, with these substitutions:

- **Inventory** — `requirements/REQUIREMENTS.md` (every REQ with priority, needs, dependencies and its acceptance criteria, numbered AC1, AC2… in order) and `requirements/CUSTOMER-NEEDS.md` (needs, examples, out of scope); plus `CLAUDE.md`, `design/` and `ux/` when present. The Reading Strategy index already covers `requirements/`.
- **Journeys** — grouped by customer need, or by a cluster of requirements that a user sees working together, in place of use cases (`references/phase-assignment-rules.md` R3, R8). FASE-0 is the write → observe → persist path of the central requirement.
- **Scenarios** — `Escenarios` and each Demo step cite `REQ-X-NNN ACn` (`REQ-F-003 AC2`), and Criterios de Éxito end with the same ids; `sdd lint --plan` checks that the requirement has criterion n. "Specs a Leer" lists the `REQUIREMENTS.md` sections instead of spec files; "Invariantes Aplicables" lists the REQ-C constraints that apply, or says none; "Contratos Resultantes" are the operations the plan derives, each recorded as a `D-PA-NNN` decision.
- **Behaviour** — Principle 2 still holds: plan only what the requirements say. An ambiguity is asked in Phase 2 or goes to "Spec Gaps Detected" as a requirement gap recommending `sdd-req-change`.
- **Architecture** — `ARCHITECTURE.md` is still written, minimal: context, containers, components and data views drawn from the requirements, the Stack Profile and the Phase 2 decisions (`D-PA-NNN`, or `ADR-DRAFT-*` from `design/`). Phase 4b has no contracts to map.
- **Validation** — V2, V3, V4 and V7 are N/A (no `spec/adr`, `spec/nfr`, invariants or contracts): list them in the Validation Report with the status `N/A — specifications skipped by the route`. V1 reads "every requirement group of the FASE files has guidance in a plan"; V8 checks scenarios against the requirement criteria; V9 is unchanged. REQ-NF targets still get a strategy in PLAN.md §Cross-FASE.
- **Header** — PLAN.md and ARCHITECTURE.md carry `Inputs: requirements v{N} (specifications skipped by the route) · design/ {yes|no} · ux/ {yes|no}`.

### Phase 1B: FASE Generation

Generates the FASE files: vertical increments, each one a user journey the customer can watch working in a short demo. Runs when G3 finds no FASE files, or under `--regenerate-fases` (all, or only the `--affected` list). Otherwise existing FASE files are kept and updated incrementally: add references to new specs, drop obsolete ones, leave the rest untouched. An existing plan without `Plan-Style: vertical` keeps its FASEs; new FASEs go after the last verified one (rule R10).

Rules for every FASE file:
- **Vertical** — cut by user journey, never by technical layer: every FASE crosses the layers its journey needs.
- **Backed** — every FASE lists the requirements it completes (`Requisitos`), the scenarios it makes pass (`Escenarios`) and a `## Demo` whose steps cite them; every Must REQ-F/REQ-NF is in some FASE.
- **100 % coverage** — every spec file appears in at least one FASE file (Requirements-only mode: every active requirement).
- **Pointers, not copies** — reference specs by path + section; only "Contenido Específico" may hold formulas/diagrams that exist nowhere else.
- **DAG** — dependencies between phases have no cycles.
- **Ubiquitous language** — only terms from `domain/01-GLOSSARY.md` (Requirements-only mode: the terms of `REQUIREMENTS.md` and `CUSTOMER-NEEDS.md`).

Steps:

1. **Inventory** — every `.md` under `spec/` (excluding `temp_files/`, `CHANGELOG.md`) with its ids (UC, ADR, INV, WF, RN, API) and type; per REQ its priority, needs and dependencies; per UC its scenarios (`AC-NNN-NN`) and the REQ criteria they tag; the use-case groups of `test/TEST-PLAN.md` §5. In Requirements-only mode: per REQ its priority, needs, dependencies and numbered criteria, grouped by customer need.
2. **Assignment** — read `references/phase-assignment-rules.md` and apply R1-R10: the central use case's write → observe → persist path is FASE-0 (the walking skeleton), then one journey per FASE ordered by dependencies and MoSCoW, whole requirements, auth with the first exposed resource, HARDENING only for measured NFRs. When the Vision Gate finds a web/mobile/desktop channel, every FASE with user-facing UCs carries its UI deliverables (pages, routes, components — `references/fase-template.md` §7B). A spec with no FASE → ask the user.
3. **Dependency analysis** — build the graph and topologically sort it. A cycle → STOP and report it.
4. **Generate FASE files** with `references/fase-template.md` within budget: header (title, estado, `Incremento`, `Requisitos`, `Escenarios`, `Workflows` — the user-facing WF the journey walks, one video each at the gate —, `Necesidades`, dependencias); Objetivo; Criterios de Éxito (one line ≤ 140 chars each, grouped by use case, ending with the REQ/scenario ids verified); Specs a Leer (path · section/ids · purpose ≤ 100 chars, by type); Invariantes Aplicables (id + where enforced); **Módulos y Conjuntos de Escritura** (required: one row per block with its write-set — `sdd-task-generator` derives the work Streams from it, so parallel write-sets must be disjoint; a vertical FASE is usually one block); Contenido Específico (optional, ≤ 30 lines); Contratos Resultantes (operation ids + one-line signature; events); Entregables de UI (web/mobile: pages/routes → UC); Verificación (≤ 10 commands with the expected result as a comment); **Demo** (≤ 10 steps from a clean checkout, each citing its scenario and needs; seed data when needed; consumer calls for an API); Alcance (Incluye/Excluye).
5. **README** — `plan/fases/README.md` from `references/readme-template.md` (increments, requirement coverage, dependency graph).
6. **Verify** — every spec referenced, no obsolete references, valid DAG, template followed, write-set table present with pairwise-disjoint parallel write-sets, every file within budget, and `sdd lint --plan` clean (Phase 6, V8/V9).

Naming: `plan/fases/FASE-{N}-{SLUG}.md`; FASE-0 is `FASE-0-SKELETON.md`, a measured-NFR FASE `FASE-{N}-HARDENING.md`, the rest name their journey (`FASE-2-VEHICLES.md`). A domain file serving several FASEs is listed in each with a section qualifier (`| domain/02-ENTITIES.md | ENT-002 Vehicle | … |`). Transversal documents (GLOSSARY, EVENTS-*, error-code catalog, OVERVIEW, SYSTEM-CONTEXT, CLARIFICATIONS) are listed in FASE-0 and referenced by the rest.

### Phase 2.0: System Vision Gate

Runs before category questions; its questions are part of the same batches as Phase 2.

1. From the manifest, write a 3-5 line System Vision Statement: system type, primary users, expected scale, key constraint.
2. Classify five dimensions as **Covered** (decided in specs, ADRs, `design/TECHNICAL-DESIGN.md` or CLAUDE.md), **Implicit** (inferable) or **Missing**:

   | Dimension | Check | Source |
   |-----------|-------|--------|
   | Delivery Channels | web, mobile, CLI, API-only | UC actors, UI references, `ux/` |
   | Data Strategy | storage and management | entities, persistence specs |
   | Auth Model | authentication and authorization | security specs, roles |
   | Integration Points | external systems | contracts, workflows |
   | Quality Attributes | top 3 quality priorities | NFRs, invariants |

3. Each Missing dimension produces a mandatory question. With `design/TECHNICAL-DESIGN.md` most dimensions are Covered and this is quick.
4. The gate table (dimension · status · evidence) goes into the CLARIFY-LOG.md header.

### Phase 2: Clarify for Implementation

1. Scan the 13 categories of `references/clarify-taxonomy.md` (detection rules, context-aware checks, question templates, priority order). For each category search ADRs, CLARIFICATIONS.md, CLAUDE.md (Active Technologies, `## SDD Stack Profile`) and FASE-0; classify it **Resolved** (log the evidence, no question), **Partial** or **Missing**.
2. Build questions only for Partial / Missing categories, ordered by the taxonomy priority, each with a recommended option first, alternatives and the existing decisions that inform it.
3. **Ask in batches of at most 4 questions per call.** Keep asking while a gap blocks architecture or planning; stop when no blocking gap remains, when the user says "done"/"proceed"/"skip", or when every question is answered. There is no fixed total; Phase 2.9 checks the minimum coverage.
4. After each answer: log it in `plan/CLARIFY-LOG.md` under the current session; flag "Needs ADR" when the answer is an architecture decision and "NEEDS_RESEARCH" when it needs research.

**Log format (budget):** only a question actually presented gets a Q-block (question, options, answer, rationale, impact). Decisions the skill takes itself — under `--skip-clarify`, or because ADR/spec/design evidence settles them — go to the "Decisions Without a Question" table: id · category · decision (≤ 140 chars) · evidence · needs ADR. No options table for a question nobody was asked; no restating a decision an ADR already contains (cite it). Template: `references/plan-templates.md` §CLARIFY-LOG. When every category is Resolved, log the coverage table and go on to Phase 3/4.

### Phase 2.9: Coverage Gate

Re-check the five Vision Gate dimensions. For each unresolved one, ask a focused question with a strong recommendation; "skip" marks it Deferred with a warning.

- **PASS** — all five resolved → Phase 3/4.
- **PASS with warnings** — 1-2 deferred → continue, warning in CLARIFY-LOG.md.
- **BLOCK** — 3+ unresolved → recommend `sdd-tech-designer` first, or answer the remaining questions.

The result is embedded in CLARIFY-LOG.md.

### Phase 3: Technical Research

Runs when `--research` / `--research-only` was passed, or Phase 2 left NEEDS_RESEARCH items whose answer is not already determined by an ADR, the recommended option of `spec/RESEARCH-QUESTIONS.md`, `design/`, or `test/TEST-PLAN.md` §9. Otherwise skip it and write `plan/RESEARCH.md` as the "skipped" table of `references/plan-templates.md` (≤ 5 rows: item · category · decided by · decision · ref).

**Agents.** Launch two research agents in one message with the `Agent` tool; pass `model: sonnet` unless `CLAUDE_CODE_SUBAGENT_MODEL` is set (then omit `model`). Agents never write `pipeline-state.json`, never send handoff messages, never touch `spec/`.

| Agent | Owns | On overlap |
|-------|------|------------|
| TECH-agent | languages, frameworks, libraries, build tools, databases | wins on the specific library choice |
| PATTERN-agent | architecture styles, integration, data and deployment patterns | wins on the structural pattern |

Each agent's prompt: its NEEDS_RESEARCH items (from CLARIFY-LOG.md), the platform (CLAUDE.md / Stack Profile), the scale targets (`nfr/*.md` rows), and the existing decisions it must respect (ids + one line) — never the spec corpus. Output per item (≤ 1 500 chars, no code sketches):

```markdown
### RES-{NNN}: {Title}

**Category:** {CL-xxx} · **Question:** {original clarify question}

| Alternative | Pros | Cons | Fit (1-5) |
|------------|------|------|-----------|
| {option} | {≤ 80 chars} | {≤ 80 chars} | {score} |

**Selected:** {chosen} · **Rationale:** {one sentence} · **Trade-offs:** {one sentence} · **Refs:** {ids, URLs}
```

**Merge:** collect both results, resolve conflicting recommendations by platform fit, write one `plan/RESEARCH.md`, and for each decision that deserves an ADR add a skeleton (Context, Decision, Consequences — ≤ 3 lines each) flagged for the user to formalize in `spec/adr/`.

### Phase 4: Architecture Design

| View | Source | Template |
|------|--------|----------|
| C4 System Context (L1) | `01-SYSTEM-CONTEXT.md`, contracts, `design/TECHNICAL-DESIGN.md` | `references/architecture-patterns.md` §1.2 |
| C4 Container (L2) | ADRs (technology), CLAUDE.md, `design/TECHNICAL-DESIGN.md` | §1.3 |
| C4 Component (L3) | domain, use cases, contracts | §1.4 |
| Deployment | ADRs, NFR, FASE-0, `design/TECHNICAL-DESIGN.md` | §2 |
| Physical Data Model | `02-ENTITIES.md`, `03-VALUE-OBJECTS.md` | `references/plan-templates.md` §ARCHITECTURE |
| Integration Map | contracts, workflows | §3 |
| Security Architecture | `nfr/SECURITY.md`, security ADRs, `audits/SECURITY-AUDIT-BASELINE.md` | §3.1 |
| Quality Attributes | `design/QUALITY-ATTRIBUTES.md`, NFR | architecture-patterns.md |

For each view: extract the elements from the opened sections, apply CLARIFY-LOG / RESEARCH / design decisions, draw one ASCII diagram plus one element table, cross-check against ADRs. The physical data model maps entity and value-object tables to the chosen database, derives indexes from UC query patterns, and states the migration strategy in ≤ 5 lines.

**Compaction rules (≤ 10 000 chars):**
- A decision is written once: cite `ADR-NNN` / `D-PA-NNN` / `RES-NNN`; §1 is a decisions table with refs, not a summary of the ADRs.
- Each view = one ASCII diagram + one table whose rows carry ids (component · module · responsibility ≤ 80 chars · interface ids · FASE/block). No narrative under the diagram.
- A view exists only when the specs give it content: no external systems → one line instead of an Integration Map; no auth → one line instead of an Authentication Flow; an error-handling view only if an ADR defines the mapping, and then it cites the ADR.
- No "Source Documents" inventory: one header line `Inputs: spec v{X} · design/ {yes|no} · ux/ {yes|no} · audits/ {yes|no}`.

**Output:** `plan/ARCHITECTURE.md`

### Phase 4b: Operation Mapping

`sdd-tech-designer` is optional, but `sdd-task-generator`, `sdd-task-implementer` and `sdd-gap-detector` read the transport of `Style: operations` contracts from `design/OPERATION-MAPPING.md`. So:

- **File exists** → read it and do not rewrite it. If an `API-` operation of a `Style: operations` contract has no row (new operation after a change), append only the missing rows and record that in a highlight; never change existing rows.
- **File missing and at least one contract declares `Style: operations`** → write `design/OPERATION-MAPPING.md` with the template and column rules of `skills/sdd-tech-designer/references/output-templates.md` §OPERATION-MAPPING. Seed it from the installed stack kit (`templates/stacks/<kit>/conventions.md`), CLAUDE.md `## Stack Conventions` / `## SDD Stack Profile`, accepted ADRs and the CL-TECH / CL-UI decisions of this run; one row per operation; requirement-mandated transport rows cite their REQ; a divergence from the kit goes to *Deviations*. Add `· Written by: sdd-plan-architect` to its header line.
- **Only `Style: http` contracts (or no contracts)** → nothing to write; Method/Path come from the contract.

### Phase 5: Plan Generation

**5A: Master Plan (`plan/PLAN.md`)** — template in `references/plan-templates.md`. Its header carries `> **Plan-Style:** vertical` (`vertical (from FASE-N)` when extending a horizontal plan): `sdd-task-generator`, `sdd-task-implementer` and `sdd lint --plan` read it, and without it they treat the plan as horizontal.

1. **Technical Context** — decisions from ADRs (authoritative), CLARIFY-LOG.md, RESEARCH.md, CLAUDE.md (Active Technologies, `## SDD Stack Profile`); the executive summary carries the FASE map (FASE · Incremento · Requisitos · depends on).
2. **Component Decomposition** — one module per bounded context (`01-SYSTEM-CONTEXT.md`), shared components for cross-cutting concerns, ASCII module dependency graph.
3. **Cross-FASE Concerns** — auth flow, tenant isolation, error handling, observability.
4. **Risk Assessment** — risks from NFR targets, integrations and scale, with mitigations.
5. **Developer Quickstart** — prerequisites, setup, build/test/deploy commands (Stack Profile keys).
6. **Validation & Traceability** — UC → plan section → FASE → component; ADR → plan compliance; NFR → strategy; INV → enforcement.
7. **Spec Gaps Detected** — gaps found while planning, each with the recommended skill.

Budget ≤ 12 000 chars: technical-context rows are `aspect · decision · ADR id` (no rationale); cross-FASE concerns ≤ 5 lines each; quickstart ≤ 15 lines; traceability tables carry ids only.

**5B: Per-FASE Plans (`plan/fase-plans/PLAN-FASE-{N}.md`)** — for each FASE file:

1. From the FASE file: title, objective, dependencies, referenced ids.
2. Open the referenced sections to extract interfaces (contract signatures / operation tables), data changes (entity field tables), rules the contract does not state (ordering, error precedence, injection points — grep the RN/ADR ids), and the FASE's test ids (`test/TEST-PLAN.md` §5 rows of its use cases, §7, matrix and E2E ids).
3. Write the plan with the template: FASE-specific decisions; component sketches from contracts; API implementation notes (handler + what the contract and `design/OPERATION-MAPPING.md` row do not say); **UI deliverables** (required for FASEs with user-facing UCs on a web/mobile/desktop channel: each page maps to its UCs, cites `ux/WIREFRAMES.md` when present — `references/fase-template.md` §7B); data changes; test strategy; **Test Coverage Map** (source file → test file, each source classified `logic | entity | service | state-machine | infrastructure | page | component`, thin infrastructure excluded with a reason, priority HIGH for domain logic/state machines/services, MEDIUM for mappers/validators/pages, LOW for config/constants); dependencies on other FASEs; acceptance criteria (from UCs + INVs).

**Compaction rules (≤ 9 000 chars per FASE):**
- Component sections: contract-derived signatures (≤ 15 lines each) plus ≤ 5 notes on what the contract does not say. No function bodies, no pseudo-code — that is code generation.
- Test strategy §7.1-7.3: ids only (PROP / UNIT / INT / E2E / PERF from `test/`, grouped by level and block); assertions stay in `test/`. §7.4 Coverage Map is mandatory and keeps its format (consumed by `sdd-task-generator` V-13/V-14 and `sdd-task-implementer` CHECK-COV).
- Do not restate the FASE file's Criterios de Éxito or Specs a Leer; §2 lists spec ids with one implementation note each (≤ 100 chars).
- Data changes only when the FASE changes a schema; otherwise one line.
- File paths in §4 match the FASE's Módulos y Conjuntos de Escritura table and the Stack Profile's `code_paths` / `test_paths`.
- **Puertos con doble** (last §4 subsection, one row per port): every external integration of PLAN.md §2.3 that this FASE calls, and every mock, fake or stub of such a system named in the Setup column of §7.2, is a port with its interface, its double, its real provider and the observable both must produce. Tests that pass against a double say nothing about the real provider, so `sdd-task-generator` emits a `CONTRACT-<port>` task per row that runs the same assertions on both; a double without a row leaves that gap invisible. Only ports toward external systems (LLMs, payment, mail, third-party APIs) get a row; an in-memory repository standing in for the database does not, and its §7.2 Setup says `in-memory repository` rather than `mock`.

### Phase 6: Validation & Traceability

| Check | What | Against |
|-------|------|---------|
| V1: UC Coverage | every UC in FASE files has guidance in a plan | FASE files ↔ PLAN-FASE-*.md |
| V2: ADR Compliance | every ADR decision reflected in the architecture | `spec/adr/` ↔ ARCHITECTURE.md |
| V3: NFR Strategies | every NFR has a strategy | `spec/nfr/` ↔ PLAN.md §Cross-FASE |
| V4: INV Enforcement | every invariant has an enforcement mechanism | `05-INVARIANTS.md` ↔ PLAN.md |
| V5: FASE Completeness | every FASE has its plan file | `plan/fases/` ↔ `plan/fase-plans/` |
| V6: No Orphan Decisions | every CLARIFY-LOG decision is used | CLARIFY-LOG.md ↔ PLAN.md |
| V7: Operation Mapping | every operation of a `Style: operations` contract has a mapping row | `spec/contracts/` ↔ `design/OPERATION-MAPPING.md` |
| V8: Backed increments | every FASE header has `Requisitos` and `Escenarios`, its criteria cite REQ/scenario ids, and its `## Demo` has 1-10 steps each citing a scenario that exists in `spec/tests/BDD-*.md` | `plan/fases/` ↔ `spec/tests/` |
| V9: Must assigned | every active Must REQ-F/REQ-NF is on some FASE `Requisitos` line | `requirements/REQUIREMENTS.md` ↔ `plan/fases/` |

V8 and V9 are mechanical: run `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" lint --plan` and fix the lines it prints (it also warns about FASEs over 3 use cases or 15 tasks). Fix V1-V5 and V7-V9 gaps in the artifacts; flag V6 unused decisions. In Requirements-only mode V2-V4 and V7 are reported as N/A, not as gaps. Append the Validation Report (check · status · coverage · gaps, then `Plan validation: PASS|FAIL`) to the PLAN.md footer.

---

## Output Artifacts

```
plan/
├── fases/
│   ├── README.md              ← coverage matrices and dependency graph
│   ├── FASE-0-SKELETON.md     ← walking skeleton of the central use case
│   └── FASE-{N}-{SLUG}.md     ← one increment (user journey) each
├── PLAN.md
├── CLARIFY-LOG.md
├── RESEARCH.md                ← 5-row table when Phase 3 is skipped
├── ARCHITECTURE.md
└── fase-plans/
    └── PLAN-FASE-{N}.md       ← one per FASE file
design/
└── OPERATION-MAPPING.md       ← only when missing and a contract is Style: operations (Phase 4b)
```

Per-FASE mode writes only `plan/fase-plans/PLAN-FASE-{N}.md`; research-only mode only `plan/RESEARCH.md`.

## Constraints

- **Write scope:** `plan/**` and, under Phase 4b, `design/OPERATION-MAPPING.md`. Never `spec/`, `audits/`, `requirements/` or `test/`.
- **No code generation:** interface and SQL schema sketches derived from contracts and the domain model, ASCII diagrams and quickstart commands are fine; implementation bodies, runnable scripts and config files are not. Sketches are illustrative — the contracts stay authoritative.
- **Decision authority:** business rules belong to specs (CLARIFICATIONS.md), architecture decisions to ADRs, technology selection to CLAUDE.md + ADRs; the plan architect makes implementation choices (logged in CLARIFY-LOG.md) and flags anything architectural as "Needs ADR".
- **Language:** output follows the user's language; technical terms, identifiers and code stay in English.

## References

| Reference | Content |
|-----------|---------|
| `references/clarify-taxonomy.md` | 13 categories: detection rules, checks, question templates, priority |
| `references/plan-templates.md` | Templates for PLAN, ARCHITECTURE, CLARIFY-LOG, RESEARCH, PLAN-FASE |
| `references/architecture-patterns.md` | C4 guide, deployment patterns, common views |
| `references/fase-template.md` | Canonical FASE file structure |
| `references/phase-assignment-rules.md` | Vertical FASE rules R1-R10, conflict resolution, todo-app and web-app examples |
| `references/readme-template.md` | `plan/fases/README.md` template |
| `references/coverage-report-template.md` | `--audit-fases` report |
| `skills/sdd-tech-designer/references/output-templates.md` §OPERATION-MAPPING | Template for Phase 4b |

## Persist Summary

After writing the artifacts, update `pipeline-state.json` (create it with the default stage structure if absent):

1. `stages["plan-architect"].status` = `"done"`, `lastRun` = now (ISO-8601).
2. `stages["plan-architect"].summary`:
   - `artifacts`: files created or updated, with labels (e.g. `{"file": "plan/fases/FASE-1-CORE.md", "label": "FASE 1: Core"}`, `{"file": "design/OPERATION-MAPPING.md", "label": "Operation mapping"}` when written)
   - `metrics`: `{ "total_fases": N, "plan_style": "vertical", "demo_steps": N, "components": N, "adrs_created": N, "clarify_questions": N, "research_items": N, "plan_chars": N, "plan_budget_chars": N, "operation_mapping": "existing" | "written" | "appended" | "n/a" }`
   - `highlights`: 3-5 notable observations (e.g. "4 increments; skeleton = add + list + persistence", "FASE-1 at 11 000 chars, over budget", "OPERATION-MAPPING written: 12 operations")
   - `nextStep`: `"Run /sdd-task-generator"`
   - `generatedAt`: now
3. Write the file and show the summary table.
4. Commit the files this run wrote: `git add plan/` (plus `design/OPERATION-MAPPING.md` when written), then `docs(plan): …` with `Refs:` the FASE ids and the REQ ids they deliver, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed). Before the commit, write the customer's journal line and stage it too (`git add status/journal.jsonl`): `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage plan-architect --kind done --text "Planificamos 4 entregas; la primera te dejará crear y ver tareas"`, with this run's real numbers; after the commit, update the status page when `status/page.json` has a `url` (plugin-root `references/status-page.md` §1, §3).
5. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
