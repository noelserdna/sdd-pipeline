# FASE File Template

Canonical template for all FASE files. A FASE is a vertical increment (`phase-assignment-rules.md`): one user journey the customer can watch in the Demo. FASE files are navigation indices: they point to specs by id and section and never copy spec content. Budget: ≤ 8 000 chars per FASE (a FASE with parallel Streams and a state machine may reach 10 000).

Section headers and header labels stay in Spanish — other tools parse them: `sdd-task-generator` (Criterios de Éxito, Specs a Leer, Invariantes Aplicables, Contratos Resultantes, Alcance, Dependencias, Módulos y Conjuntos de Escritura, Escenarios), `sdd gate --fase N` (the REQ ids of `Requisitos:`, the WF ids of `Workflows:`), `sdd lint --plan` (Requisitos, Escenarios, Criterios de Éxito, Demo) and `sdd-task-implementer` Phase 9 (Demo). Descriptive text follows the user's language.

---

## Header (REQUIRED)

```markdown
# FASE {N}: {Title}

> **Estado:** Implementable
> **Incremento:** {One line: the user journey that works at the end, in the customer's words}
> **Requisitos:** REQ-F-001, REQ-F-002, REQ-NF-002
> **Escenarios:** AC-001-01, AC-001-03, AC-002-01, REQ-NF-002 AC1
> **Workflows:** WF-001
> **Necesidades:** N-001, N-002
> **Dependencias:** {Fase X, Fase Y | Ninguna (fase inicial)}

---
```

- **Requisitos** — the requirements this FASE completes, whole (rule R5). `sdd gate --fase N` judges exactly these; list every id, no ranges.
- **Escenarios** — every scenario the FASE makes pass: `AC-NNN-NN` from `spec/tests/BDD-UC-*.md`, or `REQ-X-NNN ACn` for a requirement without a BDD scenario (a measured NFR, or every requirement when the route skipped the specifications and there is no `spec/`). Each id individually (no `..` ranges): the task generator checks that every one is cited by a task, and the lint that it exists.
- **Workflows** — the user-facing workflows (`WF-NNN` of `spec/workflows/`) the increment's journey walks through. The customer accepts what they can watch, so `sdd gate --fase N` asks for one video per id listed here, named with it; the journey task records them. Leave out background workflows (a scheduled job, a webhook) that have no screen of their own. Omit the line when the FASE has none (the route skipped the specifications, a hardening FASE): the gate then asks for the `WF-NNN` cited in `## Demo`, or for one video named `FASE-N`.
- **Necesidades** — the customer needs (`requirements/CUSTOMER-NEEDS.md`) the increment serves.
- FASE-0 is `FASE-0-SKELETON.md`; a measured-NFR FASE is `FASE-{N}-HARDENING.md`.

## Sections (in order)

### 1. Objetivo (REQUIRED)

One paragraph (≤ 600 chars): which actor can do what at the end, and how the FASE is split into Streams when it has parallel work (rare in a vertical FASE: only with disjoint write-sets).

```markdown
## Objetivo

Permitir que un **{Actor}** {journey}. {Only with Streams: Bloques **A** ({module}) ∥ **B** ({module}) → **Integración** ({what it merges and verifies}).}
```

### 2. Criterios de Éxito (REQUIRED)

Checklist grouped by use case. One line per criterion (≤ 140 chars), observable, ending with the REQ or scenario id it verifies (`sdd lint --plan` V8: every FASE has criteria backed by those ids). Technical criteria (INV, ADR) go under the UC whose code enforces them, or under `### Transversal`. The behaviour lives in the spec: write "`saveStore` atomic: tmp + rename (ADR-004, INV-STO-002, AC-001-04)", not the algorithm.

```markdown
## Criterios de Éxito

### UC-001 — {title}
- [ ] {criterion} (AC-001-01, REQ-F-001)
- [ ] {criterion} (AC-001-03)

### UC-002 — {title}
- [ ] {criterion} (AC-002-01)

### Transversal
- [ ] {constraint or measured NFR that applies to the whole increment} (REQ-C-002, REQ-NF-002 AC1)
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

Example paths (Node layout). Use the project's `code_paths` / `test_paths` from the Stack Profile; the kit's `wiring` files (e.g. rails `config/routes.rb`, `db/schema.rb`; nextjs-prisma `prisma/schema.prisma`, `src/app/layout.tsx`) belong to `base` or `Integración`. Each block's write-set includes its tests (tests are written inside the task that implements the code).

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

> **Rule:** If the System Vision Gate identifies a web, mobile, or desktop delivery channel, EVERY FASE that implements user-facing UCs MUST include this section listing the pages/components to build. Omit only for API-only / CLI projects or a HARDENING FASE with no UI change.

```markdown
## Entregables de UI

### Páginas / Rutas

| Ruta | Componente | UC | Wireframe | Descripción |
|------|------------|----|-----------|-------------|
| `/{path}` | `+page.svelte` | UC-{NNN} | WIREFRAMES §SCR-{NNN} | {≤ 80 chars} |

### Componentes Compartidos

| Componente | Usado en | Descripción |
|------------|----------|-------------|
| `{ComponentName}` | {pages} | {≤ 80 chars} |
```

Routes/pages are framework-specific (`+page.svelte`, `page.tsx`, …). Each page maps to at least one UC (no orphan pages). Forms reference validation schemas from `spec/domain/03-VALUE-OBJECTS.md` by VO id.

### 8. Verificación (REQUIRED)

≤ 10 technical commands (tests, typecheck, acceptance suite) with the expected result as a trailing comment; one group per Stream when applicable. The customer-facing walk is the Demo (8B) and the full journeys live in `test/E2E-SCENARIOS.md` — do not repeat either here.

```markdown
## Verificación

\```bash
{test_file with block A's test files}    # A: PROP-001..011 green  (Stack Profile `test_file`; `coverage` if not none)
{acceptance}                             # Smoke + Critical green  (Stack Profile `acceptance`, against `server` on `port`)
curl -X POST http://127.0.0.1:{port}/{route}   # {status} + {schema} (route/verb per design/OPERATION-MAPPING.md)
\```

\```markdown
# UI (if delivery channel includes web/mobile)
- [ ] /{path} renders · {action} → {visible result}
\```
```

### 8B. Demo (REQUIRED)

What a person runs, from a clean checkout, to see the increment work; `sdd-task-implementer` Phase 9 runs it and the FASE gate shows it to the customer. At most 10 steps. Every step cites the scenario it shows and the needs it serves. Seed data goes in the first step that needs it (a file under the project's fixtures, never hand-typed state). For an API, steps are consumer calls (`curl`, a client script); for a web app, what the person clicks and sees; never "run the unit tests" except for a measured NFR.

```markdown
## Demo

> Desde un checkout limpio: `{install}` · `{server}` (Stack Profile keys).

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `todo add "Buy milk"` | task 1 pending; `data/todos.json` has one task | AC-001-01, AC-001-04 · N-001, N-004 |
| 2 | `cp demo/seed-fase-0.json data/todos.json && todo list` | `1 [ ] …` and `2 [x] …` | AC-002-01 · N-002 |
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
9. **Ids, not ranges**: `Requisitos`, `Escenarios` and Demo cells list every id (`AC-001-01, AC-001-02`), because the gate, the lint and the task generator read them literally.
