#!/usr/bin/env bash
# Publica una versión: única fuente = .claude-plugin/plugin.json, propagada a marketplace.json, server/package.json y CHANGELOG.
# Uso: scripts/release.sh X.Y.Z[-pre]   (árbol limpio; crea commit y tag sdd-pipeline--vX.Y.Z con `claude plugin tag`)
set -euo pipefail
cd "$(dirname "$0")/.."
VER="${1:-}"
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "uso: $0 X.Y.Z[-pre]"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "árbol sucio: commitea o descarta antes de publicar"; exit 1; }

tmp=$(mktemp)
jq --arg v "$VER" '.version=$v' .claude-plugin/plugin.json > "$tmp" && mv "$tmp" .claude-plugin/plugin.json
jq --arg v "$VER" '.plugins[0].version=$v' .claude-plugin/marketplace.json > "$tmp" && mv "$tmp" .claude-plugin/marketplace.json
(cd server && npm version "$VER" --no-git-tag-version >/dev/null && npm run -s build)

today=$(date +%F)
# Solo las versiones finales cortan la sección [Unreleased]; las prerelease (-alpha/-beta/-rc) la dejan intacta.
if [[ "$VER" != *-* ]] && grep -q '^## \[Unreleased\]' CHANGELOG.md; then
  python3 - "$VER" "$today" <<'PY'
import sys,re
ver,today=sys.argv[1],sys.argv[2]
s=open('CHANGELOG.md').read()
s=s.replace('## [Unreleased]', f'## [Unreleased]\n\n## [{ver}] - {today}',1)
open('CHANGELOG.md','w').write(s)
PY
fi

bash scripts/check-version.sh
node scripts/validate-plugin.mjs >/dev/null
command -v claude >/dev/null && claude plugin validate ./ --strict >/dev/null

git add -A
git commit -q -m "chore(release): sdd-pipeline v$VER"
if command -v claude >/dev/null; then
  claude plugin tag -m "sdd-pipeline v%s" --push
else
  git tag -a "sdd-pipeline--v$VER" -m "sdd-pipeline v$VER" && git push --follow-tags
fi
echo "publicado sdd-pipeline v$VER"
