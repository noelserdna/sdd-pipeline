---
name: sdd-task-generator
description: "Generates implementation task documents from FASE files and plans: atomic tasks (1 task = 1 commit) with commit messages, spec traceability, revert strategies and Stream Ownership for parallel worktrees. Outputs to task/. Does not write code, specs or plan. Triggers: 'generate tasks', 'create tasks', 'task from plan', 'decompose FASEs', 'generar tareas', 'crear tareas', 'descomponer fases'."
---

# SDD Task Generator Skill

> Las tareas son el puente entre el plan y el commit: cada tarea = un commit atomico, reversible y revisable por una persona.
> Specs = fuente de verdad (QUE). FASE = orden (CUANDO). Plan = diseño (COMO). Task = unidad de trabajo (QUIEN/DONDE).

Reads `plan/` (from `sdd-plan-architect`) and writes only `task/`. Code is written later by `sdd-task-implementer`; spec changes go through `sdd-req-change`.

**Journal.** When a run begins, tell the customer in one plain sentence what it is about to do: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage task-generator --kind start --text "Vamos a desglosar cada entrega en pasos de trabajo pequeños"`. Persist adds the `done` line (plugin-root `references/status-page.md` §1).

## Core Principles

1. **One task = one commit.** Each task is completable and committable on its own, one behaviour (typically 1-6 files, all on the task line), its tests written first inside it. Work it needs from another uncommitted task is a dependency (`blocked-by`), not part of it.
2. **Reversible.** Every commit can be undone with `git revert <sha>`; migrations ship their down step. Each task carries a revert category (SAFE, COUPLED, MIGRATION, CONFIG). In the full format every task has a `Revert:` line; in the compact format the line is written only when the category is not SAFE, and an absent line means SAFE (CLAUDE.md, V-07).
3. **Human reviewable.** Specific acceptance criteria and checks a reviewer can run.
4. **Traceable.** Every task cites its FASE and the spec IDs it implements (UC, API, INV, ADR, REQ); commits carry `Refs:` and `Task:` trailers.
5. **Plan and specs are the source.** Derive tasks from what the plan and FASE specify; do not invent content or contradict ADRs. Missing plan content becomes a `[PLAN GAP]` task (Handling Plan Gaps). Never write to `spec/`, `plan/` or `audits/`.
6. **Ubiquitous language.** Use only the terms in `spec/domain/01-GLOSSARY.md`. When the route skipped the specifications (no `spec/`), use the terms of `requirements/REQUIREMENTS.md`, and tasks cite REQ ids in `Refs:` and `REQ-X-NNN ACn` criteria in their Acceptance, as the FASE's `Escenarios` do.

## Task IDs and Markers

`TASK-F{N}-{SEQ}`: FASE number and a 3-digit sequence within the FASE (`TASK-F0-001`, `TASK-F3-015`); unique across FASEs (V-09). Tasks with disjoint files and no shared state get `[P]` right after the id. Dependencies are continuation lines:

```
- [ ] TASK-F0-001 Scaffold the app with pinned dependencies | `{app_dir}/`
  - blocks: TASK-F0-002
- [ ] TASK-F0-002 [P] Configure the web framework per ADR-001 | `{framework config file}`
  - blocked-by: TASK-F0-001
