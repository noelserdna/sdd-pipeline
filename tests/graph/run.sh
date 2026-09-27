#!/usr/bin/env bash
# Tests del grafo de trazabilidad: scripts/sdd-graph.py (commits, rangos, refs, Stack Profile, clasificador,
# auditorías) y el parser de resultados (scripts/test-result-parser.py):
# detección de runner (vitest, minitest, rspec; app_dir del SDD Stack Profile), parsers de Minitest verbose,
# RSpec JSON y Vitest JSON, normalización de IDs con guiones bajos y la CLI de punta a punta.
# Solo python3 (stdlib). Fixtures en tests/fixtures/test-results/. Compatible con bash 3.2.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARSER="$ROOT/scripts/test-result-parser.py"
FIX="$ROOT/tests/fixtures/test-results"
unset SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR || true

if ! command -v python3 >/dev/null 2>&1; then echo "skip tests/graph: python3 no disponible"; exit 0; fi

tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

if PYTHONDONTWRITEBYTECODE=1 python3 - "$PARSER" "$FIX" "$tmp" <<'PY'
import importlib.util
import json
import os
import shutil
import subprocess
import sys

parser_path, fix, tmp = sys.argv[1:4]
spec = importlib.util.spec_from_file_location("test_result_parser", parser_path)
trp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trp)

fails = 0


def check(desc, cond, detail=""):
    global fails
    if cond:
        print("ok   " + desc)
    else:
        fails += 1
        print("FAIL " + desc + (f" ({detail})" if detail else ""))


