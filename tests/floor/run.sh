#!/usr/bin/env bash
# Tests of the floor guard (scripts/sdd.mjs lint --floor, scripts/lib/floor.mjs) and its human exception
# (`sdd accept record floor-exception`), in temporary git repos: base resolution (--base, merge-base with the default
# branch, last fase-*-accepted tag, exit 2 without one) printed in text and JSON; F-01 skip/only/focus/todo on bound,
# existing and new tests (JS, node:test, Python, Ruby; comments ignored; removing a skip is no finding); F-02 deleted or
# renamed test files; F-04 suppressions; F-07 lowered gates (only keys the base writes, removed key → default,
# .claude/CLAUDE.md, examples in code blocks ignored); floor_gate read from the base; testEdits; exceptions bound to
# code, file, exact line and base. bash 3.2 and 5; needs git and node >= 18. Run with `env -u SDD_STATE_ROOT`.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
run() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>&1) || rc=$?; }
runo() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>/dev/null) || rc=$?; }
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);const F=(c)=>j.findings.filter((f)=>f.code===c);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
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
git config --global commit.gpgsign false
git config --global tag.gpgsign false
git config --global advice.detachedHead false

commit() { ( cd "$repo" && git add -A && git commit -qm "$1" ); }
# replace FILE FROM TO → literal text replacement (fails when FROM is absent)
replace() { node -e 'const fs=require("fs");const [f,a,b]=process.argv.slice(1);const t=fs.readFileSync(f,"utf8");if(!t.includes(a)){console.error("replace: not found: "+a);process.exit(1)}fs.writeFileSync(f,t.split(a).join(b))' "$repo/$1" "$2" "$3"; }

# A project on main: profile, bound and unbound JS tests, a Python and a Ruby test, a test without ids.
new_repo() {
  repo="$tmp/$1"; rm -rf "$repo"; mkdir -p "$repo/src" "$repo/tests/py" "$repo/tests/rb"
  cat > "$repo/CLAUDE.md" <<'EOF'
# P

## SDD Stack Profile

- code_paths: src
- test_paths: tests
- literal_gate: enforce
- visual_evidence: warn
- prove_it: enforce
- adversarial_gate: enforce
EOF
  cat > "$repo/tests/a.test.js" <<'EOF'
import { test, describe, it } from "node:test";
test("REQ-F-001 AC1 · adds a task", () => {
  // REQ-F-001 AC1: "x"
});
test("helper formats dates", () => {});
describe("AC-001-02 lists tasks", () => {
  it("shows them", () => {});
});
test("node test with options", { timeout: 10 }, () => {});
EOF
  cat > "$repo/tests/b.test.js" <<'EOF'
test("REQ-F-002 AC1 · deletes", () => {});
EOF
  printf 'test("plain", () => {});\n' > "$repo/tests/plain.test.js"
  cat > "$repo/tests/py/test_x.py" <<'EOF'
def test_req_f_003_ac1_exports():
    assert True

def test_unbound_helper():
    assert True
EOF
  cat > "$repo/tests/rb/x_test.rb" <<'EOF'
class XTest < Minitest::Test
  test "REQ-F-004 AC1 renders" do
    assert true
  end
end
EOF
  printf 'export const a = 1;\n' > "$repo/src/a.js"
  ( cd "$repo" && git init -q -b main )
  commit "feat: base"
  ( cd "$repo" && git switch -q -c work )
}

# ---------------------------------------------------------------- 1. syntax and help
node --check "$ROOT/scripts/lib/floor.mjs" && pass "node --check floor.mjs" || bad "node --check floor.mjs"
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
rc=0; out=$(node "$SDD" lint --floor --help 2>&1) || rc=$?
expect "--help sale 0" "$rc" 0; has "--help documenta lint --floor" "sdd lint --floor [--base REF] [--json]"
has "--help documenta floor-exception" "floor-exception --code F-0N"

