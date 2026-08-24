---
name: sdd-setup
description: "Initializes the SDD pipeline in the current project by creating pipeline-state.json and verifying plugin installation. Use when: (1) Setting up a new project for SDD pipeline, (2) Starting SDD on an existing codebase, (3) Verifying that SDD automation (hooks, agents, MCP server) is properly installed, (4) Upgrading from hooks v1 to v2. Triggers: 'setup SDD', 'init pipeline', 'install SDD', 'start SDD project', 'iniciar SDD', 'configurar pipeline', 'initialize SDD', 'upgrade SDD'."
---

# SDD Setup

You are the **SDD Setup** installer. Your job is to install SDD automation infrastructure (hooks, agents, settings) into the current target project.

## Prerequisites

- The current directory must be the **target project** (not the sdd-skills repo itself)
- The `sdd-pipeline` plugin must be installed and enabled (`claude plugin list`)

## Installation Process

### Step 0: Upgrade Detection

Before any installation, check for existing v1 hooks that need migration:

1. Check `pipeline-state.json` for `hooksVersion` field
   - If `hooksVersion >= 2`: already upgraded, skip migration
   - If missing: potential v1 installation, continue checks
2. Detect v1 signals in `.claude/settings.json`:
   - `PreToolUse` hook with matcher `SessionStart` (should be `SessionStart` event)
   - `permissionDecision` without `hookSpecificOutput` wrapper
   - H4 stop hook with `echo {}` placeholder
   - Timeout values in milliseconds (>100) instead of seconds
3. If v1 detected:
   - Inform user: "Detected hooks v1 configuration — upgrading to v2"
   - Run `scripts/migrate-hooks-v2.sh` (or apply fixes inline)
   - Add `sddVersion` and `hooksVersion` to `pipeline-state.json`
4. If plugin is also installed (check for `hooks.json` in plugin root):
   - Remove duplicate hooks from `.claude/settings.json` that are already in plugin `hooks.json` (H1-H3, H5)
   - Keep only project-specific optional hooks (H4, H7)
5. Report migration result

### Step 1: Detect Environment

1. Verify current directory is a valid project (has `.git/` or user confirms)
2. Locate the plugin root: `${CLAUDE_PLUGIN_ROOT}` (exported by the SessionStart hook as `SDD_PLUGIN_ROOT`)
3. Check for existing `.claude/` directory and `settings.json`
4. Check if `jq` is available: `command -v jq`
   - If not: warn user that hooks will fall back to `node -e` (slower but functional)

### Step 2: Create Directory Structure

```bash
mkdir -p .claude/hooks
mkdir -p .claude/agents
```

### Step 3: Copy Hook Scripts

Copy from the sdd-skills repo:

```
sdd-skills/automation/hooks/sdd-session-start.sh      → .claude/hooks/sdd-session-start.sh
sdd-skills/automation/hooks/sdd-upstream-guard.sh      → .claude/hooks/sdd-upstream-guard.sh
sdd-skills/automation/hooks/sdd-pipeline-state-updater.sh → .claude/hooks/sdd-pipeline-state-updater.sh
```

Make them executable: `chmod +x .claude/hooks/*.sh`

### Step 3.5: Install Git Commit-Msg Hook

If the target project has a `.git/` directory, install the traceability commit-msg hook:

```
sdd-skills/automation/hooks/sdd-commit-msg-hook.sh → .git/hooks/commit-msg
```

- If `.git/hooks/commit-msg` already exists, back it up as `.commit-msg.backup` and warn the user
- Make it executable: `chmod +x .git/hooks/commit-msg`
- If no `.git/` directory exists, skip with a warning

This hook enforces that implementation commits (`feat`, `fix`, `perf`, `test`) include `Refs:` and/or `Task:` traceability trailers. Commits with types `docs`, `chore`, `ci`, `style`, `build` are exempt. Bypass with `[skip-sdd]` in the message body or `SDD_SKIP_VERIFY=1` env var.

### Step 4: Copy Agent Definitions

Copy from the sdd-skills repo:

```
sdd-skills/automation/agents/sdd-constitution-enforcer.md → .claude/agents/sdd-constitution-enforcer.md
sdd-skills/automation/agents/sdd-cross-auditor.md         → .claude/agents/sdd-cross-auditor.md
sdd-skills/automation/agents/sdd-context-keeper.md        → .claude/agents/sdd-context-keeper.md
```

### Step 4.5: Copy Augment Hook and Trace Map Updater

```
sdd-skills/automation/hooks/sdd-augment-hook.js      → .claude/hooks/sdd-augment-hook.js
sdd-skills/automation/hooks/sdd-trace-map-updater.sh → .claude/hooks/sdd-trace-map-updater.sh
```

Make them executable: `chmod +x .claude/hooks/sdd-augment-hook.js .claude/hooks/sdd-trace-map-updater.sh`

### Step 5: Configure Settings

If `.claude/settings.json` does not exist:
- Copy `sdd-skills/automation/settings-template.json` as `.claude/settings.json`

