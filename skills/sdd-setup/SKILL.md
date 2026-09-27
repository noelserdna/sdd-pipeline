---
name: sdd-setup
description: "Initializes the SDD pipeline in the current project: checks the sdd-pipeline plugin and dependencies, creates pipeline-state.json, installs the commit-msg hook, quality gates, versioning policy, --multisession, --tracker (CI, PR templates), pre-4.0 migration. Triggers: 'setup SDD', 'init pipeline', 'install SDD', 'upgrade SDD', 'iniciar SDD', 'configurar pipeline', 'migrar SDD'."
---

# SDD Setup

You are the **SDD Setup** assistant. You prepare the current project for the `sdd-pipeline` plugin.

Since 4.0 the plugin itself provides the hooks (`hooks/hooks.json`), the agents and the MCP server (`.mcp.json`). They run from `${CLAUDE_PLUGIN_ROOT}` and are updated together with the plugin. **Setup copies no hooks and no agents into the project.** It only creates the project-owned files below:

| File | Step | Versioned in git? |
|------|------|-------------------|
| `pipeline-state.json` | 1 (never overwritten) | No: per-checkout state, ignored |
| git `commit-msg` hook | 2 | No: lives in the git dir, shared by all worktrees |
| `.claude/sdd/sdd.mjs` and the modules it imports (`lib/*.mjs`, …): the validator the hook runs | 2 | Yes: CI and teammates without the plugin run it |
| `# sdd-begin ... # sdd-end` block in `.gitignore` | 4 | Yes |
| `.claude/sdd-sessions.json`, `.claude/sdd/sdd-up.sh` | 4 (`--multisession`) | Yes |
| H7/H8 quality gates in `.claude/settings.json` | 5 (opt-in) | Yes |
| `## SDD Stack Profile` + `## Stack Conventions` block in root `CLAUDE.md`, `.claude/rules/sdd-<kit>-*.md` | 4b (`--stack`) | Yes |
| Minimal `## SDD Stack Profile` (`task_state: trailers`) in root `CLAUDE.md` when no kit is installed | 4b | Yes |
| CI job, PR/MR and change-request templates (`.github/` or `.gitlab/`), `tracker:` profile key | 4c (`--tracker`) | Yes |

## Invocation

```
/sdd-setup                               # interactive: asks about the optional steps
/sdd-setup --multisession                # also creates .claude/sdd-sessions.json and .claude/sdd/sdd-up.sh
/sdd-setup --quality-gates               # also merges the H7/H8 quality gates without asking
/sdd-setup --stack=rails --app-dir web   # also installs the rails stack kit for the app in web/
/sdd-setup --stack=auto --port 3001      # detects the kit (root and first-level directories)
/sdd-setup --tracker                     # CI job + PR/issue templates for the provider of origin (github|gitlab)
```

### Flags

| Flag | Step | Meaning |
|------|------|---------|
| `--multisession` | 4.3 | Roles file and tmux launcher |
| `--quality-gates` | 5 | Merge H7/H8 without asking |
| `--stack=<kit\|auto>` | 4b | Install or refresh a stack kit (`rails`, `nextjs-prisma`, or `auto`) |
| `--app-dir DIR` | 4b | Application directory relative to the repo root (`.` = root) |
| `--port N` | 4b | Local server port written to the profile |
| `--set key=value` | 4b | Override one profile key (repeatable, remembered on refresh) |
| `--tracker[=github\|gitlab]` | 4c | CI job, PR/MR and issue templates, `tracker:` profile key |

## Ground rules

- Run every check with Bash and **show what you found before changing anything**.
- Run in the **main checkout** of the target project: not in the plugin repository, not in a linked worktree. If `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`, stop and ask the user to run setup from the main checkout (that is where `pipeline-state.json` lives; hooks in worktrees write there through `SDD_STATE_ROOT`).
- Never write absolute paths into project files: the plugin directory changes on every plugin update.
- Never overwrite `pipeline-state.json`; never replace `.claude/settings.json` (merge only); never run `git rm`, `git commit` or `/plugin` commands on the user's behalf.
- Prefer `jq`; when it is missing use `node -e` for the same JSON edits.

## Locating the plugin root

Every step reads files from the plugin. Resolve its path once:

