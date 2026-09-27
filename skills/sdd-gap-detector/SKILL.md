---
name: sdd-gap-detector
description: "Spec-vs-code gaps: missing endpoints, orphan routes, schema mismatches, untested BDD; --semantic judges whether code implements each requirement. Triggers: 'detect gaps', 'what's not implemented', 'orphan code', 'gap analysis', 'verify coverage', 'check implementation', 'are requirements implemented', 'qué falta por implementar', 'código huérfano', 'verificar cobertura'."
allowed-tools: Read, Grep, Glob, Write, Bash(node:*), Bash(mkdir:*), Bash(git log:*), Bash(git rev-parse:*), Bash(bin/rails routes:*)
---

# SDD Gap Detector

Objective gap analysis between the SDD specifications and the code: what the spec says the system should do versus
what the code does. The structural phases (1-4) compare contracts, routes and tests with regex parsers; the
semantic phase (S, `--semantic`) asks, per requirement, whether some code actually implements it.

Code and test paths come from the SDD Stack Profile (`code_paths` / `test_paths` in the project's `CLAUDE.md`, see
`skills/sdd-task-implementer/references/stack-profile.md`); `src/` and `tests/` are only defaults. Needs at least
one of `spec/contracts/`, `spec/use-cases/`, BDD scenarios (or `requirements/` for `--semantic`); partial specs are
fine — report what could not be checked.

## Modes

| Mode | Flag | Runs |
|------|------|------|
| Full | (default) | Phases 1-5: endpoints, BDD, orphans, review document |
| Endpoints | `--endpoints` | Endpoint analysis only (contracts vs routes) |
| BDD | `--bdd` | BDD coverage only (scenarios vs test files) |
| Summary | `--summary` | Statistics only, no detailed listings |
| Semantic | `--semantic` | Full + Phase S (requirement-level implementation check) |

## Phase 1: Spec manifest (what the system should do)

1. **Endpoints** — from `spec/contracts/API-*.md`: tables whose header has `Method` and `Path` (or `Endpoint`,
   `Route`), or the `Style: operations` table (`references/language-parsers.md` §8, §8b). Record `id` (API ID or
   method+path), `method`, `path`, `specFile:line`, request/response field names and status codes when documented.
2. **Use cases** — `spec/use-cases/UC-*.md`: map `UC-ID → [API-IDs, BDD-IDs]`.
3. **BDD scenarios** — `spec/tests/BDD-UC-*.md`, gherkin blocks in use cases, `**/*.feature`: `id` (BDD ID or
   scenario name), `scenarioName`, `specFile:line`.

Missing sources are noted ("No API contracts found — endpoint analysis skipped") and the rest continues. If none
exist (and no `requirements/` for `--semantic`), stop: "No spec artifacts found. Run the SDD pipeline first
(start with /sdd-requirements-engineer)."

## Phase 2: Code manifest (what the system does)

Scan the current checkout only, excluding `node_modules/`, build output and `.claude/worktrees/**` (ephemeral
worktrees with unmerged Stream branches would otherwise show up as ORPHAN or be counted twice).

1. **Framework** — detect every framework present:

   | Signal | Framework |
   |--------|-----------|
   | `package.json` dep `express` / `fastify` / `hono` / `next` | Express / Fastify / Hono / Next.js |
   | `app/api/*/route.{ts,js}` | Next.js App Router |
   | `"use server"` under `app/**` or `src/**` | Next.js Server Actions |
   | `flask` / `fastapi` in `pyproject.toml` or `requirements.txt` | Flask / FastAPI |
   | `manage.py` or `urls.py` | Django |
   | `Gemfile` with `rails` + `config/routes.rb` | Rails (`bin/rails routes --expanded`, static fallback) |

   None detected → `projectFramework: "unknown"` and try all parsers.
2. **Routes** — apply `references/language-parsers.md` to the Stack Profile `code_paths` plus framework locations
   outside them (`app/api/**`, `**/urls.py`, `routes/**`, `api/**`). Record `method`, `path` (with router mount
   prefixes applied), `codeFile`, `handler`, `line`.
3. **Exports** — exported functions/classes (JS/TS `export …`, top-level non-underscore Python `def`/`class`) as
   context for orphan analysis.
4. **Tests** — files under `test_paths` (`*.test.*`, `*.spec.*`, `test_*.py`, `*.feature`) with their
   describe/it/test names and scenario names.

## Phase 3: Structural gap analysis

