#!/usr/bin/env python3
"""
SDD traceability graph builder
Scans requirements/, spec/, plan/, task/, test/, code, tests and git history for artifact
definitions and cross-references, and writes dashboard/traceability-graph.json following the
graph schema (docs/design/graph-schema.md). The MCP server, hooks/sdd-session-start.sh and
hooks/sdd-augment-hook.js read that file.

Usage:
    python3 sdd-graph.py                          # CWD as project root
    python3 sdd-graph.py --project /path/to/proj  # explicit project root
    python3 sdd-graph.py --output /path/to/out    # explicit output directory
"""

import os
import re
import json
import sys
import argparse
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from collections import OrderedDict


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
    # API numeric: ## API-001-01 — createTask (operation, canonical) or legacy ## API-001
    ("API", re.compile(r'^(#{1,6})\s+(API-\d{3,4}(?:-\d{2})?)\s*[:\—\u2013\u2014–-]?\s*(.*)', re.IGNORECASE)),
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
    # TASK in checkbox list: - [ ] TASK-F1-009 description | `path`  ·  - [x] / - [!] (blocked)  ·  legacy bold id - [ ] **TASK-F1-009** description
    ("TASK", re.compile(r'^(\s*-\s*\[[ x!]\])\s+\**(TASK-F\d{1,2}-\d{3,4})\**\s+(.*?)(?:\s+\|\s+`.*)?$', re.IGNORECASE)),
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
    # Operation rows of a contract (Style: operations or http): | API-001-01 | Crear tarea | ...
    ("API", re.compile(r'^\s*\|\s*(API-\d{3,4}-\d{2})\s*\|')),
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
    r'|API-\d{3,4}(?:-\d{2})?'
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
    # Los ADR se contabilizan aparte, en su propia caja dentro de Arquitectura:
    # son decisiones de diseno, no especificaciones funcionales. Se mueven de
    # etapa (en vez de duplicarse) para que no se cuenten dos veces.
    "ADR": "architecture-decisions",
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
    "architecture-decisions": "decisions",
    "plan-documents": "documents",
    "task-generator": "tasks",
    "task-implementer": "src files",
    "functional-tests": "tests",
    "e2e-tests": "tests",
    "security-auditor": "findings",
    "req-change": "changes",
    "tech-designer": "dimensions",
    "ux-designer": "artifacts",
}

# Agrupacion de las etapas del pipeline en las cinco fases de ingenieria.
#
# El orden de la lista es el orden de renderizado, y el orden dentro de cada
# grupo es el orden de las cajas. Las etapas laterales (req-change,
# security-auditor, tech-designer, ux-designer) se colocan en su grupo
# correspondiente en lugar de quedar sueltas al margen del pipeline.
#
# Criterio de reparto: test-planner produce el PLAN de pruebas, que se escribe
# antes de implementar y es por tanto una especificacion; VERIFICACION agrupa
# solo la ejecucion real de tests.
#
# Esta tabla es el unico sitio donde se define la agrupacion: los consumidores la leen del
# JSON, asi que para recolocar una etapa basta con moverla aqui y regenerar.
STAGE_GROUPS = [
    ("requisitos", "Requisitos", [
        "requirements-engineer",
    ]),
    ("especificaciones", "Especificaciones", [
        "specifications-engineer",
        "architecture-decisions",
        "ux-designer",
    ]),
    # Planificacion agrupa lo que se decide ANTES de escribir codigo: en que fases
    # se divide el trabajo, en que tareas se descompone cada fase y como se va a
    # probar. task-generator produce documentos en task/, no implementacion.
    # Orden narrativo: primero el material donde se planifica (PLAN.md,
    # ARCHITECTURE.md, planes por fase), luego las fases que salen de ahi y las
    # tareas en que se descomponen.
    ("planificacion", "Planificacion", [
        "plan-documents",
        "plan-architect",
        "task-generator",
        "test-planner",
    ]),
    ("implementacion", "Implementacion", [
        "task-implementer",
    ]),
    ("verificacion", "Verificacion", [
        "functional-tests",
        "e2e-tests",
    ]),
]

# Etapas que se pintan como caja reducida. No son menos importantes: son
# complementos de la etapa principal de su grupo, y darles el mismo peso visual
# que a specifications-engineer (108 artefactos frente a 6) desequilibraba la
# lectura de la fila.
SECONDARY_STAGES = {
    "architecture-decisions",
    "plan-documents",
    "ux-designer",
    "test-planner",
    "spec-auditor",
    "security-auditor",
}

# Rotulo de visualizacion cuando el nombre interno resulta largo para la caja.
STAGE_DISPLAY_NAMES = {
    "architecture-decisions": "ADR",
    "plan-documents": "Plan docs",
}

# Indice inverso etapa -> id de grupo, derivado de STAGE_GROUPS para que no haya
# dos fuentes de verdad que puedan divergir.
STAGE_TO_GROUP = {
    stage_name: group_id
    for group_id, _label, stage_names in STAGE_GROUPS
    for stage_name in stage_names
}


def aggregate_group_status(statuses):
    """Estado agregado de un grupo a partir del de sus etapas.

    Se prioriza lo que el usuario necesita ver primero: si algo esta corriendo,
    el grupo esta corriendo; si hay mezcla de hecho y pendiente, es parcial.
    Una etapa `skipped` (la ruta adaptativa la dejo fuera) cuenta como satisfecha:
    no convierte el grupo en parcial; un grupo con todas sus etapas saltadas es `skipped`.
    """
    present = [s for s in statuses if s]
    if not present:
        return "unknown"
    if any(s == "running" for s in present):
        return "running"
    known = [s for s in present if s != "unknown"]
    if not known:
        return "unknown"
    if all(s == "skipped" for s in known):
        return "skipped"
    known = [s for s in known if s != "skipped"]
    if all(s == "done" for s in known):
        return "done"
    if all(s in ("pending", "unknown") for s in known):
        return "pending"
    return "partial"


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
    if id_str in _NFR_TABLE_IDS: return "NFR"
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


# Range references: "REQ-F-007 a REQ-F-019", "del REQ-F-001 al REQ-F-005", "UC-001 – UC-005", "UC-001..UC-005",
# "INV-SEC-001..007". Every separator except ".." needs the prefix repeated on the end ID: otherwise prose such as
# "NFR-001 — 150 ms p95" or "REQ-F-001 - 120 req/s" would expand into 150/120 invented IDs.
_RANGE_PREFIX = r'(?:REQ|UC|WF|BDD|INV|ADR|NFR|RN|FASE|TASK)(?:-[A-Z][A-Z0-9]*)?-'
_RANGE_DOTDOT = re.compile(
    r'(?P<p>' + _RANGE_PREFIX + r')(?P<s>\d{3,4})\s*\.\.\s*(?:(?P=p))?(?P<e>\d{3,4})(?![\d])',
    re.IGNORECASE,
)
_RANGE_WORD = re.compile(
    r'(?P<p>' + _RANGE_PREFIX + r')(?P<s>\d{3,4})\s*(?:\ba\b|\bhasta\b|\bal\b|\bto\b|–|—|-)\s*(?P=p)(?P<e>\d{3,4})(?![\d])',
    re.IGNORECASE,
)


def expand_ranges(line):
    """Expand range notation in a line to individual IDs.

    Supports:
    - Spanish/English: REQ-F-007 a REQ-F-019, del REQ-F-001 al REQ-F-005, UC-001 to UC-005
    - Dash:            UC-001 – UC-005, UC-001 - UC-005 (end ID must repeat the prefix)
    - Dot-dot:         UC-001..UC-005, INV-SEC-001..007 (bare end number allowed)

    Returns the line with ranges replaced by comma-separated individual IDs.
    """
    def _replace(m):
        prefix = m.group("p")  # e.g. "REQ-F-" or "UC-"
        start = int(m.group("s"))
        end = int(m.group("e"))
        if end <= start or (end - start) > 200:  # sanity limit
            return m.group(0)
        width = len(m.group("s"))  # preserve zero-padding
        return ", ".join(f"{prefix}{str(i).zfill(width)}" for i in range(start, end + 1))

    return _RANGE_WORD.sub(_replace, _RANGE_DOTDOT.sub(_replace, line))


def is_plausible_ref(rid, defined_ids):
    """A reference needs a digit (REQ-F-001, API-001-01, BDD-UC-001-01) unless it names a defined artifact.

    Named IDs without digits (API-tasks, BDD-extraction) are valid only when some file defines them;
    otherwise they are prose ("BDD-style", "API-first") and would show up as broken references.
    """
    return any(ch.isdigit() for ch in rid) or rid in defined_ids


def _rel_path(filepath, project_dir):
    """Convert an absolute path to a project-relative path with forward slashes."""
    return os.path.relpath(filepath, project_dir).replace("\\", "/")


# ──────────────────────────────────────────────────────────
# SDD Stack Profile (code/test paths)
# ──────────────────────────────────────────────────────────

# Source extensions scanned for Refs: comments (code and tests).
SOURCE_EXTENSIONS = {
    ".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte",
    ".py", ".rb", ".go", ".rs", ".java", ".kt", ".kts", ".scala", ".cs", ".php",
    ".swift", ".ex", ".exs", ".erl", ".c", ".h", ".cc", ".cpp", ".hpp", ".dart", ".lua",
}

# File names that mark a test file (used when a test path is also a code path, e.g. Next.js src/).
TEST_FILE_RE = re.compile(
    r'(?:\.(?:test|spec|e2e|pw)\.[a-z0-9]+$|_test\.[a-z0-9]+$|_spec\.rb$|(?:^|/)test_[^/]+\.py$|(?:^|/)Test[^/]*\.(?:java|kt|cs)$)'
)

DEFAULT_CODE_PATHS = ["src"]
DEFAULT_TEST_PATHS = ["tests"]


