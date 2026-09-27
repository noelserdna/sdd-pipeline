---
name: sdd-acceptance
description: "Acceptance per requirement: tests to verdicts (VERIFIED, FAILING, MISSING, WAIVED) with evidence, ID-chain integrity (broken or dangling references), loop until every Must is met, customer sign-off, shareable status page. Triggers: 'acceptance', 'did we reach the goal', 'sign-off', 'broken references', 'status page', 'aceptación', 'verificar requisitos', 'página de estado', 'cerrar entrega'."
hooks:
  Stop:
    - type: prompt
      prompt: "If this session did not run sdd-acceptance --loop, answer YES. If it did, answer YES only if the loop stopped with `goal`, or every open Must requirement named in its final summary has an explicit human disposition (fix later, waiver with a follow-up issue, or change of the requirement) or is listed as pending a human decision."
      once: true
---

# SDD Acceptance

This skill answers the question the rest of the pipeline cannot: **is each requirement satisfied, and with what
evidence?** It closes the chain REQ → UC → BDD → TASK → COMMIT → CODE → TEST with a verdict per requirement.

The `sdd` CLI decides; the skill gathers evidence, routes work and asks people. Verdicts, freshness, gate exit codes
and the loop's stop conditions all come from `sdd accept`, `sdd gate` and `sdd loop next`, so two runs on the same
commit give the same answer and CI can check it with only Node and git. Never compute a verdict yourself, and never
write `acceptance/decisions.jsonl` or `acceptance/ACCEPTANCE-REPORT.md` by hand: the upstream guard denies those edits
and the CLI regenerates them.

```bash
SDD="${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs"     # in CI: SDD=.claude/sdd/sdd.mjs
```

Every command below runs as `node "$SDD" <sub>`: `$SDD` holds only the path, because zsh does not word-split a
variable, so `SDD="node …"` followed by `$SDD accept` fails there.

## Invocation

```
/sdd-acceptance --check                 # capture tests, ledger + report, chain integrity (default)
/sdd-acceptance --fase N                # the same, scoped to the Requisitos: line of plan/fases/FASE-N-*.md
/sdd-acceptance --loop [--fase N] [--max-cycles 3]   # goal loop until every Must is VERIFIED or WAIVED
/sdd-acceptance --sign-off [--fase N | --release NAME] # gate + human acceptance + tag
/sdd-acceptance --publish [--fase N]    # PR/issue block + optional status page
```

### Flags

| Flag | Meaning |
|---|---|
| `--check` | Default mode. Steps 1-6 below |
| `--fase N` | Scope every step to FASE N; combines with `--loop`, `--sign-off`, `--publish` |
| `--loop` | Goal loop (below) |
| `--max-cycles N` | With `--loop`: cycle limit, default 3; the CLI caps it at 5 |
| `--sign-off` | Release gate and recorded human acceptance (below) |
| `--release NAME` | With `--sign-off` and no `--fase`: the release to accept (e.g. `v1.4.0`) |
| `--publish` | PR/issue acceptance block and, optionally, the shareable status page (Artifact) |

## Verdicts and evidence

| Verdict | Rule (applied by `sdd accept`, first match wins) |
|---|---|
| DEPRECATED | Requirement marked deprecated; listed apart, never blocks |
| WAIVED | A human waiver recorded for the current text of the requirement; a waived Must carries reason, role and follow-up issue, and makes the gate exit 3 |
| FAILING | Some fresh evidence fails |
| MISSING | Some criterion has no fresh evidence (not implemented, not tested, or the test is not named with its scenario id) |
| VERIFIED | Every criterion has valid evidence for the requirement's `Verification:` method; the report shows how many ("3/5") |

Evidence by method (the `Verification:` line written at requirements time):

- `test` — a passing JUnit test case whose name contains the scenario id `AC-NNN-NN` of `spec/tests/BDD-*.md` (or
  `REQ-X-NNN ACn`). File-level `Refs:` never count: they bind a whole file to a requirement and produce false
  VERIFIED verdicts.
- `demo` — observed output a human confirmed, recorded with `sdd accept record demo`.
- `measurement` — an observation the CLI compares with its threshold: produced by a command for objective metrics
  (`sdd accept measure --command CMD --extract REGEX`, re-run by `sdd accept --remeasure` when stale), or confirmed
  by a person (`sdd accept record measurement`).
- `inspection` — a recorded human review (`sdd accept record inspection`).

