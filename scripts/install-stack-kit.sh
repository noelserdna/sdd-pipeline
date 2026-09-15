#!/usr/bin/env bash
# install-stack-kit.sh — instala un "stack kit" de sdd-pipeline (templates/stacks/<kit>) en el proyecto.
#
# Escribe, o refresca en su sitio, un bloque gestionado en el CLAUDE.md raíz con el `## SDD Stack Profile`
# y las `## Stack Conventions` del kit, delimitado por
#   <!-- sdd-stack-begin kit=<kit> v<versión> --> … <!-- sdd-stack-end -->
# y copia sus reglas por ruta a .claude/rules/sdd-<kit>-<regla>.md con una cabecera gestionada. El texto del
# usuario fuera del bloque no se toca y una regla sin la cabecera no se sobrescribe nunca. Idempotente.
# Contrato y personalización: docs/stacks.md.
#
# Usage: install-stack-kit.sh --stack <kit|auto> [--app-dir DIR] [--port N] [--set key=value]...
#                             [--project DIR] [--dry-run] [--uninstall]
#   --stack KIT      rails | nextjs-prisma | auto (detecta en la raíz y en los directorios de primer nivel).
#                    Sin --stack refresca el kit del bloque que ya exista.
#   --app-dir DIR    directorio de la app, relativo a la raíz ("." = la raíz). Por defecto: el del bloque
#                    existente, el detectado o "."
#   --port N         puerto del servidor local (por defecto: el del bloque existente o el del kit)
#   --set key=value  sustituye una clave del perfil; repetible; se recuerda en los refrescos; con valor vacío
#                    (--set key=) vuelve al valor del kit. {port} y {app_dir} se sustituyen también aquí.
#                    Una `acceptance` distinta de none implica `e2e_scaffold: never` salvo --set explícito.
#   --project DIR    raíz del proyecto (por defecto la raíz git, o el directorio actual)
#   --dry-run        enseña lo que haría y el bloque renderizado; no escribe nada
#   --uninstall      quita el bloque y las reglas gestionadas (.claude/rules/sdd-*.md con la cabecera)
#
# Salida: 0 ok · 1 no se pudo (nada detectado, bloque corrupto) · 2 uso incorrecto o kit desconocido.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
STACKS="$PLUGIN_ROOT/templates/stacks"

END_LINE='<!-- sdd-stack-end -->'
RULE_MARK='<!-- sdd-stack-kit managed'
NL='
'

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARN %s\n' "$*" >&2; }
die()  { printf 'install-stack-kit: %s\n' "$1" >&2; exit "${2:-1}"; }
usage() { sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── Argumentos ───────────────────────────────────────────────────────────────
STACK=""; APP_DIR=""; PORT=""; PROJECT=""; DRYRUN=false; UNINSTALL=false
NEW_SETS=""   # una línea key=value por --set

add_set() {
  local kv="$1" key value
  case "$kv" in *=*) ;; *) die "--set espera key=value (recibido '$kv')" 2 ;; esac
  key="${kv%%=*}"; value="${kv#*=}"
  case "$key" in ''|*[!a-z0-9_]*) die "--set: clave inválida '$key'" 2 ;; esac
  case "$value" in *"$NL"*|*'-->'*) die "--set $key: el valor no puede contener saltos de línea ni '-->'" 2 ;; esac
  case "$key" in
    stack)   die "--set stack: usa --stack" 2 ;;
    app_dir) APP_DIR="$value" ;;
    port)    PORT="$value" ;;
    *)       NEW_SETS="$NEW_SETS$key=$value$NL" ;;
  esac
}
need_val() { [ $# -ge 2 ] || die "$1 necesita un valor" 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --stack=*)   STACK="${1#*=}" ;;
    --stack)     need_val "$@"; STACK="$2"; shift ;;
    --app-dir=*) APP_DIR="${1#*=}" ;;
    --app-dir)   need_val "$@"; APP_DIR="$2"; shift ;;
    --port=*)    PORT="${1#*=}" ;;
    --port)      need_val "$@"; PORT="$2"; shift ;;
    --set=*)     add_set "${1#*=}" ;;
    --set)       need_val "$@"; add_set "$2"; shift ;;
    --project=*) PROJECT="${1#*=}" ;;
    --project)   need_val "$@"; PROJECT="$2"; shift ;;
    --dry-run)   DRYRUN=true ;;
    --uninstall) UNINSTALL=true ;;
    -h|--help)   usage; exit 0 ;;
    *) die "argumento desconocido '$1' (--help para la ayuda)" 2 ;;
  esac
  shift
