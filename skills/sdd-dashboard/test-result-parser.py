#!/usr/bin/env python3
"""
SDD Test Result Parser
Reads test runner output (vitest/jest/pytest/rspec JSON, Minitest verbose text) and maps
results to BDD scenario IDs and other SDD artifact references.

Usage:
    python test-result-parser.py                              # auto-detect runner, default paths
    python test-result-parser.py --runner vitest               # force the vitest parser
    python test-result-parser.py --runner minitest --input out.txt
    python test-result-parser.py --project /path/to/proj       # explicit project root

The runner is detected in the Stack Profile app_dir (`- app_dir:` in the root CLAUDE.md)
and then at the project root. Commands that produce the raw input (examples):
    vitest example:   npx vitest run --reporter=json > .sdd/test-results-raw.json
    jest example:     npx jest --json --outputFile=.sdd/test-results-raw.json
    pytest example:   pytest --json-report --json-report-file=.sdd/test-results-raw.json
    rspec example:    bundle exec rspec --format json --out .sdd/test-results-raw.json
    minitest example: bin/rails test -v > .sdd/test-results-raw.txt
"""

import os
import re
import json
import sys
import argparse
from datetime import datetime, timezone


# ──────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────

DEFAULT_INPUT = os.path.join(".sdd", "test-results-raw.json")
DEFAULT_INPUT_TEXT = os.path.join(".sdd", "test-results-raw.txt")   # Minitest verbose output
DEFAULT_OUTPUT = os.path.join(".sdd", "test-results-mapped.json")

RUNNERS = ["vitest", "jest", "pytest", "minitest", "rspec"]

# Pattern to match BDD IDs in test names: BDD-019 or BDD-AUTH-003
BDD_ID_PATTERN = re.compile(r'BDD-[A-Z0-9]+-\d{3,4}|BDD-\d{3,4}')

# Universal SDD artifact ID pattern
SDD_ARTIFACT_PATTERN = re.compile(
    r'(?<![a-zA-Z\-])'
    r'(REQ-[A-Z]*-?\d{3,4}[a-z]?'
    r'|UC-\d{3,4}'
    r'|WF-\d{3,4}'
    r'|API-[a-zA-Z][a-zA-Z0-9-]*'
    r'|BDD-[a-zA-Z0-9][a-zA-Z0-9-]*'
    r'|INV-[A-Z]*-?\d{3,4}'
    r'|ADR-\d{3,4}'
    r'|NFR-\d{3,4}'
    r'|AC-\d{3,4}(?:-\d{1,3})?'
    r'|TASK-F\d{1,2}-\d{3,4})'
    r'(?![a-zA-Z0-9-])'
)

# IDs written with underscores, as Ruby method names require (test_BDD_UC_001_01_..., AC_001_01):
# uppercase segments first, then one or more numeric segments → hyphenated.
UNDERSCORE_ID_PATTERN = re.compile(
    r'(?<![A-Za-z0-9])(REQ|UC|WF|BDD|INV|ADR|NFR|AC|TASK)((?:_[A-Z][A-Z0-9]*)*(?:_\d+)+)(?![A-Za-z0-9])'
)

# Pattern for Refs: comments in source files (JS/TS/Python/Ruby)
REFS_COMMENT_PATTERN = re.compile(
    r'(?://|#)\s*Refs?:\s*((?:(?:REQ|UC|WF|API|BDD|INV|ADR|NFR|AC|TASK)[-][A-Za-z0-9-]+(?:,\s*)*)+)'
)

# Command templates per runner; {out} is the raw results path as seen from where the command runs.
RUNNER_HINTS = {
    "vitest": "npx vitest run --reporter=json > {out}",  # example command for this runner
    "jest": "npx jest --json --outputFile={out}",
    "pytest": "pytest --json-report --json-report-file={out}",
    "minitest": "bin/rails test -v > {out}",
    "rspec": "bundle exec rspec --format json --out {out}",
}

