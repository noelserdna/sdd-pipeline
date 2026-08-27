---
name: sdd-plan-architect
description: "Generates implementation plans from specs: FASEs, architecture, per-FASE plans, clarification of gaps. Uses design/ and ux/ if present. Outputs to plan/. Does NOT modify specs. Triggers: 'create plan', 'generate FASEs', 'implementation plan', 'architecture plan', 'plan from specs', 'generar plan', 'planificar implementacion', 'crear fases'."
---

# SDD Plan Architect Skill

> **Principio:** El plan de implementación es un artefacto derivado de las especificaciones.
> Specs = fuente de verdad (QUÉ). FASE = orden de trabajo (CUÁNDO). Plan = cómo se construye (CÓMO).
> FASE files son índices de navegación derivados — regenerables desde specs.

## Purpose

Generar planes de implementación accionables a partir de especificaciones técnicas existentes, incluyendo:

1. **Clarificación interactiva** de gaps de implementación (decisiones no tomadas)
2. **Investigación técnica** de alternativas para decisiones pendientes
3. **Diseño de arquitectura** con vistas C4, deployment, data model
4. **Planes por FASE** con detalles de componentes, APIs, tests, y datos

## When to Use This Skill

Use this skill when:
- Specs are complete and audit-clean, ready for implementation
- The `plan/` directory is empty or outdated
- Starting a new implementation phase and need a blueprint
- Onboarding developers who need to understand HOW to build the system
- Technology decisions need to be formalized before coding begins
- After spec changes that invalidate previous plan artifacts

## When NOT to Use This Skill

- To create specs → use `sdd-specifications-engineer`
- To audit specs for defects → use `sdd-spec-auditor`
- To fix spec defects → use `sdd-spec-auditor` (Mode Fix)
- To derive requirements → use `sdd-requirements-engineer`
- To generate implementation code → this skill does NOT generate code
- To audit security posture → use `sdd-security-auditor`

## Relationship to Other Skills

| Skill | Phase | Relationship |
|-------|-------|-------------|
| `sdd-specifications-engineer` | Creation | **Prerequisite**: specs must exist |
| `sdd-spec-auditor` | Quality | **Prerequisite**: specs should be audit-clean |
| `sdd-security-auditor` | Security | **Recommended**: security audit before planning |
| **`sdd-plan-architect`** | **Phases + Planning** | **THIS SKILL**: generates FASE files + plan/ artifacts |
| `sdd-task-generator` | Tasks | **Downstream**: generates task/ from plan + FASE |
| `sdd-task-implementer` | Implementation | **Downstream**: implements code from tasks |
| `sdd-tech-designer` | Technical Design | **Optional input**: reads `design/TECHNICAL-DESIGN.md` if exists |
| `sdd-ux-designer` | UX Design | **Optional input**: reads `ux/UI-DESIGN-SYSTEM.md` if exists |
| `sdd-requirements-engineer` | Requirements | **Lateral/Opcional**: retrofit para derivar REQs cuando se empezó por specs |
| `sdd-req-change` | Changes | **Lateral/Opcional**: gestionar cambios de requisitos post-facto |

### Pipeline Position

```
Requisitos → sdd-specifications-engineer → sdd-spec-auditor (fix) →
                                                        ↓
                                          sdd-plan-architect ← YOU ARE HERE
                                          (generates FASEs + plans)
                                                        ↓
                                               sdd-task-generator
                                                        ↓
                                               sdd-task-implementer

Herramientas laterales (opcionales):
  sdd-tech-designer     ← diseño técnico profundo (design/ consumido si existe)
  sdd-ux-designer       ← diseño UI/UX profundo (ux/ consumido si existe)
  sdd-requirements-engineer        ← retrofit: derivar REQs cuando se empezó por specs
  sdd-req-change        ← gestionar cambios de requisitos post-facto
  sdd-security-auditor  ← auditoría de seguridad complementaria
```

---

## Core Principles

### 1. Context-Aware Clarification

```
❌ "¿Qué lenguaje usarán?" (cuando ADR-001 ya lo define)
❌ "¿Qué base de datos?" (cuando CLAUDE.md ya lista D1)
❌ Preguntar sobre algo ya decidido en specs

✅ Leer ADRs, CLAUDE.md, CLARIFICATIONS.md ANTES de generar preguntas
✅ Solo preguntar sobre gaps genuinos de implementación
✅ Marcar categorías resueltas y mostrar evidencia
```

### 2. Specs as Single Source of Truth

```
❌ Inventar comportamiento no especificado
❌ Modificar archivos en spec/
❌ Contradecir decisiones existentes en ADRs

✅ Derivar plan de lo que ESTÁ especificado
✅ Solo escribir en plan/
✅ Flaggear si el plan necesita una spec nueva/modificada
```

### 3. Incremental Over Regenerative

```
❌ Borrar plan/ completo y regenerar
❌ Ignorar CLARIFY-LOG.md de sesiones anteriores

✅ Cargar artefactos existentes como baseline
✅ Actualizar secciones afectadas por cambios
✅ Preservar decisiones de clarify sessions anteriores
```

### 4. Traceability End-to-End

```
❌ Plan sin referencias a specs
❌ Decisiones sin rationale
❌ Componentes sin mapping a UCs

✅ Cada sección del plan referencia spec source
✅ Cada decisión tiene ADR o CLARIFY-LOG entry
✅ Traceability matrix: UC → Plan Section → FASE → Component
```

### 5. Actionable Output

```
❌ "Considerar usar caching" (vago)
❌ "Implementar según best practices" (genérico)
❌ Diagramas que no se pueden version-control

✅ "Usar Cloudflare KV para rate limiting (ADR-025)" (concreto)
✅ Interface sketches derivados de contracts
✅ ASCII diagrams en markdown (versionable)
```

---

## Reading Strategy (index first)

The plan needs ids, titles, dependencies, decisions and invariants — not the full text of every spec. Generation time is dominated by output; reading the corpus in full only adds cache and turns (`docs/perfilado.md`). Never `cat` the whole `spec/` tree.

1. **Index** — one command in Phase 0:
   ```bash
   grep -rn -E '^#{1,3} |^\*\*(Status|Estado|Decision|Decisión|Depends|Dependencias|Actor|Actores)|^\| *(UC|WF|INV|ADR|API|RN|REQ|SPEC|SEC)-[A-Z0-9-]+ *\|' spec/ requirements/ design/ ux/ audits/ test/ plan/ 2>/dev/null | cut -c1-160
   ```
   Every heading, every id-bearing table row and the status/decision/dependency lines, with `file:line`: enough for the manifest, the Vision Gate, the clarify scan and FASE assignment.
