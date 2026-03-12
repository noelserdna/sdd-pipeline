---
name: sdd-spec-auditor
description: "Audits, reviews, and validates technical specifications for defects. Performs systematic cross-document analysis to detect ambiguities, implicit rules, dangerous silences, contradictions, incomplete specs, weak invariants, evolution risks, and implicit decisions without ADRs. Use when: (1) Reviewing specs before planning or implementation, (2) Detecting quality defects in specification documents, (3) Fixing spec defects with Mode Fix, (4) Analyzing upstream impact of spec changes. Does NOT propose implementations or assume unspecified behavior. Triggers: 'audit specs', 'review specifications', 'spec quality', 'find ambiguities', 'fix specs', 'auditar especificaciones', 'revisar specs', 'calidad de specs'."
version: "1.4.0"
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
### AMB-001: Tiempo de respuesta "razonable"

**Ubicación:** nfr/PERFORMANCE.md:45
**Problema:** El término "tiempo de respuesta razonable" no tiene valor cuantificable.
**Pregunta:** ¿Cuál es el p99 latency aceptable en milisegundos?
**Documentos relacionados:** contracts/API-extraction.md (no define timeout)
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
### IMP-001: Validación de email implícita

**Ubicación:** use-cases/UC-015-create-user.md:23
**Problema:** El flujo menciona "ingresar email" pero no especifica validación de formato ni unicidad.
**Pregunta:** ¿Debe validarse formato RFC 5322? ¿Unicidad por organización o global?
**Documentos relacionados:** domain/02-ENTITIES.md (User entity no define constraint)
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
### SIL-001: Sin manejo de timeout en extracción

**Ubicación:** workflows/WF-001-extraction.md:89
**Problema:** No se especifica qué ocurre si el LLM no responde en el tiempo esperado.
**Pregunta:** ¿Retry automático? ¿Fallback? ¿Estado final de la Extraction?
**Documentos relacionados:**
- domain/04-STATES.md (no hay estado "timeout")
- nfr/LIMITS.md (define timeout pero no acción)
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
### SEM-001: "Job" vs "Extraction" inconsistente

**Ubicación:**
- workflows/WF-001.md:12 usa "job"
- domain/01-GLOSSARY.md define "Extraction"
**Problema:** Violación del lenguaje ubicuo. "Job" no está definido en glosario.
**Pregunta:** ¿Reemplazar todas las ocurrencias de "job" por "Extraction"?
**Documentos relacionados:** domain/01-GLOSSARY.md (término canónico: Extraction)
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
### CON-001: Timeout contradictorio

**Ubicación:**
- nfr/LIMITS.md:34 → "timeout: 180s"
- workflows/WF-001.md:67 → "timeout: 360s"
**Problema:** Dos documentos definen valores diferentes para el mismo timeout.
**Pregunta:** ¿Cuál es el valor autoritativo? ¿Actualizar ambos documentos?
**Documentos relacionados:** CLARIFICATIONS.md (verificar si hay RN que aclare)
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
### INC-001: Caso de uso sin flujo de excepción

**Ubicación:** use-cases/UC-023-delete-cv.md:45
**Problema:** Sección "Exception Flows" está vacía. No se especifica qué ocurre si el CV tiene MatchResults activos.
**Pregunta:** ¿Prohibir eliminación? ¿Cascade delete? ¿Soft delete?
**Documentos relacionados:** domain/05-INVARIANTS.md (buscar INV sobre integridad referencial)
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
### INV-001: Restricción sin invariante formal

**Ubicación:** use-cases/UC-007.md:34
**Problema:** Dice "el score debe estar entre 0 y 100" pero no hay INV-XXX-NNN correspondiente.
**Pregunta:** ¿Crear INV-CVA-XXX con constraint CHECK y validación Zod?
**Documentos relacionados:** domain/05-INVARIANTS.md (no existe invariante de rango de score)
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
### EVO-001: Enum de estados sin extensibilidad

**Ubicación:** domain/04-STATES.md:23
**Problema:** ExtractionStatus es enum cerrado. Agregar nuevo estado requiere migración.
**Pregunta:** ¿Considerar campo status como string con validación? ¿Documentar proceso de migración?
**Documentos relacionados:** adr/ (no hay ADR sobre estrategia de evolución de estados)
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
### ADR-001: Elección de R2 sin ADR

**Ubicación:** workflows/WF-001.md:56
**Problema:** Se menciona "guardar en R2" pero no hay ADR que justifique elección de R2 vs S3 vs GCS.
**Pregunta:** ¿Crear ADR-XXX documentando decisión y alternativas consideradas?
**Documentos relacionados:** adr/ (no existe ADR sobre storage)
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

Report the 3C gate result at the top of every audit report:

```markdown
## 3C Spec Verification

| Dimension    | Pass | Fail | Verdict |
|--------------|------|------|---------|
| Completeness | {N}/{T} | {F} | PASS / FAIL |
| Correctness  | {N}/{T} | {F} | PASS / FAIL |
| Coherence    | {N}/{T} | {F} | PASS / FAIL |

**Gate:** {PASS — ready for planning | FAIL — resolve before proceeding}
```

> Any FAIL in Completeness or Correctness blocks pipeline progression to `sdd-plan-architect`.
> Coherence failures are warnings that should be resolved but do not block.

---

## Audit Process

### Phase 0: Baseline Loading

Before starting the audit, check for an existing audit baseline to avoid re-reporting known findings.

1. **Search for baseline file:** Look for `AUDIT-BASELINE.md` in the audits directory (`audits/AUDIT-BASELINE.md`)
2. **If baseline exists:**
   - Load all findings with status `accepted`, `wont_fix`, or `deferred`
   - These findings are **excluded** from the audit report (they are NOT re-reported)
   - Track them in a separate "Excluded by Baseline" counter
   - For `deferred` findings: check the `Re-evaluar en` date — if past due, re-evaluate and potentially re-report
3. **If no baseline exists:**
   - Proceed normally (first audit or baseline not yet created)
   - Note in the report: "No baseline found — all findings are new"
4. **Load previous audit report** (if any) to classify findings as `new`, `persistent`, or `regression`

**Baseline file format expected:**

```markdown
# Audit Baseline
> Last updated: YYYY-MM-DD (AUDIT-vX.Y)

## Accepted Findings
| ID | Descripción corta | Razón de aceptación | Audit origen |
|----|-------------------|---------------------|--------------|

## Deferred Findings
| ID | Descripción corta | Razón de defer | Audit origen | Re-evaluar en |
|----|-------------------|----------------|--------------|---------------|

## Resolved Findings (últimas 2 versiones)
| ID | Descripción corta | Resuelto en | Audit origen |
|----|-------------------|-------------|--------------|
```

---

### Phase 1: Inventory

1. List all specification documents
2. Identify document types (domain, UC, WF, ADR, NFR, contracts)
3. Note document versions and last update dates
4. Identify missing documents (gaps in numbering, referenced but non-existent)

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
1. Read document
2. Apply category checklist
3. Record findings with location + problem + question
4. Cross-reference with related documents

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

After detecting all findings (Phase 5) and classifying them (Phase 6), consolidate findings to reduce noise and improve actionability.

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

```markdown
# Audit Report: {Repository Name}

> **Fecha:** YYYY-MM-DD
> **Auditor:** {Name}
> **Versión specs auditada:** X.Y.Z
> **Documentos analizados:** {N}

---

## Resumen Ejecutivo

| Categoría | Hallazgos | Críticos | Altos | Medios | Bajos |
|-----------|-----------|----------|-------|--------|-------|
| Ambigüedades | {N} | {N} | {N} | {N} | {N} |
| Reglas implícitas | {N} | {N} | {N} | {N} | {N} |
| Silencios peligrosos | {N} | {N} | {N} | {N} | {N} |
| Ambigüedades semánticas | {N} | {N} | {N} | {N} | {N} |
| Contradicciones | {N} | {N} | {N} | {N} | {N} |
| Specs incompletas | {N} | {N} | {N} | {N} | {N} |
| Invariantes débiles | {N} | {N} | {N} | {N} | {N} |
| Riesgos evolución | {N} | {N} | {N} | {N} | {N} |
| Decisiones sin ADR | {N} | {N} | {N} | {N} | {N} |
| **TOTAL** | **{N}** | **{N}** | **{N}** | **{N}** | **{N}** |

---

## Baseline Delta

> Compared against: {previous audit ID or "N/A (first audit)"}

| Métrica | Cantidad |
|---------|----------|
| Hallazgos nuevos (new) | {N} |
| Hallazgos persistentes (persistent) | {N} |
| Hallazgos de regresión (regression) | {N} |
| Hallazgos resueltos desde último audit | {N} |
| Hallazgos excluidos por baseline | {N} |

---

## Hallazgos por Categoría

### CAT-01: Ambigüedades

#### AMB-001: {Título}

| Campo | Valor |
|-------|-------|
| **Severidad** | Crítico / Alto / Medio / Bajo |
| **Estado** | new / persistent / regression |
| **Ubicación** | {documento}:{línea o sección} |
| **Problema** | {Descripción del defecto} |
| **Pregunta** | {Pregunta para resolver} |
| **Docs relacionados** | {Lista de documentos} |

---

## Hallazgos Excluidos por Baseline

> {N} hallazgos excluidos: {N} accepted, {N} wont_fix, {N} deferred

*(Los detalles de hallazgos excluidos están en `AUDIT-BASELINE.md`)*

---

## Documentos No Analizados

{Lista de documentos excluidos y razón}

---

## Recomendaciones de Priorización

1. **Críticos (resolver antes de implementar):**
   - {ID}: {Título}

2. **Altos (resolver en sprint actual):**
   - {ID}: {Título}

3. **Medios (backlog priorizado):**
   - {ID}: {Título}

4. **Bajos (mejora continua):**
   - {ID}: {Título}
```