If `.claude/settings.json` exists:
- **Merge** the hooks configuration from the template into existing settings
- Preserve existing permissions and other settings
- Add hooks that don't already exist (match by command path)
- Warn user about any conflicts

### Step 5.5: Build MCP Server

Check if `server/dist/` exists in the sdd-skills repo:
- If it exists: skip (already built)
- If not: run `cd $SDD/server && npm install && npm run build`
- Report build status (success/failure/skipped)
- Requires Node.js 18+

### Step 5.6: Optional — Code Intelligence

Inform the user about the code intelligence feature:
- `/sdd-code-index` indexes the project codebase for deep traceability
- Works standalone but produces richer results with **GitNexus** installed
- Run after `/sdd-dashboard` to enable code-aware blast radius analysis
- This is optional and can be configured later

### Step 5.7.5: Optional — Pipeline Status Line

If user wants always-visible pipeline status at the bottom of Claude Code:

1. Copy status line script:
   ```
   sdd-skills/automation/status-line/sdd-status-line.sh → .claude/hooks/sdd-status-line.sh
   ```
2. Make executable: `chmod +x .claude/hooks/sdd-status-line.sh`
3. Add to `.claude/settings.json`:
   ```json
   "statusLine": {
     "type": "command",
     "command": "bash .claude/hooks/sdd-status-line.sh"
   }
   ```

The status line displays: `SDD [4/7] audit !1stale | $0.42`
- `[N/7]`: stages completed
- Active stage name (short: req/spec/audit/test/plan/tasks/impl)
- `!Nstale` / `xNerr`: warning counts
- `> next`: recommended next stage
- `OK`: all stages done
- `$cost`: session cost from Claude Code

This is display-only, zero API cost, reads `pipeline-state.json` on each assistant message. Requires `jq` or `node`.

Present as opt-in option table:
```
┌──────────────────────────────────────────┐
│ 5.7.5 Pipeline Status Line (display-only)│
│   [A] Install status line  ← recommended │
│   [B] Skip                               │
└──────────────────────────────────────────┘
```

### Step 5.7: Optional — Quality Gate Hooks

If user wants quality gate enforcement:
1. Merge `automation/settings-optional-quality-gates.json` into `.claude/settings.json`
   - H7: Stop prompt hook (pipeline consistency check)
   - H8: TaskCompleted agent hook (traceability verification)

### Step 6: Initialize Pipeline State

If `pipeline-state.json` does not exist:
- Create it with all stages set to `pending`:

```json
{
  "currentStage": "requirements-engineer",
  "lastUpdated": "[NOW]",
  "stages": {
    "requirements-engineer":    { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "specifications-engineer":  { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "spec-auditor":             { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "test-planner":             { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "plan-architect":           { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "task-generator":           { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null },
    "task-implementer":         { "status": "pending", "outputHash": null, "lastRun": null, "staleReason": null }
  }
}
```

If `pipeline-state.json` already exists:
- Leave it untouched (preserve existing pipeline state)
- Report current state

### Step 7: Verification

Run verification checks:

1. All 5 hook scripts exist and are executable (H1-H3, H5 augment, H6 trace-map)
2. All 3 agent definitions exist
3. `settings.json` contains the 6 hook configurations (H1-H6)
4. `pipeline-state.json` exists and is valid JSON
5. MCP server built (`server/dist/index.js` exists)

Report results:

```
## SDD Automation Setup Complete

| Component | Status |
|-----------|--------|
| Hook: sdd-session-start (H1) | Installed |
| Hook: sdd-upstream-guard (H2) | Installed |
| Hook: sdd-pipeline-state-updater (H3) | Installed |
| Hook: stop-hook (H4) | Configured in settings |
| Hook: sdd-augment-hook.js (H5) | Installed |
| Hook: sdd-trace-map-updater (H6) | Installed |
| Git hook: commit-msg (traceability) | Installed / Skipped (no .git) |
| Hook: quality gates (H7-H8) | Opt-in / Configured / Skipped |
| Status Line: sdd-status-line | Opt-in / Configured / Skipped |
| Agent: sdd-constitution-enforcer (A1) | Installed |
| Agent: sdd-cross-auditor (A2) | Installed |
| Agent: sdd-context-keeper (A3) | Installed |
| MCP Server: server/dist/ | Built / NOT BUILT |
| Settings: .claude/settings.json | Configured |
| Pipeline: pipeline-state.json | Initialized (hooksVersion: 2) |
| Hooks version | v2 / Upgraded from v1 |
| Dependency: jq | Available / MISSING (using node fallback) |
| Dependency: node | Available / MISSING (MCP server requires Node.js 18+) |

### Next Steps
1. Start a new Claude Code session to activate hooks
2. Run `/sdd-pipeline-status` to verify pipeline state
3. Begin with `/sdd-requirements-engineer` for a new project
4. (Optional) Run `/sdd-code-index` to enable code intelligence
```

## Constraints

- Never overwrite existing settings without merge
- Never overwrite existing pipeline-state.json
- Always verify file integrity after copying
- Warn about missing `jq` but don't fail
