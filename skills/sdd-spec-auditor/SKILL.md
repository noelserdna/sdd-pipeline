---
name: sdd-spec-auditor
description: "Audits specs for defects: ambiguities, implicit rules, dangerous silences, contradictions, weak invariants, decisions without ADRs; Mode Fix repairs. Does NOT propose implementations. Triggers: 'audit specs', 'review specifications', 'spec quality', 'find ambiguities', 'fix specs', 'auditar especificaciones', 'revisar specs', 'calidad de specs'."
hooks:
  Stop:
    - type: prompt
      prompt: "Check the audit report. Are there any P0 (Critical) or P1 (High) findings that remain unresolved? Answer YES only if all P0/P1 findings have been addressed or documented with explicit user acknowledgment."
      once: true
---

# SDD Spec Auditor Skill

> **Principio:** Auditar es validar la especificación como contrato, no como código.
> No se asume comportamiento no especificado. No se propone implementación.

## Purpose

Detectar defectos en especificaciones técnicas mediante análisis sistemático y cruce de documentos, generando informes de hallazgos con ubicación precisa, descripción del problema y preguntas de resolución.

## When to Use This Skill

Use this skill when:
- Reviewing existing specifications for quality assurance
- Preparing for implementation phases (pre-implementation audit)
- Validating spec consistency after major changes
- Conducting periodic spec health checks
- Onboarding to an existing spec repository
- Preparing for external audits (SOC2, GDPR, etc.)

## Core Principles

### 1. No Assumptions

```
❌ "Probablemente significa X"
❌ "Se asume que Y"
❌ "Por defecto sería Z"

✅ "No está especificado qué ocurre cuando..."
✅ "Falta definir el comportamiento para..."
✅ "El documento no indica si..."
```

### 2. No Implementation

```
❌ "Se podría implementar con..."
❌ "El código debería..."
❌ "Propongo agregar este endpoint..."

✅ "Falta especificar el contrato de..."
✅ "No hay invariante que garantice..."
✅ "Pregunta: ¿Qué debe ocurrir cuando...?"
```

### 3. Cross-Document Analysis

```
Cada hallazgo debe indicar:
- Documento(s) afectado(s)
- Línea o sección específica
- Documentos relacionados que contradicen o complementan
```

---

## Defect Categories

### CAT-01: Ambigüedades

Términos o frases que admiten múltiples interpretaciones.

**Señales:**
- Palabras como "apropiado", "razonable", "adecuado", "normalmente"
- Falta de cuantificadores exactos
- Pronombres ambiguos ("esto", "aquel", "el sistema")

**Ejemplo de hallazgo:**
```markdown
### AMB-001: "Reasonable" response time is not quantified — P2 · CAT-01 · new
- **Where:** `nfr/PERFORMANCE.md:45`
- **What:** "tiempo de respuesta razonable" has no numeric value.
- **Why:** Unverifiable NFR; `contracts/API-extraction.md:30` defines no timeout either.
- **Fix:** Which p99 latency (ms) is acceptable? Replace the phrase with the value and its measurement window.
```

---

### CAT-02: Reglas Implícitas

Comportamientos que se dan por entendidos pero no están documentados.

**Señales:**
- Flujos que "obviamente" hacen algo
- Validaciones no especificadas
- Orden de operaciones asumido

**Ejemplo de hallazgo:**
```markdown
### IMP-001: Email validation assumed but never specified — P1 · CAT-02 · new
- **Where:** `use-cases/UC-015-create-user.md:23`
- **What:** Step "ingresar email" states no format or uniqueness validation.
- **Why:** Implementers will pick a rule; `domain/02-ENTITIES.md:58` (User) has no constraint either.
- **Fix:** RFC 5322 format? Uniqueness per organization or global? Add the rule to UC-015 and an INV in 05-INVARIANTS.md.
```

---

### CAT-03: Silencios Peligrosos

Casos no cubiertos que podrían causar comportamiento indefinido.

**Señales:**
- Flujos sin manejo de errores
- Estados sin transiciones de salida
- Casos borde no mencionados
- Timeouts no definidos

**Ejemplo de hallazgo:**
```markdown
### SIL-001: LLM timeout in extraction has no defined outcome — P0 · CAT-03 · new
- **Where:** `workflows/WF-001-extraction.md:89` · `nfr/LIMITS.md:34`
- **What:** Step 4 has no branch for the LLM not answering within the timeout.
- **Why:** Undefined production behaviour; LIMITS.md defines the timeout but no action, `domain/04-STATES.md` has no timeout state.
- **Fix:** Automatic retry? Fallback? Final Extraction state? Add the exception flow to WF-001 and the transition to 04-STATES.md.
```

---

### CAT-04: Ambigüedades Semánticas

Mismo término usado con diferentes significados, o términos diferentes para el mismo concepto.

**Señales:**
- Sinónimos no controlados
- Término en glosario con definición diferente al uso
- Variaciones en mayúsculas/minúsculas

**Ejemplo de hallazgo:**
```markdown
### SEM-001: "job" used for the glossary term "Extraction" — P3 · CAT-04 · new
- **Where:** `workflows/WF-001.md:12` (3 occurrences) vs `domain/01-GLOSSARY.md:40`
- **What:** "job" is not a glossary term; the canonical term is "Extraction".
- **Why:** Ubiquitous-language violation (CHECK-SH01).
- **Fix:** Replace "job" by "Extraction" in WF-001 (or add "job" to the "NO usar" column).
```

---

### CAT-05: Contradicciones Entre Documentos

Especificaciones que se contradicen entre sí.

**Señales:**
- Valores diferentes para mismo parámetro
- Flujos incompatibles
- Permisos contradictorios

**Ejemplo de hallazgo:**
```markdown
### CON-001: Extraction timeout 180 s vs 360 s — P1 · CAT-05 · new
- **Where:** `workflows/WF-001.md:67` ("timeout: 360s") vs `nfr/LIMITS.md:34` ("timeout: 180s")
- **What:** Two values for the same timeout; WF-001 is the divergent document (Minority Rule).
- **Why:** Implementers cannot choose; no RN in `CLARIFICATIONS.md` settles it.
- **Fix:** Which value is authoritative? Align WF-001 (or LIMITS.md) and record the decision as an RN.
```

---

### CAT-06: Especificaciones Incompletas

Documentos que faltan o secciones vacías/placeholder.

**Señales:**
- TODOs sin resolver
- Secciones "TBD"
- Referencias a documentos inexistentes
- Campos vacíos en templates

**Ejemplo de hallazgo:**
```markdown
### INC-001: UC-023 has an empty "Exception Flows" section — P1 · CAT-06 · new
- **Where:** `use-cases/UC-023-delete-cv.md:45`
- **What:** The section exists but is empty; deleting a CV with active MatchResults is unspecified.
- **Why:** `domain/05-INVARIANTS.md` has no referential-integrity INV for CV → MatchResult.
- **Fix:** Forbid deletion? Cascade? Soft delete? Fill the section and add the INV.
```

---

### CAT-07: Invariantes Débiles o Ausentes

Reglas de negocio críticas sin invariante formal, o invariantes sin validación especificada.

**Señales:**
- Restricciones mencionadas en texto pero sin INV-ID
- Invariantes sin query de validación
- Reglas de negocio solo en casos de uso (no en INVARIANTS.md)

