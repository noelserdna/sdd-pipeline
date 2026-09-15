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

RIGHT: "Create task (API-001-01), test-first" — one behaviour, all its paths on the task line
RIGHT: "Add authentication middleware"
RIGHT: "Register task routes" — a wiring file shared by several slices
```

Each task MUST be completable and committable independently, with its tests written first inside it. If a task requires other uncommitted work, those are **dependencies**, not parts of the same task.

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
RIGHT: One behaviour per task (typically 1-6 files, all listed on the task line)
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
- [ ] TASK-F0-005 [P] Create AuditLog entity schema | `{code_path}/audit_log.{ext}`
- [ ] TASK-F0-006 [P] Create DomainEvent entity schema | `{code_path}/domain_event.{ext}`
```

### Dependency Markers

Tasks that block other tasks use `blocks:` and `blocked-by:` annotations:

```
- [ ] TASK-F0-001 Scaffold the app with pinned dependencies | `{app_dir}/`
  - blocks: TASK-F0-002, TASK-F0-003

- [ ] TASK-F0-002 Configure the web framework per ADR-001 | `{framework config file}`
  - blocked-by: TASK-F0-001
```

---

## Invocation

### Mode 1: Full Generation (default)

```
/sdd-task-generator
```

Generates tasks for ALL FASEs that have plan artifacts. With 2 or more FASEs this runs in **fan-out mode**: one agent per FASE writes its `task/TASK-FASE-{N}.md`, the main thread writes `TASK-ORDER.md` (+ `TASK-INDEX.md` in full format), runs `sdd-task-lint.mjs lint` (V-19) and the global validations (Execution Strategy, `references/fanout-protocol.md`).

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
2. **Preserve completed tasks:** Tasks already done or unchanged are left untouched and NEVER regenerated. Done = `[x]` with `task_state: checkbox` (default); with `task_state: trailers`, `done` in `node "$TASK_LINT" status --fase N --json` (a `Task:` trailer reachable from HEAD, not reverted).
3. **Generate delta only:** Only produce task entries for new plan items or plan items whose scope/acceptance criteria changed since the last generation.
4. **Cascade traceability:** Every new or modified task includes a `Source: CASCADE-{change-report-id}` annotation linking back to the `sdd-req-change` change report that triggered the regeneration.
5. **Update indexes:** Update the `TASK-ORDER.md` dependency graph with the delta; if `TASK-INDEX.md` is present, regenerate it with `node "$TASK_LINT" index > task/TASK-INDEX.md`.
6. **Recompute Stream Ownership:** Re-run Phase 3b for the FASE over the full task set (existing + delta). A completed task keeps its Stream; if a new task would join two existing work Streams, it goes to `integración` and the conflict is reported (V-15/V-18).

**Requirements:**
- `--fase` is mandatory when using `--incremental` (full-generation incremental is not supported).
- An existing `task/TASK-FASE-{N}.md` must already exist; otherwise falls back to standard Mode 2 generation.
- A change report from `sdd-req-change` should be present in `audits/` for proper `CASCADE-{id}` annotation. If absent, tasks are annotated with `Source: CASCADE-MANUAL`.

### Execution Flags (any mode)

| Flag | Effect |
|------|--------|
| `--fanout` | Forces one agent per FASE regardless of the FASE count (useful for benchmarking) |
| `--sequential` | Forces a single thread; the reason is recorded in `metrics.mode` and `summary.highlights` |
| `--compact` | Compact output (same as `task_format: compact` in the Stack Profile; default `full`): no Review block, Revert only when not SAFE, no `TASK-INDEX.md`, short FASE header and `TASK-ORDER.md` (Per-FASE Task File Structure) |

Default (no flag): fan-out with **2 or more FASEs**; sequential with one FASE, with `--fase N` (a single FASE is one unit of work) and with `--incremental`. `--regen` does not change the mode. Same vocabulary as `sdd-spec-auditor` and `sdd-test-planner`; the implementer's equivalent pair is `--parallel` / `--sequential` (`docs/perfilado.md` § Paralelismo por etapa).

