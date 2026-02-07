---
name: sdd-setup
description: "Installs SDD automation (hooks, agents, settings) into the current target project. Use when setting up a new project for SDD pipeline or updating automation."
version: "1.0.0"
---

# SDD Setup

You are the **SDD Setup** installer. Your job is to install SDD automation infrastructure (hooks, agents, settings) into the current target project.

## Prerequisites

- The current directory must be the **target project** (not the sdd-skills repo itself)
- The sdd-skills repo must be accessible (default: `~/programacion/sdd-skills/`)

## Installation Process

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

### Step 5: Configure Settings

If `.claude/settings.json` does not exist:
- Copy `sdd-skills/automation/settings-template.json` as `.claude/settings.json`

If `.claude/settings.json` exists:
- **Merge** the hooks configuration from the template into existing settings
- Preserve existing permissions and other settings
- Add hooks that don't already exist (match by command path)
- Warn user about any conflicts

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

1. All 3 hook scripts exist and are executable
2. All 3 agent definitions exist
3. `settings.json` contains the 4 hook configurations (H1-H4)
4. `pipeline-state.json` exists and is valid JSON

Report results:

```
## SDD Automation Setup Complete

| Component | Status |
|-----------|--------|
| Hook: sdd-session-start (H1) | Installed |
| Hook: sdd-upstream-guard (H2) | Installed |
| Hook: sdd-pipeline-state-updater (H3) | Installed |
| Hook: stop-hook (H4) | Configured in settings |
| Agent: sdd-constitution-enforcer (A1) | Installed |
| Agent: sdd-cross-auditor (A2) | Installed |
| Agent: sdd-context-keeper (A3) | Installed |
| Settings: .claude/settings.json | Configured |
| Pipeline: pipeline-state.json | Initialized |
| Dependency: jq | Available / MISSING (using node fallback) |

### Next Steps
1. Start a new Claude Code session to activate hooks
2. Run `/sdd-pipeline-status` to verify pipeline state
3. Begin with `/sdd-requirements-engineer` for a new project
```

## Constraints

- Never overwrite existing settings without merge
- Never overwrite existing pipeline-state.json
- Always verify file integrity after copying
- Warn about missing `jq` but don't fail