# Minitest verbose reporter: "TodoTest#test_name = 0.01 s = ."
MINITEST_LINE = re.compile(
    r'^(?P<cls>[A-Za-z_][\w:]*)#(?P<name>\S+) = (?P<dur>\d+(?:\.\d+)?) s = (?P<st>[.FES])\s*$'
)
MINITEST_SUMMARY = re.compile(
    r'(\d+) runs?, (\d+) assertions?, (\d+) failures?, (\d+) errors?, (\d+) skips?'
)
# Header after "Failure:" / "Error:" / "Skipped:": "Class#test_name [test/x_test.rb:12]:"
MINITEST_HEADER = re.compile(
    r'^(?P<cls>[A-Za-z_][\w:]*)#(?P<name>\S+?)(?: \[(?P<file>[^\]]+?):\d+\])?:\s*$'
)
# Rerun hint printed by the Rails reporter: "bin/rails test test/x_test.rb:10"
MINITEST_RERUN = re.compile(r'^(?:bin/rails|rails) test (?P<file>\S+?):\d+\s*$')


# ──────────────────────────────────────────────────────────
# Stack Profile
# ──────────────────────────────────────────────────────────

def read_app_dir(project_dir):
    """Return `app_dir` from the `## SDD Stack Profile` section of the root CLAUDE.md ("." if absent).

    Lines inside code fences do not count; the section ends at the next level-1 or level-2 heading.
    """
    path = os.path.join(project_dir, "CLAUDE.md")
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return "."

    in_fence = False
    in_section = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if line.startswith("# ") or line.startswith("## "):
            in_section = line.rstrip() == "## SDD Stack Profile"
            continue
        if not in_section:
            continue
        m = re.match(r'^- app_dir:\s*(.*)$', line)
        if not m:
            continue
        value = re.sub(r'\s+#.*$', '', m.group(1)).strip()
        while value.startswith("./"):
            value = value[2:]
        value = value.rstrip("/")
        if not value or value.startswith("/") or ".." in value.split("/"):
            return "."
        return value
    return "."


# ──────────────────────────────────────────────────────────
# Runner Detection
# ──────────────────────────────────────────────────────────

def _read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def _detect_runner_in(directory):
    """Detect the runner from the configuration files of one directory."""
    # Check for vitest config
    for ext in ("ts", "js", "mts", "mjs"):
        if os.path.exists(os.path.join(directory, f"vitest.config.{ext}")):
            return "vitest"

    # Check for jest config files
    for fname in ("jest.config.js", "jest.config.ts", "jest.config.mjs", "jest.config.cjs", "jest.config.json"):
        if os.path.exists(os.path.join(directory, fname)):
            return "jest"

    # Check package.json for "jest" key
    pkg_path = os.path.join(directory, "package.json")
    if os.path.exists(pkg_path):
        try:
            with open(pkg_path, "r", encoding="utf-8") as f:
                pkg = json.load(f)
            if "jest" in pkg:
                return "jest"
            # Also check devDependencies for vitest vs jest
            deps = {}
            deps.update(pkg.get("dependencies", {}))
            deps.update(pkg.get("devDependencies", {}))
            if "vitest" in deps:
                return "vitest"
            if "jest" in deps:
                return "jest"
        except (json.JSONDecodeError, OSError):
            pass

    # RSpec: only explicit RSpec markers. A bare spec/ directory is the SDD specification folder.
    if os.path.exists(os.path.join(directory, ".rspec")) or \
            os.path.exists(os.path.join(directory, "spec", "rails_helper.rb")):
        return "rspec"

    # Minitest: a Gemfile that mentions rails or minitest, plus a test/ directory
    gemfile = _read_text(os.path.join(directory, "Gemfile"))
    if gemfile is not None and re.search(r'\b(rails|minitest)\b', gemfile) \
            and os.path.isdir(os.path.join(directory, "test")):
        return "minitest"

    # Check for pytest config
    if os.path.exists(os.path.join(directory, "pytest.ini")):
        return "pytest"

    pyproject = _read_text(os.path.join(directory, "pyproject.toml"))
    if pyproject is not None and "[tool.pytest" in pyproject:
        return "pytest"

    # Check for conftest.py (common pytest indicator)
    if os.path.exists(os.path.join(directory, "conftest.py")):
        return "pytest"

    return None


