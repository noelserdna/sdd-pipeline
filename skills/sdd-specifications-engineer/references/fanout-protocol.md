# Execution Protocol: Id Ledger, Fan-out by Requirement Group, Consolidation from JSON

> Profile that motivated this (`docs/medidas.md`, `docs/perfilado.md`): 22 min for a 10-requirement project — the
> longest stage of the pipeline — in **one thread**. Stage time is almost entirely output tokens (the 88 k chars of
> `spec/` are only ~20 % of what the stage generates; the rest is the per-requirement reasoning: error flows,
> invariant extraction, scenario design). Reading less does not shorten that; generating in parallel does.
> Target: wall-clock ≈ phases A+B + the slowest lane + phases D+E, main-thread context ≤ ~30 k tokens of spec content,
> zero id collisions, zero broken cross-references.

## 0. Fan-out is part of this skill's contract

Launching the requirement lanes is **the requested behaviour of `/sdd-specifications-engineer`** above the threshold,
not an optional expansion of scope: invoking this skill on a requirements set of that size *is* the explicit request for
them. They are bounded workers (at most four at a time, no nesting), each reads only its own requirements plus the
already-written shared documents, and each writes a **disjoint set of files** whose ids were reserved before they
started. **Do not downgrade to sequential out of caution.** Downgrade only for a reason in §1, and record it in
`metrics.mode` and in `summary.highlights`.

Measured on 2026-08-27 (`docs/medidas.md`, `sdd-spec-auditor`): a run that downgraded to sequential "because the session
guidance forbids spawning subagents without an explicit request" took 11 min; the same work with fan-out took 5 min and
**cost half as much**, because each worker holds a small context instead of the whole corpus.

## 1. Choose the mode (Mode 2 step 0, before writing anything)

```bash
F=$(grep -ohE '\bREQ-F-[0-9]{3}\b' requirements/REQUIREMENTS.md | sort -u | wc -l | tr -d ' ')   # functional REQs
N=$(grep -ohE '\bREQ-[A-Z]+-[0-9]{3}\b' requirements/REQUIREMENTS.md | sort -u | wc -l | tr -d ' ') # all REQs
```

| Condition | Mode |
|---|---|
| `F > 4` | **fanout** (default; also in `claude -p` — the `Agent` tool is available there) |
| `F ≤ 4` | **sequential** (one thread, same Generation Order, same id ledger) |
| `--fanout` flag | **fanout**, whatever the size (forces the mode; useful for benchmarking) |
| `--sequential` flag, or the `Agent` tool is not in the tool list | sequential; add the reason to `summary.highlights` |
| Mode 5 (brownfield), Mode 3, Mode 4 | sequential — they are diagnostic or incremental, not bulk generation |

Mode 1 (analysis and user decisions) is **always** the main thread: it asks the user, and a subagent cannot.

## 2. Lanes and write sets

One **R lane** per group of 2–3 functional requirements, plus at most one **X lane** for the cross-cutting documents
that do not depend on the use cases. Never more than 4 agents at a time; never nested.

| `F` | R lanes | X lane | Total agents |
|---|---|---|---|
| 5–6 | 2 (3+2 / 3+3) | yes | 3 |
| 7–9 | 3 (≤ 3 each) | yes | 4 |
| 10–12 | 4 (3 each) | no — the main thread keeps `nfr/` and `adr/` | 4 |
| > 12 | `ceil(F/3)` lanes launched in **waves of 4** (X in the first wave) | yes | 4 per wave |

Group by shared entity / module, not by requirement number: requirements that touch the same entity land in the same
lane, so cross-lane references stay rare and each lane reasons about one part of the model.

