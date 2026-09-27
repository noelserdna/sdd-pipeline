# Format Parsers

> Detection and parsing rules for `sdd-import` Phases 1–2. Output: the normalized item list in SKILL.md Phase 2.

## 1. Detection (`--format` always wins)

| Extension | Candidates | Content marker |
|-----------|-----------|----------------|
| `.yaml`/`.yml`/`.json` | OpenAPI | root key `openapi:` (3.x) or `swagger: "2.0"` |
| `.json` | Jira | `issues[]` or `projects[].issues[]` with `key`, `fields.summary`, `fields.issuetype` |
| `.csv` | Jira CSV | headers include `Summary`, `Issue Type`, `Status`, `Priority` |
| `.csv` | Notion CSV | headers include `Name`, `Created time`, `Last edited time` |
| `.csv` | generic CSV | anything else with a header row |
| `.md` | Notion | front matter with `id:` (UUID) and `Created time:`; a directory with `index.md` + subpages is a Notion export |
| `.md` | Markdown | no Notion markers |
| `.xlsx` | Excel | convert sheets to CSV (SKILL.md Phase 1), then parse each as CSV; a sheet name selects the type: Requirements/Reqs, Use Cases/Stories, API/Endpoints, NFR, Entities/Domain; other names → generic requirements |

## 2. Field mapping

**Jira** (JSON `issue.fields.*`, CSV same names): `key`→id, `summary`→title, `description`→description (convert ADF or wiki markup to Markdown), `issuetype`: Epic→requirement-group, Story→use-case, Task→implementation-note, Bug→defect, Sub-task→sub-requirement; `priority`, `status` (Done/Closed/Resolved→active, others→planned), `labels`→tags, `components`→group, `fixVersions`→version; `issuelinks`, `parent`, `subtasks`→relationships.

**OpenAPI**: one item per path+method: `operationId` (fallback `method_path`)→id, `summary`→title, `description`, `tags`→group, `parameters` + `requestBody` (2.0: `in: body`) → request shape, `responses` → response shapes and error codes, `security`. `components.schemas` (2.0: `definitions`): a schema with an identity field → entity, otherwise value object; `properties` + `required` → fields. `securitySchemes` (2.0: `securityDefinitions`) and `servers` → NFR items. `info.description` → requirements preamble.

**Markdown**: H1→group, H2→requirement/use-case title, H3→detail; bullets→requirements or criteria; numbered lists→workflow steps; tables→entity or parameter data; "shall"/"When…, the system…" sentences→functional requirements; "Performance:/Security:/Availability:" sections→NFRs.

**Notion**: front-matter properties → id, status, type/tags, priority; page body → description (Markdown rules); multi-select split by comma; relations → relationships.

**Generic CSV**: pick the delimiter (`,` `;` tab) that yields a consistent column count; normalize headers (lowercase, trim) and match: title/name/summary, description/details/body, type/category/kind, priority/severity/importance, status/state, id/key/ref, group/module/area/epic, tags/labels, acceptance criteria.

## 3. Encoding and errors

Try UTF-8, UTF-8 BOM, Latin-1, Windows-1252; report sample characters if none works. Empty file or password-protected/corrupt spreadsheet → stop with a message. Malformed JSON/YAML → report the line. Rows with a wrong column count or items without a title → skip and count. OpenAPI validation errors → report and continue with the valid parts. Markdown without structure → warn that the import will be low quality.
