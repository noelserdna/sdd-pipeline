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

# Variables heredadas de una sesión de Claude Code con el plugin activo (SDD_STATE_ROOT apunta a OTRO checkout
# y rompe sdd-up.sh / migrate-hooks-v3.sh): fuera antes de nada.
unset SDD_STATE_ROOT SDD_PLUGIN_ROOT SDD_ROLE CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true

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
check "template pipeline-state: sddVersion, hooksVersion 3, 7 stages pending, route null" \
  jq -e '.sddVersion == "9.9.9" and .hooksVersion == 3 and .currentStage == "requirements-engineer" and .lastUpdated == "2026-01-01T00:00:00Z" and (.stages | length) == 7 and ([.stages[] | .status] | all(. == "pending")) and has("route") and .route == null' "$tmp/ps.json"
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
check "install: vendoriza .claude/sdd/sdd.mjs y lib/git-log.mjs" sh -c 'grep -q "Vendored by sdd-pipeline" .claude/sdd/sdd.mjs && test -f .claude/sdd/lib/git-log.mjs'
check "install: el sdd.mjs vendorizado funciona" node .claude/sdd/sdd.mjs branch status
if git commit -q -m "feat: solo refs" -m "Refs: REQ-001" >/dev/null 2>&1; then bad "commit feat con solo Refs: debería fallar (feat exige Task)"; else pass "commit feat con solo Refs: rechazado"; fi
if git commit -q -m "feat: con trailer" --trailer "Task: TASK-F1-001" --trailer "Refs: REQ-001" >/dev/null 2>&1; then pass "commit feat con --trailer Task/Refs aceptado"; else bad "commit feat con --trailer Task/Refs rechazado"; fi
printf '%s\n' "// local edit" >> .claude/sdd/sdd.mjs
bash "$SCRIPTS/install-git-hooks.sh" >/dev/null
check "install: re-instalar sobrescribe la copia vendorizada" sh -c '! grep -q "// local edit" .claude/sdd/sdd.mjs'
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
# worktree por defecto dentro del proyecto (.claude/worktrees/<rol>): hereda la confianza de carpeta
tmpj="$(mktemp)"; jq '.roles["impl-f1b"] = (.roles["impl-f1a"] | .name="my-project-impl-f1b" | .stream="B" | .worktree=".claude/worktrees/impl-f1b")' .claude/sdd-sessions.json > "$tmpj" && mv "$tmpj" .claude/sdd-sessions.json
out2="$(bash "$SCRIPTS/sdd-up.sh" --dry-run impl-f1b 2>&1)"
if contains "$out2" "worktree add $P/.claude/worktrees/impl-f1b -b feat/fase-1-b"; then pass "sdd-up: worktree por defecto en .claude/worktrees/<rol>"; else bad "sdd-up: worktree interno ($out2)"; fi
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
printf '# old agent\n' > .claude/agents/sdd-legacy-agent.md
# 4.x: status lines copiadas al proyecto y ficheros de los hooks retirados (trace-map, activity log)
printf '#!/bin/bash\n' > .claude/sdd-status-line.sh; printf '#!/bin/bash\n' > .claude/sdd-subagent-status.sh
mkdir -p .sdd; printf '{}\n' > .sdd/current-task.json; printf '{}\n' > .sdd/trace-map.json
printf '{}\n' > .sdd/activity.jsonl; printf '{}\n' > .sdd/activity.1.jsonl; printf 'Q\n' > .sdd/questions-sdd-spec.md
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
  "statusLine": { "type": "command", "command": "bash .claude/hooks/sdd-status-line.sh" },
  "subagentStatusLine": { "type": "command", "command": "bash .claude/sdd-subagent-status.sh" }
}
EOF
cat > pipeline-state.json <<'EOF'
{ "currentStage": "specifications-engineer", "lastUpdated": "2026-01-01T00:00:00Z",
  "stages": { "requirements-engineer": { "status": "done", "outputHash": "abc", "lastRun": "2026-01-01T00:00:00Z", "staleReason": null } } }