2. **Open by section** (`sed -n 'A,Bp' file`) only what a phase needs:

   | Phase | Open only |
   |-------|-----------|
   | 0 / 1B | ADR `## Decision` blocks; INV table (id + one line); UC header block (actor, primary entity, `Refs`/`Depends`); contract endpoint/function tables; `01-SYSTEM-CONTEXT.md`; `CLAUDE.md` Active Technologies |
   | 2.0 / 2 | the evidence line per category (`grep -n -i -E 'frontend|framework|database|auth|deploy' spec/adr/*.md design/*.md CLAUDE.md`) — not the files |
   | 4 | entity field tables (`02-ENTITIES.md`, `03-VALUE-OBJECTS.md`), contract sections, NFR target rows, `design/TECHNICAL-DESIGN.md` decision tables |
   | 5B | per FASE: the sections its FASE file lists, the contracts of that FASE, `test/TEST-PLAN.md` §3 / §7 / §9 rows for that FASE |

3. Never open in full: `01-GLOSSARY.md`, runbooks, BDD files (scenario titles only), `CLARIFICATIONS.md` (grep the RN ids you cite), `test/E2E-SCENARIOS.md` and `test/TEST-MATRIX-*.md` (ids only).
4. If the `sdd_context` / `sdd_query` MCP tools are available (index built by `sdd-dashboard`), use them for id lookups instead of grep.

## Output Budget

Indicative for a ~10-requirement project (7 UC, 2-3 FASEs); scale with FASE/UC count, never with prose.

| File | Budget (chars) | What stays out |
|------|----------------|----------------|
| `ARCHITECTURE.md` | ≤ 10 000 | ADR content (cite `ADR-NNN`), restated contracts, a "Source Documents" inventory, views that only say "N/A" |
| `PLAN.md` | ≤ 12 000 | technology rows that repeat an ADR's rationale (aspect · decision · ADR id is enough), quickstart longer than 15 lines |
| `CLARIFY-LOG.md` | ≤ 6 000 with no question asked; + ≤ 1 200 per real question | option tables for questions nobody was asked; decisions an ADR already contains |
| `RESEARCH.md` | 5-row table when Phase 3 is skipped; ≤ 1 500 per real item | interface sketches (PLAN-FASE §4 owns them), empirical logs (one line with the result) |
| `fases/FASE-N-*.md` | ≤ 8 000 | copied spec content, criteria longer than one line, walkthroughs longer than 10 commands |
| `fases/README.md` | ≤ 4 000 | "how to use" / "principle" boilerplate |
| `fase-plans/PLAN-FASE-N.md` | ≤ 9 000 | pseudo-code bodies, test assertions already in `test/`, restated FASE criteria |
| **Total `plan/`** | **≤ 34 000 + 17 000 per FASE** (68 k for 2 FASEs, 85 k for 3, 102 k for 4) | |

Report the total as `metrics.plan_chars` (`find plan -name '*.md' -print0 | xargs -0 wc -c`) and the ceiling as
`metrics.plan_budget_chars` in Persist Summary; add a highlight when the total or any single file exceeds its budget by
more than 25 % (measured 2026-08-27: 88 150 chars for 3 FASEs against the old flat 70 k ceiling — the per-file budgets
were met, the total was simply not scaled).

---

## Invocation Modes

### Global Mode (default)

```
/sdd-plan-architect
```

Generates all plan artifacts for the complete system. Runs all 7 phases.

### Per-FASE Mode

```
/sdd-plan-architect --fase {N}
```

Generates only `plan/fase-plans/PLAN-FASE-{N}.md` for a single FASE. Reads global plan if it exists. Runs phases 0, 1, 5 (scoped), 6 (scoped).

### Skip Clarify Mode

```
/sdd-plan-architect --skip-clarify
```

Skips Phase 2 (interactive clarification). Uses existing `plan/CLARIFY-LOG.md` if available. Useful when re-running after spec changes.

### Regenerate FASEs Mode

```
/sdd-plan-architect --regenerate-fases
```

Forces regeneration of all FASE files from scratch (Phase 1B only). Useful after spec changes.

### Regenerate Affected FASEs Mode (Cascade)

```
/sdd-plan-architect --regenerate-fases --affected=1,5
```

Selective FASE regeneration triggered by upstream pipeline changes. When `--regenerate-fases` is combined with `--affected={comma-separated list}`, the skill only regenerates the specified FASE files instead of all of them.

**Behavior:**
- Re-reads changed specs from `spec/` to pick up modifications propagated by `sdd-req-change`
- Updates only the listed `plan/fases/FASE-{N}.md` files (e.g., `--affected=1,5` regenerates FASE-1 and FASE-5)
- After FASE regeneration, checks whether structural changes (new dependencies, removed specs, shifted phase boundaries) require updates to `plan/PLAN.md` and `plan/ARCHITECTURE.md`; if so, updates the affected sections incrementally
- Runs Phase 0 (Inventory), Phase 1B (scoped to affected FASEs), and Phase 6 (Validation, scoped)

**Typical trigger:** This mode is invoked by `sdd-req-change` Phase 9 (Pipeline Cascade) when requirement changes propagate downstream and specific FASEs are identified as impacted. It avoids a full plan regeneration by scoping work to the affected phases only.

### Audit FASEs Mode

```
/sdd-plan-architect --audit-fases
```

Read-only coverage check of existing FASE files. Reports orphan specs, obsolete references, DAG validity.

### Research Mode

```
/sdd-plan-architect --research
```

Forces Phase 3 (Technical Research) even when every NEEDS_RESEARCH item could be settled from ADR / spec evidence. Without it, Phase 3 runs only for genuinely open items and `RESEARCH.md` is otherwise a 5-row table (see Phase 3).

### Research Only Mode

```
/sdd-plan-architect --research-only
```

Runs only Phase 3 (Technical Research). Requires existing CLARIFY-LOG.md with NEEDS_RESEARCH items.

---

## Process

### Phase 0: Inventory & Baseline

**Purpose:** Build the spec manifest (ids, titles, dependencies, decisions, invariants) and load existing plan artifacts — from an index, not by reading every file.

**Steps:**

1. **Index** — the one command of the Reading Strategy over `spec/`, `requirements/`, `design/`, `ux/`, `audits/`, `test/`, `plan/`. Keep its output as the working index for every later phase.