| Lane | Writes (and nothing else) | Reads |
|---|---|---|
| `R1…Rk` | `spec/use-cases/UC-0NN-{slug}.md` and `spec/tests/BDD-UC-0NN.md` for **its** UC ids | the id ledger; its own line range of `requirements/REQUIREMENTS.md`; `spec/domain/01,03,05`, `spec/VALUE-REGISTRY.md`, `spec/CLARIFICATIONS.md` (whole, each ≤ 6 k chars); Templates 2 and 13 |
| `X` | `spec/nfr/*.md`, `spec/adr/ADR-0NN-{slug}.md` (ids reserved in the ledger), `spec/tests/PROPERTY-TESTS.md` | the id ledger; the `REQ-NF-*` / `REQ-C-*` sections; `spec/domain/03,05`, `spec/VALUE-REGISTRY.md`, `spec/CLARIFICATIONS.md`; Templates 6, 7 |
| main thread | everything else — see §7 | the ledger, the returned JSON, `grep`. **Never opens a file a lane wrote.** |

`spec/contracts/**` is **not** fanned out: one contract file is shared by every lane, and splitting it would either
serialize the writes or produce merge conflicts. Lanes return their operations as JSON (`ops`, `errs`) and the main
thread writes the contract in phase D — the expensive part (deciding pre/post/errors) still happens in parallel.
*Optional, only above ~12 operations:* lanes may instead write one fragment per operation to `.sdd/frag/{module}/{NN}.md`
and the main thread assembles with `cat .sdd/frag/api/*.md >> spec/contracts/API-api.md` (zero output tokens). Fragments
live outside `spec/` so an interrupted run never pollutes the corpus.

## 3. The id ledger (Generation Order phase A — the shared contract)

Fan-out is safe only because every id exists before any lane starts. Write the ledger to a working file **outside
`spec/`** (it is not a deliverable, and the auditor must not see it):

```bash
LEDGER="$([ -d .sdd ] && echo .sdd || echo "${TMPDIR:-/tmp}")/spec-id-plan.md"
grep -nE '^#{2,4} |^\*\*|REQ-[A-Z]+-[0-9]{3}' requirements/REQUIREMENTS.md | cut -c1-110   # line ranges per REQ
```

The ledger holds, in ≤ 4 000 chars:

```markdown
# Spec id plan — {project} — {date}   (working file; not part of spec/)
Mode: fanout · lanes: R1 R2 R3 X · model: sonnet

| Lane | REQs (lines in REQUIREMENTS.md) | UC ids + title | AC | API operations | INV mint | NC mint |
|---|---|---|---|---|---|---|
| R1 | REQ-F-001 (10–21), REQ-F-002 (22–32) | UC-001 Create task, UC-002 List tasks | AC-001-NN, AC-002-NN | API-001-01, -02, -07; API-002-01, -02 | INV-{AREA}-1NN | NC-1NN |
| R2 | REQ-F-003 (33–44), REQ-F-004 (45–55) | UC-003 …, UC-004 … | AC-003-NN, AC-004-NN | API-001-03, -04, -08; API-002-03, -04 | INV-{AREA}-2NN | NC-2NN |
| X  | REQ-NF-001 (81–88), REQ-C-001 (99–103) | — | — | — | INV-{AREA}-4NN | NC-4NN |
| main | — | — | — | contract headers, Operations index, Errors table | INV-{AREA}-0NN | NC-0NN |

## Fixed skeletons — cite these ids, never invent one
- WF-001 Command lifecycle. Steps: 1 parse argv · 2 validate · 3 load store · 4 apply operation · 5 persist · 6 render · 7 exit.
- ADR-001 store file shape · ADR-002 atomic save · ADR-003 single-user CLI · ADR-004 error model · ADR-005 clock (owner: X)
- Contract modules: API-001 = `api` (`src/api`), API-002 = `cli`. Operation → UC → lane as in the table above.
- Domain areas for INV: TSK (task), STO (store), CLI (interface).
```

Reservation rules — these are what make collisions impossible:

1. **UC ids are allocated per requirement**, 1–2 per functional REQ (`REQ-F-001 → UC-001..UC-002`), listed explicitly.
   `AC-NNN-NN` derives from the UC number, so acceptance-criterion ids are disjoint by construction.
