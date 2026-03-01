---
name: sdd-dashboard
description: "Generates a visual HTML traceability dashboard from SDD pipeline artifacts.
  Scans all pipeline directories, extracts artifact IDs and cross-references,
  builds a structured JSON graph, and produces a self-contained HTML dashboard.
  Triggers: 'dashboard', 'visualize pipeline', 'traceability dashboard',
  'show traceability', 'generar dashboard', 'visualizar trazabilidad',
  'show dashboard', 'pipeline visualization', 'ver dashboard'."
version: "4.0.0"
---

# SDD Traceability Dashboard

You are the **SDD Dashboard Generator**. Your job is to scan all SDD pipeline artifacts, extract artifact definitions and cross-references, build a structured traceability graph, and generate a self-contained HTML dashboard that opens in the user's browser.

## Relationship to Other Skills

- **Complements** `sdd-traceability-check`: That skill produces a text report; this skill produces a visual, interactive HTML dashboard with the same underlying data.
- **Reads** output from ALL pipeline stages: `requirements/`, `spec/`, `audits/`, `test/`, `plan/`, `task/`, `src/`, `tests/`.
- **Reads** `pipeline-state.json` for stage status information.
- **Writes** to `dashboard/` only (never modifies pipeline artifacts).
- **Does NOT participate** in the linear pipeline chain — this is a utility skill.

## Fast Path with generate.py

A Python script `generate.py` ships alongside this skill and implements Steps 1-8 as a standalone executable. This enables a **two-tier** execution model:

### Tier 1 — Fast Path (preferred)

If `generate.py` exists relative to this skill file, Claude should:

1. **Write `adoption-data.json`** (Step 2.5) — Claude parses onboarding/reconciliation markdown reports and writes `dashboard/adoption-data.json` with the structured adoption data. This is the only step that requires Claude's intelligence (regex + context-aware parsing of free-form markdown).
2. **Execute generate.py**:
   ```bash
   python /path/to/generate.py --project . --output dashboard/
   ```
   This handles Steps 1-8 automatically: scanning artifacts, extracting definitions and references, scanning code/tests/commits, classifying requirements, and writing `traceability-graph.json`.
3. **Continue at Step 9** — generate HTML from template + graph JSON.
4. **Step 10** — open browser and report metrics.

### Tier 2 — Manual Execution (fallback)

If `generate.py` is not available (e.g., skill installed without the script), Claude executes Steps 1-8 manually using tools (Glob, Grep, Read, Bash) as described below.

### CLI Reference

```
python generate.py [OPTIONS]

Options:
  --project DIR    Project root directory (default: current working directory)
  --output DIR     Output directory (default: PROJECT/dashboard)
```

The script auto-detects the project name from `package.json` → `pipeline-state.json` → directory name.

## Output Artifacts

| File | Purpose |
|------|---------|
| `dashboard/traceability-graph.json` | Structured graph of all artifacts and relationships |
| `dashboard/index.html` | Self-contained HTML dashboard (CSS+JS inline) |
| `dashboard/guide.html` | Static SDD system guide and dashboard interpretation docs |
| `dashboard/live-status.js` | JSONP live status seed file for real-time activity feed |

## Process

> **Fast Path**: If `generate.py` is available, Steps 1-8 are handled automatically. Claude only needs to write `adoption-data.json` (Step 2.5) before running the script, then skip to Step 9. See "Fast Path with generate.py" above.

### Step 1: Read Pipeline State

Read `pipeline-state.json` from the project root.

- If it exists: extract `currentStage` and each stage's `status` and `lastRun`.
- If it does not exist: set all stages to `status: "unknown"` and `lastRun: null`.

Also determine the project name:
1. From `pipeline-state.json` project field, if present
2. From `package.json` `name` field, if present
3. From the current directory name as fallback

### Step 2: Discover Artifact Directories

Use Glob to check which of these directories exist and contain `.md` files:

| Directory | Pipeline Stage |
|-----------|---------------|
| `requirements/` | requirements-engineer |
| `spec/` | specifications-engineer |
| `audits/` | spec-auditor |
| `test/` | test-planner |
| `plan/` | plan-architect |
| `task/` | task-generator |
| `src/` | task-implementer |
| `tests/` | task-implementer |
| `onboarding/` | onboarding |
| `findings/` | reverse-engineer |
| `reverse-engineering/` | reverse-engineer |
| `reconciliation/` | reconcile |
| `import/` | import |

Record which directories exist and which are empty. Report any missing directories as informational notes (not errors — partial pipelines are normal).