```bash
SDD_PLUGIN_ROOT="${SDD_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"   # exported by the SessionStart hook
if [ ! -f "${SDD_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  REG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
  SDD_PLUGIN_ROOT=$(jq -r '.plugins | to_entries[] | select(.key | startswith("sdd-pipeline@")) | .value[].installPath' "$REG" 2>/dev/null | head -1)
fi
SDD_VERSION=$(jq -r .version "$SDD_PLUGIN_ROOT/.claude-plugin/plugin.json")
```

If the path is still empty, ask the user for it (`claude plugin list` shows whether `sdd-pipeline@...` is installed; its checkout lives under `plugins/cache/` of the Claude config directory). If they cannot provide it, do Step 1 from the JSON shape shown there, then stop and report which steps were skipped and why.

## Process

### Step 0: Detect environment and previous installations

Run the checks and report them as a table:

| Check | Command | Expected |
|-------|---------|----------|
| Plugin | `claude plugin list 2>/dev/null` contains `sdd-pipeline@` | installed; version from `plugin.json` |
| Platform | `uname -s` | `Darwin` / `Linux`. `MINGW*`, `MSYS*`, `CYGWIN*` or `$OS = Windows_NT`: warn that hooks and scripts need bash and recommend WSL |
| git >= 2.32 | `git --version`, `git rev-parse --is-inside-work-tree` | required for Steps 2 and 4; 2.32 added `git commit --trailer`, which every SDD commit uses. Older: warn and recommend upgrading |
| node >= 18 | `node -v` | required (MCP server, hook fallbacks) |
| jq | `jq --version` | optional: hooks and this skill fall back to node |
| python3 | `python3 --version` | optional: only `scripts/sdd-graph.py` (graph for MCP/augment) needs it |
| tmux >= 3.2 | `tmux -V` | optional: only the `--multisession` launcher uses it |

Then look for a **previous installation**: hooks copied into the project before 4.0 (by `install-sdd-automation.sh` or the old `sdd` plugin), or the status lines, trace-map breadcrumbs and activity log that 4.x installed and 5.0 removed. Any hit is a signal:

```bash
ls .claude/hooks/sdd-*.sh .claude/hooks/sdd-*.js .claude/agents/sdd-*.md 2>/dev/null   # copied hooks and agents
ls .claude/sdd-status-line.sh .claude/sdd-subagent-status.sh .sdd/current-task.json .sdd/trace-map.json .sdd/activity*.jsonl 2>/dev/null   # removed in 5.0
grep -E 'sdd-(session-start|upstream-guard|pipeline-state-updater|augment-hook|trace-map-updater|activity-log|runs-line|status-line|subagent-status)' .claude/settings.json 2>/dev/null
[ "$(jq -r '.hooksVersion // 0' pipeline-state.json 2>/dev/null)" -ge 3 ] || echo "old pipeline-state format"
grep -oE '"(sdd@[^"]+|sdd-pipeline@sdd-pipeline-local)"' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" 2>/dev/null   # old plugin ids
```

If any signal is present:

1. Show the signals table and run `bash "$SDD_PLUGIN_ROOT/scripts/migrate-hooks-v3.sh" --dry-run`; show its output verbatim.
2. Ask the user to confirm. The migration backs everything up in `.claude/backups/`, removes the copied hooks/agents and their entries in `.claude/settings.json` (the plugin provides them now), removes the project status line scripts with their `statusLine`/`subagentStatusLine` entries and the legacy `.sdd/` runtime files, reinstalls `commit-msg`, writes `sddVersion`/`hooksVersion: 3` into `pipeline-state.json` and applies the `.gitignore` policy.
3. On confirmation run it without `--dry-run`, then continue with Step 1 (every later step is idempotent). If declined, continue anyway and warn that the project hooks and the plugin hooks will both run until the migration is applied.
4. Old plugin ids cannot be removed by a script: tell the user to run `/plugin uninstall <id>` (and `/plugin marketplace remove <name>` for the marketplace of `sdd@...`).

### Step 1: Initialize `pipeline-state.json`

Location: the root of the main checkout.

- If it exists: **leave it untouched**. Report `currentStage`, `sddVersion`, `hooksVersion` and the status of each stage. If `hooksVersion` is lower than 3 and the migration was declined, say so.
- If it does not exist, instantiate the template and validate it:

