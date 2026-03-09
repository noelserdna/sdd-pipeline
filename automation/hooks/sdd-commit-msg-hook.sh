#!/usr/bin/env bash
# SDD Commit Message Traceability Hook
# Hook type: git commit-msg | Installed to: .git/hooks/commit-msg
# Enforces that implementation commits (feat, fix, perf, test) include
# proper traceability trailers (Refs: and/or Task:) per SDD pipeline conventions.
#
# Bypass methods:
#   - Add [skip-sdd] anywhere in the commit message body
#   - Set env var: SDD_SKIP_VERIFY=1
#
# Allowed without trailers:
#   - Merge commits (start with "Merge ")
#   - docs, chore, ci, style, build commit types
#   - refactor commits require at least Task: trailer

set -euo pipefail

COMMIT_MSG_FILE="$1"

# ── Escape hatch: env var bypass ──────────────────────────────────────────────
if [ "${SDD_SKIP_VERIFY:-0}" = "1" ]; then
  exit 0
fi

# ── Read commit message ──────────────────────────────────────────────────────
if [ ! -f "$COMMIT_MSG_FILE" ]; then
  echo "[SDD] ERROR: Commit message file not found: $COMMIT_MSG_FILE"
  exit 1
fi

COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
FIRST_LINE=$(head -n 1 "$COMMIT_MSG_FILE")

# ── Merge commits: always allowed ─────────────────────────────────────────────
case "$FIRST_LINE" in
  Merge\ *)
    exit 0
    ;;
esac

# ── [skip-sdd] in message body: always allowed ───────────────────────────────
if echo "$COMMIT_MSG" | grep -q '\[skip-sdd\]'; then
  exit 0
fi

# ── Extract commit type from Conventional Commits format ──────────────────────
# Matches: type(scope): description  OR  type: description
# The type is everything before the first '(' or ':'
COMMIT_TYPE=""
if echo "$FIRST_LINE" | grep -qE '^[a-z]+(\(.+\))?!?:'; then
  COMMIT_TYPE=$(echo "$FIRST_LINE" | sed -E 's/^([a-z]+)(\(.+\))?!?:.*/\1/')
fi

# ── Types that never require trailers ─────────────────────────────────────────
case "$COMMIT_TYPE" in
  docs|chore|ci|style|build)
    exit 0
    ;;
esac

# ── Check for trailers ───────────────────────────────────────────────────────
HAS_REFS=false
HAS_TASK=false

if echo "$COMMIT_MSG" | grep -qE '^Refs: .+'; then
  HAS_REFS=true
fi

if echo "$COMMIT_MSG" | grep -qE '^Task: .+'; then
  HAS_TASK=true
fi

# ── Refactor: requires at least Task: ─────────────────────────────────────────
if [ "$COMMIT_TYPE" = "refactor" ]; then
  if [ "$HAS_TASK" = true ]; then
    exit 0
  fi
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║  SDD Commit Hook — Missing Traceability Trailer                ║"
  echo "╠══════════════════════════════════════════════════════════════════╣"
  echo "║                                                                ║"
  echo "║  Commit type 'refactor' requires at least a Task: trailer.     ║"
  echo "║                                                                ║"
  echo "║  Example:                                                      ║"
  echo "║    refactor(auth): extract token validation                    ║"
  echo "║                                                                ║"
  echo "║    Refactored token validation into reusable module.           ║"
  echo "║                                                                ║"
  echo "║    Task: TASK-FASE-2-003                                       ║"
  echo "║                                                                ║"
  echo "║  Bypass: add [skip-sdd] to the message body                   ║"
  echo "║          or set SDD_SKIP_VERIFY=1                              ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
  exit 1
fi

# ── Implementation types (feat, fix, perf, test, or unknown): require trailers ─
# If we have no recognized type, we still require trailers for safety.
# Only the explicitly exempted types above skip the check.
if [ "$HAS_REFS" = true ] || [ "$HAS_TASK" = true ]; then
  exit 0
fi

# ── Rejection: missing trailers ───────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  SDD Commit Hook — Missing Traceability Trailer                ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                ║"
echo "║  Commits of type '${COMMIT_TYPE:-<unrecognized>}' require at least one trailer:"
echo "║    Refs: <artifact-id>    (e.g., Refs: REQ-001, UC-003)        ║"
echo "║    Task: <task-id>        (e.g., Task: TASK-FASE-1-002)        ║"
echo "║                                                                ║"
echo "║  Example:                                                      ║"
echo "║    feat(auth): add JWT token refresh                           ║"
echo "║                                                                ║"
echo "║    Implements automatic token refresh when expired.            ║"
echo "║                                                                ║"
echo "║    Refs: REQ-AUTH-003, UC-AUTH-002                             ║"
echo "║    Task: TASK-FASE-1-005                                       ║"
echo "║                                                                ║"
echo "║  Bypass: add [skip-sdd] to the message body                   ║"
echo "║          or set SDD_SKIP_VERIFY=1                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
exit 1
