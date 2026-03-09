#!/bin/bash
# install-sdd-automation.sh
# Installs SDD automation (hooks, agents, settings) into the current project.
# Usage: bash /path/to/sdd-skills/sdd-setup/scripts/install-sdd-automation.sh [sdd-skills-path]
#
# Arguments:
#   sdd-skills-path  Path to the sdd-skills repository (default: ~/programacion/sdd-skills)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[SDD]${NC} $1"; }
warn()  { echo -e "${YELLOW}[SDD]${NC} $1"; }
error() { echo -e "${RED}[SDD]${NC} $1"; }

# Determine sdd-skills repo location
SDD_SKILLS="${1:-$HOME/programacion/sdd-skills}"
SDD_SKILLS=$(echo "$SDD_SKILLS" | sed 's|\\|/|g')

if [ ! -d "$SDD_SKILLS/automation" ]; then
  error "sdd-skills repo not found at: $SDD_SKILLS"
  error "Usage: bash install-sdd-automation.sh [path-to-sdd-skills]"
  exit 1
fi

TARGET_DIR=$(pwd)
info "Installing SDD automation into: $TARGET_DIR"
info "Source: $SDD_SKILLS"

# Step 1: Check dependencies
echo ""
info "Step 1: Checking dependencies..."
JQ_AVAILABLE=false
if command -v jq &>/dev/null; then
  info "  jq: found ($(jq --version 2>/dev/null || echo 'unknown version'))"
  JQ_AVAILABLE=true
else
  warn "  jq: NOT FOUND — hooks will use node fallback (slower)"
fi

if command -v node &>/dev/null; then
  info "  node: found ($(node --version 2>/dev/null))"
else
  if [ "$JQ_AVAILABLE" = false ]; then
    error "  Neither jq nor node found. At least one is required for hooks."
    exit 1
  fi
fi

# Step 2: Create directories
echo ""
info "Step 2: Creating directories..."
mkdir -p .claude/hooks
mkdir -p .claude/agents
info "  .claude/hooks/ created"
info "  .claude/agents/ created"

# Step 3: Copy hook scripts
echo ""
info "Step 3: Installing hook scripts..."
for hook in sdd-session-start.sh sdd-upstream-guard.sh sdd-pipeline-state-updater.sh sdd-trace-map-updater.sh; do
  SRC="$SDD_SKILLS/automation/hooks/$hook"
  DST=".claude/hooks/$hook"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DST"
    chmod +x "$DST"
    info "  $hook installed"
  else
    error "  $hook not found in source repo!"
  fi
done

# Step 3.5: Install git commit-msg hook (traceability enforcement)
echo ""
info "Step 3.5: Installing git commit-msg hook..."
COMMIT_MSG_HOOK_SRC="$SDD_SKILLS/automation/hooks/sdd-commit-msg-hook.sh"
if [ -d ".git" ]; then
  COMMIT_MSG_HOOK_DST=".git/hooks/commit-msg"
  if [ -f "$COMMIT_MSG_HOOK_SRC" ]; then
    if [ -f "$COMMIT_MSG_HOOK_DST" ]; then
      BACKUP_PATH="${COMMIT_MSG_HOOK_DST}.backup.$(date +%Y%m%d%H%M%S)"
      cp "$COMMIT_MSG_HOOK_DST" "$BACKUP_PATH"
      warn "  Existing commit-msg hook backed up to: $BACKUP_PATH"
    fi
    cp "$COMMIT_MSG_HOOK_SRC" "$COMMIT_MSG_HOOK_DST"
    chmod +x "$COMMIT_MSG_HOOK_DST"
    info "  commit-msg hook installed (.git/hooks/commit-msg)"
  else
    error "  sdd-commit-msg-hook.sh not found in source repo!"
  fi
else
  warn "  No .git directory found — skipping commit-msg hook (not a git repo)"
fi

# Step 4: Copy agent definitions
echo ""
info "Step 4: Installing agent definitions..."
for agent in sdd-constitution-enforcer.md sdd-cross-auditor.md sdd-context-keeper.md; do
  SRC="$SDD_SKILLS/automation/agents/$agent"
  DST=".claude/agents/$agent"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$DST"
    info "  $agent installed"
  else
    error "  $agent not found in source repo!"
  fi
done

