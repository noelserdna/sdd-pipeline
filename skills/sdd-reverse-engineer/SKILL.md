---
name: sdd-reverse-engineer
description: "Analyzes existing source code and tests to generate complete SDD artifacts (requirements, specifications, test plan, architecture plan, retroactive tasks) with full traceability. Performs deep code analysis to extract entities, routes, state machines, invariants, and business rules. Documents dead code, tech debt, workarounds, and orphan code as findings with severity markers. Operates as a lateral entry point to bootstrap the SDD pipeline for brownfield projects. Triggers on phrases like 'reverse engineer', 'extract specs from code', 'bootstrap SDD', 'code to requirements', 'analyze existing code', 'brownfield to SDD'."
---

# Skill: sdd-reverse-engineer — Code → SDD Artifact Generator

> **Version:** 1.0.0
> **Pipeline position:** Lateral — bootstrap entry point (not a linear pipeline stage)
> **Feeds into:** `sdd-spec-auditor`, `sdd-test-planner`, `sdd-plan-architect`
> **Invoked by:** `sdd-onboarding` (scenarios 2, 5, 6, 8)
> **SWEBOK v4 alignment:** Chapter 01 (Requirements), Chapter 02 (Design), Chapter 03 (Construction), Chapter 09 (Models & Methods)

---

## 1. Purpose & Scope

### What This Skill Does

- **Scans** the entire codebase to build a complete inventory of source files, modules, and dependencies
- **Analyzes** code structure to extract architectural layers, entities, routes, state machines, invariants, and business rules
- **Generates** SDD-compatible artifacts: requirements (EARS syntax), specifications (domain, use-cases, workflows, contracts, NFRs), test plan, architecture plan, and retroactive tasks
- **Documents** findings: dead code, tech debt, workarounds, orphan code, infrastructure patterns, and implicit rules — each tagged with severity markers
- **Establishes** full traceability chain from generated artifacts down to source code references
- **Pauses** at checkpoints (Phases 5 and 6) for user review before proceeding

### What This Skill Does NOT Do

- Does NOT modify source code or tests (`src/`, `tests/` are read-only)
- Does NOT execute tests or build commands
- Does NOT replace user validation — inferred artifacts are marked `[INFERRED]` and require confirmation
- Does NOT perform security analysis (use `sdd-security-auditor` for that)
- Does NOT handle drift detection (use `sdd-reconcile` if SDD artifacts already exist)

---

## 2. Invocation Modes

```bash
# Full reverse engineering (default)
/sdd-reverse-engineer

# Scope to specific paths
/sdd-reverse-engineer --scope=src/api,src/models

# Inventory only — scan and classify without generating artifacts
/sdd-reverse-engineer --inventory-only

# Continue from a checkpoint
/sdd-reverse-engineer --continue

# Findings only — just document dead code, debt, workarounds
/sdd-reverse-engineer --findings-only
```

| Mode | Phases Executed | Use Case |
|------|----------------|----------|
| **default** | All 10 phases | Full brownfield bootstrap |
| `--scope=paths` | All 10, filtered to paths | Partial reverse engineering (module-level) |
| `--inventory-only` | Phases 1-3 only | Quick assessment of codebase |
| `--continue` | Resume from last checkpoint | Continue after review pause |
| `--findings-only` | Phases 1-4 + findings extraction | Document code health without generating specs |

---

## 3. Process — 10 Phases

### Phase 1: Pre-Flight

**Objetivo:** Validate environment and load context.

1. Check for existing SDD artifacts — if found, WARN and suggest `sdd-reconcile` instead
2. Load `pipeline-state.json` if it exists; if not, create with all stages `pending`
3. Read `onboarding/ONBOARDING-REPORT.md` if available — use scenario and leverage hints
4. Detect project language(s), framework(s), and package manager
5. Identify scope: full project or `--scope` subset
6. Create working directory: `reverse-engineering/` for intermediate outputs

**Gate:** Abort if `src/` or equivalent source directory does not exist.

### Phase 2: Scan & Inventory

**Objetivo:** Build a complete map of the codebase.

1. Inventory all source files by language and directory
   - Count: files, lines of code, lines of comments
   - Identify entry points, configuration files
2. Build module dependency graph:
   - Import/require analysis
   - Package dependency tree (external libraries)