**Ejemplo de hallazgo:**
```markdown
### INV-001: Score range stated in prose without an invariant — P2 · CAT-07 · new
- **Where:** `use-cases/UC-007.md:34`
- **What:** "el score debe estar entre 0 y 100" has no INV-XXX-NNN.
- **Why:** `domain/05-INVARIANTS.md` has no score-range invariant; nothing validates it.
- **Fix:** Create INV-CVA-NNN (range 0–100, CHECK constraint + Zod validation) and reference it from UC-007.
```

---

### CAT-08: Riesgos de Evolución Futura

Diseños que dificultarán cambios futuros predecibles.

**Señales:**
- Hardcoding de valores que podrían cambiar
- Acoplamiento fuerte entre módulos
- Falta de extensibilidad en enums/estados
- Ausencia de versionado en APIs

**Ejemplo de hallazgo:**
```markdown
### EVO-001: ExtractionStatus is a closed enum — P2 · CAT-08 · new
- **Where:** `domain/04-STATES.md:23`
- **What:** Adding a state requires a migration; no evolution strategy is documented.
- **Why:** `adr/` has no ADR on state evolution (CAT-08 is capped at P2).
- **Fix:** Document the migration process, or an ADR choosing string + validation over a closed enum.
```

---

### CAT-09: Decisiones Implícitas Sin ADR

Decisiones arquitectónicas tomadas sin documentación formal.

**Señales:**
- Tecnologías mencionadas sin justificación
- Patrones usados sin explicar alternativas
- Trade-offs no documentados

**Ejemplo de hallazgo:**
```markdown
### ADR-001: Storage choice (R2) has no ADR — P2 · CAT-09 · new
- **Where:** `workflows/WF-001.md:56`
- **What:** "guardar en R2" with no ADR justifying R2 vs S3 vs GCS.
- **Why:** Data-store choice is a material decision; `adr/` has no storage ADR.
- **Fix:** Create ADR-NNN with context, decision and alternatives considered.
```

---

### Category Disambiguation Rules

When a finding could belong to multiple categories, apply these rules to assign exactly ONE category:

| Overlap | Disambiguation |
|---|---|
| **CAT-01 vs CAT-04** | CAT-01 = vague language ("reasonable", "appropriate"). CAT-04 = terminology inconsistency (synonyms, same concept with different names). If the word is vague → CAT-01. If two documents use different words for the same concept → CAT-04. |
| **CAT-02 vs CAT-07** | CAT-02 = behavior assumed but never stated anywhere. CAT-07 = constraint IS stated in prose but lacks formal INV-ID. If the rule is not mentioned at all → CAT-02. If mentioned but not formalized → CAT-07. |
| **CAT-03 vs CAT-06** | CAT-03 = a specific scenario is not handled ("what if timeout?"). CAT-06 = a structural element is missing (empty section, TBD, broken reference). If a specific scenario is missing from a populated section → CAT-03. If the entire section/field is missing or empty → CAT-06. |
| **CAT-09 materiality** | Only flag missing ADRs for significant architectural decisions (data stores, auth mechanisms, infrastructure platforms, communication protocols). Common industry-standard choices (HTTP, JSON, REST, UTF-8) do NOT require ADRs. |

> A finding MUST be classified under exactly ONE category. Dual-categorization is not permitted.

## Spec-Level Verification (3C Protocol)

> Extends the 3-dimensional verification protocol (used post-implementation by `sdd-task-implementer`)
> to the specification level. Inspired by OpenSpec's `/opsx:verify` stage-agnostic approach.
> These checks complement CAT-01..CAT-09 by providing a structural pass/fail gate before implementation.

### Dimension 1: Completeness (Spec Coverage)

```
CHECK-SC01: Every REQ in requirements/REQUIREMENTS.md traces to at least one spec artifact (UC, WF, contract, or INV)
CHECK-SC02: No orphan specs — every spec artifact traces back to at least one REQ
CHECK-SC03: All spec subdirectories populated — domain/, use-cases/, workflows/, contracts/, nfr/, adr/ each contain at least one document
CHECK-SC04: No placeholder sections — no TBD, TODO, or empty sections remain in any spec document
CHECK-SC05: Traceability chain intact — REQ → UC → WF → API → BDD → INV → ADR linkable end-to-end
```

### Dimension 2: Correctness (Spec-Requirement Alignment)

```
CHECK-SR01: Semantic match — each spec accurately reflects the intent of its traced REQ (not just the letter)
CHECK-SR02: No contradictions — no two spec documents assert conflicting facts about the same concept
CHECK-SR03: INV codes valid — every INV-XXX-NNN referenced in UCs/WFs/contracts exists in domain/05-INVARIANTS.md with complete definition
CHECK-SR04: State transitions consistent — states referenced in UCs and WFs match domain/04-STATES.md exactly
CHECK-SR05: Permission alignment — roles and permissions in UCs match contracts/PERMISSIONS-MATRIX.md
```

### Dimension 3: Coherence (Cross-Spec Consistency)

```
CHECK-SH01: Glossary adherence — all spec documents use only terms defined in domain/01-GLOSSARY.md
CHECK-SH02: Terminology uniformity — same concept uses identical name across all documents (no synonyms)
CHECK-SH03: Cross-references valid — every document reference (UC-XXX, WF-XXX, ADR-XXX, INV-XXX) resolves to an existing document
CHECK-SH04: Value consistency — shared values (timeouts, limits, enums) are identical in every document that mentions them
CHECK-SH05: Format consistency — all documents of the same type follow the same template structure
```

### 3C Verdict

Report the 3C result as the first three rows of the `Gate detail` table of the report (`references/report-template.md` §3): one row per dimension, `PASS n/n` or `FAIL: {failing check ids → finding ids}`. Do not restate the passing checks.

> Any FAIL in Completeness or Correctness blocks pipeline progression to `sdd-plan-architect`.
> Coherence failures are warnings that should be resolved but do not block.
> In fan-out mode each check has one owner (`references/fanout-protocol.md` §4); the main thread merges the auditors' `checks` with its own.

---

## Audit Process

### Execution Strategy (read first)

The full protocol is `references/fanout-protocol.md`. The rules that govern every audit:

1. **Index before files.** Phase 1 builds `$IDX` with one `grep -rn` over `spec/` (headings and id lines, cut at 110 chars). Everything else is opened by section (`sed -n 'a,bp'`, ≤ 60 lines per call) using the index line numbers. **Never `cat` a spec file in the main thread**; a file ≤ 8 k chars may be read whole only by the thread that owns it.
2. **Budget.** The main thread holds at most ~30 k tokens of spec content (index summaries, baseline ids, grep outputs, `sed -n` spot checks of P0/P1 evidence). Each dimension auditor holds its own scope plus ≤ 200 lines of neighbour lookups per finding.
3. **Fan-out by default.** When `spec/` has more than 8 files or more than 40 k chars, Phases 2–5 run in **four parallel dimension auditors** (Domain `DOM-`, Use cases + workflows `UC-`, Contracts + BDD `CON-`, NFR + ADR + runbooks `NFR-`) launched with the `Agent` tool — also under `claude -p`, where the tool is available. Each reads only its directories and returns compact JSON findings; the main thread consolidates, deduplicates, reviews P0/P1 evidence, computes the Gate and writes the report. Auditors run on `model: sonnet` unless `CLAUDE_CODE_SUBAGENT_MODEL` is set (then omit `model`); consolidation and the Gate always use the main model. Smaller specs, `--sequential`, or a tool list without `Agent` → sequential mode in one thread with the same index discipline.
4. **Compact output.** The report is `audits/AUDIT-BASELINE.md` written per `references/report-template.md` (budget ≤ 25 k chars for ≤ 15 requirements). Findings are collected in the JSON shape of the protocol before anything is written.