```bash
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -e "s/__SDD_VERSION__/$SDD_VERSION/" -e "s/__NOW__/$NOW/" \
  "$SDD_PLUGIN_ROOT/templates/pipeline-state.template.json" > pipeline-state.json
jq -e '.hooksVersion == 3 and (.stages | length) == 7' pipeline-state.json >/dev/null
```

The template holds `sddVersion`, `hooksVersion: 3`, `currentStage: "requirements-engineer"`, `lastUpdated` and the seven stages (`requirements-engineer`, `specifications-engineer`, `spec-auditor`, `test-planner`, `plan-architect`, `task-generator`, `task-implementer`), each `{ "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null }`. Lateral stages (`tech-designer`, `ux-designer`, `security-auditor`, `gap-detector`, ...) are added by the hooks when their artifacts appear.

### Step 2: Git `commit-msg` hook

```bash
bash "$SDD_PLUGIN_ROOT/scripts/install-git-hooks.sh"
```

Installs `hooks/sdd-commit-msg-hook.sh` into the hooks directory git actually uses: `core.hooksPath` when set, otherwise `$(git rev-parse --git-common-dir)/hooks`, which every linked worktree shares. A foreign hook is backed up with a timestamp and `--uninstall` restores it; re-running is a no-op. The installer also vendors the validator into `.claude/sdd/sdd.mjs` (with the modules it imports), stamped with the plugin version and overwritten on every re-install; the hook runs it with node and falls back to the same rules in bash. The rules are those of the plugin-root `references/git-conventions.md`: `Task:` on `feat`/`test`/`refactor`, `Task:` or `Change:` on `fix`/`perf`, `Refs:` on `docs(specs)`, well-formed ids, and no trailer lines outside the trailer block; other `docs`, `chore`, `ci`, `style`, `build`, merges and reverts are exempt; bypass with `[skip-sdd]` in the message or `SDD_SKIP_VERIFY=1`. If the project is not a git repository, skip with a warning.

### Step 3: Upgrade cleanup of user-level status line files

Up to 4.3, setup could install a global status line into the user's own Claude config, fed by an activity hook. The plugin no longer ships it (live observation of multi-session runs is no longer part of the plugin, see [`docs/multisesion.md`](../../docs/multisesion.md)), so a leftover script would keep printing stale data in every session. The project-level copies are removed by the migration in Step 0; this step covers the user-level files, which sit outside the project:

```bash
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ls "$CFG/sdd/status-line.sh" "$CFG/sdd/active-runs.json" 2>/dev/null
jq -r '.statusLine.command // empty' "$CFG/settings.json" 2>/dev/null | grep -E 'sdd/status-line\.sh|sdd-status-line'
```

If nothing is found, skip silently. Otherwise show what was found and ask before touching it, because these are the user's own settings for every project on this machine:

```
| Step 3: Remove the legacy SDD global status line (user-level) |
|   [A] Remove  <- recommended                                  |
|   [B] Keep                                                    |
```

On `[A]`, back up the settings, drop only a `statusLine` that runs an SDD script, and delete the files:

```bash
cp "$CFG/settings.json" "$CFG/settings.json.sdd-bak.$(date +%Y%m%d-%H%M%S)"
jq 'if ((.statusLine.command // "") | test("sdd/status-line\\.sh|sdd-status-line")) then del(.statusLine) else . end' \
  "$CFG/settings.json" > "$CFG/settings.json.tmp" && mv "$CFG/settings.json.tmp" "$CFG/settings.json"
rm -f "$CFG/sdd/status-line.sh" "$CFG/sdd/active-runs.json"
rmdir "$CFG/sdd/active-runs.json.lock" "$CFG/sdd" 2>/dev/null || true
```

Node fallback for the settings edit: `node -e 'const fs=require("fs"),f=process.argv[1];const s=JSON.parse(fs.readFileSync(f,"utf8"));if(s.statusLine&&/sdd\/status-line\.sh|sdd-status-line/.test(s.statusLine.command||""))delete s.statusLine;fs.writeFileSync(f,JSON.stringify(s,null,2)+"\n")' "$CFG/settings.json"`.

### Step 4: Versioning policy

**4.1 `.gitignore`.** Apply the managed block (idempotent; refreshes an outdated block in place):

```bash
bash "$SDD_PLUGIN_ROOT/scripts/migrate-hooks-v3.sh" --gitignore-only
```