Evidence counts only while fresh: nothing under the Stack Profile's `code_paths` and `test_paths` (default `src`,
`tests`) may have changed, committed or not, since the test results were captured, and each record stays valid while
the files it names (those paths when it names none) are unchanged since its commit. Commits to docs, `feedback/`,
specs or `acceptance/` do not age evidence; a build or test config outside those paths only does when the profile
lists it in `code_paths`. Human records are tied to a hash of the requirement's statement and criteria, so a MODIFY
through `sdd-req-change` reopens the requirement automatically ("Decisions to re-confirm" in the report). The rules live in `scripts/lib/acceptance.mjs`.

## Phase 0: Context

1. Read `pipeline-state.json` if present (the stage key of this skill is `acceptance`; the H3 hook marks it running
   when the skill starts). No `requirements/REQUIREMENTS.md` → stop: there is nothing to accept yet.
2. Resolve from the `## SDD Stack Profile` of `CLAUDE.md`: `app_dir`, `code_paths`, `test_paths`, `test_report`,
   `test_report_path`, `acceptance_gate` (reference: `../sdd-task-implementer/references/stack-profile.md`).
3. Run `node "$SDD" lint --needs --json`. Requirements without a valid `Verification:` cannot be accepted: list them; the
   loop routes them as spec gaps.

## `--check` (and `--fase N`)

### Step 1: Capture test results

The ledger reads JUnit XML, so the tests must have written it for the current commit.

1. `git status --porcelain --untracked-files=no -- <code_paths> <test_paths>` must be empty: results from a dirty
   tree are not evidence of any commit. When it is not, say which files are modified and ask whether to commit them
   first or to continue knowing that test evidence will count as stale.
2. `SHA=$(git rev-parse HEAD)`, then run the profile's `test_report` from `app_dir`:
   `(cd "$APP_DIR" && <test_report>)`. Failing tests are expected and are evidence too; the command must produce the
   XML (look under `test_report_path`, else `.sdd/junit/`). No XML newer than the start of the run → report the
   command's output and stop this step.
3. `test_report` missing or `none`: an existing JUnit under the default location is still read (it will usually be
   stale). Otherwise tell the user which command fits their runner (`references/test-report.md`) and offer to add it
   to the Stack Profile; do not guess a command silently.

### Step 2: Ledger and report

```bash
node "$SDD" accept --junit-sha "$SHA" --report acceptance/ACCEPTANCE-REPORT.md [--fase N]
```

Pass `--junit-sha` only when Step 1 ran on a clean tree at `$SHA`; otherwise omit it and the CLI falls back to file
times. When a requirement's route is `remeasure` (a stale measurement first recorded by `accept measure`), run the
same command once more with `--remeasure`: the CLI re-runs that measurement's command, appends the new value and
prints a `remeasured …` line for each, which you show; no person is asked for an objective metric.

The command writes `.sdd/acceptance.json` (git-ignored, read by `sdd-pipeline-status`, the session hook and the MCP
server) and the customer-readable report. Show its summary lines and the report path; for each Must that is not
VERIFIED or WAIVED show one line: id, verdict, criteria passing, and the route the loop would take
(`node "$SDD" loop next --no-out --state .sdd/acceptance-check.json --reset` gives `route_hint` without touching the loop's
own state). Exit 2 means a usage or git problem: show the message.

### Step 3: Chain integrity

The ledger checks evidence; this step checks that the IDs the evidence hangs on exist and connect. Read
`references/chain-integrity.md` and report: broken references (an ID cited but never defined), orphan definitions,
requirements that reach no use case or scenario, tasks marked done without a commit or commits whose `Refs:` cite
undefined IDs. It uses `dashboard/traceability-graph.json` from `scripts/sdd-graph.py` when python3 is available, and
`node "$SDD" tasks status` / `node "$SDD" trace` for the git side. Findings here are defects to fix at their source (a typo in a spec,
a missing BDD scenario); they never change a verdict.

### Step 4: Orphan-code decisions

Code no requirement asked for is part of what the customer receives. If `audits/GAP-ANALYSIS-REVIEW.md` exists (from
`sdd-gap-detector`), list its ORPHAN findings with their decision (PROMOTE, REMOVE, ACCEPT, DEFER) and rationale, and
each one still without a decision as open. The decisions stay recorded in that file; this skill only reads them. Its
absence is fine: mention that `/sdd-gap-detector` finds orphan code.

### Step 5: Test adequacy (optional, advisory)

