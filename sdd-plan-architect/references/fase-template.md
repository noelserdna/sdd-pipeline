# FASE File Template

Canonical template for all FASE files. Every FASE file MUST follow this structure.

---

## Header (REQUIRED)

```markdown
# FASE {N}: {Title}

> **Estado:** Implementable
> **Dependencias:** {Fase X, Fase Y | Ninguna (fase inicial)}
> **Valor Observable:** {One-line description of what this phase delivers}

---
```

## Sections (in order)

### 1. Objetivo (REQUIRED)

One paragraph describing what the phase enables and for which actor.

```markdown
## Objetivo

Permitir que un **{Actor}** {action description}.
```

### 2. Criterios de Éxito (REQUIRED)

Checklist of observable verification criteria.

```markdown
## Criterios de Éxito

- [ ] {Criterion 1}
- [ ] {Criterion 2}
...
```

Optional sub-sections for complex phases:
```markdown
### Criterios de Éxito - {Subsection Title}
- [ ] {Sub-criterion}
```

### 3. Specs a Leer (REQUIRED)

Organized by type. Each type in a separate sub-section with table format.

```markdown
## Specs a Leer

### Casos de Uso

| Documento | Qué extraer |
|-----------|-------------|
| `use-cases/UC-NNN-{name}.md` | {What to extract} |

### Workflows

| Documento | Qué extraer |
|-----------|-------------|
| `workflows/WF-NNN-{name}.md` | {What to extract} |

### ADRs

| Documento | Qué extraer |
|-----------|-------------|
| `adr/ADR-NNN-{name}.md` | {What to extract} |

### Dominio

| Documento | Sección | Qué extraer |
|-----------|---------|-------------|
| `domain/02-ENTITIES.md` | Sección N: {Entity} | {What to extract} |
| `domain/03-VALUE-OBJECTS.md` | {VO name} | {What to extract} |
| `domain/04-STATES.md` | {StateMachine} | {What to extract} |
| `domain/05-INVARIANTS.md` | INV-{PREFIX}-* | Invariantes |

### Contratos

| Documento | Sección | Qué extraer |
|-----------|---------|-------------|
| `contracts/API-{name}.md` | Completo | {What to extract} |
| `contracts/EVENTS-domain.md` | {EventPrefix}* | Eventos relacionados |

### Tests

| Documento | Qué extraer |
|-----------|-------------|
| `tests/BDD-{name}.md` | {What to extract} |
```

Optional types (include if applicable):
- `### NFR (Requisitos No Funcionales)` - with `| Documento | Qué extraer |` table
- `### Runbooks` - with `| Documento | Qué extraer |` table
- `### Clarificaciones` - with `| Documento | Reglas | Qué extraer |` table
- `### Documentos Raíz` - with `| Documento | Qué extraer |` table

### 4. Invariantes Aplicables (REQUIRED)

```markdown
## Invariantes Aplicables

| ID | Descripción |
|----|-------------|
| INV-{PREFIX}-{NNN} | {Short description} |
```

Note: Invariantes are cumulative. FASE-N inherits ALL invariantes from FASE-0 to FASE-(N-1).

### 5. Contenido Específico (OPTIONAL, phase-dependent)

Extracted content that provides essential context. This is the ONLY section where content from specs is reproduced (minimally). Examples:

- **FASE-0:** Encryption key ceremony, super admin bootstrap procedure
- **FASE-2:** 24 dimensions list
- **FASE-5:** Matching formula, weight redistribution
- **FASE-7:** Magic link authentication flow
- **FASE-8:** State machine diagram, SelectionEvent types, KPIs table

Format varies by content type:
```markdown
## {Content Title}

{Minimal extracted content: formulas, lists, diagrams, type tables}
```

### 6. Contratos Resultantes (REQUIRED)

```markdown
## Contratos Resultantes

| Endpoint | Método | Descripción |
|----------|--------|-------------|
| `/api/v1/{path}` | {METHOD} | {Description} |

### Eventos de Dominio

| Evento | Trigger |
|--------|---------|
| `{EventName}` | {When it fires} |
```

For complex phases, sub-section by area:
```markdown
### {Area Name}

| Endpoint | Método | Descripción |
|----------|--------|-------------|
```

### 7. Verificación (REQUIRED)

```markdown
## Verificación

\```bash
# {Description of what to verify}
curl -X {METHOD} /api/v1/{path}
# Esperar: {Expected result}
\```
```

### 8. Alcance (REQUIRED)

```markdown
## Alcance

| Incluye | Excluye |
|---------|---------|
| UC-NNN: {name} | {What is NOT in this phase + where} |
```

Alternative format for FASE-0 style:
```markdown
## Out of Scope (FASE-{N})

| Elemento | Razón | Dónde se maneja |
|----------|-------|-----------------|
```

### 9. Notas (OPTIONAL)

Additional context, clarifications, ceremonies, operational notes.

```markdown
## Notas

- {Note 1}
- {Note 2}
```

---

## Rules

1. **No content duplication**: Only reference specs by path + section. The "Contenido Específico" section is the sole exception, and it should be minimal (formulas, lists, diagrams).
2. **Consistent table format**: Always use `| Header | Header |` table syntax.
3. **Path format**: Always use backtick-quoted relative paths from spec root (e.g., `use-cases/UC-001-upload-pdf.md`).
4. **Invariant references**: Use full ID format `INV-{PREFIX}-{NNN}`.
5. **Section separators**: Use `---` between major sections.
6. **Ubiquitous language**: Use ONLY terms from `domain/01-GLOSSARY.md`.