| Ignored | Why |
|---------|-----|
| `pipeline-state.json` | Per-checkout state written by the hooks; committing it causes merge conflicts between developers |
| `.sdd/` | Async questions, bench events and other per-checkout runtime files |
| `.claude/worktrees/` | Ephemeral worktrees created by Claude Code |
| `.claude/settings.local.json` | Personal overrides |
| `dashboard/traceability-graph.json` | Generated by `scripts/sdd-graph.py` |

The script warns when `pipeline-state.json` is already tracked and prints the `git rm --cached pipeline-state.json` command: show it to the user, do not run it.

**4.2 Versioned files.** Recommend committing `.claude/settings.json`, `.gitignore`, the vendored `.claude/sdd/*.mjs` and `.claude/sdd/lib/` and, with `--multisession`, `.claude/sdd-sessions.json` and `.claude/sdd/sdd-up.sh`. Report which of them are not yet tracked (`git ls-files --error-unmatch <file>`), without committing.

**4.3 `--multisession`.** Instantiate the roles file from the plugin template, replacing its project name with the project slug (directory name in kebab-case), and copy the launcher:

```bash
SLUG=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
mkdir -p .claude/sdd
[ -f .claude/sdd-sessions.json ] || jq --arg s "$SLUG" '
  .project as $p | .project = $s
  | .roles |= with_entries(.value |= (
      .name |= sub("^" + $p + "-"; $s + "-")
      | if .worktree then .worktree |= sub("^\\.\\./" + $p + "-"; "../" + $s + "-") else . end))' \
  "$SDD_PLUGIN_ROOT/templates/sdd-sessions.example.json" > .claude/sdd-sessions.json
cp "$SDD_PLUGIN_ROOT/scripts/sdd-up.sh" .claude/sdd/sdd-up.sh && chmod +x .claude/sdd/sdd-up.sh
```

Never overwrite an existing `sdd-sessions.json` (the user tailors roles, `owns` globs, colors and worktrees there); refresh `sdd-up.sh` whenever it differs from the plugin copy. Show the resulting roles as a table (role, session name, color, owns, stages, worktree) and explain how to use them:

- The human (not Claude) runs `bash .claude/sdd/sdd-up.sh sdd-lead sdd-spec`: one tmux session per role, started with `SDD_ROLE=<role>` and `SDD_STATE_ROOT=<main checkout>`, named with `claude -n <name>` and colored with `/color`. Connect with `tmux attach -t =<name>`; `Ctrl+B` then `D` detaches without closing. `--dry-run` prints the commands; a role whose session is already alive is skipped.
- Roles with a `worktree` get `git worktree add ../<slug>-f1a -b feat/fase-1-a fase-1-foundation` on first launch (HEAD when the tag does not exist yet).
- Without tmux: `SDD_ROLE=impl-f1a SDD_STATE_ROOT=$PWD claude -n <slug>-impl-f1a` in a separate terminal.
- Recommend adding `"permissions": { "deny": ["Bash(tmux send-keys:*)"] }` to `.claude/settings.json` so no session (the lead included) types into another one; sessions coordinate through the handoff protocol, not through tmux.

### Step 4b: Stack kit (`--stack`)

The implementation skills never guess commands. Tests, lint, build, database reset, server and acceptance suite all come from the `## SDD Stack Profile` section of the root `CLAUDE.md` (contract, resolution order and limits: [`docs/stacks.md`](../../docs/stacks.md)). A **stack kit** writes that section for a known stack, plus a short `## Stack Conventions` section and path-scoped rules. Kits shipped with the plugin: `ls "$SDD_PLUGIN_ROOT/templates/stacks"` (`rails`, `nextjs-prisma`).

| Situation | Action |
|-----------|--------|
| `--stack=<kit\|auto>` given | Show the `--dry-run` output, then install (the flag is the consent) |
| `CLAUDE.md` already has `<!-- sdd-stack-begin kit=` | Refresh without asking: run the installer without `--stack` (it keeps `app_dir`, `port` and `--set` overrides) |
| No flag and no block, but `--stack auto --dry-run` detects a kit | Offer `[A] Install <kit> for <app_dir>` / `[B] Skip` |
| Nothing detected, or no kit for this stack | No kit; write the minimal profile below, and suggest completing it by hand following `docs/stacks.md` |

