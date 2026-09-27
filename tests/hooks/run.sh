#!/usr/bin/env bash
# Tests de los hooks del plugin (dos raíces + lock + SDD_ROLE) y del hook git commit-msg (vía node vendorizada y bash).
# Cada test alimenta el JSON de stdin que Claude Code enviaría y comprueba la salida/efectos.
# Fixtures reproducibles en mktemp -d; HOME se aísla para no leer ~/.claude/sessions reales.
# Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere git, jq y node.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$ROOT/hooks"
LIB="$HOOKS/lib/sdd-common.sh"
FIX="$ROOT/tests/hooks/fixtures"
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
# Sin git, sdd_roots cae a $PWD: ejecutar desde $tmp evita leer un pipeline-state.json que los hooks
# del propio plugin hayan dejado en la raíz del repo (p. ej. al escribir en tests/).
cd "$tmp"

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
# skill_start ENV cwd skill → PreToolUse Skill (Claude invoca la skill)
skill_start() {
  local envs="$1" cwd="$2" skill="$3"
  # shellcheck disable=SC2086
  printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"%s","args":"x"}}' "$cwd" "$skill" \
    | env $envs bash "$HOOKS/sdd-pipeline-state-updater.sh" 2>/dev/null
}
# prompt_expand ENV cwd command_name → UserPromptExpansion (el humano teclea /skill)
prompt_expand() {
  local envs="$1" cwd="$2" cmd="$3"
  # shellcheck disable=SC2086
  printf '{"session_id":"t","cwd":"%s","hook_event_name":"UserPromptExpansion","expansion_type":"slash_command","command_name":"%s","command_args":"","prompt":"/%s"}' "$cwd" "$cmd" "$cmd" \
    | env $envs bash "$HOOKS/sdd-pipeline-state-updater.sh" 2>/dev/null
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
for f in "$HOOKS"/*.sh "$HOOKS"/lib/*.sh "$ROOT/tests/hooks/run.sh"; do
  check "bash -n $(basename "$f")" bash -n "$f"
done
check "node --check sdd-augment-hook.js" node --check "$HOOKS/sdd-augment-hook.js"
check "templates/sdd-sessions.example.json es sdd-sessions-v1" jq -e '."$schema" == "sdd-sessions-v1" and (.roles | has("sdd-lead","sdd-spec","sdd-plan","impl-f1a","sdd-qa"))' "$TEMPLATE"

# ---------------------------------------------------------------- 2. sin pipeline (directorio sin git)
nogit="$tmp/nogit"; mkdir -p "$nogit"
out=$(h1 "" "$nogit")
[ -z "$out" ] && pass "H1 sin pipeline, sin .sdd/ y sin rol: silencio" || bad "H1 sin pipeline: $out"
[ "$(guard "" "$nogit" Write "$nogit/spec/x.md")" = allow ] && pass "H2 sin pipeline-state permite" || bad "H2 sin pipeline-state deniega"
start=$(date +%s)
if printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s/a.md"}}' "$nogit" "$nogit" | CLAUDE_PROJECT_DIR="$nogit" node "$HOOKS/sdd-augment-hook.js" >/dev/null 2>&1; then pass "H5 sin grafo (exit 0, $(( $(date +%s) - start ))s)"; else bad "H5 sin grafo falla"; fi

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
[ "$(guard "SDD_ROLE=sdd-spec SDD_STATE_ROOT=$tmp/nogit" "$repo" Write "$repo/src/x.ts")" = deny ] && pass "SDD_STATE_ROOT fuera del repositorio se ignora (registro del repo → deny 'no posee')" || bad "SDD_STATE_ROOT ajeno sigue mandando"

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
  reset_state pipeline-state.pending.json
  skill_start "PATH=$bin" "$wt" "sdd-pipeline:sdd-plan-architect"
  [ "$(status_of plan-architect "$repo/pipeline-state.json")" = running ] && pass "sin jq: H3 skill-start marca plan-architect en el principal (fallback node)" || bad "sin jq: H3 skill-start"
else
  echo "skip sin jq: git/node no operativos con PATH mínimo en esta máquina"
fi

# ---------------------------------------------------------------- 15. H3 marca la etapa running al arrancar su skill
# Las skills escriben a menudo con Bash (heredocs en `claude -p`), que PostToolUse Write no ve: el
# arranque de la skill (PreToolUse Skill o /comando tecleado → UserPromptExpansion) marca su etapa.
ss="$tmp/skillstart"; git init -q "$ss"
ss_state() { printf '{"sddVersion":"t","hooksVersion":3,"currentStage":"requirements-engineer","stages":{"requirements-engineer":{"status":"done","summary":{"nextStep":"x"}},"test-planner":{"status":"done"}}}' > "$ss/pipeline-state.json"; }
ss_state
skill_start "" "$ss" "sdd-pipeline:sdd-spec-auditor"
if [ "$(status_of spec-auditor "$ss/pipeline-state.json")" = running ] && [ "$(jq -r .currentStage "$ss/pipeline-state.json")" = spec-auditor ]; then
  pass "H3 PreToolUse Skill sdd-pipeline:sdd-spec-auditor marca spec-auditor running"
else bad "H3 skill-start: etapa no marcada ($(jq -c .stages "$ss/pipeline-state.json"))"; fi
[ "$(status_of requirements-engineer "$ss/pipeline-state.json")" = "done" ] && [ "$(jq -r '.stages["requirements-engineer"].summary.nextStep' "$ss/pipeline-state.json")" = x ] \
  && pass "H3 skill-start no toca otras etapas ni su summary" || bad "H3 skill-start pisó otra etapa"
prompt_expand "" "$ss" "sdd-test-planner"
[ "$(status_of test-planner "$ss/pipeline-state.json")" = running ] && [ "$(jq -r .currentStage "$ss/pipeline-state.json")" = test-planner ] \
  && pass "H3 UserPromptExpansion /sdd-test-planner marca test-planner running (done → running: re-ejecución)" || bad "H3 UserPromptExpansion: $(jq -c .stages "$ss/pipeline-state.json")"
prompt_expand "" "$ss" "/sdd-pipeline:sdd-acceptance"
[ "$(status_of acceptance "$ss/pipeline-state.json")" = running ] && pass "H3 /sdd-pipeline:sdd-acceptance crea y marca la etapa acceptance" || bad "H3 sdd-acceptance no marcada"
jq '.stages["plan-architect"] = {status: "error"}' "$ss/pipeline-state.json" > "$ss/x.json" && mv "$ss/x.json" "$ss/pipeline-state.json"
skill_start "" "$ss" "sdd-plan-architect"
[ "$(status_of plan-architect "$ss/pipeline-state.json")" = error ] && pass "H3 skill-start no toca una etapa en error" || bad "H3 skill-start cambió error"
before=$(cat "$ss/pipeline-state.json")
skill_start "" "$ss" "sdd-pipeline:sdd-pipeline-status"
prompt_expand "" "$ss" "compact"
skill_start "" "$ss" "other-plugin:sdd-spec-auditor-extra"
[ "$(cat "$ss/pipeline-state.json")" = "$before" ] && pass "H3 skill desconocida o de solo lectura: no-op (ni lastUpdated)" || bad "H3 skill desconocida cambió el estado"
check "H3 skill-start no deja .lock" no_lock "$ss/pipeline-state.json"
ssn="$tmp/skillstart-nostate"; git init -q "$ssn"
rc=0; skill_start "" "$ssn" "sdd-pipeline:sdd-spec-auditor" || rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$ssn/pipeline-state.json" ] && [ ! -d "$ssn/.sdd" ] && pass "H3 skill-start sin pipeline-state.json: no-op, exit 0, no crea nada" || bad "H3 skill-start sin estado (rc=$rc)"
printf 'not json' | bash "$HOOKS/sdd-pipeline-state-updater.sh" >/dev/null 2>&1 && pass "H3 entrada rota: exit 0" || bad "H3 entrada rota: exit != 0"
printf '' | bash "$HOOKS/sdd-pipeline-state-updater.sh" >/dev/null 2>&1 && pass "H3 entrada vacía: exit 0" || bad "H3 entrada vacía: exit != 0"
# desde un worktree: la etapa se marca en el estado del checkout principal
reset_state pipeline-state.pending.json
skill_start "" "$wt" "sdd-pipeline:sdd-task-generator"
[ "$(status_of task-generator "$repo/pipeline-state.json")" = running ] && [ ! -e "$wt/pipeline-state.json" ] && pass "H3 skill-start desde worktree: marca en el principal" || bad "H3 skill-start desde worktree"
unset -f ss_state

# ---------------------------------------------------------------- 19. SDD Stack Profile (CLAUDE.md): app en web/ y Minitest en la raíz
# prof DIR KEY → sdd_profile_get con PROJECT_DIR=STATE_ROOT=DIR
prof() { bash -c '. "$1"; PROJECT_DIR="$2"; STATE_ROOT="$2"; sdd_profile_get "$3"' _ "$LIB" "$1" "$2" 2>/dev/null || echo "error"; }
# codep DIR REL → yes | no (sdd_is_code_path)
codep() { if bash -c '. "$1"; PROJECT_DIR="$2"; STATE_ROOT="$2"; sdd_is_code_path "$3"' _ "$LIB" "$1" "$2" 2>/dev/null; then echo yes; else echo no; fi; }
rweb="$tmp/rweb"; git init -q "$rweb" && git -C "$rweb" commit -q --allow-empty -m init
cp "$FIX/CLAUDE.rails-web.md" "$rweb/CLAUDE.md"
rroot="$tmp/rroot"; git init -q "$rroot" && git -C "$rroot" commit -q --allow-empty -m init
cp "$FIX/CLAUDE.rails-root.md" "$rroot/CLAUDE.md"
rcrlf="$tmp/rcrlf"; mkdir -p "$rcrlf/.claude"
printf '# Proyecto\n\nSin perfil en el CLAUDE.md raíz.\n' > "$rcrlf/CLAUDE.md"
awk '{ printf "%s\r\n", $0 }' "$FIX/CLAUDE.rails-web.md" > "$rcrlf/.claude/CLAUDE.md"

[ "$(prof "$rweb" app_dir)" = web ] && pass "sdd_profile_get app_dir=web (ignora el perfil de ejemplo dentro de \`\`\`)" || bad "sdd_profile_get app_dir: '$(prof "$rweb" app_dir)'"
[ "$(prof "$rweb" test_name)" = 'bin/rails test {} -n "/{name}/"' ] && pass "sdd_profile_get: valor con {}, comillas y :" || bad "sdd_profile_get test_name: '$(prof "$rweb" test_name)'"
[ "$(prof "$rweb" install)" = 'cd web && bundle install && bin/rails db:prepare' ] && pass "sdd_profile_get: valor con &&" || bad "sdd_profile_get install: '$(prof "$rweb" install)'"
[ "$(prof "$rweb" acceptance)" = 'bin/rails test:system && echo "done: ok"' ] && pass "sdd_profile_get: el valor sigue a los PRIMEROS ':'" || bad "sdd_profile_get acceptance: '$(prof "$rweb" acceptance)'"
[ -z "$(prof "$rweb" build)" ] && [ -z "$(prof "$rweb" nope)" ] && pass "sdd_profile_get: clave vacía o ausente → nada" || bad "sdd_profile_get vacío/ausente"
[ "$(prof "$rweb" stack)" = rails ] && [ -z "$(prof "$rweb" after_section)" ] && pass "sdd_profile_get: la sección termina en el siguiente '## '" || bad "sdd_profile_get lee fuera de la sección"
[ "$(prof "$rcrlf" app_dir)" = web ] && [ "$(prof "$rcrlf" test_name)" = 'bin/rails test {} -n "/{name}/"' ] && pass "sdd_profile_get: CRLF y .claude/CLAUDE.md cuando el raíz no tiene sección" || bad "sdd_profile_get CRLF: '$(prof "$rcrlf" app_dir | od -c | head -2)'"
[ -z "$(prof "$nogit" app_dir)" ] && pass "sdd_profile_get sin CLAUDE.md → nada" || bad "sdd_profile_get sin CLAUDE.md"
okc=1
for spec in "$rweb web/app/models/task.rb yes" "$rweb web/lib/x.rb yes" "$rweb web/config/routes.rb yes" "$rweb web/db/schema.rb yes" "$rweb web/test/models/x_test.rb yes" \
            "$rweb web/application.rb no" "$rweb src/x.ts no" "$rroot test/models/x_test.rb yes" "$rroot app/models/x.rb yes" \
            "$nogit src/x.ts yes" "$nogit tests/x.test.ts yes" "$nogit test/models/x_test.rb no" "$nogit /etc/hosts no"; do
  set -- $spec
  [ "$(codep "$1" "$2")" = "$3" ] || { okc=0; echo "     sdd_is_code_path $2 en $(basename "$1"): esperaba $3"; }
done
set --
[ "$okc" = 1 ] && pass "sdd_is_code_path: entradas recortadas, sin prefijos parciales, defaults src/tests sin perfil" || bad "sdd_is_code_path"

# H3: la implementación en web/ y en test/<subdir> se registra como task-implementer
cp "$FIX/pipeline-state.pending.json" "$rweb/pipeline-state.json"
h3 "" "$rweb" "$rweb/web/app/models/task.rb"
[ "$(status_of task-implementer "$rweb/pipeline-state.json")" = running ] && pass "H3 perfil web: web/app/models/task.rb → task-implementer" || bad "H3 perfil web no mapeó web/app/models/task.rb"
cp "$FIX/pipeline-state.pending.json" "$rroot/pipeline-state.json"
h3 "" "$rroot" "$rroot/test/TEST-PLAN.md"
[ "$(status_of test-planner "$rroot/pipeline-state.json")" = running ] && [ "$(status_of task-implementer "$rroot/pipeline-state.json")" = pending ] && pass "H3 perfil raíz: test/TEST-PLAN.md sigue siendo de test-planner" || bad "H3 perfil raíz: test/TEST-PLAN.md mal mapeado"
h3 "" "$rroot" "$rroot/test/models/x_test.rb"
[ "$(status_of task-implementer "$rroot/pipeline-state.json")" = running ] && pass "H3 perfil raíz: test/models/x_test.rb → task-implementer" || bad "H3 perfil raíz no mapeó test/models/x_test.rb"
check "H3 perfil: no deja .lock" no_lock "$rroot/pipeline-state.json"

# H2: task-implementer running
cp "$FIX/pipeline-state.impl-running.json" "$rweb/pipeline-state.json"
cp "$FIX/pipeline-state.impl-running.json" "$rroot/pipeline-state.json"
[ "$(guard "" "$rweb" Write "$rweb/web/test/models/x_test.rb")" = allow ] && pass "H2 perfil web: permite web/test/models/x_test.rb" || bad "H2 perfil web deniega web/test/models/x_test.rb"
[ "$(guard "" "$rweb" Write "$rweb/test/models/x_test.rb")" = deny ] && pass "H2 perfil web: test/models/x_test.rb (no declarado) sigue denegado" || bad "H2 perfil web permite test/ no declarado"
[ "$(guard "" "$rroot" Write "$rroot/test/models/x_test.rb")" = allow ] && pass "H2 perfil raíz: permite test/models/x_test.rb (test_paths: test)" || bad "H2 perfil raíz deniega test/models/x_test.rb"
[ "$(guard "" "$rroot" Edit "$rroot/test/test_helper.rb")" = allow ] && pass "H2 perfil raíz: permite test/test_helper.rb" || bad "H2 perfil raíz deniega test/test_helper.rb"
for p in test/TEST-PLAN.md test/TEST-MATRIX-UC-001.md spec/x.md plan/p.md; do
  [ "$(guard "" "$rroot" Write "$rroot/$p")" = deny ] && pass "H2 perfil raíz: $p sigue protegido" || bad "H2 perfil raíz permite $p"
done
[ "$(guard "" "$rroot" Write "$rroot/task/TASK-FASE-1.md")" = deny ] && [ "$(guard "" "$rroot" Edit "$rroot/task/TASK-FASE-1.md")" = allow ] && pass "H2 perfil raíz: excepción task/TASK-FASE-*.md intacta" || bad "H2 perfil raíz: excepción TASK-FASE rota"
reset_state pipeline-state.impl-running.json
[ "$(guard "" "$repo" Write "$repo/test/models/x_test.rb")" = deny ] && pass "H2 sin perfil: test/models/x_test.rb sigue denegado (compatibilidad 4.2)" || bad "H2 sin perfil permite test/models/x_test.rb"
jq '.stages["task-implementer"].status = "pending" | .stages["task-generator"].status = "running"' "$FIX/pipeline-state.impl-running.json" > "$rroot/pipeline-state.json"
[ "$(guard "" "$rroot" Write "$rroot/test/models/x_test.rb")" = deny ] && pass "H2 perfil raíz: con task-generator running test/ sigue protegido" || bad "H2 perfil raíz: task-generator puede escribir test/"

# H5: el grafo con codeRefs relativos a app_dir casa con la ruta real web/...
mkdir -p "$rweb/dashboard" "$rroot/dashboard"
graph='{"artifacts":[{"id":"REQ-TSK-001","type":"REQ","title":"Tareas","codeRefs":[{"file":"./app/models/task.rb","symbol":"Task"}]}],"relationships":[]}'
printf '%s' "$graph" > "$rweb/dashboard/traceability-graph.json"
printf '%s' "$graph" > "$rroot/dashboard/traceability-graph.json"
out=$(pre_json "$rweb" Read "$rweb/web/app/models/task.rb" | node "$HOOKS/sdd-augment-hook.js" 2>/dev/null || true)
contains "$out" "REQ-TSK-001" && pass "H5 perfil web: quita el prefijo app_dir/ al mapear rutas" || bad "H5 perfil web: '$out'"
out=$(pre_json "$rroot" Read "$rroot/web/app/models/task.rb" | node "$HOOKS/sdd-augment-hook.js" 2>/dev/null || true)
contains "$out" "REQ-TSK-001" && bad "H5 sin app_dir casa web/app/... con app/..." || pass "H5 sin app_dir (app_dir .) no quita prefijos"

# ---------------------------------------------------------------- 20. H12 tool guard: consentimiento humano fabricado (PreToolUse Bash)
TOOL_GUARD="$HOOKS/sdd-tool-guard.sh"
# tg ENV cwd command → deny | allow | error(rc)
tg_out() {
  local envs="$1" cwd="$2" cmd="$3"
  # shellcheck disable=SC2086
  jq -cn --arg cwd "$cwd" --arg c "$cmd" '{session_id:"t",cwd:$cwd,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' \
    | env $envs bash "$TOOL_GUARD" 2>/dev/null
}
tg() {
  local out rc=0
  out=$(tg_out "$1" "$2" "$3") || rc=$?
  [ "$rc" -eq 0 ] || { echo "error($rc)"; return 0; }
  if contains "$out" '"permissionDecision":"deny"'; then echo deny; elif contains "$out" '"permissionDecision":"ask"'; then echo ask; elif [ -z "$out" ]; then echo allow; else echo "raro: $out"; fi
}
okd=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = deny ] || { okd=0; echo "     no deniega: $c"; }
done <<'EOF'
PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION="x" npx prisma migrate reset
export PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=x
env PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=x npx prisma migrate reset --force
cd web && PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=yes npx prisma db push
FOO_AI_CONSENT=1 npm test
SOME_CONSENT_FOR_AI_AGENT=yes ./bin/reset
echo "${PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION:=yes}" && npx prisma migrate reset
echo 'PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=yes' >> .env
EOF
[ "$(tg "" "$rroot" "$(printf 'ls\nPRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=1 npx prisma migrate reset')")" = deny ] || { okd=0; echo "     no deniega: multilínea"; }
[ "$okd" = 1 ] && pass "H12 deniega asignaciones de consentimiento IA (prefijo, export, env, \${:=}, dotenv, multilínea, nombres *CONSENT*+AI)" || bad "H12 deja pasar alguna asignación"
oka=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = allow ] || { oka=0; echo "     no permite: $c"; }
done <<'EOF'
grep PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION file
grep -rn "PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=" .
echo "$PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION"
[ "$PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION" = yes ] && echo y
unset PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION
npx prisma migrate deploy
COOKIE_CONSENT=1 npm test
EMAIL_CONSENT=1 npm test
AI_MODEL=x npm test
EOF
[ "$oka" = 1 ] && pass "H12 permite leer/mencionar la variable, migrate deploy y COOKIE_CONSENT/EMAIL_CONSENT (sin token AI)" || bad "H12 bloquea comandos legítimos"
out=$(tg_out "" "$rroot" 'export FOO_AI_CONSENT=1' || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput | .hookEventName == "PreToolUse" and .permissionDecision == "deny"
     and (.permissionDecisionReason | contains("FOO_AI_CONSENT") and contains("human") and contains("RAILS_ENV=test bin/rails db:reset"))' >/dev/null 2>&1; then
  pass "H12 salida deny con hookSpecificOutput y sugerencia db_reset_safe del perfil"
else bad "H12 salida deny: $out"; fi
out=$(tg_out "" "$repo" 'export FOO_AI_CONSENT=1' || true)
contains "$out" "db_reset_safe" && contains "$out" "ask a human" && pass "H12 sin perfil: pide pausar para un humano o declarar db_reset_safe" || bad "H12 sin perfil: $out"
printf '{not json' | bash "$TOOL_GUARD" >/dev/null 2>&1 && pass "H12 JSON roto → exit 0" || bad "H12 JSON roto falla"
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  [ "$(tg "PATH=$bin" "$rroot" 'PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION=1 npx prisma migrate reset')" = deny ] && pass "sin jq: H12 deniega (fallback node)" || bad "sin jq: H12 no deniega"
fi

# ---------------------------------------------------------------- 20b. aceptación: registros humanos (H12 ask, H2 deny)
oks=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = ask ] || { oks=0; echo "     no pregunta: $c"; }
done <<'EOF'
node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" accept record waiver --req REQ-F-001 --by Ana --role PO --reason x --follow-up #12
sdd accept record inspection --req REQ-C-001 --by Ana --role PO --note ok
cd app && node ../scripts/sdd.mjs  accept  record demo --req REQ-F-002 --observed ok --pass true --by A --role QA
git tag -a fase-2-accepted -m "FASE-2 accepted by Ana"
git -C web tag -s requirements-v3 -m "approved"
git tag -d fase-1-accepted
EOF
[ "$oks" = 1 ] && pass "H12 pregunta (ask) ante sdd accept record y tags fase-N-accepted / requirements-vN" || bad "H12 no pregunta ante algún registro de aceptación"
oka=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = allow ] || { oka=0; echo "     no permite: $c"; }
done <<'EOF'
node scripts/sdd.mjs accept --report acceptance/ACCEPTANCE-REPORT.md
sdd gate --mode enforce
git tag -l "fase-*-accepted"
git tag --contains abc123 fase-1-accepted
git tag -a v1.2.0 -m "release"
git log --oneline requirements-v2..HEAD
grep -rn "sdd accept record" skills
echo accepted
EOF
[ "$oka" = 1 ] && pass "H12 permite sdd accept/gate, listar tags de aceptación, otros tags y búsquedas" || bad "H12 pregunta ante comandos que no registran aprobación"
out=$(tg_out "" "$rroot" 'sdd accept record waiver --req REQ-F-001' || true)
if printf '%s' "$out" | jq -e '.hookSpecificOutput | .hookEventName == "PreToolUse" and .permissionDecision == "ask"
     and (.permissionDecisionReason | contains("confirmed") and contains("not a guarantee"))' >/dev/null 2>&1; then
  pass "H12 ask con motivo (confirmación humana, sin prometer garantía)"
else bad "H12 salida ask: $out"; fi
# Formas que usan los skills: $SDD / ${SDD} / "$SDD" / node "$SDD" y nombres de tag con el número en una variable
oks=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = ask ] || { oks=0; echo "     no pregunta: $c"; }
done <<'EOF'
$SDD accept record demo --req REQ-F-002 --ac 1 --observed ok --pass true --by Ana --role PO
node "$SDD" accept record fase-acceptance --fase 1 --result accepted --channel call --by Ana --role PO
node $SDD accept record waiver --req REQ-F-001 --reason x --follow-up #3 --by Ana --role PO
node "${SDD}" accept record measurement --req REQ-NF-001 --metric p95 --observed 120 --op le --threshold 200 --by A --role QA
${SDD} accept record inspection --req REQ-C-001 --note ok --by Ana --role PO
node '$SDD' accept record demo --req REQ-F-002 --observed ok --pass false --by A --role QA
git tag -a "fase-$N-accepted" -F msg.txt
git tag -s "fase-${N}-accepted" -m ok
git tag -a "requirements-v$V" -m ok
EOF
[ "$oks" = 1 ] && pass "H12 pregunta ante \$SDD, \${SDD}, node \"\$SDD\" accept record y tags con variable (fase-\$N-accepted, requirements-v\$V)" || bad "H12 no pregunta ante alguna forma con variable"
oka=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = allow ] || { oka=0; echo "     no permite: $c"; }
done <<'EOF'
node "$SDD" accept --fase 1 --report acceptance/ACCEPTANCE-REPORT.md
$SDD gate --fase 1 --md
node "$SDD" accept measure --req REQ-NF-002 --ac 1 --metric statements --command "npx c8 report" --extract 'All files[^|]*\|\s*([0-9.]+)' --op ge --threshold 90
node "${SDD}" accept --remeasure --fase 1 --report acceptance/ACCEPTANCE-REPORT.md
echo "$SDD_PLUGIN_ROOT accept record"
git tag -l "fase-$N-accepted"
git rev-parse -q --verify "refs/tags/requirements-v$V"
EOF
[ "$oka" = 1 ] && pass "H12 permite \$SDD accept/gate, accept measure y --remeasure (medición por comando), \$SDD_PLUGIN_ROOT y consultar tags con variable" || bad "H12 pregunta de más con variables"
[ "$(tg "" "$rroot" 'node "$SDD" accept record measurement --req REQ-NF-002 --metric statements --observed 91 --op ge --threshold 90 --by Ana --role QA')" = ask ] && pass "H12 sigue preguntando ante accept record measurement (medición humana)" || bad "H12 no pregunta ante accept record measurement"
# F7: el texto entre comillas solo MENCIONA el registro (resúmenes persistidos, echo): no pregunta
oka=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = allow ] || { oka=0; echo "     no permite: $c"; }
done <<'EOF'
jq '.summary="use accept record later"' f
echo "sdd accept record demo"
jq --arg h 'run node "$SDD" accept record after the demo' '.highlights += [$h]' pipeline-state.json > t && mv t pipeline-state.json
bash "$S" note "next: \$SDD accept record fase-acceptance --fase 1"
echo 'git tag -a fase-1-accepted' && echo "git tag -s requirements-v2"
printf '%s\n' "it's the accept record step"
EOF
[ "$oka" = 1 ] && pass "H12 ignora accept record / git tag dentro de cadenas entrecomilladas" || bad "H12 falso positivo con texto entrecomillado"
oks=1
while IFS= read -r c; do
  [ "$(tg "" "$rroot" "$c")" = ask ] || { oks=0; echo "     no pregunta: $c"; }
done <<'EOF'
node "$SDD" accept record demo --req REQ-F-002 --ac 1 --observed "it works" --pass true --by "Ana" --role PO
node '/Users/x/my plugins/scripts/sdd.mjs' accept record inspection --req REQ-C-001 --note ok --by A --role PO
cd app && node "${SDD}" accept record waiver --req REQ-F-001 --reason "x; y" --follow-up '#3' --by A --role PO
echo "recording" && git tag -a "fase-$N-accepted" -m "accepted; by Ana"
if true; then git tag -s requirements-v4 -m ok; fi
EOF
[ "$oks" = 1 ] && pass "H12 sigue preguntando con el token entrecomillado, rutas con espacios y tags tras && / then" || bad "H12 deja de preguntar ante alguna invocación real"
# Los bloques exactos de approval.md (tag requirements-v$V) y sign-off.md (registro y tag fase-$N-accepted)
md_block() { awk -v m="$2" '/^```/ { if (inb) { if (hit) { printf "%s", buf; exit } inb = 0; buf = ""; hit = 0; next } inb = 1; next } inb { buf = buf $0 "\n"; if (index($0, m)) hit = 1 }' "$1"; }
blk=$(md_block "$ROOT/skills/sdd-requirements-engineer/references/approval.md" 'git tag $SIGN "requirements-v$V"')
[ -n "$blk" ] && [ "$(tg "" "$rroot" "$blk")" = ask ] && pass "H12 pregunta ante el bloque de aprobación de approval.md" || bad "H12 no pregunta ante el bloque de approval.md"
blk=$(md_block "$ROOT/skills/sdd-acceptance/references/sign-off.md" 'git tag $SIGN "fase-$N-accepted"')
[ -n "$blk" ] && [ "$(tg "" "$rroot" "$blk")" = ask ] && pass "H12 pregunta ante el bloque de tag de sign-off.md" || bad "H12 no pregunta ante el bloque de tag de sign-off.md"
blk=$(md_block "$ROOT/skills/sdd-acceptance/references/sign-off.md" 'accept record fase-acceptance')
[ -n "$blk" ] && [ "$(tg "" "$rroot" "$blk")" = ask ] && pass "H12 pregunta ante el bloque de registro de sign-off.md" || bad "H12 no pregunta ante el bloque de registro de sign-off.md"
[ "$(tg "" "$rroot" "$(printf '%s_AI_%s=1 sdd accept record waiver' FOO CONSENT)")" = deny ] && pass "H12 consentimiento IA fabricado gana a ask" || bad "H12 consentimiento + accept record no deniega"
[ "$(guard "" "$repo" Write "$repo/acceptance/decisions.jsonl")" = deny ] && pass "H2 deniega Write en acceptance/decisions.jsonl sin stage running" || bad "H2 permite Write en decisions.jsonl"
[ "$(guard "" "$repo" Edit "$repo/acceptance/ACCEPTANCE-REPORT.md")" = deny ] && pass "H2 deniega Edit en acceptance/ACCEPTANCE-REPORT.md" || bad "H2 permite Edit en ACCEPTANCE-REPORT.md"
[ "$(guard "" "$repo" Write "$repo/acceptance/playwright.config.ts")" = allow ] && pass "H2 permite el resto de acceptance/ (suite Playwright)" || bad "H2 deniega acceptance/playwright.config.ts"
contains "$(guard_out "" "$repo" Write "$repo/acceptance/decisions.jsonl")" "accept record" && pass "H2 motivo apunta a sdd accept record" || bad "H2 motivo de decisions.jsonl"

# H1 resume la aceptación de .sdd/acceptance.json (sin él, nada)
acc="$tmp/accsum"; git init -q "$acc"
printf '{"sddVersion":"t","hooksVersion":3,"currentStage":"task-implementer","stages":{"task-implementer":{"status":"done"}}}' > "$acc/pipeline-state.json"
out=$(h1 "" "$acc")
contains "$out" "Acceptance:" && bad "H1 muestra aceptación sin .sdd/acceptance.json" || pass "H1 sin .sdd/acceptance.json no menciona aceptación"
mkdir -p "$acc/.sdd"
printf '{"evaluated_sha":"abcdef1234567","summary":{"must_total":3,"must_verified":2,"must_waived":0,"goal":false,"stale_evidence":1}}' > "$acc/.sdd/acceptance.json"
out=$(h1 "" "$acc")
contains "$out" "Acceptance: Must 2/3 verified (open: /sdd-acceptance --loop), stale evidence 1 @abcdef1" && pass "H1 resume la aceptación y sugiere --loop" || bad "H1 resumen de aceptación: $out"
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  out=$(h1 "PATH=$bin" "$acc")
  contains "$out" "Acceptance: Must 2/3 verified" && pass "sin jq: H1 resume la aceptación (node)" || bad "sin jq: H1 aceptación: $out"
fi

# ---------------------------------------------------------------- 21. regresiones de la revisión (BUG-1..9)
# BUG-1: H3 no crea pipeline-state.json en un repo sin SDD; el guard sigue permitiendo spec/**/*_spec.rb
plain="$tmp/plain"; git init -q "$plain" && git -C "$plain" commit -q --allow-empty -m init
h3 "" "$plain" "$plain/spec/models/user_spec.rb" || true
[ ! -e "$plain/pipeline-state.json" ] && pass "BUG-1 H3 no crea pipeline-state.json en un repo sin SDD" || bad "BUG-1 H3 creó pipeline-state.json"
[ "$(guard "" "$plain" Write "$plain/spec/models/user_spec.rb")" = allow ] && pass "BUG-1 repo sin SDD: el guard permite spec/**/*_spec.rb" || bad "BUG-1 guard deniega en repo sin SDD"
[ ! -d "$plain/.sdd" ] && pass "BUG-1 repo sin SDD: sin .sdd/" || bad "BUG-1 creó .sdd/"

# BUG-2: el stage que aplica es el más downstream; req-change running escribe requirements/ y spec/
b2="$tmp/b2"; git init -q "$b2" && git -C "$b2" commit -q --allow-empty -m init
jq '.stages["requirements-engineer"].status = "running"' "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
[ "$(guard "" "$b2" Write "$b2/spec/x.md")" = deny ] && pass "BUG-2a upstream stuck running + impl running: spec/ sigue denegado" || bad "BUG-2a un stage upstream running desactiva la protección"
out=$(guard_out "" "$b2" Write "$b2/plan/p.md")
contains "$out" "Stage 'task-implementer'" && pass "BUG-2a el deny nombra el stage más downstream" || bad "BUG-2a deny: $out"
jq '.stages["req-change"] = {status: "running"}' "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
[ "$(guard "" "$b2" Write "$b2/requirements/REQUIREMENTS.md")" = allow ] && pass "BUG-2b req-change + impl running: requirements/ permitido" || bad "BUG-2b req-change denegado en requirements/"
[ "$(guard "" "$b2" Edit "$b2/spec/use-cases/UC-001.md")" = allow ] && pass "BUG-2b req-change + impl running: spec/ permitido" || bad "BUG-2b req-change denegado en spec/"
[ "$(guard "" "$b2" Write "$b2/plan/p.md")" = deny ] && pass "BUG-2b req-change no abre plan/ con impl running" || bad "BUG-2b plan/ permitido"
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  jq '.stages["requirements-engineer"].status = "running"' "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
  [ "$(guard "PATH=$bin" "$b2" Write "$b2/spec/x.md")" = deny ] && pass "BUG-2a sin jq: stage más downstream (fallback node)" || bad "BUG-2a sin jq"
fi

# BUG-3: H3 no reabre un stage done; pending/stale → running; la skill explícita sí reabre done
cp "$FIX/pipeline-state.impl-running.json" "$b2/pipeline-state.json"
h3 "" "$b2" "$b2/requirements/REQUIREMENTS.md"
[ "$(status_of requirements-engineer "$b2/pipeline-state.json")" = "done" ] && pass "BUG-3 H3: escribir requirements/ no reabre requirements-engineer done" || bad "BUG-3 H3 reabrió un stage done"
[ "$(jq -r '.stages["requirements-engineer"].summary.handoff.to' "$b2/pipeline-state.json")" = example-lead ] && pass "BUG-3 H3 conserva summary" || bad "BUG-3 H3 alteró summary"
jq '.stages["plan-architect"].status = "stale"' "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
h3 "" "$b2" "$b2/plan/PLAN.md"
[ "$(status_of plan-architect "$b2/pipeline-state.json")" = running ] && pass "BUG-3 H3: stale → running" || bad "BUG-3 H3 no marcó stale → running"
jq '.stages["test-planner"].status = "error"' "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
h3 "" "$b2" "$b2/test/TEST-PLAN.md"
[ "$(status_of test-planner "$b2/pipeline-state.json")" = error ] && pass "BUG-3 H3: error no se toca" || bad "BUG-3 H3 cambió error"
cp "$FIX/pipeline-state.impl-running.json" "$b2/pipeline-state.json"
bash -c '. "$1"; sdd_mark_running "$2" req-change skill' _ "$LIB" "$b2/pipeline-state.json"
[ "$(status_of req-change "$b2/pipeline-state.json")" = running ] && pass "BUG-3 sdd_mark_running skill: crea el stage lateral y lo marca" || bad "BUG-3 sdd_mark_running skill"
bash -c '. "$1"; sdd_mark_running "$2" spec-auditor skill' _ "$LIB" "$b2/pipeline-state.json"
[ "$(status_of spec-auditor "$b2/pipeline-state.json")" = running ] && pass "BUG-3 sdd_mark_running skill: done → running (re-ejecución explícita)" || bad "BUG-3 skill no reabre done"
check "BUG-3 sin .lock tras sdd_mark_running" no_lock "$b2/pipeline-state.json"

# BUG-4: SDD_STATE_ROOT heredado de otro repositorio se ignora; el del mismo repo (worktree) se respeta
cp "$FIX/pipeline-state.impl-running.json" "$b2/pipeline-state.json"
[ "$(guard "SDD_STATE_ROOT=$b2" "$plain" Write "$plain/spec/x.md")" = allow ] && pass "BUG-4 SDD_STATE_ROOT de otro repo no aplica su estado" || bad "BUG-4 SDD_STATE_ROOT ajeno deniega"
h3 "SDD_STATE_ROOT=$b2" "$plain" "$plain/src/a.ts" || true
[ "$(jq -r .lastUpdated "$b2/pipeline-state.json")" = "$(jq -r .lastUpdated "$FIX/pipeline-state.impl-running.json")" ] && pass "BUG-4 H3 no escribe en el estado de otro repo" || bad "BUG-4 H3 tocó el estado ajeno"
reset_state pipeline-state.impl-running.json
[ "$(guard "SDD_STATE_ROOT=$repo" "$wt" Write "$wt/spec/x.md")" = deny ] && pass "BUG-4 SDD_STATE_ROOT del mismo repo (worktree) se respeta" || bad "BUG-4 SDD_STATE_ROOT del mismo repo ignorado"
out=$(h1 "" "$plain")
[ -z "$out" ] && pass "BUG-6 H1 en repo git sin SDD: silencio" || bad "BUG-6 H1 repo sin SDD: $out"

# BUG-5: STATE_ROOT sale del directorio del fichero (directorios de trabajo adicionales)
[ "$(guard "" "$plain" Write "$b2/spec/x.md")" = deny ] && pass "BUG-5 cwd sin SDD, fichero en repo con impl running → deny" || bad "BUG-5 usa el estado del cwd"
[ "$(guard "" "$b2" Write "$plain/spec/x.md")" = allow ] && pass "BUG-5 cwd con impl running, fichero en repo sin SDD → allow" || bad "BUG-5 aplica el estado del cwd a otro repo"

# BUG-6: N/7 cuenta solo las 7 etapas lineales
jq '.stages["task-implementer"].status = "done" | .stages["security-auditor"] = {status: "done"} | .stages["tech-designer"] = {status: "done"}' \
  "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
out=$(h1 "" "$b2")
contains "$out" "7/7 done" && contains "$out" "Next: all complete" && pass "BUG-6 H1: laterales no inflan N/7" || bad "BUG-6 H1: $out"
jq '.stages["security-auditor"] = {status: "done"} | .stages["req-change"] = {status: "running"} | .stages["plan-architect"].status = "stale"' \
  "$FIX/pipeline-state.impl-running.json" > "$b2/pipeline-state.json"
out=$(h1 "" "$b2")
contains "$out" "5/7 done. STALE: plan-architect. RUNNING: task-implementer, req-change. Next: plan-architect" && pass "BUG-6 H1: stale/running en orden de pipeline y Next" || bad "BUG-6 H1 orden: $out"
# Ruta adaptativa: las etapas skipped salen del total ("N/M done, K skipped") y nunca son la siguiente
skip_state='{"sddVersion":"t","hooksVersion":3,"currentStage":"requirements-engineer","stages":{"requirements-engineer":{"status":"done"},"specifications-engineer":{"status":"skipped","skipReason":"6 REQ-F"},"spec-auditor":{"status":"skipped"},"test-planner":{"status":"skipped"},"plan-architect":{"status":"pending"},"task-generator":{"status":"pending"},"task-implementer":{"status":"pending"}}}'
printf '%s' "$skip_state" > "$b2/pipeline-state.json"
out=$(h1 "" "$b2")
contains "$out" "1/4 done, 3 skipped (specifications-engineer, spec-auditor, test-planner). Next: plan-architect" && pass "skipped H1: N/M done, K skipped y Next ignora las saltadas" || bad "skipped H1: $out"
[ "$(bash -c '. "$1"; sdd_stage_summary "$2"' _ "$LIB" "$b2/pipeline-state.json")" = "1|4||||plan-architect|requirements-engineer|specifications-engineer spec-auditor test-planner" ] \
  && pass "skipped sdd_stage_summary: total sin saltadas y lista de saltadas (jq)" || bad "skipped sdd_stage_summary jq"
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  [ "$(PATH="$bin" bash -c '. "$1"; sdd_stage_summary "$2"' _ "$LIB" "$b2/pipeline-state.json")" = "1|4||||plan-architect|requirements-engineer|specifications-engineer spec-auditor test-planner" ] \
    && pass "skipped sdd_stage_summary: igual con el fallback node" || bad "skipped sdd_stage_summary node"
fi
jq '.stages["plan-architect"].status = "done" | .stages["task-generator"].status = "done" | .stages["task-implementer"].status = "done"' "$b2/pipeline-state.json" > "$b2/ps.tmp" && mv "$b2/ps.tmp" "$b2/pipeline-state.json"
out=$(h1 "" "$b2")
contains "$out" "4/4 done, 3 skipped" && contains "$out" "Next: all complete" && pass "skipped H1: todo hecho salvo las saltadas → all complete" || bad "skipped H1 completo: $out"
printf '%s' "$skip_state" > "$b2/pipeline-state.json"
h3 "" "$b2" "$b2/spec/domain/01-glossary.md"
[ "$(status_of specifications-engineer "$b2/pipeline-state.json")" = skipped ] && pass "skipped H3 write: escribir spec/ no reabre una etapa saltada" || bad "skipped H3 write reabrió la saltada"
bash -c '. "$1"; sdd_mark_running "$2" spec-auditor skill' _ "$LIB" "$b2/pipeline-state.json"
[ "$(status_of spec-auditor "$b2/pipeline-state.json")" = running ] && [ "$(jq -r '.stages["spec-auditor"] | has("skipReason")' "$b2/pipeline-state.json")" = false ] \
  && pass "skipped sdd_mark_running skill: la ejecución explícita arranca la saltada" || bad "skipped sdd_mark_running skill"
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  PATH="$bin" bash -c '. "$1"; sdd_mark_running "$2" specifications-engineer skill' _ "$LIB" "$b2/pipeline-state.json"
  [ "$(status_of specifications-engineer "$b2/pipeline-state.json")" = running ] && [ "$(jq -r '.stages["specifications-engineer"] | has("skipReason")' "$b2/pipeline-state.json")" = false ] \
    && pass "skipped sdd_mark_running skill: igual con el fallback node" || bad "skipped sdd_mark_running skill node"
fi
check "skipped sin .lock tras sdd_mark_running" no_lock "$b2/pipeline-state.json"

sdir="$tmp/sddonly"; git init -q "$sdir"; mkdir -p "$sdir/.sdd"
out=$(h1 "" "$sdir")
contains "$out" "No pipeline-state.json" && pass "BUG-6 H1 con .sdd/ y sin estado: sugiere /sdd-setup" || bad "BUG-6 H1 .sdd/: $out"

# BUG-7: augment hook — hookEventName, refs sin file / basename, tope por fichero
aug="$tmp/aug"; git init -q "$aug"; mkdir -p "$aug/dashboard"
cat > "$aug/dashboard/traceability-graph.json" <<'GRAPH'
{"artifacts":[
 {"id":"REQ-F-001","type":"REQ","title":"A","codeRefs":[{"symbol":"nofile"},{"file":"","symbol":"empty"},{"file":"src/x.ts","symbol":"a"}]},
 {"id":"REQ-F-002","type":"REQ","title":"B","codeRefs":[{"file":"src/x.ts","symbol":"b"}]},
 {"id":"REQ-F-003","type":"REQ","title":"C","codeRefs":[{"file":"src/x.ts","symbol":"c"}]},
 {"id":"REQ-F-004","type":"REQ","title":"D","codeRefs":[{"file":"src/x.ts","symbol":"d"}]},
 {"id":"REQ-F-005","type":"REQ","title":"E","codeRefs":[{"file":"index.ts","symbol":"e"}]}],
 "relationships":[{"source":"REQ-F-001"}]}
GRAPH
out=$(pre_json "$aug" Read "$aug/src/x.ts" | node "$HOOKS/sdd-augment-hook.js" 2>/dev/null || true)
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1 && pass "BUG-7 H5 incluye hookEventName PreToolUse" || bad "BUG-7 H5 sin hookEventName: $out"
n=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -c ' implements REQ-F-' || true)
[ "$n" = 2 ] && contains "$out" "and 2 more artifacts" && pass "BUG-7 H5 codeRef sin file no rompe; máximo 2 artefactos por fichero" || bad "BUG-7 H5 tope/robustez ($n): $out"
out=$(pre_json "$aug" Read "$aug/lib/deep/index.ts" | node "$HOOKS/sdd-augment-hook.js" 2>/dev/null || true)
contains "$out" "REQ-F-005" && bad "BUG-7 H5 un ref basename casa con cualquier index.ts" || pass "BUG-7 H5 ref basename no casa con otro directorio"
out=$(pre_json "$aug" Read "$aug/index.ts" | node "$HOOKS/sdd-augment-hook.js" 2>/dev/null || true)
contains "$out" "REQ-F-005" && pass "BUG-7 H5 ref basename casa con el fichero de la raíz" || bad "BUG-7 H5 basename raíz: $out"
out=$(pre_json "$aug" Read "$aug/src/other.ts" | node "$HOOKS/sdd-augment-hook.js" 2>/dev/null || true)
contains "$out" "REQ-F-" && bad "BUG-7 H5 casa un fichero sin refs: $out" || pass "BUG-7 H5 ref vacío no casa con todo"