def project(name, files):
    """files: {ruta: contenido | None (directorio)}"""
    root = os.path.join(tmp, name)
    os.makedirs(root, exist_ok=True)
    for rel, content in files.items():
        p = os.path.join(root, rel)
        if content is None:
            os.makedirs(p, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(content)
    return root


PROFILE_WEB = """# App

```
## SDD Stack Profile
- app_dir: dentro-de-un-fence
```

## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=rails -->
- stack: rails
- app_dir: web   # comentario
- test: bin/rails test

## Otra sección
- app_dir: nunca
"""

# ── read_app_dir ─────────────────────────────────────────────────────────────
p = project("profile", {"CLAUDE.md": PROFILE_WEB})
check("read_app_dir: lee la sección del perfil, ignora fences y comentarios", trp.read_app_dir(p) == "web", trp.read_app_dir(p))
p = project("profile-fence-only", {"CLAUDE.md": "# App\n\n```\n## SDD Stack Profile\n- app_dir: web\n```\n"})
check("read_app_dir: un perfil dentro de un fence no cuenta", trp.read_app_dir(p) == ".")
p = project("profile-none", {"README.md": "x"})
check("read_app_dir: sin CLAUDE.md → '.'", trp.read_app_dir(p) == ".")
p = project("profile-dotslash", {"CLAUDE.md": "## SDD Stack Profile\n- app_dir: ./web/\n"})
check("read_app_dir: normaliza ./web/ → web", trp.read_app_dir(p) == "web")

# ── detect_runner ────────────────────────────────────────────────────────────
p = project("rails-web", {
    "CLAUDE.md": PROFILE_WEB, "spec/use-cases/UC-001.md": "# UC", "test/TEST-PLAN.md": "# plan",
    "web/Gemfile": 'source "https://rubygems.org"\ngem "rails", "~> 8.1.0"\n', "web/test/models": None,
})
check("detect_runner: minitest en el app_dir del perfil (web/Gemfile + web/test/)", trp.detect_runner(p) == "minitest", trp.detect_runner(p))
p = project("rails-root", {"Gemfile": 'gem "rails"\n', "test": None})
check("detect_runner: minitest en la raíz", trp.detect_runner(p) == "minitest", trp.detect_runner(p))
p = project("minitest-gem", {"Gemfile": 'gem "minitest"\n', "test": None})
check("detect_runner: minitest sin rails", trp.detect_runner(p) == "minitest", trp.detect_runner(p))
p = project("sdd-spec-dir", {"Gemfile": 'gem "rails"\n', "spec/domain/01-GLOSSARY.md": "# G"})
check("detect_runner: spec/ del SDD no es RSpec (sin .rspec ni rails_helper.rb)", trp.detect_runner(p) is None, trp.detect_runner(p))
p = project("gemfile-other", {"Gemfile": 'gem "sinatra"\n', "test": None})
check("detect_runner: Gemfile sin rails/minitest → None", trp.detect_runner(p) is None, trp.detect_runner(p))
p = project("rspec-dotfile", {"Gemfile": 'gem "rails"\n', ".rspec": "--require spec_helper\n", "test": None})
check("detect_runner: .rspec → rspec (antes que minitest)", trp.detect_runner(p) == "rspec", trp.detect_runner(p))
p = project("rspec-helper", {"CLAUDE.md": PROFILE_WEB, "web/Gemfile": 'gem "rails"\n', "web/spec/rails_helper.rb": "# rspec\n"})
check("detect_runner: web/spec/rails_helper.rb → rspec", trp.detect_runner(p) == "rspec", trp.detect_runner(p))
p = project("vitest-app", {"CLAUDE.md": "## SDD Stack Profile\n- app_dir: app\n", "package.json": '{"devDependencies": {"@playwright/test": "1"}}', "app/vitest.config.ts": "export default {}\n"})
check("detect_runner: vitest en el app_dir aunque la raíz tenga otro package.json", trp.detect_runner(p) == "vitest", trp.detect_runner(p))
p = project("vitest-root", {"package.json": '{"devDependencies": {"vitest": "3"}}'})
check("detect_runner: vitest por devDependencies en la raíz (sin cambios)", trp.detect_runner(p) == "vitest", trp.detect_runner(p))

# ── normalize_ids ────────────────────────────────────────────────────────────
n = trp.normalize_ids("TodoTest#test_BDD_UC_001_01_rejects_blank AC_001_02 TASK_F1_004 REQ_F_004 keep_this")
check("normalize_ids: BDD_UC_001_01 → BDD-UC-001-01", "BDD-UC-001-01_rejects_blank" in n, n)
check("normalize_ids: AC_001_02, TASK_F1_004, REQ_F_004 con guiones", all(x in n for x in ("AC-001-02", "TASK-F1-004", "REQ-F-004")), n)
check("normalize_ids: no toca palabras en minúscula", n.endswith("keep_this"), n)

# ── parse_minitest_text ──────────────────────────────────────────────────────
p = project("mt", {
    "CLAUDE.md": PROFILE_WEB, "web/Gemfile": 'gem "rails"\n',
    "web/test/models/todo_test.rb": "# Refs: REQ-F-001\nclass TodoTest < ActiveSupport::TestCase\nend\n",
    "web/test/admin/reports_test.rb": "class Admin::ReportsTest < ActiveSupport::TestCase\nend\n",
})
with open(os.path.join(fix, "minitest-verbose.txt"), encoding="utf-8") as f:
    text = f.read()
results, summary = trp.parse_minitest_text(text, p, "web")
check("minitest: 6 resultados", len(results) == 6, len(results))
check("minitest: resumen de la línea final (6 runs, 2 fallidos = failures + errors, 1 skip)",
      summary == {"total": 6, "passed": 3, "failed": 2, "skipped": 1}, summary)
by = {r["testName"].split("#", 1)[1]: r for r in results}
fail_t = by.get("test_AC_001_02_redirects_with_see_other_after_create", {})
err_t = by.get("test_TASK_F1_004_completes_a_todo", {})
check("minitest: F → fail con fichero de la cabecera [file:line] bajo app_dir",
      fail_t.get("status") == "fail" and fail_t.get("file") == "web/test/controllers/todos_controller_test.rb", fail_t)
check("minitest: E → fail con fichero de la línea 'bin/rails test file:line'",
      err_t.get("status") == "fail" and err_t.get("file") == "web/test/controllers/completions_controller_test.rb", err_t)
check("minitest: S → skip; Admin::ReportsTest → web/test/admin/reports_test.rb",
      by.get("test_exports_csv", {}).get("status") == "skip" and by["test_exports_csv"]["file"] == "web/test/admin/reports_test.rb", by.get("test_exports_csv"))
check("minitest: fichero deducido del nombre de clase (TodoTest)", by["test_BDD_UC_001_01_rejects_a_blank_title"]["file"] == "web/test/models/todo_test.rb")
check("minitest: duración en ms", fail_t.get("duration") == 50, fail_t.get("duration"))
trp.map_artifact_refs(results, p, "web")
refs = {r["testName"].split("#", 1)[1]: r["artifactRefs"] for r in results}
check("refs: BDD_UC_001_01 del nombre + REQ-F-001 del comentario Refs: del fichero",
      refs["test_BDD_UC_001_01_rejects_a_blank_title"] == ["BDD-UC-001-01", "REQ-F-001"], refs["test_BDD_UC_001_01_rejects_a_blank_title"])
check("refs: nombre ya con guiones (test_BDD-UC-001-02_...)", "BDD-UC-001-02" in refs["test_BDD-UC-001-02_normalizes_the_title"])
check("refs: AC_001_02 → AC-001-02 y TASK_F1_004 → TASK-F1-004",
      refs["test_AC_001_02_redirects_with_see_other_after_create"] == ["AC-001-02"] and refs["test_TASK_F1_004_completes_a_todo"] == ["TASK-F1-004"], refs)
_, s2 = trp.parse_minitest_text("TodoTest#test_a = 0.00 s = .\nTodoTest#test_b = 0.10 s = F\n")
check("minitest: sin línea de resumen cuenta las líneas", s2 == {"total": 2, "passed": 1, "failed": 1, "skipped": 0}, s2)

# ── parse_rspec_json ─────────────────────────────────────────────────────────
with open(os.path.join(fix, "rspec.json"), encoding="utf-8") as f:
    raw = json.load(f)
results, summary = trp.parse_rspec_json(raw, "web")
check("rspec: resumen 3 / 1 / 1 / 1", summary == {"total": 3, "passed": 1, "failed": 1, "skipped": 1}, summary)
check("rspec: file_path relativo al app_dir (sin ./)", results[0]["file"] == "web/spec/models/todo_spec.rb", results[0]["file"])
check("rspec: pending → skip, run_time → ms", results[2]["status"] == "skip" and results[1]["duration"] == 45, results)
trp.map_artifact_refs(results, p, "web")
check("rspec: refs del full_description (BDD-UC-002-01, AC_002_03 normalizado)",
      results[0]["artifactRefs"] == ["BDD-UC-002-01"] and results[1]["artifactRefs"] == ["AC-002-03"], [r["artifactRefs"] for r in results])

# ── parse_vitest_jest (regresión) ────────────────────────────────────────────
with open(os.path.join(fix, "vitest.json"), encoding="utf-8") as f:
    raw = json.load(f)
results, summary = trp.parse_vitest_jest(raw, "vitest")
check("vitest: resumen 3 / 1 / 1 / 1", summary == {"total": 3, "passed": 1, "failed": 1, "skipped": 1}, summary)
check("vitest: ruta recortada a src/", results[0]["file"] == "src/domain/todo.test.ts", results[0]["file"])
trp.map_artifact_refs(results, p)
check("vitest: refs BDD-UC-001-01 y AC-001-02", results[0]["artifactRefs"] == ["BDD-UC-001-01"] and results[1]["artifactRefs"] == ["AC-001-02"], [r["artifactRefs"] for r in results])

# ── CLI ──────────────────────────────────────────────────────────────────────
def cli(*args):
    r = subprocess.run([sys.executable, parser_path] + list(args), capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr

out = os.path.join(tmp, "mapped.json")
rc, log = cli("--project", p, "--runner", "minitest", "--input", os.path.join(fix, "minitest-verbose.txt"), "--output", out)
data = json.load(open(out, encoding="utf-8")) if rc == 0 and os.path.exists(out) else {}
check("cli --runner minitest: exit 0 y salida sdd-test-results-v1",
      rc == 0 and data.get("$schema") == "sdd-test-results-v1" and data.get("runner") == "minitest" and data.get("appDir") == "web", log[-400:])
check("cli: summary en la salida", data.get("summary") == {"total": 6, "passed": 3, "failed": 2, "skipped": 1}, data.get("summary"))

os.makedirs(os.path.join(p, ".sdd"), exist_ok=True)
shutil.copy(os.path.join(fix, "minitest-verbose.txt"), os.path.join(p, ".sdd", "test-results-raw.txt"))
rc, log = cli("--project", p)
check("cli auto: detecta minitest y lee .sdd/test-results-raw.txt por defecto", rc == 0 and "Runner: minitest (auto-detected)" in log, log[-400:])

p2 = project("mt-no-input", {"CLAUDE.md": PROFILE_WEB, "web/Gemfile": 'gem "rails"\n', "web/test": None})
rc, log = cli("--project", p2)
check("cli sin resultados: exit 1 con el comando desde el app_dir",
      rc == 1 and "(cd web && bin/rails test -v > ../.sdd/test-results-raw.txt)" in log, log[-400:])

rc, log = cli("--project", p2, "--runner", "nope")
check("cli: --runner desconocido rechazado por argparse", rc != 0)

sys.exit(1 if fails else 0)
PY
then
  parser_ok=1
else
  parser_ok=0
fi

# ── sdd-graph.py ─────────────────────────────────────────────────────────────
GEN="$ROOT/scripts/sdd-graph.py"
if PYTHONDONTWRITEBYTECODE=1 python3 - "$GEN" "$tmp" <<'PY2'
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
from contextlib import redirect_stdout, redirect_stderr

gen_path, tmp = sys.argv[1:3]
spec = importlib.util.spec_from_file_location("sdd_generate", gen_path)
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

fails = 0


def check(desc, cond, detail=""):
    global fails
    if cond:
        print("ok   " + desc)
    else:
        fails += 1
        print("FAIL " + desc + (f" ({detail})" if detail else ""))


def write(root, files):
    for rel, content in files.items():
        p = os.path.join(root, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            f.write(content)


def git(root, *args):
    env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", HOME=tmp, GIT_AUTHOR_DATE="", GIT_COMMITTER_DATE="")
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "core.hooksPath=/dev/null",
                           "-c", "commit.gpgsign=false"] + list(args),
                          cwd=root, capture_output=True, text=True, env=env, check=True).stdout


def quiet(fn, *a, **kw):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        r = fn(*a, **kw)
    return r, out.getvalue(), err.getvalue()


def new_repo(name):
    root = os.path.join(tmp, name)
    os.makedirs(root)
    git(root, "init", "-q")
    return root


def commit(root, files, subject, body, date):
    write(root, files)
    git(root, "add", "-A")
    env_date = f"{date} +0000"
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "core.hooksPath=/dev/null",
                    "-c", "commit.gpgsign=false", "commit", "-q", "-m", subject, "-m", body],
                   cwd=root, check=True, capture_output=True,
                   env=dict(os.environ, GIT_CONFIG_NOSYSTEM="1", HOME=tmp,
                            GIT_AUTHOR_DATE=env_date, GIT_COMMITTER_DATE=env_date))