```bash
KIT_SH="$SDD_PLUGIN_ROOT/scripts/install-stack-kit.sh"
bash "$KIT_SH" --stack rails --app-dir web --dry-run     # show verbatim
bash "$KIT_SH" --stack rails --app-dir web               # + --port N, --set "acceptance=cd acceptance && npx playwright test"
bash "$KIT_SH"                                           # refresh the installed kit
```

- **CLAUDE.md block.** Writes the rendered profile and conventions between `<!-- sdd-stack-begin kit=<kit> v<version> -->` and `<!-- sdd-stack-end -->` in the root `CLAUDE.md`. Text outside the block is preserved, a second run changes nothing, and a newer kit version refreshes the block in place.
- **Rules.** Copies the rules to `.claude/rules/sdd-<kit>-<rule>.md`. It only overwrites files that carry the `sdd-stack-kit managed` header; report any `skipped … left untouched` line to the user.
- **Detection and errors.** `auto` searches the root and first-level directories and sets `app_dir` to where it finds the stack. It exits 1 when it finds nothing or several stacks: ask for `--stack` and `--app-dir`. An unknown kit exits 2: list the available kits.
- **Overrides.** `--set key=value` overrides one profile key and is remembered on refresh; `--set key=` drops the override. An `acceptance` other than `none` implies `e2e_scaffold: never`.
- **Report and commit.** Show the `wiring:` and `layers:` lines it prints (`sdd-plan-architect` uses them) and recommend committing `CLAUDE.md` and `.claude/rules/sdd-*.md`.
- **Never edit inside the block by hand.** `--uninstall` removes the block and the managed rules.

**Minimal profile (no kit).** New projects keep task state in the commits (`task_state: trailers`): the `Task:` trailer is the evidence, so no checkbox has to be kept in sync. When no kit is installed and `CLAUDE.md` has no `## SDD Stack Profile` section, append this block — without asking when `CLAUDE.md` does not exist yet, after asking (`[A] Add it (recommended)` / `[B] Skip`) when it exists:

```markdown
## SDD Stack Profile
- task_state: trailers
```

Add `- default_branch: <name>` only when the user names a default branch that `origin/HEAD` does not reveal. An existing profile is never edited.

### Step 4c: Tracker, CI and PR templates (`--tracker`)

Only with `--tracker`. SDD keeps one issue per FASE and per change and checks every PR/MR in CI (conventions: the plugin-root `references/git-conventions.md`, section "Issues, PRs and CI").

1. **Provider.** The flag value, else the host of `git remote get-url origin`: `github.com` → github; `gitlab.com`, `gitlab.*` or the host of `glab config get host` → gitlab. Anything else: ask. Report `gh auth status` / `glab auth status`; a missing or unauthenticated CLI does not block this step, but `sdd issue …` will exit 2 until it is fixed.
2. **Files.** Copy from `$SDD_PLUGIN_ROOT/templates/`. When a destination exists and differs, show the diff and ask before overwriting it; the team may have tailored it.

| Provider | Source | Destination |
|----------|--------|-------------|
| github | `ci/github/sdd.yml` | `.github/workflows/sdd.yml` |
| github | `tracker/github/pull_request_template.md` | `.github/pull_request_template.md` |
| github | `tracker/github/ISSUE_TEMPLATE/change-request.md` | `.github/ISSUE_TEMPLATE/change-request.md` |
| gitlab | `ci/gitlab/sdd.gitlab-ci.yml` | `.gitlab/sdd.gitlab-ci.yml`, included from `.gitlab-ci.yml` (`include: [{ local: .gitlab/sdd.gitlab-ci.yml }]`: create the file with only that when missing, ask before editing an existing one) |
| gitlab | `tracker/gitlab/merge_request_templates/Default.md` | `.gitlab/merge_request_templates/Default.md` |
| gitlab | `tracker/gitlab/issue_templates/Change-request.md` | `.gitlab/issue_templates/Change-request.md` |

   The CI job runs the vendored `.claude/sdd/sdd.mjs` from Step 2, so those files must be committed too.
