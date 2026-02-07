# README Template for fases/

Template for generating the `fases/README.md` file. This is the entry point for understanding the phase structure.

---

## Template

```markdown
# Fases de Implementación - {SystemName} {Version}

> **Propósito:** Índices de navegación para implementar el sistema por fases.
> **Fuente de verdad:** Las especificaciones en `spec/` (no estos índices).

---

## Principio Fundamental

\```
Specs (spec/) = Fuente única de verdad
     ↓
Fases (plan/fases/) = Índices de navegación
     ↓
Código (src/) = Derivado/Regenerable desde specs
\```

**Si algo cambia:**
1. Actualiza la spec original en `spec/`
2. Los índices de fase siguen siendo válidos (solo referencian)
3. Regenera el código desde las specs

---

## Diagrama de Dependencias

\```
{ASCII dependency graph generated from phase dependencies}
\```

---

## Resumen de Fases

| Fase | Documento | Objetivo | Dependencias |
|------|-----------|----------|--------------|
{For each phase:}
| **{N}** | [{filename}]({filename}) | {Objective} | {Dependencies} |

---

## Cobertura de Casos de Uso

| Fase | UCs Incluidos |
|------|---------------|
{For each phase:}
| {N} | {UC list with brief descriptions} |

**Total:** {N} casos de uso cubiertos (UC-001 a UC-{max})

---

## Cobertura de ADRs

| Fase | ADRs Incluidos |
|------|----------------|
{For each phase:}
| {N} | {ADR list} |

**Total:** {N} ADRs referenciados

---

## Cobertura de Tests BDD

| Fase | Tests Incluidos |
|------|-----------------|
{For each phase:}
| {N} | {Test file list} |

**Total:** {N} archivos de tests BDD referenciados

---

## Cobertura de Workflows

| Fase | Workflows Incluidos |
|------|---------------------|
{For each phase with workflows:}
| {N} | {Workflow list} |

---

## Cobertura de Contratos API

| Fase | Contratos Incluidos |
|------|---------------------|
{For each phase:}
| {N} | {Contract list} |

---

## Cobertura de Runbooks y Legal

| Fase | Documentos Operacionales |
|------|--------------------------|
{For each phase with runbooks/legal:}
| {N} | {Document list} |

---

## Archivos No Referenciados (Temporales)

Los siguientes archivos en `spec/temp_files/` son documentos de trabajo y NO están incluidos en las fases:
{List of excluded files and why}

---

## Cómo Usar Estos Índices

### Para implementar una fase:

1. Abre el documento de la fase (ej: `FASE-1-EXTRACCION.md`)
2. Lee las specs listadas en el orden sugerido
3. Implementa siguiendo las invariantes listadas
4. Verifica con los comandos de verificación
5. Pasa a la siguiente fase

### Para agregar una feature:

1. Actualiza la spec correspondiente en `spec/`
2. Identifica qué fase(s) afecta
3. El índice de fase sigue siendo válido
4. Regenera/actualiza el código

### Para dar contexto a un agente IA:

1. Pasa el documento de fase como contexto
2. El agente sabrá qué specs leer
3. Las specs tienen todo el detalle necesario

---

## Estado

- **Todas las fases:** Implementables
- **Decisiones pendientes:** {N}
- **Bloqueos:** {description or "Ninguno"}
```

---

## Dependency Graph Generation

The ASCII dependency graph should be generated from the phase dependency data. Rules:

1. FASE-0 is always the root (no dependencies)
2. Use `│`, `├`, `▼`, `◄`, `►` for arrows
3. Show parallel phases side by side
4. Show the full DAG from FASE-0 to the last phase
5. Keep it readable (max ~60 chars wide)

Example pattern:
```
FASE 0: {Title}
    │
    ├─────────────────────┐
    ▼                     ▼
FASE 1: {Title}     FASE 3: {Title}
    │                     │
    ▼                     │
FASE 2: {Title} ◄─────────┤
    │                     │
    ├─────────────────────┘
    ▼
FASE 4: {Title}
    │
    ▼
...
```

---

## Coverage Matrix Rules

1. **UCs**: List ALL UC numbers, grouped by phase. Verify total = expected count.
2. **ADRs**: List ALL ADR numbers. Some appear in multiple phases (list all).
3. **BDD Tests**: List test file names. Some appear in multiple phases (note section).
4. **Workflows**: Only list phases that have workflows.
5. **Contracts**: List contract files. EVENTS-domain.md appears in ALL phases.
6. **Runbooks/Legal**: Only list phases that have operational docs.
