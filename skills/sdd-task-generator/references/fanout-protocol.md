# Execution Protocol: Index, Budgets, Fan-out by FASE

Writing `task/TASK-FASE-{N}.md` is mechanical and the files are independent (no FASE file references another), so
the work fans out by FASE. Target: wall-clock ≈ the slowest FASE + consolidation, main-thread plan context ≤ ~25 k tokens.

## 0. Fan-out is part of this skill's contract

Launching one task agent per FASE is the requested behaviour of `/sdd-task-generator` above the threshold, not an
optional expansion of scope. Each agent is bounded to one FASE, writes exactly one file (`task/TASK-FASE-{N}.md`, no
other agent writes it), reads only its own FASE's plan artifacts, does not nest, does not commit, and does not touch
`spec/`, `plan/` or `pipeline-state.json`. Downgrade to sequential only for a reason in §1, and record it in
`metrics.mode` and `summary.highlights`.

## 1. Choose the mode (Phase 0, before opening any plan file)

```bash
FASES=$(ls plan/fases/FASE-*.md 2>/dev/null | wc -l | tr -d ' ')
```

| Condition | Mode |
|---|---|
| `FASES >= 2` (full generation) | **fanout** (default; also in `claude -p` — the `Agent` tool is available there) |
| `--fanout` flag | **fanout**, whatever the count (forces the mode; useful for benchmarking) |
| `FASES == 1`, or `--fase N` (a single FASE is one unit of work), or `--incremental` | **sequential** |
| `--sequential` flag, or the `Agent` tool is not in the tool list | sequential; add the reason to `summary.highlights` |
| `--audit` (Mode 4) | fanout with the same threshold: one agent per FASE recomputes Phase 3b for its file and returns the JSON of §6; the main thread compares, runs V-04/V-15..V-18 and writes nothing |

`--regen` does not change the mode: it only discards the previous `task/` content before generating.

## 2. Build the plan index (main thread; the only plan-wide read)

```bash
PIDX="$([ -d .sdd ] && echo .sdd || echo "${TMPDIR:-/tmp}")/plan-index.txt"
grep -rn -E '^#{1,4} |^\| *[A-Za-z]|^- \*\*|^> \*\*' plan/ | cut -c1-110 > "$PIDX"
wc -l "$PIDX"; cut -d: -f1 "$PIDX" | uniq -c | sort -rn        # sections per plan file (structure)
grep -E 'FASE-[0-9]+' "$PIDX" | grep -iE 'depend|estado|valor observable'   # FASE order and status
```

The main thread reads the two summaries above, not the whole index. Slices come on demand:
`grep '^plan/fase-plans/PLAN-FASE-1' "$PIDX"`. Sections are opened with `sed -n 'a,bp' file` (≤ 60 lines per call),
located by the index line numbers. **Never `cat` a plan file in the main thread, in any mode.** A file ≤ 8 k chars may
be read whole by the thread that owns it (sequential mode, or the agent of that FASE); above 8 k chars the owner also
works by sections. This is what keeps the token cost of fan-out close to the sequential run instead of multiplying it.

## 3. Budgets (plan content held in context)

| Thread | Budget | How |
|---|---|---|
| main, fanout | ≤ ~25 k tokens | index summaries + the cross-cutting contract of §4 + the returned JSONs; never a whole `PLAN-FASE-*.md` |
| main, sequential | one FASE at a time; release the previous FASE's sections before opening the next | same commands, FASE by FASE |
| each FASE agent | its own `FASE-{N}-*.md` + `PLAN-FASE-{N}.md` whole if ≤ 8 k chars each, else by sections; ≤ 200 lines of neighbour lookups (ARCHITECTURE, glossary) | own slice of `$PIDX`, `sed -n`, `grep -n` |

## 4. Split of work

The main thread fixes **everything that is shared between FASEs** before launching, because two agents deciding it
independently would diverge. It then owns everything that is global by nature.

