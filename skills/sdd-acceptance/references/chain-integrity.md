# Chain integrity (`--check` Step 3)

Checks that the IDs the evidence hangs on exist and connect: REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT.
Read-only; findings are fixed at their source by the owner of the artifact (a spec typo through `sdd-spec-auditor`
Mode Fix or `sdd-req-change`, a missing scenario through `sdd-test-planner`). They never change a verdict.

## 1. Specification side: the traceability graph

```bash
command -v python3 >/dev/null && python3 "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-graph.py"
```

It scans `requirements/`, `spec/`, `test/`, `plan/`, `task/`, code, tests and git, expands ID ranges, and writes
`dashboard/traceability-graph.json`. Read from `statistics`:

| Field | Report as |
|---|---|
| `brokenReferences[]` (`{id, source, file, line}`-like entries, capped at 50) | **Broken references**: an ID cited but never defined (e.g. `UC-099` in a workflow). Highest priority: evidence may be bound to something that does not exist |
| `orphans[]` (IDs, capped at 50) | **Orphan definitions**: defined but never referenced. Usually a missing cross-reference; an orphan REQ is a requirement nothing implements |
| `traceabilityCoverage.reqsWithUCs`, `reqsWithBDD`, `reqsWithTasks`, `reqsWithCommits` (`count`/`total`) | One line: how many requirements reach a use case, a scenario, a task, a commit. A requirement with no scenario can only be accepted by demo, measurement or inspection |

Show at most 10 rows per table with `file:line` when the entry has it, and the total. Without python3, or when the
script fails, say "traceability graph not available" and use §3 on the requirements only.

## 2. Git side: tasks and commits

```bash
$SDD tasks status --json          # done = a Task: trailer in a non-reverted commit; lists divergences
$SDD trace commits --json         # commits with their Task / Refs / Change ids (reverts marked)
```

Report:

- **Tasks done without a commit** — divergences where the checkbox says done but no `Task:` trailer exists (with
  `task_state: trailers` the trailer is the state, so only the divergences listed count).
- **Commits whose `Refs:` cite undefined IDs** — every id in a commit's `Refs` that is neither defined in the graph
  (`artifacts`) nor a structural id (`FASE-N`, `CHG-…`, `CR-N`).
- **Commits touching code without `Task:`** — `$SDD verify --range <base>..HEAD --json`, entries with `code: true`
  and no `Task` (a squash merge shows up this way).

## 3. Fallback: ID patterns

When the graph is unavailable, collect definitions and references with these patterns (range notation such as
`UC-001..005` or `TASK-F1-003..008` expands to each id, keeping the zero padding; an end below the start is itself a
broken reference).

| Type | Defined in | Pattern |
|---|---|---|
| REQ | `requirements/REQUIREMENTS.md` headings | `REQ-(F\|NF\|C)-\d{3,4}` (also grouped forms like `REQ-AUTH-003` in existing projects) |
| UC | `spec/use-cases/UC-NNN-*.md` | `UC-\d{3,4}` |
| WF | `spec/workflows/WF-NNN-*.md` | `WF-\d{3,4}` |
| API | `spec/contracts/API-*.md` (operation table rows) | `API-\d{3,4}-\d{2}` or `API-[A-Za-z][A-Za-z0-9-]+` |
| Scenario | `spec/tests/BDD-UC-NNN.md` | `AC-\d{3}-\d{2}` in `Scenario:` lines |
| INV | `spec/domain/05-INVARIANTS.md` | `INV-(?:[A-Z]{2,6}-)?\d{3,4}` |
| ADR | `spec/adr/ADR-NNN-*.md` | `ADR-\d{3,4}` |
| RN | `spec/CLARIFICATIONS.md`, `spec/domain/*.md` | `RN-\d{3,4}` |
| TASK | `task/TASK-FASE-N.md` task lines | `TASK-F\d+-\d{3,4}` |

A definition is the heading, table row or file name that introduces the id; every other occurrence is a reference.
