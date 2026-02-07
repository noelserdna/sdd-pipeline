# SDD Automation — Manual Installation Guide

This document describes how to manually install SDD automation (hooks, agents, settings) into a target project. For automated installation, use `/sdd-setup` or run the install script.

## Quick Install (Script)

```bash
cd /path/to/your/project
bash ~/programacion/sdd-skills/sdd-setup/scripts/install-sdd-automation.sh
```

## Quick Install (Skill)

From within Claude Code, in your target project:

```
/sdd-setup
```

## Manual Installation

### Prerequisites

- **jq** (recommended) or **Node.js** (fallback) for JSON processing in hooks
- **Claude Code CLI** with hooks support
- The **sdd-skills** repository (default: `~/programacion/sdd-skills/`)

### Step 1: Create Directories

```bash
mkdir -p .claude/hooks .claude/agents
```

### Step 2: Copy Hook Scripts

```bash
SDD=~/programacion/sdd-skills
cp $SDD/automation/hooks/sdd-session-start.sh .claude/hooks/
cp $SDD/automation/hooks/sdd-upstream-guard.sh .claude/hooks/
cp $SDD/automation/hooks/sdd-pipeline-state-updater.sh .claude/hooks/
chmod +x .claude/hooks/*.sh
```

### Step 3: Copy Agent Definitions

```bash
cp $SDD/automation/agents/sdd-constitution-enforcer.md .claude/agents/
cp $SDD/automation/agents/sdd-cross-auditor.md .claude/agents/
cp $SDD/automation/agents/sdd-context-keeper.md .claude/agents/
```

### Step 4: Configure Settings

**Option A: No existing settings**

```bash
cp $SDD/automation/settings-template.json .claude/settings.json
```

**Option B: Merge with existing settings**

Manually add the hooks from `settings-template.json` into your `.claude/settings.json`:

- `PreToolUse`: Add `SessionStart` (H1) and `Edit|Write` (H2) hooks
- `PostToolUse`: Add `Write` (H3) hook
- `Stop`: Add the prompt hook (H4)

### Step 5: Initialize Pipeline State

If `pipeline-state.json` doesn't exist in your project root:

```bash
cat > pipeline-state.json << 'EOF'
{
  "currentStage": "requirements-engineer",
  "lastUpdated": "2026-01-01T00:00:00Z",
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
EOF
```

### Step 6: Verify

```bash
# Check hooks are executable
ls -la .claude/hooks/*.sh

# Check agents exist
ls .claude/agents/*.md

# Check settings
cat .claude/settings.json | jq '.hooks | keys'

# Check pipeline state
cat pipeline-state.json | jq '.stages | to_entries[] | {key, status: .value.status}'
```

## Components Reference

| Component | File | Type | Purpose |
|-----------|------|------|---------|
| H1 | `.claude/hooks/sdd-session-start.sh` | PreToolUse (SessionStart) | Injects pipeline status at session start |
| H2 | `.claude/hooks/sdd-upstream-guard.sh` | PreToolUse (Edit\|Write) | Blocks upstream artifact modification |
| H3 | `.claude/hooks/sdd-pipeline-state-updater.sh` | PostToolUse (Write, async) | Auto-updates pipeline-state.json |
| H4 | Inline in settings.json | Stop (prompt, haiku) | Verifies pipeline state on session end |
| A1 | `.claude/agents/sdd-constitution-enforcer.md` | Agent (haiku) | Validates against SDD Constitution |
| A2 | `.claude/agents/sdd-cross-auditor.md` | Agent (sonnet) | Cross-references skill definitions |
| A3 | `.claude/agents/sdd-context-keeper.md` | Agent (haiku) | Maintains informal project context |

## Troubleshooting

### Hooks not firing
- Ensure Claude Code session was restarted after installation
- Verify `.claude/settings.json` has the correct hook paths
- Check that hook scripts are executable (`chmod +x`)

### jq not found
- Install: `apt install jq` (Linux), `brew install jq` (macOS), `choco install jq` (Windows)
- Or ensure Node.js is available as fallback

### Pipeline state not updating
- H3 is async — updates may take a few seconds
- Check that `pipeline-state.json` exists and is valid JSON
- Verify the Write hook is configured in PostToolUse

### Upstream guard false positives
- H2 only blocks when a stage has `status: "running"` in `pipeline-state.json`
- If no stage is running, the guard is permissive
- `pipeline-state.json` and `.claude/` paths are always excluded
