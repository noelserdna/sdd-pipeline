#!/usr/bin/env bash
# Tests de `sdd route` (scripts/lib/route.mjs + scripts/lib/route-rules.mjs + scripts/jev/route.json) sin red ni API
# key: un servidor mock local (SDD_JEV_URL, el patrón de tests/jev) contesta los siete Noul con reglas de palabras
# clave sobre el estado. Cubre: todo-app → ruta ligera con motivos; fixture web (login, roles, pagos, API externa) →
# ruta completa + seguridad + UX; factor dudoso (p = 0,5) → tratado como sí y listado; --answers sin Jev; exit 3 sin
# Jev; --write (skipped + skipReason, bloque route, lock de los hooks, no toca done/running); --confirm; --full;
# --set; reevaluación tras añadir pagos → escalations sin des-saltar; errores de uso; y el agregado de grupos de
# scripts/sdd-graph.py con etapas skipped. Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
FIX="$ROOT/tests/fixtures/route"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
# route DIR ARGS… → stdout en $out (stderr en $err) y código en $rc
route() { local d="$1"; shift; rc=0; out=$(cd "$d" && node "$SDD" route "$@" 2>"$tmp/err") || rc=$?; err=$(cat "$tmp/err"); }
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
jf() { node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.stdout.write(String(eval(process.argv[2])))' "$1" "$2"; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'kill "$mock_pid" 2>/dev/null || true; wait "$mock_pid" 2>/dev/null || true; rm -rf "$tmp"' EXIT
unset TYPESAFE_API_KEY SDD_JEV SDD_JEV_URL SDD_STATE_ROOT SDD_ROLE SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

# ── mock Jev: each noul is 0.95 when its keywords appear in the state, else 0.05; a `MOCK-DOUBT:<factor>` marker
#    makes that factor 0.5. The last request body is saved to check what `sdd route` sends.
cat > "$tmp/mock.mjs" <<'EOF'
import http from "node:http";
import fs from "node:fs";
const KW = {
  external_customer: /owner|customer\)/i, sensitive_data: /card|payment|password|personal data|address/i,
  multi_actor: /role|admin|mechanic/i, integrations: /provider|\bAPI\b/, ui_flows: /website|page\b|screen/i,
  long_lived: /years|second workshop/i, complex_state: /reserve the slot|refund/i,
};
const srv = http.createServer((req, res) => {
  let body = "";
  req.on("data", (d) => (body += d)).on("end", () => {
    fs.writeFileSync(process.argv[2], body);
    const r = JSON.parse(body);
    const s = JSON.stringify(r.state);
    const answers = {};
    for (const k of Object.keys(r.questions)) {
      const p = s.includes(`MOCK-DOUBT:${k}`) ? 0.5 : KW[k] && KW[k].test(s) ? 0.95 : 0.05;
      answers[k] = { type: "noul", noul: p };
    }
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ model: "jev-mock", answers, usage: { input_tokens: 42 } }));
  });
});
srv.listen(0, "127.0.0.1", () => console.log(srv.address().port));
EOF
node "$tmp/mock.mjs" "$tmp/last-request.json" > "$tmp/port" &
mock_pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$tmp/port" ] && break; sleep 0.2; done
JEV_ENV="TYPESAFE_API_KEY=test SDD_JEV_URL=http://127.0.0.1:$(cat "$tmp/port")/v1/systemone"
jroute() { local d="$1"; shift; rc=0; out=$(cd "$d" && env $JEV_ENV node "$SDD" route "$@" 2>"$tmp/err") || rc=$?; err=$(cat "$tmp/err"); }