EOF
before="$(find .claude .sdd pipeline-state.json -type f -exec cksum {} + | sort)"
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" --dry-run 2>&1)"
for needle in "sdd-session-start.sh" "sdd-upstream-guard.sh" "sdd-augment-hook.js" "sdd-pipeline-state-updater.sh" "sdd-trace-map-updater.sh" ".claude/agents/sdd-legacy-agent.md" ".claude/sdd-status-line.sh" ".claude/sdd-subagent-status.sh" ".sdd/current-task.json" ".sdd/trace-map.json" ".sdd/activity.jsonl" ".sdd/activity.1.jsonl" "statusLine runs a legacy SDD status line" "subagentStatusLine runs a legacy SDD script" "commit-msg hook missing" "pipeline-state.json: sddVersion=none hooksVersion=0" ".gitignore" "[DRY RUN]"; do
  if contains "$out" "$needle"; then pass "migrate --dry-run lista: $needle"; else bad "migrate --dry-run no lista: $needle"; fi
done
after="$(find .claude .sdd pipeline-state.json -type f -exec cksum {} + | sort)"
if [ "$before" = "$after" ] && [ ! -e .gitignore ] && [ ! -e .git/hooks/commit-msg ] && [ ! -d .claude/backups ]; then pass "migrate --dry-run: no toca nada"; else bad "migrate --dry-run: modificó ficheros"; fi

out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" 2>&1)"
check "migrate: settings.json sin hooks sdd- ni status lines SDD" jq -e '. == {}' .claude/settings.json
check "migrate: status lines copiadas eliminadas" sh -c '[ ! -e .claude/sdd-status-line.sh ] && [ ! -e .claude/sdd-subagent-status.sh ]'
check "migrate: current-task, trace-map y activity log eliminados" sh -c '! ls .sdd/current-task.json .sdd/trace-map.json .sdd/activity*.jsonl >/dev/null 2>&1'
check "migrate: el resto de .sdd/ se conserva" test -f .sdd/questions-sdd-spec.md
check "migrate: backup de los ficheros de .sdd/" sh -c 'ls .claude/backups/sdd-v3-*/.sdd/current-task.json >/dev/null 2>&1'
check "migrate: hooks copiados eliminados" sh -c '! ls .claude/hooks/sdd-* >/dev/null 2>&1'
check "migrate: agentes copiados eliminados" test ! -e .claude/agents/sdd-legacy-agent.md
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
# el validador vendorizado (.claude/sdd/) se refresca aunque el hook commit-msg ya esté al día
printf '%s\n' "// stale copy" >> .claude/sdd/sdd.mjs
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" --dry-run 2>&1)"
if contains "$out" "vendored validator .claude/sdd/ differs from the plugin (sdd.mjs)"; then pass "migrate: detecta el validador vendorizado desactualizado"; else bad "migrate: validador vendorizado ($out)"; fi
bash "$SCRIPTS/migrate-hooks-v3.sh" >/dev/null 2>&1
check "migrate: refresca la copia vendorizada" sh -c '! grep -q "// stale copy" .claude/sdd/sdd.mjs && grep -q "Vendored by sdd-pipeline" .claude/sdd/sdd.mjs'
rm -f .claude/sdd/lib/junit.mjs
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" --dry-run 2>&1)"
if contains "$out" "misses lib/junit.mjs"; then pass "migrate: detecta un módulo importado sin vendorizar"; else bad "migrate: módulo sin vendorizar ($out)"; fi
bash "$SCRIPTS/migrate-hooks-v3.sh" >/dev/null 2>&1
check "migrate: vuelve a vendorizar el módulo que faltaba" test -f .claude/sdd/lib/junit.mjs
out="$(bash "$SCRIPTS/migrate-hooks-v3.sh" 2>&1)"
if contains "$out" "Nothing to migrate"; then pass "migrate: tras refrescar el validador, sin cambios"; else bad "migrate: tras refrescar ($out)"; fi

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
  "statusLine": { "type": "command", "command": "bash ~/bin/my-line.sh" }
}
EOF
bash "$SCRIPTS/migrate-hooks-v3.sh" >/dev/null 2>&1
check "migrate: conserva permissions" jq -e '.permissions.allow == ["Bash(git status:*)"]' .claude/settings.json
check "migrate: conserva el hook del usuario" jq -e '.hooks.PreToolUse | length == 1 and .[0].hooks == [{"type":"command","command":"echo user-hook"}]' .claude/settings.json
check "migrate: elimina el evento vacío" jq -e '.hooks.SessionStart == null' .claude/settings.json
check "migrate: conserva el quality gate (prompt)" jq -e '.hooks.Stop[0].hooks[0].type == "prompt"' .claude/settings.json
check "migrate: conserva una statusLine ajena" jq -e '.statusLine.command == "bash ~/bin/my-line.sh"' .claude/settings.json

