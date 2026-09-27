#!/usr/bin/env bash
# install-git-hooks.sh — installs (or removes) the SDD commit-msg traceability hook.
#
# Usage: bash install-git-hooks.sh [-C DIR] [--uninstall] [--quiet]
#
# The hook is copied from <plugin>/hooks/sdd-commit-msg-hook.sh into the hooks
# directory that git actually uses for this repository:
#   - core.hooksPath if set (relative paths resolve against the work tree root)
#   - otherwise $(git rev-parse --git-common-dir)/hooks, which is shared by every
#     linked worktree, so installing once covers all of them.
#
# It also vendors the validator the hook runs, <plugin>/scripts/sdd.mjs plus the
# modules it imports (lib/git-log.mjs, …; same layout as scripts/), into
# <work tree>/.claude/sdd/ with a header naming the plugin version; re-installing
# overwrites them. Commit them: CI and teammates
# without the plugin run `node .claude/sdd/sdd.mjs verify --range A..B` from there.
#
# Idempotent: re-running with the same content is a no-op. A hook that is
# not ours is backed up as commit-msg.backup.<timestamp> before being replaced,
# and --uninstall restores the most recent backup (the vendored files stay).
#
# Portable: bash 3.2, no GNU-only flags.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/../hooks/sdd-commit-msg-hook.sh"
CLI_SRC="$SCRIPT_DIR/sdd.mjs"
MARKER="SDD Commit Message Traceability Hook"
VENDOR_MARKER="Vendored by sdd-pipeline"

MODE="install"
QUIET=false
TARGET_DIR=""

usage() {
  sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) MODE="uninstall" ;;
    --quiet|-q)  QUIET=true ;;
    -C)          shift; TARGET_DIR="${1:-}" ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "install-git-hooks: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log()  { [ "$QUIET" = true ] || echo "[SDD] $*"; }
warn() { echo "[SDD] WARN: $*" >&2; }
die()  { echo "[SDD] ERROR: $*" >&2; exit 1; }

if [ -n "$TARGET_DIR" ]; then
  cd "$TARGET_DIR" || die "cannot cd to $TARGET_DIR"
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree (run from the project or pass -C DIR)"

