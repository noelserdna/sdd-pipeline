# Changelog

All notable changes to the SDD plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 4.0.0 (en curso) — repositorio unificado `noelserdna/sdd-pipeline`

**Breaking**
- Nuevo id de plugin: `sdd-pipeline@noelserdna` (antes `sdd@noelserdna-claude-plugin-sdd` y `sdd-pipeline@sdd-pipeline-local`). Desinstala el antiguo antes de instalar (ver `docs/migracion.md`).
- Los hooks los aporta el plugin (`hooks/hooks.json` con `${CLAUDE_PLUGIN_ROOT}`); `sdd-setup` ya no copia hooks ni agentes al proyecto. `pipeline-state.json` pasa a `hooksVersion: 3`.
- `version:` desaparece del frontmatter de las skills; la única fuente de versión es `.claude-plugin/plugin.json`.

**Added**
- Fusión de `sdd-skills` (upstream), `claude-plugin-sdd` (empaquetado) y el fork `sdd-pipeline`: 24 skills (incluido el bloque brownfield y la nueva `sdd-lead`), 5 agentes (`sdd-orchestrator`, `sdd-pipeline-auditor`, `sdd-context-keeper`, `sdd-constitution-enforcer`, `sdd-cross-auditor`), dashboard agrupado por fases, gap-detector con revisión humana.
- Servidor MCP como bundle único `server/dist/server.js` (esbuild, sin `node_modules`), versión inyectada en build, tests (`npm test`).
- Validación y CI: `scripts/validate-plugin.mjs`, `check-paths.sh`, `check-version.sh`, `tests/hooks`, `tests/e2e`, GitHub Actions (ubuntu + macos, node 18/22).
- `examples/todo-app/`: proyecto de juguete con requisitos aprobados para las pruebas E2E.
- `docs/legacy/INVENTARIO.md`, `docs/coste-contexto.md` (always-on ~4.8k tok con 23 skills + 5 agentes).

**Changed**
- Hook H5 (`sdd-augment-hook.js`) ya no se dispara en `Grep|Glob`.
- Comandos `/sdd:<skill>` → `/sdd-<skill>` en docs y en el servidor MCP.

**Removed**
- `install-sdd-automation.sh`, `automation/INSTALL.md`, `settings-template.json`, rutas del autor (`~/programacion/sdd-skills`, cache `noelserdna-plugins`).


## [3.1.0] - 2026-03-16

### Added
- **Pipeline Status Line**: Always-visible pipeline progress at the bottom of Claude Code CLI (`scripts/sdd-status-line.sh`). Shows active stage, completion count, stale/error warnings. Zero API cost, display-only. Installed opt-in via `/sdd-setup` Step 5.7.5.
- **Dashboard: Functional & E2E test stages**: Pipeline bar now shows two new stages — `functional-tests` and `e2e-tests` — after `task-implementer`, with auto-derived status and counts from scanned test files.
- **Dashboard: E2E test discovery**: `scan_test_refs()` now detects E2E tests via directory (`e2e/`, `playwright/`, `cypress/`) and filename (`*.e2e.ts`, `*.pw.ts`) conventions. Each test ref carries `testType: "e2e"|"functional"`.
- **Dashboard: test_stats breakdown**: 6 new fields in `testStats` — `functionalFiles`, `functionalTests`, `functionalWithRefs`, `e2eFiles`, `e2eTests`, `e2eWithRefs`.

### Fixed
- **Dashboard: codeRefs/testRefs propagation to REQs**: New `propagate_refs_to_req_artifacts()` BFS fills `codeRefs`/`testRefs` on REQ nodes from downstream artifacts (UC, INV, API). Previously, REQs showed ✗ in Code/Test columns despite having transitive coverage. Propagated refs marked with `origin: "propagated"`.
- **H3 (pipeline-state-updater)**: Now transitions `done → running` when new artifact writes are detected. Previously, stages marked "done" stayed "done" even when actively writing files, causing false `SDD [7/7] OK` status during ongoing implementation.

## [2.3.0] - 2026-03-05

### Added
- **Commit-based traceability inference**: Enriches code coverage automatically from git commit trailers (`Refs:`, `Task:`) — no manual `// Refs:` comments needed
  - 4 origin states: `linked` (direct), `inferred` (commit), `suggested` (task-only), `uncovered` — with shape+color+text for colorblind accessibility
  - Single `git log --all --name-only` call with null-byte delimiters (~0.5s vs 160s for per-commit approach)
  - BFS N-hop propagation (max depth 3) replaces 1-hop for REQ coverage chains
  - Manual overrides via `.sdd/overrides.json` (pin/suppress operations)
