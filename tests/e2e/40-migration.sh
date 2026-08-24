#!/usr/bin/env bash
# Migración P3: proyecto con hooks v2 copiados (settings-template.json de sdd-skills v3.1.0) → migrate-hooks-v3.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
P="$(mktemp -d)"; trap 'rm -rf "$P"' EXIT
cd "$P" && git init -q -b main . && git config user.email e2e@example.com && git config user.name e2e
mkdir -p .claude/hooks .claude/agents
# plantilla v2 real desde la historia de sdd-skills (tag renombrado) — fallback a un settings mínimo equivalente
if ! git -C "$ROOT" show sdd-skills/v3.1.0:automation/settings-template.json > .claude/settings.json 2>/dev/null; then
  cat > .claude/settings.json <<'JSON'
{"statusLine":{"type":"command","command":"bash .claude/hooks/sdd-status-line.sh"},
 "hooks":{"SessionStart":[{"matcher":"startup|resume|compact","hooks":[{"type":"command","command":"bash .claude/hooks/sdd-session-start.sh","timeout":10}]}],
          "PreToolUse":[{"matcher":"Edit|Write","hooks":[{"type":"command","command":"bash .claude/hooks/sdd-upstream-guard.sh","timeout":5}]}],
          "PostToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"bash .claude/hooks/sdd-pipeline-state-updater.sh","timeout":10,"async":true}]}]}}
JSON
fi
for h in sdd-session-start sdd-upstream-guard sdd-pipeline-state-updater sdd-status-line; do echo '#!/bin/bash' > ".claude/hooks/$h.sh"; done
echo "---" > .claude/agents/sdd-context-keeper.md
echo '{"sddVersion":"2.4.0","hooksVersion":2,"currentStage":"requirements-engineer","stages":{}}' > pipeline-state.json
git add -A && git commit -qm "chore: v2 install" >/dev/null

bash "$ROOT/scripts/migrate-hooks-v3.sh" --dry-run >/dev/null 2>&1 && ok "dry-run ejecuta" || bad "dry-run"
[ -f .claude/hooks/sdd-upstream-guard.sh ] && ok "dry-run no borra hooks" || bad "dry-run borró hooks"
SDD_PLUGIN_ROOT="$ROOT" bash "$ROOT/scripts/migrate-hooks-v3.sh" >/dev/null 2>&1 && ok "migración aplicada" || bad "migración"
grep -q 'sdd-' <(jq -r '.hooks // {} | .. | .command? // empty' .claude/settings.json) && bad "quedan hooks sdd-* en settings.json" || ok "settings.json sin hooks sdd-*"
jq -e '.statusLine' .claude/settings.json >/dev/null && ok "statusLine conservada" || bad "statusLine perdida"
ls .claude/hooks/sdd-*.sh >/dev/null 2>&1 && bad "quedan .claude/hooks/sdd-*" || ok ".claude/hooks/sdd-* eliminados"
[ "$(jq -r .hooksVersion pipeline-state.json)" = "3" ] && ok "hooksVersion 3" || bad "hooksVersion: $(jq -r .hooksVersion pipeline-state.json)"
git check-ignore -q --no-index pipeline-state.json && ok "política .gitignore aplicada" || bad ".gitignore"
[ -x "$(git rev-parse --git-path hooks)/commit-msg" ] && ok "commit-msg reinstalado" || bad "commit-msg"
echo; [ "$fail" -eq 0 ] && echo "40-migration: todo ok" || { echo "40-migration: hay fallos"; exit 1; }