```

---

## Invocation

| Mode | Command | Behaviour |
|------|---------|-----------|
| 1 Full (default) | `/sdd-task-generator` | Every FASE with plan artifacts; fan-out with ≥ 2 FASEs (Execution Strategy) |
| 2 Per-FASE | `/sdd-task-generator --fase 0` | One FASE |
| 3 Regeneration | `/sdd-task-generator --regen` | Discards `task/` and regenerates |
| 4 Audit | `/sdd-task-generator --audit` | Read-only; reports tasks citing deleted/renamed specs, plan sections without tasks, broken dependency chains, orphan tasks, and Stream Ownership drift (recomputes Phase 3b from the current write-sets, compares with the published table and the `Streams:` lines of `TASK-ORDER.md`, runs V-15..V-18) |
| 5 Incremental | `/sdd-task-generator --fase=1 --incremental` | Delta for one FASE after a cascade (below) |

### Mode 5: Incremental Generation (cascade)

Typically invoked by `sdd-req-change` Phase 9, once per affected FASE (`--fase` is mandatory; a missing `task/TASK-FASE-{N}.md` falls back to Mode 2). Also invoked from the FASE gate for a confirmed defect, and by `sdd-acceptance --loop` for a MISSING criterion: then the plan has not changed, and the input is the defect text or the ledger's target (requirement, criterion, scenario id). Write one fix task per defect or missing criterion, citing the scenario ids in Acceptance and Refs, with `Source: FEEDBACK-FASE-{N}` (defect) or `Source: ACCEPTANCE-LOOP` (missing), then continue with steps 5-6. A confirmed finding of the adversarial round (a loop target with route `adversarial-finding`, or `sdd accept challenge list --open`) is handled the same way with `Source: ACCEPTANCE-ADVERSARIAL-FASE-{N}`: one fix task per finding, citing its `CH-NNN`, category and `path:line` evidence in Acceptance, so the fix answers what the verifier saw. A `SPEC-QUESTION` finding gets no task: it is a question for a person and goes through `sdd-req-change`. A fix task with `Source: FEEDBACK-FASE-{N}` or `Source: ACCEPTANCE-ADVERSARIAL-FASE-{N}` opens its Acceptance with `Reproduce first:` instead of `Test first:` (template: `references/task-template.md`, § Fix task): its criterion's test may already be green, so the task names the test that reproduces the defect and must fail before the fix. `ACCEPTANCE-LOOP` tasks keep `Test first:`, since a missing criterion has no green test yet. A `WEAKENED-ASSERT` or `WRONG-CAPTURE` finding is the exception: the code is right and the test is what gets fixed, so the task has no `Reproduce first:` and its test edit is approved by a person (`references/task-template.md`, § Fix task). The implementer's `--new-tasks-only` runs tasks of every `Source:` value.

1. Compare `plan/fase-plans/PLAN-FASE-{N}.md` with the existing `task/TASK-FASE-{N}.md`.
2. Leave done and unchanged tasks untouched. Done = `[x]` with `task_state: checkbox` (default); with `task_state: trailers`, `done` in `node "$SDD_CLI" tasks status --fase N --json` (a `Task:` trailer reachable from HEAD, not reverted).
3. Write task entries only for new plan items or items whose scope/acceptance changed.
4. Annotate every new or modified task with `Source: CASCADE-{CHG-ID}`, where `CHG-ID` (`CHG-YYYY-MM-DD-NNN`) comes from the most recent `changes/CHANGE-REPORT-{CHG-ID}.md` written by `sdd-req-change`; without one, `Source: CASCADE-MANUAL`.
5. Update the `TASK-ORDER.md` dependency graph with the delta; if `TASK-INDEX.md` exists, regenerate it with `node "$SDD_CLI" tasks index > task/TASK-INDEX.md`.
6. Re-run Phase 3b over the full task set. A completed task keeps its Stream; a new task that would join two existing work Streams goes to `integración` and the conflict is reported (V-15/V-18).

### Execution Flags (any mode)

| Flag | Effect |
|------|--------|
| `--fanout` | One agent per FASE regardless of the count |
| `--sequential` | Single thread; reason recorded in `metrics.mode` and `summary.highlights` |
| `--compact` | Same as `task_format: compact` in the Stack Profile (default `full`): no Review block, Revert only when not SAFE, no `TASK-INDEX.md`, short header and `TASK-ORDER.md` |

Default: fan-out with 2 or more FASEs; sequential with one FASE, `--fase N` or `--incremental`. `--regen` does not change the mode. The implementer's equivalent pair is `--parallel` / `--sequential` (`docs/perfilado.md`).

**SDD CLI** — `SDD_CLI="${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs"`, run with `node`: `lint [--dir task]` (V-19, V-09, V-05/V-06, V-16; prints `file:line V-xx message`, exit 1 on errors), `tasks json` (task list), `tasks status [--fase N] [--json]` (done = `Task:` trailer reachable from HEAD, not reverted), `tasks index` (TASK-INDEX markdown). `scripts/sdd-task-lint.mjs` remains as an alias. Stack Profile keys: `../sdd-task-implementer/references/stack-profile.md`.

## Output Artifacts

```
task/
  TASK-FASE-{N}.md   ← one per FASE (regenerated)
  TASK-ORDER.md      ← implementation order, Waves, Streams (regenerated)
  TASK-INDEX.md      ← full format only; derived by `$SDD_CLI tasks index`, never hand-written
