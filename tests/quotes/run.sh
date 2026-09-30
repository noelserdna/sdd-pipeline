#!/usr/bin/env bash
# Tests of the literal lint (scripts/sdd.mjs lint --quotes, scripts/lib/quotes.mjs) and its place in the acceptance
# ledger: Q-01 (no quote comment, warn), Q-02 (quote not the criterion's current text, error), Q-03 (a literal of the
# criterion missing from the test's code, error), a correct quote without findings, a literal only in a comment,
# a test bound through a BDD scenario id (AC-NNN-NN), --fase scope, --json, the human literal-exception and its expiry
# on a MODIFY, literal_gate enforce/warn/off in `sdd accept` and `sdd gate`, the `weakened` state, the loop route
# `weakened-test`, the report and the PR block. Fixture: tests/fixtures/acceptance/todo copied into a temporary git
# repo (visual_evidence off there, so the visual rule stays out of the way). bash 3.2 and 5; needs git, node >= 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
FIX="$ROOT/tests/fixtures/acceptance/todo"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
run() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>&1) || rc=$?; }
runo() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>/dev/null) || rc=$?; }
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
ledger() { node -e 'const L=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const R=(id)=>L.requirements.find((r)=>r.id===id);process.stdout.write(String(eval(process.argv[2])))' "$repo/.sdd/acceptance.json" "$1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if contains "$out" "$2"; then pass "$1"; else bad "$1 (missing: $2)"; fi; }
hasnt() { if contains "$out" "$2"; then bad "$1 (unexpected: $2)"; else pass "$1"; fi; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"

n=0
commit() { n=$((n + 1)); local d; d="2026-01-01T00:$(printf %02d "$n"):00"; ( cd "$repo" && git add -A && GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -qm "$1" ); }
# junit name=status… → .sdd/junit/todo.xml (written after the last commit, so it is fresh)
junit() {
  mkdir -p "$repo/.sdd/junit"
  { echo '<?xml version="1.0" encoding="UTF-8"?><testsuites><testsuite name="tests/todo.test.js">'
    local p
    for p in "$@"; do
      case "${p##*=}" in
        pass) echo "<testcase classname=\"tests/todo.test.js\" name=\"${p%=*}\" time=\"0.01\"/>" ;;
        fail) echo "<testcase classname=\"tests/todo.test.js\" name=\"${p%=*}\"><failure message=\"boom\"/></testcase>" ;;
      esac
    done
    echo '</testsuite></testsuites>'; } > "$repo/.sdd/junit/todo.xml"
}
fresh_repo() {
  repo="$tmp/$1"; rm -rf "$repo"; cp -R "$FIX" "$repo"; mkdir -p "$repo/tests"
  ( cd "$repo" && git init -q -b main )
}
# set_profile KEY VALUE → replaces or appends `- KEY: VALUE` in the fixture's SDD Stack Profile
set_profile() {
  node -e 'const fs=require("fs");const [f,k,v]=process.argv.slice(1);let t=fs.readFileSync(f,"utf8");const re=new RegExp("^- "+k+":.*$","m");t=re.test(t)?t.replace(re,"- "+k+": "+v):t.replace(/\n*$/,"\n- "+k+": "+v+"\n");fs.writeFileSync(f,t)' "$repo/CLAUDE.md" "$1" "$2"
}
# replace FILE FROM TO → literal text replacement
replace() { node -e 'const fs=require("fs");const [f,a,b]=process.argv.slice(1);const t=fs.readFileSync(f,"utf8");if(!t.includes(a)){console.error("replace: not found: "+a);process.exit(1)}fs.writeFileSync(f,t.split(a).join(b))' "$repo/$1" "$2" "$3"; }