| Owner | Owns |
|---|---|
| **main thread, before the fan-out** | Phase 0 gates G-01..G-05; the plan index; the **cross-cutting contract** passed verbatim to every agent: id format `TASK-F{N}-{SEQ}` (3 digits, sequential within the FASE, starting at 001 — ids are never reused across FASEs because the FASE number is part of them), the commit convention (types table + the `Refs:` / `Task:` trailers of `references/commit-conventions.md`), the project's path conventions from `CLAUDE.md`, the glossary terms (ids + one line, from `spec/domain/01-GLOSSARY.md`), the task-line and Stream-Ownership templates of `references/task-template.md`, the review-checklist patterns of `references/review-checklist.md` (full format only), the output format (`full` | `compact`), the Stack Profile paths (`app_dir`, `code_paths`, `test_paths`) and the kit `layers` / `wiring` lists, and, **per FASE, its `## Módulos y Conjuntos de Escritura` table** (`plan/fases/FASE-{N}-*.md` §5), which is the seed of that FASE's Streams |
| **one agent per FASE** | Phases 1–7 scoped to its FASE: FASE analysis, plan decomposition, intra-FASE dependency resolution (Phase 3), Stream assignment (Phase 3b) from the Módulos table, commit messages (Phase 4), revert strategies (Phase 5), review checklists (Phase 6). Writes **only** `task/TASK-FASE-{N}.md`, including its `## Stream Ownership` table and its Rollback Checkpoints. Self-checks the FASE-local validations and returns them in `checks` |
| **main thread, after the fan-out** | `task/TASK-ORDER.md` (global: FASE dependency graph, Waves, `Streams:` lines, **Cross-FASE Dependencies**; full format adds MVP strategy and delivery checkpoints), `task/TASK-INDEX.md` in full format only (`node "$SDD_CLI" tasks index`: flat list + traceability matrix over all FASEs), the **global validations** of §7 including V-19, the gap report, Persist Summary and Handoff |

**Validation ownership** — the global checks stay in the main thread and are computed from the returned JSON, not
re-derived by each agent:

| Check | Owner | Computed from |
|---|---|---|
| V-01, V-02, V-03 (Criterios / Contratos / Invariantes covered) | FASE agent | its FASE file vs its own tasks; reported in `checks` |
| V-05, V-06, V-07 (commit message, acceptance, revert per task) | FASE agent | its own tasks |
| V-08, V-10, V-12, V-13, V-14 (files per task, task count, path conventions, Coverage Map §7.4 tests inside their tasks, exclusions) | FASE agent | its own tasks + `PLAN-FASE-{N}.md` §7.4 |
| **V-04** (no circular dependencies) | **main thread** | the union of all `bb` (`blocked-by`) edges of all FASEs — cycles that cross a FASE boundary are invisible to any single agent |
| **V-09** (id format **and uniqueness across FASEs**) | **main thread** | every `id` of every JSON |
| **V-11** (critical path in `TASK-ORDER.md`) | **main thread** | the `critical_path` of each JSON, chained through the cross-FASE edges |
| **V-15** (work-Stream write-sets pairwise disjoint) | **main thread** | the `streams[].owns` sets of the JSONs, compared pairwise inside each FASE (a glob that matches a file of another work Stream is an overlap) |
| **V-16** (every task in exactly one Stream) | **main thread** | `tasks[].id` vs the union of `streams[].tasks` — no task missing, none listed twice |
| **V-17** (verification tasks and checkpoints only in `verificación` / the main checkout) | **main thread** | `streams[].runs` + `checkpoints` of each JSON |
| **V-18** (`blocked-by` points to the same Stream, `base`, or an earlier FASE) | **main thread** | the global edge list + the Stream of each task — the cross-FASE half of this check cannot be done inside one FASE |
| **V-19** (task-line grammar, no `### TASK-` / `**TASK-…**`) | **main thread** | `node "$SDD_CLI" lint --dir task` over the written files (each agent also runs it on its own file before returning); fix only the reported lines |

An agent that reports a `fail` in `checks` does not fix it: the main thread folds it into the validation summary with
the FASE it came from.

## 5. Launch

- One assistant message with **one `Agent` call per FASE**, up to **4 concurrent**. With more than 4 FASEs, launch them
  in batches of 4 in FASE order (batch 2 starts when batch 1 has returned). Do not wait for one agent before launching
  the next inside a batch.
- `subagent_type: "general-purpose"` (never `"fork"`: a fresh agent with a small context is the point),
  `description: "Generate tasks for FASE-{N}"`.
- `model: "sonnet"` for the FASE agents — unless `CLAUDE_CODE_SUBAGENT_MODEL` is set, in which case omit `model` and
  let the environment decide. The consolidation, the global validations, `TASK-ORDER.md` and (full format)
  `TASK-INDEX.md` are always done by the main thread with its own model.
- While the agents run, the main thread prepares what does not depend on them: the FASE dependency graph and the Waves
  (from the `Dependencias` line of each FASE file, already in `$PIDX`), the MVP strategy and the delivery checkpoints.
  It never generates tasks for a FASE that has an agent.