# ── 1. commit parser: 3 commits, files belong to their own commit ───────────
repo = new_repo("commits")
for i in (1, 2, 3):
    commit(repo, {f"src/f{i}.ts": f"export const f{i} = {i}\n"}, f"feat: step {i}",
           f"Refs: UC-00{i}, REQ-F-00{i}\nTask: TASK-F1-00{i}", f"2026-01-0{i}T10:00:00")
commits, _, _ = quiet(gen.scan_commits, repo)
by_task = {c["taskId"]: c for c in commits}
check("commits: los 3 commits se parsean", len(commits) == 3, [c.get("taskId") for c in commits])
check("commits: cada commit lleva solo sus ficheros",
      all(by_task.get(f"TASK-F1-00{i}", {}).get("files") == [f"src/f{i}.ts"] for i in (1, 2, 3)),
      {k: v["files"] for k, v in by_task.items()})
check("commits: refIds del trailer Refs",
      by_task.get("TASK-F1-002", {}).get("refIds") == ["UC-002", "REQ-F-002"], by_task.get("TASK-F1-002"))
check("commits: fullSha de 40 hex y el Task no aparece como fichero",
      all(re.fullmatch(r"[0-9a-f]{40}", c["fullSha"]) for c in commits)
      and not any("TASK-" in f for c in commits for f in c["files"]), [c["fullSha"] for c in commits])