```

---

## Execution Phases

### Execution Strategy (read first)

Full protocol: `references/fanout-protocol.md`.

1. **Index before files.** Phase 0 builds `$PIDX` with one `grep -rn` over `plan/` (headings and table rows, cut at 110 chars) and opens sections with `sed -n 'a,bp'` (≤ 60 lines per call) at the indexed lines. The main thread does not `cat` plan files; a file ≤ 8 k chars may be read whole only by the thread that owns it.
2. **Budget.** The main thread holds at most ~25 k tokens of plan content (index summaries, the cross-cutting contract, the returned JSONs). Each FASE agent holds its own `FASE-{N}-*.md` + `PLAN-FASE-{N}.md` plus ≤ 200 lines of neighbour lookups.
3. **Fan-out is the contract, not an optional expansion.** Invoking the skill on 2 or more FASEs is the request for one agent per FASE: each is bounded to one FASE, writes exactly one file no other agent writes, does not nest and does not commit. Downgrade to sequential only for the reasons in `fanout-protocol.md` §1 (single FASE, `--fase N`, `--incremental`, `--sequential`, no `Agent` tool) and record the reason. Agents run on `model: sonnet` unless `CLAUDE_CODE_SUBAGENT_MODEL` is set (then omit `model`); up to 4 concurrent, in FASE order. Consolidation and global validations use the main model.
4. **Main thread.** Fixes the cross-cutting contract before the fan-out (id format, commit and path conventions, glossary, templates, output format, kit `layers`/`wiring`, each FASE's `## Módulos y Conjuntos de Escritura` table). Afterwards it writes `TASK-ORDER.md` (and `TASK-INDEX.md` in full format), runs the global validations over the returned JSON and V-19 with `node "$SDD_CLI" lint --dir task`, without re-reading the generated files.
5. **Compact returns.** Each agent returns a JSON ≤ 8 000 chars (`fanout-protocol.md` §6) — ids, write-sets, `blocked-by`, Streams, counts, checks, gaps — never its file body. An agent that fails twice is replaced by sequential generation of that FASE, noted in `summary.highlights`.

### Phase 0: Inventory & Validation

Build `$PIDX` (`fanout-protocol.md` §2), read its two summaries, open sections only when a check needs them.

```
INPUTS:
1. plan/fases/FASE-*.md                 (all FASE files)
2. plan/fase-plans/PLAN-FASE-*.md       (all per-FASE plans)
3. plan/ARCHITECTURE.md, plan/PLAN.md
4. spec/domain/01-GLOSSARY.md
5. task/TASK-FASE-*.md                  (existing tasks: `node "$SDD_CLI" tasks json`)
6. pipeline-state.json                  (for G-04; absent = no staleness info)
7. CLAUDE.md ## SDD Stack Profile       (task_format, task_state, app_dir, code_paths, test_paths;
                                         kit templates/stacks/{stack}/kit.json → layers, wiring)
8. design/OPERATION-MAPPING.md          (transport per API-op; written by sdd-tech-designer, or by
                                         sdd-plan-architect when the tech designer did not run)
9. plan style                           grep -m1 -i 'Plan-Style' plan/PLAN.md → vertical | vertical (from FASE-N)
                                         | absent (horizontal)
```

**Plan style.** With `Plan-Style: vertical` each FASE is an increment (one user journey, `sdd-plan-architect/references/phase-assignment-rules.md`) and the rules marked *vertical* below apply; `vertical (from FASE-N)` applies them from FASE-N on. Without the marker the plan is horizontal: generate as before (Foundation may hold everything shared, Slices ungrouped). Pass the style to every FASE agent in the cross-cutting contract.

| Gate | Condition | If failed |
|------|-----------|-----------|
| G-01 | At least one FASE file exists | HALT: run `sdd-plan-architect` |
| G-02 | Plan artifacts exist for the target FASE(s) | HALT: run `sdd-plan-architect` |
| G-03 | Glossary exists | WARN |
| G-04 | `stages["plan-architect"].status != "stale"` in `pipeline-state.json` | HALT: run `sdd-plan-architect` (plan is stale: `{staleReason}`) — tasks from a stale plan would publish write-sets and Streams that no longer match the specs |
| G-05 | FASE files newer than `spec/` (mtime; only without `pipeline-state.json`) | WARN: consider `sdd-plan-architect --audit-fases` |