# BUG-9: commit-msg exime Revert/fixup!/squash!/amend!; lock huérfano roto sin carrera
CM="$HOOKS/sdd-commit-msg-hook.sh"; cmf="$tmp/cmsg"
okc=1
for m in 'Revert "feat(auth): login"' 'fixup! feat: x' 'squash! fix: y' 'amend! feat: z'; do
  printf '%s\n\nbody\n' "$m" > "$cmf"; bash "$CM" "$cmf" >/dev/null 2>&1 || { okc=0; echo "     rechaza: $m"; }
done
[ "$okc" = 1 ] && pass "BUG-9 commit-msg exime Revert/fixup!/squash!/amend!" || bad "BUG-9 commit-msg rechaza commits de git"
printf 'feat: x\n' > "$cmf"; bash "$CM" "$cmf" >/dev/null 2>&1 && bad "BUG-9 commit-msg acepta feat sin trailers" || pass "BUG-9 commit-msg sigue exigiendo trailers a feat"
lk="$tmp/lk"; mkdir -p "$lk.lock"
bash -c '. "$1"; sdd_lock_break "$2.lock"' _ "$LIB" "$lk"
[ -d "$lk.lock" ] && pass "BUG-9 sdd_lock_break no borra un lock vivo (re-comprueba bajo el mutex)" || bad "BUG-9 sdd_lock_break borró un lock vivo"
touch -t 202001010000 "$lk.lock"
bash -c '. "$1"; sdd_lock_break "$2.lock"' _ "$LIB" "$lk"
[ ! -d "$lk.lock" ] && [ ! -d "$lk.lock.break" ] && pass "BUG-9 sdd_lock_break borra el huérfano y suelta el mutex" || bad "BUG-9 sdd_lock_break huérfano"
mkdir -p "$lk.lock.break" "$lk.lock"; touch -t 202001010000 "$lk.lock.break" "$lk.lock"
bash -c '. "$1"; SDD_LOCK_RETRIES=5; sdd_lock "$2" && sdd_unlock "$2"' _ "$LIB" "$lk" && [ ! -d "$lk.lock" ] && [ ! -d "$lk.lock.break" ] \
  && pass "BUG-9 un mutex .break huérfano también se recupera" || bad "BUG-9 .break huérfano bloquea"

