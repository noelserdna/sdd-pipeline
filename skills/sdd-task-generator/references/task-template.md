# Task Document Template

> Reference template for per-FASE task documents.
> Every `TASK-FASE-{N}.md` follows the **full** template (default) or, with `--compact` / `task_format: compact`, the **compact** one.
> Both share the task-line grammar (V-19) and the `## Stream Ownership` / `### Rollback Checkpoints` tables the implementer parses.
> Paths below are placeholders or examples; real paths come from `CLAUDE.md` (`## SDD Stack Profile`: `app_dir`, `code_paths`, `test_paths`).

---

## Task Line Grammar (V-19)

```text
^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$
```

- One line per task at column 0: `- [ ] TASK-F{N}-{SEQ} [P] {Description} | ` followed by the backticked paths, `, `-separated. `[ ]` pending · `[x]` done · `[!]` blocked.
- Continuation lines indented two spaces (`  - **Commit:** …`); nested bullets four.
- Forbidden: `### TASK-…` headings, `**TASK-…**` bold ids, indented task lines, paths outside backticks. `[PLAN GAP]` tasks may omit the path (WARN).
- Checked by `scripts/sdd.mjs lint --dir task` (V-19, V-09, V-05/V-06, V-16); `sdd.mjs tasks json|status|index` read the same lines.

---

## Template: TASK-FASE-{N}.md (full)

```markdown
# Tasks: FASE-{N} - {Title}

> **Input:** plan/fases/FASE-{N}-{slug}.md + plan/fase-plans/PLAN-FASE-{N}.md
> **Generated:** {YYYY-MM-DD}
> **Total tasks:** {count}
> **Parallel capacity:** {number of work Streams from Stream Ownership}
> **Critical path:** {count} tasks

---

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | {N} |
| Parallelizable | {N} ({%}) |
| Work Streams | {N} (A: {n} tasks, B: {n} tasks) |
| Setup phase | {N} tasks |
| Foundation phase | {N} tasks |
| Slices phase | {N} tasks |
| Integration phase | {N} tasks |
| Verification phase | {N} tasks |

## Traceability

| Spec Reference | Task Coverage |
|---------------|---------------|
| {UC-XXX} | {TASK-F{N}-XXX, ...} |
| {API-NNN-NN} | {TASK-F{N}-XXX, ...} |
| {ADR-XXX} | {TASK-F{N}-XXX, ...} |
| {INV-XXX-XXX} | {TASK-F{N}-XXX, ...} |
| {REQ-XXX-XXX} | {TASK-F{N}-XXX, ...} |

---

## Phase 1: Setup

**Purpose:** Scaffold, dependencies, configuration — trivial steps of one concern merged into one task.
**Checkpoint:** Project initializes and builds successfully.

- [ ] TASK-F{N}-001 {Description} | `{file_path}`, `{file_path}`
  - **Commit:** `chore({scope}): {message}`
  - **Acceptance:**
    - Verify: `{command}` → {output that proves it, e.g. "lists the perf project"}   ← no behaviour, no test file
    - {criterion_2}
  - **Refs:** {FASE-N}, {ADR-XXX}
  - **Revert:** {SAFE|COUPLED|MIGRATION|CONFIG} — {impact description}
  - **Review:**
    - [ ] Code compiles without errors
    - [ ] Follows ubiquitous language
    - [ ] {domain_specific_check}

---

## Phase 2: Foundation

**Purpose:** Shared infrastructure used by ≥ 2 slices (schema, base layout, error handling, shared models). Vertical plan: only what ≥ 2 slices of this increment share and no earlier FASE delivered.
**Checkpoint:** Foundation tests pass.

- [ ] TASK-F{N}-{SEQ} {Description} | `{file_path}`
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:**
    - {criterion}
  - **Refs:** {references}
  - **Revert:** {category} — {impact}
  - **Review:**
    - [ ] {check}

---

## Phase 3: Slices

**Purpose:** One vertical slice per API operation (`API-NNN-NN`), layers in the kit `layers` order (rails: migration → model → controller → views; nextjs-prisma: schema → domain/data → server actions → components/page), tests written first inside the task.
**Checkpoint:** Every slice's tests green.

### UC-{NNN} — {use case title}   ← vertical plan only: one sub-heading per use case

- [ ] TASK-F{N}-{SEQ} [P] {Operation} ({API-NNN-NN}), test-first | `{test_path}`, `{code_path}`, `{view_or_component_path}`
  - blocked-by: TASK-F{N}-{SEQ}
  - **Commit:** `feat({scope}): {message}`
  - **Acceptance:**
    - Test first: `AC-{NNN}-{NN} {behaviour}` — {failing test that encodes the criterion / invariant; its name carries the scenario id}
    - {observable behaviour with specific values; transport per design/OPERATION-MAPPING.md}
  - **Refs:** {FASE-N}, {REQ-X-NNN}, {UC-XXX}, {API-NNN-NN}, {INV-XXX-XXX}
  - **Revert:** {category} — {impact}
  - **Review:**
    - [ ] The test failed before the implementation
    - [ ] {contract check}

---

## Phase 4: Integration

**Purpose:** Wiring touched by ≥ 2 slices — the kit `wiring` files (e.g. rails `config/routes.rb`, `app/views/layouts/application.html.erb`; nextjs-prisma `src/app/layout.tsx`), navigation, barrels.
**Checkpoint:** Integration tests pass.

{Same task format as above}

---

## Phase 5: Verification

**Purpose:** Cross-Stream suites, the FASE journey task (§ Journey task), end-to-end validation against FASE Criterios de Exito.
**Checkpoint:** All FASE acceptance criteria verified.

{Journey task of the FASE — § Journey task below}

- [ ] TASK-F{N}-{LAST} Verify all FASE-{N} Criterios de Exito | `{acceptance suite or directory it verifies}`
  - **Commit:** `test({scope}): verify FASE-{N} acceptance criteria`
  - **Acceptance:** All criteria from FASE-{N} marked as verified
  - **Refs:** FASE-{N}
  - **Revert:** SAFE
  - **Review:**
    - [ ] All criteria checked
    - [ ] Evidence documented

### Test Exclusions

Files excluded from unit test coverage (from PLAN-FASE §7.4 Exclusions):

| File | Reason | Verified By |
|------|--------|-------------|
| {file_path} | {reason} | {integration test / E2E test / N/A - infrastructure} |

> Every source file with testable logic has its test inside the task that implements it (test path on the task line or `Files:`), in a cross-Stream test task, or in this exclusions table (V-13/V-14).

---

## Dependencies

### Task Dependency Graph

```text
TASK-F{N}-001 ──► TASK-F{N}-002 ──► TASK-F{N}-005
             └──► TASK-F{N}-003 ──┘
