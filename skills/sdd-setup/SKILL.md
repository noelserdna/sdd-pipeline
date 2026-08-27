---
name: sdd-setup
description: "Initializes the SDD pipeline in the current project: checks the sdd-pipeline plugin and dependencies, creates pipeline-state.json, installs the git commit-msg hook, optional status line and quality gates, versioning policy, --multisession setup and pre-4.0 migration. Triggers: 'setup SDD', 'init pipeline', 'install SDD', 'upgrade SDD', 'iniciar SDD', 'configurar pipeline', 'migrar SDD'."
---

# SDD Setup

You are the **SDD Setup** assistant. You prepare the current project for the `sdd-pipeline` plugin.

Since 4.0 the plugin itself provides the hooks (`hooks/hooks.json`), the agents and the MCP server (`.mcp.json`). They run from `${CLAUDE_PLUGIN_ROOT}` and are updated together with the plugin. **Setup copies no hooks and no agents into the project.** It only creates the project-owned files below:

| File | Step | Versioned in git? |
|------|------|-------------------|
| `pipeline-state.json` | 1 (never overwritten) | No: per-checkout state, ignored |
| git `commit-msg` hook | 2 | No: lives in the git dir, shared by all worktrees |
| `.claude/sdd-status-line.sh` + `statusLine` in `.claude/settings.json` | 3 (optional) | Yes |
| `# sdd-begin ... # sdd-end` block in `.gitignore` | 4 | Yes |
| `.claude/sdd-sessions.json`, `.claude/sdd/sdd-up.sh` | 4 (`--multisession`) | Yes |
| H7/H8 quality gates in `.claude/settings.json` | 5 (opt-in) | Yes |

## Invocation

```
/sdd-setup                   # interactive: asks about the optional steps
/sdd-setup --multisession    # also creates .claude/sdd-sessions.json and .claude/sdd/sdd-up.sh
/sdd-setup --quality-gates   # also merges the H7/H8 quality gates without asking
/sdd-setup --no-status-line  # skips Step 3 without asking
```

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
| git | `git --version`, `git rev-parse --is-inside-work-tree` | required for Steps 2 and 4 |
| node >= 18 | `node -v` | required (MCP server, hook fallbacks) |
| jq | `jq --version` | optional: hooks and this skill fall back to node |
| python3 | `python3 --version` | optional: only `/sdd-dashboard` needs it |
| tmux >= 3.2 | `tmux -V` | optional: only the `--multisession` launcher uses it |

Then look for a **pre-4.0 installation** (hooks copied into the project by `install-sdd-automation.sh` or by the old `sdd` plugin). Any hit is a signal:

```bash
ls .claude/hooks/sdd-*.sh .claude/hooks/sdd-*.js .claude/agents/sdd-*.md 2>/dev/null   # copied hooks and agents
grep -E 'sdd-(session-start|upstream-guard|pipeline-state-updater|augment-hook|trace-map-updater)' .claude/settings.json 2>/dev/null
[ "$(jq -r '.hooksVersion // 0' pipeline-state.json 2>/dev/null)" -ge 3 ] || echo "old pipeline-state format"
grep -oE '"(sdd@[^"]+|sdd-pipeline@sdd-pipeline-local)"' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" 2>/dev/null   # old plugin ids
```

If any signal is present:

1. Show the signals table and run `bash "$SDD_PLUGIN_ROOT/scripts/migrate-hooks-v3.sh" --dry-run`; show its output verbatim.
2. Ask the user to confirm. The migration backs everything up in `.claude/backups/`, removes the copied hooks/agents and their entries in `.claude/settings.json` (the plugin provides them now), keeps `statusLine` (moving the script to `.claude/sdd-status-line.sh`), reinstalls `commit-msg`, writes `sddVersion`/`hooksVersion: 3` into `pipeline-state.json` and applies the `.gitignore` policy.
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

Installs `hooks/sdd-commit-msg-hook.sh` into the hooks directory git actually uses: `core.hooksPath` when set, otherwise `$(git rev-parse --git-common-dir)/hooks`, which every linked worktree shares. A foreign hook is backed up with a timestamp and `--uninstall` restores it; re-running is a no-op. The hook requires `Refs:` and/or `Task:` trailers on `feat`, `fix`, `perf` and `test` commits (`Task:` on `refactor`); `docs`, `chore`, `ci`, `style`, `build` and merge commits are exempt; bypass with `[skip-sdd]` in the body or `SDD_SKIP_VERIFY=1`. If the project is not a git repository, skip with a warning.

### Step 3: Pipeline status line (optional, recommended)