def detect_runner(project_dir):
    """Detect the test runner from project configuration files.

    Looks first in the Stack Profile app_dir (root CLAUDE.md, `- app_dir:`), then at the root.
    Priority inside each directory:
      1. vitest.config.* / jest.config.* / package.json dependencies
      2. RSpec: .rspec or spec/rails_helper.rb
      3. Minitest: Gemfile mentioning rails or minitest + test/
      4. pytest.ini, [tool.pytest] in pyproject.toml, conftest.py
    Returns: "vitest", "jest", "rspec", "minitest", "pytest", or None
    """
    app_dir = read_app_dir(project_dir)
    directories = []
    if app_dir != ".":
        directories.append(os.path.join(project_dir, app_dir))
    directories.append(project_dir)
    for directory in directories:
        runner = _detect_runner_in(directory)
        if runner:
            return runner
    return None


def runner_hint(runner, app_dir, input_file):
    """Command that produces the raw input for RUNNER, run from app_dir and writing at the project root."""
    template = RUNNER_HINTS.get(runner)
    if not template:
        return f"<your test runner> --json > {input_file}"
    if app_dir and app_dir != "." and not os.path.isabs(input_file):
        depth = len([p for p in app_dir.split("/") if p])
        out = "/".join([".."] * depth + [input_file.replace(os.sep, "/")])
        return f"(cd {app_dir} && {template.format(out=out)})"
    return template.format(out=input_file)


# ──────────────────────────────────────────────────────────
# Parsers (per runner)
# ──────────────────────────────────────────────────────────

def _normalize_status(status, runner):
    """Normalize test status to pass/fail/skip."""
    status_lower = status.lower()
    if runner in ("vitest", "jest"):
        if status_lower == "passed":
            return "pass"
        elif status_lower == "failed":
            return "fail"
        elif status_lower in ("skipped", "pending", "todo", "disabled"):
            return "skip"
    elif runner == "pytest":
        if status_lower == "passed":
            return "pass"
        elif status_lower == "failed":
            return "fail"
        elif status_lower in ("skipped", "xfailed", "xpassed", "deselected"):
            return "skip"
    elif runner == "rspec":
        if status_lower == "passed":
            return "pass"
        elif status_lower == "failed":
            return "fail"
        elif status_lower == "pending":
            return "skip"
    elif runner == "minitest":
        if status_lower == ".":
            return "pass"
        elif status_lower in ("f", "e"):
            return "fail"
        elif status_lower == "s":
            return "skip"
    return status_lower


def _summarize(results):
    summary = {"total": 0, "passed": 0, "failed": 0, "skipped": 0}
    for r in results:
        summary["total"] += 1
        if r["status"] == "pass":
            summary["passed"] += 1
        elif r["status"] == "fail":
            summary["failed"] += 1
        elif r["status"] == "skip":
            summary["skipped"] += 1
    return summary


def _in_app_dir(app_dir, file_path):
    """Project-relative path for a path reported relative to app_dir."""
    file_path = file_path.replace("\\", "/")
    while file_path.startswith("./"):
        file_path = file_path[2:]
    if not file_path or not app_dir or app_dir == "." or os.path.isabs(file_path):
        return file_path
    return f"{app_dir}/{file_path}"


