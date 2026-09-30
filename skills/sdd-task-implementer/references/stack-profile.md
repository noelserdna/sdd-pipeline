# SDD Stack Profile

> Reference for how sdd-task-implementer resolves the project's commands, paths and task-state conventions.
> SKILL.md never hardcodes a tool: every command in Phases 4-9 is a profile key written as `{key}`.

---

## 1. Contract

A section of the project's root `CLAUDE.md` (written by `/sdd-setup --stack=<kit>` or by hand):

```
## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=<kit> -->
- stack: rails|nextjs-prisma|ts-workers|python|custom
- app_dir: web            # repo-relative, "." = root
- code_paths: web/app, web/lib
- test_paths: web/test
- install: <cmd|none>
- test: <cmd>              # full own suite
- test_file: <cmd with {file}>
- test_name: <cmd with {pattern}|none>
- typecheck: <cmd|none>
- lint_files: <cmd with {files}|none>
- lint: <cmd|none>
- build: <cmd|none>
- coverage: <cmd|none>
- db_reset_safe: <local non-destructive-outside-the-app reset|none>
- server: <cmd with {port}|none>
- port: <n>
- acceptance: <cmd from repo root; ID filter appended as --grep <ID>|none>
- test_report: <cmd that writes JUnit XML to .sdd/junit/ (or test_report_path)|none>
- test_report_path: <file, dir or dir/*.xml>   # optional; default .sdd/junit/
- acceptance_gate: off|warn|enforce
- tracker: github|gitlab|off
- e2e_scaffold: allowed|never
- task_state: checkbox|trailers
- task_format: full|compact
- default_branch: <branch>   # optional; see the table
- visual_evidence: required|warn|off
- evidence_dir: <dir>        # default evidencias
- adversarial_gate: off|warn|enforce
- literal_gate: off|warn|enforce
- test_slots: <n>
- staging_url: <url|none>
- smoke: <cmd|none>
- smoke_report_path: <dir>   # default .sdd/junit/smoke
- env_required: <NAME, NAME…|none>
- deploy: <text|none>        # informative; nothing runs it
```

Parsing: one `- key: value` per line until the next `## ` heading; text after `#` preceded by whitespace is a comment;
values are trimmed. Unknown keys are ignored with `WARN stack-profile: unknown key <key>`. A missing key takes the
detected/kit/legacy value (§3), then the default below.

