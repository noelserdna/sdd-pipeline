# Traceability Graph JSON Schema

Schema for `dashboard/traceability-graph.json` — the structured representation of all SDD artifacts, code references, test references, classifications, and their relationships.

## Full Schema

```json
{
  "$schema": "traceability-graph-v3",
  "generatedAt": "2026-02-27T15:30:00.000Z",
  "projectName": "my-project",

  "pipeline": {
    "currentStage": "task-generator",
    "stages": [
      {
        "name": "requirements-engineer",
        "status": "done",
        "lastRun": "2026-02-25T10:00:00.000Z",
        "artifactCount": 330
      },
      {
        "name": "specifications-engineer",
        "status": "done",
        "lastRun": "2026-02-25T14:00:00.000Z",
        "artifactCount": 150
      },
      {
        "name": "spec-auditor",
        "status": "done",
        "lastRun": "2026-02-26T09:00:00.000Z",
        "artifactCount": 5
      },
      {
        "name": "test-planner",
        "status": "done",
        "lastRun": "2026-02-26T11:00:00.000Z",
        "artifactCount": 20,
        "summary": {
          "artifacts": [
            { "file": "test/TEST-PLAN.md", "label": "Test Strategy" },
            { "file": "test/TEST-MATRIX-extraction.md", "label": "Extraction Matrix" }
          ],
          "metrics": { "bdd_scenarios": 101, "test_matrices": 5, "perf_scenarios": 12, "invariants_mapped": 46, "test_gaps": 3 },
          "highlights": ["101 BDD scenarios cover 85% of requirements", "3 gaps in NFR testing identified"],
          "nextStep": "Run /sdd-plan-architect",
          "generatedAt": "2026-02-26T11:00:00.000Z"
        }
      },
      {
        "name": "plan-architect",
        "status": "done",
        "lastRun": "2026-02-26T15:00:00.000Z",
        "artifactCount": 10
      },
      {
        "name": "task-generator",
        "status": "running",
        "lastRun": null,
        "artifactCount": 0
      },
      {
        "name": "task-implementer",
        "status": "pending",
        "lastRun": null,
        "artifactCount": 0
      }
    ],
    "lateralStages": [
      {
        "name": "security-auditor",
        "status": "done",
        "lastRun": "2026-02-27T12:00:00.000Z",
        "artifactCount": 1,
        "summary": {
          "artifacts": [{ "file": "audits/SECURITY-AUDIT-BASELINE.md", "label": "Security Audit Baseline" }],
          "metrics": { "total_findings": 12, "critical": 1, "high": 3, "medium": 5, "low": 3, "owasp_coverage": 78 },
          "highlights": ["1 critical: Missing CSRF protection on payment endpoint"],
          "nextStep": "Address critical findings before implementation",
          "generatedAt": "2026-02-27T12:00:00.000Z"
        }
      }
    ]
  },

  "artifacts": [
    {
      "id": "REQ-EXT-001",
      "type": "REQ",
      "category": "EXT",
      "title": "Extract text from PDF files",
      "file": "requirements/REQUIREMENTS.md",
      "line": 42,
      "priority": "Must Have",
      "stage": "requirements-engineer",
      "classification": {
        "businessDomain": "Extraction & Processing",
        "technicalLayer": "Backend",
        "functionalCategory": "Functional"
      },
      "codeRefs": [
        {
          "file": "src/extraction/validators/pdf-validator.ts",
          "line": 8,
          "symbol": "validateSize",
          "symbolType": "function",
          "refIds": ["UC-001", "INV-EXT-005"]
        }
      ],
      "testRefs": [
        {
          "file": "tests/unit/extraction/pdf-validator.test.ts",
          "line": 12,
          "testName": "accepts size at exact 50MB limit",
          "framework": "vitest",
          "refIds": ["UC-001", "INV-EXT-005"]
        }
      ],
      "commitRefs": [
        {
          "sha": "abc1234",
          "fullSha": "abc1234567890abcdef1234567890abcdef123456",
          "message": "feat(extraction): add PDF upload endpoint",
          "author": "developer",
          "date": "2026-02-27T15:30:00.000Z",
          "taskId": "TASK-F1-003",
          "refIds": ["UC-001", "INV-EXT-005"]
        }
      ]
    }
  ],

  "relationships": [
    {
      "source": "UC-001",
      "target": "REQ-EXT-001",
      "type": "implements",
      "sourceFile": "spec/use-cases/UC-001.md",
      "line": 15
    }
  ],

  "statistics": {
    "totalArtifacts": 800,
    "byType": {
      "REQ": 330,
      "UC": 41,
      "WF": 15,
      "API": 20,
      "BDD": 42,
      "INV": 55,
      "ADR": 12,
      "NFR": 30,
      "RN": 25,
      "FASE": 8,
      "TASK": 242
    },
    "totalRelationships": 1200,
    "traceabilityCoverage": {
      "totalReqs": 330,
      "totalFunctionalReqs": 290,
      "reqBreakdown": { "Functional": 290, "Non-Functional": 30, "Constraint": 10 },
      "reqsWithUCs": { "count": 280, "total": 290, "percentage": 96.6 },
      "reqsWithBDD": { "count": 200, "total": 330, "percentage": 60.6, "functionalCount": 190, "functionalTotal": 290, "functionalPercentage": 65.5 },
      "reqsWithTasks": { "count": 250, "total": 330, "percentage": 75.8, "functionalCount": 250, "functionalTotal": 290, "functionalPercentage": 86.2 },
      "reqsWithCode": { "count": 180, "total": 330, "percentage": 54.5, "functionalCount": 180, "functionalTotal": 290, "functionalPercentage": 62.1 },
      "reqsWithTests": { "count": 160, "total": 330, "percentage": 48.5, "functionalCount": 155, "functionalTotal": 290, "functionalPercentage": 53.4 },
      "reqsWithCommits": { "count": 170, "total": 330, "percentage": 51.5, "functionalCount": 170, "functionalTotal": 290, "functionalPercentage": 58.6 }
    },
    "orphans": ["INV-SYS-042", "NFR-015"],
    "brokenReferences": [
      {
        "ref": "UC-099",
        "referencedIn": "spec/workflows/WF-003.md",
        "line": 15
      }
    ],
    "codeStats": {
      "totalFiles": 85,
      "totalSymbols": 340,
      "symbolsWithRefs": 120
    },
    "testStats": {
      "totalTestFiles": 42,
      "totalTests": 285,
      "testsWithRefs": 95
    },
    "commitStats": {
      "totalCommits": 48,
      "commitsWithRefs": 42,
      "commitsWithTasks": 45,
      "uniqueTasksCovered": 40
    },
    "classificationStats": {
      "byDomain": {
        "Extraction & Processing": 45,
        "Security & Auth": 30,
        "Frontend & UI": 25,
        "Data & Storage": 20,
        "Integration & APIs": 15,
        "Other": 5
      },
      "byLayer": {
        "Infrastructure": 10,
        "Backend": 80,
        "Frontend": 40,
        "Integration/Deployment": 5,
        "Unknown": 10
      },
      "byCategory": {
        "Functional": 200,
        "Non-Functional": 50,
        "Security": 30,
        "Data": 25,
        "Integration": 25
      }
    },
    "adoptionStats": {
      "overallAdoptionScore": 65,
      "overallAdoptionGrade": "C",
      "criticalFindingsCount": 3,
      "highFindingsCount": 8,
      "alignmentPercentage": 78.5
    }
  },

  "adoption": {
    "present": true,
    "onboarding": {
      "present": true,
      "scenario": "brownfield-bare",
      "scenarioName": "Brownfield — No Documentation",
      "confidence": 0.85,
      "healthScore": 42,
      "dimensions": {
        "requirements": 0,
        "specs": 0,
        "tests": 65,
        "architecture": 20,
        "traceability": 0,
        "codeQuality": 55,
        "pipelineState": 0
      },
      "actionPlan": [
        { "step": 1, "skill": "reverse-engineer", "description": "Generate SDD artifacts from existing code", "effort": "high" },
        { "step": 2, "skill": "reconcile", "description": "Align generated specs with code reality", "effort": "medium" },
        { "step": 3, "skill": "test-planner", "description": "Create test plan from specifications", "effort": "medium" }
      ],
      "signals": ["has_source_code", "no_requirements_dir", "no_spec_dir", "has_tests"]
    },
    "reverseEngineering": {
      "present": true,
      "findings": {
        "total": 45,
        "bySeverity": { "critical": 3, "high": 8, "medium": 20, "low": 14 },
        "byCategory": { "DEAD-CODE": 5, "TECH-DEBT": 12, "WORKAROUND": 8, "INFRASTRUCTURE": 6, "ORPHAN": 4, "INFERRED": 7, "IMPLICIT-RULE": 3 },
        "topFindings": [
          { "id": "FIND-001", "severity": "critical", "category": "TECH-DEBT", "description": "No error handling in payment module" },
          { "id": "FIND-002", "severity": "critical", "category": "DEAD-CODE", "description": "Unused authentication middleware" }
        ]
      },
      "inventory": {
        "totalFiles": 156,
        "totalLOC": 24500,
        "byLayer": { "Backend": 95, "Frontend": 45, "Infrastructure": 16 }
      }
    },
    "reconciliation": {
      "present": true,
      "alignmentPercentage": 78.5,
      "divergences": {
        "total": 12,
        "byType": { "NEW_FUNCTIONALITY": 4, "BEHAVIORAL_CHANGE": 3, "REFACTORING": 2, "BUG_OR_DEFECT": 1, "REMOVED_FEATURE": 1, "AMBIGUOUS": 1 },
        "resolved": 8,
        "pending": 4
      },
      "delta": { "specsAdded": 6, "specsModified": 4, "reqsAdded": 3, "reqsModified": 2 }
    },
    "import": {
      "present": true,
      "sources": [
        { "format": "jira", "file": "backlog-export.csv", "itemCount": 85, "mappedCount": 72 },
        { "format": "openapi", "file": "api-spec.yaml", "itemCount": 24, "mappedCount": 24 }
      ],
      "totals": { "itemsProcessed": 109, "itemsMapped": 96, "itemsSkipped": 13 },
      "quality": { "completeness": 88.1, "duplicatesFound": 5, "conflictsFound": 2 },
      "artifactsGenerated": { "requirements": 72, "useCases": 18, "apiContracts": 24 }
    }
  }
}
```