def parse_vitest_jest(raw_data, runner):
    """Parse vitest or jest JSON reporter output.

    Expected structure:
      {
        "testResults": [
          {
            "name": "/abs/path/to/file.test.ts",
            "testResults": [
              { "fullName": "suite > test name", "status": "passed", "duration": 12 }
            ]
          }
        ]
      }
    """
    results = []

    test_suites = raw_data.get("testResults", [])
    if not test_suites:
        # Vitest sometimes uses "testResults" at root level differently
        # Try alternative structures
        test_suites = raw_data.get("results", [])

    for suite in test_suites:
        file_path = suite.get("name", "") or suite.get("filename", "")
        # Normalize: keep relative path if possible
        if os.path.isabs(file_path):
            # Try to make it relative-looking by taking from tests/ or src/
            for marker in ("/tests/", "/test/", "/src/", "/__tests__/"):
                idx = file_path.find(marker)
                if idx != -1:
                    file_path = file_path[idx + 1:]
                    break

        test_cases = suite.get("testResults", []) or suite.get("assertionResults", [])
        for tc in test_cases:
            test_name = tc.get("fullName", "") or tc.get("title", "") or tc.get("name", "")
            status_raw = tc.get("status", "unknown")
            status = _normalize_status(status_raw, runner)
            duration = tc.get("duration", 0) or 0

            results.append({
                "testName": test_name,
                "file": file_path,
                "status": status,
                "duration": duration,
                "artifactRefs": [],  # populated later
            })

    return results, _summarize(results)


def parse_pytest(raw_data):
    """Parse pytest-json-report plugin output.

    Expected structure:
      {
        "tests": [
          { "nodeid": "tests/test_foo.py::test_bar", "outcome": "passed", "duration": 0.5 }
        ]
      }
    """
    results = []

    tests = raw_data.get("tests", [])
    for tc in tests:
        nodeid = tc.get("nodeid", "")
        # Extract file path and test name from nodeid (e.g., "tests/test_foo.py::TestClass::test_bar")
        parts = nodeid.split("::", 1)
        file_path = parts[0] if parts else ""
        test_name = parts[1] if len(parts) > 1 else nodeid

        status_raw = tc.get("outcome", "unknown")
        status = _normalize_status(status_raw, "pytest")
        # pytest duration is in seconds, convert to ms
        duration = int((tc.get("duration", 0) or 0) * 1000)

        results.append({
            "testName": test_name,
            "file": file_path,
            "status": status,
            "duration": duration,
            "artifactRefs": [],
        })

    return results, _summarize(results)


def parse_rspec_json(raw_data, app_dir="."):
    """Parse `rspec --format json` output.

    Expected structure:
      {
        "examples": [
          { "full_description": "Todo BDD-UC-001-01 ...", "status": "passed",
            "file_path": "./spec/models/todo_spec.rb", "run_time": 0.0012 }
        ],
        "summary": { "example_count": 1, "failure_count": 0, "pending_count": 0 }
      }
    File paths are relative to where rspec ran (the Stack Profile app_dir).
    """
    results = []
    for ex in raw_data.get("examples", []) or []:
        test_name = ex.get("full_description") or ex.get("description") or ex.get("id", "")
        status = _normalize_status(ex.get("status", "unknown") or "unknown", "rspec")
        duration = int(round((ex.get("run_time", 0) or 0) * 1000))
        results.append({
            "testName": test_name,
            "file": _in_app_dir(app_dir, ex.get("file_path", "") or ""),
            "status": status,
            "duration": duration,
            "artifactRefs": [],
        })
    summary = _summarize(results)
    outside = (raw_data.get("summary") or {}).get("errors_outside_of_examples_count", 0) or 0
    if outside:
        # Load errors are not examples, but the run did fail
        summary["failed"] += outside
        summary["total"] += outside
    return results, summary


def _underscore(name):
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', name)
    s = re.sub(r'([a-z\d])([A-Z])', r'\1_\2', s)
    return s.lower()


def _ruby_test_file_index(project_dir, app_dir):
    """basename → [project-relative paths] of *_test.rb files under <app_dir>/test."""
    index = {}
    base = os.path.join(project_dir, app_dir) if app_dir and app_dir != "." else project_dir
    test_root = os.path.join(base, "test")
    if not os.path.isdir(test_root):
        return index
    for root, dirs, files in os.walk(test_root):
        dirs[:] = [d for d in dirs if d not in {"fixtures", "tmp"}]
        for fname in files:
            if fname.endswith("_test.rb"):
                rel = os.path.relpath(os.path.join(root, fname), project_dir).replace(os.sep, "/")
                index.setdefault(fname, []).append(rel)
    return index