done

if [ -n "$PROJECT" ]; then
  cd "$PROJECT" 2>/dev/null || die "--project: no existe '$PROJECT'" 2
else
  top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top" ]; then cd "$top"; fi
fi
CLAUDE_MD="CLAUDE.md"
RULES_DIR=".claude/rules"

TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

# ── Lectura de kit.json (jq → node → python3) ────────────────────────────────
# kj FILE PATH → escalar; o un elemento de array por línea; o "clave=valor" por entrada de objeto
kj() {
  if have jq; then
    jq -r --arg p "$2" 'getpath($p | split(".")) | if type == "array" then .[] elif type == "object" then to_entries[] | "\(.key)=\(.value)" elif . == null then empty else tostring end' "$1"
  elif have node; then
    node -e '
      const fs = require("fs"); const [f, p] = process.argv.slice(1);
      let v = JSON.parse(fs.readFileSync(f, "utf8"));
      for (const k of p.split(".")) v = (v && typeof v === "object") ? v[k] : undefined;
      const out = (x) => process.stdout.write(String(x) + "\n");
      if (Array.isArray(v)) v.forEach(out);
      else if (v && typeof v === "object") Object.entries(v).forEach(([a, b]) => out(a + "=" + b));
      else if (v !== undefined && v !== null) out(v);' "$1" "$2"
  elif have python3; then
    python3 -c 'import json, sys
v = json.load(open(sys.argv[1], encoding="utf-8"))
for k in sys.argv[2].split("."):
    v = v.get(k) if isinstance(v, dict) else None
items = v if isinstance(v, list) else (["%s=%s" % kv for kv in v.items()] if isinstance(v, dict) else ([] if v is None else [v]))
for x in items: print(x)' "$1" "$2"
  else
    die "hace falta jq, node o python3 para leer $1"
  fi
}

available_kits() {
  local d
  for d in "$STACKS"/*/; do
    if [ -f "$d/kit.json" ]; then basename "$d"; fi
  done
}
kits_csv() { available_kits | awk 'BEGIN { ORS = "" } { printf "%s%s", (NR > 1 ? ", " : ""), $0 }'; }

# ── Detección ────────────────────────────────────────────────────────────────
# matches_kit KIT DIR → 0 si DIR contiene todos los detect.all y, si hay detect.any, alguno de ellos
matches_kit() {
  local file="$STACKS/$1/kit.json" dir="$2" f any
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -e "$dir/$f" ] || return 1
  done <<EOF
$(kj "$file" detect.all)
EOF
  any=$(kj "$file" detect.any)
  [ -n "$any" ] || return 0
  while IFS= read -r f; do
    if [ -n "$f" ] && [ -e "$dir/$f" ]; then return 0; fi
  done <<EOF
$any
EOF
  return 1
}

candidate_dirs() {
  local d
  printf '.\n'
  for d in */; do
    [ -d "$d" ] || continue
    d=${d%/}
    case "$d" in node_modules|vendor|tmp|log) continue ;; esac
    printf '%s\n' "$d"
  done
}

# detect [KIT] → líneas "kit<TAB>dir" (raíz primero)
detect() {
  local only="${1:-}" k d
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    for k in $(available_kits); do
      if [ -n "$only" ] && [ "$k" != "$only" ]; then continue; fi
      if matches_kit "$k" "$d"; then printf '%s\t%s\n' "$k" "$d"; fi
    done
  done <<EOF
$(candidate_dirs)
EOF
}