## Field Definitions

### Root

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `$schema` | string | Yes | `"traceability-graph-v6"` (consumes v3-v5 without error) |
| `generatedAt` | string (ISO-8601) | Yes | When the graph was generated |
| `projectName` | string | Yes | Name of the project (from `package.json`, directory name, or `pipeline-state.json`) |

### pipeline

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `currentStage` | string | Yes | Active stage name from `pipeline-state.json`, or `"unknown"` |
| `stages` | array | Yes | Ordered array of 7 pipeline stages |

### pipeline.stages[]

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Stage identifier (e.g., `"requirements-engineer"`) |
| `status` | enum | Yes | `"done"`, `"stale"`, `"running"`, `"error"`, `"pending"` |
| `lastRun` | string or null | Yes | ISO-8601 timestamp of last completion, null if never run |
| `artifactCount` | number | Yes | Count of artifacts produced by this stage |
| `stageLabel` | string | No | Unit label for `artifactCount` (e.g., `"requirements"`, `"findings"`). Defaults to `"artifacts"`. |
| `summary` | object or null | No | Stage completion summary (see `pipeline.stages[].summary` below) |

### pipeline.lateralStages[]

Optional array for lateral pipeline skills (`security-auditor`, `req-change`, `tech-designer`, `ux-designer`). Same schema as `pipeline.stages[]`. Only present when these stages have been run at least once.