# body fallback: Refs:/Task: that are not formal trailers (text after them)
repo_b = new_repo("commits-body")
for i in (1, 2):
    commit(repo_b, {f"lib/g{i}.rb": "x\n"}, f"feat: g{i}",
           f"Refs: UC-01{i}\nTask: TASK-F2-00{i}\n\nMore prose after the trailers.", f"2026-02-0{i}T10:00:00")
fb, _, _ = quiet(gen._scan_commits_body_fallback, repo_b)
fbt = {c["taskId"]: c for c in fb}
check("commits body fallback: ficheros y refs por commit",
      len(fb) == 2 and fbt.get("TASK-F2-001", {}).get("files") == ["lib/g1.rb"]
      and fbt.get("TASK-F2-002", {}).get("refIds") == ["UC-012"], fb)

# ── 3. expand_ranges ────────────────────────────────────────────────────────
er = gen.expand_ranges
check("ranges: 'NFR-001 — 150 ms p95' no inventa IDs", er("NFR-001 — 150 ms p95") == "NFR-001 — 150 ms p95")
check("ranges: 'REQ-F-001 - 120 req/s' no inventa IDs", er("REQ-F-001 - 120 req/s") == "REQ-F-001 - 120 req/s")
check("ranges: 'REQ-F-007 a REQ-F-009' se expande", er("REQ-F-007 a REQ-F-009") == "REQ-F-007, REQ-F-008, REQ-F-009", er("REQ-F-007 a REQ-F-009"))
check("ranges: 'UC-001 – UC-003' se expande", er("UC-001 – UC-003") == "UC-001, UC-002, UC-003")
check("ranges: 'INV-SEC-001..003' (fin sin prefijo) se expande", er("INV-SEC-001..003") == "INV-SEC-001, INV-SEC-002, INV-SEC-003")
check("ranges: 'UC-001 a 005' (sin prefijo repetido) no se expande", er("UC-001 a 005") == "UC-001 a 005")