A test named with the right scenario id can still assert the wrong thing. When `node "$SDD_PLUGIN_ROOT/scripts/sdd-jev.mjs"
status` exits 0, read `references/jev-advisory.md` and screen the VERIFIED `test` criteria of Must requirements with
`scripts/jev/test-adequacy.json`. Flagged tests are listed for a human or the LLM to read; the verdict stays as the
CLI computed it. With exit 3 (Jev off), skip this step during `--check`; at `--sign-off` an independent subagent
answers the same two questions instead (same reference).

### Step 6: Summary and persist

Print, in the user's language:

```
Acceptance {scope} at {sha7} — goal {met | met with waivers | not met}
Must {v}/{t} verified · {w} waived · FAILING {f} · MISSING {m} · stale evidence {s} · Should {v}/{t}
Open Musts: {id (verdict, criteria n/m, route)} …
Chain: {b} broken references · {o} orphan definitions · {u} requirements without scenarios
Orphan code: {d} decided · {o} without decision        (only with GAP-ANALYSIS-REVIEW.md)
Test adequacy (advisory): {k} flagged                  (only when Step 5 ran)
Report: acceptance/ACCEPTANCE-REPORT.md
Next: {/sdd-acceptance --loop | /sdd-acceptance --sign-off | …}
```

Then persist the stage:

```bash
bash "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-state.sh" set acceptance done
```

and patch `stages.acceptance.summary` (jq under the same file, tmp → mv) with `artifacts`
(`acceptance/ACCEPTANCE-REPORT.md`), `metrics` (`must_total`, `must_verified`, `must_waived`, `failing`, `missing`,
`stale_evidence`, `goal`, `gate_exit`, `loop_cycles`, `loop_stop`, `test_edits`, `evaluated_sha`, `mode`),
`highlights` (≤ 5) and `nextStep`. Then commit what this run wrote under `acceptance/` (the report and any records
appended by `--remeasure`), as every stage commits its outputs (plugin-root `references/git-conventions.md`,
§ Stage outputs are committed). The report names the SHA it evaluated, so a later reader can tell whether it is
current, and the commit touches no code path, so it does not age the evidence:

```bash
git add acceptance/
git diff --cached --quiet || git commit -m "docs(acceptance): acceptance report at {sha7}" --trailer "Refs: <evaluated REQ ids>"
```

## `--loop`

The loop drives the project toward the goal "every Must VERIFIED or WAIVED", following the pattern of the
Convergence Protocol in `sdd-spec-auditor`: each cycle measures, acts on what is open, and measures again. The stop
decision belongs to `sdd loop next`, which compares the cycle with the previous ones; do not continue past a stop and
do not stop early on your own judgment, except to ask a human something the next action depends on.

`--loop` and `--sign-off` commit (feedback, records, report), and on the default branch those commits belong on a
work branch, not on the delivered line. Before the first commit run `node "$SDD" branch start acceptance`: on the
default branch it creates `acceptance/{YYYY-MM-DD}` (or resumes it), on any other branch it stays there
(plugin-root `references/git-conventions.md`, § Branches).

```
first cycle: node "$SDD" loop next --reset [--fase N] [--max-cycles M]        # baseline
repeat:
  Step 1 (capture tests at the current commit)
  R = node "$SDD" loop next --junit-sha "$SHA" [--fase N] [--max-cycles M]
  if R.stop != null: break
  bash "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-state.sh" set task-implementer done
  act on R.targets (Musts) by route_hint; R.others (Should, Nice) are reported, not worked on
```

`stop` is `goal`, `regression` (a Must that was VERIFIED in an earlier cycle is open again), `no-progress` (VERIFIED
did not rise and FAILING + MISSING did not fall), `max-cycles`, or `needs-human` (everything left needs a person).
Marking `task-implementer` done before routing matters: a stage left `running` makes the upstream guard block the
`task/` writes of `sdd-task-generator --incremental`.

### Routes

The FASE of a requirement is the one whose `plan/fases/FASE-N-*.md` lists it in its `Requisitos:` line
(`grep -l "REQ-F-004" plan/fases/FASE-*.md`); write feedback entries in `feedback/IMPL-FEEDBACK-FASE-{N}.md` using the
entry format of `../sdd-task-implementer/references/recovery-and-report.md`, and commit them before routing, so the
next skill reads them from git (§ Stage outputs are committed):

```bash
git add feedback/
git diff --cached --quiet || git commit -m "docs(feedback): acceptance findings for FASE-{N}" --trailer "Refs: FASE-{N}"
```