3. Identify architectural layers:
   - Routes/controllers/handlers → API layer
   - Services/business logic → Domain layer
   - Repositories/DAOs/queries → Data access layer
   - Models/entities/types → Domain model
   - Middleware/interceptors → Cross-cutting
   - Utilities/helpers → Infrastructure
4. Detect design patterns: MVC, CQRS, event sourcing, layered, microservices
5. Map database schema if detectable (ORM models, migration files, schema definitions)
6. Scan test files separately: framework, structure, coverage, naming conventions

**Output:** `reverse-engineering/INVENTORY.md`

### Phase 3: Code Analysis

**Objetivo:** Deep analysis using language-specific patterns.

Load [references/code-analysis-patterns.md](references/code-analysis-patterns.md) and for each source file:

1. **Entity extraction:** Classes, interfaces, types, structs, enums with their fields and relationships
2. **Route/endpoint extraction:** HTTP methods, paths, parameters, request/response schemas, middleware chain
3. **State machine detection:** States, transitions, guards, actions (from switch/case, state pattern, enum-based flows)
4. **Invariant detection:** Validation rules, assertions, constraints, guard clauses, business rule checks
5. **Dependency mapping:** What each module depends on and what depends on it
6. **Dead code detection:** Unreachable functions, unused exports, commented-out code blocks, deprecated markers
7. **Tech debt markers:** TODO/FIXME/HACK/XXX comments, complexity hotspots, duplication patterns
8. **Workaround detection:** Temporary fixes, environment-specific hacks, version-pinned patches
9. **Implicit business rules:** Conditionals that encode business logic without documentation
10. **Infrastructure patterns:** Logging, error handling, authentication, caching, rate limiting

**Output:** `reverse-engineering/ANALYSIS.md` (structured by module)

### Phase 4: Test Analysis

**Objetivo:** Extract behavioral specifications from existing tests.

1. Parse test files to extract:
   - Test suite structure (describe/context/it nesting)
   - Assertion patterns → invariants and postconditions
   - Setup/teardown → preconditions and state requirements
   - Mocks/stubs → external dependency contracts
   - Test data → valid/invalid input boundaries
2. Map test coverage to source modules
3. Identify BDD-like patterns (given/when/then, should-style)
4. Classify tests: unit, integration, e2e, performance
5. Detect test gaps: modules without test coverage

**Output:** `reverse-engineering/TEST-ANALYSIS.md`

---

### *** CHECKPOINT 1 — Review Inventory & Analysis ***

**PAUSE** and present to user:
- Codebase inventory summary (files, modules, layers)
- Detected patterns and architectural style
- Findings summary (dead code count, tech debt count, workarounds)
- Test coverage summary
- Proposed requirement grouping structure

**Ask:** "Continue with artifact generation based on these findings?"

_(In `--inventory-only` mode, STOP here.)_

---

### Phase 5: Requirements Extraction

**Objetivo:** Generate SDD-format requirements from code analysis.

Load [references/requirement-extraction-heuristics.md](references/requirement-extraction-heuristics.md) and:

1. Map discovered features to requirements using EARS syntax:
   - Routes/endpoints → functional requirements (`WHEN <trigger> THE <system> SHALL <behavior>`)
   - Validation rules → constraint requirements
   - Auth/authz patterns → security requirements
   - Performance configurations → NFRs
   - Error handling patterns → reliability requirements
2. Assign requirement IDs: `REQ-{GROUP}-{NNN}` following the project's domain structure
3. Tag each requirement with confidence level:
   - `[INFERRED]` — derived from code patterns, needs user validation
   - `[IMPLICIT-RULE]` — business logic embedded in conditionals
   - No tag — directly observable (e.g., explicit validation message)
4. Group requirements by business domain (extracted from module/directory structure)
5. Assign priority based on: usage frequency, dependency count, error handling presence
6. Cross-reference each requirement to source location: `file:line`

**Output:** `requirements/REQUIREMENTS.md` (full SDD format)

### Phase 6: Specification Generation

**Objetivo:** Generate the complete `spec/` directory.

Generate each spec document following the exact format used by `sdd-specifications-engineer`:

1. **Domain Model** (`spec/domain.md`):
   - Entities from Phase 3 entity extraction
   - Relationships from dependency mapping
   - Aggregates from transactional boundaries
   - Value objects from immutable types

