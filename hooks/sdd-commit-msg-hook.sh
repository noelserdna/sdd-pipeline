#!/usr/bin/env bash
# SDD Commit Message Traceability Hook
# Hook type: git commit-msg | Installed to: <hooks dir>/commit-msg by scripts/install-git-hooks.sh
#
# Validates the commit message with the rules of references/git-conventions.md, the same ones as
# `sdd verify --message`:
#   - subject `<type>(<scope>): <summary>` with a Conventional Commits type;
#   - feat, test, refactor need `Task: TASK-F<N>-<NNN>`; fix, perf need `Task:` or `Change:`;
#     docs(specs) needs `Refs:`; other docs, chore, ci, style, build need nothing;
#   - Task, Refs and Change values must be well-formed ids;
#   - a Task/Refs/Change line that git does not parse as a trailer (prose, `Closes #N` or a blank line after the
#     block) is an error: git reads trailers only from the last paragraph.
# Exempt: merges (`Merge …`), `Revert "…"`, `fixup!`/`squash!`/`amend!`, and any message containing [skip-sdd].
#
# Engine: `node .claude/sdd/sdd.mjs verify --message` (vendored by install-git-hooks.sh) when node >= 18 and the
# file exist; otherwise a bash implementation of the same rules on top of `git interpret-trailers --parse`.
#
# Bypass: add [skip-sdd] to the message, or set SDD_SKIP_VERIFY=1.
#
# Portable: bash 3.2, no GNU-only flags.

set -u

MSG_FILE="${1:-}"

[ "${SDD_SKIP_VERIFY:-0}" = "1" ] && exit 0

if [ -z "$MSG_FILE" ] || [ ! -f "$MSG_FILE" ]; then
  echo "[SDD] ERROR: commit message file not found: ${MSG_FILE:-<none>}" >&2
  exit 1
fi

footer() {
  cat >&2 <<'EOF'

[SDD] Write trailers with --trailer so git builds a valid block (references/git-conventions.md):
        git commit -m "feat(tasks): create task" --trailer "Task: TASK-F2-003" --trailer "Refs: UC-002, API-002"
        git commit -m "fix(auth): reject expired tokens" --trailer "Change: CHG-2026-09-27-001"
      Bypass: add [skip-sdd] to the message, or set SDD_SKIP_VERIFY=1.
EOF
}

# ── 1. Vendored validator (node) ─────────────────────────────────────────────
find_sdd() {
  local top common cand
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  for cand in "${top:+$top/.claude/sdd/sdd.mjs}" "${common:+$(dirname "$common")/.claude/sdd/sdd.mjs}"; do
    [ -n "$cand" ] && [ -f "$cand" ] && { printf '%s\n' "$cand"; return 0; }
  done
  return 1
}

if command -v node >/dev/null 2>&1 \
   && node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)' >/dev/null 2>&1 \
   && SDD_MJS="$(find_sdd)"; then
  rc=0
  OUT="$(node "$SDD_MJS" verify --message "$MSG_FILE" 2>&1)" || rc=$?
  # A verdict always ends with the `verify: N message(s)` line; anything else (a missing module, a crash) is an engine
  # failure, and the bash rules below decide instead.
  case "$rc:$OUT" in
    0:*"verify: "*) case "$OUT" in *warning:*) printf '%s\n' "$OUT" >&2 ;; esac; exit 0 ;;
    1:*"verify: "*) printf '%s\n' "$OUT" >&2; footer; exit 1 ;;
    *) echo "[SDD] WARN: $SDD_MJS failed (exit $rc); validating with the bash rules" >&2 ;;
  esac
fi

# ── 2. Bash validator (same rules) ───────────────────────────────────────────
RE_TASK='^TASK-F[0-9]+-[0-9]{3,4}$'
RE_REFS='^[A-Z][A-Z0-9]*(-[A-Z0-9]+)+$'
RE_CHANGE='^(CHG-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}|CR-[0-9]+|[A-Z]{2,5}-[0-9]+)$'
RE_SUBJECT='^([a-z]+)(\([^()]*\))?(!)?: [^[:space:]]'
RE_BODY_TRAILER='^([Tt][Aa][Ss][Kk]|[Rr][Ee][Ff][Ss]|[Cc][Hh][Aa][Nn][Gg][Ee])[[:space:]]*:[[:space:]]*(.*)$'
TYPES=" feat fix docs style refactor perf test build ci chore revert "

ERRORS=0
WARNINGS=0
err()  { echo "$MSG_FILE: error: $*" >&2; ERRORS=$((ERRORS + 1)); }
warn() { echo "$MSG_FILE: warning: $*" >&2; WARNINGS=$((WARNINGS + 1)); }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
canon() { case "$(lower "$1")" in task) echo Task ;; refs) echo Refs ;; change) echo Change ;; esac; }
finish() {
  [ $((ERRORS + WARNINGS)) -gt 0 ] && echo "verify: 1 message(s), $ERRORS error(s), $WARNINGS warning(s)" >&2
  if [ "$ERRORS" -gt 0 ]; then footer; exit 1; fi
  exit 0
}

