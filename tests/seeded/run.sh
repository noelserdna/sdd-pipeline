#!/usr/bin/env bash
# Seeded-defect bench for sdd-pipeline 5.1: which layer catches each defect of the real case (docs/MEJORAS-SDD-5.1.md)?
# Project: tests/fixtures/seeded/app (a small «CV de alumnos» app, Node >= 18, no dependencies, every test green),
# copied into a temporary git repo with one commit. Answer key: tests/seeded/EXPECTED.md (outside the project, so the
# blind adversarial round cannot read it). This script runs the mechanical layers only:
#   node --test (precondition: the suite is green) · sdd lint --quotes --json · sdd accept --fase 1 --junit junit
#   --junit-sha HEAD --json · sdd gate --fase 1 --json · sdd lint --plan --json · sdd lint
# and then a second stage (5.3): a commit that skips a bound test (D8) and one that lowers a Stack Profile gate (D9),
# each checked with `sdd lint --floor --base HEAD~1 --json`.
# and tests/seeded/check.mjs compares their output with the key: exit 1 when an expected mechanical layer misses its
# defect or a control requirement is flagged. `sdd lint --quotes` (Q-01/Q-02/Q-03, criterion state `weakened`,
# summary.literal_gaps) is reported SKIP while the CLI does not have it.
#
#   bash tests/seeded/run.sh                 run the bench (temporary copy, removed at exit)
#   bash tests/seeded/run.sh --keep DIR      same, and keep the repo in DIR/app and the raw outputs in DIR/out
#   bash tests/seeded/run.sh --prepare DIR   only build the committed repo in DIR/app (for the blind adversarial round)
# bash 3.2 (macOS) and bash 5; needs git and node >= 18. Run with `env -u SDD_STATE_ROOT`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
APP="$ROOT/tests/fixtures/seeded/app"

mode=run keep=""
case "${1:-}" in
  --keep) mode=run; keep="${2:?--keep needs a directory}" ;;
  --prepare) mode=prepare; keep="${2:?--prepare needs a directory}" ;;
  "") ;;
  *) echo "usage: run.sh [--keep DIR | --prepare DIR]" >&2; exit 2 ;;
esac

if [ -n "$keep" ]; then
  mkdir -p "$keep"
  base="$(cd "$keep" && pwd -P)"
  if [ -e "$base/app" ]; then echo "run.sh: $base/app already exists" >&2; exit 2; fi
else
  base="$(mktemp -d)"
  base="$(cd "$base" && pwd -P)"
  trap 'rm -rf "$base"' EXIT
fi
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME="Equipo CV" GIT_AUTHOR_EMAIL=cv@campus.test GIT_COMMITTER_NAME="Equipo CV" GIT_COMMITTER_EMAIL=cv@campus.test

# ---------------------------------------------------------------- the project as a committed repo
repo="$base/app"
cp -R "$APP" "$repo"
rm -rf "$repo/.sdd"
(
  cd "$repo"
  git init -q
  git symbolic-ref HEAD refs/heads/main
  git add -A
  # Dated in the past: the JUnit report and the captures (copied now) are newer than the last code commit.
  GIT_AUTHOR_DATE="2026-09-10T10:00:00" GIT_COMMITTER_DATE="2026-09-10T10:00:00" \
    git commit -qm "feat(cv): CV de alumnos, FASE-1" --trailer "Refs: FASE-1"
)
find "$repo/junit" "$repo/evidencias" -type f -exec touch {} +
if [ "$mode" = prepare ]; then
  echo "prepared: $repo (HEAD $(cd "$repo" && git rev-parse --short HEAD))"
  exit 0
fi

out="$base/out"
mkdir -p "$out"
# sdd ARGS… > $out/NAME.json, stderr to NAME.err, exit code to NAME.rc
sdd() {
  local name="$1"; shift
  local rc=0
  (cd "$repo" && node "$SDD" "$@") > "$out/$name.json" 2> "$out/$name.err" || rc=$?
  echo "$rc" > "$out/$name.rc"
}

# ---------------------------------------------------------------- 0. precondition: the project's own suite is green
rc=0
(cd "$repo" && node --test) > "$out/node-test.txt" 2>&1 || rc=$?
echo "$rc" > "$out/node-test.rc"

# ---------------------------------------------------------------- 1. mechanical layers
sdd quotes lint --quotes --json
sdd accept accept --fase 1 --junit junit --junit-sha HEAD --no-out --json
sdd gate   gate --fase 1 --junit junit --junit-sha HEAD --json
sdd plan   lint --plan --json
sdd tasks  lint

# ---------------------------------------------------------------- 1b. second stage: the floor guard (5.3)
# D8: a later commit switches off the bound test of REQ-F-006 AC1 with test.skip (the suite stays green, the literal
# stays in the file, so only `lint --floor` sees it). D9: a docs commit lowers literal_gate from enforce to off.
(
  cd "$repo"
  node -e 'const fs=require("fs");const f="tests/api/confirmar.test.js";const t=fs.readFileSync(f,"utf8");const a="test(\"REQ-F-006 AC1";if(!t.includes(a))process.exit(1);fs.writeFileSync(f,t.replace(a,"test.skip(\"REQ-F-006 AC1"))'
  git add -A
  git commit -qm "test(cv): skip the flaky confirmation test" --trailer "Task: TASK-F1-099"
)
sdd floor lint --floor --base HEAD~1 --json
(
  cd "$repo"
  node -e 'const fs=require("fs");const t=fs.readFileSync("CLAUDE.md","utf8");if(!t.includes("- literal_gate: enforce\n"))process.exit(1);fs.writeFileSync("CLAUDE.md",t.replace("- literal_gate: enforce\n","- literal_gate: off\n"))'
  git add -A
  git commit -qm "docs: relax the literal gate"
)
sdd floor2 lint --floor --base HEAD~1 --json

# ---------------------------------------------------------------- 2. compare with the answer key
rc=0
node "$ROOT/tests/seeded/check.mjs" "$out" || rc=$?
if [ -n "$keep" ]; then echo "kept: $repo (raw outputs in $out)"; fi
exit "$rc"