---

## Quality Metrics (SWEBOK v4 Ch10 — Software Quality)

The auditor MUST compute these metrics and include the Quality Scorecard in every audit report, immediately after the Baseline Delta table.

| Metric | Definition | Target | Formula |
|--------|-----------|--------|---------|
| **Spec Defect Density** | Critical/High findings per spec document | < 2 critical per document | `critical_findings / total_documents` |
| **Traceability Coverage** | % of requirements with at least one linked spec (UC, WF, or contract) | 100% | `reqs_with_spec / total_reqs × 100` |
| **Orphan Rate** | % of spec documents without traceability to any requirement | 0% | `orphan_specs / total_specs × 100` |
| **Clarification Density** | Open `[NEEDS CLARIFICATION]` or `[TBD]` markers per document | 0 before downstream | `open_markers / total_documents` |
| **Audit Pass Rate** | % of spec documents passing all checks (zero Critical/High findings) | > 90% at baseline | `clean_docs / total_documents × 100` |
| **Cross-Reference Validity** | % of inter-document references that resolve correctly | 100% | `valid_refs / total_refs × 100` |

### Quality Scorecard Template

Include this scorecard in the audit report after the Baseline Delta section:

```markdown
## Quality Scorecard

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Spec Defect Density | {N} critical/doc | < 2 | {PASS/FAIL} |
| Traceability Coverage | {N}% | 100% | {PASS/FAIL} |
| Orphan Rate | {N}% | 0% | {PASS/FAIL} |
| Clarification Density | {N}/doc | 0 | {PASS/FAIL} |
| Audit Pass Rate | {N}% | > 90% | {PASS/FAIL} |
| Cross-Reference Validity | {N}% | 100% | {PASS/FAIL} |
| **Overall Quality Gate** | | See Convergence Protocol | **{PASS/CONDITIONAL/FAIL}** |

> **Gate rule:** See "Quality Gate Thresholds" in the Convergence Protocol section. PASS = proceed. CONDITIONAL PASS = proceed with advisory. FAIL = must resolve Critical/High findings first.
```

---

## Severity Classification

| Severidad | Criterio | Pregunta clave |
|-----------|----------|----------------|
| **Crítico** | Bloquea implementación o causa comportamiento indefinido en producción | ¿Bloquea implementación? |
| **Alto** | Riesgo de bugs significativos o violación de requisitos | ¿Causa bugs o viola requisitos? |
| **Medio** | Inconsistencia que dificulta mantenimiento o comprensión | ¿Dificulta comprensión? |
| **Bajo** | Mejora de claridad o estilo sin impacto funcional | ¿Solo mejora estilo? |

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

1. Search for the most recent audit report in `audits/`
2. Read the COMPLETE audit file. Extract EVERY finding with: ID, severity, problem, location, question, answer
3. Count findings and confirm with user

#### Fix Phase 1: Create Corrections Plan

Create `audits/CORRECTIONS-PLAN-AUDIT-vX.X.md` with ALL findings and proposed solutions.

For EACH finding (no exceptions):
- Finding ID, severity, category, location, problem
- Audit question and answer received (or `[NO ANSWER]`)
- Minimum 2 solutions (recommended + alternative) with before/after text
- Dependencies on other findings

Include summary table at top with severity breakdown.

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

1. Update `audits/AUDIT-BASELINE.md` with resolved/skipped/deferred findings
2. Produce Correction Summary with: resolved count, skipped count, pending count, new artifacts created, breaking changes
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

### Fix Constraints

1. NEVER generate code — only specification text, invariants, ADRs
2. NEVER invent behavior — every change traces to finding + answer
3. NEVER resolve conflicts silently — create ADR
4. ALWAYS show before/after for every spec change
5. ALWAYS make atomic commits per correction
6. NEVER skip a finding — every one MUST appear in corrections plan
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
| Mode Audit | Specifications + Baseline | Audit report with findings |
| Mode Fix | Audit report + Answers | Corrected specs + Corrections plan + Baseline update + Upstream impact analysis |
| Mode Focused | Change Report + Specifications subset | Focused audit report on changed documents |

### Invocation

```bash
/sdd-spec-auditor                                                    # Full audit (default)
/sdd-spec-auditor --fix                                              # Apply corrections from answered audit
/sdd-spec-auditor --focused --scope=changes/CHANGE-REPORT-{id}.md   # Focused audit on changed documents only (triggered by sdd-req-change cascade)
```

