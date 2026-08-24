---
name: sdd-gap-detector
description: "Detects implementation gaps between specifications and code. Compares API contracts, use cases, and BDD scenarios against actual source code to find MISSING endpoints, ORPHAN code, and SCHEMA mismatches. Use when: 'detect gaps', 'find missing implementations', 'what's not implemented', 'orphan code', 'gap analysis', 'verify implementation completeness', 'qué falta por implementar', 'código huérfano'."
version: "1.0.0"
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git rev-parse:*), Write(.sdd/*), Write(audits/*)
---

# SDD Gap Detector

**Version**: 1.0.0
**SWEBOK**: Ch11 (Software Construction), Ch08 (Software Testing — structural coverage)
**Purpose**: Perform objective gap analysis between SDD specifications and implementation code, identifying missing endpoints, orphan routes, schema mismatches, and uncovered BDD scenarios.

## Trigger Phrases

- `/sdd-gap-detector`
- "detect gaps between spec and code"
- "find missing implementations"
- "what's not implemented yet"
- "orphan code detection"
- "verify implementation completeness"
- "gap analysis"

## Prerequisites

- Source code in `src/` (or detected project root)
- At least one of: `spec/contracts/*.md`, `spec/use-cases/*.md`
- Tolerates partial specs — reports what it can and notes what is missing

## Modes

| Mode | Flag | Description |
|------|------|-------------|
| **Full** | (default) | Complete gap analysis: endpoints + BDD + orphans |
| **Endpoints** | `--endpoints` | Only endpoint gap analysis (spec contracts vs code routes) |
| **BDD** | `--bdd` | Only BDD coverage analysis (scenarios vs test files) |
| **Summary** | `--summary` | Statistics only, no detailed listings |

## Process

### Phase 1: Extract from Specs

Build a "spec manifest" — what the system SHOULD do.

#### 1.1 Extract API Endpoint Definitions

Read `spec/contracts/*.md` and extract endpoint definitions. Look for markdown tables with columns matching: Method, Path, Description, Status Codes.

**Table detection patterns** (see `references/language-parsers.md` Section 7):
- Header row containing `Method` and `Path` (or `Endpoint`, `Route`)
- Each data row: `| METHOD | /path/to/resource | ... |`

For each endpoint found, record:
- `id`: The API identifier if present (e.g., `API-005`), or auto-generate from method+path
- `method`: HTTP method (GET, POST, PUT, PATCH, DELETE)
- `path`: URL path pattern
- `specFile`: Source file and line number
- `requestFields`: Field names from request body schema (if documented)
- `responseFields`: Field names from response body schema (if documented)
- `statusCodes`: Expected HTTP status codes

#### 1.2 Extract Use Case References

Read `spec/use-cases/*.md` (or `spec/use-cases.md` if single file) and extract:
- UC identifiers: pattern `UC-\d{3}`
- Associated API references within each UC (pattern `API-\d{3}`)
- Associated BDD references within each UC (pattern `BDD-\d{3}`)

Build a map: `UC-ID → [API-IDs, BDD-IDs]`

#### 1.3 Extract BDD Scenario IDs

Scan for BDD scenarios in:
1. `spec/bdd/*.md` or `spec/bdd/*.feature`
2. BDD blocks embedded in `spec/use-cases/*.md` (fenced code blocks with `gherkin` or `Given/When/Then`)
3. `test/**/*.feature`

For each scenario, record:
- `id`: BDD identifier (pattern `BDD-\d{3}`) or scenario name
- `scenarioName`: The `Scenario:` or `Scenario Outline:` title
- `specFile`: Source file and line number

#### 1.4 Build Spec Manifest

Assemble the complete spec manifest:
```
specManifest = {
  endpoints: [...],      // from 1.1
  useCases: [...],       // from 1.2
  bddScenarios: [...],   // from 1.3
  specFiles: [...]        // all spec files read
}
```

**Graceful degradation:**
- If `spec/contracts/` does not exist: note "No API contracts found — endpoint analysis skipped" and continue with BDD-only analysis
- If `spec/use-cases/` does not exist: note "No use cases found — UC mapping skipped"
- If no BDD scenarios found anywhere: note "No BDD scenarios found — BDD coverage skipped"
- If NONE of the above exist: STOP with message "No spec artifacts found. Run the SDD pipeline first (start with /sdd-requirements-engineer)."

---

### Phase 2: Extract from Code

Build a "code manifest" — what the system ACTUALLY does.

#### 2.1 Detect Project Language and Framework

Detect the project's language and framework by checking for:

| File | Framework |
|------|-----------|
| `package.json` with `express` dep | Express.js |
| `package.json` with `fastify` dep | Fastify |
| `package.json` with `hono` dep | Hono |
| `package.json` with `next` dep | Next.js |
| `app/api/*/route.ts` or `route.js` | Next.js App Router |
| `pyproject.toml` or `requirements.txt` with `flask` | Flask |
| `pyproject.toml` or `requirements.txt` with `fastapi` | FastAPI |
| `manage.py` or `urls.py` | Django |

If multiple frameworks detected, process ALL of them. If none detected, set `projectFramework: "unknown"` and attempt generic route detection using all parsers.

#### 2.2 Extract Route Definitions

Using the regex patterns from `references/language-parsers.md`, scan `src/**/*` for route/endpoint definitions.

For each route found, record:
- `method`: HTTP method
- `path`: URL path pattern
- `codeFile`: Source file path
- `handler`: Function/method name handling the route
- `line`: Line number of the route definition

**Important**: Also scan files outside `src/` if the framework convention places routes elsewhere:
- Next.js: `app/api/**/*`
- Django: `**/urls.py`
- Express: `routes/**/*`, `api/**/*`

#### 2.3 Extract Exported Functions and Classes

Scan `src/**/*.{ts,js,tsx,jsx,py,java,go,rs}` for exported symbols:
- JS/TS: `export (default )?(function|class|const) NAME`
- Python: top-level `def` and `class` definitions (non-underscore-prefixed)

This provides context for orphan analysis — code that exists but serves no specified purpose.

#### 2.4 Extract Test Files

Scan for test files that may correspond to BDD scenarios:
- `test/**/*`, `tests/**/*`, `__tests__/**/*`
- Files matching: `*.test.{ts,js,py}`, `*.spec.{ts,js,py}`, `test_*.py`, `*.feature`

Build a test file inventory with searchable content (scenario names, describe blocks, test names).

#### 2.5 Build Code Manifest

```
codeManifest = {
  framework: "express|fastify|...",
  routes: [...],          // from 2.2
  exports: [...],         // from 2.3
  testFiles: [...],       // from 2.4
  sourceFiles: [...]      // all source files scanned
}
```

---

### Phase 3: Gap Analysis

Compare spec manifest against code manifest to identify gaps.

#### 3.1 MISSING Endpoints

For each endpoint in `specManifest.endpoints`:
1. Search `codeManifest.routes` for a matching route (same method + compatible path)
2. Path matching rules:
   - Exact match: `/api/users` = `/api/users`
   - Parameter equivalence: `/api/users/:id` = `/api/users/{id}` = `/api/users/[id]`
   - Prefix tolerance: spec `/users` matches code `/api/users` (common prefix addition)
3. If NO match found: classify as **MISSING**

#### 3.2 ORPHAN Routes

For each route in `codeManifest.routes`:
1. Search `specManifest.endpoints` for a matching spec entry
2. If NO match found: classify as **ORPHAN**
3. Exclude common framework routes from orphan detection:
   - Health checks: `/health`, `/healthz`, `/ready`, `/ping`
   - Documentation: `/docs`, `/swagger`, `/openapi`
   - Metrics: `/metrics`, `/prometheus`

#### 3.3 MISMATCH Detection

For endpoints that match by method+path, compare:
1. **Field names**: request/response field names in spec vs handler parameters/body parsing in code
2. **HTTP method**: spec says POST but code has PUT (or vice versa)
3. **Status codes**: spec documents 201 for creation but code returns 200

Mismatch detection is best-effort — it compares what can be extracted via regex. Report findings with confidence level.

#### 3.4 BDD Coverage

For each BDD scenario in `specManifest.bddScenarios`:
1. Search `codeManifest.testFiles` for:
   - A `.feature` file containing the scenario ID or name
   - A test file with `describe`/`it`/`test` block referencing the scenario ID
   - A test file whose name correlates with the scenario (fuzzy match on UC/BDD ID)
2. If NO matching test file found: classify as **uncovered BDD scenario**

---

### Phase 4: Write Results

#### 4.1 Write Structured Results

Write `.sdd/gap-analysis.json` with the following schema:

```json
{
  "$schema": "sdd-gap-analysis-v1",
  "generatedAt": "ISO-8601",
  "projectFramework": "express|fastify|hono|nextjs|flask|fastapi|django|unknown",
  "endpoints": {
    "specified": [
      {
        "id": "API-005",
        "method": "POST",
        "path": "/api/users",
        "specFile": "spec/contracts/users.md:24"
      }
    ],
    "implemented": [
      {
        "id": "API-005",
        "method": "POST",
        "path": "/api/users",
        "codeFile": "src/routes/users.ts",
        "handler": "createUser",
        "line": 45
      }
    ],
    "missing": [
      {
        "id": "API-012",
        "method": "DELETE",
        "path": "/api/users/:id",
        "specFile": "spec/contracts/users.md:38"
      }
    ],
    "orphan": [
      {
        "method": "GET",
        "path": "/api/legacy",
        "codeFile": "src/routes/legacy.ts",
        "handler": "getLegacy",
        "line": 12
      }
    ],
    "mismatch": [
      {
        "id": "API-003",
        "issue": "Spec expects field 'email', code uses 'mail'",
        "specFile": "spec/contracts/users.md:15",
        "codeFile": "src/routes/users.ts:30"
      }
    ]
  },
  "bddCoverage": {
    "totalScenarios": 50,
    "withTestFiles": 42,
    "withoutTestFiles": 8,
    "missing": ["BDD-020", "BDD-033"]
  },
  "statistics": {
    "totalSpecEndpoints": 20,
    "implemented": 18,
    "missing": 2,
    "orphanRoutes": 3,
    "mismatches": 1,
    "endpointCoveragePercent": 90.0,
    "bddCoveragePercent": 84.0
  }
}
```

#### 4.2 Print Summary Table

Display a summary to the user:

```
## Gap Analysis Summary

| Metric                    | Count | Percentage |
|---------------------------|-------|------------|
| Specified endpoints       | 20    |            |
| Implemented endpoints     | 18    | 90.0%      |
| Missing endpoints         | 2     | 10.0%      |
| Orphan routes (unspecified)| 3    |            |
| Schema mismatches         | 1     |            |
| BDD scenarios (total)     | 50    |            |
| BDD with test files       | 42    | 84.0%      |
| BDD without test files    | 8     | 16.0%      |

### Missing Endpoints (not implemented)
| ID      | Method | Path              | Spec File                    |
|---------|--------|-------------------|------------------------------|
| API-012 | DELETE | /api/users/:id    | spec/contracts/users.md:38   |

### Orphan Routes (not in spec)
| Method | Path        | Code File                  | Handler    |
|--------|-------------|----------------------------|------------|
| GET    | /api/legacy | src/routes/legacy.ts:12    | getLegacy  |

### Mismatches
| ID      | Issue                              | Spec File | Code File |
|---------|------------------------------------|-----------|-----------|
| API-003 | Spec 'email', code uses 'mail'     | ...       | ...       |

### Uncovered BDD Scenarios
BDD-020, BDD-033
```

---

### Phase 5: Human Review Document

**Purpose:** Generate a structured review document listing every ORPHAN, MISSING, and SCHEMA finding as a line item requiring a human decision. The LLM NEVER decides whether orphan code should stay or go — that is a human judgment call.

> **Principle:** Over-delivery (gold plating) is as harmful as under-delivery. Code without requirement backing introduces untested surface area, breaks traceability, and consumes maintenance budget. But only a human can decide whether to promote the feature to a formal REQ or remove it.

#### 5.1 Write `audits/GAP-ANALYSIS-REVIEW.md`

For each finding from Phase 3, create a structured entry:

```markdown
### {TYPE}-{NNN}: {Short title}
- **File:** `{file path}:{line}`
- **Origin:** {Where the code/spec came from — REQ, audit recommendation, implementation decision}
- **What it does:** {Brief description}
- **Why it's {orphan|missing|schema drift}:** {Explanation referencing specific REQ or spec gap}
- **Risk of {removing|not implementing|keeping as-is}:** {Concrete consequence}
- **Decision:** `________` **Rationale:** _______________________
```

#### 5.2 Decision Options

Include this legend at the top of the document:

| Decision | Meaning | Action |
|----------|---------|--------|
| **PROMOTE** | The feature is valuable — promote to formal REQ via `/sdd-req-change` | Create REQ, update specs, keep code |
| **REMOVE** | The feature was not requested — remove the code | Delete code, update tests |
| **ACCEPT** | Keep as-is without formal REQ (document rationale) | No code change, add rationale |
| **DEFER** | Decide later | No action now |

#### 5.3 Processing Instructions

Include at the bottom:

```
## How to process this document
1. Review each finding
2. Write your decision (PROMOTE / REMOVE / ACCEPT / DEFER) and rationale
3. For PROMOTE decisions: run `/sdd-req-change` to create the formal REQ
4. For REMOVE decisions: delete the code and update affected tests
5. For ACCEPT decisions: no code change, rationale serves as documentation
6. Commit this document with decisions as the audit trail
```

#### 5.4 Rules

- **NEVER** auto-fix findings — all decisions are human
- **NEVER** recommend REMOVE or PROMOTE — present facts neutrally, let the human decide
- **ALWAYS** include "Risk of removing/not implementing" so the human can make an informed choice
- For ORPHAN items that come from security audit recommendations (INFO/RECOMMENDATION severity), explicitly note: "Origin: audit recommendation, not a formal REQ"
- For ORPHAN items that are testing infrastructure (`NODE_ENV` guards, test env vars), note: "Origin: implementation convenience for testability"

---

## Constraints

- **C-01**: READ-ONLY on `spec/` and `src/` — never modify source or spec files
- **C-02**: Only writes to `.sdd/` directory (creates it if needed)
- **C-03**: Language-agnostic approach with specific regex parsers per detected framework
- **C-04**: Regex-based extraction only — no AST parser dependencies, no npm install
- **C-05**: Tolerant of partial specs — if contracts don't exist, skip endpoint analysis and report it
- **C-06**: Can be run at any pipeline stage — does not depend on pipeline-state.json
- **C-07**: Excludes common infrastructure routes from orphan detection (health, docs, metrics)
- **C-08**: Path matching is flexible — handles parameter syntax differences across frameworks
- **C-09**: Gap detection only — never proposes fixes or generates code
- **C-10**: If both spec and code manifests are empty, STOP early with clear guidance

## Output Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Gap analysis JSON | `.sdd/gap-analysis.json` | Structured results with all gaps, orphans, mismatches |
| Human review document | `audits/GAP-ANALYSIS-REVIEW.md` | Each finding as a decision item for human review (PROMOTE/REMOVE/ACCEPT/DEFER) |
| Console summary | (stdout) | Human-readable summary table |

## Integration with Other Skills

| Skill | Relationship |
|-------|-------------|
| `/sdd-dashboard` | Dashboard can load `.sdd/gap-analysis.json` for graph enrichment and coverage visualization |
| `/sdd-traceability-check` | Complementary: traceability-check verifies ID chains across specs; gap-detector verifies spec-to-code alignment |
| `/sdd-reconcile` | Complementary: reconcile handles drift resolution; gap-detector provides the objective gap data |
| `/sdd-code-index` | Code index provides symbol-level data; gap-detector provides endpoint-level data |
| `/sdd-pipeline-status` | Pipeline status can reference gap-analysis.json for implementation progress |
| MCP `sdd_gaps` tool | MCP server can expose gap-analysis.json via `sdd_gaps` query tool |

## Persist Summary

After writing `.sdd/gap-analysis.json`, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["gap-detector"].status` = `"done"` (utility stage — add key if absent)
3. Set `stages["gap-detector"].lastRun` = current ISO-8601
4. Set `stages["gap-detector"].summary`:
   - `artifacts`: `[{"file": ".sdd/gap-analysis.json", "label": "Gap Analysis Results"}]`
   - `metrics`: `{ "total_spec_endpoints": N, "implemented": N, "missing": N, "orphan_routes": N, "mismatches": N, "endpoint_coverage_pct": N, "bdd_coverage_pct": N }`
   - `highlights`: top 3-5 observations (e.g., "2 missing endpoints: API-012, API-015", "3 orphan routes in src/routes/legacy.ts", "90% endpoint coverage")
   - `nextStep`: `"Implement missing endpoints"` or `"All endpoints covered — review orphan routes"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user
