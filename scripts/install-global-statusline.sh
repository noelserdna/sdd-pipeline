#!/usr/bin/env bash
# install-global-statusline.sh — instala la barra de estado GLOBAL en el settings DEL USUARIO.
#
# Un plugin no puede escribir `statusLine` en ~/.claude/settings.json (es del usuario, no del
# proyecto), así que este script lo hace explícitamente:
#   1. crea <config>/sdd/ y copia scripts/sdd-status-line-global.sh a <config>/sdd/status-line.sh
#      — RUTA ESTABLE a propósito: la carpeta del plugin cambia en cada actualización, la del
#      settings del usuario no puede apuntar a una versión concreta;
#   2. añade a <config>/settings.json el bloque
#      "statusLine": {"type":"command","command":"bash ~/.claude/sdd/status-line.sh","refreshInterval":5}
#      con copia de seguridad previa y preguntando si ya hay otro `statusLine` distinto.
#
# Usage: install-global-statusline.sh [--force] [--dry-run] [--uninstall] [--print-only]
#   --force        reemplaza un statusLine ajeno sin preguntar (obligatorio si no hay terminal)
#   --dry-run      enseña lo que haría, no toca nada
#   --uninstall    quita el statusLine si es el nuestro y borra <config>/sdd/status-line.sh
#   --print-only   solo imprime el bloque JSON, para pegarlo a mano
#
# Es de USUARIO, no de proyecto: la barra sale en TODAS las sesiones de Claude Code de esta máquina y
# no imprime nada en los proyectos sin SDD. El equivalente por proyecto es el paso 3 de /sdd-setup
# (.claude/sdd-status-line.sh), que solo mira el proyecto de la sesión. Se pueden tener las dos.
set -euo pipefail

FORCE=false; DRYRUN=false; UNINSTALL=false; PRINTONLY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --force)      FORCE=true ;;
    --dry-run)    DRYRUN=true ;;
    --uninstall)  UNINSTALL=true ;;
    --print-only) PRINTONLY=true ;;
    -h|--help)    sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install-global-statusline: argumento desconocido '$1'" >&2; exit 2 ;;
  esac
  shift
done

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SCRIPT_DIR="."
SRC="$SCRIPT_DIR/sdd-status-line-global.sh"
CFG="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
DEST_DIR="$CFG/sdd"
DEST="$DEST_DIR/status-line.sh"
SETTINGS="$CFG/settings.json"
# Con CLAUDE_CONFIG_DIR a medida el `~` no vale: se escribe la ruta absoluta.
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then CMD="bash $DEST"; else CMD="bash ~/.claude/sdd/status-line.sh"; fi