### Phase 0: Baseline Loading

Before starting the audit, check for an existing `audits/AUDIT-BASELINE.md` (the previous compact report; its `Baseline` and `History` sections are the tracking tables — format in `references/report-template.md` §3).

1. **Read only ids and short descriptions**, never the whole file: `grep -E '^### [A-Z]+-[0-9]+|^\| [A-Z]+-[0-9]+' audits/AUDIT-BASELINE.md` (≤ 3 k tokens).
2. **If it exists:**
   - Rows of `Accepted`, `Won't fix` and `Deferred` are **excluded** from this audit (not re-reported); count them for the header. A `Deferred` row past its `Re-evaluate on` date is re-evaluated and may be re-reported.
   - Findings of the previous body not in those tables are **open**: if detected again they are `persistent` (Persistence Escalation Rule); a finding in a document modified by a previous fix is a `regression` (Phase 6).
   - Carry the `Baseline` and `History` sections forward into the new report; the body is rewritten.
   - In fan-out mode, pass the excluded rows (`ID — short description`) to each auditor as "known findings".
3. **If it does not exist:** first audit — `Delta vs none (first audit)` in the header; all findings are `new`.

---

### Phase 1: Inventory and Index

1. Measure and decide the mode (`fanout-protocol.md` §1): `FILES` and `CHARS` of `spec/**/*.md`.
2. Build the index (`fanout-protocol.md` §2) and read only its summaries: headings per file (structure, gaps in numbering, SH05) and the id set (referenced ids that do not exist → SH03).
3. Record for the Coverage table: every document path found; document versions and dates come from the index lines, not from opening the files.
4. **Fan-out mode:** launch the four auditors now (`fanout-protocol.md` §5–§6, one message with four `Agent` calls or `run_in_background`), then continue with the main-thread checks of §4 while they run. **Sequential mode:** proceed with Phases 2–5 by dimension order (`fanout-protocol.md` §8).

> Phases 2–5 below are the checks; in fan-out mode each one is executed by the auditor that owns the scope (`fanout-protocol.md` §4) and the main thread runs only cross-references, REQ coverage, markers, SC03 and SH05. In sequential mode the main thread runs all of them, section by section.

### Phase 2: Glossary Compliance

1. Extract all terms from `domain/01-GLOSSARY.md`
2. Scan all documents for:
   - Terms not in glossary
   - Synonyms of glossary terms
   - Inconsistent capitalization

### Phase 3: Cross-Reference Analysis

1. Build reference graph (document → documents it references)
2. Identify broken references
3. Identify orphan documents (not referenced by any other)
4. Check bidirectional consistency (A says X, B says Y about same topic)

### Phase 3.5: Value Registry Verification

If `spec/VALUE-REGISTRY.md` exists, use it as the authoritative source for shared values:
1. For every entry in the registry, grep ALL spec documents for that value name
2. Verify the value is identical everywhere it appears
3. Flag any document using a different value for the same metric
4. If the registry does NOT exist, create a finding (CAT-06) recommending its creation, listing all discovered shared values (timeouts, limits, rate limits, enum values)

### Phase 4: Completeness Check

1. For each UC: verify all sections filled
2. For each WF: verify all steps have error handling
3. For each INV: verify validation rule exists
4. For each ADR: verify status is not "Proposed" indefinitely
5. **Scan for `[NEEDS CLARIFICATION]` markers** — Detect all `<!-- [NEEDS CLARIFICATION] NC-NNN: ... -->` comments across spec documents. Each open marker is an **unresolved ambiguity** that the specifications engineer deferred. Report each one as a finding under **CAT-06 (Incomplete Specifications)** with:
   - **ID:** `INC-NNN` (normal finding sequence)
   - **Severity:** At minimum **Medium**; escalate to **High** if the marker blocks a use case's main flow or a contract definition
   - **Location:** The file and line where the marker appears
   - **Problem:** Quote the marker's question verbatim
   - **Question:** "Has this been decided? If so, resolve the marker and record the decision in CLARIFICATIONS.md"
   - Cross-check against `spec/CLARIFICATIONS-PENDING.md` (if it exists) to verify the index is in sync with actual markers in the documents. Report any discrepancies (marker in file but missing from index, or index entry without corresponding marker)

### Phase 5: Defect Detection

Apply each CAT-XX category systematically:
1. Open the sections the index lists for the document (`sed -n`); whole file only if ≤ 8 k chars
2. Apply the category checklist for that document type (`references/audit-checklists.md`, only that section) and the grep patterns of `references/detection-patterns.md`
3. Record findings in the compact shape `{id, sev, cat, doc, line, also, claim, why, fix}` (`fanout-protocol.md` §6) — location + what is wrong + why + the spec-level fix or the question
4. Cross-reference with related documents through `grep -n` / `sed -n` on the cited lines, never by reading the neighbour whole

### Phase 6: Regression Verification

If a previous audit exists, perform regression analysis after defect detection:

1. **Identify modified files since last audit:**
   - If git is available: use `git diff --name-only` between the last audit tag (e.g., `AUDIT-vX.Y-resolved`) and HEAD
   - If git is NOT available: compare file modification timestamps against the last audit report date
   - If no tag exists, use the last audit report date as reference
   - Focus on files within the `spec/` directory

2. **For each modified file, verify fix integrity:**
   - Check that fixes did not introduce new inconsistencies
   - Verify that the fix aligns with the original audit finding's intent
   - Confirm cross-references remain valid after the change

3. **Cross-check high-coupling documents:**
   When any of these files was modified, verify ALL its dependents:
   - `02-ENTITIES.md` modified → check `03-VALUE-OBJECTS.md`, `04-STATES.md`, `05-INVARIANTS.md`, all UCs that reference modified entities
   - `03-VALUE-OBJECTS.md` modified → check `02-ENTITIES.md` (field types), all UCs and contracts using those VOs
   - `04-STATES.md` modified → check `05-INVARIANTS.md` (state-dependent invariants), all UCs with state transitions, all WFs
   - `05-INVARIANTS.md` modified → check UCs that enforce those invariants, contracts that validate them
   - `PERMISSIONS-MATRIX.md` modified → check ALL API contracts for endpoint-permission alignment
   - `CLARIFICATIONS.md` modified → check UCs referenced by each modified RN

4. **Enum/Value-Object sync verification:**
   - If an enum was added/modified in any document, grep ALL spec files for that enum name
   - Verify the enum values are identical everywhere they appear
   - Flag any document that uses the old values or is missing the new values

5. **Classify each finding:**
   - **new**: Not present in any previous audit
   - **persistent**: Was reported in previous audit and remains unfixed
   - **regression**: Was NOT in previous audit but appears in a file that was modified to fix a previous finding

---

### Phase 7: Finding Consolidation

After detecting all findings (Phase 5) and classifying them (Phase 6), consolidate findings to reduce noise and improve actionability. In fan-out mode this phase starts by merging the four auditors' JSON results (`fanout-protocol.md` §7: deduplication, baseline filter, final ids by category, severity review of every P0/P1 against the cited lines); the rules below apply in both modes.

#### 7.1 Pattern Batching

When the same defect type appears across multiple documents, report as ONE batched finding:

```
BAD:  INC-001: Missing BDD for UC-003
      INC-002: Missing BDD for UC-005
      INC-003: Missing BDD for UC-007
      (3 separate findings)

GOOD: INC-001: Missing BDD scenarios for UC-003, UC-005, UC-007
      Locations: [list all affected files]
      (1 batched finding with 3 locations)
```

