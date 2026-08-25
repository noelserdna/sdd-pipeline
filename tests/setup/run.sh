#!/usr/bin/env bash
# Tests de sdd-setup: install-git-hooks.sh, política .gitignore, sdd-up.sh y migrate-hooks-v3.sh.
# Todo ocurre en un repo temporal; tmux y claude se sustituyen por shims que solo registran sus argumentos.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS="$ROOT/scripts"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# Aislamiento: sin config global de git, sin registro real de sesiones, sin 'claude plugin list'.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export CLAUDE_CONFIG_DIR="$tmp/claude-home"
export SDD_PLUGIN_ROOT="$ROOT"
mkdir -p "$CLAUDE_CONFIG_DIR/sessions"

# Shims de tmux y claude: registran las llamadas en $FAKE_LOG y no lanzan nada.
mkdir -p "$tmp/fakebin"
export FAKE_LOG="$tmp/fake.log"
cat > "$tmp/fakebin/tmux" <<'EOF'
#!/bin/sh
echo "tmux $*" >> "$FAKE_LOG"
case "$1" in
  -V) echo "tmux ${FAKE_TMUX_VER:-3.3a}" ;;
  has-session) [ "${FAKE_TMUX_BUSY:-0}" = "1" ] && exit 0; exit 1 ;;
esac
exit 0
EOF
printf '#!/bin/sh\necho "claude $*" >> "$FAKE_LOG"\n' > "$tmp/fakebin/claude"
chmod +x "$tmp/fakebin/tmux" "$tmp/fakebin/claude"
export PATH="$tmp/fakebin:$PATH"

# ── 1. Sintaxis ──────────────────────────────────────────────────────────────
for f in install-git-hooks.sh sdd-up.sh migrate-hooks-v3.sh; do check "bash -n $f" bash -n "$SCRIPTS/$f"; done

# ── 2. Plantillas ────────────────────────────────────────────────────────────
sed -e "s/__SDD_VERSION__/9.9.9/" -e "s/__NOW__/2026-01-01T00:00:00Z/" "$ROOT/templates/pipeline-state.template.json" > "$tmp/ps.json"
check "template pipeline-state: sddVersion, hooksVersion 3, 7 stages pending" \
  jq -e '.sddVersion == "9.9.9" and .hooksVersion == 3 and .currentStage == "requirements-engineer" and .lastUpdated == "2026-01-01T00:00:00Z" and (.stages | length) == 7 and ([.stages[] | .status] | all(. == "pending"))' "$tmp/ps.json"
check "template statusLine: type command, script .claude/sdd-status-line.sh" \
  jq -e '.statusLine.type == "command" and .statusLine.command == "bash .claude/sdd-status-line.sh"' "$ROOT/templates/settings.statusline.example.json"
check "template gitignore.sdd: marcadores" sh -c "grep -q '^# sdd-begin' '$ROOT/templates/gitignore.sdd' && grep -q '^# sdd-end' '$ROOT/templates/gitignore.sdd'"

# ── 3. Repo temporal ─────────────────────────────────────────────────────────
P="$tmp/my_Project"
mkdir -p "$P" && cd "$P"
git init -q
git config user.name test; git config user.email test@example.com; git config commit.gpgsign false
echo hi > README.md; git add README.md; git commit -q -m "chore: init"

# 3a. install-git-hooks: instala, idempotente, bloquea commits sin trailer
bash "$SCRIPTS/install-git-hooks.sh" >/dev/null
check "install: .git/hooks/commit-msg ejecutable" test -x .git/hooks/commit-msg
check "install: es el hook SDD" grep -q "SDD Commit Message Traceability Hook" .git/hooks/commit-msg
out="$(bash "$SCRIPTS/install-git-hooks.sh")"
if contains "$out" "already installed"; then pass "install: idempotente"; else bad "install: idempotente ($out)"; fi
echo a > a.txt; git add a.txt
if git commit -q -m "feat: sin trailer" >/dev/null 2>&1; then bad "commit feat sin trailer debería fallar"; else pass "commit feat sin trailer rechazado"; fi
if git commit -q -m "feat: con trailer" -m "Refs: REQ-001" >/dev/null 2>&1; then pass "commit feat con Refs: aceptado"; else bad "commit feat con Refs: rechazado"; fi
if git commit -q --allow-empty -m "docs: exento" >/dev/null 2>&1; then pass "commit docs sin trailer aceptado"; else bad "commit docs sin trailer rechazado"; fi

