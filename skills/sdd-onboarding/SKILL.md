---
name: sdd-onboarding
description: "Detects the current state of any project and generates an SDD adoption plan. Scans for existing SDD artifacts, non-SDD documentation, code, tests, and infrastructure to classify the project into one of 8 scenarios (greenfield, brownfield bare, SDD drift, partial SDD, brownfield with docs, tests-as-spec, multi-team, fork/migration). Produces a read-only diagnostic report with a step-by-step action plan specifying which SDD skills to run and in what order. Triggers on phrases like 'onboard project', 'adopt SDD', 'start SDD', 'diagnose project', 'project assessment', 'SDD readiness'."
---

# Skill: sdd-onboarding — Project Detector & SDD Adoption Planner

> **Version:** 1.0.0
> **Pipeline position:** Pre-pipeline — Entry point for any project adopting SDD
> **Delegates to:** `sdd-reverse-engineer`, `sdd-reconcile`, `sdd-import`, `sdd-requirements-engineer`, and other pipeline skills
> **SWEBOK v4 alignment:** Chapter 01 (Requirements), Chapter 09 (Engineering Models & Methods)

---

## 1. Purpose & Scope

### What This Skill Does

- **Diagnoses** the current state of a project by scanning for SDD artifacts, code, tests, documentation, and infrastructure signals
- **Classifies** the project into one of 8 predefined scenarios based on a weighted signal matrix
- **Estimates** a health score representing SDD readiness
- **Generates** a detailed, step-by-step action plan specifying which SDD skills to invoke and in what order
- **Presents** the plan for user approval — does NOT execute any skills

### What This Skill Does NOT Do

