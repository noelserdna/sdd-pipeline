#!/usr/bin/env bash
# Tests de scripts/sdd.mjs (verify, trace, branch) y scripts/lib/git-log.mjs (sin modelo, sin red), en repos temporales:
# modos de fallo del bloque de trailers (prosa detrás, `Closes #12` dentro, Co-Authored-By en otro párrafo, clave en
# minúsculas), cada regla de verify, REQ-F-01 frente a REQ-F-012, revert y revert de un revert, lectura legacy del cuerpo,
# trace why por línea y por fichero, trace delivered por tag, branch start en la rama por defecto (`trunk` por
# init.defaultBranch y `develop` por origin/HEAD), seguir en la rama de trabajo, negarse con HEAD suelto, detección de
# squash en un rango y el alias sdd-task-lint.mjs. Fixtures en tests/fixtures/git/messages/{valid,invalid}.
# Compatible con bash 3.2 (macOS) y bash 5 (Ubuntu CI). Requiere git ≥ 2.32 y node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
LIB="$ROOT/scripts/lib/git-log.mjs"
FIX="$ROOT/tests/fixtures/git/messages"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
run() { rc=0; out=$(node "$SDD" "$@" 2>&1) || rc=$?; }
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if contains "$out" "$2"; then pass "$1"; else bad "$1 (no contiene: $2)"; fi; }
hasnt() { if contains "$out" "$2"; then bad "$1 (contiene: $2)"; else pass "$1"; fi; }

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

# ---------------------------------------------------------------- 1. sintaxis
for f in "$SDD" "$LIB" "$ROOT/scripts/sdd-task-lint.mjs"; do
  if node --check "$f" 2>/dev/null; then pass "node --check $(basename "$f")"; else bad "node --check $(basename "$f")"; fi
done
[ -x "$SDD" ] && pass "sdd.mjs ejecutable" || bad "sdd.mjs sin +x"
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
run --help; expect "--help sale 0" "$rc" 0; has "--help documenta verify" "verify --range A..B"; has "--help documenta branch start" "branch start fase"
run bogus; expect "comando desconocido → 2" "$rc" 2
run verify; expect "verify sin --message ni --range → 2" "$rc" 2
run trace nada; expect "trace desconocido → 2" "$rc" 2