**Mode decision** (after the gates): pick fanout or sequential per `fanout-protocol.md` §1. In fan-out mode fix the cross-cutting contract (§4) and launch the FASE agents; Phases 1–7 then run inside them, one FASE each, while the main thread prepares the FASE dependency graph, Waves, MVP strategy and checkpoints for `TASK-ORDER.md`. In sequential mode the main thread runs Phases 1–7 FASE by FASE, collecting the same JSON shape (§6).

### Phase 1: FASE Analysis

From each FASE file: **Criterios de Exito** → acceptance groups; **Specs a Leer** → Refs; **Invariantes Aplicables** → validation constraints; **Contratos Resultantes** → deliverable tasks; **Alcance** → scope boundary; **Dependencias** → FASE ordering. *Vertical:* the header's **Requisitos** go into the Refs of the tasks that deliver them, and every scenario of **Escenarios** (`AC-NNN-NN`, `REQ-X-NNN ACn`) must be cited by at least one task's Acceptance or Refs (V-20), so the implementer names a test after it and the acceptance ledger can find it. The `## Demo` is not decomposed into tasks: `sdd-task-implementer` Phase 9 runs it, and the journey task (Phase 2) starts at its first step; a demo step that needs seed data gets it from the task whose slice owns that data (fixture file in its write-set).

### Phase 2: Plan Decomposition

From each `PLAN-FASE-{N}.md`: components → tasks grouped by behaviour; data models → inside the first slice that needs them (own Foundation task only when ≥ 2 slices share them); API operations (`API-NNN-NN`, transport per `design/OPERATION-MAPPING.md`) → one vertical slice each; tests (§7 + Coverage Map §7.4) → inside the implementing task, written first; configuration → one setup task per concern; integration points → wiring tasks.

| Concern | Granularity | Example |
|---------|-------------|---------|
| Setup / config | 1 task per concern; merge trivial steps of the same concern | "Scaffold the app with pinned dependencies" |
| Entity / model | Inside its first slice; Foundation only when shared by ≥ 2 slices | "Create Task model with title invariants" |
| API operation | 1 vertical slice per operation, layers in the kit `layers` order (rails: migration → model → controller → views; nextjs-prisma: schema → domain/data → server actions → components/page; no kit: `plan/ARCHITECTURE.md`) | "Create task (API-001-01), test-first" |
| Middleware / cross-cutting | 1 task per concern | "Add 404/503 error handling" |
| Tests | Inside the implementing task (same commit). Separate test tasks only for cross-Stream suites, BDD/E2E journeys and Coverage Map exclusions verified elsewhere | "Journey WF-001 end to end" |
| Wiring | 1 task per shared entry point touched by ≥ 2 slices (kit `wiring`) | "Register task routes" |
| Port with a double | 1 `CONTRACT-<port>` task per row of PLAN-FASE §4 `Puertos con doble` | "Contract test LlmClient: double and real provider build the same request" |

Split a task above 6 files or 2 API operations (V-08 warns above 8); two trivially related operations sharing all their files may share a slice.