# commit-msg: mismas reglas que `sdd verify --message`, por las dos vías, sobre cada fixture de tests/fixtures/git/messages
MSGS="$ROOT/tests/fixtures/git/messages"
cmr="$tmp/cmrepo"; mkdir -p "$cmr"; git -C "$cmr" init -q
( cd "$cmr" && bash "$ROOT/scripts/install-git-hooks.sh" --quiet )
check "commit-msg: install-git-hooks vendoriza sdd.mjs y lib/git-log.mjs con cabecera" \
  sh -c "grep -q 'Vendored by sdd-pipeline' '$cmr/.claude/sdd/sdd.mjs' && grep -q 'Vendored by sdd-pipeline' '$cmr/.claude/sdd/lib/git-log.mjs'"
cp "$cmr/.claude/sdd/sdd.mjs" "$tmp/sdd.mjs.real"
printf '#!/usr/bin/env node\nconsole.log("STUB-NODE\\nverify: 1 message(s), 1 error(s), 0 warning(s)"); process.exit(1);\n' > "$cmr/.claude/sdd/sdd.mjs"
out=$(cd "$cmr" && bash "$CM" "$MSGS/valid/fix-task.txt" 2>&1 || true)
contains "$out" "STUB-NODE" && pass "commit-msg: con node y el sdd.mjs vendorizado, lo usa" || bad "commit-msg: no usa el sdd.mjs vendorizado ($out)"
printf 'import "./lib/no-existe.mjs";\n' > "$cmr/.claude/sdd/sdd.mjs"
rc1=0; out=$(cd "$cmr" && bash "$CM" "$MSGS/valid/fix-task.txt" 2>&1) || rc1=$?
rc2=0; out2=$(cd "$cmr" && bash "$CM" "$MSGS/invalid/feat-no-task.txt" 2>&1) || rc2=$?
if [ "$rc1" = 0 ] && [ "$rc2" = 1 ] && contains "$out" "validating with the bash rules" && contains "$out2" '`feat` needs a `Task:` trailer'; then
  pass "commit-msg: un sdd.mjs vendorizado roto cae a las reglas bash (no bloquea ni deja pasar)"
