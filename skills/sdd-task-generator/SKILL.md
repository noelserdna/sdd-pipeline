---
name: sdd-task-generator
description: "Generates implementation task documents from FASE files and plans: atomic tasks (1 task = 1 commit) with commit messages, spec traceability, revert strategies and Stream Ownership for parallel worktrees. Outputs to task/. Does NOT modify specs or plan. Triggers: 'generate tasks', 'create tasks', 'task from plan', 'decompose FASEs', 'generar tareas', 'crear tareas', 'descomponer fases'."
---

# SDD Task Generator Skill

> **Principio:** Las tareas son el puente entre el plan y el commit.
> Cada tarea = un commit atomico, reversible y revisable por una persona.
> Specs = fuente de verdad (QUE). FASE = orden (CUANDO). Plan = diseho (COMO). Task = unidad de trabajo (QUIEN/DONDE).

## Purpose

Generar documentos de tareas accionables a partir de FASE files y planes de implementacion, produciendo:

1. **Tareas atomicas** que mapean 1:1 a commits de git
2. **Mensajes de commit** pre-definidos con formato convencional
3. **Estrategias de reversion** documentadas por tarea
4. **Checklists de revision** para revisores humanos
5. **Trazabilidad completa** a specs, FASEs, requisitos e invariantes
6. **Marcadores de paralelismo** para ejecucion concurrente
7. **Checkpoints de verificacion** por fase
8. **Stream Ownership** por FASE: particion de las tasks en Streams con write-sets disjuntos, cada uno implementable en un worktree propio (`sdd-task-implementer --stream`)

## When to Use This Skill

Use this skill when:
- Plan artifacts exist in `plan/` (from `sdd-plan-architect`)
- FASE files exist in `plan/fases/` (from `sdd-plan-architect`)
- The `task/` directory is empty or outdated
- Starting implementation and need atomic work items
- Onboarding developers who need a clear work breakdown
- Setting up a project board or issue tracker

## When NOT to Use This Skill

- To create specs → use `sdd-specifications-engineer`
- To audit specs for defects → use `sdd-spec-auditor`
- To fix spec defects → use `sdd-spec-auditor` (Mode Fix)
- To derive requirements → use `sdd-requirements-engineer`
- To generate FASE files + implementation plans → use `sdd-plan-architect`
- To implement code from tasks → use `sdd-task-implementer`
- To manage spec changes → use `sdd-req-change`

## Relationship to Other Skills

| Skill | Phase | Relationship |
|-------|-------|-------------|
| `sdd-specifications-engineer` | Creation | **Prerequisite**: specs must exist |
| `sdd-spec-auditor` | Quality | **Recommended**: specs should be audit-clean |
| `sdd-security-auditor` | Security | **Recommended**: security audit before tasks |
| `sdd-plan-architect` | Phases + Planning | **Prerequisite**: FASE files + plan/ artifacts must exist |
| **`sdd-task-generator`** | **Tasks** | **THIS SKILL**: generates task/ artifacts |
| `sdd-task-implementer` | Implementation | **Downstream**: implements code from tasks |

### Pipeline Position

```
Requisitos → sdd-specifications-engineer → sdd-spec-auditor (fix) →
                                                        |
                                          sdd-plan-architect (FASEs + plans)
                                                        |
                                                 sdd-task-generator ← YOU ARE HERE
                                                        |
                                               sdd-task-implementer

Herramientas laterales (opcionales):
  sdd-requirements-engineer ← retrofit: derivar REQs cuando se empezo por specs
  sdd-req-change        ← gestionar cambios de requisitos post-facto
  sdd-security-auditor  ← auditoria de seguridad complementaria
```

> **Nota:** Los requisitos son el punto de partida natural del proceso de ingenieria
> (SWEBOK v4 Ch01). `sdd-requirements-engineer` es una herramienta de retrofit para repositorios
> que empezaron por especificaciones sin requisitos formales. No forma parte del pipeline principal.

> SWEBOK v4 alignment:
> - Ch04 §2: Construction Planning, Managing Dependencies
> - Ch08 §3: Software Configuration Change Control, SCR Process
> - Ch09 §2: Software Project Planning, WBS, Determine Deliverables
> - Ch09 §3: Software Project Execution, Implementation of Plans

---

## Core Principles

### 1. One Task = One Commit

```
WRONG: "Implement user authentication" (multiple files, multiple concerns)
WRONG: "Setup project" (too broad, not atomic)

RIGHT: "Create User entity schema in src/domain/user.ts"
RIGHT: "Add authentication middleware in src/middleware/auth.ts"
RIGHT: "Register auth routes in src/routes/auth.ts"
```

Each task MUST be completable and committable independently. If a task requires other uncommitted work, those are **dependencies**, not parts of the same task.

### 2. Reversibility by Design