#### 7.2 Family Grouping

These finding families MUST be discovered and reported together in a single pass — never incrementally across iterations:

| Family | What to check | How to check |
|---|---|---|
| Missing BDD | ALL UCs for BDD coverage | For each UC, verify at least 1 happy + 1 error BDD scenario exists |
| Missing API error codes | ALL API contracts for error responses | For each endpoint, verify 401, 403, 404, 409, 429 are documented where applicable |
| Terminology violations | ALL docs for glossary compliance | Grep for every "NO usar" term from glossary across all spec/ files |
| Value inconsistencies | ALL shared values across ALL docs | For each value in LIMITS.md/PERFORMANCE.md, grep all spec/ files for that value |
| Missing invariants | ALL UCs for unformalized constraints | Scan UC text for "must", "shall not", "always", "never", "at least", "at most" without INV-ID reference |

#### 7.3 Cascade Dependency

When fixing finding X will automatically resolve findings Y and Z, mark the dependency:

```
INC-005: Missing VALIDATION_ERROR in API-002-04 [CASCADE-DEP: INC-004]
```

Cascade-dependent findings are NOT separately tracked for fix/verification — they resolve when their parent is fixed.

---

### Convergence Protocol

The audit process MUST converge. These rules replace the implicit unbounded loop.

#### Maximum Audit Cycles

```
Cycle 1: DISCOVERY — Full comprehensive audit (Phases 0-7 above). All categories, all documents.
Cycle 2: FIX — Apply corrections for findings with FIX disposition (Mode Fix).
Cycle 3: VERIFICATION — Narrow-scope verification of fixes only (see Verification Rules below).
```

After Cycle 3, if Critical findings remain, present the user with explicit options:
- Fix critical findings and run ONE more verification pass
- Accept risk and proceed with documented acknowledgment

**Hard limit: 5 cycles maximum.** If convergence is not reached in 5 cycles, remaining Medium/Low findings are automatically moved to baseline as `deferred`.

#### Quality Gate Thresholds

Replace the "ALL PASS" requirement with tiered thresholds:

| Gate Level | Criteria | Can proceed to plan-architect? |
|---|---|---|
| **PASS** | 0 Critical, 0 High, ≤5 Medium (all Low accepted/deferred) | Yes |
| **CONDITIONAL PASS** | 0 Critical, ≤2 High (documented), ≤10 Medium | Yes, with advisory warnings |
| **FAIL** | Any Critical unresolved, or >2 High unresolved | No — must fix or accept |

The auditor MUST recommend the appropriate gate level. The user decides whether to proceed.

#### Verification Rules (Cycle 3)

During verification, the auditor MUST:
- ✅ Verify that each fixed finding is actually resolved
- ✅ Check for regressions in documents directly modified by fixes
- ✅ Check immediate dependents of modified documents (per Propagation Checklist)

During verification, the auditor MUST NOT:
- ❌ Perform a full Phase 1-7 sweep on unchanged documents
- ❌ Discover new finding categories not found in the Discovery cycle
- ❌ Apply deeper analysis than was applied in Discovery
- ❌ Report new Low/Medium findings in documents NOT directly affected by fixes

New findings discovered during verification:
- If **Critical**: Report and require fix (extends verification by exactly 1 finding)
- If **High**: Report but add to audit baseline for next full audit
- If **Medium/Low**: Log as advisory note, do NOT count against the gate

Verification output is the ≤ 6-line `Verification (cycle 3)` block appended to the report (`references/report-template.md` §3): one line per fixed finding with its evidence `doc:line`, plus regressions, cross-reference count and new findings. It runs sequentially in the main thread (no fan-out).

#### Triage Phase

After Discovery (Cycle 1) and before Fix (Cycle 2), present ALL findings to the user for triage:

| Disposition | Meaning | Default for... |
|---|---|---|
| `FIX` | Must be corrected before proceeding | All Critical, all High |
| `ACCEPT` | Known limitation, documented and accepted | — |
| `DEFER` | Will address later (set re-evaluation date) | — |
| `WONT_FIX` | By design, not a defect in this context | — |

Default for Medium: `FIX` (user can override to ACCEPT/DEFER).
Default for Low: User's choice (present options).

Only findings with `FIX` disposition proceed to Mode Fix. Others go directly to baseline.

## Audit Report Format

The report is **`audits/AUDIT-BASELINE.md`**, one file, written with the compact template of `references/report-template.md` (mandatory; read it before writing). Its sections, in order:

| Section | Content | Cap |
|---|---|---|
| Header | Audit id, date, specs version, docs audited, mode (`fanout`/`sequential`), cycles; **Gate** with a one-clause reason; counters P0/P1/P2/P3, batched, cross-validated, excluded by baseline; delta vs the previous audit (new/persistent/regression/resolved); top 3 categories | ≤ 1 200 chars |
| Gate detail | One table: 3C rows (failing check ids → finding ids only) + the six Quality Metrics | 9 rows |
| Findings P0–P2 | One block per finding: `ID: title — P{n} · CAT · status`, **Where** (`doc:line`), **What**, **Why**, **Fix** (≤ 3 lines: spec-level correction or the question that unblocks it) | ≤ 900 chars each |
| Findings P3 | One table row per finding: ID, Cat, Where, What (≤ 12 words), Fix (≤ 12 words) | ≤ 220 chars each |
| Coverage | One row per audited document: P0/P1/P2/P3 counts + ids. No prose, no "no issues found in…", no spec content | 1 row/doc (> 40 docs: clean docs collapsed into one row) |
| Not audited | Only when non-empty | 1 line/doc |
| Baseline | Accepted / Won't fix / Deferred / Resolved tables (carried forward, updated by Mode Fix) | 1 row/finding |
| History | One row per audit run (counts, Gate, mode, report chars) | 1 row/run |

Budget: **≤ 25 k chars for ≤ 15 requirements**, +1 k per extra requirement, hard cap 60 k (`report-template.md` §1). No empty sections, no per-category tables with zero rows, no restated spec content (quotes ≤ 12 words), no priority lists repeating the ids, no second copy of the report. Severities are written P0–P3 (P0 = Critical … P3 = Low).

> Omitted detail is not lost: every finding carries `doc:line`, so the document is reopened from the id; Mode Fix works on the findings' Where/What/Fix, not on the report's prose; auditors' JSON is the working set during consolidation. Record `wc -c` of the report as `metrics.report_chars`.

---

## Quality Metrics (SWEBOK v4 Ch10 — Software Quality)

The auditor MUST compute these metrics and render them as the last six rows of the `Gate detail` table of the report (`references/report-template.md` §3) — no separate scorecard section.

| Metric | Definition | Target | Formula |
|--------|-----------|--------|---------|
| **Spec Defect Density** | Critical/High findings per spec document | < 2 critical per document | `critical_findings / total_documents` |
| **Traceability Coverage** | % of requirements with at least one linked spec (UC, WF, or contract) | 100% | `reqs_with_spec / total_reqs × 100` |
| **Orphan Rate** | % of spec documents without traceability to any requirement | 0% | `orphan_specs / total_specs × 100` |
| **Clarification Density** | Open `[NEEDS CLARIFICATION]` or `[TBD]` markers per document | 0 before downstream | `open_markers / total_documents` |
| **Audit Pass Rate** | % of spec documents passing all checks (zero Critical/High findings) | > 90% at baseline | `clean_docs / total_documents × 100` |
| **Cross-Reference Validity** | % of inter-document references that resolve correctly | 100% | `valid_refs / total_refs × 100` |