### Step 2.5: Scan Onboarding Artifacts

Scan for onboarding/adoption data produced by the 4 onboarding skills. Parse each report if it exists:

1. **`onboarding/ONBOARDING-REPORT.md`** → Extract:
   - `scenario`: scenario identifier from "Scenario Classification" section
   - `scenarioName`: human-readable name
   - `confidence`: classification confidence value
   - `healthScore`: overall health score from "Health Score" section
   - `dimensions`: per-dimension scores (requirements, specs, tests, architecture, traceability, codeQuality, pipelineState)
   - `actionPlan`: array of steps from "Action Plan" section (step number, skill name, description, effort level)
   - `signals`: detection signals from "Signals Detected" section

2. **`findings/FINDINGS-REPORT.md`** → Extract:
   - `findings.total`: total findings count
   - `findings.bySeverity`: count by severity (critical, high, medium, low)
   - `findings.byCategory`: count by category (DEAD-CODE, TECH-DEBT, WORKAROUND, INFRASTRUCTURE, ORPHAN, INFERRED, IMPLICIT-RULE)
   - `findings.topFindings`: first 5 critical/high findings with id, severity, category, description

3. **`reverse-engineering/INVENTORY.md`** → Extract:
   - `inventory.totalFiles`: total files analyzed
   - `inventory.totalLOC`: total lines of code
   - `inventory.byLayer`: file count by layer (Backend, Frontend, Infrastructure)

4. **`reconciliation/RECONCILIATION-REPORT.md`** → Extract:
   - `alignmentPercentage`: spec-code alignment percentage
   - `divergences.total`: total divergences found
   - `divergences.byType`: count by type (NEW_FUNCTIONALITY, REMOVED_FEATURE, BEHAVIORAL_CHANGE, REFACTORING, BUG_OR_DEFECT, AMBIGUOUS)
   - `divergences.resolved` / `divergences.pending`: counts
   - `delta`: specs/reqs added/modified counts

5. **`import/IMPORT-REPORT.md`** → Extract:
   - `sources`: array of { format, file, itemCount, mappedCount }
   - `totals`: { itemsProcessed, itemsMapped, itemsSkipped }
   - `quality`: { completeness, duplicatesFound, conflictsFound }
   - `artifactsGenerated`: { requirements, useCases, apiContracts }

**If a report does not exist**: Set `present: false` for that sub-block. If none of the onboarding directories exist, set `adoption: { present: false }`.

**Compute adoptionStats**: If any onboarding data exists:
- `overallAdoptionScore`: use onboarding healthScore if present, otherwise estimate from available data
- `overallAdoptionGrade`: A (≥90), B (≥75), C (≥60), D (≥40), F (<40)
- `criticalFindingsCount` / `highFindingsCount`: from findings data (0 if no findings)
- `alignmentPercentage`: from reconciliation data (null if no reconciliation)

### Step 3: Extract Artifact Definitions

Scan each existing directory for artifact ID definitions using the patterns from `references/id-patterns-extended.md`.

For each artifact found, extract:
```json
{
  "id": "REQ-EXT-001",
  "type": "REQ",
  "category": "EXT",
  "title": "text from same line or next line after ID",
  "file": "requirements/REQUIREMENTS.md",
  "line": 42,
  "priority": "Must Have",
  "stage": "requirements-engineer"
}
```

**Extraction rules:**
- **ID**: Match using definition patterns (headings, table rows).
- **Type**: The prefix before the first hyphen (REQ, UC, WF, etc.).
- **Category**: The middle segment for compound IDs (EXT in REQ-EXT-001, SYS in INV-SYS-001), or null for simple IDs.
- **Title**: The text following the ID on the same line (after stripping markdown formatting). If the ID is alone on a heading line, use the next non-empty line.
- **File**: Relative path from project root using forward slashes.
- **Line**: 1-indexed line number where the ID is defined.
- **Priority**: Extract from adjacent table columns if present (look for "Priority", "Prioridad", "MoSCoW" column headers). Null if not in a table or no priority column.
- **Stage**: Mapped from the directory using the type-to-stage mapping in `references/id-patterns-extended.md`.

**Deduplication**: If the same ID appears in multiple files, use the first occurrence (by file path alphabetical order) as the definition.

### Step 4: Extract Relationships

Scan ALL markdown files in `requirements/`, `spec/`, `audits/`, `test/`, `plan/`, `task/` for cross-references between artifact IDs.

