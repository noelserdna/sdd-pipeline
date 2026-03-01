---
name: sdd-import
description: "Imports external documentation into SDD format. Supports 6 source formats: Jira (JSON/CSV exports), OpenAPI/Swagger (YAML/JSON), Markdown/README, Notion (exported markdown/CSV), CSV, and Excel (.xlsx). Auto-detects format, parses input, maps fields to SDD requirements and specifications, shows a preview for user confirmation, generates SDD artifacts, and performs quality checks. Handles merge with existing artifacts. Triggers on phrases like 'import docs', 'import from Jira', 'import OpenAPI', 'convert to SDD', 'import requirements', 'import from Notion', 'import CSV', 'import Excel'."
version: "1.0.0"
---

# Skill: sdd-import — External Documentation → SDD Format Converter

> **Version:** 1.0.0
> **Pipeline position:** Pre-pipeline — feeds into `sdd-requirements-engineer` or `sdd-specifications-engineer`
> **Invoked by:** `sdd-onboarding` (scenarios 5, 8)
> **SWEBOK v4 alignment:** Chapter 01 (Requirements), Chapter 09 (Models & Methods)

---

## 1. Purpose & Scope

### What This Skill Does

- **Detects** the format of input documentation automatically (or accepts explicit format specification)
- **Parses** external documentation into a normalized intermediate representation
- **Maps** external fields to SDD artifact fields using format-specific rules
- **Previews** the mapping for user confirmation before generating artifacts
- **Generates** SDD-format requirements and/or specifications from the imported data
- **Checks** quality of the generated artifacts (completeness, consistency, traceability potential)
- **Merges** with existing SDD artifacts when importing into a project that already has them

### What This Skill Does NOT Do

- Does NOT modify the source documentation files
- Does NOT access external services (Jira API, Notion API) — works from exported files only
- Does NOT generate code or tests — only requirements and specifications
- Does NOT replace human judgment — always previews before generating
- Does NOT handle real-time synchronization (use `sdd-sync-notion` for Notion sync)

---

## 2. Supported Formats

| Format | File Extensions | What It Maps To |
|--------|----------------|----------------|
| **Jira** | `.json`, `.csv` (Jira export) | Epics → requirement groups, Stories → use cases, Bugs → defect tracking, Tasks → implementation notes |
| **OpenAPI/Swagger** | `.yaml`, `.json` (OpenAPI 3.x, Swagger 2.x) | Paths → API contracts, Schemas → domain model, Security → NFRs, Descriptions → requirements |
| **Markdown** | `.md` | Headings → requirement sections, Lists → individual requirements, Code blocks → technical specs |
| **Notion** | `.md` (with metadata), `.csv` (exported databases) | Database rows → requirements, Pages → specifications, Properties → requirement attributes |
| **CSV** | `.csv` | Columns → requirement fields, Rows → individual requirements |
| **Excel** | `.xlsx` | Sheets → artifact types, Rows → individual items, Named columns → requirement fields |

---

## 3. Invocation Modes

```bash
# Auto-detect format from file(s)
/sdd-import path/to/file.yaml

# Explicit format
/sdd-import path/to/export.csv --format=jira

# Target specific artifact type
/sdd-import path/to/api.yaml --target=specs

# Merge with existing artifacts
/sdd-import path/to/requirements.csv --merge

# Multiple files
/sdd-import docs/api.yaml docs/requirements.csv docs/notion-export/
```

| Mode | Behavior | Use Case |
|------|----------|----------|
| **default** | Auto-detect format, generate both requirements and specs | General import |
| `--format=TYPE` | Skip auto-detection, use specified format | When auto-detection is ambiguous |
| `--target=requirements` | Generate only `requirements/` artifacts | When source is requirements-focused |
| `--target=specs` | Generate only `spec/` artifacts | When source is spec-focused (e.g., OpenAPI) |
| `--target=both` | Generate both (default) | Full import |
| `--merge` | Merge with existing SDD artifacts instead of creating new | Adding to existing SDD project |

---

## 4. Process — 7 Phases

### Phase 1: Format Detection

**Objetivo:** Identify the format of input files.

1. For each input file/directory:
   - Check file extension
   - Inspect file content for format-specific markers:
     - OpenAPI: `openapi:` or `swagger:` key at root
     - Jira JSON: `projects` or `issues` array with Jira field names
     - Jira CSV: headers matching Jira export columns (`Summary`, `Issue Type`, `Status`, `Priority`)
     - Notion markdown: YAML front matter with Notion properties
     - Notion CSV: headers with Notion property names
     - CSV: delimiter detection, header row analysis
     - Excel: `.xlsx` binary detection
     - Markdown: standard markdown without format-specific markers