# Step 5: Configure settings
echo ""
info "Step 5: Configuring settings..."
SETTINGS=".claude/settings.json"
TEMPLATE="$SDD_SKILLS/automation/settings-template.json"

if [ ! -f "$SETTINGS" ]; then
  # No existing settings — copy template directly
  cp "$TEMPLATE" "$SETTINGS"
  info "  settings.json created from template"
else
  # Merge hooks into existing settings
  warn "  Existing settings.json found — merging hooks..."
  if [ "$JQ_AVAILABLE" = true ]; then
    TMPFILE="${SETTINGS}.tmp.$$"
    # Merge: add hooks from template, preserving existing settings
    jq -s '
      .[0] as $existing |
      .[1] as $template |
      $existing * { hooks: (
        ($existing.hooks // {}) as $eh |
        ($template.hooks // {}) as $th |
        {
          PreToolUse: (($eh.PreToolUse // []) + ($th.PreToolUse // []) | unique_by(.matcher)),
          PostToolUse: (($eh.PostToolUse // []) + ($th.PostToolUse // []) | unique_by(.matcher)),
          Stop: ($th.Stop // $eh.Stop // [])
        }
      )}
    ' "$SETTINGS" "$TEMPLATE" > "$TMPFILE" 2>/dev/null && mv "$TMPFILE" "$SETTINGS"
    info "  Hooks merged into existing settings"
  else
    # Node fallback for merge
    node -e "
      const fs = require('fs');
      const existing = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
      const template = JSON.parse(fs.readFileSync('$TEMPLATE', 'utf8'));
      if (!existing.hooks) existing.hooks = {};
      for (const [key, val] of Object.entries(template.hooks || {})) {
        if (!existing.hooks[key]) {
          existing.hooks[key] = val;
        } else {
          // Append new hook entries that don't already exist
          for (const entry of val) {
            const matcher = entry.matcher || '';
            const exists = existing.hooks[key].some(e => (e.matcher || '') === matcher);
            if (!exists) existing.hooks[key].push(entry);
          }
        }
      }
      fs.writeFileSync('$SETTINGS', JSON.stringify(existing, null, 2));
    " 2>/dev/null
    info "  Hooks merged (node fallback)"
  fi
fi

# Step 6: Initialize pipeline state
echo ""
info "Step 6: Initializing pipeline state..."
PIPELINE_STATE="pipeline-state.json"

if [ ! -f "$PIPELINE_STATE" ]; then
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  cat > "$PIPELINE_STATE" <<EOF
{
  "currentStage": "requirements-engineer",
  "lastUpdated": "$NOW",
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
  info "  pipeline-state.json initialized (all stages pending)"
else
  info "  pipeline-state.json already exists — preserved"
fi

# Step 7: Verification
echo ""
info "Step 7: Verifying installation..."
ERRORS=0

for hook in sdd-session-start.sh sdd-upstream-guard.sh sdd-pipeline-state-updater.sh sdd-trace-map-updater.sh; do
  if [ -x ".claude/hooks/$hook" ]; then
    info "  Hook $hook: OK"
  else
    error "  Hook $hook: MISSING or not executable"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ -d ".git" ] && [ -x ".git/hooks/commit-msg" ]; then
  info "  Git hook commit-msg: OK"
else
  warn "  Git hook commit-msg: SKIPPED (no .git or not installed)"
fi

for agent in sdd-constitution-enforcer.md sdd-cross-auditor.md sdd-context-keeper.md; do
  if [ -f ".claude/agents/$agent" ]; then
    info "  Agent $agent: OK"
  else
    error "  Agent $agent: MISSING"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ -f ".claude/settings.json" ]; then
  info "  settings.json: OK"
else
  error "  settings.json: MISSING"
  ERRORS=$((ERRORS + 1))
fi

if [ -f "pipeline-state.json" ]; then
  info "  pipeline-state.json: OK"
else
  error "  pipeline-state.json: MISSING"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  info "Installation complete! All components verified."
else
  error "Installation completed with $ERRORS error(s). Review above."
fi

echo ""
info "Next steps:"
info "  1. Start a new Claude Code session to activate hooks"
info "  2. Run /sdd-pipeline-status to verify pipeline state"
info "  3. Begin with /sdd-requirements-engineer for a new project"