# ── Bloque existente ─────────────────────────────────────────────────────────
block_kit() {
  [ -f "$CLAUDE_MD" ] || return 0
  awk 'match($0, /^<!-- sdd-stack-begin kit=[a-z0-9-]+/) { print substr($0, 26, RLENGTH - 25); exit }' "$CLAUDE_MD"
}
# block_field KEY → valor de "- KEY: …" dentro del bloque gestionado
block_field() {
  [ -f "$CLAUDE_MD" ] || return 0
  awk -v key="$1" '
    /^<!-- sdd-stack-begin kit=/ { inb = 1; next }
    /^<!-- sdd-stack-end -->/    { inb = 0; next }
    inb && index($0, "- " key ": ") == 1 { print substr($0, length(key) + 5); exit }' "$CLAUDE_MD"
}
# block_sets → "key=value" de las líneas <!-- sdd-stack-set key=value --> del bloque
block_sets() {
  [ -f "$CLAUDE_MD" ] || return 0
  awk '
    /^<!-- sdd-stack-begin kit=/ { inb = 1; next }
    /^<!-- sdd-stack-end -->/    { inb = 0; next }
    inb && /^<!-- sdd-stack-set [a-z0-9_]+=/ { s = substr($0, 20); sub(/ -->[ \t]*$/, "", s); print s }' "$CLAUDE_MD"
}

# stdin key=value en orden → la última gana, valor vacío la borra; salida ordenada por clave
merge_sets() {
  awk '{ i = index($0, "="); if (i < 2) next; k = substr($0, 1, i - 1); v = substr($0, i + 1)
         if (v == "") delete s[k]; else s[k] = v }
       END { for (k in s) print k "=" s[k] }' | LC_ALL=C sort
}

strip_trailing_blank() { awk 'NF == 0 { blank++; next } { while (blank > 0) { print ""; blank-- } print }'; }