# ── Full project fixture ─────────────────────────────────────────────────────
proj = new_repo("proj")
write(proj, {
    "CLAUDE.md": "# P\n\n## SDD Stack Profile\n<!-- sdd-stack-profile v1 kit=rails -->\n- stack: rails\n- app_dir: web\n"
                 "- code_paths: web/app, web/lib   # code\n- test_paths: web/test\n",
    "web/Gemfile": 'gem "rails"\n',
    "requirements/REQUIREMENTS.md": (
        "# Requirements\n\n## 3. Functional Requirements\n\n### 3.1 Authentication\n\n"
        "### REQ-F-001: The system shall require a login\n\n"
        "## Functional Requirements\n\n### REQ-F-002: Catalog performance requirement\n"
        "Latency NFR-001 — 150 ms p95. Uses a BDD-style approach and is API-first.\n"),
    "spec/use-cases/UC-001-login.md": "# UC-001: Login\n\nRefs: REQ-F-001\nContract: API-auth\n",
    "spec/use-cases/UC-002-browse.md": "# UC-002: Browse\n\nRefs: REQ-F-002\n",
    "spec/contracts/API-auth.md": "# API-auth\n\n| API-001-01 | Login | UC-001 |\n",
    "spec/nfr/PERFORMANCE.md": "| NFR-001 | p95 |\n",
    "plan/fases/FASE-1.md": "# FASE-1: Core\n\nIncluye UC-001 y UC-002.\n",
    "task/TASK-FASE-1.md": "# Tasks\n\n### TASK-F1-001: Login\n\nFASE-1 · UC-001\n\n### TASK-F1-002: Browse\n\nFASE-1 · UC-002\n",
    "web/app/models/user.rb": "# Refs: UC-001\nclass User\n  def login?\n  end\nend\n",
    "web/app/models/session.rb": "class Session\nend\n",
    "web/app/models/untraced.rb": "class Untraced\nend\n",
    "web/test/models/user_test.rb": "class UserTest < ActiveSupport::TestCase\n  test \"UC-001 logs in\" do\n  end\n  def test_BDD_UC_001_01_rejects\n  end\nend\n",
    "src/ignored.ts": "// Refs: UC-002\nexport const x = 1\n",
    "audits/AUDIT-BASELINE.md": "| Total findings | 5 |\n| High | 2 |\n| 3C Gate | PASS |\n",
    "audits/SECURITY-AUDIT-BASELINE.md": "| Total findings | 9 |\n| High | 4 |\n| Critical | 3 |\n",
    "audits/GAP-ANALYSIS-REVIEW.md": "| Total findings | 40 |\n| High | 7 |\n| Critical | 8 |\n",
    "pipeline-state.json": "{ not json",
    "dashboard/adoption-data.json": "{ broken",
    ".sdd/trace-map.json": json.dumps({"$schema": "sdd-trace-map-v1", "mappings": [
        {"file": "web/app/models/session.rb", "taskId": "TASK-F1-002", "fase": 1, "refs": ["UC-002", "REQ-F-002"],
         "origin": "hook-captured", "firstSeen": "x", "lastModified": "x"}]}),
})
git(proj, "add", "-A")
commit(proj, {}, "chore: base", "no trailers", "2026-03-01T10:00:00")
# Task-only commit: TASK-F1-001 → UC-001 (through its own link), never UC-002 (through FASE-1)
commit(proj, {"web/app/models/user.rb": "# Refs: UC-001\nclass User\n  def login?\n  end\n  def logout\n  end\nend\n"},
       "feat: logout", "Task: TASK-F1-001", "2026-03-02T10:00:00")
# Renamed file: refs of the old path follow it
commit(proj, {"web/lib/old_name.rb": "module OldName\nend\n"}, "feat: helper", "Refs: UC-002\nTask: TASK-F1-002",
       "2026-03-03T10:00:00")
