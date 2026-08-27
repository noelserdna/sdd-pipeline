#!/usr/bin/env bash
# Falla si queda alguna ruta específica del autor o de instalaciones antiguas fuera de docs/legacy y CHANGELOG.
set -euo pipefail
cd "$(dirname "$0")/.."
PATTERN='/Users/andresleon|/home/andresleon|~/programacion|programacion/sdd-skills|noelserdna-plugins|sdd-lite'
# --exclude=.git cubre el worktree enlazado, donde .git es un FICHERO con "gitdir: /ruta/absoluta"
if grep -rnE "$PATTERN" \
    --exclude-dir=.git --exclude=.git \
    --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=legacy --exclude-dir=multisesion \
    --exclude=CHANGELOG.md --exclude=check-paths.sh . ; then
  echo "check-paths: ERROR — rutas específicas del autor encontradas (ver arriba)"
  exit 1
fi
echo "check-paths: ok"
