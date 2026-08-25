#!/usr/bin/env bash
# sdd-up.sh — launches one Claude Code session per SDD role, each inside its own tmux session.
#
# Usage: bash sdd-up.sh [-d DIR] [--dry-run] ROLE [ROLE...]
#   -d DIR      main checkout that holds .claude/sdd-sessions.json
#               (default: $SDD_STATE_ROOT, else the git common dir of the cwd, else the cwd)
#   --dry-run   print the commands without running anything
#   ROLE        key under "roles" in .claude/sdd-sessions.json (sdd-lead, sdd-spec, impl-f1a, ...)
#
# For every role:
#   1. refuses to start if a live Claude session already uses the role's session name
#      (registry $CLAUDE_CONFIG_DIR/sessions/<pid>.json — undocumented, ignored when absent)
#      or a tmux session with that name exists;
#   2. creates the role's worktree when configured and missing:
#      git worktree add <wt> -b feat/fase-<N>-<stream> fase-<N>-foundation  (HEAD if the tag is missing);
#   3. tmux new-session -d -s <name> -c <dir> -e SDD_ROLE=<role> -e SDD_STATE_ROOT=<root> "claude [$SDD_CLAUDE_ARGS] -n <name>"
#      (SDD_CLAUDE_ARGS: flags extra para claude, p. ej. "--plugin-dir /ruta/al/plugin" para probar una versión local)
#      (tmux < 3.2 has no -e: the variables are passed through env(1));
#   4. waits ~2 s and sends "/color <color>" to the new session.
# Without tmux the equivalent manual command is printed instead.
#
# Portable: bash 3.2, jq preferred with a node fallback.

set -euo pipefail

DRY_RUN=false
OPT_DIR=""
ROLES=()

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -d)        shift; OPT_DIR="${1:-}" ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    -*)        echo "sdd-up: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    *)         ROLES+=("$1") ;;
  esac
  shift
done

log()  { echo "[sdd-up] $*"; }
warn() { echo "[sdd-up] WARN: $*" >&2; }
die()  { echo "[sdd-up] ERROR: $*" >&2; exit 1; }

[ "${#ROLES[@]}" -gt 0 ] || { usage >&2; exit 2; }

HAS_JQ=false;   command -v jq   >/dev/null 2>&1 && HAS_JQ=true
HAS_NODE=false; command -v node >/dev/null 2>&1 && HAS_NODE=true
[ "$HAS_JQ" = true ] || [ "$HAS_NODE" = true ] || die "jq or node is required to read .claude/sdd-sessions.json"

# ── Locate the main checkout and the sessions file ───────────────────────────
if [ -n "$OPT_DIR" ]; then
  ROOT="$(cd "$OPT_DIR" 2>/dev/null && pwd)" || die "directory not found: $OPT_DIR"
elif [ -n "${SDD_STATE_ROOT:-}" ]; then
  ROOT="$SDD_STATE_ROOT"
