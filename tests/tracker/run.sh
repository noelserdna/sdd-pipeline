#!/usr/bin/env bash
# Tests of `sdd issue open|update|close|read` and `sdd pr-body` (scripts/lib/tracker.mjs) with fake `gh` and `glab`
# on PATH (tests/tracker/stub-cli.mjs: logs argv, serves a small stateful tracker), in temporary git repos, no network.
# Covers provider detection (github remote, gitlab remote, glab-configured host, unknown host, tracker: off, no
# remote), auth failure (exit 2), open idempotency (label sdd + hidden marker), update rewriting only the
# sdd:begin/sdd:end region (human text byte for byte, CRLF included), close refused without fase-N-accepted,
# read as data, pr-body `Refs #N` for a FASE and `Closes #N` for a change, GitLab variants (MR !N), dry-run without
# write calls, and the CI / tracker templates. bash 3.2 (macOS) and bash 5 (Ubuntu CI); needs git ≥ 2.32 and node ≥ 18.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDD="$ROOT/scripts/sdd.mjs"
FIX="$ROOT/tests/fixtures/acceptance/todo"
fail=0
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
contains() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
run() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>&1) || rc=$?; }
runo() { rc=0; out=$(cd "$repo" && node "$SDD" "$@" 2>/dev/null) || rc=$?; }   # stdout only
js() { printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",(d)=>{s+=d}).on("end",()=>{const j=JSON.parse(s);process.stdout.write(String(eval(process.argv[1])))})' "$1"; }
# st EXPR → EXPR over the stub state (S = whole state, I = issues of $bin)
st() { node -e 'const fs=require("fs");const S=fs.existsSync(process.argv[1])?JSON.parse(fs.readFileSync(process.argv[1],"utf8")):{};const I=(S[process.argv[3]]||{issues:[]}).issues;process.stdout.write(String(eval(process.argv[2])))' "$STUB_STATE" "$1" "${2:-gh}"; }
expect() { if [ "$2" = "$3" ]; then pass "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has() { if contains "$out" "$2"; then pass "$1"; else bad "$1 (missing: $2)"; fi; }
hasnt() { if contains "$out" "$2"; then bad "$1 (contains: $2)"; else pass "$1"; fi; }
writes() { grep -cE ' -X (POST|PATCH|PUT|DELETE) ' "$STUB_LOG" 2>/dev/null || true; }

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
unset SDD_ROLE SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT GITLAB_HOST GH_HOST || true
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME" "$tmp/bin"
git config --global commit.gpgsign false
git config --global tag.gpgsign false
git config --global init.defaultBranch main
for b in gh glab; do
  printf '#!/usr/bin/env bash\nexec node "%s" %s "$@"\n' "$ROOT/tests/tracker/stub-cli.mjs" "$b" > "$tmp/bin/$b"
  chmod +x "$tmp/bin/$b"
done
export PATH="$tmp/bin:$PATH"
export STUB_LOG="$tmp/stub.log" STUB_STATE="$tmp/state.json"
reset_stub() { rm -f "$STUB_LOG" "$STUB_STATE"; : > "$STUB_LOG"; }

# new_repo DIR REMOTE → fixture project with a vertical FASE-1, two tasks, a change report; one task committed
new_repo() {
  repo="$1"
  mkdir -p "$repo"
  cp -R "$FIX/." "$repo/"
  cat > "$repo/plan/fases/FASE-1-core.md" <<'EOF'
# FASE 1: Create and list

> **Estado:** Implementable
> **Incremento:** Create tasks and see them listed
> **Requisitos:** REQ-F-001, REQ-F-002
> **Escenarios:** AC-001-01, AC-001-02, AC-002-01
> **Necesidades:** N-001, N-002
> **Dependencias:** Ninguna (fase inicial)

---

## Objetivo

Crear y listar tareas.

## Demo

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `todo add "Buy milk"` | task 1 pending | AC-001-01 · N-001 |
| 2 | `todo list` | `1 [ ] Buy milk` | AC-002-01 · N-002 |

## Alcance

| Incluye | Excluye |
|---------|---------|
| UC-001, UC-002 | borrar → FASE-2 |
EOF
  mkdir -p "$repo/task" "$repo/changes"
  cat > "$repo/task/TASK-FASE-1.md" <<'EOF'
# Tasks: FASE-1 — Create and list

## Slices

- [ ] TASK-F1-001 Add a task, test-first | `src/api.js`
  - **Commit:** `feat(todo): add a task`
  - **Acceptance:** AC-001-01, AC-001-02
- [ ] TASK-F1-002 List tasks in id order | `src/api.js`
  - **Commit:** `feat(todo): list tasks`
  - **Acceptance:** AC-002-01
EOF
  cat > "$repo/changes/CHANGE-REPORT-CHG-2026-09-27-001.md" <<'EOF'
# Change Report — Due dates on tasks

> **Report ID:** CHG-2026-09-27-001

## 1. Executive Summary
Tasks get an optional due date (REQ-F-002 changes its list format).

| # | CR-ID | Type | REQ-ID(s) | Category | Priority | Complexity | Status |
|---|-------|------|-----------|----------|----------|------------|--------|
| 1 | CR-001 | MODIFY | REQ-F-002 | F | Must | Low | Applied |

## 7. Context for Planning & Implementation

### 7.1 Affected FASEs
| FASE | Impact | Description |
|------|--------|-------------|
| FASE-1 | Direct | list format |
EOF
  ( cd "$repo" && git init -q && git add -A && git commit -qm "chore: fixture" \
    && echo "// add" >> src/api.js && git commit -qam "feat(todo): add a task" --trailer "Task: TASK-F1-001" )
  if [ -n "${2:-}" ]; then ( cd "$repo" && git remote add origin "$2" ); fi
}

# ---------------------------------------------------------------- 1. syntax and help
for f in scripts/sdd.mjs scripts/lib/tracker.mjs tests/tracker/stub-cli.mjs; do
  if node --check "$ROOT/$f" 2>/dev/null; then pass "node --check $f"; else bad "node --check $f"; fi
done
bash -n "$0" && pass "bash -n run.sh" || bad "bash -n run.sh"
repo="$tmp"
run --help
has "--help documents issue open" "sdd issue open   fase <N>"
has "--help documents pr-body" "sdd pr-body [--fase N | --change ID] [--issue N]"
run issue --help; expect "issue --help exits 0" "$rc" 0

# ---------------------------------------------------------------- 2. provider detection
reset_stub
new_repo "$tmp/gh" "git@github.com:acme/todo.git"
run issue open fase 1 --dry-run --json
expect "github remote → exit 0" "$rc" 0
expect "github remote → provider github" "$(js 'j.provider')" github
contains "$(cat "$STUB_LOG")" "gh api -X GET repos/acme/todo/issues?labels=sdd" && pass "github: lists issues with label sdd" || bad "github: list call ($(cat "$STUB_LOG"))"

new_repo "$tmp/gl" "https://gitlab.com/acme/sub/todo.git"
run issue open fase 1 --dry-run --json
expect "gitlab.com remote → provider gitlab" "$(js 'j.provider')" gitlab
contains "$(cat "$STUB_LOG")" "glab api -X GET projects/acme%2Fsub%2Ftodo/issues" && pass "gitlab: project path url-encoded" || bad "gitlab: list call"

new_repo "$tmp/self" "ssh://git@git.acme.io:2222/team/todo.git"
run issue open fase 1 --dry-run --json
expect "unknown host → exit 3" "$rc" 3
has "unknown host → tracker disabled" "tracker disabled"
rc=0; out=$(cd "$repo" && STUB_GLAB_HOST=git.acme.io node "$SDD" issue open fase 1 --dry-run --json 2>/dev/null) || rc=$?
expect "host configured in glab → gitlab" "$(js 'j.provider')" gitlab
contains "$(cat "$STUB_LOG")" "glab api --hostname git.acme.io" && pass "self-hosted gitlab: --hostname passed" || bad "self-hosted: --hostname"
printf '# p\n\n## SDD Stack Profile\n- tracker: github\n' > "$repo/CLAUDE.md"
run issue open fase 1 --dry-run --json
expect "profile tracker: github overrides the host" "$(js 'j.provider')" github

new_repo "$tmp/off" "git@github.com:acme/todo.git"
printf '# p\n\n## SDD Stack Profile\n- task_state: trailers\n- tracker: off\n' > "$repo/CLAUDE.md"
: > "$STUB_LOG"
run issue open fase 1
expect "tracker: off → exit 3" "$rc" 3
has "tracker: off → message" "tracker disabled"
expect "tracker: off → no CLI call" "$(wc -l < "$STUB_LOG" | tr -d ' ')" 0

new_repo "$tmp/noremote" ""
run issue update fase 1
expect "no remote → exit 3" "$rc" 3
has "no remote → reason" "no origin remote"

# ---------------------------------------------------------------- 3. auth
repo="$tmp/gh"
rc=0; out=$(cd "$repo" && STUB_AUTH_FAIL=1 node "$SDD" issue open fase 1 2>&1) || rc=$?
expect "not authenticated → exit 2" "$rc" 2
has "not authenticated → hint" "gh auth login"
rc=0; out=$(cd "$repo" && PATH="/usr/bin:/bin" "$(command -v node)" "$SDD" issue open fase 1 2>&1) || rc=$?
expect "gh not installed → exit 2" "$rc" 2
has "gh not installed → hint" "not installed"

# ---------------------------------------------------------------- 4. open: create once, then find (GitHub)
reset_stub
repo="$tmp/gh"
run issue open fase 1 --dry-run
expect "dry-run open → exit 0" "$rc" 0
has "dry-run open → would create" 'would create issue "FASE-1: Create tasks and see them listed"'
expect "dry-run open → no write call" "$(writes)" 0
expect "dry-run open → no issue created" "$(st 'I.length')" 0
run issue open fase 1 --json
expect "open → created" "$(js 'j.action')" created
expect "open → issue #1" "$(js 'j.number')" 1
expect "open → labels sdd + sdd:fase" "$(st 'I[0].labels.join(",")')" "sdd,sdd:fase"
expect "open → title from Incremento" "$(st 'I[0].title')" "FASE-1: Create tasks and see them listed"
body="$(st 'I[0].body')"
contains "$body" "<!-- sdd:FASE-1 -->" && pass "body has the hidden marker" || bad "marker"
contains "$body" "<!-- sdd:begin -->" && contains "$body" "<!-- sdd:end -->" && pass "body has the generated region" || bad "region"
contains "$body" '| 1 | `todo add "Buy milk"` | task 1 pending | AC-001-01 · N-001 |' && pass "body has the Demo table" || bad "demo table"
contains "$body" "**Needs:** N-001, N-002" && pass "body has Necesidades" || bad "needs"
contains "$body" "- [x] TASK-F1-001 Add a task, test-first" && pass "region: task done by trailer is checked" || bad "task checked ($body)"
contains "$body" "- [ ] TASK-F1-002" && pass "region: pending task unchecked" || bad "task unchecked"
contains "$body" "| REQ-F-001 Create a task | Must | MISSING | 0/2 |" && pass "region: verdict per requirement" || bad "verdicts ($body)"
hasnt "region: requirement outside the FASE absent" "REQ-F-005 Delete"
contains "$body" "FASE acceptance: pending" && pass "region: demo status pending" || bad "demo pending"
run issue open fase 1
expect "open again → exit 0" "$rc" 0
has "open again → finds the existing issue" "already has issue #1"
expect "open again → still one issue" "$(st 'I.length')" 1
# a foreign issue with label sdd but another marker, and a PR in the list, are not matched
node -e 'const f=process.argv[1],S=JSON.parse(require("fs").readFileSync(f,"utf8"));S.gh.issues.unshift({n:99,title:"x",body:"<!-- sdd:FASE-10 -->",labels:["sdd"],state:"open"},{n:98,title:"pr",body:"<!-- sdd:FASE-1 -->",labels:["sdd"],state:"open",pr:true});require("fs").writeFileSync(f,JSON.stringify(S))' "$STUB_STATE"
run issue open fase 1 --json
expect "FASE-10 marker and PRs do not match FASE-1" "$(js 'j.number')" 1

# ---------------------------------------------------------------- 5. update: only the region
node -e 'const f=process.argv[1],S=JSON.parse(require("fs").readFileSync(f,"utf8"));const i=S.gh.issues.find((x)=>x.n===1);
i.body="Customer note before.\r\n\r\n"+i.body.replace("<!-- sdd:begin -->","<!-- sdd:begin -->\nSTALE TEXT")+"\r\nHuman text after — keep *exactly*.\r\n";require("fs").writeFileSync(f,JSON.stringify(S))' "$STUB_STATE"
before="$(st 'const b=I.find((x)=>x.n===1).body; JSON.stringify([b.slice(0,b.indexOf("<!-- sdd:begin -->")), b.slice(b.indexOf("<!-- sdd:end -->"))])')"
( cd "$repo" && echo "// list" >> src/api.js && git commit -qam "feat(todo): list tasks" --trailer "Task: TASK-F1-002" )
: > "$STUB_LOG"
run issue update fase 1 --dry-run
has "dry-run update → would update" "would update #1"
expect "dry-run update → no write call" "$(writes)" 0
run issue update fase 1
expect "update → exit 0" "$rc" 0
has "update → updated" "updated #1"
after="$(st 'const b=I.find((x)=>x.n===1).body; JSON.stringify([b.slice(0,b.indexOf("<!-- sdd:begin -->")), b.slice(b.indexOf("<!-- sdd:end -->"))])')"
expect "update → human text outside the region byte for byte (CRLF too)" "$after" "$before"
body="$(st 'I.find((x)=>x.n===1).body')"
hasnt_body() { if contains "$body" "$2"; then bad "$1"; else pass "$1"; fi; }
hasnt_body "update → stale text inside the region replaced" "STALE TEXT"
contains "$body" "- [x] TASK-F1-002" && pass "update → newly done task checked" || bad "update: task 2"
: > "$STUB_LOG"
run issue update fase 1
has "update again → already up to date" "already up to date"
expect "update again → no write call" "$(writes)" 0
# branch + PR link
( cd "$repo" && git branch fase-1-core )
node -e 'const f=process.argv[1],S=JSON.parse(require("fs").readFileSync(f,"utf8"));S.gh.pulls=[{n:7,branch:"fase-1-core"}];require("fs").writeFileSync(f,JSON.stringify(S))' "$STUB_STATE"
run issue update fase 1
body="$(st 'I.find((x)=>x.n===1).body')"
contains "$body" '**Branch:** `fase-1-core` · PR #7 (open)' && pass "update → branch and PR link" || bad "PR link ($body)"
run issue update fase 3
expect "update without an issue → exit 1" "$rc" 1

# ---------------------------------------------------------------- 6. close
: > "$STUB_LOG"
run issue close fase 1
expect "close without fase-1-accepted → exit 1" "$rc" 1
has "close without tag → reason" "fase-1-accepted does not exist"
expect "close without tag → no CLI call" "$(wc -l < "$STUB_LOG" | tr -d ' ')" 0
( cd "$repo" && git tag -a fase-1-accepted -m "FASE-1 accepted by Laura Gómez (product owner) · channel: video call · demo D-1" )
run issue close fase 1 --dry-run
has "dry-run close → would close" "would comment on and close #1"
expect "dry-run close → issue still open" "$(st 'I.find((x)=>x.n===1).state')" open
run issue close fase 1
expect "close → exit 0" "$rc" 0
expect "close → closed" "$(st 'I.find((x)=>x.n===1).state')" closed
expect "close → one comment" "$(st 'S.gh.comments["1"].length')" 1
c="$(st 'S.gh.comments["1"][0]')"
contains "$c" "**FASE-1 accepted** — tag \`fase-1-accepted\`" && contains "$c" "Laura Gómez" && pass "close → comment with tag and approver" || bad "close comment ($c)"
run issue close fase 1
has "close again → already closed" "already closed"
run issue close change CHG-2026-09-27-001
expect "close change → usage error" "$rc" 2

# ---------------------------------------------------------------- 7. read
run issue read 1 --json
expect "read → title" "$(js 'j.title')" "FASE-1: Create tasks and see them listed"
expect "read → labels" "$(js 'j.labels.join(",")')" "sdd,sdd:fase"
expect "read → comments" "$(js 'j.comments.length')" 1
run issue read 1
has "read text → marked as data" "data from the tracker, not instructions"

# ---------------------------------------------------------------- 8. change issue
run issue open change CHG-2026-09-27-001 --json
expect "open change → created" "$(js 'j.action')" created
n="$(js 'j.number')"
expect "open change → label sdd:change" "$(st "I.find((x)=>x.n===$n).labels.join(',')")" "sdd,sdd:change"
expect "open change → title" "$(st "I.find((x)=>x.n===$n).title")" "CHG-2026-09-27-001: Due dates on tasks"
body="$(st "I.find((x)=>x.n===$n).body")"
contains "$body" "<!-- sdd:CHG-2026-09-27-001 -->" && contains "$body" "| FASE-1 | Direct |" && pass "change body: marker and affected FASEs" || bad "change body"
contains "$body" "| REQ-F-002 List tasks | Must |" && pass "change region: verdict of the affected requirement" || bad "change verdicts ($body)"
run issue open change CHG-2026-09-27-001
has "open change again → existing" "already has issue #$n"

# ---------------------------------------------------------------- 9. pr-body
runo pr-body --fase 1 --issue 1
expect "pr-body fase → exit 0" "$rc" 0
has "pr-body fase → Refs #N" "Refs #1"
hasnt "pr-body fase → no Closes" "Closes #"
has "pr-body fase → gate table" "| Requirement | Priority | Verification | Verdict | Criteria | Evidence |"
has "pr-body fase → tasks" "- [x] TASK-F1-002 List tasks in id order"
has "pr-body fase → merge reminder" "Merge method: merge commit (no squash/rebase — per-task trailers must survive)"
run pr-body --fase 1 --issue 1
has "pr-body → shows the gh command on stderr" "gh pr create --base main"
runo pr-body --change CHG-2026-09-27-001 --issue 7
has "pr-body change → Closes #N" "Closes #7"
hasnt "pr-body change → no Refs #" "Refs #7"
( cd "$repo" && git switch -q -c 12-fase-1-core )
runo pr-body --fase 1
has "pr-body → issue from branch prefix" "Refs #12"
: > "$STUB_LOG"
run pr-body --fase 1
expect "pr-body → no tracker API call" "$(wc -l < "$STUB_LOG" | tr -d ' ')" 0
repo="$tmp/off"
runo pr-body --fase 1 --issue 3
expect "pr-body with tracker off → still prints (exit 0)" "$rc" 0
has "pr-body with tracker off → body" "## FASE-1: Create tasks and see them listed"

# ---------------------------------------------------------------- 10. GitLab variants
reset_stub
repo="$tmp/gl"
run issue open fase 1 --json
expect "gitlab open → created #1" "$(js 'j.number')" 1
contains "$(cat "$STUB_LOG")" "glab api -X POST projects/acme%2Fsub%2Ftodo/issues -H Content-Type: application/json --input -" && pass "gitlab open → POST issues" || bad "gitlab POST ($(cat "$STUB_LOG"))"
expect "gitlab open → labels" "$(st 'I[0].labels.join(",")' glab)" "sdd,sdd:fase"
run issue open fase 1
has "gitlab open again → existing" "already has issue #1"
expect "gitlab → one issue" "$(st 'I.length' glab)" 1
( cd "$repo" && git branch 1-fase-1-core )
node -e 'const f=process.argv[1],S=JSON.parse(require("fs").readFileSync(f,"utf8"));S.glab.pulls=[{n:5,branch:"1-fase-1-core"}];const i=S.glab.issues[0];i.body="Mine.\n"+i.body+"Also mine.\n";require("fs").writeFileSync(f,JSON.stringify(S))' "$STUB_STATE"
run issue update fase 1
body="$(st 'I[0].body' glab)"
contains "$body" '`1-fase-1-core` · MR !5 (open)' && pass "gitlab update → MR !N link" || bad "gitlab MR link ($body)"
case "$body" in "Mine."*"Also mine.") pass "gitlab update → human text kept" ;; *) bad "gitlab human text" ;; esac
contains "$(cat "$STUB_LOG")" "glab api -X PUT projects/acme%2Fsub%2Ftodo/issues/1" && pass "gitlab update → PUT" || bad "gitlab PUT"
( cd "$repo" && git tag -a fase-1-accepted -m "accepted" )
run issue close fase 1
expect "gitlab close → closed" "$(st 'I[0].state' glab)" closed
contains "$(cat "$STUB_LOG")" "issues/1/notes" && pass "gitlab close → note" || bad "gitlab note"
run pr-body --change CHG-2026-09-27-001 --issue 4
has "gitlab pr-body change → Closes #N" "Closes #4"
has "gitlab pr-body → glab mr create" "glab mr create --target-branch"