# 3b. uninstall, backup de hook ajeno y restauración
bash "$SCRIPTS/install-git-hooks.sh" --uninstall >/dev/null
check "uninstall: hook eliminado" test ! -e .git/hooks/commit-msg
printf '#!/bin/sh\n# foreign hook\nexit 0\n' > .git/hooks/commit-msg; chmod +x .git/hooks/commit-msg
bash "$SCRIPTS/install-git-hooks.sh" >/dev/null 2>&1
check "install: hook ajeno respaldado" sh -c 'ls .git/hooks/commit-msg.backup.* >/dev/null 2>&1'
check "install: hook SDD sustituye al ajeno" grep -q "SDD Commit" .git/hooks/commit-msg
bash "$SCRIPTS/install-git-hooks.sh" --uninstall >/dev/null
check "uninstall: restaura el hook ajeno" grep -q "foreign hook" .git/hooks/commit-msg
check "uninstall: backup consumido" sh -c '! ls .git/hooks/commit-msg.backup.* >/dev/null 2>&1'
out="$(bash "$SCRIPTS/install-git-hooks.sh" --uninstall 2>&1)"
if contains "$out" "not the SDD hook" && grep -q "foreign hook" .git/hooks/commit-msg; then pass "uninstall: no toca un hook ajeno"; else bad "uninstall: hook ajeno tocado ($out)"; fi
rm -f .git/hooks/commit-msg

# 3c. worktree enlazado → mismo hooks común
bash "$SCRIPTS/install-git-hooks.sh" >/dev/null
git worktree add -q "$tmp/wt" -b wt-branch >/dev/null 2>&1
out="$(bash "$SCRIPTS/install-git-hooks.sh" -C "$tmp/wt")"
if contains "$out" "already installed"; then pass "worktree: usa el hooks del git-common-dir"; else bad "worktree: $out"; fi
git worktree remove --force "$tmp/wt"

# 3d. core.hooksPath respetado
git config core.hooksPath .githooks
bash "$SCRIPTS/install-git-hooks.sh" >/dev/null
check "core.hooksPath: hook en .githooks/commit-msg" test -x .githooks/commit-msg
echo b > b.txt; git add b.txt
if git commit -q -m "fix: x" >/dev/null 2>&1; then bad "core.hooksPath: commit sin trailer debería fallar"; else pass "core.hooksPath: hook activo"; fi
git commit -q -m "fix: x" -m "Task: TASK-F0-001"
bash "$SCRIPTS/install-git-hooks.sh" --uninstall >/dev/null
git config --unset core.hooksPath; rm -rf .githooks

# ── 4. Política .gitignore ───────────────────────────────────────────────────
printf 'node_modules/\n' > .gitignore
bash "$SCRIPTS/migrate-hooks-v3.sh" --gitignore-only >/dev/null
sum1="$(cksum < .gitignore)"
bash "$SCRIPTS/migrate-hooks-v3.sh" --gitignore-only >/dev/null
sum2="$(cksum < .gitignore)"
if [ "$sum1" = "$sum2" ]; then pass "gitignore: idempotente (dos veces = mismo fichero)"; else bad "gitignore: cambia en la segunda pasada"; fi
check "gitignore: conserva el contenido previo" grep -q '^node_modules/' .gitignore
check "gitignore: un solo bloque" sh -c '[ "$(grep -c "^# sdd-begin" .gitignore)" = 1 ]'
for p in pipeline-state.json .sdd/x .claude/worktrees/x .claude/settings.local.json dashboard/traceability-graph.json; do
  check "gitignore: ignora $p" git check-ignore -q "$p"