- **Graph schema v6**: Backward-compatible extension with `origin`, `inferredFrom`, `files[]`, inference stats on `codeStats`
- **code-index Phase 4.5**: Commit-Symbol Bridge — maps git diff hunks to symbol ranges for symbol-level inference
- **traceability-check Step 5b**: Inferred Reference Verification — validates commit SHAs, file freshness, task linkage; classifies as valid/stale/broken

### Fixed
- **dashboard**: Pipe delimiter in `scan_commits()` broke when commit subject contained `|` — now uses `%x00` null bytes
- **dashboard**: `Refs:` regex captured prose from commit body — now uses `%(trailers:key=Refs,valueonly)`
- **dashboard**: Ref ID validation accepted any string — now validates against `ARTIFACT_ID_RE` pattern
- **dashboard**: ZeroDivisionError when `total_functional_reqs` is 0
- **dashboard**: `open(file, "w")` truncated immediately on crash — now uses tempfile + `os.replace()` for crash-safe writes

### Changed
- **dashboard generate.py**: Rewritten `scan_commits()`, new `infer_code_refs_from_commits()`, `propagate_refs_to_reqs()` (BFS), `apply_overrides()`, `_refine_with_code_intelligence()`
- **dashboard html-template**: 4-state origin indicators (Linked/Inferred/Suggested/Uncovered) with shape+color+text, inference paths, legend
- **MCP server**: Updated TypeScript types (`origin`, `inferredFrom` on CodeRef, `files` on CommitRef), coverage tool shows inference breakdown, trace tool includes origin, context tool separates direct vs inferred refs
- **dashboard SKILL.md**: Documents inference engine and 5 origin types
- **graph-schema.md**: Schema v6 with migration notes from v5

## [2.2.0] - 2026-03-04

### Added
- **tech-designer** (v1.0.0): New lateral skill — 12-dimension technical architecture exploration (delivery channels, architecture style, tech stack, data strategy, auth, API, infrastructure, CI/CD, observability, cost, DX, i18n). Outputs `design/TECHNICAL-DESIGN.md`, `design/QUALITY-ATTRIBUTES.md`, `design/ADR-DRAFT-*.md`. ATAM-lite quality attribute analysis.
- **ux-designer** (v1.0.0): New lateral skill — 12-dimension UI/UX design system (brand, tokens, components, responsive, accessibility, interaction, forms, navigation, frontend security, performance, mobile, theming). Outputs `ux/UI-DESIGN-SYSTEM.md`, `ux/WIREFRAMES.md`, `ux/ACCESSIBILITY-SPEC.md`, `ux/INTERACTION-MODEL.md`, `ux/DESIGN-TOKENS.json`. WCAG 2.1 AA compliance.
- **GUIA-PASO-A-PASO.md**: Step-by-step guide in Spanish for new users

### Fixed
- **dashboard**: Tolerate `[x]` in TASK headings and fix multi-ref context bug
- **dashboard**: Use summary metrics fallback when artifact count is 0
- **dashboard**: Infer domain/layer from title for generic REQ prefixes
- **dashboard**: Use functional-only denominators for implementation coverage metrics
- **Install command**: Fixed installation instructions (`/plugin marketplace add` + `/plugin install`)
- **marketplace.json**: Version synced to match plugin.json (was 1.8.0, now 2.2.0)

### Changed
- **plan-architect** (v1.2.0): Phase 2.0 System Vision Gate, Phase 2.9 Coverage Gate, 13 clarify categories (+CL-UI, CL-DX, CL-ENV), consumes `design/` and `ux/` directories
- **cascade-patterns.md**: Includes tech-designer and ux-designer as lateral stages
- **graph-schema.md**: Includes tech-designer and ux-designer in lateralStages
- Plugin version bumped from 2.1.0 to 2.2.0 (22 skills)

## [2.0.0] - 2026-03-01

### Added
- **MCP Server** (`server/`): TypeScript server exposing the SDD traceability graph via Model Context Protocol
  - 5 tools: `sdd_query` (text search with scoring), `sdd_impact` (BFS blast radius by depth), `sdd_context` (360° artifact view), `sdd_coverage` (gap analysis by domain/layer), `sdd_trace` (full chain traversal REQ→...→TEST with break detection)
  - 7 resources via `sdd://` protocol: `pipeline/status`, `pipeline/stages`, `artifacts/{type}`, `artifacts/{type}/{id}`, `graph/schema`, `graph/stats`, `coverage/gaps`
  - 2 workflow prompts: `analyze_impact` (pre-change workflow), `generate_status_report` (pipeline health)
  - Next-step hints on every tool response (GitNexus pattern)
  - Reads `dashboard/traceability-graph.json` with file watcher and graceful degradation
  - Registered via `.mcp.json` at plugin root