git(proj, "mv", "web/lib/old_name.rb", "web/lib/new_name.rb")
commit(proj, {}, "refactor: rename", "no trailers", "2026-03-04T10:00:00")

# ── 6. Stack Profile paths ───────────────────────────────────────────────────
sp = gen.resolve_scan_paths(proj)
check("stack profile: code_paths/test_paths del CLAUDE.md (comentario fuera)",
      sp == (["web/app", "web/lib"], ["web/test"], True), sp)
code_refs, code_stats = quiet(gen.scan_code_refs, proj, sp)[0]
check("stack profile: escanea .rb de web/app y no src/",
      {c["file"] for c in code_refs} == {"web/app/models/user.rb"} and "src/ignored.ts" not in code_stats["files"],
      (code_refs, code_stats))
check("stack profile: símbolo Ruby (class User)", code_refs and code_refs[0]["symbol"] == "User", code_refs[:1])
test_refs, test_stats = quiet(gen.scan_test_refs, proj, sp)[0]
check("tests: minitest (framework detectado, no 'vitest'), test \"...\" y def test_ con IDs normalizados",
      test_stats["totalTests"] == 2 and {t["framework"] for t in test_refs} == {"minitest"}
      and sorted(r for t in test_refs for r in t["refIds"]) == ["BDD-UC-001-01", "UC-001"], (test_refs, test_stats))
nx = os.path.join(tmp, "next")
write(nx, {"CLAUDE.md": "## SDD Stack Profile\n- code_paths: src\n- test_paths: src, tests\n",
           "package.json": '{"devDependencies": {"vitest": "3"}}',
           "src/a.ts": "// Refs: UC-001\nexport function a() {}\n",
           "src/a.test.ts": "// Refs: UC-001\nit('a works', () => {})\n"})
nsp = gen.resolve_scan_paths(nx)
ncode, nstats = quiet(gen.scan_code_refs, nx, nsp)[0]
ntests, ntstats = quiet(gen.scan_test_refs, nx, nsp)[0]
check("stack profile solapado (Next.js src/): a.ts es código, a.test.ts es test (vitest)",
      nstats["files"] == ["src/a.ts"] and [t["file"] for t in ntests] == ["src/a.test.ts"]
      and ntests[0]["framework"] == "vitest", (nstats, ntests))
plain = os.path.join(tmp, "plain")
write(plain, {"README.md": "x"})
check("stack profile: sin perfil → src / tests", gen.resolve_scan_paths(plain) == (["src"], ["tests"], False))
check("framework: sin config → unknown", gen._framework_for("tests/x.test.ts", False, gen.detect_test_frameworks(plain)) == "unknown")

# ── Build the graph ──────────────────────────────────────────────────────────
artifacts, references, all_ids = quiet(gen.scan_files, proj)[0]
commits = quiet(gen.scan_commits, proj)[0]
out_dir = os.path.join(proj, "dashboard")
graph, _, err = quiet(gen.build_graph, proj, out_dir, "<b>P</b>", artifacts, references, all_ids,
                      commits, code_refs, code_stats, test_refs, test_stats, sp)
arts = {a["id"]: a for a in graph["artifacts"]}
st = graph["statistics"]

# 10. corrupt JSON inputs
check("pipeline-state.json corrupto: aviso en stderr y sigue", "pipeline-state.json" in err and graph["pipeline"]["currentStage"] == "unknown", err)
check("adoption-data.json corrupto: aviso en stderr y sigue", "adoption-data.json" in err and graph["adoption"] == {"present": False}, err)

# 4. prose IDs
broken = {b["ref"] for b in st["brokenReferences"]}
check("refs: 'BDD-style' y 'API-first' no son referencias rotas", not ({"BDD-style", "API-first"} & broken), broken)
check("refs: API-auth (definido, sin dígitos) sigue enlazado",
      any(r["source"] == "UC-001" and r["target"] == "API-auth" or r["source"] == "API-auth" and r["target"] == "UC-001"
          for r in graph["relationships"]))
check("ranges en el grafo: ningún NFR inventado", sorted(i for i in arts if i.startswith("NFR")) == ["NFR-001"]
      and not any(b.startswith("NFR-") for b in broken), broken)

# 2. a leftover .sdd/trace-map.json (retired hook) is ignored
check("trace map retirado: .sdd/trace-map.json no aporta refs ni contadores",
      not any(c.get("origin") == "hook-captured" for a in graph["artifacts"] for c in a["codeRefs"])
      and "hookCapturedRefs" not in st["codeStats"], st["codeStats"])
