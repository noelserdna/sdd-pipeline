# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **meta-project**: a collection of 22 Claude Code skills (9 pipeline + 4 onboarding + 6 utility + 1 setup + 2 lateral) that implement a complete Specification-Driven Development (SDD) pipeline based on SWEBOK v4, with automation infrastructure (hooks, agents, settings) and an MCP server for live traceability queries. There is no traditional source code, build system, or package manager — the "execution" happens by invoking skills within Claude Code CLI.

## Pipeline & Skill Execution Order

```
sdd-requirements-engineer  →  requirements/REQUIREMENTS.md
        ↓
sdd-specifications-engineer  →  spec/ (domain, use-cases, workflows, contracts, nfr, adr)
        ↓
sdd-spec-auditor (Mode Audit)  →  audits/AUDIT-BASELINE.md
        ↓
sdd-spec-auditor (Mode Fix)   →  corrected spec/ documents
        ↓
sdd-test-planner  →  test/TEST-PLAN.md, test/TEST-MATRIX-*.md, test/PERF-SCENARIOS.md
        ↓
sdd-plan-architect  →  plan/ (fases/FASE-*.md, PLAN.md, ARCHITECTURE.md, fase-plans/)
        ↓
sdd-task-generator  →  task/TASK-FASE-*.md
        ↓
sdd-task-implementer  →  src/, tests/, git commits
```

**Lateral skills** (invoke at any point):
- `sdd-tech-designer` → `design/TECHNICAL-DESIGN.md`, `design/QUALITY-ATTRIBUTES.md`, `design/ADR-DRAFT-*.md` — Technical architecture exploration across 12 dimensions (delivery channels, architecture style, tech stack, data strategy, auth, API, infrastructure, CI/CD, observability, cost, DX, i18n). Optional: consumed by plan-architect if exists.
- `sdd-ux-designer` → `ux/UI-DESIGN-SYSTEM.md`, `ux/WIREFRAMES.md`, `ux/ACCESSIBILITY-SPEC.md`, `ux/INTERACTION-MODEL.md`, `ux/DESIGN-TOKENS.json` — UI/UX design system across 12 dimensions (brand, tokens, components, responsive, accessibility, interaction, forms, navigation, frontend security, performance, mobile, theming). Optional: consumed by plan-architect if exists.
- `sdd-security-auditor` → `audits/SECURITY-AUDIT-BASELINE.md`
- `sdd-req-change` → Universal change entry point: manages ADD/MODIFY/DEPRECATE with maintenance classification (ISO 14764, Ch05) and optional pipeline cascade triggering (can re-trigger spec-auditor → test-planner → plan-architect → task-generator → task-implementer)

**Onboarding skills** (for adopting SDD in existing projects):
- `sdd-onboarding` → Diagnoses project state, classifies into 8 scenarios, generates adoption plan. Entry point for any project.
- `sdd-reverse-engineer` → Analyzes existing code to generate complete SDD artifacts (requirements, specs, test plan, tasks, findings). For brownfield projects.
- `sdd-reconcile` → Detects drift between SDD specs and code, classifies divergences, reconciles. Requires existing SDD artifacts + code.
- `sdd-import` → Imports external docs (Jira, OpenAPI, Markdown, Notion, CSV, Excel) into SDD format. Pre-pipeline.

**Utility skills** (invoke on demand):
- `sdd-pipeline-status` → Pipeline status report with artifact verification and next-action recommendation
- `sdd-traceability-check` → Verifies REQ→UC→WF→API→BDD→INV→ADR traceability chain, finds orphans/broken links
- `sdd-dashboard` → Visual HTML traceability dashboard with interactive prompts, pipeline popovers, and JSONP live status feed
- `sdd-code-index` → Indexes project code for deep traceability. Bridges GitNexus code intelligence with SDD artifacts (optional, enhances blast radius analysis and code coverage)
- `sdd-session-summary` → Summarizes session decisions, categorizes formal vs informal context

**Setup skill**:
- `sdd-setup` → Installs automation (hooks, agents, settings) into target projects

## Repository Structure

Each skill follows the same layout:
```
sdd-{skill-name}/
├── SKILL.md           # Full skill definition (metadata, modes, process, constraints)
└── references/        # Templates, checklists, taxonomies, patterns
```