else
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ]; then
    case "$common" in /*) ;; *) common="$PWD/$common" ;; esac
    ROOT="$(cd "$(dirname "$common")" && pwd)"
  else
    ROOT="$PWD"
  fi
fi
SESSIONS="$ROOT/.claude/sdd-sessions.json"
[ -f "$SESSIONS" ] || die "$SESSIONS not found — run /sdd-setup --multisession in the main checkout"

# ── JSON helpers (jq, else node) ─────────────────────────────────────────────
cfg() { # cfg KEY ROLE → value or empty
  if [ "$HAS_JQ" = true ]; then
    jq -r --arg r "$2" --arg k "$1" '.roles[$r][$k] // empty' "$SESSIONS" 2>/dev/null || true
  else
    node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const v=((s.roles||{})[process.argv[2]]||{})[process.argv[3]];if(v!==undefined&&v!==null)process.stdout.write(String(v));' "$SESSIONS" "$2" "$1" 2>/dev/null || true
  fi
}
top() { # top KEY → top-level value or empty
  if [ "$HAS_JQ" = true ]; then
    jq -r --arg k "$1" '.[$k] // empty' "$SESSIONS" 2>/dev/null || true
  else
    node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const v=s[process.argv[2]];if(v!==undefined&&v!==null)process.stdout.write(String(v));' "$SESSIONS" "$1" 2>/dev/null || true
  fi
}
role_exists() {
  if [ "$HAS_JQ" = true ]; then
    jq -e --arg r "$1" '.roles[$r] | type == "object"' "$SESSIONS" >/dev/null 2>&1
  else
    node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.exit(typeof (s.roles||{})[process.argv[2]]==="object"?0:1);' "$SESSIONS" "$1" 2>/dev/null
  fi
}
roles_list() {
  if [ "$HAS_JQ" = true ]; then
    jq -r '.roles | keys | join(", ")' "$SESSIONS" 2>/dev/null || true
  else
    node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(Object.keys(s.roles||{}).join(", "));' "$SESSIONS" 2>/dev/null || true
  fi
}

# Live Claude sessions registered under NAME (pids whose process is still alive).
live_registry_pids() {
  local dir pids p
  dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
  [ -d "$dir" ] || return 0
  set -- "$dir"/*.json
  [ -f "${1:-}" ] || return 0
  if [ "$HAS_JQ" = true ]; then
    pids="$(jq -r --arg n "$NAME" 'select(type == "object" and .name == $n) | .pid // empty' "$@" 2>/dev/null || true)"
  else
    pids="$(node -e 'const fs=require("fs");const n=process.argv[1];for(const f of process.argv.slice(2)){try{const s=JSON.parse(fs.readFileSync(f,"utf8"));if(s&&s.name===n&&s.pid)console.log(s.pid);}catch(e){}}' "$NAME" "$@" 2>/dev/null || true)"
  fi
  for p in $pids; do
    case "$p" in ''|*[!0-9]*) continue ;; esac
    if kill -0 "$p" 2>/dev/null; then echo "$p"; fi
  done
}

# ── tmux capabilities ────────────────────────────────────────────────────────
HAS_TMUX=false; command -v tmux >/dev/null 2>&1 && HAS_TMUX=true
tmux_supports_e() { # new-session -e exists since tmux 3.2
  local v maj min
  v="$(tmux -V 2>/dev/null | sed -E 's/^tmux[[:space:]]+(next-)?([0-9]+)\.([0-9]+).*/\2 \3/')"
  maj="${v%% *}"; min="${v##* }"
  case "$maj" in ''|*[!0-9]*) return 1 ;; esac
  case "$min" in ''|*[!0-9]*) return 1 ;; esac
  [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 2 ]; }
}
TMUX_E=false
if [ "$HAS_TMUX" = true ] && tmux_supports_e; then TMUX_E=true; fi

# ── Command printing / execution ─────────────────────────────────────────────
show_cmd() { # prints the argv with shell quoting where needed
  local a out="" q
  for a in "$@"; do
    case "$a" in
      *[!A-Za-z0-9_./:=@%+,-]*|"") q="'$(printf '%s' "$a" | sed "s/'/'\\\\''/g")'" ;;
      *) q="$a" ;;
    esac
    out="$out$q "
  done
  printf '  %s\n' "${out% }"
}
run() {
  show_cmd "$@"
  if [ "$DRY_RUN" = false ]; then "$@"; fi
}

command -v claude >/dev/null 2>&1 || warn "claude not found in PATH — the sessions will not start until it is installed"

PROJECT="$(top project)"
LAUNCHED=()
FAILED=0

