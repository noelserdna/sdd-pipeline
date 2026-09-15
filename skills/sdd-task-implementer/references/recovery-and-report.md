# Revert, Recovery and Session Report

> Reference for sdd-task-implementer: how to undo a task or a phase, what to do with a task that cannot be
> implemented, the error → recovery table, and the report printed at the end of an implementation session.

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

With `task_state: trailers` the revert commit is enough: `sdd-task-lint.mjs status` subtracts reverted commits, so the
task becomes pending again without touching the task document.

### Rollback to Checkpoint

```bash
# Rollback entire phase to last checkpoint
git revert --no-commit HEAD..fase-{N}-{phase}
git commit -m "revert: rollback to FASE-{N} {phase} checkpoint"
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
- TASK-F0-003: [DECISION PENDIENTE] in ADR-025 line 45

### Skipped checks
- typecheck: n/a (stack profile)

### Next Steps
1. Resolve ADR-025 decision
2. Continue with TASK-F0-003
3. Then TASK-F0-004 (parallel with F0-005)

### Checkpoints
- `fase-0-setup` after TASK-F0-002
```

Include the feedback summary (`feedback/IMPL-FEEDBACK-FASE-{N}.md`: open BLOCKER/WARNING entries, including
`TOOL-GUARDRAIL`) when the session produced any.