2. **`API-{module}-NN` operation ids are allocated one by one** in phase A, each to exactly one lane, with a ≤ 6-word
   purpose. A lane that needs another lane's operation cites its id; it never renames or renumbers one.
3. **Minted ids carry the lane digit.** The ledger gives every lane a digit `L` (1–9; the X lane takes the next free
   one). Phase A owns `INV-{AREA}-0NN` and `NC-0NN`; lane *L* mints only `INV-{AREA}-{L}NN` and `NC-{L}NN` — and the
   digit is unique across **waves**, not just within one. Both keep the three-digit shape the pipeline greps for
   (`INV-[A-Z]+-[0-9]{3}`, `NC-[0-9]{3}`), so nothing downstream changes. Above 9 lanes the ledger allocates explicit
   contiguous ranges instead (`INV-TSK-100..119`, `NC-100..119`).
4. **`RN-NNN` is never minted by a lane.** Business rules come from user decisions (Mode 1) and are written to
   `spec/CLARIFICATIONS.md` in phase B, before fan-out. A lane that hits an undecided ambiguity emits an `NC` marker
   from its block and returns it in `gaps`; the main thread asks the user in phase D and converts it to an RN row.
5. **`WF-NNN` and `ADR-NNN` are fixed as skeletons in phase A** — id, name and the *numbered* step list for workflows —
   so a lane can write `WF-001 steps 3–5` in a `Refs` row that will still be true when phase D expands the workflow.

## 4. Budgets and reading discipline

| Thread | Budget | How |
|---|---|---|
| main, fanout | ≤ ~30 k tokens of spec content | requirements read once in phase A; the shared documents it wrote itself; afterwards only the lanes' JSON, `grep -c`, `grep -rhoE` id lists and `wc -c`. **Never re-open a UC or BDD file** |
| each R lane | its own requirements (`sed -n 'a,bp'`) + the five shared documents whole (≤ 6 k chars each) | no access to other lanes' requirements or files |
| each lane's output | UC ≤ 3 500 chars, BDD ≤ 2 500, ADR ≤ 1 500, `nfr/*` ≤ 2 500 (SKILL.md § Output Budget) | returns `chars` per file so the main thread never measures by reading |

## 5. Launch

- **One assistant message with all the lane `Agent` calls** so they run concurrently — do not wait for one before
  launching the next. Above 4 lanes, launch in waves of 4.
- `subagent_type: "general-purpose"`, `description: "Spec lane {LANE} — {REQ ids}"`. Never `subagent_type: "fork"`:
  a fresh agent with a small context is the point.
- `model: "sonnet"` — unless `CLAUDE_CODE_SUBAGENT_MODEL` is set, in which case omit `model` and let the environment
  decide. Phases A–B (domain modelling) and D–E (consolidation, gate) always run on the main thread's own model.
- While the lanes run, the main thread does **its own phase-D work that does not depend on them**: `spec/README.md`
  skeleton, `EVENTS-*` / `PERMISSIONS-MATRIX` absence declarations, `RESEARCH-QUESTIONS.md`.
- A lane that errors, times out or returns invalid JSON is re-launched **once** with the same prompt (telling it to
  overwrite any file it already wrote). If it fails again, the main thread writes that lane's files itself, sequentially,
  and says so in `summary.highlights`.

## 6. Lane prompt templates

Substitute `{…}`. `{REFS}` = `${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/skills/sdd-specifications-engineer/references`;
if that path is unknown, paste Templates 2 and 13 (or 6 and 7) inline instead of the pointer.

### 6.1 Requirement lane (R)