# 6c. fallback node: PATH mínimo sin jq (symlinks a las herramientas que usan los scripts)
mkdir -p "$tmp/minbin"
for t in bash sh git sed awk grep cmp mv cp rm mkdir rmdir date dirname basename cat tail ls sort tr chmod node; do
  bin="$(command -v "$t" 2>/dev/null || true)"; [ -n "$bin" ] && ln -sf "$bin" "$tmp/minbin/$t"
done
if [ -x "$tmp/minbin/node" ] && ! PATH="$tmp/minbin" bash -c 'command -v jq' >/dev/null 2>&1; then
  cat > .claude/settings.json <<'EOF'
{ "hooks": { "PreToolUse": [{ "matcher": "Write", "hooks": [{ "type": "command", "command": "bash .claude/hooks/sdd-upstream-guard.sh" }] }] },
  "statusLine": { "type": "command", "command": "bash .claude/hooks/sdd-status-line.sh" },
  "subagentStatusLine": { "type": "command", "command": "bash .claude/sdd-subagent-status.sh" }, "env": { "A": "1" } }
EOF
  printf '{"currentStage":"requirements-engineer","stages":{}}\n' > pipeline-state.json
  printf '#!/bin/bash\n' > .claude/hooks-old.sh; mkdir -p .claude/hooks; printf '#!/bin/bash\n' > .claude/hooks/sdd-upstream-guard.sh
  PATH="$tmp/fakebin:$tmp/minbin" bash "$SCRIPTS/migrate-hooks-v3.sh" >/dev/null 2>&1 || true
  check "migrate (node): quita hooks sdd- y status lines SDD, conserva el resto" jq -e '. == {"env":{"A":"1"}}' .claude/settings.json
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

# ── 7. Stack kits: install-stack-kit.sh ──────────────────────────────────────
KIT_SH="$SCRIPTS/install-stack-kit.sh"
check "bash -n install-stack-kit.sh" bash -n "$KIT_SH"
check "install-stack-kit.sh ejecutable" test -x "$KIT_SH"
RAILS_V="$(jq -r .version "$ROOT/templates/stacks/rails/kit.json")"
K="$tmp/kits"
mkdir -p "$K" && cd "$K"
git init -q
git config user.name test; git config user.email test@example.com; git config commit.gpgsign false
printf '# Mi proyecto\n\nTexto del usuario.\n' > CLAUDE.md
cp CLAUDE.md "$tmp/kits.orig.md"
git add CLAUDE.md; git commit -q -m "chore: init"