```
WRONG: Tasks that require coordinated rollback across multiple files
WRONG: Migration tasks without rollback scripts
WRONG: Tasks that modify shared state without isolation

RIGHT: Each task's commit can be reverted with `git revert <sha>`
RIGHT: Database migrations include down() alongside up()
RIGHT: Feature flags isolate incomplete features
```

Every task document includes a **Revert Strategy** section documenting what breaks if the commit is reverted and how to recover.

### 3. Human Reviewable

```
WRONG: "Do the thing" (no acceptance criteria)
WRONG: Massive tasks touching 10+ files (unreviewable diff)
WRONG: Tasks without test verification steps

RIGHT: Clear acceptance criteria per task
RIGHT: Single-concern tasks (1-3 files typically)
RIGHT: Verification commands that a reviewer can run
```

### 4. Full Traceability

```
Every task MUST reference:
- FASE it belongs to (e.g., FASE-0)
- Spec documents it implements (e.g., UC-001, ADR-002)
- Invariants it must satisfy (e.g., INV-SEC-001)
- Requirements it fulfills (e.g., REQ-EXT-001)
- Plan section it derives from (e.g., PLAN-FASE-0 §3.2)
```

### 5. Specs as Single Source of Truth

```
WRONG: Invent implementation details not in specs or plan
WRONG: Modify spec/ or plan/ files
WRONG: Contradict decisions in ADRs

RIGHT: Derive tasks from what IS specified in plan + FASE
RIGHT: Only write to task/
RIGHT: Flag gaps as [PLAN GAP] requiring sdd-plan-architect
```

### 6. Ubiquitous Language

Use ONLY terms defined in `domain/01-GLOSSARY.md`. Never introduce synonyms.

---

## Task ID Convention

### Format

```
TASK-F{N}-{SEQ}
```

- `F{N}` = FASE number (F0, F1, F2, ..., F8)
- `{SEQ}` = 3-digit sequential number within the FASE (001, 002, ..., 999)

### Examples

| ID | Meaning |
|----|---------|
| `TASK-F0-001` | First task of FASE 0 (Bootstrap) |
| `TASK-F0-042` | 42nd task of FASE 0 |
| `TASK-F3-015` | 15th task of FASE 3 |

### Parallel Markers

Tasks that can execute concurrently (different files, no shared state) are marked with `[P]`:

```
- [ ] TASK-F0-005 [P] Create AuditLog entity schema
- [ ] TASK-F0-006 [P] Create DomainEvent entity schema
```

### Dependency Markers

Tasks that block other tasks use `blocks:` and `blocked-by:` annotations:

```
- [ ] TASK-F0-001 Create project structure
  - blocks: TASK-F0-002, TASK-F0-003

- [ ] TASK-F0-002 Initialize Hono framework
  - blocked-by: TASK-F0-001
```

---

## Invocation

### Mode 1: Full Generation (default)

```
/sdd-task-generator
```

Generates tasks for ALL FASEs that have plan artifacts.

### Mode 2: Per-FASE Generation

```
/sdd-task-generator --fase 0
```

Generates tasks for a single FASE only.

### Mode 3: Regeneration

```
/sdd-task-generator --regen
```

Regenerates all task files from scratch, discarding previous task/ content.

### Mode 4: Audit Mode

```
/sdd-task-generator --audit
```

Validates existing task files against current FASE + plan state without modifying them. Reports:
- Tasks referencing deleted/renamed specs
- Missing tasks for new plan sections
- Broken dependency chains
- Orphan tasks (no FASE mapping)
- Stream Ownership drift: recomputes Phase 3b from the write-sets of the existing tasks and compares the result with the published `## Stream Ownership` table and the `Streams:` lines of `TASK-ORDER.md`; runs V-15..V-18 on the published table (a file shared by two work Streams → V-15 ERROR)

### Mode 5: Incremental Generation (cascade)

```
/sdd-task-generator --fase=1 --incremental
```

Generates only new or changed tasks for a single FASE, preserving already-completed work. This mode is typically invoked by `sdd-req-change` Phase 9 (Pipeline Cascade) after a requirements change propagates through the specification and planning layers.

**Behavior:**

1. **Diff against existing tasks:** Compare the regenerated FASE plan (`plan/fase-plans/PLAN-FASE-{N}.md`) against the existing `task/TASK-FASE-{N}.md`.
2. **Preserve completed tasks:** Tasks already marked as done (`[x]`) or that have not changed are left untouched. Already-completed tasks are NEVER regenerated.
3. **Generate delta only:** Only produce task entries for new plan items or plan items whose scope/acceptance criteria changed since the last generation.
4. **Cascade traceability:** Every new or modified task includes a `Source: CASCADE-{change-report-id}` annotation linking back to the `sdd-req-change` change report that triggered the regeneration.
5. **Update indexes:** Append new tasks to `TASK-INDEX.md` and update `TASK-ORDER.md` dependency graph to incorporate the delta.
6. **Recompute Stream Ownership:** Re-run Phase 3b for the FASE over the full task set (existing + delta). A completed task keeps its Stream; if a new task would join two existing work Streams, it goes to `integración` and the conflict is reported (V-15/V-18).

