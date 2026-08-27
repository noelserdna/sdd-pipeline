# Execution Protocol: Index, Budgets, Fan-out by Dimension

> Profile that motivated this (docs/perfilado.md): one thread, 57 turns, 106 k tokens of specs read file by file,
> 112 k output tokens, 21 min for a 10-requirement project. Target: wall-clock ≈ the slowest dimension + consolidation,
> main-thread spec context ≤ ~30 k tokens, report ≤ 25 k chars.

## 0. Fan-out is part of this skill's contract

Launching the four dimension auditors is **the requested behaviour of `/sdd-spec-auditor`** above the threshold, not an
optional expansion of scope: invoking this skill on a spec of that size *is* the explicit request for them. They are
read-only workers (no writes, no commits, no nesting), bounded to four, scoped to one directory group each, and they cost
less wall-clock than the single-thread audit they replace. **Do not downgrade to sequential out of caution.** Downgrade
only for one of the reasons in §1 (below the threshold, `--sequential`, no `Agent` tool, Cycle 3), and always record the
reason in `summary.highlights` and in `metrics.mode`.

Measured on 2026-08-27 (`docs/medidas.md`): a run that downgraded to sequential "because the session guidance forbids
spawning subagents without an explicit request" took 11 min; the same audit with fan-out took 9.9 min with a larger
report — and the gap widens with the size of `spec/`.

## 1. Choose the mode (Phase 1, before opening any file)

```bash
FILES=$(find spec -name '*.md' | wc -l | tr -d ' ')
CHARS=$(find spec -name '*.md' -print0 | xargs -0 cat | wc -c | tr -d ' ')
```

| Condition | Mode |
|---|---|
| `FILES > 8` **or** `CHARS > 40000` | **fanout** (default; also in `claude -p` — the `Agent` tool is available there) |
| otherwise | **sequential** (one thread, still index + sections, never whole-corpus `cat`) |
| `--fanout` flag | **fanout**, whatever the size (forces the mode; useful for benchmarking) |
| `--sequential` flag, or the `Agent` tool is not in the tool list | sequential; add the reason to `summary.highlights` |
| `--focused --scope=…` | sequential over the change set; fanout only if the change set exceeds the threshold |

Cycle 3 (Verification) is always sequential and narrow (SKILL.md Verification Rules).

## 2. Build the index (main thread; the only corpus-wide read)

```bash
IDX="$([ -d .sdd ] && echo .sdd || echo "${TMPDIR:-/tmp}")/spec-index.txt"
grep -rn -E '^#{1,3} |^\*\*ID|^- \*\*ID|^\| [A-Z]+-[0-9]+' spec/ | cut -c1-110 > "$IDX"
wc -l "$IDX"; cut -d: -f1 "$IDX" | uniq -c | sort -rn | head -60          # headings per file (structure, SH05)
grep -oE '\b(REQ|UC|WF|API|INV|ADR|AC|BDD|SEC|SLO|PROP|RN|RB|NC)-[A-Z0-9-]+' "$IDX" | sort -u | tr '\n' ' '  # id set
```

The main thread reads the two summaries above, not the whole index (≈ 55 k chars for 45 docs). Slices come on demand:
`grep '^spec/domain/' "$IDX"`. Sections are opened with `sed -n 'a,bp' file` (≤ 60 lines per call), located by the
index line numbers. **Never `cat` a spec file in the main thread, in any mode.** A file ≤ 8 k chars may be read whole
by the thread that owns it (sequential mode or the auditor of its dimension); **above 8 k chars the owner also works by
sections** (`grep '^spec/<dir>/' "$IDX"` for its own map, then `sed -n`), so no thread ever holds a whole large document.
This is what keeps the token cost of fan-out close to the sequential run instead of multiplying it.

## 3. Budgets (spec content held in context)