Unless `--no-status-line`, offer:

```
| Step 3: Pipeline status line (display-only, no API cost) |
|   [A] Install  <- recommended                            |
|   [B] Skip                                               |
```

The script is **copied** into the project because `.claude/settings.json` cannot reference `${CLAUDE_PLUGIN_ROOT}` and the plugin path changes on every update; the copy is versioned with the project and refreshed whenever `/sdd-setup` runs again.

```bash
mkdir -p .claude
cp "$SDD_PLUGIN_ROOT/scripts/sdd-status-line.sh" .claude/sdd-status-line.sh && chmod +x .claude/sdd-status-line.sh
[ -f .claude/settings.json ] || echo '{}' > .claude/settings.json
jq -s '.[0] * .[1]' .claude/settings.json "$SDD_PLUGIN_ROOT/templates/settings.statusline.example.json" \
  > .claude/settings.json.tmp && mv .claude/settings.json.tmp .claude/settings.json
```

Node fallback for the merge: `node -e 'const fs=require("fs");const s=JSON.parse(fs.readFileSync(".claude/settings.json","utf8"));s.statusLine={type:"command",command:"bash .claude/sdd-status-line.sh",refreshInterval:5};fs.writeFileSync(".claude/settings.json",JSON.stringify(s,null,2)+"\n")'`.

If `.claude/settings.json` already has a different `statusLine`, show it and ask before replacing it. Display format: `[<role>] SDD [4/7] audit !1stale > test · spec-auditor 8m · 4 agentes` (done/total, running stage, stale and error counts, next recommended stage; `[<role>]` prefix in multi-session mode; then the running skill with elapsed minutes and the number of active subagents, read from `.sdd/activity.jsonl`). `refreshInterval: 5` re-runs it every 5 s even while the session is idle waiting for subagents. It reads `pipeline-state.json` on every refresh and needs `jq` or `node`.

### Step 4: Versioning policy

**4.1 `.gitignore`.** Apply the managed block (idempotent; refreshes an outdated block in place):

```bash
bash "$SDD_PLUGIN_ROOT/scripts/migrate-hooks-v3.sh" --gitignore-only
```

| Ignored | Why |
|---------|-----|
| `pipeline-state.json` | Per-checkout state written by the hooks; committing it causes merge conflicts between developers |
| `.sdd/` | Trace map, current-task breadcrumbs, async questions, bench events |
| `.claude/worktrees/` | Ephemeral worktrees created by Claude Code |
| `.claude/settings.local.json` | Personal overrides |
| `dashboard/traceability-graph.json` | Generated by `/sdd-dashboard` |

The script warns when `pipeline-state.json` is already tracked and prints the `git rm --cached pipeline-state.json` command: show it to the user, do not run it.

**4.2 Versioned files.** Recommend committing `.claude/settings.json`, `.claude/sdd-status-line.sh`, `.gitignore` and, with `--multisession`, `.claude/sdd-sessions.json` and `.claude/sdd/sdd-up.sh`. Report which of them are not yet tracked (`git ls-files --error-unmatch <file>`), without committing.

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
git check-ignore -q pipeline-state.json && git check-ignore -q .sdd/x
jq -e '.statusLine.command' .claude/settings.json            # if Step 3 was applied
jq -e '.roles | length > 0' .claude/sdd-sessions.json        # if --multisession
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
| Status line | Configured / Skipped |
| .gitignore policy | Applied / Already up to date; pipeline-state.json tracked: yes/no |
| Multi-session | <n> roles in .claude/sdd-sessions.json + .claude/sdd/sdd-up.sh / Not requested |
| Quality gates H7/H8 | Configured / Skipped |
| Dependencies | node <v>, git <v>, jq yes/no (node fallback), python3 yes/no, tmux yes/no |

### Next steps
1. Start a new Claude Code session (or run /reload-plugins) so the SessionStart hook picks up pipeline-state.json
2. /sdd-pipeline-status to verify the pipeline state
3. /sdd-requirements-engineer to start the pipeline (or /sdd-onboarding on an existing codebase)
4. --multisession: bash .claude/sdd/sdd-up.sh sdd-lead
```

## Constraints

- Never overwrite `pipeline-state.json` or an existing `.claude/sdd-sessions.json`.
- Never replace `.claude/settings.json`; merge, and ask before changing an existing `statusLine`.
- Run the migration only after showing `--dry-run` output and getting confirmation.
- Do not commit, do not `git rm`, do not uninstall plugins: print the commands for the user.
- Warn about missing `jq`, `python3` or `tmux`; only missing `git` or `node` block a step.