# ---------------------------------------------------------------- 2. verify --message sobre fixtures
nv=0; for f in "$FIX"/valid/*.txt; do
  nv=$((nv + 1)); run verify --message "$f"
  if [ "$rc" = 0 ]; then pass "valid/$(basename "$f") → 0"; else bad "valid/$(basename "$f") → $rc: $out"; fi
done
ni=0; for f in "$FIX"/invalid/*.txt; do
  ni=$((ni + 1)); name=$(basename "$f" .txt); run verify --message "$f"
  case "$name" in
    prose-after-trailers|closes-in-block|coauthor-separate-paragraph) want='line 3: `Task: TASK-F2-003` is outside the trailer block' ;;
    no-type) want='is not a conventional commit' ;;
    unknown-type) want='unknown commit type `feature`' ;;
    feat-no-task) want='`feat` needs a `Task:` trailer' ;;
    test-no-task) want='`test` needs a `Task:` trailer' ;;
    refactor-no-task) want='`refactor` needs a `Task:` trailer' ;;
    fix-no-task-no-change) want='`fix` needs a `Task:` or `Change:` trailer' ;;
    perf-no-trailer) want='`perf` needs a `Task:` or `Change:` trailer' ;;
    docs-specs-no-refs) want='`docs(specs)` needs a `Refs:` trailer' ;;
    bad-task-legacy-format) want='Task `TASK-FASE-1-002` does not match' ;;
    bad-task-seq) want='Task `TASK-F1-02` does not match' ;;
    bad-refs) want='Refs `#12` is not a spec id' ;;
    bad-change) want='Change `change-1` does not match' ;;
    empty) want='empty commit message' ;;
    *) want='__sin expectativa__' ;;
  esac
  if [ "$rc" = 1 ] && contains "$out" "$want"; then pass "invalid/$name → 1 ($want)"; else bad "invalid/$name → $rc: $out"; fi
done
[ "$nv" -ge 15 ] && [ "$ni" -ge 12 ] && pass "fixtures: $nv válidos, $ni inválidos" || bad "faltan fixtures ($nv/$ni)"
run verify --message "$FIX/valid/lowercase-key.txt"; has "clave en minúsculas: warning" 'trailer key `task` should be written `Task`'
run verify --message "$FIX/valid/lowercase-key.txt" --json
expect "--json: ok y trailers normalizados" "$(js 'j.ok+" "+j.results[0].trailers.Task.join(",")+" "+j.results[0].warnings.length')" "true TASK-F2-006 2"
run verify --message "$FIX/valid/merge.txt" --json; expect "merge exento" "$(js 'j.results[0].exempt')" "merge"
run verify --message "$FIX/valid/comments-scissors.txt" --json; expect "comentarios y tijera ignorados" "$(js 'j.results[0].trailers.Task.join(",")')" "TASK-F2-009"
rc=0; out=$(printf 'feat(x): y\n\nTask: TASK-F1-001\n' | node "$SDD" verify --message - 2>&1) || rc=$?; expect "--message - lee stdin" "$rc" 0
run verify --message "$tmp/no-existe.txt"; expect "--message inexistente → 2" "$rc" 2

# ---------------------------------------------------------------- 3. trace en un repo temporal
repo="$tmp/repo"; mkdir -p "$repo/src"
git -C "$repo" init -q -b main
n=0
commit() { # commit FICHERO MENSAJE [PÁRRAFO…]  (cada argumento extra es un párrafo -m)
  local file="$1"; shift
  n=$((n + 1)); echo "line $n" >> "$repo/$file"
  git -C "$repo" add -A
  local args=(); for p in "$@"; do args+=(-m "$p"); done
  git -C "$repo" commit -q "${args[@]}"
}
commit src/a.ts "feat(a): a" "Task: TASK-F1-001
Refs: REQ-F-01, UC-001"
commit src/b.ts "feat(b): b" "Task: TASK-F1-002
Refs: REQ-F-012"
commit src/c.ts "feat(c): c" "Task: TASK-F1-003
Refs: REQ-F-03"
git -C "$repo" revert --no-edit HEAD >/dev/null
commit src/d.ts "feat(d): d" "Task: TASK-F1-004
Refs: REQ-F-04"
git -C "$repo" revert --no-edit HEAD >/dev/null
git -C "$repo" revert --no-edit HEAD >/dev/null
commit src/e.ts "feat(e): e" "Task: TASK-F1-005
Refs: REQ-F-05" "Co-Authored-By: Assistant <assistant@example.com>"
commit src/f.ts "docs(specs): f" "Refs: CR-7, REQ-F-01"
commit src/g.ts "fix(g): g" "change: CHG-2026-09-27-001"

run trace req REQ-F-01 --repo "$repo" --json
expect "REQ-F-01 no casa con REQ-F-012 (exacto)" "$(js 'j.commits.map(c=>c.subject).join(",")')" "docs(specs): f,feat(a): a"
run trace req REQ-F-012 --repo "$repo" --json; expect "REQ-F-012 solo su commit" "$(js 'j.commits.length')" 1
run trace req REQ-F-03 --repo "$repo" --json; expect "revert: REQ-F-03 sin commits efectivos" "$(js 'j.effective+" "+j.reverted')" "0 1"
expect "trace req sin efectivos → 1" "$rc" 1
run trace req REQ-F-04 --repo "$repo" --json; expect "revert de un revert: REQ-F-04 efectivo" "$(js 'j.effective+" "+j.reverted')" "1 0"
expect "trace req con efectivos → 0" "$rc" 0
run trace commits --repo "$repo" --json
cm() { js "const c=j.commits.find(x=>x.subject===\"$1\"); $2"; }
expect "legacy: Task en el cuerpo (Co-Authored-By aparte) se lee y se marca" "$(cm 'feat(e): e' 'c.tasks.join()+" "+c.legacy')" "TASK-F1-005 true"
expect "trailer normal no es legacy" "$(cm 'feat(a): a' 'c.legacy+" "+c.refs.join(",")')" "false REQ-F-01,UC-001"
expect "CR- empaquetado en Refs también es change" "$(cm 'docs(specs): f' 'c.changes.join()')" "CR-7"
expect "clave Change en minúsculas se lee" "$(cm 'fix(g): g' 'c.changes.join()')" "CHG-2026-09-27-001"
run trace commits --repo "$repo" --files --json; expect "--files lista ficheros" "$(cm 'feat(a): a' 'c.files.join()')" "src/a.ts"
run trace commits --repo "$repo"; has "trace commits texto: marca [reverted]" "feat(c): c  [reverted]"
run trace req REQ-F-05 --repo "$repo"; has "trace req texto: marca [legacy]" "[legacy]"

run trace why src/a.ts:1 --repo "$repo" --json
expect "trace why línea → ids del commit" "$(js 'j.ids.join(",")')" "TASK-F1-001,REQ-F-01,UC-001"
run trace why src/d.ts:1 --repo "$repo" --json
expect "trace why en revert de revert → ids del original" "$(js 'j.ids.join(",")')" "TASK-F1-004,REQ-F-04"
run trace why src/a.ts --repo "$repo" --json; expect "trace why fichero entero" "$(js 'j.commits.length+" "+j.ids.join(",")')" "1 TASK-F1-001,REQ-F-01,UC-001"
run trace why src/a.ts:1 --repo "$repo"; has "trace why texto" "src/a.ts:1  "

# ---------------------------------------------------------------- 4. trace delivered por tag
run trace delivered REQ-F-01 --repo "$repo" --json; expect "sin tag → no entregado (1)" "$rc:$(js 'j.delivered_in.length')" "1:0"
git -C "$repo" tag -a fase-1-verified -m "FASE-1 verified"
commit src/h.ts "feat(h): h" "Task: TASK-F2-001
Refs: REQ-F-01"
run trace delivered REQ-F-01 --repo "$repo" --json
expect "commit posterior al tag: aún no entregado entero" "$rc:$(js 'j.first.tags.join()+"|"+j.last.tags.length')" "1:fase-1-verified|0"
git -C "$repo" tag -a fase-2-verified -m "FASE-2 verified"
run trace delivered REQ-F-01 --repo "$repo" --json
expect "entregado en fase-2-verified" "$rc:$(js 'j.delivered_in.join()+" "+j.last.branches.join()')" "0:fase-2-verified main"
run trace delivered REQ-F-012 --repo "$repo"; has "delivered texto: primer tag" "in fase-1-verified, fase-2-verified (earliest fase-1-verified)"

# ---------------------------------------------------------------- 5. verify --range y squash
run verify --range "$(git -C "$repo" rev-list --max-parents=0 HEAD)..HEAD" --repo "$repo" --json
expect "range: per_task_commits" "$(js 'Object.keys(j.per_task_commits).sort().join(",")')" "TASK-F1-002,TASK-F1-003,TASK-F1-004,TASK-F2-001"
expect "range: el Task legacy (bloque roto) es error" "$(js 'j.results.filter(r=>r.errors.some(e=>e.includes("outside the trailer block"))).length')" 1
expect "range con bloque roto → 1" "$rc" 1
git -C "$repo" switch -q -c feature
commit src/s1.ts "feat(s): one" "Task: TASK-F3-001"
commit src/s2.ts "feat(s): two" "Task: TASK-F3-002"
run verify --range main..feature --repo "$repo" --json; expect "range limpio → 0" "$rc:$(js 'j.per_task_commits["TASK-F3-002"].length')" "0:1"
git -C "$repo" switch -q main
git -C "$repo" merge --squash -q feature >/dev/null
git -C "$repo" commit -q -m "build: squash feature (#3)"
run verify --range HEAD~1..HEAD --repo "$repo"
expect "squash detectado → 1" "$rc" 1; has "squash: mensaje claro" "touching code paths (src) but no Task: trailer"
printf '# P\n\n## SDD Stack Profile\n\n- code_paths: app, lib\n' > "$repo/CLAUDE.md"
run verify --range HEAD~1..HEAD --repo "$repo"; expect "code_paths del perfil: src/ ya no es código → 0" "$rc" 0
mkdir -p "$repo/app"; echo x > "$repo/app/x.rb"; git -C "$repo" add -A; git -C "$repo" commit -q -m "build: squash app (#4)"
run verify --range HEAD~1..HEAD --repo "$repo"; expect "code_paths del perfil: app/ sin Task → 1" "$rc" 1; has "squash: rutas del perfil" "(app, lib)"
git -C "$repo" merge -q --no-ff --no-commit feature >/dev/null 2>&1 || true
git -C "$repo" commit -q -m "Merge feature" --trailer "Refs: FASE-3" 2>/dev/null || git -C "$repo" commit -q -m "Merge feature" -m "Refs: FASE-3"
run verify --range HEAD~1..HEAD --repo "$repo" --json; expect "merge commit exento en rango" "$rc:$(js 'j.results[0].exempt')" "0:merge"
run verify --range nada..HEAD --repo "$repo"; expect "rango inválido → 2" "$rc" 2

# ---------------------------------------------------------------- 6. branch
b="$tmp/b"; mkdir -p "$b"
git config --global init.defaultBranch trunk
git -C "$b" init -q
echo 1 > "$b/a"; git -C "$b" add -A; git -C "$b" commit -q -m "chore: init"
run branch status --repo "$b" --json; expect "default trunk por init.defaultBranch" "$(js 'j.default+" "+j.default_source+" "+j.is_default')" "trunk init.defaultBranch true"
echo 2 >> "$b/a"
run branch start fase 3 "Billing Core" --repo "$b" --json
expect "en la rama por defecto: crea fase-3-billing-core" "$rc:$(js 'j.action+" "+j.branch')" "0:created fase-3-billing-core"
expect "HEAD en la rama nueva" "$(git -C "$b" symbolic-ref --short HEAD)" "fase-3-billing-core"
expect "los cambios sin commit se conservan" "$(git -C "$b" status --porcelain)" " M a"
run branch start change CHG-2026-09-27-001 "otra cosa" --repo "$b"
expect "en rama de trabajo: se queda" "$rc:$(git -C "$b" symbolic-ref --short HEAD)" "0:fase-3-billing-core"; has "mensaje de quedarse" "staying on work branch fase-3-billing-core"
git -C "$b" commit -q -am "chore: wip"
git -C "$b" switch -q trunk
run branch start change CHG-2026-09-27-001 "Retry Window" --issue 42 --repo "$b"
expect "--issue prefija el nombre" "$(git -C "$b" symbolic-ref --short HEAD)" "42-change/CHG-2026-09-27-001-retry-window"
git -C "$b" switch -q trunk
run branch start audit 2026-09-27 --repo "$b"; expect "audit/fix-fecha" "$(git -C "$b" symbolic-ref --short HEAD)" "audit/fix-2026-09-27"
git -C "$b" switch -q trunk
run branch start acceptance 2026-09-27 --repo "$b"; expect "acceptance/fecha" "$rc:$(git -C "$b" symbolic-ref --short HEAD)" "0:acceptance/2026-09-27"
git -C "$b" switch -q trunk
run branch start acceptance 27-09-2026 --repo "$b"; expect "acceptance con fecha mal formada → 2" "$rc" 2
run branch start fase 3 billing-core --repo "$b" --json; expect "rama existente con árbol limpio: se retoma" "$(js 'j.action')" "resumed"
git -C "$b" switch -q trunk
git -C "$b" checkout -q --detach
run branch start fase 4 x --repo "$b"; expect "HEAD suelto → 1" "$rc" 1; has "HEAD suelto: mensaje" "HEAD is detached"
expect "HEAD suelto: no se crea rama" "$(git -C "$b" branch --list 'fase-4-*')" ""
git -C "$b" switch -q trunk
run branch start fase x slug --repo "$b"; expect "fase sin número → 2" "$rc" 2
printf '# P\n\n## SDD Stack Profile\n\n- default_branch: release\n' > "$b/CLAUDE.md"
run branch status --repo "$b" --json; expect "default_branch del perfil gana" "$(js 'j.default+" "+j.default_source+" "+j.is_default')" "release profile false"
rm "$b/CLAUDE.md"
git config --global --unset init.defaultBranch
up="$tmp/up"; mkdir -p "$up"; git -C "$up" init -q -b develop
echo 1 > "$up/a"; git -C "$up" add -A; git -C "$up" commit -q -m "chore: init"
git clone -q "$up" "$tmp/clone"
git -C "$tmp/clone" branch main
run branch status --repo "$tmp/clone" --json; expect "default develop por origin/HEAD (aunque exista main)" "$(js 'j.default+" "+j.default_source')" "develop origin/HEAD"
run branch start fase 1 walking-skeleton --repo "$tmp/clone"; expect "crea desde develop" "$(git -C "$tmp/clone" symbolic-ref --short HEAD)" "fase-1-walking-skeleton"
git -C "$tmp/clone" worktree add -q "$tmp/wt" -b wt-branch >/dev/null 2>&1
run branch status --repo "$tmp/wt" --json; expect "worktree enlazado detectado" "$(js 'j.linked_worktree+" "+j.current')" "true wt-branch"

# ---------------------------------------------------------------- 7. alias sdd-task-lint.mjs = sdd lint / sdd tasks
TFIX="$ROOT/tests/fixtures/tasks"
a=$(node "$ROOT/scripts/sdd-task-lint.mjs" json "$TFIX/canonical.md"); s=$(node "$SDD" tasks json "$TFIX/canonical.md")
[ "$a" = "$s" ] && pass "alias json = sdd tasks json" || bad "alias json difiere de sdd tasks json"
rc=0; node "$SDD" lint "$TFIX/invalid.md" >/dev/null 2>&1 || rc=$?; expect "sdd lint invalid → 1" "$rc" 1
run lint "$TFIX/canonical.md"; has "sdd lint: resumen con prefijo sdd" "sdd: 1 file(s), 6 task(s), 0 error(s)"
run tasks index "$TFIX/canonical.md"; has "sdd tasks index" "| FASE-1 | Task list | 6 | 2 (33%) | 2 |"
run tasks status --repo "$repo" --dir "$TFIX/canonical.md" --json; expect "sdd tasks status en el repo de trace" "$rc" 0
run tasks nada; expect "tasks desconocido → 2" "$rc" 2

# ---------------------------------------------------------------- 8. lib: tokens exactos y errores sin exit
rc=0; out=$(cd "$ROOT/scripts/lib" && node --input-type=module -e '
import { readCommits, GitError, tokens, commitsFor } from "./git-log.mjs";
const t = tokens("REQ-F-01, UC-001;REQ-F-012 (CR-3).");
let thrown = "";
try { readCommits("/", {}); } catch (e) { thrown = e instanceof GitError ? "GitError" : "other"; }
const hits = commitsFor([{ ids: ["REQ-F-012"] }, { ids: ["REQ-F-01"] }], "REQ-F-01").length;
console.log([t.join("|"), thrown, hits].join(" "));' 2>&1) || rc=$?
expect "lib: tokens, GitError y matching exacto" "$out" "REQ-F-01|UC-001|REQ-F-012|CR-3 GitError 1"

echo
if [ "$fail" -eq 0 ]; then echo "git: todo ok"; else echo "git: hay fallos"; exit 1; fi