say() { printf '%s\n' "$*"; }
die() { printf 'install-global-statusline: %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
have jq || have node || die "hace falta jq o node para editar $SETTINGS"

# settings_get EXPR → valor (vacío si no hay fichero o no hay clave)
settings_get() {
  [ -f "$SETTINGS" ] || return 0
  if have jq; then jq -r "$1 // empty" "$SETTINGS" 2>/dev/null || true
  else SDD_F="$SETTINGS" SDD_E="$1" node -e '
    const fs = require("fs");
    try {
      const s = JSON.parse(fs.readFileSync(process.env.SDD_F, "utf8"));
      const path = process.env.SDD_E.split(".").filter(Boolean);
      let v = s; for (const k of path) v = (v && typeof v === "object") ? v[k] : undefined;
      if (v !== undefined && v !== null) process.stdout.write(typeof v === "string" ? v : JSON.stringify(v));
    } catch (e) {}' 2>/dev/null || true
  fi
}

BLOCK='{"type":"command","command":"'"$CMD"'","refreshInterval":5}'
if [ "$PRINTONLY" = true ]; then
  say "Añade a $SETTINGS:"
  say "  \"statusLine\": $BLOCK"
  exit 0
fi

backup() {
  local b
  [ -f "$SETTINGS" ] || return 0
  b="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
  if [ "$DRYRUN" = true ]; then say "[dry-run] copia de seguridad → $b"; return 0; fi
  cp "$SETTINGS" "$b" && say "copia de seguridad: $b"
}

write_settings() { # $1 = programa jq | $2 = programa node (recibe SETTINGS y CMD por entorno)
  local tmp="$SETTINGS.sdd.$$"
  [ -f "$SETTINGS" ] || printf '{}\n' > "$SETTINGS"
  if have jq; then
    jq --arg cmd "$CMD" "$1" "$SETTINGS" > "$tmp" && mv -f "$tmp" "$SETTINGS"
  else
    SDD_F="$SETTINGS" SDD_TMP="$tmp" SDD_CMD="$CMD" node -e "$2" && mv -f "$tmp" "$SETTINGS"
  fi
}

CURRENT=$(settings_get '.statusLine.command') || CURRENT=""

if [ "$UNINSTALL" = true ]; then
  case "$CURRENT" in
    *sdd/status-line.sh*)
      backup
      if [ "$DRYRUN" = true ]; then say "[dry-run] quitaría statusLine de $SETTINGS"; else
        write_settings 'del(.statusLine)' '
          const fs = require("fs");
          const s = JSON.parse(fs.readFileSync(process.env.SDD_F, "utf8"));
          delete s.statusLine;
          fs.writeFileSync(process.env.SDD_TMP, JSON.stringify(s, null, 2) + "\n");'
        say "statusLine quitada de $SETTINGS"
      fi ;;
    "") say "no había statusLine en $SETTINGS" ;;
    *)  say "statusLine de $SETTINGS no es la de SDD ($CURRENT): no se toca" ;;
  esac
  if [ -f "$DEST" ]; then
    if [ "$DRYRUN" = true ]; then say "[dry-run] borraría $DEST"; else rm -f "$DEST"; say "borrado $DEST"; fi
  fi
  exit 0
fi

[ -f "$SRC" ] || die "no encuentro $SRC (ejecútalo desde el checkout del plugin)"

# 1. Script en ruta estable
if [ "$DRYRUN" = true ]; then
  say "[dry-run] mkdir -p $DEST_DIR && cp $SRC $DEST"
else
  mkdir -p "$DEST_DIR"
  cp "$SRC" "$DEST" && chmod +x "$DEST"
  say "barra instalada en $DEST (ruta estable: sobrevive a las actualizaciones del plugin)"
fi

# 2. statusLine en el settings del usuario
case "$CURRENT" in
  "") ;;
  *sdd/status-line.sh*) say "statusLine ya apunta a la barra SDD: se refresca el bloque" ;;
  *)
    say "ATENCIÓN: $SETTINGS ya tiene otra statusLine:"
    say "    $CURRENT"
    if [ "$FORCE" != true ]; then
      if [ -t 0 ]; then
        printf '¿Reemplazarla por la de SDD? [y/N] '
        IFS= read -r answer || answer=""
        case "$answer" in y|Y|s|S|yes|si|sí) ;; *) say "sin cambios; --print-only enseña el bloque para combinarlo a mano"; exit 0 ;; esac
      else
        say "sin terminal para preguntar: repite con --force (o --print-only para hacerlo a mano)"
        exit 0
      fi
    fi ;;
esac

backup
if [ "$DRYRUN" = true ]; then
  say "[dry-run] statusLine → $BLOCK"
else
  write_settings '.statusLine = {type: "command", command: $cmd, refreshInterval: 5}' '
    const fs = require("fs");
    let s = {};
    try { s = JSON.parse(fs.readFileSync(process.env.SDD_F, "utf8")); } catch (e) { s = {}; }
    if (!s || typeof s !== "object" || Array.isArray(s)) s = {};
    s.statusLine = { type: "command", command: process.env.SDD_CMD, refreshInterval: 5 };
    fs.writeFileSync(process.env.SDD_TMP, JSON.stringify(s, null, 2) + "\n");'
  say "statusLine escrita en $SETTINGS: $CMD (refreshInterval 5)"
  say "Se ve en la siguiente sesión de Claude Code. Para quitarla: $0 --uninstall"
fi
exit 0