# Absolute path helper (bash 3.2 / BSD friendly): resolves DIR/FILE without realpath.
abs_path() {
  local p="$1" d b
  case "$p" in
    /*) ;;
    *)  p="$PWD/$p" ;;
  esac
  d="$(dirname "$p")"
  b="$(basename "$p")"
  if [ -d "$d" ]; then
    d="$(cd "$d" && pwd)"
  fi
  printf '%s/%s\n' "$d" "$b"
}

# Resolve the hooks directory git will consult for this work tree.
hooks_dir() {
  local hp tilde
  hp="$(git config --get core.hooksPath 2>/dev/null || true)"
  if [ -n "$hp" ]; then
    tilde='~'
    case "$hp" in
      /*) ;;
      *)
        if [ "${hp#"$tilde"/}" != "$hp" ]; then
          hp="$HOME/${hp#"$tilde"/}"
        else
          hp="$(git rev-parse --show-toplevel)/$hp"
        fi
        ;;
    esac
    abs_path "$hp"
    return
  fi
  # --path-format=absolute needs git >= 2.31; fall back to resolving by hand.
  hp="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -z "$hp" ]; then
    hp="$(git rev-parse --git-common-dir)"
    hp="$(abs_path "$hp")"
  fi
  printf '%s/hooks\n' "$hp"
}

HOOKS_DIR="$(hooks_dir)"
DST="$HOOKS_DIR/commit-msg"

is_sdd_hook() {
  [ -f "$1" ] && grep -q "$MARKER" "$1" 2>/dev/null
}

latest_backup() {
  # Newest commit-msg.backup.* by name (timestamps sort lexicographically).
  { ls -1 "$HOOKS_DIR"/commit-msg.backup.* 2>/dev/null || true; } | sort | tail -n 1
}

if [ "$MODE" = "uninstall" ]; then
  if [ ! -f "$DST" ]; then
    log "no commit-msg hook at $DST — nothing to do"
    exit 0
  fi
  if ! is_sdd_hook "$DST"; then
    warn "$DST is not the SDD hook — left untouched"
    exit 0
  fi
  rm -f "$DST"
  log "removed SDD commit-msg hook: $DST"
  bk="$(latest_backup)"
  if [ -n "$bk" ]; then
    mv "$bk" "$DST"
    chmod +x "$DST"
    log "restored previous hook from $(basename "$bk")"
  fi
  exit 0
fi

# ── install ──────────────────────────────────────────────────────────────────
[ -f "$SRC" ] || die "hook source not found: $SRC (is the plugin checkout complete?)"

# Vendor sdd.mjs and every module it imports (relative `from "./…"` / `"../…"`, followed recursively) into
# <work tree>/.claude/sdd/, keeping their paths relative to scripts/.
plugin_version() {
  sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$SCRIPT_DIR/../.claude-plugin/plugin.json" 2>/dev/null | head -n 1
}
# Relative path of FILE under scripts/ after resolving ".." (FILE is SCRIPT_DIR/…); empty when it escapes scripts/.
rel_to_scripts() {
  local d f
  d="$(cd "$(dirname "$1")" 2>/dev/null && pwd)" || return 0
  f="$d/$(basename "$1")"
  case "$f" in "$SCRIPT_DIR"/*) printf '%s\n' "${f#"$SCRIPT_DIR"/}" ;; esac
}
import_closure() { # prints paths relative to scripts/, sdd.mjs first
  local queue="sdd.mjs" seen=" " cur spec dep
  while [ -n "$queue" ]; do
    queue="${queue# }"
    cur="${queue%% *}"; queue="${queue#"$cur"}"
    [ -z "$cur" ] && continue
    case "$seen" in *" $cur "*) continue ;; esac
    [ -f "$SCRIPT_DIR/$cur" ] || { warn "vendoring: $cur not found"; continue; }
    seen="$seen$cur "
    printf '%s\n' "$cur"
    while IFS= read -r spec; do
      [ -z "$spec" ] && continue
      dep="$(rel_to_scripts "$(dirname "$SCRIPT_DIR/$cur")/$spec")"
      if [ -n "$dep" ]; then queue="$queue $dep"; else warn "vendoring: $cur imports $spec outside scripts/"; fi
    done < <(grep -oE "(from|import)[[:space:]]*\(?[\"'](\.\.?/[^\"']+)[\"']" "$SCRIPT_DIR/$cur" | sed -E "s/.*[\"'](\.\.?\/[^\"']+)[\"']/\1/")
  done
}
vendor_one() { # vendor_one REL DST (header after a shebang line, else first); prints "updated" when DST changed
  local src="$SCRIPT_DIR/$1" dst="$2" tmpf header
  header="// $VENDOR_MARKER ${VERSION:-unknown} (scripts/$1) by install-git-hooks.sh; re-install overwrites it — edit the plugin, not this copy."
  tmpf="$dst.tmp.$$"
  mkdir -p "$(dirname "$dst")"
  if head -n 1 "$src" | grep -q '^#!'; then
    { head -n 1 "$src"; printf '%s\n' "$header"; tail -n +2 "$src"; } > "$tmpf"
  else
    { printf '%s\n' "$header"; cat "$src"; } > "$tmpf"
  fi
  if [ -f "$dst" ] && cmp -s "$tmpf" "$dst"; then
    rm -f "$tmpf"
    return 0
  fi
  mv "$tmpf" "$dst"
  echo updated
}
if [ -f "$CLI_SRC" ]; then
  VERSION="$(plugin_version)"
  VENDOR_DIR="$(git rev-parse --show-toplevel)/.claude/sdd"
  VENDOR_CHANGED=""
  for f in $(import_closure); do
    [ -n "$(vendor_one "$f" "$VENDOR_DIR/$f")" ] && VENDOR_CHANGED=1
  done
  chmod +x "$VENDOR_DIR/sdd.mjs"
  [ -n "$VENDOR_CHANGED" ] && log "validator vendored: $VENDOR_DIR/sdd.mjs (sdd-pipeline ${VERSION:-unknown})"
else
  warn "scripts/sdd.mjs not found next to this installer; the hook will use its bash rules"
fi

mkdir -p "$HOOKS_DIR"

if [ -f "$DST" ]; then
  if is_sdd_hook "$DST"; then
    if cmp -s "$SRC" "$DST"; then
      chmod +x "$DST"
      log "commit-msg hook already installed and up to date: $DST"
      exit 0
    fi
    log "updating SDD commit-msg hook (previous version replaced)"
  else
    BK="$DST.backup.$(date +%Y%m%d%H%M%S)"
    cp "$DST" "$BK"
    warn "existing non-SDD commit-msg hook backed up to $(basename "$BK")"
  fi
fi

cp "$SRC" "$DST"
chmod +x "$DST"
log "commit-msg hook installed: $DST"
if git config --get core.hooksPath >/dev/null 2>&1; then
  log "note: core.hooksPath is set; the hook lives in that directory"
fi
