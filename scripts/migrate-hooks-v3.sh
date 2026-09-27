#!/usr/bin/env bash
# migrate-hooks-v3.sh — moves a project from the pre-4.0 SDD installation to the
# sdd-pipeline plugin model (hooksVersion 3).
#
# Before 4.0, install-sdd-automation.sh (or the old "sdd" plugin plus /sdd-setup)
# copied hooks and agents into the project's .claude/ directory and registered them
# in .claude/settings.json. Since 4.0 the sdd-pipeline plugin runs all of that from
# ${CLAUDE_PLUGIN_ROOT}; the project keeps only its own configuration.
#
# Usage: bash migrate-hooks-v3.sh [-C DIR] [--dry-run] [--gitignore-only]
#   -C DIR            project directory (default: cwd)
#   --dry-run         list what would change and exit without touching anything
#   --gitignore-only  only apply the .gitignore versioning policy (safe on fresh projects;
#                     this is what /sdd-setup runs in its "Versioning policy" step)
#
# What it does (idempotent; a backup goes to .claude/backups/sdd-v3-<timestamp>/):
#   1. removes every hooks[*][*].hooks[*] entry of .claude/settings.json whose command
#      contains "sdd-" (H1-H3, H5, H6/H9/H10 of old installations, trace-map and activity log
#      included); everything else in settings.json is preserved, including the opt-in quality gates;
#   2. deletes .claude/hooks/sdd-*.sh|.js, .claude/agents/sdd-*.md, the copied status lines
#      .claude/sdd-status-line.sh and .claude/sdd-subagent-status.sh, and the legacy runtime
#      files .sdd/current-task.json, .sdd/trace-map.json and .sdd/activity*.jsonl;
#   3. removes statusLine / subagentStatusLine entries that run an SDD script (sdd-status-line*,
#      sdd-subagent-status, ~/.claude/sdd/status-line.sh): the plugin no longer ships them;
#   4. reinstalls the git commit-msg hook from the plugin (install-git-hooks.sh);
#   5. sets sddVersion (from plugin.json) and hooksVersion: 3 in pipeline-state.json;
#   6. adds the "# sdd-begin ... # sdd-end" block of templates/gitignore.sdd to .gitignore.
# Old plugin ids (sdd@..., sdd-pipeline@sdd-pipeline-local) are reported, not removed:
# run /plugin uninstall <id> yourself.
#
# Requires jq or node. Portable: bash 3.2.

set -euo pipefail

DRY_RUN=false
GITIGNORE_ONLY=false
TARGET_DIR=""

usage() { sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)        DRY_RUN=true ;;
    --gitignore-only) GITIGNORE_ONLY=true ;;
    -C)               shift; TARGET_DIR="${1:-}" ;;
    -h|--help)        usage; exit 0 ;;
    *) echo "migrate-hooks-v3: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_found() { echo "[FOUND] $*"; }
log_fix()   { echo "[FIX]   $*"; }
log_skip()  { echo "[SKIP]  $*"; }
die()       { echo "[ERROR] $*" >&2; exit 1; }

if [ -n "$TARGET_DIR" ]; then
  cd "$TARGET_DIR" || die "cannot cd to $TARGET_DIR"
fi
PROJECT_DIR="$(pwd)"
SETTINGS="$PROJECT_DIR/.claude/settings.json"
PIPELINE_STATE="$PROJECT_DIR/pipeline-state.json"
GITIGNORE="$PROJECT_DIR/.gitignore"

# ── Plugin root: exported by the SessionStart hook, else this script's own checkout ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="${SDD_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$PLUGIN_ROOT" ] || [ ! -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
[ -f "$PLUGIN_ROOT/hooks/hooks.json" ] || die "plugin files not found under $PLUGIN_ROOT (hooks/hooks.json missing)"
GI_TPL="$PLUGIN_ROOT/templates/gitignore.sdd"

HAS_JQ=false;   command -v jq   >/dev/null 2>&1 && HAS_JQ=true
HAS_NODE=false; command -v node >/dev/null 2>&1 && HAS_NODE=true
[ "$HAS_JQ" = true ] || [ "$HAS_NODE" = true ] || die "jq or node is required (brew install jq / apt-get install jq)"

