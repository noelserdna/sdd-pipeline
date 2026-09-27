#!/usr/bin/env bash
# Tests of the acceptance ledger (scripts/sdd.mjs accept | accept record | gate | loop next | lint --needs) and the
# JUnit reader (scripts/lib/junit.mjs), without a model or network. Fixture project: tests/fixtures/acceptance/todo,
# copied into a temporary git repo; JUnit dialect samples: tests/fixtures/acceptance/junit.
# Covers the verdicts (VERIFIED, FAILING, MISSING, WAIVED, DEPRECATED), NF/C methods (measurement computed in code,
# demo, inspection freshness by paths), waivers voided by a MODIFY, gate exit codes 0/1/2/3 and modes, stale JUnit,
# report rows, --fase scoping, loop stops, JUnit dialects, freshness scoped to code_paths/test_paths (a docs or
# feedback commit keeps evidence fresh), machine measurements (accept measure, accept --remeasure), summarised evidence cells. bash 3.2 (macOS) and bash 5 (Ubuntu CI); needs git, node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
FIX="$ROOT/tests/fixtures/acceptance"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
# run ARGS… → output (stdout+stderr) in $out, exit code in $rc; runs inside the temp repo
run() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>&1) || rc=$?; }
# js EXPR → EXPR evaluated with j = JSON.parse($out)
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
# ledger EXPR → EXPR over .sdd/acceptance.json (L), with v(id) = verdict of a requirement
ledger() { node -e 'const L=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const v=(id)=>L.requirements.find((r)=>r.id===id).verdict;const R=(id)=>L.requirements.find((r)=>r.id===id);process.stdout.write(String(eval(process.argv[2])))' "$repo/.sdd/acceptance.json" "$1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if contains "$out" "$2"; then pass "$1"; else bad "$1 (missing: $2)"; fi; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT || true
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME"

# Commits are dated in the past so that JUnit files written now are newer than the last code commit.
n=0
commit() { n=$((n + 1)); local d; d="2026-01-01T00:$(printf %02d "$n"):00"; ( cd "$repo" && git add -A && GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -qm "$1" ); }
# junit FILE name=status… → a JUnit report (status pass|fail|error|skip)
junit() {
  local f="$repo/$1"; shift
  mkdir -p "$(dirname "$f")"
  { echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<testsuites><testsuite name="tests/todo.test.ts" tests="'$#'">'
    local p name st
    for p in "$@"; do
      name="${p%=*}"; st="${p##*=}"
      case "$st" in
        pass) echo "<testcase classname=\"tests/todo.test.ts\" name=\"$name\" time=\"0.01\"/>" ;;
        fail) echo "<testcase classname=\"tests/todo.test.ts\" name=\"$name\"><failure message=\"boom\">stack</failure></testcase>" ;;
        error) echo "<testcase classname=\"tests/todo.test.ts\" name=\"$name\"><error message=\"crash\"/></testcase>" ;;
        skip) echo "<testcase classname=\"tests/todo.test.ts\" name=\"$name\"><skipped/></testcase>" ;;
      esac
    done
    echo '</testsuite></testsuites>'; } > "$f"
}

# ---------------------------------------------------------------- 1. syntax and help
for f in scripts/sdd.mjs scripts/lib/junit.mjs scripts/lib/acceptance.mjs scripts/lib/acceptance-cli.mjs; do
  if node --check "$ROOT/$f" 2>/dev/null; then pass "node --check $f"; else bad "node --check $f"; fi
done
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
repo="$tmp"
run --help; expect "--help exits 0" "$rc" 0
has "--help documents accept" "sdd accept [--junit PATH...]"
has "--help documents gate codes" "3 met with waived"
has "--help documents loop" "sdd loop next"

