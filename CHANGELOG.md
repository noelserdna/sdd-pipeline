# Changelog

All notable changes to the SDD skills repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-03-04

### Added
- **sdd-tech-designer** (v1.0.0): New lateral skill — 12-dimension technical architecture exploration (delivery channels, architecture style, tech stack, data strategy, auth, API, infrastructure, CI/CD, observability, cost, DX, i18n). Outputs `design/TECHNICAL-DESIGN.md`, `design/QUALITY-ATTRIBUTES.md`, `design/ADR-DRAFT-*.md`. ATAM-lite quality attribute analysis.
- **sdd-ux-designer** (v1.0.0): New lateral skill — 12-dimension UI/UX design system (brand, tokens, components, responsive, accessibility, interaction, forms, navigation, frontend security, performance, mobile, theming). Outputs `ux/UI-DESIGN-SYSTEM.md`, `ux/WIREFRAMES.md`, `ux/ACCESSIBILITY-SPEC.md`, `ux/INTERACTION-MODEL.md`, `ux/DESIGN-TOKENS.json`. WCAG 2.1 AA compliance.

### Fixed
- **sdd-dashboard**: Tolerate `[x]` in TASK headings and fix multi-ref context bug
- **sdd-dashboard**: Use summary metrics fallback when artifact count is 0
- **sdd-dashboard**: Infer domain/layer from title for generic REQ prefixes
- **sdd-dashboard**: Use functional-only denominators for implementation coverage metrics

### Changed
- **sdd-plan-architect** (v1.2.0): Phase 2.0 System Vision Gate, Phase 2.9 Coverage Gate, 13 clarify categories (+CL-UI, CL-DX, CL-ENV), consumes `design/` and `ux/` directories
- **cascade-patterns.md**: Includes tech-designer and ux-designer as lateral stages
- **graph-schema.md**: Includes tech-designer and ux-designer in lateralStages
- CLAUDE.md updated to 22 skills with lateral skill documentation

## [2.0.0] - 2026-03-01

### Added
- **MCP Server** (`server/`): TypeScript server exposing the SDD traceability graph via Model Context Protocol
  - 5 tools: `sdd_query` (text search with scoring), `sdd_impact` (BFS blast radius by depth), `sdd_context` (360° artifact view), `sdd_coverage` (gap analysis by domain/layer), `sdd_trace` (full chain traversal REQ→...→TEST with break detection)
  - 7 resources via `sdd://` protocol: `pipeline/status`, `pipeline/stages`, `artifacts/{type}`, `artifacts/{type}/{id}`, `graph/schema`, `graph/stats`, `coverage/gaps`
  - 2 workflow prompts: `analyze_impact` (pre-change workflow), `generate_status_report` (pipeline health)
  - Next-step hints on every tool response (GitNexus pattern)
  - Reads `dashboard/traceability-graph.json` with file watcher and graceful degradation
  - Registered via `.mcp.json` at repo root
- **Context Augmentation Hook** (`automation/hooks/sdd-augment-hook.js`): PreToolUse hook injecting SDD traceability context
  - Intercepts: Grep, Glob, Read, Edit, Write
  - Matches by file path (codeRefs), artifact ID patterns (regex), and symbols (code intelligence)
  - Formats: traceability chain, coverage status, last commit, callers/callees/processes when code intelligence available
  - Silent failure — never breaks tool calls
- **Code Index Skill** (`sdd-code-index/` v1.0.0): GitNexus bridge for deep code intelligence
  - Modes: Full (GitNexus AST), Lite (regex, no call graph), Status, Refresh
  - Maps GitNexus symbols to SDD artifacts via `Refs:` annotations and transitive inference (max depth 2, confidence ≥0.7)
  - Enriches `traceability-graph.json` with `codeIntelligence` block (symbols, callGraph, processes, stats)
  - Reference: `bridge-patterns.md` (mapping rules, confidence calculation, community→domain mapping)
- **Graph Schema v4** (`sdd-dashboard/references/graph-schema.md`): backward-compatible extension for code intelligence
  - New block: `codeIntelligence` with `symbols[]`, `callGraph[]`, `processes[]`, `stats`
  - New fields: `codeRefs[].inferred` (boolean), `codeRefs[].confidence` (0-1)
  - New relationship type: `inferred-implements`
  - Absent by default — all existing dashboards work without changes

