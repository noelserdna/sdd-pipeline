# Coverage Report Template

Format for the audit mode coverage report. Generated when running with `--mode audit`.

---

## Report Format

```markdown
# Phase Coverage Report

> **Fecha:** {YYYY-MM-DD}
> **Spec version:** {X.Y.Z}
> **Total spec files:** {N}
> **Total FASE files:** {N}

---

## Resumen Ejecutivo

| Métrica | Valor |
|---------|-------|
| Specs cubiertos | {N}/{Total} ({%}) |
| Specs huérfanos | {N} |
| Referencias obsoletas | {N} |
| Specs multi-fase | {N} |
| Fases generadas | {N} |

**Veredicto:** {PASS (100% cobertura) | FAIL (specs huérfanos encontrados)}

---

## Cobertura por Tipo

| Tipo | Total | Cubiertos | Huérfanos | Cobertura |
|------|-------|-----------|-----------|-----------|
| Use Cases (UC-*) | {N} | {N} | {N} | {%} |
| ADRs (ADR-*) | {N} | {N} | {N} | {%} |
| Invariantes (INV-*) | {N} | {N} | {N} | {%} |
| BDD Tests | {N} | {N} | {N} | {%} |
| Workflows (WF-*) | {N} | {N} | {N} | {%} |
| Contracts (API-*) | {N} | {N} | {N} | {%} |
| Domain Files | {N} | {N} | {N} | {%} |
| NFRs | {N} | {N} | {N} | {%} |
| Runbooks | {N} | {N} | {N} | {%} |
| Legal | {N} | {N} | {N} | {%} |
| Root docs | {N} | {N} | {N} | {%} |
| **TOTAL** | **{N}** | **{N}** | **{N}** | **{%}** |

---

## Specs Huérfanos

Spec files not referenced by any FASE file:

| Archivo | Tipo | Razón probable |
|---------|------|----------------|
| `{path}` | {type} | {suggestion: new spec? transversal? obsolete?} |

*If empty: "Ninguno - 100% cobertura"*

---

## Referencias Obsoletas

FASE files referencing specs that no longer exist:

| FASE | Referencia | Estado |
|------|------------|--------|
| FASE-{N} | `{path}` | {File not found | Section removed} |

*If empty: "Ninguna - todas las referencias son válidas"*

---

## Specs Multi-Fase

Specs assigned to multiple phases (expected behavior for large domain files):

| Spec | Fases | Qualifier |
|------|-------|-----------|
| `{path}` | FASE-{A}, FASE-{B} | {section/operation qualifier} |

---

## Distribución por Fase

| Fase | Specs asignados | UCs | ADRs | INVs | Tests | Contratos |
|------|-----------------|-----|------|------|-------|-----------|
| FASE-0 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-1 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-2 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-3 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-4 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-5 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-6 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-7 | {N} | {N} | {N} | {N} | {N} | {N} |
| FASE-8 | {N} | {N} | {N} | {N} | {N} | {N} |
| **TOTAL** | **{N}** | **{N}** | **{N}** | **{N}** | **{N}** | **{N}** |

---

## Dependency Graph Validation

| Check | Result |
|-------|--------|
| DAG (no cycles) | {PASS / FAIL: cycle detected between FASE-X and FASE-Y} |
| All dependencies exist | {PASS / FAIL: FASE-X depends on non-existent FASE-Y} |
| Topological order valid | {PASS / FAIL} |
```

---

## Veredicto Rules

- **PASS**: 100% cobertura AND 0 referencias obsoletas AND DAG válido
- **FAIL**: Any of the above checks fail

When FAIL, list specific actions needed:
```markdown
## Acciones Requeridas

1. {Action 1: e.g., "Assign UC-042 to a phase"}
2. {Action 2: e.g., "Remove obsolete reference to ADR-016 from FASE-3"}
```
