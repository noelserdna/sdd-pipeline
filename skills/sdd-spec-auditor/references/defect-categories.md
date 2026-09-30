# Defect Categories CAT-01..CAT-10 — signals and example findings

Read this before classifying findings (Phase 5) and give it to each dimension auditor. The one-category rule and the
disambiguation table are in SKILL.md § Defect Categories. Examples use the finding block of `report-template.md` §3;
they come from an illustrative task-list project, not from any real one.

## CAT-01 Ambiguities (`AMB-`)

Terms or phrases that admit several interpretations.
Signals: vague qualifiers ("appropriate", "reasonable", "normally", "apropiado", "razonable"); missing quantifiers;
pronouns without a clear referent.

```markdown
### AMB-001: "Reasonable" response time is not quantified — P2 · CAT-01 · new
- **Where:** `nfr/PERFORMANCE.md:45`
- **What:** "reasonable response time" has no numeric value.
- **Why:** Unverifiable NFR; `contracts/API-tasks.md:30` defines no timeout either.
- **Fix:** Which p95 latency (ms) is acceptable? Replace the phrase with the value and its measurement window.
```

## CAT-02 Implicit rules (`IMP-`)

Behaviour taken for granted but never written down anywhere.
Signals: flows that "obviously" do something; unspecified validations; assumed ordering.

```markdown
### IMP-001: Title uniqueness assumed but never specified — P1 · CAT-02 · new
- **Where:** `use-cases/UC-001-create-task.md:23`
- **What:** Step "enter title" states no uniqueness or format rule.
- **Why:** Implementers will pick a rule; `domain/02-ENTITIES.md:18` (Task) has no constraint either.
- **Fix:** Unique per list or not unique? Add the rule to UC-001 and an INV in 05-INVARIANTS.md.
```

## CAT-03 Dangerous silences (`SIL-`)

A specific scenario that is not handled and would produce undefined behaviour.
Signals: flows without error handling; states without exit transitions; unmentioned edge cases; undefined timeouts; a write operation without a `replay` row (`detection-patterns.md` CAT-03).

```markdown
### SIL-001: Store write timeout has no defined outcome — P0 · CAT-03 · new
- **Where:** `workflows/WF-001-command-lifecycle.md:40` · `nfr/LIMITS.md:12`
- **What:** Step 5 (persist) has no branch for the write not completing within `STORE_WRITE_TIMEOUT`.
- **Why:** Undefined production behaviour; LIMITS.md defines the timeout but no action, `domain/04-STATES.md` has no failure state.
- **Fix:** Retry? Abort with `E_STORAGE_UNAVAILABLE`? Add the exception to WF-001 and the transition to 04-STATES.md.
```

## CAT-04 Semantic ambiguities (`SEM-`)

The same term with different meanings, or different terms for the same concept.
Signals: uncontrolled synonyms; a glossary definition that differs from usage; case variations of a term.

```markdown
### SEM-001: "item" used for the glossary term "Task" — P3 · CAT-04 · new
- **Where:** `workflows/WF-001.md:12` (3 occurrences) vs `domain/01-GLOSSARY.md:8`
- **What:** "item" is listed in the glossary's "Do not use" column; the canonical term is "Task".
- **Why:** Ubiquitous-language violation (CHECK-SH01).
- **Fix:** Replace "item" by "Task" in WF-001.
```

## CAT-05 Contradictions between documents (`CON-`)

Two documents assert conflicting facts.
Signals: different values for the same parameter; incompatible flows; contradictory permissions.

```markdown
### CON-001: Title limit 120 vs 200 characters — P1 · CAT-05 · new
- **Where:** `use-cases/UC-003-rename-task.md:31` ("200 characters") vs `VALUE-REGISTRY.md:9` (`TITLE_MAX_LENGTH` = 120)
- **What:** Two values for the same limit; UC-003 is the divergent document (Minority Rule).
- **Why:** Implementers cannot choose; no RN in `CLARIFICATIONS.md` settles it.
- **Fix:** Cite `TITLE_MAX_LENGTH` in UC-003 (or amend the registry and record the decision as an RN).
```