**MISSING endpoints.** A spec endpoint matches a route with the same method and an equivalent path:
- parameter syntax is equivalent: `/users/:id` = `/users/{id}` = `/users/[id]` = `/users/<int:id>`;
- the code path may add a *mount prefix* in front of the spec path, aligned on whole segments: segments made only
  of `api` and version markers (`v1`, `v2`…), or a prefix the code applies to every route (global router mount,
  Rails `scope`). Spec `/users` matches `/api/users` and `/api/v1/users`, but not `/admin/users` or `/superusers`
  — a namespace such as `/admin` is a different resource.

No match → MISSING; when a route failed only the prefix rule, add it as `nearMatch` for the human.
`Style: operations` contracts compare API-op ↔ `design/OPERATION-MAPPING.md` row ↔ route/action
(`references/language-parsers.md` §8b); method + path equality applies only to `Style: http`.

**ORPHAN routes.** Routes with no spec endpoint (same matching rules), excluding infrastructure routes
(`references/language-parsers.md` §10: health, docs, metrics, `/up`, `/rails/*`, `/cable`, `/_next/*`).

**MISMATCH.** For matched endpoints compare field names, method variants and status codes (e.g. spec 201, code
200). Regex-based and best-effort: give each mismatch a confidence.

**BDD coverage.** A scenario is covered when a `.feature` file or a test block references its ID or name, or a
test file name correlates with its UC/BDD ID; otherwise it is uncovered.

## Phase S: Semantic check (`--semantic`)

Answers "is this requirement implemented?" for the requirements the structural phases cannot vouch for. The
decision rules below are applied by you; Jev only supplies probabilities.

**S.1 Targets.** Read `requirements/REQUIREMENTS.md`: per `REQ-*` block take the statement and its acceptance
criteria. Read `dashboard/traceability-graph.json` if present (`artifacts[]` with `codeRefs[]`,
`classification.businessDomain`; `relationships[]` with `source`/`target`). A REQ is **covered** when a codeRef has
origin `direct` or `manual-override`, or `commit-inferred` with confidence ≥ 0.8;
**weakly covered** when its only refs are `task-inferred`, `blame-inferred`, `propagated` or lower-confidence
inferred ones; **uncovered** with no refs. Targets = weakly covered + uncovered + covered REQs whose UCs lead to a
MISSING endpoint or an uncovered BDD scenario. Without the graph every REQ is a target: say so, and suggest
running `python3 "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-graph.py"` first for a narrower pass. `REQ-C-*` constraints and `REQ-NF-*` that no single code location can
implement (performance, availability) are listed as "not checkable by code reading" instead.

**S.2 Candidates** (at most 5 files per REQ, non-test, non-config, no barrel/index re-exports), in order:
1. files on the task lines / `Files:` of tasks that reference the REQ or its UCs (`task/TASK-FASE-*.md`), the files
   of its weak codeRefs, and the files of commits whose `Task`/`Refs`/`Change` name the REQ, its UCs or those tasks
   (one call: `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" trace commits --files --json`; exact
   ids, skip `effective: false`);
2. keyword search in `code_paths`: significant terms of the statement (drop EARS keywords and stop words) plus the
   business domain; rank files by hits.
No candidate → status `no-candidates`.

**S.3 Items.** Split whole files (not first-N lines) and build one JSONL item per (REQ, chunk):

```bash
JEV="${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-jev.mjs"   # same resolution as sdd-setup "Locating the plugin root"
mkdir -p .sdd/jev
node "$JEV" chunks src/a.ts src/b.ts > .sdd/jev/chunks-REQ-F-012.jsonl
node -e 'const fs=require("fs"),r=JSON.parse(process.argv[1]);for(const l of fs.readFileSync(0,"utf8").split("\n").filter(Boolean)){const c=JSON.parse(l);console.log(JSON.stringify({id:r.id+"|"+c.id,state:{requirement:r,code:{path:c.path,start:c.start,end:c.end,code:c.code}}}))}' \
  '{"id":"REQ-F-012","statement":"WHEN …","criteria":["…"]}' < .sdd/jev/chunks-REQ-F-012.jsonl >> .sdd/jev/items.jsonl
```

**S.4 Judge.** `node "$JEV" status`:
- exit 0 → `node "$JEV" judge --questions "$(dirname "$JEV")/jev/coverage.json" --items .sdd/jev/items.jsonl --out .sdd/jev-coverage.json`.
  Output `{model, items: [{id, answers: {implements, partial, related}}], errors, usage}`, each answer a
  probability. Items in `errors` (exit 1) are judged by you with the fallback prompt. Privacy: this sends the
  chunks to api.typesafe.ai; setting `TYPESAFE_API_KEY` is the opt-in, and `SDD_JEV=off` disables it for projects
  whose code must not leave the machine. Say how many chunks will be sent before the call.
