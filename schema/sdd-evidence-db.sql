-- ============================================================================
-- SDD Evidence & Traceability Database — Definitive Schema
-- Target: SQLite 3.35+ (JSON, FTS5, generated columns, STRICT)
-- Version: 1.0.0
-- Date: 2026-03-04
--
-- This schema stores the complete software development lifecycle:
--   1. SDD Artifacts (REQ, UC, WF, API, BDD, INV, ADR, TASK, RN, NFR, FASE)
--   2. Code Intelligence (files, symbols, call graph, imports)
--   3. Commits (SHA, message, diffs, trailers)
--   4. Test Evidence (screenshots, logs, executions, runs)
--   5. CI/CD Data (pipelines, jobs, steps, artifacts)
--   6. AI Audit Trail (sessions, turns, tool calls, decisions)
--   7. Traceability Links (unified, with confidence and suspect detection)
--   8. Overrides (human corrections to inferred links)
--
-- Design principles:
--   - Every entity has a UUID-style text primary key for portability
--   - All timestamps are ISO-8601 TEXT (SQLite has no native datetime)
--   - JSON columns (TEXT) for extensible metadata without schema changes
--   - FTS5 virtual tables for full-text search on content-heavy fields
--   - Schema versioning via _schema_version table
--   - Soft-delete via status fields, never hard-delete traceability data
-- ============================================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ============================================================================
-- 0. SCHEMA VERSIONING
-- ============================================================================

CREATE TABLE IF NOT EXISTS _schema_version (
    version     INTEGER PRIMARY KEY,
    applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description TEXT NOT NULL
);

INSERT INTO _schema_version (version, description)
VALUES (1, 'Initial schema: artifacts, code intelligence, commits, tests, CI/CD, AI audit, traceability links, overrides');

-- ============================================================================
-- 1. PROJECT & PIPELINE
-- ============================================================================

CREATE TABLE project (
    id              TEXT PRIMARY KEY,           -- UUID
    name            TEXT NOT NULL,
    root_path       TEXT,                       -- absolute path on disk
    repository_url  TEXT,                       -- git remote URL
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    metadata        TEXT DEFAULT '{}'           -- JSON: arbitrary project-level KV
);

CREATE TABLE pipeline_stage (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    name            TEXT NOT NULL,              -- e.g. 'requirements-engineer', 'security-auditor'
    stage_type      TEXT NOT NULL DEFAULT 'pipeline',  -- 'pipeline' | 'lateral'
    status          TEXT NOT NULL DEFAULT 'pending',   -- pending|running|done|stale|error
    last_run        TEXT,                       -- ISO-8601
    artifact_count  INTEGER DEFAULT 0,
    stage_label     TEXT DEFAULT 'artifacts',   -- unit label for artifact_count
    input_hash      TEXT,                       -- sha256 of input artifacts
    output_hash     TEXT,                       -- sha256 of output artifacts
    stale_reason    TEXT,
    sort_order      INTEGER NOT NULL DEFAULT 0, -- display ordering
    summary         TEXT,                       -- JSON: { artifacts, metrics, highlights, nextStep, generatedAt }
    metadata        TEXT DEFAULT '{}',          -- JSON: extensible
    UNIQUE(project_id, name)
);

-- ============================================================================
-- 2. SDD ARTIFACTS
-- ============================================================================

CREATE TABLE artifact (
    id              TEXT NOT NULL,              -- e.g. 'REQ-EXT-001', 'UC-003'
    project_id      TEXT NOT NULL REFERENCES project(id),
    type            TEXT NOT NULL,              -- REQ|UC|WF|API|BDD|INV|ADR|NFR|RN|FASE|TASK
    category        TEXT,                       -- sub-category: EXT, CVA, SYS, SEC, F, NF, etc.
    title           TEXT NOT NULL,
    file_path       TEXT NOT NULL,              -- relative to project root
    line            INTEGER,                    -- line number in file (1-indexed)
    priority        TEXT,                       -- 'Must Have', 'Should Have', etc.
    status          TEXT NOT NULL DEFAULT 'active',  -- active|deprecated|superseded|deleted
    stage           TEXT,                       -- pipeline stage that owns this artifact
    content_hash    TEXT,                       -- sha256 of artifact content block
    ears_syntax     TEXT,                       -- EARS statement if applicable
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    metadata        TEXT DEFAULT '{}',          -- JSON: extensible per-artifact data
    PRIMARY KEY (id, project_id)
);

-- Classification (for REQ artifacts — normalized out for queryability)
CREATE TABLE artifact_classification (
    artifact_id         TEXT NOT NULL,
    project_id          TEXT NOT NULL,
    business_domain     TEXT NOT NULL,          -- 'Extraction & Processing', 'Security & Auth', etc.
    technical_layer     TEXT NOT NULL,          -- 'Infrastructure', 'Backend', 'Frontend', etc.
    functional_category TEXT NOT NULL,          -- 'Functional', 'Non-Functional', 'Security', etc.
    classified_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    classified_by       TEXT DEFAULT 'auto',    -- 'auto' | 'manual' | session_id
    PRIMARY KEY (artifact_id, project_id),
    FOREIGN KEY (artifact_id, project_id) REFERENCES artifact(id, project_id)
);

-- Full-text search on artifact titles and content
-- Standalone FTS table (not external content) — kept in sync via triggers
CREATE VIRTUAL TABLE artifact_fts USING fts5(
    artifact_id,
    project_id,
    title,
    ears_syntax
);

-- Triggers to keep FTS in sync
CREATE TRIGGER artifact_fts_insert AFTER INSERT ON artifact BEGIN
    INSERT INTO artifact_fts(artifact_id, project_id, title, ears_syntax)
    VALUES (new.id, new.project_id, new.title, new.ears_syntax);
END;

CREATE TRIGGER artifact_fts_update AFTER UPDATE ON artifact BEGIN
    DELETE FROM artifact_fts WHERE artifact_id = old.id AND project_id = old.project_id;
    INSERT INTO artifact_fts(artifact_id, project_id, title, ears_syntax)
    VALUES (new.id, new.project_id, new.title, new.ears_syntax);
END;

