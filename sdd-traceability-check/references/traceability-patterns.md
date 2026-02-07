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

## ID Reference Pattern (Universal)

To find **references** to any ID type across all files:

```regex
(REQ|UC|WF|API|BDD|INV|ADR|NFR|RN)-\d{3}
```

This single pattern matches all ID types. After matching, group by type and cross-reference against definitions.

## Traceability Direction

The expected traceability direction flows downstream:

```
REQ → UC → WF → API → BDD → INV → ADR
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

## Edge Cases

- IDs may use 3+ digits (e.g., `REQ-001` through `REQ-999`)
- Some projects use extended IDs like `REQ-F001` (functional) or `REQ-N001` (non-functional) — the checker should be flexible
- References may appear in markdown tables, inline text, or YAML front matter
- BDD scenarios may be defined in `.feature` files under `test/`
