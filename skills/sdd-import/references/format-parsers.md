# Format Parsers — Parsing Rules by Source Format

> Reglas de parsing para cada uno de los 6 formatos soportados por `sdd-import`. Incluye auto-detección, manejo de encoding, delimiters, formatos de fecha y error handling. Utilizado por las Fases 1 y 2.

---

## 1. Format Auto-Detection

### Detection Priority Order

1. **File extension** → first pass classification
2. **Content inspection** → confirm or override extension-based detection
3. **User override** → `--format=TYPE` always wins

### Detection Rules

| Extension | First Pass | Content Confirmation |
|-----------|-----------|---------------------|
| `.yaml`, `.yml` | OpenAPI or generic YAML | Look for `openapi:` or `swagger:` root key |
| `.json` | OpenAPI or Jira | Check for `openapi`/`swagger` key OR `issues`/`projects` arrays |
| `.csv` | CSV, Jira CSV, or Notion CSV | Check headers against known patterns |
| `.xlsx` | Excel | Binary format detection (ZIP with `xl/` structure) |
| `.md` | Markdown or Notion | Check for Notion YAML front matter with `id:`, `Created time:` |
| Directory | Notion export | Check for `index.md` + subpages pattern |

### Content Markers

**OpenAPI/Swagger:**
```yaml
openapi: "3.x.x"   # OpenAPI 3.x marker
# OR
swagger: "2.0"      # Swagger 2.x marker
```

**Jira JSON:**
```json
{
  "projects": [...],    // Jira project export
  "issues": [...]       // OR direct issue export
}
// Fields: "key", "fields.summary", "fields.issuetype", "fields.status"
```

**Jira CSV headers:**
```
Summary, Issue Type, Status, Priority, Assignee, Reporter, Created, Updated, Description
```

**Notion markdown front matter:**
```yaml
---
id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Created time: 2024-01-15T10:30:00.000Z
Last edited time: 2024-03-01T14:22:00.000Z
---
```

**Notion CSV headers:**
```
Name, Tags, Status, Created time, Last edited time, ...
```

---

## 2. Jira Parser

### JSON Format

```
Structure:
  root.projects[].issues[] OR root.issues[]

Field Mapping:
  issue.key                    → item.id
  issue.fields.summary         → item.title
  issue.fields.description     → item.description (convert Jira wiki/ADF to plain text)
  issue.fields.issuetype.name  → item.type mapping:
                                   "Epic"    → "requirement-group"
                                   "Story"   → "use-case"
                                   "Task"    → "implementation-note"
                                   "Bug"     → "defect"
                                   "Sub-task" → "sub-requirement"
  issue.fields.priority.name   → item.priority mapping:
                                   "Highest"/"Blocker" → "critical"
                                   "High"              → "high"
                                   "Medium"            → "medium"
                                   "Low"/"Lowest"      → "low"
  issue.fields.status.name     → item.status mapping:
                                   "Done"/"Closed"/"Resolved" → "active" (implemented)
                                   "To Do"/"Open"/"Backlog"   → "planned"
                                   "In Progress"              → "planned"
  issue.fields.labels          → item.attributes.tags
  issue.fields.components      → item.group
  issue.fields.fixVersions     → item.attributes.version
  issue.fields.created         → item.attributes.created
  issue.fields.updated         → item.attributes.updated

Relationships:
  issue.fields.issuelinks[]    → item.relationships
    inwardIssue/outwardIssue   → target ID
    type.name                  → relationship type ("Blocks", "Relates to", etc.)
  issue.fields.parent          → item.relationships (child-of)
  issue.fields.subtasks        → item.relationships (parent-of)

Description Conversion:
  Jira ADF (Atlassian Document Format):
    - Extract text from content nodes
    - Convert code blocks to markdown fences
    - Convert tables to markdown tables
    - Convert lists to markdown lists
  Jira Wiki markup:
    - {code} → ``` fences
    - h1. → # headings
    - * → bullet lists
    - # → numbered lists
    - [link|url] → [link](url)
```

### CSV Format

```
Parse:
  - Detect delimiter (comma, semicolon, tab)
  - First row = headers
  - Map headers to Jira field names (case-insensitive)
  - Handle quoted fields with embedded delimiters

Column Mapping:
  "Summary"      → item.title
  "Description"  → item.description
  "Issue Type"   → item.type (same mapping as JSON)
  "Priority"     → item.priority (same mapping as JSON)
  "Status"       → item.status (same mapping as JSON)
  "Issue key"    → item.id
  "Labels"       → item.attributes.tags (split by comma)
  "Components"   → item.group (split by comma)
  "Fix Version"  → item.attributes.version
```

---

## 3. OpenAPI Parser

### OpenAPI 3.x / Swagger 2.x

```
Structure parsing:

info:
  title           → project name
  description     → project-level requirement
  version         → API version

paths:
  /{path}:
    {method}:     → one item per method+path combination
      summary     → item.title
      description → item.description
      operationId → item.id (fallback: method_path)
      tags        → item.group
      parameters  → request parameters (query, path, header)
      requestBody → request schema (OpenAPI 3.x)
        content.application/json.schema → request type
      responses:
        200/201   → success response schema
        4XX       → client error responses
        5XX       → server error responses
      security    → security requirements

components/definitions:
  schemas:
    {Name}:       → domain entity
      properties  → entity fields with types
      required    → required fields
      description → entity description

  securitySchemes:
    {name}:       → security NFR
      type        → auth type (apiKey, http, oauth2, openIdConnect)
      scheme      → auth scheme (bearer, basic)

