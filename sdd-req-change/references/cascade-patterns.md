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
      "staleReason": "CHG-{id} or null"
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

### Stage Names (pipeline order)

1. `requirements-engineer`
2. `specifications-engineer`
3. `spec-auditor`
4. `test-planner`
5. `plan-architect`
6. `task-generator`
7. `task-implementer`

---

## 2. Invalidation Rules

When an artifact changes, all downstream stages that depend on it become **stale** and must be re-executed. The following table defines the invalidation boundaries.

| Changed Artifact | Invalidated Stages | Scope |
|---|---|---|
| `requirements/` | `specifications-engineer` → `spec-auditor` → `test-planner` → `plan-architect` → `task-generator` → `task-implementer` | **All downstream** — requirements are the root of the traceability chain |
| `spec/domain/` | `spec-auditor` → `test-planner` → `plan-architect` → `task-generator` → `task-implementer` | Domain model changes ripple through everything below spec |
| `spec/use-cases/` | `spec-auditor` → `test-planner` → `plan-architect` → `task-generator` → `task-implementer` | Use case changes affect audit, planning, and implementation |
| `spec/contracts/` | `spec-auditor` → `test-planner` → `plan-architect` → `task-generator` → `task-implementer` | API contract changes affect audit, planning, and implementation |
| `spec/nfr/` only | `test-planner` → `plan-architect` → `task-generator` → `task-implementer` | NFR changes may affect architecture decisions and test strategy |
| `spec/adr/` only | `plan-architect` → `task-generator` → `task-implementer` | Architecture decision changes affect planning and implementation |
| `spec/tests/` only | `test-planner` → `plan-architect` → `task-generator` → `task-implementer` | Test specification changes affect test planning and downstream |
| `plan/` | `task-generator` → `task-implementer` | Plan changes affect task breakdown and implementation |
| `task/` | `task-implementer` | Task changes only affect implementation |

### Key Rules

- Invalidation always propagates **forward** (downstream) — never backward.
- A stage marked `stale` cannot be skipped; it must be re-executed before any stage after it.
- If multiple artifacts change simultaneously, take the **union** of all invalidated stages.
- The `staleReason` field in `pipeline-state.json` records which Change Report caused the invalidation.

---

## 3. Cascade Execution Order

When a cascade is triggered, skills are invoked in the following strict order. Only stages marked `stale` are executed; `done` stages are skipped.

| Step | Skill Invocation | Condition |
|------|-----------------|-----------|
| 1 | `sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{id}.md` | If any `spec/` artifact changed |
| 2 | `sdd-test-planner` (Mode 4: Audit) | If `spec/tests/` or `spec/nfr/` changed |
| 3 | `sdd-plan-architect --regenerate-fases --affected={list}` | Always executed during cascade |
| 4 | `sdd-task-generator --fase={list} --incremental` | For each affected FASE |
| 5 | `sdd-task-implementer --fase={N} --new-tasks-only` | Only in `auto` mode |

> **Note:** `sdd-security-auditor` runs as a lateral step if any security-related requirement (`NFR-SEC-*`) was modified in the change. It executes in parallel with step 1 and does not block the main cascade.

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

5. **Generate targeted commands:**
   ```bash
   sdd-plan-architect --regenerate-fases --affected=FASE-1,FASE-5
   sdd-task-generator --fase=FASE-1,FASE-5 --incremental
   sdd-task-implementer --fase=1 --new-tasks-only
   sdd-task-implementer --fase=5 --new-tasks-only
   ```

### Dependency Resolution

- If FASE-N is affected and FASE-M depends on FASE-N, then FASE-M is **indirectly affected**.
- Indirect FASEs are re-planned but only new/changed tasks are generated (via `--incremental`).
- The `--affected` flag accepts a comma-separated list: `--affected=FASE-1,FASE-3,FASE-5`.

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
1. Read CASCADE-REPORT to understand the failure
2. Fix the underlying issue (edit spec, resolve dependency, etc.)
3. Re-run the failed skill with the same flags
4. If successful, continue the cascade from the next step
5. Use: sdd-req-change --resume --from={failed-step}
```

---

## 7. CASCADE-REPORT Format

Each cascade execution produces a report artifact at `changes/CASCADE-REPORT-{id}.md`.

```markdown
# Cascade Report — {Change Report ID}

> Triggered by: changes/CHANGE-REPORT-{id}.md
> Mode: {auto | plan-only}
> Started: {timestamp}
> Completed: {timestamp | "INCOMPLETE"}
> Status: {COMPLETE | PARTIAL (failed at step N)}

## Execution Log

| Step | Skill | Scope | Status | Duration | Notes |
|------|-------|-------|--------|----------|-------|
| 1 | sdd-spec-auditor | focused | PASS | 45s | 3 documents audited |
| 2 | sdd-plan-architect | FASE-1,5 | PASS | 120s | 2 FASEs regenerated |
| 3 | sdd-task-generator | FASE-1 | FAIL | 60s | Error: missing dependency |

## Pipeline State After Cascade

{dump of pipeline-state.json}

## Recovery Instructions (if PARTIAL)

{what to fix and how to resume}
```

### Report Conventions

- One CASCADE-REPORT per cascade execution.
- The `{id}` matches the Change Report ID that triggered the cascade.
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