for role in ${ROLES[@]+"${ROLES[@]}"}; do
  echo ""
  if ! role_exists "$role"; then
    warn "role '$role' is not defined in $SESSIONS (roles: $(roles_list))"
    FAILED=$((FAILED + 1))
    continue
  fi
  NAME="$(cfg name "$role")"
  [ -n "$NAME" ] || NAME="${PROJECT:-sdd}-${role#sdd-}"
  COLOR="$(cfg color "$role")"
  WT="$(cfg worktree "$role")"
  log "role $role → session '$NAME'${COLOR:+ (color $COLOR)}"

  # 1. Already running?
  busy=""
  pids="$(live_registry_pids)"
  [ -n "$pids" ] && busy="a live Claude session named '$NAME' (pid $(echo "$pids" | head -n 1))"
  if [ -z "$busy" ] && [ "$HAS_TMUX" = true ] && tmux has-session -t "=$NAME" 2>/dev/null; then
    busy="a tmux session named '$NAME'"
  fi
  if [ -n "$busy" ]; then
    if [ "$DRY_RUN" = true ]; then
      warn "[dry-run] would abort: $busy already exists (tmux attach -t =$NAME)"
    else
      warn "skipping $role: $busy already exists (tmux attach -t =$NAME)"
      FAILED=$((FAILED + 1))
      continue
    fi
  fi

  # 2. Working directory (worktree roles)
  if [ -n "$WT" ]; then
    case "$WT" in /*) DIR="$WT" ;; *) DIR="$ROOT/$WT" ;; esac
    # Normalise "../x" lexically while the target does not exist yet (its parent must).
    if [ ! -d "$DIR" ] && [ -d "$(dirname "$DIR")" ]; then
      DIR="$(cd "$(dirname "$DIR")" && pwd)/$(basename "$DIR")"
    fi
    if [ ! -d "$DIR" ]; then
      FASE="$(cfg fase "$role")"
      STREAM="$(cfg stream "$role" | tr '[:upper:]' '[:lower:]')"
      if [ -n "$FASE" ] && [ -n "$STREAM" ]; then
        BRANCH="feat/fase-${FASE}-${STREAM}"
        BASE="fase-${FASE}-foundation"
      else
        BRANCH="feat/${role}"
        BASE="fase-0-foundation"
        warn "role $role has a worktree but no fase/stream — branch $BRANCH"
      fi
      if ! git -C "$ROOT" rev-parse -q --verify "refs/tags/$BASE" >/dev/null 2>&1; then
        warn "tag $BASE not found in $ROOT — branching $BRANCH from HEAD"
        BASE="HEAD"
      fi
      log "creating worktree $DIR"
      if git -C "$ROOT" rev-parse -q --verify "refs/heads/$BRANCH" >/dev/null 2>&1; then
        run git -C "$ROOT" worktree add "$DIR" "$BRANCH"
      else
        run git -C "$ROOT" worktree add "$DIR" -b "$BRANCH" "$BASE"
      fi
    fi
    if [ -d "$DIR" ]; then DIR="$(cd "$DIR" && pwd)"; fi
  else
    DIR="$ROOT"
  fi

  # 3. Launch
  if [ "$HAS_TMUX" = true ]; then
    if [ "$TMUX_E" = true ]; then
      run tmux new-session -d -s "$NAME" -c "$DIR" -e "SDD_ROLE=$role" -e "SDD_STATE_ROOT=$ROOT" "claude${SDD_CLAUDE_ARGS:+ $SDD_CLAUDE_ARGS} -n $NAME"
    else
      run tmux new-session -d -s "$NAME" -c "$DIR" "env SDD_ROLE=$role SDD_STATE_ROOT='$ROOT' claude${SDD_CLAUDE_ARGS:+ $SDD_CLAUDE_ARGS} -n $NAME"
    fi
    # 4. Colour the session once claude has had a moment to start
    if [ -n "$COLOR" ]; then
      if [ "$DRY_RUN" = false ]; then
        # esperar a que el panel exista y claude muestre su prompt (máx. ~15 s); nunca abortar por esto
        ready=false; i=0
        while [ $i -lt 30 ]; do
          # sin capture-pane (tmux antiguo o entorno de test) → mejor esfuerzo: esperar 2 s y enviar
          if ! pane=$(tmux capture-pane -t "=$NAME" -p 2>/dev/null); then sleep 2; ready=best-effort; break; fi
          if printf '%s' "$pane" | grep -q 'trust this folder'; then
            echo "  [sdd-up] $NAME: Claude pide confirmar la confianza en la carpeta; acéptala en tmux y ejecuta '/color $COLOR' a mano"
            ready=skip; break
          fi
          if printf '%s' "$pane" | grep -q '❯'; then ready=true; break; fi
          sleep 0.5; i=$((i+1))
        done
        case "$ready" in
          true|best-effort)
            tmux send-keys -t "=$NAME" "/color $COLOR" Enter 2>/dev/null || echo "  [sdd-up] $NAME: no se pudo enviar /color $COLOR (hazlo a mano)" ;;
          false)
            echo "  [sdd-up] $NAME: claude no mostró el prompt a tiempo; ejecuta '/color $COLOR' a mano" ;;
        esac
      else
        echo "  (wait for prompt) tmux send-keys -t =$NAME '/color $COLOR' Enter"
      fi
    fi
    LAUNCHED+=("$NAME")
  else
    log "tmux not found — start this session manually in a new terminal:"
    echo "  cd '$DIR' && SDD_ROLE=$role SDD_STATE_ROOT='$ROOT' claude${SDD_CLAUDE_ARGS:+ $SDD_CLAUDE_ARGS} -n $NAME"
    [ -n "$COLOR" ] && echo "  then type: /color $COLOR"
  fi
done

echo ""
if [ "${#LAUNCHED[@]}" -gt 0 ]; then
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] nothing was started. Without --dry-run, connect with:"
  else
    log "sessions started. Connect with:"
  fi
  for n in ${LAUNCHED[@]+"${LAUNCHED[@]}"}; do
    echo "  tmux attach -t =$n"
  done
  echo "  (Ctrl+B then D detaches without closing the session; tmux ls lists them)"
fi
[ "$FAILED" -eq 0 ] || exit 1
