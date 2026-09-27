#!/usr/bin/env bash
# Tests de scripts/sdd-jev.mjs sin red ni API key: un servidor mock local (SDD_JEV_URL) responde como la API de
# TypeSafe. Cubre opt-in (exit 3), req-lint (parseo, REQ-C sin EARS, flags), judge (JSONL, estado demasiado grande,
# reintento tras 429), needs (parseRequirements, comprobación mecánica de necesidades, Choice por necesidad), chunks,
# los conjuntos de aceptación (test-adequacy.json, evidence.json: forma, umbrales y paso por `judge` con los
# fixtures etiquetados de tests/jev/fixtures/) y que los conjuntos de preguntas de scripts/jev/*.json son JSON válido.
# Calibración real (opcional, con red): SDD_JEV_CALIBRATE_KEY=<key> bash tests/jev/run.sh imprime el acierto de
# test-adequacy y evidence sobre esos fixtures contra la API de TypeSafe; nunca hace fallar la suite.
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
CALIBRATE_KEY="${SDD_JEV_CALIBRATE_KEY:-}"
unset TYPESAFE_API_KEY SDD_JEV SDD_JEV_URL SDD_JEV_CALIBRATE_KEY || true

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
      if (q.type === "noul") answers[k] = { type: "noul", noul: (k === "vague" && /quickly/.test(s)) || (k === "asserts_then" && /expect\(|assert/.test(s)) ? 0.9 : 0.1 };
      else if (q.type === "choice") {
        const opts = Object.keys(q.criteria);
        let choice = /should/.test(s) && opts.includes("not_ears") ? "not_ears" : opts[0];
        if (opts.includes("none")) { // need coverage: the option sharing most words (4+ letters) with the item wins; none without overlap
          const words = (t) => new Set(t.toLowerCase().match(/[a-z]{4,}/g) || []);
          const src = words(r.state.need ? r.state.need.quote : r.state.requirement.statement);
          let best = 0; choice = "none";
          for (const o of opts) { if (o === "none") continue; const n = [...words(q.criteria[o])].filter((w) => src.has(w)).length; if (n > best) { best = n; choice = o; } }
        }
        answers[k] = { type: "choice", choice, confidence: 0.95, probabilities: Object.fromEntries(opts.map((o) => [o, o === choice ? 0.95 : 0.05 / (opts.length - 1)])) };
      } else {
        if (!Array.isArray(q.criteria) || q.criteria.length < 2) { res.writeHead(422); return res.end("score criteria must be an ordered array"); }
        answers[k] = { type: "score", score: 1, confidence: 0.9, probabilities: { 0: 0.05, 1: 0.9, 2: 0.05 } };
      }
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

# ── needs (need coverage) ────────────────────────────────────────────────────
cat > "$tmp/NEEDS.md" <<'EOF'
# Customer Needs
### N-001: Add groceries
- **Quote:** "I want to add groceries to my shopping list from the terminal."
- **Who:** Ana, customer
- **When:** 2026-09-01
- **Status:** confirmed
### N-002: Spreadsheet
- **Quote:** "Export everything into a spreadsheet for my accountant."
- **Who:** Ana, customer
- **When:** 2026-09-01
- **Status:** confirmed
### N-003: Phone
- **Quote:** "Maybe a phone version."
- **Who:** Ana, customer
- **When:** 2026-09-01
- **Status:** out-of-scope
### N-004: Show groceries
- **Quote:** "Show my shopping groceries."
- **Who:** Ana, customer
- **When:** 2026-09-01
- **Status:** captured
EOF
cat > "$tmp/REQN.md" <<'EOF'
# Requirements
## Functional Requirements
### REQ-F-001: Add item
- **Statement:** WHEN the user runs `shop add <item>` THE system SHALL add the groceries item to the shopping list.
- **Priority:** Must have
- **Needs:** N-001, N-004
- **Verification:** test
- **Examples reviewed by:** Ana, 2026-09-02
- **Acceptance criteria:**
  - GIVEN an empty list WHEN the user runs `shop add milk` THEN the list holds "milk"
  - GIVEN a list with "milk" WHEN the user runs `shop add eggs` THEN the list holds "milk" and "eggs"
### REQ-F-002: Weather
- **Statement:** WHEN the user runs `shop weather` THE system SHALL print the forecast.
- **Priority:** Must have
- **Needs:** —
- **Verification:** demo
### REQ-F-003: Remove item
- **Statement:** WHEN the user runs `shop rm <item>` THE system SHALL remove the item.
- **Priority:** Should have
- **Needs:** N-009
- **Verification:** tested by hand
### REQ-F-004: Old sync [DEPRECATED]
- **Statement:** WHEN the user runs `shop sync` THE system SHALL upload the list.
- **Priority:** Must have
- **Status:** Deprecated (2026-09-03) — replaced by nothing
## Nonfunctional Requirements
### REQ-NF-001: Latency
- **Statement:** THE system SHALL answer any command in less than 100 ms.
- **Priority:** Must have
- **Needs:** N-001
## Constraints
### REQ-C-001: Runtime
- **Statement:** Node.js 20.
- **Needs:** —
- **Verification:** inspection
EOF
# rutas por entorno: con argumentos, process.argv[1] sería sdd-jev.mjs y su main() se ejecutaría al importarlo
out="$(M="$JEV" F="$tmp/REQN.md" node -e 'import(process.env.M).then((m)=>{const r=m.parseRequirements(require("fs").readFileSync(process.env.F,"utf8"));process.stdout.write(JSON.stringify(r))})')"
expect "parseRequirements: priority" "$(js 'j[0].priority+","+j[2].priority')" "Must,Should"
expect "parseRequirements: needs" "$(js 'JSON.stringify(j.map(r=>r.needs))')" '[["N-001","N-004"],[],["N-009"],null,["N-001"],[]]'
expect "parseRequirements: verification" "$(js 'j.map(r=>r.verification).join()')" "test,demo,tested by hand,,,inspection"
expect "parseRequirements: deprecated" "$(js 'j.map(r=>r.deprecated?1:0).join("")')" "000100"
expect "parseRequirements: criteria" "$(js 'j[0].criteria.length')" "2"
expect "parseRequirements: type" "$(js 'j.map(r=>r.type).join()')" "F,F,F,F,NF,C"
expect "parseRequirements: examples reviewed" "$(js 'j[0].examplesReviewedBy')" "Ana, 2026-09-02"
unset TYPESAFE_API_KEY
run needs "$tmp/NEEDS.md" "$tmp/REQN.md"
expect "needs sin key → exit 3" "$rc" "3"
contains "$out" "mechanical:" && pass "needs sin key imprime la comprobación mecánica" || bad "needs sin key imprime la comprobación mecánica ($out)"
run needs "$tmp/NEEDS.md" "$tmp/REQN.md" --mechanical --json
expect "needs --mechanical con errores → exit 1" "$rc" "1"
expect "needs: códigos de error" "$(js 'j.mechanical.errors.map(e=>e.code+":"+e.id).sort().join()')" \
  "bad-verification:REQ-F-003,gold-plating:REQ-F-002,no-decision:N-003,no-verification:REQ-NF-001,uncovered-need:N-002,unknown-need:REQ-F-003"
expect "needs: avisos" "$(js 'j.mechanical.warnings.map(e=>e.code+":"+(e.id||"")).sort().join()')" \
  "examples-not-reviewed:REQ-F-002,examples-not-reviewed:REQ-F-003,examples-not-reviewed:REQ-NF-001,must-ratio:,unconfirmed-need:N-004"
run needs "$ROOT/examples/todo-app/requirements/CUSTOMER-NEEDS.md" "$ROOT/examples/todo-app/requirements/REQUIREMENTS.md" --mechanical
expect "needs: el ejemplo todo-app pasa la comprobación mecánica" "$rc" "0"
contains "$out" "0 errors, 0 warnings" && pass "needs: ejemplo sin avisos (lista Must confirmada)" || bad "needs: ejemplo sin avisos ($out)"
export TYPESAFE_API_KEY=test
run needs "$tmp/NEEDS.md" "$tmp/REQN.md" --json
expect "needs con Jev → exit 0" "$rc" "0"
expect "needs: una Choice por necesidad en alcance" "$(js 'j.items.map(i=>i.id).join()')" "N-001,N-002,N-004"
expect "needs: necesidad sin requisito → none" "$(js 'j.items.find(i=>i.id==="N-002").flags.join()')" "none"
expect "needs: opciones = REQ-F/NF activos + REQ-C con necesidad + none" "$(js 'Object.keys(j.items[0].answers.covered_by.p).join()')" "REQ-F-001,REQ-F-002,REQ-F-003,REQ-NF-001,none"
expect "needs: requisito sin necesidad → candidato a gold plating" "$(js 'j.neverTop.filter(r=>r.flags.includes("gold-plating-candidate")).map(r=>r.id).join()')" "REQ-F-002,REQ-F-003,REQ-NF-001"
run needs "$tmp/NEEDS.md" "$tmp/REQN.md"
contains "$out" "gold-plating candidates" && pass "needs: resumen legible" || bad "needs: resumen legible ($out)"

# ── acceptance sets: test-adequacy.json (Noul), evidence.json (Score) — advisory only ─────────────
TA="$ROOT/scripts/jev/test-adequacy.json"; EV="$ROOT/scripts/jev/evidence.json"
qjs() { node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(String(eval(process.argv[2])))' "$1" "$2"; }
expect "test-adequacy: dos Noul (asserts_then, exercises_when)" "$(qjs "$TA" 'Object.entries(j.questions).map(([k,q])=>k+":"+q.type).join()')" "asserts_then:noul,exercises_when:noul"
expect "test-adequacy: umbral de revisión 0.5 dentro del JSON" "$(qjs "$TA" 'j.thresholds.review_below')" "0.5"
expect "test-adequacy: el estado nombra criterion, scenario y test" "$(qjs "$TA" '["criterion.text","test.code"].every(p=>JSON.stringify(j.questions).includes(p))')" "true"
expect "evidence: un Score con 3 niveles ordenados (no / parcial / sí)" "$(qjs "$EV" 'const q=j.questions.shows_then;q.type+":"+q.criteria.length')" "score:3"
expect "evidence: umbral dentro del JSON" "$(qjs "$EV" 'typeof j.thresholds.flag_below')" "number"
expect "ambos se declaran informativos (nunca deciden veredictos)" "$(qjs "$TA" '/never changes a verdict/.test(j.description)')$(qjs "$EV" '/never records/.test(j.description)')" "truetrue"
run judge --questions "$TA" --items "$ROOT/tests/jev/fixtures/test-adequacy.jsonl"
expect "test-adequacy: judge sobre el fixture etiquetado → exit 0" "$rc" "0"
expect "test-adequacy: 6 items con dos Noul cada uno" "$(js 'j.items.filter(i=>typeof i.answers.asserts_then==="number"&&typeof i.answers.exercises_when==="number").length')" "6"
expect "test-adequacy: sin aserción → por debajo del umbral (revisión)" "$(js 'j.items.find(i=>i.id==="no-assert").answers.asserts_then<0.5')" "true"
run judge --questions "$EV" --items "$ROOT/tests/jev/fixtures/evidence.jsonl"
expect "evidence: judge sobre el fixture etiquetado → exit 0" "$rc" "0"
expect "evidence: respuesta Score compacta por item" "$(js 'j.items.filter(i=>typeof i.answers.shows_then.score==="number").length')" "4"

if [ -n "$CALIBRATE_KEY" ]; then
  # Calibración real: acierto sobre las etiquetas, informativo (no cuenta como fallo).
  (
    export TYPESAFE_API_KEY="$CALIBRATE_KEY"; unset SDD_JEV_URL
    node "$JEV" judge --questions "$TA" --items "$ROOT/tests/jev/fixtures/test-adequacy.jsonl" --out "$tmp/ta.json" >/dev/null 2>&1 || true
    node "$JEV" judge --questions "$EV" --items "$ROOT/tests/jev/fixtures/evidence.jsonl" --out "$tmp/ev.json" >/dev/null 2>&1 || true
    node -e '
      const fs=require("fs"), [ta,ev,fa,fe,qa,qe]=process.argv.slice(1);
      const lab=(f)=>Object.fromEntries(fs.readFileSync(f,"utf8").trim().split("\n").map(l=>JSON.parse(l)).map(o=>[o.id,o.label]));
      const la=lab(fa), le=lab(fe), thr=JSON.parse(fs.readFileSync(qa,"utf8")).thresholds.review_below, fb=JSON.parse(fs.readFileSync(qe,"utf8")).thresholds.flag_below;
      const a=JSON.parse(fs.readFileSync(ta,"utf8")).items, e=JSON.parse(fs.readFileSync(ev,"utf8")).items;
      const okA=a.filter(i=>((i.answers.asserts_then>=thr&&i.answers.exercises_when>=thr)?"adequate":"inadequate")===la[i.id]).length;
      const okE=e.filter(i=>(i.answers.shows_then.score>=fb)===(le[i.id]===2)).length;
      console.log(`calibración (informativa): test-adequacy ${okA}/${a.length} · evidence ${okE}/${e.length}`);
      for (const i of a) console.log(`  ${i.id} (${la[i.id]}): asserts_then=${i.answers.asserts_then.toFixed(2)} exercises_when=${i.answers.exercises_when.toFixed(2)}`);
      for (const i of e) console.log(`  ${i.id} (${le[i.id]}): shows_then=${i.answers.shows_then.score.toFixed(2)}`);' \
      "$tmp/ta.json" "$tmp/ev.json" "$ROOT/tests/jev/fixtures/test-adequacy.jsonl" "$ROOT/tests/jev/fixtures/evidence.jsonl" "$TA" "$EV" \
      || echo "calibración: sin resultados (red o key)"
  )
fi

# ── question sets ────────────────────────────────────────────────────────────
for f in "$ROOT"/scripts/jev/*.json; do
  if node -e 'const q=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const qs=q.questions||q;if(!Object.keys(qs).length)process.exit(1);for(const v of Object.values(qs))if(!["noul","choice","score"].includes(v.type))process.exit(1)' "$f"; then
    pass "preguntas válidas: $(basename "$f")"
  else bad "preguntas válidas: $(basename "$f")"; fi
done

exit $fail