# 7a. --dry-run y primera instalación (rails en web/)
out="$(bash "$KIT_SH" --stack rails --app-dir web --dry-run 2>&1)"
if contains "$out" "## SDD Stack Profile" && contains "$out" "- app_dir: web"; then pass "kit --dry-run: enseña el bloque renderizado"; else bad "kit --dry-run ($out)"; fi
check "kit --dry-run: no escribe nada" sh -c 'cmp -s CLAUDE.md "$1" && [ ! -e .claude ]' _ "$tmp/kits.orig.md"
bash "$KIT_SH" --stack rails --app-dir web >/dev/null 2>&1
check "kit rails: marca de inicio kit=rails v$RAILS_V" grep -qxF "<!-- sdd-stack-begin kit=rails v$RAILS_V -->" CLAUDE.md
check "kit rails: marca de fin" grep -qxF '<!-- sdd-stack-end -->' CLAUDE.md
check "kit rails: sección ## SDD Stack Profile v1" sh -c 'grep -qx "## SDD Stack Profile" CLAUDE.md && grep -qxF "<!-- sdd-stack-profile v1 kit=rails -->" CLAUDE.md'
check "kit rails: app_dir y rutas con prefijo web/" sh -c 'grep -qx -- "- app_dir: web" CLAUDE.md && grep -qx -- "- code_paths: web/app, web/config, web/db, web/lib" CLAUDE.md && grep -qx -- "- test_paths: web/test" CLAUDE.md'
check "kit rails: ## Stack Conventions" grep -qx '## Stack Conventions' CLAUDE.md
check "kit rails: conserva el texto del usuario" sh -c 'head -1 CLAUDE.md | grep -qx "# Mi proyecto" && grep -qx "Texto del usuario." CLAUDE.md'
check "kit rails: 5 reglas en .claude/rules/sdd-rails-*.md" sh -c '[ "$(ls .claude/rules/sdd-rails-*.md | wc -l | tr -d " ")" = 5 ]'
check "kit rails: sin {app_dir} ni {port} sin resolver" sh -c '! grep -qE "\{(app_dir|port)\}" CLAUDE.md .claude/rules/*.md'
check "kit rails: solo quedan marcadores de ejecución {file} {files} {pattern}" sh -c '[ -z "$(grep -ohE "\{[a-z_]+\}" CLAUDE.md .claude/rules/*.md | grep -vxE "\{(file|files|pattern)\}")" ]'
check "kit rails: reglas con frontmatter en la línea 1, globs web/ y cabecera gestionada" sh -c 'for f in .claude/rules/sdd-rails-*.md; do [ "$(head -1 "$f")" = "---" ] && grep -q "^  - \"web/" "$f" && grep -q "<!-- sdd-stack-kit managed kit=rails" "$f" || exit 1; done'
check "kit rails: claves 5.1 con sus valores por defecto" sh -c 'for kv in "visual_evidence: required" "evidence_dir: evidencias" "adversarial_gate: enforce" "literal_gate: enforce" "test_slots: 2" "staging_url: none" "smoke: none" "smoke_report_path: .sdd/junit/smoke" "env_required: none" "deploy: none"; do grep -qxF -- "- $kv" CLAUDE.md || exit 1; done'
check "kit rails: la regla de testing dice dónde van los E2E con captura y los tests de contrato" sh -c 'grep -q "evidencias/FASE-N/" .claude/rules/sdd-rails-testing.md && grep -q "CONTRACT-<port>" .claude/rules/sdd-rails-testing.md && ! grep -q "No system tests" .claude/rules/sdd-rails-testing.md'

# 7b. idempotencia y texto del usuario
git add -A; git commit -q -m "chore: stack kit"
bash "$KIT_SH" --stack rails --app-dir web >/dev/null 2>&1
check "kit: idempotente (git diff --quiet tras la segunda pasada)" git diff --quiet
check "kit: segunda pasada sin ficheros nuevos" sh -c '[ -z "$(git status --porcelain)" ]'
bash "$KIT_SH" >/dev/null 2>&1
check "kit: sin --stack refresca el kit instalado (sin cambios)" sh -c 'git diff --quiet && [ -z "$(git status --porcelain)" ]'
printf '\nNota final del usuario.\n' >> CLAUDE.md
bash "$KIT_SH" --stack rails --app-dir web >/dev/null 2>&1
check "kit: conserva el texto del usuario escrito después del bloque" grep -qx 'Nota final del usuario.' CLAUDE.md
check "kit: un solo bloque" sh -c '[ "$(grep -c "^<!-- sdd-stack-begin" CLAUDE.md)" = 1 ]'
git commit -q -am "docs: nota"

# 7c. --port y --set (recordados en el refresco; key= los olvida)
bash "$KIT_SH" --stack rails --port 3001 --set "acceptance=cd acceptance && BASE_URL=http://127.0.0.1:{port} npx playwright test" >/dev/null 2>&1
check "kit --set: acceptance con {port} sustituido" grep -qxF -- "- acceptance: cd acceptance && BASE_URL=http://127.0.0.1:3001 npx playwright test" CLAUDE.md
check "kit --port: port y server" sh -c 'grep -qx -- "- port: 3001" CLAUDE.md && grep -q -- "^- server: bin/rails server -p 3001 " CLAUDE.md'
check "kit --set acceptance ⇒ e2e_scaffold: never" grep -qx -- '- e2e_scaffold: never' CLAUDE.md
check "kit: sin --app-dir conserva el app_dir del bloque" grep -qx -- '- app_dir: web' CLAUDE.md
git commit -q -am "chore: acceptance"
bash "$KIT_SH" --stack rails >/dev/null 2>&1
check "kit: el refresco sin flags recuerda --set y --port" sh -c 'git diff --quiet && grep -qx -- "- port: 3001" CLAUDE.md'
bash "$KIT_SH" --stack rails --set "acceptance=" >/dev/null 2>&1
check "kit --set key=: vuelve al valor del kit" sh -c 'grep -qx -- "- acceptance: none" CLAUDE.md && grep -qx -- "- e2e_scaffold: allowed" CLAUDE.md && ! grep -q "sdd-stack-set" CLAUDE.md'
if bash "$KIT_SH" --stack rails --set "nope=1" >/dev/null 2>&1; then bad "kit --set: una clave desconocida debería fallar"; else pass "kit --set: clave desconocida → exit ≠ 0"; fi
bash "$KIT_SH" --stack rails --set "test_slots=1" --set "visual_evidence=warn" --set "staging_url=https://staging.example.com" --set "env_required=DATABASE_URL, LLM_API_KEY" >/dev/null 2>&1
check "kit --set: acepta las claves 5.1 y las renderiza" sh -c 'grep -qx -- "- test_slots: 1" CLAUDE.md && grep -qx -- "- visual_evidence: warn" CLAUDE.md && grep -qx -- "- staging_url: https://staging.example.com" CLAUDE.md && grep -qx -- "- env_required: DATABASE_URL, LLM_API_KEY" CLAUDE.md'
bash "$KIT_SH" --stack rails --set "test_slots=" --set "visual_evidence=" --set "staging_url=" --set "env_required=" >/dev/null 2>&1
check "kit --set key=: las claves 5.1 vuelven al valor del kit" sh -c 'grep -qx -- "- test_slots: 2" CLAUDE.md && grep -qx -- "- visual_evidence: required" CLAUDE.md && ! grep -q "sdd-stack-set" CLAUDE.md'
git commit -q -am "chore: sin acceptance"