- **Context Augmentation Hook** (`hooks/sdd-augment-hook.js`): PreToolUse hook injecting SDD traceability context
  - Intercepts: Grep, Glob, Read, Edit, Write
  - Matches by file path (codeRefs), artifact ID patterns (regex), and symbols (code intelligence)
  - Formats: traceability chain, coverage status, last commit, callers/callees/processes when code intelligence available
  - Silent failure — never breaks tool calls
- **Code Index Skill** (`skills/code-index/` v1.0.0): GitNexus bridge for deep code intelligence
  - Modes: Full (GitNexus AST), Lite (regex, no call graph), Status, Refresh
  - Maps GitNexus symbols to SDD artifacts via `Refs:` annotations and transitive inference (max depth 2, confidence ≥0.7)
  - Enriches `traceability-graph.json` with `codeIntelligence` block (symbols, callGraph, processes, stats)
  - Reference: `bridge-patterns.md` (mapping rules, confidence calculation, community→domain mapping)
- **Graph Schema v4** (`graph-schema.md`): backward-compatible extension for code intelligence
  - New block: `codeIntelligence` with `symbols[]`, `callGraph[]`, `processes[]`, `stats`
  - New fields: `codeRefs[].inferred` (boolean), `codeRefs[].confidence` (0-1)
  - New relationship type: `inferred-implements`
  - Absent by default — all existing dashboards work without changes

### Changed
- **req-change**: New Step 8 "Code Intelligence Impact Analysis" — uses `sdd_impact` for symbol-level blast radius when MCP server available, with fallback to existing git log approach
- **traceability-check**: New Step 5.5 "Code & Test Chain Verification" — validates codeRef/testRef existence, detects orphaned annotations and uncovered code paths
- **reconcile**: New Phase 2 Step 5 "Code Intelligence Enrichment" — uses MCP server for scalable code scan instead of manual file-by-file reading
- **dashboard**: Enhanced Step 5 with code intelligence — uses `codeIntelligence.symbols[]` for precise data when available, adds `inferred-implements` relationships
- Plugin version bumped from 1.8.0 to 2.0.0

## [1.8.0] - 2026-03-01

### Dashboard v5 — Interactive Prompts & Live Status (Phase 1)
- **Contextual Prompt Generation**: `getStagePrompt()` and `getNextAction()` produce Spanish-language, context-aware prompts based on pipeline state and coverage gaps — paste directly into Claude Code
- **Copy-to-Clipboard**: All prompts have "Copy" buttons with toast notification feedback (clipboard API with fallback)
- **Next Action Card**: Prominent card at top of Summary view showing the single most important next step with reason and copy-ready prompt
- **Hero Recommendation Copy Buttons**: Each recommendation in the Health Score hero now has a copy button with a full contextual prompt (not just "/sdd:X" commands)
- **Pipeline Stage Popovers**: Click any pipeline stage to see popover with status, last run date, artifact count, stage-specific prompt with copy button, and "Filter by Stage" action
- **Activity Feed Panel**: Scrollable feed in Summary view showing real-time pipeline activity entries with timestamps, stage names, and status icons
- **JSONP Live Status Polling**: Loads `./live-status.js` every 5 seconds via `<script>` tag injection (works with `file://` protocol, no server needed)
  - `window.__SDD_LIVE_UPDATE(data)` callback updates activity feed and pipeline indicators
  - Live dot indicator: pulsing green (active), yellow (stale), hidden (no file)
  - Stale detection: heartbeat >60s + status=running shows "Possibly stalled" warning
  - Graceful degradation: silent no-op on 404, live dot hidden after 3 failures, race condition guard via timestamp comparison
- **New reference**: `live-status-template.md` — JSONP schema, field reference, idle seed template, skill integration instructions
- **SKILL.md v4.0.0**: New Step 9.5 "Generate Live Status Seed File" writes `dashboard/live-status.js` on dashboard generation
- **New output**: `dashboard/live-status.js` (JSONP seed file for live activity feed)
- **7 new CSS components**: `.toast`, `.copy-btn`, `.next-action-card`, `.prompt-block`, `.activity-panel`/`.activity-feed`, `.stage-popover`, `.live-dot`