def read_stack_profile(project_dir):
    """Return the `- key: value` pairs of the `## SDD Stack Profile` section of the root CLAUDE.md.

    Same parsing as skills/sdd-task-implementer/references/stack-profile.md: lines inside code fences do not count,
    the section ends at the next level-1/level-2 heading, text after whitespace + `#` is a comment.
    Returns {} when there is no profile.
    """
    path = os.path.join(project_dir, "CLAUDE.md")
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError:
        return {}
    profile = {}
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
        m = re.match(r'^- ([a-z_]+):\s*(.*)$', line)
        if m:
            profile[m.group(1)] = re.sub(r'\s+#.*$', '', m.group(2)).strip()
    return profile


def _clean_rel_dir(value):
    value = value.strip().replace("\\", "/")
    if not value:
        return None
    while value.startswith("./"):
        value = value[2:]
    value = value.rstrip("/")
    if value.startswith("/") or ".." in value.split("/"):
        return None
    return value or "."


def resolve_scan_paths(project_dir):
    """Code and test paths from the SDD Stack Profile (`code_paths`/`test_paths`), defaults src / tests.

    Returns (code_paths, test_paths, declared). `declared` is False when CLAUDE.md has no profile paths:
    the scanners then also look at the legacy locations (test/, */tests/, e2e/) so older projects keep working.
    """
    profile = read_stack_profile(project_dir)

    def _paths(key, default):
        raw = profile.get(key, "")
        paths = [p for p in (_clean_rel_dir(x) for x in raw.split(",")) if p and "{" not in p]
        return (paths, True) if paths else (list(default), False)

    code_paths, code_declared = _paths("code_paths", DEFAULT_CODE_PATHS)
    test_paths, test_declared = _paths("test_paths", DEFAULT_TEST_PATHS)
    return code_paths, test_paths, (code_declared or test_declared)


def _under(rel, base):
    return base == "." or rel == base or rel.startswith(base + "/")


def is_test_path(rel, code_paths, test_paths):
    """True when a repo-relative file is a test: under a test path, and — when that test path is also
    covered by a code path (Next.js keeps tests next to code in src/) — named like a test."""
    for tp in test_paths:
        if not _under(rel, tp):
            continue
        overlaps = any(_under(tp, cp) or _under(cp, tp) for cp in code_paths)
        if not overlaps or TEST_FILE_RE.search(rel):
            return True
    return False


def is_code_path(rel, code_paths, test_paths):
    """True when a repo-relative file is implementation code (under a code path and not a test)."""
    return any(_under(rel, cp) for cp in code_paths) and not is_test_path(rel, code_paths, test_paths)


def _walk_source_files(project_dir, bases):
    """Yield (abs_path, rel_path) for source files under the given repo-relative directories (no duplicates)."""
    seen = set()
    for base in bases:
        root_dir = project_dir if base == "." else os.path.join(project_dir, base)
        if not os.path.isdir(root_dir):
            continue
        for root, dirs, filenames in os.walk(root_dir):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
            for fname in filenames:
                if os.path.splitext(fname)[1].lower() not in SOURCE_EXTENSIONS:
                    continue
                fpath = os.path.join(root, fname)
                frel = _rel_path(fpath, project_dir)
                if frel in seen:
                    continue
                seen.add(frel)
                yield fpath, frel


# ──────────────────────────────────────────────────────────
# Main extraction
# ──────────────────────────────────────────────────────────

# NFR ids defined in spec/nfr/*.md (Template 7): the first cell of a table row or a heading, with any prefix
# (SEC-005, SPEC-MNT-001, SPEC-PERF-001). Filled by scan_files; references and commit Refs to them resolve.
_NFR_TABLE_IDS = set()
_NFR_ID_RE = re.compile(r'^[A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*-\d{2,4}$')
_NFR_ROW_RE = re.compile(r'^\s*\|\s*([A-Z][A-Z0-9-]*-\d{2,4})\s*\|')
_NFR_HEADING_RE = re.compile(r'^#{1,6}\s+([A-Z][A-Z0-9-]*-\d{2,4})\s*(?:[:\u2013\u2014-]\s*(.*))?$')
# Module row of a contract (Templates 12/12b): | Module | API-002 — module `cli` … | defines the module id API-002
_MODULE_ROW_RE = re.compile(r'^\s*\|\s*Module\s*\|\s*(API-\d{3,4})(?![\w-])\s*[:\u2013\u2014-]?\s*([^|]*)\|')


def _is_nfr_file(frel):
    return frel.startswith("spec/nfr/") and frel.lower().endswith(".md")


def collect_nfr_ids(md_files, project_dir):
    """{id: (file, line, title)} of the ids an NFR file defines; ids of the other types keep their own patterns."""
    found = OrderedDict()
    for fpath in md_files:
        frel = _rel_path(fpath, project_dir)
        if not _is_nfr_file(frel):
            continue
        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError:
            continue
        for idx, line in enumerate(lines):
            line = line.rstrip()
            m = _NFR_ROW_RE.match(line) or _NFR_HEADING_RE.match(line)
            if not m:
                continue
            nid = m.group(1)
            known = classify_id(nid)
            if not _NFR_ID_RE.match(nid) or (known and known != "NFR") or nid in found:
                continue
            if line.lstrip().startswith("|"):
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                title = cells[1] if len(cells) > 1 else ""
            else:
                title = (m.group(2) or "").strip()
            found[nid] = (frel, idx + 1, title)
    return found


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

    _NFR_TABLE_IDS.clear()
    nfr_ids = collect_nfr_ids(md_files, project_dir)
    for nid, (nfile, nline, ntitle) in nfr_ids.items():
        if nid.startswith("NFR-"):
            continue  # NFR-NNN keeps the generic heading/table patterns
        _NFR_TABLE_IDS.add(nid)
        artifacts[nid] = {
            "id": nid, "type": "NFR", "category": nid.rsplit("-", 1)[0], "title": ntitle,
            "file": nfile, "line": nline, "priority": None, "stage": TYPE_TO_STAGE["NFR"],
        }
    nfr_ref_re = None
    if _NFR_TABLE_IDS:
        alts = "|".join(re.escape(i) for i in sorted(_NFR_TABLE_IDS, key=len, reverse=True))
        nfr_ref_re = re.compile(r'(?<![A-Za-z0-9-])(' + alts + r')(?![A-Za-z0-9-])')

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
        current_section = None  # nearest heading without an artifact ID (used to classify REQs)

        for line_idx, line in enumerate(lines):
            line_num = line_idx + 1
            line_stripped = line.rstrip()
            defined_here = False

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
                        if dtype == "REQ" and current_section:
                            artifacts[did]["section"] = current_section
                    file_context_ids.append(did)
                    defined_here = True
                    break  # only match first pattern per line
            if not defined_here:
                hm = re.match(r'^#{1,4}\s+(.+?)\s*#*\s*$', line_stripped)
                if hm:
                    current_section = hm.group(1)

            # 2. Check table-based definitions
            if frel.startswith("spec/contracts/"):
                mm = _MODULE_ROW_RE.match(line_stripped)
                if mm and mm.group(1) not in artifacts:
                    artifacts[mm.group(1)] = {
                        "id": mm.group(1), "type": "API", "category": "module",
                        "title": mm.group(2).strip() or os.path.splitext(fname)[0],
                        "file": frel, "line": line_num, "priority": None, "stage": TYPE_TO_STAGE["API"],
                    }
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
                        if ttype == "REQ" and current_section:
                            artifacts[tid]["section"] = current_section
            if _is_nfr_file(frel):
                nm = _NFR_ROW_RE.match(line_stripped)
                if nm and nm.group(1) in artifacts:
                    file_context_ids.append(nm.group(1))

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
            if nfr_ref_re is not None:
                for rm in nfr_ref_re.finditer(line_stripped):
                    ref_ids.add(rm.group(1))
                    all_ref_ids.add(rm.group(1))

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


# Legacy source-like directories, used only when the project declares no Stack Profile paths.
LEGACY_SOURCE_DIRS = ("src", "lib", "app", "tests", "test", "pkg", "cmd", "internal")


def _is_source_file(filepath, scan_dirs=None):
    """Return True if file is a code/test file (not config/utility).

    scan_dirs: repo-relative code+test paths from the SDD Stack Profile; None → legacy directories anywhere
    in the path.
    """
    for pat in SKIP_FILE_PATTERNS:
        if pat.search(filepath):
            return False
    if scan_dirs is not None:
        return any(_under(filepath, d) for d in scan_dirs)
    return any(filepath.startswith(p + "/") or ("/" + p + "/") in filepath for p in LEGACY_SOURCE_DIRS)


def _parse_validated_refs(raw_refs_str):
    """Parse comma-separated ref IDs and validate against artifact ID pattern."""
    if not raw_refs_str or not raw_refs_str.strip():
        return []
    raw = [r.strip() for r in raw_refs_str.split(",") if r.strip()]
    return [r for r in raw if ARTIFACT_ID_RE.match(r) or r in _NFR_TABLE_IDS]


def scan_commits(project_dir):
    """Commits reachable from HEAD that carry SDD trailers, reverted ones subtracted.

    Same rules as `sdd.mjs trace commits` (scripts/lib/git-log.mjs): Task/Refs/Change trailers as git parses them;
    a commit without any parsed id is read from `Task:|Refs:|Change:` body lines and marked legacy; a commit
    reverted by an effective revert does not count (a revert of a revert restores it). Uses `node sdd.mjs trace
    commits --json --files` when node is available, else the Python parser below. Returns list of commit dicts.
    """
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

    commits = _scan_commits_node(project_dir)
    source = "sdd.mjs trace commits"
    if commits is None:
        commits = _scan_commits_git(project_dir)
        source = "git log"
    print(f"  Found {len(commits)} commits with Refs:/Task: trailers ({source})")
    return commits