### pipeline.stages[].summary

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `artifacts` | array | Yes | Files created/modified: `[{ "file": "path", "label": "description" }]`. Max 15. |
| `metrics` | object | Yes | Flat key→number map. Keys are skill-specific (see `cascade-patterns.md` Section 9). |
| `highlights` | array of strings | Yes | Notable observations. Max 5 items. |
| `nextStep` | string | Yes | Recommended next action. |
| `generatedAt` | string (ISO-8601) | Yes | When this summary was generated. |

**Lifecycle**: `null`/absent when stage never completed. Preserved (rendered dimmed) when stage is `stale`. Overwritten on re-run.

### artifacts[]

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique artifact ID (e.g., `"REQ-EXT-001"`) |
| `type` | string | Yes | Artifact type: REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK |
| `category` | string or null | No | Sub-category (EXT, CVA, SYS, SEC, F, NF) or null |
| `title` | string | Yes | Artifact title or first line of definition |
| `file` | string | Yes | Relative file path where defined |
| `line` | number | Yes | Line number of definition |
| `priority` | string or null | No | Priority level if available |
| `stage` | string | Yes | Pipeline stage that owns this artifact |
| `classification` | object or null | No | Business/technical/functional classification (see below) |
| `codeRefs` | array | No | Source code references implementing this artifact (see below) |
| `testRefs` | array | No | Test references verifying this artifact (see below) |
| `commitRefs` | array | No | Git commits referencing this artifact via Refs/Task trailers (see below) |

