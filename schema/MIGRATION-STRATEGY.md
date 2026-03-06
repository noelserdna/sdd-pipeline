# SDD Evidence Database — Migration Strategy

## 1. Schema Versioning

The database uses the `_schema_version` table to track applied migrations:

```sql
CREATE TABLE _schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description TEXT NOT NULL
);
```

Each migration is a monotonically increasing integer. The current version is queried at startup:

```sql
SELECT MAX(version) FROM _schema_version;
```

## 2. Migration File Convention

Migrations live in `schema/migrations/` with the naming pattern:

```
migrations/
  001-initial-schema.sql      -- CREATE TABLEs, indexes, views, FTS
  002-add-coverage-file.sql   -- example: add coverage_file table
  003-add-symbol-column.sql   -- example: add column to symbol
```

Each migration file:
1. Starts with a guard: `SELECT CASE WHEN (SELECT MAX(version) FROM _schema_version) >= N THEN RAISE(ABORT, 'already applied') END;`
2. Contains DDL/DML statements
3. Ends with: `INSERT INTO _schema_version (version, description) VALUES (N, 'description');`

## 3. Migration Patterns

### 3.1 Adding a table

Safest operation. Just add the CREATE TABLE and its indexes.

```sql
-- Migration 002
CREATE TABLE IF NOT EXISTS new_table (...);
CREATE INDEX IF NOT EXISTS idx_new_table_x ON new_table(x);
INSERT INTO _schema_version VALUES (2, 'Add new_table');
```

### 3.2 Adding a column

SQLite supports `ALTER TABLE ... ADD COLUMN` but NOT `DROP COLUMN` (before 3.35) or `ALTER COLUMN`.

```sql
-- Migration 003
ALTER TABLE artifact ADD COLUMN version_number INTEGER DEFAULT 1;
INSERT INTO _schema_version VALUES (3, 'Add version_number to artifact');
```

### 3.3 Renaming/removing a column (SQLite 3.35+)

```sql
-- Migration 004
ALTER TABLE artifact RENAME COLUMN old_name TO new_name;
-- or
ALTER TABLE artifact DROP COLUMN deprecated_col;
INSERT INTO _schema_version VALUES (4, 'Rename old_name to new_name');
```

### 3.4 Restructuring a table (pre-3.35 or complex changes)

Use the 12-step SQLite ALTER TABLE pattern:

```sql
-- Migration 005
BEGIN TRANSACTION;
CREATE TABLE artifact_new (...);
INSERT INTO artifact_new SELECT ... FROM artifact;
DROP TABLE artifact;
ALTER TABLE artifact_new RENAME TO artifact;
-- Recreate indexes and triggers
COMMIT;
INSERT INTO _schema_version VALUES (5, 'Restructure artifact table');
```

### 3.5 Adding a view

Views can be freely dropped and recreated:

```sql
-- Migration 006
DROP VIEW IF EXISTS v_new_view;
CREATE VIEW v_new_view AS SELECT ...;
INSERT INTO _schema_version VALUES (6, 'Add v_new_view');
```

### 3.6 Updating FTS tables

FTS5 tables cannot be altered. Drop and recreate:

```sql
-- Migration 007
DROP TRIGGER IF EXISTS artifact_fts_insert;
DROP TRIGGER IF EXISTS artifact_fts_update;
DROP TRIGGER IF EXISTS artifact_fts_delete;
DROP TABLE IF EXISTS artifact_fts;
CREATE VIRTUAL TABLE artifact_fts USING fts5(...new columns...);
-- Recreate triggers
-- Rebuild FTS from existing data
INSERT INTO artifact_fts(artifact_fts) VALUES('rebuild');
INSERT INTO _schema_version VALUES (7, 'Update artifact FTS with new columns');
```

## 4. Migration from traceability-graph.json (v5)

The existing `traceability-graph.json` maps to the database as follows:

| JSON Path | Database Table(s) |
|-----------|-------------------|
| `project.name` | `project.name` |
| `pipeline.stages[]` | `pipeline_stage` |
| `pipeline.lateralStages[]` | `pipeline_stage` (stage_type='lateral') |
| `artifacts[]` | `artifact` + `artifact_classification` |
| `artifacts[].codeRefs[]` | `symbol` + `traceability_link` (source_type='symbol') |
| `artifacts[].testRefs[]` | `test_case` + `traceability_link` (source_type='test_case') |
| `artifacts[].commitRefs[]` | `commit` + `commit_artifact_ref` + `traceability_link` |
| `relationships[]` | `traceability_link` |
| `statistics` | Computed from views (`v_req_coverage`, `v_coverage_gaps_by_domain`, etc.) |
| `codeIntelligence.symbols[]` | `symbol` |
| `codeIntelligence.callGraph[]` | `call_edge` |
| `codeIntelligence.processes[]` | `execution_flow` + `execution_flow_step` |
| `adoption` | `pipeline_stage.metadata` or separate `snapshot` |

### Import Script Pseudocode