state_template() { sed -e "s/__SDD_VERSION__/test/" -e "s/__NOW__/2026-01-01T00:00:00Z/" "$ROOT/templates/pipeline-state.template.json" > "$1/pipeline-state.json"; }
mkproj() { local d="$tmp/$1"; mkdir -p "$d/requirements"; cp "$2"/requirements/*.md "$d/requirements/"; printf '%s' "$d"; }

todo=$(mkproj todo "$ROOT/examples/todo-app")
web=$(mkproj web "$FIX/web")

# ── question set ─────────────────────────────────────────────────────────────
Q="$ROOT/scripts/jev/route.json"
expect "route.json: 7 Noul con instrucciones y criterios true/false" \
  "$(jf "$Q" 'Object.values(j.questions).filter(q=>q.type==="noul"&&q.instructions&&q.criteria.true&&q.criteria.false).length')" "7"
expect "route.json: umbrales yes 0.65 / no 0.35" "$(jf "$Q" 'j.thresholds.yes+"/"+j.thresholds.no')" "0.65/0.35"
expect "route.json: mismos factores que route-rules" \
  "$(R="$ROOT/scripts/lib/route-rules.mjs" node -e 'import(process.env.R).then(m=>process.stdout.write(m.FACTORS.join()))')" \
  "$(jf "$Q" 'Object.keys(j.questions).join()')"

# ── sin Jev y sin --answers → exit 3 ─────────────────────────────────────────
route "$todo" --json
expect "sin Jev ni --answers → exit 3" "$rc" "3"
contains "$err" "pass --answers" && pass "exit 3 explica el camino del LLM" || bad "exit 3 sin explicación ($err)"

# ── todo-app con Jev (mock) → ruta ligera ────────────────────────────────────
jroute "$todo" --json
expect "todo: exit 0" "$rc" "0"
expect "todo: specs, auditoría y plan de tests saltados" \
  "$(js '["specifications-engineer","spec-auditor","test-planner"].map(k=>j.stages[k].run).join()')" "false,false,false"
expect "todo: seguridad, UX y tech-designer saltados" \
  "$(js '["security-auditor","ux-designer","tech-designer","gap-detector"].map(k=>j.stages[k].run).join()')" "false,false,false,false"
expect "todo: núcleo siempre (reason core)" \
  "$(js '["requirements-engineer","plan-architect","task-generator","task-implementer","acceptance"].map(k=>j.stages[k].run+":"+j.stages[k].reason).join()')" \
  "true:core,true:core,true:core,true:core,true:core"
expect "todo: motivo de specs con los números y factores" "$(js 'j.stages["specifications-engineer"].reason')" \
  "skip: 6 REQ-F (≤ 8), one user type, no integrations, no sensitive data, no complex state"
contains "$(js 'j.stages["test-planner"].reason')" "REQ-X-NNN ACn" && pass "todo: motivo del plan de tests" || bad "todo: motivo del plan de tests"
expect "todo: hechos contados" "$(js 'const f=j.facts;[f.req_f,f.req_nf,f.req_c,f.must,f.needs,f.needs_out,f.has_code,f.has_profile].join()')" "6,2,2,6,5,1,false,false"
expect "todo: minutos ahorrados (29+17+24)" "$(js 'j.saved_minutes_estimate')" "70"
expect "todo: sin dudas ni escalados" "$(js 'j.doubts.length+","+j.escalations.length')" "0,0"
expect "todo: factores con p y value" "$(js 'j.factors.sensitive_data.p+":"+j.factors.sensitive_data.value')" "0.05:no"
expect "todo: fuente jev" "$(js 'j.source+":"+j.jev.model')" "jev:jev-mock"
expect "petición: 7 preguntas" "$(jf "$tmp/last-request.json" 'Object.keys(j.questions).length')" "7"
expect "petición: estado {project, needs, requirements}" "$(jf "$tmp/last-request.json" 'Object.keys(j.state).join()')" "project,needs,requirements"
expect "petición: solo necesidades en alcance (N-006 fuera)" "$(jf "$tmp/last-request.json" 'j.state.needs.map(n=>n.id).join()')" "N-001,N-002,N-003,N-004,N-005"
expect "petición: requisitos solo con id/type/priority/statement" "$(jf "$tmp/last-request.json" 'Object.keys(j.state.requirements[0]).join()')" "id,type,priority,statement"
expect "petición: nombre del proyecto" "$(jf "$tmp/last-request.json" 'j.state.project.name')" "todo-app"
jroute "$todo"
contains "$out" "~70 min saved" && contains "$out" "skip  specifications-engineer" && pass "todo: salida legible" || bad "todo: salida legible ($out)"
check_repo_clean() { [ ! -e "$tmp/todo/pipeline-state.json" ]; }
check_repo_clean && pass "sin --write no crea pipeline-state.json" || bad "sin --write escribió estado"

# ── web (login, roles, pagos, API externa) → completa + seguridad + UX ───────
jroute "$web" --json
expect "web: exit 0" "$rc" "0"
expect "web: todas las etapas opcionales se ejecutan" \
  "$(js '["specifications-engineer","spec-auditor","test-planner","security-auditor","ux-designer","tech-designer","gap-detector"].filter(k=>j.stages[k].run).length')" "7"
expect "web: 0 minutos ahorrados" "$(js 'j.saved_minutes_estimate')" "0"
expect "web: 10 REQ-F" "$(js 'j.facts.req_f')" "10"
expect "web: motivo de specs" "$(js 'j.stages["specifications-engineer"].reason')" \
  "run: 10 REQ-F (> 8), several user types, external integrations, sensitive data, complex state"
expect "web: motivo de seguridad" "$(js 'j.stages["security-auditor"].reason')" "run: sensitive data"
expect "web: motivo de UX" "$(js 'j.stages["ux-designer"].reason')" "run: UI screens"
contains "$(js 'j.stages["tech-designer"].reason')" "no stack declared" && pass "web: tech-designer también sin stack declarado" || bad "web: tech-designer ($(js 'j.stages["tech-designer"].reason'))"

# ── factor dudoso → tratado como sí y listado ────────────────────────────────
doubt=$(mkproj doubt "$ROOT/examples/todo-app")
cat >> "$doubt/requirements/CUSTOMER-NEEDS.md" <<'EOF'

### N-007: Share the list with a friend
- **Quote:** "I'd like to send my list to a friend by email. MOCK-DOUBT:sensitive_data"
- **Who:** Laura Gómez, product owner
- **When:** 2026-08-21
- **Status:** captured
EOF
jroute "$doubt" --json
expect "duda: sensitive_data = doubt (p 0.5)" "$(js 'j.factors.sensitive_data.value+":"+j.factors.sensitive_data.p')" "doubt:0.5"
expect "duda: listada en doubts" "$(js 'j.doubts.join()')" "sensitive_data"
expect "duda: sube el rigor (specs y seguridad se ejecutan)" "$(js 'j.stages["specifications-engineer"].run+","+j.stages["security-auditor"].run')" "true,true"
contains "$(js 'j.stages["specifications-engineer"].reason')" "doubt about sensitive data" && pass "duda: el motivo la nombra" || bad "duda: motivo ($(js 'j.stages["specifications-engineer"].reason'))"
jroute "$doubt"
contains "$out" "doubts (treated as yes): sensitive_data" && pass "duda: la salida legible la nombra" || bad "duda: salida legible"

# ── --answers sin Jev ────────────────────────────────────────────────────────
printf '{"factors":{"external_customer":0.9,"sensitive_data":0.1,"multi_actor":0.2,"integrations":"no","ui_flows":{"p":0.1},"long_lived":0.3,"complex_state":0.05}}' > "$tmp/light.json"
route "$todo" --answers "$tmp/light.json" --json
expect "--answers: exit 0 sin Jev" "$rc" "0"
expect "--answers: fuente answers y ruta ligera" "$(js 'j.source+":"+j.stages["specifications-engineer"].run')" "answers:false"
expect "--answers: acepta yes/no y {p}" "$(js 'j.factors.integrations.p+","+j.factors.ui_flows.p')" "0,0.1"
printf '{"factors":{"sensitive_data":0.1}}' > "$tmp/partial.json"
route "$todo" --answers "$tmp/partial.json" --json
expect "--answers incompleto: los factores sin respuesta son dudas" "$(js 'j.doubts.length+":"+j.factors.multi_actor.value')" "6:doubt"
printf '{"factors":{"external_customer":0.1,"sensitive_data":0.9,"multi_actor":0.9,"integrations":0.9,"ui_flows":0.9,"long_lived":0.9,"complex_state":0.9}}' > "$tmp/heavy.json"
route "$todo" --answers "$tmp/heavy.json" --json
expect "--answers pesado: spec-auditor por REQ-F > 5 y datos sensibles" "$(js 'j.stages["spec-auditor"].reason')" "run: 6 REQ-F (> 5), sensitive data"

# ── errores de uso ───────────────────────────────────────────────────────────
route "$tmp/home" --answers "$tmp/light.json"
expect "sin requirements/REQUIREMENTS.md → exit 2" "$rc" "2"
route "$todo" --answers "$tmp/light.json" --set plan-architect=skip
expect "--set de una etapa núcleo → exit 2" "$rc" "2"
route "$todo" --answers "$tmp/light.json" --set nope=run
expect "--set de una etapa desconocida → exit 2" "$rc" "2"
route "$todo" --answers "$tmp/light.json" --confirm "Ana (PO)"
expect "--confirm sin --write → exit 2" "$rc" "2"
route "$todo" --answers "$tmp/light.json" --write
expect "--write sin pipeline-state.json → exit 2" "$rc" "2"
contains "$err" "sdd-setup" && pass "--write sin estado sugiere /sdd-setup" || bad "--write sin estado ($err)"

# ── --write ──────────────────────────────────────────────────────────────────
git init -q "$todo"
state_template "$todo"
node -e 'const f=process.argv[1],j=JSON.parse(require("fs").readFileSync(f,"utf8"));j.stages["requirements-engineer"]={status:"done",summary:{nextStep:"x"}};j.stages["test-planner"].status="done";require("fs").writeFileSync(f,JSON.stringify(j,null,2))' "$todo/pipeline-state.json"
route "$todo" --answers "$tmp/light.json" --write --confirm "Laura Gómez (product owner)" --json
PS="$todo/pipeline-state.json"
expect "--write: exit 0" "$rc" "0"
expect "--write: specs y auditoría skipped" "$(jf "$PS" 'j.stages["specifications-engineer"].status+","+j.stages["spec-auditor"].status')" "skipped,skipped"
expect "--write: skipReason = motivo" "$(jf "$PS" 'j.stages["specifications-engineer"].skipReason')" \
  "skip: 6 REQ-F (≤ 8), one user type, no integrations, no sensitive data, no complex state"
expect "--write: no toca una etapa done (test-planner)" "$(jf "$PS" 'j.stages["test-planner"].status+":"+("skipReason" in j.stages["test-planner"])')" "done:false"
expect "--write: informa de la etapa conservada" "$(js 'j.written.kept.map(k=>k.stage+":"+k.status).join()')" "test-planner:done"
expect "--write: laterales creadas como skipped" "$(jf "$PS" '["security-auditor","ux-designer","tech-designer","gap-detector"].map(k=>j.stages[k].status).join()')" "skipped,skipped,skipped,skipped"
expect "--write: núcleo intacto" "$(jf "$PS" 'j.stages["requirements-engineer"].status+","+j.stages["requirements-engineer"].summary.nextStep+","+j.stages["plan-architect"].status')" "done,x,pending"
expect "--write: bloque route completo" "$(jf "$PS" '["decidedAt","factors","facts","stages","doubts","confirmedBy","reqHash"].every(k=>k in j.route)')" "true"
expect "--write: confirmedBy" "$(jf "$PS" 'j.route.confirmedBy')" "Laura Gómez (product owner)"
expect "--write: reqHash sha256" "$(jf "$PS" '/^sha256:[0-9a-f]{64}$/.test(j.route.reqHash)')" "true"
[ ! -d "$PS.lock" ] && pass "--write: libera el lock" || bad "--write dejó el lock"
out=$(printf '{"session_id":"t","cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$todo" | bash "$ROOT/hooks/sdd-session-start.sh" 2>/dev/null || true)
contains "$out" "2/5 done, 2 skipped (specifications-engineer, spec-auditor)" && pass "--write: H1 cuenta N/M done, K skipped" || bad "--write: H1 ($out)"

# el lock de los hooks se respeta
before=$(cat "$PS")
mkdir "$PS.lock"
rc=0; (cd "$todo" && SDD_LOCK_RETRIES=2 node "$SDD" route --answers "$tmp/light.json" --write >/dev/null 2>&1) || rc=$?
expect "--write con el lock ocupado → exit 1" "$rc" "1"
[ "$(cat "$PS")" = "$before" ] && pass "--write con el lock ocupado no escribe" || bad "--write escribió sin lock"
rmdir "$PS.lock"

# re-ejecución sin cambios: idempotente
route "$todo" --answers "$tmp/light.json" --write --json
expect "re-ejecución: sin cambios de estado" "$(js 'j.written.changed.length')" "0"
expect "re-ejecución sin --confirm: confirmedBy null" "$(jf "$PS" 'j.route.confirmedBy')" "null"

# --set: una persona decide
route "$todo" --answers "$tmp/light.json" --write --set specifications-engineer=run ux-designer=run --json
expect "--set: la etapa pedida corre (set by user)" "$(js 'j.stages["specifications-engineer"].run+":"+j.stages["specifications-engineer"].reason')" "true:set by user"
expect "--set: acepta varias parejas" "$(js 'j.stages["ux-designer"].reason')" "set by user"
expect "--set: una saltada vuelve a pending" "$(jf "$PS" 'j.stages["specifications-engineer"].status+":"+("skipReason" in j.stages["specifications-engineer"])')" "pending:false"
expect "--set: el resto sigue skipped" "$(jf "$PS" 'j.stages["spec-auditor"].status')" "skipped"
route "$todo" --answers "$tmp/light.json" --json
expect "tras --set run, la reevaluación no baja el rigor" "$(js 'j.stages["specifications-engineer"].run')" "true"
contains "$(js 'j.stages["specifications-engineer"].reason')" "never lowers rigor" && pass "motivo de la etapa conservada" || bad "motivo conservada"
route "$todo" --answers "$tmp/light.json" --write --set specifications-engineer=skip --json
expect "--set skip: una persona sí puede bajarla" "$(jf "$PS" 'j.stages["specifications-engineer"].status+":"+j.stages["specifications-engineer"].skipReason')" "skipped:set by user"

# --full
full=$(mkproj full "$ROOT/examples/todo-app"); state_template "$full"
route "$full" --answers "$tmp/light.json" --write --json
route "$full" --answers "$tmp/light.json" --write --full --json
expect "--full: todas las opcionales corren" "$(js 'Object.values(j.stages).every(s=>s.run)')" "true"
expect "--full: motivo" "$(js 'j.stages["spec-auditor"].reason')" "set by user: full pipeline"
expect "--full: 0 minutos ahorrados" "$(js 'j.saved_minutes_estimate')" "0"
expect "--full: ninguna etapa queda skipped" "$(jf "$full/pipeline-state.json" 'Object.values(j.stages).filter(s=>s.status==="skipped").length')" "0"

# ── reevaluación que sube el rigor: aparecen pagos ───────────────────────────
esc=$(mkproj esc "$ROOT/examples/todo-app"); state_template "$esc"
jroute "$esc" --write --json
expect "reevaluación: primera ruta ligera escrita" "$(jf "$esc/pipeline-state.json" 'j.stages["specifications-engineer"].status')" "skipped"
node -e 'const f=process.argv[1],j=JSON.parse(require("fs").readFileSync(f,"utf8"));j.stages["security-auditor"].status="running";require("fs").writeFileSync(f,JSON.stringify(j,null,2))' "$esc/pipeline-state.json"
cat >> "$esc/requirements/CUSTOMER-NEEDS.md" <<'EOF'

### N-008: Pay for the premium version
- **Quote:** "Users should pay 3 euros by card to unlock unlimited lists."
- **Who:** Laura Gómez, product owner
- **When:** 2026-09-25
- **Status:** confirmed
EOF
cat >> "$esc/requirements/REQUIREMENTS.md" <<'EOF'

### REQ-F-007: Premium payment
- **Statement:** WHEN the user runs `todo premium` THE system SHALL charge 3 euros to the user's card through the payment provider and unlock unlimited lists.
- **Priority:** Must have
- **Needs:** N-008
- **Verification:** test
EOF
jroute "$esc" --write --json
expect "reevaluación: specs y seguridad ahora hacen falta" "$(js 'j.stages["specifications-engineer"].run+","+j.stages["security-auditor"].run')" "true,true"
expect "reevaluación: escalations lista las saltadas que ahora hacen falta (no la que ya corre)" "$(js 'j.escalations.join()')" "specifications-engineer,spec-auditor,test-planner,tech-designer,gap-detector"
expect "reevaluación: --write no des-salta" "$(jf "$esc/pipeline-state.json" 'j.stages["specifications-engineer"].status')" "skipped"
expect "reevaluación: no toca una etapa running" "$(jf "$esc/pipeline-state.json" 'j.stages["security-auditor"].status')" "running"
expect "reevaluación: el bloque route guarda escalations y el nuevo reqHash" \
  "$(jf "$esc/pipeline-state.json" 'j.route.escalations.includes("specifications-engineer")')" "true"
expect "reevaluación: kept marca la escalada" "$(js 'j.written.kept.filter(k=>k.escalation).map(k=>k.stage).join()')" "specifications-engineer,spec-auditor,test-planner,tech-designer,gap-detector"
expect "reevaluación: test-planner entra (cliente externo: la product owner, campo who de las necesidades)" "$(js 'j.stages["test-planner"].run')" "true"
jroute "$esc"
contains "$out" "escalations (skipped before, needed now" && pass "reevaluación: la salida legible pide decidir" || bad "reevaluación: salida legible"

# ── sdd-graph.py: skipped no es parcial ──────────────────────────────────────
if command -v python3 >/dev/null 2>&1; then
  g=$(PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT/scripts/sdd-graph.py" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("g", sys.argv[1]); g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
a = g.aggregate_group_status
print(",".join([a(["done", "skipped"]), a(["skipped", "skipped"]), a(["pending", "skipped"]), a(["done", "pending", "skipped"])]))
PY
)
  expect "sdd-graph: done+skipped=done, todo skipped=skipped, pending+skipped=pending" "$g" "done,skipped,pending,partial"
fi

[ "$fail" -eq 0 ] && echo "tests/route: todo ok" || { echo "tests/route: hay fallos"; exit 1; }
