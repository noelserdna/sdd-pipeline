#!/usr/bin/env bash
# Perfila una skill del pipeline: ejecuta `claude -p` con stream-json y desglosa dónde se va el tiempo.
# Uso: scripts/sdd-profile.sh [--plugin-dir DIR] [--out FILE] "<prompt de la skill>"
#      scripts/sdd-profile.sh --analyze FILE.jsonl
# Salida: duración total y de API, turnos, coste, tokens (entrada/salida/caché), histograma de herramientas,
#         caracteres leídos por herramientas vs escritos por el modelo, y los 8 resultados más grandes.
set -euo pipefail
PLUGIN_DIR=""; OUT=""; ANALYZE=""; PROMPT=""
while [ $# -gt 0 ]; do case "$1" in
  --plugin-dir) PLUGIN_DIR="$2"; shift 2;; --out) OUT="$2"; shift 2;; --analyze) ANALYZE="$2"; shift 2;; *) PROMPT="$1"; shift;; esac; done
command -v jq >/dev/null || { echo "sdd-profile necesita jq"; exit 2; }
if [ -z "$ANALYZE" ]; then
  [ -n "$PROMPT" ] || { echo "uso: $0 [--plugin-dir DIR] [--out FILE] \"<prompt>\"  |  --analyze FILE"; exit 2; }
  OUT="${OUT:-.sdd/profile-$(date +%Y%m%d-%H%M%S).jsonl}"; mkdir -p "$(dirname "$OUT")"
  args=(-p "$PROMPT" --output-format stream-json --verbose); [ -n "$PLUGIN_DIR" ] && args=(--plugin-dir "$PLUGIN_DIR" "${args[@]}")
  echo "perfilando → $OUT"; claude "${args[@]}" > "$OUT" 2>"$OUT.err" || true
  ANALYZE="$OUT"
fi
F="$ANALYZE"; [ -s "$F" ] || { echo "fichero vacío: $F"; exit 1; }
echo "== Resumen ($F)"
jq -r 'select(.type=="result") | "duración: \((.duration_ms/60000*10|round)/10) min · API: \((.duration_api_ms/60000*10|round)/10) min · turnos: \(.num_turns) · coste: $\((.total_cost_usd*100|round)/100)\ntokens: entrada \(.usage.input_tokens) · salida \(.usage.output_tokens) · caché leída \(.usage.cache_read_input_tokens) · caché creada \(.usage.cache_creation_input_tokens)"' "$F"
echo "== Herramientas (llamadas)"
jq -r 'select(.type=="assistant") | (.message.content | if type=="array" then .[] else empty end) | select(type=="object" and .type=="tool_use") | .name' "$F" | sort | uniq -c | sort -rn | sed 's/^/  /'
read_chars=$(jq -r 'select(.type=="user") | (.message.content | if type=="array" then .[] else empty end) | select(type=="object" and .type=="tool_result") | (if (.content|type)=="string" then .content else ([.content[]?.text // ""] | join("")) end) | length' "$F" | paste -sd+ - | bc)
write_chars=$(jq -r 'select(.type=="assistant") | (.message.content | if type=="array" then .[] else empty end) | select(type=="object" and .type=="tool_use") | (.input.content // .input.new_string // .input.command // "") | length' "$F" | paste -sd+ - | bc)
text_chars=$(jq -r 'select(.type=="assistant") | (.message.content | if type=="array" then .[] else empty end) | select(type=="object" and .type=="text") | .text | length' "$F" | paste -sd+ - | bc)
echo "== Volumen"; echo "  leído por herramientas: $read_chars chars (~$((read_chars/4)) tokens)"; echo "  escrito en herramientas (Write/Edit/heredoc): $write_chars chars"; echo "  texto de respuesta: $text_chars chars"
echo "== Resultados de herramienta más grandes"
jq -c 'select(.type=="assistant") | (.message.content | if type=="array" then .[] else empty end) | select(type=="object" and .type=="tool_use") | {id:.id, cmd:(((.input.command // .input.file_path // .input.pattern // "") | tostring)[0:70])}' "$F" > "$F.cmds"
jq -c 'select(.type=="user") | (.message.content | if type=="array" then .[] else empty end) | select(type=="object" and .type=="tool_result") | {id:(.tool_use_id // ""), len:((if (.content|type)=="string" then .content else ([.content[]?.text // ""] | join("")) end)|length)}' "$F" > "$F.res"
jq -s -r '(.[0] | map({(.id):.cmd}) | add) as $c | .[1] | sort_by(-.len) | .[0:8][] | "  \(.len)\t\($c[.id] // "?")"' "$F.cmds" "$F.res" 2>/dev/null || true
rm -f "$F.cmds" "$F.res"
