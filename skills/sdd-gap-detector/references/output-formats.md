# Output formats

## 1. `.sdd/gap-analysis.json`

`$schema` stays `"sdd-gap-analysis-v1"`: the MCP tool `sdd_gaps` (server/src/tools/gaps.ts) recognises the file by
that value or by the `endpoints`/`bddCoverage` objects, and reads `endpoints.{missing,orphan,mismatch}`,
`bddCoverage.missing`, `projectFramework`, `generatedAt` and `statistics`. Keep those keys and shapes. `semantic`
is an optional additive section (present only after `--semantic`); readers that do not know it ignore it, so
adding it needs no schema bump. Change `$schema` only for a breaking change to the keys above, and then update
gaps.ts in the same change.

```json
{
  "$schema": "sdd-gap-analysis-v1",
  "generatedAt": "ISO-8601",
  "projectFramework": "express|fastify|hono|nextjs|nextjs-actions|flask|fastapi|django|rails|unknown",
  "endpoints": {
    "specified":   [{"id": "API-001-05", "method": "POST", "path": "/api/users", "specFile": "spec/contracts/API-users.md:24"}],
    "implemented": [{"id": "API-001-05", "method": "POST", "path": "/api/users", "codeFile": "src/routes/users.ts", "handler": "createUser", "line": 45}],
    "missing":     [{"id": "API-001-12", "method": "DELETE", "path": "/api/users/:id", "specFile": "spec/contracts/API-users.md:38",
                     "nearMatch": "DELETE /admin/users/:id (src/routes/admin.ts:12)"}],
    "orphan":      [{"method": "GET", "path": "/api/legacy", "codeFile": "src/routes/legacy.ts", "handler": "getLegacy", "line": 12}],
    "mismatch":    [{"id": "API-001-03", "issue": "Spec expects field 'email', code uses 'mail'", "specFile": "spec/contracts/API-users.md:15", "codeFile": "src/routes/users.ts:30"}]
  },
  "bddCoverage": {"totalScenarios": 50, "withTestFiles": 42, "withoutTestFiles": 8, "missing": ["BDD-020", "BDD-033"]},
  "statistics": {
    "totalSpecEndpoints": 20, "implemented": 18, "missing": 2, "orphanRoutes": 3, "mismatches": 1,
    "endpointCoveragePercent": 90.0, "bddCoveragePercent": 84.0
  },
  "semantic": {
    "generatedAt": "ISO-8601",
    "judge": "jev|llm",
    "model": "jev-latest",
    "thresholds": {"covered": 0.85, "missing": 0.15, "relatedMax": 0.3, "splitBand": [0.3, 0.6], "maxFilesPerReq": 5},
    "requirements": [
      {"id": "REQ-F-012", "status": "covered", "decidedBy": "jev",
       "origin": "llm-verified", "confidence": 0.93, "evidence": "src/services/users.ts:40-88",
       "scores": {"implements": 0.93, "partial": 0.08, "related": 0.97}, "chunksChecked": 4},
      {"id": "REQ-F-020", "status": "partial", "decidedBy": "llm",
       "evidence": "src/routes/orders.ts:10-52 handles creation; the refund error case of the criteria is absent",
       "scores": {"implements": 0.45, "partial": 0.71, "related": 0.9}, "chunksChecked": 5, "reason": "split"},
      {"id": "REQ-F-031", "status": "likely-missing", "decidedBy": "jev",
       "scores": {"implements": 0.04, "partial": 0.03, "related": 0.12}, "chunksChecked": 3},
      {"id": "REQ-F-040", "status": "no-candidates", "decidedBy": "search", "chunksChecked": 0}
    ],
    "summary": {"targets": 14, "covered": 6, "partial": 2, "likelyMissing": 3, "noCandidates": 1, "reviewedByLlm": 5}
  }
}
```