### Changed
- **sdd-req-change**: New Step 8 "Code Intelligence Impact Analysis" — uses `sdd_impact` for symbol-level blast radius when MCP server available, with fallback to existing git log approach
- **sdd-traceability-check**: New Step 5.5 "Code & Test Chain Verification" — validates codeRef/testRef existence, detects orphaned annotations and uncovered code paths
- **sdd-reconcile**: New Phase 2 Step 5 "Code Intelligence Enrichment" — uses MCP server for scalable code scan instead of manual file-by-file reading
- **sdd-dashboard**: Enhanced Step 5 with code intelligence — uses `codeIntelligence.symbols[]` for precise data when available, adds `inferred-implements` relationships
- CLAUDE.md updated to 20 skills with MCP server documentation

## [1.8.0] - 2026-03-01

### Added
- **Dashboard v5 — Interactive Prompts & Live Status** (`sdd-dashboard/`)
  - Contextual prompt generation, copy-to-clipboard, next action card
  - Pipeline stage popovers with status/prompt/copy
  - JSONP live status polling (`live-status.js`) every 5s with graceful degradation
  - 7 new CSS components, SKILL v4.0.0, HTML template v5

## [1.7.0] - 2026-03-01

### Added
- **Dashboard v4.0.0** (`sdd-dashboard/`)
  - 3 CRITICAL bug fixes, 4 HIGH, 3 MEDIUM
  - Visual modernization: Inter font, shadows, gradients, SVG health ring, animations
  - Adoption view (5th tab): journey stepper, scenario card, findings, reconciliation, import
  - Schema v3: `adoption` block, `adoptionStats`
  - Guide v2.0.0: 3-part structure, 18 new glossary terms

## [1.6.0] - 2026-03-01

### Added
- **4 Onboarding Skills** for brownfield SDD adoption
  - `sdd-onboarding` (v1.0.0): project detector, 8 scenarios, health score 0-100, action plan
  - `sdd-reverse-engineer` (v1.0.0): code→SDD artifacts, 10 phases, findings taxonomy (7 markers)
  - `sdd-reconcile` (v1.0.0): spec-code drift detection, 6 divergence types, auto/ask rules
  - `sdd-import` (v1.0.0): external docs→SDD (Jira, OpenAPI, Markdown, Notion, CSV, Excel)

## [1.5.0] - 2026-02-28

### Added
- **Commit Traceability Integration**: commits as first-class traceability link
  - Extended chain: `REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST`
  - task-implementer: SHA capture, commit log table, CHECK-C03 verification
  - Dashboard: `commitRefs[]`, `implemented-by-commit`, commit stat cards
  - traceability-check: Step 5 "Commit Chain Verification"
  - req-change: Phase 2 step 7 "Commit Impact Analysis"

## [1.4.0] - 2026-02-28

### Added
- **SDD System Guide**: `guide-template.md` → `dashboard/guide.html`
- **Per-file Test Coverage Map** across pipeline skills (plan-architect, task-generator, task-implementer)

## [1.3.0] - 2026-02-28

### Changed
- **Dashboard v3.0.0**: UX overhaul for non-technical stakeholders
  - Executive Summary default view, Health Score hero, humanized labels, WCAG AA contrast fixes

## [1.2.0] - 2026-02-27

### Changed
- **Dashboard v2.0.0**: code/test tracing, auto-classification, graph schema v2
  - 3 views: Matrix, Classification, Code Coverage; 5-tab detail panel

## [1.1.0] - 2026-02-27

### Added
- `sdd-dashboard`: visual HTML traceability dashboard
- `sdd-sync-notion`: bidirectional Notion sync
- 5 agents: A4 requirements-watcher, A5 spec-compliance, A6 test-coverage, A7 traceability-validator, A8 pipeline-health

## [1.0.0] - 2026-02-07

### Added
- Initial repository with 13 SDD skills (9 pipeline + 3 utility + 1 setup)
- 3 agents: A1 constitution-enforcer, A2 cross-auditor, A3 context-keeper
- 4 hooks: H1 session-start, H2 upstream-guard, H3 state-updater, H4 stop-hook
- Automation infrastructure in `automation/`
