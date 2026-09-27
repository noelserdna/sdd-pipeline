#!/usr/bin/env bash
# Tests de scripts/sdd-jev.mjs sin red ni API key: un servidor mock local (SDD_JEV_URL) responde como la API de
# TypeSafe. Cubre opt-in (exit 3), req-lint (parseo, REQ-C sin EARS, flags), judge (JSONL, estado demasiado grande,
# reintento tras 429), chunks y que los conjuntos de preguntas de scripts/jev/*.json son JSON válido.
# Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JEV="$ROOT/scripts/sdd-jev.mjs"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
run() { rc=0; out=$(node "$JEV" "$@" 2>&1) || rc=$?; }
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }

tmp="$(mktemp -d)"
trap 'kill "$mock_pid" 2>/dev/null || true; wait "$mock_pid" 2>/dev/null || true; rm -rf "$tmp"' EXIT
unset TYPESAFE_API_KEY SDD_JEV SDD_JEV_URL || true

# ── mock: the noul "vague" is 0.9 when the state mentions "quickly", every other noul 0.1; choice picks not_ears for "should",
#    else the first option; the first request answers 429 once to exercise the retry path.
cat > "$tmp/mock.mjs" <<'EOF'
import http from "node:http";
let first = true;
const srv = http.createServer((req, res) => {
  let body = "";
  req.on("data", (d) => (body += d)).on("end", () => {
    if (first) { first = false; res.writeHead(429, { "retry-after": "0" }); return res.end("slow down"); }
    const r = JSON.parse(body);
    const s = JSON.stringify(r.state);
    const answers = {};
    for (const [k, q] of Object.entries(r.questions)) {
      if (q.type === "noul") answers[k] = { type: "noul", noul: k === "vague" && /quickly/.test(s) ? 0.9 : 0.1 };
      else if (q.type === "choice") {
        const opts = Object.keys(q.criteria);
        const choice = /should/.test(s) && opts.includes("not_ears") ? "not_ears" : opts[0];
        answers[k] = { type: "choice", choice, confidence: 0.95, probabilities: Object.fromEntries(opts.map((o) => [o, o === choice ? 0.95 : 0.05 / (opts.length - 1)])) };
      } else answers[k] = { type: "score", score: 1, confidence: 0.9, probabilities: { 0: 0.05, 1: 0.9, 2: 0.05 } };
    }
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ model: "jev-mock", answers, usage: { input_tokens: 10, output_tokens: 1 } }));
  });
});
srv.listen(0, "127.0.0.1", () => console.log(srv.address().port));
EOF
node "$tmp/mock.mjs" > "$tmp/port" &
mock_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$tmp/port" ] && break; sleep 0.2; done
port="$(cat "$tmp/port")"

# ── opt-in ───────────────────────────────────────────────────────────────────
run status
expect "status sin key → exit 3" "$rc" "3"
contains "$out" "TYPESAFE_API_KEY not set" && pass "status explica el motivo" || bad "status explica el motivo ($out)"
TYPESAFE_API_KEY=x SDD_JEV=off run status
expect "SDD_JEV=off → exit 3" "$rc" "3"
run req-lint "$ROOT/examples/todo-app/requirements/REQUIREMENTS.md"
expect "req-lint deshabilitado → exit 3" "$rc" "3"

export TYPESAFE_API_KEY=test SDD_JEV_URL="http://127.0.0.1:$port/v1/systemone"
run status
expect "status con key → exit 0" "$rc" "0"

# ── req-lint ─────────────────────────────────────────────────────────────────
cat > "$tmp/REQ.md" <<'EOF'
# Requirements
## Functional Requirements
### REQ-F-001: List
- **Statement:** WHEN the user runs `todo list` THE system SHALL display tasks quickly.
### REQ-F-002: Done
- **Statement:** Users should be able to mark tasks as done.
- **Acceptance criteria:**
  - GIVEN task 1 WHEN done 1 THEN it is completed
## Constraints
### REQ-C-001: Runtime
- **Statement:** Node.js 20 and TypeScript.
EOF
run req-lint "$tmp/REQ.md" --json
expect "req-lint: 3 requisitos" "$(js 'j.items.length')" "3"
expect "req-lint: vague en REQ-F-001" "$(js 'j.items.find(i=>i.id==="REQ-F-001").flags.join()')" "vague"
expect "req-lint: not_ears en REQ-F-002" "$(js 'j.items.find(i=>i.id==="REQ-F-002").flags.join()')" "not_ears"
expect "req-lint: REQ-C sin EARS ni impl_leak" "$(js '["ears","impl_leak"].filter(k=>k in j.items.find(i=>i.id==="REQ-C-001").answers).length')" "0"
expect "req-lint: reintento tras 429 sin errores" "$(js 'j.errors.length')" "0"
run req-lint "$tmp/REQ.md" --out "$tmp/out/lint.json"
contains "$out" "3 requirements, 2 flagged" && pass "req-lint: resumen legible" || bad "req-lint: resumen legible ($out)"
[ -f "$tmp/out/lint.json" ] && pass "req-lint --out escribe el fichero" || bad "req-lint --out escribe el fichero"

# ── judge ────────────────────────────────────────────────────────────────────
big="$(node -e 'process.stdout.write("x".repeat(120000))')"
{ echo '{"id":"a","state":{"hit":{"text":"responds quickly"}}}'
  echo '{"text":"plain object used as state"}'
  printf '{"id":"big","state":"%s"}\n' "$big"; } > "$tmp/items.jsonl"
run judge --questions "$ROOT/scripts/jev/spec-triage.json" --items "$tmp/items.jsonl"
expect "judge: exit 1 si algún item falla" "$rc" "1"
out="$(printf '%s' "$out" | sed -n '/^{/,$p')"
expect "judge: 2 items respondidos" "$(js 'j.items.length')" "2"
expect "judge: id por línea para objetos sin state" "$(js 'j.items[1].id')" "2"
expect "judge: estado grande rechazado sin enviarlo" "$(js 'j.errors[0].id')" "big"
expect "judge: respuesta compacta de choice" "$(js 'typeof j.items[0].answers.category.confidence')" "number"

# ── chunks ───────────────────────────────────────────────────────────────────
node -e 'let s="";for(let i=0;i<40;i++)s+=`function f${i}() {\n  return ${i};\n}\n\n`;process.stdout.write(s)' > "$tmp/a.js"
run chunks --max-chars 200 "$tmp/a.js"
n="$(printf '%s\n' "$out" | grep -c '"path"' || true)"
[ "$n" -gt 3 ] && pass "chunks: parte el fichero ($n trozos)" || bad "chunks: parte el fichero ($n)"
expect "chunks: el primer trozo empieza en la línea 1" "$(printf '%s\n' "$out" | head -1 | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(String(JSON.parse(s).start)))')" "1"

# ── question sets ────────────────────────────────────────────────────────────
for f in "$ROOT"/scripts/jev/*.json; do
  if node -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const qs=q.questions||q;if(!Object.keys(qs).length)process.exit(1);for(const v of Object.values(qs))if(!["noul","choice","score"].includes(v.type))process.exit(1)' "$f"; then
    pass "preguntas válidas: $(basename "$f")"
  else bad "preguntas válidas: $(basename "$f")"; fi
done

exit $fail
