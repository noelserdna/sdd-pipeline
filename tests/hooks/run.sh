#!/usr/bin/env bash
# Tests de los hooks del plugin (dos raíces + lock + SDD_ROLE).
# Cada test alimenta el JSON de stdin que Claude Code enviaría y comprueba la salida/efectos.
# Fixtures reproducibles en mktemp -d; HOME se aísla para no leer ~/.claude/sessions reales.
# Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere git, jq y node.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$ROOT/hooks"
LIB="$HOOKS/lib/sdd-common.sh"
FIX="$ROOT/tests/hooks/fixtures"
STATUS_LINE="$ROOT/scripts/sdd-status-line.sh"
TEMPLATE="$ROOT/templates/sdd-sessions.example.json"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"   # macOS: /var → /private/var (git devuelve rutas físicas)
cleanup() { [ -n "${PEER_PID:-}" ] && kill "$PEER_PID" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT

export HOME="$tmp/home"
mkdir -p "$HOME/.claude/sessions"
unset SDD_ROLE SDD_STATE_ROOT CLAUDE_PID CLAUDE_PROJECT_DIR CLAUDE_ENV_FILE CLAUDE_PLUGIN_ROOT SDD_PLUGIN_ROOT || true
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# ---------------------------------------------------------------- helpers
pre_json()   { printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2" "$3"; }
post_json()  { printf '{"session_id":"t","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s"},"tool_response":{"success":true}}' "$1" "$2"; }
start_json() { printf '{"session_id":"t","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$1"; }

# guard ENV cwd tool path → deny | allow | error(rc)
guard() {
  local envs="$1" cwd="$2" tool="$3" path="$4" out rc=0
  # shellcheck disable=SC2086
  out=$(pre_json "$cwd" "$tool" "$path" | env $envs bash "$HOOKS/sdd-upstream-guard.sh" 2>/dev/null) || rc=$?
  [ "$rc" -eq 0 ] || { echo "error($rc)"; return 0; }
  if contains "$out" '"permissionDecision":"deny"'; then echo deny; else echo allow; fi
}
guard_out() {
  local envs="$1" cwd="$2" tool="$3" path="$4"
  # shellcheck disable=SC2086
  pre_json "$cwd" "$tool" "$path" | env $envs bash "$HOOKS/sdd-upstream-guard.sh" 2>/dev/null || true
}
# h3 ENV cwd path
h3() {
  local envs="$1" cwd="$2" path="$3"
  # shellcheck disable=SC2086
  post_json "$cwd" "$path" | env $envs bash "$HOOKS/sdd-pipeline-state-updater.sh" 2>/dev/null
}
# h9 ENV cwd path
h9() {
  local envs="$1" cwd="$2" path="$3"
  # shellcheck disable=SC2086
  post_json "$cwd" "$path" | env $envs bash "$HOOKS/sdd-trace-map-updater.sh" 2>/dev/null
}
# h1 ENV cwd → stdout
h1() {
  local envs="$1" cwd="$2"
  # shellcheck disable=SC2086
  start_json "$cwd" | env $envs bash "$HOOKS/sdd-session-start.sh" 2>/dev/null || true
}
status_of() { jq -r --arg s "$1" '.stages[$s].status // "absent"' "$2" 2>/dev/null || echo "unreadable"; }
reset_state() { cp "$FIX/$1" "$repo/pipeline-state.json"; }
no_lock() { [ ! -d "$1.lock" ]; }

# ---------------------------------------------------------------- 1. sintaxis
for f in "$HOOKS"/*.sh "$HOOKS"/lib/*.sh "$STATUS_LINE" "$0"; do
  check "bash -n $(basename "$f")" bash -n "$f"
done
check "node --check sdd-augment-hook.js" node --check "$HOOKS/sdd-augment-hook.js"
check "templates/sdd-sessions.example.json es sdd-sessions-v1" jq -e '."$schema" == "sdd-sessions-v1" and (.roles | has("sdd-lead","sdd-spec","sdd-plan","impl-f1a","sdd-qa"))' "$TEMPLATE"

# ---------------------------------------------------------------- 2. sin pipeline (directorio sin git)
nogit="$tmp/nogit"; mkdir -p "$nogit"
out=$(h1 "" "$nogit")
if printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("No pipeline-state.json")' >/dev/null 2>&1; then pass "H1 sin pipeline: Fresh pipeline en JSON"; else bad "H1 sin pipeline: $out"; fi
[ "$(guard "" "$nogit" Write "$nogit/spec/x.md")" = allow ] && pass "H2 sin pipeline-state permite" || bad "H2 sin pipeline-state deniega"
start=$(date +%s)
if printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s/a.md"}}' "$nogit" "$nogit" | CLAUDE_PROJECT_DIR="$nogit" node "$HOOKS/sdd-augment-hook.js" >/dev/null 2>&1; then pass "H5 sin grafo (exit 0, $(( $(date +%s) - start ))s)"; else bad "H5 sin grafo falla"; fi
out=$(printf '{"cwd":"%s","workspace":{"current_dir":"%s"}}' "$nogit" "$nogit" | bash "$STATUS_LINE" 2>/dev/null || true)
[ "$out" = "SDD: no pipeline" ] && pass "statusLine sin pipeline" || bad "statusLine sin pipeline: '$out'"

# ---------------------------------------------------------------- 3. repo git con task-implementer running
repo="$tmp/repo"
git init -q "$repo" && git -C "$repo" commit -q --allow-empty -m init
reset_state pipeline-state.impl-running.json
[ "$(guard "" "$repo" Write "$repo/spec/x.md")" = deny ]  && pass "H2 impl running: deniega spec/x.md" || bad "H2 impl running: no deniega spec/x.md"
[ "$(guard "" "$repo" Write "$repo/src/x.ts")" = allow ] && pass "H2 impl running: permite src/x.ts" || bad "H2 impl running: deniega src/x.ts"
[ "$(guard "" "$repo" Edit "$repo/task/TASK-FASE-1.md")" = allow ] && pass "H2 impl running: Edit task/TASK-FASE-1.md permitido" || bad "H2 impl running: Edit task/TASK-FASE-1.md denegado"
[ "$(guard "" "$repo" Write "$repo/task/TASK-FASE-1.md")" = deny ] && pass "H2 impl running: Write task/TASK-FASE-1.md denegado" || bad "H2 impl running: Write task/TASK-FASE-1.md permitido"
for p in pipeline-state.json .sdd/x.json changes/c.md feedback/f.md .claude/settings.json .claude/hooks/x.sh .claude/sdd-sessions.json .claude/foo.md; do
  [ "$(guard "" "$repo" Write "$repo/$p")" = allow ] && pass "H2 siempre permite $p" || bad "H2 deniega $p"
done
[ "$(guard "" "$repo" Write "/etc/hosts")" = allow ] && pass "H2 fuera del proyecto permite" || bad "H2 fuera del proyecto deniega"
out=$(h1 "" "$repo")
contains "$out" "RUNNING: task-implementer" && pass "H1 con pipeline: RUNNING: task-implementer" || bad "H1 con pipeline: $out"
contains "$out" "handoff: example-lead skipped:lead-absent" && pass "H1 muestra handoff del último stage done" || bad "H1 sin handoff: $out"
contains "$out" "Rol:" && bad "H1 sin rol no debe mostrar Rol:" || pass "H1 sin rol no muestra Rol:"

# ---------------------------------------------------------------- 4. worktree externo (git worktree add ../wt)
wt="$tmp/wt"
git -C "$repo" worktree add -q "$wt" >/dev/null 2>&1
[ "$(guard "" "$wt" Write "$wt/spec/x.md")" = deny ]  && pass "H2 desde worktree deniega spec/x.md (estado del principal)" || bad "H2 desde worktree no deniega spec/x.md"
[ "$(guard "" "$wt" Write "$wt/src/x.ts")" = allow ] && pass "H2 desde worktree permite src/x.ts" || bad "H2 desde worktree deniega src/x.ts"
reset_state pipeline-state.pending.json
h3 "" "$wt" "$wt/src/x.ts"
[ "$(status_of task-implementer "$repo/pipeline-state.json")" = running ] && pass "H3 desde worktree escribe en <principal>/pipeline-state.json" || bad "H3 desde worktree no actualizó el principal"
[ ! -e "$wt/pipeline-state.json" ] && pass "H3 desde worktree NO crea pipeline-state.json en el worktree" || bad "H3 creó pipeline-state.json en el worktree"
check "H3 no deja .lock" no_lock "$repo/pipeline-state.json"
[ "$(jq -r '.stages["requirements-engineer"].summary.note' "$repo/pipeline-state.json")" = "must survive H3" ] && pass "H3 conserva summary" || bad "H3 alteró summary"
out=$(h1 "" "$wt")
contains "$out" "RUNNING: task-implementer" && pass "H1 desde worktree lee el estado del principal" || bad "H1 desde worktree: $out"

# ---------------------------------------------------------------- 5. .claude/worktrees/x (EnterWorktree / claude -w)
cw="$repo/.claude/worktrees/x"
mkdir -p "$repo/.claude/worktrees"
git -C "$repo" worktree add -q "$cw" >/dev/null 2>&1
rel=$(bash -c '. "$1"; sdd_roots "$2" "$3"; printf "%s|%s" "$REL_PATH" "$PROJECT_DIR"' _ "$LIB" "$(start_json "$repo")" "$cw/src/a.ts")
[ "$rel" = "src/a.ts|$cw" ] && pass "sdd_roots: .claude/worktrees/x/src/a.ts → REL_PATH src/a.ts, PROJECT_DIR el worktree" || bad "sdd_roots .claude/worktrees: $rel"
reset_state pipeline-state.impl-running.json
[ "$(guard "" "$repo" Write "$cw/spec/x.md")" = deny ] && pass "H2 deniega .claude/worktrees/x/spec/x.md (ya no cuela por .claude/*)" || bad "H2 permite .claude/worktrees/x/spec/x.md"
reset_state pipeline-state.pending.json
h3 "" "$repo" "$cw/src/a.ts"
[ "$(status_of task-implementer "$repo/pipeline-state.json")" = running ] && pass "H3 mapea .claude/worktrees/x/src/a.ts → task-implementer en el principal" || bad "H3 no mapeó .claude/worktrees/x/src/a.ts"
[ ! -e "$cw/pipeline-state.json" ] && pass "H3 no crea estado en .claude/worktrees/x" || bad "H3 creó estado en .claude/worktrees/x"

# ---------------------------------------------------------------- 6. mapeo de audits/, design/, ux/
reset_state pipeline-state.pending.json
h3 "" "$repo" "$repo/audits/SECURITY-AUDIT-BASELINE.md"
[ "$(status_of security-auditor "$repo/pipeline-state.json")" = running ] && pass "H3 audits/SECURITY-* → security-auditor running (clave creada)" || bad "H3 audits/SECURITY-* no marcó security-auditor"
[ "$(status_of spec-auditor "$repo/pipeline-state.json")" = pending ] && pass "H3 audits/SECURITY-* NO toca spec-auditor" || bad "H3 audits/SECURITY-* marcó spec-auditor"
h3 "" "$repo" "$repo/audits/GAP-ANALYSIS-REVIEW.md"
[ "$(status_of gap-detector "$repo/pipeline-state.json")" = running ] && pass "H3 audits/GAP-* → gap-detector" || bad "H3 audits/GAP-* no marcó gap-detector"
[ "$(status_of spec-auditor "$repo/pipeline-state.json")" = pending ] && pass "H3 audits/GAP-* NO toca spec-auditor" || bad "H3 audits/GAP-* marcó spec-auditor"
h3 "" "$repo" "$repo/audits/UPSTREAM-IMPACT-001.md"
[ "$(status_of spec-auditor "$repo/pipeline-state.json")" = running ] && pass "H3 audits/UPSTREAM-IMPACT-* → spec-auditor" || bad "H3 audits/UPSTREAM-IMPACT-* no marcó spec-auditor"
reset_state pipeline-state.pending.json
h3 "" "$repo" "$repo/audits/AUDIT-REPORT.md"
[ "$(status_of spec-auditor "$repo/pipeline-state.json")" = running ] && pass "H3 audits/AUDIT-* → spec-auditor" || bad "H3 audits/AUDIT-* no marcó spec-auditor"
h3 "" "$repo" "$repo/design/TECH-DESIGN.md"
[ "$(status_of tech-designer "$repo/pipeline-state.json")" = running ] && pass "H3 design/* → tech-designer" || bad "H3 design/* no marcó tech-designer"
h3 "" "$repo" "$repo/ux/DESIGN-SYSTEM.md"
[ "$(status_of ux-designer "$repo/pipeline-state.json")" = running ] && pass "H3 ux/* → ux-designer" || bad "H3 ux/* no marcó ux-designer"
[ "$(jq -r .currentStage "$repo/pipeline-state.json")" = ux-designer ] && pass "H3 actualiza currentStage" || bad "H3 currentStage incorrecto"
h3 "" "$repo" "$repo/pipeline-state.json"
[ "$(jq -r .currentStage "$repo/pipeline-state.json")" = ux-designer ] && pass "H3 ignora pipeline-state.json" || bad "H3 procesó pipeline-state.json"
check "H3 no deja .lock tras el mapeo" no_lock "$repo/pipeline-state.json"

# ---------------------------------------------------------------- 7. 20 H3 concurrentes (xargs -P 8)
reset_state pipeline-state.pending.json
mkdir -p "$tmp/in"
i=0
while [ "$i" -lt 20 ]; do
  case $((i % 4)) in
    0) p="src/a$i.ts" ;; 1) p="spec/s$i.md" ;; 2) p="test/t$i.md" ;; *) p="plan/p$i.md" ;;
  esac
  post_json "$repo" "$repo/$p" > "$tmp/in/$i.json"
  i=$((i + 1))
done
printf '%s\n' "$tmp/in"/*.json | xargs -P 8 -n 1 sh -c 'bash "$0" < "$1"' "$HOOKS/sdd-pipeline-state-updater.sh" 2>/dev/null || true
check "20 H3 concurrentes: JSON válido" jq -e . "$repo/pipeline-state.json"
check "20 H3 concurrentes: sin .lock huérfano" no_lock "$repo/pipeline-state.json"
[ -z "$(ls "$repo"/pipeline-state.json.tmp.* 2>/dev/null)" ] && pass "20 H3 concurrentes: sin temporales" || bad "20 H3 concurrentes: quedan temporales"
allrun=1
for s in task-implementer specifications-engineer test-planner plan-architect; do [ "$(status_of "$s" "$repo/pipeline-state.json")" = running ] || allrun=0; done
[ "$allrun" = 1 ] && pass "20 H3 concurrentes: los 4 stages quedan running" || bad "20 H3 concurrentes: se perdió alguna actualización"
[ "$(jq -r '.stages["requirements-engineer"].summary.note' "$repo/pipeline-state.json")" = "must survive H3" ] && pass "20 H3 concurrentes: summary intacto" || bad "20 H3 concurrentes: summary perdido"

# ---------------------------------------------------------------- 8. roles con .claude/sdd-sessions.json
mkdir -p "$repo/.claude"; cp "$TEMPLATE" "$repo/.claude/sdd-sessions.json"
reset_state pipeline-state.impl-running.json
out=$(guard_out "SDD_ROLE=sdd-spec" "$repo" Write "$repo/src/x.ts")
if contains "$out" '"deny"' && contains "$out" "no posee"; then pass "SDD_ROLE=sdd-spec Write src/x.ts → deny 'no posee'"; else bad "SDD_ROLE=sdd-spec Write src/x.ts: $out"; fi
[ "$(guard "SDD_ROLE=sdd-spec" "$repo" Write "$repo/spec/x.md")" = allow ] && pass "SDD_ROLE=sdd-spec Write spec/x.md → allow (impl running no está en sus stages)" || bad "SDD_ROLE=sdd-spec Write spec/x.md denegado"
[ "$(guard "SDD_ROLE=impl-f1a" "$repo" Edit "$repo/task/TASK-FASE-1.md")" = allow ] && pass "SDD_ROLE=impl-f1a Edit task/TASK-FASE-1.md → allow" || bad "SDD_ROLE=impl-f1a Edit task/TASK-FASE-1.md denegado"
out=$(guard_out "SDD_ROLE=impl-f1a" "$repo" Write "$repo/task/TASK-FASE-1.md")
if contains "$out" '"deny"' && contains "$out" "Art. 4"; then pass "SDD_ROLE=impl-f1a Write task/TASK-FASE-1.md → deny (Art. 4)"; else bad "SDD_ROLE=impl-f1a Write task/TASK-FASE-1.md: $out"; fi
out=$(guard_out "SDD_ROLE=impl-f1a" "$repo" Write "$repo/spec/x.md")
if contains "$out" "no posee"; then pass "SDD_ROLE=impl-f1a Write spec/x.md → deny 'no posee' (antes que Art. 4)"; else bad "SDD_ROLE=impl-f1a Write spec/x.md: $out"; fi
[ "$(guard "SDD_ROLE=impl-f1a" "$repo" Write "$repo/feedback/IMPL-FEEDBACK-FASE-1.md")" = allow ] && pass "SDD_ROLE=impl-f1a feedback/* → allow" || bad "SDD_ROLE=impl-f1a feedback/* denegado"
[ "$(guard "SDD_ROLE=sdd-lead" "$repo" Write "$repo/.claude/foo.md")" = allow ] && pass "SDD_ROLE=sdd-lead .claude/foo.md → allow (owns .claude/*)" || bad "SDD_ROLE=sdd-lead .claude/foo.md denegado"
[ "$(guard "SDD_ROLE=sdd-qa" "$repo" Write "$repo/.claude/foo.md")" = deny ] && pass "SDD_ROLE=sdd-qa .claude/foo.md → deny" || bad "SDD_ROLE=sdd-qa .claude/foo.md permitido"
[ "$(guard "SDD_ROLE=sdd-qa" "$repo" Write "$repo/.claude/settings.local.json")" = allow ] && pass "SDD_ROLE=sdd-qa .claude/settings*.json → allow (siempre)" || bad "SDD_ROLE=sdd-qa .claude/settings.local.json denegado"
[ "$(guard "SDD_ROLE=nope" "$repo" Write "$repo/src/x.ts")" = allow ] && pass "SDD_ROLE desconocido → como sin rol (allow src/x.ts)" || bad "SDD_ROLE desconocido cambia la decisión"
[ "$(guard "SDD_ROLE=nope" "$repo" Write "$repo/spec/x.md")" = deny ] && pass "SDD_ROLE desconocido → como sin rol (deny spec/x.md)" || bad "SDD_ROLE desconocido permite spec/x.md"
# rol vía registro de sesiones (~/.claude/sessions/<pid>.json → .name → sdd-sessions.json)
printf '{"pid":%s,"cwd":"%s","name":"example-spec","status":"idle"}' "$$" "$repo" > "$HOME/.claude/sessions/$$.json"
out=$(guard_out "CLAUDE_PID=$$" "$repo" Write "$repo/src/x.ts")
if contains "$out" "Rol sdd-spec no posee"; then pass "rol por registro de sesiones (CLAUDE_PID) → deny 'no posee'"; else bad "rol por registro: $out"; fi
# registro corrupto: degrada a sin rol y exit 0
cp "$repo/.claude/sdd-sessions.json" "$tmp/reg.bak"; printf '{not json' > "$repo/.claude/sdd-sessions.json"
[ "$(guard "SDD_ROLE=sdd-spec" "$repo" Write "$repo/src/x.ts")" = allow ] && pass "registro corrupto → sin rol, exit 0" || bad "registro corrupto rompe H2"
cp "$tmp/reg.bak" "$repo/.claude/sdd-sessions.json"
[ "$(guard "SDD_ROLE=sdd-spec SDD_STATE_ROOT=$tmp/nogit" "$repo" Write "$repo/src/x.ts")" = allow ] && pass "SDD_STATE_ROOT sin registro ni estado → allow" || bad "SDD_STATE_ROOT sin registro deniega"

# ---------------------------------------------------------------- 9. env -u SDD_ROLE -u CLAUDE_PID ≡ sin rol
rm -f "$HOME"/.claude/sessions/*.json
same=1
for spec in "Write spec/x.md" "Write src/x.ts" "Edit task/TASK-FASE-1.md" "Write task/TASK-FASE-1.md" "Write requirements/r.md" "Write .claude/foo.md" "Write audits/A.md" "Write plan/p.md"; do
  tool="${spec%% *}"; p="${spec#* }"
  with=$(guard "-u SDD_ROLE -u CLAUDE_PID" "$repo" "$tool" "$repo/$p")
  mv "$repo/.claude/sdd-sessions.json" "$tmp/reg.tmp"
  without=$(guard "-u SDD_ROLE -u CLAUDE_PID" "$repo" "$tool" "$repo/$p")
  mv "$tmp/reg.tmp" "$repo/.claude/sdd-sessions.json"
  [ "$with" = "$without" ] || { same=0; echo "     difiere: $spec con=$with sin=$without"; }
done
[ "$same" = 1 ] && pass "env -u SDD_ROLE -u CLAUDE_PID: decisiones idénticas con y sin registro" || bad "env -u SDD_ROLE -u CLAUDE_PID: decisiones distintas"

# ---------------------------------------------------------------- 10. H1 con rol, pares y CLAUDE_ENV_FILE
PEER_PID=$( (sleep 60 >/dev/null 2>&1 & echo $!) )   # par "vivo" fuera del control de jobs (sin mensaje Terminated)
printf '{"pid":%s,"cwd":"%s","name":"example-lead","status":"idle"}' "$PEER_PID" "$wt" > "$HOME/.claude/sessions/$PEER_PID.json"
printf '{"pid":4194000,"cwd":"%s","name":"example-qa","status":"idle"}' "$repo" > "$HOME/.claude/sessions/4194000.json"
printf '{"pid":%s,"cwd":"%s","name":"example-spec","status":"busy"}' "$$" "$repo" > "$HOME/.claude/sessions/$$.json"
envf="$tmp/env.sh"; rm -f "$envf"
out=$(h1 "SDD_ROLE=sdd-spec CLAUDE_PID=$$ CLAUDE_ENV_FILE=$envf CLAUDE_PLUGIN_ROOT=$ROOT" "$repo")
contains "$out" "Rol: sdd-spec (posee: spec/* audits/AUDIT-*" && pass "H1 con rol muestra Rol: y owns" || bad "H1 con rol: $out"
contains "$out" "stages: specifications-engineer spec-auditor req-change" && pass "H1 con rol muestra stages" || bad "H1 stages: $out"
contains "$out" "Pares vivos: example-lead(idle)" && pass "H1 lista pares vivos del mismo repo (excluye pid propio y muertos)" || bad "H1 pares: $out"
contains "$out" "example-qa" && bad "H1 lista un par muerto" || pass "H1 no lista pares muertos"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null 2>&1 && pass "H1 con rol: salida JSON válida" || bad "H1 con rol: salida no JSON"
grep -q "^export SDD_STATE_ROOT=\"$repo\"$" "$envf" 2>/dev/null && pass "H1 escribe SDD_STATE_ROOT en CLAUDE_ENV_FILE" || bad "H1 no escribió SDD_STATE_ROOT: $(cat "$envf" 2>/dev/null)"
grep -q "^export SDD_PLUGIN_ROOT=\"$ROOT\"$" "$envf" 2>/dev/null && pass "H1 escribe SDD_PLUGIN_ROOT" || bad "H1 no escribió SDD_PLUGIN_ROOT"
grep -q "^export SDD_ROLE=" "$envf" 2>/dev/null && bad "H1 exporta SDD_ROLE aunque venía del entorno" || pass "H1 no exporta SDD_ROLE si ya venía del entorno"
rm -f "$envf"
out=$(h1 "CLAUDE_PID=$$ CLAUDE_ENV_FILE=$envf" "$wt")
contains "$out" "Rol: sdd-spec" && pass "H1 resuelve el rol por registro de sesiones (desde el worktree)" || bad "H1 rol por registro: $out"
grep -q '^export SDD_ROLE="sdd-spec"$' "$envf" 2>/dev/null && pass "H1 exporta SDD_ROLE cuando lo resolvió el registro" || bad "H1 no exportó SDD_ROLE: $(cat "$envf" 2>/dev/null)"
grep -q "^export SDD_STATE_ROOT=\"$repo\"$" "$envf" 2>/dev/null && pass "H1 desde worktree: SDD_STATE_ROOT es el principal" || bad "H1 desde worktree SDD_STATE_ROOT: $(cat "$envf" 2>/dev/null)"
out=$(h1 "SDD_ROLE=sdd-spec" "$nogit")
if contains "$out" "No pipeline-state.json" && contains "$out" "Rol: sdd-spec"; then pass "H1 con rol y sin pipeline: Fresh pipeline + Rol"; else bad "H1 con rol y sin pipeline: $out"; fi
rm -f "$HOME"/.claude/sessions/*.json

# ---------------------------------------------------------------- 11. statusLine (con y sin librería)
sl() { printf '{"cwd":"%s","workspace":{"current_dir":"%s","project_dir":"%s"}}' "$1" "$1" "$1" | env "$@" bash "$STATUS_LINE" 2>/dev/null || true; }
reset_state pipeline-state.impl-running.json
out=$(printf '{"cwd":"%s","workspace":{"current_dir":"%s"}}' "$wt" "$wt" | bash "$STATUS_LINE" 2>/dev/null || true)
[ "$out" = "SDD [6/7] impl" ] && pass "statusLine desde worktree lee el estado del principal" || bad "statusLine desde worktree: '$out'"
out=$(printf '{"workspace":{"current_dir":"%s"}}' "$wt" | bash "$STATUS_LINE" 2>/dev/null || true)
[ "$out" = "SDD [6/7] impl" ] && pass "statusLine acepta workspace.current_dir sin cwd" || bad "statusLine workspace.current_dir: '$out'"
out=$(printf '{"cwd":"%s"}' "$repo" | SDD_ROLE=sdd-spec bash "$STATUS_LINE" 2>/dev/null || true)
[ "$out" = "[sdd-spec] SDD [6/7]" ] && pass "statusLine con rol: prefijo [rol] y stage ∩ rol (impl no es suyo)" || bad "statusLine rol sdd-spec: '$out'"
out=$(printf '{"cwd":"%s"}' "$repo" | SDD_ROLE=impl-f1a bash "$STATUS_LINE" 2>/dev/null || true)
[ "$out" = "[impl-f1a] SDD [6/7] impl" ] && pass "statusLine con rol impl-f1a muestra impl" || bad "statusLine rol impl-f1a: '$out'"
mkdir -p "$tmp/old"; cp "$STATUS_LINE" "$tmp/old/sdd-status-line.sh"
out=$(printf '{"cwd":"%s"}' "$wt" | CLAUDE_PROJECT_DIR="$repo" bash "$tmp/old/sdd-status-line.sh" 2>/dev/null || true)
[ "$out" = "SDD [6/7] impl" ] && pass "statusLine sin librería degrada a CLAUDE_PROJECT_DIR" || bad "statusLine sin librería: '$out'"
out=$(printf '{"cwd":"%s"}' "$wt" | SDD_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$nogit" bash "$tmp/old/sdd-status-line.sh" 2>/dev/null || true)
[ "$out" = "SDD [6/7] impl" ] && pass "statusLine copiado encuentra la librería vía SDD_PLUGIN_ROOT" || bad "statusLine vía SDD_PLUGIN_ROOT: '$out'"
# script copiado a .claude/ (instalación real): encuentra la librería vía installed_plugins.json
mkdir -p "$HOME/.claude/plugins"
printf '{"version":2,"plugins":{"sdd-pipeline@test":[{"scope":"user","installPath":"%s","version":"x"}]}}' "$ROOT" > "$HOME/.claude/plugins/installed_plugins.json"
out=$(printf '{"cwd":"%s"}' "$wt" | SDD_ROLE=sdd-spec CLAUDE_PROJECT_DIR="$nogit" bash "$tmp/old/sdd-status-line.sh" 2>/dev/null || true)
[ "$out" = "[sdd-spec] SDD [6/7]" ] && pass "statusLine copiado encuentra la librería vía installed_plugins.json" || bad "statusLine vía installed_plugins.json: '$out'"
rm -f "$HOME/.claude/plugins/installed_plugins.json"
out=$(printf '{"cwd":"%s"}' "$wt" | SDD_STATE_ROOT="$repo" SDD_ROLE=impl-f1a CLAUDE_PROJECT_DIR="$nogit" bash "$tmp/old/sdd-status-line.sh" 2>/dev/null || true)
[ "$out" = "[impl-f1a] SDD [6/7] impl" ] && pass "statusLine sin librería respeta SDD_STATE_ROOT/SDD_ROLE (sdd-up.sh)" || bad "statusLine sin librería con env: '$out'"
out=$(printf '{"cwd":"%s"}' "$wt" | CLAUDE_PROJECT_DIR="$nogit" bash "$tmp/old/sdd-status-line.sh" 2>/dev/null || true)
[ "$out" = "SDD: no pipeline" ] && pass "statusLine sin librería ni env: comportamiento anterior (no ve el principal)" || bad "statusLine sin librería ni env: '$out'"
unset -f sl

# ---------------------------------------------------------------- 12. H9 trace-map compartido, breadcrumb por worktree
mkdir -p "$wt/.sdd"; cp "$FIX/current-task.json" "$wt/.sdd/current-task.json"
h9 "" "$wt" "$wt/src/x.ts"
tm="$repo/.sdd/trace-map.json"
check "H9 crea <principal>/.sdd/trace-map.json" test -f "$tm"
[ ! -e "$wt/.sdd/trace-map.json" ] && pass "H9 no crea trace-map en el worktree" || bad "H9 creó trace-map en el worktree"
check "H9 entrada file=src/x.ts taskId=TASK-F1-003 stream=A role=impl-f1a" jq -e '.mappings[0] | .file == "src/x.ts" and .taskId == "TASK-F1-003" and .stream == "A" and .role == "impl-f1a" and .fase == 1 and (.refs | length == 2)' "$tm"
h9 "" "$wt" "$wt/src/x.ts"
[ "$(jq '.mappings | length' "$tm")" = 1 ] && pass "H9 no duplica entradas" || bad "H9 duplicó entradas"
check "H9 no deja .lock" no_lock "$tm"
h9 "" "$repo" "$repo/src/y.ts"
[ "$(jq '.mappings | length' "$tm")" = 1 ] && pass "H9 sin breadcrumb en el principal no traza" || bad "H9 trazó sin breadcrumb"

# ---------------------------------------------------------------- 13. lock huérfano y lock vivo
reset_state pipeline-state.pending.json
mkdir -p "$repo/pipeline-state.json.lock"; touch -t 202001010000 "$repo/pipeline-state.json.lock"
h3 "" "$repo" "$repo/src/z.ts"
[ "$(status_of task-implementer "$repo/pipeline-state.json")" = running ] && pass "sdd_lock rompe un lock huérfano (> 60 s)" || bad "sdd_lock no rompió el lock huérfano"
check "lock huérfano liberado" no_lock "$repo/pipeline-state.json"
reset_state pipeline-state.pending.json
mkdir -p "$repo/pipeline-state.json.lock"
h3 "SDD_LOCK_RETRIES=3" "$repo" "$repo/src/z.ts"
[ "$(status_of task-implementer "$repo/pipeline-state.json")" = pending ] && pass "lock vivo: H3 desiste sin escribir (exit 0)" || bad "lock vivo: H3 escribió igualmente"
[ -d "$repo/pipeline-state.json.lock" ] && pass "lock vivo no se rompe" || bad "lock vivo fue eliminado"
rmdir "$repo/pipeline-state.json.lock"

# ---------------------------------------------------------------- 14. sin jq (PATH mínimo con node)
bin="$tmp/bin"; mkdir -p "$bin"
for b in bash sh git node dirname basename date stat mkdir rmdir mv rm cat head tr sleep kill sed ls cp touch env uname xcrun; do
  src=$(command -v "$b" 2>/dev/null) || continue
  ln -s "$src" "$bin/$b"
done
if PATH="$bin" git --version >/dev/null 2>&1 && PATH="$bin" node --version >/dev/null 2>&1; then
  reset_state pipeline-state.impl-running.json
  out=$(guard_out "PATH=$bin SDD_ROLE=sdd-spec" "$repo" Write "$repo/src/x.ts")
  contains "$out" "no posee" && pass "sin jq: H2 deniega por owns (fallback node)" || bad "sin jq: H2 rol: $out"
  [ "$(guard "PATH=$bin" "$wt" Write "$wt/spec/x.md")" = deny ] && pass "sin jq: H2 desde worktree deniega spec/x.md" || bad "sin jq: H2 worktree"
  reset_state pipeline-state.pending.json
  h3 "PATH=$bin" "$wt" "$wt/audits/SECURITY-AUDIT.md"
  [ "$(status_of security-auditor "$repo/pipeline-state.json")" = running ] && pass "sin jq: H3 crea security-auditor en el principal" || bad "sin jq: H3 no actualizó"
  check "sin jq: H3 no deja .lock" no_lock "$repo/pipeline-state.json"
  out=$(h1 "PATH=$bin SDD_ROLE=sdd-spec" "$wt")
  if contains "$out" "RUNNING: security-auditor" && contains "$out" "Rol: sdd-spec (posee: spec/*"; then pass "sin jq: H1 contexto + rol"; else bad "sin jq: H1: $out"; fi
  out=$(printf '{"cwd":"%s"}' "$wt" | PATH="$bin" SDD_ROLE=sdd-plan bash "$STATUS_LINE" 2>/dev/null || true)
  [ "$out" = "[sdd-plan] SDD [0/7] sec" ] && pass "sin jq: statusLine con rol y stage fuera de las 7 (sec)" || bad "sin jq: statusLine: '$out'"
  rm -f "$repo/.sdd/trace-map.json"
  h9 "PATH=$bin" "$wt" "$wt/src/nojq.ts"
  check "sin jq: H9 traza con stream/role" jq -e '.mappings[0] | .file == "src/nojq.ts" and .stream == "A"' "$tm"
else
  echo "skip sin jq: git/node no operativos con PATH mínimo en esta máquina"
fi

# ---------------------------------------------------------------- 15. H10 activity log (.sdd/activity.jsonl) + sdd-watch.sh
ACT_HOOK="$HOOKS/sdd-activity-log.sh"
WATCH="$ROOT/scripts/sdd-watch.sh"
check "bash -n sdd-watch.sh" bash -n "$WATCH"
# h10 ENV json  → alimenta el hook con el JSON tal cual
h10() {
  local envs="$1" json="$2"
  # shellcheck disable=SC2086
  printf '%s' "$json" | env $envs bash "$ACT_HOOK" 2>/dev/null
}
# ev cwd session event extra-json(",k":v...)
ev() { printf '{"session_id":"%s","cwd":"%s","hook_event_name":"%s"%s}' "$2" "$1" "$3" "${4:-}"; }
act="$tmp/act"; git init -q "$act" && git -C "$act" commit -q --allow-empty -m init
cp "$FIX/pipeline-state.impl-running.json" "$act/pipeline-state.json"
mkdir -p "$act/.sdd"; cp "$FIX/current-task.json" "$act/.sdd/current-task.json"
alog="$act/.sdd/activity.jsonl"
h10 "" "$(ev "$act" a1a1a1a1-0001 SessionStart ',"source":"startup"')"
h10 "SDD_ROLE=sdd-spec" "$(ev "$act" a1a1a1a1-0001 PreToolUse ',"tool_name":"Skill","tool_input":{"skill":"sdd-spec-auditor","args":"--fix"}')"
h10 "" "$(ev "$act" a1a1a1a1-0001 PreToolUse ',"tool_name":"Agent","tool_input":{"subagent_type":"Explore","description":"Buscar usos de X","prompt":"..."}')"
h10 "" "$(ev "$act" a1a1a1a1-0001 SubagentStart ',"agent_id":"agent-1","agent_type":"Explore"')"
h10 "" "$(ev "$act" a1a1a1a1-0001 SubagentStart ',"agent_id":"agent-2","agent_type":"general-purpose"')"
h10 "" "$(ev "$act" a1a1a1a1-0001 SubagentStop ',"agent_id":"agent-2","agent_type":"general-purpose","last_assistant_message":"ok"')"
h10 "" "$(ev "$act" a1a1a1a1-0001 PreToolUse ',"tool_name":"Bash","tool_input":{"command":"ls"}')"
h10 "" "$(ev "$act" b2b2b2b2-0002 UserPromptExpansion ',"expansion_type":"slash_command","command_name":"sdd-task-implementer","command_args":"--fase 1"')"
h10 "" "$(ev "$act" b2b2b2b2-0002 Stop ',"stop_hook_active":false,"last_assistant_message":"done"')"
check "H10 crea <principal>/.sdd/activity.jsonl" test -f "$alog"
check "H10 activity.jsonl: JSON válido línea a línea" jq -e . "$alog"
check "H10 no deja .lock" no_lock "$alog"
[ "$(wc -l < "$alog" | tr -d ' ')" = 8 ] && pass "H10 8 líneas (PreToolUse Bash no se registra)" || bad "H10 líneas: $(wc -l < "$alog")"
check "H10 session-start: session(8), role -, cwd ., stage running, task del breadcrumb, source" \
  jq -e -s '.[0] | .event == "session-start" and .session == "a1a1a1a1" and .role == "-" and .cwd == "." and .stage == "task-implementer" and .task == "TASK-F1-003" and .source == "startup" and (.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))' "$alog"
check "H10 skill-start (PreToolUse Skill): skill, args, via=tool, role SDD_ROLE" \
  jq -e -s '.[1] | .event == "skill-start" and .skill == "sdd-spec-auditor" and .args == "--fix" and .via == "tool" and .role == "sdd-spec"' "$alog"
check "H10 agent-start (PreToolUse Agent): agent_type=subagent_type, description" \
  jq -e -s '.[2] | .event == "agent-start" and .agent_type == "Explore" and .description == "Buscar usos de X" and (has("agent_id") | not)' "$alog"
check "H10 subagent-start/stop: agent_id, agent_type" \
  jq -e -s '(.[3] | .event == "subagent-start" and .agent_id == "agent-1" and .agent_type == "Explore") and (.[5] | .event == "subagent-stop" and .agent_id == "agent-2")' "$alog"
check "H10 UserPromptExpansion → skill-start via=prompt (command_name/command_args)" \
  jq -e -s '.[6] | .event == "skill-start" and .skill == "sdd-task-implementer" and .args == "--fase 1" and .via == "prompt" and .session == "b2b2b2b2"' "$alog"
check "H10 stop: sin campos de tool" jq -e -s '.[7] | .event == "stop" and (has("skill") | not)' "$alog"
# desde un worktree: se escribe en el principal, cwd absoluto (fuera de STATE_ROOT), task del worktree
awt="$tmp/act-wt"; git -C "$act" worktree add -q "$awt" >/dev/null 2>&1
mkdir -p "$awt/.sdd"; sed 's/TASK-F1-003/TASK-F1-009/' "$FIX/current-task.json" > "$awt/.sdd/current-task.json"
h10 "" "$(ev "$awt" c3c3c3c3-0003 SubagentStart ',"agent_id":"agent-3","agent_type":"Plan"')"
[ ! -e "$awt/.sdd/activity.jsonl" ] && pass "H10 desde worktree NO crea activity.jsonl en el worktree" || bad "H10 creó activity.jsonl en el worktree"
check "H10 desde worktree: línea en el principal con cwd absoluto y task del worktree" \
  jq -e -s --arg wt "$awt" '.[8] | .event == "subagent-start" and .cwd == $wt and .task == "TASK-F1-009"' "$alog"
# proyectos sin SDD: ni .sdd/ ni pipeline-state.json → no se escribe nada
plain="$tmp/plain"; git init -q "$plain" && git -C "$plain" commit -q --allow-empty -m init
h10 "" "$(ev "$plain" e9e9e9e9-0009 Stop '')"
h10 "" "$(ev "$nogit" e9e9e9e9-0009 SubagentStart ',"agent_id":"a","agent_type":"Explore"')"
[ ! -e "$plain/.sdd" ] && [ ! -e "$nogit/.sdd" ] && pass "H10 sin .sdd/ ni pipeline-state.json no escribe nada" || bad "H10 escribió en un proyecto sin SDD"
# entrada rota / vacía → exit 0
printf '{not json' | bash "$ACT_HOOK" >/dev/null 2>&1 && pass "H10 JSON roto → exit 0" || bad "H10 JSON roto falla"
printf '' | bash "$ACT_HOOK" >/dev/null 2>&1 && pass "H10 stdin vacío → exit 0" || bad "H10 stdin vacío falla"
# sdd-watch.sh --once
wout=$(bash "$WATCH" --once --root "$act" 2>&1) && pass "sdd-watch --once exit 0" || bad "sdd-watch --once falla: $wout"
contains "$wout" "/sdd-spec-auditor --fix" && pass "sdd-watch muestra la skill en curso (skill-start sin stop)" || bad "sdd-watch sin skill en curso: $wout"
contains "$wout" "sdd-task-implementer" && ! contains "$wout" "skill  /sdd-task-implementer" && pass "sdd-watch: skill cerrada por stop no aparece en Ahora (sí en Actividad)" || bad "sdd-watch: skill cerrada por stop: $wout"
contains "$wout" "2 activo(s)" && pass "sdd-watch: 2 subagentes activos (agent-1 y agent-3; agent-2 parado)" || bad "sdd-watch agentes: $wout"
asec=$(printf '%s\n' "$wout" | awk '/^Agentes/{f=1; next} /^Sesiones/{f=0} f')   # solo la sección Agentes
contains "$asec" "agent-1" && contains "$asec" "Buscar usos de X" && contains "$asec" "agent-3" && ! contains "$asec" "agent-2" && pass "sdd-watch: agentes activos con descripción del agent-start previo; agent-2 (parado) fuera" || bad "sdd-watch agente activo: $asec"
contains "$wout" "6/7 done" && contains "$wout" "etapa  task-implementer" && pass "sdd-watch: Pipeline N/7 y etapa running" || bad "sdd-watch pipeline: $wout"
contains "$wout" "TASK-F1-003" && contains "$wout" "TASK-F1-009" && pass "sdd-watch: task del principal y del worktree" || bad "sdd-watch tasks: $wout"
contains "$wout" "example-lead" && contains "$wout" "skipped:lead-absent" && pass "sdd-watch: handoffs (to, result)" || bad "sdd-watch handoffs: $wout"
printf '# Questions — sdd-spec\n\n## Q-sdd-spec-001 [OPEN] skill=x context=y\nQuestion: ?\nAnswer:\n\n## Q-sdd-spec-002 [ANSWERED] skill=x context=y\nAnswer: A\n' > "$act/.sdd/questions-sdd-spec.md"
wout=$(bash "$WATCH" --once --root "$act" 2>&1) || true
contains "$wout" "questions-sdd-spec.md" && contains "$wout" "1 [OPEN]" && pass "sdd-watch: preguntas [OPEN] por fichero" || bad "sdd-watch preguntas: $wout"
wout=$(bash "$WATCH" --once --root "$nogit" 2>&1) && contains "$wout" "sin actividad registrada" && contains "$wout" "sin pipeline-state.json" && pass "sdd-watch sin SDD: exit 0 y 'sin actividad registrada'" || bad "sdd-watch sin SDD: $wout"
# rotación > 5 MB → activity.1.jsonl
mv "$alog" "$tmp/alog.bak"
awk 'BEGIN { for (i = 0; i < 100000; i++) print "{\"ts\":\"2026-01-01T00:00:00Z\",\"event\":\"stop\",\"session\":\"a1a1a1a1\"}" }' > "$alog"   # ~5,9 MB (sin `yes | head`: SIGPIPE + pipefail)
h10 "" "$(ev "$act" a1a1a1a1-0001 Stop '')"
[ -f "$act/.sdd/activity.1.jsonl" ] && [ "$(wc -l < "$alog" | tr -d ' ')" = 1 ] && pass "H10 rota activity.jsonl → activity.1.jsonl al superar 5 MB" || bad "H10 no rotó"
check "H10 tras rotar: JSON válido" jq -e . "$alog"
mv "$tmp/alog.bak" "$alog"; rm -f "$act/.sdd/activity.1.jsonl"
# sin jq (PATH mínimo con node): hook y watch por node
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  h10 "PATH=$bin SDD_ROLE=sdd-plan" "$(ev "$act" d4d4d4d4-0004 SubagentStart ',"agent_id":"agent-4","agent_type":"Explore"')"
  check "sin jq: H10 escribe la línea con node (role, stage, task)" \
    jq -e -s 'last | .event == "subagent-start" and .agent_id == "agent-4" and .role == "sdd-plan" and .stage == "task-implementer" and .task == "TASK-F1-003"' "$alog"
  wout=$(PATH="$bin" bash "$WATCH" --once --root "$act" 2>&1) && contains "$wout" "3 activo(s)" && contains "$wout" "/sdd-spec-auditor --fix" && contains "$wout" "6/7 done" && pass "sin jq: sdd-watch --once por node" || bad "sin jq: sdd-watch: $wout"
  wout2=$(bash "$WATCH" --once --root "$act" 2>&1) || true
  # misma salida salvo la cabecera (hora) y las duraciones (la pasada con node tarda ~1 s más)
  wnorm() { grep -v '^SDD watch' | sed -E 's/[0-9]+h [0-9]{2}m/DUR/g; s/[0-9]+m [0-9]{2}s/DUR/g; s/ [0-9]+s$/ DUR/; s/ [0-9]+s  / DUR  /g'; }
  [ "$(printf '%s\n' "$wout" | wnorm)" = "$(printf '%s\n' "$wout2" | wnorm)" ] && pass "sdd-watch: salida idéntica con jq y con node (salvo hora/duraciones)" || bad "sdd-watch: jq y node difieren: $(diff <(printf '%s\n' "$wout" | wnorm) <(printf '%s\n' "$wout2" | wnorm) 2>&1 | head -5)"
else
  echo "skip sin jq (H10/watch): node no operativo con PATH mínimo"
fi
git -C "$act" worktree remove --force "$awt" >/dev/null 2>&1 || true


# 16. subagentStatusLine del plugin: una fila JSON por subagente con tipo, descripción, tiempo y tokens
sub_out=$(printf '{"columns":80,"tasks":[{"id":"t1","name":"general-purpose","status":"running","description":"Audit spec/domain (DOM)","startTime":%d,"tokenCount":31450,"contextWindowSize":200000}]}' "$(( $(date +%s) * 1000 - 65000 ))" | bash "$ROOT/scripts/sdd-subagent-status.sh")
if printf '%s' "$sub_out" | jq -e 'select(.id=="t1") | .content | test("general-purpose · Audit spec/domain \\(DOM\\) · 1m[0-9]+s · 31k tok \\(15%\\)")' >/dev/null 2>&1; then pass "subagent-status: fila con tipo, descripción, tiempo y tokens"; else bad "subagent-status: $sub_out"; fi
[ -z "$(printf '' | bash "$ROOT/scripts/sdd-subagent-status.sh")" ] && pass "subagent-status: sin entrada no imprime" || bad "subagent-status: imprime sin entrada"


# 17. activity-log marca la etapa running al arrancar su skill (las skills escriben con Bash, H3 solo ve Write)
act2="$(mktemp -d)"; ( cd "$act2" && git init -q . )
printf '{"sddVersion":"t","hooksVersion":3,"currentStage":"requirements-engineer","stages":{"requirements-engineer":{"status":"done"}}}' > "$act2/pipeline-state.json"
mkdir -p "$act2/.sdd"
printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"sdd-pipeline:sdd-spec-auditor","args":"audit"}}' "$act2" | bash "$HOOKS/sdd-activity-log.sh"
if [ "$(jq -r '.stages["spec-auditor"].status' "$act2/pipeline-state.json")" = running ] && [ "$(jq -r .currentStage "$act2/pipeline-state.json")" = spec-auditor ]; then pass "activity-log: marca la etapa running al arrancar la skill"; else bad "activity-log: etapa no marcada ($(jq -c .stages "$act2/pipeline-state.json"))"; fi
[ "$(jq -r '.stages["requirements-engineer"].status' "$act2/pipeline-state.json")" = "done" ] && pass "activity-log: no toca otras etapas" || bad "activity-log: pisó otra etapa"
printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"sdd-pipeline:sdd-pipeline-status"}}' "$act2" | bash "$HOOKS/sdd-activity-log.sh"
[ "$(jq -r .currentStage "$act2/pipeline-state.json")" = spec-auditor ] && pass "activity-log: una skill de solo lectura no cambia la etapa" || bad "activity-log: pipeline-status cambió la etapa"
rm -rf "$act2"

[ "$fail" -eq 0 ] && echo "tests/hooks: todo ok" || { echo "tests/hooks: hay fallos"; exit 1; }
