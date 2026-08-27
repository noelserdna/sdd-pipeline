#!/usr/bin/env bash
# subagentStatusLine del plugin: una fila por subagente en el panel de agentes de Claude Code
#   <tipo> · <descripción> · <tiempo transcurrido> · <tokens>k (<% de su contexto>)
# Entrada (stdin): {"columns": N, "tasks": [{id, name, type, status, description, label, startTime, model, tokenCount, contextWindowSize, ...}]}
# Salida: una línea JSON por fila {"id": ..., "content": ...}. Sin jq no imprime nada (Claude Code usa su fila por defecto).
set -u
input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0
[ -n "$input" ] || exit 0
now=$(date +%s)
printf '%s' "$input" | jq -r -c --argjson now "$now" '
  (.columns // 100) as $cols
  | (.tasks // [])[] | select(type=="object" and (.id != null))
  | (.startTime // null) as $st
  | (if ($st|type)=="number" then (if $st > 1000000000000 then ($now - ($st/1000|floor)) else ($now - $st) end)
     elif ($st|type)=="string" then (try (($st | sub("\\.[0-9]+";"") | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) as $t | $now - $t) catch null)
     else null end) as $el
  | (if $el == null or $el < 0 then ""
     elif $el >= 3600 then "\($el/3600|floor)h\(($el%3600)/60|floor)m"
     elif $el >= 60 then "\($el/60|floor)m\($el%60)s"
     else "\($el)s" end) as $dur
  | (.tokenCount // 0) as $tok
  | (if (.contextWindowSize // 0) > 0 and $tok > 0 then " (\(($tok*100/.contextWindowSize)|floor)%)" else "" end) as $pct
  | ((.description // .label // "") | tostring) as $desc
  | (if (.status // "") == "running" or (.status // "") == "" then "▶" else "■" end) as $icon
  | ([ $icon + " " + ((.name // .type // "agent")|tostring), $desc, $dur, (if $tok > 0 then "\(($tok/1000)|floor)k tok\($pct)" else "" end) ]
     | map(select(. != "")) | join(" · ")) as $row
  | {id: .id, content: ($row | if length > $cols then .[0:($cols-1)] + "…" else . end)}
' 2>/dev/null || true
