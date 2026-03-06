# SDD Skills

> **[Leer en español](README.es.md)**

**Specification-Driven Development pipeline for Claude Code, based on SWEBOK v4.**

From requirements to production code — a structured, auditable, traceable pipeline that transforms natural-language requirements into implemented software.

> **Looking for the installable plugin?** See [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd).
> This repository is the **source of truth** for development. The plugin repo is the distributable package.

## What's in this repo

- **22 skills** in `sdd-*/` directories (pipeline + onboarding + lateral + utilities)
- **MCP server** in `server/` (TypeScript, 5 tools for querying the traceability graph)
- **Automation** in `automation/` (5 hooks, 3 agents, settings template)
- **References** in `references/` (SDD Constitution, shared knowledge)

## The Pipeline

```
sdd-requirements-engineer  →  requirements/REQUIREMENTS.md
sdd-specifications-engineer  →  spec/ (domain, use-cases, workflows, contracts, nfr, adr)
sdd-spec-auditor  →  audits/AUDIT-BASELINE.md + corrected spec/
sdd-test-planner  →  test/TEST-PLAN.md, TEST-MATRIX-*.md
sdd-plan-architect  →  plan/ (ARCHITECTURE.md, PLAN.md, FASE files)
sdd-task-generator  →  task/TASK-FASE-*.md
sdd-task-implementer  →  src/, tests/, git commits
```

**Lateral skills** (anytime): `sdd-security-auditor`, `sdd-req-change`, `sdd-tech-designer`, `sdd-ux-designer`

**Onboarding** (existing projects): `sdd-onboarding`, `sdd-reverse-engineer`, `sdd-reconcile`, `sdd-import`

**Utilities**: `sdd-pipeline-status`, `sdd-traceability-check`, `sdd-dashboard`, `sdd-code-index`, `sdd-session-summary`, `sdd-setup`

## Traceability Chain

Every artifact traces end-to-end:

```
REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST
```

## Skills Reference

### Pipeline (7)

| # | Skill | Input | Output |
|---|-------|-------|--------|
| 1 | requirements-engineer | User input | `requirements/` |
| 2 | specifications-engineer | `requirements/` | `spec/` |
| 3 | spec-auditor | `spec/` | `audits/`, corrected `spec/` |
| 4 | test-planner | `spec/`, `audits/` | `test/` |
| 5 | plan-architect | `spec/`, `audits/`, `test/` | `plan/` |
| 6 | task-generator | `plan/` | `task/` |
| 7 | task-implementer | `task/`, `spec/`, `plan/` | `src/`, `tests/`, commits |

### Onboarding (4)

| Skill | Purpose |
|-------|---------|
| onboarding | Diagnose project state (8 scenarios), generate adoption plan |
| reverse-engineer | Code → SDD artifacts (requirements, specs, tasks, findings) |
| reconcile | Detect spec-code drift, classify divergences, reconcile |
| import | External docs → SDD format (Jira, OpenAPI, Markdown, Notion, CSV, Excel) |

### Lateral (4)

| Skill | Purpose | Output |
|-------|---------|--------|
| security-auditor | OWASP ASVS v4 / CWE security posture audit of specs | `audits/SECURITY-AUDIT-BASELINE.md` |
| req-change | Manage ADD/MODIFY/DEPRECATE changes with optional pipeline cascade (ISO 14764) | Updated `requirements/`, `spec/`, cascade |
| tech-designer | Technical architecture design: stack, auth, API, infra, CI/CD, data, observability, cost, i18n (ATAM-lite quality analysis) | `design/TECHNICAL-DESIGN.md`, `design/QUALITY-ATTRIBUTES.md`, `design/ADR-DRAFT-*.md` |
| ux-designer | UI/UX design system: components, tokens, wireframes, responsive, accessibility, forms, navigation, theming | `ux/UI-DESIGN-SYSTEM.md`, `ux/WIREFRAMES.md`, `ux/ACCESSIBILITY-SPEC.md`, `ux/DESIGN-TOKENS.json` |

`tech-designer` and `ux-designer` output is consumed by `plan-architect` if present — the pipeline adapts automatically.

### Utilities (7)

