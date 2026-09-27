# Pipeline Cascade Patterns Reference

> **Quick reference for pipeline invalidation rules, cascade execution, and pipeline-state.json management.**

---

## 1. pipeline-state.json Schema

The `pipeline-state.json` file tracks the current state of the entire SDD pipeline. It is the single source of truth for which stages are up-to-date and which need re-execution.

```json
{
  "currentStage": "string — last completed stage name",
  "lastUpdated": "ISO 8601 timestamp",
  "stages": {
    "{stage-name}": {
      "status": "done | stale | running | error",
      "outputHash": "sha256:{hash} — hash of output directory/files",
      "lastRun": "ISO 8601 timestamp",
      "staleReason": "CHG-YYYY-MM-DD-NNN or null"
    }
  },
  "lastChange": {
    "changeReportId": "CHG-YYYY-MM-DD-NNN",
    "changedArtifacts": ["requirements/", "spec/"],
    "invalidatedStages": ["plan-architect", "task-generator", "task-implementer"],
    "cascadeMode": "auto | manual | dry-run | plan-only"
  }
}
```

### Stage Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | enum | Yes | `"done"`, `"stale"`, `"running"`, `"error"` |
| `outputHash` | string | No | `sha256:{hash}` of output directory/files |
| `lastRun` | string | No | ISO 8601 timestamp |
| `staleReason` | string | No | `CHG-YYYY-MM-DD-NNN` or null |
| `summary` | object | No | Stage completion summary (see Section 9) |

### Stage Names (pipeline order)

1. `requirements-engineer`
2. `specifications-engineer`
3. `spec-auditor`
4. `test-planner`
5. `plan-architect`
6. `task-generator`
7. `task-implementer`

### Lateral Stages (optional keys in `stages`)