# 7d. regla sin cabecera gestionada: no se toca
printf -- '---\npaths:\n  - "web/app/views/**/*.erb"\n---\n\n# Mis vistas\n' > .claude/rules/sdd-rails-views.md
out="$(bash "$KIT_SH" --stack rails 2>&1)"
check "kit: no sobrescribe una regla sin la cabecera gestionada" grep -qx '# Mis vistas' .claude/rules/sdd-rails-views.md
if contains "$out" "left untouched"; then pass "kit: avisa de la regla no gestionada"; else bad "kit: sin aviso de regla no gestionada ($out)"; fi
rm .claude/rules/sdd-rails-views.md
bash "$KIT_SH" >/dev/null 2>&1
check "kit: recrea la regla gestionada borrada" grep -q "sdd-stack-kit managed kit=rails" .claude/rules/sdd-rails-views.md

# 7e. --app-dir . quita el prefijo
bash "$KIT_SH" --stack rails --app-dir . >/dev/null 2>&1
check "kit --app-dir .: perfil sin prefijo" sh -c 'grep -qx -- "- app_dir: ." CLAUDE.md && grep -qx -- "- code_paths: app, config, db, lib" CLAUDE.md && grep -qx -- "- test_paths: test" CLAUDE.md'
check "kit --app-dir .: globs de reglas sin prefijo" grep -qF '  - "app/models/**/*.rb"' .claude/rules/sdd-rails-models.md
check "kit --app-dir .: ni {app_dir} ni web/ en bloque y reglas" sh -c '! grep -qE "\{app_dir\}|web/" CLAUDE.md .claude/rules/sdd-rails-*.md'

# 7f. kit desconocido
cp CLAUDE.md "$tmp/kits.before-unknown.md"
if bash "$KIT_SH" --stack cobol >/dev/null 2>&1; then bad "kit desconocido debería fallar"; else pass "kit desconocido → exit ≠ 0"; fi
check "kit desconocido: CLAUDE.md intacto" cmp -s CLAUDE.md "$tmp/kits.before-unknown.md"

# 7g. subida de versión: copia del plugin con el kit en 9.9.9 (el kit se resuelve junto al script)
PC="$tmp/plugin-copy"
mkdir -p "$PC/scripts" "$PC/templates"
cp "$KIT_SH" "$PC/scripts/"; cp -R "$ROOT/templates/stacks" "$PC/templates/"
jq '.version = "9.9.9"' "$ROOT/templates/stacks/rails/kit.json" > "$PC/templates/stacks/rails/kit.json"
bash "$PC/scripts/install-stack-kit.sh" --stack rails --app-dir web >/dev/null 2>&1
check "kit: refresco en su sitio al subir la versión (v9.9.9, un bloque)" sh -c 'grep -qxF "<!-- sdd-stack-begin kit=rails v9.9.9 -->" CLAUDE.md && [ "$(grep -c "^<!-- sdd-stack-begin" CLAUDE.md)" = 1 ]'
check "kit: reglas refrescadas a v9.9.9" grep -q "kit=rails v9.9.9" .claude/rules/sdd-rails-models.md
check "kit: texto del usuario intacto tras el refresco" sh -c 'grep -qx "Texto del usuario." CLAUDE.md && grep -qx "Nota final del usuario." CLAUDE.md'

