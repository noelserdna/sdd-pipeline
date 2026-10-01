---
name: sdd-import
description: "Imports external docs into SDD from Jira, OpenAPI/Swagger, Markdown, Notion, CSV or Excel: auto-detects format, maps fields to requirements and specs, previews, generates and merges artifacts. Triggers: 'import docs', 'import from Jira', 'import OpenAPI', 'convert to SDD', 'import requirements', 'import from Notion', 'import CSV', 'import Excel'."
---

# Skill: sdd-import — External Documentation → SDD Format Converter

> **Version:** 1.1.0
> **Pipeline position:** Pre-pipeline — feeds `sdd-requirements-engineer` or `sdd-specifications-engineer`
> **Recommended by:** `sdd-pipeline-status --diagnose` (Greenfield with docs, Brownfield with docs, Fork/migration)

Converts exported files (never live Jira/Notion APIs) into `requirements/` and `spec/` artifacts, previewing every mapping before writing. It does not modify the source files, generate code or tests, or keep anything in sync after the one-time import.

## 1. Supported Formats

| Format | Extensions | Maps to |
|--------|-----------|---------|
| Jira | `.json`, `.csv` | Epics → requirement groups; Stories → requirements + use cases; Bugs → import-report section "Defects" (a bug becomes a requirement only when it reveals missing behaviour); Tasks → report notes |
| OpenAPI/Swagger | `.yaml`, `.json` (3.x, 2.0) | Paths → `Style: http` contracts; schemas → domain entities/value objects; securitySchemes → security NFRs |
| Markdown | `.md` | Headings → groups/requirements; lists → requirements or workflow steps |
| Notion | `.md` export (front matter), `.csv` database export | Rows → requirements; pages → spec detail |
| CSV | `.csv` | Columns → requirement fields; rows → items |
| Excel | `.xlsx` | Sheets → artifact types; rows → items (converted to CSV first, see Phase 1) |

## 2. Invocation

```bash
/sdd-import path/to/file.yaml                      # auto-detect, both targets
/sdd-import export.csv --format=jira
/sdd-import api.yaml --target=specs
/sdd-import requirements.csv --merge
/sdd-import docs/api.yaml docs/reqs.csv docs/notion-export/
```

| Flag | Behavior |
|------|----------|
| (none) | Auto-detect format; generate requirements and specs |
| `--format=TYPE` | Skip detection (`jira`, `openapi`, `markdown`, `notion`, `csv`, `excel`) |
| `--target=requirements\|specs\|both` | Limit what is generated (default `both`) |
| `--merge` | Merge into existing SDD artifacts (duplicate review in Phase 4); without it, existing artifacts are never overwritten — the import stops and asks for `--merge` |
| `--yes` | Non-interactive: accept default mappings, skip duplicates (never replace), import skipped items as nothing; everything unresolved is listed under "Items Needing Manual Review" |

## 3. Process

### Phase 1: Format Detection

Detect by extension, confirm by content markers (rules in [references/format-parsers.md](references/format-parsers.md) §1); `--format` always wins; if still ambiguous, ask the user with the candidate formats.

`.xlsx` has no native reader. Convert each sheet to CSV first, then parse as CSV:

```bash
python3 -c "import openpyxl,csv,sys; wb=openpyxl.load_workbook(sys.argv[1],data_only=True)
for ws in wb: csv.writer(open(f'{ws.title}.csv','w',newline='')).writerows(ws.values)" file.xlsx
# or: ssconvert -S file.xlsx sheet-%s.csv
```

Write the CSVs to a scratch directory, not the project. If neither `openpyxl` nor `ssconvert` is available, ask the user to export the sheets as CSV.

### Phase 2: Parse

Parse per [references/format-parsers.md](references/format-parsers.md) into a normalized item list:

```
{ id, title, description, type, priority, status, group, attributes{}, relationships[{target,type}],
  source{file, line|row, format} }
+ metadata { format, totalItems, parseErrors[], skippedItems[{item, reason}] }
```

A malformed item is logged and skipped; it never aborts the import. Redact fields that look like secrets (API keys, tokens, passwords).

### Phase 3: Mapping Preview

Apply [references/mapping-rules.md](references/mapping-rules.md): map each item to its SDD artifact, convert to EARS (tag `[UNCONVERTED]` when conversion is not reliable), map priority, assign groups, and with `--merge` detect duplicates against existing artifacts. Show:

```
Import Preview — {files} ({format})
  → {N} requirements  → {N} use cases  → {N} contract operations  → {N} entities  → {N} NFRs
  Skipped: {N}   Parse errors: {N}   Duplicates: {N} (merge)
Sample:
  "As a user, I want to login with email"
  → REQ-F-012: WHEN a user submits valid email credentials THE system SHALL authenticate the user and start a session
  POST /api/users → API-001-01 (Style: http) in spec/contracts/API-users.md
Proceed?
```

### Phase 4: Confirmation

Ask (skipped with `--yes`, see §2): confirm the mapping; for each duplicate Skip / Merge / Replace; resolve items that fit more than one artifact type or resist EARS; whether to include skipped items.

When `requirements/` or `spec/` already exist on the default branch (importing into a delivered project), start a work branch before Phase 5: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" branch start change IMPORT-{YYYY-MM-DD} {source-slug}` (branch rule in the plugin-root `references/git-conventions.md`).

### Phase 5: Generate Artifacts

Write into the canonical tree owned by `sdd-specifications-engineer` ("Specification Folder Structure") and the requirement format owned by `sdd-requirements-engineer`. Never write flat files such as `spec/domain.md` or `spec/contracts.md`.

