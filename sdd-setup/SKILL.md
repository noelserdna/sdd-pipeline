---
name: sdd-setup
description: "Initializes the SDD pipeline in the current project by creating pipeline-state.json and verifying plugin installation. Use when: (1) Setting up a new project for SDD pipeline, (2) Starting SDD on an existing codebase, (3) Verifying that SDD automation (hooks, agents, MCP server) is properly installed, (4) Upgrading from hooks v1 to v2. Triggers: 'setup SDD', 'init pipeline', 'install SDD', 'start SDD project', 'iniciar SDD', 'configurar pipeline', 'initialize SDD', 'upgrade SDD'."
version: "2.0.0"
---

# SDD Setup

You are the **SDD Setup** installer. Your job is to install SDD automation infrastructure (hooks, agents, settings) into the current target project.

## Prerequisites

- The current directory must be the **target project** (not the sdd-skills repo itself)
- The sdd-skills repo must be accessible (default: `~/programacion/sdd-skills/`)

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
   - Run `automation/scripts/migrate-hooks-v2.sh` (or apply fixes inline)
   - Add `sddVersion` and `hooksVersion` to `pipeline-state.json`
4. If plugin is also installed (check for `hooks.json` in plugin root):
   - Remove duplicate hooks from `.claude/settings.json` that are already in plugin `hooks.json` (H1-H3, H5)
   - Keep only project-specific optional hooks (H4, H6, H7)
5. Report migration result

### Step 1: Detect Environment

1. Verify current directory is a valid project (has `.git/` or user confirms)
2. Locate the sdd-skills repo (check `~/programacion/sdd-skills/` or ask user)
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

### Step 4: Copy Agent Definitions

Copy from the sdd-skills repo:

```
sdd-skills/automation/agents/sdd-constitution-enforcer.md → .claude/agents/sdd-constitution-enforcer.md
sdd-skills/automation/agents/sdd-cross-auditor.md         → .claude/agents/sdd-cross-auditor.md
sdd-skills/automation/agents/sdd-context-keeper.md        → .claude/agents/sdd-context-keeper.md
```

### Step 4.5: Copy Augment Hook

```
sdd-skills/automation/hooks/sdd-context-augment.sh → .claude/hooks/sdd-context-augment.sh
```

Make it executable: `chmod +x .claude/hooks/sdd-context-augment.sh`

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

### Step 5.7: Optional — Dashboard Server & HTTP Hooks

If user wants real-time dashboard updates:
1. Merge `automation/settings-optional-dashboard.json` into `.claude/settings.json`
   - Adds HTTP hooks (H6) that POST events to `http://localhost:3001/hooks/*`
   - Events: SessionStart, PostToolUse (artifact-changed), SubagentStart/Stop, TaskCompleted, Stop, SessionEnd
2. Optionally merge `automation/settings-optional-quality-gates.json`
   - H7: Stop prompt hook (pipeline consistency check)
   - H8: TaskCompleted agent hook (traceability verification)
3. Start the dashboard server: `node $SDD/server/dist/dashboard-entry.js`
   - Or set `SDD_DASHBOARD_PORT` env var for custom port
   - Dashboard available at `http://localhost:3001/`
   - SSE stream at `http://localhost:3001/events`
4. Inform user: these hooks require the dashboard server to be running — they silently fail if the server is not available

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

1. All 4 hook scripts exist and are executable (H1-H3 + H5 augment)
2. All 3 agent definitions exist
3. `settings.json` contains the 5 hook configurations (H1-H5)
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
| Hook: sdd-context-augment (H5) | Installed |
| Hook: dashboard HTTP hooks (H6) | Opt-in / Configured / Skipped |
| Hook: quality gates (H7-H8) | Opt-in / Configured / Skipped |
| Agent: sdd-constitution-enforcer (A1) | Installed |
| Agent: sdd-cross-auditor (A2) | Installed |
| Agent: sdd-context-keeper (A3) | Installed |
| MCP Server: server/dist/ | Built / NOT BUILT |
| Dashboard Server | Available (port 3001) / NOT CONFIGURED |
| Settings: .claude/settings.json | Configured |
| Pipeline: pipeline-state.json | Initialized (hooksVersion: 2) |
| Hooks version | v2 / Upgraded from v1 |
| Dependency: jq | Available / MISSING (using node fallback) |
| Dependency: node | Available / MISSING (MCP server requires Node.js 18+) |

### Next Steps
1. Start a new Claude Code session to activate hooks
2. Run `/sdd-pipeline-status` to verify pipeline state
3. Begin with `/sdd-requirements-engineer` for a new project
4. (Optional) Run `/sdd-code-index` after dashboard to enable code intelligence
5. (Optional) Start dashboard server: `node server/dist/dashboard-entry.js`
```

## Constraints

- Never overwrite existing settings without merge
- Never overwrite existing pipeline-state.json
- Always verify file integrity after copying
- Warn about missing `jq` but don't fail
