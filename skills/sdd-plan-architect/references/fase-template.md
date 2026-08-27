# FASE File Template

Canonical template for all FASE files. Every FASE file MUST follow this structure. FASE files are navigation indices: they point to specs by id and section and never copy spec content. Budget: ≤ 8 000 chars per FASE (a FASE with three parallel blocks and a state machine may reach 10 000).

Section headers stay in Spanish — `sdd-task-generator` parses them (Criterios de Éxito, Specs a Leer, Invariantes Aplicables, Contratos Resultantes, Alcance, Dependencias, Módulos y Conjuntos de Escritura). Descriptive text follows the project language.

---

## Header (REQUIRED)

```markdown
# FASE {N}: {Title}

> **Estado:** Implementable
> **Dependencias:** {Fase X, Fase Y | Ninguna (fase inicial)}
> **Valor Observable:** {One line: what a user or a test can observe when the phase is done}

---
```

## Sections (in order)

### 1. Objetivo (REQUIRED)

One paragraph (≤ 600 chars): which actor gets what, and how the FASE is split into blocks when it has parallel work.

```markdown
## Objetivo

Permitir que un **{Actor}** {action}. Bloques: **A** ({module}) ∥ **B** ({module}) → **Integración** ({what it merges and verifies}).
```

### 2. Criterios de Éxito (REQUIRED)

Checklist. One line per criterion (≤ 140 chars), observable, ending with the ids it verifies. Group by block when the FASE has parallel blocks. The behaviour lives in the spec: write "`saveStore` atomic: tmp + rename, compensation (ADR-004, INV-STO-002)", not the algorithm.

```markdown
## Criterios de Éxito

### Bloque A — {module}
- [ ] {criterion} ({ids})

### Bloque B — {module}
- [ ] {criterion} ({ids})

### Integración
- [ ] {criterion} ({ids})
```

### 3. Specs a Leer (REQUIRED)

Pointers only: path · section or ids · purpose (≤ 100 chars per row; prefix the block letter when the FASE has blocks). Never paraphrase the spec — a row that needs more than one line is copying content.

```markdown
## Specs a Leer

### Casos de Uso

| Documento | Sección / ids | Para |
|-----------|---------------|------|
| `use-cases/UC-NNN-{name}.md` | flujo principal, EC1–EC4, AC-NNN-01..14 | A: paso 5 · B: pasos 2–3 · C: E2E |

### Workflows

| Documento | Sección / ids | Para |
|-----------|---------------|------|
| `workflows/WF-NNN-{name}.md` | pasos 1–5 | B: orquestación |

### ADRs

| Documento | Sección | Para |
|-----------|---------|------|
| `adr/ADR-NNN-{name}.md` | §Decision | A: {one clause} |

### Dominio

| Documento | Sección | Para |
|-----------|---------|------|
| `domain/02-ENTITIES.md` | ENT-001, ENT-002 | A: tipos |
| `domain/03-VALUE-OBJECTS.md` | VO-004, VO-009 | A / B |
| `domain/04-STATES.md` | SM-001 | A: transiciones |
| `domain/05-INVARIANTS.md` | INV-{PREFIX}-* | ver Invariantes Aplicables |

### Contratos

| Documento | Sección / ids | Para |
|-----------|---------------|------|
| `contracts/API-{name}.md` | API-NNN-01..05 | A: firmas |
| `contracts/EVENTS-domain.md` | {EventPrefix}* | eventos |

### Tests

| Documento | ids | Para |
|-----------|-----|------|
| `tests/BDD-{name}.md` | AC-NNN-01..NN | C: E2E |
| `tests/PROPERTY-TESTS.md` | PROP-001, PROP-003 | A: unit |
```

Optional types (only if the FASE references them): `### NFR`, `### Runbooks`, `### Clarificaciones` (RN ids per block), `### Documentos Raíz`, `### Plan de tests (test/)` (TEST-PLAN §3 / §7 / §9 ids, matrix and E2E ids).

### 4. Invariantes Aplicables (REQUIRED)

Ids and where each one is enforced. The description is in `05-INVARIANTS.md`; do not copy it.

```markdown
## Invariantes Aplicables

> Acumulativas: esta fase hereda las de FASE-0..FASE-(N-1).

| ID | Dónde se aplica (bloque · función) |
|----|------------------------------------|
| INV-{PREFIX}-{NNN} | A · `addTask` / `loadStore` |
```

### 5. Módulos y Conjuntos de Escritura (REQUIRED)

