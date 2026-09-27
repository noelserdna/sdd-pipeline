# Git conventions (SDD)

The single reference for commits, branches, merges and tags in an SDD project. Git history is the evidence that a
task was done and a requirement delivered, so every rule here exists to keep that evidence machine-readable.
Validator: `node scripts/sdd.mjs verify` (also run by the commit-msg hook). Queries: `node scripts/sdd.mjs trace`.

## Trailers

| Trailer | Value | Required on |
|---|---|---|
| `Task` | one id `TASK-F{N}-{NNN}` (`^TASK-F\d+-\d{3,4}$`) | `feat`, `test`, `refactor`; `fix`/`perf` need `Task` **or** `Change` |
| `Refs` | spec ids, comma-separated (`REQ-F-001, UC-003, API-002`) | `docs(specs)` |
| `Change` | `CHG-YYYY-MM-DD-NNN`, `CR-N` or a finding id (`SEC-12`, `AUD-7`) | `fix`/`perf` without a task (hotfix, audit fix) |

- Subject: Conventional Commits, `<type>(<scope>): <summary>`, type in `feat fix docs style refactor perf test build ci chore revert`.
- Exempt from trailers: other `docs`, `chore`, `ci`, `style`, `build`; merges (`Merge …`); `Revert "…"`;
  `fixup!`/`squash!`/`amend!`; any message containing `[skip-sdd]`.
- Keys are matched case-insensitively, but write them as `Task`, `Refs`, `Change` (other spellings get a warning).
- One commit = one task: a commit carries a single `Task`.
- Ids match as exact tokens: `REQ-F-01` never matches `REQ-F-012`.

### Write trailers with `--trailer`, never by hand

Git reads trailers only from the **last paragraph** of the message, and only when every line of that paragraph is a
trailer. Prose after the block, a `Closes #12` line inside it, or attribution added as a separate paragraph silently
turns the whole block into body text, and the task stops counting as done. `git commit --trailer` (git ≥ 2.32)
always builds a valid block:

```bash
git commit -m "feat(tasks): create task with server-side validation" \
  -m "Validates title length and due date per RN-004." \
  --trailer "Task: TASK-F2-003" \
  --trailer "Refs: UC-002, API-002-01, RN-004" \
  --trailer "Refs: BDD-UC-002" \
  --trailer "Co-Authored-By: <the attribution line your harness asks for>"

git commit -m "fix(auth): reject expired reset tokens" --trailer "Change: CHG-2026-09-27-001" --trailer "Refs: REQ-F-014"
git commit -m "docs(specs): clarify RN-004 retry window" --trailer "Refs: CR-12, REQ-F-004, UC-002"
```

When the harness asks for an attribution line, pass it through `--trailer` too, so it lands in the same block
instead of a new paragraph; do not add one otherwise.
Repeated `Refs` trailers are fine; readers join them. Check a message before committing with
`git interpret-trailers --parse < msg.txt` or `node scripts/sdd.mjs verify --message msg.txt`.

## Branches

| Work | Branch |
|---|---|
| FASE N | `fase-{N}-{slug}` |
| Requirement change | `change/{CHG-ID}-{slug}` |
| Audit fixes | `audit/fix-{YYYY-MM-DD}` |

With an issue, prefix the issue number: `42-fase-3-billing` (GitLab links branches by that prefix).

Rule before any commit: on the default branch, create the work branch (`git switch -c`, uncommitted changes carry
over); on a work branch, keep working there; on a detached HEAD, stop and ask. `node scripts/sdd.mjs branch start
<fase|change|audit> <id> <slug> [--issue N]` applies it; `branch status` reports the state. The default branch is
`default_branch` in the SDD Stack Profile, else `origin/HEAD`, else `init.defaultBranch`, else `main`/`master`.
Stream worktrees (`--stream`) and their integration (`--integrate`) manage their own branches and skip this rule.

## Merges: merge commits only

Squash and rebase merges rewrite the per-task commits into one, which erases every `Task:` trailer. Merge with a
merge commit, locally and on the platform (disable squash/rebase merge in repository settings). `sdd verify --range
base..head` fails when a range touches code paths but carries no `Task:` trailer, which is how a squash shows up.

To put trailers on a merge commit:

```bash
git merge --no-ff --no-commit fase-3-billing
git commit -m "Merge fase-3-billing: FASE-3 billing" --trailer "Refs: FASE-3, REQ-F-020, REQ-F-021"
```

## Tags

Annotated always (`git tag -a`), signed (`-s`) when a signing key is configured. Tags mark states that a later
question needs ("was REQ-X delivered, and when?"):

- `fase-N-foundation`, `fase-N-verified` — kept for Streams (foundation done; FASE integrated and verified).
- `requirements-v{N}` and `fase-{N}-accepted` — introduced with requirement acceptance; once a `fase-*-accepted`
  tag exists, all new work starts on a branch.

## Native queries

```bash
git log --format='%h %(trailers:key=Task,valueonly,separator=%x2C) %s'      # task per commit
git log --format='%h %s' --grep='REQ-F-004'                                 # rough; prefer: sdd trace req REQ-F-004
git log --first-parent main                                                 # one line per merged branch
git log -S'retryWindow' --oneline                                           # commits that added/removed a string
git log -L '/function validate/,+20:src/tasks.ts'                           # history of a function
git bisect run npm test                                                     # first bad commit
git tag --contains <sha>                                                    # releases that ship a commit
```

SDD wrappers (exact id matching, reverts subtracted, legacy body trailers read and marked `legacy`):

```bash
node scripts/sdd.mjs trace req REQ-F-004           # commits for an id
node scripts/sdd.mjs trace why src/tasks.ts:42     # blame → commit → Task/Refs/Change
node scripts/sdd.mjs trace delivered REQ-F-004     # tags and branches that contain that work
node scripts/sdd.mjs trace commits --files --json  # full trailer index
```

## Not used: git notes

Notes are not pushed or fetched by default and GitHub does not show them, so evidence stored there gets lost. All
traceability lives in trailers, tags and the SDD artifacts.
