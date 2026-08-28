#!/bin/bash
# sdd-common.sh — helpers compartidos por los hooks SDD y la status line.
#
# Se carga con `. "$(dirname "${BASH_SOURCE[0]}")/lib/sdd-common.sh"`. Reglas:
#   - Compatible con bash 3.2 (macOS): sin mapfile, sin declare -A, sin ${var,,}.
#   - Seguro bajo `set -euo pipefail`: ninguna función sale con error por un problema
#     de git/jq/registro; devuelven vacío y el hook degrada al comportamiento 3.x.
#   - Sin flock, sin `~`, sin rutas absolutas del autor.
#
# Dos raíces:
#   PROJECT_DIR  toplevel git del fichero (o del cwd): clasifica REL_PATH. En un
#                worktree (git worktree add ../x, claude -w, EnterWorktree) es el worktree.
#   STATE_ROOT   directorio del `.git` común: allí viven pipeline-state.json y
#                .sdd/trace-map.json, compartidos por todos los worktrees.
#   .sdd/current-task.json vive en PROJECT_DIR (uno por worktree).
#
# Variables de entorno opcionales (no documentadas por Claude Code, degradables):
#   SDD_STATE_ROOT  fija STATE_ROOT.  SDD_ROLE  fija el rol.  CLAUDE_PID  pid de la sesión.

SDD_LOCKS_HELD="${SDD_LOCKS_HELD:-}"
SDD_NAP="${SDD_NAP:-}"

# ---------------------------------------------------------------- utilidades
sdd_has_jq() { command -v jq >/dev/null 2>&1; }
sdd_has_node() { command -v node >/dev/null 2>&1; }

# Normaliza separadores Windows.
sdd_norm() { printf '%s\n' "${1//\\//}"; }

# Ruta física (resuelve symlinks de los ancestros existentes; macOS: /var → /private/var).
# Conserva la cola que aún no existe (Write puede crear directorios nuevos).
sdd_physical() {
  local p="$1" tail="" d
  [ -n "$p" ] || { printf '\n'; return 0; }
  d="$p"
  while [ ! -d "$d" ]; do
    tail="$(basename "$d")${tail:+/$tail}"
    case "$d" in /|.) break ;; esac
    d=$(dirname "$d")
  done
  if [ -d "$d" ]; then
    d=$(cd "$d" 2>/dev/null && pwd -P) || d="$d"
  fi
  case "$d" in */) printf '%s%s\n' "$d" "$tail" ;; *) printf '%s%s\n' "$d" "${tail:+/$tail}" ;; esac
}

# sdd_json_get FILE JQ_EXPR  (FILE="-" lee stdin). Con jq acepta cualquier filtro.
# Sin jq, node resuelve un subconjunto: rutas con punto, alternativas `a // b`,
# literales JSON y `empty`. Nunca falla; sin dato imprime vacío.
sdd_json_get() {
  local file="$1" expr="$2"
  if sdd_has_jq; then
    if [ "$file" = "-" ]; then jq -r "$expr" 2>/dev/null || true
    else jq -r "$expr" "$file" 2>/dev/null || true; fi
    return 0
  fi
  sdd_has_node || return 0
  SDD_JSON_FILE="$file" SDD_JSON_EXPR="$expr" node -e '
    const fs = require("fs");
    const file = process.env.SDD_JSON_FILE, expr = process.env.SDD_JSON_EXPR;
    let data;
    try { data = JSON.parse(fs.readFileSync(file === "-" ? 0 : file, "utf8")); } catch (e) { process.exit(0); }
    let out;
    for (const alt of expr.split("//").map((s) => s.trim())) {
      if (alt === "empty") break;
      if (/^(\.[A-Za-z_][A-Za-z0-9_-]*)+$/.test(alt)) {
        let v = data;
        for (const k of alt.split(".").slice(1)) { v = (v !== null && typeof v === "object") ? v[k] : undefined; }
        if (v !== null && v !== undefined) { out = v; break; }
        continue;
      }
      try { out = JSON.parse(alt); break; } catch (e) { /* no es literal */ }
    }
    if (out === undefined) process.exit(0);
    process.stdout.write((typeof out === "string" ? out : JSON.stringify(out)) + "\n");
  ' 2>/dev/null || true
}