- An agent that errors, times out or returns invalid JSON is re-launched **once** with the same prompt; if it fails
  again, the main thread generates that FASE sequentially and says so in `summary.highlights`.

## 6. FASE-agent prompt template

Substitute `{…}`. `{REFS}` = `${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/skills/sdd-task-generator/references`; if that
path is unknown, inline the relevant template sections (≤ 60 lines) instead of the pointer. `{SDD_CLI}` =
`${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs` (the same `$SDD_CLI` of SKILL.md).

```
You generate the task document of FASE-{N} for the SDD pipeline (sdd-task-generator). Write in {project language}.

Write EXACTLY ONE file: task/TASK-FASE-{N}.md. Create or modify no other file. Never touch spec/, plan/, audits/,
task/TASK-INDEX.md, task/TASK-ORDER.md or pipeline-state.json. Do not commit. Do not launch further agents.

Read (grep -n for headings first, then sed -n the sections; whole file only if ≤ 8 k chars):
- plan/fases/FASE-{N}-{slug}.md   → Criterios de Éxito, Specs a Leer, Invariantes Aplicables, Contratos Resultantes,
                                    Alcance (Incluye/Excluye), Dependencias, Módulos y Conjuntos de Escritura
- plan/fase-plans/PLAN-FASE-{N}.md → components, data models, endpoints, config, integration points, §7.4 Coverage Map
- plan/ARCHITECTURE.md            → only the sections this FASE touches (≤ 200 lines total)
- spec/ files named in "Specs a Leer" → only the sections you cite in Refs (grep -n the ids, then sed -n)
Do NOT read other FASEs, other PLAN-FASE files, or task/ files of other FASEs.

Cross-cutting contract fixed by the main thread — apply verbatim, do not re-invent:
- Task ids: TASK-F{N}-001, 002, … sequential within this FASE, 3 digits.
- Task line (one line per task, column 0; continuation lines indented two spaces):
    - [ ] TASK-F{N}-{SEQ} [P] <Description> | `<path>`[, `<path>`]*
  Never `### TASK-…` headings, never `**TASK-…**` bold ids, never paths outside backticks.
- Output format: {full|compact}. compact = no Review block, Revert line only when not SAFE, no Summary /
  Traceability / Dependencies sections (template "compact" of {REFS}/task-template.md).