2. **Context lines** (open by section from the index):
   - `spec/00-OVERVIEW.md` / `01-SYSTEM-CONTEXT.md` → system statement, actors, bounded contexts (heading + first table)
   - `spec/CLARIFICATIONS.md` → RN ids + titles only (`grep -n -E '^#+ *RN-|^\| *RN-'`); open an RN only when you cite it
   - `CLAUDE.md` (all levels) → "Active Technologies" / constraints section only
   - `spec/domain/01-GLOSSARY.md` → term list, never the definitions

3. **ADRs** — per file: title, `Status`, the `## Decision` block (≤ 15 lines). Not Context / Alternatives / Consequences.

4. **Invariants and contracts** — `05-INVARIANTS.md` rows (id + one line); contract endpoint/function ids with their section line; event names.

5. **Use cases** — per UC: title, primary actor, primary entity, `Refs` / `Depends` ids, exception-flow headings. The narrative flow is opened only in Phase 5B, for the FASE that owns the UC.

6. **FASE files** (if `plan/fases/` exists) → number, title, `Dependencias`, ids referenced (`grep -o -E '(UC|ADR|INV|WF|API)-[A-Z0-9-]+' | sort -u`).

7. **Technical design** (if `design/` exists) → decision tables of `TECHNICAL-DESIGN.md`, trade-off table of `QUALITY-ATTRIBUTES.md`, `ADR-DRAFT-*` titles + Decision lines. They pre-resolve most clarify categories.

7b. **UX design** (if `ux/` exists) → page list and component inventory of `WIREFRAMES.md`, token names of `UI-DESIGN-SYSTEM.md`, keyboard/ARIA tables of `ACCESSIBILITY-SPEC.md`, state names of `INTERACTION-MODEL.md`. Pre-resolves CL-UI.

8. **Security findings** (if `audits/SECURITY-AUDIT-BASELINE.md` exists) → finding id + severity + title rows → CL-SEC / CL-NFR in Phase 2.

8b. **Test plan** (if `test/TEST-PLAN.md` exists) → §3 Design Decisions, §5 Per-FASE Targets, §9 Inputs for sdd-plan-architect (R-* rows). They constrain the plan (injection points, module boundaries, test locations).

9. **Baseline** (if `plan/` has artifacts) → headings + Document History of PLAN.md, ARCHITECTURE.md, CLARIFY-LOG.md, RESEARCH.md, PLAN-FASE-*.md; open a section only when updating it.

10. **Build manifest:**
   ```
   {
     file_path: {
       type: "UC" | "ADR" | "INV" | "WF" | "BDD" | "NFR" | "contract" | "domain" | ...,
       ids: ["UC-001", "ADR-001", ...],
       decisions: ["TypeScript selected", "D1 for storage", ...],
       gaps: ["no migration strategy", "no test framework", ...]
     }
   }
   ```

**Output:** Internal manifest (not written to disk). For a 10-requirement project the context read in Phase 0 should stay under ~40 k chars.

---

### Phase 1: Spec Readiness Gate

**Purpose:** Verify prerequisites are met before planning.

**Gates:**

| Gate | Check | Action if Fails |
|------|-------|----------------|
| G1: Specs exist | `spec/` has domain/, use-cases/, contracts/ | STOP: "Run sdd-specifications-engineer" |
| G2: Audit-clean | `audits/AUDIT-BASELINE.md` exists with 0 findings | WARN: "Run sdd-spec-auditor, audit not clean" |
| G3: FASE files exist | `plan/fases/FASE-*.md` exist | AUTO: Run Phase 1B to generate FASE files |
| G4: Requirements exist | `requirements/REQUIREMENTS.md` exists | WARN: "Run sdd-requirements-engineer, recommended" |
| G5: Security audit | `audits/SECURITY-AUDIT-BASELINE.md` exists | WARN: "Run sdd-security-auditor, recommended" |

**Behavior:**
- STOP gates: Abort with recommendation. Cannot continue.
- WARN gates: Log warning, continue with reduced confidence.

**Output:** Readiness report (displayed to user, not persisted)

```markdown
## Spec Readiness Report

| Gate | Status | Evidence |
|------|--------|----------|
| G1: Specs exist | ✅ PASS | 91 spec files found |
| G2: Audit-clean | ✅ PASS | AUDIT-BASELINE.md: 0 findings |
| G3: FASE files | ✅ PASS | FASE-0 through FASE-8 found (or generated in Phase 1B) |
| G4: Requirements | ✅ PASS | REQUIREMENTS.md: 260 requirements |
| G5: Security audit | ✅ PASS | SECURITY-AUDIT-BASELINE.md: 0 findings |

**Result:** All gates PASS. Proceeding to Phase 1B (if FASE files missing) or Phase 2.
```

---

### Phase 1B: FASE Generation

**Purpose:** Generate FASE (implementation phase) files as navigation indices that map specs to incremental implementation phases.

> This phase runs automatically when Gate G3 detects no FASE files in `plan/fases/`.
> It can also be explicitly invoked with `--regenerate-fases` to regenerate from scratch.
> FASE files are **derived artifacts** — always regenerated from specs, never patched incrementally.

**Core Principles:**

1. **100% Coverage** — Every spec file MUST appear in at least one FASE file
2. **No Content Duplication** — FASE files ONLY reference specs by path + section (exception: "Contenido Específico" for formulas/diagrams)
3. **Dependencies Form a DAG** — No circular dependencies between phases
4. **Each Phase Independently Testable** — Verifiable in isolation given its dependencies
5. **Ubiquitous Language** — Only terms from `domain/01-GLOSSARY.md`

**Steps:**

1. **Inventory** — Scan all `.md` files under `spec/` (excluding `temp_files/`, `CHANGELOG.md`). For each file, extract IDs (UC-NNN, ADR-NNN, INV-XXX-NNN, WF-NNN, RN-NNN) and classify by type.

2. **Classification** — Apply phase assignment algorithm (see `references/phase-assignment-rules.md`) to assign each spec to one or more phases. Priority order: INV prefix → UC number → ADR content → BDD test → Contract module → Workflow → Domain section → NFR/Runbook → Keyword fallback → **Delivery Channel / UI pages** (Rule 8). If any spec has zero phases assigned, ask the user. **CRITICAL:** If the System Vision Gate identifies a web/mobile delivery channel, every FASE with user-facing UCs MUST include UI deliverables (pages, routes, components) — see Rule 8 and `references/fase-template.md` §7B.

3. **Dependency Analysis** — Define dependency graph, verify DAG property via topological sort. If cycle detected: STOP and report.

