#!/usr/bin/env bash
# B3 — smoke del pipeline sobre examples/todo-app con el plugin cargado por --plugin-dir (usa el modelo: cuesta tokens y minutos).
# Uso: tests/e2e/20-smoke.sh [--until <stage>] [--keep]
#   --until: setup | specs | audit | test | plan | tasks | impl   (por defecto impl = FASE-0)
# Requiere sesión de Claude Code autenticada (usa el CLAUDE_CONFIG_DIR del usuario; el plugin NO se instala, solo --plugin-dir).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UNTIL="impl"; KEEP=""
while [ $# -gt 0 ]; do case "$1" in --until) UNTIL="$2"; shift 2;; --keep) KEEP=1; shift;; *) shift;; esac; done
command -v claude >/dev/null || { echo "claude CLI no disponible"; exit 2; }

WORK="$(mktemp -d)/todo-app"
cp -R "$ROOT/examples/todo-app" "$WORK" && cd "$WORK"
git init -q -b main . && git config user.email e2e@example.com && git config user.name e2e && git add -A && git commit -qm "chore: toy project"
[ -n "$KEEP" ] || trap 'rm -rf "$(dirname "$WORK")"' EXIT
echo "proyecto: $WORK"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
run() { # etapa, prompt
  echo; echo "== $1"; claude --plugin-dir "$ROOT" -p "$2" --output-format text 2>&1 | tail -15
}
manual_if_needed() { grep -q "AskUserQuestion\|necesito que\|please confirm" <<<"$1" && echo "MANUAL: la skill pidió intervención"; true; }

run setup "/sdd-setup — run non-interactively: accept all defaults, no status line, no multisession."
jq -e '.stages["requirements-engineer"]' pipeline-state.json >/dev/null && ok "pipeline-state.json creado" || bad "pipeline-state.json"
jq -e '.hooksVersion == 3' pipeline-state.json >/dev/null && ok "hooksVersion 3" || bad "hooksVersion"
[ -x "$(git rev-parse --git-path hooks)/commit-msg" ] && ok "commit-msg instalado" || bad "commit-msg"
git check-ignore -q pipeline-state.json .sdd/x .claude/worktrees/x && ok ".gitignore policy" || bad ".gitignore policy"
git commit -q --allow-empty -m "feat: sin trailer" 2>/dev/null && bad "commit-msg no rechaza feat sin trailer" || ok "commit-msg rechaza feat sin trailer"
[ "$UNTIL" = "setup" ] && { echo; echo "B3 (hasta setup): $([ $fail -eq 0 ] && echo ok || echo FALLOS)"; exit $fail; }

# requisitos ya escritos y aprobados: marcar la etapa como done sin ejecutar la skill
tmp=$(mktemp); jq '.stages["requirements-engineer"].status="done" | .stages["requirements-engineer"].lastRun=(now|todate) | .currentStage="specifications-engineer"' pipeline-state.json > "$tmp" && mv "$tmp" pipeline-state.json

run specs "/sdd-specifications-engineer — requirements/REQUIREMENTS.md is approved. Generate spec/ completely without asking questions; take the recommended option for any clarification and record it in spec/CLARIFICATIONS.md."
[ -d spec/use-cases ] && ok "spec/use-cases" || bad "spec/use-cases"
[ "$UNTIL" = "specs" ] && exit $fail
run audit "/sdd-spec-auditor — audit spec/ and apply Mode Fix for P0/P1 without asking; write audits/AUDIT-BASELINE.md."
[ -f audits/AUDIT-BASELINE.md ] && ok "AUDIT-BASELINE.md" || bad "AUDIT-BASELINE.md"
grep -qiE 'gate.*(PASS|CONDITIONAL)' audits/AUDIT-BASELINE.md && ok "gate PASS/CONDITIONAL" || echo "WARN gate no PASS (revisar)"
[ "$UNTIL" = "audit" ] && exit $fail
run test "/sdd-test-planner — generate test/ from spec/ without asking questions."
[ -f test/TEST-PLAN.md ] && ok "TEST-PLAN.md" || bad "TEST-PLAN.md"
[ "$UNTIL" = "test" ] && exit $fail
run plan "/sdd-plan-architect --skip-clarify — generate plan/ with FASE-0 (foundation) and FASE-1 split so that src/api and src/cli can be implemented independently."
[ -f plan/ARCHITECTURE.md ] && ok "ARCHITECTURE.md" || bad "ARCHITECTURE.md"
ls plan/fases/FASE-*.md >/dev/null 2>&1 && ok "plan/fases" || bad "plan/fases"
[ "$UNTIL" = "plan" ] && exit $fail
run tasks "/sdd-task-generator — generate task/ for all FASEs without asking questions."
[ -f task/TASK-ORDER.md ] && ok "TASK-ORDER.md" || bad "TASK-ORDER.md"
grep -q "## Stream Ownership" task/TASK-FASE-1.md 2>/dev/null && ok "Stream Ownership en TASK-FASE-1" || echo "WARN sin tabla Stream Ownership"
[ "$UNTIL" = "tasks" ] && exit $fail
run impl "/sdd-task-implementer --fase=0 — implement FASE-0 completely, test-first, one commit per task with Refs:/Task: trailers, without asking questions (take recommended options)."
[ "$(jq -r '.stages["task-implementer"].status' pipeline-state.json)" = "done" ] && ok "task-implementer done" || echo "WARN task-implementer no done: $(jq -r '.stages["task-implementer"].status' pipeline-state.json)"
n=$(git log --format=%B | grep -cE '^(Refs|Task):' || true); [ "$n" -ge 2 ] && ok "trailers Refs:/Task: ($n)" || bad "trailers"
git tag -l 'fase-0-verified' | grep -q . && ok "tag fase-0-verified" || echo "WARN sin tag fase-0-verified"
echo; echo "B3: $([ $fail -eq 0 ] && echo todo ok || echo hay fallos)"; exit $fail