```python
def import_graph_json(db, graph_json):
    # 1. Create or update project
    project_id = upsert_project(db, graph_json['projectName'])

    # 2. Import pipeline stages
    for i, stage in enumerate(graph_json['pipeline']['stages']):
        upsert_pipeline_stage(db, project_id, stage, sort_order=i, stage_type='pipeline')
    for i, stage in enumerate(graph_json['pipeline'].get('lateralStages', [])):
        upsert_pipeline_stage(db, project_id, stage, sort_order=100+i, stage_type='lateral')

    # 3. Import artifacts
    for art in graph_json['artifacts']:
        insert_artifact(db, project_id, art)
        if art.get('classification'):
            insert_classification(db, project_id, art['id'], art['classification'])

    # 4. Import relationships as traceability_links
    for rel in graph_json['relationships']:
        insert_link(db, project_id, {
            'source_id': rel['source'],
            'source_type': 'artifact',
            'target_id': rel['target'],
            'target_type': 'artifact',
            'link_type': rel['type'],
            'origin': 'manual',
            'confidence': 1.0,
            'source_file': rel.get('sourceFile'),
            'source_line': rel.get('line'),
        })

    # 5. Import codeRefs → symbols + links
    for art in graph_json['artifacts']:
        for cr in art.get('codeRefs', []):
            sym_id = upsert_symbol(db, project_id, cr)
            insert_link(db, project_id, {
                'source_id': sym_id,
                'source_type': 'symbol',
                'target_id': art['id'],
                'target_type': 'artifact',
                'link_type': 'implemented-by-code',
                'origin': 'inferred:code-comment',
            })

    # 6. Import testRefs → test_cases + links
    for art in graph_json['artifacts']:
        for tr in art.get('testRefs', []):
            tc_id = upsert_test_case(db, project_id, tr)
            insert_link(db, project_id, {
                'source_id': tc_id,
                'source_type': 'test_case',
                'target_id': art['id'],
                'target_type': 'artifact',
                'link_type': 'tested-by',
                'origin': 'inferred:test-description',
            })

    # 7. Import commitRefs → commits + links
    for art in graph_json['artifacts']:
        for cr in art.get('commitRefs', []):
            upsert_commit(db, project_id, cr)
            insert_link(db, project_id, {
                'source_id': cr['fullSha'],
                'source_type': 'commit',
                'target_id': art['id'],
                'target_type': 'artifact',
                'link_type': 'implemented-by-commit',
                'origin': 'inferred:commit-chain',
            })

    # 8. Import codeIntelligence if present
    ci = graph_json.get('codeIntelligence')
    if ci:
        import_code_intelligence(db, project_id, ci)
```

## 5. Export: Database to JSON

The JSON export format (`json-export-format.json`) is generated by querying the database:

```python
def export_to_json(db, project_id):
    return {
        "$schema": "sdd-evidence-db-export-v1",
        "exportedAt": now_iso(),
        "dbSchemaVersion": get_schema_version(db),
        "project": query_project(db, project_id),
        "pipeline": {
            "stages": query_stages(db, project_id, 'pipeline'),
            "lateralStages": query_stages(db, project_id, 'lateral'),
        },
        "artifacts": query_all_artifacts_with_classification(db, project_id),
        "codeIntelligence": export_code_intelligence(db, project_id),
        "commits": query_all_commits(db, project_id),
        "testEvidence": export_test_evidence(db, project_id),
        "cicd": export_cicd(db, project_id),
        "aiAudit": export_ai_audit(db, project_id),
        "traceabilityLinks": query_all_links(db, project_id),
        "overrides": query_all_overrides(db, project_id),
        "statistics": compute_statistics_from_views(db, project_id),
    }
```

## 6. Backward Compatibility with traceability-graph.json

The dashboard currently reads `traceability-graph.json`. During migration:

1. **Phase 1 (Parallel)**: The database is the source of truth. A `db-to-graph.py` script generates `traceability-graph.json` from the database for dashboard compatibility.
2. **Phase 2 (Dashboard Update)**: The dashboard reads directly from the SQLite database via the MCP server or a lightweight REST API.
3. **Phase 3 (Deprecation)**: `traceability-graph.json` generation becomes optional, only for portability/export scenarios.

## 7. Extensibility Patterns

### 7.1 New entity types

Add a new table and use the existing `traceability_link` table with a new `source_type`/`target_type` value. No schema change needed on the link table.

### 7.2 New link types

Just use a new `link_type` string value. The enum is open-ended by design.

### 7.3 New metadata

Every table has a `metadata TEXT DEFAULT '{}'` column for JSON key-value pairs. Use this for one-off extensions before committing to a schema migration.

### 7.4 New classification dimensions

Add columns to `artifact_classification` via migration, or store in `metadata` JSON first.

## 8. Performance Considerations

- **WAL mode**: Enabled for concurrent reads during writes (dashboard reads while imports run).
- **Covering indexes**: The `idx_link_source_target` index covers the most common join pattern.
- **Partial indexes**: `WHERE suspect = 1` and `WHERE invalidated_at IS NULL` reduce index size for filtered queries.
- **FTS5**: Used for artifact text search and AI content search. Kept in sync via triggers.
- **Views**: Precomputed joins for common patterns. SQLite materializes views on each query, so complex views should be used judiciously.
- **Statistics**: Computed at export time, not stored (except in snapshots). This avoids stale aggregate data.

## 9. Database File Location

The database file lives at: `{project_root}/dashboard/sdd-evidence.db`

This colocates with the existing dashboard output directory and is gitignored by default (binary file).