```
You are lane {LANE} of sdd-specifications-engineer (Mode 2, Generation Order phase C). Write in {project language}.
You own {REQ-F-00x, REQ-F-00y}. You produce their use cases and BDD scenarios. Nothing else.

READ, in this order, and nothing else:
1. {LEDGER} — the id ledger. Every id you write comes from your row; you never mint an id outside your blocks.
2. requirements/REQUIREMENTS.md lines {a}-{b} and {c}-{d}:  sed -n '{a},{b}p;{c},{d}p' requirements/REQUIREMENTS.md
3. spec/domain/01-GLOSSARY.md, spec/domain/03-VALUE-OBJECTS.md, spec/domain/05-INVARIANTS.md,
   spec/VALUE-REGISTRY.md, spec/CLARIFICATIONS.md — whole, each ≤ 6 k chars. They are written and authoritative.
4. {REFS}/document-templates.md § 0 (rules W1-W9) and Templates 2 and 13 — those sections only (grep -n, then sed -n).
Never open another lane's use case, BDD file, or anything under spec/contracts/, spec/workflows/, spec/adr/, spec/nfr/.

WRITE exactly these files, one Write each, never re-opened:
  {spec/use-cases/UC-003-{slug}.md, spec/tests/BDD-UC-003.md, spec/use-cases/UC-004-{slug}.md, spec/tests/BDD-UC-004.md}
Budgets: UC ≤ 3 500 chars, BDD ≤ 2 500 chars. Follow Template 2 and Template 13 exactly — same headings, same column
order, same `Refs` header row. Do not add sections; a mandatory section with nothing to say is the single line `None.`

METHOD, per use case (all of it in memory before the first Write):
- Error Flow Forcing Function: for every main-flow step answer the 5 questions (step failure / invalid input /
  authorization denied / concurrent conflict / precondition broken mid-flight). Each "yes" becomes ONE row of the
  `Exceptions & errors` table with error code + HTTP-or-exit + effect + AC id. A "no" produces NO text — no N/A rows,
  no "not applicable" prose, no record of the questions.
- Invariant Extraction: scan the requirement and your flow for "must, shall not, always, never, at most, at least,
  between X and Y, unique, only if, requires, cannot exceed". If `05-INVARIANTS.md` already has it, cite that id.
  If not, mint one from {INV-{AREA}-{L}NN}, cite it inline in the step or postcondition, and return it in `inv_new`
  — the main thread appends the row; you never edit spec/domain/.
- Write the UC and its BDD file back to back: the BDD file defines the AC-NNN-NN ids the UC cites, so every AC id in
  the UC is a scenario title in that file, and every scenario title carries its `[REQ-X ACn]` tag.
- CITE, NEVER COPY (rules W1-W2): requirement statements stay in REQUIREMENTS.md, term definitions in the glossary,
  numeric values in VALUE-REGISTRY (cite the NAME, e.g. `TITLE_MAX_LENGTH`, never the number), error message/class in
  the catalog of 03-VALUE-OBJECTS.md, rules as INV-/RN- ids. Given/When/Then exist only in the BDD file.
- Glossary discipline: never use a synonym listed in the glossary's "Do not use" column. A domain term the glossary
  lacks: use the term and return `{"term":…, "def":…}` in `gaps` — you never edit spec/domain/.
- A contract operation you need already has an id in the ledger: cite it. Return its signature, pre, post and error
  codes in `ops` — do NOT create or edit any file under spec/contracts/.
- An ambiguity that no RN, ADR or invariant resolves: do NOT decide and do NOT ask. Insert
  `<!-- [NEEDS CLARIFICATION] NC-{L}NN: {question} -->` right after the ambiguous text and return it in `gaps`.
- Behaviour that no REQ covers (a new workflow, a new user-visible message, a new business rule): do NOT specify it —
  return it in `tier1` and leave an NC marker.
- Never touch pipeline-state.json. Never run Persist Summary or Handoff. Never launch subagents. Never ask the user.

Worked example of the level of detail expected (one exception row and its scenario, same project style):
| E3 | 5 | no task with `<id>` | `E_TASK_NOT_FOUND` | 3 | store untouched (INV-STO-004) | AC-003-03 |
Scenario: AC-003-03 — task does not exist [REQ-F-003 AC3]
  When I run `todo done 9`
  Then error `E_TASK_NOT_FOUND` with exit code 3 and stderr `task 9 not found`
  And the store is untouched

RETURN ONLY this JSON (no prose, no file bodies, ≤ 3 000 chars):
{"lane":"{LANE}","reqs":["REQ-F-003"],
 "files":[["spec/use-cases/UC-003-complete-task.md",2677],["spec/tests/BDD-UC-003.md",1815]],
 "ids_used":{"UC":["UC-003"],"AC":["AC-003-01..06"],"INV":["INV-TSK-201"],"NC":["NC-201"]},
 "ids_ref":["REQ-F-003","WF-001","API-001-03","API-001-08","INV-TSK-001","RN-007","ADR-005","SM-001"],
 "ops":[{"id":"API-001-03","sig":"completeTask(store,id,now): {store,task,changed}","pure":true,
         "pre":"≤120 chars","post":"≤200 chars","uc":"UC-003","errs":["E_TASK_NOT_FOUND"]}],
 "errs":[{"code":"E_TASK_NOT_FOUND","cls":"NotFoundError","ops":["API-001-03"],"status":"3",
          "when":"≤80 chars","new":false}],
 "inv_new":[{"id":"INV-TSK-201","rule":"≤120 chars","check":"≤120 chars","at":"API-001-03","uc":"UC-003","err":"E_…"}],
 "derived":[{"tier":2,"from":"REQ-F-003","pattern":"id-parsing validation errors","ids":"AC-003-04, AC-004-04"}],
 "tier1":[],
 "gaps":[{"nc":"NC-201","doc":"spec/use-cases/UC-004-remove-task.md","q":"≤140 chars"},
         {"term":"soft delete","def":"≤20 words — a term you needed and the glossary lacks"}],
 "wf":[{"uc":"UC-003","steps":"2,3,4,5,6"}],
 "chars":4492}
```