CREATE TRIGGER artifact_fts_delete AFTER DELETE ON artifact BEGIN
    DELETE FROM artifact_fts WHERE artifact_id = old.id AND project_id = old.project_id;
END;

-- ============================================================================
-- 3. CODE INTELLIGENCE (GitNexus)
-- ============================================================================

CREATE TABLE code_file (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    path            TEXT NOT NULL,              -- relative to project root
    language        TEXT,                       -- 'typescript', 'python', etc.
    size_bytes      INTEGER,
    line_count      INTEGER,
    last_modified   TEXT,                       -- ISO-8601
    content_hash    TEXT,                       -- sha256 of file content
    indexed_at      TEXT,                       -- last time symbols were extracted
    metadata        TEXT DEFAULT '{}',
    UNIQUE(project_id, path)
);

CREATE TABLE symbol (
    id              TEXT PRIMARY KEY,           -- e.g. 'sym-validate-user-a3f2'
    project_id      TEXT NOT NULL REFERENCES project(id),
    file_id         TEXT NOT NULL REFERENCES code_file(id),
    name            TEXT NOT NULL,
    qualified_name  TEXT,                       -- full qualified name: module.Class.method
    kind            TEXT NOT NULL,              -- 'function'|'class'|'method'|'interface'|'enum'|'const'|'type'|'variable'
    signature       TEXT,                       -- e.g. '(userId: string): Promise<User>'
    start_line      INTEGER NOT NULL,
    end_line        INTEGER NOT NULL,
    is_exported     BOOLEAN NOT NULL DEFAULT 0,
    visibility      TEXT DEFAULT 'public',      -- 'public'|'private'|'protected'|'internal'
    community       TEXT,                       -- cluster name from graph analysis
    indexed_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    metadata        TEXT DEFAULT '{}'
);

-- Call graph: caller → callee
CREATE TABLE call_edge (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    caller_id       TEXT NOT NULL REFERENCES symbol(id),
    callee_id       TEXT NOT NULL REFERENCES symbol(id),
    edge_type       TEXT NOT NULL DEFAULT 'CALLS',  -- 'CALLS'|'IMPORTS'|'INHERITS'|'IMPLEMENTS'|'OVERRIDES'
    confidence      REAL NOT NULL DEFAULT 1.0,
    call_site_file  TEXT,                       -- file where call occurs
    call_site_line  INTEGER,                    -- line where call occurs
    metadata        TEXT DEFAULT '{}',
    UNIQUE(caller_id, callee_id, edge_type)
);

-- Import graph: file → imported_file
CREATE TABLE import_edge (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    importer_id     TEXT NOT NULL REFERENCES code_file(id),
    imported_id     TEXT NOT NULL REFERENCES code_file(id),
    import_path     TEXT,                       -- raw import string as written in code
    is_dynamic      BOOLEAN NOT NULL DEFAULT 0,
    line            INTEGER,
    UNIQUE(importer_id, imported_id, import_path)
);

-- Symbol references (usages) across the codebase
CREATE TABLE symbol_reference (
    id              TEXT PRIMARY KEY,           -- UUID
    symbol_id       TEXT NOT NULL REFERENCES symbol(id),
    file_id         TEXT NOT NULL REFERENCES code_file(id),
    line            INTEGER NOT NULL,
    column          INTEGER,
    ref_type        TEXT DEFAULT 'usage',       -- 'usage'|'definition'|'type-ref'|'override'
    metadata        TEXT DEFAULT '{}'
);

