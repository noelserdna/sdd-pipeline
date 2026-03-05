#!/usr/bin/env python3
"""
SDD Dashboard Generator
Scans requirements/, spec/, plan/, task/, test/ for artifact definitions and cross-references,
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
import tempfile
from datetime import datetime, timezone
from collections import OrderedDict

# ──────────────────────────────────────────────────────────
# Constants (static — do not depend on CLI args)
# ──────────────────────────────────────────────────────────

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def _safe_write_json(output_path, data):
    """Write JSON atomically: write to temp file, then os.replace (Step 0.5)."""
    out_dir = os.path.dirname(output_path)
    os.makedirs(out_dir, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, suffix=".tmp")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        os.replace(tmp_path, output_path)
    except Exception:
        # Clean up temp file on failure
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def _safe_write_text(output_path, text):
    """Write text atomically: write to temp file, then os.replace (Step 0.5)."""
    out_dir = os.path.dirname(output_path)
    os.makedirs(out_dir, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=out_dir, suffix=".tmp")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp_path, output_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


SCAN_DIRS = ["requirements", "spec", "plan", "task", "test"]
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
    # TASK: ### TASK-F0-001: title  or  ### [x] TASK-F0-001: title  or  ### ✅ TASK-F0-001: title
    ("TASK", re.compile(r'^(#{1,6})\s+(?:\[[ x]\]\s*)?(?:✅\s*)?(TASK-F\d{1,2}-\d{3,4})\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
    # TASK in checkbox list: - [ ] TASK-F1-009 description  or  - [x] TASK-F1-009 description
    ("TASK", re.compile(r'^(\s*-\s*\[[ x]\])\s+(TASK-F\d{1,2}-\d{3,4})\s+(.*)', re.IGNORECASE)),
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
    r'(?<![a-zA-Z\-])'  # no letter or hyphen before (prevents REQ-001 matching inside INV-GDPR-REQ-001)
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

STAGE_COUNT_UNITS = {
    "requirements-engineer": "requirements",
    "specifications-engineer": "artifacts",
    "spec-auditor": "findings",
    "test-planner": "documents",
    "plan-architect": "phases",
    "task-generator": "tasks",
    "task-implementer": "files",
    "security-auditor": "findings",
    "req-change": "changes",
    "tech-designer": "dimensions",
    "ux-designer": "artifacts",
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


# Pattern for range references: "REQ-F-007 a REQ-F-019", "UC-001..UC-005", "INV-SEC-001..007"
# Captures: PREFIX-CAT-START {separator} PREFIX-CAT-END  or  PREFIX-CAT-START..END
_RANGE_PATTERN_FULL = re.compile(
    r'((?:REQ|UC|WF|BDD|INV|ADR|NFR|RN|FASE|TASK)(?:-[A-Z]+)?-)'  # prefix with optional category
    r'(\d{3,4})'                                                     # start number
    r'\s*(?:\.\.|\ba\b|\bhasta\b|\bal\b|–|—|-\s+)'                  # separator: .., a, hasta, al, en-dash, em-dash
    r'\s*(?:(?:REQ|UC|WF|BDD|INV|ADR|NFR|RN|FASE|TASK)(?:-[A-Z]+)?-)?'  # optional repeated prefix
    r'(\d{3,4})',                                                     # end number
    re.IGNORECASE
)


def expand_ranges(line):
    """Expand range notation in a line to individual IDs.

    Supports:
    - Spanish:  REQ-F-007 a REQ-F-019, del REQ-F-001 al REQ-F-005
    - Dot-dot:  UC-001..UC-005, INV-SEC-001..007
    - Dash:     UC-001 – UC-005 (en-dash/em-dash)

    Returns the line with ranges replaced by comma-separated individual IDs.
    """
    def _replace(m):
        prefix = m.group(1)  # e.g. "REQ-F-" or "UC-"
        start = int(m.group(2))
        end = int(m.group(3))
        if end < start or (end - start) > 200:  # sanity limit
            return m.group(0)
        width = len(m.group(2))  # preserve zero-padding
        ids = [f"{prefix}{str(i).zfill(width)}" for i in range(start, end + 1)]
        return ", ".join(ids)

    return _RANGE_PATTERN_FULL.sub(_replace, line)


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

            # 3. Extract all references on this line (expand ranges first)
            ref_ids = set()
            expanded_line = expand_ranges(line_stripped)
            for rm in REF_PATTERN.finditer(expanded_line):
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
                # Also connect the file context ID (e.g., API heading) to each ref ID on this line
                # This fixes orphaned APIs when a Refs: line under an API heading has 2+ IDs
                if file_context_ids:
                    ctx_id = file_context_ids[-1]
                    for rid in ref_list:
                        if rid != ctx_id:
                            references.append((ctx_id, rid, frel, line_num))
            elif len(ref_ids) == 1 and file_context_ids:
                rid = list(ref_ids)[0]
                ctx_id = file_context_ids[-1]
                if rid != ctx_id:
                    references.append((ctx_id, rid, frel, line_num))

    return artifacts, references, all_ref_ids


# Valid SDD artifact ID pattern for ref validation (Step 0.3)
ARTIFACT_ID_RE = re.compile(r'^(REQ|UC|WF|API|BDD|INV|ADR|RN|NFR|FASE|TASK)-[\w.-]+$')

# Files to skip during commit-based inference (utility/config files)
SKIP_FILE_PATTERNS = [
    re.compile(r'package\.json$'),
    re.compile(r'package-lock\.json$'),
    re.compile(r'tsconfig\.json$'),
    re.compile(r'\.config\.'),
    re.compile(r'\.lock$'),
    re.compile(r'\.env'),
    re.compile(r'README', re.IGNORECASE),
    re.compile(r'CHANGELOG', re.IGNORECASE),
    re.compile(r'^\.'),
    re.compile(r'node_modules/'),
    re.compile(r'__pycache__/'),
]


def _is_source_file(filepath):
    """Return True if file is likely a source/test file (not config/utility)."""
    for pat in SKIP_FILE_PATTERNS:
        if pat.search(filepath):
            return False
    # Must be under a source-like directory
    src_prefixes = ("src/", "lib/", "app/", "tests/", "test/", "pkg/", "cmd/", "internal/")
    return any(filepath.startswith(p) or ("/" + p) in filepath for p in src_prefixes)


def _parse_validated_refs(raw_refs_str):
    """Parse comma-separated ref IDs and validate against artifact ID pattern."""
    if not raw_refs_str or not raw_refs_str.strip():
        return []
    raw = [r.strip() for r in raw_refs_str.split(",") if r.strip()]
    return [r for r in raw if ARTIFACT_ID_RE.match(r)]


def scan_commits(project_dir):
    """Scan git log for commits with Refs: and Task: trailers.

    Uses a single git log call with null-byte delimiters and --name-only
    to get both metadata and changed files efficiently.
    Returns list of commit dicts.
    """
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

    # Single git log call: null-byte delimiters (Step 0.1), trailer extraction (Step 0.2),
    # --name-only for file lists (Step 1.1)
    COMMIT_DELIM = "---COMMIT-END---"
    try:
        result = subprocess.run(
            [
                "git", "log", "--all", "--name-only",
                f"--format=%H%x00%h%x00%s%x00%an%x00%aI%x00%(trailers:key=Refs,valueonly)%x00%(trailers:key=Task,valueonly){COMMIT_DELIM}"
            ],
            capture_output=True, text=True, cwd=project_dir, timeout=60
        )
        if result.returncode != 0:
            print(f"  Warning: git log failed (rc={result.returncode})")
            return []
    except Exception as e:
        print(f"  Warning: git log scan failed: {e}")
        return []

    commits = []
    for chunk in result.stdout.split(COMMIT_DELIM):
        chunk = chunk.strip()
        if not chunk:
            continue
        lines = chunk.split("\n")
        if not lines or not lines[0]:
            continue

        header = lines[0].split("\x00", 6)
        if len(header) < 5:
            continue

        full_sha = header[0]
        short_sha = header[1]
        subject = header[2]
        author = header[3]
        date = header[4]
        trailer_refs = header[5].strip() if len(header) > 5 else ""
        trailer_task = header[6].strip() if len(header) > 6 else ""

        # Parse and validate ref IDs (Step 0.3)
        ref_ids = _parse_validated_refs(trailer_refs)

        # Parse Task: trailer — validate format
        task_id = None
        if trailer_task:
            task_match = re.match(r'^(TASK-F\d{1,2}-\d{3,4})\s*$', trailer_task)
            if task_match:
                task_id = task_match.group(1)

        # Skip commits without any trailer data
        if not ref_ids and not task_id:
            continue

        # Extract changed files from remaining lines
        files = [f.strip() for f in lines[1:] if f.strip()]

        commits.append({
            "sha": short_sha,
            "fullSha": full_sha,
            "message": subject,
            "author": author,
            "date": date,
            "taskId": task_id,
            "refIds": ref_ids,
            "files": files,
        })

    print(f"  Found {len(commits)} commits with Refs:/Task: trailers")
    return commits


def infer_code_refs_from_commits(commits, artifacts, incoming, outgoing):
    """Infer code references from commits with Refs:/Task: trailers (Step 1.2).

    For each commit that has changed files AND trailer refs:
    - Files from Refs: trailer → origin "commit-inferred"
    - Files from Task: trailer (transitive via graph) → origin "task-inferred"

    Returns list of inferred codeRef dicts.
    """
    SIGNIFICANT_TYPES = {"UC", "INV", "API", "BDD", "REQ", "ADR", "WF"}
    inferred_refs = []

    for commit in commits:
        if not commit.get("files"):
            continue

        ref_ids = list(commit.get("refIds", []))
        task_id = commit.get("taskId")

        # If we have a taskId, BFS from the TASK node to find related artifacts
        task_inferred_ids = []
        if task_id and task_id in artifacts:
            visited = {task_id}
            queue = [(task_id, 0)]
            while queue:
                current, depth = queue.pop(0)
                if depth > 2:
                    continue
                neighbors = list(outgoing.get(current, set())) + list(incoming.get(current, set()))
                for n in neighbors:
                    if n not in visited:
                        visited.add(n)
                        n_type = classify_id(n)
                        if n_type in SIGNIFICANT_TYPES:
                            task_inferred_ids.append(n)
                        if depth < 2:
                            queue.append((n, depth + 1))

        # Determine origin based on what we have
        if ref_ids:
            origin = "commit-inferred"
        elif task_inferred_ids:
            origin = "task-inferred"
        else:
            continue

        # Combine all ref IDs (direct trailers + task-inferred)
        all_ref_ids = list(set(ref_ids + task_inferred_ids))
        if not all_ref_ids:
            continue

        # Create inferred code refs for source files in this commit
        for filepath in commit["files"]:
            fpath_fwd = filepath.replace("\\", "/")
            if not _is_source_file(fpath_fwd):
                continue

            inferred_refs.append({
                "file": fpath_fwd,
                "line": 0,
                "symbol": os.path.basename(fpath_fwd),
                "symbolType": "file",
                "refIds": all_ref_ids,
                "origin": origin,
                "inferredFrom": {
                    "commitSha": commit["sha"],
                    "taskId": task_id,
                    "trailerRefs": commit.get("refIds", []),
                },
            })

    print(f"  Inferred {len(inferred_refs)} code refs from commits")
    return inferred_refs


def propagate_refs_to_reqs(reqs, ref_map, incoming, outgoing, max_depth=3):
    """BFS N-hop propagation: find REQs reachable from artifacts with refs (Step 1.3).

    Args:
        reqs: set of REQ IDs to check
        ref_map: dict {artifactId: [...refs]} — artifacts that have code/test/commit refs
        incoming/outgoing: adjacency dicts from the relationship graph
        max_depth: maximum BFS depth
    Returns:
        set of REQ IDs that have refs reachable within max_depth hops
    """
    result = set()
    for req_id in reqs:
        # Quick check: direct ref on the REQ itself
        if ref_map.get(req_id):
            result.add(req_id)
            continue
        # BFS from REQ through non-REQ neighbors
        visited = {req_id}
        queue = [(req_id, 0)]
        found = False
        while queue and not found:
            current, depth = queue.pop(0)
            if depth > 0 and current in ref_map:
                result.add(req_id)
                found = True
                break
            if depth >= max_depth:
                continue
            neighbors = list(outgoing.get(current, set())) + list(incoming.get(current, set()))
            for neighbor in neighbors:
                if neighbor not in visited and not neighbor.startswith("REQ-"):
                    visited.add(neighbor)
                    queue.append((neighbor, depth + 1))
    return result


def apply_overrides(code_refs, overrides_path):
    """Apply manual overrides from .sdd/overrides.json (Step 1.5).

    Supports:
    - "pin": force-add refs for specific files
    - "suppress": remove inferred refs for specific files
    """
    if not os.path.exists(overrides_path):
        return code_refs, 0

    try:
        with open(overrides_path, "r", encoding="utf-8") as f:
            overrides = json.load(f)
    except Exception as e:
        print(f"  Warning: could not read overrides file: {e}")
        return code_refs, 0

    count = 0

    # Apply pins (add/force refs)
    for pin in overrides.get("pin", []):
        pin_file = pin.get("file", "").replace("\\", "/")
        pin_refs = pin.get("refs", [])
        if pin_file and pin_refs:
            code_refs.append({
                "file": pin_file,
                "line": 0,
                "symbol": os.path.basename(pin_file),
                "symbolType": "file",
                "refIds": pin_refs,
                "origin": "manual-override",
                "inferredFrom": None,
            })
            count += 1

    # Apply suppressions (remove inferred refs for specific files)
    for sup in overrides.get("suppress", []):
        sup_file = sup.get("file", "").replace("\\", "/")
        sup_refs = sup.get("refs", ["*"])
        if sup_file:
            if "*" in sup_refs:
                # Suppress all inferred refs for this file
                code_refs = [r for r in code_refs
                             if not (r["file"] == sup_file and r.get("origin", "direct") != "direct")]
            else:
                # Suppress specific ref IDs
                for cr in code_refs:
                    if cr["file"] == sup_file and cr.get("origin", "direct") != "direct":
                        cr["refIds"] = [rid for rid in cr["refIds"] if rid not in sup_refs]
                code_refs = [r for r in code_refs if r.get("refIds")]
            count += 1

    if count > 0:
        print(f"  Applied {count} manual overrides from .sdd/overrides.json")
    return code_refs, count


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


def _discover_test_dirs(project_dir):
    """Discover test directories: tests/, test/, and */tests/ one level deep."""
    candidates = [
        os.path.join(project_dir, "tests"),
        os.path.join(project_dir, "test"),
    ]
    # Auto-discover */tests/ and */test/ one level deep (e.g. frontend/tests/)
    try:
        for entry in os.listdir(project_dir):
            if entry.startswith(".") or entry in SKIP_DIRS:
                continue
            subdir = os.path.join(project_dir, entry)
            if os.path.isdir(subdir):
                for tname in ("tests", "test"):
                    tpath = os.path.join(subdir, tname)
                    if os.path.isdir(tpath) and tpath not in candidates:
                        candidates.append(tpath)
    except OSError:
        pass
    return candidates


def scan_test_refs(project_dir):
    """Scan tests/ for Refs: comments and test descriptions referencing SDD artifacts."""
    test_dirs = _discover_test_dirs(project_dir)
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


def scan_audits(project_dir):
    """Scan audits/*.md for severity breakdown, 3C gate status, corrections, and progression."""
    audits_dir = os.path.join(project_dir, "audits")
    result = {
        "auditFiles": [],
        "latestGate": None,
        "totalFindings": 0,
        "bySeverity": {"critical": 0, "high": 0, "medium": 0, "low": 0},
        "corrected": 0,
        "accepted": 0,
        "deferred": 0,
        "progression": [],
    }

    if not os.path.isdir(audits_dir):
        return result

    md_files = sorted(
        [f for f in os.listdir(audits_dir) if f.lower().endswith(".md")]
    )
    if not md_files:
        return result

    result["auditFiles"] = [f"audits/{f}" for f in md_files]

    # Patterns for table rows (pipe-delimited markdown tables)
    re_total = re.compile(
        r'\|\s*(?:Findings in audit|Total hallazgos|Total findings)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_critical = re.compile(
        r'\|\s*(?:Criticos|Critical|Cr[ií]ticos)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_high = re.compile(
        r'\|\s*(?:Altos|High)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_medium = re.compile(
        r'\|\s*(?:Medios|Medium)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_low = re.compile(
        r'\|\s*(?:Bajos|Low)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_corrected = re.compile(
        r'\|\s*(?:Corrections applied|Correcciones aplicadas|Corrected)\s*\|\s*(\d+)\s*/?\s*\d*\s*\|', re.IGNORECASE
    )
    re_accepted = re.compile(
        r'\|\s*(?:Accepted|Aceptados)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_deferred = re.compile(
        r'\|\s*(?:Deferred|Diferidos)\s*\|\s*(\d+)\s*\|', re.IGNORECASE
    )
    re_gate = re.compile(
        r'\|\s*(?:3C Gate|3C)\s*\|\s*(PASS|FAIL)\s*\|', re.IGNORECASE
    )
    # Progression table row: | vN.N | N | N | N | N | PASS/FAIL |
    re_progression = re.compile(
        r'\|\s*(v[\d.]+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(PASS|FAIL)\s*\|', re.IGNORECASE
    )

    latest_gate = None
    latest_total = 0
    latest_severity = {"critical": 0, "high": 0, "medium": 0, "low": 0}
    latest_corrected = 0
    latest_accepted = 0
    latest_deferred = 0
    progression = []

    for fname in md_files:
        fpath = os.path.join(audits_dir, fname)
        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                content = f.read()
        except Exception:
            continue

        # Extract progression table rows (most complete source)
        prog_rows = re_progression.findall(content)
        if prog_rows:
            progression = []
            for row in prog_rows:
                progression.append({
                    "version": row[0],
                    "findings": int(row[1]),
                    "fixed": int(row[2]),
                    "accepted": int(row[3]),
                    "deferred": int(row[4]),
                    "gate": row[5].upper(),
                })

        # Extract summary data (latest file wins)
        m = re_total.search(content)
        if m:
            latest_total = int(m.group(1))
        m = re_critical.search(content)
        if m:
            latest_severity["critical"] = int(m.group(1))
        m = re_high.search(content)
        if m:
            latest_severity["high"] = int(m.group(1))
        m = re_medium.search(content)
        if m:
            latest_severity["medium"] = int(m.group(1))
        m = re_low.search(content)
        if m:
            latest_severity["low"] = int(m.group(1))
        m = re_corrected.search(content)
        if m:
            latest_corrected = int(m.group(1))
        m = re_accepted.search(content)
        if m:
            latest_accepted = int(m.group(1))
        m = re_deferred.search(content)
        if m:
            latest_deferred = int(m.group(1))
        m = re_gate.search(content)
        if m:
            latest_gate = m.group(1).upper()

    result["latestGate"] = latest_gate
    result["totalFindings"] = latest_total
    result["bySeverity"] = latest_severity
    result["corrected"] = latest_corrected
    result["accepted"] = latest_accepted
    result["deferred"] = latest_deferred
    result["progression"] = progression

    sev_parts = []
    for sev in ("critical", "high", "medium", "low"):
        if latest_severity[sev]:
            sev_parts.append(f"{latest_severity[sev]} {sev}")
    sev_str = ", ".join(sev_parts) if sev_parts else "none"
    print(f"  Audits: {len(md_files)} files, {latest_total} findings ({sev_str}), gate={latest_gate or 'N/A'}")

    return result


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

    # Title-based domain inference rules: (keywords, domain_name)
    # Used as fallback when REQ prefix is generic (F, C, NF) or unknown
    _domain_keyword_rules = [
        # Customer & User Management
        (["cliente", "client", "usuario", "user", "alta", "baja", "registro", "registr", "perfil", "profile",
          "cuenta", "account", "contacto", "suscript", "subscri"], "Customer Management"),
        # Service & Product Management
        (["servicio", "service", "pack", "producto", "product", "tarifa", "plan", "oferta", "offer",
          "catalogo", "catalog", "tipo de servicio", "contratacion", "contrat"], "Service Management"),
        # Billing & Payments
        (["factur", "invoice", "billing", "pago", "payment", "cobro", "cargo", "charge", "precio", "price",
          "descuento", "discount", "impuesto", "tax", "penalizacion", "penal"], "Billing & Payments"),
        # Provisioning & Activation
        (["activacion", "activat", "provision", "suspend", "suspens", "reactivac", "reactivat",
          "desactivac", "deactivat", "permanencia", "portabilidad"], "Provisioning & Lifecycle"),
        # Incidents & Support
        (["incidencia", "incident", "ticket", "soporte", "support", "sla", "escalad", "resolucion",
          "resolut", "averia", "reclam", "claim", "queja", "complaint"], "Incidents & Support"),
        # Security & Auth
        (["seguridad", "security", "autenticac", "authenticat", "autorizac", "authorizat", "password",
          "contrasena", "token", "sesion", "session", "rol", "role", "permiso", "permission",
          "cifrado", "encrypt", "audit"], "Security & Auth"),
        # Integration & APIs
        (["integracion", "integrat", "api", "webhook", "notificacion", "notificat", "email", "sms",
          "mensaje", "message", "evento", "event", "sincroniz", "sync"], "Integration & APIs"),
        # Infrastructure & DevOps
        (["infraestructura", "infrastructure", "deploy", "despliegue", "monitor", "log", "backup",
          "migracion", "migrat", "config", "entorno", "environment", "ci/cd", "pipeline"], "Infrastructure & DevOps"),
        # Reporting & Analytics
        (["reporte", "report", "estadistic", "statistic", "dashboard", "tablero", "metricas",
          "metrics", "analitic", "analytic", "kpi", "export"], "Analytics & Reporting"),
        # Frontend & UI
        (["interfaz", "interface", "ui", "ux", "pantalla", "screen", "formulario", "form",
          "vista", "view", "navegacion", "navigation", "responsive", "accesibil"], "Frontend & UI"),
        # Data & Storage
        (["base de datos", "database", "almacen", "storage", "cache", "indice", "index",
          "archivo", "file", "import", "export"], "Data & Storage"),
    ]

    # Title-based layer inference rules: (keywords, layer_name)
    _layer_keyword_rules = [
        (["ui", "ux", "interfaz", "interface", "pantalla", "screen", "formulario", "form",
          "vista", "view", "frontend", "navegacion", "navigation", "responsive", "css",
          "componente visual", "widget", "boton", "button", "modal", "menu", "sidebar"], "Frontend"),
        (["infraestructura", "infrastructure", "deploy", "despliegue", "ci/cd", "pipeline",
          "docker", "kubernetes", "terraform", "cloud", "servidor", "server", "nginx",
          "ssl", "dns", "dominio", "domain", "hosting", "monitor", "log"], "Infrastructure"),
        (["integracion", "integrat", "webhook", "api extern", "third.party", "tercero",
          "pasarela", "gateway", "sync", "sincroniz", "import", "export", "migra"], "Integration/Deployment"),
    ]

    def _infer_domain_from_title(title):
        """Infer business domain from REQ title using keyword matching."""
        t = title.lower()
        for keywords, domain_name in _domain_keyword_rules:
            if any(kw in t for kw in keywords):
                return domain_name
        return "Other"

    def _infer_layer_from_title(title):
        """Infer technical layer from REQ title using keyword matching. Defaults to Backend."""
        t = title.lower()
        for keywords, layer_name in _layer_keyword_rules:
            if any(kw in t for kw in keywords):
                return layer_name
        # Default to Backend for functional requirements — most common layer
        return "Backend"

    # Generic REQ prefixes that don't carry domain information (IEEE 830 style)
    generic_cats = {"F", "NF", "C", "R", "D", "G", "S", "P"}

    from collections import Counter

    for art in artifacts.values():
        if art["type"] != "REQ":
            art["classification"] = None
            continue

        cat = art.get("category")
        title = art.get("title", "")

        # Business domain: try prefix map first, fallback to title inference
        if cat and cat not in generic_cats:
            domain = domain_map.get(cat, None)
            if domain is None:
                domain = _infer_domain_from_title(title)
        else:
            domain = _infer_domain_from_title(title)

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
            layer = Counter(layers).most_common(1)[0][0]
        else:
            # Fallback: infer from title keywords instead of showing "Unknown"
            layer = _infer_layer_from_title(title)

        # Functional category from section or category prefix
        nfr_cats = {"PERF", "SEC", "SCAL", "AVAIL", "TECH", "CACHE", "OBS", "RATE", "VAL", "I18N", "ACC", "NF"}
        security_cats = {"SEC", "AUT", "GDP", "GDPR", "DPR"}
        data_cats = {"RET", "DPR", "AUT", "MNT"}
        integration_cats = {"NTF", "INC", "DEP", "MON", "REC", "DER"}
        constraint_cats = {"C"}
        if cat in nfr_cats:
            func_cat = "Non-Functional"
        elif cat in security_cats:
            func_cat = "Security"
        elif cat in data_cats:
            func_cat = "Data"
        elif cat in integration_cats:
            func_cat = "Integration"
        elif cat in constraint_cats:
            func_cat = "Constraint"
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

    # Count audit files for spec-auditor stage (findings aren't graph artifacts)
    audits_dir = os.path.join(project_dir, "audits")
    if os.path.isdir(audits_dir):
        audit_files = [f for f in os.listdir(audits_dir) if f.lower().endswith(".md")]
        stage_counts["spec-auditor"] = stage_counts.get("spec-auditor", 0) + len(audit_files)

    # Count test plan documents for test-planner stage
    test_dir = os.path.join(project_dir, "test")
    if os.path.isdir(test_dir):
        test_files = [f for f in os.listdir(test_dir) if f.lower().endswith(".md")]
        stage_counts["test-planner"] = stage_counts.get("test-planner", 0) + len(test_files)

    # Count code + test files for task-implementer stage
    impl_count = code_stats.get("totalFiles", 0) + test_stats.get("totalTestFiles", 0)
    if impl_count > 0:
        stage_counts["task-implementer"] = impl_count

    # Fallback: when a stage is done/stale but count is 0, use summary.metrics from pipeline-state.json
    # This avoids showing misleading "0" for completed stages whose artifacts aren't captured by graph scanning
    # Each entry: (metric_keys_to_sum, label_override_when_fallback_used)
    SUMMARY_METRIC_FALLBACKS = {
        "test-planner": (["bdd_scenarios", "test_matrices", "perf_scenarios"], "scenarios"),
        "task-implementer": (["tasks_completed", "commits", "tests_passed"], "tasks/commits"),
        "spec-auditor": (["total_findings"], "findings"),
        "plan-architect": (["total_fases", "components"], "phases"),
        "task-generator": (["total_tasks"], "tasks"),
        "security-auditor": (["total_findings"], "findings"),
        "tech-designer": (["dimensions_analyzed"], "dimensions"),
        "ux-designer": (["dimensions_analyzed"], "dimensions"),
    }
    summary_label_overrides = {}
    for sname, (metric_keys, label_override) in SUMMARY_METRIC_FALLBACKS.items():
        if stage_counts.get(sname, 0) == 0:
            sd = stages_data.get(sname, {})
            if sd.get("status") in ("done", "stale"):
                summary = sd.get("summary")
                if summary and isinstance(summary.get("metrics"), dict):
                    metrics = summary["metrics"]
                    fallback = sum(metrics.get(k, 0) for k in metric_keys)
                    if fallback > 0:
                        stage_counts[sname] = fallback
                        summary_label_overrides[sname] = label_override

    # Fallback: count files recursively for test-planner if still 0
    if stage_counts.get("test-planner", 0) == 0:
        test_dir = os.path.join(project_dir, "test")
        if os.path.isdir(test_dir):
            count = 0
            for root, dirs, filenames in os.walk(test_dir):
                count += sum(1 for f in filenames if f.lower().endswith(".md"))
            if count > 0:
                stage_counts["test-planner"] = count

    # Fallback: count src/tests files with broader extensions for task-implementer if still 0
    if stage_counts.get("task-implementer", 0) == 0:
        broad_exts = {".ts", ".js", ".tsx", ".jsx", ".py", ".go", ".rs", ".java", ".kt", ".rb", ".cs", ".cpp", ".c", ".swift"}
        impl_fallback = 0
        for search_dir in ["src", "app", "lib", "tests", "test"]:
            d = os.path.join(project_dir, search_dir)
            if os.path.isdir(d):
                for root, dirs, filenames in os.walk(d):
                    dirs[:] = [dd for dd in dirs if dd not in SKIP_DIRS]
                    impl_fallback += sum(1 for f in filenames if os.path.splitext(f)[1].lower() in broad_exts)
        if impl_fallback > 0:
            stage_counts["task-implementer"] = impl_fallback

    pipeline_stages = []
    for sname in stage_order:
        sd = stages_data.get(sname, {})
        stage_entry = {
            "name": sname,
            "status": sd.get("status", "unknown"),
            "lastRun": sd.get("lastRun"),
            "artifactCount": stage_counts.get(sname, 0),
            "stageLabel": summary_label_overrides.get(sname, STAGE_COUNT_UNITS.get(sname, "artifacts")),
        }
        if sd.get("summary"):
            stage_entry["summary"] = sd["summary"]
        pipeline_stages.append(stage_entry)
    pipeline_data["stages"] = pipeline_stages

    # Lateral stages (security-auditor, req-change)
    lateral_names = ["security-auditor", "req-change", "tech-designer", "ux-designer"]
    lateral_stages = []
    for lname in lateral_names:
        ld = stages_data.get(lname)
        if ld:
            lateral_entry = {
                "name": lname,
                "status": ld.get("status", "unknown"),
                "lastRun": ld.get("lastRun"),
                "artifactCount": stage_counts.get(lname, 0),
                "stageLabel": summary_label_overrides.get(lname, STAGE_COUNT_UNITS.get(lname, "artifacts")),
            }
            if ld.get("summary"):
                lateral_entry["summary"] = ld["summary"]
            lateral_stages.append(lateral_entry)
    if lateral_stages:
        pipeline_data["lateralStages"] = lateral_stages

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

    # Categories that don't need Use Cases (they trace to NFR specs or are project constraints)
    _NO_UC_CATEGORIES = {"NF", "C"}

    def _req_needs_uc(req):
        """Return True if this REQ type is expected to have a Use Case."""
        cat = req.get("category")
        return cat not in _NO_UC_CATEGORIES

    # Functional REQs = those expected to have UCs
    functional_reqs = [r for r in reqs if _req_needs_uc(r)]
    total_functional_reqs = len(functional_reqs)

    def _neighbors(node_id):
        """Return all directly connected artifact IDs (both directions)."""
        return incoming.get(node_id, set()) | outgoing.get(node_id, set())

    def count_reqs_with(target_type):
        count = 0
        for req in reqs:
            rid = req["id"]
            for neighbor in _neighbors(rid):
                if classify_id(neighbor) == target_type:
                    count += 1
                    break
        return count

    def count_reqs_with_transitive(target_type, req_subset=None, bridge_types=("UC", "WF")):
        """Count REQs linked to target_type within 2 hops via bridge artifacts.

        Checks: REQ↔TARGET (1-hop) then REQ↔bridge↔TARGET (2-hop).
        bridge_types=None means any artifact type can serve as bridge.
        req_subset: if provided, only count from this subset of REQs.
        """
        subset = req_subset if req_subset is not None else reqs
        count = 0
        for req in subset:
            rid = req["id"]
            found = False
            neighbors = _neighbors(rid)
            # 1-hop: direct REQ↔TARGET
            for n in neighbors:
                if classify_id(n) == target_type:
                    found = True
                    break
            if not found:
                # 2-hop: REQ↔bridge↔TARGET
                for n in neighbors:
                    n_type = classify_id(n)
                    if n_type == "REQ":
                        continue  # skip REQ→REQ→TARGET to avoid noise
                    if bridge_types is not None and n_type not in bridge_types:
                        continue
                    for n2 in _neighbors(n):
                        if classify_id(n2) == target_type:
                            found = True
                            break
                    if found:
                        break
            if found:
                count += 1
        return count

    # UC coverage: only count functional REQs (NF/C don't need UCs by design)
    reqs_with_uc = count_reqs_with_transitive("UC", req_subset=functional_reqs, bridge_types=None)
    reqs_with_bdd = count_reqs_with_transitive("BDD", bridge_types=None)
    reqs_with_task = count_reqs_with_transitive("TASK")

    # Functional-only variants for implementation metrics
    # (NF/C REQs don't generate UCs, tasks, or code — so they shouldn't penalize coverage)
    functional_req_ids = {r["id"] for r in functional_reqs}
    reqs_with_bdd_functional = count_reqs_with_transitive("BDD", req_subset=functional_reqs, bridge_types=None)
    reqs_with_task_functional = count_reqs_with_transitive("TASK", req_subset=functional_reqs)

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

    for commit in commits:
        commit_ref = {
            "sha": commit["sha"],
            "fullSha": commit["fullSha"],
            "message": commit["message"],
            "author": commit["author"],
            "date": commit["date"],
            "taskId": commit.get("taskId"),
            "refIds": commit.get("refIds", []),
            "files": commit.get("files", []),
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

    # ── Code refs processing (Step 1.4: merge direct + inferred) ──
    # 1. Tag direct code refs with origin
    for cr in code_refs:
        cr["origin"] = "direct"
        cr["inferredFrom"] = None

    # 2. Infer code refs from commits (Step 1.2)
    inferred_code_refs = infer_code_refs_from_commits(commits, artifacts, incoming, outgoing)

    # 3. Deduplicate: if file+refId already has direct ref, skip inferred
    direct_keys = set()
    for cr in code_refs:
        for rid in cr.get("refIds", []):
            direct_keys.add((cr["file"], rid))

    deduped_inferred = []
    for cr in inferred_code_refs:
        new_ref_ids = [rid for rid in cr["refIds"] if (cr["file"], rid) not in direct_keys]
        if new_ref_ids:
            cr["refIds"] = new_ref_ids
            deduped_inferred.append(cr)

    # 4. Apply overrides (Step 1.5)
    overrides_path = os.path.join(project_dir, ".sdd", "overrides.json")
    all_code_refs = code_refs + deduped_inferred
    all_code_refs, override_count = apply_overrides(all_code_refs, overrides_path)

    # 5. Build artifact_code_refs map from merged refs
    artifact_code_refs = {}
    for cr in all_code_refs:
        for ref_id in cr.get("refIds", []):
            artifact_code_refs.setdefault(ref_id, []).append(cr)
    for art in artifacts.values():
        art["codeRefs"] = artifact_code_refs.get(art["id"], [])

    # ── Test refs processing ──────────────────────────────────
    artifact_test_refs = {}
    for tr in test_refs:
        for ref_id in tr.get("refIds", []):
            artifact_test_refs.setdefault(ref_id, []).append(tr)
    for art in artifacts.values():
        art["testRefs"] = artifact_test_refs.get(art["id"], [])

    # ── BFS N-hop propagation to REQs (Step 1.3) ──────────────
    req_ids = {r["id"] for r in reqs}
    reqs_with_code_set = propagate_refs_to_reqs(req_ids, artifact_code_refs, incoming, outgoing)
    reqs_with_tests_set = propagate_refs_to_reqs(req_ids, artifact_test_refs, incoming, outgoing)
    reqs_with_commits_set = propagate_refs_to_reqs(req_ids, artifact_commit_refs, incoming, outgoing)

    reqs_with_code = len(reqs_with_code_set)
    reqs_with_code_functional = len(reqs_with_code_set & functional_req_ids)
    reqs_with_tests = len(reqs_with_tests_set)
    reqs_with_tests_functional = len(reqs_with_tests_set & functional_req_ids)
    reqs_with_commits = len(reqs_with_commits_set)
    reqs_with_commits_functional = len(reqs_with_commits_set & functional_req_ids)

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

    # Enhanced code stats with inference breakdown (Step 1.6)
    direct_refs_count = sum(1 for cr in all_code_refs if cr.get("origin") == "direct")
    inferred_refs_count = sum(1 for cr in all_code_refs if cr.get("origin") in ("commit-inferred", "task-inferred"))
    code_stats["directRefs"] = direct_refs_count
    code_stats["inferredRefs"] = inferred_refs_count
    code_stats["manualOverrides"] = override_count

    stats = {
        "totalArtifacts": len(artifacts),
        "byType": OrderedDict(sorted(by_type.items())),
        "totalRelationships": len(deduped_rels),
        "traceabilityCoverage": {
            "totalReqs": total_reqs,
            "totalFunctionalReqs": total_functional_reqs,
            "reqBreakdown": classification_stats.get("byCategory", {}),
            "reqsWithUCs": {
                "count": reqs_with_uc,
                "total": total_functional_reqs,
                "percentage": round(reqs_with_uc / total_functional_reqs * 100, 1) if total_functional_reqs > 0 else 0,
            },
            "reqsWithBDD": {
                "count": reqs_with_bdd,
                "total": total_reqs,
                "percentage": round(reqs_with_bdd / total_reqs * 100, 1) if total_reqs > 0 else 0,
                "functionalCount": reqs_with_bdd_functional,
                "functionalTotal": total_functional_reqs,
                "functionalPercentage": round(reqs_with_bdd_functional / total_functional_reqs * 100, 1) if total_functional_reqs > 0 else 0,
            },
            "reqsWithTasks": {
                "count": reqs_with_task,
                "total": total_reqs,
                "percentage": round(reqs_with_task / total_reqs * 100, 1) if total_reqs > 0 else 0,
                "functionalCount": reqs_with_task_functional,
                "functionalTotal": total_functional_reqs,
                "functionalPercentage": round(reqs_with_task_functional / total_functional_reqs * 100, 1) if total_functional_reqs > 0 else 0,
            },
            "reqsWithCode": {
                "count": reqs_with_code,
                "total": total_reqs,
                "percentage": round(reqs_with_code / total_reqs * 100, 1) if total_reqs > 0 else 0,
                "functionalCount": reqs_with_code_functional,
                "functionalTotal": total_functional_reqs,
                "functionalPercentage": round(reqs_with_code_functional / total_functional_reqs * 100, 1) if total_functional_reqs > 0 else 0,
            },
            "reqsWithTests": {
                "count": reqs_with_tests,
                "total": total_reqs,
                "percentage": round(reqs_with_tests / total_reqs * 100, 1) if total_reqs > 0 else 0,
                "functionalCount": reqs_with_tests_functional,
                "functionalTotal": total_functional_reqs,
                "functionalPercentage": round(reqs_with_tests_functional / total_functional_reqs * 100, 1) if total_functional_reqs > 0 else 0,
            },
            "reqsWithCommits": {
                "count": reqs_with_commits,
                "total": total_reqs,
                "percentage": round(reqs_with_commits / total_reqs * 100, 1) if total_reqs > 0 else 0,
                "functionalCount": reqs_with_commits_functional,
                "functionalTotal": total_functional_reqs,
                "functionalPercentage": round(reqs_with_commits_functional / total_functional_reqs * 100, 1) if total_functional_reqs > 0 else 0,
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
    stats["auditData"] = scan_audits(project_dir)

    graph = {
        "$schema": "traceability-graph-v6",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "projectName": project_name,
        "pipeline": pipeline_data,
        "artifacts": list(artifacts.values()),
        "relationships": deduped_rels,
        "statistics": stats,
        "adoption": adoption,
    }

    # Preserve codeIntelligence from previous graph if it exists (Step 2.1)
    graph_file = os.path.join(output_dir, "traceability-graph.json")
    if os.path.exists(graph_file):
        try:
            with open(graph_file, "r", encoding="utf-8") as f:
                prev_graph = json.load(f)
            if "codeIntelligence" in prev_graph:
                graph["codeIntelligence"] = prev_graph["codeIntelligence"]
        except Exception:
            pass

    # Refine with code intelligence if available (Step 2.3)
    if "codeIntelligence" in graph:
        _refine_with_code_intelligence(graph)

    return graph


def _refine_with_code_intelligence(graph):
    """Refine file-level inferred codeRefs with symbol-level data from codeIntelligence (Step 2.3).

    For each codeRef with origin "commit-inferred" and symbolType "file",
    if codeIntelligence has symbols for that file, replace with symbol-level refs.
    """
    ci = graph.get("codeIntelligence")
    if not ci or not ci.get("indexed"):
        return

    # Build file→symbols index
    file_symbols = {}
    for sym in ci.get("symbols", []):
        fp = sym.get("filePath", "")
        file_symbols.setdefault(fp, []).append(sym)

    for art in graph.get("artifacts", []):
        refined = []
        for cr in art.get("codeRefs", []):
            if (cr.get("origin") in ("commit-inferred", "task-inferred")
                    and cr.get("symbolType") == "file"
                    and cr["file"] in file_symbols):
                # Replace with symbol-level refs
                for sym in file_symbols[cr["file"]]:
                    sym_ref_ids = list(set(sym.get("artifactRefs", []) + sym.get("inferredRefs", [])))
                    # Only include if there's overlap with the inferred refIds
                    overlap = set(sym_ref_ids) & set(cr["refIds"])
                    if overlap:
                        refined.append({
                            "file": cr["file"],
                            "line": sym.get("startLine", 0),
                            "symbol": sym["name"],
                            "symbolType": sym.get("type", "unknown").lower(),
                            "refIds": list(overlap),
                            "origin": "code-index",
                            "inferredFrom": cr.get("inferredFrom"),
                        })
                # If no symbol matched, keep original file-level ref
                if not any(r for r in refined if r["file"] == cr["file"]):
                    refined.append(cr)
            else:
                refined.append(cr)
        art["codeRefs"] = refined


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

    _safe_write_text(html_file, html)

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

    # Write JSON (crash-safe — Step 0.5)
    _safe_write_json(graph_file, graph)
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
                _safe_write_text(guide_file, gm.group(1))
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
    _safe_write_text(live_status_file, live_status_js)
    print(f"Wrote {live_status_file}")

    print(f"\n{'='*60}")
    print("Done!")
    print(f"{'='*60}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