## [1.7.0] - 2026-03-01

### Dashboard v4.0.0
- **Bug fixes**: 3 CRITICAL (pipeline null crash, NaN stats, XSS in summary), 4 HIGH (undefined file, NaN gaps, filter conflict, ARIA), 3 MEDIUM (empty missing render, sticky CSS, misleading coverage pct)
- **Visual modernization**: Shadow system, gradient background, Inter font, SVG health ring chart, improved progress bars, CSS pipeline arrows, view transitions, staggered animations, custom tooltips, bento summary grid, styled scrollbars, focus-visible styles
- **Adoption view**: New 5th tab showing onboarding status — journey stepper, scenario card, health dimensions, findings panel, reconciliation panel, import panel; graceful empty states per sub-panel
- **Schema v3**: New `adoption` block with `onboarding`, `reverseEngineering`, `reconciliation`, `import` sub-blocks; new `adoptionStats` in statistics; backward-compatible (defaults to `{ present: false }`)
- **SKILL.md v3.0.0**: New Step 2.5 scanning onboarding artifacts (5 report types from 5 directories); updated Step 8 assembly and Step 10 report for v3

### Guide v2.0.0
- **3-part structure**: Part 2 "Adopting SDD in Existing Projects" (new)
- **Onboarding skills**: Brownfield decision tree, 8 project scenarios table, 4 skill descriptions (onboarding, reverse-engineer, reconcile, import)
- **Adoption View section**: Journey stepper, scenario card, dimensions, findings, reconciliation, import panels
- **Updated traceability chain**: 11 nodes (added COMMIT with orange styling)
- **Updated pipeline skills**: 19 skills count, commit traceability references
- **Expanded glossary**: 18 new terms (COMMIT, SHA, Brownfield, Greenfield, Scenario, Drift, Reconciliation, finding markers, Health Score, Blast Radius, Coverage Map, ISO 14764)

## [1.6.0] - 2026-03-01

### Added
- **4 Onboarding Skills** for adopting SDD in existing projects (brownfield, drift, migration scenarios)
  - **`onboarding`** (v1.0.0): Project detector and SDD adoption planner
    - 7-phase diagnostic: environment check, SDD artifact scan, non-SDD doc scan, code/test analysis, scenario classification, health score estimation, action plan generation
    - 8 scenarios: greenfield, brownfield bare, SDD drift, partial SDD, brownfield with docs, tests-as-spec, multi-team, fork/migration
    - Health score 0-100 with per-dimension breakdown (requirements, specs, tests, architecture, traceability, code quality, pipeline state)
    - Modes: default (full), `--quick`, `--reassess`
    - Output: `onboarding/ONBOARDING-REPORT.md`
    - References: `detection-matrix.md` (25+ signals, weighted classification matrix), `action-plan-templates.md` (8 scenario templates with effort/health projections)
  - **`reverse-engineer`** (v1.0.0): Code to SDD artifact generator
    - 10-phase process with 2 user checkpoints (after inventory/analysis, after artifact generation)
    - Generates complete SDD artifacts: requirements (EARS syntax), specs, test plan, architecture plan, retroactive tasks, findings report
    - Findings taxonomy with 7 markers: `[DEAD-CODE]`, `[TECH-DEBT]`, `[WORKAROUND]`, `[INFRASTRUCTURE]`, `[ORPHAN]`, `[INFERRED]`, `[IMPLICIT-RULE]`
    - Language-specific analysis patterns: TypeScript, Python, Rust, Go, Java
    - Modes: default (full), `--scope=paths`, `--inventory-only`, `--continue`, `--findings-only`
    - Output: `requirements/`, `spec/`, `test/`, `plan/`, `task/`, `findings/`, `reverse-engineering/`
    - References: `code-analysis-patterns.md`, `requirement-extraction-heuristics.md`, `findings-taxonomy.md`, `retroactive-task-template.md`
  - **`reconcile`** (v1.0.0): Spec-code drift detection and alignment
    - 8-phase process: context loading, code scan, spec-code comparison, divergence classification, reconciliation plan, user review, apply changes, pipeline state update
    - 6 divergence types: `NEW_FUNCTIONALITY` (auto), `REMOVED_FEATURE` (auto), `BEHAVIORAL_CHANGE` (ask), `REFACTORING` (auto), `BUG_OR_DEFECT` (ask), `AMBIGUOUS` (ask)
    - Automatic resolution for safe types; user decision for ambiguous cases
    - Modes: default (full), `--dry-run`, `--scope=paths`, `--code-wins`
    - Output: `reconciliation/RECONCILIATION-REPORT.md` + updated specs/requirements
    - References: `divergence-classification.md`, `reconciliation-strategies.md`, `reconciliation-report-template.md`
  - **`import`** (v1.0.0): External documentation to SDD format converter
    - 7-phase process: format detection, parse input, mapping preview, user confirmation, generate SDD artifacts, quality check, pipeline state update
    - 6 formats supported: Jira (JSON/CSV), OpenAPI/Swagger (YAML/JSON), Markdown, Notion (markdown/CSV), CSV, Excel (.xlsx)
    - Auto-detect format with content inspection fallback
    - EARS syntax conversion from user stories, imperative statements, conditionals, API descriptions
    - Modes: default (auto-detect), `--format=TYPE`, `--target=requirements|specs|both`, `--merge`
    - Output: `requirements/`, `spec/`, `import/IMPORT-REPORT.md`
    - References: `format-parsers.md`, `mapping-rules.md`, `import-report-template.md`