# ---------------------------------------------------------------- 2. base
new_repo base
run lint --floor
expect "rama sin cambios → 0" "$rc" 0
has "texto: base y motivo" "(merge-base: merge-base of HEAD and main)"
has "texto: resumen" "lint --floor: 0 error(s) · 0 warning(s) · 0 excepted · 0 test edit(s)"
runo lint --floor --json
expect "json: base merge-base" "$(js 'j.base.source+" "+j.base.ref+" "+(j.base.sha.length)')" "merge-base main 40"
expect "json: modo por defecto" "$(js 'j.mode+" "+j.mode_source+" "+j.exit')" "enforce default 0"
( cd "$repo" && git switch -q main )
run lint --floor
expect "en la rama por defecto sin tag → 2" "$rc" 2; has "mensaje sin base" "no base: pass --base REF"
( cd "$repo" && git tag -a fase-1-accepted -m "FASE-1 accepted" )
printf 'export const b = 2;\n' > "$repo/src/b.js"; commit "feat: b"
runo lint --floor --json
expect "en main: último tag fase-*-accepted" "$(js 'j.base.source+" "+j.base.ref')" "tag fase-1-accepted"
run lint --floor --base nope
expect "--base desconocido → 2" "$rc" 2; has "mensaje revisión" "unknown revision nope"
run lint --floor --bogus; expect "opción desconocida → 2" "$rc" 2
( cd "$repo" && git switch -q work )
runo lint --floor --base HEAD --json; expect "--base: motivo flag" "$(js 'j.base.source')" "flag"
rc=0; out=$(node "$SDD" lint --floor --repo "$tmp" 2>&1) || rc=$?; expect "fuera de un repo → 2" "$rc" 2

# ---------------------------------------------------------------- 3. F-01
new_repo f01
replace tests/a.test.js 'test("REQ-F-001 AC1 · adds' 'test.skip("REQ-F-001 AC1 · adds'
run lint --floor
expect "skip en test ligado → 1" "$rc" 1
has "F-01 error con el criterio" "tests/a.test.js:2 F-01 error \`test.skip\` (skip) added on a test bound to REQ-F-001 AC1"
has "pista de excepción" "sdd accept record floor-exception --code F-01 --file tests/a.test.js --line"
runo lint --floor --json
expect "json F-01: criterio, línea, texto" "$(js 'F("F-01").map(f=>f.severity+" "+f.criteria.join()+" "+f.line+" "+f.kind).join("|")')" "error REQ-F-001 AC1 2 skip"
expect "json: testEdits M" "$(js 'j.testEdits.map(t=>t.status+" "+t.file).join()')" "M tests/a.test.js"
( cd "$repo" && git checkout -q -- tests )

replace tests/a.test.js 'test("helper formats dates"' 'test.only("helper formats dates"'
replace tests/a.test.js 'describe("AC-001-02 lists' 'describe.skip("AC-001-02 lists'
replace tests/a.test.js '{ timeout: 10 }' '{ timeout: 10, skip: "flaky" }'
replace tests/a.test.js 'it("shows them"' 'xit("shows them"'
cat >> "$repo/tests/a.test.js" <<'EOF'
test.skip("brand new idea", () => {});
test.todo("later");
// test.skip("REQ-F-001 AC1 commented out")
EOF
runo lint --floor --json
expect "only en test existente → error" "$(js 'F("F-01").filter(f=>f.kind==="only"&&f.severity==="error").length')" 1
expect "describe.skip con id de escenario → error (scenarios)" "$(js 'F("F-01").filter(f=>f.scenarios.includes("AC-001-02")&&f.severity==="error").length')" 1
expect "xit en un test que ya existía → error" "$(js 'F("F-01").filter(f=>f.text.includes("xit(")).map(f=>f.severity+" "+f.kind).join()')" "error skip"
expect "node:test { skip: } en test existente → error" "$(js 'F("F-01").filter(f=>f.text.includes("skip: \"flaky\"")&&f.severity==="error").length')" 1
expect "test nuevo sin id con skip → warn" "$(js 'F("F-01").filter(f=>f.text.includes("brand new")).map(f=>f.severity).join()')" "warn"
expect "todo → warn" "$(js 'F("F-01").filter(f=>f.kind==="todo").map(f=>f.severity).join()')" "warn"
expect "comentario ignorado" "$(js 'F("F-01").filter(f=>f.text.includes("commented")).length')" 0
expect "exit 1 por los errores" "$(js 'j.exit')" 1
( cd "$repo" && git checkout -q -- tests )

replace tests/py/test_x.py 'def test_req_f_003_ac1_exports' '@pytest.mark.skip(reason="later")
def test_req_f_003_ac1_exports'
replace tests/py/test_x.py '    assert True

def test_unbound' '    pytest.skip("no")
    assert True

def test_unbound'
replace tests/rb/x_test.rb '    assert true' '    skip "flaky"
    assert true'
runo lint --floor --json
expect "pytest decorator sobre test ligado → error" "$(js 'F("F-01").filter(f=>f.file.endsWith(".py")&&f.text.includes("mark.skip")).map(f=>f.severity+" "+f.criteria.join()).join()')" "error REQ-F-003 AC1"
expect "pytest.skip( dentro de test ligado → error" "$(js 'F("F-01").filter(f=>f.text.includes("pytest.skip")).map(f=>f.severity).join()')" "error"
expect "Ruby skip en test ligado → error" "$(js 'F("F-01").filter(f=>f.file.endsWith(".rb")).map(f=>f.severity+" "+f.criteria.join()).join()')" "error REQ-F-004 AC1"
( cd "$repo" && git checkout -q -- tests )