# A test file that quotes each criterion it names and asserts its literals (the convention of tdd-workflow.md).
good_tests() {
  cat > "$repo/tests/todo.test.js" <<'EOF'
import { run } from "./helpers.js";

test("AC-001-01 add a task", () => {
  // REQ-F-001 AC1: "…WHEN the user runs `todo add "Buy milk"` THEN task 1 "Buy milk" is pending"
  expect(run("add", "Buy milk").stdout).toBe("1 Buy milk pending");
});

test("AC-001-02 empty title", () => {
  // REQ-F-001 AC2: "GIVEN any state WHEN the user runs `todo add ""` THEN the command exits 2 with `title must not be empty`"
  const r = run("add", "");
  expect(r.code).toBe(2);
  expect(r.stderr).toContain('title must not be empty');
});

test("AC-002-01 list in id order", () => {
  // REQ-F-002 AC1: "GIVEN tasks 1 and 2 WHEN the user runs `todo list` THEN two lines are printed in id order"
  expect(run("list").stdout.split("\n")).toHaveLength(2);
});

test("AC-002-02 empty list", () => {
  // REQ-F-002 AC2: "…THEN the output is `No tasks`"
  expect(run("list").stdout).toBe(`No tasks`);
});
EOF
}

# ---------------------------------------------------------------- 1. syntax and help
for f in scripts/sdd.mjs scripts/lib/quotes.mjs scripts/lib/acceptance.mjs scripts/lib/acceptance-cli.mjs; do
  if node --check "$ROOT/$f" 2>/dev/null; then pass "node --check $f"; else bad "node --check $f"; fi
done
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
repo="$tmp"
run --help
has "--help documents lint --quotes" "sdd lint --quotes [--fase N] [--json]"
has "--help documents literal-exception" "literal-exception --req ID --ac N --literal TEXT"
has "--help documents literal_gate" "literal_gate: off|warn|enforce"
has "--help documents weakened-test" "weakened-test"

# ---------------------------------------------------------------- 2. unit: literals, quotes, comments
unit() { node --input-type=module -e "import * as q from '$ROOT/scripts/lib/quotes.mjs'; $1"; }
got=$(unit 'process.stdout.write(JSON.stringify(q.criterionLiterals("GIVEN an empty list WHEN the user runs `todo add \"Buy milk\"` THEN task 1 \"Buy milk\" is pending").map(l=>l.literal)))')
expect "literal: quoted text; the WHEN command in backticks is not a literal" "$got" '["Buy milk"]'
got=$(unit 'process.stdout.write(JSON.stringify(q.criterionLiterals("GIVEN any state WHEN the user runs `todo add \"\"` THEN the command exits 2 with `title must not be empty`").map(l=>l.literal)))')
expect "literal: a THEN backtick span is a literal; an empty quote is not" "$got" '["title must not be empty"]'
got=$(unit "process.stdout.write(JSON.stringify(q.criterionLiterals(\"CUANDO el usuario abre la lista ENTONCES el usuario ve el título 'Proyectos personales' y el proyecto «Huerto 2026»\").map(l=>l.literal)))")
expect "literal: single quotes and guillemets" "$got" '["Proyectos personales","Huerto 2026"]'
got=$(unit "process.stdout.write(JSON.stringify(q.criterionLiterals(\"GIVEN the user's list WHEN it isn't empty THEN the header reads \u201cYour tasks\u201d\").map(l=>l.literal)))")
expect "literal: an apostrophe is not a quote; curly quotes are" "$got" '["Your tasks"]'
got=$(unit "process.stdout.write(String(q.quoteMatches('…ENTONCES el usuario ve el título \"Proyectos personales\"', \"CUANDO x ENTONCES el usuario ve el título 'Proyectos personales' y más\")))")
expect "quote: elided GIVEN/WHEN and another quote mark still match" "$got" true
got=$(unit "process.stdout.write(String(q.quoteMatches('…ENTONCES el usuario ve el título \"proyectos personales\"', \"CUANDO x ENTONCES el usuario ve el título 'Proyectos personales'\")))")
expect "quote: case is not normalized" "$got" false
got=$(unit "const r=q.splitComments('const a = \"// not a comment\"; // REQ-F-001 AC1: \"x\"\n# not a comment in js\n/* block\n * REQ-F-002 AC1: \"y\" */ b();\n', 'a.test.ts'); process.stdout.write(JSON.stringify([r.comments.map(c=>c.line+':'+c.text), r.code.includes('not a comment'), r.code.includes('REQ-F-001')]))")
expect "comments: // and /* */ found by line; strings kept as code" "$got" '[["1:REQ-F-001 AC1: \"x\"","3:block","4:REQ-F-002 AC1: \"y\""],true,false]'
got=$(unit "const r=q.splitComments('it \"AC-001-01 works\" do # REQ-F-001 AC1: \"x\"\n  assert_equal \"#{a} b\", c\nend\n', 'todo_test.rb'); process.stdout.write(JSON.stringify([r.comments.map(c=>c.text), r.code.includes('#{a} b')]))")
expect "comments: # in Ruby, interpolation inside a string is code" "$got" '[["REQ-F-001 AC1: \"x\""],true]'

