#!/bin/bash
# SDD Hooks v1 → v2 Migration Script
# Usage: bash migrate-hooks-v2.sh [--dry-run]
#
# Safe, idempotent, non-destructive.
# Detects v1 hook patterns and upgrades to v2 format.
# Handles 3 scenarios:
#   - Plugin installed + old project hooks → clean duplicates
#   - No plugin + old project hooks → update in-place
#   - Already v2 → no-op

set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

PROJECT_DIR="$(pwd)"
SETTINGS="$PROJECT_DIR/.claude/settings.json"
PIPELINE_STATE="$PROJECT_DIR/pipeline-state.json"

# Colors (if terminal supports them)
# shellcheck disable=SC2034
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_found() { echo -e "${YELLOW}[FOUND]${NC} $1"; }
log_fix()   { echo -e "${GREEN}[FIX]${NC} $1"; }
log_skip()  { echo -e "${NC}[SKIP]${NC} $1"; }

echo "============================================"
echo "  SDD Hooks Migration v1 → v2"
echo "============================================"
echo ""

# ─────────────────────────────────────────────
# Phase 1: Detection
# ─────────────────────────────────────────────
V1_SIGNALS=0
FIXES=()

# Detect plugin
PLUGIN_DETECTED=false
if [ -f "$PROJECT_DIR/.claude/plugins/sdd/hooks/hooks.json" ] 2>/dev/null || \
   [ -d "$HOME/.claude/plugins/sdd" ] 2>/dev/null; then
  PLUGIN_DETECTED=true
  log_info "Plugin 'sdd' detected"
else
  log_info "No plugin detected (manual installation)"
fi

# Signal 1: SessionStart inside PreToolUse in settings.json
if [ -f "$SETTINGS" ]; then
  if grep -q '"SessionStart"' "$SETTINGS" 2>/dev/null && \
     grep -q '"PreToolUse"' "$SETTINGS" 2>/dev/null; then
    # Check if SessionStart is a matcher inside PreToolUse (v1 pattern)
    # vs a top-level event (v2 pattern)
    if python3 -c "
import json, sys
try:
    s = json.load(open('$SETTINGS'))
    for group in s.get('hooks', {}).get('PreToolUse', []):
        if group.get('matcher') == 'SessionStart':
            sys.exit(0)
    sys.exit(1)
except: sys.exit(1)
" 2>/dev/null; then
      V1_SIGNALS=$((V1_SIGNALS + 1))
      log_found "v1: H1 SessionStart as PreToolUse matcher (should be SessionStart event)"
      FIXES+=("settings-h1-event")
    fi
  fi

  # Signal 2: Timeouts > 100 (likely milliseconds)
  if grep -qE '"timeout"\s*:\s*[0-9]{4,}' "$SETTINGS" 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    log_found "v1: Timeouts in milliseconds (should be seconds)"
    FIXES+=("settings-timeouts")
  fi

  # Signal 3: echo {} stop hook
  if grep -q 'echo {}' "$SETTINGS" 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    log_found "v1: Placeholder Stop hook (echo {})"
    FIXES+=("settings-stop-placeholder")
  fi

  # Signal 4: Duplicate hooks (plugin + project both have sdd-session-start)
  if [ "$PLUGIN_DETECTED" = true ]; then
    if grep -q 'sdd-session-start' "$SETTINGS" 2>/dev/null; then
      V1_SIGNALS=$((V1_SIGNALS + 1))
      log_found "DUPLICATE: Project settings has sdd-session-start (plugin already provides this)"
      FIXES+=("duplicate-h1")
    fi
    if grep -q 'sdd-upstream-guard' "$SETTINGS" 2>/dev/null; then
      V1_SIGNALS=$((V1_SIGNALS + 1))
      log_found "DUPLICATE: Project settings has sdd-upstream-guard (plugin already provides this)"
      FIXES+=("duplicate-h2")
    fi
    if grep -q 'sdd-pipeline-state-updater' "$SETTINGS" 2>/dev/null; then
      V1_SIGNALS=$((V1_SIGNALS + 1))
      log_found "DUPLICATE: Project settings has sdd-pipeline-state-updater (plugin already provides this)"
      FIXES+=("duplicate-h3")
    fi
  fi