### artifacts[].classification

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `businessDomain` | string | Yes | Business domain inferred from REQ prefix (see `id-patterns-extended.md` Classification Taxonomy) |
| `technicalLayer` | string | Yes | Technical layer inferred from FASE mapping: `"Infrastructure"`, `"Backend"`, `"Frontend"`, `"Integration/Deployment"`, `"Unknown"` |
| `functionalCategory` | string | Yes | Functional category inferred from section headers: `"Functional"`, `"Non-Functional"`, `"Security"`, `"Data"`, `"Integration"` |

**Applies to**: REQ artifacts only. Other artifact types inherit classification from their linked REQs (not stored in JSON — resolved at render time by the HTML dashboard).

### artifacts[].codeRefs[]

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | string | Yes | Relative path to source file (forward slashes) |
| `line` | number | Yes | Line number where the Ref comment was found |
| `symbol` | string | Yes | Nearest symbol name (function, class, const, etc.) or `"filename:line"` fallback |
| `symbolType` | string | Yes | Symbol type: `"function"`, `"class"`, `"const"`, `"interface"`, `"type"`, `"method"`, `"variable"`, `"unknown"` |
| `refIds` | array of strings | Yes | Artifact IDs referenced in the Ref comment (e.g., `["UC-001", "INV-EXT-005"]`) |
| `origin` | string | No | Source of this reference: `"direct"` (default, from `// Refs:` comment), `"commit-inferred"` (from commit Refs: trailer), `"task-inferred"` (transitively from Task: trailer), `"manual-override"` (from `.sdd/overrides.json`), `"code-index"` (from codeIntelligence symbol mapping) |
| `inferredFrom` | object or null | No | Inference provenance when origin is not `"direct"`: `{ "commitSha": "abc1234", "taskId": "TASK-F1-003", "trailerRefs": ["UC-001"] }`. Default: `null` |

**Origin states and visual mapping**:
- **linked** (`origin: "direct"`): `// Refs:` comment in code — green solid badge
- **inferred** (`origin: "commit-inferred"`): Commit has Refs: + Task: trailers — yellow dashed badge
- **suggested** (`origin: "task-inferred"`): Only Task: trailer, transitively resolved — gray dotted badge
- **uncovered**: No reference of any kind — red faint badge

**Propagation**: A codeRef is attached to a REQ if any of its `refIds` match a UC/INV/BDD/WF/API that traces back to that REQ via BFS (max 3 hops). Direct REQ references in code are also captured.

### artifacts[].testRefs[]

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | string | Yes | Relative path to test file (forward slashes) |
| `line` | number | Yes | Line number of the test definition or Ref comment |
| `testName` | string | Yes | Test description (e.g., `"validates size per INV-EXT-005"`) |
| `framework` | string | Yes | Test framework: `"vitest"`, `"jest"`, `"pytest"`, `"jasmine"`, `"unknown"` |
| `refIds` | array of strings | Yes | Artifact IDs referenced in the test (e.g., `["UC-001", "INV-EXT-005"]`) |

