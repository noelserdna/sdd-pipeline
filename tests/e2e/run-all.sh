#!/usr/bin/env bash
# Encadena las verificaciones E2E del plugin. Uso: tests/e2e/run-all.sh [--no-install]
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$DIR/00-validate.sh"
[ "${1:-}" = "--no-install" ] || bash "$DIR/10-install.sh"
for s in 20-smoke.sh 30-multisession.sh 40-migration.sh; do
  [ -x "$DIR/$s" ] && bash "$DIR/$s" || echo "skip $s (no disponible todavía)"
done
echo "run-all: fin"