done
check "gitignore: no ignora .claude/settings.json" sh -c '! git check-ignore -q .claude/settings.json'
# bloque desactualizado → se refresca sin duplicar
sed -i.bak '/^\.sdd\/$/d' .gitignore && rm -f .gitignore.bak
bash "$SCRIPTS/migrate-hooks-v3.sh" --gitignore-only >/dev/null
check "gitignore: bloque refrescado en su sitio" sh -c 'git check-ignore -q .sdd/x && [ "$(grep -c "^# sdd-begin" .gitignore)" = 1 ]'
rm .gitignore
bash "$SCRIPTS/migrate-hooks-v3.sh" --gitignore-only --dry-run >/dev/null
check "gitignore: --dry-run no escribe" test ! -e .gitignore
bash "$SCRIPTS/migrate-hooks-v3.sh" --gitignore-only >/dev/null
check "gitignore: se crea si no existe" git check-ignore -q pipeline-state.json
echo '{}' > pipeline-state.json; git add -f pipeline-state.json; git commit -q -m "chore: track state"
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" --gitignore-only 2>&1)"
if contains "$out" "git rm --cached pipeline-state.json"; then pass "gitignore: avisa si pipeline-state.json está trackeado"; else bad "gitignore: sin aviso de tracked ($out)"; fi
check "gitignore: no ejecuta git rm" git ls-files --error-unmatch pipeline-state.json
git rm -q --cached pipeline-state.json; git commit -q -m "chore: untrack state"; rm -f pipeline-state.json

# ── 5. sdd-up.sh ─────────────────────────────────────────────────────────────
mkdir -p .claude
cat > .claude/sdd-sessions.json <<'EOF'
{
  "project": "my-project",
  "roles": {
    "sdd-lead": { "name": "my-project-lead", "color": "blue", "owns": ["requirements/*"], "stages": ["requirements-engineer"] },
    "impl-f1a": { "name": "my-project-impl-f1a", "color": "red", "owns": ["src/*"], "stages": ["task-implementer"],
                  "fase": 1, "stream": "A", "worktree": "../my-project-f1a" }
  }
}
EOF
out="$(bash "$SCRIPTS/sdd-up.sh" --dry-run sdd-lead 2>&1)"
if contains "$out" "SDD_ROLE=sdd-lead"; then pass "sdd-up --dry-run: SDD_ROLE=sdd-lead"; else bad "sdd-up --dry-run: sin SDD_ROLE ($out)"; fi
if contains "$out" "SDD_STATE_ROOT=$P"; then pass "sdd-up --dry-run: SDD_STATE_ROOT = checkout principal"; else bad "sdd-up --dry-run: SDD_STATE_ROOT ($out)"; fi
if contains "$out" "tmux new-session -d -s my-project-lead -c $P -e SDD_ROLE=sdd-lead -e SDD_STATE_ROOT=$P 'claude -n my-project-lead'"; then pass "sdd-up --dry-run: comando tmux (>= 3.2, -e)"; else bad "sdd-up --dry-run: comando tmux ($out)"; fi
if contains "$out" "tmux send-keys -t my-project-lead:0.0 '/color blue' Enter"; then pass "sdd-up --dry-run: /color"; else bad "sdd-up --dry-run: /color ($out)"; fi
if contains "$out" "tmux attach -t =my-project-lead"; then pass "sdd-up --dry-run: instrucciones de conexión"; else bad "sdd-up --dry-run: sin instrucciones ($out)"; fi
check "sdd-up --dry-run: no lanza tmux" sh -c "! grep -q 'new-session' '$FAKE_LOG' 2>/dev/null"
out="$(FAKE_TMUX_VER=3.1c bash "$SCRIPTS/sdd-up.sh" --dry-run sdd-lead 2>&1)"
if contains "$out" "'env SDD_ROLE=sdd-lead SDD_STATE_ROOT='\\''$P'\\'' claude -n my-project-lead'"; then pass "sdd-up --dry-run: tmux < 3.2 usa env"; else bad "sdd-up --dry-run: tmux < 3.2 ($out)"; fi
out="$(bash "$SCRIPTS/sdd-up.sh" --dry-run impl-f1a 2>&1)"
if contains "$out" "git -C $P worktree add $tmp/my-project-f1a -b feat/fase-1-a HEAD" && contains "$out" "fase-1-foundation not found"; then pass "sdd-up --dry-run: worktree desde HEAD si no hay tag"; else bad "sdd-up --dry-run: worktree ($out)"; fi
check "sdd-up --dry-run: no crea el worktree" test ! -e "$tmp/my-project-f1a"
if bash "$SCRIPTS/sdd-up.sh" --dry-run nope >/dev/null 2>&1; then bad "sdd-up: rol desconocido debería fallar"; else pass "sdd-up: rol desconocido → exit 1"; fi
out="$(cd "$tmp" && bash "$SCRIPTS/sdd-up.sh" -d "$P" --dry-run sdd-lead 2>&1)"
if contains "$out" "SDD_STATE_ROOT=$P"; then pass "sdd-up -d DIR: localiza el checkout"; else bad "sdd-up -d DIR ($out)"; fi
# lanzamiento real contra los shims
rm -f "$FAKE_LOG"
bash "$SCRIPTS/sdd-up.sh" sdd-lead >/dev/null 2>&1
if grep -q "^tmux new-session -d -s my-project-lead -c $P -e SDD_ROLE=sdd-lead -e SDD_STATE_ROOT=$P claude -n my-project-lead$" "$FAKE_LOG" 2>/dev/null; then pass "sdd-up: new-session con -e"; else bad "sdd-up: new-session ($(cat "$FAKE_LOG" 2>/dev/null))"; fi
if grep -q "^tmux send-keys -t my-project-lead:0.0 /color blue Enter$" "$FAKE_LOG" 2>/dev/null; then pass "sdd-up: send-keys /color tras el arranque"; else bad "sdd-up: send-keys"; fi
git tag fase-1-foundation
bash "$SCRIPTS/sdd-up.sh" impl-f1a >/dev/null 2>&1
check "sdd-up: crea el worktree del rol" test -d "$tmp/my-project-f1a"
check "sdd-up: rama feat/fase-1-a desde fase-1-foundation" sh -c "[ \"\$(git -C '$tmp/my-project-f1a' branch --show-current)\" = feat/fase-1-a ]"
if grep -q "^tmux new-session -d -s my-project-impl-f1a -c $tmp/my-project-f1a " "$FAKE_LOG"; then pass "sdd-up: sesión en el worktree"; else bad "sdd-up: sesión del worktree"; fi
rm -f "$FAKE_LOG"
if FAKE_TMUX_BUSY=1 bash "$SCRIPTS/sdd-up.sh" sdd-lead >/dev/null 2>&1; then bad "sdd-up: sesión tmux existente debería abortar"; else pass "sdd-up: aborta si tmux has-session"; fi
check "sdd-up: no relanza con tmux ocupado" sh -c "! grep -q new-session '$FAKE_LOG' 2>/dev/null"
printf '{"pid":%s,"name":"my-project-lead","status":"idle","cwd":"%s"}\n' "$$" "$P" > "$CLAUDE_CONFIG_DIR/sessions/$$.json"
if out="$(bash "$SCRIPTS/sdd-up.sh" sdd-lead 2>&1)"; then bad "sdd-up: sesión viva en el registro debería abortar"; else
  if contains "$out" "live Claude session named 'my-project-lead'"; then pass "sdd-up: aborta si ~/.claude/sessions tiene el nombre con pid vivo"; else bad "sdd-up: registro ($out)"; fi