check("orphanFiles: solo los ficheros sin ninguna referencia",
      st["codeStats"]["orphanFiles"] == ["web/app/models/session.rb", "web/app/models/untraced.rb"],
      st["codeStats"]["orphanFiles"])

# 5. task-inferred BFS + confidence
task_refs = [c for a in graph["artifacts"] for c in a["codeRefs"] if c.get("origin") == "task-inferred"]
task_ids = {r for c in task_refs for r in c["refIds"]}
check("task-inferred: no atraviesa FASE-1 (UC-002 no se adjunta a user.rb)",
      "UC-002" not in {r for c in task_refs if c["file"] == "web/app/models/user.rb" for r in c["refIds"]} and "REQ-F-001" in task_ids,
      task_refs)
check("task-inferred: confianza 0.5 (graph-schema.md)", task_refs and all(c["confidence"] == 0.5 for c in task_refs), task_refs)
blame = [c for a in graph["artifacts"] for c in a["codeRefs"] if c.get("origin") == "blame-inferred"]
check("rename: las refs de web/lib/old_name.rb pasan a web/lib/new_name.rb (blame-inferred)",
      any(c["file"] == "web/lib/new_name.rb" and "UC-002" in c["refIds"] for c in blame), blame)

# 12. rename lookup skipped when nothing to infer
calls = []
orig = gen._build_rename_map
gen._build_rename_map = lambda *a, **k: calls.append(a) or {}
quiet(gen.infer_code_refs_from_commits, [], artifacts, {}, {}, project_dir=proj)
gen._build_rename_map = orig
check("rename: sin refs inferidas no se consulta git", calls == [], calls)

# 7. classifier
c1 = arts["REQ-F-001"]["classification"]
c2 = arts["REQ-F-002"]["classification"]
check("classifier: dominio del encabezado de sección (3.1 Authentication)", c1["businessDomain"] == "Authentication", c1)
check("classifier: encabezado genérico → General", c2["businessDomain"] == "General", c2)
check("classifier: 'require'/'catalog'/'performance' no activan ui/log/form (Backend)", c2["technicalLayer"] == "Backend", c2)
lay = gen._LAYER_KEYWORD_RES
def layer(t):
    return next((l for p, l in lay if p.search(t)), "Backend")
check("classifier: palabras completas ('Login form' → Frontend, 'require catalog' → Backend)",
      layer("Login form") == "Frontend" and layer("require catalog performance") == "Backend" and layer("Audit logs") == "Infrastructure")
check("classifier: sin mapas de un proyecto antiguo", "Candidate Portal" not in open(gen_path, encoding="utf-8").read())

# 8. audits
ad = st["auditData"]
check("audits: cifras del spec audit solo de AUDIT-*.md",
      ad["totalFindings"] == 5 and ad["bySeverity"] == {"critical": 0, "high": 2, "medium": 0, "low": 0}
      and ad["latestGate"] == "PASS" and ad["source"] == "audits/AUDIT-BASELINE.md", ad)
check("audits: SECURITY-AUDIT aparte", ad["security"] and ad["security"]["totalFindings"] == 9 and ad["security"]["bySeverity"]["critical"] == 3, ad.get("security"))

# 13. llm-verified refs from .sdd/gap-analysis.json (sdd-gap-detector --semantic) + API-NNN-NN headings
lp = new_repo("llm")
write(lp, {
    "requirements/REQUIREMENTS.md": "# R\n\n### REQ-F-001: A\n\n### REQ-F-002: B\n\n### REQ-F-003: C\n\n"
                                    "### REQ-F-004: D\n\n### REQ-F-005: E\n",
    "spec/contracts/API-tasks.md": "# API-tasks\n\n## API-001-01 — createTask\n\nRefs: REQ-F-001\n",
    "src/a.ts": "// Refs: REQ-F-001\nexport function a() {}\n",
    "src/b.ts": "export function b() {}\n",
    ".sdd/gap-analysis.json": json.dumps({"$schema": "sdd-gap-analysis-v1", "semantic": {"judge": "jev", "requirements": [
        {"id": "REQ-F-001", "status": "covered", "decidedBy": "jev", "origin": "llm-verified", "confidence": 0.9, "evidence": "src/a.ts:1-2"},
        {"id": "REQ-F-002", "status": "covered", "decidedBy": "jev", "origin": "llm-verified", "confidence": 0.93, "evidence": "./src/b.ts:3-9"},
        {"id": "REQ-F-003", "status": "partial", "decidedBy": "llm", "evidence": "src/b.ts:1-2 handles part"},
        {"id": "REQ-F-004", "status": "covered", "decidedBy": "search", "evidence": "src/b.ts:1-2"},
        {"id": "REQ-F-005", "status": "covered", "decidedBy": "llm", "confidence": 0.88, "evidence": "somewhere in src/b.ts"}]}}),
})
lsp = gen.resolve_scan_paths(lp)
l_arts, l_refs, l_ids = quiet(gen.scan_files, lp)[0]
check("api: el encabezado '## API-001-01 — createTask' define API-001-01 (no API-001)",
      "API-001-01" in l_arts and "API-001" not in l_arts, sorted(i for i in l_arts if i.startswith("API")))
