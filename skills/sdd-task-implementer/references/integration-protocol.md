# Integration Protocol (`--integrate --fase N`)

> **Role requirement.** When `SDD_ROLE` is set, the role must own the `integración`/`verificación` write-set (`src/*`, `tests/*`, `.github/*`, config files, `task/TASK-FASE-*.md`, `.sdd/*`) or the upstream guard will deny the writes and the run will PAUSE. The default `sdd-lead` role in `templates/sdd-sessions.example.json` owns it; alternatively run `--integrate` without `SDD_ROLE`.

> Brings the Stream branches of a FASE back into the main checkout: one `--no-ff` merge per Stream, then the
> `integración` and `verificación` tasks, then the normal FASE checkpoint. Every task commit keeps its own SHA and
> its `Refs:`/`Task:` trailers, so traceability (`git log HEAD`) survives the merge. Squashing is forbidden.

`--wave N` is an alias of `--fase N` in this mode. The source of truth for the Streams is the `## Stream Ownership`
table of `task/TASK-FASE-N.md` written by `sdd-task-generator`:

```
## Stream Ownership
| Stream | Tasks | Owns (write-set) | Runs in |
| base | TASK-F1-001, TASK-F1-002 | package.json, src/index.ts | main checkout, before worktrees (checkpoint `fase-1-foundation`) |
| A | TASK-F1-003, TASK-F1-005 | src/api/**, tests/api/** | worktree `feat/fase-1-a` |
| B | TASK-F1-004, TASK-F1-006 | src/cli/**, tests/cli/** | worktree `feat/fase-1-b` |
| integración | TASK-F1-009 | src/index.ts | main checkout, after `--integrate --fase 1` |
| verificación | TASK-F1-010 | — | main checkout, Phase 9 |
```

Naming: Stream `X` → branch `feat/fase-N-x` (lower case), worktree `../<project>-fNx`; the branching point is the
tag `fase-N-foundation` placed after the `base` tasks. Streams whose name is `base`, `integración` or
`verificación` never have a branch.

## 0. Lifecycle of a FASE with Streams

```
main checkout            worktree ../proj-f1a          worktree ../proj-f1b
─────────────            ────────────────────          ────────────────────
--fase 1 --stream base
  → tag fase-1-foundation
                         --fase 1 --stream A            --fase 1 --stream B
                           commits on feat/fase-1-a       commits on feat/fase-1-b
                           Phase 9-S: push + handoff      Phase 9-S: push + handoff
--integrate --fase 1
  merge --no-ff feat/fase-1-a
  merge --no-ff feat/fase-1-b
  integración tasks → --verify → verificación tasks → tag fase-1-verified
  Persist Summary → push --follow-tags → handoff → suggest worktree cleanup
```

### Creating the worktrees