# ── Render ───────────────────────────────────────────────────────────────────
# render FILE SETS_FILE → sustituye líneas "- clave: …" con SETS_FILE, luego {app_dir} y {port}
render() {
  awk -v app="$APP_DIR" -v port="$PORT" -v setsf="$2" '
    BEGIN {
      while ((getline l < setsf) > 0) { i = index(l, "="); if (i > 1) ov[substr(l, 1, i - 1)] = substr(l, i + 1) }
      if (("acceptance" in ov) && ov["acceptance"] != "none" && !("e2e_scaffold" in ov)) ov["e2e_scaffold"] = "never"
    }
    {
      line = $0
      if (match(line, /^- [a-z0-9_]+: /)) { k = substr(line, 3, RLENGTH - 4); if (k in ov) line = "- " k ": " ov[k] }
      if (app == ".") gsub(/\{app_dir\}\//, "", line)
      gsub(/\{app_dir\}/, app, line)
      gsub(/\{port\}/, port, line)
      print line
    }' "$1" | strip_trailing_blank
}

build_block() {
  local kv
  printf '<!-- sdd-stack-begin kit=%s v%s -->\n' "$KIT" "$VERSION"
  printf '<!-- Managed by sdd-pipeline scripts/install-stack-kit.sh: edits inside this block are lost on refresh; use --set or write outside it. -->\n'
  while IFS= read -r kv; do
    if [ -n "$kv" ]; then printf '<!-- sdd-stack-set %s -->\n' "$kv"; fi
  done < "$SETS_FILE"
  render "$KITDIR/profile.md" "$SETS_FILE"
  printf '\n'
  render "$KITDIR/conventions.md" /dev/null
  printf '%s\n' "$END_LINE"
}

# compose_install BLOCK_FILE → CLAUDE.md con el bloque sustituido en su sitio o añadido al final
compose_install() {
  if [ -f "$CLAUDE_MD" ] && grep -q '^<!-- sdd-stack-begin kit=' "$CLAUDE_MD"; then
    awk -v blockf="$1" '
      /^<!-- sdd-stack-begin kit=/ { if (!done) { while ((getline l < blockf) > 0) print l; done = 1 } skip = 1; next }
      skip { if ($0 ~ /^<!-- sdd-stack-end -->[ \t]*$/) skip = 0; next }
      { print }' "$CLAUDE_MD"
  elif [ -s "$CLAUDE_MD" ]; then
    strip_trailing_blank < "$CLAUDE_MD"
    printf '\n'
    cat "$1"
  else
    cat "$1"
  fi
}

# compose_uninstall → CLAUDE.md sin el bloque (ni la línea en blanco doble que deja el hueco)
compose_uninstall() {
  awk '
    /^<!-- sdd-stack-begin kit=/ { skip = 1; drop = prev_blank; next }
    skip { if ($0 ~ /^<!-- sdd-stack-end -->[ \t]*$/) { skip = 0; after = 1 } next }
    after && NF == 0 && drop { after = 0; next }
    { after = 0; print; prev_blank = (NF == 0) }' "$CLAUDE_MD" \
  | awk 'NF == 0 && !started { next } { started = 1; print }' | strip_trailing_blank
}

check_block_integrity() {
  [ -f "$CLAUDE_MD" ] || return 0
  local b e
  b=$(grep -c '^<!-- sdd-stack-begin kit=' "$CLAUDE_MD" || true)
  e=$(grep -c '^<!-- sdd-stack-end -->' "$CLAUDE_MD" || true)
  if [ "$b" != "$e" ]; then
    die "CLAUDE.md tiene $b marcas sdd-stack-begin y $e sdd-stack-end: repáralo a mano antes de continuar" 1
  fi
}

# ── Reglas ───────────────────────────────────────────────────────────────────
rule_render() {  # rule_render SRC NAME → frontmatter + cabecera gestionada + cuerpo, con {app_dir}/{port}
  local header="$RULE_MARK kit=$KIT v$VERSION rule=$2: regenerated by install-stack-kit.sh; delete this line to customize (the installer then leaves the file alone) -->"
  awk -v app="$APP_DIR" -v port="$PORT" -v header="$header" '
    {
      line = $0
      if (app == ".") gsub(/\{app_dir\}\//, "", line)
      gsub(/\{app_dir\}/, app, line)
      gsub(/\{port\}/, port, line)
    }
    NR == 1 && line == "---" { fm = 1; print line; next }
    fm && line == "---"      { print line; print header; fm = 0; next }
    NR == 1                  { print header }
    { print line }' "$1"
}

act() {  # act ESTADO RUTA
  if [ "$DRYRUN" = true ]; then printf '[dry-run] %-10s %s\n' "$1" "$2"; else printf '%-10s %s\n' "$1" "$2"; fi
}

# remove_managed_rules " nombre.md nombre2.md " → borra las reglas gestionadas que no estén en la lista
remove_managed_rules() {
  local keep="$1" f b
  [ -d "$RULES_DIR" ] || return 0
  for f in "$RULES_DIR"/sdd-*.md; do
    [ -f "$f" ] || continue
    grep -qF "$RULE_MARK" "$f" || continue
    b=$(basename "$f")
    case "$keep" in *" $b "*) continue ;; esac
    if [ "$DRYRUN" != true ]; then rm -f "$f"; fi
    act removed "$f"
  done
}

install_rules() {
  local name src dest state wanted=" "
  for name in $(kj "$KITDIR/kit.json" rules); do
    src="$KITDIR/rules/$name.md"
    dest="$RULES_DIR/sdd-$KIT-$name.md"
    wanted="${wanted}sdd-$KIT-$name.md "
    if [ ! -f "$src" ]; then warn "kit $KIT: falta rules/$name.md"; continue; fi
    rule_render "$src" "$name" > "$TMPD/rule"
    if [ -f "$dest" ] && ! grep -qF "$RULE_MARK" "$dest"; then
      act skipped "$dest (exists without the managed header: left untouched)"
      continue
    fi
    if [ ! -f "$dest" ]; then state=created
    elif cmp -s "$TMPD/rule" "$dest"; then state=unchanged
    else state=updated; fi
    if [ "$DRYRUN" != true ] && [ "$state" != unchanged ]; then
      mkdir -p "$RULES_DIR"
      cat "$TMPD/rule" > "$dest"
    fi
    act "$state" "$dest"
  done
  remove_managed_rules "$wanted"
}

join_lines() {  # join_lines PREFIJO SEP ← stdin
  awk -v p="$1" -v sep="$2" 'BEGIN { ORS = "" } NF { printf "%s%s%s", (n++ ? sep : ""), p, $0 } END { print "\n" }'
}

# ── --uninstall ──────────────────────────────────────────────────────────────
if [ "$UNINSTALL" = true ]; then
  check_block_integrity
  if [ -f "$CLAUDE_MD" ] && grep -q '^<!-- sdd-stack-begin kit=' "$CLAUDE_MD"; then
    old_kit=$(block_kit)
    compose_uninstall > "$TMPD/claude"
    if [ -s "$TMPD/claude" ]; then
      if [ "$DRYRUN" != true ]; then cat "$TMPD/claude" > "$CLAUDE_MD"; fi
      act removed "$CLAUDE_MD (block kit=$old_kit)"
    else
      if [ "$DRYRUN" != true ]; then rm -f "$CLAUDE_MD"; fi
      act removed "$CLAUDE_MD (it only contained the block kit=$old_kit)"
    fi
  else
    say "CLAUDE.md: no sdd-stack block"
  fi
  remove_managed_rules " "
  if [ "$DRYRUN" != true ]; then rmdir "$RULES_DIR" .claude 2>/dev/null || true; fi
  exit 0
fi

# ── Kit ──────────────────────────────────────────────────────────────────────
check_block_integrity
EXISTING_KIT=$(block_kit)
DETECTED_DIR=""
case "$STACK" in
  "")
    [ -n "$EXISTING_KIT" ] || die "falta --stack <kit|auto> (kits: $(kits_csv))" 2
    KIT="$EXISTING_KIT"
    ;;
  auto)
    matches=$(detect)
    n=$(printf '%s\n' "$matches" | grep -c . || true)
    if [ "$n" -eq 1 ]; then
      KIT=$(printf '%s' "$matches" | cut -f1)
      DETECTED_DIR=$(printf '%s' "$matches" | cut -f2)
      say "auto: detected kit $KIT in $DETECTED_DIR"
    elif [ "$n" -eq 0 ] && [ -n "$EXISTING_KIT" ]; then
      KIT="$EXISTING_KIT"
      say "auto: nothing detected; refreshing the installed kit $KIT"
    elif [ "$n" -eq 0 ]; then
      die "auto: no stack detected in $(pwd) or its first-level directories; pass --stack <kit> [--app-dir DIR] (kits: $(kits_csv))" 1
    else
      die "auto: several stacks detected ($(printf '%s\n' "$matches" | join_lines '' ', ' | tr '\t' ' ')); pass --stack <kit> --app-dir DIR" 1
    fi
    ;;
  *) KIT="$STACK" ;;