fi

# Signal 5: Old upstream-guard script format (no hookSpecificOutput)
if [ -f "$PROJECT_DIR/.claude/hooks/sdd-upstream-guard.sh" ]; then
  if grep -q '"permissionDecision"' "$PROJECT_DIR/.claude/hooks/sdd-upstream-guard.sh" 2>/dev/null && \
     ! grep -q 'hookSpecificOutput' "$PROJECT_DIR/.claude/hooks/sdd-upstream-guard.sh" 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    log_found "v1: upstream-guard.sh uses deprecated top-level permissionDecision"
    FIXES+=("script-upstream-guard")
  fi
fi

# Signal 6: No version marker in pipeline-state.json
if [ -f "$PIPELINE_STATE" ]; then
  if ! grep -q '"sddVersion"' "$PIPELINE_STATE" 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    log_found "v1: pipeline-state.json missing sddVersion field"
    FIXES+=("pipeline-version")
  fi
fi

echo ""

# ─────────────────────────────────────────────
# Phase 2: Decision
# ─────────────────────────────────────────────
if [ "$V1_SIGNALS" -eq 0 ]; then
  log_info "No v1 signals detected. Already on v2 or fresh install."
  exit 0
fi

echo "Found $V1_SIGNALS v1 signal(s). Fixes needed:"
for fix in "${FIXES[@]}"; do
  echo "  - $fix"
done
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] No changes made. Run without --dry-run to apply fixes."
  exit 0
fi

# ─────────────────────────────────────────────
# Phase 3: Backup
# ─────────────────────────────────────────────
BACKUP_DIR="$PROJECT_DIR/.claude/backups/hooks-v1-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

[ -f "$SETTINGS" ] && cp "$SETTINGS" "$BACKUP_DIR/settings.json"
[ -f "$PIPELINE_STATE" ] && cp "$PIPELINE_STATE" "$BACKUP_DIR/pipeline-state.json"
[ -f "$PROJECT_DIR/.claude/hooks/sdd-upstream-guard.sh" ] && \
  cp "$PROJECT_DIR/.claude/hooks/sdd-upstream-guard.sh" "$BACKUP_DIR/sdd-upstream-guard.sh"

log_info "Backup created at $BACKUP_DIR"
echo ""

# ─────────────────────────────────────────────
# Phase 4: Apply Fixes
# ─────────────────────────────────────────────

# Helper: check if jq is available
HAS_JQ=false
command -v jq >/dev/null 2>&1 && HAS_JQ=true