## CAT-06 Incomplete specifications (`INC-`)

A structural element is missing: empty section, placeholder, broken reference, open `[NEEDS CLARIFICATION]` marker.
Signals: TODO/TBD/FIXME; empty template fields; references to documents that do not exist.

```markdown
### INC-001: UC-004 has an empty "Exceptions & errors" table — P1 · CAT-06 · new
- **Where:** `use-cases/UC-004-remove-task.md:45`
- **What:** The table has no rows; removing a task that other tasks depend on is unspecified.
- **Why:** `domain/05-INVARIANTS.md` has no referential-integrity INV for task dependencies.
- **Fix:** Forbid removal? Cascade? Fill the table and add the INV.
```

## CAT-07 Weak or missing invariants (`INV-`)

A business rule stated in prose without a formal invariant, or an invariant without a validation.
Signals: constraints in text without an INV id; invariants without a validation column; rules living only in UCs.

```markdown
### INV-001: Priority range stated in prose without an invariant — P2 · CAT-07 · new
- **Where:** `use-cases/UC-005-set-priority.md:34`
- **What:** "priority must be between 1 and 5" has no INV-{AREA}-NNN.
- **Why:** `domain/05-INVARIANTS.md` has no priority-range invariant; nothing validates it.
- **Fix:** Create INV-TSK-NNN (range 1–5, with its validation) and cite it from UC-005.
```

## CAT-08 Future evolution risks (`EVO-`) — capped at P2

Design choices that make predictable changes hard.
Signals: hard-coded values likely to change; tight coupling between modules; closed enums/states; unversioned public APIs.

```markdown
### EVO-001: TaskStatus is a closed enum without an evolution rule — P2 · CAT-08 · new
- **Where:** `domain/04-STATES.md:23`
- **What:** Adding a state requires migrating stored tasks; no strategy is documented.
- **Why:** `adr/` has no decision on state evolution.
- **Fix:** Document the migration rule, or an ADR on how new states are introduced.
```

## CAT-09 Implicit decisions without ADR (`ADR-`)

A material architectural decision taken without a record. Material: data store, auth mechanism, infrastructure
platform, communication protocol, encryption, multi-tenancy model, id format, retry/backoff strategy. Industry-standard
defaults (JSON, UTF-8, HTTP for a web app) do not need one.

```markdown
### ADR-001: Storage format (single JSON file) has no ADR — P2 · CAT-09 · new
- **Where:** `workflows/WF-001.md:56`
- **What:** "persist the store as one JSON file" with no ADR weighing alternatives.
- **Why:** The storage choice drives concurrency and recovery behaviour; `adr/` has no storage ADR.
- **Fix:** Create ADR-NNN with context, decision and alternatives considered.
```

## CAT-10 Transport over-specification (`TRN-`) — ≤ P2, P1 when it blocks required behaviour

Transport or UI mechanics fixed without a REQ demanding them: they tie the spec to a stack and fight its conventions.
Signals (greps in `detection-patterns.md` § CAT-10, over `spec/`, plus `ux/` and `test/` when present): HTTP
verbs/paths, status codes or redirects outside `Style: http` contracts; `required|maxlength|pattern` attributes that
hide server validation messages; client-script mechanics or URLs no REQ requires.
Fix: rewrite as operation semantics + "transport: see design/OPERATION-MAPPING.md"; never remove transport a REQ
demands (cite the REQ instead).

```markdown
### TRN-001: Contract fixes routes and statuses no REQ demands — P2 · CAT-10 · new
- **Where:** `contracts/API-tasks.md:14`
- **What:** `POST /tasks/{id}/title` + 400/404 per error in a `Style: operations` module.
- **Why:** No REQ demands it; it pushes custom routes over the stack idiom.
- **Fix:** Operation `renameTask` + domain codes; transport → `design/OPERATION-MAPPING.md`.
```