## [1.5.0] - 2026-02-28

### Added
- **Commit Traceability Integration**: commits are now a first-class link in the SDD traceability chain
  - Extended chain: `REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST`
  - task-implementer Phase 7: SHA capture via `git rev-parse --short HEAD` after each atomic commit
  - task-implementer Phase 8: progress reports include SHA (`→ commit abc1234`)
  - task-implementer Phase 9: completion report includes full commit log table (Task/SHA/Message/Refs)
  - CHECK-C03: full implementation procedure (search by Task trailer → fallback subject → verify file scope → graceful degradation)
  - commit-conventions.md: new "SHA Capture & Traceability" section documenting the extended chain
  - Dashboard graph schema: `commitRefs[]` on artifacts, `implemented-by-commit` relationship type
  - Dashboard statistics: `commitStats` (totalCommits, commitsWithRefs, commitsWithTasks, uniqueTasksCovered) and `reqsWithCommits` coverage metric
  - Dashboard Step 5.5: "Scan Commit References" — scans git log for `Refs:` and `Task:` trailers, builds commitRef objects, propagates to REQs
  - Dashboard HTML: "Commits" and "Requirements with Commits" stat cards, progress bar in Summary view, commit stats in Code Coverage view
  - traceability-check Step 5: "Commit Chain Verification" — TASK→commit mapping, gap detection (tasks without commits, commits without refs, broken refs), commit coverage metric
  - traceability-patterns.md: TASK ID pattern (`TASK-F\d{1,2}-\d{3,4}`), "Commit Reference Patterns" section (Task/Refs trailers, git log extraction)
  - req-change Phase 2 step 7: "Commit Impact Analysis" — artifact→commits→files blast radius estimation via git log

### Changed
- Dashboard schema remains v2 (backward compatible): `commitRefs` defaults to `[]`, `commitStats` to zeros
- All git checks include graceful degradation (skip if not inside a git repository)
- Session Report table expanded with SHA and Commit Message columns

## [1.4.0] - 2026-02-28

### Added
- **SDD System Guide**: self-contained HTML documentation page (`guide.html`) generated alongside the dashboard
  - Part 1: Full SDD system documentation (9 pipeline skills, traceability chain, automation hooks/agents, utility skills)
  - Part 2: Dashboard interpretation guide (all views, metrics, health score formula, color legend, glossary)
  - Sticky sidebar navigation with scroll-spy active tracking
  - Same dark theme as dashboard, responsive at 768px
  - "Guide" button in dashboard header linking to `guide.html`; "Back to Dashboard" link in guide
  - New reference: `guide-template.md`
- **Per-file Test Coverage Map** across pipeline skills
  - plan-architect: Coverage Map §7.4 in FASE templates (source file → test file mapping with classification)
  - task-generator: 1 test task per source file from Coverage Map; new validations V-13, V-14
  - task-implementer: per-file coverage verification (0% = CRITICAL, <80% domain logic = WARNING), coverage in completion report
  - New verification dimension: Dimension 4 (Coverage) with CHECK-COV-01 through CHECK-COV-04

### Changed
- Dashboard SKILL.md Step 9 now generates both `index.html` and `guide.html`
- Dashboard output artifacts: added `dashboard/guide.html`

## [1.3.0] - 2026-02-28

