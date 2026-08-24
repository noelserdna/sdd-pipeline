#!/usr/bin/env bash
# B2 — instalación real en un CLAUDE_CONFIG_DIR limpio (marketplace local), inventario del plugin y coste de contexto.
# Uso: tests/e2e/10-install.sh [--keep]   (--keep no borra el config dir temporal)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KEEP="${1:-}"
export CLAUDE_CONFIG_DIR
CLAUDE_CONFIG_DIR="$(mktemp -d)"
[ "$KEEP" = "--keep" ] || trap 'rm -rf "$CLAUDE_CONFIG_DIR"' EXIT
fail=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; fail=1; }

command -v claude >/dev/null 2>&1 || { echo "claude CLI no disponible"; exit 2; }
echo "config aislada: $CLAUDE_CONFIG_DIR"

claude plugin marketplace add "$ROOT" >/dev/null 2>&1 && ok "marketplace add $ROOT" || bad "marketplace add"
claude plugin install sdd-pipeline@noelserdna --scope user >/dev/null 2>&1 && ok "plugin install sdd-pipeline@noelserdna" || bad "plugin install"
claude plugin list 2>/dev/null | grep -q 'sdd-pipeline@noelserdna' && ok "plugin list" || bad "plugin list"

details="$(claude plugin details sdd-pipeline 2>/dev/null || true)"
skills=$(grep -cE '^\s+sdd-[a-z-]+ ' <<<"$details" || true)
echo "$details" | grep -qE 'MCP servers \(1\)' && ok "MCP servers (1)" || bad "MCP servers"
echo "$details" | grep -qE 'Hooks \([1-9]' && ok "Hooks registrados" || bad "Hooks"
always=$(grep -oE 'Always-on:\s+~[0-9.,]+ tok' <<<"$details" | grep -oE '[0-9.,]+' | tr -d '.,' || true)
echo "componentes listados: $skills · always-on: ${always:-?} tok"
if [ -n "$always" ] && [ "$always" -gt 8000 ]; then bad "always-on > 8000 tok (umbral de división del plugin)"; else ok "always-on dentro del umbral"; fi

# H1 determinista, sin modelo
tmp="$(mktemp -d)"; out=$(printf '{"session_id":"t","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | CLAUDE_PROJECT_DIR="$tmp" bash "$ROOT/hooks/sdd-session-start.sh" 2>/dev/null || true)
if [ -z "$out" ] || printf '%s' "$out" | jq -e . >/dev/null 2>&1; then ok "H1 responde JSON/vacío sin pipeline"; else bad "H1 salida inválida"; fi
rm -rf "$tmp"

# MCP: el smoke test del servidor arranca dist/server.js por stdio y comprueba las 6 tools
if [ -d "$ROOT/server/node_modules" ]; then
  (cd "$ROOT/server" && npm test >/dev/null 2>&1) && ok "server smoke (6 tools por stdio)" || bad "server smoke"
else
  echo "skip server/node_modules ausente (npm ci)"
fi

[ "$fail" -eq 0 ] && { echo; echo "B2: todo ok"; } || { echo; echo "B2: hay fallos"; exit 1; }