def _ruby_test_file_for(cls, index):
    parts = [_underscore(p) for p in cls.split("::") if p]
    if not parts:
        return ""
    candidates = index.get(parts[-1] + ".rb", [])
    if not candidates:
        return ""
    if len(parts) > 1:
        suffix = "/".join(parts) + ".rb"
        for c in candidates:
            if c.endswith("/" + suffix):
                return c
    return candidates[0]


def parse_minitest_text(text, project_dir=None, app_dir="."):
    """Parse Minitest verbose output (`bin/rails test -v`).

    Result lines:   TodoTest#test_BDD_UC_001_01_rejects_blank = 0.01 s = .|F|E|S
    Summary line:   N runs, M assertions, F failures, E errors, S skips
    The file of each test comes from the failure header ("Class#test [file:line]:"), the rerun hint
    ("bin/rails test file:line") or, for the rest, from the class name under <app_dir>/test.
    """
    results = []
    by_key = {}
    expect_header = False
    last_key = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        m = MINITEST_LINE.match(line)
        if m:
            key = (m.group("cls"), m.group("name"))
            entry = {
                "testName": f"{m.group('cls')}#{m.group('name')}",
                "file": "",
                "status": _normalize_status(m.group("st"), "minitest"),
                "duration": int(round(float(m.group("dur")) * 1000)),
                "artifactRefs": [],
            }
            by_key[key] = entry
            results.append(entry)
            continue
        if line in ("Failure:", "Error:", "Skipped:"):
            expect_header = True
            continue
        if expect_header:
            expect_header = False
            h = MINITEST_HEADER.match(line)
            if h:
                last_key = (h.group("cls"), h.group("name"))
                if h.group("file") and last_key in by_key and not by_key[last_key]["file"]:
                    by_key[last_key]["file"] = _in_app_dir(app_dir, h.group("file"))
            continue
        r = MINITEST_RERUN.match(line)
        if r and last_key in by_key:
            if not by_key[last_key]["file"]:
                by_key[last_key]["file"] = _in_app_dir(app_dir, r.group("file"))
            last_key = None

    if project_dir and any(not e["file"] for e in results):
        index = _ruby_test_file_index(project_dir, app_dir)
        for e in results:
            if not e["file"]:
                e["file"] = _ruby_test_file_for(e["testName"].split("#", 1)[0], index)

    summary = _summarize(results)
    totals = None
    for totals in MINITEST_SUMMARY.finditer(text):
        pass
    if totals:
        runs, _assertions, failures, errors, skips = (int(g) for g in totals.groups())
        summary = {
            "total": runs,
            "passed": max(runs - failures - errors - skips, 0),
            "failed": failures + errors,
            "skipped": skips,
        }
    return results, summary


# ──────────────────────────────────────────────────────────
# Artifact Reference Mapping
# ──────────────────────────────────────────────────────────

def normalize_ids(text):
    """Hyphenate IDs written with underscores: BDD_UC_001_01 → BDD-UC-001-01, AC_001_01 → AC-001-01."""
    return UNDERSCORE_ID_PATTERN.sub(lambda m: m.group(1) + m.group(2).replace("_", "-"), text)


