---
name: sdd-dashboard
description: "Generates a self-contained HTML traceability dashboard from SDD artifacts: scans pipeline dirs, extracts IDs and cross-references, builds the JSON graph used by the MCP server. Triggers: 'dashboard', 'visualize pipeline', 'traceability dashboard', 'show traceability', 'generar dashboard', 'visualizar trazabilidad', 'ver dashboard'."
---

# SDD Traceability Dashboard

You are the **SDD Dashboard Generator**. Your job is to scan all SDD pipeline artifacts, extract artifact definitions and cross-references, build a structured traceability graph, and generate a self-contained HTML dashboard that opens in the user's browser.

## Relationship to Other Skills

- **Complements** `sdd-traceability-check`: that skill produces a text report; this one an interactive HTML dashboard over the same data.
- **Reads** `requirements/`, `spec/`, `audits/`, `test/`, `plan/`, `task/`, the code and test paths of the SDD Stack Profile (`code_paths`/`test_paths` in the root `CLAUDE.md`; default `src/` and `tests/`), git history, `pipeline-state.json` and the optional `.sdd/` files (`trace-map.json`, `overrides.json`, `gap-analysis.json`, `test-results-mapped.json`).
- **Writes** to `dashboard/` only (never modifies pipeline artifacts).
- **Does not participate** in the linear pipeline chain — this is a utility skill.

## How it runs

`generate.py` (next to this file) does all the scanning, graph building and HTML rendering. Your part is Step 1 (adoption data, only when adoption reports exist), running the script, and reporting.

```
python3 "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/skills/sdd-dashboard/generate.py" [--project DIR] [--output DIR]

  --project DIR    Project root (default: current directory)
  --output DIR     Output directory (default: PROJECT/dashboard)
```

The project name comes from `package.json` → `pipeline-state.json` → directory name. A corrupt `pipeline-state.json` or `adoption-data.json` is reported on stderr and skipped; the dashboard is still generated.

What the script does:

1. Extracts artifact definitions (headings, table rows, file names such as `UC-001-*.md`, `API-{module}.md`) and cross-references, expanding ranges (`UC-001..UC-005`, `REQ-F-007 a REQ-F-009`; a dash or "a" range needs the prefix repeated on the end ID). Digit-less IDs (`API-auth`) count only when some file defines them, so prose like "BDD-style" is not a broken reference. Patterns: `references/id-patterns-extended.md`.
2. Scans code under `code_paths` and tests under `test_paths` (plus `e2e/`, `playwright/`, `cypress/`) in any common language for `Refs:` comments and IDs in test names; the test framework comes from the files and project config, otherwise `unknown`.
3. Reads git history (`Refs:`/`Task:` trailers) and infers code references (below), merges hook-captured mappings from `.sdd/trace-map.json` and llm-verified requirement refs from `.sdd/gap-analysis.json`, applies `.sdd/overrides.json`.
4. Classifies REQs (business domain from the requirement's section heading or ID group, else `General`; technical layer; functional category), computes coverage statistics and audit numbers (spec audit from `audits/AUDIT-*.md`, security audit from `audits/SECURITY-AUDIT-*.md`, each report parsed on its own).
5. Writes `dashboard/traceability-graph.json` (schema: `references/graph-schema.md`) and `dashboard/index.html` from `references/html-template.md`.

### Code reference origins

| `origin` | Source | Confidence |
|----------|--------|------------|
| `direct` | `Refs:` comment in the code | 1.0 |
| `hook-captured` | `.sdd/trace-map.json`, written by the trace-map hook while a task is implemented | 0.95 |
| `commit-inferred` | Files of a commit whose `Refs:` trailer names the artifact | 0.6-0.9 by recency |
| `blame-inferred` | Same, carried to the file's current path after a rename | 0.6-0.9 |
| `llm-verified` | `covered` verdicts in `.sdd/gap-analysis.json` → `semantic.requirements[]` (`/sdd-gap-detector --semantic`) with `path:start-end` evidence; never replaces a direct or hook-captured ref | from the entry (e.g. 0.93) |
| `task-inferred` | Only a `Task:` trailer: the artifacts the TASK points at and their REQs (never through the FASE) | 0.5 |
| `manual-override` | `pin` entries in `.sdd/overrides.json` (`suppress` removes inferred refs) | 1.0 |
| `code-index` | File-level inferred refs refined to symbols when `codeIntelligence` exists (`/sdd-code-index`) | — |

Code files with no reference of any origin are listed in `statistics.codeStats.orphanFiles` — the dashboard's "untraced code" section.

## Output Artifacts

| File | Purpose |
|------|---------|
| `dashboard/traceability-graph.json` | Structured graph of artifacts and relationships (also read by the MCP server) |
| `dashboard/index.html` | Self-contained HTML dashboard (CSS+JS inline) |
| `dashboard/adoption-data.json` | Adoption data from Step 1 (only when adoption reports exist) |

## Process

### Step 1: Write adoption-data.json (only when adoption reports exist)

`generate.py` cannot read the free-form adoption reports (reverse-engineer, reconcile, import), so this is the one step you do yourself. Parse each report that exists and write `dashboard/adoption-data.json` as `{"adoption": {...}, "adoptionStats": {...}}` (shape in `references/graph-schema.md`). Skip the file entirely when none of these reports exist.

1. **`findings/FINDINGS-REPORT.md`** → Extract:
   - `findings.total`: total findings count
   - `findings.bySeverity`: count by severity (critical, high, medium, low)
   - `findings.byCategory`: count by category (DEAD-CODE, TECH-DEBT, WORKAROUND, INFRASTRUCTURE, ORPHAN, INFERRED, IMPLICIT-RULE)
   - `findings.topFindings`: first 5 critical/high findings with id, severity, category, description

2. **`reverse-engineering/INVENTORY.md`** → Extract:
   - `inventory.totalFiles`: total files analyzed
   - `inventory.totalLOC`: total lines of code
   - `inventory.byLayer`: file count by layer (Backend, Frontend, Infrastructure)

3. **`reconciliation/RECONCILIATION-REPORT.md`** → Extract:
   - `alignmentPercentage`: spec-code alignment percentage
   - `divergences.total`: total divergences found
   - `divergences.byType`: count by type (NEW_FUNCTIONALITY, REMOVED_FEATURE, BEHAVIORAL_CHANGE, REFACTORING, BUG_OR_DEFECT, AMBIGUOUS)
   - `divergences.resolved` / `divergences.pending`: counts
   - `delta`: specs/reqs added/modified counts

4. **`import/IMPORT-REPORT.md`** → Extract:
   - `sources`: array of { format, file, itemCount, mappedCount }
   - `totals`: { itemsProcessed, itemsMapped, itemsSkipped }
   - `quality`: { completeness, duplicatesFound, conflictsFound }
   - `artifactsGenerated`: { requirements, useCases, apiContracts }

**If a report does not exist**: set `present: false` for that sub-block.

**Compute adoptionStats**: If any adoption data exists:
- `overallAdoptionScore`: estimate 0-100 from the available data (alignment percentage, findings severity, import completeness)
- `overallAdoptionGrade`: A (≥90), B (≥75), C (≥60), D (≥40), F (<40)
- `criticalFindingsCount` / `highFindingsCount`: from findings data (0 if no findings)
- `alignmentPercentage`: from reconciliation data (null if no reconciliation)

### Step 2: Run generate.py

Run the command above from the project root. Read its printed statistics for the report.

### Step 3: Open in Browser and Report

Open `dashboard/index.html` (`open` on macOS, `xdg-open` on Linux, `start` on Windows) and report:

```
## Dashboard Generated

| Metric | Value |
|--------|-------|
| Total Artifacts | {N} |
| Artifact Types | REQ:{n}, UC:{n}, WF:{n}, API:{n}, BDD:{n}, INV:{n}, ADR:{n}, TASK:{n} |
| Total Relationships | {N} |
| REQs with UCs | {N}% ({count}/{total}) |
| REQs with Code | {N}% ({count}/{total}) |
| REQs with Tests | {N}% ({count}/{total}) |
| REQs with Commits | {N}% ({count}/{total}) |
| Code / Test Files Scanned | {N} / {N} |
| Commits with trailers | {N} ({commitsWithRefs} with Refs, {commitsWithTasks} with Task) |
| Orphaned Artifacts | {N} |
| Broken References | {N} |
| Pipeline Stage | {currentStage} |

Files written:
- `dashboard/traceability-graph.json`
- `dashboard/index.html`
```

If there are broken references or orphans, list the top 5 of each with file locations.

## Constraints

- Write only to `dashboard/`; pipeline artifacts stay untouched.
- Partial pipelines are normal: generate the dashboard with whatever exists.
- The HTML stays self-contained (no CDN links, no external CSS/JS).
- Output language follows the user's language; technical terms and artifact IDs stay in English.
