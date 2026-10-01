#!/usr/bin/env bash
# Preview the status page template with a data file, without the sdd CLI.
#
#   bash templates/status-page/preview.sh [data.json] [--out DIR] [--no-images]
#
# Writes DIR/index.html (the template with the data embedded the same way `sdd status build` does)
# and, unless --no-images, placeholder PNGs for every published capture the data names, so the page
# can be opened from disk. Default data: sample-data.json next to this script. Default DIR:
# $TMPDIR/sdd-status-preview. Videos are not generated: the page shows its "cannot play" note.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data="$here/sample-data.json"
out="${TMPDIR:-/tmp}"
out="${out%/}/sdd-status-preview"
images=1

while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="$2"; shift 2 ;;
    --no-images) images=0; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) data="$1"; shift ;;
  esac
done

command -v node >/dev/null 2>&1 || { echo "preview.sh: node is required" >&2; exit 1; }
[ -f "$data" ] || { echo "preview.sh: no data file at $data" >&2; exit 1; }
mkdir -p "$out"

node - "$here/index.html" "$data" "$out" "$images" <<'NODE'
const fs = require("fs"), path = require("path"), zlib = require("zlib");
const [tpl, dataPath, out, images] = process.argv.slice(2);
const data = JSON.parse(fs.readFileSync(dataPath, "utf8"));
// Same embedding as the CLI: escape "<" so no "</script" or "<!--" inside the JSON can close the block.
const json = JSON.stringify(data).replace(/</g, "\\u003c");
const html = fs.readFileSync(tpl, "utf8");
if (!html.includes("<!--SDD-DATA-->")) { console.error("preview.sh: marker <!--SDD-DATA--> not found in template"); process.exit(1); }
fs.writeFileSync(path.join(out, "index.html"), html.replace("<!--SDD-DATA-->", () => json));

if (images === "1") {
  const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const chunk = (type, body) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(body.length);
    const tb = Buffer.concat([Buffer.from(type), body]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(tb));
    return Buffer.concat([len, tb, c]);
  };
  // A plain phone-screen mock: header band, a few text lines, a button. Seeded by the file name.
  const png = (seed) => {
    const W = 360, H = 270, rows = [];
    const hue = [[44, 63, 143], [11, 95, 122], [29, 111, 69], [93, 74, 134]][seed % 4];
    for (let y = 0; y < H; y++) {
      const row = Buffer.alloc(1 + W * 3);
      for (let x = 0; x < W; x++) {
        let c = [247, 248, 250];
        if (y < 40) c = hue;
        else if (y > 60 && y < 200 && x > 24 && x < 336 && ((y - 60) % 28) < 10 && x < 336 - ((y * 7 + seed * 13) % 120)) c = [214, 220, 228];
        else if (y > 215 && y < 250 && x > 24 && x < 180) c = hue;
        row[1 + x * 3] = c[0]; row[2 + x * 3] = c[1]; row[3 + x * 3] = c[2];
      }
      rows.push(row);
    }
    const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
    return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr),
      chunk("IDAT", zlib.deflateSync(Buffer.concat(rows))), chunk("IEND", Buffer.alloc(0))]);
  };
  const caps = [];
  for (const r of data.requirements || []) for (const c of r.criteria || []) for (const cap of c.captures || []) if (cap.published !== false) caps.push(cap.path);
  let made = 0;
  for (const p of new Set(caps)) {
    if (!/^[\w./-]+\.png$/i.test(p) || p.includes("..")) continue;
    const dest = path.join(out, p);
    if (fs.existsSync(dest)) continue;
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, png([...p].reduce((a, ch) => a + ch.charCodeAt(0), 0)));
    made++;
  }
  if (made) console.error(`preview.sh: ${made} placeholder capture(s) written`);
}
console.log(path.join(out, "index.html"));
NODE