**Contract task per port.** A slice tested against a double stays green when the real provider sends something else (a missing prompt field, config read from the wrong place), and nothing else in the chain would notice. So each row of `Puertos con doble` gets a sister task `CONTRACT-<port>`: `blocked-by` the task that writes the double and the one that writes the real provider; its write-set is one test file under the Stack Profile's `test_paths`, in `contract/` and named by the stack's test-file convention (`<port>.contract.test.ts` in JS/TS, `<port>_contract_test.rb` in Rails, as the kit's testing rule says), so the runner picks it up; it runs in the provider's Stream (in `integración` when the double's task sits in another work Stream, since it needs both merged); Revert SAFE; commit `test({scope}): …`. Its Acceptance names the test `CONTRACT-<port> REQ-F-NNN ACn …` (the id binds it to the criterion in the acceptance ledger) and lists the row's observable, which the test asserts on the double and on the real provider driven through a fake transport. A mock, fake or stub of an external system in §7.2 Setup with no row in `Puertos con doble` is a `[PLAN GAP]` (Handling Plan Gaps): without the row there is no observable to write the contract against. Template: `references/task-template.md` § Contract task.

**Journey task per FASE.** Unit and slice tests can all pass while the page the user opens never calls the new piece, or shows a container with the wrong text. So every FASE with REQ-F scenarios gets one journey task in the Verification phase (Stream `verificación`). Its Acceptance, which travels in both formats, says that the test:

- enters through the user's route: the first step of the FASE's `## Demo` (the URL, screen or command the customer uses), never an internal entry point;
- is named after, and walks through, every REQ-F scenario of the FASE's `Escenarios` (`AC-NNN-NN` or `REQ-F-NNN ACn`);
- carries in its title the id of the workflow it records: each `WF-NNN` of the FASE's `Workflows:` header line (without that line, those cited in `## Demo`), or `FASE-{N}` when the FASE names none. The video helper names the video after that id and `sdd gate --fase N` finds the video by it;
- asserts the text of each criterion's example on the element that shows it (`toHaveText` / `toContainText`), not the visibility of its container;
- saves one screenshot per criterion as `evidencias/FASE-{N}/{AC-NNN-NN | REQ-F-NNN-ACn}.png` and one video per workflow whose file name carries its `WF-NNN` (or `FASE-{N}`) (the folder is the Stack Profile `evidence_dir`, default `evidencias`), attached to the test so the JUnit report carries them.

Its write-set is the journey file of the acceptance suite (Stack Profile `acceptance`; `test_paths` when there is none). The acceptance ledger counts a REQ-F criterion without a screenshot as `unshown`, not VERIFIED, so this task is what closes the FASE. With `visual_evidence: off` in the Stack Profile (no user interface) the task keeps the route and the text asserts and drops the captures. Template: `references/task-template.md` § Journey task.

**Test-first applies to behaviour.** A task that implements behaviour (`feat`/`fix`: a slice, a validation, an error path) opens its Acceptance with `Test first: …` and has its test file in its write-set. A task without behaviour (`chore`/`build`/`ci`/config: a runner setting, a dataset fixture, a dependency pin) states its verification instead — a command whose output proves the change, e.g. `Verify: npx vitest run --project perf --reporter=junit lists the perf project` — and needs no test file. If a chore task still deserves a versioned test, put that test file in its write-set; a `Test first:` line with no test path to write is a contradiction the implementer can only report (IF feedback).

### Phase 3: Dependency Resolution

Per task: write-set (files it creates/modifies) and read-set. B depends on A when B's read-set meets A's write-set or B needs A's deliverable. Mark `[P]` when write-sets are disjoint and there is no read-dependency on uncommitted work. The graph must be a DAG with every task reachable from a root; identify the critical path.

**Internal phases within each FASE** (these names are the contract `sdd-task-implementer` follows):

1. **Setup**: scaffold, dependencies, configuration (merged per concern)
2. **Foundation**: infrastructure shared by ≥ 2 slices (schema, base layout, error handling, shared models). *Vertical:* only what ≥ 2 slices **of this increment** share and no earlier FASE delivered — everything else is built inside the first slice that needs it, so the increment stays thin and each FASE adds only its own journey's infrastructure (FASE-0, the skeleton, has the most)
3. **Slices**: one vertical slice per API operation / behaviour, test-first, kit `layers` order. *Vertical:* grouped under one `### UC-NNN — {title}` sub-heading per use case inside the Slices section (task lines unchanged; the sub-heading is not a phase name, so tools keep reading the tasks as Slices)
4. **Integration**: wiring touching ≥ 2 slices (routes table, layout, navigation, barrels)
5. **Verification**: cross-Stream suites, BDD/E2E journeys, FASE Criterios de Éxito, checkpoint

Legacy labels in existing files: Domain and Contracts count as Slices, Tests as Verification (a test task covering one Stream joins it, Phase 3b step 5).

### Phase 3b: Stream Assignment

Partition each FASE's tasks into **Streams** with pairwise-disjoint write-sets, so each work Stream can be implemented in its own worktree (`sdd-task-implementer --fase N --stream A`) and merged by `--integrate --fase N`. The result is the `## Stream Ownership` table (the implementer's task filter) and the `Streams:` line in `TASK-ORDER.md`.

**Write-set of a task** = every backticked path after the `|` on the task line plus every path in its optional `- **Files:**` bullet. Paths only in Acceptance/Refs/Review are reads.

```
1. base := tasks of Setup (1) and Foundation (2).
   Run in the main checkout before any worktree; the implementer tags the last base commit
   `fase-{N}-foundation` (branch point of every worktree of this FASE).

2. Work graph G over Slices (3) and Integration (4) (legacy: Domain, Contracts, single-Stream Tests):
   node = task; edge(A,B) if write-sets intersect or one is `blocked-by` the other.
   Connected components → candidate Streams.

3. Wiring extraction (repeat until no candidate passes):
   Candidate = a task writing a shared entry point / index / barrel: any path of the kit / Stack
   Profile `wiring` list prefixed by `app_dir` (rails: config/routes.rb, db/schema.rb,
   app/views/layouts/application.html.erb; nextjs-prisma: src/app/layout.tsx, prisma/schema.prisma),
   or without a kit src/index.ts, src/app.ts, src/routes/index.ts, migrations/index.*, any barrel
   re-exporting ≥ 2 directories; or a task whose `blocked-by` spans ≥ 2 top-level source dirs.
   Remove it from G: if its neighbours now fall into ≥ 2 components, it moves to Stream
   `integración` (main checkout, after `--integrate`). An emptied component disappears; if no work
   task is left, keep them all in Stream A and leave `integración` empty.

4. Letter the remaining components A, B, C… by task count, largest first (tie → lowest task ID).

5. Tests follow their slice. A separate test task whose test files cover source files of exactly
   one work Stream (Coverage Map §7.4) joins it (test paths added to Owns); otherwise → `verificación`.

6. Verification (phase 5) → Stream `verificación` (main checkout, implementer Phase 9).
   Checkpoints belong to the main checkout only: `fase-{N}-foundation` after the last base task,
   `fase-{N}-verified` after Verification. Worktrees never create tags.
```

**Owns column:** the smallest set of globs covering the Stream's write-set and matching no file of another Stream; exact paths when a directory is shared (typical for `base` and `integración`). **Branches:** `feat/fase-{N}-{stream}` in lower case; only work Streams get a worktree. **Single-Stream FASE:** valid; the table is written the same way and `TASK-ORDER.md` says `Streams: serial`.

The table is mandatory in every `TASK-FASE-{N}.md` (after "Parallel Execution Plan" in full format); do not add Stream markers to task lines. Example paths:

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

Row order is fixed: `base`, A…Z, `integración`, `verificación`; an empty Stream is listed with `—`.

### Phase 4: Commit Messages

A task's **Commit** field is the subject `{type}({scope}): {description}`; its id becomes the `Task:` trailer and its **Refs** (`FASE-{N}`, UC/API/INV/ADR ids) the `Refs:` trailer. `sdd-task-implementer` commits it as:

```bash
git commit -m "feat(tasks): create task with server-side title validation" \
  --trailer "Task: TASK-F1-006" --trailer "Refs: FASE-1, UC-001, API-001-01, INV-TSK-002"
```

Types and scopes: `references/commit-conventions.md` (scope = the FASE's module or bounded context). Trailers, branches, merges and tags: the plugin-root `references/git-conventions.md`.

### Phase 5: Revert Strategy

| Category | Meaning | Recovery |
|----------|---------|----------|
| `SAFE` | Reverts independently, no side effects | Single `git revert <sha> --no-edit` |
| `COUPLED` | Must revert with related tasks | Revert in reverse commit order |
| `MIGRATION` | Changes database state | Down migration first |
| `CONFIG` | Changes runtime config | Restart/redeploy after revert |

Line format: `- **Revert:** {category} — {what breaks and how to recover}` (compact: only when not SAFE). Checkpoints, whole-FASE rollback and per-stack examples: `references/commit-conventions.md`.

### Phase 6: Review Checklist

Full format only (compact omits it; reviewers use `references/review-checklist.md`). At least two checks per task: generic ones (compiles, glossary terms, acceptance criteria met, invariants enforced, no secrets, error handling per the project's ADR) plus the domain-specific items for the task type (entity, API operation, migration, event, PII, multi-tenant, test) from `references/review-checklist.md`.

### Phase 7: Document Generation

| Artifact | Written by | Content |
|----------|-----------|---------|
| `TASK-FASE-{N}.md` | the FASE agent (fan-out) or the main thread (sequential) | All tasks of the FASE, `## Stream Ownership`, `### Rollback Checkpoints` |
| `TASK-INDEX.md` (full only) | main thread | `node "$SDD_CLI" tasks index > task/TASK-INDEX.md` |
| `TASK-ORDER.md` | main thread | FASE dependency graph (ASCII), Waves, critical path, one `Streams:` line per FASE, Cross-FASE Dependencies with each task's Stream, MVP strategy, delivery checkpoints — template and `Streams:` rules in `references/task-template.md` § TASK-ORDER |

A FASE agent writes only its own `TASK-FASE-{N}.md`: never the global files, `pipeline-state.json`, `spec/` or `plan/`, and it sends no handoff.

### Phase 8: Validation

| Check | Description | Severity |
|-------|-------------|----------|
| V-01 | Every FASE Criterio de Exito maps to at least one task | ERROR |
| V-02 | Every Contrato Resultante has implementation tasks | ERROR |
| V-03 | Every Invariante Aplicable is enforced in at least one task | ERROR |
| V-04 | No circular dependencies | ERROR |
| V-05 | Every task has a commit message | ERROR |
| V-06 | Every task has acceptance criteria | ERROR |
| V-07 | Every task has a revert category (compact: absent Revert = SAFE) | WARN |
| V-08 | No task touches more than 8 files | WARN |
| V-09 | Task IDs follow `TASK-F{N}-{SEQ}` and are unique | ERROR |
| V-10 | 5-80 tasks per FASE | WARN |
| V-11 | Critical path identified in TASK-ORDER.md | ERROR |
| V-12 | File paths follow the CLAUDE.md conventions | WARN |
| V-13 | Every source file in Coverage Map §7.4 has its test inside the implementing task, in a cross-Stream test task, or an exclusion | ERROR |
| V-14 | Every Coverage Map exclusion has a reason | WARN |
| V-15 | Work-Stream write-sets are pairwise disjoint (no file, no glob overlap) | ERROR |
| V-16 | Every task is in exactly one Stream | ERROR |
| V-17 | Verification tasks and checkpoints only in `verificación` / the main checkout | ERROR |
| V-18 | Every `blocked-by` of a Stream task points to the same Stream, `base`, or an earlier FASE | WARN |
| V-19 | Every task line matches the grammar; no `### TASK-` headings, no `**TASK-…**` ids | ERROR |
| V-20 | *Vertical:* every scenario of the FASE's `Escenarios` header line is cited by some task (Acceptance or Refs) | ERROR |
| V-21 | *Vertical:* every port of PLAN-FASE §4 `Puertos con doble` has a task whose Acceptance cites `CONTRACT-<port>`; with an acceptance suite, every REQ-F scenario of `Escenarios` is cited by a task with an e2e path (the journey task) | WARN |

**Ownership.** The FASE agent (or the main thread in sequential mode) self-checks V-01..V-03, V-05..V-08, V-10, V-12..V-14 and reports them in `checks`. The main thread always computes V-04, V-09, V-11 and V-15..V-18 from the union of the returned JSONs (they span FASEs, and an agent should not grade its own homework). V-19 is mechanical: run `node "$SDD_CLI" lint --dir task` (it also re-checks V-05, V-06, V-09, V-16) and edit only the lines it reports. V-20 is mechanical too: `node "$SDD_CLI" lint --plan` prints a `V-20` line per uncited scenario once the task files exist, and a `V-21` warning per port without its contract task or REQ-F scenario outside the journey. `--audit` runs everything read-only.

---

## Per-FASE Task File Structure

Templates: `references/task-template.md` (full and compact).

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

`[ ]` pending · `[x]` done (checkbox state) · `[!]` blocked. Forbidden: `### TASK-…` headings, `**TASK-…**` bold ids, indented task lines, paths outside backticks; a `[PLAN GAP]` line may omit the path (WARN).

**Full format** (default), in order: header (`> **Input:**`, `> **Total tasks:**`, `> **Parallel capacity:**`, `> **Critical path:**`), `## Summary`, `## Traceability`, one `## Phase N: {Setup|Foundation|Slices|Integration|Verification}` section per internal phase (Purpose + Checkpoint, then its task lines — *vertical:* Slices under `### UC-NNN — {title}` sub-headings; Verification ends with the Test Exclusions table), `## Dependencies` (ASCII Task Dependency Graph, Critical Path, Parallel Execution Plan), `## Stream Ownership`, `### Rollback Checkpoints`.

**Compact format** (`--compact` or `task_format: compact`): `# Tasks: FASE-{N} — {Title}`, one `> **Critical path:** …` line, `## Stream Ownership`, `### Rollback Checkpoints`, then `## Setup` … `## Verification` with task lines only (*vertical:* `### UC-NNN` sub-headings inside `## Slices`). Derived views come from `$SDD_CLI tasks json|index|status`; the absence of `TASK-INDEX.md` is never an inconsistency.

## Handling Plan Gaps

When a FASE needs something the plan does not cover, do not invent it. Write a gap task and list every gap in the validation summary:

```markdown
- [ ] TASK-F{N}-{SEQ} [PLAN GAP] {What is needed}
  - **Gap:** PLAN-FASE-{N} does not specify {what is missing}
  - **Action:** Run `sdd-plan-architect --fase {N}` to resolve
  - **Commit:** N/A (blocked)
  - **Refs:** {spec references that need plan coverage}
```

## Error Recovery

| Error | Recovery |
|-------|----------|
| No FASE files / plan artifacts (G-01, G-02) | Run `sdd-plan-architect` |
| Plan is stale (G-04) | Run `sdd-plan-architect` for the affected FASEs, then regenerate tasks |
| FASE references a spec not in the plan | `[PLAN GAP]`; run `sdd-plan-architect --fase {N}` |
| Circular dependency (V-04) | Review `blocked-by` annotations |
| Task touches > 8 files (V-08) | Split by API operation or by layer (> 6 files) |
| Task line does not match grammar (V-19) | Rewrite only the lines `$SDD_CLI lint` prints |
| Shared file between Streams (V-15) | Move that task to `integración`, or merge the two Streams |
| Task in no/two Streams (V-16) | Re-run Phase 3b (`--regen` or `--fase N`) |
| Checkpoint in a worktree Stream (V-17) | Move it to `verificación` |
| FASE agent returned invalid JSON, or its file is missing | Re-launch once with the same prompt; then generate that FASE in the main thread and note it (`fanout-protocol.md` §5, §7.2) |
| Two FASEs use the same id (V-09) | Re-run that FASE with the cross-cutting contract restated in the prompt |

## Persist Summary

After writing all artifacts, update `pipeline-state.json` (create with the default stage structure if absent):

1. `stages["task-generator"].status` = `"done"`, `lastRun` = now (ISO-8601).
2. `stages["task-generator"].summary`:
   - `artifacts`: files written in `task/` with labels (e.g. `{"file": "task/TASK-FASE-1.md", "label": "FASE 1 Tasks"}`)
   - `metrics`: `{ "total_tasks": N, "parallelizable_pct": N, "safe_revert": N, "coupled_revert": N, "migration_revert": N, "config_revert": N, "streamsPerFase": { "1": 2, "2": 1 }, "mode": "fanout"|"sequential", "task_agents": N, "format": "full"|"compact" }`
     - revert counts cover all four categories (compact tasks without a Revert line count as SAFE)
     - `streamsPerFase` = work Streams per FASE (`1` = serial)
     - `mode` = mode actually used (`fanout` even when one FASE was regenerated sequentially after two failures — say so in `highlights`)
     - `task_agents` = FASE agents actually launched (`0` sequential). Together with `mode` this is the record that the fan-out happened, so report the real count, not the planned one
   - `highlights`: 3-5 observations (e.g. "42 tasks across 7 FASEs", "65% parallelizable") plus one line per FASE with more than one work Stream ("FASE-1: 2 streams (A: 2 tasks, B: 2 tasks)"). When the mode was degraded to sequential, the first highlight is the reason.
   - `nextStep`: `"Run /sdd-task-implementer --fase=0"`
   - `generatedAt`: now
3. Commit the files this run wrote: `git add task/`, then `docs(tasks): …` with `Refs:` the FASE ids, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed). Before the commit, write the customer's journal line and stage it too (`git add status/journal.jsonl`): `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" journal add --stage task-generator --kind done --text "Desglosamos las 4 entregas en 32 pasos de trabajo"`, with this run's real numbers; after the commit, update the status page when `status/page.json` has a `url` (plugin-root `references/status-page.md` §1, §3), except in station mode (a role other than `sdd-lead`), where the station only writes the journal and the lead publishes.
4. Show the summary table to the user.
5. Handoff: plugin-root `references/handoff-protocol.md` (station mode only; never from a subagent).