Item Type Mapping:
  path+method            → "api-endpoint" → API contract
  schema (with ID field) → "entity" → domain model entry
  schema (without ID)    → "value-object" → domain model value type
  securityScheme         → "nfr" → security requirement
  server                 → "nfr" → infrastructure requirement

Swagger 2.x Differences:
  - definitions instead of components.schemas
  - parameters[].in: "body" instead of requestBody
  - produces/consumes instead of content negotiation
  - securityDefinitions instead of components.securitySchemes
```

---

## 4. Markdown Parser

```
Structure parsing:

# H1 Heading        → Requirement group / document section
## H2 Heading       → Individual requirement or use case title
### H3 Heading      → Sub-requirement or detail section

Content patterns:
  - Bullet list item → Individual requirement or acceptance criterion
  - Numbered list    → Workflow steps or ordered requirements
  - Table            → Structured data (entity fields, API params, etc.)
  - Code block       → Technical specification or example
  - Blockquote       → Note, constraint, or non-functional requirement
  - Bold text        → Emphasis on key terms, often requirement keywords

Requirement Detection Heuristics:
  - "The system shall..."  → Functional requirement (EARS: ubiquitous)
  - "When..., the system..." → Functional requirement (EARS: event-driven)
  - "Users can..."         → Use case description
  - "Must...", "Required:" → Constraint
  - "Performance:", "Security:", "Availability:" → NFR section

Link/Reference Extraction:
  - [text](url) → External reference
  - [REQ-XXX] → Internal cross-reference
  - Footnotes → Additional context
```

---

## 5. Notion Parser

### Exported Markdown

```
Structure:
  - Directory with index.md + subpages
  - Each page has YAML front matter with Notion properties
  - Subpages in subdirectories

Front matter → item attributes:
  id              → item.id
  Status          → item.status
  Tags/Type       → item.type or item.attributes.tags
  Priority        → item.priority
  Created time    → item.attributes.created
  Last edited     → item.attributes.updated

Content → item.description (standard markdown parsing)

Database export → treat like structured CSV with rich text cells
```

### Exported CSV

```
Parse like standard CSV but with Notion-specific column handling:
  - "Name" column → item.title
  - Status/Select properties → mapped to SDD equivalents
  - Multi-select properties → split by comma
  - Date properties → parse ISO-8601 or Notion date format
  - Relation properties → item.relationships
  - URL properties → item.attributes.links
  - Checkbox properties → boolean attributes
```

---

## 6. CSV Parser

```
Generic CSV handling:

Delimiter Detection:
  1. Try comma (,)
  2. Try semicolon (;) — common in European exports
  3. Try tab (\t)
  4. Use the delimiter that produces the most consistent column count

Header Detection:
  - First row is assumed to be headers
  - Normalize: lowercase, trim, replace spaces with underscores
  - Match against known patterns:
    "title", "name", "summary"           → item.title
    "description", "details", "body"     → item.description
    "type", "category", "kind"           → item.type
    "priority", "severity", "importance" → item.priority
    "status", "state"                    → item.status
    "id", "key", "number", "ref"         → item.id
    "group", "module", "area", "epic"    → item.group
    "tags", "labels"                     → item.attributes.tags

Encoding Handling:
  1. Try UTF-8
  2. Try UTF-8 with BOM
  3. Try Latin-1 (ISO-8859-1)
  4. Try Windows-1252
  If all fail → report encoding error with sample of problematic characters

Data Type Detection per Column:
  - Dates: try ISO-8601, then common formats (MM/DD/YYYY, DD/MM/YYYY, etc.)
  - Numbers: detect numeric columns for priority mapping
  - Booleans: yes/no, true/false, 1/0
  - Lists: values containing commas or semicolons within quoted fields
```

---

## 7. Excel Parser

```
XLSX Handling:

Sheet Interpretation:
  - Each sheet → potential artifact type
  - Sheet names suggest content: "Requirements", "Use Cases", "API", "NFRs"
  - If only one sheet → treat as generic CSV-like parsing
  - If multiple sheets → map each to appropriate artifact type

Cell Parsing:
  - Read cell values and types (string, number, date, boolean)
  - Handle merged cells (use value from top-left cell)
  - Handle formatted text (bold, italic) → preserve as markdown
  - Handle hyperlinks → extract URL

Column Mapping:
  Same rules as CSV parser but with additional:
  - Cell colors/formatting may indicate priority (red=critical, yellow=medium)
  - Conditional formatting rules may encode status
  - Named ranges may indicate data structure

Multi-sheet Mapping:
  Sheet named "Requirements" or "Reqs" → requirements
  Sheet named "Use Cases" or "Stories" → use cases
  Sheet named "API" or "Endpoints"     → API contracts
  Sheet named "NFR" or "Non-Functional" → NFRs
  Sheet named "Entities" or "Domain"   → domain model
  Default (unrecognized name)          → generic requirement import
```

---

## 8. Error Handling by Format

| Format | Common Errors | Handling |
|--------|--------------|----------|
| All | Encoding issues | Try multiple encodings, report if none work |
| All | Empty file | Abort with clear message |
| JSON | Malformed JSON | Report line/position of error |
| YAML | Invalid YAML syntax | Report line of error |
| CSV | Inconsistent column count | Skip malformed rows, report count |
| CSV | Unescaped delimiters | Try alternative quoting/escaping |
| Excel | Password-protected | Abort with message asking user to remove protection |
| Excel | Corrupted file | Report and abort |
| OpenAPI | Schema validation failure | Report specific validation errors, continue with valid portions |
| Jira | Missing required fields | Skip items without title/summary |
| Notion | Mixed export formats | Handle each file according to its individual format |
| Markdown | No structured content | Warn that import will be low quality |