Consumed by `sdd-task-generator` (Phase 3b Stream Assignment) to derive the work Streams of the FASE. One row per block; the write-sets of blocks meant to run in parallel MUST be pairwise disjoint. Paths are globs or exact paths; shared files (barrels, config, CI) belong to `base` or `Integración`, never to two blocks.

```markdown
## Módulos y Conjuntos de Escritura

| Bloque | Módulo / directorio | Escribe (write-set) | No escribe | Depende de |
|--------|---------------------|---------------------|------------|------------|
| base | — | `package.json`, `src/api/index.ts` | — | FASE-0 |
| A | `src/api/` | `src/api/tasks.ts`, `src/api/repository.ts`, `tests/unit/api/**` | `src/cli/**`, config | base |
| B | `src/cli/` | `src/cli/**`, `tests/unit/cli/**` | `src/api/**` | base |
| Integración | — | `tests/e2e/**`, `tests/perf/**`, `.github/workflows/ci.yml` | código de producción | A, B |
```

A FASE with a single block still writes the table (one work row) so the generator marks it `Streams: serial`.

### 6. Contenido Específico (OPTIONAL)

The only section where spec content is reproduced, and only content that exists nowhere else in a usable form: a formula, a state diagram, a type table, a mapping table (e.g. WF step → function → block). ≤ 30 lines. Never restate contract signatures (Contratos Resultantes) or ADR text.

```markdown
## Contenido Específico

### {Content title}

{formula | diagram | table}
```

### 7. Contratos Resultantes (REQUIRED)

One line per endpoint/function delivered by the FASE; domain events with their trigger.

```markdown
## Contratos Resultantes

| Contrato | Firma / Ruta | Descripción (≤ 80 chars) |
|----------|--------------|--------------------------|
| API-NNN-01 | `POST /api/v1/{path}` · `addTask(store, title, now)` | {description} |

### Eventos de Dominio

| Evento | Trigger |
|--------|---------|
| `{EventName}` | {when it fires} |
```

### 7B. Entregables de UI (REQUIRED if delivery channel includes web/mobile)

> **Rule:** If the System Vision Gate identifies a web, mobile, or desktop delivery channel, EVERY FASE that implements user-facing UCs MUST include this section listing the pages/components to build. Omit ONLY for API-only / CLI projects or purely infrastructure FASEs.

```markdown
## Entregables de UI

### Páginas / Rutas

| Ruta | Componente | UC | Wireframe | Descripción |
|------|------------|----|-----------|-------------|
| `/{path}` | `+page.svelte` | UC-{NNN} | WIREFRAMES §{id} | {≤ 80 chars} |

### Componentes Compartidos

| Componente | Usado en | Descripción |
|------------|----------|-------------|
| `{ComponentName}` | {pages} | {≤ 80 chars} |
```

Routes/pages are framework-specific (`+page.svelte`, `page.tsx`, …). Each page maps to at least one UC (no orphan pages). Forms reference validation schemas from `spec/domain/03-VALUE-OBJECTS.md` by VO id.

### 8. Verificación (REQUIRED)

≤ 10 commands with the expected result as a trailing comment; one group per block when applicable. The full journey lives in `test/E2E-SCENARIOS.md` — do not repeat it here.

```markdown
## Verificación

\```bash
npm run test:unit -- tests/unit/api      # A: PROP-001..011 green; src/api ≥ 90 %
curl -X POST /api/v1/{path}              # 201 + {schema}
\```

\```markdown
# UI (if delivery channel includes web/mobile)
- [ ] /{path} renders · {action} → {visible result}
\```
```

### 9. Alcance (REQUIRED)

```markdown
## Alcance

| Incluye | Excluye |
|---------|---------|
| UC-NNN: {name} | {what is NOT in this phase} → {where it is handled} |
```

### 10. Notas (OPTIONAL)

≤ 5 bullets: execution order of blocks, platform skips, Derived expectations. Nothing that belongs in a spec.

---

## Rules

1. **No content duplication**: reference specs by path + section/ids. Contenido Específico is the sole exception (≤ 30 lines).
2. **One line per criterion / row**: a criterion or a "Para" cell longer than 140 chars is copying the spec — replace it with the ids.
3. **Consistent table format**: always `| Header | Header |`.
4. **Path format**: backtick-quoted relative paths from spec root (e.g. `use-cases/UC-001-upload-pdf.md`).
5. **Invariant references**: full id format `INV-{PREFIX}-{NNN}`.
6. **Section separators**: `---` between major sections.
7. **Ubiquitous language**: only terms from `domain/01-GLOSSARY.md`.
8. **Write-sets are the Stream contract**: keep Módulos y Conjuntos de Escritura consistent with PLAN-FASE §4 file paths and §7.4 Coverage Map.