### Quality Scorecard Rendering

Each metric is one row `| {Metric} | {value} ({target}) {PASS/FAIL} |` of the `Gate detail` table; the overall Gate goes in the header line (`**Gate:** PASS | CONDITIONAL PASS | FAIL — {reason}`), decided by the Quality Gate Thresholds of the Convergence Protocol. PASS = proceed. CONDITIONAL PASS = proceed with advisory. FAIL = must resolve P0/P1 findings first.

---

## Severity Classification

| Severidad | Label | Criterio | Pregunta clave |
|-----------|-------|----------|----------------|
| **Crítico** | **P0** | Bloquea implementación o causa comportamiento indefinido en producción | ¿Bloquea implementación? |
| **Alto** | **P1** | Riesgo de bugs significativos o violación de requisitos | ¿Causa bugs o viola requisitos? |
| **Medio** | **P2** | Inconsistencia que dificulta mantenimiento o comprensión | ¿Dificulta comprensión? |
| **Bajo** | **P3** | Mejora de claridad o estilo sin impacto funcional | ¿Solo mejora estilo? |

Reports, JSON findings and `pipeline-state.json` use the P0–P3 labels (`critical`/`high`/`medium`/`low` keys in metrics are unchanged).

### Signal Filters

Apply these filters BEFORE assigning severity to reduce noise:

1. **Evidence requirement:** Only report findings with concrete evidence from 2+ documents. A finding based on a single document and a subjective interpretation is NOT a valid finding.

2. **CAT-08 severity cap:** Evolution Risks (CAT-08) have a **maximum severity of Medium**. They cannot be Critical or High because they are speculative about future needs, not current defects.

3. **Style/format severity cap:** Findings about naming conventions, lowercase/uppercase inconsistencies, or formatting issues have a **maximum severity of Low**.

4. **Implementation-blocking test:** Use this decision tree:
   ```
   Does this defect block implementation?
   ├── YES → Crítico or Alto
   │   ├── Undefined behavior in production? → Crítico
   │   └── Risk of bugs but workaround exists? → Alto
   └── NO → Medio or Bajo
       ├── Hinders comprehension/maintenance? → Medio
       └── Style/clarity improvement only? → Bajo
   ```

### Persistence Escalation Rule

Findings that persist across audit iterations MUST be escalated:

| Persistence | Action |
|---|---|
| Found in 1 audit, not yet fixed | Normal severity — no change |
| Persists across 2 audits without resolution | Severity escalates by 1 level (Low→Medium, Medium→High) |
| Persists across 3+ audits | User MUST assign explicit disposition: `fix`, `accept`, `defer`, or `wont_fix`. Cannot remain unresolved. |

> **Rationale:** Persistent findings create noise in audit reports and mask new issues. Escalation creates pressure to resolve or explicitly accept them.

---

## Checklist de Auditoría Rápida

### Por Documento

- [ ] ¿Tiene versión y fecha de actualización?
- [ ] ¿Usa solo términos del glosario?
- [ ] ¿Todas las referencias a otros docs son válidas?
- [ ] ¿Tiene todas las secciones del template completas?
- [ ] ¿Los valores numéricos tienen unidades?
- [ ] ¿Los flujos tienen manejo de errores?

### Por Repositorio

- [ ] ¿El glosario está actualizado?
- [ ] ¿Hay ADR para cada decisión tecnológica mencionada?
- [ ] ¿Cada invariante tiene validación especificada?
- [ ] ¿Los timeouts son consistentes entre documentos?
- [ ] ¿Los rate limits son consistentes?
- [ ] ¿Hay UC para cada funcionalidad mencionada en OVERVIEW?

---

## Mode Fix: Apply Audit Corrections

> **Principio:** Corregir es integrar respuestas verificadas en la especificación, no inventar comportamiento.

After an audit has been performed AND audit questions have been answered, use Mode Fix to systematically apply corrections. This replaces the need for a separate `sdd-spec-fixer` skill.

### When to Use Mode Fix

- An audit report has been produced AND its questions have been answered
- Specification defects need to be systematically corrected
- Post-audit corrections require traceability and ADR creation

### Fix Principles

1. **No Invention** — Every change MUST trace to an audit finding + validated answer
2. **No Code** — Only specification text, invariants, ADRs, and clarifications
3. **Full Traceability** — Every correction references: Finding ID, answer, document(s) modified, change type
4. **No Silent Conflict Resolution** — Create ADR for any non-trivial decision
5. **Zero Omissions** — Every finding in the audit report MUST be addressed

### Correction Categories

| Audit Category | Correction Type | Primary Action |
|----------------|-----------------|----------------|
| AMB (Ambiguities) | SPEC CHANGE | Rewrite vague text with precise, quantified language |
| IMP (Implicit Rules) | NEW INVARIANT + SPEC CHANGE | Formalize implicit behavior as invariant |
| SIL (Dangerous Silences) | SPEC CHANGE | Add missing flows, error handling, edge cases |
| SEM (Semantic) | SEMANTIC CLARIFICATION | Align terminology with glossary |
| CON (Contradictions) | SPEC CHANGE + ADR REQUIRED | Resolve conflict, update all docs, document decision |
| INC (Incomplete) | SPEC CHANGE | Complete missing sections, fill TBDs |
| INV (Weak Invariants) | NEW INVARIANT | Formalize rules with ID, validation, constraint |
| EVO (Evolution Risks) | ADR REQUIRED | Document extensibility strategy |
| ADR (Missing ADRs) | ADR REQUIRED | Create ADR with context, decision, alternatives |

### Fix Process

#### Fix Phase 0: Locate Audit Report

1. Open `audits/AUDIT-BASELINE.md` (the compact report; a `--focused` fix reads `audits/AUDIT-FOCUSED-*.md`). It is ≤ 25 k chars: read it whole.
2. Extract EVERY finding with: ID, severity (P0–P3), category, **Where** (`doc:line`), **What**, **Why**, **Fix** (the proposed correction or the open question), and the answer received (from the user, the questions file, or `[NO ANSWER]`). The report's prose is not the working set: the cited lines are — open them with `sed -n` when applying a correction.
3. Count findings by severity and disposition and confirm with the user (or apply the delegated scope, e.g. "P0/P1 without asking").

#### Fix Phase 1: Create Corrections Plan

Create `audits/CORRECTIONS-PLAN-AUDIT-vX.X.md` per `references/report-template.md` §4 (budget ≤ 12 k chars for ≤ 15 requirements):

- Summary table: totals per severity and disposition (FIX / ACCEPT / DEFER / WONT_FIX).
- One block per **P0–P2 finding with FIX disposition**, referenced by id (do not copy What/Why from the report): decision (answer or chosen option), change (≤ 3 lines, `doc:line`), before → after limited to the changed sentence or value (≤ 4 lines; omitted for new sections/ADRs), dependents to update (Propagation Checklist), rejected alternative (one line), dependencies, upstream Tier.
- **Every other finding** (P3, and P0–P2 with ACCEPT/DEFER/WONT_FIX or `[NO ANSWER]`) is one row of the `Dispositions` table: id, severity, disposition, reason or re-evaluation date.

#### Fix Phase 1.5: User Workflow Decision

Ask the user:
- **Option 1: Batch mode** — Apply all recommended solutions in priority order
- **Option 2: Interactive mode** — Decide one by one

#### Fix Phase 2: Execute Corrections