2. **Use Cases** (`spec/use-cases.md`):
   - One use case per user-facing feature/endpoint
   - Actors inferred from auth roles and entry points
   - Pre/postconditions from test assertions
   - Alternative flows from error handling paths

3. **Workflows** (`spec/workflows.md`):
   - State machines from Phase 3 detection
   - Multi-step processes from sequential service calls
   - Event flows from pub/sub patterns

4. **API Contracts** (`spec/contracts.md`):
   - Endpoints from route extraction
   - Request/response schemas from type definitions
   - Error codes from error handling patterns
   - Authentication requirements

5. **NFRs** (`spec/nfr.md`):
   - Performance from config (timeouts, pool sizes, cache TTLs)
   - Security from auth patterns
   - Reliability from retry/circuit-breaker patterns
   - Scalability from container/cluster config

6. **ADRs** (`spec/adr/`):
   - One ADR per major architectural decision detected
   - Framework choice, database choice, auth strategy, etc.
   - Status: `[INFERRED]` — decision already implemented but rationale is guessed

---

### *** CHECKPOINT 2 — Review Generated Artifacts ***

**PAUSE** and present to user:
- Requirements summary: count by group, confidence distribution
- Spec coverage: which spec documents generated, completeness
- Flagged items requiring user decision
- Traceability preview: REQ → UC → WF → API mapping

**Ask:** "Proceed with test plan, architecture plan, and task generation?"

---

### Phase 7: Test Plan Mapping

**Objetivo:** Generate test plan aligned with discovered tests and specs.

1. Map existing tests to generated requirements and use cases
2. Identify coverage gaps (requirements without tests)
3. Generate `test/TEST-PLAN.md` with:
   - Existing tests classified by type
   - Recommended new tests for gaps
   - BDD scenarios derived from use cases
4. Generate `test/TEST-MATRIX-*.md` per domain area
5. If performance tests/config detected, generate `test/PERF-SCENARIOS.md`

**Output:** `test/` directory (SDD format)

### Phase 8: Plan Reconstruction

**Objetivo:** Generate architecture and implementation plan from existing structure.

1. Generate `plan/ARCHITECTURE.md`:
   - C4 model (Context, Container, Component) from detected architecture
   - Technology stack documentation
   - Deployment architecture from Docker/CI config
2. Generate `plan/PLAN.md`:
   - Phases derived from architectural layers
   - Dependency order from module graph
3. Generate phase plans (`plan/fases/FASE-*.md`):
   - One phase per architectural layer or domain area
   - Source-to-test mapping table (from `sdd-plan-architect` coverage map format)

**Output:** `plan/` directory (SDD format)

### Phase 9: Task Reconstruction

**Objetivo:** Generate retroactive task files documenting what was already built.

Load [references/retroactive-task-template.md](references/retroactive-task-template.md) and:

1. Generate `task/TASK-FASE-{N}.md` for each phase in the plan
2. Each task documents an already-implemented feature:
   - Status: `[x]` (completed) with marker `[RETROACTIVE]`
   - Commit: Real SHA from git history if traceable, or `[NO-COMMIT]`
   - Files: Actual source and test files
   - Revert strategy: `RETROACTIVE — already in production`
3. Link tasks to requirements, use cases, and source files

**Output:** `task/TASK-FASE-*.md` files (SDD format)

### Phase 10: Traceability Mapping & Findings

**Objetivo:** Establish the full traceability chain and compile findings report.

1. Build traceability chain:
   - REQ → UC → WF → API → BDD → INV → ADR → TASK → CODE
   - Mark gaps in the chain
   - Generate `Refs:` markers for code files (document but do NOT modify code)
2. Compile findings report using [references/findings-taxonomy.md](references/findings-taxonomy.md):
   - Dead code inventory with `[DEAD-CODE]` markers
   - Tech debt catalog with `[TECH-DEBT]` markers and severity
   - Workaround registry with `[WORKAROUND]` markers
   - Infrastructure patterns with `[INFRASTRUCTURE]` markers
   - Orphan code (no requirements trace) with `[ORPHAN]` markers
   - Implicit rules with `[IMPLICIT-RULE]` markers
3. Update `pipeline-state.json`:
   - Set all stages from requirements through tasks to `done`
   - Record output hashes

**Output:** `findings/FINDINGS-REPORT.md`, updated `pipeline-state.json`

---

## 4. Findings Markers

All findings are tagged with standardized markers:

| Marker | Meaning | Severity Range |
|--------|---------|---------------|
| `[DEAD-CODE]` | Unreachable or unused code | INFO — MEDIUM |
| `[TECH-DEBT]` | Suboptimal implementation requiring future work | LOW — HIGH |
| `[WORKAROUND]` | Temporary fix or hack | MEDIUM — HIGH |
| `[INFRASTRUCTURE]` | Cross-cutting concern pattern | INFO |
| `[ORPHAN]` | Code with no traceable requirement | LOW — MEDIUM |
| `[INFERRED]` | Artifact derived from code patterns, not explicit docs | INFO |
| `[IMPLICIT-RULE]` | Business rule embedded in code without documentation | MEDIUM — HIGH |

---

## 5. Output Format Summary

| Directory | Files Generated | Source |
|-----------|----------------|--------|
| `requirements/` | `REQUIREMENTS.md` | Phase 5 |
| `spec/` | `domain.md`, `use-cases.md`, `workflows.md`, `contracts.md`, `nfr.md`, `adr/` | Phase 6 |
| `test/` | `TEST-PLAN.md`, `TEST-MATRIX-*.md`, `PERF-SCENARIOS.md` | Phase 7 |
| `plan/` | `ARCHITECTURE.md`, `PLAN.md`, `fases/FASE-*.md` | Phase 8 |
| `task/` | `TASK-FASE-*.md` | Phase 9 |
| `findings/` | `FINDINGS-REPORT.md` | Phase 10 |
| `reverse-engineering/` | `INVENTORY.md`, `ANALYSIS.md`, `TEST-ANALYSIS.md` | Phases 2-4 (intermediate) |

---

## 6. Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-onboarding` | Invokes reverse-engineer for brownfield scenarios |
| `sdd-import` | May run before reverse-engineer to pre-populate requirements from external docs |
| `sdd-reconcile` | Use instead if SDD artifacts already exist (drift scenario) |
| `sdd-spec-auditor` | Run after reverse-engineer to audit generated specs |
| `sdd-test-planner` | Run after to refine test plan beyond what reverse-engineer generates |
| `sdd-plan-architect` | Run after to validate/enhance architecture plan |
| `sdd-task-implementer` | Retroactive tasks feed into its tracking; new tasks for gaps feed forward |
| `sdd-traceability-check` | Run after to verify the generated traceability chain |
| `sdd-security-auditor` | Complementary — run for security-specific analysis |

---

## 7. Pipeline Integration

### Reads
- `src/` and all source code directories (READ-ONLY)
- `tests/` and all test directories (READ-ONLY)
- `pipeline-state.json` (if exists)
- `onboarding/ONBOARDING-REPORT.md` (if exists)
- Package manager files, configs, CI/CD files

### Writes
- `requirements/REQUIREMENTS.md`
- `spec/` (full directory)
- `test/` (full directory)
- `plan/` (full directory)
- `task/TASK-FASE-*.md`
- `findings/FINDINGS-REPORT.md`
- `reverse-engineering/` (intermediate work)
- `pipeline-state.json` (stage updates)

### Pipeline State
- Sets stages `requirements-engineer` through `task-generator` to `done`
- Records hashes for all generated directories
- Does NOT set `task-implementer` to done (code already exists, but tasks are retroactive)

---

## 8. Constraints

1. **Source read-only**: NEVER modify files in `src/` or `tests/`. These directories are strictly read-only.
2. **Checkpoint pauses**: MUST pause at Checkpoints 1 and 2 for user review. Do NOT proceed without confirmation.
3. **EARS syntax**: All generated requirements MUST use EARS syntax: `WHEN <trigger> THE <system> SHALL <behavior>`.
4. **Format compatibility**: All generated artifacts MUST follow the exact format produced by the corresponding forward-pipeline skill.
5. **Evidence-based**: Every generated artifact MUST reference the source code location it was derived from.
6. **Confidence tagging**: Inferred artifacts MUST be tagged with `[INFERRED]` or `[IMPLICIT-RULE]`.
7. **No assumptions**: If a pattern is ambiguous, document it as a finding rather than guessing.
8. **Findings documented**: Dead code, tech debt, and workarounds are documented AND signaled (markers + severity) — never silently ignored.
9. **Git-aware**: When git history is available, use it for commit SHAs, contributor info, and file history analysis.
10. **Language-adaptive**: Output language follows the user's language. Technical terms remain in English.