| Key | Used in | Default when absent everywhere |
|-----|---------|--------------------------------|
| `app_dir` | every command except `acceptance` runs from it | `.` |
| `code_paths` / `test_paths` | Output Artifacts, trace scope, coverage scope, acceptance freshness (below) | `src` / `tests` |
| `install` | Setup tasks, G-08 | `none` |
| `test` | Foundation checkpoint, Phase 9, Phase 9-S, after each merge of `--integrate` | — (G-08 HALT) |
| `test_file` | Phase 4 RED, Phase 5 GREEN, Phase 6 per task | `test` without a file filter |
| `test_name` | Phase 4/5 when one test file holds many behaviours | `none` |
| `typecheck` | Phase 6 per task, Phase 9 | `none` |
| `lint_files` | Phase 6 per task (changed files only) | `none` |
| `lint` | Phase 9 | `none` |
| `build` | Phase 9 only | `none` |
| `coverage` | Phase 9 step 4, `--verify` Dimension 4 (its output directory is git-ignored, below) | `none` |
| `db_reset_safe` | after a schema/migration change when the test runner does not prepare the DB; AI Tool Guardrails | `none` |
| `server` / `port` | server helper (§8): config tasks without tests, manual smoke | `none` / `3000` |
| `acceptance` | E2E tasks (`--grep <E2E-ID>`), Phase 9 (once, fail fast) | `none` |
| `test_report` | Phase 9 step 4.0 and `sdd-acceptance --check/--loop` capture test results before `sdd accept`; runs from `app_dir` and writes JUnit XML whose test names carry the scenario id (`AC-NNN-NN`) | `none` (the acceptance ledger then finds no test evidence) |
| `test_report_path` | where `sdd accept`/`sdd gate` read that JUnit (file, directory or `dir/*.xml`, comma-separated) | `.sdd/junit/` |
| `acceptance_gate` | mode of `sdd gate` (`off` · `warn` prints and exits 0 · `enforce` fails when a Must is not VERIFIED or WAIVED) | `enforce`; set `warn` when adopting SDD in a brownfield project |
| `tracker` | issue/PR provider for `sdd issue`/`sdd pr-body` (any push, issue or PR still asks the human) | `off` |
| `e2e_scaffold` | construction-protocol.md E2E step 2 | `allowed` |
| `task_state` | Phase 2, Phase 7, Modes 3/6/7, G-11, `--verify`, I-06/I-09 (§6) | `checkbox` |
| `task_format` | Phase 6 review, Revert (§6) | `full` |
| `default_branch` | branch rule (G-13, `sdd.mjs branch start`), `--integrate` merge target | `origin/HEAD`, then `init.defaultBranch`, then `main`/`master` |
| `visual_evidence` | `sdd accept`: with `required`, a criterion of a REQ-F that passes without an image attached reads `unshown` and its requirement stays MISSING; `warn` only reports it; `off` (no UI at all: a pure API or CLI, decided by a person) ignores it. Read by the test planner and the E2E steps (construction-protocol.md) | `required` |
| `evidence_dir` | where the acceptance suite writes captures and videos, `<dir>/FASE-{N}/` (git-ignored; `sdd accept pack` bundles it) | `evidencias` |
| `adversarial_gate` | how `sdd gate` treats an open challenge of the adversarial round on a Must (`off` · `warn` prints it · `enforce` exits 4) | `warn` |
| `literal_gate` | how `sdd accept` treats a test that names a criterion without carrying its letter (`sdd lint --quotes` Q-02 stale quote, Q-03 missing literal): `enforce` holds a passing Must criterion back as `weakened` (requirement not VERIFIED, loop route `weakened-test`) · `warn` lists the gap · `off` skips the check | `enforce` |
| `test_slots` | how many test processes may run at once on this machine: `[P]` subagents that run tests (SKILL.md → Multi-Agent Strategy), Phase 9-S, one Playwright worker with `1` (§2), the lead's second implementation station, the adversarial verifiers. `1` when tests use an in-memory or shared database, browsers or containers | `2` |
| `staging_url` | base URL of the deployed staging environment for the smoke templates and the test planner's smoke tier | `none` |
| `smoke` | command that runs the post-deploy smoke tier (tests tagged `@smoke-deploy`; `@smoke` is the PR tier) against `staging_url`, e.g. `PLAYWRIGHT_JUNIT_OUTPUT_FILE="$PWD/$SMOKE_REPORT_PATH/smoke.xml" npx playwright test --grep @smoke-deploy --reporter=junit` | `none` |
| `smoke_report_path` | where the smoke run writes its JUnit; the `sdd-smoke` CI templates export it as `SMOKE_REPORT_PATH` and publish it. The acceptance CLI reads only `test_report_path`, so list this directory there too when smoke results should enter the ledger | `.sdd/junit/smoke` |
| `env_required` | environment variables the app needs, comma-separated names (never values). The tech designer proposes the names (DIM-7-002) and a person writes them, with `install-stack-kit.sh --set env_required=…` or by hand. The implementer compares the variables a task reads with this list and records an IF- entry (`ENV-REQUIRED`) for each one missing, because a variable only a local `.env` holds fails first in staging; it never writes `.env` | `none` (no list) |
| `deploy` | informative note on how the project is deployed; no skill runs it | `none` |

`code_paths` and `test_paths` also decide when acceptance evidence goes stale: `sdd accept` discards test results and
records without `--paths` only when files under those paths changed since they were captured, so a docs or feedback
commit leaves them valid. List a build or test config there (`vitest.config.ts`, `package.json`) when a change to it
should invalidate evidence.

Coverage output is generated, never versioned: the task that first configures a coverage tool adds its output
directory (`coverage/`, `.nyc_output/`, `htmlcov/`) to `.gitignore`, below the SDD managed block and in the same task
commit, so later stage commits do not pick up the reports.

`/sdd-setup` writes `task_state: trailers` for new projects: the commit is the evidence, so nothing has to keep a
checkbox in sync. `checkbox` stays the default when the key is absent, for projects created before that.

## 2. Substituting placeholders