- exit 3 (no key or `SDD_JEV=off`) → fallback: judge each (REQ, chunk) yourself with the template in
  `references/verification-prompt.md`; your `confidence` stands in for `implements`, and `related` is your
  judgment of whether the chunk is about the same feature.

**S.5 Decide per REQ** (p = max `implements` over its chunks):

| Condition | Status |
|-----------|--------|
| p ≥ 0.85 | `covered` — origin `llm-verified`, confidence = p, evidence = best chunk `path:start-end` |
| p ≤ 0.15 and max `related` ≤ 0.3 | `likely-missing` |
| two or more chunks each with `implements` in 0.3-0.6 (behaviour split across files; Jev is weak at multi-hop) | you read those chunks together and decide (`reason: split`) |
| anything else | you read the top chunks (by `implements`, then `partial`) and decide (`reason: uncertain`) |

The split rule wins over the other two. When you decide, the outcome is `covered`, `partial` or `likely-missing`,
with evidence. Low scores are never proof of absence on their own.

## Phase 4: Write results

Read `references/output-formats.md` before writing. Write `.sdd/gap-analysis.json` (§1; the `semantic` section
only with `--semantic`), then print the console summary (§2).

## Phase 5: Human review document

Write `audits/GAP-ANALYSIS-REVIEW.md` (§3 of `references/output-formats.md`): every ORPHAN, MISSING, MISMATCH and
uncovered BDD finding, and with `--semantic` every requirement not verified as covered, as a line item awaiting a
human decision. Present facts neutrally with the risk of each option; do not recommend REMOVE or PROMOTE and do
not fix anything. Gold plating is as harmful as a missing feature — code without a requirement is untested
surface and breaks traceability — but only a human can decide whether it becomes a REQ or goes.

The decisions the human writes in this file (PROMOTE / REMOVE / ACCEPT / DEFER per ORPHAN, with its rationale) are
the record: `sdd-acceptance --check` reads `audits/GAP-ANALYSIS-REVIEW.md` and lists them next to the acceptance
report, and an ORPHAN still without a decision is shown there as open, because unrequested code is part of what the
customer receives. When you re-run, carry over every decision already written for a finding that still exists.

## Constraints

- Read-only on `spec/`, `requirements/` and code. Writes only `.sdd/gap-analysis.json`, `.sdd/jev-coverage.json`
  and `.sdd/jev/` (scratch), `audits/GAP-ANALYSIS-REVIEW.md` and the `gap-detector` entry of `pipeline-state.json`.
- Regex extraction only for the structural phases: no AST parsers, no package installs.
- Runs at any pipeline stage; pipeline-state.json is optional input.
- Reports gaps; never proposes code or edits specs.
- `llm-verified` results are proposals: nothing is written into source files or the traceability graph.

## Related skills

`python3 "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-graph.py"` builds the graph used in S.1 and loads `.sdd/gap-analysis.json`; `/sdd-acceptance --check`
verifies ID chains across artifacts and reports each requirement's verdict with its evidence (it reads the orphan decisions of this skill's review document); `/sdd-reconcile` resolves drift using these findings; the MCP tool `sdd_gaps`
serves `.sdd/gap-analysis.json`.

## Persist summary

After writing the results, update `pipeline-state.json` (create it from
`$SDD_PLUGIN_ROOT/templates/pipeline-state.template.json` if absent, as `sdd-setup` Step 1 does):

1. `stages["gap-detector"]` (utility stage, add the key if absent): `status: "done"`, `lastRun`: now (ISO-8601).
2. `summary`:
   - `artifacts`: `.sdd/gap-analysis.json` ("Gap Analysis Results"), `audits/GAP-ANALYSIS-REVIEW.md` ("Gap review")
   - `metrics`: `total_spec_endpoints`, `implemented`, `missing`, `orphan_routes`, `mismatches`,
     `endpoint_coverage_pct`, `bdd_coverage_pct`; with `--semantic` also `semantic_targets`, `semantic_covered`,
     `semantic_partial`, `semantic_likely_missing`, `semantic_judge` (`jev` | `llm`)
   - `highlights`: 3-5 observations (e.g. "2 missing endpoints: API-001-12, API-002-03", "REQ-F-031 likely missing")
   - `nextStep`: e.g. "Review audits/GAP-ANALYSIS-REVIEW.md" or "Implement missing endpoints"
   - `generatedAt`: now
3. Show the summary table. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode;
   never from a subagent).
