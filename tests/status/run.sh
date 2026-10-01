#!/usr/bin/env bash
# Tests of the living status page data (sdd-pipeline 5.2): `sdd journal add|list` (scripts/lib/journal.mjs),
# `sdd status page …` (status/page.json, migration of .sdd/status-page.json), `sdd status build` (scripts/lib/status.mjs,
# contract sdd-status-v1 checked by tests/status/shape.mjs), the journal lines of `sdd route --write` and the
# `no-plain` warning of `sdd lint --needs`. Projects: the seeded bench (tests/fixtures/seeded/app, built by
# tests/seeded/run.sh --prepare) cut into five moments (needs only → requirements approved → plan → FASE built and
# verified → signed), the full bench (evidence copies, warnings, GitHub and GitLab links, no secrets or traces) and
# tests/fixtures/acceptance/todo (records, waiver, measurement, a changed attachment). The page template is the
# minimal test one of tests/fixtures/status/ (the real template is another piece of 5.2). No network, no model.
# bash 3.2 (macOS) and bash 5; needs git and node >= 18. Run with `env -u SDD_STATE_ROOT`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
TPL="$ROOT/tests/fixtures/status/template.html"
SHAPE="$ROOT/tests/status/shape.mjs"
SEED="$ROOT/tests/fixtures/seeded/app"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
# run ARGS… inside $repo → stdout in $out, stderr in $err, exit code in $rc
run() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>"$tmp/stderr") || rc=$?; err=$(cat "$tmp/stderr"); }
# js EXPR → EXPR with j = JSON.parse($out)
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
# jf FILE EXPR → EXPR with j = the JSON of FILE; R(id) = requirement, F(n) = FASE
jf() { node -e 'const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const R=(id)=>j.requirements.find((r)=>r.id===id);const F=(n)=>j.fases.find((f)=>f.n===n);process.stdout.write(String(eval(process.argv[2])))' "$1" "$2"; }
# build → status build with the test template; $D = the data.json written
build() { run status build --template "$TPL"; D="$repo/.sdd/status-page/data.json"; }
shape_ok() { local r=0 o; o=$(node "$SHAPE" "$D" 2>&1) || r=$?; if [ "$r" = 0 ]; then pass "$1: data.json follows sdd-status-v1"; else bad "$1: contract ($o)"; fi; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT TYPESAFE_API_KEY GITLAB_HOST || true
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null TZ=UTC
export GIT_AUTHOR_NAME="Equipo CV" GIT_AUTHOR_EMAIL=cv@campus.test GIT_COMMITTER_NAME="Equipo CV" GIT_COMMITTER_EMAIL=cv@campus.test
mkdir -p "$HOME"
# commit MSG [trailer…] → a commit dated in the past (evidence written now is newer than the code)
n=0
commit() {
  n=$((n + 1)); local d m="$1"; shift; d="2026-09-10T10:$(printf %02d "$n"):00"
  local args=(); for t in "$@"; do args+=(--trailer "$t"); done
  ( cd "$repo" && git add -A && GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -qm "$m" ${args[@]+"${args[@]}"} )
}
newrepo() { repo="$1"; mkdir -p "$repo"; ( cd "$repo" && git init -q && git symbolic-ref HEAD refs/heads/main ); }
state() { sed -e 's/__SDD_VERSION__/5.2.0/' -e 's/__NOW__/2026-09-10T10:00:00Z/' "$ROOT/templates/pipeline-state.template.json" > "$repo/pipeline-state.json"; }

# ---------------------------------------------------------------- 1. journal
repo="$tmp/j"; mkdir -p "$repo"
run journal add --stage requirements-engineer --kind "done" --text "Recogimos 4 necesidades." --refs N-001 N-002 --by "Marta Ibáñez (coordinación)" --at 2026-09-01T10:00:00+02:00
expect "journal add exits 0" "$rc" 0
[ -f "$repo/status/journal.jsonl" ] && pass "journal add creates status/journal.jsonl" || bad "no status/journal.jsonl"
expect "journal line: stable key order, UTC to the second" "$(sed -n 1p "$repo/status/journal.jsonl")" \
  '{"at":"2026-09-01T08:00:00Z","feature":"initial","stage":"requirements-engineer","kind":"done","text":"Recogimos 4 necesidades.","refs":["N-001","N-002"],"by":"Marta Ibáñez (coordinación)"}'
run journal add --stage plan-architect --kind start --text "  Planificamos   las entregas. " --feature CHG-2026-09-05-001 --refs FASE-1,FASE-2 --json
expect "journal add --json exits 0" "$rc" 0
expect "journal add --json: line 2, text collapsed, refs split, no by" "$(js '[j.line,j.entry.text,j.entry.refs.join("+"),("by" in j.entry)].join("|")')" "2|Planificamos las entregas.|FASE-1+FASE-2|false"
contains "$(sed -n 2p "$repo/status/journal.jsonl")" '"at":"20' && pass "journal add without --at stamps now" || bad "journal add --at default"
run journal add --stage acceptance --kind verdict --text x; expect "journal add: unknown kind → 2" "$rc" 2
contains "$err" "start | done | gate" && pass "journal add: lists the kinds" || bad "journal add kinds ($err)"
run journal add --stage acceptance --kind "done"; expect "journal add: no --text → 2" "$rc" 2
run journal add --stage "Plan Architect" --kind "done" --text x; expect "journal add: bad stage → 2" "$rc" 2
run journal add --stage deploy --kind "done" --text x; expect "journal add: unknown stage → 2" "$rc" 2
contains "$err" "status-page" && pass "journal add: lists the accepted stages" || bad "journal add stages ($err)"
run journal add --stage acceptance --kind "done" --text x --at ayer; expect "journal add: bad --at → 2" "$rc" 2
run journal add --stage acceptance --kind "done" --text x --refs "REQ F"; expect "journal add: bad ref → 2" "$rc" 2
run journal add --stage acceptance --kind "done" --text x --feature "mi feature"; expect "journal add: bad feature → 2" "$rc" 2
expect "journal: invalid adds write nothing" "$(wc -l < "$repo/status/journal.jsonl" | tr -d ' ')" 2
ok=0
for st in setup route status-page acceptance req-change gap-detector orchestrator lead task-implementer; do
  run journal add --stage "$st" --kind decision --text "x" --refs REQ-NF-002 N-004 FASE-3 CHG-2026-09-05-001 requirements-v2 fase-1-accepted CH-007 --feature probe --at 2026-09-02T00:00:00Z
  [ "$rc" = 0 ] || { ok=1; bad "journal add --stage $st ($err)"; }
done
[ "$ok" = 0 ] && pass "journal add: setup, route, status-page, acceptance, req-change, gap-detector, orchestrator, lead and the pipeline stages; refs REQ, N, FASE, CHG, tags, CH"
run journal list --feature probe --json
expect "journal: the probe lines keep their refs" "$(js 'j.count+":"+j.entries[0].refs.join(" ")')" "9:REQ-NF-002 N-004 FASE-3 CHG-2026-09-05-001 requirements-v2 fase-1-accepted CH-007"
run journal list --feature initial
expect "journal list exits 0" "$rc" 0
contains "$out" "journal: 1 entry (feature initial)" && pass "journal list: summary" || bad "journal list ($out)"
contains "$out" "2026-09-01T08:00:00Z  initial  requirements-engineer  done  Recogimos 4 necesidades.  [N-001, N-002]  — Marta" && pass "journal list: one line per entry" || bad "journal list line ($out)"
run journal list --json
expect "journal list --json: entries in file order" "$(js 'j.count+":"+j.entries.slice(0,3).map(e=>e.kind).join()')" "11:done,start,decision"
run journal list --feature CHG-2026-09-05-001 --json
expect "journal list --feature filters" "$(js 'j.count+":"+j.entries[0].stage')" "1:plan-architect"
run journal remove; expect "journal: unknown subcommand → 2" "$rc" 2

# ---------------------------------------------------------------- 2. status/page.json
repo="$tmp/p"; mkdir -p "$repo"
run status page --json
expect "status page without registry: url null, declined false" "$(js 'j.url+":"+j.declined+":"+j.features.length')" "null:false:0"
[ ! -e "$repo/status/page.json" ] && pass "status page (read) creates nothing" || bad "status page created page.json"
run status page set --url http://x; expect "status page set: http refused → 2" "$rc" 2
run status page set --url https://claude.ai/code/artifact/abc --json
expect "status page set exits 0" "$rc" 0
expect "status page set: url stored" "$(js 'j.url')" "https://claude.ai/code/artifact/abc"
expect "page.json: stable key order" "$(jf "$repo/status/page.json" 'Object.keys(j).join()')" "url,createdAt,features,assets"
run status page decline --json
expect "status page decline: declined, url kept" "$(js 'j.declined+":"+j.url')" "true:https://claude.ai/code/artifact/abc"
expect "page.json with declined: key order" "$(jf "$repo/status/page.json" 'Object.keys(j).join()')" "url,createdAt,declined,features,assets"
run status page set --url https://claude.ai/code/artifact/def --json
expect "status page set clears declined" "$(js 'j.declined+":"+j.url')" "false:https://claude.ai/code/artifact/def"
expect "page.json without declined after set" "$(jf "$repo/status/page.json" '"declined" in j')" false
run status page feature add --id CHG-2026-09-20-001 --title "Pagos con tarjeta" --chg CHG-2026-09-20-001 --summary "Pagar la matrícula" --json
expect "feature add" "$(js 'j.features.map(f=>[f.id,f.title,f.chg,f.summary].join("|")).join()')" "CHG-2026-09-20-001|Pagos con tarjeta|CHG-2026-09-20-001|Pagar la matrícula"
created=$(jf "$repo/status/page.json" 'j.features[0].createdAt')
run status page feature add --id CHG-2026-09-20-001 --title "Pagos" --json
expect "feature add again updates, keeps createdAt" "$(js 'j.features.length+":"+j.features[0].title+":"+j.features[0].createdAt')" "1:Pagos:$created"
run status page feature add --id "x y" --title t; expect "feature add: bad id → 2" "$rc" 2
run status page feature add --id pagos; expect "feature add: no title → 2" "$rc" 2
H=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
run status page asset --sha256 abc --url https://a.test/x.png; expect "asset: bad sha → 2" "$rc" 2
run status page asset --sha256 "$H" --url https://claude.ai/asset/1 --json
expect "asset stored under sha256:" "$(js 'j.assets["sha256:'"$H"'"]')" "https://claude.ai/asset/1"
H1=$(echo "$H" | tr 0 1); H2=$(echo "$H" | tr 0 2)
run status page asset --sha256 "sha256:$H1" --url evidencias/FASE-1/REQ-F-001-AC1.png --json
expect "asset: a published path inside the page" "$(js 'j.assets["sha256:'"$H1"'"]')" "evidencias/FASE-1/REQ-F-001-AC1.png"
run status page asset --sha256 "$H2" --url withheld --json
expect "asset: withheld (personal data)" "$(js 'j.assets["sha256:'"$H2"'"]')" withheld
run status page asset --sha256 "$H" --url "a b"; expect "asset: a reference with spaces → 2" "$rc" 2
run status page; contains "$out" "1 feature(s) · 3 asset(s)" && pass "status page: text summary" || bad "status page text ($out)"
repo="$tmp/m"; mkdir -p "$repo/.sdd"
printf '{"url":"https://claude.ai/code/artifact/old","publishedAt":"2026-08-01T09:00:00Z","sha":"abc1234","assets":{"%s":"https://claude.ai/asset/9"}}\n' "$H" > "$repo/.sdd/status-page.json"
run status page --json
expect "migration on the first status page --json: url and declined" "$(js 'j.url+":"+j.declined')" "https://claude.ai/code/artifact/old:false"
expect "migration: url, createdAt and assets moved" "$(jf "$repo/status/page.json" 'j.url+"|"+j.createdAt+"|"+j.assets["sha256:'"$H"'"]')" \
  "https://claude.ai/code/artifact/old|2026-08-01T09:00:00Z|https://claude.ai/asset/9"
[ ! -e "$repo/.sdd/status-page.json" ] && pass "migration: old file removed" || bad "migration left the old file"
repo="$tmp/m2"; mkdir -p "$repo/.sdd"
printf '{"url":"https://claude.ai/code/artifact/x","publishedAt":"2026-08-01T09:00:00Z"}\n' > "$repo/.sdd/status-page.json"
run status page; contains "$out" "moved .sdd/status-page.json" && pass "migration: announced in text mode" || bad "migration message ($out)"
run status page; if contains "$out" "moved"; then bad "migration ran twice"; else pass "migration: only the first time"; fi

# ---------------------------------------------------------------- 3. empty projects
repo="$tmp/empty"; mkdir -p "$repo"
build
expect "build on an empty directory exits 0" "$rc" 0
shape_ok "empty directory"
expect "empty: phase understand, nothing listed" "$(jf "$D" 'j.where.phase+":"+j.requirements.length+":"+j.sha+":"+j.where.phases[0].state')" "understand:0:null:current"
[ -f "$repo/.sdd/status-page/index.html" ] && pass "empty: index.html written" || bad "empty: no index.html"
newrepo "$tmp/fresh"; state; commit "chore: setup"
build
shape_ok "fresh pipeline-state.json"
expect "fresh state: phase understand, pipeline listed" "$(jf "$D" 'j.where.phase+":"+j.technical.pipeline.length+":"+j.where.now')" "understand:7:Estamos entendiendo lo que necesitas."
run status build; expect "status build with the plugin template (templates/status-page/index.html) exits 0" "$rc" 0
run status build --template "$tmp/none.html"; expect "status build: missing --template → 2" "$rc" 2
printf '<html><body>no marker</body></html>\n' > "$tmp/nomarker.html"
run status build --template "$tmp/nomarker.html"; expect "status build: template without marker → 2" "$rc" 2

# ---------------------------------------------------------------- 4. five moments of the seeded bench
m="$tmp/moments"; newrepo "$m"; repo="$m"; state
mkdir -p "$m/requirements"; cp "$SEED/requirements/CUSTOMER-NEEDS.md" "$m/requirements/"
commit "docs(requirements): customer needs"
build; shape_ok "moment 1 (needs only)"
expect "moment 1: understand, 4 needs, no requirements" "$(jf "$D" 'j.where.phase+":"+j.needs.length+":"+j.requirements.length')" "understand:4:0"
expect "moment 1: needs carry quote and who" "$(jf "$D" 'j.needs[0].who+"|"+j.needs[0].quote.slice(0,24)')" "Marta Ibáñez, coordinación académica|Queremos que cada alumno"
expect "moment 1: language es" "$(jf "$D" 'j.project.lang+":"+j.project.name')" "es:cv-alumnos"

cp "$SEED/requirements/REQUIREMENTS.md" "$m/requirements/"
commit "docs(requirements): requirements v1"
build
expect "moment 2a: requirements written, not approved → agree" "$(jf "$D" 'j.where.phase+":"+j.where.needFromYou[0].anchor')" "agree:REQ-F-001"
(cd "$m" && GIT_COMMITTER_DATE="2026-09-10T11:00:00" git tag -a requirements-v1.0 -m "Approved by Marta Ibáñez")
build; shape_ok "moment 2 (requirements approved)"
expect "moment 2: approved → design (specs pending in the state)" "$(jf "$D" 'j.where.phase+":"+j.where.phases.map(p=>p.state).join()')" "design:done,done,current,pending,pending,pending,pending"
expect "moment 2: every requirement pending, plain null without the line" "$(jf "$D" 'j.requirements.map(r=>r.status).join()+"|"+R("REQ-F-001").plain')" "pending,pending,pending,pending,pending,pending,pending,pending|null"
expect "moment 2: approval in the journal, derived from the tag" "$(jf "$D" 'j.journal.map(e=>[e.kind,e.refs.join("+"),e.derived,e.by].join(":")).join()')" "decision:requirements-v1.0:true:Equipo CV"
expect "moment 2: tag with date and no web link (no origin)" "$(jf "$D" 'j.technical.tags.map(t=>t.name+":"+t.date+":"+t.url).join()')" "requirements-v1.0:2026-09-10T11:00:00Z:null"
# the approval written by the orchestrator as the gate answer replaces the derived decision (one fact, one line)
(cd "$m" && node "$ROOT/scripts/sdd.mjs" journal add --stage orchestrator --kind gate --text "Aprobaste los requisitos." --refs requirements-v1.0 --at 2026-09-10T11:05:00Z >/dev/null)
build
expect "moment 2: a written gate line suppresses the derived approval decision" "$(jf "$D" 'j.journal.filter(e=>e.refs.includes("requirements-v1.0")).map(e=>e.kind+":"+e.derived).join()')" "gate:false"
rm -f "$m/status/journal.jsonl"   # the test line was never committed: the later moments start without a written journal
# a «Para el cliente» line reaches `plain`; `sdd lint --needs` warns when it is missing
node -e '
const fs = require("fs"), f = process.argv[1];
const add = { "### REQ-F-001": "- **Para el cliente:** Tu CV empieza con tu nombre y tu email.", "### REQ-F-002": "- **For the customer:** Your projects get their own section." };
fs.writeFileSync(f, fs.readFileSync(f, "utf8").split("\n").flatMap((l) => { const k = Object.keys(add).find((x) => l.startsWith(x + ":")); return k ? [l, add[k]] : [l]; }).join("\n"));' "$m/requirements/REQUIREMENTS.md"
build
expect "Para el cliente → plain" "$(jf "$D" 'R("REQ-F-001").plain')" "Tu CV empieza con tu nombre y tu email."
expect "For the customer → plain" "$(jf "$D" 'R("REQ-F-002").plain')" "Your projects get their own section."
run lint --needs --json
expect "lint --needs: no-plain warning on the 6 requirements without the line" "$(js 'j.warnings.filter(w=>w.code==="no-plain").map(w=>w.id).join()')" \
  "REQ-F-003,REQ-F-004,REQ-F-005,REQ-F-006,REQ-F-007,REQ-F-008"
run lint --needs
contains "$out" "warning  no-plain  REQ-F-003 has no \"- **Para el cliente:**\" line" && pass "lint --needs: the warning in text mode" || bad "lint --needs text ($out)"
expect "lint --needs: the warning does not fail it" "$rc" 0
(cd "$m" && git checkout -q -- requirements/REQUIREMENTS.md)
# the route: --write adds a skip line per stage it leaves out and the decision; the page does not repeat them
cp "$SEED/CLAUDE.md" "$m/"  # a declared stack: the route leaves the technical design out too
printf '{"factors":{"external_customer":0.05,"sensitive_data":0.05,"multi_actor":0.05,"integrations":0.05,"ui_flows":0.05,"long_lived":0.05,"complex_state":0.05}}\n' > "$tmp/light.json"
run route --answers "$tmp/light.json" --write --confirm "Marta Ibáñez (coordinación)" --json
expect "route --write exits 0" "$rc" 0
skipped=$(jf "$m/pipeline-state.json" 'Object.keys(j.route.stages).filter(k=>!j.route.stages[k].run).join()')
expect "route --write: one skip line per skipped stage, then the decision" \
  "$(node -e 'const l=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").map(JSON.parse);process.stdout.write(l.filter(e=>e.kind==="skip").map(e=>e.stage).join()+"|"+l[l.length-1].kind+":"+l[l.length-1].stage+":"+l[l.length-1].by)' "$m/status/journal.jsonl")" \
  "$skipped|decision:route:Marta Ibáñez (coordinación)"