**Requirements:**
- `--fase` is mandatory when using `--incremental` (full-generation incremental is not supported).
- An existing `task/TASK-FASE-{N}.md` must already exist; otherwise falls back to standard Mode 2 generation.
- A change report from `sdd-req-change` should be present in `audits/` for proper `CASCADE-{id}` annotation. If absent, tasks are annotated with `Source: CASCADE-MANUAL`.

---

## Output Artifacts

All artifacts are written to `task/` directory:

```
task/
  TASK-INDEX.md          ← Global index: all tasks across all FASEs
  TASK-ORDER.md          ← Implementation order with dependency graph
  TASK-FASE-0.md         ← Tasks for FASE 0
  TASK-FASE-1.md         ← Tasks for FASE 1
  ...
  TASK-FASE-N.md         ← Tasks for FASE N
```

---

## Execution Phases

### Phase 0: Inventory & Validation

**Goal:** Verify prerequisites and gather all inputs.

```
INPUTS TO READ:
1. plan/fases/FASE-*.md                     (ALL FASE files)
2. plan/fase-plans/PLAN-FASE-*.md           (ALL per-FASE plans)
3. plan/ARCHITECTURE.md                     (architecture views)
4. plan/PLAN.md                             (global plan)
5. spec/domain/01-GLOSSARY.md               (ubiquitous language)
6. task/TASK-INDEX.md                        (existing tasks if any)
7. pipeline-state.json                       (stage status, for G-04; absent = no staleness info)
```

**Validation Gates:**

| Gate | Condition | Action if Failed |
|------|-----------|-----------------|
| G-01 | At least one FASE file exists | HALT: run `sdd-plan-architect` first |
| G-02 | Plan artifacts exist for target FASE(s) | HALT: run `sdd-plan-architect` first |
| G-03 | Glossary exists | WARN: proceed with caution |
| G-04 | Plan is current: `stages["plan-architect"].status != "stale"` in `pipeline-state.json` | HALT: run `sdd-plan-architect` first (plan is stale: `{staleReason}`) |
| G-05 | FASE files are newer than `spec/` (mtime heuristic; only check when `pipeline-state.json` is absent) | WARN: consider running `sdd-plan-architect --audit-fases` |

> G-04 replaces the previous WARN: generating tasks from a stale plan would publish write-sets and Streams that no longer match the specs, and the implementer would branch worktrees from them. `spec-auditor` stale is covered transitively (the `sdd-req-change` cascade marks `plan-architect` stale whenever it marks `spec-auditor` stale).

### Phase 1: FASE Analysis

**Goal:** Parse each FASE file to extract implementation scope.

For each FASE, extract:
1. **Criterios de Exito** → become acceptance criteria groups
2. **Specs a Leer** → become traceability references
3. **Invariantes Aplicables** → become validation constraints
4. **Contratos Resultantes** → become deliverable tasks (endpoints, events)
5. **Alcance (Incluye/Excluye)** → boundary for task scope
6. **Dependencias** → FASE-level ordering constraints

### Phase 2: Plan Decomposition

**Goal:** Decompose plan sections into atomic tasks.

For each PLAN-FASE-{N}.md, extract:
1. **Components to build** → individual tasks per component
2. **Data models** → entity creation tasks
3. **API endpoints** → route + handler + validation tasks
4. **Tests** → test creation tasks
5. **Configuration** → config/setup tasks
6. **Integration points** → wiring/integration tasks

**Decomposition Rules:**

| Concern | Task Granularity | Example |
|---------|-----------------|---------|
| Entity/Model | 1 task per entity | "Create Organization entity" |
| API Endpoint | 1 task per route-group | "Implement /api/v1/health endpoints" |
| Middleware | 1 task per middleware | "Add rate limiting middleware" |
| Service | 1 task per service class | "Implement EncryptionService" |
| Migration | 1 task per schema change | "Create users table migration" |
| Test file | **1 task per source file** that needs tests (from Coverage Map §7.4) | "Add unit tests for call-analyzer.step.ts" |
| Config | 1 task per config concern | "Configure Cloudflare Workers environment" |
| Integration | 1 task per integration | "Wire event bus to audit logger" |

**Size Heuristic:** If a task would touch more than 3 files, split it. If a task description exceeds 2 sentences, it may be too broad.

### Phase 3: Dependency Resolution

**Goal:** Establish task ordering and parallel opportunities.

**Algorithm:**

```
1. For each task, identify:
   - Files it creates/modifies → write-set
   - Files it reads/imports → read-set

2. Task B depends on Task A if:
   - B's read-set intersects A's write-set
   - B requires A's deliverable (e.g., entity before service)

3. Mark independent tasks as [P] (parallelizable):
   - No overlapping write-sets
   - No read-dependency on uncommitted write-sets

4. Verify DAG:
   - No circular dependencies
   - Every task reachable from at least one root task
   - Critical path identified
```