# ---------------------------------------------------------------- 3. lint --quotes: correct quotes, no findings
fresh_repo lint
good_tests
run lint --quotes
expect "correct quotes and literals: exit 0" "$rc" 0
has "summary line" "lint --quotes: 4 criterion-file pair(s) in 1 test file(s), 4 criteria · 0 error(s) · 0 warning(s) · 0 excepted"
hasnt "no finding printed" "Q-0"

# ---------------------------------------------------------------- 4. Q-01 (warn)
replace tests/todo.test.js '  // REQ-F-002 AC1: "GIVEN tasks 1 and 2 WHEN the user runs `todo list` THEN two lines are printed in id order"
' ''
run lint --quotes
expect "Q-01 alone: exit 0 (a warning)" "$rc" 0
has "Q-01 names file, line, criterion" "tests/todo.test.js:15 Q-01 REQ-F-002 AC1"
has "Q-01 counted as a warning" "0 error(s) · 1 warning(s)"

# ---------------------------------------------------------------- 5. Q-02 (error): forged quote
good_tests
replace tests/todo.test.js 'THEN task 1 "Buy milk" is pending"' 'THEN task 1 "Buy milk" is done"'
run lint --quotes
expect "Q-02: exit 1" "$rc" 1
has "Q-02 on the quote's line" "tests/todo.test.js:4 Q-02 REQ-F-001 AC1"
runo lint --quotes --json
expect "--json: exit 1" "$rc" 1
expect "--json: Q-02 finding shape" "$(js 'const f=j.findings.find(x=>x.code==="Q-02");[f.severity,f.req,f.ac,f.file,f.line,f.quote.endsWith("is done")].join(",")')" "error,REQ-F-001,1,tests/todo.test.js,4,true"
expect "--json: summary counts" "$(js '[j.summary.errors,j.summary.warnings,j.summary.pairs].join(",")')" "1,0,4"

# ---------------------------------------------------------------- 6. Q-03 (error): literal missing; a comment does not count
good_tests
replace tests/todo.test.js 'expect(run("list").stdout).toBe(`No tasks`);' 'expect(run("list").stdout).toMatch(/no/i); // No tasks'
run lint --quotes
expect "Q-03: exit 1" "$rc" 1
has "Q-03 names the literal" 'tests/todo.test.js:21 Q-03 REQ-F-002 AC2 the literal "No tasks" of REQ-F-002 AC2 is not in the test'
runo lint --quotes --json
expect "--json: Q-03 carries literal" "$(js 'j.findings.filter(x=>x.code==="Q-03").map(x=>x.literal).join("|")')" "No tasks"