TASK-F{N}-004 ──► TASK-F{N}-006
```

### Critical Path

1. TASK-F{N}-001 → TASK-F{N}-002 → TASK-F{N}-005 → ... → TASK-F{N}-{LAST}
   ({count} tasks on critical path)

### Parallel Execution Plan

**Stream A:** {what it delivers, e.g. "create and list slices"} — see Stream Ownership
**Stream B:** {what it delivers, e.g. "rename and toggle slices"} — see Stream Ownership

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | TASK-F{N}-001, TASK-F{N}-002 | {exact paths, e.g. dependency manifest, schema} | main checkout, before worktrees (checkpoint `fase-{N}-foundation`) |
| A | TASK-F{N}-003, TASK-F{N}-005 | {globs of Stream A code + tests} | worktree `feat/fase-{N}-a` |
| B | TASK-F{N}-004, TASK-F{N}-006 | {globs of Stream B code + tests} | worktree `feat/fase-{N}-b` |
| integración | TASK-F{N}-009 | {exact wiring paths} | main checkout, after `--integrate --fase {N}` |
| verificación | TASK-F{N}-{LAST} | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Foundation | TASK-F{N}-002 | `fase-{N}-foundation` | main checkout |
| Verified | TASK-F{N}-{LAST} | `fase-{N}-verified` | main checkout |
```

---

## Template: TASK-FASE-{N}.md (compact)

