#!/usr/bin/env bash
# Tests del parser de resultados del dashboard (skills/sdd-dashboard/test-result-parser.py):
# detección de runner (vitest, minitest, rspec; app_dir del SDD Stack Profile), parsers de Minitest verbose,
# RSpec JSON y Vitest JSON, normalización de IDs con guiones bajos y la CLI de punta a punta.
# Solo python3 (stdlib). Fixtures en tests/fixtures/test-results/. Compatible con bash 3.2.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PARSER="$ROOT/skills/sdd-dashboard/test-result-parser.py"
FIX="$ROOT/tests/fixtures/test-results"
unset SDD_STATE_ROOT SDD_PLUGIN_ROOT CLAUDE_PROJECT_DIR || true

if ! command -v python3 >/dev/null 2>&1; then echo "skip tests/dashboard: python3 no disponible"; exit 0; fi

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
  echo "tests/dashboard: todo ok"
else
  echo "tests/dashboard: hay fallos"
  exit 1
fi