- `{file}` — one test file; `{files}` — the files changed by the task, space-separated, shell-quoted; `{pattern}` —
  a test name or regex; `{port}` — the `port` key.
- Paths in task documents are repo-relative. When `app_dir` ≠ `.`, strip the `<app_dir>/` prefix before substituting
  (the command runs inside `app_dir`); drop files outside `app_dir` from `{files}`.
- A command without a placeholder runs as written (e.g. legacy `lint_files: npm run lint`).
- Run: `(cd "<app_dir>" && <command>)`. `acceptance` runs from the repo root; to filter append ` --grep <ID>`
  (`--grep "E2E-WF-001-01|E2E-WF-002-03"` for several).
- `lint_files` with an empty `{files}` (only non-code files changed) is skipped silently.
- Every `{acceptance}` run (an E2E task's `--grep`, Phase 9) exports `SDD_FASE={N}` (the task's FASE) and
  `SDD_EVIDENCE_DIR={evidence_dir}`: `SDD_FASE=2 SDD_EVIDENCE_DIR=evidencias <acceptance> --grep AC-004-01`. The
  suite's configuration reads both to write captures and videos under `{evidence_dir}/FASE-{N}/`; without them a
  capture lands in `FASE-0` or in the default folder, and the FASE gate and `sdd accept pack --fase N`, which show
  `{evidence_dir}/FASE-{N}/`, miss it.
- `test_slots: 1` and a Playwright `acceptance`: append ` --workers=1` as well (another runner: its own one-worker
  flag), so one browser runs at a time on this machine; CI keeps the suite's own setting.
- A key resolved to `none` skips the step and logs, once per session per key:
  `WARN <key>: n/a (stack profile)` — e.g. `WARN typecheck: n/a (stack profile)`. `none` is never a failure and never
  counts as a passed check in the Task Quality Report (`Typecheck: n/a`).

## 3. Resolution order (Phase 0, once per session)

The first source that yields a `stack` wins; later sources only fill keys it left empty. Record the source as
`metrics.profile_source` in Persist Summary.

| # | Source | `profile_source` |
|---|--------|------------------|
| 1 | `## SDD Stack Profile` section in the root `CLAUDE.md` | `declared` |
| 2 | File detection at the repo root and each first-level directory (that directory becomes `app_dir`); keys from `templates/stacks/<kit>/kit.json` → `defaults` when the kit exists in the plugin | `detected` |
| 3 | Legacy text heuristic on `CLAUDE.md` (table §4, unchanged values) | `legacy` |
| 4 | `plan/ARCHITECTURE.md` §2.1 names a stack that has a kit → the kit's `defaults`, and recommend `/sdd-setup --stack=<kit>` in the session log | `architecture` |
| — | Nothing matched | G-08 stops and asks: `Question: Which stack does this project use?  Options: [A] <best candidate> (recommended)  [B] declare ## SDD Stack Profile in CLAUDE.md  [C] run /sdd-setup --stack=<kit>` |

File detection (source 2), checked in this order:

| Files | Stack / kit |
|-------|-------------|
| `Gemfile` + `config/application.rb` | `rails` |
| `package.json` + `next.config.{js,mjs,ts}` + `prisma/schema.prisma` | `nextjs-prisma` |
| `package.json` + `next.config.{js,mjs,ts}` | `nextjs` (kit `nextjs-prisma` defaults minus the DB keys: `db_reset_safe: none`) |
| `wrangler.toml` or `wrangler.jsonc` | `ts-workers` (legacy values §4) |
| `pyproject.toml` or `requirements.txt` | `python` (legacy values §4) |

Kit files live at `${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/templates/stacks/<kit>/kit.json`; only `defaults` is read
here (`wiring` and `layers` belong to `/sdd-setup` and `sdd-plan-architect`). Several matches (e.g. a Rails app in
`web/` and a Playwright project at the root) → pick the one that owns `test_paths` referenced by the task document;
if still ambiguous, ask with the G-08 Question.

Regardless of source, if `plan/ARCHITECTURE.md` exists its project structure wins for file placement.

## 4. Legacy values (projects without a Stack Profile)

The pre-4.3 Stack Detection, verbatim:

```
IF CLAUDE.md mentions "TypeScript" AND "Cloudflare Workers":
  → Test runner: vitest
  → Build: wrangler
  → Deploy: wrangler deploy
  → DB: D1 (SQLite migrations)
  → Queue: Cloudflare Queues

IF CLAUDE.md mentions "Python":
  → Test runner: pytest
  → Build: pip/poetry
  → Deploy: varies

IF plan/ARCHITECTURE.md exists:
  → Follow its project structure exactly
```

The same stacks expressed as profile keys (these are the commands the skill used before 4.3):

| Key | `ts-workers` | `python` |
|-----|--------------|----------|
| `app_dir` | `.` | `.` |
| `code_paths` / `test_paths` | `src` / `tests` | `src` / `tests` |
| `install` | `npm install` | `pip install -r requirements.txt` (or `poetry install` when `poetry.lock` exists) |
| `test` | `npx vitest run` | `pytest` |
| `test_file` | `npx vitest run {file}` | `pytest {file}` |
| `test_name` | `npx vitest run -t "{pattern}"` | `pytest -k "{pattern}"` |
| `typecheck` | `npx tsc --noEmit` | `none` |
| `lint_files` | `npm run lint` | `none` |
| `lint` | `npm run lint` | `none` |
| `build` | `npx wrangler deploy --dry-run` | `none` |
| `coverage` | `npx vitest run --coverage` | `pytest --cov` |
| `db_reset_safe` | `none` | `none` |
| `server` / `port` | `npx wrangler dev --port {port}` / `8787` | `none` |
| `acceptance` | `none` (or detected, §7) | `none` (or detected, §7) |
| `e2e_scaffold` | `allowed` | `allowed` |
| `task_state` / `task_format` | `checkbox` / `full` | `checkbox` / `full` |

## 5. Examples

Rendered by the kit installer (`templates/stacks/<kit>/kit.json` is the source of truth; `{port}` is substituted at install time, `{file}`, `{files}` and `{pattern}` at run time).

**Rails 8 app in `web/`, shared Playwright acceptance suite at the root** — output of `scripts/install-stack-kit.sh --stack rails --app-dir web --port 3001 --set "acceptance=cd acceptance && BASE_URL=http://127.0.0.1:3001 npx playwright test"`:

```
## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=rails -->
- stack: rails
- app_dir: web
- code_paths: web/app, web/config, web/db, web/lib
- test_paths: web/test
- install: bundle install
- test: bin/rails test
- test_file: bin/rails test {file}
- test_name: bin/rails test {file} -n "/{pattern}/"
- typecheck: none
- lint_files: bin/rubocop {files}
- lint: bin/rubocop
- build: none
- coverage: none
- db_reset_safe: bin/rails db:reset
- server: bin/rails server -p 3001 -b 127.0.0.1 -P tmp/pids/sdd-server.pid
- port: 3001
- acceptance: cd acceptance && BASE_URL=http://127.0.0.1:3001 npx playwright test
- test_report: MINITEST_REPORTER=JUnitReporter MINITEST_REPORTERS_REPORTS_DIR="$(git rev-parse --show-toplevel)/.sdd/junit/minitest" bin/rails test
- acceptance_gate: enforce
- tracker: off
- e2e_scaffold: never
- task_state: trailers
- task_format: compact
- visual_evidence: required
- evidence_dir: evidencias
- adversarial_gate: warn
- literal_gate: enforce
- test_slots: 2
- staging_url: none
- smoke: none
- smoke_report_path: .sdd/junit/smoke
- env_required: none
- deploy: none
```