| Skill | Purpose |
|-------|---------|
| pipeline-status | Pipeline state report with next-action recommendation |
| traceability-check | Verify full traceability chain (REQ→...→TEST), find orphans and broken links |
| dashboard | Generate interactive HTML traceability dashboard (5 views + guide + live status) |
| code-index | Index code symbols for deep traceability — optional [GitNexus](https://github.com/nicobailon/gitnexus) bridge for call graphs |
| sync-notion | Bidirectional sync of SDD artifacts with Notion databases |
| session-summary | Summarize session decisions and update project memory |
| setup | Initialize `pipeline-state.json` in a new project |

## MCP Server

The `server/` directory contains a TypeScript MCP server that exposes the traceability graph:

| Tool | Purpose |
|------|---------|
| `sdd_query` | Search artifacts by text, ID, type, or domain |
| `sdd_impact` | Blast radius analysis by depth |
| `sdd_context` | 360° artifact view with all connections |
| `sdd_coverage` | Gap analysis by business domain or technical layer |
| `sdd_trace` | Full chain traversal with break detection |

Plus 7 `sdd://` resources and 2 workflow prompts (`analyze_impact`, `generate_status_report`).

### Build

```bash
cd server && npm install && npm run build
```

### Installation

The MCP server is configured via `~/.claude/.mcp.json` (global) or `<project>/.mcp.json` (per-project):

```json
{
  "mcpServers": {
    "sdd": {
      "command": "node",
      "args": ["/path/to/sdd-skills/server/dist/index.js"]
    }
  }
}
```

**Global vs per-project:** The server uses `process.cwd()` to locate the traceability graph, and Claude Code launches MCP servers from the current project directory. This means a global installation automatically resolves to the correct project — no path configuration needed.

**How it finds the graph:** On startup, the server searches for `dashboard/traceability-graph.json` starting from `cwd` and walking up to 6 parent directories. If no graph is found, it degrades gracefully (returns empty results, no crash). This means:

- In projects **with** SDD artifacts: full functionality after running `/sdd:dashboard`
- In projects **without** SDD artifacts: the server loads but all queries return empty results

**Prerequisites:** Node.js 18+. After restarting Claude Code, you'll be prompted to approve the "sdd" MCP server on first use.

## Code Intelligence (Optional)

The `sdd-code-index` skill maps code symbols (functions, classes, modules) to SDD artifacts for deep traceability. It works in two modes:

- **Lite mode** (default): Regex-based analysis — no extra dependencies needed
- **Full mode**: Uses [GitNexus](https://github.com/nicobailon/gitnexus) for AST-level call graph analysis, cross-file references, and execution flow mapping

### Installing GitNexus

```bash
npm install -g gitnexus
```

Or use it without installing:

```bash
npx gitnexus analyze
```

**Requirements:** Node.js 18+

### Usage

```bash
# Full mode (with GitNexus)
/sdd-code-index

# Lite mode (regex only, no GitNexus needed)
/sdd-code-index --lite

# Check index status
/sdd-code-index --status

# Refresh only changed files
/sdd-code-index --refresh
```

When GitNexus is available, `sdd-code-index` produces richer results: symbol-level call graphs, transitive inference (max 2 hops), execution flow mapping, and community-based domain detection. Without it, the skill still works but only provides file-level symbol detection and direct `// Refs:` annotations.

## Automation

In `automation/`:

**Hooks:**
- **H1** `sdd-session-start.sh` — Injects pipeline status at session start
- **H2** `sdd-upstream-guard.sh` — Blocks downstream skills from editing upstream artifacts
- **H3** `sdd-pipeline-state-updater.sh` — Auto-updates pipeline state on writes
- **H4** Stop hook — Consistency check at session end

**Agents:**
- **A1** Constitution Enforcer — Validates against the 11 SDD Constitution articles
- **A2** Cross-Auditor — Cross-references skill definitions for I/O mismatches
- **A3** Context Keeper — Maintains informal project context

**Context Augmentation Hook** (`automation/hooks/sdd-augment-hook.js`):
Intercepts Grep/Glob/Read/Edit/Write and injects SDD traceability context automatically.

## Repository Structure

```
sdd-skills/
├── sdd-requirements-engineer/   # Each skill has SKILL.md + references/
├── sdd-specifications-engineer/
├── sdd-spec-auditor/
├── sdd-test-planner/
├── sdd-plan-architect/
├── sdd-task-generator/
├── sdd-task-implementer/
├── sdd-security-auditor/
├── sdd-req-change/
├── sdd-onboarding/
├── sdd-reverse-engineer/
├── sdd-reconcile/
├── sdd-import/
├── sdd-pipeline-status/
├── sdd-traceability-check/
├── sdd-dashboard/
├── sdd-code-index/
├── sdd-session-summary/
├── sdd-tech-designer/
├── sdd-ux-designer/
├── sdd-setup/
├── server/                      # MCP server (TypeScript)
├── automation/
│   ├── hooks/                   # H1, H2, H3, augment hook
│   ├── agents/                  # A1, A2, A3
│   └── settings-template.json
├── references/
│   └── sdd-constitution.md      # 11 articles governing the pipeline
└── recursos/                    # External references (not in git)
```

Each skill follows the same layout: `SKILL.md` (YAML front matter + full process) and `references/` (templates, checklists, patterns).

## Contributing

When modifying skills:

1. Preserve YAML front matter (`name:`, `description:`) — Claude Code uses it for registration
2. Keep cross-references consistent — skills reference each other by name
3. Run the Cross-Auditor (A2) after changes to detect I/O mismatches
4. Sync changes to the [plugin repo](https://github.com/noelserdna/claude-plugin-sdd) (adapt `sdd-X` → `X` naming)

## Standards

SWEBOK v4 &middot; OWASP ASVS v4 &middot; CWE &middot; IEEE 830 &middot; ISO 14764 &middot; C4 Model &middot; Gherkin/BDD

## License

MIT