# Drop comment lines and everything after the scissors line, as git does; keep original line numbers.
NUMS=(); TEXTS=()
while IFS= read -r row || [ -n "$row" ]; do
  NUMS[${#NUMS[@]}]="${row%%$'\t'*}"
  TEXTS[${#TEXTS[@]}]="${row#*$'\t'}"
done <<EOF
$(awk '{ sub(/\r$/, "") } /^# -+ >8 -+$/ { exit } /^#/ { next } { printf "%d\t%s\n", NR, $0 }' "$MSG_FILE")
EOF
first=-1; last=-1
for i in "${!TEXTS[@]}"; do
  if [ -n "$(trim "${TEXTS[$i]}")" ]; then
    [ "$first" -lt 0 ] && first=$i
    last=$i
  fi
done
if [ "$first" -lt 0 ]; then err "empty commit message"; finish; fi

MESSAGE=""
for ((i = first; i <= last; i++)); do MESSAGE="$MESSAGE${TEXTS[$i]}"$'\n'; done
SUBJECT="${TEXTS[$first]}"

EXEMPT=""
case "$SUBJECT" in
  Merge\ *) EXEMPT=merge ;;
  Revert\ \"*) EXEMPT=revert ;;
  fixup!\ *|squash!\ *|amend!\ *) EXEMPT=autosquash ;;
esac
case "$MESSAGE" in *"[skip-sdd]"*) [ -z "$EXEMPT" ] && EXEMPT=skip-sdd ;; esac

# Trailers exactly as git parses them.
PARSED="$(printf '%s' "$MESSAGE" | git interpret-trailers --parse 2>/dev/null || true)"
TASKS=""; REFS=""; CHANGES=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  key="$(trim "${line%%:*}")"; value="$(trim "${line#*:}")"
  c="$(canon "$key")"
  [ -z "$c" ] && continue
  [ "$key" != "$c" ] && warn "trailer key \`$key\` should be written \`$c\`"
  toks="$(printf '%s' "$value" | tr ',;' '  ')"
  case "$c" in
    Task) TASKS="$TASKS $toks" ;;
    Refs) REFS="$REFS $toks" ;;
    Change) CHANGES="$CHANGES $toks" ;;
  esac
done <<EOF
$PARSED
EOF

# Broken block: a Task/Refs/Change line in the body that git does not parse as a trailer.
for ((i = first + 1; i <= last; i++)); do
  text="${TEXTS[$i]}"
  [[ $text =~ $RE_BODY_TRAILER ]] || continue
  bkey="$(lower "${BASH_REMATCH[1]}")"; bval="$(trim "${BASH_REMATCH[2]}")"
  found=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    pkey="$(lower "$(trim "${line%%:*}")")"; pval="$(trim "${line#*:}")"
    if [ "$pkey" = "$bkey" ] && [ "${pval#"$bval"}" != "$pval" ]; then found=1; break; fi
  done <<EOF
$PARSED
EOF
  [ "$found" = 1 ] || err "line ${NUMS[$i]}: \`$(trim "$text")\` is outside the trailer block — git reads trailers only from the last paragraph, and only when every line in it is a trailer (no prose, \`Closes #N\` or blank line after it); write it with \`git commit --trailer\`"
done
[ -n "$EXEMPT" ] && finish

if [[ ! $SUBJECT =~ $RE_SUBJECT ]]; then
  err "subject is not a conventional commit \`<type>(<scope>): <summary>\`: $SUBJECT"; finish
fi
TYPE="${BASH_REMATCH[1]}"; SCOPE="${BASH_REMATCH[2]}"
case "$TYPES" in
  *" $TYPE "*) ;;
  *) err "unknown commit type \`$TYPE\` (use feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert)"; finish ;;
esac
[ "$TYPE" = revert ] && finish

strip() { printf '%s' "$1" | sed -E 's/^[([]+//; s/[].)]+$//'; }
NT=0; NR=0; NC=0
for t in $TASKS; do t="$(strip "$t")"; [ -z "$t" ] && continue; NT=$((NT + 1))
  [[ $t =~ $RE_TASK ]] || err "Task \`$t\` does not match TASK-F<N>-<NNN>"; done
[ "$NT" -gt 1 ] && warn "$NT Task ids in one commit (1 task = 1 commit)"
for t in $REFS; do t="$(strip "$t")"; [ -z "$t" ] && continue; NR=$((NR + 1))
  [[ $t =~ $RE_REFS ]] || err "Refs \`$t\` is not a spec id (e.g. REQ-F-001, UC-003)"; done
for t in $CHANGES; do t="$(strip "$t")"; [ -z "$t" ] && continue; NC=$((NC + 1))
  [[ $t =~ $RE_CHANGE ]] || err "Change \`$t\` does not match CHG-YYYY-MM-DD-NNN, CR-N or a finding id (e.g. SEC-12)"; done

case "$TYPE" in
  feat|test|refactor) [ "$NT" -eq 0 ] && err "\`$TYPE\` needs a \`Task:\` trailer" ;;
  fix|perf) [ "$NT" -eq 0 ] && [ "$NC" -eq 0 ] && err "\`$TYPE\` needs a \`Task:\` or \`Change:\` trailer" ;;
  docs) [ "$SCOPE" = "(specs)" ] && [ "$NR" -eq 0 ] && err "\`docs(specs)\` needs a \`Refs:\` trailer" ;;
esac
finish