# Cadena → literal JSON (con comillas). Sin jq ni node, escape mínimo.
sdd_json_string() {
  if sdd_has_jq; then printf '%s' "$1" | jq -Rs . 2>/dev/null && return 0; fi
  if sdd_has_node; then printf '%s' "$1" | node -e 'process.stdout.write(JSON.stringify(require("fs").readFileSync(0,"utf8"))+"\n")' 2>/dev/null && return 0; fi
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  printf '"%s"\n' "$s"
}

# ¿LIST (una entrada por línea o separada por espacios) contiene ITEM?
sdd_list_has() {
  local list="$1" item="$2" x
  for x in $list; do [ "$x" = "$item" ] && return 0; done
  return 1
}

# ¿PATH casa con GLOB (sintaxis de `case`; `*` cruza `/`)?
sdd_glob_match() {
  # shellcheck disable=SC2254  # el glob debe expandirse como patrón, no literal
  case "$1" in $2) return 0 ;; esac
  return 1
}

# ¿PATH casa con alguno de los globs de LIST (una por línea)?
sdd_globs_match() {
  local path="$1" g
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    sdd_glob_match "$path" "$g" && return 0
  done <<< "$2"
  return 1
}

# git-common-dir absoluto de DIR (git ≥ 2.31 con --path-format; fallback manual).
sdd_git_common_dir() {
  local dir="$1" c
  [ -d "$dir" ] || return 1
  c=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || c=""
  if [ -z "$c" ]; then
    c=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
    case "$c" in /*) ;; *) c=$(cd "$dir" 2>/dev/null && cd "$c" 2>/dev/null && pwd -P) || return 1 ;; esac
  fi
  [ -n "$c" ] && printf '%s\n' "$c"
}

# ---------------------------------------------------------------- raíces
# sdd_roots INPUT [FILE_PATH] → exporta CWD, PROJECT_DIR, STATE_ROOT, REL_PATH.
#   PROJECT_DIR = toplevel git del fichero, si no del cwd, si no ${CLAUDE_PROJECT_DIR:-$PWD}.
#   STATE_ROOT  = ${SDD_STATE_ROOT:-dirname(git-common-dir del cwd)}, fallback PROJECT_DIR.
#   REL_PATH    = FILE_PATH relativo a PROJECT_DIR (igual a FILE_PATH si no está debajo).
sdd_roots() {
  local input="${1:-}" file_path="${2:-}" fdir
  CWD=""
  if [ -n "$input" ]; then
    CWD=$(printf '%s' "$input" | sdd_json_get - '.cwd // .workspace.current_dir // empty') || CWD=""
  fi
  CWD=$(sdd_norm "$CWD")
  [ -n "$CWD" ] && [ -d "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-$PWD}"
  CWD=$(sdd_norm "$CWD")

  PROJECT_DIR=""
  if [ -n "$file_path" ]; then
    file_path=$(sdd_norm "$file_path")
    case "$file_path" in /*|[A-Za-z]:/*) ;; *) file_path="$CWD/$file_path" ;; esac
    file_path=$(sdd_physical "$file_path")
    fdir=$(dirname "$file_path")
    while [ ! -d "$fdir" ] && [ "$fdir" != "/" ] && [ "$fdir" != "." ]; do fdir=$(dirname "$fdir"); done
    PROJECT_DIR=$(git -C "$fdir" rev-parse --show-toplevel 2>/dev/null) || PROJECT_DIR=""
  fi
  if [ -z "$PROJECT_DIR" ] && [ -d "$CWD" ]; then
    PROJECT_DIR=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || PROJECT_DIR=""
  fi
  [ -n "$PROJECT_DIR" ] || PROJECT_DIR=$(sdd_physical "$(sdd_norm "${CLAUDE_PROJECT_DIR:-$PWD}")")
  PROJECT_DIR=$(sdd_norm "$PROJECT_DIR")

  STATE_ROOT=$(sdd_norm "${SDD_STATE_ROOT:-}")
  if [ -z "$STATE_ROOT" ]; then
    local common
    common=$(sdd_git_common_dir "$CWD") || common=""
    [ -n "$common" ] && STATE_ROOT=$(dirname "$common")
  fi
  [ -n "$STATE_ROOT" ] || STATE_ROOT="$PROJECT_DIR"

  REL_PATH=""
  if [ -n "$file_path" ]; then
    # Fuera del proyecto queda la ruta absoluta (física): el llamador lo detecta con `case /*`.
    REL_PATH="${file_path#"$PROJECT_DIR"/}"
  fi
  export CWD PROJECT_DIR STATE_ROOT REL_PATH
  return 0
}

# ---------------------------------------------------------------- lock portable
# sdd_lock FILE: crea FILE.lock con mkdir (atómico). 50 reintentos × 0,1 s (SDD_LOCK_RETRIES
# lo ajusta); un lock con más de 60 s se considera huérfano y se rompe. Devuelve 1 si no
# lo consigue: el llamador decide (los hooks saltan la escritura). trap EXIT libera.
sdd_nap() {
  if [ -z "$SDD_NAP" ]; then
    if sleep 0.1 2>/dev/null; then SDD_NAP=0.1; else SDD_NAP=1; fi
    return 0
  fi
  sleep "$SDD_NAP"
}

sdd_mtime() {
  local m
  m=$(stat -c %Y "$1" 2>/dev/null) || m=$(stat -f %m "$1" 2>/dev/null) || m=""
  case "$m" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s\n' "$m"
}

sdd_lock_stale() {
  local m now
  m=$(sdd_mtime "$1") || return 1
  now=$(date +%s)
  [ $((now - m)) -gt 60 ]
}

sdd_unlock_all() {
  local d
  for d in $SDD_LOCKS_HELD; do rmdir "$d" 2>/dev/null || true; done
  SDD_LOCKS_HELD=""
}

sdd_lock() {
  local target="$1" lockdir tries=0 max="${SDD_LOCK_RETRIES:-50}"
  lockdir="$target.lock"
  while ! mkdir "$lockdir" 2>/dev/null; do
    tries=$((tries + 1))
    [ "$tries" -le "$max" ] || return 1
    if sdd_lock_stale "$lockdir"; then
      rmdir "$lockdir" 2>/dev/null || true
      continue
    fi
    sdd_nap
  done
  SDD_LOCKS_HELD="${SDD_LOCKS_HELD:+$SDD_LOCKS_HELD }$lockdir"
  trap sdd_unlock_all EXIT
  return 0
}

sdd_unlock() {
  local lockdir="$1.lock" d rest=""
  rmdir "$lockdir" 2>/dev/null || true
  for d in $SDD_LOCKS_HELD; do [ "$d" = "$lockdir" ] || rest="${rest:+$rest }$d"; done
  SDD_LOCKS_HELD="$rest"
  return 0
}

# ---------------------------------------------------------------- índice global de ejecuciones
# <config>/sdd/active-runs.json: una entrada por checkout principal (clave `root`) que escribe
# hooks/sdd-activity-log.sh. Lo leen hooks/sdd-runs-line.sh y scripts/sdd-watch.sh --brief.
# scripts/sdd-status-line-global.sh NO usa estos helpers a propósito: se copia fuera del plugin.
sdd_runs_file() { printf '%s\n' "${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/sdd/active-runs.json"; }

# sdd_stage_counts FILE → "hechas<TAB>totales" de pipeline-state.json (vacío si no se puede leer).
# El total son las etapas REALES del fichero (las laterales las añaden los hooks), no 7 fijo.
sdd_stage_counts() {
  local f="$1"
  [ -f "$f" ] || return 0
  if sdd_has_jq; then
    jq -r '(.stages // {}) | (if type == "object" then . else {} end) as $s
           | [ ([ $s[] | select(type == "object" and .status == "done") ] | length), ($s | length) ] | @tsv' "$f" 2>/dev/null || true
    return 0
  fi
  sdd_has_node || return 0
  SDD_SC_FILE="$f" node -e '
    const fs = require("fs");
    try {
      const st = JSON.parse(fs.readFileSync(process.env.SDD_SC_FILE, "utf8"));
      const s = (st && typeof st.stages === "object" && st.stages) || {};
      const keys = Object.keys(s);
      const done = keys.filter((k) => s[k] && typeof s[k] === "object" && s[k].status === "done").length;
      process.stdout.write(done + "\t" + keys.length + "\n");
    } catch (e) {}' 2>/dev/null || true
  return 0
}

# ---------------------------------------------------------------- roles (sdd-sessions.json)
sdd_registry_file() { printf '%s\n' "${STATE_ROOT:-${PROJECT_DIR:-$PWD}}/.claude/sdd-sessions.json"; }

# sdd_role_by_name NAME → clave de `roles` cuyo .name coincide (vacío si no hay).
sdd_role_by_name() {
  local reg name="$1"
  reg=$(sdd_registry_file)
  [ -f "$reg" ] && [ -n "$name" ] || return 0
  if sdd_has_jq; then
    jq -r --arg n "$name" '.roles // {} | to_entries[] | select(.value.name == $n) | .key' "$reg" 2>/dev/null | head -n 1 || true
  elif sdd_has_node; then
    SDD_REG="$reg" SDD_NAME="$name" node -e '
      try { const r = JSON.parse(require("fs").readFileSync(process.env.SDD_REG, "utf8")).roles || {};
        const k = Object.keys(r).find((k) => r[k] && r[k].name === process.env.SDD_NAME);
        if (k) process.stdout.write(k + "\n"); } catch (e) {}' 2>/dev/null || true
  fi
  return 0
}

# sdd_role → $SDD_ROLE, o el rol cuya .name coincide con el nombre de esta sesión
# (~/.claude/sessions/<CLAUDE_PID|PPID>.json, registro no documentado). Nunca falla.
sdd_role() {
  if [ -n "${SDD_ROLE:-}" ]; then printf '%s\n' "$SDD_ROLE"; return 0; fi
  local sess name
  sess="${HOME:-}/.claude/sessions/${CLAUDE_PID:-$PPID}.json"
  [ -f "$sess" ] || return 0
  name=$(sdd_json_get "$sess" '.name // empty') || name=""
  [ -n "$name" ] || return 0
  sdd_role_by_name "$name" || true
  return 0
}

# sdd_role_exists ROLE → 0 si el rol está en el registro.
sdd_role_exists() {
  local reg role="$1"
  reg=$(sdd_registry_file)
  [ -f "$reg" ] && [ -n "$role" ] || return 1
  if sdd_has_jq; then
    jq -e --arg r "$role" '.roles[$r] != null' "$reg" >/dev/null 2>&1
  elif sdd_has_node; then
    SDD_REG="$reg" SDD_ROLE_Q="$role" node -e '
      try { const r = JSON.parse(require("fs").readFileSync(process.env.SDD_REG, "utf8")).roles || {};
        process.exit(r[process.env.SDD_ROLE_Q] ? 0 : 1); } catch (e) { process.exit(1); }' 2>/dev/null
  else
    return 1
  fi
}

# sdd_role_list ROLE FIELD → elementos del array (uno por línea); vacío si no hay fichero.
sdd_role_list() {
  local reg role="$1" field="$2"
  reg=$(sdd_registry_file)
  [ -f "$reg" ] && [ -n "$role" ] || return 0
  if sdd_has_jq; then
    jq -r --arg r "$role" --arg f "$field" '.roles[$r][$f] // [] | .[] | tostring' "$reg" 2>/dev/null || true
  elif sdd_has_node; then
    SDD_REG="$reg" SDD_ROLE_Q="$role" SDD_FIELD="$field" node -e '
      try { const r = JSON.parse(require("fs").readFileSync(process.env.SDD_REG, "utf8")).roles || {};
        const v = (r[process.env.SDD_ROLE_Q] || {})[process.env.SDD_FIELD];
        if (Array.isArray(v)) process.stdout.write(v.map(String).join("\n") + (v.length ? "\n" : "")); } catch (e) {}' 2>/dev/null || true
  fi
  return 0
}
sdd_role_owns() { sdd_role_list "$1" owns; }
sdd_role_stages() { sdd_role_list "$1" stages; }

# sdd_peers → líneas `name(status)` de las sesiones vivas (~/.claude/sessions/*.json) con
# pid ≠ CLAUDE_PID y el mismo git-common-dir que STATE_ROOT. Siempre devuelve 0.
sdd_peers() {
  local me="${CLAUDE_PID:-0}" mine f pid cwd name status common
  mine=$(sdd_git_common_dir "${STATE_ROOT:-${PROJECT_DIR:-$PWD}}") || return 0
  for f in "${HOME:-}"/.claude/sessions/*.json; do
    [ -f "$f" ] || continue
    pid=$(sdd_json_get "$f" '.pid // empty') || pid=""
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    [ "$pid" != "$me" ] || continue
    kill -0 "$pid" 2>/dev/null || continue
    cwd=$(sdd_json_get "$f" '.cwd // empty') || cwd=""
    [ -n "$cwd" ] && [ -d "$cwd" ] || continue
    common=$(sdd_git_common_dir "$cwd") || continue
    [ "$common" = "$mine" ] || continue
    name=$(sdd_json_get "$f" '.name // empty') || name=""
    status=$(sdd_json_get "$f" '.status // empty') || status=""
    printf '%s(%s)\n' "${name:-pid$pid}" "${status:-?}"
  done
  return 0
}