`test_report` needs the `minitest-reporters` gem (see the kit's testing rule). `$(git rev-parse --show-toplevel)` puts
the JUnit under the repo root's `.sdd/junit/` even when `app_dir` is a subdirectory; the JUnit reporter empties its own
directory, hence the `minitest/` subdirectory.

`bin/rails test` keeps the test schema in sync by itself: `db_reset_safe` is only for the development database the
server and the acceptance suite use, after a migration.

**Next.js 16 + Prisma 7 (SQLite) at the root** — output of `scripts/install-stack-kit.sh --stack nextjs-prisma --app-dir . --port 3000`:

```
## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=nextjs-prisma -->
- stack: nextjs-prisma
- app_dir: .
- code_paths: src, prisma
- test_paths: src, tests
- install: npm ci
- test: npx vitest run
- test_file: npx vitest run {file}
- test_name: npx vitest run {file} -t "{pattern}"
- typecheck: npx tsc --noEmit
- lint_files: npx eslint {files}
- lint: npx eslint .
- build: npm run build
- coverage: none
- db_reset_safe: find . -maxdepth 2 -type f \( -name '*.db' -o -name '*.db-journal' -o -name '*.db-wal' -o -name '*.db-shm' \) -not -path './node_modules/*' -delete && npx prisma migrate deploy && npx prisma generate
- server: npx next dev -p 3000 -H 127.0.0.1
- port: 3000
- acceptance: none
- test_report: npx vitest run --reporter=junit --outputFile="$(git rev-parse --show-toplevel)/.sdd/junit/vitest.xml"
- acceptance_gate: enforce
- tracker: off
- e2e_scaffold: allowed
- task_state: trailers
- task_format: compact
- visual_evidence: required
- evidence_dir: evidencias
- adversarial_gate: warn
- literal_gate: enforce
- test_slots: 2
- staging_url: none
- smoke: none
- smoke_report_path: .sdd/junit/smoke
- env_required: none
- deploy: none
```

Never `prisma migrate reset` from the agent: Prisma refuses it for AI agents and the refusal must not be bypassed
(SKILL.md → AI Tool Guardrails). Deleting the SQLite file inside `app_dir` and running `migrate deploy` gives the same
clean local database without any consent step.

## 6. Task state and task format

### Task line grammar

```
- [ ] TASK-F<N>-<SEQ> [P] <Description> | `<path>`[, `<path>`]*
```

Regex: ``^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$``. Continuation lines (Acceptance,
Commit, Refs, Review, Revert…) are indented two spaces.

Tool (same plugin): `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" lint | tasks json|status|index [--fase N] [--json]`
(`scripts/sdd-task-lint.mjs lint|json|status|index` remains as an alias).

- `lint --fase N` — G-12. Its findings (V-19 grammar, legacy `### TASK-F0-001: …` headings, `**TASK-…**` bold ids,
  unindented fields) never stop the implementer: a non-zero exit is logged as `WARN G-12: <n> findings in
  task/TASK-FASE-N.md` and the tasks are parsed tolerantly with `tasks json` (which reads legacy shapes). **0 tasks from
  `tasks json` → HALT** (`task document has no parseable tasks: re-run sdd-task-generator`). When `node` or the script is
  unavailable, parse with the regex above plus the legacy heading form and log `WARN G-12: sdd.mjs unavailable`.
- `tasks json --fase N` — task list for Phase 2 (id, `[P]`, description, write-set, blocked-by, Stream).
- `tasks status --fase N --json [--rev <ref>] [--state checkbox|trailers]` — done-state per task: `Task:` trailers reachable
  from `--rev` (default `HEAD`) minus reverted commits, the checkbox state, `[!]`, and divergences between both.
  `--state` defaults to the profile's `task_state`; with `trailers` an unchecked box is not a divergence.
  `--require-done` exits 1 when a selected task is not done (useful for G-11 / I-06 / I-09).

### `task_state: checkbox` (default)

Current behaviour: Phase 7 marks `- [x]` before the commit and stages the task document in the same commit; every
"`[x]`" check reads the checkbox (at `HEAD` when the skill says so).

### `task_state: trailers`

- Phase 7 never edits checkboxes and never stages the task document: the `Task:` trailer of the commit *is* the
  done-state.
- Every done check of the skill reads `tasks status`: Phase 2 (done/pending), Mode 3 `--continue`, Mode 6 `--new-tasks-only`,
  Mode 7 EXTERNAL dependencies and G-11 (run at the worktree's `HEAD`), `--verify` Completeness,
  integration-protocol I-06 (main checkout `HEAD`) and I-09 (the Stream branch — see integration-protocol.md).
- `[!]` (blocked) is derived: a task is blocked while `feedback/IMPL-FEEDBACK-FASE-{N}.md` has an entry with
  `Severity: BLOCKER`, `Status: OPEN` and that `Task`. Wherever SKILL.md says "mark `[!]`", write or keep that entry.
- Divergences reported by `tasks status` (checkbox `[x]` without trailer, trailer without checkbox) are `WARN`, never
  auto-fixed; the trailer wins.
- Merge conflicts in `task/TASK-FASE-{N}.md` cannot come from task progress, so the "keep both `[x]`" rule of
  integration-protocol.md §2 does not apply; any conflict there is a real content conflict → resolve by hand.

### `task_format: compact`

- A task may omit the **Review** and **Revert** blocks.
- Absent **Revert** = `SAFE`.
- Absent **Review** → Phase 6 uses the checklist for the task's type from
  `${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/skills/sdd-task-generator/references/review-checklist.md` (Universal items +
  the matching task-type block).
- Acceptance, Commit and Refs remain mandatory.

## 7. E2E and acceptance suites

An acceptance suite exists when `acceptance` ≠ `none`, or any of `acceptance/playwright.config.*`, `e2e/`,
`test/system/` exists (repo root or `app_dir`). When one exists:

- never scaffold Playwright or a second E2E project (construction-protocol.md, E2E step 0);
- an E2E task is done when `{acceptance} --grep <E2E-ID>` passes;
- no per-task manual `curl` smoke: the suite is the smoke;
- Phase 9 runs `{acceptance}` once and re-runs only the failing IDs with `--grep` (fail fast).

A detected suite without an `acceptance` key: use `npx playwright test -c <config>` for `acceptance/playwright.config.*`
or `e2e/`, `bin/rails test:system` for `test/system/` (no `--grep`; filter with `bin/rails test test/system -n "/<ID>/"`), and log
`WARN acceptance: detected, not declared (stack profile)`.

## 8. Server helper

Only when a step really needs a running app (config task without tests, manual smoke with no acceptance suite and no
E2E tasks, an acceptance config without its own `webServer`). Define, start, use and stop inside **one** shell
invocation so the server never outlives the block:

```bash
sdd_server_start() { # sdd_server_start PORT  — SERVER_CMD already has {port} substituted
  mkdir -p .sdd
  ( cd "$APP_DIR" && exec sh -c "$SERVER_CMD" ) > .sdd/server.log 2>&1 &
  echo $! > .sdd/server.pid
  curl -s -o /dev/null --retry 60 --retry-delay 1 --retry-connrefused --retry-max-time 60 "http://127.0.0.1:$1/" \
    || { echo "server did not open port $1 within 60 s — see .sdd/server.log"; sdd_server_stop "$1"; return 1; }
}
sdd_server_stop() { # sdd_server_stop PORT
  [ -f .sdd/server.pid ] && kill "$(cat .sdd/server.pid)" 2>/dev/null
  lsof -ti "tcp:$1" 2>/dev/null | xargs kill 2>/dev/null
  rm -f .sdd/server.pid
  return 0
}
trap 'sdd_server_stop "$PORT"' EXIT
sdd_server_start "$PORT" && curl -s "http://127.0.0.1:$PORT/health"
```

- `.sdd/server.log` is the first thing to read when the port never opens; do not restart in a loop.
- A stale `.sdd/server.pid` from an interrupted session → `sdd_server_stop "$PORT"` before starting.
- `server: none` → the step is skipped with `WARN server: n/a (stack profile)`.
- Playwright configs with `webServer` start the app themselves: never start a second server for `{acceptance}`.

## 9. Verification cadence (summary)

| When | Commands |
|------|----------|
| Phase 4 RED / Phase 5 GREEN | `{test_file}` on the task's test file (`{test_name}` to focus) |
| Phase 6, every task | `{test_file}` for the task's tests and tests of changed files, `{typecheck}`, `{lint_files}` on changed files |
| After a schema/migration change | `{db_reset_safe}` only if `{test}`/`{acceptance}` do not prepare the DB themselves |
| E2E task | `{acceptance} --grep <E2E-ID>` |
| Foundation checkpoint | `{test}` (full) |
| Other internal checkpoints | `{test_file}` over the phase's test files |
| `--integrate`, after each merge | `{test}` |
| Phase 9 | `{test}`, `{typecheck}`, `{lint}`, `{build}`, `{coverage}`, then `{acceptance}` once, re-running only failures by `--grep` |
| Phase 9-S (Stream complete) | `{test}` (`test_slots: 1`: `{test_file}` over the Stream's test files) |

Not per task: `{build}`, full `{test}`, full `{acceptance}`, `{db_reset_safe}`, manual server start + `curl` + kill.