- Commit convention: {types table + Refs:/Task: trailer format}.
- Path conventions: {from CLAUDE.md and its ## SDD Stack Profile: app_dir, code_paths, test_paths}.
  Glossary terms (use only these): {ids + one line}.
- Slice layer order: {kit layers, or "per plan/ARCHITECTURE.md"}. Wiring files (→ Integration): {kit wiring, prefixed by app_dir}.
- Task line, Stream Ownership table and Rollback Checkpoints templates: {REFS}/task-template.md.
- Review checklist patterns (full format only): {REFS}/review-checklist.md (only the sections for the task types you produce).
- Módulos y Conjuntos de Escritura of THIS FASE (seed of your Streams): {the table, verbatim}.

Produce the tasks with SKILL.md Phases 1–7 restricted to FASE-{N}: 1 task = 1 commit; one vertical slice per API
operation in the layer order, its tests written FIRST inside the same task (separate test tasks only for cross-Stream
suites, BDD/E2E journeys and exclusions); trivial setup steps of one concern merged; split above 6 files or 2 API
operations; internal phases Setup → Foundation → Slices → Integration → Verification, [P] markers, blocked-by
annotations, Phase 3b Stream assignment (base / A…Z / integración / verificación) derived from the Módulos table,
commit message, acceptance criteria, Refs and (per format) revert strategy and review checklist per task, plus the
sections of the format (full: Summary, Traceability, Dependencies, Parallel Execution Plan; both: ## Stream Ownership
and ### Rollback Checkpoints).
Plan gaps: never invent plan content — emit the task with [PLAN GAP] as SKILL.md "Handling Plan Gaps" describes and
list it in `gaps`.
Before returning, run `node {SDD_CLI} lint task/TASK-FASE-{N}.md` and fix every line it reports.
Self-check V-01, V-02, V-03, V-05, V-06, V-07, V-08, V-10, V-12, V-13, V-14 over your own tasks and report them in
`checks`. Do NOT check V-04, V-09, V-15, V-16, V-17, V-18: they are global and the main thread computes them from
your JSON.

Return ONLY this JSON (no prose, no file body, ≤ 8 000 chars):
{"fase":{N},"file":"task/TASK-FASE-{N}.md","chars":12345,
 "tasks":[{"id":"TASK-F{N}-003","ph":"Slices","p":true,"w":["src/api/tasks.ts","tests/unit/api/tasks.test.ts"],"bb":["TASK-F{N}-001"],
           "stream":"A","refs":["UC-002","INV-SEC-001","ADR-004"],"revert":"SAFE"}],
 "streams":[{"s":"A","tasks":["TASK-F{N}-003"],"owns":["src/api/**","tests/unit/api/**"],"runs":"worktree feat/fase-{N}-a"}],
 "checkpoints":[{"cp":"Foundation","after":"TASK-F{N}-002","tag":"fase-{N}-foundation","runs":"main checkout"}],
 "critical_path":["TASK-F{N}-001","TASK-F{N}-003"],
 "counts":{"total":27,"parallel":9,"setup":2,"foundation":3,"slices":16,"integration":3,"verification":3},
 "checks":{"V-01":"pass","V-13":"fail:src/cli/parse.ts"},
 "gaps":[{"task":"TASK-F{N}-012","need":"PLAN-FASE-{N} no especifica el formato del token"}]}
```

`w` = write-set of the task (the backticked paths of the task line plus its `- **Files:**` bullet). `bb` = blocked-by.
`p` = the `[P]` marker. The main thread needs no other field: `TASK-ORDER.md` is built from this JSON, **not** by
re-reading the generated files (`TASK-INDEX.md`, full format only, comes from `sdd.mjs tasks index`).

## 7. Consolidation (main thread, main model)

1. Parse one JSON per FASE. A missing or invalid JSON → re-launch once (§5), then generate that FASE sequentially.
2. Verify each `file` exists and its size matches `chars` (`wc -c task/TASK-FASE-*.md`). Do not read the bodies.
   Run `node "$SDD_CLI" lint --dir task` (**V-19**; it also re-checks V-05/V-06/V-09/V-16 on the files) and edit only
   the lines it reports.
3. Build the **global task graph**: nodes = every `tasks[].id`, edges = every `bb` entry (intra- and cross-FASE) plus the
   FASE-level `Dependencias`. Run **V-04** (no cycles, every node reachable) and compute the critical path (**V-11**)
   by chaining the per-FASE `critical_path` through the cross-FASE edges.
4. Run **V-09** (format + uniqueness of ids across FASEs), **V-15** (pairwise-disjoint `owns` per FASE),
   **V-16** (every `tasks[].id` in exactly one `streams[].tasks`), **V-17** (`checkpoints[].runs` = main checkout, and
   no verification task in a lettered Stream), **V-18** (each `bb` edge resolves to the same Stream, to `base`, or to a
   task of an earlier FASE). Fold the agents' `checks` failures in without re-computing them.
5. Full format only: `node "$SDD_CLI" tasks index > task/TASK-INDEX.md` (Summary by FASE, flat task list, traceability
   matrix from the Refs lines, across all FASEs). Compact format: no index.
6. Write `task/TASK-ORDER.md`: FASE dependency graph, Waves, one `Streams:` line per FASE built from `streams[].tasks`
   counts (`Streams: base(2) → A(10) ∥ B(9) → integración(1) → verificación(10)`, or exactly `Streams: serial` for a
   single work Stream), the **Cross-FASE Dependencies** table (each edge whose endpoints belong to different FASEs, with
   the Stream of both tasks in parentheses), the MVP strategy and the incremental delivery checkpoints. Compact format:
   ≤ 1 500 chars keeping the dependency graph, `Critical path:` and `Streams:` lines (SKILL.md TASK-ORDER.md Structure).
7. Report the gaps (`gaps` of every FASE) and the validation results, then Persist Summary with
   `metrics.mode = "fanout"` and `metrics.task_agents = {number of agents actually launched}`.

## 8. Sequential mode (one FASE, `--sequential`, or no `Agent` tool)

Same discipline in one thread: index first; FASEs in numeric order; each FASE's plan read by sections (whole only if
≤ 8 k chars); collect the same JSON shape of §6 per FASE **before** writing `TASK-ORDER.md` (and `TASK-INDEX.md`), so the
global validations of §7 run over the same data structure in both modes; `metrics.mode = "sequential"`,
`metrics.task_agents = 0`, and the reason in `summary.highlights`.