**Propagation**: Same as codeRefs — testRefs propagate to REQs via the traceability chain.

### artifacts[].commitRefs[]

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sha` | string | Yes | Short SHA (7 chars) of the commit |
| `fullSha` | string | Yes | Full 40-char SHA of the commit |
| `message` | string | Yes | Commit subject line (first line of commit message) |
| `author` | string | Yes | Commit author name |
| `date` | string (ISO-8601) | Yes | Commit author date |
| `taskId` | string or null | Yes | Task ID from `Task:` trailer (e.g., `"TASK-F0-003"`), null if no Task trailer |
| `refIds` | array of strings | Yes | Artifact IDs from `Refs:` trailer (e.g., `["UC-002", "ADR-003"]`) |
| `files` | array of strings | No | Files changed in this commit (from `git log --name-only`). Default: `[]` |

**Propagation**: A commitRef is attached to a REQ if any of its `refIds` match a UC/INV/BDD/WF/API that traces back to that REQ via BFS (max 3 hops, same as codeRefs/testRefs). Commits with `Task:` trailers also propagate via the TASK → FASE → spec chain.

### relationships[]

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | string | Yes | ID of the referencing artifact |
| `target` | string | Yes | ID of the referenced artifact |
| `type` | string | Yes | Relationship type (see below) |
| `sourceFile` | string | Yes | File where the reference was found |
| `line` | number | Yes | Line number of the reference |

### Relationship Types

| Type | Meaning | Typical Direction |
|------|---------|-------------------|
| `implements` | UC implements REQ | UC → REQ |
| `orchestrates` | WF orchestrates API | WF → API |
| `verifies` | BDD verifies REQ/UC | BDD → REQ/UC |
| `guarantees` | INV guarantees domain rule | INV → REQ |
| `decides` | ADR decides architecture | ADR → REQ/NFR |
| `decomposes` | TASK decomposes FASE | TASK → FASE |
| `implemented-by` | Task Refs field | TASK → UC/API/INV |
| `implemented-by-code` | Code file references artifact | code → UC/INV/API |
| `tested-by` | Test file references artifact | test → UC/INV/BDD |
| `implemented-by-commit` | Commit references artifact via Refs/Task trailers | commit → UC/INV/API/TASK |
| `reads-from` | FASE reads spec | FASE → spec artifacts |
| `traces-to` | Generic cross-reference | any → any |

### statistics

| Field | Type | Description |
|-------|------|-------------|
| `totalArtifacts` | number | Total count of all artifacts |
| `byType` | object | Count per artifact type |
| `totalRelationships` | number | Total count of all relationships |
| `traceabilityCoverage` | object | Coverage metrics |
| `orphans` | array of strings | Artifact IDs with no incoming references |
| `brokenReferences` | array | References to undefined artifacts |
| `codeStats` | object | Code scanning statistics |
| `testStats` | object | Test scanning statistics |
| `commitStats` | object | Commit scanning statistics |
| `classificationStats` | object | Classification breakdown statistics |
| `adoptionStats` | object or null | Adoption/onboarding statistics (null if no onboarding data) |

### traceabilityCoverage

| Field | Type | Description |
|-------|------|-------------|
| `totalReqs` | number | Total number of REQ artifacts |
| `totalFunctionalReqs` | number | Total functional REQs (excludes NFR/Constraint) |
| `reqBreakdown` | object | Count per functional category (`Functional`, `Non-Functional`, `Constraint`, etc.) |
| `reqsWithUCs` | coverage | Functional REQs that have at least one UC |
| `reqsWithBDD` | coverage+ | REQs that have at least one BDD |
| `reqsWithTasks` | coverage+ | REQs traceable to at least one TASK |
| `reqsWithCode` | coverage+ | REQs that have at least one codeRef (directly or via chain) |
| `reqsWithTests` | coverage+ | REQs that have at least one testRef (directly or via chain) |
| `reqsWithCommits` | coverage+ | REQs that have at least one commitRef (directly or via chain) |

Base coverage object: `{ "count": N, "total": M, "percentage": P }`

Extended coverage object (coverage+): base fields plus `{ "functionalCount": N, "functionalTotal": M, "functionalPercentage": P }` — metrics computed over functional REQs only. NFR/constraint REQs are excluded since they don't produce UCs, tasks, or code by design. The HTML dashboard uses `functionalPercentage` as the primary display and falls back to `percentage` for backwards compatibility.

### codeStats

| Field | Type | Description |
|-------|------|-------------|
| `totalFiles` | number | Total source files scanned in `src/` |
| `totalSymbols` | number | Total exported symbols found across all files |
| `symbolsWithRefs` | number | Symbols that have at least one SDD artifact reference |
| `directRefs` | number | Total code refs from `// Refs:` comments (origin: direct) |
| `inferredRefs` | number | Total code refs inferred from commits (origin: commit-inferred or task-inferred) |
| `manualOverrides` | number | Total overrides applied from `.sdd/overrides.json` |