esac
case "$KIT" in ''|*[!a-z0-9-]*) die "kit inválido '$KIT' (kits: $(kits_csv))" 2 ;; esac
KITDIR="$STACKS/$KIT"
[ -f "$KITDIR/kit.json" ] || die "kit desconocido '$KIT' (kits: $(kits_csv))" 2
for f in profile.md conventions.md; do [ -f "$KITDIR/$f" ] || die "kit $KIT incompleto: falta $f" 1; done
VERSION=$(kj "$KITDIR/kit.json" version)

SAME_KIT=false
if [ -n "$EXISTING_KIT" ] && [ "$EXISTING_KIT" = "$KIT" ]; then SAME_KIT=true; fi

# app_dir: --app-dir > bloque del mismo kit > detectado > detección del kit > defaults.app_dir > "."
if [ -z "$APP_DIR" ] && [ "$SAME_KIT" = true ]; then APP_DIR=$(block_field app_dir); fi
if [ -z "$APP_DIR" ] && [ -n "$DETECTED_DIR" ]; then APP_DIR="$DETECTED_DIR"; fi
if [ -z "$APP_DIR" ] && [ "$STACK" != auto ]; then
  matches=$(detect "$KIT")
  n=$(printf '%s\n' "$matches" | grep -c . || true)
  if [ "$n" -eq 1 ]; then
    APP_DIR=$(printf '%s' "$matches" | cut -f2)
    say "detected $KIT app in $APP_DIR"
  elif [ "$n" -gt 1 ]; then
    warn "$KIT detected in several directories ($(printf '%s\n' "$matches" | cut -f2 | join_lines '' ', ')); using the kit default: pass --app-dir"
  fi