### Changed
- **Dashboard v3.0.0 — Comprehension Dashboard**: UX overhaul for non-technical stakeholders
  - New Executive Summary view as default tab: coverage progress bars, top gaps, artifact breakdown, pipeline status
  - Health Score hero banner: weighted letter grade (A-F) with actionable recommendations
  - Humanized all labels: UC → Use Cases, WF → Workflows, BDD → Acceptance Tests, INV → Business Rules, ADR → Decisions
  - Status labels: Full → Complete, Partial → In Progress, Spec Only → Specified, Untraced → Not Started
  - Color legend below stats cards for status dot meanings
  - WCAG AA contrast fixes: improved --text2, --text3, --yellow, --gray color values
  - Contextual tooltips on all stats cards and zero-count matrix cells
  - Responsive hero banner (column layout on mobile)
  - No schema changes — all improvements are UI/presentation only

## [1.2.0] - 2026-02-27

### Changed
- **Dashboard v2.0.0 — Comprehension Dashboard**: Major upgrade to the traceability dashboard skill
  - Traces REQs to source code: scans `src/` for `Refs:` comments in JSDoc, inline comments, and decorators
  - Traces REQs to tests: scans `tests/` for artifact references in test descriptions and file headers
  - Auto-classifies REQs by business domain (from prefix), technical layer (from FASE), and functional category (from section headers)
  - New graph schema v2: `codeRefs[]`, `testRefs[]`, `classification{}` on artifacts; `codeStats`, `testStats`, `classificationStats` in statistics
  - New relationship types: `implemented-by-code` (code→artifact), `tested-by` (test→artifact)
  - New HTML dashboard views: Matrix (enhanced), Classification (domain grouping), Code Coverage (file-level detail)
  - Redesigned detail panel with 5 tabs: Story (narrative), Trace Chain, Code, Tests, Documents
  - New filters: Domain, Layer, Category dropdowns
  - New status calculation: Full (REQ+UC+BDD+TASK+Code+Tests), Partial, Spec Only, Untraced
  - Symbol extraction from code: functions, classes, consts with fallback to filename:line
  - Test framework detection: vitest, jest, pytest, jasmine
  - Reference documents updated: `id-patterns-extended.md`, `graph-schema.md`, `html-template.md`

## [1.1.0] - 2026-02-27

### Added
- New utility skill: `dashboard` — generates a visual HTML traceability dashboard from SDD pipeline artifacts
  - Scans all pipeline directories for artifact definitions (REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK)
  - Extracts cross-references and relationship types (implements, verifies, orchestrates, etc.)
  - Builds `dashboard/traceability-graph.json` with full artifact graph and statistics
  - Generates self-contained `dashboard/index.html` (no external dependencies)
  - Interactive features: pipeline status bar, traceability matrix, filters, detail panel
  - Extended ID patterns supporting compound IDs (REQ-EXT-001, INV-SYS-001, API-pdf-reader)
- Reference documents: `id-patterns-extended.md`, `graph-schema.md`, `html-template.md`
- New agent: Requirements Watcher (A4) — detects changes in requirements since last dashboard generation
- New agent: Spec Compliance Checker (A5) — verifies src/ implements what spec/ declares
- New agent: Test Coverage Monitor (A6) — calculates % of REQs with BDD/test coverage
- New agent: Traceability Validator (A7) — suspect link detection inspired by IBM DOORS
- New agent: Pipeline Health Monitor (A8) — health score 0-100 with actionable recommendations
- New utility skill: `sync-notion` — bidirectional sync of SDD artifacts with Notion databases
  - Push: creates/updates Notion databases with relations for REQ, UC, WF, API, BDD, INV, ADR, TASK
  - Pull: detects Notion changes and applies them to local markdown (with confirmation)
  - Rate-limited API calls (3 req/s), idempotent push, conflict resolution
  - Reference documents: `notion-schema.md`, `sync-protocol.md`

## [1.0.0] - 2026-02-07

### Added
- Initial plugin release migrated from sdd-skills repository
- 9 pipeline skills: requirements-engineer, specifications-engineer, spec-auditor, test-planner, plan-architect, task-generator, task-implementer, security-auditor, req-change
- 3 utility skills: pipeline-status, traceability-check, session-summary
- 1 setup skill: setup (initializes pipeline-state.json)
- 3 agents: constitution-enforcer (A1), cross-auditor (A2), context-keeper (A3)
- 4 hooks: session-start (H1), upstream-guard (H2), state-updater (H3), stop-hook (H4)
- SDD Constitution as shared reference
- All skills namespaced under `sdd:` (e.g., `/sdd:requirements-engineer`)