4. **Generate FASE Files** — For each phase, generate using the canonical template (`references/fase-template.md`) within its budget (≤ 8 000 chars). FASE files are pointers: ids and sections, never copied spec text.
   - Header: title, estado, dependencias, valor observable (one line)
   - Objetivo: one paragraph; names the parallel blocks (A ∥ B → Integración) when the FASE has them
   - Criterios de Éxito: checklist, one line per criterion (≤ 140 chars) ending with the ids it verifies, grouped by block
   - Specs a Leer: tables of path · section/ids · purpose (≤ 100 chars per row), by type (UCs, Workflows, ADRs, Domain, Contracts, Tests, NFR, Runbooks)
   - Invariantes Aplicables: id + where it is enforced (block · function); cumulative inheritance note
   - Módulos y Conjuntos de Escritura (REQUIRED): one row per block with its write-set — `sdd-task-generator` derives the work Streams (A/B…) from it; write-sets of parallel blocks must be disjoint
   - Contenido Específico (optional): formulas, diagrams, type/mapping tables that exist nowhere else (max 30 lines)
   - Contratos Resultantes: endpoint/function ids with a one-line signature; domain events
   - Entregables de UI (when the delivery channel is web/mobile): pages/routes → UC
   - Verificación: ≤ 10 commands with the expected result as a comment
   - Alcance: Incluye/Excluye table

5. **Generate README.md** — Coverage matrices and dependency graph for `plan/fases/README.md` using `references/readme-template.md`.

6. **Verification** — Confirm: every spec referenced in at least one FASE, no obsolete references, valid DAG, consistent template format, every FASE has a Módulos y Conjuntos de Escritura table whose parallel write-sets are pairwise disjoint, every FASE within budget (≤ 8 000 chars).

**File naming:** `FASE-{N}-{SLUG}.md` (e.g., `FASE-0-BOOTSTRAP.md`, `FASE-1-EXTRACCION.md`)

**Output:** `plan/fases/FASE-*.md` + `plan/fases/README.md`

**Audit Mode:** With `--audit-fases`, runs read-only coverage check without modifying files.

**Multi-Phase Specs:** Large domain files spanning multiple phases use section qualifiers:
```markdown
| `domain/02-ENTITIES.md` | Sección 2: CVAnalysis | Entidad completa |
| `domain/02-ENTITIES.md` | Sección 9: JobOffer | Entidad JobOffer |
```

**Transversal Documents:** GLOSSARY, EVENTS-domain, ERROR-CODES, OVERVIEW, SYSTEM-CONTEXT, CLARIFICATIONS are assigned to FASE-0 as primary and referenced by all phases.

---

### Phase 2.0: System Vision Gate (Mandatory)

**Purpose:** Ensure a holistic understanding of the system before diving into category-specific questions.

> This phase is **mandatory** and does NOT count toward question limits. It runs before category-specific clarification.

**Steps:**

1. **Analyze the manifest** — Use the Phase 0 index/manifest to build the holistic picture; open a spec section only for a dimension the index leaves ambiguous.

2. **Generate System Vision Statement** (3-5 lines):
   - What type of system is this? (web app, API, data pipeline, etc.)
   - Who are the primary users?
   - What is the expected scale?
   - What is the key constraint?

3. **Verify 5 minimum dimensions:**

   | Dimension | Check | Source |
   |-----------|-------|--------|
   | **Delivery Channels** | How do users interact? (web, mobile, CLI, API-only) | Use-cases actors, UI references |
   | **Data Strategy** | How is data stored and managed? | Domain entities, persistence specs |
   | **Auth Model** | How are users authenticated and authorized? | Security specs, user roles |
   | **Integration Points** | What external systems are involved? | Contracts, workflows |
   | **Quality Attributes** | What are the top 3 quality priorities? | NFRs, invariants |

4. **For each dimension, classify:**
   - **Covered**: Decision exists in specs, ADRs, `design/TECHNICAL-DESIGN.md`, or CLAUDE.md
   - **Implicit**: Can be inferred from specs but not explicitly stated
   - **Missing**: No information found — **generate mandatory question**

5. **Output — Vision Gate Table:**

   ```markdown
   ## System Vision Gate

   > {System Vision Statement — 3-5 lines}

   | Dimension | Status | Evidence |
   |-----------|--------|----------|
   | Delivery Channels | ✅ Covered | ADR-005: Web SPA with React |
   | Data Strategy | ⚠️ Implicit | Domain entities exist, no DB selection |
   | Auth Model | ✅ Covered | nfr/SECURITY.md defines JWT + RBAC |
   | Integration Points | ✅ Covered | 3 external APIs in contracts/ |
   | Quality Attributes | ❌ Missing | No NFR prioritization found |
   ```

6. **If any dimension is Missing → generate mandatory question** (presented before category questions).

7. **If `design/TECHNICAL-DESIGN.md` exists**, many dimensions will be Covered — the Vision Gate validates this and proceeds quickly.

**Output:** Vision Gate table (embedded in CLARIFY-LOG.md header)

---

### Phase 2: Clarify for Implementation (Interactive)

**Purpose:** Identify and resolve implementation gaps through interactive Q&A.

> Inspired by the spec-kit `clarify → plan` workflow. Context-aware to avoid asking about already-decided topics.

**Steps:**

1. **Scan against 13 categories** (see Clarify Taxonomy below)

2. **For each category, classify:**
   - **Resolved**: Decision exists in ADR, spec, CLARIFICATIONS.md, or CLAUDE.md
   - **Partial**: Some aspects decided, others missing
   - **Missing**: No decision found

3. **Generate candidate questions** (max 10 total):
   - Only for Partial and Missing categories
   - Prioritize by implementation impact (see taxonomy priority)
   - Include recommended answer + alternatives table

4. **Present ONE question at a time:**
   ```markdown
   **Question 1 of {N}: {CL-xxx-NNN} — {Short Title}**

   {Question text explaining the gap}

   | Opción | Descripción |
   |--------|-------------|
   | {option 1} (Recomendado) | {why recommended} |
   | {option 2} | {description} |
   | {option 3} | {description} |

   **Contexto:** {existing decisions that inform this choice}
   ```

5. **After each accepted answer:**
   - Log to `plan/CLARIFY-LOG.md` under current session
   - If answer requires new ADR, flag as "Needs ADR: ADR-xxx"
   - If answer needs research, flag as "NEEDS_RESEARCH"
   - Proceed to next question

