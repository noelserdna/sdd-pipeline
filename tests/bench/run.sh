#!/usr/bin/env bash
# Tests de scripts/sdd-bench.sh: events.jsonl sintético + repo git con 3 commits con trailers y tag fase-1-verified.
# Comprueba la tabla (tasks=3, streams=2, conflictos=1), el fichero BENCH-FASE-1.md, la igualdad jq/node y el
# fallback a git cuando no hay eventos. Compatible con bash 3.2; requiere git, jq y node.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH="$ROOT/scripts/sdd-bench.sh"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
unset SDD_STATE_ROOT SDD_BENCH_JSON || true
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

check_syntax() { bash -n "$BENCH" && bash -n "$0"; }
check_syntax && pass "bash -n" || bad "bash -n"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning "$BENCH" "$0" && pass "shellcheck" || bad "shellcheck"
fi

# ── repo: 3 task commits (10:00, 10:20, 10:40) + tag fase-1-verified (11:00) ─────────────────
repo="$tmp/repo"; mkdir -p "$repo"; cd "$repo"
git init -q .
GIT_AUTHOR_DATE=2026-08-24T09:50:00Z GIT_COMMITTER_DATE=2026-08-24T09:50:00Z git commit -q --allow-empty -m "chore: init"
commit_task() { # commit_task SEQ TIME FILE
  printf 'x\n' > "$3"; git add "$3"
  GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git commit -q -m "feat(t): task $1

Refs: FASE-1, UC-001
Task: TASK-F1-$1"
}
commit_task 001 2026-08-24T10:00:00Z a.txt
commit_task 002 2026-08-24T10:20:00Z b.txt
commit_task 003 2026-08-24T10:40:00Z c.txt
GIT_COMMITTER_DATE=2026-08-24T11:00:00Z git tag -a fase-1-verified -m "FASE-1 verified"
sha1="$(git log --format=%h --grep='Task: TASK-F1-001' | head -n 1)"
sha2="$(git log --format=%h --grep='Task: TASK-F1-002' | head -n 1)"
sha3="$(git log --format=%h --grep='Task: TASK-F1-003' | head -n 1)"

# ── events: 2 Streams (A, B), 1 PAUSE (impl-f1b), 2 merges, 1 conflict, verified 11:30 ──────
mkdir -p .sdd/bench
cat > .sdd/bench/events.jsonl <<EVT
{"ts":"2026-08-24T10:00:00Z","role":"impl-f1a","fase":1,"stream":"A","event":"task-start","task":"TASK-F1-001","sha":""}
{"ts":"2026-08-24T10:05:00Z","role":"impl-f1a","fase":1,"stream":"A","event":"task-commit","task":"TASK-F1-001","sha":"$sha1"}
{"ts":"2026-08-24T10:10:00Z","role":"impl-f1b","fase":1,"stream":"B","event":"task-start","task":"TASK-F1-002","sha":""}
{"ts":"2026-08-24T10:12:00Z","role":"impl-f1b","fase":1,"stream":"B","event":"pause","task":"TASK-F1-002","sha":""}

{"ts":"2026-08-24T10:20:00Z","role":"impl-f1b","fase":1,"stream":"B","event":"task-commit","task":"TASK-F1-002","sha":"$sha2"}
{"ts":"2026-08-24T10:25:00Z","role":"impl-f1a","fase":1,"stream":"A","event":"task-start","task":"TASK-F1-003","sha":""}
{"ts":"2026-08-24T10:40:00Z","role":"impl-f1a","fase":1,"stream":"A","event":"task-commit","task":"TASK-F1-003","sha":"$sha3"}
{"ts":"2026-08-24T10:40:00Z","role":"impl-f1a","fase":1,"stream":"A","event":"task-commit","task":"TASK-F1-003","sha":"$sha3"}
{"ts":"2026-08-24T10:50:00Z","role":"sdd-lead","fase":1,"stream":"-","event":"merge","task":"","sha":"aaaaaaa"}
{"ts":"2026-08-24T10:55:00Z","role":"sdd-lead","fase":1,"stream":"-","event":"merge-conflict","task":"","sha":"","file":"task/TASK-FASE-1.md"}
not json at all
{"ts":"2026-08-24T10:58:00Z","role":"sdd-lead","fase":1,"stream":"-","event":"merge","task":"","sha":"bbbbbbb"}
{"ts":"2026-08-24T11:30:00Z","role":"sdd-lead","fase":1,"stream":"-","event":"fase-verified","task":"","sha":"$sha3"}
EVT
cd "$tmp"