# The case of 5.1: the criterion asks for 'Proyectos personales' and the test asserts 'Proyectos'.
replace requirements/REQUIREMENTS.md 'THEN the output is `No tasks`' "THEN the heading reads 'Proyectos personales'"
good_tests
replace tests/todo.test.js '  // REQ-F-002 AC2: "…THEN the output is `No tasks`"
  expect(run("list").stdout).toBe(`No tasks`);' "  // REQ-F-002 AC2: \"…THEN the heading reads 'Proyectos personales'\"
  expect(run(\"list\").stdout).toContain('Proyectos');"
run lint --quotes
expect "Proyectos vs Proyectos personales: exit 1" "$rc" 1
has "Proyectos personales is a Q-03" 'Q-03 REQ-F-002 AC2 the literal "Proyectos personales"'
replace tests/todo.test.js "toContain('Proyectos')" 'toContain("Proyectos   personales")'
run lint --quotes
expect "same literal with other quotes and spacing: exit 0" "$rc" 0

# ---------------------------------------------------------------- 7. binding: REQ-X-NNN ACn, BDD scenario, unknown, --fase
fresh_repo bind
good_tests
cat > "$repo/tests/rm.test.js" <<'EOF'
test("REQ-F-005 AC2 rm of an unknown id", () => {
  expect(run("rm", "9").code).toBe(3);
});
// REQ-F-003 AC1 is only named in this comment: no pair
EOF
run lint --quotes
expect "REQ-F-005 AC2 bound by name: Q-01 and Q-03" "$rc" 1
has "REQ-X ACn name binds (Q-01)" "tests/rm.test.js:1 Q-01 REQ-F-005 AC2"
has "REQ-X ACn name binds (Q-03)" 'tests/rm.test.js:1 Q-03 REQ-F-005 AC2 the literal "task 9 not found"'
hasnt "a criterion named only in a comment is not a pair" "REQ-F-003"
has "scenario AC-001-01 bound through the BDD tag to REQ-F-001 AC1" "5 criterion-file pair(s) in 2 test file(s)"
run lint --quotes --fase 1
expect "--fase 1 leaves REQ-F-005 out: exit 0" "$rc" 0
has "--fase 1 summary" "4 criterion-file pair(s) in 1 test file(s), 4 criteria · 0 error(s) · 0 warning(s) · 0 excepted · FASE 1"

# ---------------------------------------------------------------- 8. MODIFY makes a quote stale (Q-02)
fresh_repo modify
good_tests
replace requirements/REQUIREMENTS.md 'THEN task 1 "Buy milk" is pending' 'THEN task 1 "Buy milk" is pending and shown first'
run lint --quotes
expect "after a MODIFY the old quote still matches as a prefix fragment: exit 0" "$rc" 0
replace requirements/REQUIREMENTS.md 'THEN task 1 "Buy milk" is pending and shown first' 'THEN task 1 "Buy oat milk" is pending'
run lint --quotes
expect "after a MODIFY of the literal: exit 1" "$rc" 1
has "stale quote is Q-02" "tests/todo.test.js:4 Q-02 REQ-F-001 AC1"
has "new literal is Q-03" 'Q-03 REQ-F-001 AC1 the literal "Buy oat milk"'

# ---------------------------------------------------------------- 9. literal exception (human) and its expiry
fresh_repo exception
good_tests
cat > "$repo/tests/helpers.js" <<'EOF'
export const run = () => ({});
EOF
replace tests/todo.test.js "expect(r.stderr).toContain('title must not be empty');" 'expect(r.stderr).toContain(msg("empty"));'
commit "initial"
run lint --quotes
expect "helper-built literal: Q-03, exit 1" "$rc" 1
run accept record literal-exception --req REQ-F-001 --ac 2 --literal "not a literal" --reason helper --by Ana --role PO
expect "exception for a text that is not a literal of the criterion: exit 2" "$rc" 2
has "says it is not a literal" '"not a literal" is not a literal of REQ-F-001 AC2'
run accept record literal-exception --req REQ-F-001 --literal "title must not be empty" --reason helper --by Ana --role PO
expect "exception without --ac: exit 2" "$rc" 2
run accept record literal-exception --req REQ-F-001 --ac 2 --literal "title must not be empty" --reason "msg() builds it from i18n/en.json" --by Ana --role "product owner"
expect "record literal-exception: exit 0" "$rc" 0
has "recorded with the literal" 'recorded literal-exception REQ-F-001 AC2 "title must not be empty"'
expect "record carries reqHash, literal, ac" "$(tail -1 "$repo/acceptance/decisions.jsonl" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);process.stdout.write([r.type,r.ac,r.literal,r.reqHash.startsWith("sha256:"),Boolean(r.head)].join(","))})')" "literal-exception,2,title must not be empty,true,true"
run lint --quotes
expect "excepted Q-03: exit 0" "$rc" 0
has "excepted finding shown" "Q-03 REQ-F-001 AC2 (excepted)"
has "summary counts the exception" "0 error(s) · 0 warning(s) · 1 excepted"
runo lint --quotes --json
expect "--json: excepted severity and exception" "$(js 'const f=j.findings[0];[f.severity,f.exception.by,f.exception.line].join(",")')" "excepted,Ana,1"
commit "exception"
replace requirements/REQUIREMENTS.md 'THEN the command exits 2 with `title must not be empty`' 'THEN the command exits 2 with `title must not be empty` on stderr'
run lint --quotes
expect "exception expires when the requirement text changes: exit 1" "$rc" 1
has "Q-03 again after the MODIFY" 'Q-03 REQ-F-001 AC2 the literal "title must not be empty"'
run accept --fase 1
has "ledger lists the expired exception as a stale decision" "stale decision acceptance/decisions.jsonl:1 literal-exception REQ-F-001"

# ---------------------------------------------------------------- 10. ledger and gate: enforce (default), warn, off
fresh_repo gate
good_tests
replace tests/todo.test.js 'expect(run("add", "Buy milk").stdout).toBe("1 Buy milk pending");' 'expect(run("add", "Buy").stdout).toMatch(/Buy/);'
commit "tests"
junit "AC-001-01 add a task=pass" "AC-001-02 empty title=pass" "AC-002-01 list in id order=pass" "AC-002-02 empty list=pass"
run gate --fase 1
expect "enforce (default): gate exit 1" "$rc" 1
has "gate names the reason" "REQ-F-001  MISSING (test does not carry the criterion's literal)  1/2"
run accept --fase 1
expect "ledger literal_gate enforce" "$(ledger 'L.literal_gate')" enforce
expect "criterion weakened" "$(ledger 'R("REQ-F-001").criteria[0].state')" weakened
expect "requirement MISSING with the literal reason" "$(ledger 'R("REQ-F-001").verdict+"|"+R("REQ-F-001").reason')" "MISSING|test does not carry the criterion's literal"
expect "literal_gaps per criterion" "$(ledger 'JSON.stringify(R("REQ-F-001").criteria[0].literal_gaps)')" '[{"code":"Q-03","file":"tests/todo.test.js","line":4,"literal":"Buy milk"}]'
expect "other criteria have empty literal_gaps" "$(ledger 'R("REQ-F-002").criteria.map(c=>c.literal_gaps.length).join(",")')" "0,0"
expect "summary.literal_gaps and weakened" "$(ledger 'L.summary.literal_gaps+","+L.summary.weakened')" "1,1"
has "accept prints the weakened criterion" "weakened REQ-F-001 AC1: literal \"Buy milk\" not in the test (tests/todo.test.js:4, weakened-test)"
run loop next --fase 1 --reset
expect "loop: target route weakened-test" "$(js 'j.targets.find(t=>t.req==="REQ-F-001").route_hint')" weakened-test
expect "loop: criterion route and gaps" "$(js 'const c=j.targets[0].criteria[0];[c.n,c.state,c.route_hint,c.literal_gaps[0].literal].join(",")')" "1,weakened,weakened-test,Buy milk"
expect "loop does not stop on a weakened test" "$(js 'String(j.stop)')" null
run accept --fase 1 --report acceptance/ACCEPTANCE-REPORT.md
report=$(cat "$repo/acceptance/ACCEPTANCE-REPORT.md")
contains "$report" "## Literal letter" && pass "report has a Literal letter section" || bad "report lacks the Literal letter section"
contains "$report" '| REQ-F-001 | AC1 | weakened | literal "Buy milk" not in the test (Q-03 tests/todo.test.js:4) |' && pass "report row of the gap" || bad "report row of the gap"
contains "$report" "MISSING (test does not carry the criterion's literal)" && pass "report verdict cell carries the reason" || bad "report verdict reason"
run gate --fase 1 --md
has "gate --md carries the literal line" 'Literal letter (`literal_gate: enforce`): 1 criterion whose test lacks'
runo gate --fase 1 --json
expect "gate --json: literal fields" "$(js '[j.code,j.literal_gate,j.literal_gaps,j.weakened].join(",")')" "1,enforce,1,1"

set_profile literal_gate warn
commit "warn"
junit "AC-001-01 add a task=pass" "AC-001-02 empty title=pass" "AC-002-01 list in id order=pass" "AC-002-02 empty list=pass"
run gate --fase 1
expect "warn: gate exit 0" "$rc" 0
has "warn: gate reports the gaps" "literal_gate warn keeps the verdicts"
run accept --fase 1
expect "warn: VERIFIED, criterion pass, gap listed" "$(ledger 'R("REQ-F-001").verdict+","+R("REQ-F-001").criteria[0].state+","+R("REQ-F-001").criteria[0].literal_gaps.length')" "VERIFIED,pass,1"
has "warn: accept prints a warning" "warning: literal gap REQ-F-001 AC1"

set_profile literal_gate off
commit "off"
junit "AC-001-01 add a task=pass" "AC-001-02 empty title=pass" "AC-002-01 list in id order=pass" "AC-002-02 empty list=pass"
run gate --fase 1
expect "off: gate exit 0" "$rc" 0
run accept --fase 1
expect "off: no literal_gaps on criteria" "$(ledger 'String(R("REQ-F-001").criteria[0].literal_gaps)')" undefined
expect "off: summary.literal_gaps 0" "$(ledger 'L.summary.literal_gaps')" 0

# Enforce holds back only Musts: a Should with a gap stays VERIFIED and lists it.
set_profile literal_gate enforce
cat > "$repo/tests/filter.test.js" <<'EOF'
test("AC-002-03 filter pending", () => {
  // REQ-F-003 AC1: "…THEN only task 1 is shown"
  expect(run("list", "--status", "pending").stdout).toBe("1 Buy milk pending");
});
EOF
replace tests/todo.test.js 'expect(run("add", "Buy").stdout).toMatch(/Buy/);' 'expect(run("add", "Buy milk").stdout).toBe("1 Buy milk pending");'
replace requirements/REQUIREMENTS.md 'THEN only task 1 is printed' 'THEN only task 1 is printed under "Pending"'
commit "should"
junit "AC-001-01 add a task=pass" "AC-001-02 empty title=pass" "AC-002-01 list in id order=pass" "AC-002-02 empty list=pass" "AC-002-03 filter pending=pass"
run accept
expect "enforce: a Should with a gap stays VERIFIED" "$(ledger 'R("REQ-F-003").verdict+","+R("REQ-F-003").criteria[0].state')" "VERIFIED,pass"
expect "enforce: its gaps are listed (Q-02 quote and Q-03 literal)" "$(ledger 'R("REQ-F-003").criteria[0].literal_gaps.map(g=>g.code).join(",")')" "Q-02,Q-03"
expect "enforce: fixed Must is VERIFIED again" "$(ledger 'R("REQ-F-001").verdict')" VERIFIED
run gate --fase 1
expect "enforce: FASE 1 gate exit 0 once the literal is asserted" "$rc" 0

# ---------------------------------------------------------------- 11. the acceptance fixture stays clean
repo="$FIX"
run lint --quotes
expect "fixture: no test sources, exit 0" "$rc" 0
has "fixture: note on test paths" "note: no test source files under tests"

if [ "$fail" = 0 ]; then echo "tests/quotes: all passed"; else echo "tests/quotes: FAILURES"; exit 1; fi
