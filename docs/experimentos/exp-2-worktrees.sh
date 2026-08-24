#!/usr/bin/env bash
# Experimento (riesgo 5 del plan): ¿conflictúa task/TASK-FASE-1.md cuando dos Streams marcan [x] tasks distintas
# en ramas paralelas y se integran con merge --no-ff? Genera un TASK-FASE-1.md realista (bloques de 7 líneas por task),
# dos ramas que marcan tasks alternas (una por commit) y hace N rondas de merge. Imprime conflictos por ronda.
set -euo pipefail
ROUNDS="${1:-5}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp" && git init -q -b main . && git config user.email exp@example.com && git config user.name exp
mkdir -p task
{
  echo "# TASK-FASE-1"; echo
  for i in $(seq 1 $((ROUNDS * 2))); do
    printf -- '- [ ] TASK-F1-%03d [P] Task %d | `src/mod%d.ts`\n' "$i" "$i" "$i"
    echo '  - **Commit:** `feat(mod): task`'
    echo '  - **Acceptance:** works'
    echo '  - **Refs:** FASE-1, UC-001'
    echo '  - **Revert:** SAFE'
    echo '  - **Review:** [ ] a [ ] b'
    echo
  done
} > task/TASK-FASE-1.md
git add -A && git commit -qm "chore: tasks"
git branch feat/fase-1-a && git branch feat/fase-1-b
mark() { # rama, task
  git checkout -q "$1"
  sed -i.bak "s/^- \[ \] TASK-F1-$(printf '%03d' "$2")/- [x] TASK-F1-$(printf '%03d' "$2")/" task/TASK-FASE-1.md && rm task/TASK-FASE-1.md.bak
  git commit -qam "feat: task $2"
}
conflicts=0
for r in $(seq 1 "$ROUNDS"); do
  mark feat/fase-1-a $((2*r-1))
  mark feat/fase-1-b $((2*r))
  git checkout -q main
  for b in feat/fase-1-a feat/fase-1-b; do
    if git merge -q --no-ff "$b" -m "Merge $b (round $r)" >/dev/null 2>&1; then
      echo "ronda $r · merge $b: limpio"
    else
      conflicts=$((conflicts+1)); echo "ronda $r · merge $b: CONFLICTO"; git merge --abort
    fi
  done
done
marked=$(grep -c '^- \[x\]' task/TASK-FASE-1.md || true)
echo "resultado: $conflicts conflictos en $((ROUNDS*2)) merges; tasks marcadas en main: $marked/$((ROUNDS*2))"