With `--compact` or `task_format: compact`. Keeps only what the implementer and the global validations read; `sdd.mjs tasks json | index | status` derive the rest.

```markdown
# Tasks: FASE-{N} — {Title}

> **Critical path:** TASK-F{N}-001 → TASK-F{N}-003 → … → TASK-F{N}-{LAST}

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | {tasks} | {exact paths} | main checkout, before worktrees (checkpoint `fase-{N}-foundation`) |
| A | {tasks} | {globs} | worktree `feat/fase-{N}-a` |
| integración | {tasks or —} | {exact paths or —} | main checkout, after `--integrate --fase {N}` |
| verificación | {tasks} | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Foundation | {last base task} | `fase-{N}-foundation` | main checkout |
| Verified | TASK-F{N}-{LAST} | `fase-{N}-verified` | main checkout |

## Setup

- [ ] TASK-F{N}-001 {Description} | `{path}`, `{path}`
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:** {criteria}
  - **Refs:** FASE-{N}, {ids}

## Foundation

{task lines}

## Slices

### UC-{NNN} — {use case title}

- [ ] TASK-F{N}-{SEQ} [P] {Operation} ({API-NNN-NN}), test-first | `{test_path}`, `{code_path}`
  - blocked-by: TASK-F{N}-{SEQ}
  - **Commit:** `feat({scope}): {message}`
  - **Acceptance:** Test first: `AC-{NNN}-{NN} {behaviour}`; {observable behaviour}
  - **Refs:** FASE-{N}, {UC}, {API}, {INV}
  - **Revert:** COUPLED — {written only when not SAFE}

## Integration

{task lines}

## Verification

{journey task (§ Journey task), then the other task lines}
```

| Omitted in compact | Where it comes from |
|---|---|
| Summary, Traceability | `sdd.mjs tasks index` / `tasks json` |
| Dependency graph, Parallel Execution Plan | `blocked-by` lines + Stream Ownership |
| Review block | `references/review-checklist.md` |
| `Revert: SAFE` | absent Revert line = SAFE (V-07; CLAUDE.md Revert strategies) |
| `TASK-INDEX.md` | `sdd.mjs tasks index` (never templated by hand) |

### Stream Ownership Rules

| Rule | Detail |
|------|--------|
| Source of truth | `sdd-task-implementer --stream X` filters tasks by this table, never by markers on the task lines |
| Row order | `base`, then work Streams `A`…`Z` (largest first), then `integración`, then `verificación`; empty Streams are listed with `—` |
| `base` | Setup + Foundation tasks; main checkout before any worktree; last commit tagged `fase-{N}-foundation` |
| Work Streams | Connected components of the Slices/Integration write-set + `blocked-by` graph (SKILL.md Phase 3b); write-sets pairwise disjoint (V-15); each slice's tests belong to its Stream |
| `integración` | Wiring tasks that touch ≥ 2 components: kit / Stack Profile `wiring` files (prefixed by `app_dir`), or without a kit `src/index.ts`, `routes/index.ts`, migration indexes, barrels; main checkout after `--integrate --fase {N}` |
| `verificación` | Verification-phase tasks and cross-Stream test tasks; main checkout, implementer Phase 9 (V-17) |
| Owns | Smallest globs covering the Stream's write-set and no file of another Stream; exact paths when a directory is shared |
| Runs in | `worktree \`feat/fase-{N}-{stream lower-case}\`` for A…Z; `main checkout, …` for the rest |
| Single Stream | Table still written (base + A + integración/verificación); `TASK-ORDER.md` says `Streams: serial` |

---

## Contract task (`CONTRACT-<port>`)

One per row of PLAN-FASE §4 `Puertos con doble` (SKILL.md Phase 2). It sits after the slices it depends on, in the provider's Stream (`integración` when the double is written in another work Stream). Compact form (full adds `Revert: SAFE` and a Review block):