**Phase Ordering Within Each FASE:**

1. **Setup Phase**: Project structure, dependencies, configuration
2. **Foundation Phase**: Shared infrastructure (DB schemas, middleware, base classes)
3. **Domain Phase**: Entities, value objects, domain services
4. **Contract Phase**: API routes, handlers, event schemas
5. **Integration Phase**: Wiring, event handlers, background jobs
6. **Test Phase**: Unit tests, integration tests, BDD scenarios
7. **Verification Phase**: End-to-end validation, checkpoint

### Phase 3b: Stream Assignment

**Goal:** Partition the tasks of each FASE into **Streams** with pairwise-disjoint write-sets, so that each work Stream can be implemented in its own git worktree (`sdd-task-implementer --fase N --stream A`) and merged back by `--integrate --fase N`. The result is the `## Stream Ownership` table (source of truth for the implementer's task filter) and the `Streams:` line in `TASK-ORDER.md`.

**Write-set of a task** = every backticked path after the `|` on the task line (comma-separated when the task touches more than one file) plus every path listed in its optional `- **Files:**` bullet. Paths mentioned only in Acceptance/Refs/Review are reads, not writes.

**Algorithm (per FASE, after Phase 3 assigned every task to an internal phase):**

```
1. base := tasks of internal phases Setup (1) and Foundation (2).
   - Run in the main checkout BEFORE any worktree is opened.
   - The implementer tags the last base commit with checkpoint `fase-{N}-foundation`
     (branch point of every worktree of this FASE).

2. Work graph G over the tasks of Domain (3), Contracts (4), Integration (5)
   and any other internal phase between Foundation and Tests:
   - node  = task
   - edge(A, B) if write-set(A) ∩ write-set(B) ≠ ∅
                or A is `blocked-by` B (or B is `blocked-by` A)
   - connected components of G → candidate Streams

3. Wiring extraction (repeat until no candidate passes):
   - Candidate: a task whose write-set contains a shared entry point / index / barrel
     (`src/index.ts`, `src/app.ts`, `src/routes/index.ts`, `migrations/index.*`,
     any `index.ts` re-exporting ≥ 2 directories) or whose `blocked-by` list spans
     ≥ 2 top-level source directories.
   - Test: remove the candidate from G. If the tasks it was connected to now fall into
     ≥ 2 components, the candidate touches ≥ 2 components → it leaves its component
     and goes to Stream `integración` (main checkout, after `--integrate --fase N`).
   - A component emptied by the extraction disappears. If NO work task is left
     (every work task was wiring), keep them all in Stream A and leave `integración` empty.

4. Letter the remaining components A, B, C… by task count, largest first
   (tie → the component containing the lowest task ID).

5. Tests (internal phase 6):
   - A test task whose test files cover source files of exactly ONE work Stream
     (Coverage Map §7.4 Source → Test) joins that Stream; its test paths are added
     to the Stream's Owns.
   - Any other test task (integration/BDD/e2e across Streams) → Stream `verificación`.

6. Verification (internal phase 7) → Stream `verificación` (main checkout, implementer Phase 9).
   Rollback checkpoints belong to the main checkout only: `fase-{N}-foundation` after the
   last base task and `fase-{N}-verified` after Verification. Worktrees never create tags.
```

**Owns (write-set) column:** the smallest set of globs that covers every file of the Stream's write-set and matches no file of any other Stream (e.g. `src/api/**`). List exact paths when a directory is shared (typical for `base` and `integración`, e.g. `package.json, src/index.ts`).

**Branch names:** `feat/fase-{N}-{stream}` with the Stream letter in lower case (`feat/fase-1-a`, `feat/fase-1-b`). Only work Streams (A, B, C…) get a worktree; `base`, `integración` and `verificación` run in the main checkout.

**Single-Stream FASE:** a FASE whose work graph yields one component is valid. The table is written the same way (base + A + integración/verificación) and `TASK-ORDER.md` marks it `Streams: serial`.

**Stream Ownership table** (mandatory in every `TASK-FASE-{N}.md`, right after "Parallel Execution Plan"; it replaces the former free-text Stream lists — do NOT add new markers to the task lines):

```markdown
## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F1-001, TASK-F1-002 | package.json, src/index.ts | main checkout, before worktrees (checkpoint `fase-1-foundation`) |
| A | TASK-F1-003, TASK-F1-005 | src/api/**, tests/api/** | worktree `feat/fase-1-a` |
| B | TASK-F1-004, TASK-F1-006 | src/cli/**, tests/cli/** | worktree `feat/fase-1-b` |
| integración | TASK-F1-009 | src/index.ts | main checkout, after `--integrate --fase 1` |
| verificación | TASK-F1-010 | — | main checkout, Phase 9 |
```

Row order is fixed: `base`, work Streams A…Z, `integración`, `verificación`. A Stream with no tasks is still listed with `—` in Tasks and Owns.

### Phase 4: Commit Message Generation

**Goal:** Pre-generate conventional commit messages for each task.

**Format:**

```
{type}({scope}): {description}

Refs: {FASE}, {UC/ADR/INV references}
Task: {TASK-ID}
```

**Types:**

| Type | Use For |
|------|---------|
| `feat` | New functionality (endpoints, services, entities) |
| `fix` | Bug fixes found during implementation |
| `refactor` | Restructuring without behavior change |
| `test` | Adding or modifying tests |
| `chore` | Configuration, build, tooling |
| `docs` | Documentation only changes |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvements |

**Scope:** Module or bounded context name from FASE. Examples: `auth`, `extraction`, `matching`, `gdpr`, `admin`.

**Examples:**

```
feat(auth): add rate limiting middleware

Refs: FASE-0, ADR-025, INV-SEC-003
Task: TASK-F0-012

chore(bootstrap): configure Cloudflare Workers environment

Refs: FASE-0, ADR-036
Task: TASK-F0-001

test(audit): add integrity check for hash chain

Refs: FASE-0, INV-AUD-002, INV-AUD-004
Task: TASK-F0-038
```

### Phase 5: Revert Strategy Generation

**Goal:** Document revert impact and recovery steps per task.

For each task, generate:

```markdown
**Revert Strategy:**
- Revert command: `git revert <sha> --no-edit`
- Impact: {what breaks if reverted}
- Recovery: {steps to recover after revert}
- Safe to revert independently: {yes/no}
- Requires coordinated revert with: {list of coupled tasks, if any}
```

**Revert Safety Categories:**

| Category | Meaning | Action |
|----------|---------|--------|
| `SAFE` | Can revert independently, no side effects | Single `git revert` |
| `COUPLED` | Must revert with related tasks | Revert in reverse order |
| `MIGRATION` | Has database state change | Requires down migration first |
| `CONFIG` | Changes runtime config | Requires restart/redeploy after revert |

### Phase 6: Review Checklist Generation

**Goal:** Generate per-task review checklist for human reviewers.

Every task includes a review checklist following this pattern:

```markdown
**Review Checklist:**
- [ ] Code compiles without errors
- [ ] Follows ubiquitous language from glossary
- [ ] Satisfies acceptance criteria listed above
- [ ] Referenced invariants are enforced
- [ ] No secrets or credentials in code
- [ ] Error handling follows ADR-026 patterns
- [ ] {domain-specific checks based on task type}
```

**Domain-Specific Review Items** (added per task type):

| Task Type | Additional Review Items |
|-----------|----------------------|
| Entity | Schema matches spec/domain/02-ENTITIES.md |
| API Endpoint | Contract matches spec/contracts/*.md |
| Middleware | Rate limits match spec/nfr/LIMITS.md |
| Migration | Has reversible down() function |
| Event | Schema matches spec/contracts/EVENTS-domain.md |
| Test | Covers acceptance criteria from FASE file |
| PII-related | Encryption follows ADR-002 |
| Multi-tenant | Tenant isolation enforced (INV-SYS-001) |

### Phase 7: Document Generation

**Goal:** Write all task/ artifacts.

Generate documents using templates from `references/`:

1. **Per-FASE task file** (`TASK-FASE-{N}.md`): All tasks for one FASE, including the `## Stream Ownership` table from Phase 3b
2. **Global index** (`TASK-INDEX.md`): Summary of all tasks across FASEs
3. **Implementation order** (`TASK-ORDER.md`): Dependency graph, critical path, parallel opportunities, one `Streams:` line per FASE and the Stream of every task in Cross-FASE Dependencies

### Phase 8: Validation

**Goal:** Verify completeness and consistency.

**Validation Checks:**

| Check | Description | Severity |
|-------|-------------|----------|
| V-01 | Every FASE Criterio de Exito maps to at least one task | ERROR |
| V-02 | Every Contrato Resultante has implementation tasks | ERROR |
| V-03 | Every Invariante Aplicable has enforcement in at least one task | ERROR |
| V-04 | No circular dependencies in task graph | ERROR |
| V-05 | Every task has a commit message | ERROR |
| V-06 | Every task has acceptance criteria | ERROR |
| V-07 | Every task has a revert strategy | WARN |
| V-08 | No task touches more than 5 files | WARN |
| V-09 | All task IDs follow TASK-F{N}-{SEQ} format | ERROR |
| V-10 | Task count per FASE is reasonable (5-80 tasks) | WARN |
| V-11 | Critical path identified in TASK-ORDER.md | ERROR |
| V-12 | All file paths use project conventions from CLAUDE.md | WARN |
| V-13 | Every source file in Coverage Map §7.4 has a corresponding test task | ERROR |
| V-14 | Every file in Coverage Map Exclusions has a justified reason | WARN |
| V-15 | Write-sets of the work Streams (A, B, C…) are pairwise disjoint (no file, no glob overlap) | ERROR |
| V-16 | Every task belongs to exactly one Stream (`base`, A…Z, `integración`, `verificación`); no task missing from the table, none listed twice | ERROR |
| V-17 | Verification-phase tasks and rollback checkpoints appear only in Stream `verificación` / the main checkout; no checkpoint is assigned to a worktree Stream | ERROR |
| V-18 | Every `blocked-by` of a Stream task points to the same Stream, to `base`, or to a task of an earlier FASE | WARN |

V-15..V-18 are computed from the `## Stream Ownership` table of each `TASK-FASE-{N}.md`. `--audit` recomputes the table (Phase 3b) from the current task write-sets, compares it with the published one, and reports both the drift and any V-15..V-18 finding.

---

## Per-FASE Task File Structure

Every `TASK-FASE-{N}.md` follows this canonical structure:

```markdown
# Tasks: FASE-{N} - {Title}

> **Input:** plan/fases/FASE-{N}-{slug}.md + plan/PLAN-FASE-{N}.md
> **Generated:** {YYYY-MM-DD}
> **Total tasks:** {count}
> **Parallel capacity:** {number of work Streams from Stream Ownership}
> **Critical path:** {count} tasks, ~{estimate}

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | {N} |
| Parallelizable | {N} ({%}) |
| Work Streams | {N} (A: {n} tasks, B: {n} tasks) |
| Setup phase | {N} tasks |
| Foundation phase | {N} tasks |
| Domain phase | {N} tasks |
| Contract phase | {N} tasks |
| Integration phase | {N} tasks |
| Test phase | {N} tasks |
| Verification phase | {N} tasks |

## Traceability

| Spec Reference | Task Coverage |
|---------------|---------------|
| UC-001 | TASK-F{N}-{X}, TASK-F{N}-{Y} |
| ADR-002 | TASK-F{N}-{Z} |
| INV-SEC-001 | TASK-F{N}-{W} |
| REQ-EXT-001 | TASK-F{N}-{V} |

---

## Phase 1: Setup

**Purpose:** Project structure, dependencies, configuration.
**Checkpoint:** Project initializes and builds successfully.

- [ ] TASK-F{N}-001 [P] {Description} | `{file_path}`
  - **Commit:** `chore({scope}): {message}`
  - **Acceptance:** {criteria}
  - **Refs:** {FASE, UC, ADR, INV, REQ}
  - **Revert:** SAFE | {impact}
  - **Review:** [ ] compiles [ ] follows glossary [ ] {domain-specific}

---

## Phase 2: Foundation

**Purpose:** Shared infrastructure blocking all subsequent phases.
**Checkpoint:** Foundation services pass smoke tests.

...

## Phase 3: Domain

**Purpose:** Entities, value objects, domain logic.
**Checkpoint:** Domain model unit tests pass.

...

## Phase 4: Contracts

**Purpose:** API endpoints, event schemas, handlers.
**Checkpoint:** Contract tests pass against spec.

...

## Phase 5: Integration

**Purpose:** Wiring, event handlers, cross-cutting concerns.
**Checkpoint:** Integration tests pass.

...

## Phase 6: Tests

**Purpose:** Remaining test coverage (BDD, property, e2e).
**Checkpoint:** All test suites green.

...

## Phase 7: Verification

**Purpose:** End-to-end validation against FASE Criterios de Exito.
**Checkpoint:** All FASE acceptance criteria verified.

- [ ] TASK-F{N}-{LAST} Verify all FASE-{N} Criterios de Exito
  - **Commit:** `test({scope}): verify FASE-{N} acceptance criteria`
  - **Acceptance:** All criteria from FASE-{N} marked as passing
  - **Refs:** FASE-{N}
  - **Revert:** SAFE
  - **Review:** [ ] all criteria checked [ ] evidence documented

---

## Dependencies

### Task Dependency Graph

{Mermaid or text-based dependency graph}

### Critical Path

{Sequence of tasks on the critical path}

### Parallel Execution Plan

{One line per work Stream: what it delivers; the task lists live in the table below}

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | {TASK-F{N}-001, ...} | {exact paths} | main checkout, before worktrees (checkpoint `fase-{N}-foundation`) |
| A | {tasks} | {globs} | worktree `feat/fase-{N}-a` |
| B | {tasks} | {globs} | worktree `feat/fase-{N}-b` |
| integración | {tasks or —} | {exact paths or —} | main checkout, after `--integrate --fase {N}` |
| verificación | {TASK-F{N}-{LAST}} | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Foundation | {last base task} | `fase-{N}-foundation` | main checkout |
| Verified | TASK-F{N}-{LAST} | `fase-{N}-verified` | main checkout |
```

---

## TASK-INDEX.md Structure

```markdown
# Task Index

> **Generated:** {YYYY-MM-DD}
> **Total tasks:** {count across all FASEs}
> **FASEs covered:** {list}

## Summary by FASE

| FASE | Title | Tasks | Parallelizable | Status |
|------|-------|-------|---------------|--------|
| FASE-0 | Bootstrap Tecnico | 45 | 18 (40%) | pending |
| FASE-1 | Extraccion PDF | 38 | 15 (39%) | pending |
| ... | ... | ... | ... | ... |

## All Tasks (Flat List)

| ID | FASE | Phase | Description | Parallel | Status |
|----|------|-------|-------------|----------|--------|
| TASK-F0-001 | 0 | Setup | Create project structure | - | [ ] |
| TASK-F0-002 | 0 | Setup | Initialize Hono framework | - | [ ] |
| TASK-F0-003 | 0 | Foundation | Create base D1 schema | [P] | [ ] |
| ... | ... | ... | ... | ... | ... |

## Traceability Matrix

| Spec | Tasks |
|------|-------|
| UC-001 | TASK-F1-005, TASK-F1-006, TASK-F1-012 |
| UC-002 | TASK-F1-015, TASK-F1-016 |
| ... | ... |
```

---

## TASK-ORDER.md Structure

```markdown
# Implementation Order

> **Generated:** {YYYY-MM-DD}
> **Total FASEs:** {count}
> **Recommended approach:** Incremental delivery per FASE

## FASE Dependency Graph

{Text or Mermaid diagram showing FASE ordering}

## Recommended Implementation Sequence

### Wave 1: Foundation
**FASE-0** (No dependencies — start here)
- {count} tasks, {parallel count} parallelizable
- Critical path: {N} sequential tasks
- Estimated review cycles: {N}
- Streams: serial

### Wave 2: Core Capabilities
**FASE-1** (depends on: FASE-0)
- {count} tasks, {parallel count} parallelizable
- Critical path: {N} sequential tasks
- Streams: base(2) → A(2) ∥ B(2) → integración(1) → verificación(1)

### Wave N: {Title}
**FASE-{N}** (depends on: ...)
...

## Cross-FASE Dependencies

| From (Stream) | To (Stream) | Reason |
|---------------|-------------|--------|
| TASK-F0-005 (base) | TASK-F1-001 (A) | F1 uses encryption from F0 |
| ... | ... | ... |

## MVP Strategy

**Minimum Viable Product:** FASE-0 + FASE-1
- {count} total tasks
- Core capability: {description}
- Can deploy and validate independently

## Incremental Delivery Checkpoints

| Checkpoint | FASEs Complete | Capability |
|-----------|---------------|------------|
| CP-1 | FASE-0 | Infrastructure + admin |
| CP-2 | FASE-0,1 | PDF extraction functional |
| CP-3 | FASE-0,1,2 | CV analysis operational |
| ... | ... | ... |
```

**`Streams:` line rules:** one per FASE, inside its Wave entry. Format `Streams: base(n) → A(n) ∥ B(n) [∥ C(n)…] → integración(n) → verificación(n)` with the task count of each Stream in parentheses (a Stream with no tasks is written `integración(0)`). When the FASE has a single work Stream, write exactly `Streams: serial`. In Cross-FASE Dependencies, every task carries its Stream in parentheses.

---

## Multi-Agent Strategy

When generating tasks for multiple FASEs, use parallel agents grouped by FASE:

```
Agent-F0: Reads FASE-0 + PLAN-FASE-0 → writes TASK-FASE-0.md
Agent-F1: Reads FASE-1 + PLAN-FASE-1 → writes TASK-FASE-1.md
...
(No cross-file conflicts since each agent writes to a different file)

After all agents complete:
Main thread: Generates TASK-INDEX.md + TASK-ORDER.md from all TASK-FASE-{N}.md files
```

---

## Handling Plan Gaps

If during task generation you discover that a FASE references something not covered in the plan:

1. **DO NOT invent** the missing plan content
2. **Mark the gap** in the task file:

```markdown
- [ ] TASK-F{N}-{SEQ} [PLAN GAP] {Description of what's needed}
  - **Gap:** PLAN-FASE-{N} does not specify {what's missing}
  - **Action:** Run `sdd-plan-architect --fase {N}` to resolve
  - **Commit:** N/A (blocked)
  - **Refs:** {spec references that need plan coverage}
```

3. **Report all gaps** in the validation summary

---

## Integration with Git Workflow

### Recommended Branch Strategy

```
main
  └── feat/fase-{N}
       ├── TASK-F{N}-001  (commit)
       ├── TASK-F{N}-002  (commit)
       ├── ...
       └── TASK-F{N}-{LAST}  (commit)
       → PR: "feat: implement FASE-{N} - {Title}"
```

With more than one work Stream (Stream Ownership table), the FASE branches per Stream from the Foundation checkpoint:

```
main (or feat/fase-{N})
  ├── base tasks (commits) ──── tag fase-{N}-foundation
  ├── worktree feat/fase-{N}-a  ← Stream A tasks (commits, no tags)
  ├── worktree feat/fase-{N}-b  ← Stream B tasks (commits, no tags)
  ├── git merge --no-ff feat/fase-{N}-a, feat/fase-{N}-b   (sdd-task-implementer --integrate --fase {N})
  ├── integración tasks (commits)
  └── verificación task ──────── tag fase-{N}-verified
```

### Commit Discipline

1. One task = one commit (atomic)
2. Each commit message follows the pre-generated format
3. Each commit should pass CI independently
4. PRs group commits by FASE (reviewable unit)
5. Squash merge only if team prefers linear history; otherwise merge commit preserves atomicity

### Revert Workflow

```bash
# Revert a single task
git revert <sha-of-TASK-F0-012> --no-edit

# Revert a phase within a FASE (e.g., all Integration tasks)
git revert <sha-last-integration-task>..<sha-first-integration-task> --no-edit

# Revert entire FASE (if on feature branch, just delete branch)
git branch -D feat/fase-0
```

---

## Output Location Rules

| Artifact | Path | Overwrites |
|----------|------|------------|
| Per-FASE tasks | `task/TASK-FASE-{N}.md` | Yes (regenerated) |
| Global index | `task/TASK-INDEX.md` | Yes (regenerated) |
| Implementation order | `task/TASK-ORDER.md` | Yes (regenerated) |

**NEVER modify:**
- `spec/` (any file)
- `plan/` (any file)
- `audits/` (any file)

---

## Quality Signals

### Good Task

```markdown
- [ ] TASK-F0-012 Add rate limiting middleware | `src/middleware/rate-limiter.ts`
  - **Commit:** `feat(auth): add rate limiting middleware`
  - **Acceptance:**
    - Burst limit: 100 req/min/session (ADR-025)
    - Sustained limit: 1000 req/h/user (ADR-025)
    - Returns 429 with Retry-After header (RN-289)
    - Uses Cloudflare KV for counter storage (ADR-036)
  - **Refs:** FASE-0, ADR-025, INV-SEC-003, REQ-NFR-042
  - **Revert:** SAFE — endpoints work without rate limiting (less secure)
  - **Review:**
    - [ ] Limits match ADR-025 values exactly
    - [ ] 429 response includes Retry-After header
    - [ ] KV namespace configured
    - [ ] Tenant isolation maintained (INV-SYS-001)
```

### Bad Task

```markdown
- [ ] TASK-F0-012 Setup security stuff
  (no commit message, no acceptance criteria, no refs, no revert strategy)
```

---

## Error Recovery

| Error | Cause | Recovery |
|-------|-------|---------|
| "No FASE files found" | Plan architect not run | Run `sdd-plan-architect` |
| "No plan artifacts found" | Plan architect not run | Run `sdd-plan-architect` |
| "FASE references spec not in plan" | Plan incomplete | Run `sdd-plan-architect --fase {N}` |
| "Circular dependency detected" | Task ordering error | Review dependency annotations |
| "Task touches >5 files" | Task too broad | Split into smaller tasks |
| "Orphan task (no FASE)" | Task lost traceability | Assign to correct FASE or remove |
| "Plan is stale" (G-04) | `sdd-req-change` cascade marked `plan-architect` stale | Run `sdd-plan-architect` (affected FASEs), then regenerate tasks |
| "Shared file between Streams" (V-15) | Two work Streams write the same file | Move the shared file's task to `integración`, or merge the two Streams |
| "Task in no/two Streams" (V-16) | Stream table out of date | Re-run Phase 3b (`--regen` or `--fase N`) |
| "Checkpoint in worktree Stream" (V-17) | Verification/checkpoint assigned to A/B/C | Move it to `verificación` |

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["task-generator"].status` = `"done"`
3. Set `stages["task-generator"].lastRun` = current ISO-8601
4. Set `stages["task-generator"].summary`:
   - `artifacts`: list of files created in `task/` with labels (e.g., `{"file": "task/TASK-FASE-1.md", "label": "FASE 1 Tasks"}`)
   - `metrics`: `{ "total_tasks": N, "parallelizable_pct": N, "safe_revert": N, "coupled_revert": N, "streamsPerFase": { "1": 2, "2": 1 } }` (`streamsPerFase` = number of work Streams A, B, C… per FASE; `1` = serial)
   - `highlights`: top 3-5 notable observations (e.g., "42 tasks across 7 FASEs", "65% parallelizable", "8 coupled-revert tasks") plus one line per FASE with more than one work Stream, e.g. "FASE-1: 2 streams (A: 2 tasks, B: 2 tasks)"
   - `nextStep`: `"Run /sdd-task-implementer --fase=0"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