_TASK_ID_RE = re.compile(r'^TASK-F\d{1,2}-\d{3,4}$')
_ANY_TASK_RE = re.compile(r'^TASK-F\d+-\d+$')
_BODY_TRAILER_RE = re.compile(r'^(Task|Refs|Change)\s*:\s*(.*)$', re.IGNORECASE)
_REVERTS_RE = re.compile(r'This reverts commit ([0-9a-f]{7,40})')
SDD_CLI = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sdd.mjs")


def _first_task_id(raw):
    """First valid TASK-Fn-NNN in a comma-separated Task: trailer value, or None."""
    for part in (raw or "").split(","):
        part = part.strip()
        if _TASK_ID_RE.match(part):
            return part
    return None


def _tokens(value):
    """Split a trailer value like sdd.mjs does: "REQ-F-01, UC-001 (CR-3)." → [REQ-F-01, UC-001, CR-3]."""
    out = []
    for t in re.split(r'[\s,;]+', value or ""):
        t = re.sub(r'[.)\]]+$', '', re.sub(r'^[(\[]+', '', t))
        if t and t not in out:
            out.append(t)
    return out


def _commit_dict(full_sha, short_sha, subject, author, date, tasks, refs, files, legacy):
    """Graph commit record, or None when it carries neither a task nor an artifact ref."""
    task_id = next((t for t in tasks if _TASK_ID_RE.match(t)), None)
    ref_ids = [r for r in refs if ARTIFACT_ID_RE.match(r) or r in _NFR_TABLE_IDS]
    if not ref_ids and not task_id:
        return None
    return {
        "sha": short_sha,
        "fullSha": full_sha,
        "message": subject,
        "author": author,
        "date": date,
        "taskId": task_id,
        "refIds": ref_ids,
        "files": files,
        "legacy": legacy,
    }


def _effective(commits):
    """Set of shas not undone by an effective revert (port of effectiveCommits in scripts/lib/git-log.mjs)."""
    shas = [c["sha"] for c in commits]
    known = set(shas)
    reverted_by = {}
    for c in commits:
        for target in c["reverts"]:
            full = target if target in known else next((x for x in shas if x.startswith(target)), None)
            if full:
                reverted_by.setdefault(full, []).append(c["sha"])
    memo = {}

    def eff(sha):
        if sha in memo:
            return memo[sha]
        memo[sha] = True
        memo[sha] = not any(eff(r) for r in reverted_by.get(sha, []))
        return memo[sha]

    return {s for s in shas if eff(s)}


def _git_commits(project_dir, legacy_only=False):
    """Python reading of HEAD, same rules as sdd.mjs trace commits (used when node is unavailable)."""
    if subprocess.run(["git", "rev-parse", "--verify", "-q", "HEAD^{commit}"], capture_output=True,
                      cwd=project_dir).returncode != 0:
        return []
    tr = lambda k: f"%(trailers:key={k},valueonly,separator=%x2C)"
    fmt = f"--format=%x1e%H%x1f%h%x1f{tr('Task')}%x1f{tr('Refs')}%x1f{tr('Change')}%x1f%s%x1f%an%x1f%aI%x1f%b%x1f"
    try:
        result = subprocess.run(["git", "-c", "core.quotepath=off", "log", "--name-only", fmt, "HEAD"],
                                capture_output=True, text=True, cwd=project_dir, timeout=60)
        if result.returncode != 0:
            print(f"  Warning: git log failed (rc={result.returncode})")
            return []
    except Exception as e:
        print(f"  Warning: git log scan failed: {e}")
        return []

    raw = []
    for rec in result.stdout.split("\x1e")[1:]:
        parts = rec.split("\x1f")
        if len(parts) < 10:
            continue
        full_sha, short_sha, t, r, c, subject, author, date, body = parts[:9]
        tail = "\x1f".join(parts[9:])
        tasks = [x for x in _tokens(t) if _ANY_TASK_RE.match(x)]
        refs, changes = _tokens(r), _tokens(c)
        legacy = False
        if not (tasks or refs or changes):
            found = {"task": [], "refs": [], "change": []}
            for line in body.splitlines():
                m = _BODY_TRAILER_RE.match(line)
                if m:
                    found[m.group(1).lower()].append(m.group(2))
            tasks = [x for x in _tokens(",".join(found["task"])) if _ANY_TASK_RE.match(x)]
            refs, changes = _tokens(",".join(found["refs"])), _tokens(",".join(found["change"]))
            legacy = bool(tasks or refs or changes)
        raw.append({"sha": full_sha, "short": short_sha, "subject": subject, "author": author, "date": date,
                    "tasks": tasks, "refs": refs, "legacy": legacy, "reverts": _REVERTS_RE.findall(body),
                    "files": [f.strip() for f in tail.split("\n") if f.strip()]})

    effective = _effective(raw)
    commits = []
    for c in raw:
        if c["sha"] not in effective or (legacy_only and not c["legacy"]):
            continue
        d = _commit_dict(c["sha"], c["short"], c["subject"], c["author"], c["date"], c["tasks"], c["refs"],
                         c["files"], c["legacy"])
        if d:
            commits.append(d)
    return commits


def _scan_commits_git(project_dir):
    return _git_commits(project_dir)


def _scan_commits_body_fallback(project_dir):
    """Commits whose Task/Refs lines sit in the body but not in a parseable trailer block (legacy commits)."""
    return _git_commits(project_dir, legacy_only=True)


