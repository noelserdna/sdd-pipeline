#!/usr/bin/env bash
# La versión vive en .claude-plugin/plugin.json y debe coincidir en marketplace.json y server/package.json.
set -euo pipefail
cd "$(dirname "$0")/.."
a=$(jq -r .version .claude-plugin/plugin.json)
b=$(jq -r '.plugins[0].version' .claude-plugin/marketplace.json)
c=$(jq -r .version server/package.json)
if [ "$a" != "$b" ] || [ "$a" != "$c" ]; then
  echo "check-version: ERROR — plugin.json=$a marketplace.json=$b server/package.json=$c"
  exit 1
fi
last=$(grep -m1 -oE '^## \[[0-9][^]]*\]' CHANGELOG.md | tr -d '#[] ' || true)
echo "check-version: ok ($a; última entrada del CHANGELOG: ${last:-ninguna})"