fi
printf '{"pid":4194303,"name":"my-project-lead","status":"idle"}\n' > "$CLAUDE_CONFIG_DIR/sessions/$$.json"
out="$(bash "$SCRIPTS/sdd-up.sh" --dry-run sdd-lead 2>&1)"
if contains "$out" "would abort"; then bad "sdd-up: pid muerto no debería bloquear"; else pass "sdd-up: ignora entradas del registro con pid muerto"; fi
rm -f "$CLAUDE_CONFIG_DIR/sessions/$$.json"
git worktree remove --force "$tmp/my-project-f1a"; git branch -q -D feat/fase-1-a; git tag -d fase-1-foundation >/dev/null

# ── 6. migrate-hooks-v3.sh ───────────────────────────────────────────────────
rm -f .gitignore .git/hooks/commit-msg
mkdir -p .claude/hooks .claude/agents
for h in sdd-session-start.sh sdd-upstream-guard.sh sdd-pipeline-state-updater.sh sdd-trace-map-updater.sh sdd-status-line.sh; do printf '#!/bin/bash\n' > ".claude/hooks/$h"; done
printf '// old\n' > .claude/hooks/sdd-augment-hook.js
printf '# old agent\n' > .claude/agents/sdd-cross-auditor.md
cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "SessionStart": [{ "matcher": "startup|resume|compact", "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-session-start.sh", "timeout": 10 }] }],
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-upstream-guard.sh", "timeout": 5 }] },
      { "matcher": "Read|Edit|Write|Grep|Glob", "hooks": [{ "type": "command", "command": "node .claude/hooks/sdd-augment-hook.js", "timeout": 5 }] }
    ],
    "PostToolUse": [
      { "matcher": "Write", "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-pipeline-state-updater.sh", "timeout": 10 }, { "type": "command", "command": "bash .claude/hooks/sdd-trace-map-updater.sh", "timeout": 10 }] }
    ],
    "Stop": [{ "hooks": [{ "type": "command", "command": "echo {}" }] }]
  },
  "statusLine": { "type": "command", "command": "bash .claude/hooks/sdd-status-line.sh" }
}
EOF
cat > pipeline-state.json <<'EOF'
{ "currentStage": "specifications-engineer", "lastUpdated": "2026-01-01T00:00:00Z",
  "stages": { "requirements-engineer": { "status": "done", "outputHash": "abc", "lastRun": "2026-01-01T00:00:00Z", "staleReason": null } } }