# ---------------------------------------------------------------- 2. JUnit dialects
dialect() { node --input-type=module -e '
import { parseJUnit } from "'"$ROOT"'/scripts/lib/junit.mjs";
import { readFileSync } from "node:fs";
const c = parseJUnit(readFileSync(process.argv[1], "utf8"));
process.stdout.write(c.map((x) => `${x.status}|${x.file ?? "-"}|${x.name}`).join("\n"));' "$FIX/junit/$1"; }
d=$(dialect vitest.xml)
expect "vitest: 4 testcases" "$(printf '%s\n' "$d" | wc -l | tr -d ' ')" 4
contains "$d" "pass|tests/add.test.ts|todo add > AC-001-01 adds a pending task" && pass "vitest: entity decoded, file from classname" || bad "vitest: first case ($d)"
contains "$d" "fail|tests/add.test.ts|todo add > AC-001-02" && pass "vitest: failure" || bad "vitest: failure"
contains "$d" "skip|tests/add.test.ts|todo add > AC-001-03" && pass "vitest: skipped" || bad "vitest: skipped"
d=$(dialect pytest.xml)
expect "pytest: CDATA with a fake <testcase> not counted" "$(printf '%s\n' "$d" | wc -l | tr -d ' ')" 4
contains "$d" "error|tests/test_add.py|test_req_f_001_ac2_empty_title" && pass "pytest: error + file attribute" || bad "pytest: error ($d)"
contains "$d" "skip|-|test_AC_002_01_list" && pass "pytest: skipped, dotted classname is not a path" || bad "pytest: skip ($d)"
d=$(dialect rspec.xml)
contains "$d" "fail|spec/requests/tasks_spec.rb|Tasks AC-002-04" && pass "rspec: CDATA failure, ./ stripped from file" || bad "rspec ($d)"
d=$(dialect playwright.xml)
contains "$d" "pass|e2e/list.spec.ts|list › AC-002-01 — shows tasks in id order" && pass "playwright: unicode name, file from classname" || bad "playwright ($d)"
expect "playwright: 2 testcases" "$(printf '%s\n' "$d" | wc -l | tr -d ' ')" 2
d=$(dialect jest.xml); contains "$d" "pass|-|REQ-F-002 AC2 prints No tasks" && pass "jest-junit: parsed" || bad "jest ($d)"
d=$(dialect minitest.xml); contains "$d" "pass|test/controllers/tasks_controller_test.rb|test_AC-002-03" && pass "minitest-reporters: file from suite filepath" || bad "minitest ($d)"
d=$(dialect mocha.xml); contains "$d" "pass|test/rm.spec.js|AC-002-04" && pass "mocha-junit: file from suite" || bad "mocha ($d)"
keys=$(node --input-type=module -e '
import { testKeys } from "'"$ROOT"'/scripts/lib/acceptance.mjs";
const k = (s) => JSON.stringify(testKeys(s));
process.stdout.write([k("test_ac_001_01_adds"), k("AC-001-011 x"), k("test_req_nf_002_ac1_cov"), k("xAC-001-01")].join("\n"));')
contains "$keys" '{"scenarios":["AC-001-01"],"reqAcs":[]}' && pass "testKeys: underscore/lowercase scenario id" || bad "testKeys underscore ($keys)"
contains "$keys" '{"scenarios":["AC-001-011"],"reqAcs":[]}' && pass "testKeys: AC-001-011 is not AC-001-01" || bad "testKeys boundary ($keys)"
contains "$keys" '"reqAcs":[{"req":"REQ-NF-002","ac":1}]' && pass "testKeys: REQ_NF_002_AC1" || bad "testKeys req ($keys)"
contains "$keys" '{"scenarios":[],"reqAcs":[]}' && pass "testKeys: no match inside a word" || bad "testKeys word ($keys)"

# ---------------------------------------------------------------- 3. lint --needs
repo="$ROOT/examples/todo-app"
run lint --needs; expect "lint --needs on examples/todo-app exits 0" "$rc" 0
has "lint --needs summary" "0 error(s)"
run lint --needs --json; expect "lint --needs --json exits 0" "$rc" 0
expect "lint --needs --json: 6 needs" "$(js 'j.needs')" 6
mkdir -p "$tmp/needs/requirements"
cp "$ROOT/examples/todo-app/requirements/"*.md "$tmp/needs/requirements/"
sed -i.bak 's/^- \*\*Needs:\*\* N-001$/- **Needs:** N-099/' "$tmp/needs/requirements/REQUIREMENTS.md"
repo="$tmp/needs"
run lint --needs; expect "lint --needs: unknown need → exit 1" "$rc" 1
has "lint --needs: names the unknown need" "REQ-F-001 cites N-099"

# ---------------------------------------------------------------- 4. ledger: every verdict
repo="$tmp/todo"
cp -R "$FIX/todo" "$repo"
git init -q "$repo"
commit "init"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=fail" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass" "AC-009-01 unknown scenario=pass" "REQ-F-006 AC1 columns=pass"
run accept --report acceptance/ACCEPTANCE-REPORT.md
expect "accept exits 0" "$rc" 0
[ -f "$repo/.sdd/acceptance.json" ] && pass "writes .sdd/acceptance.json" || bad "no .sdd/acceptance.json"
expect "schema" "$(ledger 'L.$schema')" "sdd-acceptance-v1"
expect "evaluated_sha = HEAD" "$(ledger 'L.evaluated_sha')" "$(cd "$repo" && git rev-parse HEAD)"
expect "dirty false" "$(ledger 'L.dirty')" false
expect "F-001 VERIFIED (both criteria bound by scenario id)" "$(ledger 'v("REQ-F-001")')" VERIFIED
expect "F-001 2/2" "$(ledger 'R("REQ-F-001").criteria_passing + "/" + R("REQ-F-001").criteria_total')" 2/2
expect "F-002 FAILING (AC-002-02 fails)" "$(ledger 'v("REQ-F-002")')" FAILING
expect "F-003 VERIFIED (pytest-style underscore name)" "$(ledger 'v("REQ-F-003")')" VERIFIED
expect "F-004 DEPRECATED" "$(ledger 'v("REQ-F-004")')" DEPRECATED
expect "F-005 MISSING (AC2 has no scenario)" "$(ledger 'v("REQ-F-005")')" MISSING
expect "F-005 1/2" "$(ledger 'R("REQ-F-005").criteria_passing + "/" + R("REQ-F-005").criteria_total')" 1/2
expect "F-006 demo: a passing test is not demo evidence" "$(ledger 'v("REQ-F-006")')" MISSING
expect "NF-002 MISSING without a measurement" "$(ledger 'v("REQ-NF-002")')" MISSING
expect "C-001 without priority counts as Must" "$(ledger 'R("REQ-C-001").priority')" Must
expect "unknown scenario reported" "$(ledger 'L.unknown_scenarios.join()')" AC-009-01
expect "summary: goal not met" "$(ledger 'L.summary.goal')" false
expect "summary: Must total 6" "$(ledger 'L.summary.must_total')" 6
expect "summary: deprecated 1" "$(ledger 'L.summary.deprecated')" 1
rows=$(grep -c '^| REQ-' "$repo/acceptance/ACCEPTANCE-REPORT.md" || true)
active=$(ledger 'L.summary.active')
deprows=$(sed -n '/^## Deprecated/,/^## /p' "$repo/acceptance/ACCEPTANCE-REPORT.md" | grep -c '^| REQ-' || true)
expect "report: one Requirements row per active requirement" "$((rows - deprows))" "$active"
expect "report: deprecated listed apart" "$deprows" 1
grep -q "^> Evaluated at \`$(cd "$repo" && git rev-parse HEAD | cut -c1-12)\`" "$repo/acceptance/ACCEPTANCE-REPORT.md" && pass "report header carries evaluated_sha" || bad "report header sha"
run gate; expect "gate: goal not met → 1" "$rc" 1
run gate --mode warn; expect "gate --mode warn → 0" "$rc" 0; has "warn prints the would-be code" "would exit 1"
run gate --mode off; expect "gate --mode off → 0" "$rc" 0; expect "gate --mode off is silent" "$out" ""
run gate --mode bogus; expect "gate bad mode → 2" "$rc" 2

# ---------------------------------------------------------------- 5. --fase scoping
run gate --fase 1 --json; expect "gate --fase 1 → 1 (F-002 failing)" "$rc" 1
expect "fase scope from the header only" "$(js 'j.scope.requirements.join()')" "REQ-F-001,REQ-F-002"
expect "fase scope: 2 requirements in the gate" "$(js 'j.requirements.length')" 2
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass" "REQ-F-006 AC1 columns=pass"
run gate --fase 1; expect "gate --fase 1 → 0 once F-002 passes" "$rc" 0
run gate --fase 1 --md; has "--md: PR block" "### Acceptance — FASE 1"; has "--md: Refs line" "Refs: REQ-F-001, REQ-F-002"; if contains "$out" "Closes #<issue>"; then bad "--md: no Closes placeholder"; else pass "--md: no Closes placeholder"; fi
run accept --fase 1 --report acceptance/F1.md --no-out
expect "report --fase 1: 2 rows" "$(grep -c '^| REQ-' "$repo/acceptance/F1.md")" 2

# ---------------------------------------------------------------- 6. decisions: measurement, demo, inspection, waiver
run accept record measurement --req REQ-NF-002 --metric statements --observed 92.5 --op ge --threshold 90 --paths src --by "Ana" --role "tech lead"
expect "record measurement exits 0" "$rc" 0
has "record prints the line" "acceptance/decisions.jsonl:1"
run accept record measurement --req REQ-NF-001 --metric p95_ms --observed 250 --op lt --threshold 200 --paths src --by Ana --role "tech lead"
expect "record measurement (failing value) exits 0" "$rc" 0
# A hand-written `pass: true` is ignored: the comparison is done in code.
node -e 'const f=process.argv[1];const fs=require("fs");const l=fs.readFileSync(f,"utf8").trim().split("\n");const r=JSON.parse(l[1]);r.pass=true;l[1]=JSON.stringify(r);fs.writeFileSync(f,l.join("\n")+"\n")' "$repo/acceptance/decisions.jsonl"
run accept record demo --req REQ-F-006 --ac 1 --observed "columns aligned on 5 tasks" --pass true --by "Laura" --role "product owner"
expect "record demo exits 0" "$rc" 0
run accept record inspection --req REQ-C-001 --note "package.json has no dependencies" --paths package.json --by Ana --role "tech lead"
expect "record inspection exits 0" "$rc" 0
run accept record demo --req REQ-F-006 --observed x --by Laura --role po
expect "record demo without --pass → 2" "$rc" 2
run accept record measurement --req REQ-F-001 --metric m --observed 1 --op lt --threshold 2 --by a --role b
expect "record measurement on a test requirement → 2" "$rc" 2; has "method mismatch explained" "verified by test"
run accept record inspection --req REQ-C-001 --note x --role b
expect "record without --by → 2" "$rc" 2
run accept record waiver --req REQ-X-999 --reason r --by a --role b
expect "record on an unknown requirement → 2" "$rc" 2
run accept record waiver --req REQ-F-005 --reason "customer defers delete" --by Laura --role "product owner"
expect "Must waiver without --follow-up → 2" "$rc" 2; has "follow-up required for a Must" "needs --follow-up"
run accept record waiver --req REQ-F-005 --reason "customer defers delete" --by Laura --role "product owner" --follow-up nope
expect "waiver with a non-issue follow-up → 2" "$rc" 2
run accept record waiver --req REQ-F-005 --reason "customer defers delete" --by Laura --role "product owner" --follow-up "#42"
expect "Must waiver with follow-up exits 0" "$rc" 0
expect "decisions.jsonl has 5 lines" "$(wc -l < "$repo/acceptance/decisions.jsonl" | tr -d ' ')" 5
expect "records carry head" "$(head -1 "$repo/acceptance/decisions.jsonl" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(String(JSON.parse(s).head)))')" "$(cd "$repo" && git rev-parse HEAD)"
grep -q '"reqHash":"sha256:' "$repo/acceptance/decisions.jsonl" && pass "records carry reqHash" || bad "no reqHash"
commit "acceptance decisions"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass"
run accept
expect "NF-002 VERIFIED: 92.5 ge 90 computed" "$(ledger 'v("REQ-NF-002")')" VERIFIED
expect "NF-001 FAILING: 250 lt 200 is false, hand-written pass ignored" "$(ledger 'v("REQ-NF-001")')" FAILING
expect "F-006 VERIFIED by demo" "$(ledger 'v("REQ-F-006")')" VERIFIED
expect "C-001 VERIFIED by inspection" "$(ledger 'v("REQ-C-001")')" VERIFIED
expect "F-005 WAIVED" "$(ledger 'v("REQ-F-005")')" WAIVED
expect "junit still fresh after a commit that only touched acceptance/**" "$(ledger 'L.junit[0].fresh')" true
expect "goal met with waivers" "$(ledger 'L.summary.goal + "/" + L.summary.waived_musts.join()')" "true/REQ-F-005"
run gate; expect "gate: goal met with a waived Must → 3" "$rc" 3
has "gate names the waived Must" "REQ-F-005"
run accept --report acceptance/ACCEPTANCE-REPORT.md --no-out
sed -n '/^## Waived Must/,/^## Requirements/p' "$repo/acceptance/ACCEPTANCE-REPORT.md" | grep -q '^| REQ-F-005 .*#42' && pass "report: waived Musts first, with follow-up" || bad "report waived section"

# ---------------------------------------------------------------- 7. freshness: inspection by paths, stale JUnit, MODIFY
printf '# notes\n' > "$repo/NOTES.md"; commit "docs: notes"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass"
run accept
expect "inspection with paths survives a change elsewhere" "$(ledger 'v("REQ-C-001")')" VERIFIED
expect "measurement with paths survives a change elsewhere" "$(ledger 'v("REQ-NF-002")')" VERIFIED
expect "demo without paths survives a docs commit (outside code_paths/test_paths)" "$(ledger 'v("REQ-F-006")')" VERIFIED
# F12: only the Stack Profile's code_paths + test_paths (default src, tests) make evidence stale.
sha_cap=$(cd "$repo" && git rev-parse HEAD)
touch -t "2026010100$(printf %02d "$n").30" "$repo/.sdd/junit/unit.xml"   # captured after the last commit
mkdir -p "$repo/feedback"; printf '# FASE-1 feedback\n' > "$repo/feedback/IMPL-FEEDBACK-FASE-1.md"; commit "docs(feedback): FASE-1"
run accept
expect "JUnit captured before a feedback/ commit stays fresh (mtime rule)" "$(ledger 'L.junit[0].fresh')" true
expect "demo without paths stays fresh after a feedback/ commit" "$(ledger 'v("REQ-F-006")')" VERIFIED
run accept --junit-sha "$sha_cap" --json --no-out
expect "--junit-sha before a docs-only commit stays fresh" "$(js 'j.junit[0].fresh')" true
printf '# docs\n' > "$repo/NOTES.md"
run accept --json --no-out
expect "an uncommitted docs change does not make JUnit stale" "$(js 'j.junit[0].fresh + "/" + j.dirty')" true/true
( cd "$repo" && git checkout -q -- NOTES.md )
printf 'export const add = (t) => t.toUpperCase();\n' > "$repo/src/api.js"
run accept --json --no-out
expect "an uncommitted src/ change makes JUnit stale" "$(js 'j.junit[0].fresh')" false
expect "an uncommitted src/ change makes a demo without paths stale" "$(js 'j.requirements.find(r=>r.id==="REQ-F-006").verdict')" MISSING
( cd "$repo" && git checkout -q -- src/api.js )
printf '{\n  "name": "todo",\n  "private": true,\n  "dependencies": { "left-pad": "1.0.0" }\n}\n' > "$repo/package.json"; commit "chore: add dep"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass"
run accept
expect "inspection stale after its path changed" "$(ledger 'v("REQ-C-001")')" MISSING
expect "stale inspection listed to re-confirm" "$(ledger 'L.stale_decisions.some((d)=>d.type==="inspection"&&d.req==="REQ-C-001")')" true
run accept record inspection --req REQ-C-001 --note "left-pad removed again? no: accepted" --paths package.json --by Ana --role "tech lead"
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --paths src --by Laura --role "product owner"
commit "re-inspect"
touch -t 202001010000 "$repo/.sdd/junit/unit.xml"
run accept
expect "JUnit older than the last code commit is stale" "$(ledger 'L.junit[0].fresh')" false
expect "stale test evidence → MISSING, flagged" "$(ledger 'v("REQ-F-001") + "/" + R("REQ-F-001").stale_evidence')" MISSING/true
run gate; expect "gate: stale evidence → 2" "$rc" 2
has "gate explains stale evidence" "stale evidence"
run gate --junit-sha HEAD; expect "--junit-sha HEAD asserts the report matches HEAD → 3" "$rc" 3
run gate --junit-sha HEAD~1; expect "--junit-sha of a commit that differs only in acceptance/** → 3" "$rc" 3
run gate --junit-sha HEAD~2; expect "--junit-sha of a commit that differs only outside src/tests (package.json) → 3" "$rc" 3
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass"
printf 'export const add = (t) => t.trim();\n' > "$repo/src/api.js"
run accept
expect "uncommitted tracked change: ledger dirty" "$(ledger 'L.dirty')" true
expect "uncommitted tracked change: JUnit stale" "$(ledger 'L.junit[0].fresh')" false
expect "uncommitted change under a measurement path: stale" "$(ledger 'v("REQ-NF-002")')" MISSING
( cd "$repo" && git checkout -q -- src/api.js )
# MODIFY: the Must waiver of F-005 is tied to the old text.
sed -i.bak 's/remove the task without renumbering/remove the task permanently without renumbering/' "$repo/requirements/REQUIREMENTS.md"; rm -f "$repo/requirements/REQUIREMENTS.md.bak"
commit "docs(specs): modify REQ-F-005"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass"
run accept --report acceptance/ACCEPTANCE-REPORT.md
expect "MODIFY voids the waiver: F-005 back to MISSING" "$(ledger 'v("REQ-F-005")')" MISSING
expect "voided waiver listed to re-confirm" "$(ledger 'L.stale_decisions.some((d)=>d.type==="waiver"&&/text changed/.test(d.reason))')" true
grep -q 'waiver | REQ-F-005 | requirement text changed' "$repo/acceptance/ACCEPTANCE-REPORT.md" && pass "report lists the voided waiver" || bad "report stale decisions"
run gate; expect "gate after MODIFY → 1" "$rc" 1
run gate --ledger .sdd/acceptance.json; expect "gate --ledger fresh ledger → 1" "$rc" 1
printf 'export const add = (t) => String(t);\n' > "$repo/src/api.js"; commit "fix: api"
run gate --ledger .sdd/acceptance.json; expect "gate --ledger on a ledger older than the code → 2" "$rc" 2
touch -t "2026010100$(printf %02d $((n - 1))).30" "$repo/.sdd/junit/unit.xml"   # captured before the src/ commit
run accept --json --no-out
expect "a src/ commit after the capture makes JUnit stale (mtime rule)" "$(js 'j.junit[0].fresh')" false
run gate --junit-sha HEAD~1; expect "--junit-sha before a src/ commit → 2" "$rc" 2

# ---------------------------------------------------------------- 8. fase acceptance
run accept record fase-acceptance --fase 1 --result accepted --channel "demo meeting 2026-09-27" --by Laura --role "product owner" --demo DEMO-1
expect "record fase-acceptance exits 0" "$rc" 0
grep -q '"reqHashes":{"REQ-F-001":"sha256:[0-9a-f]*","REQ-F-002":"sha256:' "$repo/acceptance/decisions.jsonl" && pass "fase-acceptance stores the hashes of its scope" || bad "fase-acceptance reqHashes"
run accept record fase-acceptance --fase 1 --result maybe --channel x --by a --role b
expect "fase-acceptance bad --result → 2" "$rc" 2
run accept
expect "fase acceptance current" "$(ledger 'L.fase_acceptances[0].stale')" false
sed -i.bak 's/print every task ordered by id/print every task ordered by id ascending/' "$repo/requirements/REQUIREMENTS.md"; rm -f "$repo/requirements/REQUIREMENTS.md.bak"
run accept
expect "MODIFY of a FASE requirement reopens the FASE acceptance" "$(ledger 'L.fase_acceptances[0].stale + "/" + L.fase_acceptances[0].changed.join()')" true/REQ-F-002
( cd "$repo" && git checkout -q -- requirements/REQUIREMENTS.md )

# ---------------------------------------------------------------- 9. loop next
loopq() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
L="--state .sdd/loop-a.json"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=fail" "AC-002-01 order=pass"
run loop next $L
expect "loop cycle 1 exits 0" "$rc" 0
expect "loop: cycle 1 baseline, no stop" "$(loopq 'j.cycle + "/" + j.stop')" 1/null
expect "loop: FAILING → fix-code" "$(loopq 'j.targets.find(t=>t.req==="REQ-F-001").route_hint')" "fix-code (Art. 12)"
expect "loop: MISSING with a scenario but no test → implement-or-test" "$(loopq 'j.targets.find(t=>t.req==="REQ-F-002").route_hint')" implement-or-test
expect "loop: criterion without scenario → spec-gap" "$(loopq 'j.targets.find(t=>t.req==="REQ-F-005").criteria.find(c=>c.n===2).route_hint')" "spec-gap (human, req-change)"
expect "loop: missing demo/measurement/inspection → needs-human" "$(loopq 'j.targets.find(t=>t.req==="REQ-F-006").route_hint')" needs-human
expect "loop: Should listed apart" "$(loopq 'j.others.map(t=>t.req).join()')" "REQ-F-003,REQ-NF-001"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=fail" "AC-002-01 order=pass"
run loop next $L
expect "loop: same state → no-progress" "$(loopq 'j.cycle + "/" + j.stop')" 2/no-progress
L="--state .sdd/loop-b.json"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass"
run loop next $L; expect "loop b1: no stop" "$(loopq 'j.stop')" null
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=fail" "AC-002-01 order=pass" "AC-002-02 empty list=pass" "AC-002-04 rm keeps ids=pass"
run loop next $L
expect "loop: a VERIFIED Must now FAILING → regression" "$(loopq 'j.stop + "/" + j.regressed.join()')" regression/REQ-F-001
L="--state .sdd/loop-c.json --max-cycles 1"
junit .sdd/junit/unit.xml "AC-001-01 adds=pass"
run loop next $L; expect "loop c1: no stop" "$(loopq 'j.stop')" null
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass"
run loop next $L; expect "loop: progress but past --max-cycles 1 → max-cycles" "$(loopq 'j.cycle + "/" + j.stop')" 2/max-cycles
run loop next --state .sdd/loop-d.json --max-cycles 9
expect "loop: --max-cycles capped at 5" "$(loopq 'j.max_cycles')" 5
# needs-human: every open Must needs a person (the tests all pass; demo, inspection records missing after a re-record).
all_green() { junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass" \
  "test_ac_002_03_filter=pass" "AC-002-04 rm keeps ids=pass" "REQ-F-005 AC2 rm unknown=pass"; }
all_green
run loop next --state .sdd/loop-e.json
expect "loop: only demo/measurement/inspection left → needs-human" "$(loopq 'j.stop + "/" + j.targets.map(t=>t.req).join()')" "needs-human/REQ-F-006,REQ-NF-002"
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --paths src --by Laura --role "product owner"
run accept record measurement --req REQ-NF-002 --metric statements --observed 95 --op ge --threshold 90 --paths src --by Ana --role "tech lead"
commit "record"
all_green
run loop next --state .sdd/loop-e.json
expect "loop: goal" "$(loopq 'j.cycle + "/" + j.stop')" 2/goal
run gate; expect "gate: all Musts verified (F-005 AC2 via REQ ACn test name) → 0" "$rc" 0

# ---------------------------------------------------------------- 10. JUnit inputs: directory, glob, errors
run accept --junit .sdd/junit --json --no-out; expect "--junit DIR" "$(js 'j.junit.length')" 1
run accept --junit '.sdd/junit/*.xml' --json --no-out; expect "--junit glob" "$(js 'j.junit.length')" 1
run accept --junit nope.xml; expect "--junit missing file → 2" "$rc" 2
cp "$FIX/junit/rspec.xml" "$repo/.sdd/junit/"
run accept --json --no-out
expect "default .sdd/junit/ reads every report" "$(js 'j.junit.length')" 2
expect "rspec failure of AC-002-04 makes F-005 FAILING" "$(js 'j.requirements.find(r=>r.id==="REQ-F-005").verdict')" FAILING
rm -f "$repo/.sdd/junit/rspec.xml"
run accept bogus; expect "accept unexpected argument → 2" "$rc" 2
run accept record nope; expect "accept record unknown type → 2" "$rc" 2
run loop; expect "loop without next → 2" "$rc" 2

# ---------------------------------------------------------------- 11. machine measurements: accept measure, --remeasure
dlines() { wc -l < "$repo/acceptance/decisions.jsonl" | tr -d ' '; }
lastrec() { tail -1 "$repo/acceptance/decisions.jsonl" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
printf 'Statements   : 93.4%% ( 120/128 )\n' > "$repo/cov.txt"   # untracked: stands in for a coverage run
M=(--req REQ-NF-002 --metric statements --command "cat cov.txt" --extract 'Statements\s*:\s*([0-9.]+)%' --op ge --threshold 90)
run accept measure "${M[@]}"
expect "accept measure exits 0" "$rc" 0
has "accept measure prints value and verdict" "statements = 93.4 (ge 90: pass)"
expect "measure record: by command, role automated" "$(lastrec 'r.by + "/" + r.role')" command/automated
expect "measure record: observed extracted, command and regex stored" "$(lastrec 'r.observed + "|" + r.command + "|" + r.extract')" '93.4|cat cov.txt|Statements\s*:\s*([0-9.]+)%'
expect "measure record carries reqHash" "$(lastrec '/^sha256:/.test(r.reqHash)')" true
expect "measure record head = HEAD" "$(lastrec 'r.head')" "$(cd "$repo" && git rev-parse HEAD)"
before=$(dlines)
run accept measure --req REQ-NF-002 --metric statements --command "echo no coverage here" --extract 'Statements\s*:\s*([0-9.]+)%' --op ge --threshold 90
expect "measure: no number matched → 1" "$rc" 1
has "measure: says nothing matched" "no number matched"
run accept measure --req REQ-NF-002 --metric statements --command "cat cov.txt" --extract 'Statements [0-9.]+' --op ge --threshold 90
expect "measure: regex without a capture group → 2" "$rc" 2
run accept measure "${M[@]}" --by Ana --role "tech lead"
expect "measure: --by is refused (use accept record measurement) → 2" "$rc" 2
run accept measure --req REQ-F-001 --metric m --command "cat cov.txt" --extract 'Statements\s*:\s*([0-9.]+)%' --op ge --threshold 90
expect "measure on a test requirement → 2" "$rc" 2
expect "failed measures append nothing" "$(dlines)" "$before"
commit "docs(acceptance): machine measurement"
all_green
run accept
expect "NF-002 VERIFIED by the machine measurement" "$(ledger 'v("REQ-NF-002")')" VERIFIED
printf 'export const add = (t) => t.trim().toLowerCase();\n' > "$repo/src/api.js"; commit "feat: lowercase"
all_green
printf 'Statements   : 95.1%% ( 122/128 )\n' > "$repo/cov.txt"
before=$(dlines)
run accept
expect "src/ commit makes the machine measurement stale → MISSING" "$(ledger 'v("REQ-NF-002") + "/" + R("REQ-NF-002").stale_evidence')" MISSING/true
expect "accept without --remeasure appends nothing" "$(dlines)" "$before"
run loop next --state .sdd/loop-f.json --reset
expect "loop: stale measurement with a command → remeasure" "$(loopq 'j.targets.find(t=>t.req==="REQ-NF-002").route_hint')" remeasure
run accept --remeasure
expect "accept --remeasure exits 0" "$rc" 0
has "--remeasure reports the new value" "remeasured REQ-NF-002 statements = 95.1 (was 93.4)"
expect "--remeasure appends one record" "$(dlines)" "$((before + 1))"
expect "NF-002 VERIFIED again after --remeasure" "$(ledger 'v("REQ-NF-002")')" VERIFIED
expect "re-measured record keeps the command" "$(lastrec 'r.by + "/" + r.command')" "command/cat cov.txt"
# A human measurement (no command) is never re-run: it stays MISSING and needs a person.
run accept record measurement --req REQ-NF-002 --metric statements --observed 91 --op ge --threshold 90 --by Ana --role "tech lead"
commit "record human measurement"
printf 'export const add = (t) => t.trim();\n' > "$repo/src/api.js"; commit "fix: keep case"
all_green
before=$(dlines)
run accept --remeasure
expect "stale human measurement: --remeasure leaves it MISSING" "$(ledger 'v("REQ-NF-002")')" MISSING
expect "stale human measurement: nothing appended" "$(dlines)" "$before"
run loop next --state .sdd/loop-g.json --reset
expect "loop: stale measurement without a command → needs-human" "$(loopq 'j.targets.find(t=>t.req==="REQ-NF-002").route_hint')" needs-human
rm -f "$repo/cov.txt"

# ---------------------------------------------------------------- 12. evidence cell summarised (F16)
# 40 passing tests with long names on one criterion and 7 failing on another: the PR block shows counts, at most 2
# passing names (clipped to 80 chars) and up to 5 failing names; the full list stays in .sdd/acceptance.json.
md=$(node --input-type=module -e '
import { renderPrBlock, renderReport, summarize } from "'"$ROOT"'/scripts/lib/acceptance.mjs";
const long = (i) => `AC-001-01 test number ${i} ` + "x".repeat(120);
const t = (i, status) => ({ kind: "test", ref: "tests/a.test.ts", name: long(i), status, fresh: true });
const pass = Array.from({ length: 40 }, (_, i) => t(i, "pass"));
const fail = [...Array.from({ length: 7 }, (_, i) => t(100 + i, "fail")), t(200, "pass")];
const req = (id, crit) => ({ id, title: id, priority: "Must", needs: [], verification: "test", in_scope: true, stale_evidence: false,
  verdict: crit.some((c) => c.state === "fail") ? "FAILING" : "VERIFIED", criteria: crit,
  criteria_total: crit.length, criteria_passing: crit.filter((c) => c.state === "pass").length });
const reqs = [req("REQ-F-001", [{ n: 1, state: "pass", evidence: pass }]), req("REQ-F-002", [{ n: 1, state: "pass", evidence: pass.slice(0, 1) }, { n: 2, state: "fail", evidence: fail }])];
const L = { requirements: reqs, summary: summarize(reqs), evaluated_sha: "abcdef1234567", generatedAt: "2026-09-27T00:00:00Z",
  scope: null, dirty: false, stale_decisions: [], fase_acceptances: [] };
process.stdout.write(renderPrBlock(L, 1) + "\n@@REPORT@@\n" + renderReport(L));')
contains "$md" "AC1: 40 tests pass — " && pass "evidence: passing count per criterion" || bad "evidence: passing count"
contains "$md" "+38 more" && pass "evidence: at most 2 passing names, +m more" || bad "evidence: +m more"
contains "$md" "…\"" && pass "evidence: long names clipped" || bad "evidence: clipped names"
contains "$md" "AC2: 7 of 8 tests fail — " && pass "evidence: failing count" || bad "evidence: failing count"
expect "evidence: 5 failing names listed" "$(printf '%s' "$md" | sed -n '/^| REQ-F-002/p' | head -1 | grep -o '(fail)' | wc -l | tr -d ' ')" 5
contains "$md" "(fail) +2 more" && pass "evidence: failing beyond 5 counted" || bad "evidence: failing +2 more"
contains "$md" "AC1: 1 test pass — " && pass "evidence: singular" || bad "evidence: singular"
size=$(printf '%s' "$md" | sed '/@@REPORT@@/q' | wc -c | tr -d ' ')
[ "$size" -lt 2500 ] && pass "PR block stays small with 48 bound tests ($size bytes)" || bad "PR block size $size"

[ "$fail" -eq 0 ] && echo "tests/acceptance: all passed" || echo "tests/acceptance: FAILURES"
exit "$fail"
