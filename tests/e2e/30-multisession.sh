#!/usr/bin/env bash
# B4 (pasos 1-4) — multi-sesión sin modelo: roles, worktree, estado común y lock, sobre una copia de examples/todo-app.
# El paso 5 (tmux + sesiones reales) está en docs/pruebas-manuales.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$ROOT/hooks"
fail=0; ok() { echo "ok   $1"; }; bad() { echo "FAIL $1"; fail=1; }
base="$(mktemp -d)"; trap 'rm -rf "$base"' EXIT
MAIN="$base/todo-app"; cp -R "$ROOT/examples/todo-app" "$MAIN"; cd "$MAIN"
git init -q -b main . && git config user.email e2e@example.com && git config user.name e2e && git add -A && git commit -qm "chore: toy" && git tag fase-0-verified

# setup mínimo (sin modelo): estado, hook git, gitignore, roles
sed -e "s/__SDD_VERSION__/test/" -e "s/__NOW__/2026-01-01T00:00:00Z/" "$ROOT/templates/pipeline-state.template.json" > pipeline-state.json
bash "$ROOT/scripts/install-git-hooks.sh" >/dev/null && ok "install-git-hooks" || bad "install-git-hooks"
bash "$ROOT/scripts/migrate-hooks-v3.sh" --gitignore-only >/dev/null 2>&1 || true
mkdir -p .claude/sdd && sed 's/example/todo/g' "$ROOT/templates/sdd-sessions.example.json" > .claude/sdd-sessions.json && cp "$ROOT/scripts/sdd-up.sh" .claude/sdd/
git add -A && git commit -qm "chore: sdd setup [skip-sdd]" >/dev/null

# 1. worktree + H1 con rol
WT="$base/todo-f1a"; git worktree add -q "$WT" -b feat/fase-1-a fase-0-verified
envf="$base/env.sh"; : > "$envf"
out=$(printf '{"session_id":"t","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$WT" | SDD_ROLE=impl-f1a CLAUDE_ENV_FILE="$envf" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$HOOKS/sdd-session-start.sh")
grep -q 'Rol: impl-f1a' <<<"$out" && ok "H1 muestra el rol desde el worktree" || bad "H1 rol: $out"
MAINP="$(cd "$MAIN" && pwd -P)"
grep -q "SDD_STATE_ROOT=\"$MAINP\"" "$envf" && ok "H1 exporta SDD_STATE_ROOT del principal" || bad "H1 SDD_STATE_ROOT: $(cat "$envf")"

# 2. H2 con rol: deny fuera de owns, allow dentro; sin rol = comportamiento 3.x
h2() { printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$WT" "$1" "$2" | env "${@:3}" bash "$HOOKS/sdd-upstream-guard.sh" 2>/dev/null || true; }
grep -q '"deny"' <<<"$(h2 Write "$WT/spec/x.md" SDD_ROLE=impl-f1a)" && ok "H2 deny spec/ con rol impl" || bad "H2 deny spec/"
grep -q '"deny"' <<<"$(h2 Write "$WT/src/x.ts" SDD_ROLE=impl-f1a)" && bad "H2 deniega src/ con rol impl" || ok "H2 allow src/ con rol impl"
grep -q '"deny"' <<<"$(h2 Write "$WT/src/x.ts")" && bad "H2 sin rol deniega src/" || ok "H2 sin rol = permisivo (3.x)"

# 3. H3 desde el worktree escribe en el principal
printf '{"session_id":"t","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/api/todo.ts"},"tool_response":{"success":true}}' "$WT" "$WT" | bash "$HOOKS/sdd-pipeline-state-updater.sh"
[ "$(jq -r '.stages["task-implementer"].status' "$MAIN/pipeline-state.json")" = "running" ] && ok "H3 marca running en el principal" || bad "H3 principal"
[ ! -f "$WT/pipeline-state.json" ] && ok "H3 no crea estado en el worktree" || bad "H3 creó pipeline-state.json en el worktree"

# 4. lock: 20 escrituras concurrentes
helper="$base/h3.sh"
printf '#!/usr/bin/env bash\nprintf %%s "{\\"session_id\\":\\"t\\",\\"cwd\\":\\"%s\\",\\"hook_event_name\\":\\"PostToolUse\\",\\"tool_name\\":\\"Write\\",\\"tool_input\\":{\\"file_path\\":\\"%s/src/f$1.ts\\"},\\"tool_response\\":{\\"success\\":true}}" | bash %q\n' "$WT" "$WT" "$HOOKS/sdd-pipeline-state-updater.sh" > "$helper"
seq 20 | xargs -P 8 -n 1 bash "$helper"
jq -e . "$MAIN/pipeline-state.json" >/dev/null && ok "estado JSON válido tras 20 escrituras concurrentes" || bad "estado corrupto"
[ ! -e "$MAIN/pipeline-state.json.lock" ] && ok "sin lock huérfano" || bad "lock huérfano"

# sdd-up.sh dry-run
up_out=$(cd "$MAIN" && bash .claude/sdd/sdd-up.sh --dry-run impl-f1a 2>&1 || true)
grep -q 'SDD_ROLE=impl-f1a' <<<"$up_out" && ok "sdd-up.sh --dry-run impl-f1a" || bad "sdd-up.sh dry-run: $up_out"

echo; [ "$fail" -eq 0 ] && echo "B4 (1-4): todo ok" || { echo "B4: hay fallos"; exit 1; }