EOF
before="$(find .claude pipeline-state.json -type f -exec cksum {} + | sort)"
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" --dry-run 2>&1)"
for needle in "sdd-session-start.sh" "sdd-upstream-guard.sh" "sdd-augment-hook.js" "sdd-pipeline-state-updater.sh" "sdd-trace-map-updater.sh" ".claude/agents/sdd-cross-auditor.md" "statusLine points to .claude/hooks" "commit-msg hook missing" "pipeline-state.json: sddVersion=none hooksVersion=0" ".gitignore" "[DRY RUN]"; do
  if contains "$out" "$needle"; then pass "migrate --dry-run lista: $needle"; else bad "migrate --dry-run no lista: $needle"; fi
done
after="$(find .claude pipeline-state.json -type f -exec cksum {} + | sort)"
if [ "$before" = "$after" ] && [ ! -e .gitignore ] && [ ! -e .git/hooks/commit-msg ] && [ ! -d .claude/backups ]; then pass "migrate --dry-run: no toca nada"; else bad "migrate --dry-run: modificó ficheros"; fi

out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" 2>&1)"
check "migrate: settings.json solo conserva statusLine" jq -e 'keys == ["statusLine"]' .claude/settings.json
check "migrate: statusLine apunta a .claude/sdd-status-line.sh" jq -e '.statusLine.command == "bash .claude/sdd-status-line.sh"' .claude/settings.json
check "migrate: .claude/sdd-status-line.sh copiado del plugin" cmp -s .claude/sdd-status-line.sh "$ROOT/scripts/sdd-status-line.sh"
check "migrate: .claude/sdd-status-line.sh ejecutable" test -x .claude/sdd-status-line.sh
check "migrate: hooks copiados eliminados" sh -c '! ls .claude/hooks/sdd-* >/dev/null 2>&1'
check "migrate: agentes copiados eliminados" test ! -e .claude/agents/sdd-cross-auditor.md
check "migrate: commit-msg reinstalado" grep -q "SDD Commit" .git/hooks/commit-msg
PLUGIN_VERSION="$(jq -r .version "$ROOT/.claude-plugin/plugin.json")"
check "migrate: pipeline-state sddVersion=$PLUGIN_VERSION hooksVersion=3" jq -e --arg v "$PLUGIN_VERSION" '.sddVersion == $v and .hooksVersion == 3' pipeline-state.json
check "migrate: pipeline-state conserva los stages" jq -e '.stages["requirements-engineer"].status == "done" and .currentStage == "specifications-engineer"' pipeline-state.json
check "migrate: política .gitignore aplicada" git check-ignore -q pipeline-state.json
check "migrate: backup de settings.json" sh -c 'ls .claude/backups/sdd-v3-*/settings.json >/dev/null 2>&1'
check "migrate: backup de los hooks antiguos" sh -c 'ls .claude/backups/sdd-v3-*/hooks/sdd-session-start.sh >/dev/null 2>&1'
if contains "$out" "Migration complete"; then pass "migrate: resumen final"; else bad "migrate: sin resumen ($out)"; fi
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" 2>&1)"
if contains "$out" "Nothing to migrate"; then pass "migrate: segunda pasada sin cambios (idempotente)"; else bad "migrate: segunda pasada ($out)"; fi