Automation infrastructure:
```
automation/
├── hooks/                               # Hook scripts (installed to target .claude/hooks/)
│   ├── sdd-session-start.sh             # H1: Pipeline status injection at session start
│   ├── sdd-upstream-guard.sh            # H2: Upstream artifact immutability guard
│   └── sdd-pipeline-state-updater.sh    # H3: Auto-update pipeline-state.json on writes
├── agents/                              # Agent definitions (installed to target .claude/agents/)
│   ├── sdd-constitution-enforcer.md     # A1: Validates against 11 SDD Constitution articles
│   ├── sdd-cross-auditor.md             # A2: Cross-references skill definitions for mismatches
│   └── sdd-context-keeper.md            # A3: Maintains informal project context
├── scripts/
│   └── migrate-hooks-v2.sh              # Migration script: v1→v2 hooks (idempotent, backup)
├── settings-template.json               # P1: Settings template with H1-H3 core hook configs
├── settings-optional-dashboard.json     # P2: Opt-in HTTP hooks for dashboard server (H6)
├── settings-optional-quality-gates.json # P3: Opt-in prompt/agent quality gate hooks (H7-H8)
└── INSTALL.md                           # Manual installation guide
```

MCP server (live traceability queries) + Dashboard server (HTTP+SSE):
```
server/                                  # TypeScript MCP server + Dashboard server
├── package.json                         # Deps: @modelcontextprotocol/sdk
├── tsconfig.json
└── src/
    ├── index.ts                         # Entry: stdio transport (MCP)
    ├── dashboard-entry.ts               # Entry: HTTP dashboard server
    ├── dashboard-server.ts              # HTTP+SSE server for real-time dashboard updates
    ├── sse.ts                           # SSE client manager (addClient, broadcast)
    ├── path-mapper.ts                   # File path → pipeline stage mapper
    ├── server.ts                        # createSDDServer() — registers tools/resources/prompts
    ├── graph-loader.ts                  # Reads traceability-graph.json, file watcher
    ├── tools/
    │   ├── query.ts                     # sdd_query — search artifacts by text/ID/type
    │   ├── impact.ts                    # sdd_impact — blast radius BFS by depth
    │   ├── context.ts                   # sdd_context — 360° artifact view
    │   ├── coverage.ts                  # sdd_coverage — gap analysis by domain/layer
    │   └── trace.ts                     # sdd_trace — full traceability chain
    ├── resources.ts                     # sdd:// URI handlers
    ├── prompts.ts                       # Workflow prompts (analyze_impact, generate_status_report)
    └── hints.ts                         # Next-step hints (GitNexus pattern)
```

Scripts: `sdd-specifications-engineer/scripts/create-spec-structure.ps1` (PowerShell) and `sdd-setup/scripts/install-sdd-automation.sh` (bash).

## Resources (`recursos/`)

Reference implementations and external tools used as inspiration/comparison for the SDD skills:

- **`OpenSpec/`** — Fission-AI's spec framework (`@fission-ai/openspec`, Node/TypeScript). Artifact-guided workflow with commands like `/opsx:new`, `/opsx:ff`. Iterative, brownfield-friendly approach.
- **`spec-kit/`** — GitHub's Spec-Driven Development toolkit (Python CLI via `uv`). Generates working implementations from specifications using `specify` CLI.
- **`swebok-v4.pdf`** — Software Engineering Body of Knowledge v4. The authoritative reference document cited by all skills. Also available at root level.

## Key Conventions

- **EARS syntax** for requirements: `WHEN <trigger> THE <system> SHALL <behavior>`
- **Traceability chain**: REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST
- **1 task = 1 commit** using Conventional Commits with `Refs:` and `Task:` trailers
- **Inference engine**: Commits with `Refs:`/`Task:` trailers enrich code coverage automatically; 4 origin states: `linked` (direct `// Refs:`), `inferred` (commit), `suggested` (task-only), `uncovered`
- **Graph schema v6**: `codeRefs[].origin`, `codeRefs[].inferredFrom`, `commitRefs[].files`, BFS N-hop propagation (max depth 3), `.sdd/overrides.json` for manual pin/suppress
- **Clarification-first**: Skills never assume — they ask the user via structured option tables
- **Baseline auditing**: First audit creates baseline; subsequent audits only report new/regression findings
- **Revert strategies**: Each task documents rollback approach (SAFE, COUPLED, MIGRATION, CONFIG)

## Pipeline State Management

