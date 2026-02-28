# Traceability ID Patterns

Reference patterns for the SDD traceability chain. Used by `sdd-traceability-check` to scan artifacts.

## ID Definition Patterns

These patterns identify where an ID is **defined** (first occurrence as a heading or definition).

| Type | Regex (Definition) | Typical File |
|------|-------------------|--------------|
| REQ | `^#+\s*REQ-(\d{3})` or `\|\s*REQ-(\d{3})\s*\|` | `requirements/REQUIREMENTS.md` |
| UC | `^#+\s*UC-(\d{3})` or `##\s+UC-(\d{3})` | `spec/use-cases.md` |
| WF | `^#+\s*WF-(\d{3})` or `##\s+WF-(\d{3})` | `spec/workflows.md` |
| API | `^#+\s*API-(\d{3})` or `##\s+API-(\d{3})` | `spec/contracts.md` |
| BDD | `^#+\s*BDD-(\d{3})` or `Scenario:\s*BDD-(\d{3})` | `spec/use-cases.md`, `test/` |
| INV | `^#+\s*INV-(\d{3})` or `\|\s*INV-(\d{3})\s*\|` | `spec/domain-model.md`, `spec/invariants.md` |
| ADR | `^#+\s*ADR-(\d{3})` or filename `ADR-(\d{3})` | `spec/adr/ADR-*.md` |
| NFR | `^#+\s*NFR-(\d{3})` or `\|\s*NFR-(\d{3})\s*\|` | `spec/nfr.md` |
| RN | `^#+\s*RN-(\d{3})` or `\|\s*RN-(\d{3})\s*\|` | `spec/release-notes.md` |
| TASK | `^#+\s*TASK-F(\d{1,2})-(\d{3,4})` or `\|\s*TASK-F(\d{1,2})-(\d{3,4})\s*\|` or `- \[.\]\s*.*TASK-F(\d{1,2})-(\d{3,4})` | `task/TASK-FASE-{N}.md` |

## ID Reference Pattern (Universal)

To find **references** to any ID type across all files:

```regex
(REQ|UC|WF|API|BDD|INV|ADR|NFR|RN)-\d{3}
```

For TASK IDs (compound format):
```regex
TASK-F\d{1,2}-\d{3,4}
```

These patterns match all ID types. After matching, group by type and cross-reference against definitions.

## Traceability Direction

The expected traceability direction flows downstream:

```
REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST
         ↘          ↗
          NFR ------
```

- **REQ** should be referenced by at least one **UC**
- **UC** should reference at least one **WF** or **API**
- **WF** should reference **API** endpoints it orchestrates
- **API** should have at least one **BDD** scenario
- **INV** should be referenced by **BDD** or **API** that enforces them
- **ADR** should be referenced by the artifacts they affect
- **NFR** should trace to **UC** or **API** that implement them
- **TASK** should decompose a **FASE** and reference upstream specs via `Refs:` field
- **COMMIT** should link to **TASK** via `Task:` trailer and to specs via `Refs:` trailer
- **CODE** should reference **UC/INV/API** via `Refs:` comments in source files
- **TEST** should reference **UC/INV/BDD** via test descriptions or `Refs:` comments

## Commit Reference Patterns

Commits link to the traceability chain via trailers in their commit messages.

### Task Trailer

```regex
^Task:\s*(TASK-F\d{1,2}-\d{3,4})\s*$
```

Found in the commit message body (after the blank line separator). Links COMMIT → TASK.

### Refs Trailer

```regex
^Refs:\s*(.+)$
```

The value is a comma-separated list of artifact IDs (e.g., `Refs: FASE-0, UC-002, ADR-003, INV-SYS-001`). Links COMMIT → upstream spec artifacts.

### Extracting from Git Log

```bash
# Commits with Refs: trailers
git log --all --format='%H|%h|%s|%an|%aI|%b' --grep='Refs:'

# Commits with Task: trailers
git log --all --format='%H|%h|%s|%an|%aI|%b' --grep='Task:'
```

Parse the `%b` (body) field to extract `Refs:` and `Task:` lines. The body may contain multiple trailers; extract each one.

### Graceful Degradation

If `git rev-parse --is-inside-work-tree` fails (not a git repository), skip all commit-related checks and note "Git not available" in the report.

## Edge Cases

- IDs may use 3+ digits (e.g., `REQ-001` through `REQ-999`)
- Some projects use extended IDs like `REQ-F001` (functional) or `REQ-N001` (non-functional) — the checker should be flexible
- References may appear in markdown tables, inline text, or YAML front matter
- BDD scenarios may be defined in `.feature` files under `test/`
- TASK IDs use a compound format `TASK-F{N}-{SEQ}` where N is the FASE number (1-2 digits) and SEQ is the sequence (3-4 digits)
- Commits may have both `Refs:` and `Task:` trailers, or only one of them
- A single TASK may have multiple commits (rework, amendments) — use the latest by date