### 6.2 Cross-cutting lane (X)

Same header, scope and prohibitions, with these differences:

```
You own the cross-cutting documents that do not depend on any use case: {REQ-NF-*, REQ-C-*} and the decisions already
listed in the ledger's "Fixed skeletons".
READ additionally: the REQ-NF / REQ-C sections named in the ledger; {REFS}/document-templates.md Templates 6, 7 and
the PROPERTY-TESTS shape; the ledger's UC id + title list (to cite UC ids you must never open).
WRITE exactly: {spec/nfr/PERFORMANCE.md, LIMITS.md, SECURITY.md, OBSERVABILITY.md}, {spec/adr/ADR-001-…md … ADR-005-…md},
spec/tests/PROPERTY-TESTS.md. Budgets: nfr ≤ 2 500, ADR ≤ 1 500, PROPERTY-TESTS ≤ 4 000 chars.
Rules: one ADR per decision ACTUALLY taken (Nygard short: context ≤ 5 lines, alternatives table `Option | Why not`,
consequences as +/− bullets, a risk is a `−` bullet). An NFR category that does not apply is ONE row
`Not applicable (ADR-NNN)`, never a paragraph. Every quantified target cites its VALUE-REGISTRY name. Property tests
are one row per INV id from 05-INVARIANTS.md.
RETURN the same JSON, with "ids_used":{"ADR":[…],"SPEC":[…],"PROP":[…]} and "ops":[], "wf":[].
```

## 7. Consolidation (phases D–E, main thread, main model — from JSON and `grep`, never by re-reading)

1. **Write-set check.** Every file the ledger promised exists and is non-empty:
   `ls spec/use-cases spec/tests spec/nfr spec/adr` compared with the ledger; `wc -c` for the budget. A missing file
   means a lane failed → §5 relaunch rule.