| Thread | Budget | How |
|---|---|---|
| main, fanout | ≤ ~30 k tokens (~120 k chars) | index summaries + baseline ids + grep outputs + `sed -n` spot checks of P0/P1 evidence |
| main, sequential | corpus ≤ 40 k chars fits; read by dimension order, section by section | same commands; collect findings in a compact list before writing |
| each auditor | its scope whole if ≤ 60 k chars, else by sections; ≤ 200 lines of neighbour lookups per finding | own slice of `$IDX`, `sed -n`, `grep -n` |

## 4. Scopes (prefixes from the Multi-Agent table in SKILL.md)

| Auditor | Prefix | Reads ONLY | Owns these corpus-wide families (grep-based) | 3C checks |
|---|---|---|---|---|
| Domain | `DOM-` | `spec/domain/**`, `spec/CLARIFICATIONS.md` | Terminology violations (every "NO usar" term of the glossary grepped over `spec/`); business rules (RN) without invariant | SH01, SH02, SR03 (definition side) |
| Use cases & workflows | `UC-` | `spec/use-cases/**`, `spec/workflows/**` | Missing invariants (must/never/always/at most in UC text without INV-id); state transitions vs `04-STATES.md` (grep) | SR01, SR04, SC04 (own docs) |
| Contracts & BDD | `CON-` | `spec/contracts/**`, `spec/tests/**` | Missing BDD per UC (≥ 1 happy + 1 error); missing API error codes (401/403/404/409/429 where applicable); permissions vs `PERMISSIONS-MATRIX.md` | SR05, SR03 (usage side) |
| NFR, ADR & runbooks | `NFR-` | `spec/nfr/**`, `spec/adr/**`, `spec/runbooks/**`, `spec/VALUE-REGISTRY.md` | Value inconsistencies (each registry / LIMITS / PERFORMANCE value grepped over `spec/`); ADR status and materiality (CAT-09) | SH04 |
| main thread | — | `$IDX`, `spec/README.md`, `TRACEABILITY-MATRIX.md`, `DERIVED-SPECS.md`, `CLARIFICATIONS-PENDING.md`, `requirements/REQUIREMENTS.md` (ids only) | Cross-references (SH03: every referenced id exists in the id set); REQ coverage and orphans (SC01, SC02, SC05); subdirectories populated (SC03); `TBD|TODO|NEEDS CLARIFICATION` markers corpus-wide (SC04); template uniformity from heading counts (SH05); baseline and regression (Phases 0, 6) | SC01–SC03, SC05, SH03, SH05 |

Directories not in the table (`spec/events/`, `spec/ux/`, …) go to the closest auditor, named in its prompt
(events → Contracts; ux → Use cases). A missing directory: the auditor returns `docs_read: []`; the main thread records
the SC03 failure as a CAT-06 finding. Auditors do not write files and do not run Persist Summary or Handoff.

## 5. Launch

- One assistant message with **four `Agent` calls** (they run concurrently), or four calls with `run_in_background: true`.
  Do not wait for one auditor before launching the next.
- `subagent_type: "general-purpose"`, `description: "Audit spec/{dimension} ({PREFIX})"`.
- `model: "sonnet"` for the four auditors — unless `CLAUDE_CODE_SUBAGENT_MODEL` is set, in which case omit `model`
  and let the environment decide. Consolidation, severity review of P0/P1, the Gate and the report are always done
  by the main thread with its own model.
- While the auditors run (background), the main thread performs its own row of §4. It never re-audits their scopes.
- An auditor that errors, times out or returns invalid JSON is re-launched **once** with the same prompt; if it fails
  again, the main thread audits that scope sequentially (index + sections) and says so in `summary.highlights`.

## 6. Auditor prompt template

Substitute `{…}`. `{REFS}` = `${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/skills/sdd-spec-auditor/references`; if that path
is unknown, inline the relevant checklist headings (≤ 40 lines) instead of the pointer.