```markdown
- [ ] TASK-F{N}-{SEQ} Contract test {Port}: double and real provider agree | `{test_paths}/contract/{port contract test file}`
  - blocked-by: {task writing the double}, {task writing the real provider}
  - **Commit:** `test({scope}): contract test for the {Port} double and its real provider`
  - **Acceptance:** Test first: `CONTRACT-{Port} REQ-F-{NNN} AC{n} …` runs the same assertions on the double and on the real provider driven through a fake transport that captures the request; observable: {Observable del contrato of the row}
  - **Refs:** FASE-{N}, REQ-F-{NNN}, PLAN-FASE-{N} §4.{x}
```

`{test_paths}` is the Stack Profile directory that holds the tests; the file follows the stack's naming convention so the runner picks it up: `{port}.contract.test.ts` in JS/TS, `{port}_contract_test.rb` in Rails (the kit's testing rule names it).

A double in §7.2 Setup without its row is written as a `[PLAN GAP]` task instead (`Gap: PLAN-FASE-{N} §4.{x} has no row for {double}`).

---

## Journey task (one per FASE with REQ-F scenarios)

Verification phase, Stream `verificación` (SKILL.md Phase 2). The rule lives in Acceptance so it survives the compact format. Compact form:

```markdown
- [ ] TASK-F{N}-{SEQ} Journey FASE-{N} {WF-NNN …}: {Incremento} through the user's route | `{acceptance suite dir}/fase-{N}.journey.spec.{ext}`
  - blocked-by: {last slice or integration task of the FASE}
  - **Commit:** `test({scope}): FASE-{N} journey from the user's route with captures`
  - **Acceptance:**
    - Test first: named `{AC-NNN-NN | REQ-F-NNN ACn} …` for each REQ-F scenario of the FASE's Escenarios: {ids}
    - The journey's title carries {WF-NNN of the FASE's `Workflows:` line (else of its `## Demo`) | FASE-{N} when it names none}, the id the video is named after and `sdd gate --fase N` looks for
    - Enters through Demo step 1 ({URL, screen or command}), never an internal entry point
    - Asserts each criterion's example text on the element that shows it (`toHaveText` / `toContainText`), not the container's visibility: {criterion → "text"}
    - Saves `evidencias/FASE-{N}/{scenario id}.png` per criterion and one video per workflow with `{WF-NNN | FASE-{N}}` in its file name, attached to the test
  - **Refs:** FASE-{N}, {REQ-F ids}, {WF ids}