# Removing a skip that the base had is hardening: no finding.
replace tests/b.test.js 'test("REQ-F-002' 'test.skip("REQ-F-002'; commit "test: skip b"
( cd "$repo" && git branch -f main HEAD && git switch -q -c work2 )
replace tests/b.test.js 'test.skip("REQ-F-002' 'test("REQ-F-002'
runo lint --floor --json
expect "quitar un skip no es hallazgo" "$(js 'j.findings.length+" "+j.exit')" "0 0"
( cd "$repo" && git checkout -q -- tests )

# ---------------------------------------------------------------- 4. F-02
new_repo f02
( cd "$repo" && git rm -q tests/b.test.js tests/plain.test.js )
runo lint --floor --json
expect "borrado con ids → error; sin ids → warn" "$(js 'F("F-02").map(f=>f.file+" "+f.severity+" "+f.text).join("|")')" "tests/b.test.js error (deleted)|tests/plain.test.js warn (deleted)"
expect "borrado: ids de la base" "$(js 'F("F-02")[0].criteria.join()')" "REQ-F-002 AC1"
expect "testEdits D" "$(js 'j.testEdits.map(t=>t.status+" "+t.file).join()')" "D tests/b.test.js,D tests/plain.test.js"
( cd "$repo" && git reset -q --hard )
( cd "$repo" && git mv tests/b.test.js tests/b2.test.js )
runo lint --floor --json
expect "renombrado conservando ids → sin hallazgo" "$(js 'F("F-02").length+" "+j.testEdits.map(t=>t.status+" "+t.from+" "+t.file).join()')" "0 R tests/b.test.js tests/b2.test.js"
( cd "$repo" && git reset -q --hard )
mkdir -p "$repo/old"; ( cd "$repo" && git mv tests/b.test.js src/b.test.js )
runo lint --floor --json
expect "movido fuera de test_paths → error" "$(js 'F("F-02").map(f=>f.severity+" "+f.text).join()')" "error (renamed to src/b.test.js)"
( cd "$repo" && git reset -q --hard )

# ---------------------------------------------------------------- 5. F-04
new_repo f04
printf '/* istanbul ignore next */\nexport const c = 3; // nosemgrep\n' > "$repo/src/c.js"
printf '# pragma: no cover\n' >> "$repo/tests/py/test_x.py"
run lint --floor
expect "supresiones → aviso, exit 0" "$rc" 0
runo lint --floor --json
expect "F-04: tres avisos (fichero nuevo sin seguimiento incluido)" "$(js 'F("F-04").map(f=>f.severity).join()')" "warn,warn,warn"

# ---------------------------------------------------------------- 6. F-07
new_repo f07
replace CLAUDE.md '- literal_gate: enforce' '- literal_gate: off'
replace CLAUDE.md '- visual_evidence: warn' '- visual_evidence: required'
replace CLAUDE.md '- prove_it: enforce' ''
printf -- '- acceptance_gate: warn\n' >> "$repo/CLAUDE.md"
run lint --floor
expect "gate rebajado → 1" "$rc" 1
has "F-07 con línea" "CLAUDE.md:7 F-07 error literal_gate lowered from enforce to off"
runo lint --floor --json
expect "F-07: literal_gate y prove_it (clave quitada → warn), nada por visual subido ni acceptance_gate ausente en la base" "$(js 'F("F-07").map(f=>f.key+":"+f.from+">"+f.to).sort().join()')" "literal_gate:enforce>off,prove_it:enforce>warn"
expect "clave quitada: texto de la base, sin línea" "$(js 'F("F-07").find(f=>f.key==="prove_it").text+"|"+F("F-07").find(f=>f.key==="prove_it").line')" "- prove_it: enforce|null"
( cd "$repo" && git checkout -q -- CLAUDE.md )
cat >> "$repo/CLAUDE.md" <<'EOF'

Ejemplo (no es la configuración):

```
- adversarial_gate: off
```
EOF
runo lint --floor --json; expect "ejemplo en bloque de código no cuenta" "$(js 'F("F-07").length')" 0
( cd "$repo" && git checkout -q -- CLAUDE.md )
# Profile moved to .claude/CLAUDE.md with a lowered gate.
mkdir -p "$repo/.claude"; ( cd "$repo" && git mv CLAUDE.md .claude/CLAUDE.md )
replace .claude/CLAUDE.md '- adversarial_gate: enforce' '- adversarial_gate: warn'
runo lint --floor --json
expect ".claude/CLAUDE.md leído" "$(js 'F("F-07").map(f=>f.file+" "+f.key+" "+f.to).join()')" ".claude/CLAUDE.md adversarial_gate warn"
( cd "$repo" && git reset -q --hard )