Process in priority order: Critical → High → Medium → Low.
Within each severity: CON first, then SIL, then others.

**Propagation Checklist:** When modifying any spec document, verify and update ALL dependent documents atomically. Incomplete propagation is the #1 cause of audit regressions.

| If you modify... | You MUST also verify and update... |
|---|---|
| `domain/01-GLOSSARY.md` | ALL spec documents for term usage alignment |
| `domain/02-ENTITIES.md` | `03-VALUE-OBJECTS.md`, `04-STATES.md`, `05-INVARIANTS.md`, all UCs referencing modified entities, all API contracts with those entities in schemas |
| `domain/03-VALUE-OBJECTS.md` | `02-ENTITIES.md` (field types), all UCs and contracts using those VOs, `05-INVARIANTS.md` if VO has constraints |
| `domain/04-STATES.md` | `05-INVARIANTS.md`, all UCs with state transitions, all WFs, all BDD scenarios testing state changes |
| `domain/05-INVARIANTS.md` | UCs that enforce those invariants, contracts that validate them, BDD scenarios that test them |
| `contracts/PERMISSIONS-MATRIX.md` | ALL API contracts for endpoint-permission alignment |
| Any UC exception flow | Corresponding API contract error codes, BDD error scenarios, `03-VALUE-OBJECTS.md` ErrorResponse |
| Any enum value in any document | ALL documents that reference that enum (use grep to find all occurrences) |
| `nfr/LIMITS.md` or `nfr/PERFORMANCE.md` | All WFs (timeouts), all API contracts (rate limits), all UCs (limits in text) |
| Any terminology change | ALL spec documents for the old term (find-and-replace across entire spec/) |

**Propagation Verification:** After applying fixes, run `grep -r "OLD_TERM\|OLD_VALUE" spec/` for every changed term or value to confirm zero residual occurrences of the old version.

**Commit format:**
```
fix(specs): resolve {FINDING-ID} - {brief description}

Audit: AUDIT-vX.X
Severity: {severity}
Correction: {SPEC CHANGE | NEW INVARIANT | ADR REQUIRED | SEMANTIC CLARIFICATION}
Documents: {comma-separated list}
```

#### Fix Phase 3: Verification Summary and Baseline Update

1. In `audits/AUDIT-BASELINE.md`: append ` — RESOLVED ({artifact})` to the heading of each fixed P0–P2 finding; add one row per fixed finding to `Baseline › Resolved`, per accepted/deferred/won't-fix disposition to the matching table; update the `History` row (Gate after fix).
2. Append the ≤ 8-line `Fix cycle` block (`references/report-template.md` §3): fixed/skipped/open counts with ids, new artifacts, documents modified (count), breaking changes, commits or the reason they were not made. No per-document tables.
3. Suggest tagging: `git tag AUDIT-vX.X-resolved`

#### Fix Phase 4: Upstream Impact Analysis

> **Principio:** Las correcciones en especificaciones pueden revelar que los requisitos de origen están incompletos o desalineados. Esta fase cierra el ciclo de retroalimentación hacia arriba sin violar Art. 4 (el spec-auditor detecta pero no modifica requisitos — delega a req-change).

After all corrections are applied and the baseline is updated, analyze whether the corrections impact upstream requirements.

##### Step 4.1: Classify Corrections by Traceability Tier

For each corrected finding, classify its upstream impact using the 3-Tier system:

| Tier | Criteria | Examples | Action |
|---|---|---|---|
| **Tier 1** — User-visible behavior change | Correction changes behavior a REQ explicitly defined, OR introduces new user-facing functionality with no tracing REQ | Changing a timeout that a REQ specified; adding a new UC without REQ; new user notification flow | **Must propagate** to requirements via `sdd-req-change` |
| **Tier 2** — Technical detail derived from existing REQ | Correction adds error flows, invariants, BDD scenarios, API details, or state transitions that are technical elaborations of behavior already covered by a REQ | Adding 404 to an API endpoint; formalizing an invariant from UC text; adding BDD edge case for existing UC | **Register** in `spec/DERIVED-SPECS.md` — no REQ needed |
| **Tier 3** — Cosmetic/structural | Terminology fix, format correction, cross-reference fix, filling TBD with info already implied | Fixing a glossary term; reordering error table; adding missing cross-reference | **No action** needed |

**Classification Decision Tree:**
```
Does this correction change user-visible behavior?
├── YES → Does a REQ already define this behavior?
│   ├── YES → Does the correction CONTRADICT the REQ?
│   │   ├── YES → Tier 1 (MODIFY: REQ must be updated)
│   │   └── NO  → Tier 2 (technical elaboration of existing REQ)
│   └── NO  → Tier 1 (ADD: new REQ needed)
└── NO  → Is it a technical detail (error code, invariant, BDD)?
    ├── YES → Can it trace to an existing REQ indirectly?
    │   ├── YES → Tier 2 (derived from REQ-X)
    │   └── NO  → Tier 1 (new business rule without REQ)
    └── NO  → Tier 3 (cosmetic)
```

##### Step 4.2: Cross-Reference Against Requirements

For each Tier 1 and Tier 2 correction:

1. **Identify the REQ(s)** that the corrected spec document traces to (via Refs field, UC→REQ mapping, or INV→REQ chain)
2. **For Tier 1 (MODIFY):** Compare the REQ's statement and acceptance criteria against the corrected spec. Flag if:
   - The REQ statement contradicts the corrected behavior
   - The REQ acceptance criteria are incomplete (missing cases added by the correction)
   - The REQ's scope is narrower than what the correction defines
3. **For Tier 1 (ADD):** Verify there is truly no REQ that covers this functionality. Search:
   - Direct REQ references in the spec document
   - Implicit coverage via parent REQs or domain-level REQs
   - If none found → mark as `[PENDING REQ]`
4. **For Tier 2:** Record the derived-from REQ in `spec/DERIVED-SPECS.md`

##### Step 4.3: Update DERIVED-SPECS.md

After classification, update `spec/DERIVED-SPECS.md` with ALL Tier 1 and Tier 2 corrections:

```markdown
## Audit-Derived Specifications (AUDIT-vX.X)

| Spec Artifact | Finding ID | Derived From | Tier | Justification |
|---|---|---|---|---|
| INV-SRV-003 | INV-001 | REQ-F-008 | 2 | Formalization of "score between 0 and 100" |
| EX3 in UC-005 | SIL-002 | REQ-F-012 | 2 | Error flow: timeout handling |
| UC-011 (health check) | INC-005 | — | 1 | **[PENDING REQ]** New user-visible endpoint |
| ADR-007 | ADR-001 | — | 2 | Technical decision, no REQ needed |
```

##### Step 4.4: Generate Impact Summary

Present to the user:

```markdown
## Upstream Impact Analysis

| # | Finding ID | Correction Summary | Tier | REQ Affected | Description |
|---|---|---|---|---|---|
| 1 | {ID} | {brief} | 1 (MODIFY) | REQ-F-012 | REQ needs update: {what changed} |
| 2 | {ID} | {brief} | 1 (ADD) | [PENDING REQ] | New requirement needed: {what's missing} |
| 3 | {ID} | {brief} | 2 | REQ-F-008 | Derived — registered in DERIVED-SPECS.md |
| 4 | {ID} | {brief} | 3 | — | Cosmetic — no action |

**Totals:** {N} Tier 1, {N} Tier 2, {N} Tier 3
**Tier 1 pending REQs:** {N}
```

##### Step 4.5: Pipeline Gate and User Decision