```

With `visual_evidence: off` the last Acceptance bullet is dropped.

---

## Fix task (Mode 5, `FEEDBACK-FASE-{N}` and `ACCEPTANCE-ADVERSARIAL-FASE-{N}`)

The defect slipped past a green test, so the fix proves itself with a new or tightened test that fails on the current code. `ACCEPTANCE-LOOP` tasks use the slice form with `Test first:`.

```markdown
- [ ] TASK-F{N}-{SEQ} Fix {defect in one line} ({CH-NNN | IF-N-SEQ | feedback id}) | `{test_path}`, `{code_path}`
  - Source: {FEEDBACK-FASE-{N} | ACCEPTANCE-ADVERSARIAL-FASE-{N}}
  - **Commit:** `fix({scope}): {message}`
  - **Acceptance:**
    - Reproduce first: `{AC-NNN-NN | REQ-X-NNN ACn | INV-… | CONTRACT-…} {defect behaviour}` fails on the current code with {observed wrong result}
    - {expected behaviour with the criterion's values}; {category and `path:line` of the finding, for an adversarial one}
  - **Refs:** FASE-{N}, {REQ ids}, {scenario / INV / CONTRACT ids}, {CH-NNN}
```

For a `WEAKENED-ASSERT` or `WRONG-CAPTURE` finding the code is right and the test is what gets fixed: no `Reproduce first:` line, the first Acceptance bullet names the tightened assert (or capture) with the criterion's literal, and the edit is listed for a person's approval (`sdd-acceptance`, Test edits inside the loop).

---

## Task Entry Format (Quick Reference)

```markdown
- [ ] {TASK-ID} [P?] {Description} | `{path}`, `{path}`
  - blocked-by: {TASK-ID, ...}
  - **Files:** `{extra_path}`, `{extra_path}`
  - **Commit:** `{type}({scope}): {message}`
  - **Acceptance:**
    - {feat/fix: test written first · chore/build: Verify command; then criteria with specific values, not vague}
  - **Refs:** {FASE, UC, API, ADR, INV, REQ — comma-separated}
  - **Revert:** {SAFE|COUPLED|MIGRATION|CONFIG} — {what breaks}
  - **Review:**
    - [ ] {actionable check for reviewer}
```

### Field Rules

| Field | Required | Notes |
|-------|----------|-------|
| Task ID | YES | Format: `TASK-F{N}-{SEQ}` (3-4 digit SEQ), unique across FASEs (V-09) |
| [P] marker | NO | Right after the id, only if parallelizable |
| Description | YES | Imperative mood, specific, one behaviour (a slice names its API operation) |
| File path(s) | YES | After the pipe separator, each path in backticks, `, `-separated, exact from the project root (V-19); a slice lists all its paths (split above 6 files) |
| blocked-by | NO | Task IDs this task depends on (same FASE or earlier); drives Stream assignment (V-18) |
| Files | NO | Extra paths the task creates/modifies; together with the line paths they form the task's write-set (Stream Ownership) |
| Commit | YES | Conventional commit format (V-05) |
| Acceptance | YES | At least 1 criterion with specific values (V-06). `feat`/`fix` tasks: the first is `Test first: …` (`Reproduce first: …` in a fix task from feedback or the adversarial round, § Fix task) and the test file is in the write-set (Constitution Art. 8). `chore`/`build`/config tasks: `Verify: \`{command}\` → {expected output}`, no test file; a chore task that says `Test first` must list its test file |
| Refs | YES | At least FASE reference |
| Revert | Full: YES · compact: only when not SAFE | Category + impact (V-07; absent = SAFE in compact) |
| Review | Full: YES (≥ 2 checks) · compact: omitted | Patterns in `references/review-checklist.md` |

---

## Template: TASK-ORDER.md (full)

Written by the main thread from the FASE JSONs. Diagrams are ASCII (no Mermaid), as in `plan/`.

```markdown
# Implementation Order

> **Generated:** {YYYY-MM-DD}
> **Total FASEs:** {count}
> **Recommended approach:** Incremental delivery per FASE

## FASE Dependency Graph

{ASCII diagram, one line per FASE, e.g. FASE-0 ──► FASE-1 ──► FASE-2}

## Recommended Implementation Sequence

### Wave 1: Foundation
**FASE-0** (No dependencies — start here)
- {count} tasks, {parallel count} parallelizable
- Critical path: {N} sequential tasks
- Streams: serial

### Wave 2: Core Capabilities
**FASE-1** (depends on: FASE-0)
- {count} tasks, {parallel count} parallelizable
- Critical path: {N} sequential tasks
- Streams: base(2) → A(2) ∥ B(2) → integración(1) → verificación(1)

## Cross-FASE Dependencies

| From (Stream) | To (Stream) | Reason |
|---------------|-------------|--------|
| TASK-F0-005 (base) | TASK-F1-001 (A) | {why F1 needs it} |

## MVP Strategy

**Minimum Viable Product:** FASE-0 + FASE-1
- {count} total tasks
- Core capability: {description}

## Incremental Delivery Checkpoints

| Checkpoint | FASEs Complete | Capability |
|-----------|---------------|------------|
| CP-1 | FASE-0 | {capability delivered} |
| CP-2 | FASE-0,1 | {capability delivered} |
```

**`Streams:` line:** one per FASE inside its Wave entry: `Streams: base(n) → A(n) ∥ B(n) [∥ C(n)…] → integración(n) → verificación(n)`, task count per Stream (empty Stream = `integración(0)`); a FASE with a single work Stream writes exactly `Streams: serial`. In Cross-FASE Dependencies every task carries its Stream in parentheses.

**Compact format:** `TASK-ORDER.md` ≤ 1 500 chars — keep `## FASE Dependency Graph` (one line per FASE), one Wave entry per FASE with its `Critical path:` and `Streams:` lines, and Cross-FASE Dependencies only when non-empty; drop MVP Strategy and Incremental Delivery Checkpoints. V-11 and `--audit` read only what is kept.
