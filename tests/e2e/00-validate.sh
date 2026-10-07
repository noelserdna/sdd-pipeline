#!/usr/bin/env bash
# B1 — validación estática del plugin: manifiestos, lint, rutas, versiones, bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail=0
step() { printf '\n== %s\n' "$1"; }
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

step "claude plugin validate --strict"
if command -v claude >/dev/null 2>&1; then
  # The root CLAUDE.md is this repository's maintainer guide, not context the plugin ships: newer CLIs warn that a
  # plugin does not load it, and --strict turns that warning into a failure. Only that warning is tolerated.
  if out=$(claude plugin validate ./ --strict 2>&1); then ok "marketplace + plugin"
  elif ! printf '%s\n' "$out" | grep -E '^\s*❯' | grep -vq 'CLAUDE.md at the plugin root is not loaded'; then ok "marketplace + plugin (root CLAUDE.md is the maintainer guide)"
  else bad "claude plugin validate ./ --strict"; printf '%s\n' "$out" | grep -E '^\s*❯' | grep -v 'CLAUDE.md at the plugin root' | head -5; fi
  claude plugin validate ./skills --strict >/dev/null 2>&1 && ok "skills" || bad "claude plugin validate ./skills"
  # El plugin no distribuye agentes; los de mantenimiento viven en .claude/agents/ (no se publican).
  if [ -d agents ]; then
    claude plugin validate ./agents --strict >/dev/null 2>&1 && ok "agents" || bad "claude plugin validate ./agents"
  fi
else
  echo "skip claude CLI no disponible"
fi

step "validate-plugin.mjs (hooks.json y .mcp.json no los cubre claude plugin validate)"
node scripts/validate-plugin.mjs >/dev/null && ok "validate-plugin.mjs" || bad "validate-plugin.mjs"
jq -e '.hooks' hooks/hooks.json >/dev/null && ok "hooks.json wrapper" || bad "hooks.json wrapper"
jq -e '.mcpServers.sdd' .mcp.json >/dev/null && ok ".mcp.json mcpServers.sdd" || bad ".mcp.json"

step "shell"
for f in hooks/*.sh scripts/*.sh tests/*/*.sh; do
  bash -n "$f" || bad "bash -n $f"
  [ -x "$f" ] || bad "sin +x: $f"
done
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning hooks/*.sh scripts/*.sh tests/*/*.sh && ok "shellcheck" || bad "shellcheck"
else
  echo "skip shellcheck no disponible"
fi

step "rutas y versiones"
bash scripts/check-paths.sh >/dev/null && ok "check-paths" || bad "check-paths"
bash scripts/check-version.sh >/dev/null && ok "check-version" || bad "check-version"

step "servidor MCP"
[ "$(git ls-files server/node_modules | wc -l | tr -d ' ')" = "0" ] && ok "node_modules no trackeado" || bad "node_modules trackeado"
[ -x server/dist/server.js ] && ok "dist/server.js existe y es ejecutable" || bad "dist/server.js"
size=$(wc -c < server/dist/server.js); [ "$size" -lt 2097152 ] && ok "dist/server.js < 2 MB ($size bytes)" || bad "dist/server.js demasiado grande"

[ "$fail" -eq 0 ] && { echo; echo "B1: todo ok"; } || { echo; echo "B1: hay fallos"; exit 1; }