-- Execution flows / processes detected by code-index
CREATE TABLE execution_flow (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    name            TEXT NOT NULL,
    entry_point_id  TEXT REFERENCES symbol(id),
    description     TEXT,
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE execution_flow_step (
    flow_id         TEXT NOT NULL REFERENCES execution_flow(id),
    step_order      INTEGER NOT NULL,
    symbol_id       TEXT NOT NULL REFERENCES symbol(id),
    PRIMARY KEY (flow_id, step_order)
);

-- ============================================================================
-- 4. COMMITS
-- ============================================================================

CREATE TABLE git_commit (
    sha             TEXT NOT NULL,              -- full 40-char SHA
    project_id      TEXT NOT NULL REFERENCES project(id),
    short_sha       TEXT GENERATED ALWAYS AS (substr(sha, 1, 7)) STORED,
    message         TEXT NOT NULL,              -- full commit message
    subject         TEXT,                       -- first line only
    author_name     TEXT NOT NULL,
    author_email    TEXT,
    author_date     TEXT NOT NULL,              -- ISO-8601
    committer_name  TEXT,
    committer_date  TEXT,
    branch          TEXT,                       -- branch at time of commit
    -- Diff stats
    files_added     INTEGER DEFAULT 0,
    files_modified  INTEGER DEFAULT 0,
    files_deleted   INTEGER DEFAULT 0,
    lines_added     INTEGER DEFAULT 0,
    lines_deleted   INTEGER DEFAULT 0,
    -- Trailers (extracted from commit message)
    task_id         TEXT,                       -- from 'Task:' trailer
    refs_raw        TEXT,                       -- raw 'Refs:' trailer value
    co_authors      TEXT,                       -- JSON array of co-author strings
    -- Conventional commit parsing
    cc_type         TEXT,                       -- 'feat', 'fix', 'refactor', etc.
    cc_scope        TEXT,                       -- scope in parentheses
    cc_breaking     BOOLEAN DEFAULT 0,          -- has '!' or 'BREAKING CHANGE'
    metadata        TEXT DEFAULT '{}',
    PRIMARY KEY (sha, project_id)
);

-- Files changed in each commit
CREATE TABLE commit_file (
    id              TEXT PRIMARY KEY,           -- UUID
    commit_sha      TEXT NOT NULL,
    project_id      TEXT NOT NULL,
    file_path       TEXT NOT NULL,
    change_type     TEXT NOT NULL,              -- 'A'|'M'|'D'|'R' (added/modified/deleted/renamed)
    old_path        TEXT,                       -- for renames
    lines_added     INTEGER DEFAULT 0,
    lines_deleted   INTEGER DEFAULT 0,
    FOREIGN KEY (commit_sha, project_id) REFERENCES git_commit(sha, project_id)
);

-- Parsed artifact references from Refs: trailer
CREATE TABLE commit_artifact_ref (
    commit_sha      TEXT NOT NULL,
    project_id      TEXT NOT NULL,
    artifact_id     TEXT NOT NULL,
    ref_source      TEXT NOT NULL DEFAULT 'refs_trailer',  -- 'refs_trailer'|'task_trailer'|'message_body'
    PRIMARY KEY (commit_sha, project_id, artifact_id, ref_source),
    FOREIGN KEY (commit_sha, project_id) REFERENCES git_commit(sha, project_id)
);

-- ============================================================================
-- 5. TEST EVIDENCE
-- ============================================================================

-- A test run = one execution session (e.g. `npm test`, a CI test job)
CREATE TABLE test_run (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    runner          TEXT,                       -- 'vitest', 'jest', 'pytest', etc.
    trigger         TEXT,                       -- 'local', 'ci', 'pre-commit'
    branch          TEXT,
    commit_sha      TEXT,
    started_at      TEXT NOT NULL,
    finished_at     TEXT,
    status          TEXT NOT NULL DEFAULT 'running',  -- running|passed|failed|error
    total_tests     INTEGER DEFAULT 0,
    passed          INTEGER DEFAULT 0,
    failed          INTEGER DEFAULT 0,
    skipped         INTEGER DEFAULT 0,
    duration_ms     INTEGER,
    ci_run_id       TEXT REFERENCES ci_pipeline_run(id),
    metadata        TEXT DEFAULT '{}'
);

-- Individual test case
CREATE TABLE test_case (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    file_path       TEXT NOT NULL,              -- test file relative path
    line            INTEGER,
    test_name       TEXT NOT NULL,              -- describe + it text
    suite_name      TEXT,                       -- describe block name
    framework       TEXT,                       -- 'vitest', 'jest', 'pytest', etc.
    tags            TEXT DEFAULT '[]',          -- JSON array of tags
    metadata        TEXT DEFAULT '{}'
);

-- Test execution result (one per test_case per test_run)
CREATE TABLE test_execution (
    id              TEXT PRIMARY KEY,           -- UUID
    test_run_id     TEXT NOT NULL REFERENCES test_run(id),
    test_case_id    TEXT NOT NULL REFERENCES test_case(id),
    result          TEXT NOT NULL,              -- 'pass'|'fail'|'skip'|'error'|'flaky'
    duration_ms     INTEGER,
    error_message   TEXT,
    error_stack     TEXT,
    retry_count     INTEGER DEFAULT 0,
    metadata        TEXT DEFAULT '{}'
);

-- Evidence items (screenshots, videos, logs, HAR files)
CREATE TABLE test_evidence (
    id              TEXT PRIMARY KEY,           -- UUID
    test_execution_id TEXT REFERENCES test_execution(id),
    test_run_id     TEXT REFERENCES test_run(id),
    evidence_type   TEXT NOT NULL,              -- 'screenshot'|'video'|'log'|'har'|'trace'|'report'|'coverage'
    file_path       TEXT NOT NULL,
    file_name       TEXT,
    mime_type       TEXT,
    size_bytes      INTEGER,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description     TEXT,
    content_hash    TEXT,
    metadata        TEXT DEFAULT '{}'
);

-- Code coverage data
CREATE TABLE coverage_report (
    id              TEXT PRIMARY KEY,           -- UUID
    test_run_id     TEXT NOT NULL REFERENCES test_run(id),
    project_id      TEXT NOT NULL REFERENCES project(id),
    tool            TEXT,                       -- 'istanbul', 'c8', 'coverage.py', etc.
    format          TEXT,                       -- 'lcov', 'cobertura', 'json'
    lines_total     INTEGER,
    lines_covered   INTEGER,
    lines_pct       REAL,
    branches_total  INTEGER,
    branches_covered INTEGER,
    branches_pct    REAL,
    functions_total INTEGER,
    functions_covered INTEGER,
    functions_pct   REAL,
    statements_total INTEGER,
    statements_covered INTEGER,
    statements_pct  REAL,
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    metadata        TEXT DEFAULT '{}'
);

-- Per-file coverage breakdown
CREATE TABLE coverage_file (
    id              TEXT PRIMARY KEY,           -- UUID
    coverage_report_id TEXT NOT NULL REFERENCES coverage_report(id),
    file_path       TEXT NOT NULL,
    lines_total     INTEGER,
    lines_covered   INTEGER,
    lines_pct       REAL,
    branches_total  INTEGER,
    branches_covered INTEGER,
    branches_pct    REAL,
    functions_total INTEGER,
    functions_covered INTEGER,
    functions_pct   REAL,
    uncovered_lines TEXT,                       -- JSON array of line numbers
    metadata        TEXT DEFAULT '{}'
);

-- ============================================================================
-- 6. CI/CD DATA
-- ============================================================================

CREATE TABLE ci_pipeline_run (
    id              TEXT PRIMARY KEY,           -- UUID or CI system ID
    project_id      TEXT NOT NULL REFERENCES project(id),
    provider        TEXT NOT NULL,              -- 'github-actions'|'gitlab-ci'|'jenkins'|'circleci'
    pipeline_name   TEXT,
    run_number      INTEGER,
    trigger_type    TEXT,                       -- 'push'|'pull_request'|'schedule'|'manual'|'workflow_dispatch'
    trigger_ref     TEXT,                       -- branch or tag
    commit_sha      TEXT,
    status          TEXT NOT NULL,              -- 'queued'|'in_progress'|'success'|'failure'|'cancelled'|'skipped'
    conclusion      TEXT,                       -- 'success'|'failure'|'cancelled'|'timed_out'|'action_required'
    url             TEXT,                       -- link to CI UI
    started_at      TEXT,
    finished_at     TEXT,
    duration_ms     INTEGER,
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE ci_job (
    id              TEXT PRIMARY KEY,           -- UUID or CI system ID
    run_id          TEXT NOT NULL REFERENCES ci_pipeline_run(id),
    name            TEXT NOT NULL,
    status          TEXT NOT NULL,
    conclusion      TEXT,
    runner          TEXT,                       -- runner label/name
    started_at      TEXT,
    finished_at     TEXT,
    duration_ms     INTEGER,
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE ci_step (
    id              TEXT PRIMARY KEY,           -- UUID
    job_id          TEXT NOT NULL REFERENCES ci_job(id),
    name            TEXT NOT NULL,
    step_number     INTEGER NOT NULL,
    status          TEXT NOT NULL,
    conclusion      TEXT,
    started_at      TEXT,
    finished_at     TEXT,
    duration_ms     INTEGER,
    log_excerpt     TEXT,                       -- last N lines or error excerpt
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE ci_artifact (
    id              TEXT PRIMARY KEY,           -- UUID
    run_id          TEXT NOT NULL REFERENCES ci_pipeline_run(id),
    name            TEXT NOT NULL,
    artifact_type   TEXT,                       -- 'test-results'|'coverage'|'build'|'binary'|'logs'
    size_bytes      INTEGER,
    download_url    TEXT,
    expires_at      TEXT,
    metadata        TEXT DEFAULT '{}'
);

-- CI test results (aggregated from test report artifacts)
CREATE TABLE ci_test_result (
    id              TEXT PRIMARY KEY,           -- UUID
    run_id          TEXT NOT NULL REFERENCES ci_pipeline_run(id),
    suite_name      TEXT,
    total           INTEGER NOT NULL DEFAULT 0,
    passed          INTEGER NOT NULL DEFAULT 0,
    failed          INTEGER NOT NULL DEFAULT 0,
    skipped         INTEGER NOT NULL DEFAULT 0,
    errored         INTEGER NOT NULL DEFAULT 0,
    duration_ms     INTEGER,
    report_url      TEXT,
    metadata        TEXT DEFAULT '{}'
);

-- ============================================================================
-- 7. AI AUDIT TRAIL
-- ============================================================================

CREATE TABLE ai_session (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    skill_name      TEXT,                       -- 'requirements-engineer', 'spec-auditor', etc.
    mode            TEXT,                       -- 'default', 'audit', 'fix', '--quick', etc.
    model           TEXT,                       -- 'claude-opus-4-6', 'claude-sonnet-4-20250514', etc.
    started_at      TEXT NOT NULL,
    finished_at     TEXT,
    status          TEXT NOT NULL DEFAULT 'running',  -- 'running'|'completed'|'aborted'|'error'
    total_turns     INTEGER DEFAULT 0,
    total_tokens    INTEGER DEFAULT 0,
    input_tokens    INTEGER DEFAULT 0,
    output_tokens   INTEGER DEFAULT 0,
    summary         TEXT,                       -- session summary text
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE ai_turn (
    id              TEXT PRIMARY KEY,           -- UUID
    session_id      TEXT NOT NULL REFERENCES ai_session(id),
    sequence        INTEGER NOT NULL,           -- 1-indexed turn number
    role            TEXT NOT NULL,              -- 'user'|'assistant'|'system'
    content_hash    TEXT,                       -- sha256 of content
    content_preview TEXT,                       -- first 500 chars
    token_count     INTEGER DEFAULT 0,
    timestamp       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE ai_tool_call (
    id              TEXT PRIMARY KEY,           -- UUID
    turn_id         TEXT NOT NULL REFERENCES ai_turn(id),
    tool_name       TEXT NOT NULL,              -- 'Read', 'Write', 'Edit', 'Bash', etc.
    input_hash      TEXT,
    input_preview   TEXT,                       -- first 300 chars of input
    output_hash     TEXT,
    output_preview  TEXT,                       -- first 300 chars of output
    status          TEXT DEFAULT 'success',     -- 'success'|'error'|'timeout'
    duration_ms     INTEGER,
    files_affected  TEXT DEFAULT '[]',          -- JSON array of file paths
    metadata        TEXT DEFAULT '{}'
);

CREATE TABLE ai_decision (
    id              TEXT PRIMARY KEY,           -- UUID
    session_id      TEXT NOT NULL REFERENCES ai_session(id),
    turn_id         TEXT REFERENCES ai_turn(id),
    description     TEXT NOT NULL,              -- what was decided
    options_presented TEXT,                     -- JSON array of options shown to user
    choice_made     TEXT NOT NULL,              -- which option was chosen
    rationale       TEXT,                       -- why this choice
    impact          TEXT,                       -- 'low'|'medium'|'high'|'critical'
    category        TEXT,                       -- 'architecture'|'requirement'|'implementation'|'process'
    artifacts_affected TEXT DEFAULT '[]',       -- JSON array of artifact IDs
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    metadata        TEXT DEFAULT '{}'
);

-- FTS on AI content for searching session history
-- Standalone FTS table — kept in sync via triggers
CREATE VIRTUAL TABLE ai_content_fts USING fts5(
    turn_id,
    session_id,
    content_preview
);

CREATE TRIGGER ai_turn_fts_insert AFTER INSERT ON ai_turn BEGIN
    INSERT INTO ai_content_fts(turn_id, session_id, content_preview)
    VALUES (new.id, new.session_id, new.content_preview);
END;

CREATE TRIGGER ai_turn_fts_update AFTER UPDATE ON ai_turn BEGIN
    DELETE FROM ai_content_fts WHERE turn_id = old.id;
    INSERT INTO ai_content_fts(turn_id, session_id, content_preview)
    VALUES (new.id, new.session_id, new.content_preview);
END;

CREATE TRIGGER ai_turn_fts_delete AFTER DELETE ON ai_turn BEGIN
    DELETE FROM ai_content_fts WHERE turn_id = old.id;
END;

-- ============================================================================
-- 8. TRACEABILITY LINKS (Unified)
-- ============================================================================
--
-- This is the SINGLE source of truth for ALL relationships in the system.
-- Every connection between any two entities flows through this table.
-- The entity types are open-ended (extensible via source_type/target_type).
--

CREATE TABLE traceability_link (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    source_id       TEXT NOT NULL,              -- ID of source entity
    source_type     TEXT NOT NULL,              -- 'artifact'|'symbol'|'commit'|'test_case'|'ci_run'|'ai_session'|'code_file'|'flow'
    target_id       TEXT NOT NULL,              -- ID of target entity
    target_type     TEXT NOT NULL,              -- same enum as source_type
    link_type       TEXT NOT NULL,              -- see LINK TYPES below
    origin          TEXT NOT NULL DEFAULT 'manual',
        -- 'manual'              — human-created
        -- 'inferred:commit-chain' — from Refs:/Task: trailers
        -- 'inferred:call-graph'   — from call graph analysis
        -- 'inferred:naming'       — from naming convention matching
        -- 'inferred:test-description' — from BDD/test text
        -- 'inferred:import-chain' — from import graph
        -- 'inferred:code-comment' — from Ref: comments in code
        -- 'inferred:ai-suggestion' — from AI analysis
        -- 'override'             — from human override table
    confidence      REAL NOT NULL DEFAULT 1.0 CHECK (confidence >= 0.0 AND confidence <= 1.0),
    suspect         BOOLEAN NOT NULL DEFAULT 0, -- DOORS-style suspect link
    suspect_reason  TEXT,                       -- why it became suspect
    suspect_since   TEXT,                       -- when it became suspect
    source_file     TEXT,                       -- file where link was found
    source_line     INTEGER,                    -- line where link was found
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_validated  TEXT,                       -- last time this link was confirmed valid
    invalidated_at  TEXT,                       -- set when link is broken (soft-delete)
    metadata        TEXT DEFAULT '{}'
);

-- ============================================================================
-- LINK TYPES reference:
--
--   implements       — UC implements REQ
--   orchestrates     — WF orchestrates API
--   verifies         — BDD verifies REQ/UC
--   guarantees       — INV guarantees domain rule
--   decides          — ADR decides architecture
--   decomposes       — TASK decomposes FASE
--   implemented-by   — TASK implements UC/API/INV
--   traces-to        — generic cross-reference
--   reads-from       — FASE reads spec artifacts
--   implemented-by-code    — code symbol references artifact
--   tested-by              — test verifies artifact
--   implemented-by-commit  — commit references artifact
--   inferred-implements    — transitive code→artifact link
--   produced-by     — evidence produced by test execution
--   triggered-by    — CI run triggered by commit
--   covers          — test covers symbol/file
--   depends-on      — symbol depends on another
--   calls           — symbol calls another
--   imports          — file imports another
--   supersedes      — new artifact supersedes old
--   derived-from    — artifact derived from another
--   constrained-by  — artifact constrained by NFR/INV
--   resolved-by     — finding resolved by commit/task
-- ============================================================================

-- ============================================================================
-- 9. OVERRIDES (Human corrections)
-- ============================================================================

CREATE TABLE override (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    operation       TEXT NOT NULL,              -- 'add'|'confirm'|'reject'|'exclude'|'suspect'|'unsuspect'
    link_id         TEXT REFERENCES traceability_link(id),  -- for ops on existing links
    source_id       TEXT,                       -- for 'add' ops
    source_type     TEXT,
    target_id       TEXT,
    target_type     TEXT,
    link_type       TEXT,
    reason          TEXT NOT NULL,
    created_by      TEXT NOT NULL,              -- user identifier or session_id
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    applied         BOOLEAN NOT NULL DEFAULT 0, -- whether the override has been applied
    applied_at      TEXT,
    metadata        TEXT DEFAULT '{}'
);

-- ============================================================================
-- 10. TAGS & LABELS (extensible classification)
-- ============================================================================

CREATE TABLE tag (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    name            TEXT NOT NULL,
    category        TEXT,                       -- 'domain'|'layer'|'priority'|'risk'|'custom'
    color           TEXT,                       -- hex color for UI
    UNIQUE(project_id, name, category)
);

CREATE TABLE entity_tag (
    tag_id          TEXT NOT NULL REFERENCES tag(id),
    entity_id       TEXT NOT NULL,
    entity_type     TEXT NOT NULL,              -- same enum as traceability_link source_type
    PRIMARY KEY (tag_id, entity_id, entity_type)
);

-- ============================================================================
-- 11. SNAPSHOTS (point-in-time captures)
-- ============================================================================

CREATE TABLE snapshot (
    id              TEXT PRIMARY KEY,           -- UUID
    project_id      TEXT NOT NULL REFERENCES project(id),
    name            TEXT NOT NULL,              -- 'v1.0.0-release', 'sprint-3-end', etc.
    snapshot_type   TEXT NOT NULL,              -- 'release'|'milestone'|'baseline'|'audit'
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    created_by      TEXT,
    commit_sha      TEXT,                       -- git SHA at snapshot time
    pipeline_state  TEXT,                       -- JSON: full pipeline-state.json at this moment
    statistics      TEXT,                       -- JSON: statistics block at this moment
    metadata        TEXT DEFAULT '{}'
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- === Artifact indexes ===
CREATE INDEX idx_artifact_project       ON artifact(project_id);
CREATE INDEX idx_artifact_type          ON artifact(project_id, type);
CREATE INDEX idx_artifact_stage         ON artifact(project_id, stage);
CREATE INDEX idx_artifact_status        ON artifact(project_id, status);
CREATE INDEX idx_artifact_file          ON artifact(project_id, file_path);
CREATE INDEX idx_artifact_category      ON artifact(project_id, type, category);

-- === Classification indexes ===
CREATE INDEX idx_classification_domain  ON artifact_classification(project_id, business_domain);
CREATE INDEX idx_classification_layer   ON artifact_classification(project_id, technical_layer);
CREATE INDEX idx_classification_category ON artifact_classification(project_id, functional_category);

-- === Code intelligence indexes ===
CREATE INDEX idx_code_file_project      ON code_file(project_id);
CREATE INDEX idx_code_file_path         ON code_file(project_id, path);
CREATE INDEX idx_code_file_language     ON code_file(project_id, language);
CREATE INDEX idx_symbol_project         ON symbol(project_id);
CREATE INDEX idx_symbol_file            ON symbol(file_id);
CREATE INDEX idx_symbol_name            ON symbol(project_id, name);
CREATE INDEX idx_symbol_kind            ON symbol(project_id, kind);
CREATE INDEX idx_symbol_exported        ON symbol(project_id, is_exported) WHERE is_exported = 1;
CREATE INDEX idx_call_edge_caller       ON call_edge(caller_id);
CREATE INDEX idx_call_edge_callee       ON call_edge(callee_id);
CREATE INDEX idx_call_edge_project      ON call_edge(project_id);
CREATE INDEX idx_import_edge_importer   ON import_edge(importer_id);
CREATE INDEX idx_import_edge_imported   ON import_edge(imported_id);
CREATE INDEX idx_symbol_ref_symbol      ON symbol_reference(symbol_id);
CREATE INDEX idx_symbol_ref_file        ON symbol_reference(file_id);

-- === Commit indexes ===
CREATE INDEX idx_commit_project         ON git_commit(project_id);
CREATE INDEX idx_commit_date            ON git_commit(project_id, author_date);
CREATE INDEX idx_commit_branch          ON git_commit(project_id, branch);
CREATE INDEX idx_commit_task            ON git_commit(project_id, task_id);
CREATE INDEX idx_commit_cc_type         ON git_commit(project_id, cc_type);
CREATE INDEX idx_commit_file_sha        ON commit_file(commit_sha, project_id);
CREATE INDEX idx_commit_file_path       ON commit_file(file_path);
CREATE INDEX idx_commit_artifact_ref    ON commit_artifact_ref(project_id, artifact_id);

-- === Test indexes ===
CREATE INDEX idx_test_run_project       ON test_run(project_id);
CREATE INDEX idx_test_run_status        ON test_run(project_id, status);
CREATE INDEX idx_test_run_commit        ON test_run(commit_sha);
CREATE INDEX idx_test_case_project      ON test_case(project_id);
CREATE INDEX idx_test_case_file         ON test_case(project_id, file_path);
CREATE INDEX idx_test_exec_run          ON test_execution(test_run_id);
CREATE INDEX idx_test_exec_case         ON test_execution(test_case_id);
CREATE INDEX idx_test_exec_result       ON test_execution(result);
CREATE INDEX idx_test_evidence_exec     ON test_evidence(test_execution_id);
CREATE INDEX idx_coverage_run           ON coverage_report(test_run_id);
CREATE INDEX idx_coverage_file_report   ON coverage_file(coverage_report_id);

-- === CI/CD indexes ===
CREATE INDEX idx_ci_run_project         ON ci_pipeline_run(project_id);
CREATE INDEX idx_ci_run_commit          ON ci_pipeline_run(commit_sha);
CREATE INDEX idx_ci_run_status          ON ci_pipeline_run(project_id, status);
CREATE INDEX idx_ci_job_run             ON ci_job(run_id);
CREATE INDEX idx_ci_step_job            ON ci_step(job_id);
CREATE INDEX idx_ci_artifact_run        ON ci_artifact(run_id);
CREATE INDEX idx_ci_test_result_run     ON ci_test_result(run_id);

-- === AI audit indexes ===
CREATE INDEX idx_ai_session_project     ON ai_session(project_id);
CREATE INDEX idx_ai_session_skill       ON ai_session(project_id, skill_name);
CREATE INDEX idx_ai_session_status      ON ai_session(status);
CREATE INDEX idx_ai_turn_session        ON ai_turn(session_id);
CREATE INDEX idx_ai_turn_seq            ON ai_turn(session_id, sequence);
CREATE INDEX idx_ai_tool_turn           ON ai_tool_call(turn_id);
CREATE INDEX idx_ai_tool_name           ON ai_tool_call(tool_name);
CREATE INDEX idx_ai_decision_session    ON ai_decision(session_id);

-- === Traceability link indexes (most critical for query performance) ===
CREATE INDEX idx_link_project           ON traceability_link(project_id);
CREATE INDEX idx_link_source            ON traceability_link(project_id, source_id, source_type);
CREATE INDEX idx_link_target            ON traceability_link(project_id, target_id, target_type);
CREATE INDEX idx_link_type              ON traceability_link(project_id, link_type);
CREATE INDEX idx_link_source_target     ON traceability_link(source_id, target_id, link_type);
CREATE INDEX idx_link_suspect           ON traceability_link(project_id, suspect) WHERE suspect = 1;
CREATE INDEX idx_link_origin            ON traceability_link(project_id, origin);
CREATE INDEX idx_link_confidence        ON traceability_link(project_id, confidence);
CREATE INDEX idx_link_valid             ON traceability_link(project_id, invalidated_at) WHERE invalidated_at IS NULL;

-- === Override indexes ===
CREATE INDEX idx_override_project       ON override(project_id);
CREATE INDEX idx_override_link          ON override(link_id);
CREATE INDEX idx_override_applied       ON override(project_id, applied);

-- === Tag indexes ===
CREATE INDEX idx_tag_project            ON tag(project_id);
CREATE INDEX idx_entity_tag_entity      ON entity_tag(entity_id, entity_type);

-- === Snapshot indexes ===
CREATE INDEX idx_snapshot_project       ON snapshot(project_id);
CREATE INDEX idx_snapshot_type          ON snapshot(project_id, snapshot_type);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- ---------------------------------------------------------------------------
-- V1: Artifact with classification (denormalized for easy querying)
-- ---------------------------------------------------------------------------
CREATE VIEW v_artifact_full AS
SELECT
    a.id,
    a.project_id,
    a.type,
    a.category,
    a.title,
    a.file_path,
    a.line,
    a.priority,
    a.status,
    a.stage,
    a.content_hash,
    a.ears_syntax,
    a.created_at,
    a.updated_at,
    ac.business_domain,
    ac.technical_layer,
    ac.functional_category
FROM artifact a
LEFT JOIN artifact_classification ac
    ON a.id = ac.artifact_id AND a.project_id = ac.project_id;

-- ---------------------------------------------------------------------------
-- V2: Traceability coverage per REQ (does this REQ have UC, BDD, TASK, code, test, commit?)
-- ---------------------------------------------------------------------------
CREATE VIEW v_req_coverage AS
SELECT
    a.id AS req_id,
    a.project_id,
    a.title,
    ac.business_domain,
    ac.technical_layer,
    ac.functional_category,
    -- Has UC?
    EXISTS(SELECT 1 FROM traceability_link tl
           WHERE tl.project_id = a.project_id
             AND tl.target_id = a.id AND tl.target_type = 'artifact'
             AND tl.source_type = 'artifact' AND tl.link_type = 'implements'
             AND tl.invalidated_at IS NULL) AS has_uc,
    -- Has BDD?
    EXISTS(SELECT 1 FROM traceability_link tl
           WHERE tl.project_id = a.project_id
             AND tl.target_id = a.id AND tl.target_type = 'artifact'
             AND tl.source_type = 'artifact' AND tl.link_type = 'verifies'
             AND tl.invalidated_at IS NULL) AS has_bdd,
    -- Has TASK?
    EXISTS(SELECT 1 FROM traceability_link tl
           JOIN artifact ta ON ta.id = tl.source_id AND ta.project_id = tl.project_id AND ta.type = 'TASK'
           WHERE tl.project_id = a.project_id
             AND (tl.target_id = a.id OR tl.target_id IN (
                 SELECT tl2.source_id FROM traceability_link tl2
                 WHERE tl2.target_id = a.id AND tl2.project_id = a.project_id
                   AND tl2.link_type = 'implements' AND tl2.invalidated_at IS NULL
             ))
             AND tl.invalidated_at IS NULL) AS has_task,
    -- Has code?
    EXISTS(SELECT 1 FROM traceability_link tl
           WHERE tl.project_id = a.project_id
             AND tl.target_id = a.id AND tl.target_type = 'artifact'
             AND tl.source_type = 'symbol' AND tl.link_type = 'implemented-by-code'
             AND tl.invalidated_at IS NULL) AS has_code,
    -- Has test?
    EXISTS(SELECT 1 FROM traceability_link tl
           WHERE tl.project_id = a.project_id
             AND tl.target_id = a.id AND tl.target_type = 'artifact'
             AND tl.source_type = 'test_case' AND tl.link_type = 'tested-by'
             AND tl.invalidated_at IS NULL) AS has_test,
    -- Has commit?
    EXISTS(SELECT 1 FROM traceability_link tl
           WHERE tl.project_id = a.project_id
             AND tl.target_id = a.id AND tl.target_type = 'artifact'
             AND tl.source_type = 'commit' AND tl.link_type = 'implemented-by-commit'
             AND tl.invalidated_at IS NULL) AS has_commit
FROM artifact a
LEFT JOIN artifact_classification ac
    ON a.id = ac.artifact_id AND a.project_id = ac.project_id
WHERE a.type = 'REQ' AND a.status = 'active';

-- ---------------------------------------------------------------------------
-- V3: Suspect links dashboard
-- ---------------------------------------------------------------------------
CREATE VIEW v_suspect_links AS
SELECT
    tl.id AS link_id,
    tl.project_id,
    tl.source_id,
    tl.source_type,
    tl.target_id,
    tl.target_type,
    tl.link_type,
    tl.origin,
    tl.confidence,
    tl.suspect_reason,
    tl.suspect_since,
    tl.created_at,
    tl.last_validated,
    sa.title AS source_title,
    ta.title AS target_title
FROM traceability_link tl
LEFT JOIN artifact sa ON sa.id = tl.source_id AND sa.project_id = tl.project_id
LEFT JOIN artifact ta ON ta.id = tl.target_id AND ta.project_id = tl.project_id
WHERE tl.suspect = 1
  AND tl.invalidated_at IS NULL;

-- ---------------------------------------------------------------------------
-- V4: Symbol coverage (which symbols have SDD artifact refs?)
-- ---------------------------------------------------------------------------
CREATE VIEW v_symbol_coverage AS
SELECT
    s.id AS symbol_id,
    s.project_id,
    s.name,
    s.kind,
    s.qualified_name,
    cf.path AS file_path,
    s.start_line,
    s.end_line,
    s.is_exported,
    s.community,
    -- Direct artifact references
    (SELECT COUNT(*) FROM traceability_link tl
     WHERE tl.source_id = s.id AND tl.source_type = 'symbol'
       AND tl.target_type = 'artifact' AND tl.origin = 'inferred:code-comment'
       AND tl.invalidated_at IS NULL) AS direct_ref_count,
    -- Inferred artifact references
    (SELECT COUNT(*) FROM traceability_link tl
     WHERE tl.source_id = s.id AND tl.source_type = 'symbol'
       AND tl.target_type = 'artifact' AND tl.origin LIKE 'inferred:%'
       AND tl.origin != 'inferred:code-comment'
       AND tl.invalidated_at IS NULL) AS inferred_ref_count,
    -- Total callers
    (SELECT COUNT(*) FROM call_edge ce WHERE ce.callee_id = s.id) AS caller_count,
    -- Total callees
    (SELECT COUNT(*) FROM call_edge ce WHERE ce.caller_id = s.id) AS callee_count
FROM symbol s
JOIN code_file cf ON s.file_id = cf.id;

-- ---------------------------------------------------------------------------
-- V5: Commit traceability (which commits reference which artifacts?)
-- ---------------------------------------------------------------------------
CREATE VIEW v_commit_traceability AS
SELECT
    c.sha,
    c.short_sha,
    c.project_id,
    c.subject,
    c.author_name,
    c.author_date,
    c.task_id,
    c.cc_type,
    c.cc_scope,
    c.cc_breaking,
    c.files_added + c.files_modified + c.files_deleted AS total_files_changed,
    c.lines_added,
    c.lines_deleted,
    -- Count of artifact references
    (SELECT COUNT(DISTINCT artifact_id) FROM commit_artifact_ref car
     WHERE car.commit_sha = c.sha AND car.project_id = c.project_id) AS artifact_ref_count,
    -- Artifact IDs (comma-separated)
    (SELECT GROUP_CONCAT(DISTINCT artifact_id) FROM commit_artifact_ref car
     WHERE car.commit_sha = c.sha AND car.project_id = c.project_id) AS artifact_ids
FROM git_commit c;

-- ---------------------------------------------------------------------------
-- V6: Test case traceability (which tests verify which artifacts?)
-- ---------------------------------------------------------------------------
CREATE VIEW v_test_traceability AS
SELECT
    tc.id AS test_case_id,
    tc.project_id,
    tc.test_name,
    tc.suite_name,
    tc.file_path,
    tc.framework,
    -- Latest execution result
    (SELECT te.result FROM test_execution te
     JOIN test_run tr ON te.test_run_id = tr.id
     WHERE te.test_case_id = tc.id
     ORDER BY tr.started_at DESC LIMIT 1) AS latest_result,
    -- Latest execution duration
    (SELECT te.duration_ms FROM test_execution te
     JOIN test_run tr ON te.test_run_id = tr.id
     WHERE te.test_case_id = tc.id
     ORDER BY tr.started_at DESC LIMIT 1) AS latest_duration_ms,
    -- Count of artifact refs
    (SELECT COUNT(*) FROM traceability_link tl
     WHERE tl.source_id = tc.id AND tl.source_type = 'test_case'
       AND tl.target_type = 'artifact'
       AND tl.invalidated_at IS NULL) AS artifact_ref_count,
    -- Artifact IDs
    (SELECT GROUP_CONCAT(DISTINCT tl.target_id) FROM traceability_link tl
     WHERE tl.source_id = tc.id AND tl.source_type = 'test_case'
       AND tl.target_type = 'artifact'
       AND tl.invalidated_at IS NULL) AS artifact_ids
FROM test_case tc;

-- ---------------------------------------------------------------------------
-- V7: Pipeline status summary
-- ---------------------------------------------------------------------------
CREATE VIEW v_pipeline_status AS
SELECT
    ps.project_id,
    p.name AS project_name,
    ps.name AS stage_name,
    ps.stage_type,
    ps.status,
    ps.last_run,
    ps.artifact_count,
    ps.stage_label,
    ps.stale_reason,
    ps.sort_order
FROM pipeline_stage ps
JOIN project p ON ps.project_id = p.id
ORDER BY ps.project_id, ps.sort_order;

-- ---------------------------------------------------------------------------
-- V8: AI session summary
-- ---------------------------------------------------------------------------
CREATE VIEW v_ai_session_summary AS
SELECT
    s.id AS session_id,
    s.project_id,
    s.skill_name,
    s.mode,
    s.model,
    s.started_at,
    s.finished_at,
    s.status,
    s.total_turns,
    s.total_tokens,
    -- Decision count
    (SELECT COUNT(*) FROM ai_decision ad WHERE ad.session_id = s.id) AS decision_count,
    -- Tool call count
    (SELECT COUNT(*) FROM ai_tool_call atc
     JOIN ai_turn at2 ON atc.turn_id = at2.id
     WHERE at2.session_id = s.id) AS tool_call_count,
    -- Files affected (distinct)
    (SELECT COUNT(DISTINCT value) FROM ai_tool_call atc
     JOIN ai_turn at2 ON atc.turn_id = at2.id,
     json_each(atc.files_affected)
     WHERE at2.session_id = s.id) AS files_affected_count
FROM ai_session s;

-- ---------------------------------------------------------------------------
-- V9: Coverage gap analysis by domain
-- ---------------------------------------------------------------------------
CREATE VIEW v_coverage_gaps_by_domain AS
SELECT
    rc.project_id,
    rc.business_domain,
    COUNT(*) AS total_reqs,
    SUM(rc.has_uc) AS reqs_with_uc,
    SUM(rc.has_bdd) AS reqs_with_bdd,
    SUM(rc.has_task) AS reqs_with_task,
    SUM(rc.has_code) AS reqs_with_code,
    SUM(rc.has_test) AS reqs_with_test,
    SUM(rc.has_commit) AS reqs_with_commit,
    ROUND(100.0 * SUM(rc.has_uc) / COUNT(*), 1) AS uc_pct,
    ROUND(100.0 * SUM(rc.has_bdd) / COUNT(*), 1) AS bdd_pct,
    ROUND(100.0 * SUM(rc.has_code) / COUNT(*), 1) AS code_pct,
    ROUND(100.0 * SUM(rc.has_test) / COUNT(*), 1) AS test_pct
FROM v_req_coverage rc
WHERE rc.functional_category = 'Functional'
GROUP BY rc.project_id, rc.business_domain;

-- ---------------------------------------------------------------------------
-- V10: Orphan artifacts (no incoming or outgoing links)
-- ---------------------------------------------------------------------------
CREATE VIEW v_orphan_artifacts AS
SELECT
    a.id,
    a.project_id,
    a.type,
    a.title,
    a.file_path,
    a.stage
FROM artifact a
WHERE a.status = 'active'
  AND NOT EXISTS (
      SELECT 1 FROM traceability_link tl
      WHERE tl.project_id = a.project_id
        AND (
            (tl.source_id = a.id AND tl.source_type = 'artifact')
            OR (tl.target_id = a.id AND tl.target_type = 'artifact')
        )
        AND tl.invalidated_at IS NULL
  );

-- ---------------------------------------------------------------------------
-- V11: CI/CD health per project
-- ---------------------------------------------------------------------------
CREATE VIEW v_ci_health AS
SELECT
    cr.project_id,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN cr.conclusion = 'success' THEN 1 ELSE 0 END) AS successful_runs,
    SUM(CASE WHEN cr.conclusion = 'failure' THEN 1 ELSE 0 END) AS failed_runs,
    ROUND(100.0 * SUM(CASE WHEN cr.conclusion = 'success' THEN 1 ELSE 0 END) / COUNT(*), 1) AS success_rate,
    AVG(cr.duration_ms) AS avg_duration_ms,
    MAX(cr.finished_at) AS last_run_at
FROM ci_pipeline_run cr
WHERE cr.status NOT IN ('queued', 'in_progress')
GROUP BY cr.project_id;

-- ---------------------------------------------------------------------------
-- V12: Flaky tests (tests that have both pass and fail in recent history)
-- ---------------------------------------------------------------------------
CREATE VIEW v_flaky_tests AS
SELECT
    tc.id AS test_case_id,
    tc.project_id,
    tc.test_name,
    tc.file_path,
    COUNT(DISTINCT te.result) AS distinct_results,
    SUM(CASE WHEN te.result = 'pass' THEN 1 ELSE 0 END) AS pass_count,
    SUM(CASE WHEN te.result = 'fail' THEN 1 ELSE 0 END) AS fail_count,
    COUNT(*) AS total_executions
FROM test_case tc
JOIN test_execution te ON te.test_case_id = tc.id
JOIN test_run tr ON te.test_run_id = tr.id
GROUP BY tc.id, tc.project_id, tc.test_name, tc.file_path
HAVING COUNT(DISTINCT te.result) > 1
   AND SUM(CASE WHEN te.result = 'pass' THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN te.result = 'fail' THEN 1 ELSE 0 END) > 0;