l_code, l_cstats = quiet(gen.scan_code_refs, lp, lsp)[0]
l_tests, l_tstats = quiet(gen.scan_test_refs, lp, lsp)[0]
lg, _, lerr = quiet(gen.build_graph, lp, os.path.join(lp, "dashboard"), "llm", l_arts, l_refs, l_ids,
                    [], l_code, l_cstats, l_tests, l_tstats, lsp)
la = {a["id"]: a for a in lg["artifacts"]}
llm2 = [c for c in la["REQ-F-002"]["codeRefs"] if c.get("origin") == "llm-verified"]
check("llm-verified: REQ covered (jev) con evidencia path:start-end → codeRef {file, confidence, lines}",
      len(llm2) == 1 and llm2[0]["file"] == "src/b.ts" and llm2[0]["lines"] == [3, 9] and llm2[0]["confidence"] == 0.93, la["REQ-F-002"]["codeRefs"])
check("llm-verified: no pisa la ref directa del mismo fichero",
      [c["origin"] for c in la["REQ-F-001"]["codeRefs"] if c["file"] == "src/a.ts"] == ["direct"], la["REQ-F-001"]["codeRefs"])
check("llm-verified: partial, decidedBy search y evidencia en prosa se ignoran",
      not any(c.get("origin") == "llm-verified" for r in ("REQ-F-003", "REQ-F-004", "REQ-F-005") for c in la[r]["codeRefs"]),
      {r: la[r]["codeRefs"] for r in ("REQ-F-003", "REQ-F-004", "REQ-F-005")})
check("llm-verified: cuenta en estadísticas (llmVerifiedRefs, reqsWithCode) sin avisos",
      lg["statistics"]["codeStats"]["llmVerifiedRefs"] == 1 and lg["statistics"]["traceabilityCoverage"]["reqsWithCode"]["count"] == 2
      and "gap-analysis" not in lerr, (lg["statistics"]["codeStats"], lg["statistics"]["traceabilityCoverage"]["reqsWithCode"], lerr))
write(lp, {".sdd/gap-analysis.json": "{ broken"})
lg2, _, lerr2 = quiet(gen.build_graph, lp, os.path.join(lp, "dashboard"), "llm", l_arts, l_refs, l_ids,
                      [], l_code, l_cstats, l_tests, l_tstats, lsp)
check("llm-verified: gap-analysis.json corrupto → aviso y sigue sin refs llm-verified",
      "gap-analysis.json" in lerr2 and lg2["statistics"]["codeStats"]["llmVerifiedRefs"] == 0, lerr2)
os.remove(os.path.join(lp, ".sdd", "gap-analysis.json"))
lg3, _, lerr3 = quiet(gen.build_graph, lp, os.path.join(lp, "dashboard"), "llm", l_arts, l_refs, l_ids,
                      [], l_code, l_cstats, l_tests, l_tstats, lsp)
check("llm-verified: sin gap-analysis.json → silencio", "gap-analysis" not in lerr3 and lg3["statistics"]["codeStats"]["llmVerifiedRefs"] == 0, lerr3)

# End to end CLI
r = subprocess.run([sys.executable, gen_path, "--project", proj], capture_output=True, text=True)
check("cli: exit 0 con entradas corruptas y escribe solo el grafo (sin html)",
      r.returncode == 0 and os.path.exists(os.path.join(out_dir, "traceability-graph.json"))
      and not os.path.exists(os.path.join(out_dir, "index.html")), (r.stdout[-300:], r.stderr[-300:]))

sys.exit(1 if fails else 0)
PY2
then
  gen_ok=1
else
  gen_ok=0
fi

if [ "$parser_ok" = 1 ] && [ "$gen_ok" = 1 ]; then
  echo "tests/graph: todo ok"
else
  echo "tests/graph: hay fallos"
  exit 1
fi