```
You are the {DIMENSION} auditor of sdd-spec-auditor (prefix {PREFIX}). Read-only: create or modify no file.

Scope — read ONLY: {dirs and files from §4}. Index of your scope (path:line:heading|id), produced by:
  grep '^{scope-prefix}' {IDX}
Neighbours: for cross-document evidence use `grep -n` and `sed -n 'a,bp'` on other spec/ files, ≤ 200 lines per
lookup; never `cat` a file outside your scope. Glossary terms: {IDX slice of spec/domain/01-GLOSSARY.md, or "read it"}.
Known findings — do NOT re-report: {baseline rows "ID — short description", or "none"}.

Detect defects CAT-01..CAT-09 (definitions and one-category rule: {REFS}/../SKILL.md "Defect Categories";
checklists: {REFS}/audit-checklists.md sections {"Use Case", "Workflow", …}; grep patterns:
{REFS}/detection-patterns.md sections {CAT-xx list}). Read only those sections.
Rules:
- Evidence from 2+ documents, or the document plus the element that is missing; cite `doc:line`; quote ≤ 12 words.
- Exactly one category per finding. Severity: P0 = blocks implementation / undefined production behaviour;
  P1 = bugs or a violated requirement; P2 = hinders comprehension or maintenance; P3 = style or clarity.
  CAT-08 is at most P2; naming/format findings at most P3.
- An ADR or a CLARIFICATIONS rule that explains the behaviour makes it a decision, not a finding. Minority rule for
  contradictions: the divergent document is the location; one finding, not N.
- Batch the same defect pattern across documents into ONE finding listing all locations.
  Families you own: {from §4}.  3C checks you own: {from §4} — report pass/fail with the failing ids.
- No implementation proposals. `fix` is the spec-level correction, or the question that must be answered first.

Return ONLY this JSON (no prose, ≤ 6 000 chars), P0 first, at most 25 findings (batch harder rather than exceed):
{"dim":"{PREFIX}","docs_read":["spec/…"],"checks":{"SR04":"pass","SR01":"fail:{PREFIX}-003"},
 "findings":[{"id":"{PREFIX}-001","sev":"P1","cat":"CAT-05","doc":"spec/…/file.md","line":42,
   "also":["spec/…/other.md:17"],"claim":"≤200 chars: what is wrong","why":"≤200 chars: consequence + evidence",
   "fix":"≤240 chars: correction or question","batch":["spec/…:12","spec/…:30"]}]}
```

## 7. Consolidation (main thread, main model)

1. Parse the four JSON results. Compute `docs_read` union → Coverage rows; missing scope docs → `Not audited` or SC03.
2. **Deduplicate:** same `doc` + same line (±5) or same section + same defect type → keep the most complete finding,
   union the locations, mark `[CROSS-VALIDATED]`. A contradiction reported from both sides (A vs B, B vs A) is one
   finding located in the divergent document. Apply Phase 7.1 batching and 7.3 cascade marks across dimensions.
3. **Baseline filter** (Phase 0 lists): a finding matching an `Accepted`, `Won't fix` or unexpired `Deferred` row
   (same document + same defect) is dropped and counted as excluded.
4. **Classify** `new | persistent | regression` against the previous report's ids (Phase 6).
5. **Final ids by category:** `AMB- IMP- SIL- SEM- CON- INC- INV- EVO- ADR-`, numbered within category in severity
   order; keep the provisional id as `Source` (e.g. `Source: DOM-004`). Note that the final `CON-` = CAT-05
   contradictions, not the Contracts auditor.
6. **Severity review:** before a P0 or P1 enters the report, the main thread opens the cited lines once
   (`sed -n`, ≤ 60 lines) and confirms the claim; missing evidence → downgrade or drop. P2/P3 are accepted as reported
   after the Signal Filters.
7. Compute 3C (own checks + auditors' `checks`), the Quality Scorecard and the Gate (Quality Gate Thresholds), then
   write `audits/AUDIT-BASELINE.md` per `report-template.md` and run Persist Summary (`metrics.mode = "fanout"`).

## 8. Sequential mode (small specs)

Same discipline in one thread: index first; dimensions in the order DOM → UC/WF → CON/tests → NFR/ADR/runbooks;
each file read by sections from the index (whole only if ≤ 8 k chars); the corpus-wide families of §4 run as greps;
findings are collected in the compact JSON shape of §6 before the report is written; `metrics.mode = "sequential"`.
