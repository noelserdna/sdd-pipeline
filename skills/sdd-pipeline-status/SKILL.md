---
name: sdd-pipeline-status
description: "Shows SDD pipeline status, artifact verification, staleness detection and next action. Use to check progress or stage, find stale artifacts after upstream changes, or pick the next skill. Triggers: 'pipeline status', 'what stage', 'next step', 'check staleness', 'pipeline progress', 'que sigue', 'estado del pipeline', 'verificar artefactos'."
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

# SDD Pipeline Status (S1)

You are the **SDD Pipeline Status** reporter. Your job is to provide a comprehensive, accurate view of the current pipeline state for the target project.

## Process

### Step 1: Read Pipeline State

Read `pipeline-state.json` from the project root. If it doesn't exist, report "No pipeline initialized" and recommend running `/sdd-setup`.

### Step 2: Verify Artifacts Exist

For each stage marked as `done`, verify the expected output artifacts actually exist:

| Stage | Expected Artifacts |
|-------|-------------------|
| requirements-engineer | `requirements/REQUIREMENTS.md` |
| specifications-engineer | `spec/` with at least: `domain-model.md`, `use-cases.md`, `workflows.md`, `contracts.md`, `nfr.md` |
| spec-auditor | `audits/AUDIT-BASELINE.md` |
| test-planner | `test/TEST-PLAN.md`, `test/TEST-MATRIX-*.md` |
| plan-architect | `plan/PLAN.md`, `plan/ARCHITECTURE.md`, `plan/fases/FASE-*.md` |
| task-generator | `task/TASK-FASE-*.md`, `task/TASK-INDEX.md` |
| task-implementer | `src/` and/or `tests/` with implementation files |

Flag any stage marked `done` whose artifacts are missing as **INCONSISTENT**.

### Step 3: Detect Staleness

Check if any `done` stage's output directory has files newer than the `lastRun` timestamp of downstream stages. If so, flag those downstream stages as **potentially stale**.

### Step 4: Check for Errors

Report any stage with `status: "error"` and include the `staleReason` if present.

### Step 5: Generate Report

Output a formatted report:

```
## SDD Pipeline Status

| # | Stage | Status | Last Run | Artifacts | Notes |
|---|-------|--------|----------|-----------|-------|
| 1 | requirements-engineer | done | 2026-01-15 | OK | — |
| 2 | specifications-engineer | done | 2026-01-16 | OK | — |
| 3 | spec-auditor | stale | 2026-01-14 | OK | Stale: specs modified after audit |
| ... | ... | ... | ... | ... | ... |

### Last Change
- Change Report: CHG-2026-01-20-001
- Changed Artifacts: requirements/, spec/
- Invalidated Stages: plan-architect, task-generator
- Cascade Mode: manual

### Handoffs (multi-session only)

| Stage | To | Sent | Result |
|-------|----|------|--------|
| spec-auditor | todo-lead | 2026-08-24T18:40:12Z | sent |

### Recommended Next Action
> Run `sdd-spec-auditor` to re-audit the updated specifications.

### Warnings
- Stage X marked done but artifacts missing
- Stage Y potentially stale (upstream modified after lastRun)
```

## Constraints

- READ-ONLY: Never modify any files.
- Report facts only; do not execute pipeline stages.
- If `pipeline-state.json` has the extended schema (with `lastChange`), include that section; otherwise skip it.
- Include the **Handoffs** section only when at least one stage has `summary.handoff` (see `references/handoff-protocol.md` at the plugin root); show `to`, `sentAt` and `result` (`sent`, `skipped:*`, `failed:*`). Also print the current session role when `SDD_ROLE` is set.
