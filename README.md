# SDD Skills

> **[Leer en español](README.es.md)**

**Specification-Driven Development pipeline for Claude Code, based on SWEBOK v4.**

From requirements to production code — a structured, auditable, traceable pipeline that transforms natural-language requirements into implemented software through formal specifications, automated auditing, and atomic task execution.

> **Looking for the installable plugin?** See [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd).
> This repository is the **source of truth** for development. The plugin repo is the distributable package.

---

## Table of Contents

- [What is SDD?](#what-is-sdd)
- [The Pipeline](#the-pipeline)
- [Skills Reference](#skills-reference)
- [Automation Infrastructure](#automation-infrastructure)
- [How It Works in Practice](#how-it-works-in-practice)
- [Project Structure](#project-structure)
- [Pipeline State Management](#pipeline-state-management)
- [The SDD Constitution](#the-sdd-constitution)
- [Standards Referenced](#standards-referenced)
- [Known Gaps](#known-gaps)
- [Contributing](#contributing)

---

## What is SDD?

SDD (Specification-Driven Development) is a methodology where **specifications are the single source of truth**. Every line of code, every test, and every architectural decision traces back to a formal specification document. Nothing is assumed, everything is auditable, and changes propagate through the entire chain automatically.

The SDD pipeline is implemented as a collection of **13 Claude Code skills** that guide an AI assistant through each stage — from gathering requirements to committing production code. Each skill enforces constraints, produces specific artifacts, and hands off to the next stage with full traceability.

**Key principles:**

- **Specs drive everything** — code is a derived artifact, not the source of truth
- **Never assume, always ask** — every ambiguity is surfaced to the user with structured options
- **Full traceability** — every artifact traces through the chain: REQ - UC - WF - API - BDD - INV - ADR - RN
- **Atomic reversibility** — every task maps to exactly one git commit with a documented rollback strategy
- **Baseline auditing** — first audit establishes a baseline; subsequent audits only report new or regression findings

---

## The Pipeline

```
                            LINEAR PIPELINE
                            ===============

  requirements-engineer       requirements/REQUIREMENTS.md
          |
  specifications-engineer     spec/ (domain, use-cases, workflows, contracts, nfr, adr)
          |
  spec-auditor (Audit)        audits/AUDIT-BASELINE.md
          |
  spec-auditor (Fix)          corrected spec/ documents
          |
  test-planner                test/TEST-PLAN.md, TEST-MATRIX-*.md, PERF-SCENARIOS.md
          |
  plan-architect              plan/ (FASE files, PLAN.md, ARCHITECTURE.md)
          |
  task-generator              task/TASK-FASE-*.md
          |
  task-implementer            src/, tests/, git commits


                          LATERAL SKILLS
                          ==============

  security-auditor            audits/SECURITY-AUDIT-BASELINE.md    (invoke anytime)
  req-change                  pipeline cascade trigger              (invoke anytime)


                          UTILITIES
                          =========

  pipeline-status             status report + next action recommendation
  traceability-check          REQ-UC-WF-API-BDD-INV-ADR chain verification
  session-summary             session decisions categorization
```

Each stage reads artifacts from the previous stage and produces its own. Stages cannot modify upstream artifacts — this is enforced automatically by hooks.

---

## Skills Reference

### Pipeline Skills (9)

| # | Skill | Version | Input | Output | SWEBOK |
|---|-------|---------|-------|--------|--------|
| 1 | **requirements-engineer** | v1.0.0 | User input | `requirements/REQUIREMENTS.md` | Ch01 |
| 2 | **specifications-engineer** | v1.0.0 | `requirements/` | `spec/` (6+ documents) | Ch01 |
| 3 | **spec-auditor** | v1.1.0 | `spec/` | `audits/AUDIT-BASELINE.md`, corrected `spec/` | Ch01 |
| 4 | **test-planner** | v1.0.0 | `spec/`, `audits/` | `test/TEST-PLAN.md`, matrices, perf scenarios | Ch04 |
| 5 | **plan-architect** | v1.1.0 | `spec/`, `audits/`, `test/` | `plan/` (FASEs, PLAN, ARCHITECTURE) | Ch02 |
| 6 | **task-generator** | v1.1.0 | `plan/` | `task/TASK-FASE-*.md` | Ch04 |
| 7 | **task-implementer** | v1.1.0 | `task/`, `spec/`, `plan/` | `src/`, `tests/`, commits | Ch04 |
| 8 | **security-auditor** | v1.0.0 | `spec/` | `audits/SECURITY-AUDIT-BASELINE.md` | OWASP |
| 9 | **req-change** | v2.0.0 | Change request | Updated `spec/`, `requirements/`, cascade | Ch01, Ch05 |

### Utility Skills (3)

| Skill | Version | Purpose |
|-------|---------|---------|
| **pipeline-status** | v1.0.0 | Reports pipeline state, artifact verification, staleness detection, next action |
| **traceability-check** | v1.0.0 | Verifies the full traceability chain across all artifacts, finds orphans |
| **session-summary** | v1.0.0 | Categorizes session decisions as formal vs informal, flags unformalised choices |

### Setup Skill (1)

| Skill | Version | Purpose |
|-------|---------|---------|
| **setup** | v1.0.0 | Installs automation (hooks, agents, settings) into target projects |

---

## Automation Infrastructure

SDD includes automated guardrails that enforce pipeline integrity without manual intervention.

### Hooks

| ID | Hook | Event | Purpose |
|----|------|-------|---------|
| H1 | `sdd-session-start.sh` | PreToolUse (SessionStart) | Reads `pipeline-state.json` and injects current pipeline status into the session context |
| H2 | `sdd-upstream-guard.sh` | PreToolUse (Edit/Write) | **Blocks** downstream skills from modifying upstream artifacts (Art. 4 enforcement) |
| H3 | `sdd-pipeline-state-updater.sh` | PostToolUse (Write) | Auto-updates `pipeline-state.json` when pipeline artifact directories are written to |
| H4 | Stop hook (prompt) | Stop | Verifies pipeline state consistency on session end |

### Agents

| ID | Agent | Model | Purpose |
|----|-------|-------|---------|
| A1 | **Constitution Enforcer** | haiku | Validates operations against the 11 SDD Constitution articles |
| A2 | **Cross-Auditor** | sonnet | Cross-references all skill definitions for I/O contract mismatches |
| A3 | **Context Keeper** | haiku | Maintains informal project context (preferences, deferred decisions) |

---

## How It Works in Practice

### Starting a new project

```
/sdd:setup                          # Install automation into your project
/sdd:requirements-engineer          # Elicit requirements interactively
/sdd:specifications-engineer        # Transform requirements into formal specs
/sdd:spec-auditor                   # Audit specs — produces baseline
/sdd:spec-auditor --fix             # Fix audit findings
/sdd:test-planner                   # Generate test strategy and matrices
/sdd:plan-architect                 # Generate FASE files and implementation plans
/sdd:task-generator                 # Decompose into atomic tasks
/sdd:task-implementer --fase 0      # Implement FASE 0, task by task
```

### Handling a requirements change mid-pipeline

```
/sdd:req-change --cascade=auto      # Add/modify/deprecate a requirement
                                    # Automatically propagates through:
                                    #   spec-auditor -> test-planner ->
                                    #   plan-architect -> task-generator ->
                                    #   task-implementer
```

### Checking pipeline health

```
/sdd:pipeline-status                # Which stages are done, stale, or running?
/sdd:traceability-check             # Any orphaned references or broken links?
/sdd:session-summary                # What did we decide this session?
```

---

## Project Structure

```
sdd-skills/
|
|-- sdd-requirements-engineer/      # Skill: requirements elicitation and audit
|   |-- SKILL.md                    # Skill definition (YAML front matter + process)
|   +-- references/                 # Templates, checklists, knowledge bases
|       |-- audit-checklist.md
|       |-- elicitation-guide.md
|       +-- swebok-requirements-knowledge.md
|
|-- sdd-specifications-engineer/    # Skill: requirements -> formal specifications
|-- sdd-spec-auditor/               # Skill: spec quality audit + fix mode
|-- sdd-test-planner/               # Skill: test strategy from specs
|-- sdd-plan-architect/             # Skill: FASE generation + implementation plans
|-- sdd-task-generator/             # Skill: atomic task decomposition
|-- sdd-task-implementer/           # Skill: TDD implementation from tasks
|-- sdd-security-auditor/           # Skill: OWASP/CWE security posture audit
|-- sdd-req-change/                 # Skill: change management + pipeline cascade
|-- sdd-pipeline-status/            # Skill: pipeline state reporter
|-- sdd-traceability-check/         # Skill: traceability chain verifier
|-- sdd-session-summary/            # Skill: session decisions summarizer
|-- sdd-setup/                      # Skill: automation installer
|
|-- automation/
|   |-- hooks/                      # H1, H2, H3 shell scripts
|   |-- agents/                     # A1, A2, A3 agent definitions
|   |-- settings-template.json      # Hook configuration template
|   +-- INSTALL.md                  # Manual installation guide
|
|-- references/
|   +-- sdd-constitution.md         # The 11 articles governing the pipeline
|
|-- recursos/                       # External references (not in git)
|   |-- OpenSpec/                   # Fission-AI spec framework
|   |-- spec-kit/                   # GitHub's SDD toolkit
|   +-- swebok-v4.pdf               # SWEBOK v4 document
|
+-- CLAUDE.md                       # Project instructions for Claude Code
```

Each skill follows the same pattern: a `SKILL.md` defining the full process, modes of operation, constraints, and output format, plus a `references/` directory with supporting material that gets loaded as context.

---

## Pipeline State Management

Every project using SDD tracks its pipeline progress in `pipeline-state.json`:

```json
{
  "currentStage": "spec-auditor",
  "lastUpdated": "2026-02-07T10:30:00Z",
  "stages": {
    "requirements-engineer":    { "status": "done",    "lastRun": "...", "staleReason": null },
    "specifications-engineer":  { "status": "done",    "lastRun": "...", "staleReason": null },
    "spec-auditor":             { "status": "running", "lastRun": "...", "staleReason": null },
    "test-planner":             { "status": "pending", "lastRun": null,  "staleReason": null },
    "plan-architect":           { "status": "pending", "lastRun": null,  "staleReason": null },
    "task-generator":           { "status": "pending", "lastRun": null,  "staleReason": null },
    "task-implementer":         { "status": "pending", "lastRun": null,  "staleReason": null }
  }
}
```

**State transitions:**

```
pending --> running --> done --> stale --> running --> done
                                  ^                     |
                                  +---------------------+
```

**Staleness propagation:** When stage N becomes stale, all stages N+1 through 7 are automatically marked stale. The `req-change` skill can trigger a full cascade to re-run affected stages.

---

## The SDD Constitution

The pipeline is governed by 11 articles that every skill must comply with:

| # | Article | Principle |
|---|---------|-----------|
| 1 | **Spec Is Source of Truth** | All downstream artifacts derive from specifications |
| 2 | **Never Assume, Always Ask** | Every decision point is presented to the user |
| 3 | **Traceability Is Non-Negotiable** | REQ - UC - WF - API - BDD - INV - ADR - RN, no orphans |
| 4 | **Upstream Immutability** | Downstream skills cannot modify upstream artifacts |
| 5 | **Implementation-Ready Quality** | Specs must be detailed enough for unfamiliar developers |
| 6 | **Baseline Auditing** | Subsequent audits only report new/regression findings |
| 7 | **One Task, One Atomic Commit** | Each task = one commit with Conventional Commits format |
| 8 | **Test-First Construction** | Tests are written before implementation |
| 9 | **Structured Feedback Loops** | Spec issues found downstream route through formal channels |
| 10 | **Context-Aware Operation** | Skills read existing decisions before asking questions |
| 11 | **Iterative Over Waterfall** | Deficient input stops the pipeline, not garbage-in-garbage-out |

Full text: [`references/sdd-constitution.md`](references/sdd-constitution.md)

---

## Standards Referenced

| Standard | Used By | Coverage |
|----------|---------|----------|
| **SWEBOK v4** | All skills | Ch01 (Requirements), Ch02 (Design), Ch04 (Testing), Ch05 (Maintenance) |
| **OWASP ASVS v4** | security-auditor | Security posture evaluation framework |
| **CWE** | security-auditor | Weakness enumeration for findings |
| **IEEE 830** | requirements-engineer | Requirements document format |
| **ISO 14764** | req-change | Maintenance classification (corrective/adaptive/perfective/preventive) |
| **C4 Model** | plan-architect | Architecture diagram views |
| **Gherkin/BDD** | All pipeline skills | Acceptance criteria format |

---

## Known Gaps

| Area | Status | Notes |
|------|--------|-------|
| SWEBOK Ch05 (Maintenance) | Partial | Covered by `req-change` v2.0.0 for specification-level maintenance. Operational maintenance (monitoring, incident response) is out of scope. |
| SWEBOK Ch07 (Engineering Management) | Not covered | No effort estimation, risk management, or project control metrics. |
| SWEBOK Ch10 (Software Economics) | Not covered | No cost-benefit analysis. |

---

## Contributing

This is the development repository. When modifying skills:

1. **Preserve YAML front matter** — Claude Code uses `name:` and `description:` for skill registration
2. **Keep cross-references consistent** — skills reference each other by name; changes must propagate
3. **Run the Cross-Auditor** after changes — agent A2 detects I/O contract mismatches
4. **Update the plugin** — after changes here, regenerate the [plugin repo](https://github.com/noelserdna/claude-plugin-sdd)

---

## License

MIT