json_get() { # json_get FILE JQ_PATH NODE_EXPR  (prints value or empty; never fails)
  [ -f "$1" ] || return 0
  if [ "$HAS_JQ" = true ]; then
    jq -r "$2 // empty" "$1" 2>/dev/null || true
  else
    node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const v=(new Function("s","return "+process.argv[2]))(s);if(v!==undefined&&v!==null)process.stdout.write(String(v));' "$1" "$3" 2>/dev/null || true
  fi
}
json_valid() {
  if [ "$HAS_JQ" = true ]; then jq -e . "$1" >/dev/null 2>&1
  else node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$1" >/dev/null 2>&1; fi
}

PLUGIN_VERSION="$(json_get "$PLUGIN_ROOT/.claude-plugin/plugin.json" '.version' 's.version')"
[ -n "$PLUGIN_VERSION" ] || PLUGIN_VERSION="4.0.0"

# ── .gitignore policy (shared by sdd-setup and the migration) ────────────────
render_gitignore() { # render_gitignore OUT → writes the policy-applied .gitignore to OUT
  local out="$1"
  if [ -f "$GITIGNORE" ] && grep -q '^# sdd-begin' "$GITIGNORE" && grep -q '^# sdd-end' "$GITIGNORE"; then
    # Refresh the managed block in place so template updates propagate.
    awk -v tpl="$GI_TPL" '
      /^# sdd-begin/ { while ((getline line < tpl) > 0) print line; close(tpl); skip = 1; next }
      /^# sdd-end/   { skip = 0; next }
      !skip          { print }
    ' "$GITIGNORE" > "$out"
  else
    {
      if [ -s "$GITIGNORE" ]; then
        cat "$GITIGNORE"
        if [ -n "$(tail -c 1 "$GITIGNORE")" ]; then echo; fi
        echo
      fi
      cat "$GI_TPL"
    } > "$out"
  fi
}
gitignore_needs_update() {
  local tmp="$GITIGNORE.sdd-check.$$"
  [ -f "$GI_TPL" ] || return 1
  render_gitignore "$tmp"
  if [ -f "$GITIGNORE" ] && cmp -s "$tmp" "$GITIGNORE"; then rm -f "$tmp"; return 1; fi
  rm -f "$tmp"; return 0
}
apply_gitignore_policy() {
  local tmp="$GITIGNORE.sdd-tmp.$$"
  render_gitignore "$tmp"
  mv "$tmp" "$GITIGNORE"
  log_fix ".gitignore: sdd-begin/sdd-end block applied"
}
warn_tracked_state() {
  if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 && \
     git -C "$PROJECT_DIR" ls-files --error-unmatch pipeline-state.json >/dev/null 2>&1; then
    log_warn "pipeline-state.json is tracked by git; it is per-checkout state. Untrack it with:"
    log_warn "  git rm --cached pipeline-state.json && git commit -m 'chore(sdd): stop tracking pipeline state'"
  fi
}

if [ "$GITIGNORE_ONLY" = true ]; then
  [ -f "$GI_TPL" ] || die "template not found: $GI_TPL"
  if gitignore_needs_update; then
    if [ "$DRY_RUN" = true ]; then
      log_found ".gitignore: sdd block missing or outdated (dry-run, not applied)"
    else
      apply_gitignore_policy
    fi
  else
    log_skip ".gitignore: sdd block already up to date"
  fi
  warn_tracked_state
  exit 0
fi

echo "============================================"
echo "  SDD migration → plugin model (hooks v3)"
echo "============================================"
echo "Project: $PROJECT_DIR"
echo "Plugin:  $PLUGIN_ROOT (sdd-pipeline $PLUGIN_VERSION)"
echo ""

# ── Is the new plugin registered in Claude Code? ─────────────────────────────
PLUGIN_LISTED=false
if [ -n "${SDD_PLUGIN_ROOT:-}${CLAUDE_PLUGIN_ROOT:-}" ]; then
  PLUGIN_LISTED=true
elif command -v claude >/dev/null 2>&1 && claude plugin list 2>/dev/null | grep -q 'sdd-pipeline@'; then
  PLUGIN_LISTED=true
fi
if [ "$PLUGIN_LISTED" = true ]; then
  log_info "sdd-pipeline plugin detected"
else
  log_warn "sdd-pipeline is not listed by 'claude plugin list'. The hooks removed below are provided by the plugin:"
  log_warn "  /plugin marketplace add noelserdna/sdd-pipeline  →  /plugin install sdd-pipeline@noelserdna"
fi

# ── Phase 1: detection ───────────────────────────────────────────────────────
FIXES=()
add_fix() { FIXES+=("$1"); }

