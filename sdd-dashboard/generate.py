#!/usr/bin/env python3
"""
SDD Dashboard Generator
Scans spec/, plan/, task/, test/ for artifact definitions and cross-references,
builds traceability-graph.json following the SDD graph schema,
and generates index.html from the plugin HTML template.

Usage:
    python generate.py                          # CWD as project root
    python generate.py --project /path/to/proj  # explicit project root
    python generate.py --output /path/to/out    # explicit output directory
"""

import os
import re
import json
import sys
import argparse
import subprocess
from datetime import datetime, timezone
from collections import OrderedDict

# ──────────────────────────────────────────────────────────
# Constants (static — do not depend on CLI args)
# ──────────────────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

SCAN_DIRS = ["spec", "plan", "task", "test"]
SKIP_DIRS = {".git", ".claude", "node_modules", "__pycache__", "dashboard", "temp_files"}

# ──────────────────────────────────────────────────────────
# ID Patterns
# ──────────────────────────────────────────────────────────

# Definition patterns: match artifact IDs defined in headings (^#+ ID ...)
DEF_PATTERNS = [
    # REQ with category: ### REQ-SEC-001: title
    ("REQ", re.compile(r'^(#{1,6})\s+(REQ-[A-Z]+-\d{3,4}[a-z]?)\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # REQ simple: ### REQ-001: title
    ("REQ", re.compile(r'^(#{1,6})\s+(REQ-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # UC: ## UC-001: title  (also match from filename-based headings like "# UC-001-extract-pdf")
    ("UC", re.compile(r'^(#{1,6})\s+(UC-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # WF: ## WF-001: title
    ("WF", re.compile(r'^(#{1,6})\s+(WF-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # API named: ## API-pdf-reader or # API-matching
    ("API", re.compile(r'^(#{1,6})\s+(API-[a-zA-Z][a-zA-Z0-9-]*)\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # API numeric: ## API-001
    ("API", re.compile(r'^(#{1,6})\s+(API-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # BDD heading: ## BDD-extraction or Scenario: BDD-xxx
    ("BDD", re.compile(r'^(#{1,6})\s+(BDD-[a-zA-Z0-9][a-zA-Z0-9-]*)\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # INV with scope: ### INV-EXT-001: title
    ("INV", re.compile(r'^(#{1,6})\s+(INV-[A-Z]+-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # INV simple: ### INV-001: title
    ("INV", re.compile(r'^(#{1,6})\s+(INV-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # ADR: # ADR-001: title
    ("ADR", re.compile(r'^(#{1,6})\s+(ADR-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # NFR: ## NFR-001: title
    ("NFR", re.compile(r'^(#{1,6})\s+(NFR-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # RN: ## RN-001: title
    ("RN", re.compile(r'^(#{1,6})\s+(RN-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # FASE: # FASE-0: title
    ("FASE", re.compile(r'^(#{1,6})\s+(FASE-\d{1,2})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # TASK: ### TASK-F0-001: title
    ("TASK", re.compile(r'^(#{1,6})\s+(TASK-F\d{1,2}-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
]

# Filename-based definitions: extract from filenames like UC-001-extract-pdf.md, ADR-001-hybrid.md, WF-001-xxx.md
FILENAME_PATTERNS = [
    ("UC", re.compile(r'^(UC-\d{3,4})', re.IGNORECASE)),
    ("WF", re.compile(r'^(WF-\d{3,4})', re.IGNORECASE)),
    ("API", re.compile(r'^(API-[a-zA-Z][a-zA-Z0-9-]*?)\.md$', re.IGNORECASE)),
    ("ADR", re.compile(r'^(ADR-\d{3,4})', re.IGNORECASE)),
    ("BDD", re.compile(r'^(BDD-[a-zA-Z0-9][a-zA-Z0-9-]*?)\.md$', re.IGNORECASE)),
]

# Table-based definitions: | REQ-XXX-001 | ... | or | INV-XXX-001 | ... |
TABLE_DEF_PATTERNS = [
    ("REQ", re.compile(r'\|\s*(REQ-[A-Z]+-\d{3,4}[a-z]?)\s*\|')),
    ("REQ", re.compile(r'\|\s*(REQ-\d{3,4})\s*\|')),
    ("INV", re.compile(r'\|\s*(INV-[A-Z]+-\d{3,4})\s*\|')),
    ("INV", re.compile(r'\|\s*(INV-\d{3,4})\s*\|')),
    ("NFR", re.compile(r'\|\s*(NFR-\d{3,4})\s*\|')),
    ("RN", re.compile(r'\|\s*(RN-\d{3,4})\s*\|')),
]

# Universal reference pattern: matches any artifact ID in text
REF_PATTERN = re.compile(
    r'(?<![a-zA-Z])'  # no letter before
    r'('
    r'REQ-[A-Z]*-?\d{3,4}[a-z]?'
    r'|UC-\d{3,4}'
    r'|WF-\d{3,4}'
    r'|API-[a-zA-Z][a-zA-Z0-9-]*'
    r'|BDD-[a-zA-Z0-9][a-zA-Z0-9-]*'
    r'|INV-[A-Z]*-?\d{3,4}'
    r'|ADR-\d{3,4}'
    r'|NFR-\d{3,4}'
    r'|RN-\d{3,4}'
    r'|FASE-\d{1,2}'
    r'|TASK-F\d{1,2}-\d{3,4}'
    r')'
    r'(?![a-zA-Z0-9-])'  # no trailing alphanum or hyphen (prevent partial match)
)

# IDs that are not actual artifacts (audit finding IDs, etc.)
NOISE_PREFIXES = {"SEC-", "SIL-", "SEM-", "CON-", "INC-", "REF-", "AMB-", "DEC-", "IMP-", "CONTR-", "ALTO-"}

# Type to pipeline stage mapping
TYPE_TO_STAGE = {
    "REQ": "requirements-engineer",
    "UC": "specifications-engineer",
    "WF": "specifications-engineer",
    "API": "specifications-engineer",
    "BDD": "specifications-engineer",
    "INV": "specifications-engineer",
    "ADR": "specifications-engineer",
    "NFR": "specifications-engineer",
    "RN": "specifications-engineer",
    "FASE": "plan-architect",
    "TASK": "task-generator",
}


# ──────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────

def detect_project_name(project_dir):
    """Auto-detect project name from package.json, pipeline-state.json, or directory name."""
    for f in ["package.json", "pipeline-state.json"]:
        path = os.path.join(project_dir, f)
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    data = json.load(fh)
                    name = data.get("name") or data.get("project")
                    if name:
                        return name
            except Exception:
                continue
    return os.path.basename(os.path.abspath(project_dir))


def resolve_template(project_dir):
    """Find the HTML template. Priority: script-local > project dashboard > plugin cache."""
    candidates = [
        # 1. Relative to this script (when running from plugin or sdd-skills)
        os.path.join(SCRIPT_DIR, "references", "html-template.md"),
        # 2. Project's own dashboard/references (legacy)
        os.path.join(project_dir, "dashboard", "references", "html-template.md"),
        # 3. Plugin cache (Cloudflare plugin location)
        os.path.normpath(os.path.join(
            os.path.expanduser("~"), ".claude", "plugins", "cache", "noelserdna-plugins", "sdd",
            "1.8.0", "skills", "dashboard", "references", "html-template.md"
        )),
    ]
    return next((p for p in candidates if os.path.exists(p)), candidates[0])


def infer_relationship_type(source_type, target_type):
    """Infer the relationship type based on source and target types."""
    pairs = {
        ("UC", "REQ"): "implements",
        ("WF", "API"): "orchestrates",
        ("BDD", "REQ"): "verifies",
        ("BDD", "UC"): "verifies",
        ("INV", "REQ"): "guarantees",
        ("ADR", "REQ"): "decides",
        ("ADR", "NFR"): "decides",
        ("TASK", "FASE"): "decomposes",
        ("TASK", "UC"): "implemented-by",
        ("TASK", "API"): "implemented-by",
        ("TASK", "INV"): "implemented-by",
        ("FASE", "UC"): "reads-from",
        ("FASE", "API"): "reads-from",
    }
    return pairs.get((source_type, target_type), "traces-to")


def classify_id(id_str):
    """Return the type prefix for an artifact ID."""
    if id_str.startswith("REQ-"): return "REQ"
    if id_str.startswith("UC-"): return "UC"
    if id_str.startswith("WF-"): return "WF"
    if id_str.startswith("API-"): return "API"
    if id_str.startswith("BDD-"): return "BDD"
    if id_str.startswith("INV-"): return "INV"
    if id_str.startswith("ADR-"): return "ADR"
    if id_str.startswith("NFR-"): return "NFR"
    if id_str.startswith("RN-"): return "RN"
    if id_str.startswith("FASE-"): return "FASE"
    if id_str.startswith("TASK-"): return "TASK"
    return None


def extract_category(id_str, id_type):
    """Extract sub-category from ID if present."""
    if id_type == "REQ":
        # REQ-SEC-001 => SEC, REQ-001 => None
        m = re.match(r'REQ-([A-Z]+)-\d', id_str)
        return m.group(1) if m else None
    if id_type == "INV":
        m = re.match(r'INV-([A-Z]+)-\d', id_str)
        return m.group(1) if m else None
    return None


def normalize_id(id_str):
    """Normalize an artifact ID for deduplication."""
    return id_str.strip()


def _rel_path(filepath, project_dir):
    """Convert an absolute path to a project-relative path with forward slashes."""
    return os.path.relpath(filepath, project_dir).replace("\\", "/")


# ──────────────────────────────────────────────────────────
# Main extraction
# ──────────────────────────────────────────────────────────

def collect_md_files(project_dir):
    """Walk scan directories and collect all .md files."""
    files = []
    for dirname in SCAN_DIRS:
        dirpath = os.path.join(project_dir, dirname)
        if not os.path.isdir(dirpath):
            continue
        for root, dirs, filenames in os.walk(dirpath):
            # Skip unwanted directories
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for fname in filenames:
                if fname.lower().endswith(".md"):
                    files.append(os.path.join(root, fname))
    return files


def extract_priority_from_context(lines, line_idx):
    """Try to extract priority from nearby table columns or text."""
    search_range = lines[max(0, line_idx-5):min(len(lines), line_idx+10)]
    for ln in search_range:
        # MoSCoW in text
        m = re.search(r'(?:Must\s+Have|Should\s+Have|Could\s+Have|Won\'t\s+Have)', ln, re.IGNORECASE)
        if m:
            return m.group(0).title()
        # Priority column
        m = re.search(r'\|\s*(Critical|High|Medium|Low)\s*\|', ln, re.IGNORECASE)
        if m:
            return m.group(1).title()
    return None


def scan_files(project_dir):
    """Scan all markdown files, extract definitions and references."""
    artifacts = OrderedDict()  # id -> artifact dict (first definition wins)
    references = []  # list of (source_id, target_id, file, line)
    all_ref_ids = set()  # all IDs found as references anywhere

    md_files = collect_md_files(project_dir)
    print(f"Scanning {len(md_files)} .md files across {SCAN_DIRS}...")

    for fpath in md_files:
        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except Exception as e:
            print(f"  Warning: cannot read {fpath}: {e}")
            continue

        frel = _rel_path(fpath, project_dir)
        fname = os.path.basename(fpath)

        # Check filename for artifact definition
        for ftype, fpat in FILENAME_PATTERNS:
            m = fpat.match(fname)
            if m:
                fid = normalize_id(m.group(1))
                if fid not in artifacts:
                    # Read first heading for title
                    title = ""
                    for ln in lines[:10]:
                        hm = re.match(r'^#{1,6}\s+(.*)', ln)
                        if hm:
                            title = hm.group(1).strip()
                            # Remove the ID itself from the title
                            title = re.sub(r'^' + re.escape(fid) + r'\s*[:\—\u2013\u2014–-]?\s*', '', title).strip()
                            break
                    artifacts[fid] = {
                        "id": fid,
                        "type": ftype,
                        "category": extract_category(fid, ftype),
                        "title": title,
                        "file": frel,
                        "line": 1,
                        "priority": None,
                        "stage": TYPE_TO_STAGE.get(ftype, "unknown"),
                    }

        # Scan line by line
        # Track which IDs are defined in this file (for reference context)
        file_context_ids = []

        for line_idx, line in enumerate(lines):
            line_num = line_idx + 1
            line_stripped = line.rstrip()

            # 1. Check heading-based definitions
            for dtype, dpat in DEF_PATTERNS:
                m = dpat.match(line_stripped)
                if m:
                    did = normalize_id(m.group(2))
                    title = m.group(3).strip() if m.group(3) else ""
                    # Clean common suffixes from title
                    title = re.sub(r'\s*\[.*?\]\s*$', '', title).strip()
                    title = title.rstrip(":").strip()

                    if did not in artifacts:
                        priority = extract_priority_from_context(lines, line_idx)
                        artifacts[did] = {
                            "id": did,
                            "type": dtype,
                            "category": extract_category(did, dtype),
                            "title": title,
                            "file": frel,
                            "line": line_num,
                            "priority": priority,
                            "stage": TYPE_TO_STAGE.get(dtype, "unknown"),
                        }
                    file_context_ids.append(did)
                    break  # only match first pattern per line

            # 2. Check table-based definitions
            for ttype, tpat in TABLE_DEF_PATTERNS:
                for tm in tpat.finditer(line_stripped):
                    tid = normalize_id(tm.group(1))
                    if tid not in artifacts:
                        # Try to get title from the same table row
                        cells = [c.strip() for c in line_stripped.split("|") if c.strip()]
                        title = ""
                        for i, cell in enumerate(cells):
                            if tid in cell and i + 1 < len(cells):
                                title = cells[i + 1]
                                break
                        artifacts[tid] = {
                            "id": tid,
                            "type": ttype,
                            "category": extract_category(tid, ttype),
                            "title": title,
                            "file": frel,
                            "line": line_num,
                            "priority": None,
                            "stage": TYPE_TO_STAGE.get(ttype, "unknown"),
                        }

            # 3. Extract all references on this line
            ref_ids = set()
            for rm in REF_PATTERN.finditer(line_stripped):
                rid = normalize_id(rm.group(1))
                # Skip noise IDs
                if any(rid.startswith(p) for p in NOISE_PREFIXES):
                    continue
                # Skip very short API matches that look like noise (API-v1, API-v2)
                if rid.startswith("API-v"):
                    continue
                ref_ids.add(rid)
                all_ref_ids.add(rid)

            # Build references: if this line has an ID definition, all other IDs on same line are references from that definition
            # Otherwise, use file context (the most recent heading-defined ID)
            if len(ref_ids) > 1:
                ref_list = sorted(ref_ids)
                for i, src in enumerate(ref_list):
                    for j, tgt in enumerate(ref_list):
                        if i != j:
                            references.append((src, tgt, frel, line_num))
            elif len(ref_ids) == 1 and file_context_ids:
                rid = list(ref_ids)[0]
                ctx_id = file_context_ids[-1]
                if rid != ctx_id:
                    references.append((ctx_id, rid, frel, line_num))

    return artifacts, references, all_ref_ids


def scan_commits(project_dir):
    """Scan git log for commits with Refs: and Task: trailers. Returns list of commit dicts."""
    # Check git availability
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            capture_output=True, text=True, cwd=project_dir, timeout=5
        )
        if result.returncode != 0:
            print("  Git not available — skipping commit scan.")
            return []
    except Exception:
        print("  Git not available — skipping commit scan.")
        return []

    commits_by_sha = {}  # full SHA -> commit dict

    for trailer in ["Refs:", "Task:"]:
        try:
            result = subprocess.run(
                ["git", "log", "--all", "--format=%H|%h|%s|%an|%aI|%b", f"--grep={trailer}"],
                capture_output=True, text=True, cwd=project_dir, timeout=30
            )
            if result.returncode != 0:
                continue

            # Parse output — each commit can span multiple lines (body has newlines)
            # Split by full SHA pattern at start of line
            raw = result.stdout
            entries = re.split(r'(?=^[0-9a-f]{40}\|)', raw, flags=re.MULTILINE)
            for entry in entries:
                entry = entry.strip()
                if not entry:
                    continue
                # Parse first line: fullSha|shortSha|subject|author|date
                parts = entry.split("|", 5)
                if len(parts) < 5:
                    continue
                full_sha = parts[0]
                short_sha = parts[1]
                subject = parts[2]
                author = parts[3]
                date = parts[4]
                body = parts[5] if len(parts) > 5 else ""

                if full_sha in commits_by_sha:
                    existing = commits_by_sha[full_sha]
                    if not existing.get("body") and body:
                        existing["body"] = body
                    continue

                commits_by_sha[full_sha] = {
                    "sha": short_sha,
                    "fullSha": full_sha,
                    "message": subject,
                    "author": author,
                    "date": date,
                    "body": body,
                    "taskId": None,
                    "refIds": [],
                }
        except Exception as e:
            print(f"  Warning: git log scan failed for {trailer}: {e}")
            continue

    # Parse trailers from body
    task_re = re.compile(r'^Task:\s*(TASK-F\d{1,2}-\d{3,4})\s*$', re.MULTILINE)
    refs_re = re.compile(r'^Refs:\s*(.+)$', re.MULTILINE)

    for commit in commits_by_sha.values():
        body = commit.get("body", "")
        # Extract Task: trailer
        tm = task_re.search(body)
        if tm:
            commit["taskId"] = tm.group(1)
        # Extract Refs: trailer
        rm = refs_re.search(body)
        if rm:
            refs_str = rm.group(1)
            ref_ids = [r.strip() for r in refs_str.split(",") if r.strip()]
            commit["refIds"] = ref_ids
        # Remove body from output (not needed in JSON)
        del commit["body"]

    commits = list(commits_by_sha.values())
    print(f"  Found {len(commits)} commits with Refs:/Task: trailers")
    return commits


def scan_code_refs(project_dir):
    """Scan src/ for Refs: comments linking to SDD artifacts."""
    src_dir = os.path.join(project_dir, "src")
    if not os.path.isdir(src_dir):
        return [], {"totalFiles": 0, "totalSymbols": 0, "symbolsWithRefs": 0}

    code_refs = []
    total_files = 0
    total_symbols = 0
    symbols_with_refs = 0
    extensions = {".ts", ".js", ".tsx", ".jsx"}

    # Pattern for Refs: in JSDoc/inline comments
    refs_pattern = re.compile(r'Refs?:\s*((?:(?:REQ|UC|INV|RN|WF|API|BDD|ADR|NFR|FASE|TASK)[-][A-Za-z0-9-]+(?:,\s*)?)+)')
    inline_ref_pattern = re.compile(r'//\s*((?:REQ|UC|INV|RN|WF|API|BDD|ADR|NFR)[-][A-Za-z0-9-]+)')
    symbol_pattern = re.compile(r'(?:export\s+)?(?:async\s+)?(?:function|class|const|let|var|interface|type|enum)\s+(\w+)')

    for root, dirs, filenames in os.walk(src_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in extensions:
                continue
            total_files += 1
            fpath = os.path.join(root, fname)
            try:
                with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                    lines = f.readlines()
            except Exception:
                continue

            frel = _rel_path(fpath, project_dir)
            # Count symbols in file
            file_symbols = []
            for i, line in enumerate(lines):
                sm = symbol_pattern.search(line)
                if sm:
                    file_symbols.append((i, sm.group(1)))
                    total_symbols += 1

            # Find Refs: comments
            for i, line in enumerate(lines):
                ref_ids = []
                rm = refs_pattern.search(line)
                if rm:
                    raw = rm.group(1)
                    ref_ids = [r.strip() for r in re.split(r'[,\s]+', raw) if r.strip() and classify_id(r.strip())]
                else:
                    im = inline_ref_pattern.search(line)
                    if im:
                        ref_ids = [im.group(1)]

                if ref_ids:
                    # Find nearest symbol
                    symbol = f"{os.path.basename(fpath)}:{i+1}"
                    symbol_type = "unknown"
                    for si, sname in reversed(file_symbols):
                        if si <= i + 2:
                            symbol = sname
                            # Determine type from the line
                            sline = lines[si] if si < len(lines) else ""
                            if "function" in sline or "async function" in sline:
                                symbol_type = "function"
                            elif "class " in sline:
                                symbol_type = "class"
                            elif "const " in sline:
                                symbol_type = "const"
                            elif "interface " in sline:
                                symbol_type = "interface"
                            elif "type " in sline:
                                symbol_type = "type"
                            elif "enum " in sline:
                                symbol_type = "enum"
                            else:
                                symbol_type = "variable"
                            symbols_with_refs += 1
                            break

                    code_refs.append({
                        "file": frel,
                        "line": i + 1,
                        "symbol": symbol,
                        "symbolType": symbol_type,
                        "refIds": ref_ids,
                    })

    print(f"  Code: {total_files} files, {total_symbols} symbols, {symbols_with_refs} with refs, {len(code_refs)} ref comments")
    return code_refs, {
        "totalFiles": total_files,
        "totalSymbols": total_symbols,
        "symbolsWithRefs": symbols_with_refs,
    }


def scan_test_refs(project_dir):
    """Scan tests/ for Refs: comments and test descriptions referencing SDD artifacts."""
    test_dirs = [os.path.join(project_dir, "tests"), os.path.join(project_dir, "test")]
    test_refs = []
    total_test_files = 0
    total_tests = 0
    tests_with_refs = 0
    extensions = {".ts", ".js", ".tsx", ".jsx"}

    refs_pattern = re.compile(r'Refs?:\s*((?:(?:REQ|UC|INV|RN|WF|API|BDD|ADR|NFR|FASE|TASK)[-][A-Za-z0-9-]+(?:,\s*)?)+)')
    test_desc_ref_pattern = re.compile(r'(?:describe|it|test)\(\s*[\'"`](.*?(?:REQ|UC|INV|BDD|WF|API|ADR|NFR)[-][A-Za-z0-9-]+.*?)[\'"`]')
    test_block_pattern = re.compile(r'(?:it|test)\(\s*[\'"`](.*?)[\'"`]')

    for test_dir in test_dirs:
        if not os.path.isdir(test_dir):
            continue
        for root, dirs, filenames in os.walk(test_dir):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for fname in filenames:
                ext = os.path.splitext(fname)[1].lower()
                if ext not in extensions:
                    continue
                total_test_files += 1
                fpath = os.path.join(root, fname)
                try:
                    with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                        lines = f.readlines()
                except Exception:
                    continue

                frel = _rel_path(fpath, project_dir)
                current_describe = ""

                for i, line in enumerate(lines):
                    # Track describe blocks
                    dm = re.search(r'describe\(\s*[\'"`](.*?)[\'"`]', line)
                    if dm:
                        current_describe = dm.group(1)

                    # Count test blocks
                    tm = test_block_pattern.search(line)
                    if tm:
                        total_tests += 1

                    # Find refs
                    ref_ids = []
                    rm = refs_pattern.search(line)
                    if rm:
                        raw = rm.group(1)
                        ref_ids = [r.strip() for r in re.split(r'[,\s]+', raw) if r.strip() and classify_id(r.strip())]

                    # Find refs in test descriptions
                    drm = test_desc_ref_pattern.search(line)
                    if drm:
                        desc_text = drm.group(1)
                        for m in REF_PATTERN.finditer(desc_text):
                            rid = m.group(1)
                            if rid not in ref_ids:
                                ref_ids.append(rid)

                    if ref_ids:
                        test_name = ""
                        tmatch = test_block_pattern.search(line)
                        if tmatch:
                            test_name = tmatch.group(1)
                            if current_describe:
                                test_name = f"{current_describe} > {test_name}"
                        elif current_describe:
                            test_name = current_describe
                        else:
                            test_name = f"{fname}:{i+1}"

                        tests_with_refs += 1
                        test_refs.append({
                            "file": frel,
                            "line": i + 1,
                            "testName": test_name,
                            "framework": "vitest",
                            "refIds": ref_ids,
                        })

    print(f"  Tests: {total_test_files} files, {total_tests} tests, {tests_with_refs} with refs")
    return test_refs, {
        "totalTestFiles": total_test_files,
        "totalTests": total_tests,
        "testsWithRefs": tests_with_refs,
    }


def classify_requirements(artifacts, incoming, outgoing):
    """Classify REQ artifacts by business domain, technical layer, and functional category."""
    # Business domain mapping from REQ category prefix
    domain_map = {
        # Extraction & Processing
        "EXT": "Extraction & Processing", "CVA": "Extraction & Processing",
        "VAL": "Extraction & Processing", "PRO": "Extraction & Processing",
        "DOC": "Extraction & Processing", "PAR": "Extraction & Processing",
        "OCR": "Extraction & Processing", "PRM": "Extraction & Processing",
        "MAT": "Matching & Selection", "OFF": "Matching & Selection",
        "SEL": "Matching & Selection", "SRC": "Matching & Selection",
        # Security & Auth
        "SEC": "Security & Auth", "AUT": "Security & Auth",
        "PRV": "Security & Auth", "LOG": "Security & Auth",
        "CRD": "Security & Auth", "TOK": "Security & Auth",
        "SSO": "Security & Auth",
        "GDP": "GDPR & Privacy", "GDPR": "GDPR & Privacy",
        "DPR": "GDPR & Privacy", "RET": "GDPR & Privacy",
        # Frontend & UI
        "UI": "Frontend & UI", "UX": "Frontend & UI",
        "DASH": "Frontend & UI", "NAV": "Frontend & UI",
        "FORM": "Frontend & UI", "MOD": "Frontend & UI",
        "VIS": "Frontend & UI", "I18N": "Frontend & UI",
        "ACC": "Frontend & UI",
        "CAN": "Candidate Portal", "VPR": "Candidate Portal",
        "DSH": "Dashboards & Reporting",
        # Data & Storage
        "DB": "Data & Storage", "IDX": "Data & Storage",
        "CAC": "Data & Storage", "MIG": "Data & Storage",
        "STO": "Data & Storage", "BAK": "Data & Storage",
        "ARC": "Data & Storage", "CACHE": "Data & Storage",
        "BLK": "Bulk Operations", "BAT": "Bulk Operations",
        # Integration & APIs
        "INT": "Integration & APIs", "WBH": "Integration & APIs",
        "NOT": "Integration & APIs", "MSG": "Integration & APIs",
        "EVT": "Integration & APIs", "SYN": "Integration & APIs",
        "NTF": "Integration & APIs", "INC": "Integration & APIs",
        # Infrastructure & DevOps
        "CFG": "Infrastructure & DevOps", "ENV": "Infrastructure & DevOps",
        "DEP": "Infrastructure & DevOps", "MON": "Infrastructure & DevOps",
        "INF": "Infrastructure & DevOps", "OPS": "Infrastructure & DevOps",
        "CI": "Infrastructure & DevOps",
        "SYS": "Infrastructure & DevOps", "TECH": "Infrastructure & DevOps",
        "AVAIL": "Infrastructure & DevOps",
        # Performance & Scalability
        "PERF": "Performance & Scalability", "SCAL": "Performance & Scalability",
        "RATE": "Performance & Scalability", "OBS": "Performance & Scalability",
        # Analytics & Reporting
        "RPT": "Analytics & Reporting", "ANL": "Analytics & Reporting",
        "MET": "Analytics & Reporting", "KPI": "Analytics & Reporting",
        "EXP": "Analytics & Reporting", "AGG": "Analytics & Reporting",
        # User & Org Management
        "USR": "User Management", "ROL": "User Management",
        "PER": "User Management", "ORG": "User Management",
        "TEN": "User Management",
        # Derived/Cross-cutting
        "DER": "Derived Requirements", "MNT": "Infrastructure & DevOps",
        "REC": "Infrastructure & DevOps",
    }

    # Find FASE linked to each REQ via TASK chain
    task_to_fase = {}
    for art in artifacts.values():
        if art["type"] == "TASK":
            m = re.match(r'TASK-F(\d+)-', art["id"])
            if m:
                task_to_fase[art["id"]] = int(m.group(1))

    classification_stats = {"byDomain": {}, "byLayer": {}, "byCategory": {}}

    for art in artifacts.values():
        if art["type"] != "REQ":
            art["classification"] = None
            continue

        cat = art.get("category")
        domain = domain_map.get(cat, "Other") if cat else "Other"

        # Technical layer: follow REQ -> UC -> TASK -> FASE
        fases = set()
        # Direct TASK links
        for tgt in outgoing.get(art["id"], set()):
            if tgt in task_to_fase:
                fases.add(task_to_fase[tgt])
        # Via UCs
        for src in incoming.get(art["id"], set()):
            if classify_id(src) == "UC":
                for tgt in outgoing.get(src, set()):
                    if tgt in task_to_fase:
                        fases.add(task_to_fase[tgt])

        if fases:
            # Most frequent layer
            layers = []
            for fn in fases:
                if fn == 0:
                    layers.append("Infrastructure")
                elif 1 <= fn <= 6:
                    layers.append("Backend")
                elif 7 <= fn <= 8:
                    layers.append("Frontend")
                else:
                    layers.append("Integration/Deployment")
            from collections import Counter
            layer = Counter(layers).most_common(1)[0][0]
        else:
            layer = "Unknown"

        # Functional category from section or category prefix
        nfr_cats = {"PERF", "SEC", "SCAL", "AVAIL", "TECH", "CACHE", "OBS", "RATE", "VAL", "I18N", "ACC"}
        security_cats = {"SEC", "AUT", "GDP", "GDPR", "DPR"}
        data_cats = {"RET", "DPR", "AUT", "MNT"}
        integration_cats = {"NTF", "INC", "DEP", "MON", "REC", "DER"}
        if cat in nfr_cats:
            func_cat = "Non-Functional"
        elif cat in security_cats:
            func_cat = "Security"
        elif cat in data_cats:
            func_cat = "Data"
        elif cat in integration_cats:
            func_cat = "Integration"
        else:
            func_cat = "Functional"

        art["classification"] = {
            "businessDomain": domain,
            "technicalLayer": layer,
            "functionalCategory": func_cat,
        }

        # Stats
        classification_stats["byDomain"][domain] = classification_stats["byDomain"].get(domain, 0) + 1
        classification_stats["byLayer"][layer] = classification_stats["byLayer"].get(layer, 0) + 1
        classification_stats["byCategory"][func_cat] = classification_stats["byCategory"].get(func_cat, 0) + 1

    return classification_stats


def build_graph(project_dir, output_dir, project_name, artifacts, references, all_ref_ids,
                commits=None, code_refs=None, code_stats=None, test_refs=None, test_stats=None):
    """Build the traceability graph JSON structure."""
    if commits is None:
        commits = []
    if code_refs is None:
        code_refs = []
    if code_stats is None:
        code_stats = {"totalFiles": 0, "totalSymbols": 0, "symbolsWithRefs": 0}
    if test_refs is None:
        test_refs = []
    if test_stats is None:
        test_stats = {"totalTestFiles": 0, "totalTests": 0, "testsWithRefs": 0}

    # Read pipeline state
    pipeline_state_file = os.path.join(project_dir, "pipeline-state.json")
    pipeline_data = {"currentStage": "unknown", "stages": []}
    if os.path.exists(pipeline_state_file):
        try:
            with open(pipeline_state_file, "r", encoding="utf-8") as f:
                ps = json.load(f)
            pipeline_data["currentStage"] = ps.get("currentStage", "unknown")
        except Exception:
            pass

    # Count artifacts per stage
    stage_counts = {}
    for art in artifacts.values():
        stage = art.get("stage", "unknown")
        stage_counts[stage] = stage_counts.get(stage, 0) + 1

    # Build pipeline stages
    stage_order = [
        "requirements-engineer",
        "specifications-engineer",
        "spec-auditor",
        "test-planner",
        "plan-architect",
        "task-generator",
        "task-implementer",
    ]

    if os.path.exists(pipeline_state_file):
        try:
            with open(pipeline_state_file, "r", encoding="utf-8") as f:
                ps = json.load(f)
            stages_data = ps.get("stages", {})
        except Exception:
            stages_data = {}
    else:
        stages_data = {}

    pipeline_stages = []
    for sname in stage_order:
        sd = stages_data.get(sname, {})
        pipeline_stages.append({
            "name": sname,
            "status": sd.get("status", "unknown"),
            "lastRun": sd.get("lastRun"),
            "artifactCount": stage_counts.get(sname, 0),
        })
    pipeline_data["stages"] = pipeline_stages

    # Deduplicate relationships
    seen_rels = set()
    deduped_rels = []
    for (src, tgt, sfile, line) in references:
        src_type = classify_id(src)
        tgt_type = classify_id(tgt)
        if not src_type or not tgt_type:
            continue
        rel_type = infer_relationship_type(src_type, tgt_type)
        key = (src, tgt, rel_type)
        if key not in seen_rels:
            seen_rels.add(key)
            deduped_rels.append({
                "source": src,
                "target": tgt,
                "type": rel_type,
                "sourceFile": sfile,
                "line": line,
            })

    # Compute statistics
    by_type = {}
    for art in artifacts.values():
        by_type[art["type"]] = by_type.get(art["type"], 0) + 1

    # Build incoming/outgoing indexes for coverage
    incoming = {}  # target -> set of source IDs
    outgoing = {}  # source -> set of target IDs
    for rel in deduped_rels:
        incoming.setdefault(rel["target"], set()).add(rel["source"])
        outgoing.setdefault(rel["source"], set()).add(rel["target"])

    # REQ coverage
    reqs = [a for a in artifacts.values() if a["type"] == "REQ"]
    total_reqs = len(reqs)

    def count_reqs_with(target_type):
        count = 0
        for req in reqs:
            rid = req["id"]
            # Check incoming: other artifacts pointing to this REQ
            for src in incoming.get(rid, set()):
                if classify_id(src) == target_type:
                    count += 1
                    break
            else:
                # Check outgoing: this REQ pointing to other artifacts
                for tgt in outgoing.get(rid, set()):
                    if classify_id(tgt) == target_type:
                        count += 1
                        break
        return count

    reqs_with_uc = count_reqs_with("UC")
    reqs_with_bdd = count_reqs_with("BDD")
    reqs_with_task = count_reqs_with("TASK")

    # Find orphans: artifacts defined but never referenced by any other artifact
    all_defined = set(artifacts.keys())
    all_referenced = set()
    for rel in deduped_rels:
        all_referenced.add(rel["target"])
        all_referenced.add(rel["source"])
    orphans = sorted(all_defined - all_referenced)

    # Find broken references: IDs referenced but never defined
    broken_refs = []
    broken_ids = set()
    for (src, tgt, sfile, line) in references:
        if tgt not in artifacts and tgt not in broken_ids:
            broken_ids.add(tgt)
            broken_refs.append({
                "ref": tgt,
                "referencedIn": sfile,
                "line": line,
            })

    # ── Commit processing ──────────────────────────────────
    artifact_commit_refs = {}  # artifact id -> list of commitRef objects
    reqs_with_commits_set = set()

    for commit in commits:
        commit_ref = {
            "sha": commit["sha"],
            "fullSha": commit["fullSha"],
            "message": commit["message"],
            "author": commit["author"],
            "date": commit["date"],
            "taskId": commit.get("taskId"),
            "refIds": commit.get("refIds", []),
        }
        # Attach to each referenced artifact
        for ref_id in commit.get("refIds", []):
            artifact_commit_refs.setdefault(ref_id, []).append(commit_ref)
            # Create implemented-by-commit relationship
            if ref_id in artifacts:
                rel_key = (commit["sha"], ref_id, "implemented-by-commit")
                if rel_key not in seen_rels:
                    seen_rels.add(rel_key)
                    deduped_rels.append({
                        "source": commit["sha"],
                        "target": ref_id,
                        "type": "implemented-by-commit",
                        "sourceFile": "git-log",
                        "line": 0,
                    })
        # Attach to task artifact if present
        task_id = commit.get("taskId")
        if task_id and task_id in artifacts:
            artifact_commit_refs.setdefault(task_id, []).append(commit_ref)

    # Inject commitRefs into artifact objects
    for art in artifacts.values():
        art["commitRefs"] = artifact_commit_refs.get(art["id"], [])

    # Propagate commits to REQs
    for req in reqs:
        rid = req["id"]
        if artifact_commit_refs.get(rid):
            reqs_with_commits_set.add(rid)
            continue
        for src in incoming.get(rid, set()):
            if artifact_commit_refs.get(src):
                reqs_with_commits_set.add(rid)
                break
        else:
            for tgt in outgoing.get(rid, set()):
                if artifact_commit_refs.get(tgt):
                    reqs_with_commits_set.add(rid)
                    break

    reqs_with_commits = len(reqs_with_commits_set)

    # ── Code refs processing ─────────────────────────────────
    artifact_code_refs = {}
    reqs_with_code_set = set()
    for cr in code_refs:
        for ref_id in cr.get("refIds", []):
            artifact_code_refs.setdefault(ref_id, []).append(cr)
    for art in artifacts.values():
        art["codeRefs"] = artifact_code_refs.get(art["id"], [])
    # Propagate to REQs
    for req in reqs:
        rid = req["id"]
        if artifact_code_refs.get(rid):
            reqs_with_code_set.add(rid)
            continue
        for src in incoming.get(rid, set()):
            if artifact_code_refs.get(src):
                reqs_with_code_set.add(rid)
                break
        else:
            for tgt in outgoing.get(rid, set()):
                if artifact_code_refs.get(tgt):
                    reqs_with_code_set.add(rid)
                    break
    reqs_with_code = len(reqs_with_code_set)

    # ── Test refs processing ──────────────────────────────────
    artifact_test_refs = {}
    reqs_with_tests_set = set()
    for tr in test_refs:
        for ref_id in tr.get("refIds", []):
            artifact_test_refs.setdefault(ref_id, []).append(tr)
    for art in artifacts.values():
        art["testRefs"] = artifact_test_refs.get(art["id"], [])
    # Propagate to REQs
    for req in reqs:
        rid = req["id"]
        if artifact_test_refs.get(rid):
            reqs_with_tests_set.add(rid)
            continue
        for src in incoming.get(rid, set()):
            if artifact_test_refs.get(src):
                reqs_with_tests_set.add(rid)
                break
        else:
            for tgt in outgoing.get(rid, set()):
                if artifact_test_refs.get(tgt):
                    reqs_with_tests_set.add(rid)
                    break
    reqs_with_tests = len(reqs_with_tests_set)

    # ── Classification ────────────────────────────────────────
    classification_stats = classify_requirements(artifacts, incoming, outgoing)

    # Commit stats
    commits_with_refs = sum(1 for c in commits if c.get("refIds"))
    commits_with_tasks = sum(1 for c in commits if c.get("taskId"))
    unique_tasks = len(set(c["taskId"] for c in commits if c.get("taskId")))

    commit_stats = {
        "totalCommits": len(commits),
        "commitsWithRefs": commits_with_refs,
        "commitsWithTasks": commits_with_tasks,
        "uniqueTasksCovered": unique_tasks,
    }

    stats = {
        "totalArtifacts": len(artifacts),
        "byType": OrderedDict(sorted(by_type.items())),
        "totalRelationships": len(deduped_rels),
        "traceabilityCoverage": {
            "reqsWithUCs": {
                "count": reqs_with_uc,
                "total": total_reqs,
                "percentage": round(reqs_with_uc / total_reqs * 100, 1) if total_reqs > 0 else 0,
            },
            "reqsWithBDD": {
                "count": reqs_with_bdd,
                "total": total_reqs,
                "percentage": round(reqs_with_bdd / total_reqs * 100, 1) if total_reqs > 0 else 0,
            },
            "reqsWithTasks": {
                "count": reqs_with_task,
                "total": total_reqs,
                "percentage": round(reqs_with_task / total_reqs * 100, 1) if total_reqs > 0 else 0,
            },
            "reqsWithCode": {
                "count": reqs_with_code,
                "total": total_reqs,
                "percentage": round(reqs_with_code / total_reqs * 100, 1) if total_reqs > 0 else 0,
            },
            "reqsWithTests": {
                "count": reqs_with_tests,
                "total": total_reqs,
                "percentage": round(reqs_with_tests / total_reqs * 100, 1) if total_reqs > 0 else 0,
            },
            "reqsWithCommits": {
                "count": reqs_with_commits,
                "total": total_reqs,
                "percentage": round(reqs_with_commits / total_reqs * 100, 1) if total_reqs > 0 else 0,
            },
        },
        "orphans": orphans[:50],  # cap at 50 to avoid bloat
        "brokenReferences": broken_refs[:50],
        "codeStats": code_stats,
        "testStats": test_stats,
        "commitStats": commit_stats,
        "classificationStats": classification_stats,
    }

    # ── Adoption data (loaded from dashboard/adoption-data.json) ─────────
    adoption_file = os.path.join(output_dir, "adoption-data.json")
    adoption = {"present": False}
    adoption_stats = None
    if os.path.exists(adoption_file):
        with open(adoption_file, "r", encoding="utf-8") as f:
            adoption_data = json.load(f)
        adoption = adoption_data.get("adoption", {"present": False})
        adoption_stats = adoption_data.get("adoptionStats", None)

    stats["adoptionStats"] = adoption_stats

    graph = {
        "$schema": "traceability-graph-v3",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "projectName": project_name,
        "pipeline": pipeline_data,
        "artifacts": list(artifacts.values()),
        "relationships": deduped_rels,
        "statistics": stats,
        "adoption": adoption,
    }

    return graph


def generate_html(graph, template_file, html_file):
    """Read the HTML template and inject the graph JSON."""
    if not os.path.exists(template_file):
        print(f"  Warning: HTML template not found at {template_file}")
        print("  Skipping HTML generation.")
        return False

    with open(template_file, "r", encoding="utf-8") as f:
        template_md = f.read()

    # Extract HTML between ```html and ```
    m = re.search(r'```html\s*\n(.*?)\n```', template_md, re.DOTALL)
    if not m:
        print("  Warning: could not find ```html block in template.")
        return False

    html = m.group(1)

    # Serialize JSON (compact but readable)
    data_json = json.dumps(graph, ensure_ascii=False)

    # Replace placeholders
    html = html.replace("{{DATA_JSON}}", data_json)
    html = html.replace("{{PROJECT_NAME}}", graph.get("projectName", "SDD Project"))

    with open(html_file, "w", encoding="utf-8") as f:
        f.write(html)

    return True


def main():
    parser = argparse.ArgumentParser(
        description="SDD Dashboard Generator — scans pipeline artifacts and generates traceability dashboard"
    )
    parser.add_argument(
        "--project", default=".",
        help="Project root directory (default: current working directory)"
    )
    parser.add_argument(
        "--output", default=None,
        help="Output directory (default: PROJECT/dashboard)"
    )
    args = parser.parse_args()

    # Resolve paths
    project_dir = os.path.abspath(args.project)
    output_dir = os.path.abspath(args.output) if args.output else os.path.join(project_dir, "dashboard")
    project_name = detect_project_name(project_dir)

    # Resolve template locations
    template_file = resolve_template(project_dir)
    guide_template_file = os.path.join(os.path.dirname(template_file), "guide-template.md")
    graph_file = os.path.join(output_dir, "traceability-graph.json")
    html_file = os.path.join(output_dir, "index.html")
    guide_file = os.path.join(output_dir, "guide.html")
    live_status_file = os.path.join(output_dir, "live-status.js")

    print("=" * 60)
    print("SDD Dashboard Generator")
    print("=" * 60)
    print(f"Project: {project_dir}")
    print(f"Name:    {project_name}")
    print(f"Output:  {output_dir}")
    print(f"Template:{template_file}")
    print()

    # Extract artifacts and references
    artifacts, references, all_ref_ids = scan_files(project_dir)

    print(f"\nExtracted {len(artifacts)} artifact definitions")
    print(f"Extracted {len(references)} raw references")

    # Scan source code
    print("\nScanning source code...")
    code_refs, code_stats = scan_code_refs(project_dir)

    # Scan tests
    print("\nScanning tests...")
    test_refs, test_stats = scan_test_refs(project_dir)

    # Scan commits
    print("\nScanning git commits...")
    commits = scan_commits(project_dir)

    # Build graph
    graph = build_graph(project_dir, output_dir, project_name, artifacts, references, all_ref_ids,
                        commits, code_refs, code_stats, test_refs, test_stats)

    # Write JSON
    os.makedirs(output_dir, exist_ok=True)
    with open(graph_file, "w", encoding="utf-8") as f:
        json.dump(graph, f, indent=2, ensure_ascii=False)
    print(f"\nWrote {graph_file}")

    # Print statistics
    stats = graph["statistics"]
    print(f"\n{'='*60}")
    print("STATISTICS")
    print(f"{'='*60}")
    print(f"Total artifacts: {stats['totalArtifacts']}")
    for t, c in stats["byType"].items():
        print(f"  {t}: {c}")
    print(f"Total relationships: {stats['totalRelationships']}")
    cov = stats["traceabilityCoverage"]
    print(f"REQs with UCs:   {cov['reqsWithUCs']['count']}/{cov['reqsWithUCs']['total']} ({cov['reqsWithUCs']['percentage']}%)")
    print(f"REQs with BDDs:  {cov['reqsWithBDD']['count']}/{cov['reqsWithBDD']['total']} ({cov['reqsWithBDD']['percentage']}%)")
    print(f"REQs with TASKs: {cov['reqsWithTasks']['count']}/{cov['reqsWithTasks']['total']} ({cov['reqsWithTasks']['percentage']}%)")
    if "reqsWithCommits" in cov:
        print(f"REQs with Commits: {cov['reqsWithCommits']['count']}/{cov['reqsWithCommits']['total']} ({cov['reqsWithCommits']['percentage']}%)")
    cs = stats.get("commitStats", {})
    if cs.get("totalCommits", 0) > 0:
        print(f"Commits: {cs['totalCommits']} total, {cs['commitsWithRefs']} with refs, {cs['commitsWithTasks']} with tasks, {cs['uniqueTasksCovered']} tasks covered")
    print(f"Orphans: {len(stats['orphans'])}")
    print(f"Broken references: {len(stats['brokenReferences'])}")

    # Print code/test stats
    cs2 = stats.get("codeStats", {})
    ts2 = stats.get("testStats", {})
    if cs2.get("totalFiles", 0) > 0:
        cov2 = stats["traceabilityCoverage"]
        print(f"REQs with Code:  {cov2['reqsWithCode']['count']}/{cov2['reqsWithCode']['total']} ({cov2['reqsWithCode']['percentage']}%)")
        print(f"REQs with Tests: {cov2['reqsWithTests']['count']}/{cov2['reqsWithTests']['total']} ({cov2['reqsWithTests']['percentage']}%)")
        print(f"Code files: {cs2['totalFiles']}, symbols: {cs2['totalSymbols']}, with refs: {cs2['symbolsWithRefs']}")
        print(f"Test files: {ts2['totalTestFiles']}, tests: {ts2['totalTests']}, with refs: {ts2['testsWithRefs']}")

    # Generate HTML
    print(f"\nGenerating HTML dashboard...")
    if generate_html(graph, template_file, html_file):
        print(f"Wrote {html_file}")
    else:
        print("HTML generation failed.")

    # Generate guide.html
    if os.path.exists(guide_template_file):
        try:
            with open(guide_template_file, "r", encoding="utf-8") as f:
                guide_md = f.read()
            gm = re.search(r'```html\s*\n(.*?)\n```', guide_md, re.DOTALL)
            if gm:
                with open(guide_file, "w", encoding="utf-8") as f:
                    f.write(gm.group(1))
                print(f"Wrote {guide_file}")
        except Exception as e:
            print(f"  Warning: guide generation failed: {e}")

    # Generate live-status.js seed file
    now_iso = datetime.now(timezone.utc).isoformat()
    live_status_js = f"""// SDD Live Status — generated by /sdd:dashboard
// Skills update this file during execution to show real-time progress
window.__SDD_LIVE_UPDATE({{
  "sessionId": null,
  "currentStage": null,
  "status": "idle",
  "lastHeartbeat": "{now_iso}",
  "progress": null,
  "message": "Dashboard generated. Waiting for pipeline activity.",
  "history": []
}});"""
    with open(live_status_file, "w", encoding="utf-8") as f:
        f.write(live_status_js)
    print(f"Wrote {live_status_file}")

    print(f"\n{'='*60}")
    print("Done!")
    print(f"{'='*60}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