### testStats

| Field | Type | Description |
|-------|------|-------------|
| `totalTestFiles` | number | Total test files scanned |
| `totalTests` | number | Total test cases (it/test blocks) found |
| `testsWithRefs` | number | Tests that reference at least one SDD artifact |

### commitStats

| Field | Type | Description |
|-------|------|-------------|
| `totalCommits` | number | Total commits scanned with `Refs:` or `Task:` trailers |
| `commitsWithRefs` | number | Commits that have a `Refs:` trailer with at least one valid artifact ID |
| `commitsWithTasks` | number | Commits that have a `Task:` trailer |
| `uniqueTasksCovered` | number | Distinct TASK IDs referenced across all commits |

### classificationStats

| Field | Type | Description |
|-------|------|-------------|
| `byDomain` | object | Count of REQs per business domain (keys from Classification Taxonomy) |
| `byLayer` | object | Count of REQs per technical layer (`Infrastructure`, `Backend`, `Frontend`, `Integration/Deployment`, `Unknown`) |
| `byCategory` | object | Count of REQs per functional category (`Functional`, `Non-Functional`, `Security`, `Data`, `Integration`) |

### adoptionStats

| Field | Type | Description |
|-------|------|-------------|
| `overallAdoptionScore` | number | Overall SDD adoption score 0-100 |
| `overallAdoptionGrade` | string | Letter grade A-F |
| `criticalFindingsCount` | number | Count of critical findings from reverse engineering |
| `highFindingsCount` | number | Count of high findings from reverse engineering |
| `alignmentPercentage` | number | Spec-code alignment percentage from reconciliation |

### adoption

Top-level block for onboarding skill data. Defaults to `{ "present": false }` when no onboarding data exists.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `present` | boolean | Yes | Whether any adoption/onboarding data exists |
| `onboarding` | object | No | Data from `onboarding/ONBOARDING-REPORT.md` |
| `reverseEngineering` | object | No | Data from `findings/FINDINGS-REPORT.md` and `reverse-engineering/INVENTORY.md` |
| `reconciliation` | object | No | Data from `reconciliation/RECONCILIATION-REPORT.md` |
| `import` | object | No | Data from `import/IMPORT-REPORT.md` |

### adoption.onboarding

| Field | Type | Description |
|-------|------|-------------|
| `present` | boolean | Whether onboarding report exists |
| `scenario` | string | Scenario identifier (e.g., `"brownfield-bare"`, `"greenfield"`) |
| `scenarioName` | string | Human-readable scenario name |
| `confidence` | number | Classification confidence 0-1 |
| `healthScore` | number | Project health score 0-100 |
| `dimensions` | object | Per-dimension scores: `requirements`, `specs`, `tests`, `architecture`, `traceability`, `codeQuality`, `pipelineState` (each 0-100) |
| `actionPlan` | array | Steps: `{ step, skill, description, effort }` |
| `signals` | array of strings | Detection signals found |

### adoption.reverseEngineering

| Field | Type | Description |
|-------|------|-------------|
| `present` | boolean | Whether reverse engineering data exists |
| `findings` | object | `{ total, bySeverity: {critical,high,medium,low}, byCategory: {DEAD-CODE,...}, topFindings: [{id,severity,category,description}] }` |
| `inventory` | object | `{ totalFiles, totalLOC, byLayer: {Backend,Frontend,...} }` |

