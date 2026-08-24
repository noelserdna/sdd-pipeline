#!/usr/bin/env python3
"""
SDD Test Result Parser
Reads test runner output (jest/vitest/pytest) in JSON format and maps results
to BDD scenario IDs and other SDD artifact references.

Usage:
    python test-result-parser.py                              # auto-detect runner, default paths
    python test-result-parser.py --runner vitest               # force vitest parser
    python test-result-parser.py --input results.json          # custom input path
    python test-result-parser.py --project /path/to/proj       # explicit project root

Prerequisites:
    Run your tests with JSON output first, e.g.:
      npx vitest run --reporter=json > .sdd/test-results-raw.json
      npx jest --json --outputFile=.sdd/test-results-raw.json
      pytest --json-report --json-report-file=.sdd/test-results-raw.json
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
DEFAULT_OUTPUT = os.path.join(".sdd", "test-results-mapped.json")

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
    r'|TASK-F\d{1,2}-\d{3,4})'
    r'(?![a-zA-Z0-9-])'
)

# Pattern for Refs: comments in source files (JS/TS/Python)
REFS_COMMENT_PATTERN = re.compile(
    r'(?://|#)\s*Refs?:\s*((?:(?:REQ|UC|WF|API|BDD|INV|ADR|NFR|TASK)[-][A-Za-z0-9-]+(?:,\s*)*)+)'
)

RUNNER_HINTS = {
    "vitest": "npx vitest run --reporter=json > .sdd/test-results-raw.json",
    "jest": "npx jest --json --outputFile=.sdd/test-results-raw.json",
    "pytest": "pytest --json-report --json-report-file=.sdd/test-results-raw.json",
}


# ──────────────────────────────────────────────────────────
# Runner Detection
# ──────────────────────────────────────────────────────────

def detect_runner(project_dir):
    """Detect the test runner from project configuration files.

    Priority:
      1. vitest.config.ts / vitest.config.js
      2. jest.config.* or "jest" key in package.json
      3. pytest.ini or [tool.pytest] in pyproject.toml
    Returns: "vitest", "jest", "pytest", or None
    """
    # Check for vitest config
    for ext in ("ts", "js", "mts", "mjs"):
        if os.path.exists(os.path.join(project_dir, f"vitest.config.{ext}")):
            return "vitest"

    # Check for jest config files
    for fname in ("jest.config.js", "jest.config.ts", "jest.config.mjs", "jest.config.cjs", "jest.config.json"):
        if os.path.exists(os.path.join(project_dir, fname)):
            return "jest"

    # Check package.json for "jest" key
    pkg_path = os.path.join(project_dir, "package.json")
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

    # Check for pytest config
    if os.path.exists(os.path.join(project_dir, "pytest.ini")):
        return "pytest"

    pyproject_path = os.path.join(project_dir, "pyproject.toml")
    if os.path.exists(pyproject_path):
        try:
            with open(pyproject_path, "r", encoding="utf-8") as f:
                content = f.read()
            if "[tool.pytest" in content:
                return "pytest"
        except OSError:
            pass

    # Check for conftest.py (common pytest indicator)
    if os.path.exists(os.path.join(project_dir, "conftest.py")):
        return "pytest"

    return None


# ──────────────────────────────────────────────────────────
# JSON Parsers (per runner)
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
    return status_lower


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
    summary = {"total": 0, "passed": 0, "failed": 0, "skipped": 0}

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

            summary["total"] += 1
            if status == "pass":
                summary["passed"] += 1
            elif status == "fail":
                summary["failed"] += 1
            elif status == "skip":
                summary["skipped"] += 1

            results.append({
                "testName": test_name,
                "file": file_path,
                "status": status,
                "duration": duration,
                "artifactRefs": [],  # populated later
            })

    return results, summary


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
    summary = {"total": 0, "passed": 0, "failed": 0, "skipped": 0}

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

        summary["total"] += 1
        if status == "pass":
            summary["passed"] += 1
        elif status == "fail":
            summary["failed"] += 1
        elif status == "skip":
            summary["skipped"] += 1

        results.append({
            "testName": test_name,
            "file": file_path,
            "status": status,
            "duration": duration,
            "artifactRefs": [],
        })

    return results, summary


# ──────────────────────────────────────────────────────────
# Artifact Reference Mapping
# ──────────────────────────────────────────────────────────

def _scan_file_for_refs(file_path, project_dir):
    """Scan a test file for Refs: comments and return artifact IDs found."""
    refs = set()
    abs_path = os.path.join(project_dir, file_path)
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


def map_artifact_refs(results, project_dir):
    """Map each test result to SDD artifact references.

    Sources (in priority order):
      1. Artifact IDs found directly in the test name/description
      2. Refs: comments found in the test source file
    """
    # Cache file-level refs to avoid re-reading files
    file_refs_cache = {}

    for result in results:
        refs = set()

        # 1. Scan the test name for artifact IDs
        for m in SDD_ARTIFACT_PATTERN.finditer(result["testName"]):
            refs.add(m.group(1))

        # 2. Scan the source file for Refs: comments (cached)
        file_path = result.get("file", "")
        if file_path:
            if file_path not in file_refs_cache:
                file_refs_cache[file_path] = _scan_file_for_refs(file_path, project_dir)
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

    # Step 2: Read raw JSON input
    input_path = os.path.join(project_dir, input_file) if not os.path.isabs(input_file) else input_file
    if not os.path.isfile(input_path):
        hint = RUNNER_HINTS.get(runner, f"<your test runner> --json > {input_file}")
        print(f"\nError: raw test results not found at: {input_path}")
        print(f"Run your tests with JSON output first:")
        print(f"  {hint}")
        return 1

    try:
        with open(input_path, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON in {input_path}: {e}")
        return 1
    except OSError as e:
        print(f"Error: cannot read {input_path}: {e}")
        return 1

    print(f"Input:   {input_path}")

    # Step 3: Parse based on runner format
    if runner in ("vitest", "jest"):
        results, summary = parse_vitest_jest(raw_data, runner)
    elif runner == "pytest":
        results, summary = parse_pytest(raw_data)
    else:
        print(f"Error: unsupported runner '{runner}'")
        return 1

    if summary["total"] == 0:
        print("Warning: no test results found in input file.")
        print("Check that the JSON format matches the expected structure for your runner.")

    print(f"Parsed:  {summary['total']} tests ({summary['passed']} passed, "
          f"{summary['failed']} failed, {summary['skipped']} skipped)")

    # Step 4: Map artifact references
    results = map_artifact_refs(results, project_dir)
    mapped_count = sum(1 for r in results if r["artifactRefs"])
    print(f"Mapped:  {mapped_count}/{summary['total']} tests have artifact references")

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
        "--input", default=DEFAULT_INPUT,
        help=f"Path to raw test results JSON (default: {DEFAULT_INPUT})"
    )
    parser.add_argument(
        "--output", default=DEFAULT_OUTPUT,
        help=f"Path for mapped output JSON (default: {DEFAULT_OUTPUT})"
    )
    parser.add_argument(
        "--runner", choices=["vitest", "jest", "pytest"], default=None,
        help="Test runner format (default: auto-detect from project config)"
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