**Requirements** (`requirements/REQUIREMENTS.md`) — IDs `REQ-F-NNN` / `REQ-NF-NNN` / `REQ-C-NNN`, continuing after the highest existing number. The source's grouping (epic, component, tag) goes in a `Group` field, not in the ID:

```markdown
### REQ-F-012: {Title} [IMPORTED]
- **Statement:** {EARS statement}
- **Para el cliente:** {one or two plain sentences, in the customer's language, on what the user can do or count on}
- **Category:** Functional
- **Priority:** Must have | Should have | Nice to have
- **Source:** {format} {original-id} ({file}:{line|row})
- **Group:** {epic/component/tag}
- **Original text:** "{original description}"
- **Acceptance criteria:** {imported criteria as GIVEN/WHEN/THEN, or "None imported"}
```

The `Para el cliente:` line (`sdd-requirements-engineer` `references/requirements-template.md`) is what the status page shows on the requirement's card. Take it from the source's own plain description when it has one; otherwise draft it. Either way it is pending the customer's review: it gets no `Examples reviewed by` until the customer reads it with the examples at approval (approval §3), and the import report lists the drafted ones as to be reviewed with the customer.

**Specs** (`spec/`):

| Imported content | Target |
|------------------|--------|
| Entities / DTOs (OpenAPI schemas, entity tables) | `spec/domain/02-ENTITIES.md`, `spec/domain/03-VALUE-OBJECTS.md` |
| Glossary terms | `spec/domain/01-GLOSSARY.md` |
| Business rules | `spec/domain/05-INVARIANTS.md` (`INV-{AREA}-NNN`) |
| Stories / feature descriptions | `spec/use-cases/UC-NNN-{slug}.md` |
| Acceptance criteria | `spec/tests/BDD-UC-NNN.md` |
| Ordered processes | `spec/workflows/WF-NNN-{slug}.md` |
| OpenAPI paths | `spec/contracts/API-{module}.md` (one per tag/module) |
| Security schemes, servers, performance items | `spec/nfr/SECURITY.md`, `spec/nfr/PERFORMANCE.md`, `spec/nfr/LIMITS.md` |
| Decision records | `spec/adr/ADR-NNN-{slug}.md` (next free number) |

Imported OpenAPI contracts are written as `Style: http` (specifications-engineer Template 12), header row `Style | http — imported from {file}; the published HTTP interface is an existing commitment`. The reason: an OpenAPI document describes an HTTP interface that clients already depend on, so the paths, methods and status codes are requirements, not design choices; recording them as `Style: operations` would drop that information or push it into a design document that does not exist yet. Operation IDs follow the specifications-engineer scheme `API-NNN-NN`.

After writing, create or update `spec/COVERAGE.md` listing each imported module and its status (`IMPORTED`, or `SPECIFIED` only for modules whose UC, contract, domain and BDD files all exist).

**Merge (`--merge`)**: new items are appended with `[IMPORTED]`; merged duplicates are marked `[MERGED]`; replaced ones `[IMPORTED-REPLACED]`; skipped ones are left untouched. The `[IMPORTED]` marker is the seed contract with `sdd-reverse-engineer`: it may enrich or merge those entries instead of treating the project as already-specified.

### Phase 6: Quality Check

Check: every item has an SDD ID; requirements are EARS or `[UNCONVERTED]`; use cases have actor, pre- and postconditions; contract operations have request/response shapes; no duplicate IDs; REQ → UC → API references resolve; priorities are not all `Must have`. Report items imported, EARS conversion rate, traceability readiness and the manual-review count.

### Phase 7: Pipeline State and Report

1. If `pipeline-state.json` is missing, create it from the plugin template as `sdd-setup` Step 1 does (`$SDD_PLUGIN_ROOT/templates/pipeline-state.template.json`), then apply step 2.
2. Stage updates:
   - `requirements-engineer` → `done` when requirements were imported.
   - `specifications-engineer` → `done` only when the full canonical tree for the imported scope exists (domain 01–05, UC, contracts, BDD, NFR) and `spec/COVERAGE.md` shows every module `SPECIFIED`. Otherwise leave it `pending` with `staleReason: "partial import — run sdd-specifications-engineer to complete spec/"` (an OpenAPI-only import is partial).
   - Downstream stages stay `pending`; nothing runs automatically. Next step is `sdd-specifications-engineer` (partial) or `sdd-spec-auditor` (complete).
3. Write `import/IMPORT-REPORT.md` from [references/import-report-template.md](references/import-report-template.md), including the Defects section for Jira bugs and the Items Needing Manual Review section.
4. Commit what the import wrote: `git add requirements/ spec/ import/` (the paths that exist), then `docs(specs): import from {source}` with `Refs:` the imported REQ ids (`docs(requirements)` when only requirements were imported), skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed).

## 4. Pipeline Integration

| Reads | Writes |
|-------|--------|
| Input files; `requirements/REQUIREMENTS.md`, `spec/`, `pipeline-state.json` (when present) | `requirements/REQUIREMENTS.md`, `spec/` (canonical tree), `spec/COVERAGE.md`, `import/IMPORT-REPORT.md`, `pipeline-state.json` |

| Skill | Relationship |
|-------|-------------|
| `sdd-pipeline-status --diagnose` | Recommends import when external docs exist |
| `sdd-reverse-engineer` | May run after import; merges into `[IMPORTED]` entries |
| `sdd-reconcile` | Verifies spec ↔ code alignment after import + reverse-engineer |
| `sdd-specifications-engineer` | Completes a partial import |
| `sdd-spec-auditor` | Audits the imported specs |

Every imported item keeps its source reference (file, line/row, original ID). Output language follows the user's language; technical terms stay in English.