2. Resolve ambiguities:
   - If JSON but unclear source → check for Jira fields vs OpenAPI fields
   - If CSV but unclear source → check column headers against known patterns
   - If still ambiguous → ask user with detected possibilities
3. Validate format compatibility:
   - OpenAPI: validate against OpenAPI 3.x or Swagger 2.x schema
   - Jira: validate expected fields are present
   - CSV/Excel: validate has headers and parseable content

**Output:** Format identification with confidence and validation status.

### Phase 2: Parse Input

**Objetivo:** Parse files into a normalized intermediate representation.

Load [references/format-parsers.md](references/format-parsers.md) and parse according to detected format.

Normalized intermediate format:

```
{
  items: [
    {
      id: "original-id",
      title: "item title",
      description: "full description",
      type: "requirement | use-case | api-endpoint | entity | nfr | ...",
      priority: "critical | high | medium | low",
      status: "active | deprecated | planned",
      group: "parent/category/epic name",
      attributes: { ...format-specific key-value pairs },
      relationships: [ { target: "id", type: "depends-on | child-of | ..." } ],
      source: { file: "path", line: N, format: "jira|openapi|..." }
    }
  ],
  metadata: {
    format: "detected format",
    totalItems: N,
    parseErrors: [ ... ],
    skippedItems: [ ... with reasons ]
  }
}
```

Handle edge cases:
- Encoding issues (UTF-8, Latin-1, etc.)
- Date format variations
- Empty or null fields
- Malformed entries (log and skip with reason)

**Output:** Normalized intermediate representation.

### Phase 3: Mapping Preview

**Objetivo:** Map intermediate items to SDD artifact fields and present for confirmation.

Load [references/mapping-rules.md](references/mapping-rules.md) and:

1. Apply format-specific mapping rules:
   - Map each item to its SDD equivalent (requirement, use case, contract, etc.)
   - Convert descriptions to EARS syntax where possible
   - Map priority/status to SDD equivalents
   - Group items by business domain
2. Detect potential duplicates (if `--merge`):
   - Compare imported items against existing SDD artifacts
   - Match by: ID similarity, title similarity, description overlap
   - Flag duplicates for user review
3. Generate mapping preview:

```
Import Preview
━━━━━━━━━━━━━━
Source: {file(s)}
Format: {detected format}

Mapping Summary:
  → {N} requirements (from {source type})
  → {N} use cases (from {source type})
  → {N} API contracts (from {source type})
  → {N} domain entities (from {source type})
  → {N} NFRs (from {source type})

  Skipped: {N} items (see details)
  Parse errors: {N}
  Duplicates detected: {N} (merge mode)

Sample Mappings:
  Original: "As a user, I want to login with email"
  → REQ-AUTH-001: WHEN a user submits email credentials THE system SHALL authenticate and return a session token

  Original: POST /api/users (OpenAPI)
  → API contract: POST /api/users with request/response schemas

Proceed with import?
```

**Output:** Mapping preview for user confirmation.

### Phase 4: User Confirmation

**Objetivo:** Get user approval before generating artifacts.

Present the mapping preview and ask:

1. **Confirm mapping**: "Proceed with these mappings?"
2. **Handle duplicates** (if `--merge`): "These {N} items match existing artifacts. Options: Skip / Merge / Replace"
3. **Resolve ambiguities**: Items that couldn't be auto-mapped get presented with options:
   - "This item could be a requirement OR a use case. Which?"
   - "This description doesn't fit EARS syntax. Import as-is or convert?"
4. **Confirm skipped items**: "These {N} items were skipped because {reasons}. Include anyway?"

In non-interactive mode (if user pre-confirmed with `--yes`): apply default mappings and skip confirmation.

### Phase 5: Generate SDD Artifacts

**Objetivo:** Generate SDD-format artifacts from confirmed mappings.

Based on `--target` and confirmed mappings:

#### Requirements Generation (`requirements/REQUIREMENTS.md`)

```markdown
### REQ-{GROUP}-{NNN}: {Title} [IMPORTED]

> {EARS statement — converted from original description}

- **Source:** Imported from {format} ({original-id})
- **Original text:** "{original description}"
- **Priority:** {mapped priority}
- **Imported:** {ISO-8601}
```

#### Specification Generation (`spec/`)

**Domain Model** (`spec/domain.md`):
- Entities from OpenAPI schemas, Jira entity descriptions, or CSV entity rows
- Fields with types and constraints

**Use Cases** (`spec/use-cases.md`):
- From Jira stories, Markdown feature descriptions, or CSV use case rows
- Actor, preconditions, main flow, postconditions, alternative flows

**API Contracts** (`spec/contracts.md`):
- From OpenAPI paths — highest fidelity import
- Endpoints with full request/response schemas