### Mode Focused (`--focused`)

When `--focused` is provided together with `--scope` pointing to a Change Report, the auditor operates in a reduced-scope mode:

1. **Scope restriction:** Only audit the documents listed in the Change Report's "Documents Modified" section. All other spec documents are treated as unchanged context (read but not audited).
2. **Skip full cross-document audit:** Do NOT perform a full Phase 1-6 sweep. Instead, focus exclusively on verifying alignment and consistency of the changed documents against each other and against their immediate neighbors in the traceability chain.
3. **Output:** Generate a focused audit report at `audits/AUDIT-FOCUSED-{change-report-id}.md` (e.g., `audits/AUDIT-FOCUSED-CR-007.md`). This report uses the same finding format (CAT-01..CAT-09) and severity classification but includes only findings related to the modified documents.
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

## Multi-Agent Deduplication Protocol

When using multiple parallel agents for auditing (e.g., Domain agent, UCs agent, Contracts agent, NFRs agent):

### Agent ID Prefixes

<!-- Standard SDD agent prefix convention: prefixes map to spec/ subdirectories.
     DOM- → domain/, UC- → use-cases/, WF- → workflows/, CON- → contracts/,
     NFR- → nfr/, ADR- → adr/, TEST- → tests/, RUN- → runbooks/.
     All SDD skills sharing multi-agent protocols MUST use these same prefixes. -->

Each agent MUST use a unique prefix for finding IDs to avoid collisions:

| Agent | Prefix | Scope | Spec Directory |
|-------|--------|-------|----------------|
| Domain Agent | `DOM-` | Glossary, Entities, Value Objects, States, Invariants | `spec/domain/` |
| Use Cases/Workflows Agent | `UC-`, `WF-` | UC-001 to UC-041, WF-001 to WF-004 | `spec/use-cases/`, `spec/workflows/` |
| Contracts Agent | `CON-` | API contracts, Events, PERMISSIONS-MATRIX | `spec/contracts/` |
| NFRs/ADRs/Tests Agent | `NFR-`, `ADR-`, `TEST-`, `RUN-` | NFRs, ADRs, BDD tests, Runbooks | `spec/nfr/`, `spec/adr/`, `spec/tests/`, `spec/runbooks/` |

### Consolidation Process

After all agents complete, the consolidator MUST:

1. **Merge all findings** into a single report
2. **Cross-reference by:** document affected + type of defect + field/value involved
3. **Deduplication rules:**
   - If 2+ agents report the **same defect** (same document + same field/value + same problem type) → keep the most complete finding, mark as `cross-validated`
   - **Threshold for duplicate:** identical location (file + section) AND identical problem description = duplicate
   - Cross-validated findings get a confidence boost (mention both agent sources)
4. **Renumber** final findings sequentially within each category (AMB-001, CON-001, etc.)
5. **Preserve** the original agent prefix in a `Source` field for traceability

### Cross-Validation Bonus

Findings independently detected by 2+ agents are marked `[CROSS-VALIDATED]` — these have the highest confidence and should be prioritized for resolution.

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
3. **SIEMPRE indicar ubicación exacta** - Documento y línea/sección
4. **SIEMPRE cruzar documentos** - Un hallazgo puede involucrar múltiples docs
5. **SIEMPRE formular pregunta** - El hallazgo debe terminar con pregunta de resolución

---

## Persist Summary

After generating all output artifacts (Mode Audit or Mode Fix), update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["spec-auditor"].status` = `"done"`
3. Set `stages["spec-auditor"].lastRun` = current ISO-8601
4. Set `stages["spec-auditor"].summary`:
   - `artifacts`: list of files created/modified with labels (e.g., `{"file": "audits/AUDIT-BASELINE.md", "label": "Audit Baseline"}`)
   - `metrics`: `{ "total_findings": N, "critical": N, "high": N, "medium": N, "low": N, "batched_findings": N, "gate_result": "PASS"|"CONDITIONAL"|"FAIL", "audit_cycle": N, "topFindingCategories": ["CAT-06", "CAT-03", "CAT-07"] }` (top 3 categories by frequency)
   - `highlights`: top 3-5 notable observations (e.g., "26 findings: 2 P0, 5 P1", "Gate: CONDITIONAL — 1 High documented")
   - `nextStep`: `"Run /sdd-test-planner"` (if gate PASS/CONDITIONAL) or `"Run /sdd-spec-auditor --fix"` (if gate FAIL)
   - `templateImprovements`: list of 1-3 recommendations for the spec-engineer based on most frequent finding categories (e.g., "UC template should require explicit error codes per step", "Add invariant extraction for constraint language in UCs"). These are consumed by the spec-engineer on the NEXT project run to apply extra scrutiny.
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
