#!/usr/bin/env bash
# Tests de los hooks del plugin. Cada test alimenta el JSON de stdin que Claude Code enviaría y comprueba la salida.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS="$ROOT/hooks"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# 1. Sintaxis
for f in "$HOOKS"/*.sh; do bash -n "$f" && pass "bash -n $(basename "$f")" || bad "bash -n $(basename "$f")"; done
node --check "$HOOKS/sdd-augment-hook.js" && pass "node --check sdd-augment-hook.js" || bad "node --check sdd-augment-hook.js"

# 2. H1 en un directorio sin pipeline: no rompe y devuelve JSON (o nada)
out=$(printf '{"session_id":"t","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOKS/sdd-session-start.sh" 2>/dev/null || true)
if [ -z "$out" ] || printf '%s' "$out" | jq -e . >/dev/null 2>&1; then pass "H1 sin pipeline (salida vacía o JSON)"; else bad "H1 sin pipeline: salida no JSON: $out"; fi

# 3. H2 sin pipeline-state: no bloquea
out=$(printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/spec/x.md"}}' "$tmp" "$tmp" | CLAUDE_PROJECT_DIR="$tmp" bash "$HOOKS/sdd-upstream-guard.sh" 2>/dev/null || true)
if printf '%s' "$out" | grep -q '"deny"'; then bad "H2 sin pipeline-state deniega"; else pass "H2 sin pipeline-state permite"; fi

# 4. H5 sin grafo: sale rápido sin error
start=$(date +%s); printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"%s/a.md"}}' "$tmp" "$tmp" | CLAUDE_PROJECT_DIR="$tmp" node "$HOOKS/sdd-augment-hook.js" >/dev/null 2>&1 && pass "H5 sin grafo (exit 0, $(( $(date +%s) - start ))s)" || bad "H5 sin grafo falla"

[ "$fail" -eq 0 ] && echo "tests/hooks: todo ok" || { echo "tests/hooks: hay fallos"; exit 1; }