# 1. sdd- hook commands in settings.json
SDD_HOOK_LINES=""
if [ -f "$SETTINGS" ]; then
  if ! json_valid "$SETTINGS"; then
    die "$SETTINGS is not valid JSON — fix it before migrating"
  fi
  if [ "$HAS_JQ" = true ]; then
    SDD_HOOK_LINES="$(jq -r '
      def is_sdd: ((.command // "") | test("sdd-")) or ((.command // "") | test("^echo \\{\\}$"));
      [ (.hooks // {}) | to_entries[] | .key as $ev | (.value | if type == "array" then .[] else empty end)
        | (.hooks // [])[] | select(is_sdd) | "\($ev): \(.command)" ] | .[]' "$SETTINGS" 2>/dev/null || true)"
  else
    SDD_HOOK_LINES="$(node -e '
      const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const isSdd=h=>/sdd-/.test(h.command||"")||/^echo \{\}$/.test(h.command||"");
      for(const [ev,groups] of Object.entries(s.hooks||{})) if(Array.isArray(groups))
        for(const g of groups) for(const h of (g.hooks||[])) if(isSdd(h)) console.log(ev+": "+h.command);' "$SETTINGS" 2>/dev/null || true)"
  fi
  if [ -n "$SDD_HOOK_LINES" ]; then
    log_found "settings.json hooks provided by the plugin since 4.0 (will be removed):"
    echo "$SDD_HOOK_LINES" | sed 's/^/          /'
    add_fix "settings-hooks"
  fi
fi

# 2. Copied hook, agent and status line files; legacy runtime files of removed hooks
OLD_FILES=()
shopt -s nullglob
for f in "$PROJECT_DIR"/.claude/hooks/sdd-*.sh "$PROJECT_DIR"/.claude/hooks/sdd-*.js "$PROJECT_DIR"/.claude/agents/sdd-*.md \
         "$PROJECT_DIR"/.claude/sdd-status-line.sh "$PROJECT_DIR"/.claude/sdd-subagent-status.sh \
         "$PROJECT_DIR"/.sdd/current-task.json \
         "$PROJECT_DIR"/.sdd/trace-map.json "$PROJECT_DIR"/.sdd/activity*.jsonl; do
  [ -f "$f" ] && OLD_FILES+=("$f")
done
shopt -u nullglob
if [ "${#OLD_FILES[@]}" -gt 0 ]; then
  log_found "${#OLD_FILES[@]} legacy SDD file(s) under .claude/ or .sdd/ (will be deleted):"
  for f in ${OLD_FILES[@]+"${OLD_FILES[@]}"}; do echo "          ${f#"$PROJECT_DIR"/}"; done
  add_fix "old-files"
fi

# 3. Status lines: the plugin no longer ships them; drop entries that run an SDD script
SL_CMD="$(json_get "$SETTINGS" '.statusLine.command' 's.statusLine&&s.statusLine.command')"
SUB_CMD="$(json_get "$SETTINGS" '.subagentStatusLine.command' 's.subagentStatusLine&&s.subagentStatusLine.command')"
SL_ACTION=""
case "$SL_CMD" in
  *sdd-status-line*|*"/sdd/status-line.sh"*)
    SL_ACTION="remove"
    log_found "statusLine runs a legacy SDD status line (will be removed): $SL_CMD" ;;
esac
case "$SUB_CMD" in
  *sdd-subagent-status*)
    SL_ACTION="remove"
    log_found "subagentStatusLine runs a legacy SDD script (will be removed): $SUB_CMD" ;;
esac
[ -z "$SL_ACTION" ] || add_fix "status-line-remove"

# 4. commit-msg hook
COMMIT_MSG_ACTION=""
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  HOOK_PATH="$(git -C "$PROJECT_DIR" rev-parse --path-format=absolute --git-path hooks 2>/dev/null || true)"
  [ -n "$HOOK_PATH" ] || HOOK_PATH="$(git -C "$PROJECT_DIR" rev-parse --git-common-dir)/hooks"
  if [ ! -f "$HOOK_PATH/commit-msg" ] || ! cmp -s "$HOOK_PATH/commit-msg" "$PLUGIN_ROOT/hooks/sdd-commit-msg-hook.sh"; then
    COMMIT_MSG_ACTION="install"
    log_found "git commit-msg hook missing or outdated (will reinstall from the plugin)"
    add_fix "commit-msg"
  fi
fi

# 5. pipeline-state.json version markers
STATE_ACTION=""
if [ -f "$PIPELINE_STATE" ]; then
  if json_valid "$PIPELINE_STATE"; then
    HV="$(json_get "$PIPELINE_STATE" '.hooksVersion' 's.hooksVersion')"
    SV="$(json_get "$PIPELINE_STATE" '.sddVersion' 's.sddVersion')"
    case "$HV" in ''|*[!0-9]*) HV=0 ;; esac
    if [ "$HV" -lt 3 ] || [ "$SV" != "$PLUGIN_VERSION" ]; then
      STATE_ACTION="update"
      log_found "pipeline-state.json: sddVersion=${SV:-none} hooksVersion=${HV} (will set $PLUGIN_VERSION / 3)"
      add_fix "pipeline-version"
    fi
  else
    log_warn "pipeline-state.json is not valid JSON — left untouched"
  fi
fi

# 6. .gitignore policy
GI_ACTION=""
if [ -f "$GI_TPL" ] && gitignore_needs_update; then
  GI_ACTION="apply"
  log_found ".gitignore: sdd-begin/sdd-end block missing or outdated (will apply)"
  add_fix "gitignore"
fi

# 7. Old plugin ids (advisory only)
REGISTRY="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
OLD_IDS=""
if [ -f "$REGISTRY" ]; then
  OLD_IDS="$(grep -oE '"(sdd@[^"]+|sdd-pipeline@sdd-pipeline-local)"' "$REGISTRY" 2>/dev/null | tr -d '"' | sort -u || true)"
fi

echo ""
if [ "${#FIXES[@]}" -eq 0 ]; then
  log_info "Nothing to migrate: the project already uses the plugin model (hooks v3)."
  if [ -n "$OLD_IDS" ]; then
    log_warn "Old plugin(s) still installed — remove them to avoid duplicate hooks:"
    echo "$OLD_IDS" | sed 's|^|          /plugin uninstall |'
  fi
  warn_tracked_state
  exit 0
fi

echo "Planned changes (${#FIXES[@]}):"
for fix in ${FIXES[@]+"${FIXES[@]}"}; do echo "  - $fix"; done
if [ -n "$OLD_IDS" ]; then
  echo ""
  log_warn "Old plugin(s) registered in Claude Code — uninstall them yourself (a script cannot):"
  echo "$OLD_IDS" | sed 's|^|          /plugin uninstall |'
fi
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] No changes made. Run without --dry-run to apply."
  exit 0
fi

# ── Phase 2: backup ──────────────────────────────────────────────────────────
BACKUP_DIR="$PROJECT_DIR/.claude/backups/sdd-v3-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
[ -f "$SETTINGS" ]       && cp "$SETTINGS" "$BACKUP_DIR/settings.json"
[ -f "$PIPELINE_STATE" ] && cp "$PIPELINE_STATE" "$BACKUP_DIR/pipeline-state.json"
[ -f "$GITIGNORE" ]      && cp "$GITIGNORE" "$BACKUP_DIR/gitignore"
for f in ${OLD_FILES[@]+"${OLD_FILES[@]}"}; do
  sub="$(basename "$(dirname "$f")")"
  mkdir -p "$BACKUP_DIR/$sub"
  cp "$f" "$BACKUP_DIR/$sub/"
done
log_info "Backup written to ${BACKUP_DIR#"$PROJECT_DIR"/}"
echo ""

# ── Phase 3: apply ───────────────────────────────────────────────────────────
CHANGED=()

# 3b. settings.json: strip sdd- hooks and an SDD statusLine, keep everything else
if [ -n "$SDD_HOOK_LINES" ] || [ -n "$SL_ACTION" ]; then
  tmp="$SETTINGS.tmp.$$"
  if [ "$HAS_JQ" = true ]; then
    jq '
      def is_sdd: ((.command // "") | test("sdd-")) or ((.command // "") | test("^echo \\{\\}$"));
      (if (.hooks | type) == "object" then
        .hooks |= (
          with_entries(
            .value |= (if type == "array"
                       then map(if (.hooks | type) == "array" then .hooks |= map(select(is_sdd | not)) else . end
                                | select(((.hooks // []) | length) > 0))
                       else . end)
          ) | with_entries(select((.value | type) != "array" or (.value | length) > 0))
        )
        | if (.hooks | length) == 0 then del(.hooks) else . end
      else . end)
      | if ((.statusLine.command // "") | test("sdd-status-line|/sdd/status-line\\.sh"))
        then del(.statusLine) else . end
      | if ((.subagentStatusLine.command // "") | test("sdd-subagent-status"))
        then del(.subagentStatusLine) else . end
    ' "$SETTINGS" > "$tmp"
  else
    node -e '
      const fs=require("fs"); const f=process.argv[1];
      const s=JSON.parse(fs.readFileSync(f,"utf8"));
      const isSdd=h=>/sdd-/.test(h.command||"")||/^echo \{\}$/.test(h.command||"");
      if(s.hooks&&typeof s.hooks==="object"){
        for(const ev of Object.keys(s.hooks)){
          if(!Array.isArray(s.hooks[ev])) continue;
          s.hooks[ev]=s.hooks[ev].map(g=>{ if(Array.isArray(g.hooks)) g.hooks=g.hooks.filter(h=>!isSdd(h)); return g; })
                                 .filter(g=>(g.hooks||[]).length>0);
          if(s.hooks[ev].length===0) delete s.hooks[ev];
        }
        if(Object.keys(s.hooks).length===0) delete s.hooks;
      }
      if(s.statusLine&&/sdd-status-line|\/sdd\/status-line\.sh/.test(s.statusLine.command||""))
        delete s.statusLine;
      if(s.subagentStatusLine&&/sdd-subagent-status/.test(s.subagentStatusLine.command||""))
        delete s.subagentStatusLine;
      fs.writeFileSync(process.argv[2],JSON.stringify(s,null,2)+"\n");' "$SETTINGS" "$tmp"
  fi
  mv "$tmp" "$SETTINGS"
  log_fix "settings.json: sdd- hooks removed${SL_ACTION:+, SDD status lines removed}; other settings preserved"
  CHANGED+=("settings")
fi

# 3c. delete copied hooks, agents, status line and legacy runtime files
if [ "${#OLD_FILES[@]}" -gt 0 ]; then
  for f in ${OLD_FILES[@]+"${OLD_FILES[@]}"}; do rm -f "$f"; done
  rmdir "$PROJECT_DIR/.claude/hooks" 2>/dev/null || true
  rmdir "$PROJECT_DIR/.claude/agents" 2>/dev/null || true
  log_fix "deleted ${#OLD_FILES[@]} legacy SDD file(s) from .claude/ and .sdd/"
  CHANGED+=("old-files")
fi

# 3d. git commit-msg hook
if [ -n "$COMMIT_MSG_ACTION" ]; then
  if bash "$PLUGIN_ROOT/scripts/install-git-hooks.sh" -C "$PROJECT_DIR" --quiet; then
    log_fix "git commit-msg hook reinstalled from the plugin"
    CHANGED+=("commit-msg")
  else
    log_warn "could not reinstall the commit-msg hook (see above)"
  fi
fi

# 3e. pipeline-state.json version markers
if [ -n "$STATE_ACTION" ]; then
  tmp="$PIPELINE_STATE.tmp.$$"
  if [ "$HAS_JQ" = true ]; then
    jq --arg v "$PLUGIN_VERSION" '. + {sddVersion: $v, hooksVersion: 3}' "$PIPELINE_STATE" > "$tmp"
  else
    node -e '
      const fs=require("fs"); const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
      s.sddVersion=process.argv[3]; s.hooksVersion=3;
      fs.writeFileSync(process.argv[2],JSON.stringify(s,null,2)+"\n");' "$PIPELINE_STATE" "$tmp" "$PLUGIN_VERSION"
  fi
  mv "$tmp" "$PIPELINE_STATE"
  log_fix "pipeline-state.json: sddVersion=$PLUGIN_VERSION hooksVersion=3"
  CHANGED+=("pipeline-version")
fi

# 3f. .gitignore policy
if [ -n "$GI_ACTION" ]; then
  apply_gitignore_policy
  CHANGED+=("gitignore")
fi
warn_tracked_state

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Migration complete (${#CHANGED[@]} change(s): $(IFS=,; echo "${CHANGED[*]-}"))"
echo "============================================"
echo "Backup: ${BACKUP_DIR#"$PROJECT_DIR"/}"
echo ""
echo "Next steps:"
echo "  1. Start a new Claude Code session (or /reload-plugins) so the plugin hooks take over"
if [ -n "$OLD_IDS" ]; then
  echo "  2. Uninstall the old plugin(s): $(echo "$OLD_IDS" | tr '\n' ' ')"
fi
echo "  3. Run /sdd-pipeline-status to verify the pipeline state"
echo "  4. Commit .claude/settings.json and .gitignore (pipeline-state.json is now ignored)"