# 7h. --uninstall
bash "$KIT_SH" --uninstall >/dev/null 2>&1
check "kit --uninstall: sin bloque" sh -c '! grep -q "sdd-stack-" CLAUDE.md'
check "kit --uninstall: sin reglas gestionadas" sh -c '! ls .claude/rules/sdd-*.md >/dev/null 2>&1'
check "kit --uninstall: conserva el texto del usuario sin líneas en blanco dobles" sh -c 'grep -qx "Texto del usuario." CLAUDE.md && grep -qx "Nota final del usuario." CLAUDE.md && awk "NF == 0 { if (++b > 1) exit 1; next } { b = 0 }" CLAUDE.md'

# 7i. auto: rails en web/, nextjs-prisma en app/, nada → error
A="$tmp/kits-auto"
mkdir -p "$A/web/config" && cd "$A" && git init -q
printf 'source "https://rubygems.org"\ngem "rails"\n' > web/Gemfile; : > web/config/application.rb
printf '# Auto\n\nTexto.\n' > CLAUDE.md; cp CLAUDE.md "$tmp/kits-auto.orig.md"
out="$(bash "$KIT_SH" --stack auto 2>&1)"
check "kit auto: web/Gemfile + web/config/application.rb → rails" grep -q '^<!-- sdd-stack-begin kit=rails ' CLAUDE.md
check "kit auto: app_dir web" grep -qx -- '- app_dir: web' CLAUDE.md
if contains "$out" "detected kit rails in web"; then pass "kit auto: informa de la detección"; else bad "kit auto: sin informe ($out)"; fi
bash "$KIT_SH" --uninstall >/dev/null 2>&1
check "kit --uninstall: CLAUDE.md idéntico al original" cmp -s CLAUDE.md "$tmp/kits-auto.orig.md"
check "kit --uninstall: no deja .claude vacío" test ! -e .claude
E="$tmp/kits-empty"
mkdir -p "$E" && cd "$E" && git init -q
rc=0; out="$(bash "$KIT_SH" --stack auto 2>&1)" || rc=$?
if [ "$rc" -ne 0 ] && contains "$out" "--stack"; then pass "kit auto sin stack: exit ≠ 0 y pide --stack"; else bad "kit auto sin stack (rc=$rc, $out)"; fi
check "kit auto sin stack: no escribe" sh -c '[ ! -e CLAUDE.md ] && [ ! -e .claude ]'
mkdir -p app && printf '{}\n' > app/package.json && : > app/next.config.ts
bash "$KIT_SH" --stack auto >/dev/null 2>&1
check "kit auto: app/package.json + app/next.config.ts → nextjs-prisma en app" sh -c 'grep -q "^<!-- sdd-stack-begin kit=nextjs-prisma " CLAUDE.md && grep -qx -- "- app_dir: app" CLAUDE.md'
check "kit nextjs-prisma: glob de dominio app/src/{lib,domain,server}/**" grep -qF '"app/src/{lib,domain,server}/**"' .claude/rules/sdd-nextjs-prisma-domain.md
check "kit nextjs-prisma: claves 5.1 renderizadas" sh -c 'grep -qx -- "- test_slots: 2" CLAUDE.md && grep -qx -- "- evidence_dir: evidencias" CLAUDE.md && grep -qx -- "- adversarial_gate: enforce" CLAUDE.md && grep -qx -- "- literal_gate: enforce" CLAUDE.md'
check "kit nextjs-prisma: E2E con captura en app/tests/e2e y contrato en app/tests/contract" sh -c 'grep -q "app/tests/e2e/" .claude/rules/sdd-nextjs-prisma-testing.md && grep -q "app/tests/contract/" .claude/rules/sdd-nextjs-prisma-testing.md'
check "kit nextjs-prisma: ningún reset de Prisma" sh -c '! grep -qiE "migrate +reset" CLAUDE.md .claude/rules/*.md'

cd "$ROOT"
[ "$fail" -eq 0 ] && echo "tests/setup: todo ok" || { echo "tests/setup: hay fallos"; exit 1; }