apply_settings_fixes() {
  if [ ! -f "$SETTINGS" ]; then
    log_skip "No .claude/settings.json to fix"
    return
  fi

  if [ "$HAS_JQ" = true ]; then
    local tmpfile="${SETTINGS}.tmp.$$"

    if [ "$PLUGIN_DETECTED" = true ]; then
      # Plugin installed: remove ALL SDD hooks from project settings (plugin provides them)
      # Keep any non-SDD hooks the user may have added
      jq '
        .hooks.PreToolUse = [.hooks.PreToolUse[]? | select(
          (.hooks[]?.command // "" | test("sdd-"; "i") | not)
        )] |
        .hooks.PostToolUse = [.hooks.PostToolUse[]? | select(
          (.hooks[]?.command // "" | test("sdd-"; "i") | not)
        )] |
        .hooks.Stop = [.hooks.Stop[]? | select(
          (.hooks[]?.command // "" | test("echo \\{\\}") | not)
        )] |
        # Clean up empty arrays
        if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end |
        if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
        if .hooks.Stop == [] then del(.hooks.Stop) else . end |
        # Remove SessionStart if it was a PreToolUse matcher (migrated hooks)
        if .hooks.SessionStart then . else . end
      ' "$SETTINGS" > "$tmpfile" 2>/dev/null && mv "$tmpfile" "$SETTINGS"
      log_fix "Removed duplicate SDD hooks from project settings (plugin provides them)"
    else
      # No plugin: fix hooks in-place
      jq '
        # Fix 1: Move SessionStart from PreToolUse matcher to SessionStart event
        (if [.hooks.PreToolUse[]? | select(.matcher == "SessionStart")] | length > 0 then
          .hooks.SessionStart = [{
            "matcher": "startup|resume|compact",
            "hooks": [.hooks.PreToolUse[] | select(.matcher == "SessionStart") | .hooks[]]
          }] |
          .hooks.PreToolUse = [.hooks.PreToolUse[]? | select(.matcher != "SessionStart")]
        else . end) |

        # Fix 2: Fix timeouts (divide by 1000 if > 100)
        (.hooks | to_entries | map(
          .value |= map(
            .hooks |= map(
              if (.timeout // 0) > 100 then .timeout = ((.timeout / 1000) | floor) else . end
            )
          )
        ) | from_entries) as $fixed_hooks |
        .hooks = $fixed_hooks |

        # Fix 3: Remove echo {} stop hook
        .hooks.Stop = [.hooks.Stop[]? | select(
          (.hooks[]?.command // "" | test("echo \\{\\}") | not)
        )] |
        if .hooks.Stop == [] then del(.hooks.Stop) else . end
      ' "$SETTINGS" > "$tmpfile" 2>/dev/null && mv "$tmpfile" "$SETTINGS"
      log_fix "Updated settings.json: SessionStart event, timeouts, removed placeholder"
    fi
  else
    log_warn "jq not available. Settings fixes require manual editing or jq installation."
    log_warn "Install jq: apt-get install jq / brew install jq / choco install jq"
  fi
}

fix_upstream_guard_script() {
  local script="$PROJECT_DIR/.claude/hooks/sdd-upstream-guard.sh"
  if [ ! -f "$script" ]; then
    log_skip "No upstream-guard.sh to fix"
    return
  fi

  if grep -q 'hookSpecificOutput' "$script" 2>/dev/null; then
    log_skip "upstream-guard.sh already uses hookSpecificOutput"
    return
  fi

  # Replace the old output format with the new one
  sed -i 's|{"permissionDecision":"deny","reason":\$ESCAPED_REASON}|{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":\$ESCAPED_REASON}}|g' "$script" 2>/dev/null || \
  sed -i '' 's|{"permissionDecision":"deny","reason":\$ESCAPED_REASON}|{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":\$ESCAPED_REASON}}|g' "$script" 2>/dev/null || \
  log_warn "Could not auto-fix upstream-guard.sh. Manual update needed."

  if grep -q 'hookSpecificOutput' "$script" 2>/dev/null; then
    log_fix "Updated upstream-guard.sh to use hookSpecificOutput"
  fi
}

add_version_marker() {
  if [ ! -f "$PIPELINE_STATE" ]; then
    log_skip "No pipeline-state.json to update"
    return
  fi

  if grep -q '"sddVersion"' "$PIPELINE_STATE" 2>/dev/null; then
    log_skip "pipeline-state.json already has sddVersion"
    return
  fi

  if [ "$HAS_JQ" = true ]; then
    local tmpfile="${PIPELINE_STATE}.tmp.$$"
    jq '. + {"sddVersion": "2.4.0", "hooksVersion": 2}' "$PIPELINE_STATE" > "$tmpfile" 2>/dev/null && \
      mv "$tmpfile" "$PIPELINE_STATE"
    log_fix "Added sddVersion: 2.4.0 to pipeline-state.json"
  else
    # Fallback: use node
    node -e "
      const fs = require('fs');
      try {
        const state = JSON.parse(fs.readFileSync('$PIPELINE_STATE', 'utf8'));
        state.sddVersion = '2.4.0';
        state.hooksVersion = 2;
        fs.writeFileSync('$PIPELINE_STATE', JSON.stringify(state, null, 2));
        console.log('[FIX] Added sddVersion via node');
      } catch(e) {
        console.error('[WARN] Could not update pipeline-state.json:', e.message);
      }
    " 2>&1
  fi
}

# Apply all fixes
apply_settings_fixes
fix_upstream_guard_script
add_version_marker

echo ""
echo "============================================"
echo "  Migration complete"
echo "============================================"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code session to activate new hooks"
echo "  2. Run /sdd-setup to install optional features (dashboard, quality gates)"
echo "  3. Verify with /sdd-pipeline-status"
echo ""