# 6b. conserva hooks y ajustes ajenos
cat > .claude/settings.json <<'EOF'
{
  "permissions": { "allow": ["Bash(git status:*)"] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-upstream-guard.sh" }, { "type": "command", "command": "echo user-hook" }] }
    ],
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-session-start.sh" }] }],
    "Stop": [{ "hooks": [{ "type": "prompt", "prompt": "quality gate", "timeout": 30 }] }]
  },
  "statusLine": { "type": "command", "command": "bash .claude/sdd-status-line.sh" }
}
EOF
bash "$SCRIPTS/migrate-hooks-v3.sh" >/dev/null 2>&1
check "migrate: conserva permissions" jq -e '.permissions.allow == ["Bash(git status:*)"]' .claude/settings.json
check "migrate: conserva el hook del usuario" jq -e '.hooks.PreToolUse | length == 1 and .[0].hooks == [{"type":"command","command":"echo user-hook"}]' .claude/settings.json
check "migrate: elimina el evento vacío" jq -e '.hooks.SessionStart == null' .claude/settings.json
check "migrate: conserva el quality gate (prompt)" jq -e '.hooks.Stop[0].hooks[0].type == "prompt"' .claude/settings.json

# 6c. fallback node: PATH mínimo sin jq (symlinks a las herramientas que usan los scripts)
mkdir -p "$tmp/minbin"
for t in bash sh git sed awk grep cmp mv cp rm mkdir rmdir date dirname basename cat tail ls sort tr chmod node; do
  bin="$(command -v "$t" 2>/dev/null || true)"; [ -n "$bin" ] && ln -sf "$bin" "$tmp/minbin/$t"
done
if [ -x "$tmp/minbin/node" ] && ! PATH="$tmp/minbin" bash -c 'command -v jq' >/dev/null 2>&1; then
  cat > .claude/settings.json <<'EOF'
{ "hooks": { "PreToolUse": [{ "matcher": "Write", "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-upstream-guard.sh" }] }] },
  "statusLine": { "type": "command", "command": "bash .claude/hooks/sdd-status-line.sh" } }
EOF
  printf '{"currentStage":"requirements-engineer","stages":{}}\n' > pipeline-state.json
  printf '#!/bin/bash\n' > .claude/hooks-old.sh; mkdir -p .claude/hooks; printf '#!/bin/bash\n' > .claude/hooks/sdd-upstream-guard.sh
  PATH="$tmp/fakebin:$tmp/minbin" bash "$SCRIPTS/migrate-hooks-v3.sh" >/dev/null 2>&1 || true
  check "migrate (node): settings solo statusLine" jq -e 'keys == ["statusLine"] and .statusLine.command == "bash .claude/sdd-status-line.sh"' .claude/settings.json
  check "migrate (node): pipeline-state versionado" jq -e '.hooksVersion == 3' pipeline-state.json
  check "migrate (node): hook antiguo borrado" test ! -e .claude/hooks/sdd-upstream-guard.sh
  rm -f .claude/hooks-old.sh
else
  echo "skip migrate (node): no se pudo construir un PATH sin jq"
fi

# 6d. sin ficheros que migrar en un proyecto nuevo → no-op
D="$tmp/fresh"; mkdir -p "$D"; cd "$D"; git init -q
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" --dry-run 2>&1)"
if contains "$out" "commit-msg" && contains "$out" ".gitignore" && ! contains "$out" "settings.json hooks"; then pass "migrate: proyecto nuevo solo propone commit-msg y .gitignore"; else bad "migrate: proyecto nuevo ($out)"; fi
check "migrate: dry-run en proyecto nuevo no escribe" sh -c '[ ! -e .gitignore ] && [ ! -e .git/hooks/commit-msg ]'

cd "$ROOT"
[ "$fail" -eq 0 ] && echo "tests/setup: todo ok" || { echo "tests/setup: hay fallos"; exit 1; }