- Does NOT modify any files (except writing the onboarding report)
- Does NOT execute downstream skills — it only recommends them
- Does NOT replace human judgment — ambiguous cases are flagged for decision
- Does NOT perform deep code analysis (that is `sdd-reverse-engineer`'s job)

---

## 2. Invocation Modes

```bash
# Full diagnostic (default)
/sdd-onboarding

# Quick scan — skips deep code analysis, faster classification
/sdd-onboarding --quick

# Reassessment — re-evaluates after partial SDD adoption
/sdd-onboarding --reassess
```

| Mode | Phases Executed | Use Case |
|------|----------------|----------|
| **default** | All 7 phases | First-time project assessment |
| `--quick` | Phases 1-3, 6-7 (skip deep analysis) | Quick triage, initial estimation |
| `--reassess` | All 7 phases, compares with previous report | Mid-adoption progress check |

---

## 3. Process — 7 Phases

### Phase 1: Environment Check

**Objetivo:** Establish project context and boundaries.

1. Detect project root (look for `.git/`, `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `pom.xml`, `*.sln`, `Makefile`, etc.)
2. Identify primary language(s) and framework(s)
3. Detect package manager and dependency count
4. Check for monorepo structure (workspaces, Lerna, Nx, Turborepo)
5. Detect CI/CD configuration (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, etc.)
6. Check for containerization (`Dockerfile`, `docker-compose.yml`)
7. Record git history stats: total commits, contributors, age, last commit date

**Output:** Environment profile object.

### Phase 2: SDD Artifact Scan

**Objetivo:** Determine if the project has existing SDD artifacts and their completeness.

1. Scan for `pipeline-state.json` — if found, read current stage status
2. Check automation version: look for `hooksVersion` field in `pipeline-state.json`
   - If missing: v1 hooks — flag for upgrade in action plan (recommend running `/sdd-setup` to migrate)
   - If `hooksVersion >= 2`: current version, no action needed
   - Also check `.claude/settings.json` for v1 signals (PreToolUse matcher "SessionStart", missing hookSpecificOutput)
3. Scan for SDD directories: `requirements/`, `spec/`, `audits/`, `test/`, `plan/`, `task/`, `onboarding/`, `reconciliation/`, `findings/`
3. For each found directory:
   - Count files and total lines
   - Check for key files (e.g., `REQUIREMENTS.md`, `ARCHITECTURE.md`)
   - Verify internal cross-references (REQ-XXX, UC-XXX patterns)
   - Check last modification dates
4. Scan for `AUDIT-BASELINE.md`, `SECURITY-AUDIT-BASELINE.md`
5. Calculate SDD artifact coverage percentage

**Output:** SDD artifact inventory with coverage metrics.

### Phase 3: Non-SDD Documentation Scan

**Objetivo:** Find existing documentation that could be imported or leveraged.

1. Scan for documentation files:
   - `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`
   - `docs/` directory and contents
   - `*.md` files at any level
   - `wiki/` or `.github/wiki/` references
2. Scan for API documentation:
   - OpenAPI/Swagger files (`openapi.yaml`, `swagger.json`, `*.openapi.*`)
   - GraphQL schema files (`*.graphql`, `schema.graphql`)
   - Postman collections (`*.postman_collection.json`)
   - API Blueprint files (`*.apib`)
3. Scan for external tool exports:
   - Jira exports (`*.jira.json`, `*.jira.csv`)
   - CSV/Excel files in docs directories
   - Notion exports (markdown with metadata)
4. Scan for architecture documents:
   - `ARCHITECTURE.md`, `ADR/`, `adr/`, `decisions/`
   - Diagram files (`.drawio`, `.mermaid`, `.puml`, PlantUML)
5. Evaluate documentation quality: freshness, coverage, cross-referencing

**Output:** Non-SDD documentation inventory with leverage potential.

### Phase 4: Code & Test Analysis

**Objetivo:** Assess codebase size, structure, and test coverage. _(Skipped in `--quick` mode)_

1. Count source files by language and directory
2. Identify architectural layers:
   - Entry points (main files, index files, app bootstrap)
   - Routes/controllers/handlers
   - Services/business logic
   - Data access/repositories
   - Models/entities/types
   - Utilities/helpers
3. Detect design patterns: MVC, CQRS, event sourcing, microservices, monolith
4. Scan for existing tests:
   - Test framework(s) used (Jest, pytest, JUnit, Go testing, etc.)
   - Test count and type distribution (unit, integration, e2e)
   - Test-to-source ratio
   - Coverage configuration presence
5. Scan for code quality signals:
   - Linter configuration (ESLint, Pylint, Clippy, etc.)
   - Type checking (TypeScript strict, mypy, etc.)
   - Code comments density (JSDoc, docstrings, etc.)
6. Detect database/storage:
   - ORM/ODM usage (Prisma, SQLAlchemy, GORM, etc.)
   - Migration files
   - Schema definitions

**Output:** Code & test analysis profile.

### Phase 5: Scenario Classification

**Objetivo:** Classify the project into one of 8 scenarios using the weighted signal matrix.

Load [references/detection-matrix.md](references/detection-matrix.md) and apply the classification algorithm:

1. Evaluate each signal from Phases 1-4 against the detection matrix
2. Calculate weighted scores for each scenario
3. Apply confidence thresholds:
   - **HIGH** (>75%): Single clear scenario match
   - **MEDIUM** (50-75%): Primary scenario with notable secondary signals
   - **LOW** (<50%): Ambiguous — present top 2-3 scenarios with reasoning
4. For LOW confidence: present findings and ask user to confirm scenario
5. Document evidence for the classification decision

**8 Scenarios:**

| # | Scenario | Key Signal | Primary Action |
|---|----------|------------|----------------|
| 1 | **Greenfield** | No code, no docs | Standard pipeline from `requirements-engineer` |
| 2 | **Brownfield bare** | Code exists, no docs, no tests | `reverse-engineer` full |
| 3 | **SDD drift** | SDD artifacts + code diverged | `reconcile` |
| 4 | **Partial SDD** | Some SDD artifacts, incomplete pipeline | Resume pipeline from gap |
| 5 | **Brownfield with docs** | Code + non-SDD docs | `import` → `reverse-engineer` → `reconcile` |
| 6 | **Tests-as-spec** | Good tests, poor/no docs | `reverse-engineer` with test-first strategy |
| 7 | **Multi-team** | Monorepo/microservices, mixed states | Per-module assessment, phased adoption |
| 8 | **Fork/migration** | Forked from another project | Assess upstream, `import`/`reverse-engineer` delta |

**Output:** Classified scenario with confidence level and evidence.

### Phase 6: Health Score Estimation

**Objetivo:** Calculate a numeric health score representing current SDD readiness.

Scoring dimensions (100 points total):

| Dimension | Weight | Scoring Criteria |
|-----------|--------|-----------------|
| Requirements coverage | 20 pts | 0=none, 10=informal docs, 20=SDD format |
| Specification coverage | 20 pts | 0=none, 10=partial specs, 20=full spec/ |
| Test coverage | 15 pts | 0=none, 8=some tests, 15=good coverage+plan |
| Architecture documentation | 15 pts | 0=none, 8=README/diagrams, 15=SDD plan/ |
| Traceability | 15 pts | 0=none, 8=partial refs, 15=full chain |
| Code quality signals | 10 pts | 0=none, 5=linter, 10=types+linter+CI |
| Pipeline state | 5 pts | 0=none, 3=partial, 5=complete pipeline-state.json |

Score interpretation:

| Score | Grade | Meaning |
|-------|-------|---------|
| 80-100 | A | SDD compliant — minor gaps only |
| 60-79 | B | Partial SDD — clear path to completion |
| 40-59 | C | Significant work needed — leverage existing assets |
| 20-39 | D | Major effort required — systematic adoption needed |
| 0-19 | F | Starting from scratch or near-scratch |

**Output:** Health score with per-dimension breakdown.

### Phase 7: Action Plan Generation

**Objetivo:** Generate a concrete, step-by-step plan for SDD adoption.

Load [references/action-plan-templates.md](references/action-plan-templates.md) and:

1. Select the template matching the classified scenario
2. Customize based on project-specific findings:
   - Adjust steps based on detected documentation (leverage potential)
   - Add import steps if external docs found
   - Add reconciliation steps if drift detected
   - Estimate effort per step (S/M/L/XL)
3. Calculate projected health score progression (after each step)
4. Add risk factors and mitigation suggestions
5. Present the complete plan in the report

**Plan format per step:**

| Field | Description |
|-------|-------------|
| Step # | Sequential order |
| Skill | SDD skill to invoke (e.g., `sdd-import --format=openapi`) |
| Purpose | What this step achieves |
| Inputs | What files/artifacts it needs |
| Outputs | What it produces |
| Leverage | Existing assets it builds on |
| Effort | S/M/L/XL estimate |
| Health after | Projected health score after completion |

**Output:** Complete action plan ready for user approval.

---

## 4. Output Format

### File: `onboarding/ONBOARDING-REPORT.md`

```markdown
# SDD Onboarding Report

> Generated: {ISO-8601}
> Project: {project-name}
> Mode: {default|quick|reassess}

## 1. Executive Summary

- **Scenario:** {scenario name} (confidence: {HIGH|MEDIUM|LOW})
- **Health Score:** {score}/100 ({grade})
- **Recommended approach:** {1-2 sentence summary}
- **Estimated total effort:** {S|M|L|XL}

## 2. Environment Profile

{environment details from Phase 1}

## 3. Current State Assessment

### 3.1 SDD Artifacts
{inventory from Phase 2}

### 3.2 Existing Documentation
{inventory from Phase 3}

### 3.3 Code & Test Analysis
{analysis from Phase 4, or "Skipped (--quick mode)" }

## 4. Scenario Classification

**Classified as:** {scenario}
**Confidence:** {level}

### Evidence
{bullet list of signals that led to classification}

### Alternative scenarios considered
{if confidence < HIGH, list alternatives with reasoning}

## 5. Health Score Breakdown

| Dimension | Score | Notes |
|-----------|-------|-------|
| Requirements | X/20 | ... |
| Specifications | X/20 | ... |
| Tests | X/15 | ... |
| Architecture | X/15 | ... |
| Traceability | X/15 | ... |
| Code quality | X/10 | ... |
| Pipeline state | X/5 | ... |
| **Total** | **X/100** | **Grade: {X}** |

## 6. Action Plan

| Step | Skill | Purpose | Inputs | Outputs | Leverage | Effort | Health After |
|------|-------|---------|--------|---------|----------|--------|-------------|
| 1 | ... | ... | ... | ... | ... | ... | .../100 |
| ... | ... | ... | ... | ... | ... | ... | .../100 |

### Risk Factors
{identified risks and mitigations}

## 7. Next Steps

To begin SDD adoption, invoke the first skill in the action plan:
\`\`\`
{exact command for step 1}
\`\`\`
```

---

## 5. Reassessment Mode (`--reassess`)

When invoked with `--reassess`:

1. Load previous `onboarding/ONBOARDING-REPORT.md`
2. Re-execute all 7 phases with fresh data
3. Compare with previous assessment:
   - Health score delta (improvement/regression)
   - Steps completed vs planned
   - New signals detected
   - Scenario reclassification (if applicable)
4. Generate updated report with `## 8. Progress Since Last Assessment` section
5. Adjust remaining action plan based on current state

---

## 6. Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-reverse-engineer` | Onboarding recommends it for brownfield/bare scenarios |
| `sdd-reconcile` | Onboarding recommends it when drift is detected |
| `sdd-import` | Onboarding recommends it when external docs are found |
| `sdd-requirements-engineer` | Onboarding recommends it for greenfield or as final step |
| `sdd-pipeline-status` | Onboarding reads pipeline-state.json similarly but provides deeper analysis |
| `sdd-setup` | Onboarding may recommend running setup as first action step |

---

## 7. Pipeline Integration

### Reads
- `pipeline-state.json` (if exists)
- All SDD artifact directories
- All source code and test directories
- All documentation files

### Writes
- `onboarding/ONBOARDING-REPORT.md`

### Pipeline State
- Does NOT update `pipeline-state.json` stages (it is pre-pipeline)
- If `pipeline-state.json` does not exist, notes this as a signal (no SDD setup)

---

## 8. Constraints

1. **READ-ONLY**: The only file written is the onboarding report. No source code, tests, or existing artifacts are modified.
2. **Evidence-based**: Every classification decision must cite specific signals found during scanning.
3. **No assumptions**: If signals are ambiguous (confidence < 50%), present options and ask the user.
4. **No execution**: The skill recommends skills but never invokes them. The user decides when to start.
5. **Deterministic**: Same project state should produce the same classification and plan (barring git history changes).
6. **Language-adaptive**: Output language follows the user's language. Technical terms remain in English.