6. **Early termination signals:**
   - User says "done", "proceed", "skip" → End Phase 2
   - All questions answered → End Phase 2
   - No maximum question limit — questions continue until critical dimensions are covered
   - User can cut short at any time; Phase 2.9 Coverage Gate validates minimum coverage

**Output:** `plan/CLARIFY-LOG.md`

**Log format (budget):** only a question actually presented to the user gets a Q-block (question, options, answer, rationale, impact). Decisions the skill takes on its own — under `--skip-clarify`, or because ADR/spec/design evidence settles them — go to the "Decisions Without a Question" table: one row of id · category · decision (≤ 140 chars) · evidence · needs ADR. Never write an options table for a question nobody was asked; never restate a decision an ADR already contains (cite it). Template in `references/plan-templates.md` §CLARIFY-LOG.

**Skip behavior:** If `--skip-clarify` flag or existing CLARIFY-LOG.md with sufficient entries, show summary and proceed; decisions taken silently are logged as table rows, not as questions.

---

### Phase 2.9: Coverage Gate

**Purpose:** Validate that the 5 critical dimensions from the Vision Gate are resolved before proceeding to architecture design.

**Steps:**

1. **Re-check Vision Gate dimensions:**
   - Delivery Channels: Resolved?
   - Data Strategy: Resolved?
   - Auth Model: Resolved?
   - Integration Points: Resolved?
   - Quality Attributes: Resolved?

2. **For each unresolved dimension:**
   - Generate a focused question targeting the specific gap
   - Present to user with strong recommendation
   - If user says "skip" → mark as "Deferred" with warning

3. **Gate result:**
   - **PASS**: All 5 dimensions resolved → proceed to Phase 3/4
   - **PASS with warnings**: 1-2 dimensions deferred → proceed with explicit warning in CLARIFY-LOG.md
   - **BLOCK**: 3+ dimensions unresolved → recommend running `sdd-tech-designer` first, or answer remaining questions

**Output:** Coverage Gate result embedded in CLARIFY-LOG.md

---

### Clarify Taxonomy (13 Categories)

> Full details in `references/clarify-taxonomy.md`

| ID | Category | Detects | Priority |
|----|----------|---------|----------|
| CL-TECH | Technology Stack | Missing language/framework/runtime choices | 1 |
| CL-DATA | Physical Data Model | Logical-to-physical mapping gaps | 2 |
| CL-UI | Delivery Channels & UI | Missing presentation layer decisions | 2.5 |
| CL-ARCH | Architecture Topology | Undefined deployment/scaling strategy | 3 |
| CL-SEC | Security Implementation | Security specs without library/pattern | 4 |
| CL-INTEG | Integration Patterns | Undefined external system protocols | 5 |
| CL-PERF | Performance Strategy | NFR targets without implementation strategy | 6 |
| CL-TEST | Test Implementation | Missing test framework/environment | 7 |
| CL-DX | Developer Experience | Missing repo structure/tooling/dev env decisions | 7.5 |
| CL-CICD | Build & Deploy Pipeline | Missing CI/CD definition | 8 |
| CL-ENV | Deployment Environment | Missing cloud/hosting/region decisions | 8.5 |
| CL-OBS | Observability & Ops | Missing monitoring/logging strategy | 9 |
| CL-COST | Cost & Resources | Missing infrastructure cost estimation | 10 |

**Context-Aware Check Protocol:**

For each category:
1. Search ADRs for relevant keywords
2. Search CLARIFICATIONS.md for relevant RN-xxx rules
3. Search CLAUDE.md for "Active Technologies" and decisions
4. Search FASE-0 for bootstrap decisions
5. If decision found → mark Resolved, skip question, log evidence

---

### Phase 3: Technical Research (Multi-Agent)

**Purpose:** Research unresolved items flagged as NEEDS_RESEARCH in Phase 2.

**When it runs:**
- `--research` or `--research-only` was passed, or
- Phase 2 produced NEEDS_RESEARCH items whose answer is **not** already determined by an ADR, the recommended option of `spec/RESEARCH-QUESTIONS.md`, `design/`, or `test/TEST-PLAN.md` §9.

Otherwise skip the phase and write `plan/RESEARCH.md` as the "skipped" table of `references/plan-templates.md` (≤ 5 rows: item · category · decided by · decision · ref) — nothing else.

**Multi-Agent Protocol:**

Launch the 2 research agents in one message with the `Agent` tool. Pass `model: sonnet` unless the environment variable `CLAUDE_CODE_SUBAGENT_MODEL` is set — then omit `model` and let the environment decide. Each agent receives only its research items, the platform/scale constraints and the existing decisions it must respect (ids + one line) — never the spec corpus.

| Agent | Scope | Searches |
|-------|-------|----------|
| **TECH-agent** | Technology stack, frameworks, libraries, infrastructure | Web search for docs, benchmarks, compatibility |
| **PATTERN-agent** | Architecture patterns, integration patterns, data patterns | Web search for patterns, case studies, best practices |

**Per-item research template** (≤ 1 500 chars per item; alternatives ≤ 4 rows with pros/cons ≤ 80 chars each; no interface sketches — PLAN-FASE §4 owns them; an empirical check is one line with the result):

```markdown
### RES-{NNN}: {Title}

**Category:** {CL-xxx} · **Question:** {Original clarify question}

| Alternative | Pros | Cons | Fit (1-5) |
|------------|------|------|-----------|
| {option 1} | {pros} | {cons} | {score} |

**Selected:** {chosen} · **Rationale:** {one sentence} · **Trade-offs:** {one sentence} · **Refs:** {ids, URLs}
```

**ADR Flagging:**

For each decision that warrants formal documentation:
- Draft ADR skeleton (Context, Decision, Consequences — ≤ 3 lines each)
- Flag for user to formalize in spec/adr/

**Output:** `plan/RESEARCH.md`

---

### Phase 4: Architecture Design

**Purpose:** Generate architecture views from specs + clarify answers + research.

**Views to generate:**

| View | Source | Template |
|------|--------|----------|
| C4 System Context (L1) | 01-SYSTEM-CONTEXT.md, contracts/, `design/TECHNICAL-DESIGN.md` (if exists) | architecture-patterns.md §1.2 |
| C4 Container Diagram (L2) | ADRs (technology), CLAUDE.md, `design/TECHNICAL-DESIGN.md` (if exists) | architecture-patterns.md §1.3 |
| C4 Component Diagram (L3) | domain/, use-cases/, contracts/ | architecture-patterns.md §1.4 |
| Deployment View | ADRs, NFR, FASE-0, `design/TECHNICAL-DESIGN.md` (if exists) | architecture-patterns.md §2 |
| Physical Data Model | domain/02-ENTITIES.md, 03-VALUE-OBJECTS.md | plan-templates.md §ARCHITECTURE |
| Integration Map | contracts/, workflows/ | architecture-patterns.md §3 |
| Security Architecture | nfr/SECURITY.md, ADR-002, `audits/SECURITY-AUDIT-BASELINE.md` (if exists) | architecture-patterns.md §3.1 |
| Quality Attributes | `design/QUALITY-ATTRIBUTES.md` (if exists), NFR | architecture-patterns.md |