**NFRs** (`spec/nfr.md`):
- From Jira non-functional items, OpenAPI security schemes, CSV NFR rows

**ADRs** (`spec/adr/`):
- From Markdown decision records, Jira architecture decisions

#### Merge Logic (when `--merge`)

- New items: append to existing files with `[IMPORTED]` marker
- Duplicates (user chose merge): update existing entry with imported data, mark `[MERGED]`
- Duplicates (user chose skip): leave existing entry unchanged
- Duplicates (user chose replace): overwrite existing with imported, mark `[IMPORTED-REPLACED]`

### Phase 6: Quality Check

**Objetivo:** Verify quality of generated artifacts.

1. **Completeness check:**
   - All imported items have SDD IDs
   - All requirements have EARS syntax (or `[UNCONVERTED]` tag if conversion failed)
   - All use cases have actors, preconditions, postconditions
   - All API contracts have request/response schemas

2. **Consistency check:**
   - No duplicate IDs
   - All cross-references resolve (REQ→UC links)
   - Priority distribution is reasonable (not all CRITICAL)
   - Group structure is coherent

3. **Traceability readiness:**
   - Requirements can link to use cases
   - Use cases can link to API contracts
   - Identify gaps in the chain

4. **Quality metrics:**

```
Import Quality Report:
  Items imported: {N}/{total}
  EARS conversion rate: {X}%
  Traceability ready: {X}%
  Quality issues: {N}
  Manual review needed: {N} items
```

**Output:** Quality assessment.

### Phase 7: Pipeline State Update

**Objetivo:** Update pipeline state to reflect imported artifacts.

1. If `pipeline-state.json` does not exist → create with imported stages marked `done`
2. If it exists:
   - If `requirements-engineer` was `pending` and requirements were imported → set to `done`
   - If `specifications-engineer` was `pending` and specs were imported → set to `done`
   - Mark downstream stages as needing run
3. Generate import report: `import/IMPORT-REPORT.md`
4. Record import metadata for future reference (source files, mapping rules used)

**Output:** Updated `pipeline-state.json`, import report.

---

## 5. Output Format

### File: `import/IMPORT-REPORT.md`

Load [references/import-report-template.md](references/import-report-template.md) for the full template.

Key sections:
- Source files and formats
- Import statistics (parsed, mapped, skipped, errors)
- Mapping summary (original → SDD)
- Quality assessment
- Items needing manual review
- Pipeline state impact

---

## 6. Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-onboarding` | Recommends import when external docs detected (scenarios 5, 8) |
| `sdd-reverse-engineer` | May run after import to fill gaps from code analysis |
| `sdd-reconcile` | Run after import + reverse-engineer to verify alignment |
| `sdd-requirements-engineer` | Import feeds into or replaces the requirements engineering step |
| `sdd-specifications-engineer` | Import may partially replace the spec engineering step |
| `sdd-spec-auditor` | Run after import to audit imported specs |
| `sdd-sync-notion` | For real-time Notion sync; import handles one-time file-based import |

---

## 7. Pipeline Integration

### Reads
- Input files specified by user (various formats)
- `requirements/REQUIREMENTS.md` (if `--merge`)
- `spec/` directory (if `--merge`)
- `pipeline-state.json` (if exists)

### Writes
- `requirements/REQUIREMENTS.md` (new or merged)
- `spec/` documents (new or merged)
- `import/IMPORT-REPORT.md`
- `pipeline-state.json` (stage updates)

### Pipeline State
- Can set `requirements-engineer` to `done` (if requirements imported)
- Can set `specifications-engineer` to `done` (if full specs imported, e.g., OpenAPI → contracts)
- Downstream stages become eligible for execution
- Does NOT run downstream skills automatically

---

## 8. Constraints

1. **File-based only**: Works from exported files, NOT direct API access to Jira/Notion/etc.
2. **No overwrites**: NEVER overwrites existing SDD artifacts without explicit user confirmation via `--merge`.
3. **Preview first**: ALWAYS shows mapping preview before generating artifacts.
4. **EARS conversion**: ATTEMPT to convert all requirements to EARS syntax. Tag as `[UNCONVERTED]` if automatic conversion fails.
5. **Source tracing**: Every imported item MUST reference its source (file, line/row, original ID).
6. **Error tolerance**: Parse errors on individual items do NOT abort the entire import. Log errors, skip items, continue.
7. **Encoding safe**: Handle UTF-8, Latin-1, and common encodings gracefully.
8. **No secrets**: Skip/redact any fields that appear to contain secrets (API keys, tokens, passwords).
9. **Language-adaptive**: Output language follows the user's language. Technical terms remain in English.