| `route_hint` | Meaning | Action |
|---|---|---|
| `implement-or-test` | A criterion has a scenario but no passing, fresh test bound to it | Feedback entry `MISSING-BEHAVIOR` (or `COVERAGE-GAP` when the code exists and only the test is missing) naming the requirement, criterion and scenario id; `/sdd-task-generator --fase N --incremental`; `/sdd-task-implementer --fase N --new-tasks-only`. When a test exists but lacks the scenario id in its name, renaming it is a test edit (below) |
| `fix-code (Art. 12)` | A bound test fails | The code is wrong, not the test: feedback entry with the failure, incremental task, implementer. Never weaken, skip or rewrite the assertion to make it pass. If you believe the test or the criterion itself is wrong, that is a spec gap |
| `spec-gap (human, req-change)` | A criterion without any scenario, a requirement without `Verification:`, or a spec that looks wrong | `SPEC-DEVIATION` entry (Spec, Deviation, Impact, Recommendation, `Status: PENDING-REVIEW`) and ask the human: keep the spec (then the missing scenario goes to `sdd-test-planner`/the spec owner) or amend it through `/sdd-req-change`. The loop does not edit specs |
| `remeasure` | A measurement recorded by `accept measure` is stale (its code paths changed) | `node "$SDD" accept --remeasure [--fase N]` re-runs its command and appends the new value; nobody is asked. A value that now fails its threshold turns the requirement FAILING and routes as `fix-code` |
| `needs-human` | `demo`, `measurement` or `inspection` evidence is missing or failing, and no command can re-measure it | Prepare what the person needs (run the demo command and capture its output, run the measurement), show it with the criterion, and ask. Record only what they confirm, with their name and role: `node "$SDD" accept record demo --req ID --ac N --observed TEXT --pass true\|false --by NAME --role ROLE [--paths P…]` (or `measurement` / `inspection`, see `node "$SDD" --help`). The tool guard asks for confirmation before `accept record`; for demo output, `scripts/jev/evidence.json` can pre-screen it (advisory) |
| `rerun-tests` | Evidence exists but is stale | Nothing to do beyond Step 1 of the next cycle |

Cycles run sequentially in the main thread: each one needs the commits of the previous one. The implementer's own
commits are the only code changes; this skill does not edit code or tests directly.

**Station mode** (`SDD_ROLE` set, multi-session). A station writes only what its role owns, and the QA role owns
`.sdd/`, `acceptance/` and `feedback/` but not `task/` or code, so the upstream guard would deny the writes of
`sdd-task-generator` and `sdd-task-implementer`. There the loop writes the feedback entries of the cycle, does not run
either skill, and hands off to the lead (plugin-root `references/handoff-protocol.md`) with `status=blocked` and the
route list as a highlight line (`routes: REQ-F-004 implement-or-test FASE-2; REQ-F-007 fix-code FASE-3`; the same list
goes into `summary.highlights`), then ends its turn. The lead dispatches
task-generator and task-implementer to their owners and sends the loop back (`skills/sdd-lead/SKILL.md`, phase 10);
the next cycle continues from `.sdd/acceptance-loop.json`, without `--reset`. `needs-human` and `spec-gap` items go to
`$SDD_STATE_ROOT/.sdd/questions-<role>.md` as questions for the lead (`references/async-questions.md`).

### Test edits inside the loop

A test changed during the loop could make a criterion pass without the behaviour. Before the final summary, list
every test file that existed at the loop's first cycle and was modified since:
`git diff --name-status <cycle-1 evaluated_sha>..HEAD -- <test_paths>` (the SHA is `cycles[0].evaluated_sha` in
`.sdd/acceptance-loop.json`), keeping `M` and `R` entries. Show each diff to the human and ask whether to approve it.
A rejected edit is reverted with a new commit (`git revert` of that commit, or a `fix` task restoring the assertion)
and its criterion returns to the loop. Record the approved ones in `highlights` and `metrics.test_edits`, and in the
PR body of `--publish`.

### When the loop stops