**Process:**

1. Open the sections listed above (Reading Strategy: entity field tables, contract sections, NFR target rows, design decision tables) — not the files
2. For each view:
   a. Extract elements from specs
   b. Apply decisions from CLARIFY-LOG.md, RESEARCH.md, and `design/TECHNICAL-DESIGN.md` (if exists)
   c. Generate ASCII diagram + element table
   d. Cross-reference with ADRs and `design/QUALITY-ATTRIBUTES.md` (if exists)

3. Generate physical data model:
   a. Read the entity field tables of domain/02-ENTITIES.md (not the narrative)
   b. Read the value-object tables of domain/03-VALUE-OBJECTS.md
   c. Map to physical schema using selected database technology
   d. Define indexes from query patterns in use-cases
   e. Define migration strategy (≤ 5 lines)

**Compaction rules (budget ≤ 10 000 chars):**
- A decision is written once: cite `ADR-NNN` / `D-PA-NNN` / `RES-NNN`; never paraphrase an ADR's context, alternatives or consequences. §1 of the template is a decisions table with refs, not a summary of the ADRs.
- Each view = one ASCII diagram + one table whose rows carry ids (component · module · responsibility ≤ 80 chars · interface ids · FASE/block). No narrative under the diagram.
- Generate a view only when the specs give it content: no external systems → one line instead of an Integration Map; no auth → one line instead of an Authentication Flow; the error-handling view exists only if an ADR defines the mapping, and then it cites the ADR.
- No "Source Documents" inventory: one header line `Inputs: spec v{X} · design/ {yes|no} · ux/ {yes|no} · audits/ {yes|no}`.

**Output:** `plan/ARCHITECTURE.md`

**SWEBOK alignment:**
- Ch02 (Software Design): Architecture Views/Viewpoints, Quality Attributes, Design Processes, Design Rationale

---

### Phase 5: Plan Generation

**Purpose:** Generate the master implementation plan and per-FASE plans.

**5A: Master Plan (PLAN.md)**

Generate using template from `references/plan-templates.md`:

1. **Technical Context** — Consolidate all technology decisions:
   - From ADRs (authoritative)
   - From CLARIFY-LOG.md (session decisions)
   - From RESEARCH.md (research decisions)
   - From CLAUDE.md (Active Technologies)

2. **Component Decomposition** — Map bounded contexts to modules:
   - One module per bounded context (from 01-SYSTEM-CONTEXT.md)
   - Shared components extracted from cross-cutting concerns
   - Module dependency graph (ASCII)

3. **Cross-FASE Concerns** — Patterns used across all phases:
   - Authentication & Authorization flow
   - Multi-tenant isolation strategy
   - Error handling pattern
   - Observability approach

4. **Risk Assessment** — Technical risks from specs + gaps:
   - Risks from NFR targets
   - Risks from external integrations
   - Risks from scale requirements
   - Mitigation strategies

5. **Developer Quickstart** — How to start coding:
   - Prerequisites (tools, accounts, access)
   - Setup commands
   - Build, test, deploy workflow

6. **Validation & Traceability** — Cross-check matrices:
   - UC → Plan Section → FASE → Component
   - ADR → Plan compliance
   - NFR → Strategy
   - INV → Enforcement mechanism

Budget ≤ 12 000 chars: technical-context rows are `aspect · decision · ADR id` (no rationale); cross-FASE concerns ≤ 5 lines each; quickstart ≤ 15 lines; traceability tables carry ids only.

**Output:** `plan/PLAN.md`

**5B: Per-FASE Plans (PLAN-FASE-{N}.md)**

For each FASE file found in Phase 0:

1. Read FASE-{N}.md to get:
   - Title, objective, dependencies
   - Specs referenced (UCs, ADRs, INVs, contracts)

2. Open the referenced sections (not files) to extract:
   - Interfaces to implement (contract signatures / endpoint tables)
   - Data changes needed (entity field tables)
   - Rules the contract does not state (ordering, error precedence, injection points) — grep the RN/ADR ids
   - Test ids for this FASE from `test/TEST-PLAN.md` §5/§7 and the matrix / E2E ids

3. Generate per-FASE plan using template:
   - FASE-specific technical decisions
   - Component implementation details (interface sketches from contracts)
   - API implementation notes (endpoints, middleware, validation)
   - **UI deliverables** (pages/routes, components, forms) — REQUIRED for FASEs with user-facing UCs when delivery channel is web/mobile/desktop. Each page must map to its UC(s). Reference wireframes from `ux/WIREFRAMES.md` if available. See `references/fase-template.md` §7B.
   - Data changes (new tables, migrations)
   - Test strategy (unit, integration, BDD mapping)
   - **Test Coverage Map** (Source File → Test File):
     - For each source file with testable logic, map to its corresponding test file
     - Classify each source file: `logic` | `entity` | `service` | `state-machine` | `infrastructure` | `page` | `component`
     - Infrastructure files (thin wrappers, enum constants, event publishers) → mark as excluded with justification
     - Priority: HIGH (domain logic, state machines, services), MEDIUM (mappers, validators, pages), LOW (config, constants)
   - Dependencies on shared components from other FASEs
   - Acceptance criteria (from UCs + INVs)

   **Compaction rules (budget ≤ 9 000 chars per FASE):**
   - Component sections: contract-derived signatures (≤ 15 lines each) plus ≤ 5 notes on what the contract does not say. No function bodies, no pseudo-code in comments — that is code generation.
   - Test strategy §7.1-7.3: ids only (PROP / UNIT / INT / E2E / PERF ids from `test/`, grouped by level and block); assertions stay in `test/`. §7.4 Coverage Map is mandatory and keeps its format (consumed by `sdd-task-generator` V-13/V-14 and `sdd-task-implementer` CHECK-COV).
   - Do not restate the FASE file's Criterios de Éxito or Specs a Leer; §2 lists spec ids with one implementation note each (≤ 100 chars).
   - Data changes only when the FASE changes a schema; otherwise one line.
   - File paths in §4 must match the FASE's Módulos y Conjuntos de Escritura table.