`semantic.requirements[].status`: `covered` · `partial` · `likely-missing` · `no-candidates`. `decidedBy`: `jev`
(a threshold rule decided), `llm` (you decided after reading the chunks, or the whole pass ran in fallback) or
`search` (nothing to judge). `origin`/`confidence`/`evidence` appear on `covered` entries; `origin` is always
`"llm-verified"`: `scripts/sdd-graph.py` turns each `covered` entry with `path:start-end` evidence into a
`llm-verified` codeRef on that REQ, below direct refs (`docs/design/graph-schema.md` in the plugin). `reason` on
LLM-decided entries: `split` (several chunks in the 0.3-0.6 band), `uncertain` (between the thresholds) or
`fallback` (Jev disabled). `nearMatch` on a missing endpoint is optional: the closest route that failed the
segment-aligned rule, for the human to judge.

## 2. Console summary

```
## Gap Analysis Summary

| Metric                      | Count | %     |
|-----------------------------|-------|-------|
| Specified endpoints         | 20    |       |
| Implemented endpoints       | 18    | 90.0% |
| Missing endpoints           | 2     | 10.0% |
| Orphan routes (unspecified) | 3     |       |
| Schema mismatches           | 1     |       |
| BDD scenarios with tests    | 42/50 | 84.0% |
| Semantic: REQs covered      | 6/14  |       |   ← only with --semantic

Then one table each for Missing endpoints (ID, Method, Path, Spec file), Orphan routes (Method, Path, Code file,
Handler), Mismatches (ID, Issue, Spec file, Code file), Uncovered BDD scenarios (IDs), and with --semantic
Requirements not covered (REQ, Status, Decided by, Evidence or best score).
```

## 3. `audits/GAP-ANALYSIS-REVIEW.md`

Header: date, source `.sdd/gap-analysis.json`, then this legend:

| Decision | Meaning | Action |
|----------|---------|--------|
| **PROMOTE** | The feature is valuable: make it a formal REQ via `/sdd-req-change` | Create REQ, update specs, keep code |
| **REMOVE** | The feature was not requested | Delete code, update tests |
| **ACCEPT** | Keep as-is without a formal REQ | No code change; the rationale documents it |
| **DEFER** | Decide later | No action now |

One entry per ORPHAN, MISSING, MISMATCH and uncovered BDD finding:

```markdown
### {TYPE}-{NNN}: {Short title}
- **File:** `{file path}:{line}`
- **Origin:** {where the code/spec came from: REQ, audit recommendation, implementation decision}
- **What it does:** {brief description}
- **Why it's {orphan|missing|schema drift}:** {explanation referencing the REQ or spec gap}
- **Risk of {removing|not implementing|keeping as-is}:** {concrete consequence}
- **Decision:** `________` **Rationale:** _______________________
```

With `--semantic`, add a section `## Requirements without verified implementation` with one entry per `partial`,
`likely-missing` and `no-candidates` requirement (REQ, statement, status, decided by, evidence or best chunk and
its scores, candidate files checked), and a short list of the `covered` ones with their evidence, so the human can
add `// Refs: REQ-…` comments or dismiss a wrong match. For these entries the decisions are IMPLEMENT (task via
`/sdd-task-generator --fase=N --incremental`), AMEND (spec change via `/sdd-req-change`), ACCEPT or DEFER.

Footer:

```
## How to process this document
1. Review each finding and write a decision and rationale
2. PROMOTE / AMEND: run `/sdd-req-change`
3. REMOVE: delete the code and update affected tests
4. IMPLEMENT: generate the task with `/sdd-task-generator --fase=N --incremental`
5. ACCEPT: no code change; the rationale is the documentation
6. Commit this document with the decisions as the audit trail
```

Notes for specific origins: an orphan that comes from a security-audit recommendation says "Origin: audit
recommendation, not a formal REQ"; testing infrastructure (`NODE_ENV` guards, test env vars) says "Origin:
implementation convenience for testability".