contains "$(sed -n 1p "$m/status/journal.jsonl")" "No hacemos la especificación detallada: este proyecto no lo necesita" && pass "route --write: skip text in plain Spanish with its reason" || bad "route skip text ($(sed -n 1p "$m/status/journal.jsonl"))"
lines=$(wc -l < "$m/status/journal.jsonl" | tr -d ' ')
run route --answers "$tmp/light.json" --write --json
expect "route --write again: only a new decision line (no repeated skips)" "$(wc -l < "$m/status/journal.jsonl" | tr -d ' ')" "$((lines + 1))"
build
expect "route: no duplicated skip in the page journal" "$(jf "$D" 'const s=j.journal.filter(e=>e.kind==="skip");s.length+":"+s.every(e=>!e.derived)')" "$(echo "$skipped" | tr ',' '\n' | grep -c .):true"
expect "route skipped the design stages → design skipped, phase plan" "$(jf "$D" 'j.where.phase+":"+j.where.phases[2].state+":"+(j.where.phases[2].reason.length>10)')" "plan:skipped:true"
commit "chore(status): journal" "Change: STATUS-TEST"

mkdir -p "$m/plan"; cp -R "$SEED/plan/." "$m/plan/"
commit "docs(plan): FASE-1"
build; shape_ok "moment 3 (plan)"
expect "moment 3: plan with a FASE, no tasks → plan" "$(jf "$D" 'j.where.phase+":"+F(1).status+":"+F(1).tasks.total+":"+R("REQ-F-003").fase')" "plan:pending:0:1"
expect "moment 3: FASE header read (increment, workflows, demo steps, needs)" "$(jf "$D" '[F(1).increment.slice(0,30),F(1).workflows.join(),F(1).demo.length,F(1).demo[1].action,F(1).needs.length].join("|")')" \
  "El alumno genera su CV desde e|WF-001|8|Lucía abre \`/cv/estado\`|4"

