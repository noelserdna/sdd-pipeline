#!/usr/bin/env bash
# B4 paso 5 (automatizado con modelo) — FASE N por Streams en dos worktrees con roles, y reintegración.
# Uso: tests/e2e/50-streams.sh --dir <proyecto con fase-(N-1)-verified y task/TASK-FASE-N.md> [--fase N]
# Flujo: --stream base (principal, tag fase-N-foundation) → worktrees feat/fase-N-a|b → --stream A ∥ --stream B (paralelo,
#        SDD_ROLE impl-fNa/impl-fNb) → --integrate --fase N (principal) → sdd-bench.sh --fase N
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR=""; N=1
while [ $# -gt 0 ]; do case "$1" in --dir) DIR="$2"; shift 2;; --fase) N="$2"; shift 2;; *) shift;; esac; done
[ -n "$DIR" ] || { echo "uso: $0 --dir <proyecto> [--fase N]"; exit 2; }
command -v claude >/dev/null || { echo "claude CLI no disponible"; exit 2; }
cd "$DIR"; DIR="$(pwd -P)"; PARENT="$(dirname "$DIR")"; SLUG="$(basename "$DIR")"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
t0=$(date +%s); lap() { local now; now=$(date +%s); echo "     [$1: $(( (now - t0) / 60 )) min]"; t0=$now; }
PREV=$((N-1))
git tag -l "fase-$PREV-verified" | grep -q . || { echo "falta el tag fase-$PREV-verified"; exit 2; }
grep -q '^## Stream Ownership' "task/TASK-FASE-$N.md" || { echo "falta Stream Ownership en task/TASK-FASE-$N.md"; exit 2; }
echo "proyecto: $DIR · FASE $N"

# roles: sdd-sessions.json con impl-fNa / impl-fNb (worktrees hermanos)
mkdir -p .claude/sdd
sed "s/example/$SLUG/g" "$ROOT/templates/sdd-sessions.example.json" > .claude/sdd-sessions.json
tmp=$(mktemp); jq --arg n "$N" --arg s "$SLUG" '
  .roles["impl-f\($n)a"] = (.roles["impl-f1a"] | .name = "\($s)-impl-f\($n)a" | .fase = ($n|tonumber) | .stream = "A" | .worktree = "../\($s)-f\($n)a") |
  .roles["impl-f\($n)b"] = (.roles["impl-f\($n)a"] | .name = "\($s)-impl-f\($n)b" | .stream = "B" | .worktree = "../\($s)-f\($n)b" | .color = "orange") |
  del(.roles["impl-f1a"] | select("\($n)" != "1"))' .claude/sdd-sessions.json > "$tmp" && mv "$tmp" .claude/sdd-sessions.json
jq -e ".roles[\"impl-f${N}a\"] and .roles[\"impl-f${N}b\"]" .claude/sdd-sessions.json >/dev/null && ok "roles impl-f${N}a / impl-f${N}b en .claude/sdd-sessions.json" || bad "sdd-sessions.json"
git add .claude/sdd-sessions.json && git commit -qm "chore(sdd): multi-session roles for FASE-$N [skip-sdd]" && ok "roles commiteados"

run() { # etiqueta, dir, rol, prompt
  echo; echo "== $1"; ( cd "$2" && SDD_ROLE="$3" SDD_STATE_ROOT="$DIR" claude --plugin-dir "$ROOT" -p "$4" --output-format text 2>&1 | tail -12 ); lap "$1"; }

# 1. base en el principal
run "base" "$DIR" "sdd-lead" "/sdd-task-implementer --fase=$N --stream base — implement the base Stream of FASE-$N in the main checkout (it may be empty), place the checkpoint tag fase-$N-foundation and stop. Do not implement Stream A or B. Without asking questions."
if ! git tag -l "fase-$N-foundation" | grep -q .; then echo "WARN la skill no creó fase-$N-foundation; se crea sobre fase-$PREV-verified"; git tag "fase-$N-foundation" "fase-$PREV-verified"; fi
ok "tag fase-$N-foundation en $(git rev-parse --short "fase-$N-foundation")"

# 2. worktrees
WA="$PARENT/$SLUG-f${N}a"; WB="$PARENT/$SLUG-f${N}b"
for w in "$WA" "$WB"; do [ -d "$w" ] && { git worktree remove --force "$w" 2>/dev/null || rm -rf "$w"; }; done
git branch -D "feat/fase-$N-a" "feat/fase-$N-b" 2>/dev/null || true
git worktree add -q "$WA" -b "feat/fase-$N-a" "fase-$N-foundation" && git worktree add -q "$WB" -b "feat/fase-$N-b" "fase-$N-foundation" && ok "worktrees $WA y $WB desde fase-$N-foundation"

# 3. Streams A y B en paralelo
LA="$DIR/.sdd/stream-A.log"; LB="$DIR/.sdd/stream-B.log"; mkdir -p "$DIR/.sdd"
echo; echo "== streams A ∥ B (paralelo)"
( cd "$WA" && SDD_ROLE="impl-f${N}a" SDD_STATE_ROOT="$DIR" claude --plugin-dir "$ROOT" -p "/sdd-task-implementer --fase=$N --stream A — you are in the worktree feat/fase-$N-a. Implement ONLY the Stream A tasks of FASE-$N, test-first, one commit per task with Refs:/Task: trailers, no tags, finish with Phase 9-S (Stream Complete). Without asking questions; take recommended options." --output-format text > "$LA" 2>&1 ) & pa=$!
( cd "$WB" && SDD_ROLE="impl-f${N}b" SDD_STATE_ROOT="$DIR" claude --plugin-dir "$ROOT" -p "/sdd-task-implementer --fase=$N --stream B — you are in the worktree feat/fase-$N-b. Implement ONLY the Stream B tasks of FASE-$N, test-first, one commit per task with Refs:/Task: trailers, no tags, finish with Phase 9-S (Stream Complete). Without asking questions; take recommended options." --output-format text > "$LB" 2>&1 ) & pb=$!
wait $pa || echo "WARN stream A terminó con error"; echo "-- A --"; tail -6 "$LA"; wait $pb || echo "WARN stream B terminó con error"; echo "-- B --"; tail -6 "$LB"; lap "streams"
for s in A B; do
  w="$WA"; [ "$s" = "B" ] && w="$WB"
  n=$(git -C "$w" log "fase-$N-foundation..HEAD" --format=%B | grep -c "^Task: TASK-F$N-" || true)
  [ "$n" -gt 0 ] && ok "stream $s: $n commits con Task:" || bad "stream $s sin commits con Task:"
  x=$(grep -c '^- \[x\] TASK-' "$w/task/TASK-FASE-$N.md" || true); echo "     stream $s: $x tasks marcadas en su worktree"
  git -C "$w" tag -l "fase-$N-*" | grep -qv "fase-$N-foundation" && bad "stream $s creó tags" || ok "stream $s no creó tags"
done
jq -e . pipeline-state.json >/dev/null && ok "pipeline-state.json válido tras dos streams concurrentes" || bad "pipeline-state.json corrupto"
[ ! -e pipeline-state.json.lock ] && ok "sin lock huérfano" || bad "lock huérfano"

# 4. integrar en el principal
run "integrate" "$DIR" "sdd-lead" "/sdd-task-implementer --integrate --fase $N — merge feat/fase-$N-a and feat/fase-$N-b with --no-ff, run the integración and verificación tasks, verify, tag fase-$N-verified, persist summary. Without asking questions; take recommended options. If a merge conflict appears, resolve it keeping both [x] marks in task/TASK-FASE-$N.md."
for b in "feat/fase-$N-a" "feat/fase-$N-b"; do git branch --merged HEAD | grep -q "$b" && ok "$b integrada" || bad "$b no integrada"; done
[ "$(grep -c '^- \[x\] TASK-' "task/TASK-FASE-$N.md")" = "$(grep -c '^- \[[ x]\] TASK-' "task/TASK-FASE-$N.md")" ] && ok "todas las tasks de FASE-$N marcadas" || echo "WARN quedan tasks sin marcar: $(grep -c '^- \[ \] TASK-' "task/TASK-FASE-$N.md")"
dup=$(git log HEAD --format='%(trailers:key=Task,valueonly)' | sed '/^$/d' | sort | uniq -d | wc -l | tr -d ' '); [ "$dup" = "0" ] && ok "sin Task: duplicados" || bad "$dup Task: duplicados"
git tag -l "fase-$N-verified" | grep -q . && ok "tag fase-$N-verified" || echo "WARN sin tag fase-$N-verified"
(npm test --silent 2>&1 | tail -3) || echo "WARN npm test falló"
echo; echo "== bench"; bash "$ROOT/scripts/sdd-bench.sh" --fase "$N" --root "$DIR" 2>&1 | tail -8
echo; echo "50-streams: $([ $fail -eq 0 ] && echo todo ok || echo hay fallos)"; exit $fail