else bad "commit-msg: sdd.mjs roto ($rc1: $out | $rc2: $out2)"; fi
cp "$tmp/sdd.mjs.real" "$cmr/.claude/sdd/sdd.mjs"
# PATH sin node: enlaces a las herramientas que usa el hook
nonode="$tmp/nonode"; mkdir -p "$nonode"
for t in git awk sed tr cat head tail grep dirname basename env sh bash; do
  p="$(command -v "$t" 2>/dev/null || true)"; [ -n "$p" ] && ln -sf "$p" "$nonode/$t"
done
if PATH="$nonode" bash -c 'command -v node' >/dev/null 2>&1; then bad "commit-msg: el PATH de prueba aún tiene node"; fi
cm_run() { # cm_run node|bash FICHERO → rc en $cmrc, salida en $out
  cmrc=0
  if [ "$1" = node ]; then out=$(cd "$cmr" && bash "$CM" "$2" 2>&1) || cmrc=$?
  else out=$(cd "$cmr" && PATH="$nonode" bash "$CM" "$2" 2>&1) || cmrc=$?; fi
}
for via in node bash; do
  okv=1; for f in "$MSGS"/valid/*.txt; do
    cm_run "$via" "$f"; [ "$cmrc" = 0 ] || { okv=0; echo "     $via rechaza valid/$(basename "$f"): $out"; }
  done
  [ "$okv" = 1 ] && pass "commit-msg ($via): acepta los $(ls "$MSGS"/valid/*.txt | wc -l | tr -d ' ') fixtures válidos" || bad "commit-msg ($via): rechaza fixtures válidos"
  oki=1; for f in "$MSGS"/invalid/*.txt; do
    name=$(basename "$f" .txt); cm_run "$via" "$f"
    case "$name" in
      prose-after-trailers|closes-in-block|coauthor-separate-paragraph) want='line 3: `Task: TASK-F2-003` is outside the trailer block' ;;
      no-type) want='is not a conventional commit' ;;
      unknown-type) want='unknown commit type `feature`' ;;
      feat-no-task|test-no-task|refactor-no-task) want="needs a \`Task:\` trailer" ;;
      fix-no-task-no-change|perf-no-trailer) want='needs a `Task:` or `Change:` trailer' ;;
      docs-specs-no-refs) want='`docs(specs)` needs a `Refs:` trailer' ;;
      bad-task-legacy-format) want='Task `TASK-FASE-1-002` does not match' ;;
      bad-task-seq) want='Task `TASK-F1-02` does not match' ;;
      bad-refs) want='Refs `#12` is not a spec id' ;;
      bad-change) want='Change `change-1` does not match' ;;
      empty) want='empty commit message' ;;
      *) want='__sin expectativa__' ;;
    esac
    if [ "$cmrc" = 1 ] && contains "$out" "$want"; then :; else oki=0; echo "     $via invalid/$name → $cmrc: $out"; fi
  done
  [ "$oki" = 1 ] && pass "commit-msg ($via): rechaza los $(ls "$MSGS"/invalid/*.txt | wc -l | tr -d ' ') fixtures inválidos con el mensaje de verify" || bad "commit-msg ($via): fixtures inválidos"
  cm_run "$via" "$MSGS/valid/lowercase-key.txt"
  contains "$out" 'trailer key `task` should be written `Task`' && pass "commit-msg ($via): avisa de la clave en minúsculas" || bad "commit-msg ($via): sin aviso de clave ($out)"
  cm_run "$via" "$MSGS/valid/fix-task.txt"
  [ -z "$out" ] && pass "commit-msg ($via): un mensaje válido no imprime nada" || bad "commit-msg ($via): ruido en un commit válido ($out)"
  cmrc=0; out=$(cd "$cmr" && SDD_SKIP_VERIFY=1 PATH="$nonode" bash "$CM" "$MSGS/invalid/feat-no-task.txt" 2>&1) || cmrc=$?
done
[ "$cmrc" = 0 ] && pass "commit-msg: SDD_SKIP_VERIFY=1 salta la validación" || bad "commit-msg: SDD_SKIP_VERIFY ignorado"
grep -q 'TASK-FASE-' "$CM" && bad "commit-msg: ejemplos con el formato viejo TASK-FASE-N-NNN" || pass "commit-msg: sin ejemplos TASK-FASE-N-NNN"

# scripts/sdd-state.sh: set/get bajo el lock de los hooks
STATE_SH="$ROOT/scripts/sdd-state.sh"
cp "$FIX/pipeline-state.impl-running.json" "$b2/pipeline-state.json"
( cd "$b2" && bash "$STATE_SH" set task-implementer "done" ) && [ "$(status_of task-implementer "$b2/pipeline-state.json")" = "done" ] \
  && [ "$(jq -r '.stages["requirements-engineer"].summary.handoff.to' "$b2/pipeline-state.json")" = example-lead ] \
  && pass "sdd-state.sh set: cambia el status y conserva summary" || bad "sdd-state.sh set"
[ "$(cd "$b2" && bash "$STATE_SH" get task-implementer)" = "done" ] && [ "$(cd "$b2" && bash "$STATE_SH" get nope)" = absent ] && pass "sdd-state.sh get" || bad "sdd-state.sh get"
( cd "$b2" && bash "$STATE_SH" set req-change running ) && [ "$(jq -r .currentStage "$b2/pipeline-state.json")" = req-change ] && pass "sdd-state.sh set running: crea la clave y fija currentStage" || bad "sdd-state.sh set running"
( cd "$b2" && bash "$STATE_SH" set x bogus ) >/dev/null 2>&1 && bad "sdd-state.sh acepta un status inválido" || pass "sdd-state.sh rechaza status inválido"
( cd "$plain" && bash "$STATE_SH" set x "done" ) >/dev/null 2>&1 && bad "sdd-state.sh crea estado en repo sin SDD" || pass "sdd-state.sh sin pipeline-state.json: exit 1, no crea nada"
( cd "$b2" && bash "$STATE_SH" set spec-auditor skipped --reason "spec skipped, 6 REQ-F" ) \
  && [ "$(jq -r '.stages["spec-auditor"].status + "|" + .stages["spec-auditor"].skipReason' "$b2/pipeline-state.json")" = "skipped|spec skipped, 6 REQ-F" ] \
  && pass "sdd-state.sh set skipped --reason: guarda skipReason" || bad "sdd-state.sh set skipped --reason"
( cd "$b2" && bash "$STATE_SH" set spec-auditor pending ) && [ "$(jq -r '.stages["spec-auditor"] | has("skipReason")' "$b2/pipeline-state.json")" = false ] \
  && pass "sdd-state.sh: otro status borra skipReason" || bad "sdd-state.sh no borra skipReason"
( cd "$b2" && bash "$STATE_SH" set spec-auditor "done" --reason x ) >/dev/null 2>&1 && bad "sdd-state.sh acepta --reason sin skipped" || pass "sdd-state.sh: --reason solo con skipped"
if [ -d "$bin" ] && PATH="$bin" node --version >/dev/null 2>&1; then
  ( cd "$b2" && PATH="$bin" bash "$STATE_SH" set test-planner skipped --reason "no UI" ) \
    && [ "$(jq -r '.stages["test-planner"].status + "|" + .stages["test-planner"].skipReason' "$b2/pipeline-state.json")" = "skipped|no UI" ] \
    && pass "sdd-state.sh set skipped --reason: igual sin jq (node)" || bad "sdd-state.sh skipped sin jq"
fi
[ "$(cd "$b2" && bash "$STATE_SH" path)" = "$(cd "$b2" && pwd -P)/pipeline-state.json" ] && pass "sdd-state.sh path: imprime el fichero de estado" || bad "sdd-state.sh path ($(cd "$b2" && bash "$STATE_SH" path))"
( cd "$plain" && bash "$STATE_SH" path ) >/dev/null 2>&1 && bad "sdd-state.sh path sin estado → exit 0" || pass "sdd-state.sh path sin estado: exit 1"
check "sdd-state.sh sin estado no crea pipeline-state.json" test ! -e "$plain/pipeline-state.json"
check "sdd-state.sh no deja .lock" no_lock "$b2/pipeline-state.json"

[ "$fail" -eq 0 ] && echo "tests/hooks: todo ok" || { echo "tests/hooks: hay fallos"; exit 1; }