for x in CLAUDE.md package.json .gitignore spec src tests task junit evidencias; do cp -R "$SEED/$x" "$m/"; done
commit "feat(cv): FASE-1" "Refs: FASE-1"
find "$m/junit" "$m/evidencias" -type f -exec touch {} +
build; shape_ok "moment 4a (FASE built)"
expect "moment 4a: tasks done, not verified → verify" "$(jf "$D" 'j.where.phase+":"+F(1).status+":"+F(1).tasks.done+"/"+F(1).tasks.total')" "verify:building:8/8"
expect "moment 4a: where.fase and now name the delivery" "$(jf "$D" 'j.where.fase.n+"/"+j.where.fase.of+"|"+j.where.now.slice(0,40)')" "1/1|Estamos comprobando la entrega 1 de 1: E"
(cd "$m" && GIT_COMMITTER_DATE="2026-09-12T18:00:00" git tag -a fase-1-verified -m "FASE-1 implementation complete and verified")
build; shape_ok "moment 4 (FASE tagged, gate blocked)"
expect "moment 4: tag, but the bench's defects block the gate → not offered to the customer" "$(jf "$D" 'j.where.phase+":"+F(1).status+":"+j.where.needFromYou.map(x=>x.anchor).join()+":"+F(1).missingVideos.join()')" "verify:building::WF-001"
expect "moment 4: tag in the FASE and in the journal" "$(jf "$D" 'F(1).tags.map(t=>t.name).join()+"|"+j.journal.filter(e=>e.derived&&e.kind==="evidence").map(e=>e.refs.join("+")).join()')" "fase-1-verified|FASE-1+fase-1-verified"
expect "moment 4: statuses (verified, held back by the bench's defects, failing none)" "$(jf "$D" 'j.requirements.map(r=>r.id.slice(-1)+r.status[0]).join()')" "1s,2b,3b,4s,5s,6s,7b,8s"
# with the gates a person turned off, the same FASE passes its gate and the customer is asked to try it
printf -- '- visual_evidence: off\n- literal_gate: off\n- adversarial_gate: off\n' >> "$m/CLAUDE.md"; commit "docs: gates off for this moment"
find "$m/junit" -type f -exec touch {} +
build; shape_ok "moment 4b (gate passes)"
expect "moment 4b: gate passes → deliver, the customer is asked to try it" "$(jf "$D" 'j.where.phase+":"+F(1).status+":"+j.where.needFromYou.map(x=>x.anchor).join()')" "deliver:verified:FASE-1"
run accept record fase-acceptance --fase 1 --result accepted --channel "reunión de demo" --by "Marta Ibáñez" --role "coordinación académica"
expect "fase-acceptance recorded" "$rc" 0
build; shape_ok "moment 5 (signed)"
expect "moment 5: accepted → done, every phase done" "$(jf "$D" 'j.where.phase+":"+F(1).status+":"+j.where.phases.filter(p=>p.state==="done").length+":"+j.where.next+":"+j.where.fase')" "done:accepted:6:null:null"
expect "moment 5: who accepted, by which channel" "$(jf "$D" 'F(1).acceptance.by+"|"+F(1).acceptance.role+"|"+F(1).acceptance.channel')" "Marta Ibáñez|coordinación académica|reunión de demo"
expect "moment 5: the acceptance is in the journal" "$(jf "$D" 'j.journal.filter(e=>e.kind==="decision"&&e.refs.includes("FASE-1")).map(e=>e.text+"|"+e.by).join()')" "Aceptaste la entrega 1.|Marta Ibáñez (coordinación académica)"
[ ! -e "$m/.sdd/acceptance.json" ] && pass "build never writes .sdd/acceptance.json" || bad "build wrote the ledger"