### adoption.reconciliation

| Field | Type | Description |
|-------|------|-------------|
| `present` | boolean | Whether reconciliation data exists |
| `alignmentPercentage` | number | Spec-code alignment 0-100 |
| `divergences` | object | `{ total, byType: {NEW_FUNCTIONALITY,...}, resolved, pending }` |
| `delta` | object | `{ specsAdded, specsModified, reqsAdded, reqsModified }` |

### adoption.import

| Field | Type | Description |
|-------|------|-------------|
| `present` | boolean | Whether import data exists |
| `sources` | array | `[{ format, file, itemCount, mappedCount }]` |
| `totals` | object | `{ itemsProcessed, itemsMapped, itemsSkipped }` |
| `quality` | object | `{ completeness, duplicatesFound, conflictsFound }` |
| `artifactsGenerated` | object | `{ requirements, useCases, apiContracts }` |

## Migration from v1

| v1 Field | v2 Change |
|----------|-----------|
| `$schema: "traceability-graph-v1"` | Changed to `"traceability-graph-v2"` |
| `artifacts[].classification` | **New**: added classification object |
| `artifacts[].codeRefs` | **New**: added code reference array |
| `artifacts[].testRefs` | **New**: added test reference array |
| `statistics.traceabilityCoverage.reqsWithCode` | **New**: code coverage metric |
| `statistics.traceabilityCoverage.reqsWithTests` | **New**: test coverage metric |
| `statistics.codeStats` | **New**: code scanning stats |
| `statistics.testStats` | **New**: test scanning stats |
| `statistics.classificationStats` | **New**: classification breakdown |
| Relationship type `implemented-by-code` | **New**: code→artifact reference |
| Relationship type `tested-by` | **New**: test→artifact reference |

| `artifacts[].commitRefs` | **New**: git commit reference array |
| `statistics.traceabilityCoverage.reqsWithCommits` | **New**: commit coverage metric |
| `statistics.commitStats` | **New**: commit scanning stats |
| Relationship type `implemented-by-commit` | **New**: commit→artifact reference |

All v1 fields remain unchanged. v2 is a backward-compatible extension.

## Migration from v2

| v2 Field | v3 Change |
|----------|-----------|
| `$schema: "traceability-graph-v2"` | Changed to `"traceability-graph-v3"` |
| `adoption` | **New**: top-level adoption block with onboarding, reverseEngineering, reconciliation, import sub-blocks |
| `statistics.adoptionStats` | **New**: adoption score, grade, findings counts, alignment percentage |

All v2 fields remain unchanged. v3 is a backward-compatible extension. When no onboarding data exists, `adoption` defaults to `{ "present": false }` and `adoptionStats` is `null`.

## Migration from v3

| v3 Field | v4 Change |
|----------|-----------|
| `$schema: "traceability-graph-v3"` | Changed to `"traceability-graph-v4"` |
| `codeIntelligence` | **New**: top-level code intelligence block from `/sdd-code-index` |
| `codeRefs[].inferred` | **New**: boolean flag for transitively inferred refs |
| `codeRefs[].confidence` | **New**: 0.0-1.0 confidence for inferred refs |
| `statistics.codeStats.symbolsWithInferredRefs` | **New**: count of symbols with inferred refs |
| Relationship type `inferred-implements` | **New**: transitively inferred code→artifact link |

All v3 fields remain unchanged. v4 is a backward-compatible extension. When no code index has been run, `codeIntelligence` is absent (not null).

## Migration from v4

| v4 Field | v5 Change |
|----------|-----------|
| `pipeline.stages[].summary` | **New**: stage completion summary object |
| `pipeline.stages[].stageLabel` | **New**: unit label for artifactCount |
| `pipeline.lateralStages` | **New**: array for lateral skills (security-auditor, req-change) |

All v4 fields remain unchanged. v5 is a backward-compatible extension. When no summaries exist, `summary` is `null` or absent and `lateralStages` is an empty array or absent.