**Output:** `plan/fase-plans/PLAN-FASE-{N}.md` (one per FASE)

---

### Phase 6: Validation & Traceability

**Purpose:** Cross-check the generated plan against specs for completeness.

**Checks:**

| Check | What | Against |
|-------|------|---------|
| V1: UC Coverage | Every UC in FASE files has guidance in plan | FASE files ↔ PLAN-FASE-*.md |
| V2: ADR Compliance | Every ADR decision reflected in architecture | spec/adr/ ↔ ARCHITECTURE.md |
| V3: NFR Strategies | Every NFR has implementation strategy | spec/nfr/ ↔ PLAN.md §Cross-FASE |
| V4: INV Enforcement | Every invariant has enforcement mechanism | domain/05-INVARIANTS.md ↔ PLAN.md |
| V5: FASE Completeness | Every FASE has corresponding plan file | plan/fases/ ↔ plan/fase-plans/ |
| V6: No Orphan Decisions | Every CLARIFY-LOG decision used in plan | CLARIFY-LOG.md ↔ PLAN.md |

**Process:**

1. Run each check
2. Collect gaps
3. If gaps found:
   - For V1-V5: Add missing sections to plan artifacts
   - For V6: Flag unused decisions
4. Generate validation summary

**Output:** Validation report embedded in PLAN.md footer section

```markdown
## Validation Report

| Check | Status | Coverage | Gaps |
|-------|--------|----------|------|
| V1: UC Coverage | ✅ | 41/41 UCs | None |
| V2: ADR Compliance | ✅ | 35/35 ADRs | None |
| V3: NFR Strategies | ✅ | 12/12 NFRs | None |
| V4: INV Enforcement | ✅ | 45/45 INVs | None |
| V5: FASE Plans | ✅ | 9/9 FASEs | None |
| V6: Decision Usage | ✅ | 5/5 decisions | None |

**Plan validation: PASS**
```

---

## Output Artifacts

### Global Mode

```
plan/
├── fases/                         ← FASE navigation indices (generated from specs)
│   ├── README.md                  ← Coverage matrices and dependency graph
│   ├── FASE-0-BOOTSTRAP.md        ← Phase 0 index
│   ├── FASE-1-{SLUG}.md           ← Phase 1 index
│   └── ... (one per implementation phase)
├── PLAN.md                        ← Master implementation plan
├── CLARIFY-LOG.md                 ← Interactive clarification session log
├── RESEARCH.md                    ← Technology research findings (5-row table when Phase 3 is skipped)
├── ARCHITECTURE.md                ← Architecture views (C4 + deploy + data)
└── fase-plans/
    ├── PLAN-FASE-0.md             ← Per-FASE implementation details
    ├── PLAN-FASE-1.md
    ├── PLAN-FASE-2.md
    └── ... (one per FASE file)
```

### Per-FASE Mode

```
plan/
└── fase-plans/
    └── PLAN-FASE-{N}.md      ← Single FASE plan
```

### Research Only Mode

```
plan/
└── RESEARCH.md                ← Technology research findings
```

---

## Multi-Agent Protocol (Phase 3)

### Agent Launch

```
Launch 2 agents in parallel (one message, Agent tool):
├── TECH-agent  → Technology research (stack, frameworks, libraries)
└── PATTERN-agent → Architecture patterns (integration, data, deployment)
model: sonnet — unless CLAUDE_CODE_SUBAGENT_MODEL is set (then omit `model`)
```

Agents never write `pipeline-state.json`, never send handoff messages, never touch `spec/`. They receive the items below, not the spec corpus.

### Agent Instructions Template

```
You are a {TECH|PATTERN} research agent for sdd-plan-architect Phase 3.

Your task: Research alternatives for the following implementation questions
and produce structured evaluations.

## Research Items

{List of NEEDS_RESEARCH items from CLARIFY-LOG.md}

## Output Format

For each item, produce (≤ 1 500 chars per item, no code sketches):
- Alternatives table (≤ 4 options, pros/cons ≤ 80 chars each, fit score)
- Recommended selection with a one-sentence rationale and trade-off
- References (documentation URLs, benchmarks)

## Constraints

- Focus on {technology stack / architecture patterns}
- Consider platform: {platform from CLAUDE.md}
- Consider scale: {scale targets from nfr/LIMITS.md}
- Prefer solutions compatible with: {existing tech decisions}
```

### Agent Deduplication

- TECH-agent owns: languages, frameworks, libraries, build tools, databases
- PATTERN-agent owns: architecture styles, integration patterns, data patterns, deployment strategies
- If overlap: TECH-agent decision takes precedence for specific library choice; PATTERN-agent takes precedence for structural pattern choice

### Agent Result Merge

After both agents complete:
1. Collect all research items
2. Check for conflicting recommendations → resolve by platform fit
3. Merge into single RESEARCH.md
4. Flag ADR drafts

---

## Important Constraints

### 1. Read-Only on Specs

```
✅ READ: spec/**/*.md (any file)
✅ WRITE: plan/**/*.md (only plan directory)

❌ WRITE: spec/**/*.md (NEVER modify specs)
❌ WRITE: audits/**/*.md (NEVER modify audits)
❌ WRITE: Any file outside plan/
```

If the plan reveals a spec gap that should be fixed:
- Document it in PLAN.md under "Spec Gaps Detected"
- Recommend running sdd-spec-auditor (Mode Fix)
- Do NOT fix it in the plan

### 2. No Code Generation

```
❌ Full implementation code
❌ Pseudo-code bodies (comments that walk through an algorithm) — signatures only
❌ Runnable scripts
❌ Package.json / config files

✅ Interface sketches (derived from contracts)
✅ SQL schema sketches (derived from domain model)
✅ ASCII architecture diagrams
✅ Command examples for developer quickstart
```

Interface sketches are **illustrative**, not authoritative. The contracts in spec/ remain the source of truth.

### 3. Decision Authority

| Decision Type | Authority | Where Documented |
|--------------|-----------|-----------------|
| Business rules | Specs (CLARIFICATIONS.md) | spec/ |
| Architecture | ADRs | spec/adr/ |
| Implementation choices | Plan Architect | plan/CLARIFY-LOG.md |
| Technology selection | CLAUDE.md + ADRs | plan/PLAN.md references them |

Plan Architect can make **implementation choices** (how to build) but not **business decisions** (what to build) or **architecture decisions** (these should be formalized as ADRs).