**Use the universal reference pattern** from `references/id-patterns-extended.md` to find all ID mentions. For each mention:
1. Determine the **source**: the artifact that "owns" the current file (e.g., if scanning `spec/use-cases/UC-001.md`, the source is `UC-001`).
2. Determine the **target**: the referenced ID.
3. Skip self-references (source === target).
4. Determine the **relationship type** by context:

| Context | Relationship Type |
|---------|-------------------|
| UC file referencing REQ | `implements` |
| WF file referencing API | `orchestrates` |
| BDD/test file referencing REQ or UC | `verifies` |
| INV referencing REQ | `guarantees` |
| ADR referencing REQ or NFR | `decides` |
| TASK referencing FASE | `decomposes` |
| `Refs:` field in task/commit | `implemented-by` |
| "Specs a Leer" / "Reads" section in FASE | `reads-from` |
| Any other cross-reference | `traces-to` |

**Range expansion**: When encountering range patterns like `INV-SEC-001..007`, expand to 7 individual references (INV-SEC-001 through INV-SEC-007).

**Deduplication**: Remove duplicate relationships (same source + target + type).

### Step 5: Scan Code References

Scan source code files for references to SDD artifact IDs using the patterns from `references/id-patterns-extended.md` section "Code Reference Patterns".

1. **Glob** for source files: `src/**/*.{ts,js,tsx,jsx,py,java,go,rs,cs}`
2. For each file, search for:
   - JSDoc/block comment `Refs:` lines
   - Inline comment refs (`// UC-001`, `// INV-EXT-005`)
   - Decorator/annotation refs (`@implements("UC-001")`)
3. For each reference found, extract:
   ```json
   {
     "file": "src/extraction/validators/pdf-validator.ts",
     "line": 8,
     "symbol": "validateSize",
     "symbolType": "function",
     "refIds": ["UC-001", "INV-EXT-005"]
   }
   ```
4. **Symbol extraction**: Search backward (up to 5 lines) and forward (up to 2 lines) from the Ref line for the nearest symbol definition (function, class, const, etc.). Use `filename:line` as fallback.
5. **Create relationships**: For each refId found in code, create a relationship of type `implemented-by-code` from the code file to the referenced artifact.
6. **Propagate to REQs**: For each refId (e.g., `UC-001`), find all REQs that the artifact traces to (via `implements`, `verifies`, `guarantees` chains) and attach the codeRef to those REQs.

**If `src/` does not exist**: Skip this step. Set `codeRefs: []` for all artifacts and `codeStats` to zeros.

### Step 5.5: Scan Commit References

Scan git history for commits that reference SDD artifacts via `Refs:` and `Task:` trailers.

1. **Check git availability**:
   ```bash
   git rev-parse --is-inside-work-tree 2>/dev/null
   ```
   If this fails, skip this step entirely. Set `commitRefs: []` for all artifacts and `commitStats` to zeros.

2. **Extract commits with `Refs:` trailers** (limit to 500 for performance):
   ```bash
   git log --all --format='%H|%h|%s|%an|%aI|%b' --grep='Refs:' | head -500
   ```

3. **Extract commits with `Task:` trailers** (merge with above, dedup by SHA):
   ```bash
   git log --all --format='%H|%h|%s|%an|%aI|%b' --grep='Task:' | head -500
   ```

4. **Build commitRef objects** from each unique commit:
   - Parse the `Refs:` line from the body to extract artifact IDs (e.g., `Refs: FASE-0, UC-002, ADR-003`)
   - Parse the `Task:` line from the body to extract task ID (e.g., `Task: TASK-F0-003`)
   - Construct:
     ```json
     {
       "sha": "{short-sha}",
       "fullSha": "{full-sha}",
       "message": "{subject}",
       "author": "{author}",
       "date": "{ISO-8601 date}",
       "taskId": "{TASK-ID or null}",
       "refIds": ["{extracted artifact IDs}"]
     }
     ```

5. **Create relationships**: For each refId in a commit, create a relationship of type `implemented-by-commit` from the commit (identified as `commit:{sha}`) to the referenced artifact.

6. **Attach commitRefs to artifacts**: For each artifact referenced by a commit's `refIds` or linked via its `taskId`, attach the commitRef to that artifact's `commitRefs[]` array.

7. **Propagate to REQs**: For each refId (e.g., `UC-001`), find all REQs that the artifact traces to (via `implements`, `verifies`, `guarantees` chains) and attach the commitRef to those REQs. Same propagation logic as codeRefs/testRefs.