3. **Merge method.** Squash and rebase merges erase the per-task `Task:` trailers. Print the repository setting for the user to apply (it changes the project for the whole team, so do not run it): GitHub `gh repo edit --enable-merge-commit --enable-squash-merge=false --enable-rebase-merge=false`; GitLab: Settings → Merge requests → Merge method "Merge commit" and Squash commits "Do not allow". Suggest making the `sdd` check required on the default branch.
4. **Profile.** Write `tracker: <provider>` into the `## SDD Stack Profile` (the `--tracker` flag is the consent for this one key): with a kit installed run `bash "$KIT_SH" --set tracker=<provider>`; otherwise add the line `- tracker: <provider>` to the section, creating the minimal profile of Step 4b when there is none.
5. **Consent.** Setup creates no issue. Afterwards skills ask the human before `sdd issue open|update|close`, any `git push`, opening a PR/MR and merging.

### Step 5: Quality gates (opt-in)

Unless `--quality-gates` was given, ask. They add latency (about 30 s per Stop, 60 s per TaskCompleted) in exchange for an LLM check of pipeline consistency (H7, `Stop` prompt hook) and commit traceability (H8, `TaskCompleted` agent hook). Merge only the events the project does not define yet:

```bash
[ -f .claude/settings.json ] || echo '{}' > .claude/settings.json
jq -s '.[0] as $s | (.[1].hooks // {}) as $q | $s | .hooks = ($q + ($s.hooks // {}))' \
  .claude/settings.json "$SDD_PLUGIN_ROOT/templates/settings-optional-quality-gates.json" \
  > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
```

### Step 6: Verification and summary

Setup is not a pipeline stage: do not touch `stages`, only confirm the files are valid.

```bash
jq -e '.hooksVersion >= 3 and (.stages | length) >= 7' pipeline-state.json
grep -q "SDD Commit" "$(git rev-parse --git-path hooks)/commit-msg"
node .claude/sdd/sdd.mjs branch status                       # vendored validator runs
git check-ignore -q pipeline-state.json && git check-ignore -q .sdd/x
jq -e '.roles | length > 0' .claude/sdd-sessions.json        # if --multisession
grep -q '^<!-- sdd-stack-begin kit=' CLAUDE.md && ls .claude/rules/sdd-*.md   # if Step 4b was applied
ls .github/workflows/sdd.yml 2>/dev/null || ls .gitlab/sdd.gitlab-ci.yml       # if Step 4c was applied
ls "$SDD_PLUGIN_ROOT/server/dist/server.js"                  # MCP bundle shipped with the plugin
```

Report:

```
## SDD Setup Complete

| Component | Status |
|-----------|--------|
| Plugin sdd-pipeline | <version> (hooks, agents and MCP run from the plugin) |
| Migration from pre-4.0 | Applied / Not needed / Declined |
| pipeline-state.json | Created (hooksVersion 3) / Preserved (stage <currentStage>) |
| Git hook: commit-msg | Installed at <path> / Skipped (not a git repo) |
| Legacy global status line (user-level) | Removed / Kept / Not found |
| .gitignore policy | Applied / Already up to date; pipeline-state.json tracked: yes/no |
| Multi-session | <n> roles in .claude/sdd-sessions.json + .claude/sdd/sdd-up.sh / Not requested |
| Stack kit | <kit> v<version> (app_dir <dir>, <n> rules) installed / refreshed / Minimal profile written (task_state: trailers) / Profile already present |
| Tracker | <github\|gitlab>: CI job + PR/MR and issue templates, `tracker:` in the profile; merge setting printed / Not requested |
| Quality gates H7/H8 | Configured / Skipped |
| Dependencies | node <v>, git <v> (>= 2.32 for --trailer), jq yes/no (node fallback), python3 yes/no, tmux yes/no |

### Next steps
1. Start a new Claude Code session (or run /reload-plugins) so the SessionStart hook picks up pipeline-state.json
2. /sdd-pipeline-status to verify the pipeline state
3. /sdd-requirements-engineer to start the pipeline (or /sdd-pipeline-status --diagnose on an existing codebase)
4. --multisession: bash .claude/sdd/sdd-up.sh sdd-lead
```

## Constraints

- Never overwrite `pipeline-state.json` or an existing `.claude/sdd-sessions.json`.
- Never replace `.claude/settings.json`; merge only. Ask before changing anything under the user's Claude config directory.
- Run the migration only after showing `--dry-run` output and getting confirmation.
- Do not commit, do not `git rm`, do not uninstall plugins: print the commands for the user.
- Warn about missing `jq`, `python3` or `tmux`; only missing `git` or `node` block a step.