Each target project using SDD skills tracks pipeline progress in a `pipeline-state.json` file at the project root. This enables fast-forward re-runs (inspired by OpenSpec's `/opsx:ff`) and staleness detection.

**`pipeline-state.json` schema:**
```json
{
  "currentStage": "spec-auditor",
  "stages": {
    "requirements-engineer":    { "status": "done", "completedAt": "ISO-8601", "inputHash": "sha256:...", "outputHash": "sha256:..." },
    "specifications-engineer":  { "status": "done", "completedAt": "ISO-8601", "inputHash": "sha256:...", "outputHash": "sha256:..." },
    "spec-auditor":             { "status": "running", "completedAt": null,     "inputHash": "sha256:...", "outputHash": null },
    "test-planner":             { "status": "pending", "completedAt": null,     "inputHash": null,         "outputHash": null },
    "plan-architect":           { "status": "pending", "completedAt": null,     "inputHash": null,         "outputHash": null },
    "task-generator":           { "status": "pending", "completedAt": null,     "inputHash": null,         "outputHash": null },
    "task-implementer":         { "status": "pending", "completedAt": null,     "inputHash": null,         "outputHash": null }
  }
}
```

Each completed stage also stores a `summary` object with: `artifacts` (files created), `metrics` (skill-specific numbers), `highlights` (notable observations), `nextStep` (recommended action), and `generatedAt` (timestamp). Skills persist this on completion; it's preserved when stage goes stale and overwritten on re-run. See `sdd-req-change/references/cascade-patterns.md` Section 9 for the full schema and per-skill metric keys.

Lateral skills (`security-auditor`, `req-change`) store their state as additional keys in `stages`.

**Stage I/O mapping** (used for hash computation):

| Stage                    | Input artifacts              | Output artifacts          |
|--------------------------|------------------------------|---------------------------|
| requirements-engineer    | (user input)                 | `requirements/`           |
| specifications-engineer  | `requirements/`              | `spec/`                   |
| spec-auditor             | `spec/`                      | `audits/`, corrected `spec/` |
| test-planner             | `spec/`, `audits/`           | `test/`                   |
| plan-architect           | `spec/`, `audits/`, `test/`, `design/` (optional), `ux/` (optional)  | `plan/`                   |
| task-generator           | `plan/`                      | `task/`                   |
| task-implementer         | `task/`, `spec/`, `plan/`    | `src/`, `tests/`          |

**Staleness rules:**
- A stage is **stale** when its `inputHash` no longer matches the current hash of its input directory.
- When stage N becomes stale, all stages N+1..7 are also marked stale (`status: "stale"`).
- Lateral skills (`sdd-security-auditor`, `sdd-req-change`) do not participate in the linear chain but may invalidate specific stages.
- Lateral skills (`sdd-tech-designer`) output to `design/` which is consumed optionally by `plan-architect` Phase 0.
- Lateral skills (`sdd-ux-designer`) output to `ux/` which is consumed optionally by `plan-architect` Phase 0.
- `sdd-req-change` is the primary pipeline cascade trigger: it reads/writes `pipeline-state.json` (Phases 0, 8, 9) and can invoke downstream skills via `--cascade={auto|manual|dry-run|plan-only}`. See `sdd-req-change/references/cascade-patterns.md` for full invalidation rules.

**Re-run guidance** -- when a file changes in:
- `requirements/` → re-run from `specifications-engineer` onward
- `spec/`          → re-run from `spec-auditor` onward
- `plan/`          → re-run from `task-generator` onward
- `task/`          → re-run from `task-implementer`

**State flow:**
```
pending → running → done → stale → running → done
                      ↑                        |
                      └────────────────────────┘
```

Skills should read `pipeline-state.json` on start and update it on completion. If the file does not exist, assume a fresh pipeline (all stages pending).

## Automation

SDD automation is installed into target projects via `/sdd-setup` or the install script. It consists of:

**Hooks v2** (enforced automatically by Claude Code):
- **H1 — Session Start** (`sdd-session-start.sh`): Reads `pipeline-state.json` and injects pipeline status. Event: `SessionStart` (matcher: `startup|resume|compact`).
- **H2 — Upstream Guard** (`sdd-upstream-guard.sh`): Blocks downstream skills from modifying upstream artifacts (Art. 4). Event: `PreToolUse` (matcher: `Edit|Write`). Uses `hookSpecificOutput` wrapper.
- **H3 — State Updater** (`sdd-pipeline-state-updater.sh`): Auto-updates `pipeline-state.json` on writes. Event: `PostToolUse` (matcher: `Write`, async).
- **H4 — Stop Hook** (inline prompt in settings): Verifies pipeline state consistency on session end. Uses haiku model.
- **H5 — Context Augment** (`sdd-context-augment.sh`): Enriches tool context with SDD traceability data. Event: `PreToolUse` (matcher: `Grep|Glob|Read|Edit|Write`).

**Optional hooks** (opt-in via `/sdd-setup` Step 5.7):
- **H6 — Dashboard HTTP hooks** (`settings-optional-dashboard.json`): POST events to dashboard server (`http://localhost:3001/hooks/*`). Events: SessionStart, PostToolUse, SubagentStart/Stop, TaskCompleted, Stop, SessionEnd.
- **H7 — Stop Quality Gate** (prompt hook): Pipeline consistency check at session end.
- **H8 — Task Traceability Gate** (agent hook): Verifies commit trailers on TaskCompleted.

**Skill-level hooks** (defined in SKILL.md frontmatter):
- `sdd-task-implementer` Stop hook: Prompt verifying Refs:/Task: trailers on last commit.
- `sdd-spec-auditor` Stop hook: Prompt verifying P0/P1 findings are addressed.

**Agents** (delegated by Claude or user):
- **A1 — Constitution Enforcer**: Validates operations against the 11 SDD Constitution articles. Model: haiku.
- **A2 — Cross-Auditor**: Cross-references all skill definitions for I/O contract mismatches. Model: sonnet. Has project memory.
- **A3 — Context Keeper**: Maintains informal project context (preferences, deferred decisions). Model: haiku. Has project memory.

**Dashboard Server** (`server/src/dashboard-server.ts`):
- HTTP+SSE server for real-time dashboard updates, zero external deps (node:http only)
- Receives hook events via POST `/hooks/*`, broadcasts to connected browsers via SSE `/events`
- Serves dashboard HTML at `/`, API status at `/api/status`, graph at `/api/graph`
- Configurable port via `SDD_DASHBOARD_PORT` env var (default: 3001)
- Entry: `node server/dist/dashboard-entry.js`

**Pipeline State Schema** (authoritative source: `sdd-req-change/references/cascade-patterns.md`):
- Uses `lastRun` (not `completedAt`), no `inputHash`, adds `staleReason`, `error` status, `lastChange` block.
- Includes `sddVersion` and `hooksVersion` fields for upgrade detection.
- Hooks and skills use this schema; the simplified schema in "Pipeline State Management" above is for conceptual understanding only.

## Modifying Skills

When editing a SKILL.md:
- Preserve the YAML front matter (`name`, `description`) — Claude Code uses it for skill registration
- The `description` field contains trigger phrases that control when the skill activates
- Cross-references between skills (e.g., "reads output from sdd-spec-auditor") define the pipeline contract — keep them consistent
- Reference documents in `references/` are loaded as context by the skill — changes affect skill behavior

## Standards Referenced

- **SWEBOK v4** (chapters cited per-skill)
- **OWASP ASVS v4** (security auditor)
- **CWE** (security auditor)
- **IEEE 830** (requirements format)
- **ISO 14764** (maintenance classification in req-change)
- **C4 Model** (architecture diagrams in plan-architect)
- **Gherkin/BDD** (acceptance criteria throughout)

## Known Gaps

- **Brownfield adoption:** Fully covered by 4 onboarding skills: `sdd-onboarding` (diagnosis), `sdd-reverse-engineer` (code→artifacts), `sdd-reconcile` (drift resolution), `sdd-import` (external docs). Covers greenfield, brownfield, drift, partial SDD, multi-team, fork, and tests-as-spec scenarios.
- **SWEBOK Ch05 (Software Maintenance):** Partially covered by `sdd-req-change` v2.0.0 (ISO 14764 maintenance classification, feature retirement planning, impact analysis, regression risk, technical debt tracking, pipeline cascade). Production-specific operational maintenance (monitoring, incident response, runtime rollback) remains uncovered — these are operational concerns outside the SDD specification pipeline scope.
- **SWEBOK Ch07 (Engineering Management):** No effort estimation, risk management, or project control metrics. The pipeline focuses on technical artifacts, not project management.
- **SWEBOK Ch10 (Software Eng. Economics):** Cost-benefit analysis not covered.
- **Platform dependency:** Skills use bash commands (grep, git) within Claude Code CLI, which always provides a bash environment. If porting to non-CLI contexts, these commands need abstraction.

## Language

Skills are written in English with Spanish contextual text. Output language follows the user's language. Technical terms remain in English.
