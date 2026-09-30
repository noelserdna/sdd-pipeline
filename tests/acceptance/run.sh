#!/usr/bin/env bash
# Tests of the acceptance ledger (scripts/sdd.mjs accept | accept record | gate | loop next | lint --needs) and the
# JUnit reader (scripts/lib/junit.mjs), without a model or network. Fixture project: tests/fixtures/acceptance/todo,
# copied into a temporary git repo; JUnit dialect samples: tests/fixtures/acceptance/junit.
# Covers the verdicts (VERIFIED, FAILING, MISSING, WAIVED, DEPRECATED), NF/C methods (measurement computed in code,
# demo, inspection freshness by paths), waivers voided by a MODIFY, gate exit codes 0/1/2/3 and modes, stale JUnit,
# report rows, --fase scoping, loop stops, JUnit dialects, freshness scoped to code_paths/test_paths (a docs or
# feedback commit keeps evidence fresh), machine measurements (accept measure, accept --remeasure), summarised evidence
# cells, untracked files under the code paths, commit before evidence (--junit-sha, --allow-dirty), attachments
# (JUnit [[ATTACHMENT|…]], record --attach, name-bound captures), the visual rule (required, warn, off; video per
# FASE), accept pack, req show and the adversarial round (challenges, gate exit 4, loop targets, adversarial plan).
# The fixture is a CLI app with `visual_evidence: off` in its CLAUDE.md; section 16
# removes it. bash 3.2 (macOS) and bash 5 (Ubuntu CI); needs git, node ≥ 18.
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
# runo ARGS… → like run, but $out holds stdout only and $err stderr (JSON output next to a stderr warning)
runo() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>"$tmp/stderr") || rc=$?; err=$(cat "$tmp/stderr"); }
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
has "--help documents accept pack" "sdd accept pack --fase N"
has "--help documents req show" "sdd req show <REQ-ID> [--ac N]"
has "--help documents --attach and --allow-dirty" "[--attach FILE...] [--allow-dirty]"
has "--help documents the visual rule" "visual_evidence: required|warn|off"
has "--help documents capture-evidence" "route_hint capture-evidence"

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
att=$(node --input-type=module -e '
import { parseJUnit } from "'"$ROOT"'/scripts/lib/junit.mjs";
import { readFileSync } from "node:fs";
const all = (f) => parseJUnit(readFileSync("'"$FIX"'/junit/" + f, "utf8")).map((x) => x.attachments.join("+")).join("|");
process.stdout.write(all("playwright.xml") + "\n" + ["vitest.xml", "pytest.xml", "rspec.xml"].map(all).join("").replace(/\|/g, ""));')
expect "playwright: attachments from <property name=attachment> and [[ATTACHMENT|…]] in <system-out>" "$(printf '%s\n' "$att" | head -1)" "screenshots/list-AC-002-01.png|list-AC-002-02/trace.zip"
expect "other dialects: no attachments invented" "$(printf '%s\n' "$att" | sed -n 2p)" ""
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
runo accept --json --no-out
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

# ---------------------------------------------------------------- 9b. loop without spec/ (route skipped the specifications)
# No spec/tests: the requirement criteria are the contract, so a criterion with neither scenario nor test is work for
# the implementer (a test named `REQ-X-NNN ACn`), not a spec gap. With spec/tests (section 9) it stays spec-gap.
saved_repo="$repo"
repo="$tmp/nospec"
cp -R "$FIX/todo" "$repo"; rm -rf "$repo/spec"
git init -q "$repo"
commit "init without spec"
junit .sdd/junit/unit.xml "REQ-F-001 AC1 adds=pass" "REQ-F-005 AC1 rm keeps ids=pass"
run loop next --state .sdd/loop-nospec.json
expect "no spec/: loop exits 0" "$rc" 0
expect "no spec/: criterion without test → implement-or-test" "$(loopq 'j.targets.find(t=>t.req==="REQ-F-005").criteria.find(c=>c.n===2).route_hint')" implement-or-test
expect "no spec/: requirement route → implement-or-test" "$(loopq 'j.targets.find(t=>t.req==="REQ-F-005").route_hint')" implement-or-test
expect "no spec/: open test criteria are not needs-human" "$(loopq 'j.stop')" null
run accept --json --no-out
expect "no spec/: ledger says spec_tests false" "$(js 'j.spec_tests')" false
expect "no spec/: REQ ACn test binds (F-005 AC1 passes)" "$(js 'j.requirements.find(r=>r.id==="REQ-F-005").criteria.find(c=>c.n===1).state')" pass
repo="$saved_repo"

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

# ---------------------------------------------------------------- 13. untracked files under the code paths (bug 1)
# A new file under src/ that nobody added does not exist at evaluated_sha: the evidence would describe another tree.
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --paths src --by Laura --role "product owner"
commit "record demo again"
all_green
run accept --json --no-out
expect "baseline: clean tree, F-001 and F-006 VERIFIED, no untracked paths" "$(js '["REQ-F-001","REQ-F-006"].map(id=>j.requirements.find(r=>r.id===id).verdict).join() + "/" + j.untracked_paths.length')" VERIFIED,VERIFIED/0
printf 'export const helper = 1;\n' > "$repo/src/helper.js"
runo accept --json --no-out
expect "untracked file under src/: JUnit stale" "$(js 'j.junit[0].fresh')" false
expect "untracked file under src/: listed in untracked_paths" "$(js 'j.untracked_paths.join()')" src/helper.js
expect "untracked file under src/: ledger dirty" "$(js 'j.dirty')" true
expect "untracked file under src/: F-001 MISSING with stale evidence" "$(js 'const r=j.requirements.find(r=>r.id==="REQ-F-001"); r.verdict + "/" + r.stale_evidence')" MISSING/true
expect "untracked file under a demo record's paths: F-006 stale" "$(js 'j.requirements.find(r=>r.id==="REQ-F-006").verdict')" MISSING
contains "$(js 'j.junit[0].stale_reason')" "src/helper.js" && pass "stale reason names the untracked file" || bad "stale reason ($(js 'j.junit[0].stale_reason'))"
rm -f "$repo/src/helper.js"
printf 'scratch\n' > "$repo/scratch.txt"
all_green
run accept --json --no-out
expect "untracked file outside the code paths: JUnit fresh, not listed" "$(js 'j.junit[0].fresh + "/" + j.untracked_paths.length')" true/0
rm -f "$repo/scratch.txt"

# ---------------------------------------------------------------- 14. commit before evidence (M7.1, bug 3)
# Evidence and human observations are anchored to a commit: on uncommitted code they would be stale from birth.
printf 'export const add = (t) => t;\n' > "$repo/src/api.js"
run accept --junit-sha HEAD --no-out
expect "--junit-sha with uncommitted code → 2" "$rc" 2; has "--junit-sha: says commit first" "commit first"
run gate --junit-sha HEAD
expect "gate --junit-sha with uncommitted code → 2" "$rc" 2
runo accept --no-out --json
expect "accept without --junit-sha on uncommitted code still exits 0" "$rc" 0
contains "$err" "warning: uncommitted changes under the code paths (src/api.js)" && pass "…with a warning: line on stderr" || bad "dirty warning ($err)"
expect "…and stdout stays JSON" "$(js 'j.$schema')" sdd-acceptance-v1
before=$(dlines)
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --by Laura --role "product owner"
expect "record demo on uncommitted code → 2" "$rc" 2; has "record: names the path and says commit first" "uncommitted changes in src/api.js: commit first"
run accept record inspection --req REQ-C-001 --note ok --by Ana --role "tech lead"
expect "record inspection without paths on uncommitted code → 2" "$rc" 2
run accept record measurement --req REQ-NF-002 --metric statements --observed 95 --op ge --threshold 90 --by Ana --role "tech lead"
expect "record measurement on uncommitted code → 2" "$rc" 2
run accept record fase-acceptance --fase 1 --result accepted --channel call --by Laura --role "product owner"
expect "record fase-acceptance on uncommitted code → 2" "$rc" 2
printf 'Statements   : 93.4%% ( 120/128 )\n' > "$repo/cov.txt"
run accept measure "${M[@]}"
expect "accept measure on uncommitted code → 2" "$rc" 2; has "measure: says commit first" "commit first"
expect "refused records append nothing" "$(dlines)" "$before"
run accept record waiver --req REQ-F-005 --reason "customer defers delete" --by Laura --role "product owner" --follow-up "#42"
expect "a waiver is exempt (observes nothing) → 0" "$rc" 0
expect "…and carries no dirty flag" "$(lastrec 'r.dirty === undefined')" true
run accept record inspection --req REQ-C-001 --note "no deps" --paths package.json --by Ana --role "tech lead"
expect "a record whose own paths are clean is accepted → 0" "$rc" 0
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --by Laura --role "product owner" --allow-dirty
expect "record demo --allow-dirty → 0" "$rc" 0
expect "…recorded with dirty: true" "$(lastrec 'r.dirty')" true
run accept measure "${M[@]}" --allow-dirty
expect "accept measure --allow-dirty → 0" "$rc" 0
expect "…recorded with dirty: true" "$(lastrec 'r.dirty')" true
( cd "$repo" && git checkout -q -- src/api.js )
printf 'export const extra = 1;\n' > "$repo/src/extra.js"
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --by Laura --role "product owner"
expect "an untracked file under src/ also refuses a record → 2" "$rc" 2
rm -f "$repo/src/extra.js" "$repo/cov.txt"
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --by Laura --role "product owner"
expect "clean tree: record demo → 0, no dirty flag" "$rc/$(lastrec 'r.dirty === undefined')" 0/true
( cd "$repo" && git checkout -q -- acceptance/decisions.jsonl )

# ---------------------------------------------------------------- 15. attachments: JUnit [[ATTACHMENT|…]] and record --attach
mkdir -p "$repo/evidencias/FASE-1"
printf 'png-bytes-1' > "$repo/evidencias/FASE-1/AC-001-01.png"
printf 'webm' > "$repo/evidencias/FASE-1/FASE-1.webm"
# Paths relative to the report's directory (Playwright) or to the repo root; a missing file is kept, not present.
cat > "$repo/.sdd/junit/e2e.xml" <<'XML'
<testsuites><testsuite name="e2e/add.spec.ts">
<testcase classname="e2e/add.spec.ts" name="add › AC-001-01 adds a task"><system-out><![CDATA[[[ATTACHMENT|../../evidencias/FASE-1/AC-001-01.png]]
[[ATTACHMENT|evidencias/FASE-1/FASE-1.webm]]
[[ATTACHMENT|test-results/add/trace.zip]]
]]></system-out></testcase>
</testsuite></testsuites>
XML
all_green
run accept --json --no-out
A='j.requirements.find(r=>r.id==="REQ-F-001").criteria[0].evidence.find(e=>/adds a task/.test(e.name)).attachments'
expect "test evidence carries its attachments with kind" "$(js "$A.map(a=>a.kind).join()")" image,video,trace
expect "attachment paths relative to the repo root" "$(js "$A.map(a=>a.path).join()")" "evidencias/FASE-1/AC-001-01.png,evidencias/FASE-1/FASE-1.webm,test-results/add/trace.zip"
expect "present: existing files yes, missing trace no" "$(js "$A.map(a=>a.present).join()")" true,true,false
sha=$(node -e 'process.stdout.write("sha256:"+require("crypto").createHash("sha256").update(require("fs").readFileSync(process.argv[1])).digest("hex"))' "$repo/evidencias/FASE-1/AC-001-01.png")
expect "attachment sha256 and bytes" "$(js "${A}[0].sha256 + '/' + ${A}[0].bytes")" "$sha/11"
expect "a test without attachments carries an empty list" "$(js 'j.requirements.find(r=>r.id==="REQ-F-002").criteria[0].evidence[0].attachments.length')" 0
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --attach evidencias/FASE-1/AC-001-01.png --by Laura --role "product owner"
expect "record demo --attach → 0" "$rc" 0
expect "record stores path, kind and sha256 of the attachment" "$(lastrec 'r.attachments.map(a=>a.path+"|"+a.kind+"|"+a.sha256+"|"+a.bytes).join()')" "evidencias/FASE-1/AC-001-01.png|image|$sha|11"
before=$(dlines)
run accept record demo --req REQ-F-006 --observed x --pass true --attach package.json --by Laura --role "product owner"
expect "--attach outside evidencias/ → 2" "$rc" 2; has "--attach: names the evidence dir" "not under evidencias/"
run accept record demo --req REQ-F-006 --observed x --pass true --attach evidencias/FASE-1/nope.png --by Laura --role "product owner"
expect "--attach of a missing file → 2" "$rc" 2; has "--attach: missing file" "no such file"
run accept record waiver --req REQ-F-005 --reason r --follow-up "#42" --attach evidencias/FASE-1/AC-001-01.png --by Laura --role "product owner"
expect "--attach on a waiver → 2" "$rc" 2
expect "refused --attach records append nothing" "$(dlines)" "$before"
run accept --json --no-out
D='j.requirements.find(r=>r.id==="REQ-F-006").criteria[0].evidence[0]'
expect "demo evidence: F-006 VERIFIED with its attachment present" "$(js "j.requirements.find(r=>r.id==='REQ-F-006').verdict + '/' + $D.attachments[0].present")" VERIFIED/true
printf 'replaced' > "$repo/evidencias/FASE-1/AC-001-01.png"
run accept --json --no-out
expect "a replaced attachment no longer counts (hash differs)" "$(js "$D.attachments[0].present + '/' + $D.attachments[0].changed")" false/true
rm -f "$repo/evidencias/FASE-1/AC-001-01.png"
run accept --json --no-out
expect "a deleted attachment is not present" "$(js "$D.attachments[0].present")" false
( cd "$repo" && git checkout -q -- acceptance/decisions.jsonl )
rm -rf "$repo/evidencias" "$repo/.sdd/junit/e2e.xml"

# ---------------------------------------------------------------- 16. visual evidence: required (default), warn, off
# A copy of the fixture without its `visual_evidence: off` profile: the default rule is required.
repo="$tmp/visual"
cp -R "$FIX/todo" "$repo"; rm -f "$repo/CLAUDE.md"
git init -q "$repo"
commit "init visual"
green4() { junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass"; }
C='(id,n)=>j.requirements.find(r=>r.id===id).criteria.find(c=>c.n===n)'
V='(id)=>j.requirements.find(r=>r.id===id)'
green4
run accept --json --no-out
expect "default rule: visual_evidence required" "$(js 'j.visual_evidence + "/" + j.evidence_dir')" required/evidencias
expect "required: passing REQ-F criteria without a screenshot are unshown" "$(js "[1,2].map(n=>($C)('REQ-F-001',n).state).join()")" unshown,unshown
expect "required: F-001 MISSING with reason no visual evidence" "$(js "($V)('REQ-F-001').verdict + '/' + ($V)('REQ-F-001').reason + '/' + ($V)('REQ-F-001').criteria_passing")" "MISSING/no visual evidence/0"
expect "required: summary.unshown counts the criteria (F-001 ×2, F-002 ×2)" "$(js 'j.summary.unshown')" 4
expect "required: REQ-NF / REQ-C carry no visual state" "$(js "($V)('REQ-NF-002').criteria[0].visual === undefined")" true
expect "required: a missing test stays missing, not unshown (F-005 AC2)" "$(js "($C)('REQ-F-005',2).state + '/' + ($V)('REQ-F-005').reason")" missing/null
run loop next --state .sdd/loop-v.json
expect "loop: unshown criteria → capture-evidence" "$(loopq 'const t=j.targets.find(t=>t.req==="REQ-F-001"); t.route_hint + "/" + t.criteria.map(c=>c.route_hint).join()')" "capture-evidence/capture-evidence,capture-evidence"
run gate --fase 1; expect "gate --fase 1 with unshown criteria → 1" "$rc" 1
has "gate names the reason" "REQ-F-001  MISSING (no visual evidence)"
run accept --no-out
has "accept lists the unshown criteria" "unshown REQ-F-001 AC1: passes without a screenshot in evidencias/ (capture-evidence)"
# Screenshots: one through a JUnit [[ATTACHMENT|…]], the others bound by file name (minitest writes no attachments).
mkdir -p "$repo/evidencias/FASE-1" "$repo/evidencias/otros"
printf 'img' > "$repo/evidencias/FASE-1/shot-1.png"
printf 'img' > "$repo/evidencias/FASE-1/REQ-F-001-AC2.png"
printf 'img' > "$repo/evidencias/otros/AC-002-01.png"
printf 'img' > "$repo/evidencias/FASE-1/AC-002-021.png"
cat > "$repo/.sdd/junit/e2e.xml" <<'XML'
<testsuites><testsuite name="e2e/add.spec.ts">
<testcase classname="e2e/add.spec.ts" name="add › AC-001-01 adds a task"><system-out><![CDATA[[[ATTACHMENT|../../evidencias/FASE-1/shot-1.png]]
]]></system-out></testcase>
</testsuite></testsuites>
XML
run accept --json --no-out
expect "JUnit screenshot shows F-001 AC1" "$(js "($C)('REQ-F-001',1).state + '/' + ($C)('REQ-F-001',1).visual")" pass/shown
expect "file named REQ-F-001-AC2 shows F-001 AC2 (bound by name)" "$(js "($C)('REQ-F-001',2).state + '/' + ($C)('REQ-F-001',2).evidence.find(e=>e.kind==='capture').ref")" pass/evidencias/FASE-1/REQ-F-001-AC2.png
expect "name-bound capture carries sha256 and present" "$(js "const a=($C)('REQ-F-001',2).evidence.find(e=>e.kind==='capture').attachments[0]; /^sha256:/.test(a.sha256) + '/' + a.present + '/' + a.kind")" true/true/image
expect "F-001 VERIFIED with both screenshots" "$(js "($V)('REQ-F-001').verdict + '/' + ($V)('REQ-F-001').reason")" VERIFIED/null
expect "a scenario id in any subfolder binds (AC-002-01 under evidencias/otros)" "$(js "($C)('REQ-F-002',1).state")" pass
expect "AC-002-021.png does not bind AC-002-02" "$(js "($C)('REQ-F-002',2).state")" unshown
touch -t 202001010000 "$repo/evidencias/FASE-1/REQ-F-001-AC2.png"
run accept --json --no-out
expect "a capture older than the last code commit does not count" "$(js "($C)('REQ-F-001',2).state + '/' + ($C)('REQ-F-001',2).evidence.find(e=>e.kind==='capture').fresh")" unshown/false
touch "$repo/evidencias/FASE-1/REQ-F-001-AC2.png"
printf 'img' > "$repo/evidencias/FASE-1/AC-002-02.png"
# A demo REQ-F needs its capture too: the record's --attach.
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --by Laura --role "product owner"
run accept --json --no-out
expect "demo without --attach: F-006 unshown" "$(js "($V)('REQ-F-006').verdict + '/' + ($C)('REQ-F-006',1).state")" MISSING/unshown
printf 'img' > "$repo/evidencias/FASE-1/columns.png"
run accept record demo --req REQ-F-006 --observed "aligned" --pass true --attach evidencias/FASE-1/columns.png --by Laura --role "product owner"
run accept --json --no-out
expect "demo with --attach of a screenshot: F-006 VERIFIED" "$(js "($V)('REQ-F-006').verdict")" VERIFIED
# Video per FASE: the FASE file cites no WF-NNN, so the gate asks for a video named FASE-1.
run gate --fase 1 --json
expect "every criterion shown but no FASE-1 video → gate 1" "$rc" 1
expect "gate --json lists missing_videos" "$(js 'j.missing_videos.join() + "/" + j.summary.goal')" FASE-1/false
run gate --fase 1 --md
has "--md: visual evidence line" "Visual evidence (required): missing video: FASE-1"
run loop next --fase 1 --state .sdd/loop-w.json
expect "loop: missing video → capture-evidence" "$(loopq 'j.missing_videos.map(v=>v.video+"/"+v.route_hint).join()')" FASE-1/capture-evidence
printf 'vid' > "$repo/evidencias/FASE-1/FASE-10-otra.webm"
run gate --fase 1; expect "a FASE-10 video does not satisfy FASE-1 → 1" "$rc" 1
printf 'vid' > "$repo/evidencias/FASE-1/FASE-1-crear-y-listar.webm"
run gate --fase 1; expect "video named FASE-1-<title> → gate 0" "$rc" 0
run accept --fase 1 --report acceptance/F1.md --no-out
grep -q '^## Visual evidence' "$repo/acceptance/F1.md" && pass "report: Visual evidence section" || bad "report: no Visual evidence section"
grep -q '^| REQ-F-001 | AC2 | pass | evidencias/FASE-1/REQ-F-001-AC2.png |' "$repo/acceptance/F1.md" && pass "report: screenshot per criterion" || bad "report: screenshot row"
grep -q '^Videos for FASE 1: FASE-1 present' "$repo/acceptance/F1.md" && pass "report: videos of the FASE" || bad "report: videos line"
# Workflows cited as reading material (Specs a Leer) ask for no video: still FASE-1, already present.
printf '\n## Specs a Leer\n\n- spec/workflows/WF-009-export.md\n' >> "$repo/plan/fases/FASE-1-core.md"; commit "docs(plan): specs to read"
run gate --fase 1 --json
expect "WF-009 under Specs a Leer asks for no video → 0" "$rc/$(js 'j.missing_videos.length')" 0/0
# Without a Workflows: header line, the WF-NNN cited inside ## Demo ask for one video each (E2E-WF-NNN-NN names),
# here through a JUnit attachment.
printf '\n## Demo\n\n1. Alta y listado (WF-003).\n\n## Notas\n\nWF-008 queda para otra FASE.\n' >> "$repo/plan/fases/FASE-1-core.md"; commit "docs(plan): demo cites WF-003"
run gate --fase 1 --json
expect "Demo citing WF-003 without its video → 1, missing WF-003 (not WF-008 of Notas)" "$rc/$(js 'j.missing_videos.join()')" 1/WF-003
mkdir -p "$repo/test-results"; printf 'vid' > "$repo/test-results/E2E-WF-003-01.webm"
cat > "$repo/.sdd/junit/e2e.xml" <<'XML'
<testsuites><testsuite name="e2e/add.spec.ts">
<testcase classname="e2e/add.spec.ts" name="add › AC-001-01 adds a task"><system-out><![CDATA[[[ATTACHMENT|../../evidencias/FASE-1/shot-1.png]]
[[ATTACHMENT|test-results/E2E-WF-003-01.webm]]
]]></system-out></testcase>
</testsuite></testsuites>
XML
run gate --fase 1 --json
expect "E2E-WF-003-01.webm attached by the journey test → gate 0" "$rc/$(js 'j.missing_videos.length')" 0/0
# A `Workflows:` header line wins over ## Demo; a manual demo recording under evidencias/ counts by its name.
node -e 'const fs=require("fs"),f=process.argv[1];fs.writeFileSync(f,fs.readFileSync(f,"utf8").replace(/^(> \*\*Requisitos:\*\*.*)$/m,"$1\n> **Workflows:** WF-003, WF-004, WF-005"))' "$repo/plan/fases/FASE-1-core.md"
commit "docs(plan): Workflows header"
run gate --fase 1 --json
expect "Workflows: WF-003, WF-004, WF-005 header → WF-004, WF-005 missing → 1" "$rc/$(js 'j.missing_videos.join()')" 1/WF-004,WF-005
run accept --fase 1 --json --no-out
expect "ledger videos.required comes from the header (not Demo's WF-003 alone, not WF-008/WF-009)" "$(js 'j.videos.required.join()')" WF-003,WF-004,WF-005
# Loop with every Must VERIFIED and only videos pending: one capture target per video; a captured one is progress.
run loop next --fase 1 --reset --state .sdd/loop-x.json
expect "loop: one capture-evidence target per missing video, only those" "$(loopq 'j.targets.map(t=>t.video+"/"+t.fase+"/"+t.route_hint).join() + "|" + j.stop + "|" + j.progress.videos_missing')" "WF-004/1/capture-evidence,WF-005/1/capture-evidence|null|2"
printf 'vid' > "$repo/evidencias/FASE-1/demo-manual-WF-004.mp4"
run gate --fase 1 --json
expect "manual recording demo-manual-WF-004.mp4 under evidencias/ counts, WF-005 still missing → 1" "$rc/$(js 'j.missing_videos.join()')" 1/WF-005
run loop next --fase 1 --state .sdd/loop-x.json
expect "loop: a captured video is progress, not no-progress" "$(loopq 'j.cycle + "/" + j.stop + "/" + j.targets.map(t=>t.video).join()')" 2/null/WF-005
run loop next --fase 1 --state .sdd/loop-x.json
expect "loop: nothing captured since → no-progress" "$(loopq 'j.cycle + "/" + j.stop')" 3/no-progress
printf 'vid' > "$repo/evidencias/FASE-1/WF-005.webm"
run gate --fase 1 --json
expect "every workflow video present → gate 0" "$rc/$(js 'j.missing_videos.length')" 0/0
# warn: reported, the verdicts do not change.
printf '# p\n\n## SDD Stack Profile\n- visual_evidence: warn\n' > "$repo/CLAUDE.md"
rm -rf "$repo/evidencias" "$repo/test-results" "$repo/.sdd/junit/e2e.xml"
green4
run accept --json --no-out
expect "warn: F-001 VERIFIED without screenshots" "$(js "($V)('REQ-F-001').verdict + '/' + ($C)('REQ-F-001',1).state + '/' + ($C)('REQ-F-001',1).visual")" VERIFIED/pass/missing
expect "warn: summary.unshown still counts them (F-001 ×2, F-002 ×2, F-006 demo whose capture is gone)" "$(js 'j.summary.unshown')" 5
run accept --no-out
has "warn: accept prints a warning per criterion" "warning: no screenshot REQ-F-001 AC1"
run gate --fase 1 --json
expect "warn: missing video listed, gate unchanged → 0" "$rc/$(js 'j.missing_videos.join()')" 0/WF-003,WF-004,WF-005
run loop next --fase 1 --reset --state .sdd/loop-y.json
expect "warn: video targets go to others, not targets" "$(loopq 'j.targets.filter(t=>t.video).length + "/" + j.others.filter(t=>t.video).map(t=>t.video).join()')" 0/WF-003,WF-004,WF-005
# off: nothing.
printf '# p\n\n## SDD Stack Profile\n- visual_evidence: off\n' > "$repo/CLAUDE.md"
run accept --fase 1 --json --no-out
expect "off: no visual state, no count, no videos" "$(js "String(($C)('REQ-F-001',1).visual) + '/' + j.summary.unshown + '/' + j.videos")" undefined/0/null
run gate --fase 1; expect "off: gate --fase 1 → 0" "$rc" 0
rm -f "$repo/CLAUDE.md"

# ---------------------------------------------------------------- 17. accept pack: evidencias/FASE-N/ + manifest
mkdir -p "$repo/evidencias/FASE-1/sub"
printf 'img' > "$repo/evidencias/FASE-1/AC-001-01.png"
printf 'vid' > "$repo/evidencias/FASE-1/sub/FASE-1-crear.webm"
green4
run accept pack --fase 1
expect "accept pack --fase 1 → 0" "$rc" 0
has "pack prints the archive" ".sdd/entregas/FASE-1-evidencias.tar.gz"
arch="$repo/.sdd/entregas/FASE-1-evidencias.tar.gz"
listing=$(tar -tzf "$arch" | sort | tr '\n' ' ')
expect "archive holds manifest.json and evidencias/FASE-1/…" "$listing" "evidencias/FASE-1/ evidencias/FASE-1/AC-001-01.png evidencias/FASE-1/sub/ evidencias/FASE-1/sub/FASE-1-crear.webm manifest.json "
out=$(tar -xOzf "$arch" manifest.json)
expect "manifest: evaluated_sha = HEAD, 2 files" "$(js 'j.evaluated_sha + "/" + j.files.length + "/" + j.fase')" "$(cd "$repo" && git rev-parse HEAD)/2/1"
sha=$(node -e 'process.stdout.write("sha256:"+require("crypto").createHash("sha256").update(require("fs").readFileSync(process.argv[1])).digest("hex"))' "$repo/evidencias/FASE-1/AC-001-01.png")
expect "manifest: path, sha256, bytes, kind, criterion per file" "$(js 'const f=j.files[0]; [f.path,f.sha256,f.bytes,f.kind,f.criterion].join("|")')" "evidencias/FASE-1/AC-001-01.png|$sha|3|image|AC-001-01"
expect "manifest: criteria the capture shows (from the ledger)" "$(js 'j.files[0].criteria.join()')" "REQ-F-001 AC1"
expect "manifest: the video named after its FASE" "$(js 'j.files[1].kind + "/" + j.files[1].criterion')" video/FASE-1
run accept pack --fase 2; expect "accept pack of a FASE without evidence → 1" "$rc" 1; has "pack: says there is nothing" "no evidence under evidencias/FASE-2/"
run accept pack; expect "accept pack without --fase → 2" "$rc" 2
rm -rf "$repo/evidencias" "$repo/.sdd/entregas"
repo="$saved_repo"

# ---------------------------------------------------------------- 18. req show: the literal text a test quotes (M6)
run req show REQ-F-001
expect "req show exits 0" "$rc" 0
has "req show: title" "REQ-F-001: Create a task"
has "req show: statement" 'Statement: WHEN the user runs `todo add <title>` THE system SHALL create a pending task with the next id.'
has "req show: criteria verbatim" 'AC2: GIVEN any state WHEN the user runs `todo add ""` THEN the command exits 2 with `title must not be empty`'
run req show REQ-F-001 --ac 1
expect "req show --ac 1: one line, verbatim" "$out" 'REQ-F-001 AC1: GIVEN an empty list WHEN the user runs `todo add "Buy milk"` THEN task 1 "Buy milk" is pending'
run req show req-f-001 --ac AC2 --json
expect "req show --json: id, ac, criterion, verification" "$(js 'j.id + "|" + j.ac + "|" + j.criteria.length + "|" + j.criteria[0].n + "|" + j.verification + "|" + j.priority')" "REQ-F-001|2|1|2|test|Must"
expect "req show --json: reqHash matches the ledger's" "$(js 'j.reqHash')" "$(cd "$repo" && node "$SDD" accept --json --no-out 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).requirements.find(r=>r.id==="REQ-F-001").reqHash))')"
run req show REQ-F-004 --json
expect "req show: a deprecated requirement is flagged" "$(js 'j.deprecated')" true
run req show REQ-F-001 --ac 3; expect "req show --ac beyond the criteria → 1" "$rc" 1; has "req show: says how many criteria" "has 2 criteria"
run req show REQ-X-999; expect "req show of an unknown id → 1" "$rc" 1
run req show; expect "req show without an id → 2" "$rc" 2
run req list; expect "req with an unknown subcommand → 2" "$rc" 2
run req show REQ-F-001 --requirements nope.md; expect "req show --requirements missing file → 2" "$rc" 2

# ---------------------------------------------------------------- 19. adversarial round: challenges, gate 4, loop, plan
# acceptance/challenges.jsonl is written only by `accept challenge add`; a challenge sits next to the verdict (never
# changes it), goes stale when a cited file or the requirement text changes, and is dismissed only by a person.
repo="$tmp/adv"
cp -R "$FIX/todo" "$repo"
git init -q "$repo"
profile() { { echo "# adv"; echo; echo "## SDD Stack Profile"; echo "- visual_evidence: off"; for l in "$@"; do echo "- $l"; done; } > "$repo/CLAUDE.md"; }
# commitT MSG TRAILER… → a dated commit with `git commit --trailer` (the FASE's Task: commits feed the candidate files)
commitT() {
  n=$((n + 1)); local d m="$1" t; local -a a=(); shift
  for t in "$@"; do a+=(--trailer "$t"); done
  d="2026-01-01T01:$(printf %02d "$n"):00"
  ( cd "$repo" && git add -A && GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -qm "$m" "${a[@]}" )
}
chlines() { if [ -f "$repo/acceptance/challenges.jsonl" ]; then wc -l < "$repo/acceptance/challenges.jsonl" | tr -d ' '; else echo 0; fi; }
lastch() { tail -1 "$repo/acceptance/challenges.jsonl" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const r=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
profile
mkdir -p "$repo/tests" "$repo/test/models"
printf 'import { add } from "../src/api.js";\ntest("AC-001-01 adds", () => {\n  expect(add("Buy milk")).toBe("Buy milk");\n});\n' > "$repo/tests/todo.test.js"
printf 'class TaskTest\n  def test_ac_001_01\n  end\nend\n' > "$repo/test/models/task_test.rb"
printf '# Test plan\n' > "$repo/test/TEST-PLAN.md"
commit "init"
printf 'export const add = (t) => t;\nexport const list = (ts) => ts;\nexport const rm = (ts, id) => ts.filter((t) => t.id !== id);\n' > "$repo/src/api.js"
commitT "feat(todo): list and rm" "Task: TASK-F1-001" "Refs: REQ-F-002"
printf 'export const store = new Map();\n' > "$repo/src/store.js"
commitT "feat(todo): store" "Task: TASK-F1-002" "Refs: REQ-F-001"
printf 'export const csv = () => "";\n' > "$repo/src/other.js"
commitT "feat(todo): export" "Task: TASK-F2-001"
all_green() { junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=pass" "AC-002-01 order=pass" "AC-002-02 empty list=pass"; }
all_green
add_ok() {
  run accept challenge add --req REQ-F-001 --ac 1 --category WEAKENED-ASSERT --quote 'task 1 "Buy milk" is pending' \
    --evidence src/api.js:1 tests/todo.test.js:3 --verifier verifier-FASE-1 --counter confirmed "$@"
}
bad_ev() { run accept challenge add --req REQ-F-001 --ac 1 --category UNWIRED --quote q --evidence "$1" --verifier v --counter confirmed; }

run gate --fase 1; expect "adv: gate --fase 1 → 0 before any challenge" "$rc" 0
add_ok --json
expect "challenge add → 0" "$rc" 0
expect "challenge add: id CH-001, req, ac, category, counter" "$(js 'const c=j.challenge; [c.id,c.req,c.ac,c.category,c.counter].join("|")')" "CH-001|REQ-F-001|1|WEAKENED-ASSERT|confirmed"
expect "challenge add: evidence path:line and cited paths" "$(js 'j.challenge.evidence.map(e=>e.path+":"+e.line).join()+"|"+j.challenge.paths.join()')" "src/api.js:1,tests/todo.test.js:3|src/api.js,tests/todo.test.js"
expect "challenge add: stamps HEAD" "$(js 'j.challenge.head')" "$(cd "$repo" && git rev-parse HEAD)"
expect "challenge add: stamps the requirement's reqHash" "$(js 'j.challenge.reqHash')" "$(cd "$repo" && node "$SDD" req show REQ-F-001 --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).reqHash))')"
expect "challenge add: one line in acceptance/challenges.jsonl" "$(chlines)" 1
before=$(chlines)
bad_ev spec/tests/BDD-UC-001.md:5
expect "evidence under spec/ → 2" "$rc" 2; has "names the forbidden folder" "spec/ is never evidence"
for p in acceptance/x.md feedback/x.md requirements/REQUIREMENTS.md plan/fases/FASE-1-core.md task/T.md audits/A.md changes/C.md; do
  mkdir -p "$repo/$(dirname "$p")"; [ -f "$repo/$p" ] || echo x > "$repo/$p"
  bad_ev "$p:1"
  expect "evidence under ${p%%/*}/ → 2" "$rc" 2
done
rm -rf "$repo/acceptance/x.md" "$repo/feedback" "$repo/task" "$repo/audits" "$repo/changes"
bad_ev test/models/task_test.rb:2
expect "test/ outside test_paths → 2" "$rc" 2; has "test/: says why" "not a test path of the Stack Profile"
bad_ev .sdd/junit/unit.xml:1
expect "evidence under .sdd/ → 2" "$rc" 2
run accept challenge add --req REQ-F-001 --ac 1 --category WEAKENED-ASSERT --quote q --evidence src/api.js:1 --verifier v --counter refuted
expect "--counter refuted → 2" "$rc" 2; has "refuted: goes to the summary" "a refuted finding is not recorded"
run accept challenge add --req REQ-F-001 --ac 1 --category WEAKENED-ASSERT --quote q --evidence src/api.js:1 --verifier v
expect "no --counter → 2" "$rc" 2
run accept challenge add --req REQ-F-099 --ac 1 --category WEAKENED-ASSERT --quote q --evidence src/api.js:1 --verifier v --counter confirmed
expect "unknown requirement → 2" "$rc" 2
run accept challenge add --req REQ-F-001 --ac 3 --category WEAKENED-ASSERT --quote q --evidence src/api.js:1 --verifier v --counter confirmed
expect "criterion that does not exist → 2" "$rc" 2; has "says how many criteria" "has 2 criteria"
run accept challenge add --req REQ-F-001 --category WEAKENED-ASSERT --quote q --evidence src/api.js:1 --verifier v --counter confirmed
expect "no --ac → 2" "$rc" 2
run accept challenge add --req REQ-F-004 --ac 1 --category WEAKENED-ASSERT --quote q --evidence src/api.js:1 --verifier v --counter confirmed
expect "deprecated requirement → 2" "$rc" 2
run accept challenge add --req REQ-F-001 --ac 1 --category WRONG --quote q --evidence src/api.js:1 --verifier v --counter confirmed
expect "unknown category → 2" "$rc" 2; has "lists the categories" "WRONG-CAPTURE"
run accept challenge add --req REQ-F-001 --ac 1 --category UNWIRED --quote "  " --evidence src/api.js:1 --verifier v --counter confirmed
expect "empty --quote → 2" "$rc" 2
run accept challenge add --req REQ-F-001 --ac 1 --category UNWIRED --quote q --evidence src/api.js:1 --counter confirmed
expect "no --verifier → 2" "$rc" 2
run accept challenge add --req REQ-F-001 --ac 1 --category UNWIRED --quote q --verifier v --counter confirmed
expect "no --evidence → 2" "$rc" 2
bad_ev src/nope.js:1
expect "missing evidence file → 2" "$rc" 2; has "missing file named" "no such file"
bad_ev src/api.js:99
expect "line beyond the file → 2" "$rc" 2; has "says how many lines" "has 3 lines"
bad_ev src/api.js
expect "code evidence without a line → 2" "$rc" 2
bad_ev ../outside.js:1
expect "evidence outside the repo → 2" "$rc" 2
echo 'export const x = 1;' > "$repo/src/new.js"
bad_ev src/new.js:1
expect "uncommitted (untracked) evidence file → 2" "$rc" 2; has "commit first" "commit first"
rm -f "$repo/src/new.js"
echo '// wip' >> "$repo/src/store.js"
bad_ev src/store.js:1
expect "evidence file with uncommitted changes → 2" "$rc" 2
( cd "$repo" && git checkout -q -- src/store.js )
expect "refused challenges append nothing" "$(chlines)" "$before"
run accept challenge add --req REQ-F-001 --ac 2 --category BYPASS-PATH --quote "not literal" --evidence src/api.js:2 --verifier v --counter inconclusive
expect "inconclusive is recorded → 0" "$rc" 0; has "warns when the quote is not literal" "--quote is not a literal part of REQ-F-001 AC2"
expect "second challenge is CH-002" "$(lastch 'r.id + "|" + r.counter')" "CH-002|inconclusive"

# test/ inside test_paths (Rails Minitest) is evidence; top-level test/*.md never is.
profile "test_paths: test" "code_paths: src"
commit "profile: test_paths test"
run accept challenge add --req REQ-F-002 --ac 1 --category MOCK-ONLY --quote "two lines are printed in id order" --evidence test/models/task_test.rb:2 --verifier v --counter confirmed
expect "test/ inside test_paths → 0" "$rc" 0
bad_ev test/TEST-PLAN.md:1
expect "top-level test/*.md stays forbidden → 2" "$rc" 2
profile
commit "profile: back to default"

# list
run accept challenge list --json
expect "list --json: counts" "$(js 'j.total + "/" + j.open + "/" + j.stale + "/" + j.dismissed')" "3/3/0/0"
expect "list --json: Musts with an open challenge" "$(js 'j.must_open.join()')" "REQ-F-001,REQ-F-002"
run accept challenge list
has "list: one line per challenge" "CH-001  open"
has "list: summary line" "challenges: 3 · open 3"

# ledger: the verdict does not change; challenges[] and summary.must_challenged
all_green
run accept --fase 1 --report acceptance/ACCEPTANCE-REPORT.md
expect "accept with challenges → 0" "$rc" 0
expect "verdict unchanged: F-001 VERIFIED" "$(ledger 'v("REQ-F-001")')" VERIFIED
expect "ledger: challenges[] per requirement with state" "$(ledger 'R("REQ-F-001").challenges.map(c=>c.id+":"+c.state).join()')" "CH-001:open,CH-002:open"
expect "ledger: summary.must_challenged" "$(ledger 'L.summary.must_challenged')" 2
expect "ledger: adversarial_gate default warn" "$(ledger 'L.adversarial_gate')" warn
has "accept: prints the open challenges" "challenge CH-001 open REQ-F-001 AC1 WEAKENED-ASSERT"
grep -q '^## Adversarial challenges' "$repo/acceptance/ACCEPTANCE-REPORT.md" && pass "report: Adversarial challenges section" || bad "report: no Adversarial challenges section"
grep -q '^| CH-001 | REQ-F-001 | AC1 | WEAKENED-ASSERT | confirmed | open |' "$repo/acceptance/ACCEPTANCE-REPORT.md" && pass "report: one row per challenge" || bad "report: challenge row"
grep -q '| VERIFIED · challenged CH-001, CH-002 |' "$repo/acceptance/ACCEPTANCE-REPORT.md" && pass "report: the verdict cell names its challenges" || bad "report: verdict cell"

# gate: warn (default) keeps the code; enforce → 4; off ignores; precedence 2 > 1 > 4 > 3 > 0
run gate --fase 1; expect "gate warn: open Must challenge keeps exit 0" "$rc" 0
has "gate warn: prints the challenge" "challenge CH-001 open on REQ-F-001 AC1"; has "gate warn: says enforce would exit 4" "enforce would exit 4"
run gate --fase 1 --md; has "gate --md: adversarial line" "Adversarial (\`adversarial_gate: warn\`): 3 open challenges"
profile "adversarial_gate: off"; commit "profile: off"
all_green
run gate --fase 1; expect "gate off: exit 0" "$rc" 0
if contains "$out" "challenge CH-001"; then bad "gate off: challenges not printed"; else pass "gate off: challenges not printed"; fi
profile "adversarial_gate: enforce"; commit "profile: enforce"
all_green
run gate --fase 1; expect "gate enforce: open challenge on a Must → 4" "$rc" 4; has "gate: label 4" "open adversarial challenge on a Must"
run gate --fase 1 --json; expect "gate --json: code 4 and the challenges" "$(js 'j.code + "|" + j.adversarial_gate + "|" + j.must_challenged + "|" + j.open_challenges.map(c=>c.id).join()')" "4|enforce|2|CH-001,CH-002,CH-003"
run gate --fase 1 --md; has "gate --md: exit 4 in the header" "gate exit 4"
run gate --fase 1 --mode warn; expect "acceptance_gate warn over enforce → 0" "$rc" 0; has "warn: would exit 4" "would exit 4"
run gate; expect "precedence: goal not met (1) over an open challenge (4)" "$rc" 1
junit .sdd/junit/unit.xml "AC-001-01 adds=pass" "AC-001-02 empty title=fail" "AC-002-01 order=pass" "AC-002-02 empty list=pass"
run gate --fase 1; expect "precedence: failing (1) over 4" "$rc" 1
all_green
echo '// wip' >> "$repo/tests/todo.test.js"
run gate --fase 1; expect "precedence: stale evidence (2) over 4" "$rc" 2
( cd "$repo" && git checkout -q -- tests/todo.test.js )

# loop next: challenges are targets; under enforce the goal is not reached while one is open on a Must
run loop next --reset --fase 1
expect "loop: no goal stop while a Must challenge is open (enforce)" "$(js 'String(j.stop)')" null
expect "loop: challenge targets with route and category" "$(js 'j.targets.filter(t=>t.challenge).map(t=>t.challenge+":"+t.route_hint+":"+t.category).join()')" "CH-001:adversarial-finding:WEAKENED-ASSERT,CH-002:needs-human:BYPASS-PATH,CH-003:adversarial-finding:MOCK-ONLY"
expect "loop: progress counts challenged Musts" "$(js 'j.progress.challenged')" 2

# dismissal: a person's record in decisions.jsonl
run accept record challenge-dismissal --challenge CH-002 --reason "the other route is admin-only by design" --by "Laura" --role "product owner"
expect "record challenge-dismissal → 0" "$rc" 0
expect "dismissal: record carries challenge, req, ac" "$(lastrec 'r.type + "|" + r.challenge + "|" + r.req + "|" + r.ac + "|" + r.by')" "challenge-dismissal|CH-002|REQ-F-001|2|Laura"
run accept record challenge-dismissal --challenge CH-002 --reason again --by Laura --role "product owner"
expect "dismissing twice → 2" "$rc" 2; has "already dismissed" "already dismissed"
run accept record challenge-dismissal --challenge CH-042 --reason r --by Laura --role "product owner"
expect "unknown challenge → 2" "$rc" 2
run accept record challenge-dismissal --challenge CH-001 --by Laura --role "product owner"
expect "dismissal without --reason → 2" "$rc" 2
run accept record challenge-dismissal --challenge CH-001 --reason r
expect "dismissal without --by/--role → 2" "$rc" 2
run accept challenge list --json
expect "list: CH-002 dismissed with who and why" "$(js 'const c=j.challenges.find(x=>x.id==="CH-002"); c.state + "|" + c.dismissal.by')" "dismissed|Laura"

# stale: the cited code changed since the challenge's HEAD
printf 'export const add = (t) => ({ title: t, pending: true });\nexport const list = (ts) => ts;\nexport const rm = (ts, id) => ts.filter((t) => t.id !== id);\n' > "$repo/src/api.js"
commitT "fix(todo): add returns a pending task" "Task: TASK-F1-003" "Refs: REQ-F-001"
run accept challenge list --json
expect "CH-001 stale once src/api.js changed" "$(js 'const c=j.challenges.find(x=>x.id==="CH-001"); c.state + "|" + /src\/api\.js/.test(c.stale_reason)')" "stale|true"
expect "CH-003 still open (test/models untouched)" "$(js 'j.challenges.find(x=>x.id==="CH-003").state')" open
run accept challenge list --open --json
expect "list --open: only the open ones" "$(js 'j.challenges.map(c=>c.id).join()')" CH-003
all_green
run gate --fase 1; expect "enforce: still 4 while CH-003 is open on REQ-F-002" "$rc" 4
run accept record challenge-dismissal --challenge CH-003 --reason "the real provider is the one tested" --by Laura --role "product owner"
run gate --fase 1; expect "enforce: 0 once no Must challenge is open" "$rc" 0
run loop next --fase 1; expect "loop: goal once no Must challenge is open" "$(js 'j.stop')" goal
# waived Must (3) vs an open challenge (4): the challenge outranks the waiver
run accept record waiver --req REQ-F-002 --reason "deferred" --follow-up "#7" --by Laura --role "product owner"
run gate --fase 1; expect "waived Must, no open challenge → 3" "$rc" 3
add_ok
run gate --fase 1; expect "precedence: open challenge (4) over waivers (3)" "$rc" 4
run accept record challenge-dismissal --challenge CH-004 --reason r --by Laura --role "product owner"

# stale by the requirement text (MODIFY) and by a changed capture
add_ok
sed -i.bak 's/THEN task 1 "Buy milk" is pending/THEN task 1 "Buy milk" is pending and listed/' "$repo/requirements/REQUIREMENTS.md"; rm -f "$repo/requirements/REQUIREMENTS.md.bak"
run accept challenge list --json
expect "stale when the requirement text changed" "$(js 'j.challenges.find(x=>x.id==="CH-005").stale_reason')" "requirement text changed since the challenge (MODIFY)"
( cd "$repo" && git checkout -q -- requirements/REQUIREMENTS.md )
mkdir -p "$repo/evidencias/FASE-1"; printf 'png' > "$repo/evidencias/FASE-1/AC-001-01.png"
run accept challenge add --req REQ-F-001 --ac 1 --category WRONG-CAPTURE --quote 'Buy milk' --evidence evidencias/FASE-1/AC-001-01.png --verifier v --counter confirmed --json
expect "a capture of the evidence dir without a line → 0, pinned by sha256" "$(js 'const e=j.challenge.evidence[0]; e.path + "|" + e.line + "|" + /^sha256:/.test(e.sha256)')" "evidencias/FASE-1/AC-001-01.png|null|true"
printf 'png2' > "$repo/evidencias/FASE-1/AC-001-01.png"
run accept challenge list --json
expect "stale when the cited capture changed" "$(js 'j.challenges.find(x=>x.id==="CH-006").stale_reason')" "capture evidencias/FASE-1/AC-001-01.png changed"
rm -rf "$repo/evidencias"

# adversarial plan: the mechanical coverage critic
printf '# FASE 2: Export\n\nNo header here.\n\n## Objetivo\n\nExport.\n' > "$repo/plan/fases/FASE-2-export.md"
commit "plan: FASE-2 without header"
all_green
run accept adversarial plan --json
expect "plan: exit 0" "$rc" 0
expect "plan: FASEs listed" "$(js 'j.fases.map(f=>f.fase + ":" + f.header).join()')" "1:true,2:false"
expect "plan: FASE 1 requirements" "$(js 'j.fases[0].requirements.map(r=>r.id).join()')" "REQ-F-001,REQ-F-002"
expect "plan: literal statement" "$(js 'j.fases[0].requirements[0].statement')" 'WHEN the user runs `todo add <title>` THE system SHALL create a pending task with the next id.'
expect "plan: criteria with their literal text" "$(js 'j.fases[0].requirements[0].criteria[1].text')" 'GIVEN any state WHEN the user runs `todo add ""` THEN the command exits 2 with `title must not be empty`'
expect "plan: bound tests with their file" "$(js 'j.fases[0].requirements[0].criteria[0].tests.map(t=>t.name+"@"+t.file).join()')" "AC-001-01 adds@tests/todo.test.ts"
expect "plan: candidate files of the FASE (Task: TASK-F1-…, under code_paths)" "$(js 'j.fases[0].candidate_files.join()')" "src/api.js,src/store.js"
expect "plan: candidate files per requirement (commits naming it)" "$(js 'j.fases[0].requirements[0].candidate_files.join()')" "src/api.js,src/store.js"
expect "plan: tasks of the FASE" "$(js 'j.fases[0].tasks.join()')" "TASK-F1-001,TASK-F1-002,TASK-F1-003"
expect "plan: uncovered (active, in no FASE)" "$(js 'j.uncovered.map(r=>r.id).join()')" "REQ-F-003,REQ-F-005,REQ-F-006,REQ-NF-001,REQ-NF-002,REQ-C-001"
expect "plan: fases_without_header" "$(js 'j.fases_without_header.map(f=>f.fase+":"+f.file).join()')" "2:plan/fases/FASE-2-export.md"
expect "plan: criteria_without_test" "$(js 'j.criteria_without_test.map(c=>c.req+" AC"+c.ac).join()')" "REQ-F-003 AC1,REQ-F-005 AC1,REQ-F-005 AC2"
expect "plan: coverage_gaps = uncovered + without header" "$(js 'j.coverage_gaps')" 7
run accept adversarial plan --fase 1 --json
expect "plan --fase 1: one FASE" "$(js 'j.fases.map(f=>f.fase).join()')" 1
expect "plan --fase 1: criteria without test scoped to the FASE" "$(js 'j.criteria_without_test.length')" 0
expect "plan --fase 1: uncovered stays project-wide" "$(js 'j.uncovered.length')" 6
run accept adversarial plan
has "plan: text summary" "adversarial plan: 2 FASE(s) · 6 uncovered · 1 without header"
run accept adversarial plan --fase 9; expect "plan of a FASE that does not exist → 2" "$rc" 2
run accept adversarial; expect "accept adversarial without plan → 2" "$rc" 2
run accept challenge; expect "accept challenge without add|list → 2" "$rc" 2
run --help; has "--help documents challenge add" "sdd accept challenge add --req ID"; has "--help documents gate exit 4" "4 met, but a Must"; has "--help documents adversarial plan" "sdd accept adversarial plan"

[ "$fail" -eq 0 ] && echo "tests/acceptance: all passed" || echo "tests/acceptance: FAILURES"
exit "$fail"