expected='| 1 | worktrees | 2 | 1h 30m | 3 | 3 | 2 | 1 | 1 (impl-f1b:1) | 2.0 |'

# 1. jq engine, --fase 1
out="$(SDD_BENCH_JSON=jq bash "$BENCH" --fase 1 --root "$repo")"
contains "$out" "$expected" && pass "tabla FASE-1 (jq): $expected" || bad "tabla FASE-1 (jq):
$out"
contains "$out" "| FASE | modo | streams | wall | tasks | commits | merges | conflictos | PAUSE | tasks/h |" && pass "cabecera" || bad "cabecera"
contains "$out" "streams A, B" && pass "nombres de streams en las notas" || bad "nombres de streams"
contains "$out" "conflicts: task/TASK-FASE-1.md" && pass "fichero en conflicto en las notas" || bad "fichero en conflicto"
contains "$out" "2026-08-24T10:00:00Z → 2026-08-24T11:30:00Z (events)" && pass "wall desde eventos" || bad "wall desde eventos: $out"
[ -f "$repo/.sdd/bench/BENCH-FASE-1.md" ] && pass "BENCH-FASE-1.md guardado" || bad "BENCH-FASE-1.md no existe"
if [ -f "$repo/.sdd/bench/BENCH-FASE-1.md" ]; then
  contains "$(cat "$repo/.sdd/bench/BENCH-FASE-1.md")" "$expected" && pass "BENCH-FASE-1.md contiene la fila" || bad "BENCH-FASE-1.md sin la fila"
  contains "$(cat "$repo/.sdd/bench/BENCH-FASE-1.md")" "task/TASK-FASE-1.md" && pass "BENCH-FASE-1.md lista el conflicto" || bad "BENCH-FASE-1.md sin conflicto"
fi

# 2. node engine gives the same table
out_node="$(SDD_BENCH_JSON=node bash "$BENCH" --fase 1 --root "$repo" --no-save)"
out_jq="$(SDD_BENCH_JSON=jq bash "$BENCH" --fase 1 --root "$repo" --no-save)"
[ "$out_node" = "$out_jq" ] && pass "jq y node producen la misma salida" || bad "jq/node difieren:
--- jq
$out_jq
--- node
$out_node"

# 3. without --fase: same single FASE; --root from cwd; SDD_STATE_ROOT honoured
out="$(cd "$repo" && bash "$BENCH" --no-save)"
contains "$out" "$expected" && pass "sin --fase, root desde el cwd" || bad "sin --fase: $out"
out="$(SDD_STATE_ROOT="$repo" bash "$BENCH" --no-save)"
contains "$out" "$expected" && pass "SDD_STATE_ROOT como root" || bad "SDD_STATE_ROOT: $out"

# 4. git fallback: no events → subagentes, wall 10:00 → 11:00 from trailers/tag, tasks/commits from trailers
mv "$repo/.sdd/bench/events.jsonl" "$repo/.sdd/bench/events.bak"
out="$(bash "$BENCH" --fase 1 --root "$repo" --no-save)"
exp_git='| 1 | subagentes | 0 | 1h 00m | 3 | 3 | 0 | 0 | 0 | 3.0 |'
contains "$out" "$exp_git" && pass "fallback git: $exp_git" || bad "fallback git:
$out"
contains "$out" "(git)" && pass "wall marcado como (git)" || bad "wall no marcado como git"
mv "$repo/.sdd/bench/events.bak" "$repo/.sdd/bench/events.jsonl"

# 5. --fase without data → exit 1; unknown flag → exit 2; no git and no events → exit 1
rc=0; bash "$BENCH" --fase 7 --root "$repo" --no-save >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] && pass "--fase 7 sin datos → exit 1" || bad "--fase 7 sin datos → exit $rc"
rc=0; bash "$BENCH" --bogus >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && pass "flag desconocido → exit 2" || bad "flag desconocido → exit $rc"
empty="$tmp/empty"; mkdir -p "$empty"
rc=0; bash "$BENCH" --root "$empty" --no-save >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 1 ] && pass "sin git ni eventos → exit 1" || bad "sin git ni eventos → exit $rc"

# 6. read-only: the repo has no new tracked changes and events.jsonl is untouched
[ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ] && pass "el repo no cambia" || bad "el repo cambió"
[ "$(grep -c . "$repo/.sdd/bench/events.jsonl")" -eq 13 ] && pass "events.jsonl intacto" || bad "events.jsonl modificado"

echo
[ "$fail" -eq 0 ] && { echo "tests/bench: todo ok"; } || { echo "tests/bench: hay fallos"; exit 1; }