# ---------------------------------------------------------------- 7. floor_gate, read from the base
new_repo mode
printf -- '- floor_gate: off\n' >> "$repo/CLAUDE.md"
replace tests/a.test.js 'test("REQ-F-001 AC1 · adds' 'test.skip("REQ-F-001 AC1 · adds'
runo lint --floor --json
expect "base sin floor_gate: el modo sale del árbol" "$(js 'j.mode+" "+j.mode_source+" "+j.exit')" "off tree 0"
( cd "$repo" && git checkout -q -- . )
printf -- '- floor_gate: warn\n' >> "$repo/CLAUDE.md"; commit "docs: floor warn"
( cd "$repo" && git branch -f main HEAD && git switch -q -c w3 )
printf -- '- floor_gate: off\n' >> "$repo/CLAUDE.md"
replace tests/a.test.js 'test("REQ-F-001 AC1 · adds' 'test.skip("REQ-F-001 AC1 · adds'
runo lint --floor --json
expect "base floor_gate warn: errores listados, exit 0" "$(js 'j.mode+" "+j.mode_source+" "+j.summary.errors+" "+j.exit')" "warn base 2 0"
expect "bajar floor_gate es un F-07" "$(js 'F("F-07").map(f=>f.key+">"+f.to).join()')" "floor_gate>off"

# ---------------------------------------------------------------- 8. exception (a person)
new_repo exc
replace tests/a.test.js 'test("REQ-F-001 AC1 · adds' 'test.skip("REQ-F-001 AC1 · adds'
base=$(cd "$repo" && git rev-parse main)
line='test.skip("REQ-F-001 AC1 · adds a task", () => {'
run accept record floor-exception --code F-01 --file tests/a.test.js --line "$line" --base main --reason "flaky upstream, issue #9" --by Ana --role "tech lead"
expect "registro de excepción con árbol sucio → 0" "$rc" 0; has "mensaje de registro" "recorded floor-exception F-01 tests/a.test.js"
expect "registro: base resuelta, sin req" "$(node -e 'const l=require("fs").readFileSync(process.argv[1],"utf8").trim().split("\n").pop();const r=JSON.parse(l);console.log(r.type+" "+r.base+" "+(r.req===undefined))' "$repo/acceptance/decisions.jsonl")" "floor-exception $base true"
runo lint --floor --json
expect "excepción: excepted, exit 0" "$(js 'F("F-01").map(f=>f.severity+" "+f.exception.by).join()+" "+j.exit')" "excepted Ana 0"
run lint --floor; has "texto: excepted" "F-01 excepted"
replace tests/a.test.js 'adds a task", () => {' 'adds a task!", () => {'
runo lint --floor --json
expect "línea cambiada → el hallazgo vuelve" "$(js 'F("F-01").map(f=>f.severity).join()+" "+j.exit')" "error 1"
replace tests/a.test.js 'adds a task!", () => {' 'adds a task", () => {'
printf 'export const z = 0;\n' > "$repo/src/z.js"; ( cd "$repo" && git add src/z.js && git commit -qm "feat: z" )
runo lint --floor --base HEAD --json
expect "otra base → el hallazgo vuelve" "$(js 'F("F-01").map(f=>f.severity).join()')" "error"
run accept record floor-exception --code F-03 --file x --line y --base main --reason r --by A --role R
expect "--code fuera de F-01/F-02/F-04/F-07 → 2" "$rc" 2; has "mensaje código" "--code must be one of F-01, F-02, F-04, F-07"
run accept record floor-exception --code F-01 --file x --base main --reason r --by A --role R
expect "sin --line → 2" "$rc" 2
run accept record floor-exception --code F-01 --file x --line y --base main --reason r --by A --role R --req REQ-F-001
expect "con --req → 2" "$rc" 2
run accept record floor-exception --code F-01 --file x --line y --base nope --reason r --by A --role R
expect "--base desconocida → 2" "$rc" 2
run accept record floor-exception --code F-01 --file x --line y --base main --reason r --by A --role R --attach evidencias/x.png
expect "--attach rechazado → 2" "$rc" 2

echo
if [ "$fail" -eq 0 ]; then echo "floor: todo ok"; else echo "floor: hay fallos"; exit 1; fi