**Task lint script** — `TASK_LINT="${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-task-lint.mjs"`, run with `node`: `lint [--dir task]` (V-19, V-09, V-05/V-06, V-16; prints `file:line V-xx message`, exit 1 on errors), `json` (task list), `status [--fase N] [--json]` (done = `Task:` trailer reachable from HEAD, not reverted; checkbox divergences), `index` (TASK-INDEX markdown). Stack Profile keys: `../sdd-task-implementer/references/stack-profile.md`.

---

## Output Artifacts

All artifacts are written to `task/` directory:

```
task/
  TASK-INDEX.md          ← Global index (full format only; derived by `$TASK_LINT index`)
  TASK-ORDER.md          ← Implementation order with dependency graph
  TASK-FASE-0.md         ← Tasks for FASE 0
  TASK-FASE-1.md         ← Tasks for FASE 1
  ...
  TASK-FASE-N.md         ← Tasks for FASE N
```

---

## Execution Phases

### Execution Strategy (read first)

The full protocol is `references/fanout-protocol.md`. The rules that govern every generation:

1. **Index before files.** Phase 0 builds `$PIDX` with one `grep -rn` over `plan/` (headings and table rows, cut at 110 chars). Everything else is opened by section (`sed -n 'a,bp'`, ≤ 60 lines per call) using the index line numbers. **Never `cat` a plan file in the main thread**; a file ≤ 8 k chars may be read whole only by the thread that owns it (sequential mode, or the agent of that FASE).
2. **Budget.** The main thread holds at most ~25 k tokens of plan content (index summaries, the cross-cutting contract, the returned JSONs). Each FASE agent holds its own `FASE-{N}-*.md` + `PLAN-FASE-{N}.md` plus ≤ 200 lines of neighbour lookups.
3. **Fan-out by default — it is part of the skill's contract, not an optional expansion of scope.** Invoking `/sdd-task-generator` on a plan with **2 or more FASEs** *is* the explicit request for the FASE agents: writing `TASK-FASE-{N}.md` is mechanical and the files are independent (no FASE file references another), so each agent is bounded to one FASE, writes exactly one file that no other agent writes, does not nest and does not commit. Never downgrade to sequential out of caution; downgrade only for the reasons in `references/fanout-protocol.md` §1 (a single FASE, `--fase N`, `--incremental`, `--sequential`, or no `Agent` tool), and record the reason in `metrics.mode` and `summary.highlights`. Agents run on `model: sonnet` unless `CLAUDE_CODE_SUBAGENT_MODEL` is set (then omit `model`); consolidation and the global validations always use the main model. **Flags:** `--fanout` forces the FASE agents regardless of the count; `--sequential` forces one thread.
4. **What stays in the main thread.** The cross-cutting contract is fixed *before* the fan-out (id format `TASK-F{N}-{SEQ}`, commit conventions, path conventions, glossary, templates, and each FASE's `## Módulos y Conjuntos de Escritura` table). Afterwards the main thread writes `TASK-ORDER.md` (and, in full format, `TASK-INDEX.md` via `$TASK_LINT index`), runs the **global validations V-04, V-09, V-11, V-15, V-16, V-17, V-18 over the returned JSON** and **V-19 with `node "$TASK_LINT" lint --dir task`**, never by re-reading the generated task files. The FASE agents self-check only the FASE-local validations (V-01..V-03, V-05..V-08, V-10, V-12..V-14) and report them in `checks`.
5. **Compact output.** Each agent returns a JSON of ≤ 8 000 chars (`references/fanout-protocol.md` §6) — task ids, write-sets, `blocked-by`, Streams, counts, checks, gaps — and never the body of its file. `TASK-ORDER.md` is built from those JSONs.

### Phase 0: Inventory & Validation

**Goal:** Verify prerequisites, decide the execution mode and gather all inputs.

Read them **by index**, never whole (Execution Strategy §1): build `$PIDX` with the single `grep -rn` over `plan/` of `references/fanout-protocol.md` §2, read only its two summaries (sections per file, FASE order and status), and open sections with `sed -n` when a check needs them.

```
INPUTS TO READ:
1. plan/fases/FASE-*.md                     (ALL FASE files)
2. plan/fase-plans/PLAN-FASE-*.md           (ALL per-FASE plans)
3. plan/ARCHITECTURE.md                     (architecture views)
4. plan/PLAN.md                             (global plan)
5. spec/domain/01-GLOSSARY.md               (ubiquitous language)
6. task/TASK-FASE-*.md                       (existing tasks if any: `node "$TASK_LINT" json`; TASK-INDEX.md only if present)
7. pipeline-state.json                       (stage status, for G-04; absent = no staleness info)
8. CLAUDE.md ## SDD Stack Profile            (task_format, task_state, app_dir, code_paths, test_paths;
                                              kit templates/stacks/{stack}/kit.json → layers, wiring)
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

**Mode decision (after the gates, before opening any plan section):** count the FASE files and pick fanout or sequential per `references/fanout-protocol.md` §1. In fan-out mode, fix the cross-cutting contract now (`fanout-protocol.md` §4: id format, commit conventions, path conventions from `CLAUDE.md` and its Stack Profile, the output format (`full`/`compact`), the kit `layers` and `wiring`, glossary terms, the `references/` templates, and each FASE's `## Módulos y Conjuntos de Escritura` table) and launch the FASE agents at the start of Phase 1 — Phases 1–7 then run inside them, one FASE each, while the main thread prepares the FASE dependency graph, the Waves, the MVP strategy and the delivery checkpoints for `TASK-ORDER.md`.

> Phases 1–7 below are the generation steps; in fan-out mode each one is executed by the agent that owns the FASE (`fanout-protocol.md` §4) and the main thread runs only the cross-FASE work and Phase 8's global validations. In sequential mode the main thread runs all of them, FASE by FASE, collecting the same JSON shape of `fanout-protocol.md` §6 before writing the global files.

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
1. **Components to build** → tasks, grouped by behaviour
2. **Data models** → inside the first slice that needs them; a Foundation task only when ≥ 2 slices share them
3. **API operations** (`API-NNN-NN`; transport in `design/OPERATION-MAPPING.md` when present) → one vertical slice each
4. **Tests** (§7 + Coverage Map §7.4) → inside the task that implements the covered code, written first
5. **Configuration** → setup tasks, one per concern
6. **Integration points** → wiring tasks

**Decomposition Rules** (examples are illustrative):

| Concern | Task Granularity | Example |
|---------|-----------------|---------|
| Setup / config | 1 task per concern; **merge trivial steps of the same concern** (scaffold + pinned deps + generator init) | "Scaffold the app with pinned dependencies" |
| Entity / model | Inside its first slice; own Foundation task only when shared by ≥ 2 slices | "Create Task model with title invariants" |
| API operation | **1 vertical slice per operation**, layers in the kit `layers` order (rails: migration → model → controller → views; nextjs-prisma: schema → domain/data → server actions → components/page; no kit: `plan/ARCHITECTURE.md`) | "Create task (API-001-01), test-first" |
| Middleware / cross-cutting | 1 task per concern | "Add 404/503 error handling" |
| Tests | **Inside the implementing task** (test first, same commit). Separate test tasks only for cross-Stream suites, BDD/E2E journeys and Coverage Map exclusions verified elsewhere | "Journey WF-001 end to end" |
| Wiring | 1 task per shared entry point touched by ≥ 2 slices (kit `wiring` list) | "Register task routes" |

**Size Heuristic:** split a task above **6 files** or **2 API operations** (V-08 warns above 8); two trivially related operations sharing all their files may share one slice. A description over 2 sentences may be too broad.

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

1. **Setup**: scaffold, dependencies, configuration (merged per concern)
2. **Foundation**: shared infrastructure used by ≥ 2 slices (schema, base layout, error handling, shared models)
3. **Slices**: one vertical slice per API operation / behaviour, test-first inside, kit `layers` order
4. **Integration**: wiring touching ≥ 2 slices (routes table, layout, navigation, barrels)
5. **Verification**: cross-Stream suites, BDD/E2E journeys, FASE Criterios de Éxito, checkpoint

Legacy labels are accepted when reading existing files: Domain and Contracts count as Slices, Tests as Verification (a test task covering one Stream joins it, Phase 3b step 5).

### Phase 3b: Stream Assignment

**Goal:** Partition the tasks of each FASE into **Streams** with pairwise-disjoint write-sets, so that each work Stream can be implemented in its own git worktree (`sdd-task-implementer --fase N --stream A`) and merged back by `--integrate --fase N`. The result is the `## Stream Ownership` table (source of truth for the implementer's task filter) and the `Streams:` line in `TASK-ORDER.md`.

**Write-set of a task** = every backticked path after the `|` on the task line (comma-separated when the task touches more than one file) plus every path listed in its optional `- **Files:**` bullet. Paths mentioned only in Acceptance/Refs/Review are reads, not writes.

**Algorithm (per FASE, after Phase 3 assigned every task to an internal phase):**

```
1. base := tasks of internal phases Setup (1) and Foundation (2).
   - Run in the main checkout BEFORE any worktree is opened.
   - The implementer tags the last base commit with checkpoint `fase-{N}-foundation`
     (branch point of every worktree of this FASE).

2. Work graph G over the tasks of Slices (3) and Integration (4)
   (legacy: Domain, Contracts, Integration and single-Stream Tests):
   - node  = task
   - edge(A, B) if write-set(A) ∩ write-set(B) ≠ ∅
                or A is `blocked-by` B (or B is `blocked-by` A)
   - connected components of G → candidate Streams

3. Wiring extraction (repeat until no candidate passes):
   - Candidate: a task whose write-set contains a shared entry point / index / barrel:
     every path of the kit / Stack Profile `wiring` list, prefixed by `app_dir`
     (rails: `config/routes.rb`, `db/schema.rb`, `app/views/layouts/application.html.erb`;
     nextjs-prisma: `src/app/layout.tsx`, `prisma/schema.prisma`), or, without a kit,
     `src/index.ts`, `src/app.ts`, `src/routes/index.ts`, `migrations/index.*`, any barrel
     re-exporting ≥ 2 directories; or a task whose `blocked-by` spans ≥ 2 top-level source directories.
   - Test: remove the candidate from G. If the tasks it was connected to now fall into
     ≥ 2 components, the candidate touches ≥ 2 components → it leaves its component
     and goes to Stream `integración` (main checkout, after `--integrate --fase N`).
   - A component emptied by the extraction disappears. If NO work task is left
     (every work task was wiring), keep them all in Stream A and leave `integración` empty.

4. Letter the remaining components A, B, C… by task count, largest first
   (tie → the component containing the lowest task ID).

5. Tests live inside their slice and follow it. A separate test task (legacy, or an exclusion)
   whose test files cover source files of exactly ONE work Stream (Coverage Map §7.4) joins that
   Stream, its test paths added to the Owns; any other one → Stream `verificación`.

6. Verification (internal phase 5) → Stream `verificación` (main checkout, implementer Phase 9).
   Rollback checkpoints belong to the main checkout only: `fase-{N}-foundation` after the
   last base task and `fase-{N}-verified` after Verification. Worktrees never create tags.
```

**Owns (write-set) column:** the smallest set of globs that covers every file of the Stream's write-set and matches no file of any other Stream (e.g. `src/api/**`). List exact paths when a directory is shared (typical for `base` and `integración`, e.g. `package.json, src/index.ts`).

**Branch names:** `feat/fase-{N}-{stream}` with the Stream letter in lower case (`feat/fase-1-a`, `feat/fase-1-b`). Only work Streams (A, B, C…) get a worktree; `base`, `integración` and `verificación` run in the main checkout.

**Single-Stream FASE:** a FASE whose work graph yields one component is valid. The table is written the same way (base + A + integración/verificación) and `TASK-ORDER.md` marks it `Streams: serial`.

**Stream Ownership table** (mandatory in every `TASK-FASE-{N}.md`, right after "Parallel Execution Plan"; it replaces the former free-text Stream lists — do NOT add new markers to the task lines; example paths):

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

**Types and scopes:** `references/commit-conventions.md` (`feat`, `fix`, `refactor`, `test`, `chore`, `docs`, `ci`, `perf`, `style`; scope = the FASE's module or bounded context, e.g. `auth`, `tasks`).

**Examples:**

```
feat(auth): add rate limiting middleware

Refs: FASE-0, ADR-025, INV-SEC-003
Task: TASK-F0-012

chore(bootstrap): scaffold app with pinned dependencies

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

**Compact format:** write the `- **Revert:**` line only when the category is not SAFE; an absent Revert line means SAFE (V-07).

**Revert Safety Categories:**

| Category | Meaning | Action |
|----------|---------|--------|
| `SAFE` | Can revert independently, no side effects | Single `git revert` |
| `COUPLED` | Must revert with related tasks | Revert in reverse order |
| `MIGRATION` | Has database state change | Requires down migration first |
| `CONFIG` | Changes runtime config | Requires restart/redeploy after revert |

### Phase 6: Review Checklist Generation

**Goal:** Generate per-task review checklist for human reviewers.

Every task includes a review checklist following this pattern (full format; compact omits the Review block and reviewers use `references/review-checklist.md`):

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

**Domain-Specific Review Items** per task type (entity, API operation, migration, event, PII, multi-tenant, test): `references/review-checklist.md`.

### Phase 7: Document Generation

**Goal:** Write all task/ artifacts.

Generate documents using templates from `references/`:

| Artifact | Written by | Content |
|----------|-----------|---------|
| **Per-FASE task file** (`TASK-FASE-{N}.md`) | the FASE agent (fan-out) or the main thread (sequential) | All tasks for one FASE, including the `## Stream Ownership` table from Phase 3b and the Rollback Checkpoints |
| **Global index** (`TASK-INDEX.md`, full format only) | **always the main thread** | `node "$TASK_LINT" index > task/TASK-INDEX.md`: Summary by FASE, flat task list, traceability matrix from Refs — derived, never hand-written |
| **Implementation order** (`TASK-ORDER.md`) | **always the main thread** | FASE dependency graph, Waves, critical path, one `Streams:` line per FASE, Cross-FASE Dependencies with the Stream of every task, MVP strategy, delivery checkpoints |

A FASE agent writes **only** its own `TASK-FASE-{N}.md`: it never writes the two global files, never `pipeline-state.json`, never `spec/` or `plan/`, and never sends a handoff.

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
| V-07 | Every task has a revert strategy (compact: absent Revert = SAFE) | WARN |
| V-08 | No task touches more than 8 files (split rule: > 6 files or > 2 API operations) | WARN |
| V-09 | All task IDs follow TASK-F{N}-{SEQ} format | ERROR |
| V-10 | Task count per FASE is reasonable (5-80 tasks) | WARN |
| V-11 | Critical path identified in TASK-ORDER.md | ERROR |
| V-12 | All file paths use project conventions from CLAUDE.md | WARN |
| V-13 | Every source file in Coverage Map §7.4 has its test inside the implementing task (test path on its line / `Files:`), in a cross-Stream test task, or an exclusion | ERROR |
| V-14 | Every file in Coverage Map Exclusions has a justified reason | WARN |
| V-15 | Write-sets of the work Streams (A, B, C…) are pairwise disjoint (no file, no glob overlap) | ERROR |
| V-16 | Every task belongs to exactly one Stream (`base`, A…Z, `integración`, `verificación`); no task missing from the table, none listed twice | ERROR |
| V-17 | Verification-phase tasks and rollback checkpoints appear only in Stream `verificación` / the main checkout; no checkpoint is assigned to a worktree Stream | ERROR |
| V-18 | Every `blocked-by` of a Stream task points to the same Stream, to `base`, or to a task of an earlier FASE | WARN |
| V-19 | Every task line matches the grammar (Per-FASE Task File Structure); no `### TASK-` headings, no `**TASK-…**` ids | ERROR |

**Who runs which check.** The FASE-local checks are self-checked by the thread that generated the FASE (a FASE agent in fan-out mode) and reported in its `checks` field; the **global checks stay in the main thread and are computed from the returned JSON**, because they span FASEs or would otherwise let an agent grade its own homework:

| Owner | Checks | Computed from |
|-------|--------|---------------|
| FASE agent (or main thread in sequential mode) | V-01, V-02, V-03, V-05, V-06, V-07, V-08, V-10, V-12, V-13, V-14 | its own tasks vs its FASE file and `PLAN-FASE-{N}.md` §7.4 |
| **Main thread, always** | **V-04** (cycles, including edges that cross a FASE boundary), **V-09** (id format + uniqueness across FASEs), **V-11** (critical path), **V-15** (work-Stream write-sets pairwise disjoint), **V-16** (every task in exactly one Stream), **V-17** (checkpoints and verification tasks only in the main checkout), **V-18** (`blocked-by` scope, including cross-FASE) | the union of `tasks[]`, `bb`, `streams[]` and `checkpoints[]` of every FASE JSON |

V-15..V-18 are computed from the Stream data of each FASE (the `## Stream Ownership` table, returned as `streams[]` in the JSON). `--audit` recomputes the table (Phase 3b) from the current task write-sets — one agent per FASE above the threshold, same JSON — compares it with the published one in the main thread, and reports both the drift and any V-15..V-18 finding without writing anything.

**V-19 is mechanical:** once the FASE files exist, the main thread runs `node "$TASK_LINT" lint --dir task` (it also re-checks V-05, V-06, V-09 and V-16 on the files) and edits only the lines it reports — never regenerates a FASE for it. `--audit` runs it read-only.

---

## Per-FASE Task File Structure

Templates: `references/task-template.md` (full and compact). Both formats share the task-line grammar and the `## Stream Ownership` / `### Rollback Checkpoints` tables that `sdd-task-implementer` parses.

**Task line grammar (V-19, normative).** One line per task at column 0; continuation lines indented two spaces:

```markdown
- [ ] TASK-F{N}-{SEQ} [P] {Description} | `{path}`, `{path}`
  - blocked-by: TASK-F{N}-{SEQ}, …                     (optional)
  - **Files:** `{path}`, …                             (optional; extra write-set)
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:** {criteria; the test written first comes first; nested bullets indented four spaces}
  - **Refs:** FASE-{N}, {UC, API, INV, ADR, REQ}
  - **Revert:** {SAFE|COUPLED|MIGRATION|CONFIG} — {impact}  (compact: only when not SAFE)
  - **Review:** [ ] {check} [ ] {check}                 (full format only)
```

```text
^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$
```

`[ ]` pending · `[x]` done (checkbox state) · `[!]` blocked. Forbidden: `### TASK-…` headings, `**TASK-…**` bold ids, indented task lines, paths outside backticks; a `[PLAN GAP]` line may omit the path (WARN). Commit trailers stay `Refs:` + `Task: TASK-F{N}-{SEQ}`.

**Full format** (default), in order: header (`> **Input:**`, `> **Total tasks:**`, `> **Parallel capacity:**`, `> **Critical path:**`), `## Summary`, `## Traceability`, one `## Phase N: {Setup|Foundation|Slices|Integration|Verification}` section per internal phase (Purpose + Checkpoint, then its task lines; Verification ends with the Test Exclusions table), `## Dependencies` (Task Dependency Graph, Critical Path, Parallel Execution Plan), `## Stream Ownership`, `### Rollback Checkpoints`.

**Compact format** (`--compact` or `task_format: compact`): `# Tasks: FASE-{N} — {Title}`, one `> **Critical path:** …` line, `## Stream Ownership`, `### Rollback Checkpoints`, then `## Setup` … `## Verification` with task lines only — no Summary, Traceability, dependency graph, Parallel Execution Plan or Review blocks; Revert only when not SAFE. Derived views come from `$TASK_LINT json|index|status`.

---

## TASK-INDEX.md

Full format only, always derived: `node "$TASK_LINT" index > task/TASK-INDEX.md` (Summary by FASE, flat task list, traceability matrix from the Refs lines). Compact format writes no index; consumers call `index` or `json`. Its absence is never an inconsistency.

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

**Compact format:** `TASK-ORDER.md` ≤ 1 500 chars — keep `## FASE Dependency Graph` (one line per FASE), one Wave entry per FASE with its `Critical path:` and `Streams:` lines, and Cross-FASE Dependencies only when non-empty; drop MVP Strategy and Incremental Delivery Checkpoints. V-11 and `--audit` read only what is kept.

---

## Multi-Agent Strategy

Fan-out by FASE is the default execution mode with 2 or more FASEs (Execution Strategy). Full protocol — mode decision, index commands, budgets, the split of work, launch parameters, the agent prompt, the JSON shape and consolidation — in `references/fanout-protocol.md`.

```
Main thread (before):  gates G-01..G-05 · plan index · cross-cutting contract
                       (TASK-F{N}-{SEQ} numbering, commit conventions, path conventions,
                        glossary, templates, each FASE's "Módulos y Conjuntos de Escritura")
                              │
        ┌─────────────────────┼─────────────────────┐        (max 4 concurrent)
   Agent-F0              Agent-F1              Agent-F2
   FASE-0 + PLAN-FASE-0  FASE-1 + PLAN-FASE-1  FASE-2 + PLAN-FASE-2
   → task/TASK-FASE-0.md → task/TASK-FASE-1.md → task/TASK-FASE-2.md
   → JSON (tasks, write-sets, blocked-by, Streams, counts, checks, gaps)
        └─────────────────────┼─────────────────────┘
                              │
Main thread (after):   V-04 · V-09 · V-11 · V-15..V-18 over the JSONs · V-19 (sdd-task-lint.mjs lint)
                       TASK-INDEX.md (full format: sdd-task-lint.mjs index)
                       TASK-ORDER.md (Waves, Streams: lines, Cross-FASE Dependencies, MVP)
                       Persist Summary (metrics.mode, metrics.task_agents)
```

| | FASE agent | Main thread |
|---|---|---|
| Unit | one FASE | the whole plan |
| Reads | `plan/fases/FASE-{N}-*.md`, `plan/fase-plans/PLAN-FASE-{N}.md`, the ARCHITECTURE and `spec/` sections it cites | the plan index, the FASE `Dependencias` lines, the returned JSONs |
| Writes | only `task/TASK-FASE-{N}.md` | `task/TASK-ORDER.md`, `task/TASK-INDEX.md` (full), `pipeline-state.json`, V-19 line fixes |
| Validations | the FASE-local ones (V-01..V-03, V-05..V-08, V-10, V-12..V-14), reported in `checks` | the global ones (V-04, V-09, V-11, V-15..V-19) |
| Model | `sonnet` (omit when `CLAUDE_CODE_SUBAGENT_MODEL` is set) | the session's own model |
| Never | writes another FASE's file, the global files, `spec/`, `plan/` or `pipeline-state.json`; nests agents; commits; sends a handoff | re-generates a FASE that has an agent, or re-reads a task file it can read from the JSON |

No cross-file conflicts: each agent owns a different `TASK-FASE-{N}.md`. With more than 4 FASEs, launch in batches of 4 in FASE order. An agent that fails twice is replaced by sequential generation of that FASE, recorded in `summary.highlights`.

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

Single task: `git revert <sha> --no-edit`; COUPLED tasks in reverse commit order; checkpoints and whole-FASE rollback: `references/commit-conventions.md`.

---

## Output Location Rules

| Artifact | Path | Overwrites |
|----------|------|------------|
| Per-FASE tasks | `task/TASK-FASE-{N}.md` | Yes (regenerated) |
| Global index (full format) | `task/TASK-INDEX.md` | Yes (derived by `$TASK_LINT index`) |
| Implementation order | `task/TASK-ORDER.md` | Yes (regenerated) |

**NEVER modify:**
- `spec/` (any file)
- `plan/` (any file)
- `audits/` (any file)

---

## Quality Signals

### Good Task

```markdown
- [ ] TASK-F1-006 Create task (API-001-01) with server-side title validation, test-first | `test/controllers/tasks_controller_test.rb`, `app/controllers/tasks_controller.rb`, `app/views/tasks/_form.html.erb`
  - blocked-by: TASK-F1-002
  - **Commit:** `feat(tasks): create task with server-side title validation`
  - **Acceptance:**
    - Test first: a blank title answers 422 and re-renders the form with the alert (AC-001-02)
    - A valid title redirects to the list with the task last (INV-TSK-004)
  - **Refs:** FASE-1, UC-001, API-001-01, INV-TSK-002
  - **Revert:** SAFE — the create form disappears; list and other operations keep working
  - **Review:**
    - [ ] The controller test failed before the action existed (Art. 8)
    - [ ] Status, redirect and message match API-001-01 / `design/OPERATION-MAPPING.md`
```

(Illustrative Rails slice; paths come from the Stack Profile and the kit `layers`.)

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
| "Task touches >8 files" (V-08) | Task too broad | Split by API operation or by layer (> 6 files) |
| "Task line does not match grammar" (V-19) | Heading, bold id or missing write-set path | Rewrite only the lines `$TASK_LINT lint` prints |
| "Orphan task (no FASE)" | Task lost traceability | Assign to correct FASE or remove |
| "Plan is stale" (G-04) | `sdd-req-change` cascade marked `plan-architect` stale | Run `sdd-plan-architect` (affected FASEs), then regenerate tasks |
| "Shared file between Streams" (V-15) | Two work Streams write the same file | Move the shared file's task to `integración`, or merge the two Streams |
| "Task in no/two Streams" (V-16) | Stream table out of date | Re-run Phase 3b (`--regen` or `--fase N`) |
| "Checkpoint in worktree Stream" (V-17) | Verification/checkpoint assigned to A/B/C | Move it to `verificación` |
| "FASE agent returned invalid JSON" | Truncated or prose-wrapped answer | Re-launch that agent once with the same prompt; on a second failure generate the FASE in the main thread and note it in `summary.highlights` (`fanout-protocol.md` §5) |
| "TASK-FASE-N.md missing after fan-out" | The agent wrote nothing or wrote elsewhere | Same recovery as above; never accept a JSON whose `file` does not exist (`fanout-protocol.md` §7.2) |
| "Two FASEs use the same task id" (V-09) | An agent ignored the numbering contract | Re-run that FASE with the cross-cutting contract restated verbatim in the prompt |

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["task-generator"].status` = `"done"`
3. Set `stages["task-generator"].lastRun` = current ISO-8601
4. Set `stages["task-generator"].summary`:
   - `artifacts`: list of files created in `task/` with labels (e.g., `{"file": "task/TASK-FASE-1.md", "label": "FASE 1 Tasks"}`)
   - `metrics`: `{ "total_tasks": N, "parallelizable_pct": N, "safe_revert": N, "coupled_revert": N, "streamsPerFase": { "1": 2, "2": 1 }, "mode": "fanout"|"sequential", "task_agents": N, "format": "full"|"compact" }`
     - `streamsPerFase` = number of work Streams A, B, C… per FASE; `1` = serial
     - `mode` = execution mode actually used (`fanout` even when one FASE had to be regenerated sequentially after two agent failures — say so in `highlights`)
     - `task_agents` = number of FASE agents actually launched (`0` in sequential mode); this is the number the status line and `scripts/sdd-watch.sh` show live as `N agentes` while the skill runs (`docs/multisesion.md`)
   - `highlights`: top 3-5 notable observations (e.g., "42 tasks across 7 FASEs", "65% parallelizable", "8 coupled-revert tasks") plus one line per FASE with more than one work Stream, e.g. "FASE-1: 2 streams (A: 2 tasks, B: 2 tasks)". **When the mode was degraded to sequential, the first highlight is the reason** (e.g., "sequential: single FASE", "sequential: --sequential flag", "sequential: Agent tool not available", "FASE-2 regenerated sequentially: agent failed twice")
   - `nextStep`: `"Run /sdd-task-implementer --fase=0"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