fi
if [ -z "$APP_DIR" ]; then APP_DIR=$(kj "$KITDIR/kit.json" defaults.app_dir); fi
while :; do case "$APP_DIR" in ./*) APP_DIR="${APP_DIR#./}" ;; */) APP_DIR="${APP_DIR%/}" ;; *) break ;; esac; done
[ -n "$APP_DIR" ] || APP_DIR="."
case "$APP_DIR" in /*|..|../*|*/..|*/../*) die "--app-dir debe ser relativo a la raíz del proyecto y sin '..' (recibido '$APP_DIR')" 2 ;; esac
case "$APP_DIR" in *[!A-Za-z0-9._/-]*) die "--app-dir: solo letras, dígitos, '.', '_', '-' y '/' (recibido '$APP_DIR')" 2 ;; esac
if [ ! -d "$APP_DIR" ]; then warn "app_dir '$APP_DIR' does not exist yet: create the app there before implementing"; fi

# port: --port > bloque del mismo kit > defaults.port > 3000
if [ -z "$PORT" ] && [ "$SAME_KIT" = true ]; then PORT=$(block_field port); fi
if [ -z "$PORT" ]; then PORT=$(kj "$KITDIR/kit.json" defaults.port); fi
[ -n "$PORT" ] || PORT=3000
case "$PORT" in *[!0-9]*) die "--port: número entre 1 y 65535 (recibido '$PORT')" 2 ;; esac
if [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then die "--port: número entre 1 y 65535 (recibido '$PORT')" 2; fi

# --set: se validan las nuevas; las recordadas de una versión anterior con claves que ya no existen se descartan
KEYS=" $(sed -n 's/^- \([a-z0-9_]*\): .*/\1/p' "$KITDIR/profile.md" | tr '\n' ' ') "
while IFS= read -r kv; do
  [ -n "$kv" ] || continue
  case "$KEYS" in *" ${kv%%=*} "*) ;; *) die "--set: clave desconocida '${kv%%=*}' en el perfil del kit $KIT" 2 ;; esac
done <<EOF
$NEW_SETS
EOF
: > "$TMPD/sets.raw"
if [ "$SAME_KIT" = true ]; then block_sets >> "$TMPD/sets.raw"; fi
printf '%s' "$NEW_SETS" >> "$TMPD/sets.raw"
SETS_FILE="$TMPD/sets"
: > "$SETS_FILE"
while IFS= read -r kv; do
  [ -n "$kv" ] || continue
  case "$KEYS" in
    *" ${kv%%=*} "*) printf '%s\n' "$kv" >> "$SETS_FILE" ;;
    *) warn "dropping stored --set ${kv%%=*}: the key no longer exists in kit $KIT v$VERSION" ;;
  esac
done <<EOF
$(merge_sets < "$TMPD/sets.raw")
EOF

# ── CLAUDE.md ────────────────────────────────────────────────────────────────
build_block > "$TMPD/block"
compose_install "$TMPD/block" > "$TMPD/claude"
if [ ! -f "$CLAUDE_MD" ]; then cstate=created
elif cmp -s "$TMPD/claude" "$CLAUDE_MD"; then cstate=unchanged
elif [ -n "$EXISTING_KIT" ] && [ "$EXISTING_KIT" != "$KIT" ]; then cstate=replaced
elif [ -n "$EXISTING_KIT" ]; then cstate=refreshed
else cstate=added; fi

say "stack kit $KIT v$VERSION · app_dir=$APP_DIR · port=$PORT · project=$(pwd)"
if [ "$DRYRUN" != true ] && [ "$cstate" != unchanged ]; then cat "$TMPD/claude" > "$CLAUDE_MD"; fi
if [ "$cstate" = replaced ]; then act "$cstate" "$CLAUDE_MD (block kit=$EXISTING_KIT → kit=$KIT)"; else act "$cstate" "$CLAUDE_MD (block kit=$KIT v$VERSION)"; fi
install_rules

if [ "$APP_DIR" = "." ]; then prefix=""; else prefix="$APP_DIR/"; fi
say "wiring:  $(kj "$KITDIR/kit.json" wiring | join_lines "$prefix" ', ')"
say "layers:  $(kj "$KITDIR/kit.json" layers | join_lines '' ' > ')"
if [ "$DRYRUN" = true ]; then
  say ""
  say "--- rendered block (CLAUDE.md) ---"
  cat "$TMPD/block"
fi