**If git is not available or no commits with trailers exist**: Set `commitRefs: []` for all artifacts, `commitStats` to `{ totalCommits: 0, commitsWithRefs: 0, commitsWithTasks: 0, uniqueTasksCovered: 0 }`.

### Step 6: Scan Test References

Scan test files for references to SDD artifact IDs using the patterns from `references/id-patterns-extended.md` section "Test Reference Patterns".

1. **Glob** for test files: `tests/**/*.{test,spec}.{ts,js,tsx,jsx}` + `tests/**/*.py` + `test/**/*.{test,spec}.{ts,js,tsx,jsx}`
2. For each file, search for:
   - File header `Refs:` lines (same as code JSDoc refs)
   - Test block description refs (`it('validates per INV-EXT-005', ...)`)
   - Python test docstring refs
3. For each reference found, extract:
   ```json
   {
     "file": "tests/unit/extraction/pdf-validator.test.ts",
     "line": 12,
     "testName": "accepts size at exact 50MB limit",
     "framework": "vitest",
     "refIds": ["UC-001", "INV-EXT-005"]
   }
   ```
4. **Test name extraction**: Extract from the enclosing `it()`/`test()` block description. If inside a `describe()`, prepend the describe name: `"PDF Validator > validates size per INV-EXT-005"`.
5. **Framework detection**: Check for `vitest.config.*`, `jest.config.*`, `pytest.ini`, or framework-specific imports.
6. **Create relationships**: For each refId, create a relationship of type `tested-by` from the test file to the referenced artifact.
7. **Propagate to REQs**: Same propagation logic as Step 5 — attach testRefs to upstream REQs.
8. **Test-to-code association**: Link test files to source files via path convention or import analysis (for the HTML dashboard's code view).

**If `tests/` and `test/` do not exist**: Skip this step. Set `testRefs: []` for all artifacts and `testStats` to zeros.

### Step 7: Classify Artifacts

For each REQ artifact, compute a classification object using the taxonomy from `references/id-patterns-extended.md` section "Classification Taxonomy".

1. **Business Domain**: Map the REQ's category prefix to a business domain:
   - Extract category from `REQ-{CATEGORY}-{NUMBER}` (e.g., `EXT` from `REQ-EXT-001`)
   - Look up in the Business Domain mapping table
   - If no category or no match, set to `"Other"`

2. **Technical Layer**: Follow the traceability chain to determine layer:
   - Find TASKs linked to this REQ (through UC → TASK or direct)
   - Extract FASE numbers from those TASKs (TASK-F{N}-{NNN} → FASE-{N})
   - Map FASE number to layer: 0=Infrastructure, 1-6=Backend, 7-8=Frontend, 9+=Integration/Deployment
   - If multiple layers, use the most frequent one
   - If no TASK/FASE link, set to `"Unknown"`

3. **Functional Category**: Determine from context in REQUIREMENTS.md:
   - Find the nearest H2/H3 heading above the REQ definition
   - Match heading text against category keywords
   - Default to `"Functional"` if no match

4. **Attach classification** to each REQ artifact:
   ```json
   {
     "classification": {
       "businessDomain": "Extraction & Processing",
       "technicalLayer": "Backend",
       "functionalCategory": "Functional"
     }
   }
   ```

**Non-REQ artifacts**: Set `classification: null`. The HTML dashboard resolves their classification at render time from linked REQs.

### Step 8: Build traceability-graph.json

Assemble the JSON structure following the schema in `references/graph-schema.md` (v3):

1. **pipeline**: Merge stage statuses from Step 1 with artifact counts from Step 3.
2. **artifacts**: All extracted artifacts from Step 3, enriched with:
   - `classification` from Step 7
   - `codeRefs` from Step 5
   - `testRefs` from Step 6
   - `commitRefs` from Step 5.5
3. **relationships**: All relationships from Step 4, plus `implemented-by-code` (Step 5), `tested-by` (Step 6), and `implemented-by-commit` (Step 5.5).
4. **statistics**: Compute:
   - `totalArtifacts`: count of all artifacts
   - `byType`: count per artifact type
   - `totalRelationships`: count of all relationships
   - `traceabilityCoverage`:
     - `reqsWithUCs`: REQs that have at least one incoming `implements` relationship from a UC
     - `reqsWithBDD`: REQs that have at least one incoming `verifies` relationship from a BDD
     - `reqsWithTasks`: REQs traceable to at least one TASK (through any chain of relationships)
     - `reqsWithCode`: REQs that have at least one `codeRef` (directly or via traceability chain)
     - `reqsWithTests`: REQs that have at least one `testRef` (directly or via traceability chain)
     - `reqsWithCommits`: REQs that have at least one `commitRef` (directly or via traceability chain)
   - `orphans`: artifact IDs that have zero incoming relationships (no other artifact references them)
   - `brokenReferences`: IDs that appear in cross-references but are not defined in any artifact
   - `codeStats`: `{ totalFiles, totalSymbols, symbolsWithRefs }`
   - `testStats`: `{ totalTestFiles, totalTests, testsWithRefs }`
   - `commitStats`: `{ totalCommits, commitsWithRefs, commitsWithTasks, uniqueTasksCovered }`
   - `classificationStats`: `{ byDomain, byLayer, byCategory }` — count of REQs per classification value
   - `adoptionStats`: from Step 2.5 (null if no onboarding data)
5. **adoption**: From Step 2.5 — the full adoption block with onboarding, reverseEngineering, reconciliation, import sub-blocks.

Write the JSON to `dashboard/traceability-graph.json` with 2-space indentation.

### Step 9: Generate HTML Dashboard and Guide

1. Read the HTML template from `references/html-template.md` (extract the content inside the ```html code block).
2. Read the JSON from `dashboard/traceability-graph.json`.
3. Replace `{{DATA_JSON}}` with the raw JSON content.
4. Replace `{{PROJECT_NAME}}` with the project name.
5. Write the result to `dashboard/index.html`.
6. Read the guide template from `references/guide-template.md` (extract the content inside the ```html code block).
7. Write the extracted HTML directly to `dashboard/guide.html` (no placeholder replacement needed — the guide is static documentation).

### Step 9.5: Generate Live Status Seed File

1. Read the JSONP template structure from `references/live-status-template.md` (the "Idle Seed File" section).
2. Replace `{{TIMESTAMP}}` with the current ISO-8601 timestamp.
3. Write the result to `dashboard/live-status.js`.

This creates an idle seed file that the dashboard's JSONP polling can find immediately. Pipeline skills will overwrite this file during execution with real-time progress data.

### Step 10: Open in Browser and Report

Execute the appropriate command to open the dashboard:
- **Windows**: `start dashboard/index.html`
- **macOS**: `open dashboard/index.html`
- **Linux**: `xdg-open dashboard/index.html`

Report a summary to the user:

```
## Dashboard Generated (v4)

| Metric | Value |
|--------|-------|
| Total Artifacts | {N} |
| Artifact Types | REQ:{n}, UC:{n}, WF:{n}, API:{n}, BDD:{n}, INV:{n}, ADR:{n}, TASK:{n} |
| Total Relationships | {N} |
| REQs with UCs | {N}% ({count}/{total}) |
| REQs with Code | {N}% ({count}/{total}) |
| REQs with Tests | {N}% ({count}/{total}) |
| Code Files Scanned | {N} ({symbolsWithRefs} symbols with refs) |
| Test Files Scanned | {N} ({testsWithRefs} tests with refs) |
| Commits Scanned | {N} ({commitsWithRefs} with refs, {commitsWithTasks} with tasks) |
| REQs with Commits | {N}% ({count}/{total}) |
| Classification | {domains} domains, {layers} layers |
| Orphaned Artifacts | {N} |
| Broken References | {N} |
| Pipeline Stage | {currentStage} |

Files written:
- `dashboard/traceability-graph.json`
- `dashboard/index.html`
- `dashboard/guide.html`
- `dashboard/live-status.js`

Dashboard opened in default browser.
```

If there are broken references or orphans, list the top 5 of each with file locations.

## Constraints

- **Write only to `dashboard/`**: Never modify pipeline artifacts (`requirements/`, `spec/`, `plan/`, `task/`, etc.).
- **Tolerate partial pipelines**: If only `requirements/` exists, still generate a dashboard with whatever is available.
- **No external dependencies**: The HTML file must be fully self-contained (no CDN links, no external CSS/JS).
- **Forward-slash paths**: Always use forward slashes in file paths within the JSON, even on Windows.
- **JSON validity**: The output JSON must be valid and parseable. Escape special characters in titles.
- **Idempotent**: Running the dashboard multiple times overwrites previous output without side effects.
- **Output Language**: Match the user's language for the summary report. Technical terms and artifact IDs remain in English.
- **Fast Path preferred**: When `generate.py` is available, prefer using it for Steps 1-8 instead of manual tool-based execution. This is faster and produces consistent output across projects.