def _scan_commits_node(project_dir):
    """Commits from `node sdd.mjs trace commits --json --files`; None when node or the CLI is unavailable."""
    if os.environ.get("SDD_GRAPH_NO_NODE") == "1" or not shutil.which("node") or not os.path.exists(SDD_CLI):
        return None
    try:
        result = subprocess.run(["node", SDD_CLI, "trace", "commits", "--json", "--files", "--repo", project_dir],
                                capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
        meta_out = subprocess.run(["git", "log", "--format=%H%x1f%h%x1f%an%x1f%aI", "HEAD"], capture_output=True,
                                  text=True, cwd=project_dir, timeout=60).stdout
    except Exception:
        return None
    meta = {}
    for line in meta_out.splitlines():
        parts = line.split("\x1f")
        if len(parts) == 4:
            meta[parts[0]] = parts[1:]
    commits = []
    for c in data.get("commits", []):
        if c.get("effective") is False:
            continue
        short_sha, author, date = meta.get(c["sha"], [c["sha"][:7], "", ""])
        d = _commit_dict(c["sha"], short_sha, c.get("subject", ""), author, date, c.get("tasks", []),
                         c.get("refs", []), c.get("files", []), bool(c.get("legacy")))
        if d:
            commits.append(d)
    return commits


def _build_rename_map(project_dir, old_paths):
    """Map old file paths to their current names, following rename chains.

    One `git log -M --diff-filter=R` over the whole history instead of a `git log --follow` per file.
    Only paths in old_paths are resolved. Returns {old_path: current_path}.
    """
    if not old_paths:
        return {}
    try:
        result = subprocess.run(
            ["git", "log", "HEAD", "-M", "--diff-filter=R", "--name-status", "--format="],
            capture_output=True, text=True, cwd=project_dir, timeout=60
        )
        if result.returncode != 0:
            return {}
    except Exception:
        return {}

    # git log lists newest first; keep the newest rename of each source path.
    step = {}
    for line in result.stdout.splitlines():
        parts = line.strip().split("\t")
        if len(parts) >= 3 and parts[0].startswith("R"):
            old_path = parts[1].replace("\\", "/")
            new_path = parts[2].replace("\\", "/")
            step.setdefault(old_path, new_path)

    rename_map = {}
    for old_path in old_paths:
        current, hops = old_path, 0
        while current in step and hops < 20:
            current, hops = step[current], hops + 1
        if current != old_path and os.path.exists(os.path.join(project_dir, current)):
            rename_map[old_path] = current
    return rename_map


# graph-schema.md: task-inferred refs have a fixed 0.5 confidence; commit/blame-inferred 0.6-0.9 by recency.
TASK_INFERRED_CONFIDENCE = 0.5


def _compute_confidence(commit_rank, origin="commit-inferred"):
    """Confidence of an inferred ref.

    task-inferred: 0.5 (only a Task: trailer, resolved through the graph).
    commit/blame-inferred, by commit recency rank (0-indexed) among the commits touching the file:
    0 → 0.9, 1 → 0.8, 2 → 0.7, older → 0.6 (floor).
    """
    if origin == "task-inferred":
        return TASK_INFERRED_CONFIDENCE
    return {0: 0.9, 1: 0.8, 2: 0.7}.get(commit_rank, 0.6)


def _task_related_artifacts(task_id, incoming, outgoing, significant_types):
    """Artifacts a TASK points at, plus the REQs those artifacts trace to.

    Never walks through a FASE or a sibling TASK, and the second hop only climbs to REQs: a FASE links every
    UC/API of the phase, and a FASE file that lists "UC-001 y UC-002" on one line links those UCs to each
    other, so a wider walk would attach the whole phase to every file the task touched.
    """
    def _neighbours(node):
        return sorted(outgoing.get(node, set()) | incoming.get(node, set()))

    found = []
    seen = {task_id}
    first_hop = []
    for n in _neighbours(task_id):
        n_type = classify_id(n)
        if n in seen or n_type in ("FASE", "TASK") or n_type not in significant_types:
            continue
        seen.add(n)
        found.append(n)
        first_hop.append(n)
    for node in first_hop:
        if classify_id(node) == "REQ":
            continue
        for n in _neighbours(node):
            if n not in seen and classify_id(n) == "REQ":
                seen.add(n)
                found.append(n)
    return found


def infer_code_refs_from_commits(commits, artifacts, incoming, outgoing, project_dir=None, scan_dirs=None):
    """Infer code references from commits with Refs:/Task: trailers (Step 1.2).

    For each commit that has changed files:
    - IDs from the Refs: trailer → origin "commit-inferred" (confidence 0.6-0.9 by recency)
    - IDs reached from the Task: trailer through the graph (not in Refs:) → origin "task-inferred" (0.5)
    - Refs of files renamed since → origin "blame-inferred" on the current path

    scan_dirs: code+test paths of the SDD Stack Profile (None → legacy source directories).
    Returns list of inferred codeRef dicts.
    """
    SIGNIFICANT_TYPES = {"UC", "INV", "API", "BDD", "REQ", "ADR", "WF"}

    # Phase 1: Collect per-file, per-artifactId entries with commit metadata
    file_artifact_commits = {}  # (file, artifactId) -> [(commit, origin, task_id), ...]

    for commit in commits:
        if not commit.get("files"):
            continue

        ref_ids = list(commit.get("refIds", []))
        task_id = commit.get("taskId")

        task_inferred_ids = []
        if task_id and task_id in artifacts:
            task_inferred_ids = [
                a for a in _task_related_artifacts(task_id, incoming, outgoing, SIGNIFICANT_TYPES)
                if a not in ref_ids
            ]

        pairs = [(rid, "commit-inferred") for rid in dict.fromkeys(ref_ids)]
        pairs += [(rid, "task-inferred") for rid in task_inferred_ids]
        if not pairs:
            continue

        for filepath in commit["files"]:
            fpath_fwd = filepath.replace("\\", "/")
            if not _is_source_file(fpath_fwd, scan_dirs):
                continue
            for artifact_id, origin in pairs:
                file_artifact_commits.setdefault((fpath_fwd, artifact_id), []).append(
                    (commit, origin, task_id)
                )

    # Phase 2: Rename tracking — propagate refs from old paths to current paths (skipped when nothing to track)
    if project_dir and file_artifact_commits:
        old_paths = {
            f for (f, _aid) in file_artifact_commits
            if not os.path.exists(os.path.join(project_dir, f))
        }
        rename_map = _build_rename_map(project_dir, old_paths)

        if rename_map:
            blame_additions = {}
            for old_path, new_path in rename_map.items():
                for (f, artifact_id) in list(file_artifact_commits):
                    if f != old_path:
                        continue
                    new_key = (new_path, artifact_id)
                    if new_key not in file_artifact_commits:
                        blame_additions[new_key] = [
                            (commit, "blame-inferred", task_id)
                            for (commit, _origin, task_id) in file_artifact_commits[(old_path, artifact_id)]
                        ]
            for key, entries in blame_additions.items():
                file_artifact_commits.setdefault(key, []).extend(entries)
            if blame_additions:
                print(f"  Rename tracking: propagated refs across {len(rename_map)} renames, {len(blame_additions)} new file-artifact pairs")

    # Phase 3: Sort commits per (file, artifactId) by date descending and assign confidence
    inferred_refs = []

    # Group by file to emit one codeRef per file with all its artifact refs
    file_refs = {}  # file -> {artifactId: (confidence, origin, best_commit, task_id)}

    for (fpath, artifact_id), entries in file_artifact_commits.items():
        # Best entry: an explicit Refs: trailer beats a task-inferred link, then the most recent commit
        sorted_entries = sorted(
            entries,
            key=lambda e: (e[1] != "task-inferred", e[0].get("date", "")),
            reverse=True,
        )
        best_commit, best_origin, best_task_id = sorted_entries[0]
        confidence = _compute_confidence(0, best_origin)

        # Confidence is re-ranked below against all commits touching this file
        file_refs.setdefault(fpath, {})[artifact_id] = (
            confidence, best_origin, best_commit, best_task_id
        )

    # Now compute per-file commit ranking for confidence
    # Collect all commits per file (across all artifacts) for ranking
    file_commit_dates = {}  # file -> sorted list of unique (date, sha)
    for (fpath, artifact_id), entries in file_artifact_commits.items():
        for (commit, _origin, _task_id) in entries:
            file_commit_dates.setdefault(fpath, set()).add(
                (commit.get("date", ""), commit["sha"])
            )

    for fpath in file_commit_dates:
        file_commit_dates[fpath] = sorted(
            file_commit_dates[fpath],
            key=lambda x: x[0],
            reverse=True,
        )

    # Rebuild with proper cross-artifact ranking
    for fpath, artifact_map in file_refs.items():
        # Build a date-ranked index for this file
        date_rank = {}
        for rank, (date, sha) in enumerate(file_commit_dates.get(fpath, [])):
            date_rank[sha] = rank

        for artifact_id, (_, best_origin, best_commit, best_task_id) in artifact_map.items():
            commit_rank = date_rank.get(best_commit["sha"], 3)
            confidence = _compute_confidence(commit_rank, best_origin)

            # Update the stored confidence
            artifact_map[artifact_id] = (
                confidence, best_origin, best_commit, best_task_id
            )

    # Phase 4: Emit one inferred codeRef per file, aggregating all artifact refs
    for fpath, artifact_map in file_refs.items():
        # Group by (origin, commit_sha) to produce coherent codeRef entries
        origin_groups = {}  # (origin, sha) -> {refIds, confidence_min, commit, task_id}
        for artifact_id, (confidence, origin, commit, task_id) in artifact_map.items():
            group_key = (origin, commit["sha"])
            if group_key not in origin_groups:
                origin_groups[group_key] = {
                    "refIds": [],
                    "confidence": confidence,
                    "commit": commit,
                    "task_id": task_id,
                    "origin": origin,
                }
            origin_groups[group_key]["refIds"].append(artifact_id)
            # Use the lowest confidence in the group (conservative)
            origin_groups[group_key]["confidence"] = min(
                origin_groups[group_key]["confidence"], confidence
            )

        for group_key, group in origin_groups.items():
            inferred_refs.append({
                "file": fpath,
                "line": 0,
                "symbol": os.path.basename(fpath),
                "symbolType": "file",
                "refIds": sorted(set(group["refIds"])),
                "origin": group["origin"],
                "confidence": group["confidence"],
                "inferredFrom": {
                    "commitSha": group["commit"]["sha"],
                    "taskId": group["task_id"],
                    "trailerRefs": group["commit"].get("refIds", []),
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


def propagate_refs_to_req_artifacts(artifacts, req_ids, ref_map, incoming, outgoing, ref_key, max_depth=3):
    """Propagate codeRefs/testRefs from downstream artifacts to REQ nodes (Step 1.3b).

    The existing propagate_refs_to_reqs() computes which REQs have transitive
    coverage (used for statistics), but does NOT populate the ref arrays on
    the REQ artifact objects.  This function fills that gap so consumers
    that read req.codeRefs / req.testRefs directly see the correct indicators.

    Refs are copied with origin="propagated" and a propagatedFrom field
    identifying the intermediate artifact that owns the original ref.
    """
    for req_id in req_ids:
        art = artifacts.get(req_id)
        if not art:
            continue
        # Skip REQs that already have direct refs
        if art.get(ref_key):
            continue
        # BFS to collect refs from reachable non-REQ artifacts
        collected = []
        seen_files = set()
        visited = {req_id}
        queue = [(req_id, 0)]
        while queue:
            current, depth = queue.pop(0)
            if depth > 0 and current in ref_map:
                for ref in ref_map[current]:
                    # Deduplicate by file path
                    fpath = ref.get("file", "")
                    if fpath and fpath in seen_files:
                        continue
                    if fpath:
                        seen_files.add(fpath)
                    propagated = dict(ref)
                    propagated["origin"] = "propagated"
                    propagated["propagatedFrom"] = current
                    collected.append(propagated)
            if depth >= max_depth:
                continue
            neighbors = list(outgoing.get(current, set())) + list(incoming.get(current, set()))
            for neighbor in neighbors:
                if neighbor not in visited and not neighbor.startswith("REQ-"):
                    visited.add(neighbor)
                    queue.append((neighbor, depth + 1))
        if collected:
            art[ref_key] = collected


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
                "confidence": 1.0,
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


# Refs in comments of any language (// # -- /* * """) and inline IDs after a comment marker
CODE_REFS_RE = re.compile(r'Refs?:\s*((?:(?:REQ|UC|INV|RN|WF|API|BDD|ADR|NFR|FASE|TASK)[-][A-Za-z0-9-]+(?:,\s*)?)+)')
CODE_INLINE_REF_RE = re.compile(r'(?://|#|--)\s*((?:REQ|UC|INV|RN|WF|API|BDD|ADR|NFR)[-][A-Za-z0-9-]*\d[A-Za-z0-9-]*)')
SYMBOL_RE = re.compile(
    r'^\s*(?:(?:export|default|async|public|private|protected|static|final|abstract|pub(?:\([a-z]+\))?)\s+)*'
    r'(?P<kind>function\*?|class|const|let|var|interface|type|enum|def|module|func|fn|struct|trait|record)\s+'
    r'(?:\([^)]*\)\s*)?(?:self\.)?(?P<name>[A-Za-z_]\w*[?!]?)'
)
SYMBOL_KIND_TYPES = {
    "function": "function", "function*": "function", "def": "function", "func": "function", "fn": "function",
    "class": "class", "struct": "class", "record": "class", "module": "module", "trait": "interface",
    "interface": "interface", "type": "type", "enum": "enum", "const": "const", "let": "variable", "var": "variable",
}


def scan_code_refs(project_dir, scan_paths=None):
    """Scan the code paths of the SDD Stack Profile (default src/) for Refs: comments linking to SDD artifacts.

    scan_paths: (code_paths, test_paths, declared) from resolve_scan_paths(); resolved here when None.
    Also returns the list of scanned code files as stats["files"] (popped by the caller).
    """
    code_paths, test_paths, _declared = scan_paths or resolve_scan_paths(project_dir)

    code_refs = []
    files = []
    total_symbols = 0
    symbols_with_refs = 0

    for fpath, frel in _walk_source_files(project_dir, code_paths):
        if not is_code_path(frel, code_paths, test_paths):
            continue
        files.append(frel)
        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except Exception:
            continue

        file_symbols = []
        for i, line in enumerate(lines):
            sm = SYMBOL_RE.search(line)
            if sm:
                file_symbols.append((i, sm.group("name"), SYMBOL_KIND_TYPES.get(sm.group("kind"), "variable")))
                total_symbols += 1

        for i, line in enumerate(lines):
            ref_ids = []
            rm = CODE_REFS_RE.search(line)
            if rm:
                ref_ids = [r.strip() for r in re.split(r'[,\s]+', rm.group(1)) if r.strip() and classify_id(r.strip())]
            else:
                im = CODE_INLINE_REF_RE.search(line)
                if im:
                    ref_ids = [im.group(1)]
            if not ref_ids:
                continue

            # First symbol on the comment line or up to 2 lines below it (doc comment above a definition),
            # else the nearest one above (comment inside a body)
            symbol = f"{os.path.basename(fpath)}:{i+1}"
            symbol_type = "unknown"
            below = [(sn, stp) for si, sn, stp in file_symbols if i <= si <= i + 2]
            above = [(sn, stp) for si, sn, stp in file_symbols if si < i]
            pick = below[0] if below else (above[-1] if above else None)
            if pick:
                symbol, symbol_type = pick
                symbols_with_refs += 1

            code_refs.append({
                "file": frel,
                "line": i + 1,
                "symbol": symbol,
                "symbolType": symbol_type,
                "refIds": ref_ids,
                "confidence": 1.0,
            })

    print(f"  Code ({', '.join(code_paths)}): {len(files)} files, {total_symbols} symbols, {symbols_with_refs} with refs, {len(code_refs)} ref comments")
    return code_refs, {
        "totalFiles": len(files),
        "totalSymbols": total_symbols,
        "symbolsWithRefs": symbols_with_refs,
        "files": files,
    }


def _discover_test_dirs(project_dir):
    """Legacy test directories (projects without Stack Profile paths): tests/, test/, */tests/, */test/."""
    candidates = ["tests", "test"]
    try:
        for entry in sorted(os.listdir(project_dir)):
            if entry.startswith(".") or entry in SKIP_DIRS:
                continue
            if os.path.isdir(os.path.join(project_dir, entry)):
                for tname in ("tests", "test"):
                    if os.path.isdir(os.path.join(project_dir, entry, tname)):
                        candidates.append(f"{entry}/{tname}")
    except OSError:
        pass
    return candidates


def _discover_e2e_dirs(project_dir):
    """e2e/, playwright/, cypress/ at the root and one level deep (acceptance suites often live outside test_paths)."""
    found = []
    names = ("e2e", "playwright", "cypress")
    for edir in names:
        if os.path.isdir(os.path.join(project_dir, edir)):
            found.append(edir)
    try:
        for entry in sorted(os.listdir(project_dir)):
            if entry.startswith(".") or entry in SKIP_DIRS or not os.path.isdir(os.path.join(project_dir, entry)):
                continue
            for edir in names:
                if os.path.isdir(os.path.join(project_dir, entry, edir)):
                    found.append(f"{entry}/{edir}")
    except OSError:
        pass
    return found


def _is_e2e_test(fpath, frel):
    """Classify a test file as E2E based on path/filename conventions."""
    lower = frel.lower().replace("\\", "/")
    # Directory-based: e2e/, playwright/, cypress/, system/ (Rails system tests) anywhere in path
    if re.search(r'(?:^|/)(?:e2e|playwright|cypress|system)/', lower):
        return True
    # Filename-based: *.e2e.ts, *.pw.ts
    base = os.path.basename(lower)
    return bool(re.search(r'\.e2e\.', base) or re.search(r'\.pw\.', base))


def _read_quiet(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def detect_test_frameworks(project_dir):
    """Detect JS unit/E2E frameworks from package.json files (root and the Stack Profile app_dir).

    Returns {"js": <vitest|jest|mocha|None>, "e2e": <playwright|cypress|None>, "ruby": <rspec|minitest|None>}.
    """
    profile = read_stack_profile(project_dir)
    app_dir = _clean_rel_dir(profile.get("app_dir", ".")) or "."
    roots = [project_dir] if app_dir == "." else [os.path.join(project_dir, app_dir), project_dir]

    deps = set()
    for root in roots:
        try:
            pkg = json.loads(_read_quiet(os.path.join(root, "package.json")) or "{}")
        except ValueError:
            pkg = {}
        for key in ("dependencies", "devDependencies"):
            if isinstance(pkg.get(key), dict):
                deps.update(pkg[key].keys())
        for cfg in ("vitest.config.ts", "vitest.config.js", "vitest.config.mts"):
            if os.path.exists(os.path.join(root, cfg)):
                deps.add("vitest")
        for cfg in ("jest.config.js", "jest.config.ts", "jest.config.cjs"):
            if os.path.exists(os.path.join(root, cfg)):
                deps.add("jest")
        for cfg in ("playwright.config.ts", "playwright.config.js"):
            if os.path.exists(os.path.join(root, cfg)):
                deps.add("@playwright/test")

    js = next((fw for fw in ("vitest", "jest", "mocha") if fw in deps), None)
    e2e = "playwright" if ("@playwright/test" in deps or "playwright" in deps) else ("cypress" if "cypress" in deps else None)

    ruby = None
    for root in roots:
        gemfile = _read_quiet(os.path.join(root, "Gemfile"))
        if os.path.exists(os.path.join(root, ".rspec")) or "rspec" in gemfile:
            ruby = "rspec"
            break
        if re.search(r'gem\s+["\'](?:rails|minitest)["\']', gemfile):
            ruby = "minitest"
            break
    return {"js": js, "e2e": e2e, "ruby": ruby}


def _framework_for(frel, is_e2e, frameworks):
    """Framework of one test file from its extension and the detected frameworks; "unknown" when unsure."""
    ext = os.path.splitext(frel)[1].lower()
    lower = frel.lower()
    if is_e2e:
        if "playwright/" in lower or ".pw." in lower:
            return "playwright"
        if "cypress/" in lower:
            return "cypress"
        if ext == ".rb":
            return "minitest" if frameworks.get("ruby") != "rspec" else "rspec"
        return frameworks.get("e2e") or "unknown"
    if ext == ".rb":
        if lower.endswith("_spec.rb"):
            return "rspec"
        if lower.endswith("_test.rb"):
            return "minitest"
        return frameworks.get("ruby") or "unknown"
    if ext == ".py":
        return "pytest"
    if ext == ".go":
        return "go-test"
    if ext in (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs"):
        return frameworks.get("js") or "unknown"
    return "unknown"


_UNDERSCORE_ID_RE = re.compile(
    r'(?<![A-Za-z0-9])(REQ|UC|WF|BDD|INV|ADR|NFR|TASK)((?:_[A-Z][A-Z0-9]*)*(?:_\d+)+)(?![A-Za-z0-9])'
)


def _normalize_underscored_ids(text):
    """test_BDD_UC_001_01_x → test_BDD-UC-001-01_x (Minitest/pytest names cannot contain hyphens)."""
    return _UNDERSCORE_ID_RE.sub(lambda m: m.group(1) + m.group(2).replace("_", "-"), text)


TEST_BLOCK_RES = [
    re.compile(r'^\s*(?:it|test|specify|scenario)\s*(?:\.\w+\s*)?\(?\s*[\'"`](.*?)[\'"`]'),  # JS it()/test(), RSpec/Minitest it "..." / test "..."
    re.compile(r'^\s*(?:async\s+)?def\s+(test_?\w*)\s*[(:]?'),                        # Minitest/pytest def test_x
    re.compile(r'^\s*func\s+(Test\w+)\s*\('),                                       # Go
]
DESCRIBE_RE = re.compile(r'(?:describe|context|suite)\s*\(?\s*[\'"`](.*?)[\'"`]|^\s*class\s+(\w+(?:::\w+)*)')


def _test_name_on(line):
    for pat in TEST_BLOCK_RES:
        m = pat.search(line)
        if m and m.group(1) not in ("test", "test_"):
            return m.group(1)
    return None


def scan_test_refs(project_dir, scan_paths=None):
    """Scan the test paths of the SDD Stack Profile (default tests/) for Refs: comments and test names
    referencing SDD artifacts. Without declared paths, the legacy locations (test/, */tests/) are scanned too.
    E2E directories (e2e/, playwright/, cypress/) are always included."""
    code_paths, test_paths, declared = scan_paths or resolve_scan_paths(project_dir)
    bases = list(test_paths)
    if not declared:
        bases += [d for d in _discover_test_dirs(project_dir) if d not in bases]
    e2e_dirs = _discover_e2e_dirs(project_dir)
    bases += [d for d in e2e_dirs if d not in bases]
    frameworks = detect_test_frameworks(project_dir)

    test_refs = []
    counts = {"files": 0, "tests": 0, "refs": 0,
              "functionalFiles": 0, "functionalTests": 0, "functionalWithRefs": 0,
              "e2eFiles": 0, "e2eTests": 0, "e2eWithRefs": 0}
    declared_tests = list(test_paths) if declared else bases

    for fpath, frel in _walk_source_files(project_dir, bases):
        # A test path shared with code (Next.js src/) only yields files named like tests
        in_e2e_dir = any(_under(frel, d) for d in e2e_dirs)
        if not in_e2e_dir and not is_test_path(frel, code_paths, declared_tests):
            continue
        try:
            with open(fpath, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except Exception:
            continue

        is_e2e = _is_e2e_test(fpath, frel)
        kind = "e2e" if is_e2e else "functional"
        framework = _framework_for(frel, is_e2e, frameworks)
        counts["files"] += 1
        counts[kind + "Files"] += 1
        current_describe = ""
        file_tests = 0
        file_refs = 0

        for i, line in enumerate(lines):
            dm = DESCRIBE_RE.search(line)
            describe_here = None
            if dm:
                describe_here = dm.group(1) or dm.group(2)
                current_describe = describe_here or current_describe

            test_name = _test_name_on(line)
            if test_name is not None:
                file_tests += 1

            ref_ids = []
            rm = CODE_REFS_RE.search(line)
            if rm:
                ref_ids = [r.strip() for r in re.split(r'[,\s]+', rm.group(1)) if r.strip() and classify_id(r.strip())]
            for label in (test_name, describe_here):
                if not label:
                    continue
                for m in REF_PATTERN.finditer(_normalize_underscored_ids(label)):
                    if m.group(1) not in ref_ids:
                        ref_ids.append(m.group(1))
            if not ref_ids:
                continue

            if test_name:
                shown = f"{current_describe} > {test_name}" if current_describe else test_name
            else:
                shown = current_describe or f"{os.path.basename(fpath)}:{i+1}"
            file_refs += 1
            test_refs.append({
                "file": frel,
                "line": i + 1,
                "testName": shown,
                "framework": framework,
                "refIds": ref_ids,
                "testType": kind,
            })

        counts["tests"] += file_tests
        counts["refs"] += file_refs
        counts[kind + "Tests"] += file_tests
        counts[kind + "WithRefs"] += file_refs

    print(f"  Tests ({', '.join(bases) or 'none'}): {counts['files']} files, {counts['tests']} tests, {counts['refs']} with refs")
    print(f"    Functional: {counts['functionalFiles']} files, {counts['functionalTests']} tests, {counts['functionalWithRefs']} with refs")
    print(f"    E2E:        {counts['e2eFiles']} files, {counts['e2eTests']} tests, {counts['e2eWithRefs']} with refs")
    return test_refs, {
        "totalTestFiles": counts["files"],
        "totalTests": counts["tests"],
        "testsWithRefs": counts["refs"],
        "functionalFiles": counts["functionalFiles"],
        "functionalTests": counts["functionalTests"],
        "functionalWithRefs": counts["functionalWithRefs"],
        "e2eFiles": counts["e2eFiles"],
        "e2eTests": counts["e2eTests"],
        "e2eWithRefs": counts["e2eWithRefs"],
    }


_AUDIT_ROW_RES = {
    "total": re.compile(r'\|\s*(?:Findings in audit|Total hallazgos|Total findings)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
    "critical": re.compile(r'\|\s*(?:Criticos|Critical|Cr[ií]ticos)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
    "high": re.compile(r'\|\s*(?:Altos|High)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
    "medium": re.compile(r'\|\s*(?:Medios|Medium)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
    "low": re.compile(r'\|\s*(?:Bajos|Low)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
    "corrected": re.compile(r'\|\s*(?:Corrections applied|Correcciones aplicadas|Corrected)\s*\|\s*(\d+)\s*/?\s*\d*\s*\|', re.IGNORECASE),
    "accepted": re.compile(r'\|\s*(?:Accepted|Aceptados)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
    "deferred": re.compile(r'\|\s*(?:Deferred|Diferidos)\s*\|\s*(\d+)\s*\|', re.IGNORECASE),
}
_AUDIT_GATE_RE = re.compile(r'\|\s*(?:3C Gate|3C)\s*\|\s*(PASS|FAIL)\s*\|', re.IGNORECASE)
# Progression table row: | vN.N | N | N | N | N | PASS/FAIL |
_AUDIT_PROGRESSION_RE = re.compile(
    r'\|\s*(v[\d.]+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(PASS|FAIL)\s*\|', re.IGNORECASE
)


def parse_audit_file(content):
    """Summary numbers of one audit report (first matching row of each kind; None when absent)."""
    data = {}
    for key, pat in _AUDIT_ROW_RES.items():
        m = pat.search(content)
        data[key] = int(m.group(1)) if m else None
    m = _AUDIT_GATE_RE.search(content)
    data["gate"] = m.group(1).upper() if m else None
    data["progression"] = [
        {"version": r[0], "findings": int(r[1]), "fixed": int(r[2]), "accepted": int(r[3]),
         "deferred": int(r[4]), "gate": r[5].upper()}
        for r in _AUDIT_PROGRESSION_RE.findall(content)
    ]
    return data


def _audit_summary(parsed):
    return {
        "latestGate": parsed["gate"],
        "totalFindings": parsed["total"] or 0,
        "bySeverity": {k: parsed[k] or 0 for k in ("critical", "high", "medium", "low")},
        "corrected": parsed["corrected"] or 0,
        "accepted": parsed["accepted"] or 0,
        "deferred": parsed["deferred"] or 0,
        "progression": parsed["progression"],
    }


def _pick_report(parsed_by_name, preferred):
    """The report whose numbers are shown: `preferred` if it has data, else the most recently modified one."""
    with_data = {n: d for n, d in parsed_by_name.items()
                 if d["parsed"]["total"] is not None or any(d["parsed"][k] is not None for k in ("critical", "high", "medium", "low"))}
    if not with_data:
        return None
    if preferred in with_data:
        return preferred
    return max(with_data, key=lambda n: (with_data[n]["mtime"], n))


def scan_audits(project_dir):
    """Scan audits/*.md. Each report is parsed on its own; the spec-audit numbers come only from AUDIT-*.md
    (AUDIT-BASELINE.md when it has data, else the newest AUDIT-*.md). SECURITY-AUDIT-*.md goes to `security`;
    other reports (gap reviews, etc.) are only listed in auditFiles."""
    audits_dir = os.path.join(project_dir, "audits")
    empty = _audit_summary({"gate": None, "total": None, "critical": None, "high": None, "medium": None,
                            "low": None, "corrected": None, "accepted": None, "deferred": None, "progression": []})
    result = dict(empty, auditFiles=[], source=None, security=None)

    if not os.path.isdir(audits_dir):
        return result
    md_files = sorted(f for f in os.listdir(audits_dir) if f.lower().endswith(".md"))
    if not md_files:
        return result
    result["auditFiles"] = [f"audits/{f}" for f in md_files]

    spec_reports, security_reports = {}, {}
    for fname in md_files:
        upper = fname.upper()
        if upper.startswith("AUDIT-"):
            bucket = spec_reports
        elif upper.startswith("SECURITY-AUDIT"):
            bucket = security_reports
        else:
            continue
        fpath = os.path.join(audits_dir, fname)
        content = _read_quiet(fpath)
        bucket[fname] = {"parsed": parse_audit_file(content), "mtime": os.path.getmtime(fpath)}

    chosen = _pick_report(spec_reports, "AUDIT-BASELINE.md")
    if chosen:
        result.update(_audit_summary(spec_reports[chosen]["parsed"]))
        result["source"] = f"audits/{chosen}"
    sec = _pick_report(security_reports, "SECURITY-AUDIT-BASELINE.md")
    if sec:
        result["security"] = dict(_audit_summary(security_reports[sec]["parsed"]), source=f"audits/{sec}")

    sev = result["bySeverity"]
    sev_str = ", ".join(f"{sev[k]} {k}" for k in ("critical", "high", "medium", "low") if sev[k]) or "none"
    print(f"  Audits: {len(md_files)} files, spec audit {result['source'] or 'N/A'}: "
          f"{result['totalFindings']} findings ({sev_str}), gate={result['latestGate'] or 'N/A'}")
    return result


_GENERIC_SECTION_WORDS = re.compile(
    r'\b(?:requirements?|requisitos?|requerimientos?|functional|funcionales?|non[- ]functional|no[- ]funcionales?|'
    r'constraints?|restricciones?|specifications?|especificaciones?|and|y|de|del|the|of|list|lista)\b',
    re.IGNORECASE,
)

# Layer keywords, matched as whole words (a bare substring match put "require" in Frontend via "ui" and
# "catalog" in Infrastructure via "log").
_LAYER_KEYWORD_RULES = [
    (r'ui|ux|interfaz|interface|pantallas?|screens?|formularios?|forms?|vistas?|views?|frontend|'
     r'navegaci[oó]n|navigation|responsive|css|widgets?|bot[oó]n|botones|buttons?|modal(?:es)?|men[uú]s?|sidebar',
     "Frontend"),
    (r'infraestructura|infrastructure|deploy\w*|despliegues?|ci/cd|docker|kubernetes|terraform|cloud|'
     r'servidor(?:es)?|servers?|nginx|ssl|dns|hosting|monitor\w*|logs?|logging',
     "Infrastructure"),
    (r'integraci[oó]n|integrat\w*|webhooks?|third[- ]party|terceros?|pasarelas?|gateways?|sync\w*|'
     r'sincroniz\w*|imports?|exports?|migra\w*',
     "Integration/Deployment"),
]
_LAYER_KEYWORD_RES = [(re.compile(r'(?<![\w/])(?:' + kw + r')(?![\w/])', re.IGNORECASE), layer)
                      for kw, layer in _LAYER_KEYWORD_RULES]


def _domain_from_section(section):
    """Business domain from the requirement's section heading ("### 3.1 Authentication" → "Authentication").

    Returns None for headings that only say "Functional Requirements" and the like.
    """
    if not section:
        return None
    text = re.sub(r'^[\d.\s)–—-]+', '', section).strip()          # numbering
    text = re.sub(r'[*_`]+', '', text).strip()
    text = re.sub(r'\s*\(.*?\)\s*$', '', text).strip()               # trailing "(REQ-F-001..010)"
    if not text or not re.sub(r'[\W\d_]+', '', _GENERIC_SECTION_WORDS.sub('', text)):
        return None
    return text[:60]


def classify_requirements(artifacts, incoming, outgoing):
    """Classify REQ artifacts by business domain, technical layer, and functional category.

    Business domain: the requirement's section heading when it names one, else the ID group of grouped IDs
    (REQ-AUTH-003 → AUTH), else "General". No project-specific maps.
    """
    classification_stats = {"byDomain": {}, "byLayer": {}, "byCategory": {}}

    def _infer_layer_from_title(title):
        """Infer technical layer from REQ title using whole-word keyword matching. Defaults to Backend."""
        for pat, layer_name in _LAYER_KEYWORD_RES:
            if pat.search(title or ""):
                return layer_name
        return "Backend"

    # Generic REQ prefixes that don't carry domain information (IEEE 830 style)
    generic_cats = {"F", "NF", "C", "R", "D", "G", "S", "P"}

    for art in artifacts.values():
        if art["type"] != "REQ":
            art["classification"] = None
            continue

        cat = art.get("category")
        title = art.get("title", "")

        # Business domain: section heading, else ID group (REQ-AUTH-003), else General
        domain = _domain_from_section(art.get("section"))
        if not domain:
            domain = cat if (cat and cat not in generic_cats) else "General"

        # Technical layer from the title. FASEs are vertical increments (one user journey each), so a FASE
        # number says nothing about the layer.
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


def _warn(msg):
    print(f"  Warning: {msg}", file=sys.stderr)


def load_pipeline_state(project_dir):
    """pipeline-state.json as a dict ({} when absent). A corrupt file is reported on stderr and ignored."""
    path = os.path.join(project_dir, "pipeline-state.json")
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        _warn(f"pipeline-state.json is not valid JSON ({e}); stage statuses shown as unknown")
        return {}
    if not isinstance(data, dict):
        _warn("pipeline-state.json is not a JSON object; stage statuses shown as unknown")
        return {}
    return data


def build_graph(project_dir, output_dir, project_name, artifacts, references, all_ref_ids,
                commits=None, code_refs=None, code_stats=None, test_refs=None, test_stats=None,
                scan_paths=None):
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

    if scan_paths is None:
        scan_paths = resolve_scan_paths(project_dir)
    code_paths, test_paths, paths_declared = scan_paths
    code_files = code_stats.pop("files", None) or []

    # Read pipeline state
    ps = load_pipeline_state(project_dir)
    pipeline_data = {"currentStage": ps.get("currentStage", "unknown"), "stages": []}

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
        "plan-documents",
        "architecture-decisions",
        "task-generator",
        "task-implementer",
        "functional-tests",
        "e2e-tests",
    ]

    stages_data = ps.get("stages", {})
    if not isinstance(stages_data, dict):
        _warn("pipeline-state.json 'stages' is not an object; ignored")
        stages_data = {}

    # Count audit files for spec-auditor stage (findings aren't graph artifacts)
    audits_dir = os.path.join(project_dir, "audits")
    if os.path.isdir(audits_dir):
        audit_files = [f for f in os.listdir(audits_dir) if f.lower().endswith(".md")]
        stage_counts["spec-auditor"] = stage_counts.get("spec-auditor", 0) + len(audit_files)

    # Documentos de planificacion: el material donde se elabora el trabajo
    # (PLAN.md, ARCHITECTURE.md, CLARIFY-LOG.md y los planes detallados por fase).
    # Se excluye plan/fases/ a proposito: esos .md ya se cuentan como artefactos
    # FASE en la caja de plan-architect y sumarlos aqui los duplicaria.
    plan_dir = os.path.join(project_dir, "plan")
    if os.path.isdir(plan_dir):
        fases_dir = os.path.join(plan_dir, "fases")
        plan_docs = 0
        for root, dirs, filenames in os.walk(plan_dir):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            if os.path.abspath(root) == os.path.abspath(fases_dir):
                continue
            plan_docs += sum(1 for f in filenames if f.lower().endswith(".md"))
        if plan_docs:
            stage_counts["plan-documents"] = plan_docs

    # Count test plan documents for test-planner stage
    test_dir = os.path.join(project_dir, "test")
    if os.path.isdir(test_dir):
        test_files = [f for f in os.listdir(test_dir) if f.lower().endswith(".md")]
        stage_counts["test-planner"] = stage_counts.get("test-planner", 0) + len(test_files)

    # Count code files for task-implementer stage (tests are shown separately)
    impl_count = code_stats.get("totalFiles", 0)
    if impl_count > 0:
        stage_counts["task-implementer"] = impl_count

    # Count functional and E2E tests for their dedicated stages
    func_tests = test_stats.get("functionalTests", 0)
    e2e_tests_count = test_stats.get("e2eTests", 0)
    if func_tests > 0:
        stage_counts["functional-tests"] = func_tests
    elif test_stats.get("functionalFiles", 0) > 0:
        stage_counts["functional-tests"] = test_stats["functionalFiles"]
    if e2e_tests_count > 0:
        stage_counts["e2e-tests"] = e2e_tests_count
    elif test_stats.get("e2eFiles", 0) > 0:
        stage_counts["e2e-tests"] = test_stats["e2eFiles"]

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

    # Fallback: count src files with broader extensions for task-implementer if still 0 (excludes test dirs)
    if stage_counts.get("task-implementer", 0) == 0:
        fallback_dirs = code_paths if paths_declared else ["src", "app", "lib"]
        impl_fallback = sum(
            1 for _fp, frel in _walk_source_files(project_dir, fallback_dirs)
            if not is_test_path(frel, code_paths, test_paths)
        )
        if impl_fallback > 0:
            stage_counts["task-implementer"] = impl_fallback

    # Derive status for test stages (not tracked in pipeline-state.json)
    _test_stage_status = {}
    for tname, files_key, tests_key, refs_key in [
        ("functional-tests", "functionalFiles", "functionalTests", "functionalWithRefs"),
        ("e2e-tests", "e2eFiles", "e2eTests", "e2eWithRefs"),
    ]:
        fcount = test_stats.get(files_key, 0)
        _test_stage_status[tname] = "done" if fcount > 0 else "pending"

    # architecture-decisions tampoco vive en pipeline-state.json: es una caja
    # derivada del recuento de ADR, asi que su estado se infiere igual que el de
    # las etapas de test.
    _test_stage_status["architecture-decisions"] = (
        "done" if stage_counts.get("architecture-decisions", 0) > 0 else "pending"
    )
    _test_stage_status["plan-documents"] = (
        "done" if stage_counts.get("plan-documents", 0) > 0 else "pending"
    )

    pipeline_stages = []
    for sname in stage_order:
        sd = stages_data.get(sname, {})
        # Use derived status for test stages, pipeline-state for the rest
        if sname in _test_stage_status:
            status = _test_stage_status[sname]
        else:
            status = sd.get("status", "unknown")
        stage_entry = {
            "name": sname,
            "status": status,
            "lastRun": sd.get("lastRun"),
            "artifactCount": stage_counts.get(sname, 0),
            "stageLabel": summary_label_overrides.get(sname, STAGE_COUNT_UNITS.get(sname, "artifacts")),
            "group": STAGE_TO_GROUP.get(sname),
            "secondary": sname in SECONDARY_STAGES,
            "displayName": STAGE_DISPLAY_NAMES.get(sname),
        }
        if sd.get("summary"):
            stage_entry["summary"] = sd["summary"]
        if status == "skipped":
            stage_entry["skipReason"] = sd.get("skipReason")
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
                "group": STAGE_TO_GROUP.get(lname),
                "lateral": True,
                "secondary": lname in SECONDARY_STAGES,
                "displayName": STAGE_DISPLAY_NAMES.get(lname),
            }
            if ld.get("summary"):
                lateral_entry["summary"] = ld["summary"]
            if lateral_entry["status"] == "skipped":
                lateral_entry["skipReason"] = ld.get("skipReason")
            lateral_stages.append(lateral_entry)
    if lateral_stages:
        pipeline_data["lateralStages"] = lateral_stages

    # Agrupacion en las cinco fases de ingenieria. Se emite como dato (no como
    # maquetacion) para que cualquier consumidor del grafo pueda usar la misma agrupacion.
    by_name = {}
    for entry in pipeline_stages:
        by_name[entry["name"]] = entry
    for entry in lateral_stages:
        by_name[entry["name"]] = entry

    pipeline_groups = []
    for order, (group_id, group_label, member_names) in enumerate(STAGE_GROUPS, start=1):
        # Solo se listan las etapas realmente presentes: un pipeline parcial no
        # debe pintar cajas fantasma de etapas que nunca se ejecutaron.
        members = [by_name[n] for n in member_names if n in by_name]
        if not members:
            continue
        pipeline_groups.append({
            "id": group_id,
            "label": group_label,
            "order": order,
            "stages": [m["name"] for m in members],
            "artifactCount": sum(m.get("artifactCount", 0) or 0 for m in members),
            "status": aggregate_group_status([m.get("status") for m in members]),
        })
    pipeline_data["groups"] = pipeline_groups

    # Drop prose that looks like an ID ("BDD-style", "API-first"): digit-less IDs count only when defined
    defined_ids = set(artifacts.keys())
    references = [r for r in references
                  if is_plausible_ref(r[0], defined_ids) and is_plausible_ref(r[1], defined_ids)]
    for ref_list in (code_refs, test_refs):
        for ref in ref_list:
            ref["refIds"] = [rid for rid in ref.get("refIds", []) if is_plausible_ref(rid, defined_ids)]
    code_refs = [r for r in code_refs if r["refIds"]]
    test_refs = [r for r in test_refs if r["refIds"]]

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
    # Exclude structural IDs that are valid cross-reference targets but don't have
    # their own artifact definitions (FASE-N headers, API group headers like API-AUTH)
    _STRUCTURAL_ID_RE = re.compile(r'^(FASE-\d{1,2}|API-[A-Z]+)$')
    broken_refs = []
    broken_ids = set()
    for (src, tgt, sfile, line) in references:
        if tgt not in artifacts and tgt not in broken_ids and not _STRUCTURAL_ID_RE.match(tgt):
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
        cr.setdefault("confidence", 1.0)

    # 2. Infer code refs from commits (Step 1.2)
    scan_dirs = list(code_paths) + list(test_paths) if paths_declared else None
    inferred_code_refs = infer_code_refs_from_commits(commits, artifacts, incoming, outgoing,
                                                      project_dir=project_dir, scan_dirs=scan_dirs)

    # 3. Deduplicate by (file, refId): direct > llm-verified > inferred
    def _dedup(refs, taken):
        kept = []
        for cr in refs:
            new_ref_ids = [rid for rid in cr["refIds"] if (cr["file"], rid) not in taken]
            if new_ref_ids:
                cr["refIds"] = new_ref_ids
                kept.append(cr)
        for cr in kept:
            for rid in cr["refIds"]:
                taken.add((cr["file"], rid))
        return kept

    # 3b. llm-verified refs from sdd-gap-detector --semantic (.sdd/gap-analysis.json → semantic.requirements[])
    llm_refs = semantic_code_refs(load_gap_analysis(project_dir, warn=True))
    if llm_refs:
        print(f"  Gap analysis: {len(llm_refs)} llm-verified requirement refs")

    taken = {(cr["file"], rid) for cr in code_refs for rid in cr.get("refIds", [])}
    deduped_llm = _dedup(llm_refs, taken)
    deduped_inferred = _dedup(inferred_code_refs, taken)

    # 5. Apply overrides (Step 1.5)
    overrides_path = os.path.join(project_dir, ".sdd", "overrides.json")
    all_code_refs = code_refs + deduped_llm + deduped_inferred
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

    # ── Propagate refs to REQ artifacts (Step 1.3b) ──────────
    # Fill codeRefs/testRefs on REQ nodes so graph consumers see them directly.
    # Without this, REQs show ✗ even when downstream artifacts have refs.
    propagate_refs_to_req_artifacts(artifacts, req_ids, artifact_code_refs, incoming, outgoing, "codeRefs")
    propagate_refs_to_req_artifacts(artifacts, req_ids, artifact_test_refs, incoming, outgoing, "testRefs")

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
    inferred_refs_count = sum(1 for cr in all_code_refs if cr.get("origin") in ("commit-inferred", "task-inferred", "blame-inferred"))
    code_stats["directRefs"] = direct_refs_count
    code_stats["inferredRefs"] = inferred_refs_count
    code_stats["llmVerifiedRefs"] = sum(1 for cr in all_code_refs if cr.get("origin") == "llm-verified")
    code_stats["manualOverrides"] = override_count
    # Code files with no reference of any origin: untraced code
    traced_files = {cr["file"] for cr in all_code_refs if cr.get("refIds")}
    code_stats["orphanFiles"] = sorted(f for f in code_files if f not in traced_files)

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
        try:
            with open(adoption_file, "r", encoding="utf-8") as f:
                adoption_data = json.load(f)
            if not isinstance(adoption_data, dict):
                raise ValueError("top level is not an object")
            adoption = adoption_data.get("adoption", {"present": False})
            adoption_stats = adoption_data.get("adoptionStats", None)
        except (OSError, ValueError) as e:
            _warn(f"{adoption_file} is not valid JSON ({e}); adoption data skipped")

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

    return graph


# ──────────────────────────────────────────────────────────
# Optional Data Loaders (.sdd/ enrichment files)
# ──────────────────────────────────────────────────────────

def load_gap_analysis(project_dir, warn=False):
    """Load .sdd/gap-analysis.json if it exists. Returns parsed dict or None (warns on bad JSON when warn=True)."""
    gap_path = os.path.join(project_dir, ".sdd", "gap-analysis.json")
    if not os.path.isfile(gap_path):
        return None
    try:
        with open(gap_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        if warn:
            _warn(f"{gap_path} is not valid JSON ({e}); llm-verified refs and gap analysis skipped")
        return None
    return data if isinstance(data, dict) else None


_EVIDENCE_RE = re.compile(r'^\s*([^\s:][^:]*?):(\d+)(?:-(\d+))?\s*$')


def semantic_code_refs(gap_analysis):
    """Turn .sdd/gap-analysis.json semantic.requirements[] (sdd-gap-detector --semantic) into codeRefs.

    Only entries with status "covered", decidedBy jev|llm and evidence "path:start-end" (or "path:line")
    become refs, with origin "llm-verified". Anything else, or a missing section, yields nothing.
    """
    if not isinstance(gap_analysis, dict):
        return []
    semantic = gap_analysis.get("semantic")
    reqs = semantic.get("requirements") if isinstance(semantic, dict) else None
    if not isinstance(reqs, list):
        return []
    out = []
    for entry in reqs:
        if not isinstance(entry, dict):
            continue
        rid = entry.get("id")
        if not isinstance(rid, str) or classify_id(rid) != "REQ":
            continue
        if entry.get("status") != "covered" or entry.get("decidedBy") not in ("jev", "llm"):
            continue
        m = _EVIDENCE_RE.match(str(entry.get("evidence") or ""))
        if not m:
            continue
        fpath = m.group(1).replace("\\", "/")
        if fpath.startswith("./"):
            fpath = fpath[2:]
        start = int(m.group(2))
        end = int(m.group(3)) if m.group(3) else start
        conf = entry.get("confidence")
        try:
            conf = round(float(conf), 2)
        except (TypeError, ValueError):
            conf = 0.85
        out.append({
            "file": fpath,
            "line": start,
            "lines": [start, end],
            "symbol": f"{os.path.basename(fpath)}:{start}-{end}",
            "symbolType": "range",
            "refIds": [rid],
            "origin": "llm-verified",
            "confidence": conf,
            "inferredFrom": None,
            "judge": entry.get("decidedBy"),
        })
    return out


def load_test_results(project_dir):
    """Load .sdd/test-results-mapped.json if it exists. Returns parsed dict or None."""
    results_path = os.path.join(project_dir, ".sdd", "test-results-mapped.json")
    if not os.path.isfile(results_path):
        return None
    try:
        with open(results_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def _enrich_graph_with_loaders(graph, project_dir):
    """Enrich graph with optional .sdd/ data files (gap analysis, test results).

    This is a post-processing step: if the files exist, they add data to the graph;
    if they don't exist, the graph remains unchanged.
    """
    # 1. Gap analysis → graph.statistics.gapAnalysis
    gap_analysis = load_gap_analysis(project_dir)
    if gap_analysis is not None:
        graph.setdefault("statistics", {})["gapAnalysis"] = gap_analysis
        print("  Enriched: gap-analysis.json loaded into statistics.gapAnalysis")

    # 2. Test results → enrich artifact testRefs with lastRunStatus
    test_results = load_test_results(project_dir)
    if test_results is not None:
        # Build a lookup: artifactId -> worst status from test results
        artifact_test_status = {}  # artifactId -> "pass" | "fail" | "skip"
        for tr in test_results.get("results", []):
            status = tr.get("status", "unknown")
            for ref_id in tr.get("artifactRefs", []):
                current = artifact_test_status.get(ref_id)
                # Worst status wins: fail > skip > pass
                if current is None:
                    artifact_test_status[ref_id] = status
                elif status == "fail":
                    artifact_test_status[ref_id] = "fail"
                elif status == "skip" and current != "fail":
                    artifact_test_status[ref_id] = "skip"

        # Apply to artifacts in the graph
        enriched_count = 0
        for art in graph.get("artifacts", []):
            art_id = art.get("id", "")
            if art_id in artifact_test_status:
                # Add or update lastRunStatus on each testRef, or on the artifact itself
                art["lastRunStatus"] = artifact_test_status[art_id]
                enriched_count += 1
                # Also enrich individual testRefs if they exist
                for tref in art.get("testRefs", []):
                    for tr in test_results.get("results", []):
                        if art_id in tr.get("artifactRefs", []):
                            tref_name = tref.get("testName", "")
                            if tref_name and tref_name == tr.get("testName", ""):
                                tref["lastRunStatus"] = tr["status"]
                                tref["lastRunDuration"] = tr.get("duration", 0)

        if enriched_count > 0:
            print(f"  Enriched: test-results-mapped.json applied to {enriched_count} artifacts")

        # Also store summary-level data in statistics
        summary = test_results.get("summary")
        bdd_coverage = test_results.get("bddCoverage")
        if summary:
            graph.setdefault("statistics", {})["testRunSummary"] = summary
        if bdd_coverage:
            graph.setdefault("statistics", {})["bddCoverage"] = bdd_coverage


def main():
    parser = argparse.ArgumentParser(
        description="SDD traceability graph — scans pipeline artifacts and writes dashboard/traceability-graph.json"
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

    graph_file = os.path.join(output_dir, "traceability-graph.json")

    print("=" * 60)
    print("SDD Traceability Graph")
    print("=" * 60)
    print(f"Project: {project_dir}")
    print(f"Name:    {project_name}")
    print(f"Output:  {output_dir}")
    print()

    # Extract artifacts and references
    artifacts, references, all_ref_ids = scan_files(project_dir)
    scan_paths = resolve_scan_paths(project_dir)
    print(f"Code paths: {', '.join(scan_paths[0])} · test paths: {', '.join(scan_paths[1])}"
          f" ({'SDD Stack Profile' if scan_paths[2] else 'defaults'})")

    print(f"\nExtracted {len(artifacts)} artifact definitions")
    print(f"Extracted {len(references)} raw references")

    # Scan source code
    print("\nScanning source code...")
    code_refs, code_stats = scan_code_refs(project_dir, scan_paths)

    # Scan tests
    print("\nScanning tests...")
    test_refs, test_stats = scan_test_refs(project_dir, scan_paths)

    # Scan commits
    print("\nScanning git commits...")
    commits = scan_commits(project_dir)

    # Build graph
    graph = build_graph(project_dir, output_dir, project_name, artifacts, references, all_ref_ids,
                        commits, code_refs, code_stats, test_refs, test_stats, scan_paths)

    # Enrich with optional .sdd/ data files (gap analysis, test results)
    print("\nLoading optional enrichment data...")
    _enrich_graph_with_loaders(graph, project_dir)

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
        if ts2.get("functionalFiles", 0) > 0 or ts2.get("e2eFiles", 0) > 0:
            print(f"  Functional: {ts2.get('functionalFiles', 0)} files, {ts2.get('functionalTests', 0)} tests")
            print(f"  E2E:        {ts2.get('e2eFiles', 0)} files, {ts2.get('e2eTests', 0)} tests")

    print(f"\n{'='*60}")
    print("Done!")
    print(f"{'='*60}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