- `security-auditor` — populated by `/sdd-security-auditor`
- `req-change` — populated by `/sdd-req-change`
- `tech-designer` — populated by `/sdd-tech-designer`
- `ux-designer` — populated by `/sdd-ux-designer`
- `acceptance` — populated by `/sdd-acceptance`. Never marked stale by a cascade: `sdd accept` recomputes freshness itself (evidence against `evaluated_sha`, human decisions against the requirement's text hash), so a MODIFY reopens the affected requirement on the next `/sdd-acceptance --check`

---

## 2. Invalidation Rules

When an artifact changes, every downstream stage that depends on it becomes **stale**. Boundaries (same as CLAUDE.md "Re-run guidance"):

| Changed Artifact | Invalidated Stages |
|---|---|
| `requirements/` (not yet propagated to specs) | `specifications-engineer` → `spec-auditor` → `test-planner` → `plan-architect` → `task-generator` → `task-implementer` |
| `spec/` (any file) | `spec-auditor` → `test-planner` → `plan-architect` → `task-generator` → `task-implementer`; laterals `tech-designer` and `ux-designer` when their outputs exist |
| security requirement or `spec/nfr/SECURITY.md` | additionally `security-auditor` (lateral) |
| `plan/` | `task-generator` → `task-implementer` |
| `task/` | `task-implementer` |

`sdd-req-change` edits `requirements/` and propagates the change into `spec/` in the same run, so its changes count as `spec/` changes: `specifications-engineer` stays `done` (Persist restores it if the H3 hook flipped it) and staleness starts at `spec-auditor`.

### Key Rules

- Invalidation always propagates **forward** (downstream) — never backward.
- A `stale` stage is re-executed before any stage after it.
- Several artifacts changed at once → the **union** of invalidated stages.
- Affected FASEs (Section 5) narrow which FASEs are regenerated, never which stages are stale.
- `staleReason` records the Change Report ID (`CHG-YYYY-MM-DD-NNN`) that caused the invalidation.
- Only `sdd-req-change` Phase 9 writes these stale marks for a change; `--cascade=dry-run` writes nothing.

---

## 3. Cascade Execution Order

Skills run in this order; only `stale` stages run.

| Step | Skill Invocation | Condition |
|------|-----------------|-----------|
| 1 | `sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{CHG-ID}.md` | Always (spec/ changed) |
| 2 | `sdd-test-planner`, Mode 4 (Audit Test Coverage) over the changed UCs/NFRs | Always |
| 3 | `sdd-plan-architect --regenerate-fases --affected={N,M}` | Always |
| 4 | `sdd-task-generator --fase={N} --incremental` | Once per affected FASE |
| 5 | `sdd-task-implementer --fase {N} --new-tasks-only` | Once per affected FASE; `auto` mode only |

> `sdd-security-auditor` runs alongside step 1 when a security requirement changed; it does not block the main cascade.

---

## 4. Cascade Modes Reference

The `cascadeMode` field controls how far the cascade executes and whether it modifies state.

### `auto` — Full Automatic Cascade

- Updates `pipeline-state.json` at each step.
- Invokes all needed downstream skills **sequentially**.
- Generates a `CASCADE-REPORT` at the end.
- **STOPS on first skill failure** — does not continue past errors.
- Best for: CI/CD pipelines, well-tested change sets.

### `manual` (default) — Guided Manual Cascade

- Computes the full invalidation scope.
- Updates `pipeline-state.json` (marks stages as `stale`).
- **Prints recommended commands** with exact flags and arguments.
- User invokes each skill manually in the prescribed order.
- Best for: exploratory changes, first-time users, complex changes requiring human judgment.

### `dry-run` — Read-Only Analysis

- Computes invalidation scope only.
- Does **NOT** update `pipeline-state.json`.
- Prints the full cascade plan with estimated scope (number of files, FASEs affected).
- Best for: impact assessment before committing to a change.

### `plan-only` — Cascade Through Planning Skills Only

- Cascades through: `spec-auditor` → `test-planner` → `plan-architect` → `task-generator`.
- Does **NOT** invoke `task-implementer`.
- Updates `pipeline-state.json` for planning stages; `task-implementer` remains `stale`.
- Best for: validating that a change is well-specified before committing to implementation.

---

## 5. FASE-Aware Selective Cascade

Not all changes affect all FASEs. The cascade system supports **selective FASE targeting** to minimize unnecessary re-execution.

### How to Determine Affected FASEs

1. **Parse Change Report Section 7.1** — Extract the list of affected FASE files from the change report's impact analysis.

2. **Map changed REQs to FASEs via traceability chain:**
   - REQ → UC → WF → API → Task → FASE
   - Follow the `Refs:` trailers in task definitions to trace back to requirements.

3. **Identify direct impact** — FASEs containing tasks that directly implement changed requirements or use changed contracts/APIs.

4. **Identify indirect impact** — FASEs that have **dependencies** on directly affected FASEs (e.g., FASE-3 depends on services built in FASE-2).

5. **Generate targeted commands** (the task generator and implementer take one FASE per run):
   ```bash
   /sdd-plan-architect --regenerate-fases --affected=1,5
   /sdd-task-generator --fase=1 --incremental
   /sdd-task-generator --fase=5 --incremental
   /sdd-task-implementer --fase 1 --new-tasks-only
   /sdd-task-implementer --fase 5 --new-tasks-only
   ```

### Dependency Resolution

- If FASE-N is affected and FASE-M depends on FASE-N, then FASE-M is **indirectly affected**.
- Indirect FASEs are re-planned but only new/changed tasks are generated (via `--incremental`).
- `--affected` (plan-architect) takes a comma-separated list of FASE numbers: `--affected=1,3,5`.

---

## 6. Failure Handling

When a cascade step fails, the system follows a strict recovery protocol.

### Failure Protocol

1. **STOP immediately** — do not proceed to the next step in the cascade.
2. **Update `pipeline-state.json`:**
   - Failed stage → `status: "error"`
   - All subsequent stages → remain `status: "stale"`
   - `currentStage` remains at the last **successfully completed** stage.
3. **Record failure in CASCADE-REPORT** with full error details (see Section 7).
4. **Print recovery instructions:**
   - Identify what went wrong (missing dependency, validation error, etc.).
   - Provide the exact command to resume from the failed step.
5. **Never retry automatically** — human intervention is always required before resuming.

### Recovery Flow

```
1. Read the CASCADE-REPORT to understand the failure
2. Fix the underlying issue (edit spec via sdd-req-change, resolve dependency, etc.)
3. Re-run the failed skill with the same flags
4. Run the remaining commands of the report's plan, in order
```

---

## 7. CASCADE-REPORT Format

Each `auto` or `plan-only` cascade produces `changes/CASCADE-REPORT-{CHG-ID}.md`.

```markdown
# Cascade Report — {CHG-ID}

> Triggered by: changes/CHANGE-REPORT-{CHG-ID}.md
> Mode: {auto | plan-only}
> Started: {timestamp}
> Completed: {timestamp | "INCOMPLETE"}
> Status: {COMPLETE | PARTIAL (failed at step N)}

## Execution Log

| Step | Skill | Scope | Status | Duration | Notes |
|------|-------|-------|--------|----------|-------|
| 1 | sdd-spec-auditor | focused | PASS | 45s | 3 documents audited |
| 2 | sdd-test-planner (Mode 4) | UC-004, UC-007 | PASS | 40s | 1 coverage gap |
| 3 | sdd-plan-architect | FASE-1,5 | PASS | 120s | 2 FASEs regenerated |
| 4 | sdd-task-generator | FASE-1 | FAIL | 60s | Error: missing dependency |

## Pipeline State After Cascade

{dump of pipeline-state.json}

## Recovery Instructions (if PARTIAL)

{what to fix and how to resume}
```

### Report Conventions

- One CASCADE-REPORT per cascade execution.
- `{CHG-ID}` is the ID of the Change Report that triggered the cascade.
- If the same change triggers multiple cascades (e.g., after a fix), append a suffix: `CASCADE-REPORT-CHG-2025-01-15-001-r2.md`.
- `COMPLETE` status means all planned steps finished successfully.
- `PARTIAL` status includes the step number where failure occurred.

---

## 8. Hash Computation

The `outputHash` field in `pipeline-state.json` enables the system to detect whether a stage's outputs have changed without re-running the stage.

### For Directories

1. List all files in the directory recursively.
2. Sort file paths alphabetically.
3. Concatenate all file contents in sorted order.
4. Compute SHA-256 of the concatenated content.
5. Store as `sha256:{hex-digest}`.

### For Single Files

1. Read the file content.
2. Compute SHA-256 of the content.
3. Store as `sha256:{hex-digest}`.

### Using Git (preferred)

When git is available, leverage it for efficient hashing:

```bash
# Hash a single file
git hash-object path/to/file

# Detect changes in a directory
git diff --stat HEAD -- path/to/directory/
```

### Fallback Without Git

If git is not available, use file modification timestamps as a proxy:

- Record the latest `mtime` across all files in the output directory.
- Compare against the stored timestamp from the last run.
- This is less reliable than content hashing but sufficient for detecting changes.

> **Important:** Hash comparison is used to **skip** stages whose inputs have not changed. If the hash matches the stored value, the stage is still `done`. If it differs, the stage must be marked `stale`.

---

## 9. Stage Summaries

Each skill persists a structured summary in `pipeline-state.json` upon completion. This enables the dashboard to display rich stage information without re-scanning artifacts.

**Changing a stage status.** Prefer the locked helper over a hand-written read-modify-write, which can clobber the hooks' async writes: `bash "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-state.sh" set <stage> <pending|running|done|stale|error>` (`get <stage>` reads it). It creates the stage key if missing, keeps `summary` and the other fields, sets `lastRun` on running/done and `currentStage` on running, clears `staleReason` except on stale, and never creates `pipeline-state.json` (exit 1 without it: create it from the template first). Write `summary` and `staleReason` with a separate jq patch.

### Summary Sub-Schema

```json
"summary": {
  "artifacts": [
    { "file": "test/TEST-PLAN.md", "label": "Test Strategy" }
  ],
  "metrics": {
    "bdd_scenarios": 101,
    "invariants_mapped": 46
  },
  "highlights": ["0% coverage -> Plan for 100%"],
  "nextStep": "Run /sdd-plan-architect",
  "generatedAt": "2026-03-04T15:30:00Z",
  "handoff": { "to": "miseia-lead", "sentAt": "2026-03-04T15:30:41Z", "result": "sent" }
}
```

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `artifacts` | array of `{file, label}` | Max 15 items | Files created/modified by the stage |
| `metrics` | object (key→number, short string or small array/object) | Flat, skill-specific keys | Quantitative metrics (see table below) |
| `highlights` | array of strings | Max 5 items | Notable observations or decisions |
| `nextStep` | string | — | Recommended next action |
| `generatedAt` | string (ISO-8601) | — | When this summary was generated |
| `handoff` | object `{to, sentAt, result}` | Optional; station mode only | Written by the handoff protocol (plugin-root `references/handoff-protocol.md`) after the summary. `to`: lead session name or `null`; `sentAt`: ISO-8601; `result`: `sent`, `skipped:no-tools`, `skipped:lead-absent`, `skipped:self`, `failed:<reason>` |

### Per-Skill Metric Keys

| Skill | Metric Keys |
|-------|-------------|
| `requirements-engineer` | `total_requirements`, `functional`, `nonfunctional`, `constraints` |
| `specifications-engineer` | `use_cases`, `workflows`, `api_contracts`, `bdd_scenarios`, `invariants`, `adrs`, `spec_chars`, `spec_budget_chars`, `mode`, `spec_agents` |
| `spec-auditor` | `total_findings`, `critical`, `high`, `medium`, `low`, `batched_findings`, `gate_result`, `audit_cycle`, `topFindingCategories`, `report_chars`, `mode` |
| `test-planner` | `bdd_scenarios`, `test_matrices`, `matrix_cases`, `perf_scenarios`, `e2e_scenarios`, `e2e_fields_total`, `e2e_fields_complete`, `e2e_field_coverage_pct`, `invariants_mapped`, `test_gaps`, `test_chars`, `mode`, `matrix_agents` |
| `plan-architect` | `total_fases`, `components`, `adrs_created`, `clarify_questions`, `research_items`, `plan_chars`, `plan_budget_chars`, `operation_mapping` (`existing` \| `written` \| `appended` \| `n/a`) |
| `task-generator` | `total_tasks`, `parallelizable_pct`, `safe_revert`, `coupled_revert`, `migration_revert`, `config_revert`, `streamsPerFase`, `mode`, `task_agents`, `format` |
| `task-implementer` | `tasks_completed`, `tasks_remaining`, `commits`, `tests_passed`, `tests_failed`, `mode`, `task_agents`, `pauses`, `stack`, `profile_source`, `inline_p_tasks`; `--integrate` adds `streamsIntegrated`, `mergeConflicts` |
| `security-auditor` | `total_findings`, `critical`, `high`, `medium`, `low`, `global_score`, `grade`, `owasp_coverage` |
| `req-change` | `change_requests`, `applied`, `skipped`, `documents_modified`, `invalidated_stages` |
| `tech-designer` | `dimensions_analyzed`, `quality_attributes`, `adr_drafts`, `trade_offs_evaluated` |
| `ux-designer` | `dimensions_analyzed`, `wireframes`, `components_specified`, `wcag_level`, `design_tokens`, `frontend_security_items` |
| `acceptance` | `must_total`, `must_verified`, `must_waived`, `failing`, `missing`, `stale_evidence`, `goal` (`met` \| `met-with-waivers` \| `not-met`), `gate_exit`, `loop_cycles`, `loop_stop`, `test_edits`, `evaluated_sha`, `mode` |
| `gap-detector` | `total_spec_endpoints`, `implemented`, `missing`, `orphan_routes`, `mismatches`, `endpoint_coverage_pct`, `bdd_coverage_pct`; with `--semantic` also `semantic_targets`, `semantic_covered`, `semantic_partial`, `semantic_likely_missing`, `semantic_judge` (`jev` \| `llm`) |

Each skill's own Persist section is authoritative; this table mirrors them.

### Summary Lifecycle Rules

1. **Optional**: `summary` is `null` or absent when the stage has never completed.
2. **Preserved on stale**: When a stage transitions to `stale`, its `summary` is retained (rendered dimmed in the dashboard).
3. **Overwritten on re-run**: When a stage completes again, `summary` is fully replaced with the new data.
4. **Lateral skills**: `security-auditor`, `req-change`, `tech-designer`, `ux-designer`, `gap-detector` and `acceptance` store summaries under their own keys in `stages` (not part of the 7-stage linear chain).
5. **Hook-safe**: The H3 state-updater hook does NOT modify `summary` — it is exclusively managed by skills.
6. **Handoff patch**: `summary.handoff` is absent in single-session mode. In station mode it is added with a minimal patch (jq under lock, tmp → mv) after Persist Summary and after the skill's local gate question; it is never a full rewrite of the file, and it is replaced together with `summary` on re-run. Readers (H1, `sdd-pipeline-status`, `sdd-lead`, dashboard) must tolerate its absence.