**Pipeline Gate Rule:**
- **≤3 Tier 1 items without REQs:** Advisory — pipeline can proceed. Items are registered as `[PENDING REQ]` in DERIVED-SPECS.md
- **>3 Tier 1 items without REQs:** **Pipeline BLOCKED** — too many spec artifacts lack requirement backing. Must create REQs before proceeding to plan-architect.

**User Decision (when Tier 1 items exist):**

- **Option 1: Invoke req-change now** (Recommended) — Execute `/sdd-req-change` with pre-populated CRs. Pass:
  - CR table with: CR-ID, Type (ADD/MODIFY), REQ-ID (or "new"), description, source finding ID, Tier
  - Note that spec documents are already corrected — only requirements need updating
  - Audit ID for traceability
- **Option 2: Generate impact report only** — Write to `audits/UPSTREAM-IMPACT-AUDIT-vX.X.md` for later review. Tier 1 items remain as `[PENDING REQ]`
- **Option 3: Accept risk** — Acknowledge Tier 1 items as intentional spec-level additions without formal REQs. Mark as `[ACCEPTED WITHOUT REQ]` in DERIVED-SPECS.md with user justification

> **Note:** If Option 1 is selected, the req-change skill handles all requirement modifications. The spec-auditor only detects and classifies — it never writes to `requirements/`.

> **Station mode** (`SDD_ROLE` set, or a role resolved from `.claude/sdd-sessions.json`, and the role is not `sdd-lead`): do not pick an option. Write the Upstream Impact table, leave Tier 1 items as `[PENDING REQ]`, append the decision as a `Q-<role>-NNN [OPEN]` block (Options 1/2/3 above as A/B/C, A recommended; `Blocks:` = pipeline gate to plan-architect) to `$STATE_ROOT/.sdd/questions-<role>.md` following the plugin-root `references/async-questions.md`, finish the audit report and Persist Summary, then send the handoff with `status=blocked questions=<n> file=<path>` and end the turn. On resume, apply the `[ANSWERED]` option exactly as if the user had chosen it. Without a role: ask the user as above.

### Fix Constraints

1. NEVER generate code — only specification text, invariants, ADRs
2. NEVER invent behavior — every change traces to finding + answer
3. NEVER resolve conflicts silently — create ADR
4. ALWAYS show before/after for every spec change — limited to the changed sentence or value (≤ 4 lines), never the surrounding section
5. ALWAYS make atomic commits per correction
6. NEVER skip a finding — every one MUST appear in the corrections plan: P0–P2 with FIX as a block, all others as one row of the Dispositions table
7. NEVER modify requirements directly — upstream impacts are detected and delegated to req-change
8. ALWAYS classify corrections by Tier (1/2/3) and register Tier 1-2 in `spec/DERIVED-SPECS.md`

---

## Post-Audit Traceability Reconciliation

After the complete audit+fix cycle finishes (Discovery → Fix → Verification), run a final traceability reconciliation before the pipeline advances to `sdd-plan-architect`.

### Reconciliation Process

1. **Scan all spec artifacts:** List every UC, WF, INV, API contract, BDD scenario, and ADR in `spec/`
2. **For each artifact, check traceability:**
   - Does it trace to a REQ in `requirements/REQUIREMENTS.md`? → OK
   - Does it appear in `spec/DERIVED-SPECS.md` as Tier 2? → OK (derived, documented)
   - Does it appear in `spec/DERIVED-SPECS.md` as Tier 1 with `[ACCEPTED WITHOUT REQ]`? → OK (accepted)
   - Does it appear in `spec/DERIVED-SPECS.md` as Tier 1 with `[PENDING REQ]`? → **Flag**
   - Does it NOT appear anywhere? → **Untraced artifact** — must be classified

3. **Report:**

```markdown
## Traceability Reconciliation Report

| Status | Count | Details |
|--------|-------|---------|
| Traced to REQ | {N} | Fully traceable |
| Derived (Tier 2) | {N} | Documented in DERIVED-SPECS.md |
| Accepted without REQ (Tier 1) | {N} | User explicitly accepted |
| Pending REQ (Tier 1) | {N} | **Action needed** |
| Untraced | {N} | **Must classify** |

**Pipeline gate:** {PASS / BLOCKED}
```

4. **Pipeline Gate:**
   - **PASS** if: Pending REQ ≤ 3 AND Untraced = 0
   - **BLOCKED** if: Pending REQ > 3 OR Untraced > 0

5. **For untraced artifacts:** Present to user for classification (Tier 1/2/3) and register in DERIVED-SPECS.md

---

## Integration with Pipeline

This skill is **Step 3** of the SDD pipeline, covering both audit and fix:

```
sdd-specifications-engineer (create) → sdd-spec-auditor (audit) → sdd-spec-auditor (fix) → sdd-spec-auditor (re-audit)
```

| Mode | Input | Output |
|------|-------|--------|
| Mode Audit | Specifications + previous `audits/AUDIT-BASELINE.md` | `audits/AUDIT-BASELINE.md` (compact report + Baseline/History tables) |
| Mode Fix | `audits/AUDIT-BASELINE.md` + Answers | Corrected specs + `audits/CORRECTIONS-PLAN-AUDIT-vX.X.md` + Baseline update + Upstream impact analysis |
| Mode Focused | Change Report + Specifications subset | `audits/AUDIT-FOCUSED-{id}.md` on changed documents |

### Invocation

```bash
/sdd-spec-auditor                                                    # Full audit (default; fan-out by dimension when spec/ > 8 files or > 40 k chars)
/sdd-spec-auditor --sequential                                       # Force one thread (debugging, or when the Agent tool is unavailable)
/sdd-spec-auditor --fix                                              # Apply corrections from answered audit
/sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{id}.md   # Focused audit on changed documents only (triggered by sdd-req-change cascade)
```

### Mode Focused (`--focused`)

When `--focused` is provided together with `--scope` pointing to a Change Report, the auditor operates in a reduced-scope mode:

1. **Scope restriction:** Only audit the documents listed in the Change Report's "Documents Modified" section. All other spec documents are treated as unchanged context (read but not audited).
2. **Skip full cross-document audit:** Do NOT perform a full Phase 1-6 sweep. Instead, focus exclusively on verifying alignment and consistency of the changed documents against each other and against their immediate neighbors in the traceability chain.
3. **Output:** Generate a focused audit report at `audits/AUDIT-FOCUSED-{change-report-id}.md` (e.g., `audits/AUDIT-FOCUSED-CR-007.md`). It uses the compact template (`references/report-template.md` §3, without the Baseline and History sections), the same categories (CAT-01..CAT-09) and severity classification, and includes only findings related to the modified documents. Execution is sequential unless the change set itself exceeds the fan-out threshold.
4. **3C Verification:** Run the 3C Protocol checks (Completeness, Correctness, Coherence) scoped to the changed documents only. The verdict applies to the change set, not to the entire specification.
5. **Cascade origin:** This mode is typically invoked automatically by `sdd-req-change` Phase 9 (Pipeline Cascade) after requirements changes have been propagated to spec documents. It provides a lightweight validation gate without requiring a full re-audit.

> **Note:** If the focused audit reveals Critical or High findings, the user should consider running a full audit (`/sdd-spec-auditor` without `--focused`) to check for broader ripple effects.