2. **Collision check.** Union the `ids_used` of every lane: no id may appear in two lanes. Then check the corpus at its
   *definition* sites — a duplicate there is a ledger bug, not a lane bug:
   ```bash
   ls spec/use-cases spec/workflows spec/adr | grep -oE '(UC|WF|ADR)-[0-9]{3}' | sort | uniq -d
   grep -hoE '^\| *INV-[A-Z]+-[0-9]{3}'   spec/domain/05-INVARIANTS.md | tr -d '| ' | sort | uniq -d
   grep -hoE '^\| *RN-[0-9]{3}'           spec/CLARIFICATIONS.md       | tr -d '| ' | sort | uniq -d
   grep -hoE '^\| *API-[0-9]{3}-[0-9]{2}' spec/contracts/API-*.md      | tr -d '| ' | sort | uniq -d
   grep -rhoE '^ *Scenario( Outline)?: *AC-[0-9]{3}-[0-9]{2}' spec/tests | grep -oE 'AC-[0-9]{3}-[0-9]{2}' | sort | uniq -d
   grep -rhoE '\[NEEDS CLARIFICATION\] NC-[0-9]{3}' spec | grep -oE 'NC-[0-9]{3}' | sort | uniq -d
   ```
   Each must print nothing. Scope matters: the same id legitimately opens a row in `DERIVED-SPECS.md` or
   `TRACEABILITY-MATRIX.md`, so only the **home** document of each family is checked. A duplicate means the ledger
   handed one id to two lanes: fix the ledger and rewrite the losing file.
3. **Dangling check.** `ids_ref` (union) minus (`ids_used` ∪ phase-A/B ids ∪ ids phase D is about to create) must be
   empty. Anything left is a broken cross-reference: fix it before writing the matrix.
4. **Sanctioned appends** (the only files re-opened after being written, rows only, one Edit each):
   `spec/domain/05-INVARIANTS.md` ← `inv_new` rows; `spec/domain/03-VALUE-OBJECTS.md` error catalog ← `errs` with
   `"new":true`; `spec/domain/01-GLOSSARY.md` ← `gaps` entries carrying a `term`; `spec/CLARIFICATIONS.md` ← RN rows for
   the `gaps` the user resolves now (remove the corresponding `NC` marker with a targeted `Edit` when you do).
5. **Contracts** — `spec/contracts/API-{module}.md` per Template 12: header + Operations index from the ledger,
   one detail block per `ops` entry, **one** Errors table from the deduplicated `errs` union (same code from two lanes
   = one row whose "Operations" column is the union).
6. **Workflows** — expand each ledger skeleton into `spec/workflows/WF-NNN-{slug}.md` using the `wf` digests
   (which UC exercises which steps); no UC file is opened.
7. **`DERIVED-SPECS.md`** from the `derived` rows grouped by pattern, plus every `inv_new` (Tier 2) and every `tier1`
   entry marked `[PENDING REQ]`. More than 3 Tier 1 entries → alert the user before proceeding.
8. **`CLARIFICATIONS-PENDING.md`** from the `gaps` rows (always written, even empty).
9. **`TRACEABILITY-MATRIX.md`** from the ledger plus `ids_used` / `ids_ref` — a pure join, no re-reading.
10. `README.md`, `RESEARCH-QUESTIONS.md`, the `EVENTS-*` / `PERMISSIONS-MATRIX` declarations, then the
    **Self-Validation Gate** (grep/wc only) and **Persist Summary** with
    `metrics.mode = "fanout"`, `metrics.spec_agents = {N}`.

## 8. Sequential mode (`F ≤ 4`, `--sequential`, or no `Agent` tool)

Same Generation Order, one thread: the ledger is still built in phase A (it is what keeps ids unique and lets an
interrupted run resume), phase C writes UC + BDD requirement by requirement, and phase D consolidates from the running
lists instead of from JSON. `metrics.mode = "sequential"`, `metrics.spec_agents = 0`, and the reason for the downgrade
goes in `summary.highlights`.