## Migration from v5

| v5 Field | v6 Change |
|----------|-----------|
| `$schema: "traceability-graph-v5"` | Changed to `"traceability-graph-v6"` |
| `codeRefs[].origin` | **New**: origin field for direct/inferred/override/code-index tracking |
| `codeRefs[].inferredFrom` | **New**: inference provenance object with commitSha, taskId, trailerRefs |
| `commitRefs[].files` | **New**: files changed in the commit (from git log --name-only) |
| `codeStats.directRefs` | **New**: count of direct code refs |
| `codeStats.inferredRefs` | **New**: count of inferred code refs |
| `codeStats.manualOverrides` | **New**: count of manual overrides applied |

All v5 fields remain unchanged. v6 is a backward-compatible extension. The `origin` field defaults to `"direct"` when absent (backward-compatible with v3-v5 data).

### codeIntelligence (v4)

Top-level block added by `/sdd-code-index`. Absent by default.

| Field | Type | Description |
|-------|------|-------------|
| `indexed` | boolean | Whether code has been indexed |
| `indexedAt` | string (ISO-8601) | When the index was last generated |
| `engine` | string | Analysis engine: `"gitnexus"` or `"regex-lite"` |
| `engineVersion` | string | Engine version |
| `symbols` | array | Symbol table (see below) |
| `callGraph` | array | Call relationships between symbols |
| `processes` | array | Detected execution flows |
| `stats` | object | Aggregate statistics |

### codeIntelligence.symbols[]

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique symbol ID (e.g., `"sym-validate-user-a3f2"`) |
| `name` | string | Symbol name |
| `type` | string | `"Function"`, `"Class"`, `"Method"`, `"Const"`, `"Interface"` |
| `filePath` | string | Relative file path |
| `startLine` | number | Start line of definition |
| `endLine` | number | End line of definition |
| `isExported` | boolean | Whether the symbol is exported/public |
| `artifactRefs` | array of strings | Direct Refs: annotation artifact IDs |
| `inferredRefs` | array of strings | Transitively inferred artifact IDs |
| `callers` | array of strings | Symbol names that call this symbol |
| `callees` | array of strings | Symbol names called by this symbol |
| `processes` | array of strings | Execution flow names this symbol participates in |
| `community` | string | Community/cluster name from graph analysis |

### codeIntelligence.callGraph[]

| Field | Type | Description |
|-------|------|-------------|
| `from` | string | Caller symbol name |
| `to` | string | Callee symbol name |
| `confidence` | number | Edge confidence 0.0-1.0 |
| `type` | string | `"CALLS"`, `"IMPORTS"`, `"INHERITS"` |

### codeIntelligence.processes[]

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Process/flow name |
| `steps` | array of strings | Ordered symbol names in the flow |
| `entryPoint` | string | First symbol in the flow |
| `artifactRefs` | array of strings | SDD artifacts this flow implements |

### codeIntelligence.stats

| Field | Type | Description |
|-------|------|-------------|
| `totalSymbols` | number | Total symbols indexed |
| `symbolsWithRefs` | number | Symbols with direct Refs: annotations |
| `symbolsWithInferredRefs` | number | Symbols with transitive inferred refs |
| `uncoveredSymbols` | number | Symbols with no refs (direct or inferred) |
| `totalProcesses` | number | Total execution flows detected |
| `processesWithRefs` | number | Flows linked to SDD artifacts |

## Notes

- The `file` and `sourceFile` fields use forward-slash paths relative to the project root.
- `line` is 1-indexed.
- Duplicate relationships (same source+target+type) are deduplicated.
- Artifacts with the same ID but found in multiple files use the first occurrence as the definition.
- `codeRefs`, `testRefs`, and `commitRefs` are empty arrays `[]` when no references are found (not omitted).
- `classification` is `null` for non-REQ artifacts and for REQs without a recognized category prefix.
- Projects without `src/` or `tests/` directories will have empty `codeStats`/`testStats` with zero values.
- Projects without git or without commits using `Refs:`/`Task:` trailers will have empty `commitStats` with zero values and empty `commitRefs` arrays.