### 4. Incremental Updates

When plan/ already has artifacts:

1. Read existing artifacts as baseline
2. Identify what changed (new specs, new FASE files, new ADRs)
3. Update only affected sections
4. Add version entry to Document History
5. Preserve existing CLARIFY-LOG.md sessions (append new session)

### 5. ASCII-First Diagrams

All diagrams use ASCII art in markdown fenced code blocks:

```
✅ ASCII box diagrams (portable, diff-friendly, version-controllable)
❌ Mermaid (requires renderer)
❌ PlantUML (requires renderer)
❌ External image files (not version-controllable as text)
```

### 6. Language Convention

- Section headers: English (for international readability)
- Descriptive text: Spanish (following spec/ convention)
- Technical terms: English (ubiquitous language from glossary)
- Code/schema: English (programming convention)

---

## Handling Edge Cases

### No FASE Files Found

```
Phase 1 Gate G3 FAILS → AUTO-GENERATE
Action: Run Phase 1B (FASE Generation) to create FASE files in plan/fases/
Message: "No FASE files found. Generating from specs..."
```

### All Clarify Categories Resolved

```
Phase 2 produces 0 questions → Skip to Phase 4
Message: "All implementation decisions found in existing ADRs and specs.
Skipping clarification phase."
Log in CLARIFY-LOG.md: coverage table with all Resolved
```

### No NEEDS_RESEARCH Items (or all settled by evidence)

```
Phase 3 is skipped → write plan/RESEARCH.md as the 5-row "skipped" table → Proceed to Phase 4
Message: "No research needed. All decisions resolved in clarify phase / by ADR evidence."
```

### Per-FASE Mode Without Global Plan

```
If plan/PLAN.md does not exist:
- WARN: "No global plan found. Per-FASE plan will have limited cross-references."
- Generate standalone PLAN-FASE-{N}.md with inline context
- Recommend running global mode first
```

### Existing Plan Outdated

```
If spec version > plan version (from Document History):
- WARN: "Plan artifacts are from spec v{old}, current is v{new}."
- Run incremental update: re-scan specs, identify deltas, update affected sections
- Add version entry to Document History
```

---

## SWEBOK v4 Alignment

| SWEBOK Chapter | Topic | How Addressed |
|---------------|-------|---------------|
| Ch01 (Requirements) | Requirements Analysis | Reads REQUIREMENTS.md, validates coverage |
| Ch02 (Software Design) | Architecture Views | C4 model (L1-L3), deployment, data views |
| Ch02 (Software Design) | Architecture Evaluation | Traceability matrix, validation checks |
| Ch02 (Software Design) | Architecture Styles | Modular monolith, serverless, queue-mediated |
| Ch02 (Software Design) | Design Processes | Clarify → Research → Design → Plan |
| Ch02 (Software Design) | Design Rationale | CLARIFY-LOG.md, RESEARCH.md, ADR references |
| Ch03 (Software Construction) | Construction Planning | Per-FASE plans with components, APIs, tests |
| Ch03 (Software Construction) | Construction Design | Interface sketches, data schemas |
| Ch03 (Software Construction) | Construction Testing | Test strategy per FASE |
| Ch10 (Software Quality) | Quality Planning | NFR strategies, validation checks |

---

## Quick Reference

### Minimum Viable Run

```
Phase 0 (Inventory) → Phase 1 (Gates) → Phase 1B (FASEs, if needed) → Phase 2.0 (Vision Gate) → Phase 2 (Clarify) → Phase 2.9 (Coverage Gate) → Phase 5 (Generate) → Phase 6 (Validate)
```

Phases 1B, 3, and 4 are conditional:
- Phase 1B only if FASE files don't exist or `--regenerate-fases`
- Phase 3 only for genuinely open NEEDS_RESEARCH items or with `--research` (otherwise RESEARCH.md is a 5-row table)
- Phase 4 can be deferred if architecture is simple

### Full Run

```
Phase 0 → Phase 1 → Phase 1B → Phase 2.0 → Phase 2 → Phase 2.9 → Phase 3 → Phase 4 → Phase 5 → Phase 6
```

### Time Estimates

| Phase | Estimated Duration |
|-------|-------------------|
| Phase 0: Inventory | 1-2 min (index + sections; design/ if exists) |
| Phase 1: Gates | < 30s (existence checks) |
| Phase 2.0: Vision Gate | 1-2 min (holistic system analysis) |
| Phase 2: Clarify | 2-15 min (interactive, no hard limit) |
| Phase 2.9: Coverage Gate | < 30s (dimension validation) |
| Phase 3: Research | 0 (skipped) or 3-5 min (parallel sonnet agents, web search) |
| Phase 4: Architecture | 3-5 min (generating views) |
| Phase 5: Plan Generation | 4-8 min (writing all artifacts within budget) |
| Phase 6: Validation | 1-2 min (cross-checks) |

**Total (full run):** 12-30 min depending on spec size and gap count; output size is the driver (see Output Budget)

---

## References

| Reference | Location | Content |
|-----------|----------|---------|
| Clarify Taxonomy | `references/clarify-taxonomy.md` | 13 categories with detection rules, templates |
| Plan Templates | `references/plan-templates.md` | Output templates for all artifacts |
| Architecture Patterns | `references/architecture-patterns.md` | C4 guide, deployment patterns, common views |
| FASE Template | `references/fase-template.md` | Canonical FASE file structure |
| Phase Assignment Rules | `references/phase-assignment-rules.md` | Algorithm for assigning specs to phases |
| FASE README Template | `references/readme-template.md` | Template for fases/ README with coverage matrices |
| Coverage Report Template | `references/coverage-report-template.md` | Template for FASE audit reports |

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["plan-architect"].status` = `"done"`
3. Set `stages["plan-architect"].lastRun` = current ISO-8601
4. Set `stages["plan-architect"].summary`:
   - `artifacts`: list of files created in `plan/` with labels (e.g., `{"file": "plan/fases/FASE-1.md", "label": "FASE 1: Core Setup"}`)
   - `metrics`: `{ "total_fases": N, "components": N, "adrs_created": N, "clarify_questions": N, "research_items": N, "plan_chars": N }` — `plan_chars` is the total of `find plan -name '*.md' -print0 | xargs -0 wc -c` (Output Budget)
   - `highlights`: top 3-5 notable observations (e.g., "7 FASEs planned", "3 new ADRs for architecture decisions", "FASE-1 at 11 000 chars, over budget")
   - `nextStep`: `"Run /sdd-task-generator"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