# ---------------------------------------------------------------- 11. CI and tracker templates
GHY="$ROOT/templates/ci/github/sdd.yml"; GLY="$ROOT/templates/ci/gitlab/sdd.gitlab-ci.yml"
yaml_ok() {
  if python3 -c 'import yaml' 2>/dev/null; then python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$1"
  elif command -v ruby >/dev/null 2>&1; then ruby -ryaml -e 'YAML.safe_load(File.read(ARGV[0]))' "$1"
  else grep -q '^[a-z_]*:' "$1"; fi
}
for y in "$GHY" "$GLY"; do
  if yaml_ok "$y" >/dev/null 2>&1; then pass "yaml parses: ${y#$ROOT/}"; else bad "yaml parse: ${y#$ROOT/}"; fi
done
for k in "fetch-depth: 0" "actions/setup-node" 'verify --range "origin/${BASE_REF}..HEAD"' ".claude/sdd/sdd.mjs lint --plan" "gate --mode warn" "pull_request:" "jobs:"; do
  grep -qF -- "$k" "$GHY" && pass "github ci: $k" || bad "github ci: $k"
done
for k in 'GIT_DEPTH: "0"' 'verify --range "${CI_MERGE_REQUEST_DIFF_BASE_SHA}..HEAD"' ".claude/sdd/sdd.mjs lint --plan" "gate --mode warn" "merge_request_event"; do
  grep -qF -- "$k" "$GLY" && pass "gitlab ci: $k" || bad "gitlab ci: $k"
done
for f in github/pull_request_template.md github/ISSUE_TEMPLATE/change-request.md gitlab/merge_request_templates/Default.md gitlab/issue_templates/Change-request.md; do
  [ -s "$ROOT/templates/tracker/$f" ] && pass "template exists: $f" || bad "template missing: $f"
done
grep -qF "Merge method: merge commit" "$ROOT/templates/tracker/github/pull_request_template.md" && grep -qF "Merge method: merge commit" "$ROOT/templates/tracker/gitlab/merge_request_templates/Default.md" \
  && pass "PR/MR templates carry the merge-commit reminder" || bad "merge reminder in templates"
grep -qF "sdd-req-change --issue" "$ROOT/templates/tracker/github/ISSUE_TEMPLATE/change-request.md" && pass "change-request template points to sdd-req-change --issue" || bad "change-request template"

echo
if [ "$fail" -eq 0 ]; then echo "tracker: all tests passed"; else echo "tracker: FAILURES"; fi
exit "$fail"