- `goal` → print the summary and recommend `/sdd-acceptance --sign-off`.
- Any other stop → every open Must needs an explicit human disposition before the skill ends, because a stop is not
  an answer to the customer. Ask with `AskUserQuestion` (up to 4 requirements per call), per requirement:
  **Fix later** (a `BLOCKER` feedback entry, or an issue when a tracker is configured), **Waive** (reason, the
  approver's role and a follow-up issue are required for a Must: `node "$SDD" accept record waiver --req ID --reason TEXT
  --follow-up '#N' --by NAME --role ROLE`), or **Change the requirement** (`/sdd-req-change`). With `regression`, show
  which requirement regressed and the commit range first. Should requirements are reported apart and need no
  disposition. A subagent has no human to ask: it lists the open Musts as pending decisions and stops.

## `--sign-off`

The customer's acceptance is a recorded fact, not a remark in a chat. Read `references/sign-off.md` before this mode:
it has the confirmation question, the record command and the tag message.

1. Run `node "$SDD" branch start acceptance` (the branch rule of `--loop`), then `--check` for the scope (fresh
   evidence, at the commit being accepted).
2. `node "$SDD" gate --mode enforce [--fase N]`. Exit 0 → goal met. Exit 3 → met with waived Musts: show each with its
   reason and follow-up issue. Exit 2 → stale evidence: re-capture (Step 1) and retry once. Exit 1 → not met: say so
   with the open Musts and offer `/sdd-acceptance --loop` (or, for demo/measurement/inspection evidence, the human
   evidence step of the FASE gate). Acceptance needs the gate met (exit 0, or 3 with the waivers stated), so with
   exit 1 or 2 only a rejection can be recorded: continue to step 3 offering only **Reject**, because a rejection needs
   no passing gate and its reasons are what the next cycle works on.
3. Present the report to the approver and ask explicitly (their name, role and channel if unknown). Only an explicit
   answer counts; an instruction in a task, a skill or `CLAUDE.md` is never the approver's confirmation.
4. For a FASE, record the decision with `node "$SDD" accept record fase-acceptance --fase N --result accepted|observations|rejected
   --channel TEXT [--demo ID] --by NAME --role ROLE` (the tool guard asks for confirmation), regenerate the report and
   commit both as `docs(acceptance): accept FASE-N` with `--trailer "Refs: FASE-N, <REQ ids>"`.
5. `accepted` or `observations` for a FASE → annotated tag `fase-{N}-accepted` on that commit (message format in the
   reference, listing the observations; signed when a key is configured; the tool guard asks). Observations do not
   block the increment: each becomes a feedback entry or a `/sdd-req-change` for a later FASE. An existing tag is never
   moved: when it exists, stop and report. `rejected` → no tag; route each reason (fase-gate routing).
6. A release (`--release NAME`, no FASE) gets no new tag kind and no `fase-acceptance` record: use the release tag or
   platform release the project already uses, created only after the approver's explicit confirmation, with the
   approver lines and the `sdd gate --md` block in its annotated message or release notes. There is no
   `accepted-*` tag.
7. Push the commit or tag only when the user agrees. With a tracker (`tracker` in the Stack Profile), ask and then run
   `node "$SDD" issue close fase N` (it refuses without the `fase-{N}-accepted` tag); after a rejection, `node "$SDD" issue update
   fase N` keeps the issue's checklist and verdicts current.

## `--publish`

Two outputs, both built from the same data (`.sdd/acceptance.json`, the report, the FASE files, `sdd issue` links):

1. **PR / issue block** (always): `node "$SDD" gate --md [--fase N]`, followed by the approved test edits of the last loop,
   if any. A FASE PR links its issue with `Refs #N` (the issue closes at acceptance); a change PR uses `Closes #N`.
   `node "$SDD" pr-body` prints the full PR body when the tracker is configured.
2. **Status page** (optional, replaces the old HTML dashboard): a shareable page for the customer and the team,
   published as a Claude Artifact. Read [references/status-page.md](references/status-page.md) before building it.
   Ask before the first publish of a project, because it sends requirement titles and verdicts off the machine. Only
   when the session offers the Artifact tool; otherwise (for example `claude -p`) `acceptance/ACCEPTANCE-REPORT.md`
   is the shareable view.

Nothing is pushed, created or published without asking.

## Constraints

- The CLI decides verdicts, freshness, the gate and the loop's stop; the skill never overrides them, and Jev is
  advisory only (it never decides a verdict, waiver, sign-off, stop or anything in CI).
- Tests verify the specification (Art. 12): code is fixed, tests are not bent; a test edit is listed and approved by
  a human.
- Human records (`accept record`, acceptance tags) are made only after the named person confirms in this
  conversation. The tool guard asks and the upstream guard blocks hand edits of `acceptance/decisions.jsonl` and the
  report; together they prevent accidental self-approval, they are not a guarantee.
- Read-only on `requirements/`, `spec/`, `plan/`, `task/` and code; writes `acceptance/` through the CLI, feedback
  entries, `.sdd/` state and the `acceptance` stage of `pipeline-state.json`.
