# Guia Completa Extendida: Todas las Opciones de SDD

> **La guia definitiva** — Cubre las 21 skills, los 5 hooks del plugin, el servidor MCP,
> la aceptacion por requisito y todos los escenarios posibles (greenfield, brownfield, drift, multi-equipo).
>
> **Nota (5.0):** la instalacion vigente esta en [instalacion.md](instalacion.md). Algunos diagramas de esta guia
> simplifican la estructura real de `spec/` (que es `domain/01..05-*.md`, `use-cases/UC-NNN-*.md`, `workflows/`,
> `contracts/API-*.md`, `tests/BDD-UC-NNN.md`, `nfr/*.md`, `adr/ADR-NNN-*.md`) y los IDs de ejemplo; ante la duda
> manda el `SKILL.md` de cada skill.

---

## Tabla de Contenidos

1. [Instalacion y setup completo](#1-instalacion-y-setup-completo)
2. [Diagnostico de proyecto](#2-diagnostico-de-proyecto)
3. [Escenario A: Proyecto nuevo (greenfield)](#3-escenario-a-proyecto-nuevo-greenfield)
4. [Escenario B: Proyecto existente (brownfield)](#4-escenario-b-proyecto-existente-brownfield)
5. [Pipeline principal paso a paso](#5-pipeline-principal-paso-a-paso)
6. [Diseno tecnico (12 dimensiones)](#6-diseno-tecnico-12-dimensiones)
7. [Diseno UX (12 dimensiones)](#7-diseno-ux-12-dimensiones)
8. [Auditoria de seguridad (10 dimensiones)](#8-auditoria-de-seguridad-10-dimensiones)
9. [Gestion de cambios y cascada](#9-gestion-de-cambios-y-cascada)
10. [Importar documentacion externa](#10-importar-documentacion-externa)
11. [Reconciliar specs con codigo](#11-reconciliar-specs-con-codigo)
12. [Herramientas de utilidad](#12-herramientas-de-utilidad)
13. [Aceptacion por requisito y git](#13-aceptacion-por-requisito-y-git)
14. [Servidor MCP (consultas de trazabilidad)](#14-servidor-mcp-consultas-de-trazabilidad)
15. [Automatizacion: hooks](#15-automatizacion-hooks)
16. [La Constitucion SDD (12 articulos)](#16-la-constitucion-sdd-12-articulos)
17. [Notion](#17-notion)
18. [Ejemplo completo: proyecto brownfield con todas las opciones](#18-ejemplo-completo-proyecto-brownfield-con-todas-las-opciones)
19. [Referencia rapida de todos los comandos](#19-referencia-rapida-de-todos-los-comandos)
20. [Glosario extendido](#20-glosario-extendido)

---

## 1. Instalacion y setup completo

### Prerrequisitos

```
┌─────────────────────────────────────────────────────────┐
│  Obligatorio                                             │
│                                                          │
│  ✓ Claude Code CLI  (claude.ai/code)                    │
│  ✓ Git 2.32+        (git commit --trailer)              │
│  ✓ Node.js 18+      (servidor MCP + CLI sdd)            │
│  ✓ jq               (procesamiento JSON en hooks)       │
│                                                          │
│  Opcional (desbloquea funcionalidades extra)             │
│                                                          │
│  ○ gh / glab         Issues y PRs (tracker)              │
│  ○ Notion API key    Sync bidireccional con Notion       │
│  ○ Python 3          Grafo JSON (scripts/sdd-graph.py)   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Paso 1: Instalar el plugin (global, una sola vez)

```bash
claude
```

```
/plugin marketplace add noelserdna/sdd-pipeline
/plugin install sdd-pipeline@noelserdna
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Que se instala globalmente:                                         │
│                                                                      │
│  21 skills como comandos /sdd-*                                      │
│  ├── 7 pipeline       (requirements → implementation)               │
│  ├── 4 laterales      (tech-designer, ux-designer, security, change)│
│  ├── 3 brownfield     (reverse-engineer, reconcile, import)         │
│  ├── 4 utilidades     (status [--diagnose], acceptance,             │
│  │                      gap-detector, session-summary)              │
│  ├── 1 setup          (sdd-setup)                                   │
│  └── 2 conduccion     (sdd-orchestrator, sdd-lead)                  │
│                                                                      │
│  Automatizacion incluida:                                            │
│  ├── 5 hooks del plugin, 7 registros de evento (ver Seccion 15)     │
│  ├── CLI scripts/sdd.mjs (lint, trace, verify, branch, accept, gate)│
│  ├── Quality gates opcionales (H7-H8)                               │
│  ├── Sin agentes: el plugin no distribuye agentes                   │
│  └── Servidor MCP     (herramientas de consulta)                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Paso 2: Inicializar SDD en tu proyecto

```bash
cd mi-proyecto
claude
```

```
/sdd-setup
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Que hace /sdd-setup en tu proyecto:                                 │
│                                                                      │
│  Paso 1: Crea pipeline-state.json (solo sdd-setup lo crea)           │
│  ├── Todas las etapas en "pending"                                   │
│  ├── sddVersion y hooksVersion registradas                          │
│  └── Listo para rastrear progreso                                    │
│                                                                      │
│  Paso 2: Detecta upgrades                                            │
│  ├── Hooks copiados (pre-4.0) → migrate-hooks-v3.sh                 │
│  ├── Status lines y restos de 4.x → los elimina                     │
│  └── Preserva estado existente                                       │
│                                                                      │
│  Paso 3: Hook git commit-msg + validador                             │
│  ├── Instala commit-msg (= sdd verify)                              │
│  ├── Copia el validador a .claude/sdd/sdd.mjs (versionable)         │
│  └── Comprueba git >= 2.32 (git commit --trailer)                   │
│                                                                      │
│  Paso 4: Stack Profile minimo (task_state: trailers) o kit --stack   │
│                                                                      │
│  Paso 5: Instala quality gates opcionales (te pregunta)              │
│  ├── H7: Stop Quality Gate (verifica pipeline al cerrar)            │
│  └── H8: Task Traceability Gate (verifica trailers en commits)      │
│                                                                      │
│  Paso 6: Genera reporte de verificacion                              │
│  ┌──────────────────────────────────────────────────┐               │
│  │  Componente              │ Estado                 │               │
│  │──────────────────────────│────────────────────────│               │
│  │  pipeline-state.json     │ ✅ Creado              │               │
│  │  Hook H1 (session-start) │ ✅ Activo              │               │
│  │  Hook H2 (upstream-guard)│ ✅ Activo              │               │
│  │  Hook H3 (state-updater) │ ✅ Activo              │               │
│  │  Hook H5 (context-augm.) │ ✅ Activo              │               │
│  │  Hook H12 (tool-guard)   │ ✅ Activo              │               │
│  │  commit-msg + validador  │ ✅ Instalado           │               │
│  │  Servidor MCP            │ ✅ Registrado          │               │
│  │  Hook H7 (quality gate)  │ ⚪ No instalado (opt.) │               │
│  │  Hook H8 (task gate)     │ ⚪ No instalado (opt.) │               │
│  └──────────────────────────────────────────────────┘               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Gestion del plugin

```
/plugin                                                    # Gestor visual interactivo
/plugin disable sdd-pipeline@noelserdna                # Desactivar temporalmente
/plugin enable sdd-pipeline@noelserdna                 # Reactivar
/plugin update sdd-pipeline@noelserdna                 # Actualizar a nueva version
/plugin uninstall sdd-pipeline@noelserdna              # Desinstalar
```

---

## 2. Diagnostico de proyecto

Antes de hacer nada, diagnostica tu proyecto para saber por donde empezar:

```
/sdd-pipeline-status --diagnose
```

Sin `pipeline-state.json` ni carpetas SDD, `/sdd-pipeline-status` entra en este modo solo. Es de solo lectura: no
escribe ningun fichero ni ejecuta etapas. Recoge una ficha de hechos (codigo, tests, carpetas SDD, docs importables,
historial git, paquetes, remoto `upstream`, senales de drift), clasifica el proyecto en uno de 8 escenarios (la primera
regla que encaja gana) y propone los comandos en orden, empezando por `/sdd-setup` si falta `pipeline-state.json`:

| Escenario | Senal clave | Comandos tras el setup |
|-----------|-------------|------------------------|
| Multi-equipo | Varios paquetes con su propio manifest | El plan de cada paquete, con `--scope` |
| Fork/migracion | Remoto `upstream` y commits propios | `/sdd-import` del upstream · `/sdd-reverse-engineer --scope=<delta>` · `/sdd-spec-auditor` |
| SDD drift | Artefactos SDD + codigo que han divergido | `/sdd-reconcile --dry-run` · `/sdd-reconcile` · `/sdd-spec-auditor` · `/sdd-gap-detector` |
| Partial SDD | Pipeline a medias sin drift | La primera etapa que falte y el resto |
| Greenfield | Sin codigo | Pipeline completo desde `/sdd-requirements-engineer` |
| Brownfield con docs | Codigo + OpenAPI/Jira/CSV/... | `/sdd-import` · `/sdd-reverse-engineer` · `/sdd-reconcile --dry-run` · `/sdd-spec-auditor` |
| Tests-as-spec | Ratio test/fuente ≥ 0,3 | `/sdd-reverse-engineer` · `/sdd-spec-auditor` · `/sdd-test-planner` · `/sdd-gap-detector --semantic` |
| Brownfield bare | Solo codigo | `/sdd-reverse-engineer --inventory-only` · `--continue` · `/sdd-spec-auditor` · `/sdd-gap-detector --semantic` |

Si un hecho dudoso cambia el resultado (un `upstream` que solo es un espejo, un workspace con un unico paquete real),
pregunta con los dos escenarios candidatos en vez de adivinar. Un pipeline completo sin drift no es un caso de
diagnostico: vuelve al modo estado normal.

---

## 3. Escenario A: Proyecto nuevo (greenfield)

Si tu proyecto es nuevo (Escenario 1), el camino es directo:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Proyecto nuevo → Pipeline completo:                                 │
│                                                                      │
│  /sdd-setup                                                          │
│       ↓                                                              │
│  /sdd-requirements-engineer        ← Tu idea → requisitos formales  │
│       ↓                                                              │
│  /sdd-specifications-engineer      ← Requisitos → 6 docs tecnicos  │
│       ↓                                                              │
│  /sdd-spec-auditor                 ← Auditar + corregir specs       │
│       ↓                                                              │
│  /sdd-tech-designer    (opcional)  ← Explorar stack y arquitectura  │
│  /sdd-ux-designer      (opcional)  ← Diseno visual y accesibilidad │
│  /sdd-security-auditor (opcional)  ← Auditoria OWASP               │
│       ↓                                                              │
│  /sdd-test-planner                 ← Plan de pruebas completo      │
│       ↓                                                              │
│  /sdd-plan-architect               ← Arquitectura C4 + FASEs       │
│       ↓                                                              │
│  /sdd-task-generator               ← Tareas atomicas por FASE      │
│       ↓                                                              │
│  /sdd-task-implementer --fase N    ← Codigo con TDD + commits + demo│
│       ↓                                                              │
│  Puerta de FASE: el cliente acepta el incremento                     │
│  /sdd-acceptance --loop            ← Bucle hasta que todo Must pase │
│  /sdd-acceptance --sign-off        ← Aceptacion + tag fase-N-accepted│
│  /sdd-session-summary              ← Resumir sesion                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

> Este es el camino que cubre la Guia Paso a Paso basica. Continua leyendo
> para ver TODAS las opciones en detalle.

---

## 4. Escenario B: Proyecto existente (brownfield)

### 4.1 Reverse engineering: codigo → artefactos SDD

Cuando tienes codigo pero no tienes especificaciones:

```
/sdd-reverse-engineer
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  El reverse engineer analiza tu codigo en 10 fases:                  │
│                                                                      │
│  Fase 1: Pre-vuelo                                                   │
│  └── Valida entorno, busca artefactos SDD existentes                │
│                                                                      │
│  Fase 2: Escaneo e inventario                                        │
│  ├── Archivos, modulos, dependencias                                │
│  ├── Capas arquitectonicas                                           │
│  ├── Patrones de diseno                                              │
│  ├── Schema de base de datos                                         │
│  └── Tests existentes                                                │
│                                                                      │
│  Fase 3: Analisis profundo de codigo                                 │
│  ├── Extraccion de entidades                                         │
│  ├── Rutas y endpoints                                               │
│  ├── Maquinas de estado                                              │
│  ├── Invariantes implicitas                                          │
│  ├── Codigo muerto                                                   │
│  ├── Deuda tecnica                                                   │
│  └── Workarounds                                                     │
│                                                                      │
│  Fase 4: Analisis de tests                                           │
│  ├── Specs de comportamiento desde tests                            │
│  ├── Patrones de assertions                                          │
│  ├── Mocks y stubs                                                   │
│  └── Gaps de cobertura                                               │
│                                                                      │
│  ══════════════════════════════════════════════                       │
│  CHECKPOINT 1: Inventario y patrones presentados                     │
│  "¿Continuar con generacion de artefactos?"                          │
│  ══════════════════════════════════════════════                       │
│                                                                      │
│  Fase 5: Extraccion de requisitos                                    │
│  └── Genera REQ-* en formato EARS, marcados [INFERRED]              │
│                                                                      │
│  Fase 6: Generacion de especificaciones                              │
│  └── Domain model, use cases, workflows, API contracts, NFRs, ADRs  │
│                                                                      │
│  ══════════════════════════════════════════════                       │
│  CHECKPOINT 2: Specs generadas mostradas                             │
│  "¿Proceder con test plan, arquitectura y tareas?"                   │
│  ══════════════════════════════════════════════                       │
│                                                                      │
│  Fase 7: Mapeo de test plan                                          │
│  Fase 8: Reconstruccion del plan de arquitectura                     │
│  Fase 9: Reconstruccion de tareas (marcadas [RETROACTIVE])          │
│  Fase 10: Mapeo de trazabilidad + reporte de hallazgos              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Modos de ejecucion

```
/sdd-reverse-engineer                              # Completo (10 fases)
/sdd-reverse-engineer --scope=src/api,src/models   # Solo ciertos paths
/sdd-reverse-engineer --inventory-only             # Solo escaneo (fases 1-3)
/sdd-reverse-engineer --findings-only              # Solo hallazgos (dead code, tech debt)
/sdd-reverse-engineer --continue                   # Reanudar desde ultimo checkpoint
```

### Marcadores especiales

Los artefactos generados por reverse-engineer usan marcadores para distinguir
lo inferido de lo explicitado:

```
┌──────────────────────────────────────────────────────────────┐
│  Marcador              Significado                            │
│  ─────────────────── ─────────────────────────────────────── │
│  [INFERRED]           Requisito inferido del codigo          │
│  [IMPLICIT-RULE]      Regla de negocio implicita detectada   │
│  [RETROACTIVE]        Tarea ya implementada (documentacion)  │
│  [DEAD-CODE]          Codigo sin uso detectado               │
│  [TECH-DEBT]          Deuda tecnica identificada             │
│  [WORKAROUND]         Solucion temporal/hack                 │
│  [INFRASTRUCTURE]     Codigo de infraestructura              │
│  [ORPHAN]             Codigo sin conexion al dominio         │
│                                                              │
│  Severidad de hallazgos:                                     │
│  🔴 critical    Riesgo inmediato                             │
│  🟠 high        Deberia resolverse pronto                    │
│  🟡 medium      Planificar resolucion                        │
│  🔵 low         Informativo                                  │
└──────────────────────────────────────────────────────────────┘
```

### Archivos generados

```
mi-proyecto/
├── requirements/REQUIREMENTS.md        ← Requisitos extraidos
├── spec/
│   ├── DOMAIN-MODEL.md                 ← Entidades del codigo
│   ├── USE-CASES.md                    ← Casos de uso inferidos
│   ├── WORKFLOWS.md                    ← Flujos detectados
│   ├── API-CONTRACTS.md                ← Contratos de API
│   ├── NFR.md                          ← NFRs observados
│   └── adr/ADR-*.md                    ← Decisiones documentadas
├── test/
│   ├── TEST-PLAN.md                    ← Plan mapeado a tests existentes
│   └── TEST-MATRIX-*.md               ← Matrices con gaps
├── plan/
│   ├── ARCHITECTURE.md                 ← Arquitectura C4 retroactiva
│   └── fases/FASE-*.md                 ← Fases retroactivas
├── task/TASK-FASE-*.md                 ← Tareas [RETROACTIVE]
├── findings/FINDINGS-REPORT.md         ← Dead code, tech debt, workarounds
└── reverse-engineering/
    ├── INVENTORY.md                    ← Inventario del codebase
    ├── ANALYSIS.md                     ← Analisis profundo
    └── TEST-ANALYSIS.md               ← Analisis de tests
```

### 4.2 Importar documentacion externa

Si tienes documentacion en otros formatos (Jira, OpenAPI, Notion, etc.):

```
/sdd-import path/to/archivo
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  6 formatos soportados:                                              │
│                                                                      │
│  Formato     Extensiones    Que se extrae                            │
│  ─────────── ───────────── ──────────────────────────────────────── │
│  Jira        .json, .csv   Epics → grupos req, Stories → use cases, │
│                             Bugs → defectos, Tasks → notas          │
│                                                                      │
│  OpenAPI     .yaml, .json  Paths → API contracts, Schemas → domain, │
│              (3.x / 2.x)   Security → NFRs, Descriptions → reqs    │
│                                                                      │
│  Markdown    .md            Headings → secciones, Lists → reqs,     │
│                             Code blocks → specs                     │
│                                                                      │
│  Notion      .md + meta,   DB rows → requirements,                  │
│              .csv export    Pages → specs, Properties → atributos   │
│                                                                      │
│  CSV         .csv           Columns → campos req,                    │
│                             Rows → reqs individuales                │
│                                                                      │
│  Excel       .xlsx          Sheets → tipos de artefacto,            │
│                             Rows → items, Named cols → campos       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Modos de importacion

```
# Auto-detectar formato
/sdd-import docs/api-spec.yaml

# Formato explicito
/sdd-import exports/jira-export.csv --format=jira

# Solo generar requisitos (no specs)
/sdd-import docs/requirements.csv --target=requirements

# Solo generar specs (no reqs)
/sdd-import docs/api.yaml --target=specs

# Generar ambos
/sdd-import docs/api.yaml --target=both

# Merge con artefactos existentes
/sdd-import docs/nuevos-reqs.csv --merge

# Multiples archivos
/sdd-import docs/api.yaml docs/requirements.csv docs/notion-export/

# Sin confirmacion interactiva
/sdd-import docs/api.yaml --yes
```

### Proceso de importacion (7 fases)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Fase 1: Deteccion de formato                                        │
│  └── Analiza extension + contenido → identifica formato             │
│                                                                      │
│  Fase 2: Parseo                                                      │
│  └── Convierte a representacion intermedia normalizada              │
│                                                                      │
│  Fase 3: Preview de mapeo                                            │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │                                                          │        │
│  │  Original (Jira):                                        │        │
│  │  "As a user, I want to create tasks"                     │        │
│  │                                                          │        │
│  │  → EARS:                                                  │        │
│  │  WHEN a user submits task creation form                   │        │
│  │  THE system SHALL create a new task                       │        │
│  │  AND assign a unique identifier                          │        │
│  │                                                          │        │
│  │  ¿Aprobar esta conversion? [y/n]                         │        │
│  │                                                          │        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                      │
│  Fase 4: Confirmacion del usuario                                    │
│  └── Duplicados: Skip / Merge / Replace                             │
│                                                                      │
│  Fase 5: Generacion de artefactos SDD                                │
│  └── Marcados con [IMPORTED], [MERGED], o [IMPORTED-REPLACED]       │
│                                                                      │
│  Fase 6: Check de calidad                                            │
│  ├── % de conversion a EARS                                         │
│  ├── Trazabilidad lista?                                             │
│  └── Items que necesitan revision manual                            │
│                                                                      │
│  Fase 7: Actualizar pipeline-state.json                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Archivos generados

```
mi-proyecto/
├── requirements/REQUIREMENTS.md        ← Con marcadores [IMPORTED]
├── spec/                               ← Specs generadas del import
│   ├── DOMAIN-MODEL.md
│   ├── API-CONTRACTS.md
│   └── ...
└── import/
    └── IMPORT-REPORT.md                ← Estadisticas, items pendientes
```

### 4.3 Reconciliar specs con codigo

Cuando ya tienes artefactos SDD PERO el codigo se alejo de ellos:

```
/sdd-reconcile
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  6 tipos de divergencia detectados:                                  │
│                                                                      │
│  Tipo                   Senal                   Resolucion           │
│  ───────────────────── ─────────────────────── ──────────────────── │
│  NEW_FUNCTIONALITY     Codigo existe sin spec;  AUTO: actualizar    │
│                        tiene tests o se usa     specs (codigo gana) │
│                                                                      │
│  REMOVED_FEATURE       Spec existe sin codigo;  AUTO: deprecar      │
│                        sin commits recientes    en specs             │
│                                                                      │
│  BEHAVIORAL_CHANGE     Ambos existen pero       PREGUNTA: ¿codigo   │
│                        comportamiento difiere   es correcto o bug?  │
│                                                                      │
│  REFACTORING           Estructura cambio pero   AUTO: actualizar    │
│                        comportamiento igual     refs tecnicas       │
│                                                                      │
│  BUG_OR_DEFECT         Codigo contradice spec   PREGUNTA: ¿arreglar│
│                        Y tests fallan/faltan    codigo o spec?      │
│                                                                      │
│  AMBIGUOUS             No se puede determinar   PREGUNTA: clasificar│
│                        con confianza            manualmente          │
│                                                                      │
│  Confianza:                                                          │
│  HIGH (>75%)  MEDIUM (50-75%)  LOW (<50%)                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Modos de reconciliacion

```
/sdd-reconcile                                # Completo: auto-resolve + preguntas
/sdd-reconcile --dry-run                      # Solo detectar, no cambiar nada
/sdd-reconcile --scope=src/api,src/models     # Solo ciertos paths
/sdd-reconcile --code-wins                    # Todo se resuelve a favor del codigo
```

### Proceso (8 fases)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Fase 1: Cargar contexto                                             │
│  └── Lee requirements/, spec/, pipeline-state.json                  │
│                                                                      │
│  Fase 2: Escaneo de codigo                                           │
│  └── Analiza features actuales del codigo                           │
│      (opcionalmente usa servidor MCP para code intelligence)        │
│                                                                      │
│  Fase 3: Comparacion spec ↔ codigo                                  │
│  ├── Spec sin codigo                                                │
│  ├── Codigo sin spec                                                │
│  └── Diferencias de comportamiento                                   │
│                                                                      │
│  Fase 4: Clasificacion de divergencias                               │
│  └── Asigna tipo + confianza a cada divergencia                     │
│                                                                      │
│  Fase 5: Plan de reconciliacion                                      │
│  ├── Cambios automaticos (NEW_FUNCTIONALITY, REMOVED, REFACTORING)  │
│  └── Preguntas para usuario (BEHAVIORAL, BUG, AMBIGUOUS)           │
│                                                                      │
│  Fase 6: Revision del usuario                                        │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │                                                          │        │
│  │  Divergencia D-003 (BEHAVIORAL_CHANGE, HIGH):            │        │
│  │                                                          │        │
│  │  Spec dice:   "Tareas eliminadas van a papelera"        │        │
│  │  Codigo hace: "Tareas eliminadas se borran permanente"  │        │
│  │  Tests:       No hay test para esto                      │        │
│  │                                                          │        │
│  │  Opciones:                                               │        │
│  │  A) Actualizar spec (el codigo es correcto)              │        │
│  │  B) Marcar como bug (la spec es correcta)                │        │
│  │  C) Necesito mas contexto                                │        │
│  │                                                          │        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                      │
│  Fase 7: Aplicar cambios                                             │
│  └── Actualiza specs con marcadores [RECONCILED], [DEPRECATED]      │
│                                                                      │
│  Fase 8: Actualizar pipeline state                                   │
│  └── Marca stages afectados como stale                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Archivos generados

```
reconciliation/
└── RECONCILIATION-REPORT.md    ← Resumen ejecutivo, acciones, pendientes
```

---

## 5. Pipeline principal paso a paso

> Esta seccion resume los 7 pasos del pipeline. Para detalles completos
> de cada paso, consulta la Guia Paso a Paso basica.

### Paso 1: Requisitos

```
/sdd-requirements-engineer

# Opciones de entrada:
# - Idea informal ("quiero una app de...")
# - Archivo con notas (docs/mi-idea.md)
# - Multiples fuentes
```

Genera dos ficheros:

- `requirements/CUSTOMER-NEEDS.md`: las palabras del cliente, literales, como necesidades `N-NNN` (cita, quien y
  cuando). Se releen con el cliente **antes** de escribir ningun requisito.
- `requirements/REQUIREMENTS.md`: requisitos EARS (WHEN/THE/SHALL). Cada uno lleva:
  - `Needs:` con las necesidades que sirve (los `REQ-C` de equipo pueden llevar `Needs: —`);
  - `Verification: test | demo | measurement | inspection`, el metodo con el que se aceptara;
  - criterios de aceptacion con un ejemplo con datos reales, revisado con el cliente (`Examples reviewed by:`).

```
### REQ-F-001: Create a task
- **Statement:** WHEN the user runs `todo add <title>` THE system SHALL create a task ...
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN an empty task list WHEN the user runs `todo add "Buy milk"` THEN a task with id 1 ... is stored
```

**Puerta 1 (aprobacion):**

1. `node scripts/sdd.mjs lint --needs` comprueba de forma mecanica que toda necesidad esta cubierta o fuera de
   alcance con su decision, que todo `REQ-F`/`REQ-NF` cita una necesidad (lo contrario es gold plating) y que todo
   requisito tiene un `Verification:` valido.
2. Si mas del 60 % de los requisitos son Must, avisa; en cualquier caso el cliente confirma la lista Must.
3. Opcional, con Jev: `sdd-jev.mjs needs` sugiere necesidades sin cubrir y candidatos a gold plating. Solo sugiere.
4. Solo con un "Apruebo" explicito: commit `docs(requirements)` y tag anotado `requirements-v{N}` con aprobador, rol,
   fecha y el sha256 de `REQUIREMENTS.md` y `CUSTOMER-NEEDS.md`. El tool guard pide confirmacion antes del tag.

### Paso 2: Especificaciones

```
/sdd-specifications-engineer
```

Genera el arbol `spec/`: `domain/`, `use-cases/UC-NNN-*.md`, `workflows/`, `contracts/API-*.md`,
`tests/BDD-UC-NNN.md` (escenarios con ID `AC-NNN-NN`), `nfr/` y `adr/`.

### Paso 3: Auditoria de especificaciones

```
/sdd-spec-auditor
```

**Dos modos:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Modo AUDIT (por defecto):                                           │
│  Detecta defectos en 9 categorias:                                   │
│                                                                      │
│  CAT-01 (AMB-)  Ambiguedades         "aproximadamente 200ms"        │
│  CAT-02 (IMP-)  Reglas implicitas    Comportamiento asumido         │
│  CAT-03 (SIL-)  Silencios peligrosos Error handling no especificado │
│  CAT-04 (SEM-)  Ambiguedad semantica Mismo termino, distintos usos  │
│  CAT-05 (CON-)  Contradicciones      Docs dicen cosas distintas     │
│  CAT-06 (INC-)  Specs incompletas    TODOs, TBDs, secciones vacias │
│  CAT-07 (INV-)  Invariantes debiles  Reglas sin formal INV-*        │
│  CAT-08 (EVO-)  Riesgos de evolucion Hardcoding, acoplamiento      │
│  CAT-09 (ADR-)  Decisiones sin ADR   Elecciones sin justificacion  │
│                                                                      │
│  Modo FIX:                                                           │
│  Corrige los hallazgos de la auditoria:                              │
│  ├── Lee el reporte de auditoria                                    │
│  ├── Genera plan de correcciones con 2+ opciones por hallazgo       │
│  ├── Tu decides: batch (auto-aplicar) o interactivo (1 a 1)        │
│  ├── Aplica correcciones por prioridad (Critico → Bajo)            │
│  ├── Actualiza AUDIT-BASELINE.md                                    │
│  └── Analiza impacto upstream (puede necesitar /sdd-req-change)    │
│                                                                      │
│  Modo FOCUSED:                                                       │
│  Auditoria ligera solo de documentos cambiados                      │
│  (activado automaticamente por cascada de req-change)               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Protocolo 3C de verificacion:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  3 dimensiones verificadas:                                          │
│                                                                      │
│  SC — Completeness (Completitud)                                     │
│  ├── Trazabilidad REQ → Spec 100%                                   │
│  ├── Sin specs huerfanas                                             │
│  └── Todos los subdirectorios poblados                              │
│                                                                      │
│  SR — Correctness (Correccion)                                       │
│  ├── Specs reflejan intencion de REQs                               │
│  ├── Sin contradicciones                                             │
│  └── Codigos INV-* validos                                          │
│                                                                      │
│  SH — Coherence (Coherencia)                                         │
│  ├── Glosario respetado                                              │
│  ├── Terminologia uniforme                                           │
│  └── Cross-references validas                                        │
│                                                                      │
│  Quality Gate: FAIL en SC o SR BLOQUEA progresion a plan-architect  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Baseline incremental:** La primera auditoria crea un baseline. Las siguientes
solo reportan hallazgos NUEVOS y REGRESIONES (no repite los ya conocidos).

### Paso 4: Plan de pruebas

```
/sdd-test-planner
```

Genera: `test/TEST-PLAN.md`, `test/TEST-MATRIX-*.md`, `test/PERF-SCENARIOS.md`, con objetivos por caso de uso.

**Regla de nombres:** cada test lleva en su nombre el ID del escenario que verifica (`AC-001-03`, o `REQ-NF-002 AC1`
para un NFR sin escenario BDD). Asi el resultado JUnit se ata a un criterio de aceptacion; un `Refs:` a nivel de
fichero no cuenta como evidencia.

### Paso 5: Arquitectura y plan

```
/sdd-plan-architect
```

Genera: `plan/PLAN.md` (con `> **Plan-Style:** vertical`), `plan/ARCHITECTURE.md`, `plan/fases/FASE-*.md`
y `plan/fase-plans/PLAN-FASE-{N}.md`.

**FASEs verticales.** Cada FASE es un incremento que el cliente puede ver funcionando, no una capa:

| Regla | Contenido |
|---|---|
| Orden | Las dependencias mandan; MoSCoW desempata |
| FASE-0 (esqueleto) | `FASE-0-SKELETON.md`: el camino minimo escribir → observar → persistir del caso de uso central, con solo la infraestructura que ese camino necesita |
| Incrementos | Un recorrido de usuario por FASE (el CRUD de una entidad es uno). Maximo 3 casos de uso y unas 15 tareas |
| Seguridad | Autenticacion y validacion en la primera FASE que expone el recurso; un rol entra con su primera capacidad |
| NFR | `FASE-N-HARDENING` solo para NFR medidos (rendimiento, disponibilidad), y solo si existen |
| Streams | Excepcion: solo con conjuntos de escritura disjuntos |
| Planes mixtos | Un plan horizontal previo conserva sus FASEs; las nuevas van en vertical despues de la ultima verificada |

Ejemplo del todo-app:

| FASE | Incremento | Requisitos |
|------|-----------|------------|
| FASE-0-SKELETON | Apuntar tareas y verlas en otra ejecucion | REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002 |
| FASE-1-LIFECYCLE | Completar y borrar tareas | REQ-F-003, REQ-F-004 |
| FASE-2-FILTER | Filtrar por estado | REQ-F-005 |
| FASE-3-HARDENING | Latencia con 1 000 tareas | REQ-NF-001 |

Cabecera de cada FASE y su demo (maximo 10 pasos desde un checkout limpio, cada uno citando su escenario y sus
necesidades):

```markdown
# FASE 0: Esqueleto — apuntar tareas y verlas de nuevo

> **Incremento:** Apuntar tareas y verlas en otra ejecucion
> **Requisitos:** REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002
> **Escenarios:** AC-001-01, AC-001-03, AC-002-01, AC-002-04, REQ-NF-002 AC1
> **Necesidades:** N-001, N-002, N-004, N-005
> **Dependencias:** Ninguna (fase inicial)

## Demo
| # | Accion | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `rm -rf data && todo list` | `No tasks`, exit 0 | AC-002-02 · N-002 |
| 2 | `todo add "Buy milk"` | tarea 1 pending; `data/todos.json` creado | AC-001-01, AC-001-04 · N-001, N-004 |
```

`node scripts/sdd.mjs lint --plan` lo comprueba: cada FASE con `Requisitos` y `Escenarios`, criterios y demo
respaldados por IDs REQ/AC existentes (V8) y todo requisito Must asignado a alguna FASE (V9). Un plan sin
`Plan-Style: vertical` se trata como horizontal y sigue funcionando.

> Si ejecutaste `/sdd-tech-designer` y/o `/sdd-ux-designer` antes,
> el arquitecto los consume automaticamente en su Phase 0.

### Paso 6: Generacion de tareas

```
/sdd-task-generator
```

Genera: `task/TASK-FASE-*.md`, `task/TASK-ORDER.md` y, en formato completo, `task/TASK-INDEX.md` (opcional: `node scripts/sdd.mjs tasks index` lo deriva). Con un plan vertical, Foundation minima y slices agrupados por caso de uso (`### UC-NNN`); cada escenario de la cabecera de la FASE lo cita alguna tarea.

### Paso 7: Implementacion

```
/sdd-task-implementer
```

Implementa tarea por tarea con TDD (Red → Green → Refactor → Commit), en una **rama de trabajo**: en la rama por
defecto crea `fase-{N}-{slug}` con `node scripts/sdd.mjs branch start fase N <slug>` (en otra rama sigue ahi; con HEAD
suelto se para). Una tarea = un commit, con los trailers escritos por git:

```bash
git commit -m "feat(tasks): create task with server-side validation" \
  --trailer "Task: TASK-F0-003" \
  --trailer "Refs: UC-001, API-001-01, AC-001-03"
```

- `feat`/`test`/`refactor` exigen `Task`; `fix`/`perf` exigen `Task` **o** `Change` (`CHG-…`, `CR-…` o un hallazgo),
  para que un hotfix no quede bloqueado; `docs(specs)` exige `Refs`.
- El hook git `commit-msg` ejecuta las mismas reglas que `sdd verify` (validador copiado a `.claude/sdd/sdd.mjs`).
- Merge solo con merge commit (`git merge --no-ff`), nunca squash ni rebase: borrarian los trailers.
- Detalle en `references/git-conventions.md` del plugin.

Al terminar la FASE (Phase 9) ejecuta la **demo** de la FASE y `sdd accept --fase N`. Despues llega la **puerta de
FASE**: se presenta la demo y el veredicto por requisito y el cliente responde:

| Respuesta | Que pasa |
|---|---|
| Aceptado | `sdd-acceptance --sign-off --fase N` registra la decision y crea el tag anotado `fase-N-accepted` |
| Aceptado con observaciones | Igual, con tag; cada observacion se enruta sin bloquear |
| Rechazado, con feedback | Sin tag; cada punto se clasifica (defecto → tareas incrementales; peticion de cambio → `/sdd-req-change`; pregunta → se responde). Jev `feedback-route` puede proponer la ruta; una persona confirma |

Si faltan requisitos por verificar, `/sdd-acceptance --loop` itera hasta el objetivo (ver Seccion 13).

---

## 6. Diseno tecnico (12 dimensiones)

```
/sdd-tech-designer
```

Explora decisiones de arquitectura y tecnologia **antes** de planificar.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Las 12 dimensiones del Tech Designer:                                       │
│                                                                              │
│  #   Dimension              Que decide                    Ejemplo           │
│  ──  ───────────────────── ───────────────────────────── ──────────────── │
│  1   Canales de entrega    Web, mobile, API, CLI,        "SPA + API REST" │
│                             desktop, IoT                                    │
│                                                                              │
│  2   Estilo arquitectura   Monolito, microservicios,     "Modular          │
│                             serverless, modular monolith  monolith"        │
│                                                                              │
│  3   Stack tecnologico     Lenguaje, framework, runtime  "TypeScript +     │
│                                                           Next.js"         │
│                                                                              │
│  4   Estrategia de datos   BD tipo, schema, migrations,  "PostgreSQL +     │
│                             caching, backups              Redis cache"     │
│                                                                              │
│  5   Auth y seguridad      Modelo auth, encryption,      "JWT + RBAC +    │
│                             compliance                    bcrypt"          │
│                                                                              │
│  6   Diseno de API         REST/GraphQL/gRPC,            "REST con         │
│                             versionado, rate limiting     OpenAPI 3.1"     │
│                                                                              │
│  7   Infraestructura       Cloud, containers, IaC, CDN   "AWS ECS +       │
│                                                           CloudFront"      │
│                                                                              │
│  8   CI/CD                 Build, test, deploy, rollback  "GitHub Actions  │
│                                                           + blue-green"    │
│                                                                              │
│  9   Observabilidad        Logs, metricas, tracing,      "Datadog +       │
│                             alerting                      structured logs" │
│                                                                              │
│  10  Costos y escalado     Budget, scaling strategy,     "Auto-scale 2-8  │
│                             cost optimization            instances"        │
│                                                                              │
│  11  Developer Experience  Monorepo, tooling, local dev, "Turborepo +     │
│                             onboarding                   Docker Compose"   │
│                                                                              │
│  12  i18n / Accesibilidad  Idiomas, formatos, timezones, "i18next + RTL  │
│                             WCAG, RTL                    + CLDR"           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Modos de ejecucion

```
/sdd-tech-designer                              # Completo: 12 dimensiones
/sdd-tech-designer --dimensions=1,4,5,7         # Solo dimensiones especificas
/sdd-tech-designer --update                     # Actualizar diseno existente
/sdd-tech-designer --quality-only               # Solo atributos de calidad (ATAM-lite)
```

### Proceso (5 fases)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Phase 0: Cargar contexto                                            │
│  └── Lee specs, decisiones existentes, findings de seguridad        │
│                                                                      │
│  Phase 1: Vision del sistema                                         │
│  └── Tipo de sistema, stakeholders tecnicos, restricciones duras    │
│                                                                      │
│  Phase 2: Atributos de calidad (ATAM-lite)                           │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │                                                          │        │
│  │  Atributo         Score  Prioridad                       │        │
│  │  ──────────────── ───── ──────────                      │        │
│  │  Performance       4/5   Alta                            │        │
│  │  Scalability       3/5   Media                           │        │
│  │  Security          5/5   Critica                         │        │
│  │  Maintainability   4/5   Alta                            │        │
│  │  Availability      3/5   Media                           │        │
│  │  Testability       4/5   Alta                            │        │
│  │                                                          │        │
│  │  Trade-offs identificados:                               │        │
│  │  • Performance vs Security: JWT valido 15min (no 24h)   │        │
│  │  • Simplicity vs Scalability: monolith now, split later │        │
│  │                                                          │        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                      │
│  Phase 3: Analisis interactivo (12 dimensiones)                      │
│  └── Preguntas contextuales por dimension, opciones con trade-offs  │
│                                                                      │
│  Phase 4: Generar outputs                                            │
│  └── TECHNICAL-DESIGN.md, QUALITY-ATTRIBUTES.md, ADR-DRAFT-*.md    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Archivos generados

```
design/
├── TECHNICAL-DESIGN.md        ← Decisiones por dimension
├── QUALITY-ATTRIBUTES.md      ← Trade-offs y priorizacion ATAM-lite
└── ADR-DRAFT-NNN-{slug}.md   ← Borradores de ADRs (0 o mas)
```

> **Tip:** Si `design/` existe cuando ejecutas `/sdd-plan-architect`,
> el arquitecto lo consume automaticamente y no te pregunta cosas ya decididas.

---

## 7. Diseno UX (12 dimensiones)

```
/sdd-ux-designer
```

Define el sistema de diseno visual y de interaccion.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Las 12 dimensiones del UX Designer:                                         │
│                                                                              │
│  #   Dimension              Que define                   Detalle            │
│  ──  ───────────────────── ───────────────────────────── ──────────────── │
│  1   Identidad de marca    Logo, colores, tipografia,   Palette primaria,  │
│                             voz y tono                   font stack         │
│                                                                              │
│  2   Design tokens          Variables reutilizables:     JSON exportable a  │
│                             colores, spacing, radii,     CSS/Tailwind/etc.  │
│                             shadows, breakpoints                            │
│                                                                              │
│  3   Componentes            Atomic Design:               Atoms → molecules  │
│                             atoms, molecules,            → organisms →      │
│                             organisms, templates, pages  templates → pages  │
│                                                                              │
│  4   Responsive/Adaptive    Breakpoints, mobile-first    320, 768, 1024,   │
│                             vs desktop-first, fluid      1280, 1440        │
│                                                                              │
│  5   Accesibilidad          WCAG 2.2 AA:                 Contraste 4.5:1,  │
│                             contraste, keyboard,         focus visible,     │
│                             screen readers, ARIA, focus  ARIA landmarks    │
│                                                                              │
│  6   Interaccion            Micro-interacciones,         Duracion: 200ms,  │
│                             transiciones, animaciones,   easing: ease-out,  │
│                             loading states               skeleton loaders  │
│                                                                              │
│  7   Formularios            Validacion, errores,         Inline validation, │
│                             field types, multi-step      error below field, │
│                             flows                        autosave           │
│                                                                              │
│  8   Navegacion             Nav patterns, breadcrumbs,   Sidebar + top nav, │
│                             search, sitemap, IA          max depth 3       │
│                                                                              │
│  9   Seguridad frontend     CSP, XSS prevention,        CSP nonces, SRI,  │
│                             CSRF, cookies, clickjacking, X-Frame-Options   │
│                             SRI (Subresource Integrity)                     │
│                                                                              │
│  10  Performance frontend   Core Web Vitals:             LCP < 2.5s,       │
│                             LCP, INP, CLS,              INP < 200ms,       │
│                             lazy loading, code splitting CLS < 0.1         │
│                                                                              │
│  11  Mobile                 Touch targets (48px min),    Swipe gestures,   │
│                             gestos, offline-first, PWA   service worker    │
│                                                                              │
│  12  Dark mode / Temas      Theme switching, semantica   prefers-color-     │
│                             de colores, preferencia user scheme, CSS vars  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Modos de ejecucion

```
/sdd-ux-designer                                          # Completo: 12 dimensiones
/sdd-ux-designer --dimensions=brand,accessibility,mobile  # Solo dimensiones especificas
/sdd-ux-designer --update                                 # Actualizar diseno existente
/sdd-ux-designer --wireframes-only                        # Solo wireframes y componentes
```

### Archivos generados

```
ux/
├── UI-DESIGN-SYSTEM.md        ← Sistema de diseno completo (12 dims)
├── WIREFRAMES.md              ← Wireframes ASCII por pantalla (SCR-NNN)
├── ACCESSIBILITY-SPEC.md      ← Checklist WCAG 2.2 AA
├── INTERACTION-MODEL.md       ← Estados, transiciones, animaciones, errores
└── DESIGN-TOKENS.json         ← Tokens exportables a cualquier framework
```

### Ejemplo de Design Tokens

```json
{
  "colors": {
    "primary": { "50": "#eff6ff", "500": "#3b82f6", "900": "#1e3a5f" },
    "semantic": { "success": "#22c55e", "error": "#ef4444", "warning": "#f59e0b" }
  },
  "spacing": { "xs": "4px", "sm": "8px", "md": "16px", "lg": "24px", "xl": "32px" },
  "borderRadius": { "sm": "4px", "md": "8px", "lg": "16px", "full": "9999px" },
  "typography": {
    "fontFamily": { "sans": "Inter, system-ui", "mono": "JetBrains Mono, monospace" },
    "fontSize": { "xs": "12px", "sm": "14px", "base": "16px", "lg": "18px" }
  },
  "breakpoints": { "sm": "640px", "md": "768px", "lg": "1024px", "xl": "1280px" }
}
```

> **Tip:** Si `ux/` existe cuando ejecutas `/sdd-plan-architect`,
> el arquitecto integra el sistema de diseno en las fases de implementacion.

---

## 8. Auditoria de seguridad (10 dimensiones)

```
/sdd-security-auditor
```

Evalua la postura de seguridad de tus especificaciones usando OWASP ASVS v4 y CWE.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Security Posture Scorecard (10 dimensiones):                                │
│                                                                              │
│  #   Dimension (peso)                Score  Grado  Hallazgos               │
│  ──  ─────────────────────────────  ─────  ─────  ─────────────────────── │
│  1   Autenticacion (15%)             8/10   B      AUTH-001: Falta MFA     │
│  2   Autorizacion (15%)              6/10   C      AUTHZ-002: Sin RBAC    │
│                                                     granular               │
│  3   Proteccion de datos (15%)       9/10   A      (sin hallazgos)        │
│  4   Validacion de input (10%)       7/10   B      INPUT-001: Falta       │
│                                                     sanitizacion HTML      │
│  5   Criptografia (10%)              8/10   B      (sin hallazgos)        │
│  6   Respuesta a incidentes (10%)    4/10   D      INCIDENT-001: Sin      │
│                                                     runbooks              │
│  7   Compliance regulatorio (10%)    6/10   C      COMPLY-001: GDPR       │
│                                                     data retention         │
│  8   Cobertura test seguridad (5%)   5/10   C      STEST-001: Sin tests  │
│                                                     de inyeccion          │
│  9   Cobertura threat model (5%)     3/10   D      THR-001: Sin modelo   │
│                                                     de amenazas           │
│  10  Documentacion decisiones (5%)   7/10   B      SADR-001: Auth sin    │
│                                                     ADR formal            │
│                                                                              │
│  Score total: 67/100    Grado: B-                                           │
│                                                                              │
│  Grados: A (90-100) B (70-89) C (50-69) D (30-49) F (0-29)               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10 categorias de hallazgos

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Prefijo     Categoria                       Ref OWASP/CWE          │
│  ──────────  ─────────────────────────────  ──────────────────────  │
│  THR-        Superficie de amenaza sin       ASVS 1.1               │
│              modelo de threats                                       │
│                                                                      │
│  AUTH-       Gaps de autenticacion           ASVS 2.x, CWE-287     │
│              (login, MFA, password policy)                           │
│                                                                      │
│  AUTHZ-      Gaps de autorizacion            ASVS 4.x, CWE-862     │
│              (RBAC, tenant isolation)                                │
│                                                                      │
│  DATA-       Proteccion de datos             ASVS 8.x, CWE-311     │
│              (PII, encryption, key mgmt)                            │
│                                                                      │
│  INPUT-      Validacion de input ausente     ASVS 5.x, CWE-20      │
│              (injection, XSS, SSRF)                                 │
│                                                                      │
│  CRYPTO-     Criptografia debil/incompleta   ASVS 6.x, CWE-327     │
│              (algoritmos, key lifecycle)                             │
│                                                                      │
│  INCIDENT-   Respuesta a incidentes          ASVS 7.x              │
│              (deteccion, escalation, audit)                          │
│                                                                      │
│  COMPLY-     Compliance regulatorio          GDPR, PCI-DSS          │
│              (consent, retention, rights)                            │
│                                                                      │
│  STEST-      Tests de seguridad faltantes    ASVS 14.x             │
│              (BDD security, pentesting)                              │
│                                                                      │
│  SADR-       Decisiones de seguridad sin     Art. 11                │
│              ADR (protocolo, cifrado, auth)                          │
│                                                                      │
│  Severidad (misma escala P0-P3 que el spec-auditor):                 │
│  Critico (P0)  Explotable sin mitigacion, PII expuesta, auth bypass│
│  Alto (P1)     Control parcial, gap explotable bajo condiciones     │
│  Medio (P2)    Control incompleto, defense-in-depth faltante        │
│  Bajo (P3)     Mejora sin amenaza inmediata, gap de documentacion   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Protocolo multi-agente

El security auditor internamente coordina 4 agentes especializados:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  AUTH-agent   → Autenticacion + Autorizacion (AUTH-, AUTHZ-)        │
│  DATA-agent   → Proteccion datos + Criptografia (DATA-, CRYPTO-)   │
│  COMPLY-agent → Compliance + Incidentes (COMPLY-, INCIDENT-)       │
│  TEST-agent   → Tests + Threats + ADRs + Input (STEST-, THR-,      │
│                  SADR-, INPUT-)                                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Archivo generado

```
audits/
└── SECURITY-AUDIT-BASELINE.md    ← Scorecard + hallazgos detallados
```

> Como el spec-auditor, usa baseline incremental: la primera vez crea el
> baseline completo, las siguientes solo reportan nuevos y regresiones.
>
> El auditor no edita las specs: las correcciones pasan por `/sdd-req-change` (un CR por hallazgo o grupo, citando
> sus IDs) y un humano decide cada una. Los requisitos de seguridad son `REQ-NF-NNN` cuyo objeto es un control, las
> filas `SEC-NNN` de `spec/nfr/SECURITY.md` y los invariantes `INV-{AREA}-NNN`; no existe un prefijo `REQ-SEC`.

---

## 9. Gestion de cambios y cascada

```
/sdd-req-change
```

El skill mas poderoso del sistema. Gestiona el ciclo completo de cambios
en requisitos con propagacion automatica por todo el pipeline.

### 3 operaciones

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ADD        Nuevo requisito                                          │
│  ├── Genera nuevo REQ-*, UC-*, WF-*, API-*, BDD-*                  │
│  ├── Actualiza domain model, test plan, fases, tareas              │
│  └── Ejemplo: "Agregar notificaciones push"                        │
│                                                                      │
│  MODIFY     Cambiar requisito existente                              │
│  ├── Modifica el REQ-* y todos los artefactos downstream           │
│  ├── Analiza blast radius antes de aplicar                          │
│  └── Ejemplo: "Las tareas ahora tienen prioridad"                  │
│                                                                      │
│  DEPRECATE  Retirar funcionalidad                                    │
│  ├── Marca REQ-* como [DEPRECATED] (no se borra)                   │
│  ├── Propaga deprecacion a specs, tests, plan                      │
│  ├── Genera plan de sunset con timeline                             │
│  └── Ejemplo: "Eliminar soporte para IE11"                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Clasificacion ISO 14764 (automatica)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Tipo            Descripcion                    Ejemplo              │
│  ──────────────  ───────────────────────────── ──────────────────── │
│  Corrective      Arreglar defectos             "Fix: login falla    │
│                                                 con email largo"    │
│                                                                      │
│  Adaptive        Adaptarse a cambios externos  "Migrar de Node 18  │
│                                                 a Node 22"         │
│                                                                      │
│  Perfective      Mejorar funcionalidad          "Agregar filtro por │
│                                                 fecha a tareas"    │
│                                                                      │
│  Preventive      Prevenir problemas futuros    "Agregar rate        │
│                                                 limiting a API"    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4 modos de cascada

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Modo          Comportamiento                                        │
│  ────────────  ─────────────────────────────────────────────────── │
│  manual        Actualiza pipeline-state.json, imprime comandos      │
│  (default)     recomendados para que TU los ejecutes                │
│                                                                      │
│  auto          Ejecuta automaticamente la cascada completa:          │
│                spec-auditor → test-planner → plan-architect →       │
│                task-generator → task-implementer                    │
│                                                                      │
│  dry-run       Muestra que SE HARIA sin ejecutar nada               │
│                (preview del impacto)                                 │
│                                                                      │
│  plan-only     Cascada hasta planificacion, se detiene antes        │
│                de implementar (util para revisar plan primero)      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Opciones de invocacion

```
# Cambio interactivo (te pregunta todo)
/sdd-req-change

# Cambio desde archivo estructurado
/sdd-req-change --file changes/CHANGE-REQUEST.md

# Solo planificar, no ejecutar
/sdd-req-change --dry-run

# Auto-aplicar todos los cambios sin confirmacion
/sdd-req-change --batch

# Pre-clasificar tipo de mantenimiento
/sdd-req-change --maintenance=corrective

# Controlar cascada
/sdd-req-change --cascade=auto
/sdd-req-change --cascade=manual
/sdd-req-change --cascade=dry-run
/sdd-req-change --cascade=plan-only
```

### Proceso completo (10 fases)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Fase 0:  Inventario, contexto y rama change/{CHG-ID}-{slug}         │
│  Fase 1:  Recepcion del cambio + clasificacion ISO 14764            │
│  Fase 2:  Analisis de impacto                                        │
│           ├── Impacto directo e indirecto                            │
│           ├── Conflictos detectados                                  │
│           ├── Codigo afectado (sdd trace req <ID>)                   │
│           └── Riesgo de regresion                                    │
│  Fase 3:  Clarificacion (7 propiedades SWEBOK)                      │
│           └── Genera EARS + criterios de aceptacion                 │
│  Fase 4:  Plan de cambio (antes/despues por artefacto)              │
│  Fase 5:  Revision y aprobacion del usuario                         │
│  Fase 6:  Ejecucion atomica (1 commit docs(specs) por CR,           │
│           con --trailer "Change: CHG-..." y --trailer "Refs: ...")    │
│  Fase 7:  Auditoria focalizada (8 checks)                           │
│  Fase 8:  Generacion del Change Report                               │
│  Fase 9:  Cascada del pipeline                                       │
│                                                                      │
│  Ejemplo de analisis de impacto (Fase 2):                            │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │                                                          │        │
│  │  Cambio: Agregar prioridad a tareas                      │        │
│  │                                                          │        │
│  │  Artefactos afectados: 8                                 │        │
│  │  ├── REQUIREMENTS.md      (MODIFY REQ-F-001)            │        │
│  │  ├── DOMAIN-MODEL.md      (ADD priority to Task)        │        │
│  │  ├── USE-CASES.md         (MODIFY UC-TASK-001)          │        │
│  │  ├── API-CONTRACTS.md     (MODIFY POST /tasks)          │        │
│  │  ├── WORKFLOWS.md         (MODIFY WF-TASK-CREATE)       │        │
│  │  ├── TEST-MATRIX-TASK.md  (ADD priority tests)          │        │
│  │  ├── TASK-FASE-02.md      (ADD new task)                │        │
│  │  └── TASK-FASE-03.md      (MODIFY existing task)        │        │
│  │                                                          │        │
│  │  Riesgo de regresion: MEDIO                              │        │
│  │  Codigo afectado: src/domain/task.ts, src/api/tasks.ts  │        │
│  │                                                          │        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

Un MODIFY escribe `Needs:`/`Verification:`, reabre la aceptacion del requisito (las decisiones de
`acceptance/decisions.jsonl` estan atadas al hash de su texto) y pide una nueva aprobacion `requirements-v{N}`.

### Ciclo de vida de un Change Request

```
  DRAFT → REVIEWED → APPROVED → APPLIED → ARCHIVED
```

### Archivos generados

```
changes/
├── CR-001-add-task-priority.md                   ← Delta proposal
├── CHANGE-PLAN-CHG-2026-03-15-001.md             ← Plan detallado antes/despues
├── CHANGE-REPORT-CHG-2026-03-15-001.md           ← Reporte completo
└── CASCADE-REPORT-CHG-2026-03-15-001.md          ← Resultado de la cascada (si auto/plan-only)
```

---

## 10. Importar documentacion externa

> Cubierto en detalle en la Seccion 4.2 de esta guia.
> Resumen rapido de comandos:

```
/sdd-import docs/api.yaml                          # OpenAPI → SDD
/sdd-import exports/jira.csv --format=jira          # Jira → SDD
/sdd-import docs/README.md                          # Markdown → SDD
/sdd-import exports/notion/ --format=notion          # Notion → SDD
/sdd-import data/requirements.csv                    # CSV → SDD
/sdd-import data/specs.xlsx                          # Excel → SDD
/sdd-import docs/a.yaml docs/b.csv --merge          # Multiples + merge
```

---

## 11. Reconciliar specs con codigo

> Cubierto en detalle en la Seccion 4.3 de esta guia.
> Resumen rapido:

```
/sdd-reconcile                  # Completo con auto-resolve + preguntas
/sdd-reconcile --dry-run        # Solo detectar divergencias
/sdd-reconcile --code-wins      # Resolver todo a favor del codigo
/sdd-reconcile --scope=src/api  # Solo cierto scope
```

---

## 12. Herramientas de utilidad

### 12.1 Estado del pipeline

```
/sdd-pipeline-status
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Pipeline Status                                                     │
│                                                                      │
│  Etapa                     Estado    Desde          Nota              │
│  ────────────────────────  ────────  ────────────── ──────────────── │
│  requirements-engineer     ✅ done   2026-03-02     12 reqs          │
│  specifications-engineer   ✅ done   2026-03-02     6 docs, 3 ADRs  │
│  spec-auditor              ✅ done   2026-03-03     5 findings (0 P0)│
│  test-planner              ✅ done   2026-03-03     36 tests planned │
│  plan-architect            ✅ done   2026-03-04     4 fases          │
│  task-generator            ⚠️ stale  2026-03-04     spec/ cambio    │
│  task-implementer          ⏳ pending ──             ──               │
│                                                                      │
│  Laterales:                                                          │
│  tech-designer             ✅ done   2026-03-03                      │
│  ux-designer               ✅ done   2026-03-03                      │
│  security-auditor          ✅ done   2026-03-04     Score: 74/100   │
│                                                                      │
│  Siguiente accion recomendada:                                       │
│  → Re-ejecutar /sdd-task-generator (spec/ cambio despues del plan)  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.2 Integridad de la cadena de trazabilidad

La antigua `sdd-traceability-check` forma parte de `sdd-acceptance`:

```
/sdd-acceptance --check
```

Ademas del veredicto por requisito (Seccion 13), el paso de integridad de cadena informa de referencias rotas (un ID
citado y nunca definido), definiciones huerfanas, requisitos que no llegan a ningun caso de uso o escenario, tareas
marcadas como hechas sin commit y commits cuyo `Refs:` cita IDs inexistentes. Usa
`dashboard/traceability-graph.json` (lo construye `scripts/sdd-graph.py` cuando hay python3) y, para la parte de git,
`sdd tasks status` y `sdd trace`. Estos hallazgos son defectos a corregir en su origen; nunca cambian un veredicto.

### 12.3 De una linea de codigo a su requisito

La antigua `sdd-code-index` (puente con GitNexus) ya no existe. La pregunta "¿por que existe esta linea?" la responde
git: blame → commit → trailers → IDs.

```bash
node scripts/sdd.mjs trace why src/tasks.ts:42     # Task/Refs/Change del commit que escribio esa linea
node scripts/sdd.mjs trace req REQ-F-004           # commits cuyo Task/Refs/Change contiene ese ID exacto
```

### 12.4 Resumen de sesion

```
/sdd-session-summary
```

Resume decisiones de la sesion y separa contexto formal del informal.

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Session Summary — 2026-03-09                                        │
│                                                                      │
│  Progreso del pipeline:                                              │
│  │ Etapa                  │ Antes    │ Despues  │ Cambio             │
│  │────────────────────────│──────────│──────────│───────────────────│
│  │ spec-auditor           │ pending  │ done     │ 5 findings fixed  │
│  │ test-planner           │ pending  │ done     │ 36 tests planned  │
│                                                                      │
│  Decisiones formales (en artefactos):                                │
│  ✅ ADR-003: Elegido PostgreSQL sobre MongoDB (ADR escrito)         │
│  ✅ INV-007: Agregado invariante de longitud email                  │
│                                                                      │
│  Contexto informal (NO en artefactos):                               │
│  📝 Preferencia: "Usar Tailwind CSS" (sin ADR aun)                 │
│  📝 Aplazado: "Decidir proveedor de email en Sprint 2"             │
│  📝 Stakeholder: "PM dijo que prioridad de filtros es P2"          │
│                                                                      │
│  Decisiones NO formalizadas (deberian estar en artefactos):         │
│  ⚠️ Se discutio usar Redis para cache pero no hay ADR              │
│  ⚠️ Se acordo rate limiting de 100 req/min sin NFR formal          │
│                                                                      │
│  Preguntas abiertas:                                                │
│  ❓ ¿Notificaciones push en MVP o Sprint 2?                        │
│  ❓ ¿Soporte para internacionalizacion?                             │
│                                                                      │
│  Proximos pasos recomendados:                                        │
│  1. Formalizar decision de Redis en ADR-004                         │
│  2. Agregar NFR para rate limiting                                   │
│  3. Ejecutar /sdd-plan-architect                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Categorias de decision:**

```
┌──────────────────────────────────────────────────────────────┐
│  Tipo de decision          Donde pertenece        Accion     │
│  ────────────────────────  ──────────────────── ──────────── │
│  Decision de arquitectura  spec/adr/ADR-NNN.md   Flag si no  │
│                                                   hay ADR    │
│  Cambio de requisito       requirements/          Flag si no │
│                             REQUIREMENTS.md       formalizado│
│  Clarificacion de spec     spec/*.md relevante    Flag si no │
│                                                   aplicado   │
│  Preferencia de impl.      Memoria del proyecto   Recordar   │
│  Decision aplazada         Memoria con DEFERRED   Recordar   │
│  Input de stakeholder      Memoria con fuente     Recordar   │
└──────────────────────────────────────────────────────────────┘
```

---

## 13. Aceptacion por requisito y git

La pregunta que el resto del pipeline no responde: **¿esta satisfecho cada requisito, y con que evidencia?** La
responde la skill `sdd-acceptance` sobre la CLI `scripts/sdd.mjs` (Node, sin dependencias; en CI basta con Node y git,
usando el validador copiado en `.claude/sdd/sdd.mjs`).

### 13.1 Modos de la skill

```
/sdd-acceptance --check                 # captura tests (JUnit), libro de aceptacion + informe, integridad de cadena
/sdd-acceptance --fase N                # lo mismo, limitado a los Requisitos de la FASE N
/sdd-acceptance --loop [--max-cycles 3] # bucle hasta que todo Must este VERIFIED o WAIVED
/sdd-acceptance --sign-off [--fase N | --release NAME]   # puerta + aceptacion humana + tag
/sdd-acceptance --publish [--fase N]    # bloque para PR/issue y, opcional, pagina de estado
```

Los resultados de tests salen del comando `test_report` del Stack Profile, que escribe JUnit XML (por defecto en
`.sdd/junit/`). El nombre de cada test lleva el ID del escenario (`AC-NNN-NN`).

### 13.2 Veredictos

| Veredicto | Regla |
|---|---|
| VERIFIED | Cada criterio tiene evidencia valida y fresca segun su metodo; el informe dice cuantos ("3/5") |
| FAILING | Alguna evidencia falla |
| MISSING | Algun criterio sin evidencia (sin implementar, sin test o test sin el ID en su nombre) |
| WAIVED | Exencion humana vigente para el texto actual del requisito; un Must exento exige motivo, rol e issue de seguimiento |

Los requisitos deprecados se listan aparte y nunca bloquean. La evidencia depende del `Verification:` del requisito:
`test` (test JUnit que pasa), `demo` (salida observada que una persona confirma), `measurement` (valor registrado que
la CLI compara con su umbral) e `inspection` (revision humana registrada). Los registros humanos se hacen con
`sdd accept record <waiver|demo|measurement|inspection|fase-acceptance> --by NOMBRE --role ROL …` y viven en
`acceptance/decisions.jsonl`, atados al hash del texto del requisito: un MODIFY con `sdd-req-change` los reabre.

Salidas: `.sdd/acceptance.json` (ignorado por git; lo leen `sdd-pipeline-status`, el hook de sesion y el servidor MCP)
y `acceptance/ACCEPTANCE-REPORT.md`, legible por el cliente, con el SHA evaluado. El upstream guard deniega editar a
mano `decisions.jsonl` y el informe; el tool guard pide confirmacion antes de `sdd accept record` y de los tags
`fase-N-accepted` y `requirements-vN`. Evita la auto-aprobacion accidental; no es una garantia.

### 13.3 Puerta y bucle

```bash
node scripts/sdd.mjs gate [--mode off|warn|enforce] [--fase N] [--md]
```

| Salida | Significado |
|---|---|
| 0 | Objetivo cumplido: todo Must VERIFIED o WAIVED |
| 1 | Objetivo no cumplido |
| 2 | Evidencia obsoleta (o error de uso) |
| 3 | Objetivo cumplido con Musts exentos |

`warn` imprime y sale con 0; `off` sale con 0 en silencio. El modo por defecto es `acceptance_gate` del Stack Profile
(o `enforce`); en proyectos brownfield conviene `warn`. `--md` imprime el bloque para el cuerpo de un PR.

`sdd loop next` da un paso del bucle de `--loop` como JSON: ciclo, progreso, objetivos con su `route_hint` y la
condicion de parada, que decide el codigo: `goal`, `regression`, `no-progress`, `max-cycles` (3 por defecto, tope 5)
o `needs-human`. Enrutado: lo que falta va a tareas incrementales; un test que falla se arregla en el codigo, nunca
en el test (Art. 12); una spec dudosa va a una persona y a `/sdd-req-change`. Todo test modificado dentro del bucle se
lista y lo aprueba una persona. Jev (`test-adequacy`, `evidence`) es solo informativo y nunca decide un veredicto.

### 13.4 Git como evidencia

```bash
node scripts/sdd.mjs trace commits [--files] [--json]   # commits con sus IDs Task/Refs/Change (reverts marcados)
node scripts/sdd.mjs trace req REQ-F-004                # commits de un ID (REQ-F-01 no casa con REQ-F-012)
node scripts/sdd.mjs trace why src/tasks.ts:42          # blame → commit → trailers
node scripts/sdd.mjs trace delivered REQ-F-004          # tags y ramas que contienen ese trabajo
node scripts/sdd.mjs verify --range main..HEAD          # valida cada commit y detecta squash
node scripts/sdd.mjs branch status                      # rama actual, rama por defecto, HEAD suelto
```

Tags anotados (firmados si hay clave): `requirements-v{N}` (aprobacion de requisitos), `fase-{N}-accepted`
(aceptacion del cliente) y, con Streams, `fase-N-foundation` y `fase-N-verified`. Para una regresion,
`git bisect run <comando de test>`. No se usan `git notes`: no se sincronizan por defecto y GitHub no las muestra.

### 13.5 Pagina de estado y grafo

- `sdd-acceptance --publish` puede publicar una pagina de estado como Claude Artifact (pregunta antes, porque saca
  titulos de requisitos de la maquina). Sin la herramienta Artifact (por ejemplo `claude -p`), la vista compartible es
  `acceptance/ACCEPTANCE-REPORT.md`. Sustituye al antiguo dashboard HTML.
- `scripts/sdd-graph.py` sigue construyendo `dashboard/traceability-graph.json` para el servidor MCP y los hooks (sin
  pagina HTML).
- La observacion en vivo (status lines, `sdd-watch`, log de actividad) ya no forma parte del plugin; ver
  [multisesion.md](multisesion.md#ver-qué-está-pasando).

---

## 14. Servidor MCP (consultas de trazabilidad)

El servidor MCP permite hacer consultas en tiempo real sobre la trazabilidad
del proyecto. Se activa automaticamente si el plugin esta instalado.

### 6 herramientas de consulta

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Herramienta    Descripcion                        Uso                      │
│  ────────────── ─────────────────────────────────  ──────────────────────── │
│  sdd_query      Buscar artefactos por texto, ID,   "¿Que artefactos        │
│                 tipo o dominio. Retorna con         mencionan autenticacion?"│
│                 scores de relevancia.                                        │
│                 Filtros: REQ, UC, WF, API, BDD,                             │
│                 INV, ADR, NFR, RN, FASE, TASK                               │
│                                                                              │
│  sdd_impact     Analisis de blast radius via BFS.   "Si cambio REQ-001,    │
│                 Upstream y downstream.               que se afecta?"         │
│                 Depth 1: WILL_BREAK                                         │
│                 Depth 2: LIKELY_AFFECTED                                    │
│                 Depth 3: MAY_NEED_REVIEW                                    │
│                                                                              │
│  sdd_context    Vista 360° de un artefacto.         "Dame todo sobre       │
│                 Definicion, upstream, downstream,    UC-TASK-001"            │
│                 code refs, test refs, commit refs,                           │
│                 coverage gaps.                                               │
│                                                                              │
│  sdd_coverage   Con .sdd/acceptance.json: veredicto  "¿Estan verificados   │
│                 por requisito y si todo Must esta     todos los Must?"       │
│                 verificado. Sin el: gaps de links.                          │
│                                                                              │
│  sdd_trace      Cadena de trazabilidad completa:    "Traza REQ-NF-002      │
│                 REQ → UC → WF → API → BDD → INV     de punta a punta"      │
│                 → ADR → TASK → COMMIT → CODE → TEST                        │
│                 Detecta rupturas en la cadena.                               │
│                                                                              │
│  sdd_gaps       Hallazgos de sdd-gap-detector.      "¿Que endpoints faltan?"│
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7 recursos MCP

```
sdd://pipeline/status         ← Estado actual del pipeline
sdd://pipeline/stages         ← Detalle por etapa
sdd://graph/schema            ← Schema del grafo de trazabilidad
sdd://graph/stats             ← Estadisticas del grafo
sdd://coverage/gaps           ← Gaps de cobertura
sdd://artifacts/{type}        ← Artefactos por tipo
sdd://artifacts/{type}/{id}   ← Detalle de un artefacto
```

### 2 prompts de workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  analyze_impact                                                      │
│  Pre-cambio: contexto + blast radius + integridad de cadena         │
│  + recomendacion de cascada                                         │
│                                                                      │
│  generate_status_report                                              │
│  Salud del pipeline: estado + cobertura + acciones prioritarias     │
│  + evaluacion general                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 15. Automatizacion: hooks

Los hooks corren desde el plugin (`${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json`); `/sdd-setup` no los copia al proyecto.
Todos salen en silencio en un repositorio sin `pipeline-state.json` ni `.sdd/`.

5 hooks, 7 registros de evento:

| Hook | Script | Evento | Que hace |
|------|--------|--------|----------|
| H1 | `sdd-session-start.sh` | SessionStart (startup, resume, compact) | Inyecta el estado del pipeline (`N/7` sobre las 7 etapas ordenadas) y el resumen de aceptacion; callado en proyectos sin SDD |
| H2 | `sdd-upstream-guard.sh` | PreToolUse (Edit, Write) | Bloquea que una skill downstream modifique artefactos upstream (Art. 4); deniega editar a mano `acceptance/decisions.jsonl` y el informe |
| H3 | `sdd-pipeline-state-updater.sh` | PreToolUse (Skill), UserPromptExpansion, PostToolUse (Write) — todos async | Marca `running` la etapa cuando arranca su skill o se escribe un fichero bajo su directorio; no crea el fichero (eso es de `/sdd-setup`) |
| H5 | `sdd-augment-hook.js` | PreToolUse (Read, Edit, Write) | Enriquece el contexto con datos de trazabilidad del grafo |
| H12 | `sdd-tool-guard.sh` | PreToolUse (Bash) | Deniega asignar variables de consentimiento humano para acciones de IA; pide confirmacion (`ask`) antes de `sdd accept record` y de los tags `fase-N-accepted` / `requirements-vN` |

Las skills que cambian el estado de una etapa usan `scripts/sdd-state.sh set <etapa> <estado>`, que escribe bajo el
mismo lock que los hooks.

**Hook git `commit-msg`** (lo instala `/sdd-setup`, que copia el validador a `.claude/sdd/sdd.mjs`): aplica las mismas
reglas que `sdd verify`. `Task:` en `feat|test|refactor`, `Task:` o `Change:` en `fix|perf`, `Refs:` en
`docs(specs)`, IDs bien formados y ninguna linea de trailer fuera del bloque. Deja pasar el resto de `docs`, `chore`,
`ci`, `style`, `build`, merges, `Revert "..."` y los `fixup!`/`squash!`/`amend!`. Sin node, usa el mismo criterio en
bash sobre `git interpret-trailers`.

**Quality gates opcionales** (`/sdd-setup` los ofrece): H7 Stop Quality Gate (prompt hook que revisa la
consistencia de `pipeline-state.json` al cerrar) y H8 Task Traceability Gate (agent hook en `TaskCompleted` que
verifica los trailers del ultimo commit).

**Hooks a nivel de skill**: `sdd-spec-auditor` (Stop: hallazgos P0/P1 tratados) y `sdd-acceptance` (Stop: si el
bucle no alcanzo el objetivo, cada Must abierto tiene una decision humana o queda pendiente).

**Agentes**: el plugin no distribuye agentes. `sdd-orchestrator` es una skill; `sdd-cross-auditor` y
`sdd-pipeline-auditor` son herramientas de mantenimiento del propio repositorio (`.claude/agents/`).

---

## 16. La Constitucion SDD (12 articulos)

Definida en `references/sdd-constitution.md`; las skills la citan en sus puertas de calidad.

| Art. | Nombre | Regla |
|------|--------|-------|
| 1 | Spec es fuente de verdad | Plan, tasks, codigo y tests se derivan de la spec y se ajustan a ella |
| 2 | Nunca asumir, preguntar | Las ambiguedades se preguntan con opciones estructuradas |
| 3 | Trazabilidad innegociable | Cada artefacto traza a su origen (REQ ↔ UC ↔ WF ↔ API ↔ BDD ↔ INV ↔ ADR); un huerfano es un defecto |
| 4 | Inmutabilidad upstream | Una skill downstream no modifica artefactos upstream (H2 lo aplica) |
| 5 | Calidad lista para implementar | Una spec debe poder implementarse sin mas aclaraciones; calificativos vagos ("rapido") son defectos |
| 6 | Auditoria con baseline | La primera auditoria crea baseline; las siguientes reportan nuevos y regresiones |
| 7 | Una task, un commit atomico | Conventional Commits con trailers `Task:`/`Refs:` (via `git commit --trailer`) y estrategia de revert |
| 8 | Construccion test-first | El test se escribe antes que el codigo |
| 9 | Bucles de feedback estructurados | La retroalimentacion va a `feedback/IMPL-FEEDBACK-FASE-N.md` |
| 10 | Operacion consciente del contexto | Leer decisiones existentes (ADRs, CLARIFICATIONS, CLAUDE.md, baselines) antes de preguntar o proponer |
| 11 | Iterativo sobre cascada | Si la entrada es deficiente, parar y recomendar la skill upstream en vez de producir sobre una base rota |
| 12 | Primacia de la especificacion | Los tests verifican la spec, no el codigo; una spec dudosa se reporta como entrada `SPEC-DEVIATION` en `feedback/IMPL-FEEDBACK-FASE-N.md` y decide un humano |

---

## 17. Notion

No hay skill de sincronizacion con Notion. Para traer un export de Notion al pipeline:

```
/sdd-import exports/notion/ --format=notion --target=requirements
```

---

## 18. Ejemplo completo: proyecto brownfield con todas las opciones

Vamos a recorrer un escenario realista donde usamos TODAS las herramientas.

### Contexto

Tienes un proyecto existente: una API de e-commerce en Node.js/TypeScript.
Tiene codigo, algunos tests, un README, y exports de Jira. No tiene
especificaciones formales.

### Fase 0: Setup y diagnostico

```bash
cd ecommerce-api
claude
```

```
# Inicializar SDD (con hooks opcionales)
/sdd-setup

# Diagnosticar el proyecto
/sdd-pipeline-status --diagnose
```

Resultado: **Brownfield con docs** (regla 6: codigo + docs importables).

Plan recomendado:
1. `/sdd-import` (Jira + OpenAPI)
2. `/sdd-reverse-engineer`
3. `/sdd-reconcile`
4. Pipeline normal desde spec-auditor

### Fase 1: Importar docs existentes

```
# Importar el export de Jira
/sdd-import exports/jira-2026-03.csv --format=jira --target=requirements

# Importar la spec OpenAPI
/sdd-import docs/openapi.yaml --target=specs --merge
```

### Fase 2: Reverse engineer el codigo

```
/sdd-reverse-engineer --scope=src/
```

Al llegar al Checkpoint 1, revisas el inventario y continuas.
Al Checkpoint 2, revisas las specs generadas y continuas.

### Fase 3: Reconciliar

```
/sdd-reconcile
```

Detecta 12 divergencias:
- 5 NEW_FUNCTIONALITY (auto-resueltas)
- 3 REMOVED_FEATURE (auto-resueltas)
- 2 BEHAVIORAL_CHANGE (decides tu)
- 1 BUG_OR_DEFECT (decides tu)
- 1 AMBIGUOUS (decides tu)

### Fase 4: Auditoria y correccion

```
# Auditar specs
/sdd-spec-auditor

# Corregir (modo Fix)
/sdd-spec-auditor
# → Selecciona "Fix"
```

### Fase 5: Diseno tecnico y UX

```
# Explorar/documentar stack actual
/sdd-tech-designer --update

# Definir sistema de diseno
/sdd-ux-designer
```

### Fase 6: Auditoria de seguridad

```
/sdd-security-auditor
```

Score: 52/100 (C). 8 hallazgos, 2 criticos.

### Fase 7: Plan de pruebas y arquitectura

```
/sdd-test-planner
/sdd-plan-architect
```

### Fase 8: Tareas e implementacion

```
/sdd-task-generator
/sdd-task-implementer --fase 0      # en la rama fase-0-<slug>; demo al final de la FASE
# Puerta de FASE: el cliente acepta el incremento → /sdd-acceptance --sign-off --fase 0
```

### Fase 9: Post-implementacion

```
# Veredicto por requisito e integridad de cadena (en brownfield: acceptance_gate: warn)
/sdd-acceptance --check

# Bucle hasta que todo Must este VERIFIED o WAIVED
/sdd-acceptance --loop

# Bloque para el PR y pagina de estado opcional
/sdd-acceptance --publish

# Ver estado final
/sdd-pipeline-status

# Resumir sesion
/sdd-session-summary
```

### Fase 10: Sprint 2 — Nuevo requisito

```
# Agregar funcionalidad de "wishlist"
/sdd-req-change --cascade=auto

# Verificar resultado
/sdd-pipeline-status
/sdd-acceptance --check
```

### Fase 11: Sprint 3 — Detectar drift

```
# Alguien hizo cambios directos al codigo...
/sdd-reconcile --dry-run     # Ver que cambio
/sdd-reconcile               # Reconciliar
```

### Estructura final del proyecto

```
ecommerce-api/
├── pipeline-state.json
│
├── import/
│   └── IMPORT-REPORT.md              ← Reporte de importacion
│
├── reverse-engineering/
│   ├── INVENTORY.md                   ← Inventario del codebase
│   ├── ANALYSIS.md                    ← Analisis profundo
│   └── TEST-ANALYSIS.md              ← Analisis de tests
│
├── findings/
│   └── FINDINGS-REPORT.md            ← Dead code, tech debt
│
├── reconciliation/
│   └── RECONCILIATION-REPORT.md      ← Divergencias resueltas
│
├── requirements/
│   ├── CUSTOMER-NEEDS.md             ← Necesidades del cliente (N-NNN)
│   └── REQUIREMENTS.md               ← Requisitos formales (EARS)
│
├── spec/
│   ├── domain/  use-cases/  workflows/  contracts/
│   ├── tests/BDD-UC-*.md             ← Escenarios AC-NNN-NN
│   ├── nfr/
│   └── adr/ADR-*.md
│
├── audits/
│   ├── AUDIT-BASELINE.md             ← Auditoria de specs
│   └── SECURITY-AUDIT-BASELINE.md    ← Auditoria de seguridad
│
├── design/
│   ├── TECHNICAL-DESIGN.md           ← 12 dimensiones tecnicas
│   ├── QUALITY-ATTRIBUTES.md         ← Trade-offs ATAM-lite
│   └── ADR-DRAFT-*.md
│
├── ux/
│   ├── UI-DESIGN-SYSTEM.md           ← 12 dimensiones UX
│   ├── WIREFRAMES.md
│   ├── ACCESSIBILITY-SPEC.md
│   ├── INTERACTION-MODEL.md
│   └── DESIGN-TOKENS.json
│
├── test/
│   ├── TEST-PLAN.md
│   ├── TEST-MATRIX-*.md
│   └── PERF-SCENARIOS.md
│
├── plan/
│   ├── PLAN.md                        ← Plan-Style: vertical
│   ├── ARCHITECTURE.md
│   ├── fases/FASE-*.md                ← FASE-0-SKELETON, incrementos
│   └── fase-plans/PLAN-FASE-*.md
│
├── task/
│   ├── TASK-FASE-*.md
│   ├── TASK-INDEX.md
│   └── TASK-ORDER.md
│
├── changes/
│   ├── CR-001-add-wishlist.md         ← Change request
│   ├── CHANGE-PLAN-CHG-2026-04-02-001.md
│   ├── CHANGE-REPORT-CHG-2026-04-02-001.md
│   └── CASCADE-REPORT-CHG-2026-04-02-001.md
│
├── acceptance/
│   ├── ACCEPTANCE-REPORT.md           ← Veredicto por requisito (SHA evaluado)
│   └── decisions.jsonl                ← Exenciones, demos, mediciones, aceptaciones
│
├── dashboard/
│   └── traceability-graph.json        ← Grafo para MCP y hooks (sdd-graph.py)
│
├── src/                               ← Codigo implementado
├── tests/                             ← Tests automatizados
└── package.json
```

---

## 19. Referencia rapida de todos los comandos

```
┌──────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  SETUP                                                                    │
│  /sdd-setup                              Inicializar proyecto            │
│                                                                           │
│  DIAGNOSTICO                                                              │
│  /sdd-pipeline-status --diagnose         Diagnostico y plan de adopcion  │
│                                                                           │
│  BROWNFIELD                                                               │
│  /sdd-reverse-engineer                   Codigo → artefactos SDD        │
│  /sdd-reverse-engineer --scope=PATH      Scope limitado                  │
│  /sdd-reverse-engineer --inventory-only  Solo escaneo                    │
│  /sdd-reverse-engineer --findings-only   Solo hallazgos                  │
│  /sdd-reverse-engineer --continue        Reanudar checkpoint            │
│  /sdd-import FILE                        Importar doc externo           │
│  /sdd-import FILE --format=FORMAT        Formato explicito              │
│  /sdd-import FILE --target=TARGET        Solo reqs/specs/both           │
│  /sdd-import FILE --merge                Merge con existentes           │
│  /sdd-reconcile                          Reconciliar spec ↔ codigo     │
│  /sdd-reconcile --dry-run                Solo detectar                   │
│  /sdd-reconcile --code-wins              Codigo siempre gana            │
│  /sdd-reconcile --scope=PATH             Scope limitado                  │
│                                                                           │
│  PIPELINE (en orden)                                                      │
│  /sdd-requirements-engineer              Requisitos formales             │
│  /sdd-specifications-engineer            Especificaciones tecnicas      │
│  /sdd-spec-auditor                       Auditar/corregir specs         │
│  /sdd-test-planner                       Plan de pruebas                 │
│  /sdd-plan-architect                     Arquitectura + fases            │
│  /sdd-task-generator                     Tareas atomicas                 │
│  /sdd-task-implementer --fase N          Implementar con TDD + demo      │
│                                                                           │
│  LATERALES (cualquier momento)                                            │
│  /sdd-tech-designer                      12 dims tecnicas               │
│  /sdd-tech-designer --dimensions=N,N     Dims especificas               │
│  /sdd-tech-designer --update             Actualizar existente           │
│  /sdd-tech-designer --quality-only       Solo ATAM-lite                 │
│  /sdd-ux-designer                        12 dims UX                     │
│  /sdd-ux-designer --dimensions=LIST      Dims especificas               │
│  /sdd-ux-designer --update               Actualizar existente           │
│  /sdd-ux-designer --wireframes-only      Solo wireframes                │
│  /sdd-security-auditor                   10 dims seguridad (OWASP)     │
│  /sdd-req-change                         Gestion de cambios             │
│  /sdd-req-change --cascade=MODE          auto/manual/dry-run/plan-only │
│  /sdd-req-change --dry-run               Solo planificar                │
│  /sdd-req-change --batch                 Auto-aplicar todo              │
│  /sdd-req-change --file=PATH             Desde archivo CR               │
│  /sdd-req-change --maintenance=TYPE      Pre-clasificar ISO 14764      │
│                                                                           │
│  UTILIDADES                                                               │
│  /sdd-pipeline-status                    Estado del pipeline             │
│  /sdd-acceptance --check                 Veredictos + integridad cadena │
│  /sdd-acceptance --loop                  Bucle hasta objetivo            │
│  /sdd-acceptance --sign-off --fase N     Aceptacion + fase-N-accepted    │
│  /sdd-acceptance --publish               Bloque PR + pagina de estado    │
│  /sdd-session-summary                    Resumen de sesion               │
│  /sdd-gap-detector                       Gaps spec ↔ codigo             │
│  /sdd-gap-detector --semantic            + cobertura por requisito       │
│                                                                           │
│  CONDUCCION                                                               │
│  /sdd-orchestrator                       Pipeline completo guiado        │
│  /sdd-lead                               Sesion lead multisesion         │
│                                                                           │
│  CLI (node scripts/sdd.mjs; en CI node .claude/sdd/sdd.mjs)               │
│  lint [--needs | --plan]                 Tareas, necesidades, plan       │
│  trace commits|req|why|delivered         Trazabilidad por git            │
│  verify --message F | --range A..B       Reglas de commit (commit-msg)  │
│  branch start|status                     Rama de trabajo por defecto    │
│  accept [record ...]                     Libro de aceptacion             │
│  gate [--mode off|warn|enforce] [--md]   Puerta: exit 0/1/2/3            │
│  loop next                               Un paso del bucle               │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 20. Glosario extendido

| Termino | Significado |
|---------|-------------|
| **Pipeline** | Secuencia de 7 pasos (REQ → IMPL) |
| **FASE** | Incremento vertical: un recorrido de usuario con su demo (FASE-0 = esqueleto) |
| **Necesidad (N-NNN)** | Palabras literales del cliente en `CUSTOMER-NEEDS.md`; cada requisito cita las suyas |
| **Veredicto** | VERIFIED / FAILING / MISSING / WAIVED por requisito, calculado por `sdd accept` |
| **Trailer** | Linea `Task:` / `Refs:` / `Change:` del bloque final de un commit, escrita con `git commit --trailer` |
| **EARS** | Formato de requisitos: WHEN/THE/SHALL |
| **BDD** | Escenarios Given/When/Then |
| **ADR** | Architecture Decision Record |
| **INV** | Invariante (regla que siempre se cumple) |
| **Stale** | Artefacto cuyos inputs cambiaron |
| **Cascade** | Propagacion automatica de cambios por el pipeline |
| **Traceability** | Conexion verificable entre artefactos |
| **TDD** | Test-Driven Development (test primero, codigo despues) |
| **C4 Model** | Diagramas de arquitectura en 4 niveles de zoom |
| **SWEBOK** | Software Engineering Body of Knowledge (v4) |
| **OWASP ASVS** | Application Security Verification Standard v4 |
| **CWE** | Common Weakness Enumeration |
| **ISO 14764** | Estandar de clasificacion de mantenimiento |
| **MCP** | Model Context Protocol (consultas de trazabilidad) |
| **Design Tokens** | Variables de diseno exportables (colores, spacing, etc.) |
| **WCAG** | Web Content Accessibility Guidelines (2.2 AA) |
| **Blast Radius** | Conjunto de artefactos/codigo afectados por un cambio |
| **ATAM-lite** | Architecture Tradeoff Analysis Method simplificado |
| **Atomic Design** | Metodologia UI: atoms → molecules → organisms → templates → pages |
| **Baseline** | Primera auditoria; las siguientes solo reportan deltas |
| **Checkpoint** | Punto de pausa en reverse-engineer para confirmacion |
| **Divergence** | Diferencia detectada entre spec y codigo (reconcile) |
| **CR** | Change Request (solicitud de cambio formal) |
| **Constitution** | 12 articulos que gobiernan el comportamiento de SDD (`references/sdd-constitution.md`) |
| **Upstream** | Artefactos que alimentan al actual (ej: requirements es upstream de spec) |
| **Downstream** | Artefactos que dependen del actual (ej: task es downstream de plan) |
| **Walking skeleton** | FASE-0: el camino minimo escribir → observar → persistir del caso de uso central |

---

> **SDD no es burocracia. Es la diferencia entre construir una casa con planos
> y construir una casa "a ojo".** Los planos toman tiempo, pero la casa no se cae.
>
> Esta guia cubre TODAS las opciones. No necesitas usarlas todas en cada proyecto.
> Usa `/sdd-pipeline-status --diagnose` para que el sistema te diga exactamente cuales necesitas.
