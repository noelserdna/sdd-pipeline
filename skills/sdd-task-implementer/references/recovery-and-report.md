# Revert, Recovery and Session Report

> Reference for sdd-task-implementer: how to undo a task or a phase, what to do with a task that cannot be
> implemented, the error → recovery table, the session report, the feedback file template and the bench event helper.

---

## Revert & Recovery Strategies

### Reverting a Single Task

Lee el campo **Revert** de la task (con `task_format: compact` una task sin bloque **Revert** es `SAFE`):

| Category | Action |
|----------|--------|
| `SAFE` | `git revert <sha>` — sin efectos secundarios |
| `COUPLED` | Revertir tasks acopladas en orden inverso |
| `MIGRATION` | Ejecutar down migration, luego revertir (base de datos local: `{db_reset_safe}`; nunca un reset que la herramienta rechace — SKILL.md → AI Tool Guardrails) |
| `CONFIG` | Revertir, luego redeploy |

With `task_state: trailers` the revert commit is enough: `sdd.mjs tasks status` subtracts reverted commits, so the
task becomes pending again without touching the task document.

### Rollback to Checkpoint

```bash
# Rollback entire phase to last checkpoint
git revert --no-commit HEAD..fase-{N}-{phase}
git commit -m "revert: rollback to FASE-{N} {phase} checkpoint"
```

### Locate a regression

When a test that passed at a checkpoint fails now, let git find the first bad commit; each step runs the test of the
acceptance criterion (`{test_file}` of the Stack Profile), and the commit it names carries the `Task:` of the culprit:

```bash
git bisect start HEAD fase-{N}-verified      # bad, then last known good
git bisect run {test_file with the failing test}
git bisect reset
```

### Handling Failed Implementation

Si una task no puede implementarse:
1. Revertir los cambios parciales de esta task
2. Marcar la task con `[!]` (blocked) en el task document — con `task_state: trailers`, abrir en su lugar una entrada
   `BLOCKER` en `feedback/IMPL-FEEDBACK-FASE-{N}.md` (references/stack-profile.md §6)
3. Documentar la razon del bloqueo
4. Continuar con la siguiente task no dependiente

## Error Recovery

| Error | Cause | Recovery |
|-------|-------|---------|
| "Task document not found" | Task generator not run | Run `sdd-task-generator` |
| "Plan artifacts not found" | Plan architect not run | Run `sdd-plan-architect` |
| "Spec file not found" | Referenced spec missing | Check Refs field, verify spec exists |
| "Dependency task incomplete" | Previous task not done | Complete dependency task first |
| "Tests fail after implementation" | Bug in implementation | Debug and fix, re-run tests |
| "Build fails" | Syntax error or missing dependency | Fix compilation error |
| "Merge conflict" | Parallel task touched same file | Tasks marked [P] should not conflict — investigate |
| "Checkpoint tag exists" | Phase already checkpointed | Skip checkpoint or force with `--force` |
| "[DECISION PENDIENTE] found" | Spec has unresolved decision | Pause, ask user, resolve in spec first |
| "Git working tree dirty" | Uncommitted changes | Commit or stash pending changes |
| "Stale upstream" | `task-generator`/`plan-architect` marked `stale` | Re-run the stale skill, then `--continue` |
| "Stream X not in Stream Ownership table" (G-09) | Table missing or wrong name | Re-run `sdd-task-generator`; check the Stream column |
| "Not in the Stream worktree" (G-10) | `--stream X` run in the main checkout or wrong branch | `git worktree add ../<project>-f{N}{x} -b feat/fase-{N}-{x} fase-{N}-foundation` and run there |
| "Run base tasks in the main checkout first" (G-11) | `base` tasks not `[x]` in HEAD | `--fase {N} --stream base` in the main checkout, recreate the worktree from `fase-{N}-foundation` |
| "External dependency not in HEAD" | `blocked-by` on a task of another Stream | Mark `[!]`, continue; implement after `--integrate` |
| "Merge conflict during --integrate" | Two Streams touched the same file (V-15 violated) or both marked `task/TASK-FASE-{N}.md` | `references/integration-protocol.md` §2: keep both `[x]` (checkbox mode), resolve code by hand, `git add` + `git commit`, log feedback CONFLICT |
| "Duplicate Task: trailer after merge" | Same task committed on two branches | Keep the merge, `git revert` the later duplicate, report |
| "Tool refused a destructive action (AI consent)" | Tool guardrail (e.g. `prisma migrate reset`) | Never set consent variables; `{db_reset_safe}` or `PAUSE: Tool guardrail` (SKILL.md → AI Tool Guardrails) |
| "Stack Profile not resolved" (G-08) | No `## SDD Stack Profile`, no detectable stack, no kit | Declare the section in `CLAUDE.md` or run `/sdd-setup --stack=<kit>` (`references/stack-profile.md` §3) |

---

## Output Format: Implementation Session Report

Al finalizar una sesion de implementacion:

```markdown
## Implementation Session Report

**Date:** {YYYY-MM-DD}
**FASE:** {N}
**Stack:** {stack} (profile: {declared|detected|legacy|architecture})
**Tasks completed:** {list}
**Tasks remaining:** {count}

### Progress

| Task | Status | Tests | SHA | Commit Message |
|------|--------|-------|-----|----------------|
| TASK-F0-001 | ✓ Complete | 3/3 | abc1234 | chore(bootstrap): configure toolchain |
| TASK-F0-002 | ✓ Complete | 5/5 | def5678 | feat(bootstrap): init application skeleton |
| TASK-F0-003 | ⏸ Paused | 2/4 | — | — |
| TASK-F0-004 | ○ Pending | — | — | — |

### Pauses
- TASK-F0-003: [DECISION PENDIENTE] in spec/adr/ADR-NNN-*.md line 45

### Skipped checks
- typecheck: n/a (stack profile)

### Next Steps
1. Resolve the ADR-NNN decision
2. Continue with TASK-F0-003
3. Then TASK-F0-004 (parallel with F0-005)

### Checkpoints
- `fase-0-setup` after TASK-F0-002
```

Include the feedback summary (`feedback/IMPL-FEEDBACK-FASE-{N}.md`: open BLOCKER/WARNING entries, including
`TOOL-GUARDRAIL`) when the session produced any.

---

## Implementation Feedback File

`feedback/IMPL-FEEDBACK-FASE-{N}.md`, one per FASE, appended as spec-level issues appear (create it with the first
entry). `sdd-req-change --file feedback/IMPL-FEEDBACK-FASE-{N}.md` processes it.

```markdown
# Implementation Feedback — FASE-{N}

> Generated by: sdd-task-implementer
> Date: YYYY-MM-DD
> Status: PENDING | PARTIALLY-RESOLVED | RESOLVED

## Issues

### IF-{FASE}-{SEQ}: {Short Title}

| Field              | Value |
|--------------------|-------|
| **ID**             | IF-{FASE}-{SEQ} |
| **Severity**       | BLOCKER | WARNING |
| **Task**           | TASK-F{N}-{SEQ} |
| **Affected Specs** | {comma-separated spec file paths} |
| **Category**       | AMBIGUITY | CONFLICT | MISSING-BEHAVIOR | INCORRECT-CONTRACT | STALE-DECISION | SPEC-DEVIATION | TOOL-GUARDRAIL | COVERAGE-GAP | ENV-REQUIRED |
| **Status**         | OPEN | RESOLVED | WONT-FIX |

**Problem:**
> {Detailed description of what the implementer found}

**Evidence:**
> {Code context, test failure, or concrete example showing the issue}

**Suggested Resolution:**
> {Implementer's recommendation — e.g., "UC-005 should define the valid formats"}

**Workaround (if WARNING):**
> {How the implementer proceeded despite the issue, or "N/A — BLOCKER"}

---
```

A `SPEC-DEVIATION` entry (the implementer believes the spec should differ; the spec is still implemented as written)
also carries `| **Spec** | {spec ID and exact text} |`, `| **Deviation** | … |`, `| **Impact** | … |` and
`| **Recommendation** | AMEND \| KEEP \| NEEDS-DISCUSSION |`, with `Status: PENDING-REVIEW`. A `COVERAGE-GAP` entry
(Phase 9: a source file at 0% coverage and not excluded) names the file and recommends
`/sdd-task-generator --fase=N --incremental`. An `ENV-REQUIRED` entry (Phase 3: the task reads an environment
variable that the profile's `env_required` does not list) names the variable, never its value.

---

## Bench Events

One JSON line per event in `.sdd/bench/events.jsonl` of the **current checkout** (worktree or main; git-ignored).
`--integrate` concatenates the worktree files into `$SDD_STATE_ROOT/.sdd/bench/events.jsonl` before suggesting the
worktree removal; `scripts/sdd-bench.sh [--fase N]` turns the file into `BENCH-FASE-N.md`. A skipped event never blocks
a task; the script falls back to `git log`.

| Field | Value |
|-------|-------|
| `ts` | ISO-8601 UTC (`date -u +%Y-%m-%dT%H:%M:%SZ`) |
| `role` | `$SDD_ROLE`, or `-` |
| `fase` | FASE number (JSON number) |
| `stream` | Stream letter in Stream mode (`A`, `base`), else `-` |
| `event` | `task-start` (Phase 3) · `task-commit` (Phase 7) · `pause` (every PAUSE) · `merge` / `merge-conflict` (`--integrate`, one `merge-conflict` per file) · `fase-verified` (Phase 9, when the tag is placed) |
| `task` | `TASK-F{N}-{SEQ}` for `task-start`, `task-commit`, `pause`; empty otherwise |
| `sha` | short SHA for `task-commit`, `merge`, `fase-verified`; empty otherwise |
| `file` | only in `merge-conflict`: the conflicted path |

Helper (define once per session; `FASE` = FASE number, `STREAM` = Stream name or empty):

```bash
sdd_bench_event() { # sdd_bench_event EVENT [TASK] [SHA] [FILE]
  mkdir -p .sdd/bench
  printf '{"ts":"%s","role":"%s","fase":%s,"stream":"%s","event":"%s","task":"%s","sha":"%s"%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SDD_ROLE:--}" "${FASE:-0}" "${STREAM:--}" \
    "$1" "${2:-}" "${3:-}" "${4:+,\"file\":\"$4\"}" >> .sdd/bench/events.jsonl
}
```
