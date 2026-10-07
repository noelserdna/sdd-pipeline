#!/usr/bin/env bash
# Evals deterministas de enrutado (M4 nivel 1): red de seguridad léxica sobre las descriptions de las skills, no una
# medida de cómo enruta el modelo. Ver la cabecera de run.mjs. Requiere node ≥ 18, sin dependencias.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec node "$ROOT/tests/triggers/run.mjs" --root "$ROOT" "$@"