def _scan_file_for_refs(file_path, project_dir, app_dir="."):
    """Scan a test file for Refs: comments and return artifact IDs found."""
    refs = set()
    abs_path = os.path.join(project_dir, file_path)
    if not os.path.isfile(abs_path) and app_dir and app_dir != ".":
        abs_path = os.path.join(project_dir, app_dir, file_path)
    if not os.path.isfile(abs_path):
        return refs

    try:
        with open(abs_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except OSError:
        return refs

    # Find Refs: comment lines
    for m in REFS_COMMENT_PATTERN.finditer(content):
        raw = m.group(1)
        for ref_match in SDD_ARTIFACT_PATTERN.finditer(raw):
            refs.add(ref_match.group(1))

    return refs


def map_artifact_refs(results, project_dir, app_dir="."):
    """Map each test result to SDD artifact references.

    Sources (in priority order):
      1. Artifact IDs found directly in the test name/description (underscored IDs normalized)
      2. Refs: comments found in the test source file
    """
    # Cache file-level refs to avoid re-reading files
    file_refs_cache = {}

    for result in results:
        refs = set()

        # 1. Scan the test name for artifact IDs
        for m in SDD_ARTIFACT_PATTERN.finditer(normalize_ids(result["testName"])):
            refs.add(m.group(1))

        # 2. Scan the source file for Refs: comments (cached)
        file_path = result.get("file", "")
        if file_path:
            if file_path not in file_refs_cache:
                file_refs_cache[file_path] = _scan_file_for_refs(file_path, project_dir, app_dir)
            refs.update(file_refs_cache[file_path])

        result["artifactRefs"] = sorted(refs)

    return results


# ──────────────────────────────────────────────────────────
# BDD Coverage Computation
# ──────────────────────────────────────────────────────────

def compute_bdd_coverage(results, project_dir):
    """Compute BDD coverage statistics from mapped results.

    Collects all BDD IDs from test results, cross-references with BDD IDs
    defined in spec/ files, and reports unmapped BDDs.
    """
    # Collect BDD IDs from test results
    bdd_status = {}  # bdd_id -> "pass" | "fail" | "skip"
    for r in results:
        for ref in r["artifactRefs"]:
            if ref.startswith("BDD-"):
                current = bdd_status.get(ref)
                new_status = r["status"]
                # Worst status wins: fail > skip > pass
                if current is None:
                    bdd_status[ref] = new_status
                elif new_status == "fail":
                    bdd_status[ref] = "fail"
                elif new_status == "skip" and current != "fail":
                    bdd_status[ref] = "skip"

    # Discover all BDD IDs defined in spec/ files
    defined_bdds = set()
    spec_dir = os.path.join(project_dir, "spec")
    if os.path.isdir(spec_dir):
        for root, dirs, files in os.walk(spec_dir):
            dirs[:] = [d for d in dirs if d not in {".git", "node_modules", "__pycache__"}]
            for fname in files:
                if not fname.lower().endswith(".md"):
                    continue
                fpath = os.path.join(root, fname)
                try:
                    with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                        content = f.read()
                    for m in BDD_ID_PATTERN.finditer(content):
                        defined_bdds.add(m.group(0))
                except OSError:
                    continue

    # BDDs defined in specs but not covered by any test
    all_tested_bdds = set(bdd_status.keys())
    unmapped = sorted(defined_bdds - all_tested_bdds)

    passing = sum(1 for s in bdd_status.values() if s == "pass")
    failing = sum(1 for s in bdd_status.values() if s == "fail")

    return {
        "totalMapped": len(bdd_status),
        "passing": passing,
        "failing": failing,
        "unmapped": unmapped,
    }


# ──────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────

def run(project_dir, input_file, output_file, runner_override):
    """Main execution: detect runner, parse, map, write output."""
    app_dir = read_app_dir(project_dir)

    # Step 1: Detect or use overridden runner
    if runner_override:
        runner = runner_override
        print(f"Runner: {runner} (specified via --runner)")
    else:
        runner = detect_runner(project_dir)
        if runner:
            print(f"Runner: {runner} (auto-detected)")
        else:
            print("Warning: could not auto-detect test runner.")
            print("Defaulting to vitest format. Use --runner to specify explicitly.")
            runner = "vitest"
    if app_dir != ".":
        print(f"App dir: {app_dir} (SDD Stack Profile)")

    # Step 2: Read raw input (Minitest: verbose text; the rest: JSON)
    if input_file is None:
        input_file = DEFAULT_INPUT_TEXT if runner == "minitest" else DEFAULT_INPUT
    input_path = os.path.join(project_dir, input_file) if not os.path.isabs(input_file) else input_file
    if not os.path.isfile(input_path):
        print(f"\nError: raw test results not found at: {input_path}")
        print("Run your tests with machine-readable output first:")
        print(f"  {runner_hint(runner, app_dir, input_file)}")
        return 1

    try:
        with open(input_path, "r", encoding="utf-8", errors="replace") as f:
            raw_text = f.read()
    except OSError as e:
        print(f"Error: cannot read {input_path}: {e}")
        return 1

    print(f"Input:   {input_path}")

    # Step 3: Parse based on runner format
    if runner == "minitest":
        results, summary = parse_minitest_text(raw_text, project_dir, app_dir)
        if summary["total"] and not results:
            print("Warning: Minitest summary found but no per-test lines: run the tests with -v.")
    else:
        try:
            raw_data = json.loads(raw_text)
        except json.JSONDecodeError as e:
            print(f"Error: invalid JSON in {input_path}: {e}")
            return 1
        if runner in ("vitest", "jest"):
            results, summary = parse_vitest_jest(raw_data, runner)
        elif runner == "pytest":
            results, summary = parse_pytest(raw_data)
        elif runner == "rspec":
            results, summary = parse_rspec_json(raw_data, app_dir)
        else:
            print(f"Error: unsupported runner '{runner}'")
            return 1

    if summary["total"] == 0:
        print("Warning: no test results found in input file.")
        print("Check that the format matches the expected structure for your runner.")

    print(f"Parsed:  {summary['total']} tests ({summary['passed']} passed, "
          f"{summary['failed']} failed, {summary['skipped']} skipped)")

    # Step 4: Map artifact references
    results = map_artifact_refs(results, project_dir, app_dir)
    mapped_count = sum(1 for r in results if r["artifactRefs"])
    print(f"Mapped:  {mapped_count}/{len(results)} tests have artifact references")

    # Step 5: Compute BDD coverage
    bdd_coverage = compute_bdd_coverage(results, project_dir)
    if bdd_coverage["totalMapped"] > 0:
        print(f"BDD:     {bdd_coverage['totalMapped']} scenarios mapped "
              f"({bdd_coverage['passing']} passing, {bdd_coverage['failing']} failing)")
    if bdd_coverage["unmapped"]:
        print(f"         {len(bdd_coverage['unmapped'])} BDD scenarios without tests")

    # Step 6: Build and write output
    output = {
        "$schema": "sdd-test-results-v1",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "runner": runner,
        "appDir": app_dir,
        "summary": summary,
        "results": results,
        "bddCoverage": bdd_coverage,
    }

    output_path = os.path.join(project_dir, output_file) if not os.path.isabs(output_file) else output_file
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    try:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
    except OSError as e:
        print(f"Error: cannot write output to {output_path}: {e}")
        return 1

    print(f"Output:  {output_path}")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="SDD Test Result Parser — maps test runner output to BDD scenario IDs"
    )
    parser.add_argument(
        "--project", default=".",
        help="Project root directory (default: current working directory)"
    )
    parser.add_argument(
        "--input", default=None,
        help=f"Path to raw test results (default: {DEFAULT_INPUT}; {DEFAULT_INPUT_TEXT} for minitest)"
    )
    parser.add_argument(
        "--output", default=DEFAULT_OUTPUT,
        help=f"Path for mapped output JSON (default: {DEFAULT_OUTPUT})"
    )
    parser.add_argument(
        "--runner", choices=RUNNERS, default=None,
        help="Test runner format (default: auto-detect from project config and the Stack Profile app_dir)"
    )
    args = parser.parse_args()

    project_dir = os.path.abspath(args.project)

    print("=" * 60)
    print("SDD Test Result Parser")
    print("=" * 60)
    print(f"Project: {project_dir}")

    result = run(project_dir, args.input, args.output, args.runner)

    print("=" * 60)
    if result == 0:
        print("Done!")
    else:
        print("Failed.")
    print("=" * 60)

    return result


if __name__ == "__main__":
    sys.exit(main())