# ---------------------------------------------------------------- 5. the full seeded bench: evidence, warnings, links, secrets
bash "$ROOT/tests/seeded/run.sh" --prepare "$tmp/seeded" > /dev/null
repo="$tmp/seeded/app"
printf 'CV_GENERATOR=vertex\nVERTEX_TOKEN=sk-live-NEVER-ON-THE-PAGE\n' > "$repo/.env"
printf 'PK\003\004 cookies sk-live-NEVER-ON-THE-PAGE\n' > "$repo/evidencias/FASE-1/REQ-F-001-AC1-trace.zip"
mkdir -p "$repo/docs"; echo "# notas" > "$repo/docs/notas.md"
commit "docs: notas" "Refs: REQ-F-001"
build; shape_ok "seeded bench"
O="$repo/.sdd/status-page"
expect "seeded: every requirement has its criteria with tests bound" "$(jf "$D" 'j.requirements.every(r=>r.criteria.length&&r.criteria.every(c=>c.tests.total>0))')" true
expect "seeded: shown requirements carry a published capture per criterion" "$(jf "$D" 'j.requirements.filter(r=>r.status==="shown").every(r=>r.criteria.every(c=>c.captures.length&&c.captures.every(x=>x.published)))')" true
expect "seeded: REQ-F-007 unshown (no capture), held back" "$(jf "$D" 'R("REQ-F-007").status+":"+R("REQ-F-007").criteria[0].status+":"+R("REQ-F-007").warnings.map(w=>w.code).join("+")')" "building:unshown:unshown"
expect "seeded: REQ-F-002 and REQ-F-003 weakened with the missing literal" "$(jf "$D" '["REQ-F-002","REQ-F-003"].map(id=>R(id).criteria[0].status+"/"+R(id).warnings[0].code).join()')" "weakened/weakened,weakened/weakened"
contains "$(jf "$D" 'R("REQ-F-002").warnings[0].text')" '"Proyectos personales"' && pass "seeded: the weakened warning names the literal" || bad "weakened text"
expect "seeded: tests n of n per criterion" "$(jf "$D" 'R("REQ-F-006").criteria.map(c=>c.tests.pass+"/"+c.tests.total).join()')" "1/1,1/1"
expect "seeded: the scenario-named video reaches its requirement" "$(jf "$D" 'R("REQ-F-008").videos.map(v=>v.path+":"+v.published).join()')" "evidencias/FASE-1/AC-001-05-descarga.webm:true"
expect "seeded: 10 evidence files, all published" "$(jf "$D" 'j.evidence.files.length+":"+j.evidence.files.every(f=>f.published&&f.reason===null)')" "10:true"
expect "seeded: copies = published files" "$(cd "$O" && find evidencias -type f | sort | tr '\n' ',')" "$(jf "$D" 'j.evidence.files.map(f=>f.path).sort().join()+","')"
expect "seeded: copies keep their sha256" "$(cd "$O" && shasum -a 256 evidencias/FASE-1/REQ-F-001-AC1.png | cut -c1-64)" "$(jf "$D" 'j.evidence.files.find(f=>f.path.endsWith("REQ-F-001-AC1.png")).sha256.slice(7)')"
if grep -rq "sk-live-NEVER-ON-THE-PAGE" "$O"; then bad "seeded: a secret reached the page"; else pass "seeded: no .env content in the output"; fi
[ -z "$(find "$O" -name '*trace*')" ] && pass "seeded: no trace copied" || bad "seeded: trace copied"
if grep -q "createServer\|module.exports\|require(" "$O/data.json"; then bad "seeded: code in data.json"; else pass "seeded: no code in data.json"; fi
expect "seeded: commit linked to the requirement, no URL without origin" "$(jf "$D" 'R("REQ-F-001").links.commits.map(c=>c.subject+":"+c.url).join()')" "docs: notas:null"
full=$(cd "$repo" && git rev-parse HEAD)
(cd "$repo" && git remote add origin git@github.com:campus/cv-alumnos.git && git tag fase-1-verified && git branch 7-fase-1-cv)
build
expect "GitHub: repo web" "$(jf "$D" 'j.project.repo.provider+" "+j.project.repo.web')" "github https://github.com/campus/cv-alumnos"
expect "GitHub: commit URL" "$(jf "$D" 'R("REQ-F-001").links.commits[0].url')" "https://github.com/campus/cv-alumnos/commit/$full"
expect "GitHub: tag URL" "$(jf "$D" 'F(1).tags[0].url')" "https://github.com/campus/cv-alumnos/releases/tag/fase-1-verified"
expect "GitHub: FASE issue from the branch {N}-fase-1-…" "$(jf "$D" 'F(1).issue.number+" "+F(1).issue.url+" "+R("REQ-F-001").links.issue.number')" "7 https://github.com/campus/cv-alumnos/issues/7 7"
(cd "$repo" && git remote set-url origin https://gitlab.com/campus/cv-alumnos.git)
build
expect "GitLab: commit URL" "$(jf "$D" 'R("REQ-F-001").links.commits[0].url')" "https://gitlab.com/campus/cv-alumnos/-/commit/$full"
expect "GitLab: tag and issue URLs" "$(jf "$D" 'F(1).tags[0].url+" "+F(1).issue.url')" "https://gitlab.com/campus/cv-alumnos/-/tags/fase-1-verified https://gitlab.com/campus/cv-alumnos/-/issues/7"
expect "webUrl: blob on both providers" "$(node --input-type=module -e '
import { webUrl } from "'"$ROOT"'/scripts/lib/tracker.mjs";
const gh = { provider: "github", host: "github.com", path: "a/b" }, gl = { provider: "gitlab", host: "gitlab.com", path: "g/s/p" };
process.stdout.write([webUrl(gh, { kind: "blob", ref: "v1", path: "docs/a b.md" }), webUrl(gl, { kind: "blob", ref: "main", path: "x.md" }), String(webUrl({ provider: null }, { kind: "commit", sha: "a" }))].join(" "));')" \
  "https://github.com/a/b/blob/v1/docs/a%20b.md https://gitlab.com/g/s/p/-/blob/main/x.md null"
# a video over 15 MB is listed, never copied
head -c 16000000 /dev/zero > "$repo/evidencias/FASE-1/WF-001-recorrido.webm"
build; shape_ok "seeded with a large video"
expect "large video: too-large, not published" "$(jf "$D" 'const f=j.evidence.files.find(x=>x.path.endsWith("WF-001-recorrido.webm"));f.published+":"+f.reason+":"+F(1).videos.map(v=>v.published).join()')" "false:too-large:false"
[ ! -e "$O/evidencias/FASE-1/WF-001-recorrido.webm" ] && pass "large video: not copied" || bad "large video copied"
expect "large video: the FASE video is no longer missing" "$(jf "$D" 'R("REQ-F-002").warnings.map(w=>w.code).join()')" "weakened"
# a capture a person withheld (personal data) is listed, never copied; inAssets marks what page.json already has
h4=$(jf "$D" 'j.evidence.files.find(f=>f.path.endsWith("REQ-F-004-AC1.png")).sha256')
h1=$(jf "$D" 'j.evidence.files.find(f=>f.path.endsWith("REQ-F-001-AC1.png")).sha256')
run status page asset --sha256 "$h4" --url withheld
run status page asset --sha256 "$h1" --url evidencias/FASE-1/REQ-F-001-AC1.png
build; shape_ok "seeded with a withheld capture"
expect "withheld capture: personal-data, not published, on its card too" \
  "$(jf "$D" 'const f=j.evidence.files.find(x=>x.path.endsWith("REQ-F-004-AC1.png"));f.published+":"+f.reason+":"+R("REQ-F-004").criteria[0].captures[0].published')" "false:personal-data:false"
[ ! -e "$O/evidencias/FASE-1/REQ-F-004-AC1.png" ] && [ -e "$O/evidencias/FASE-1/REQ-F-001-AC1.png" ] && pass "withheld capture: not copied" || bad "withheld capture copied"
expect "inAssets: true only for the hashes in page.json" "$(jf "$D" 'j.evidence.files.filter(f=>f.inAssets).map(f=>f.path.split("/").pop()).sort().join()')" "REQ-F-001-AC1.png,REQ-F-004-AC1.png"
run status build --template "$TPL" --json
expect "status build --json: each evidence file with path, sha256, bytes, published, inAssets" \
  "$(js 'j.evidence.files.every(f=>["path","sha256","bytes","published","inAssets"].every(k=>k in f))+":"+j.evidence.files.filter(f=>f.published&&!f.inAssets).length')" "true:8"
# index.html: the same JSON, embedded and escaped; the journal sorted by time (a union merge can mix the lines)
mkdir -p "$repo/status"
printf '%s\n' '{"at":"2026-09-11T09:00:00Z","feature":"initial","stage":"acceptance","kind":"feedback","text":"La cliente escribió </script><!-- en un comentario.","refs":[]}' \
  '{"at":"2026-09-05T09:00:00Z","feature":"initial","stage":"plan-architect","kind":"done","text":"Planificamos una entrega.","refs":["FASE-1"],"by":null}' > "$repo/status/journal.jsonl"
build
expect "journal: sorted by at, written lines kept" "$(jf "$D" 'j.journal.filter(e=>!e.derived).map(e=>e.kind+"@"+e.at.slice(5,10)).join()')" "done@09-05,feedback@09-11"
expect "journal: by null is left out" "$(jf "$D" '"by" in j.journal.find(e=>e.kind==="done"&&!e.derived)')" false
expect "index.html: embedded JSON equals data.json" "$(node -e '
const fs=require("fs");const h=fs.readFileSync(process.argv[1],"utf8");
const m=h.match(/<script type="application\/json" id="sdd-data">([\s\S]*?)<\/script>/);
const d=JSON.parse(fs.readFileSync(process.argv[2],"utf8"));
process.stdout.write(String(Boolean(m)&&JSON.stringify(JSON.parse(m[1]))===JSON.stringify(d)));' "$O/index.html" "$D")" true
expect "index.html: </script and <!-- escaped inside the data" "$(grep -c '</script><!--' "$O/index.html" || true)" 0
grep -q 'escribió \\u003c/script>\\u003c!-- en' "$O/index.html" && pass "index.html: every < of the data as \\u003c" || bad "index.html: escape form"
expect "index.html: title of two to four words with the project name" "$(grep -o "<title>[^<]*</title>" "$O/index.html")" "<title>Estado · cv-alumnos</title>"
expect "index.html: the template around the data is kept" "$(grep -c 'document.getElementById("sdd-data")' "$O/index.html")" 1
expect "journal: a written line comes first, not derived" "$(jf "$D" 'j.journal.filter(e=>e.kind==="feedback").map(e=>e.derived).join()')" false
# a template that already holds the element: its content is replaced
printf '<html><script type="application/json" id="sdd-data"><!--SDD-DATA--></script></html>\n' > "$tmp/inside.html"
run status build --template "$tmp/inside.html" --out .sdd/other
expect "template with the element: one sdd-data element" "$(grep -o 'id="sdd-data"' "$repo/.sdd/other/index.html" | wc -l | tr -d ' ')" 1
run status build --template "$TPL" --json
expect "status build --json prints the data" "$(js 'j.$schema+":"+j.where.phase')" "sdd-status-v1:agree"
# the real template of the plugin: the built page holds the JSON, not the marker, and the project title
run status build --out .sdd/real
expect "real template: build exits 0" "$rc" 0
expect "real template: the marker is gone, one sdd-data element" "$(grep -c 'id="sdd-data"><!--SDD-DATA-->' "$repo/.sdd/real/index.html" || true):$(grep -o 'id="sdd-data"' "$repo/.sdd/real/index.html" | wc -l | tr -d ' ')" "0:1"
expect "real template: embedded JSON equals data.json" "$(node -e '
const fs=require("fs");const h=fs.readFileSync(process.argv[1],"utf8");
const m=h.match(/<script type="application\/json" id="sdd-data">([\s\S]*?)<\/script>/);
process.stdout.write(String(Boolean(m)&&JSON.stringify(JSON.parse(m[1]))===JSON.stringify(JSON.parse(fs.readFileSync(process.argv[2],"utf8")))));' "$repo/.sdd/real/index.html" "$repo/.sdd/real/data.json")" true
expect "real template: title with the project name" "$(grep -o "<title>[^<]*</title>" "$repo/.sdd/real/index.html")" "<title>Estado · cv-alumnos</title>"

# ---------------------------------------------------------------- 6. the acceptance todo fixture: records and attachments
newrepo "$tmp/todo"; repo="$tmp/todo"
cp -R "$ROOT/tests/fixtures/acceptance/todo/." "$repo/"
mkdir -p "$repo/evidencias/FASE-1"
printf 'png-columns' > "$repo/evidencias/FASE-1/REQ-F-006-AC1.png"
printf 'png-package' > "$repo/evidencias/FASE-1/REQ-C-001-package.png"
commit "feat: todo"
mkdir -p "$repo/.sdd/junit"
cat > "$repo/.sdd/junit/unit.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<testsuites><testsuite name="tests/todo.test.ts" tests="6">
<testcase classname="tests/todo.test.ts" name="AC-001-01 adds"/>
<testcase classname="tests/todo.test.ts" name="AC-001-02 empty title"/>
<testcase classname="tests/todo.test.ts" name="AC-002-01 order"/>
<testcase classname="tests/todo.test.ts" name="AC-002-02 empty list"><failure message="boom">stack</failure></testcase>
<testcase classname="tests/todo.test.ts" name="test_ac_002_03_filter"/>
<testcase classname="tests/todo.test.ts" name="AC-002-04 rm keeps ids"/>
</testsuite></testsuites>
EOF
run accept record measurement --req REQ-NF-002 --metric statements --observed 92.5 --op ge --threshold 90 --paths src --by Ana --role "tech lead"
run accept record demo --req REQ-F-006 --ac 1 --observed "columns aligned" --pass true --by Laura --role "product owner" --attach evidencias/FASE-1/REQ-F-006-AC1.png
run accept record inspection --req REQ-C-001 --note "package.json has no dependencies" --paths package.json --by Ana --role "tech lead" --attach evidencias/FASE-1/REQ-C-001-package.png
run accept record waiver --req REQ-F-005 --reason "customer defers delete" --follow-up "#12" --by Laura --role "product owner"
expect "todo: four records" "$(wc -l < "$repo/acceptance/decisions.jsonl" | tr -d ' ')" 4
printf 'png-package-retouched' > "$repo/evidencias/FASE-1/REQ-C-001-package.png"
build; shape_ok "todo fixture"
expect "todo: language en" "$(jf "$D" 'j.project.lang')" en
expect "todo: statuses" "$(jf "$D" 'j.requirements.map(r=>r.id+"="+r.status).join()')" \
  "REQ-F-001=shown,REQ-F-002=failing,REQ-F-003=shown,REQ-F-004=deprecated,REQ-F-005=deferred,REQ-F-006=shown,REQ-NF-001=pending,REQ-NF-002=shown,REQ-C-001=shown"
expect "todo: kinds" "$(jf "$D" 'j.requirements.map(r=>r.kind).join("")')" "FFFFFFNFNFC"
expect "todo: tests per criterion" "$(jf "$D" 'R("REQ-F-001").criteria.map(c=>c.tests.pass+"/"+c.tests.total).join()+"|"+R("REQ-F-002").criteria.map(c=>c.status).join()')" "1/1,1/1|pass,fail"
expect "todo: failing warning on the failing criterion" "$(jf "$D" 'R("REQ-F-002").warnings.map(w=>w.code+":"+w.ac).join()')" "failing:2"
expect "todo: measurement value against threshold" "$(jf "$D" 'JSON.stringify(R("REQ-NF-002").criteria[0].measurement)')" '{"metric":"statements","observed":92.5,"op":"ge","threshold":90}'
expect "todo: demo record with who and what was seen" "$(jf "$D" 'const r=R("REQ-F-006").criteria[0].record;r.type+"|"+r.by+"|"+r.note+"|"+Boolean(r.at)')" "demo|Laura (product owner)|columns aligned|true"
expect "todo: inspection record" "$(jf "$D" 'const r=R("REQ-C-001").criteria[0].record;r.type+"|"+r.note')" "inspection|package.json has no dependencies"
expect "todo: waiver with its date" "$(jf "$D" 'const w=R("REQ-F-005").waiver;[w.reason,w.by,w.followUp,/^20..-..-..T..:..:..Z$/.test(w.at)].join("|")')" "customer defers delete|Laura (product owner)|#12|true"
expect "todo: C without priority is a Must, NF Should" "$(jf "$D" 'R("REQ-C-001").priority+":"+R("REQ-NF-001").priority')" "Must:Should"
expect "todo: attachment present with its sha → published; changed one → not" "$(jf "$D" 'j.evidence.files.map(f=>f.path+":"+f.published+":"+f.reason).join()')" \
  "evidencias/FASE-1/REQ-F-006-AC1.png:true:null,evidencias/FASE-1/REQ-C-001-package.png:false:missing"
[ -f "$repo/.sdd/status-page/evidencias/FASE-1/REQ-F-006-AC1.png" ] && [ ! -e "$repo/.sdd/status-page/evidencias/FASE-1/REQ-C-001-package.png" ] \
  && pass "todo: only the matching attachment is copied" || bad "todo: copies"
expect "todo: FASE scope from the header" "$(jf "$D" 'F(1).requirements.join()+":"+F(1).status+":"+R("REQ-F-001").fase+":"+R("REQ-F-003").fase')" "REQ-F-001,REQ-F-002:building:1:null"
expect "todo: records in the journal (derived)" "$(jf "$D" 'j.journal.filter(e=>e.derived).map(e=>e.kind+":"+e.refs.join("+")).join()')" \
  "evidence:REQ-NF-002,evidence:REQ-F-006,evidence:REQ-C-001,decision:REQ-F-005"
expect "todo: english texts" "$(jf "$D" 'j.journal.find(e=>e.kind==="decision").text')" "We agreed to defer REQ-F-005: customer defers delete."
# a journal line already written for a record is not repeated by the derived one
run journal add --stage acceptance --kind decision --text "Laura deferred deleting tasks." --refs REQ-F-005 --at "$(jf "$repo/acceptance/decisions.jsonl" 'j.at' 2>/dev/null || node -e 'const l=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n");process.stdout.write(JSON.parse(l[3]).at)' "$repo/acceptance/decisions.jsonl")"
build
expect "todo: written line replaces the derived one" "$(jf "$D" 'j.journal.filter(e=>e.kind==="decision").map(e=>e.derived+":"+e.text).join()')" "false:Laura deferred deleting tasks."
# a feature of a change: its requirements and the change report
mkdir -p "$repo/changes"
printf '# Change Report — Export to JSON\n\n## 1. Executive summary\n\nADD REQ-F-003 as its own feature.\n' > "$repo/changes/CHANGE-REPORT-CHG-2026-09-20-001.md"
run status page feature add --id CHG-2026-09-20-001 --title "Export" --chg CHG-2026-09-20-001
build; shape_ok "todo with a feature"
expect "feature: listed after the initial one" "$(jf "$D" 'j.features.map(f=>f.id).join()')" "initial,CHG-2026-09-20-001"
expect "feature: a FASE takes the feature of its requirements" "$(jf "$D" 'F(1).feature')" initial
expect "feature: its requirement and the change in the journal" "$(jf "$D" 'R("REQ-F-003").feature+"|"+j.journal.filter(e=>e.kind==="change").map(e=>e.feature+":"+e.refs[0]).join()')" \
  "CHG-2026-09-20-001|CHG-2026-09-20-001:CHG-2026-09-20-001"
[ ! -e "$repo/.sdd/acceptance.json" ] && pass "todo: build never writes .sdd/acceptance.json" || bad "todo: ledger written"

# the template's sample data follows the same contract the CLI writes
node "$ROOT/tests/status/shape.mjs" "$ROOT/templates/status-page/sample-data.json" >/dev/null 2>&1 \
  && pass "template sample-data.json follows sdd-status-v1" || bad "template sample-data.json drifted from sdd-status-v1"

if [ "$fail" = 0 ]; then echo "status: all tests passed"; else echo "status: FAILURES"; fi
exit "$fail"