Preferred (outside the repository, so no scanner ever sees another Stream's files):

```bash
git worktree add ../<project>-f1a -b feat/fase-1-a fase-1-foundation
```

`.claude/sdd/sdd-up.sh impl-f1a` runs exactly that for the role's `worktree`/`fase`/`stream` in
`.claude/sdd-sessions.json` and then launches the station (`SDD_ROLE=impl-f1a SDD_STATE_ROOT=<main>`).

Alternative: `claude -w <name>` creates `.claude/worktrees/<name>` inside the repository (ignored through the
`# sdd-begin … # sdd-end` block of `.gitignore`). It branches from the default base ref (usually `origin/HEAD`), so
inside it run `git checkout -B feat/fase-1-a fase-1-foundation` before starting `--stream A`. The hooks resolve the
shared state through the git common dir, so `pipeline-state.json` and `.sdd/trace-map.json` stay in the main
checkout either way; `.sdd/current-task.json` and `.sdd/bench/events.jsonl` are per worktree.

## 1. Preconditions (all HALT unless stated)

| # | Check | Command | On failure |
|---|-------|---------|------------|
| I-01 | cwd is the main checkout, not a worktree | `[ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ]`; when `SDD_STATE_ROOT` is set it must equal `git rev-parse --show-toplevel` | HALT: `cd` to the main checkout |
| I-02 | Working tree clean | `git status --porcelain` prints nothing | HALT: commit or stash first |
| I-03 | Integration branch = project base branch | `git branch --show-current` equals the branch that carries `fase-N-foundation` (`git branch --contains fase-N-foundation`), normally `main` | WARN + Question: [A] switch to it (recommended) [B] integrate here |
| I-04 | Stream Ownership table present | `## Stream Ownership` in `task/TASK-FASE-N.md` with at least one lettered Stream | HALT: nothing to integrate; `--fase N` already covers this FASE |
| I-05 | Stale brake | `stages["task-generator"].status` and `stages["plan-architect"].status` in `$SDD_STATE_ROOT/pipeline-state.json` are not `stale` | PAUSE `Stale upstream: re-run <skill> before continuing` |
| I-06 | `base` tasks are `[x]` in HEAD and `fase-N-foundation` exists | `git show HEAD:task/TASK-FASE-N.md`, `git rev-parse -q --verify refs/tags/fase-N-foundation` | HALT: run `--fase N --stream base` first |
| I-07 | Every lettered Stream has a branch | `git rev-parse -q --verify refs/heads/feat/fase-N-x`, else `git fetch origin feat/fase-N-x` and use `origin/feat/fase-N-x` | Question: [A] skip that Stream (partial integration, reported) [B] abort |
| I-08 | Stream branch descends from the foundation tag | `git merge-base --is-ancestor fase-N-foundation feat/fase-N-x` | WARN: the branch was not created from the checkpoint; expect conflicts |
| I-09 | Stream tasks complete on their branch | every task of the Stream is `[x]` in `git show feat/fase-N-x:task/TASK-FASE-N.md` | WARN + Question: [A] skip the Stream [B] integrate the partial Stream anyway |

Read the tables and branches once; keep `STREAMS="A B …"` in session memory.

## 2. Merge loop (one Stream at a time, table order)

```bash
for X in $STREAMS; do
  x=$(printf '%s' "$X" | tr '[:upper:]' '[:lower:]')
  git merge --no-ff "feat/fase-N-$x" -m "Merge branch 'feat/fase-N-$x' (FASE-N Stream $X)"
done
```

- The message must start with `Merge ` — the SDD `commit-msg` hook lets merge commits through without trailers.
- NEVER `--squash`, NEVER `--ff-only`, NEVER rebase a pushed Stream branch: each task commit must keep its SHA and
  trailers (`Task:` uniqueness and `sdd-traceability-check` depend on it).
- After a successful merge: `sdd_bench_event merge "" "$(git rev-parse --short HEAD)"` (Bench Events in SKILL.md) and
  add the Stream to the `merged` list with its merge SHA.
- Run the full test suite after **every** merge, not only at the end; a failure here is a `PAUSE: Test regression`
  whose cause is the merge itself.

### Merge conflict

`git merge` exits non-zero and `git diff --name-only --diff-filter=U` lists the files. Then:

1. For each file: `sdd_bench_event merge-conflict "" "" "<file>"`.
2. PAUSE (never resolve silently, never `git merge --abort` silently):

```
PAUSE: Merge conflict integrating Stream B (feat/fase-N-b) into FASE-N
  Files: task/TASK-FASE-N.md, src/index.ts
  task/TASK-FASE-N.md → keep BOTH sides: every `[x]` marked by either branch stays `[x]`
                        (two Streams mark different tasks; a checkbox is never un-marked).
  src/index.ts        → resolve by hand following the spec. Two Streams touching the same file
                        violates V-15 (disjoint write-sets): log it in feedback/IMPL-FEEDBACK-FASE-N.md
                        (category CONFLICT) so sdd-task-generator can fix the Stream assignment.
  Then: git add <files> && git commit        (keeps the merge message; no --no-verify, no --squash)
  Question: How do you want to continue?
  Options: [A] Conflict resolved, continue with the next Stream (recommended)  [B] git merge --abort and stop
```

3. On [A]: verify `git diff --name-only --diff-filter=U` is empty and `git log -1 --format=%P | wc -w` = 2 (a real
   merge commit exists), run the test suite, continue the loop. On [B]: `git merge --abort`, report the Streams
   already merged, Persist Summary with `status: "running"`, handoff `status=blocked`, stop.
4. Station mode (a role other than `sdd-lead`): the conflict cannot be resolved without a human — write the
   question (`references/async-questions.md`), hand off `status=blocked`, and end the turn with the merge left in
   progress (`git status` shows it; the lead resumes with `--integrate --fase N` after resolving, which detects the
   merged Streams by their merge commits and skips them).

## 3. After the merges

1. **`integración` Stream**: implement its tasks with the normal Phases 3-7 (breadcrumb, test-first, one commit per
   task with `Refs:`/`Task:`, checkbox-first). These are the wiring tasks that touch files shared by several Streams
   (`src/index.ts`, route indexes, migration indexes).
2. **`--verify --fase N`** (read-only, `references/verification-protocol.md`): every task of `base` and of the
   lettered and `integración` Streams must PASS; only commits reachable from `HEAD` count. Any FAIL → fix before
   tagging (a missing commit means a Stream was integrated incomplete).
3. **`verificación` Stream**: implement its tasks with Phases 3-7 (they usually run the E2E/acceptance suite and
   commit its evidence).
4. **Phase 9** as in SKILL.md: tag `fase-N-verified`, Criterios de Exito, full suite, coverage, completion report
   (the Commit Log lists task commits in `git log HEAD` order, merges included as `merge` rows).

## 4. Post-merge checks (all must hold before Persist Summary)

```bash
# every task of the FASE is [x]
grep -cE '^- \[ \] TASK-F'"$N"'-' task/TASK-FASE-N.md           # → 0
grep -cE '^- \[!\] TASK-F'"$N"'-' task/TASK-FASE-N.md           # → 0 (blocked tasks stop the FASE)
# no task implemented twice (same Task: trailer on two commits)
git log HEAD --format='%(trailers:key=Task,valueonly)' | grep -v '^$' | sort | uniq -d   # → empty
# exactly one verified tag for the FASE, on HEAD
git tag -l "fase-$N-verified" | wc -l                             # → 1
git tag --points-at HEAD | grep -x "fase-$N-verified"             # → found
# each merged Stream has its merge commit
git log HEAD --merges --format=%s | grep -c "(FASE-$N Stream "     # → number of merged Streams
```

A duplicated `Task:` trailer means the same task was committed on two branches (or re-done after a merge): keep the
merge history, revert the later duplicate with `git revert`, and note it in the completion report.

## 5. Bench consolidation, Persist Summary, push, handoff

1. `sdd_bench_event fase-verified "" "$(git rev-parse --short HEAD)"` right after the tag.
2. Consolidate the worktree events **before** suggesting their removal — the files are ignored by git and would be
   lost with the worktree:

```bash
mkdir -p "$SDD_STATE_ROOT/.sdd/bench"
git worktree list --porcelain | awk '/^worktree /{wt=$2} /^branch refs\/heads\/feat\/fase-'"$N"'-/{print wt}' |
while IFS= read -r wt; do
  [ -f "$wt/.sdd/bench/events.jsonl" ] && cat "$wt/.sdd/bench/events.jsonl" >> "$SDD_STATE_ROOT/.sdd/bench/events.jsonl"
done
```

   (`scripts/sdd-bench.sh` de-duplicates identical lines, so running the consolidation twice is harmless.)
3. **Persist Summary** (SKILL.md) with, in addition to the usual fields:
   - `metrics.streamsIntegrated`: number of merged Streams; `metrics.mergeConflicts`: number of conflicted files
   - `highlights`: one line per merged branch (`Merged feat/fase-1-a (3 tasks) → 9f3c2a1`), one line per conflict
     (`Conflict in task/TASK-FASE-1.md resolved (both [x] kept)`), `FASE-1 verified: fase-1-verified`
   - `nextStep`: `"Run /sdd-task-implementer --fase N+1"` (or `--fase N+1 --stream base` when FASE N+1 has Streams)
4. `git push --follow-tags` when `git remote get-url origin` succeeds (the Stream branches were already pushed by
   Phase 9-S; pushing the base branch publishes the merges and the tag).
5. Handoff per `references/handoff-protocol.md` (`stage=task-implementer status=done gate=PASS`).
6. Suggest — never run — the cleanup, one line per Stream:

```
Streams integrated. When the worktrees are no longer needed:
  git worktree remove ../proj-f1a && git branch -d feat/fase-1-a
  git worktree remove ../proj-f1b && git branch -d feat/fase-1-b
  (git push origin --delete feat/fase-1-a feat/fase-1-b   # optional, after the merge is pushed)
Then: scripts/sdd-bench.sh --fase 1   # measures the FASE from .sdd/bench/events.jsonl
```

## 6. Re-running `--integrate`

The mode is idempotent per Stream: a Stream whose merge commit `Merge branch 'feat/fase-N-x' (FASE-N Stream X)` is
already in `git log HEAD --merges` is reported as `already merged` and skipped; `integración`/`verificación` tasks
already `[x]` are skipped by Phase 2; an existing `fase-N-verified` tag makes Phase 9 report instead of re-tagging.
This is how a lead resumes after resolving a conflict or after a station handed off `status=blocked`.
