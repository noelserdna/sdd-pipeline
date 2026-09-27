# Reconciliation Strategies

> Used by Phases 5 and 7 of `sdd-reconcile`. Every spec amendment is first written as a CR entry in `changes/CR-RECONCILE-{YYYY-MM-DD}.md` using `sdd-req-change/references/change-request-template.md`, then applied to the canonical spec tree (`sdd-specifications-engineer` § "Specification Folder Structure"). Reconcile writes only `requirements/`, `spec/`, `changes/` and `reconciliation/`.

## 1. CR entry (all amendments)

Use the req-change template fields (Type, Category, Priority, Affected REQs, Description, Motivation, Draft EARS Statement) and add a reconcile evidence block in Motivation:

```markdown
## CR-{NNN}: {title}
...(req-change template fields)...
### Motivation
Reconciliation {date} — DIV-{NNN} ({type}, confidence {level}).
- Code: `{file}:{lines}` — Tests: `{test_file}` {pass | fail | missing | not run}
- Decision: {auto | user option A | --code-wins}
```

## 2. NEW_FUNCTIONALITY and option A → CR ADD / MODIFY

| Content | Target |
|---|---|
| Requirement | `requirements/REQUIREMENTS.md`, next free `REQ-F-NNN` or `REQ-NF-NNN`, EARS, tagged `[RECONCILED]` (ADD) or `[UPDATED]` with the previous statement kept (MODIFY) |
| Use case | `spec/use-cases/UC-NNN-{slug}.md` (actor from auth/entry point, preconditions from guards, flow from handler logic, alternatives from error paths) |
| Acceptance | `spec/tests/BDD-UC-NNN.md` |
| Operation | `spec/contracts/API-{module}.md`, following the module's `Style` (operations: behaviour, inputs, outputs, errors; http: plus method, path, status codes) |
| Entity / rule | `spec/domain/02-ENTITIES.md`, `spec/domain/05-INVARIANTS.md` (`INV-{AREA}-NNN`) |
| NFR | `spec/nfr/{PERFORMANCE,LIMITS,SECURITY,OBSERVABILITY}.md` |
| Trace | new row in `spec/TRACEABILITY-MATRIX.md` |

Each item carries `Reconciled: {date}, CR-{NNN}`.

## 3. REMOVED_FEATURE → CR DEPRECATE

Mark the REQ `[DEPRECATED]` with date, reason ("implementation removed in `{SHA}`") and downstream impact; keep the text. Also deprecate UCs, WF steps, operations and BDD scenarios that serve only that REQ; shared artifacts stay. Never delete. `NOT_IMPLEMENTED` items never take this path.

## 4. Option B (defect) and NOT_IMPLEMENTED → report only

No spec change. Record in the report:

```markdown
### DEFECT-{NNN}: {title}            (or GAP-{NNN} for NOT_IMPLEMENTED)
- Requirement: REQ-{…} — Expected: {EARS} — Actual: {behaviour | not implemented}
- Location: `{file}:{lines}` — Tests: {fail | missing}
- Next: /sdd-task-generator --fase={N} --incremental
```

## 5. Option C → sdd-req-change

Leave the CR in `changes/` without applying it and recommend `/sdd-req-change --file changes/CR-RECONCILE-{date}.md`.

## 6. Option D → deferred

List in the report's Deferred table with the reason.

## 7. REFACTORING → technical references in specs

Update code paths, symbol names and (for `Style: http`) paths that appear inside spec documents; keep requirement and UC text unchanged. References in `plan/`, `task/` and `test/` are listed in the report ("Artifacts to regenerate") for `sdd-plan-architect`, `sdd-task-generator` and `sdd-test-planner`; reconcile does not edit them.

## 8. Cascade

Canonical rules (CLAUDE.md, `sdd-req-change/references/cascade-patterns.md`): `requirements/` changed → re-run from `specifications-engineer`; `spec/` changed → re-run from `spec-auditor`. Any write to `spec/`, including a REFACTORING path update, therefore makes `spec-auditor` and later stages stale.

## 9. Markers

| Marker | Meaning |
|---|---|
| `[RECONCILED]` | Added from code (CR ADD) |
| `[UPDATED]` | Changed to match code (CR MODIFY) |
| `[DEPRECATED]` | Implementation removed (CR DEPRECATE) |
| `[REFACTORED]` | Technical reference updated |