**Full pipeline:**
```
sdd-requirements-engineer → requirements/REQUIREMENTS.md
sdd-specifications-engineer → spec/
sdd-spec-auditor (audit) → audits/AUDIT-BASELINE.md
sdd-spec-auditor (fix) → spec/ (corrections) + audits/CORRECTIONS-PLAN-*.md
  └─ Phase 4: upstream impact? ──YES──→ sdd-req-change → requirements/ (updated)
                                 NO
                                 ↓
sdd-plan-architect → plan/
sdd-task-generator → task/
sdd-task-implementer → src/, tests/
```

---

## Multi-Agent Protocol (fan-out by dimension)

Fan-out is the default execution mode above the threshold (Execution Strategy). Full protocol — mode decision, index commands, budgets, scopes, launch parameters, auditor prompt, JSON shape and consolidation — in `references/fanout-protocol.md`.

### Agent ID Prefixes

<!-- Standard SDD agent prefix convention: prefixes map to spec/ subdirectories.
     DOM- → domain/, UC- → use-cases/ + workflows/, CON- → contracts/ + tests/,
     NFR- → nfr/ + adr/ + runbooks/.
     All SDD skills sharing multi-agent protocols MUST use these same prefixes. -->

Each auditor uses its prefix for **provisional** ids in its JSON; the consolidator assigns the final category ids and keeps the provisional one as `Source`:

| Auditor | Prefix | Reads ONLY | Owns corpus-wide (grep) |
|---------|--------|------------|-------------------------|
| Domain | `DOM-` | `spec/domain/`, `spec/CLARIFICATIONS.md` | Terminology violations; rules without invariant |
| Use cases / Workflows | `UC-` | `spec/use-cases/`, `spec/workflows/` | Unformalized constraints in UC text; state transitions vs `04-STATES.md` |
| Contracts / BDD | `CON-` | `spec/contracts/`, `spec/tests/` | Missing BDD per UC; missing API error codes; permissions |
| NFR / ADR / Runbooks | `NFR-` | `spec/nfr/`, `spec/adr/`, `spec/runbooks/`, `spec/VALUE-REGISTRY.md` | Shared-value inconsistencies; ADR status/materiality |
| Main thread | — | index, `README.md`, `TRACEABILITY-MATRIX.md`, `DERIVED-SPECS.md`, `CLARIFICATIONS-PENDING.md`, REQ ids | Cross-references, REQ coverage, markers, SC03, SH05, baseline, regression |

Auditors: `subagent_type: general-purpose`, `model: sonnet` (omit when `CLAUDE_CODE_SUBAGENT_MODEL` is set), read-only, return JSON only (≤ 6 k chars, ≤ 25 findings, P0 first), never write files, never Persist Summary or Handoff.

### Consolidation (main thread, main model)

1. Merge the four JSON results; `docs_read` union → Coverage table.
2. Deduplicate: same document + same line (±5) or section + same defect type → keep the most complete finding, union the locations, mark `[CROSS-VALIDATED]` (highest confidence; both `Source` prefixes kept). A contradiction reported from both sides is one finding located in the divergent document (Minority Rule).
3. Apply the baseline filter (Phase 0) and the Phase 7 batching/cascade rules across dimensions.
4. Assign final ids per category (`AMB- IMP- SIL- SEM- CON- INC- INV- EVO- ADR-`) in severity order; the final `CON-` means CAT-05, not the Contracts auditor.
5. Review every P0/P1 against its cited lines (`sed -n`, ≤ 60 lines) before it enters the report; downgrade or drop without evidence.
6. Compute 3C, metrics and Gate; write the report; Persist Summary with `metrics.mode = "fanout"`.

---

## Audit Stability Rules

These rules prevent audit noise and ensure consistent, actionable results across audit iterations:

### Rule 1: No Re-Reporting Resolved Findings

Do not report findings that were reported AND resolved in previous audits. Check the baseline file (`AUDIT-BASELINE.md`) before reporting. If a finding matches a baseline entry with status `accepted`, `wont_fix`, or `resolved`, exclude it.

### Rule 2: Respect Design Decisions

Do not report as a defect something that is a documented design decision. Before flagging a potential issue:
- Check `adr/` for an ADR that explains the decision
- Check `CLARIFICATIONS.md` for a business rule that justifies it
- If an ADR or RN covers it, it is NOT a defect — skip it

### Rule 3: Minority Rule for Contradictions

If a value appears in N documents and only 1 document differs:
- The defect is in the **1 divergent document**, NOT in all N documents
- Report: "Document X has value Y, but N-1 other documents consistently use value Z"
- Do NOT report N separate findings for the same contradiction

### Rule 4: Precision Over Volume

Prefer **precise findings with clear fixes** over **general observations**:

```
BAD:  "Several documents use inconsistent terminology"
GOOD: "UC-015:34 uses 'job' instead of 'Extraction' (per 01-GLOSSARY.md)"

BAD:  "Security could be improved"
GOOD: "UC-023 lacks authorization check — no role specified for DELETE operation (see PERMISSIONS-MATRIX.md)"
```

Every finding MUST include:
- Exact file and section/line
- The specific value or text that is wrong
- What the correct value should be (or a question to determine it)
- Evidence from 2+ documents (for cross-document findings)

---

## Important Constraints

1. **NUNCA proponer implementación** - Solo identificar el problema y formular pregunta
2. **NUNCA asumir comportamiento** - Si no está especificado, es un hallazgo
3. **SIEMPRE indicar ubicación exacta** - Documento y línea (`doc:line`); es lo que permite volver al documento desde el informe compacto
4. **SIEMPRE cruzar documentos** - Un hallazgo puede involucrar múltiples docs
5. **SIEMPRE cerrar con resolución** - El hallazgo termina con `Fix` (≤ 3 líneas): la corrección a nivel de especificación o la pregunta que hay que responder antes de poder escribirla
6. **NUNCA restituir las specs en el informe** - Citas ≤ 12 palabras; el informe es un índice de hallazgos con presupuesto (`references/report-template.md`)

---

## Persist Summary

After generating all output artifacts (Mode Audit or Mode Fix), update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["spec-auditor"].status` = `"done"`
3. Set `stages["spec-auditor"].lastRun` = current ISO-8601
4. Set `stages["spec-auditor"].summary`:
   - `artifacts`: list of files created/modified with labels (e.g., `{"file": "audits/AUDIT-BASELINE.md", "label": "Audit Baseline"}`)
   - `metrics`: `{ "total_findings": N, "critical": N, "high": N, "medium": N, "low": N, "batched_findings": N, "gate_result": "PASS"|"CONDITIONAL"|"FAIL", "audit_cycle": N, "topFindingCategories": ["CAT-06", "CAT-03", "CAT-07"], "report_chars": N, "mode": "fanout"|"sequential" }` (top 3 categories by frequency; `report_chars` = `wc -c audits/AUDIT-BASELINE.md`; `mode` = execution mode actually used, `fanout` even when one auditor had to be re-run sequentially — say so in `highlights`)
   - `highlights`: top 3-5 notable observations (e.g., "26 findings: 2 P0, 5 P1", "Gate: CONDITIONAL — 1 High documented", "fanout: 4 auditors (sonnet), NFR re-run sequentially", "report 18.4 k chars")
   - `nextStep`: `"Run /sdd-test-planner"` (if gate PASS/CONDITIONAL) or `"Run /sdd-spec-auditor --fix"` (if gate FAIL)
   - `templateImprovements`: list of 1-3 recommendations for the spec-engineer based on most frequent finding categories (e.g., "UC template should require explicit error codes per step", "Add invariant extraction for constraint language in UCs"). These are consumed by the spec-engineer on the NEXT project run to apply extra scrutiny.
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
