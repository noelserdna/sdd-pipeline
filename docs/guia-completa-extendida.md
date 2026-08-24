# Guia Completa Extendida: Todas las Opciones de SDD

> **La guia definitiva** — Cubre los 22 skills, 5 hooks, 3 agentes, servidor MCP,
> dashboard en vivo, y todos los escenarios posibles (greenfield, brownfield, drift, multi-equipo).

---

## Tabla de Contenidos

1. [Instalacion y setup completo](#1-instalacion-y-setup-completo)
2. [Diagnostico de proyecto (onboarding)](#2-diagnostico-de-proyecto-onboarding)
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
13. [Dashboard y servidor en vivo](#13-dashboard-y-servidor-en-vivo)
14. [Servidor MCP (consultas de trazabilidad)](#14-servidor-mcp-consultas-de-trazabilidad)
15. [Automatizacion: hooks y agentes](#15-automatizacion-hooks-y-agentes)
16. [La Constitucion SDD (11 articulos)](#16-la-constitucion-sdd-11-articulos)
17. [Sync con Notion](#17-sync-con-notion)
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
│  ✓ Git              (control de versiones)              │
│  ✓ Node.js 18+      (servidor MCP + dashboard)          │
│  ✓ jq               (procesamiento JSON en hooks)       │
│                                                          │
│  Opcional (desbloquea funcionalidades extra)             │
│                                                          │
│  ○ GitHub CLI (gh)   Para PRs automaticos               │
│  ○ GitNexus          Code intelligence profundo          │
│    npm i -g gitnexus   (call graph, clusters, flows)    │
│  ○ Notion API key    Sync bidireccional con Notion       │
│  ○ Python 3          Fast path del dashboard             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Paso 1: Instalar el plugin (global, una sola vez)

```bash
claude
```

```
/plugin marketplace add noelserdna/claude-plugin-sdd
/plugin install sdd@noelserdna-claude-plugin-sdd
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Que se instala globalmente:                                         │
│                                                                      │
│  22 skills como comandos /sdd:*                                      │
│  ├── 7 pipeline       (requirements → implementation)               │
│  ├── 4 laterales      (tech-designer, ux-designer, security, change)│
│  ├── 4 onboarding     (onboarding, reverse-engineer, reconcile,     │
│  │                      import)                                      │
│  ├── 6 utilidades     (status, traceability, dashboard, code-index, │
│  │                      session-summary, sync-notion)                │
│  └── 1 setup          (sdd:setup)                                   │
│                                                                      │
│  Automatizacion incluida:                                            │
│  ├── 5 hooks core     (H1-H5)                                       │
│  ├── 3 hooks opcionales (H6-H8)                                     │
│  ├── 3 agentes        (A1-A3)                                       │
│  └── Servidor MCP     (5 herramientas de consulta)                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Paso 2: Inicializar SDD en tu proyecto

```bash
cd mi-proyecto
claude
```

```
/sdd:setup
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Que hace /sdd:setup en tu proyecto:                                 │
│                                                                      │
│  Paso 1: Crea pipeline-state.json                                    │
│  ├── Todas las etapas en "pending"                                   │
│  ├── sddVersion y hooksVersion registradas                          │
│  └── Listo para rastrear progreso                                    │
│                                                                      │
│  Paso 2: Detecta upgrades                                            │
│  ├── Si tienes hooks v1 → migra automaticamente a v2                │
│  └── Preserva estado existente                                       │
│                                                                      │
│  Paso 3: Verifica dependencias                                       │
│  ├── jq instalado?                                                   │
│  ├── Node.js 18+?                                                    │
│  └── Compila servidor MCP si necesario                              │
│                                                                      │
│  Paso 4: Instala hooks opcionales (te pregunta)                      │
│  ├── H6: Dashboard HTTP hooks (POST a localhost:3001)               │
│  ├── H7: Stop Quality Gate (verifica pipeline al cerrar)            │
│  └── H8: Task Traceability Gate (verifica trailers en commits)      │
│                                                                      │
│  Paso 5: Genera reporte de verificacion                              │
│  ┌──────────────────────────────────────────────────┐               │
│  │  Componente              │ Estado                 │               │
│  │──────────────────────────│────────────────────────│               │
│  │  pipeline-state.json     │ ✅ Creado              │               │
│  │  Hook H1 (session-start) │ ✅ Activo              │               │
│  │  Hook H2 (upstream-guard)│ ✅ Activo              │               │
│  │  Hook H3 (state-updater) │ ✅ Activo              │               │
│  │  Hook H5 (context-augm.) │ ✅ Activo              │               │
│  │  Agente A1 (constitution)│ ✅ Registrado          │               │
│  │  Agente A2 (cross-audit) │ ✅ Registrado          │               │
│  │  Agente A3 (context)     │ ✅ Registrado          │               │
│  │  Servidor MCP            │ ✅ Compilado           │               │
│  │  Hook H6 (dashboard)     │ ⚪ No instalado (opt.) │               │
│  │  Hook H7 (quality gate)  │ ⚪ No instalado (opt.) │               │
│  │  Hook H8 (task gate)     │ ⚪ No instalado (opt.) │               │
│  └──────────────────────────────────────────────────┘               │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Gestion del plugin

```
/plugin                                                    # Gestor visual interactivo
/plugin disable sdd@noelserdna-claude-plugin-sdd          # Desactivar temporalmente
/plugin enable sdd@noelserdna-claude-plugin-sdd           # Reactivar
/plugin update sdd@noelserdna-claude-plugin-sdd           # Actualizar a nueva version
/plugin uninstall sdd@noelserdna-claude-plugin-sdd        # Desinstalar
```

---

## 2. Diagnostico de proyecto (onboarding)

Antes de hacer nada, diagnostica tu proyecto para saber por donde empezar.

### Ejecutar el diagnostico

```
/sdd:onboarding
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  El onboarding analiza tu proyecto en 7 fases:                       │
│                                                                      │
│  Fase 1: Entorno                                                     │
│  ├── Lenguajes detectados (TypeScript, Python, Go...)               │
│  ├── Frameworks (React, Express, Django...)                          │
│  ├── CI/CD (GitHub Actions, GitLab CI...)                            │
│  └── Historial git (commits, ramas, tags)                            │
│                                                                      │
│  Fase 2: Artefactos SDD existentes                                   │
│  ├── Busca requirements/, spec/, audits/, test/, plan/, task/       │
│  ├── Verifica pipeline-state.json                                    │
│  └── Detecta version de hooks (v1 vs v2)                            │
│                                                                      │
│  Fase 3: Documentacion no-SDD                                        │
│  ├── README, CONTRIBUTING, docs/                                     │
│  ├── OpenAPI/Swagger specs                                           │
│  ├── Exports de Jira, Notion                                         │
│  └── Diagramas de arquitectura                                       │
│                                                                      │
│  Fase 4: Analisis de codigo y tests                                  │
│  ├── Tamano del codebase (lineas, archivos, modulos)                │
│  ├── Capas arquitectonicas (domain, API, UI)                        │
│  ├── Patrones de diseno detectados                                   │
│  └── Cobertura de tests estimada                                     │
│                                                                      │
│  Fase 5: Clasificacion en 1 de 8 escenarios                         │
│  Fase 6: Puntuacion de salud (0-100 puntos)                         │
│  Fase 7: Plan de accion personalizado                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Los 8 escenarios posibles

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  #  Escenario              Senal clave              Accion recomendada      │
│  ── ───────────────────── ──────────────────────── ─────────────────────── │
│  1  Greenfield             Sin codigo, sin docs     Pipeline completo       │
│                                                      desde requirements      │
│                                                                              │
│  2  Brownfield bare        Codigo sin docs ni tests  /sdd:reverse-engineer  │
│                                                      completo               │
│                                                                              │
│  3  SDD drift              Artefactos SDD + codigo   /sdd:reconcile        │
│                             han divergido                                    │
│                                                                              │
│  4  Partial SDD            Algunos artefactos SDD,   Reanudar desde el     │
│                             pipeline incompleto       gap identificado       │
│                                                                              │
│  5  Brownfield con docs    Codigo + docs no-SDD      /sdd:import →         │
│                             (README, OpenAPI, etc.)   /sdd:reverse-engineer │
│                                                      → /sdd:reconcile      │
│                                                                              │
│  6  Tests-as-spec          Buena cobertura de tests,  /sdd:reverse-engineer│
│                             docs pobres/inexistentes  con estrategia        │
│                                                      test-first             │
│                                                                              │
│  7  Multi-equipo           Monorepo/microservicios,  Evaluacion por modulo │
│                             estados mixtos            + adopcion por fases  │
│                                                                              │
│  8  Fork/migracion         Fork de otro proyecto     Evaluar upstream,     │
│                                                      importar delta         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Puntuacion de salud (Health Score)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Health Score: 42/100  Grado: C                                      │
│                                                                      │
│  Requisitos        ██░░░░░░░░  2/10  Sin EARS, vagos                │
│  Especificaciones  ░░░░░░░░░░  0/10  No existen                     │
│  Tests             ████████░░  8/10  Buenos, sin trazabilidad       │
│  Arquitectura      ██████░░░░  6/10  README describe alto nivel     │
│  Trazabilidad      ░░░░░░░░░░  0/10  Inexistente                    │
│  Calidad codigo    ████████░░  8/10  Clean code, bien estructurado  │
│  Estado pipeline   ░░░░░░░░░░  0/10  Sin pipeline SDD              │
│                                                                      │
│  Clasificacion: Escenario 6 (Tests-as-spec)                          │
│  Confianza: HIGH (85%)                                               │
│                                                                      │
│  Grados:                                                             │
│  A (80-100) Excelente   B (60-79) Bueno                             │
│  C (40-59) Regular      D (20-39) Pobre    F (0-19) Critico        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Plan de accion generado

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Plan de accion para Escenario 6 (Tests-as-spec):                    │
│                                                                      │
│  Paso  Skill                    Esfuerzo  Health proyectado          │
│  ────  ────────────────────── ────────  ─────────────────           │
│  1     /sdd:reverse-engineer   L         42 → 58 (+16)              │
│  2     /sdd:spec-auditor       M         58 → 65 (+7)               │
│  3     /sdd:reconcile          M         65 → 72 (+7)               │
│  4     /sdd:test-planner       S         72 → 78 (+6)               │
│  5     /sdd:plan-architect     M         78 → 84 (+6)               │
│  6     /sdd:dashboard          S         84 → 86 (+2)               │
│                                                                      │
│  Esfuerzo: S=pequeno  M=mediano  L=grande  XL=muy grande           │
│                                                                      │
│  Riesgos detectados:                                                 │
│  ⚠ Tests sin assertions claras en src/api/tests/                    │
│  ⚠ 3 modulos sin ningun test                                        │
│                                                                      │
│  Siguiente comando: /sdd:reverse-engineer                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Modos de ejecucion del onboarding

```
/sdd:onboarding                # Diagnostico completo (7 fases)
/sdd:onboarding --quick        # Rapido: salta analisis profundo de codigo (fases 1-3, 6-7)
/sdd:onboarding --reassess     # Re-evaluar despues de adopcion parcial
```

### Archivo generado

```
onboarding/
└── ONBOARDING-REPORT.md       ← Diagnostico completo (solo lectura)
```

> **Importante:** El onboarding NUNCA modifica tu proyecto. Solo genera un reporte
> con recomendaciones. Tu decides que ejecutar.

---

## 3. Escenario A: Proyecto nuevo (greenfield)

Si tu proyecto es nuevo (Escenario 1), el camino es directo:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Proyecto nuevo → Pipeline completo:                                 │
│                                                                      │
│  /sdd:setup                                                          │
│       ↓                                                              │
│  /sdd:requirements-engineer        ← Tu idea → requisitos formales  │
│       ↓                                                              │
│  /sdd:specifications-engineer      ← Requisitos → 6 docs tecnicos  │
│       ↓                                                              │
│  /sdd:spec-auditor                 ← Auditar + corregir specs       │
│       ↓                                                              │
│  /sdd:tech-designer    (opcional)  ← Explorar stack y arquitectura  │
│  /sdd:ux-designer      (opcional)  ← Diseno visual y accesibilidad │
│  /sdd:security-auditor (opcional)  ← Auditoria OWASP               │
│       ↓                                                              │
│  /sdd:test-planner                 ← Plan de pruebas completo      │
│       ↓                                                              │
│  /sdd:plan-architect               ← Arquitectura C4 + FASEs       │
│       ↓                                                              │
│  /sdd:task-generator               ← Tareas atomicas por FASE      │
│       ↓                                                              │
│  /sdd:task-implementer             ← Codigo con TDD + commits      │
│       ↓                                                              │
│  /sdd:code-index       (opcional)  ← Indexar codigo implementado    │
│  /sdd:dashboard                    ← Dashboard visual               │
│  /sdd:traceability-check           ← Verificar cadena completa     │
│  /sdd:session-summary              ← Resumir sesion                 │
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
/sdd:reverse-engineer
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
/sdd:reverse-engineer                              # Completo (10 fases)
/sdd:reverse-engineer --scope=src/api,src/models   # Solo ciertos paths
/sdd:reverse-engineer --inventory-only             # Solo escaneo (fases 1-3)
/sdd:reverse-engineer --findings-only              # Solo hallazgos (dead code, tech debt)
/sdd:reverse-engineer --continue                   # Reanudar desde ultimo checkpoint
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
/sdd:import path/to/archivo
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
/sdd:import docs/api-spec.yaml

# Formato explicito
/sdd:import exports/jira-export.csv --format=jira

# Solo generar requisitos (no specs)
/sdd:import docs/requirements.csv --target=requirements

# Solo generar specs (no reqs)
/sdd:import docs/api.yaml --target=specs

# Generar ambos
/sdd:import docs/api.yaml --target=both

# Merge con artefactos existentes
/sdd:import docs/nuevos-reqs.csv --merge

# Multiples archivos
/sdd:import docs/api.yaml docs/requirements.csv docs/notion-export/

# Sin confirmacion interactiva
/sdd:import docs/api.yaml --yes
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
/sdd:reconcile
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
/sdd:reconcile                                # Completo: auto-resolve + preguntas
/sdd:reconcile --dry-run                      # Solo detectar, no cambiar nada
/sdd:reconcile --scope=src/api,src/models     # Solo ciertos paths
/sdd:reconcile --code-wins                    # Todo se resuelve a favor del codigo
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
/sdd:requirements-engineer

# Opciones de entrada:
# - Idea informal ("quiero una app de...")
# - Archivo con notas (docs/mi-idea.md)
# - Multiples fuentes
```

Genera: `requirements/REQUIREMENTS.md` con requisitos EARS (WHEN/THE/SHALL).

### Paso 2: Especificaciones

```
/sdd:specifications-engineer
```

Genera 6 documentos en `spec/`: DOMAIN-MODEL, USE-CASES, WORKFLOWS,
API-CONTRACTS, NFR, y ADRs.

### Paso 3: Auditoria de especificaciones

```
/sdd:spec-auditor
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
│  └── Analiza impacto upstream (puede necesitar /sdd:req-change)    │
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
/sdd:test-planner
```

Genera: `test/TEST-PLAN.md`, `test/TEST-MATRIX-*.md`, `test/PERF-SCENARIOS.md`

### Paso 5: Arquitectura y plan

```
/sdd:plan-architect
```

Genera: `plan/PLAN.md`, `plan/ARCHITECTURE.md`, `plan/fases/FASE-*.md`

> Si ejecutaste `/sdd:tech-designer` y/o `/sdd:ux-designer` antes,
> el arquitecto los consume automaticamente en su Phase 0.

### Paso 6: Generacion de tareas

```
/sdd:task-generator
```

Genera: `task/TASK-FASE-*.md`, `task/TASK-INDEX.md`, `task/TASK-ORDER.md`

### Paso 7: Implementacion

```
/sdd:task-implementer
```

Implementa tarea por tarea con TDD (Red → Green → Refactor → Commit).
Cada commit tiene trailers `Refs:` y `Task:` para trazabilidad.

---

## 6. Diseno tecnico (12 dimensiones)

```
/sdd:tech-designer
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
/sdd:tech-designer                              # Completo: 12 dimensiones
/sdd:tech-designer --dimensions=1,4,5,7         # Solo dimensiones especificas
/sdd:tech-designer --update                     # Actualizar diseno existente
/sdd:tech-designer --quality-only               # Solo atributos de calidad (ATAM-lite)
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

> **Tip:** Si `design/` existe cuando ejecutas `/sdd:plan-architect`,
> el arquitecto lo consume automaticamente y no te pregunta cosas ya decididas.

---

## 7. Diseno UX (12 dimensiones)

```
/sdd:ux-designer
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
│  5   Accesibilidad          WCAG 2.1 AA:                 Contraste 4.5:1,  │
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
│                             LCP, FID, CLS,              FID < 100ms,       │
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
/sdd:ux-designer                                          # Completo: 12 dimensiones
/sdd:ux-designer --dimensions=brand,accessibility,mobile  # Solo dimensiones especificas
/sdd:ux-designer --update                                 # Actualizar diseno existente
/sdd:ux-designer --wireframes-only                        # Solo wireframes y componentes
```

### Archivos generados

```
ux/
├── UI-DESIGN-SYSTEM.md        ← Sistema de diseno completo (12 dims)
├── WIREFRAMES.md              ← Wireframes ASCII + descripcion por pantalla
├── ACCESSIBILITY-SPEC.md      ← Checklist WCAG 2.1 AA
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

> **Tip:** Si `ux/` existe cuando ejecutas `/sdd:plan-architect`,
> el arquitecto integra el sistema de diseno en las fases de implementacion.

---

## 8. Auditoria de seguridad (10 dimensiones)

```
/sdd:security-auditor
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
│  Severidad:                                                          │
│  Critico  Explotable sin mitigacion, PII expuesta, auth bypass     │
│  Alto     Control parcial, gap explotable bajo condiciones          │
│  Medio    Control incompleto, defense-in-depth faltante             │
│  Bajo     Mejora sin amenaza inmediata, gap de documentacion        │
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

---

## 9. Gestion de cambios y cascada

```
/sdd:req-change
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
/sdd:req-change

# Cambio desde archivo estructurado
/sdd:req-change --file changes/CHANGE-REQUEST.md

# Solo planificar, no ejecutar
/sdd:req-change --dry-run

# Auto-aplicar todos los cambios sin confirmacion
/sdd:req-change --batch

# Pre-clasificar tipo de mantenimiento
/sdd:req-change --maintenance=corrective

# Controlar cascada
/sdd:req-change --cascade=auto
/sdd:req-change --cascade=manual
/sdd:req-change --cascade=dry-run
/sdd:req-change --cascade=plan-only
```

### Proceso completo (10 fases)

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Fase 0:  Inventario y carga de contexto                             │
│  Fase 1:  Recepcion del cambio + clasificacion ISO 14764            │
│  Fase 2:  Analisis de impacto                                        │
│           ├── Impacto directo e indirecto                            │
│           ├── Conflictos detectados                                  │
│           ├── Blast radius en codigo                                 │
│           └── Riesgo de regresion                                    │
│  Fase 3:  Clarificacion (7 propiedades SWEBOK)                      │
│           └── Genera EARS + criterios de aceptacion                 │
│  Fase 4:  Plan de cambio (antes/despues por artefacto)              │
│  Fase 5:  Revision y aprobacion del usuario                         │
│  Fase 6:  Ejecucion atomica (1 commit por CR)                       │
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
│  │  ├── REQUIREMENTS.md      (MODIFY REQ-TASK-001)         │        │
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

### Ciclo de vida de un Change Request

```
  DRAFT → REVIEWED → APPROVED → APPLIED → ARCHIVED
```

### Archivos generados

```
changes/
├── CR-001-add-task-priority.md           ← Delta proposal
├── CHANGE-PLAN-001.md                    ← Plan detallado antes/despues
├── CHANGE-REPORT-001.md                  ← Reporte completo
└── CASCADE-REPORT-001.md                 ← Resultado de la cascada (si auto/plan-only)
```

---

## 10. Importar documentacion externa

> Cubierto en detalle en la Seccion 4.2 de esta guia.
> Resumen rapido de comandos:

```
/sdd:import docs/api.yaml                          # OpenAPI → SDD
/sdd:import exports/jira.csv --format=jira          # Jira → SDD
/sdd:import docs/README.md                          # Markdown → SDD
/sdd:import exports/notion/ --format=notion          # Notion → SDD
/sdd:import data/requirements.csv                    # CSV → SDD
/sdd:import data/specs.xlsx                          # Excel → SDD
/sdd:import docs/a.yaml docs/b.csv --merge          # Multiples + merge
```

---

## 11. Reconciliar specs con codigo

> Cubierto en detalle en la Seccion 4.3 de esta guia.
> Resumen rapido:

```
/sdd:reconcile                  # Completo con auto-resolve + preguntas
/sdd:reconcile --dry-run        # Solo detectar divergencias
/sdd:reconcile --code-wins      # Resolver todo a favor del codigo
/sdd:reconcile --scope=src/api  # Solo cierto scope
```

---

## 12. Herramientas de utilidad

### 12.1 Estado del pipeline

```
/sdd:pipeline-status
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
│  → Re-ejecutar /sdd:task-generator (spec/ cambio despues del plan)  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.2 Verificacion de trazabilidad

```
/sdd:traceability-check
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Traceability Check                                                  │
│                                                                      │
│  Cadena: REQ → UC → WF → API → BDD → INV → ADR                     │
│                                                                      │
│  REQ-TASK-001  ✅ → UC-TASK-001 ✅ → WF-TASK-CREATE ✅ → API-TASK-001│
│  REQ-TASK-002  ✅ → UC-TASK-002 ✅ → WF-TASK-LIST   ✅ → API-TASK-002│
│  REQ-TASK-003  ✅ → UC-TASK-003 ⚠️ → (sin workflow)                 │
│  REQ-SEC-001   ✅ → UC-AUTH-001 ✅ → WF-AUTH-LOGIN  ✅ → API-AUTH-001│
│                                                                      │
│  Problemas encontrados:                                              │
│  ⚠️ REQ-TASK-003 → UC-TASK-003: Falta workflow WF-TASK-DONE        │
│  ⚠️ ADR-002 no referenciado por ningun UC                           │
│  ⚠️ INV-005 no referenciado por ningun use case                     │
│                                                                      │
│  Huerfanos: 2 (ADR-002, INV-005)                                    │
│  Links rotos: 1 (WF-TASK-DONE referenciado pero no definido)       │
│  Cobertura: 92% (23/25 links verificados)                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.3 Code intelligence

```
/sdd:code-index
```

Indexa el codigo fuente y lo conecta con artefactos SDD.

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Dos motores disponibles:                                            │
│                                                                      │
│  Sin GitNexus (Lite):                                                │
│  ├── Descubrimiento de simbolos via regex                           │
│  ├── Mapeo directo de Refs: comments                                │
│  ├── Commits con trailers Refs:/Task:                               │
│  └── Sin call graph ni inferencia transitiva                        │
│                                                                      │
│  Con GitNexus (Full):                                                │
│  ├── Todo lo anterior +                                              │
│  ├── AST analysis completo                                          │
│  ├── Call graph (quien llama a quien)                               │
│  ├── Clusters de codigo relacionado                                 │
│  ├── Flujos de ejecucion (execution flows)                          │
│  ├── Inferencia transitiva (max depth 2, confidence > 0.7)         │
│  └── Commit-symbol bridge (a nivel de funcion, no archivo)         │
│                                                                      │
│  4 estados de origen (inference engine):                             │
│                                                                      │
│  Estado     Color     Significado                                    │
│  ─────────  ────────  ──────────────────────────────────────        │
│  direct     ■ verde   Tiene // Refs: comment en el codigo           │
│  inferred   ◧ amarillo Inferido de commits con Refs: trailers       │
│  suggested  ? gris    Inferencia de baja confianza (< 0.7)         │
│  uncovered  ○ rojo    Sin ninguna referencia encontrada             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Modos de ejecucion

```
/sdd:code-index                 # Full (con GitNexus si disponible)
/sdd:code-index --lite          # Solo regex (sin GitNexus)
/sdd:code-index --status        # Verificar si el index esta actualizado
/sdd:code-index --refresh       # Re-indexar solo archivos cambiados
```

### Archivos generados

```
dashboard/traceability-graph.json     ← Enriquecido con codeIntelligence
code-intelligence/
└── CODE-INDEX-REPORT.md              ← Estadisticas, simbolos uncovered
```

### 12.4 Resumen de sesion

```
/sdd:session-summary
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
│  3. Ejecutar /sdd:plan-architect                                    │
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

## 13. Dashboard y servidor en vivo

### 13.1 Generar dashboard

```
/sdd:dashboard
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Dashboard HTML interactivo con 5 vistas:                            │
│                                                                      │
│  1. Resumen ejecutivo                                                │
│     ├── Health score global                                         │
│     ├── Metricas clave (artefactos, cobertura, orphans)            │
│     └── Alertas activas                                              │
│                                                                      │
│  2. Trazabilidad                                                     │
│     ├── Grafo interactivo (nodos = artefactos, edges = refs)        │
│     ├── Click en nodo para ver detalle                              │
│     └── Filtro por tipo de artefacto                                │
│                                                                      │
│  3. Cobertura                                                        │
│     ├── Gap analysis por dominio y capa tecnica                     │
│     ├── REQs con/sin code refs                                      │
│     ├── REQs con/sin test refs                                      │
│     └── Estados: linked (verde), inferred (amarillo),               │
│         suggested (gris), uncovered (rojo)                          │
│                                                                      │
│  4. Pipeline                                                         │
│     ├── Estado de cada etapa con timestamps                         │
│     ├── Resumen de metricas por etapa                               │
│     └── Dependencias y flujo                                        │
│                                                                      │
│  5. Adopcion                                                         │
│     ├── Progreso de adopcion SDD                                    │
│     ├── Skills ejecutados vs pendientes                             │
│     └── Health score over time                                       │
│                                                                      │
│  Metricas reportadas:                                                │
│  ├── Total artefactos por tipo (REQ, UC, WF, API, BDD, INV, ADR)  │
│  ├── Cobertura de trazabilidad (% REQs con UCs, code, tests)      │
│  ├── Artefactos huerfanos (0 incoming refs)                        │
│  ├── Referencias rotas (mencionadas pero no definidas)              │
│  ├── Code stats (archivos, simbolos con refs, uncovered)           │
│  ├── Test stats (archivos de test, tests con refs)                 │
│  └── Commit stats (commits con Refs: trailers, Task: trailers)    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Archivos generados

```
dashboard/
├── index.html                  ← Dashboard interactivo (abrir en navegador)
├── guide.html                  ← Guia de interpretacion
├── traceability-graph.json     ← Datos del grafo (schema v3/v4)
└── live-status.js              ← Seed JSONP para activity feed
```

### 13.2 Dashboard server con actualizaciones en vivo (SSE)

Para ver cambios en tiempo real mientras trabajas (sin regenerar el dashboard):

```bash
# Levantar el servidor
node ~/.claude/plugins/cache/noelserdna-plugins/sdd/*/server/dist/dashboard-entry.js

# O con puerto personalizado
SDD_DASHBOARD_PORT=4000 node .../dashboard-entry.js
```

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Dashboard Server (HTTP + SSE):                                      │
│                                                                      │
│  Endpoints:                                                          │
│  http://localhost:3001/              ← Dashboard HTML                │
│  http://localhost:3001/events        ← SSE stream (tiempo real)     │
│  http://localhost:3001/api/status    ← Estado del pipeline JSON     │
│  http://localhost:3001/api/graph     ← Grafo de trazabilidad JSON   │
│                                                                      │
│  Hooks que alimentan el server (requiere H6 instalado):             │
│  POST /hooks/session-start          ← Inicio de sesion             │
│  POST /hooks/tool-use               ← Cada uso de herramienta      │
│  POST /hooks/subagent-start         ← Inicio de subagente          │
│  POST /hooks/subagent-stop          ← Fin de subagente             │
│  POST /hooks/task-completed         ← Tarea completada             │
│  POST /hooks/session-stop           ← Fin de sesion                │
│  POST /hooks/session-end            ← Cierre de sesion             │
│                                                                      │
│  El dashboard detecta automaticamente:                               │
│  • Si esta servido por HTTP → usa SSE en vivo                       │
│  • Si esta abierto como archivo local → usa JSONP polling           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

Para habilitar los hooks HTTP (H6), ejecuta `/sdd:setup` y acepta la opcion
de instalar hooks opcionales, o copia manualmente `settings-optional-dashboard.json`.

---

## 14. Servidor MCP (consultas de trazabilidad)

El servidor MCP permite hacer consultas en tiempo real sobre la trazabilidad
del proyecto. Se activa automaticamente si el plugin esta instalado.

### 5 herramientas de consulta

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
│  sdd_coverage   Gap analysis por dominio de          "¿Que dominios        │
│                 negocio y capa tecnica.              tienen menos            │
│                 Identifica areas sin cobertura.      cobertura?"             │
│                                                                              │
│  sdd_trace      Cadena de trazabilidad completa:    "Traza REQ-SEC-001     │
│                 REQ → UC → WF → API → BDD → INV     de punta a punta"      │
│                 → ADR → TASK → COMMIT → CODE → TEST                        │
│                 Detecta rupturas en la cadena.                               │
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
sdd://artifact/{id}           ← Detalle de un artefacto
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

## 15. Automatizacion: hooks y agentes

### Hooks core (siempre activos)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Hook  Nombre             Evento          Que hace                          │
│  ────  ─────────────────  ──────────────  ──────────────────────────────── │
│  H1    Session Start      SessionStart    Lee pipeline-state.json e         │
│                           (startup,       inyecta estado del pipeline al    │
│                            resume,        inicio de cada sesion             │
│                            compact)                                         │
│                                                                              │
│  H2    Upstream Guard     PreToolUse      Bloquea si un skill downstream   │
│                           (Edit, Write)   intenta modificar artefactos      │
│                                           upstream (Art. 4 Constitucion)   │
│                                                                              │
│  H3    State Updater      PostToolUse     Auto-actualiza pipeline-state.json│
│                           (Write, async)  cuando se escribe un artefacto   │
│                                                                              │
│  H4    Stop Hook          Stop            Verifica consistencia del         │
│                           (inline prompt) pipeline al cerrar sesion         │
│                                                                              │
│  H5    Context Augment    PreToolUse      Enriquece contexto de             │
│                           (Grep, Glob,    herramientas con datos de         │
│                            Read, Edit,    trazabilidad SDD                  │
│                            Write)                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Hooks opcionales (instalar con /sdd:setup)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Hook  Nombre              Evento          Que hace                         │
│  ────  ──────────────────  ──────────────  ─────────────────────────────── │
│  H6    Dashboard HTTP      SessionStart,   POST eventos al dashboard server│
│                            PostToolUse,    en http://localhost:3001/hooks/* │
│                            SubagentStart,  Permite actualizaciones en vivo │
│                            SubagentStop,   via SSE                          │
│                            TaskCompleted,                                   │
│                            Stop, SessionEnd                                │
│                                                                              │
│  H7    Stop Quality Gate   Stop            Quality gate al cerrar sesion:  │
│                            (prompt hook)   verifica que pipeline-state.json │
│                                            es consistente y sin stages     │
│                                            "running" abandonados           │
│                                                                              │
│  H8    Task Traceability   TaskCompleted   Verifica que el ultimo commit   │
│        Gate                (agent hook)    tiene trailers Refs: y Task:    │
│                                            Si faltan, bloquea hasta       │
│                                            corregir                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Hooks a nivel de skill

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                   │
│  Skill               Hook              Que verifica              │
│  ──────────────────  ────────────────  ────────────────────────  │
│  task-implementer    Stop (prompt)     Refs:/Task: en el ultimo │
│                                        commit de la sesion       │
│                                                                   │
│  spec-auditor        Stop (prompt)     Hallazgos P0/P1 estan   │
│                                        addressed (no ignorados) │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Agentes de validacion

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Agente  Nombre                  Modelo   Que hace                          │
│  ──────  ──────────────────────  ───────  ──────────────────────────────── │
│  A1      Constitution Enforcer   haiku    Valida operaciones contra los    │
│                                           11 articulos de la Constitucion  │
│                                           SDD. Cualquier skill o hook      │
│                                           puede delegarle una validacion.  │
│                                                                              │
│  A2      Cross-Auditor           sonnet   Cross-referencia las 13           │
│                                           definiciones de skills para       │
│                                           detectar: mismatches de I/O,     │
│                                           inconsistencias de version,       │
│                                           refs cruzadas stale. Tiene       │
│                                           memoria de proyecto.             │
│                                                                              │
│  A3      Context Keeper          haiku    Mantiene contexto informal del   │
│                                           proyecto que NO pertenece a      │
│                                           artefactos formales:             │
│                                           preferencias, decisiones         │
│                                           aplazadas, input de stakeholders.│
│                                           Tags: PREF, DEFERRED,           │
│                                           STAKEHOLDER, TECH-NOTE,          │
│                                           CONSTRAINT, OBSERVATION          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 16. La Constitucion SDD (11 articulos)

El agente A1 (Constitution Enforcer) valida contra estos articulos:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│  Art.  Nombre                    Regla                                      │
│  ────  ────────────────────────  ─────────────────────────────────────────  │
│  1     Spec es fuente de verdad  Toda implementacion se deriva de la spec  │
│                                                                              │
│  2     Cadena de trazabilidad    REQ→UC→WF→API→BDD→INV→ADR sin huerfanos  │
│                                                                              │
│  3     Clarificacion primero     Nunca asumir. Preguntar con opciones      │
│                                  estructuradas. Documentar en CLARIFY-LOG  │
│                                                                              │
│  4     Inmutabilidad upstream    Skills downstream NO modifican artefactos │
│                                  upstream (H2 lo enforce automaticamente)  │
│                                                                              │
│  5     Reversibilidad atomica    1 tarea = 1 commit con estrategia de      │
│                                  rollback (SAFE/COUPLED/MIGRATION/CONFIG)  │
│                                                                              │
│  6     Auditoria baseline        Primera auditoria crea baseline.          │
│                                  Siguientes solo reportan new + regression │
│                                                                              │
│  7     Conventional commits      Commits con Refs: y Task: trailers        │
│                                                                              │
│  8     Integridad del pipeline   pipeline-state.json es autoritativo.      │
│                                  Staleness se propaga downstream           │
│                                                                              │
│  9     Separacion de concerns    Cada skill escribe en SU directorio.      │
│                                  Cross-writing prohibido                    │
│                                                                              │
│  10    Cambio via proceso        Todos los cambios van por                  │
│                                  /sdd:req-change, no edicion directa       │
│                                                                              │
│  11    Formal sobre informal     Comportamiento del sistema se captura     │
│                                  en ADRs/reqs/specs, no en contexto        │
│                                  informal ni en memoria                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 17. Sync con Notion

```
/sdd:sync-notion
```

Sincroniza artefactos SDD bidireccionalmente con bases de datos de Notion.

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Prerrequisitos:                                                     │
│  ├── NOTION_API_KEY         (token de integracion Notion)           │
│  └── NOTION_PARENT_PAGE_ID  (pagina padre donde crear las DBs)     │
│                                                                      │
│  Que sincroniza:                                                     │
│  ├── requirements/  ←→  Notion DB "SDD Requirements"               │
│  ├── spec/use-cases ←→  Notion DB "SDD Use Cases"                  │
│  ├── task/          ←→  Notion DB "SDD Tasks"                      │
│  └── pipeline status ←→ Notion DB "SDD Pipeline"                   │
│                                                                      │
│  Modos:                                                              │
│  push   Local → Notion  (sobreescribe)                              │
│  pull   Notion → Local  (actualiza markdown)                        │
│  sync   Bidireccional   (merge inteligente)                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
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
/sdd:setup

# Diagnosticar el proyecto
/sdd:onboarding
```

Resultado: **Escenario 5 (Brownfield con docs)**, Health Score: 35/100 (D).

Plan recomendado:
1. `/sdd:import` (Jira + OpenAPI)
2. `/sdd:reverse-engineer`
3. `/sdd:reconcile`
4. Pipeline normal desde spec-auditor

### Fase 1: Importar docs existentes

```
# Importar el export de Jira
/sdd:import exports/jira-2026-03.csv --format=jira --target=requirements

# Importar la spec OpenAPI
/sdd:import docs/openapi.yaml --target=specs --merge
```

### Fase 2: Reverse engineer el codigo

```
/sdd:reverse-engineer --scope=src/
```

Al llegar al Checkpoint 1, revisas el inventario y continuas.
Al Checkpoint 2, revisas las specs generadas y continuas.

### Fase 3: Reconciliar

```
/sdd:reconcile
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
/sdd:spec-auditor

# Corregir (modo Fix)
/sdd:spec-auditor
# → Selecciona "Fix"
```

### Fase 5: Diseno tecnico y UX

```
# Explorar/documentar stack actual
/sdd:tech-designer --update

# Definir sistema de diseno
/sdd:ux-designer
```

### Fase 6: Auditoria de seguridad

```
/sdd:security-auditor
```

Score: 52/100 (C). 8 hallazgos, 2 criticos.

### Fase 7: Plan de pruebas y arquitectura

```
/sdd:test-planner
/sdd:plan-architect
```

### Fase 8: Tareas e implementacion

```
/sdd:task-generator
/sdd:task-implementer
```

### Fase 9: Post-implementacion

```
# Indexar codigo implementado
/sdd:code-index

# Verificar trazabilidad
/sdd:traceability-check

# Generar dashboard
/sdd:dashboard

# Ver estado final
/sdd:pipeline-status

# Resumir sesion
/sdd:session-summary
```

### Fase 10: Sprint 2 — Nuevo requisito

```
# Agregar funcionalidad de "wishlist"
/sdd:req-change --cascade=auto

# Verificar resultado
/sdd:pipeline-status
/sdd:dashboard
```

### Fase 11: Sprint 3 — Detectar drift

```
# Alguien hizo cambios directos al codigo...
/sdd:reconcile --dry-run     # Ver que cambio
/sdd:reconcile               # Reconciliar
```

### Estructura final del proyecto

```
ecommerce-api/
├── pipeline-state.json
│
├── onboarding/
│   └── ONBOARDING-REPORT.md          ← Diagnostico inicial
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
│   └── REQUIREMENTS.md               ← Requisitos formales (EARS)
│
├── spec/
│   ├── DOMAIN-MODEL.md
│   ├── USE-CASES.md
│   ├── WORKFLOWS.md
│   ├── API-CONTRACTS.md
│   ├── NFR.md
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
│   ├── PLAN.md
│   ├── ARCHITECTURE.md
│   └── fases/FASE-*.md
│
├── task/
│   ├── TASK-FASE-*.md
│   ├── TASK-INDEX.md
│   └── TASK-ORDER.md
│
├── changes/
│   ├── CR-001-add-wishlist.md         ← Change request
│   ├── CHANGE-PLAN-001.md
│   ├── CHANGE-REPORT-001.md
│   └── CASCADE-REPORT-001.md
│
├── dashboard/
│   ├── index.html                     ← Dashboard interactivo
│   ├── guide.html
│   ├── traceability-graph.json
│   └── live-status.js
│
├── code-intelligence/
│   └── CODE-INDEX-REPORT.md           ← Simbolos, cobertura, gaps
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
│  /sdd:setup                              Inicializar proyecto            │
│                                                                           │
│  DIAGNOSTICO                                                              │
│  /sdd:onboarding                         Diagnostico completo            │
│  /sdd:onboarding --quick                 Diagnostico rapido              │
│  /sdd:onboarding --reassess              Re-evaluar                      │
│                                                                           │
│  BROWNFIELD                                                               │
│  /sdd:reverse-engineer                   Codigo → artefactos SDD        │
│  /sdd:reverse-engineer --scope=PATH      Scope limitado                  │
│  /sdd:reverse-engineer --inventory-only  Solo escaneo                    │
│  /sdd:reverse-engineer --findings-only   Solo hallazgos                  │
│  /sdd:reverse-engineer --continue        Reanudar checkpoint            │
│  /sdd:import FILE                        Importar doc externo           │
│  /sdd:import FILE --format=FORMAT        Formato explicito              │
│  /sdd:import FILE --target=TARGET        Solo reqs/specs/both           │
│  /sdd:import FILE --merge                Merge con existentes           │
│  /sdd:reconcile                          Reconciliar spec ↔ codigo     │
│  /sdd:reconcile --dry-run                Solo detectar                   │
│  /sdd:reconcile --code-wins              Codigo siempre gana            │
│  /sdd:reconcile --scope=PATH             Scope limitado                  │
│                                                                           │
│  PIPELINE (en orden)                                                      │
│  /sdd:requirements-engineer              Requisitos formales             │
│  /sdd:specifications-engineer            Especificaciones tecnicas      │
│  /sdd:spec-auditor                       Auditar/corregir specs         │
│  /sdd:test-planner                       Plan de pruebas                 │
│  /sdd:plan-architect                     Arquitectura + fases            │
│  /sdd:task-generator                     Tareas atomicas                 │
│  /sdd:task-implementer                   Implementar con TDD             │
│                                                                           │
│  LATERALES (cualquier momento)                                            │
│  /sdd:tech-designer                      12 dims tecnicas               │
│  /sdd:tech-designer --dimensions=N,N     Dims especificas               │
│  /sdd:tech-designer --update             Actualizar existente           │
│  /sdd:tech-designer --quality-only       Solo ATAM-lite                 │
│  /sdd:ux-designer                        12 dims UX                     │
│  /sdd:ux-designer --dimensions=LIST      Dims especificas               │
│  /sdd:ux-designer --update               Actualizar existente           │
│  /sdd:ux-designer --wireframes-only      Solo wireframes                │
│  /sdd:security-auditor                   10 dims seguridad (OWASP)     │
│  /sdd:req-change                         Gestion de cambios             │
│  /sdd:req-change --cascade=MODE          auto/manual/dry-run/plan-only │
│  /sdd:req-change --dry-run               Solo planificar                │
│  /sdd:req-change --batch                 Auto-aplicar todo              │
│  /sdd:req-change --file=PATH             Desde archivo CR               │
│  /sdd:req-change --maintenance=TYPE      Pre-clasificar ISO 14764      │
│                                                                           │
│  UTILIDADES                                                               │
│  /sdd:pipeline-status                    Estado del pipeline             │
│  /sdd:traceability-check                 Verificar cadena               │
│  /sdd:dashboard                          Dashboard HTML                  │
│  /sdd:code-index                         Indexar codigo                  │
│  /sdd:code-index --lite                  Sin GitNexus                    │
│  /sdd:code-index --status                Verificar frescura             │
│  /sdd:code-index --refresh               Re-indexar cambios             │
│  /sdd:session-summary                    Resumen de sesion               │
│  /sdd:sync-notion                        Sync con Notion                 │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 20. Glosario extendido

| Termino | Significado |
|---------|-------------|
| **Pipeline** | Secuencia de 7 pasos (REQ → IMPL) |
| **FASE** | Fase de implementacion (grupo de tareas) |
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
| **SSE** | Server-Sent Events (actualizaciones push en tiempo real) |
| **MCP** | Model Context Protocol (consultas de trazabilidad) |
| **GitNexus** | Herramienta de code intelligence (call graph, clusters) |
| **Design Tokens** | Variables de diseno exportables (colores, spacing, etc.) |
| **WCAG** | Web Content Accessibility Guidelines (2.1 AA) |
| **Blast Radius** | Conjunto de artefactos/codigo afectados por un cambio |
| **Code Intelligence** | Mapeo bidireccional codigo ↔ artefactos SDD |
| **ATAM-lite** | Architecture Tradeoff Analysis Method simplificado |
| **Atomic Design** | Metodologia UI: atoms → molecules → organisms → templates → pages |
| **Health Score** | Puntuacion 0-100 de salud del proyecto SDD |
| **Baseline** | Primera auditoria; las siguientes solo reportan deltas |
| **Checkpoint** | Punto de pausa en reverse-engineer para confirmacion |
| **Divergence** | Diferencia detectada entre spec y codigo (reconcile) |
| **CR** | Change Request (solicitud de cambio formal) |
| **Constitution** | 11 articulos que gobiernan el comportamiento de SDD |
| **Upstream** | Artefactos que alimentan al actual (ej: requirements es upstream de spec) |
| **Downstream** | Artefactos que dependen del actual (ej: task es downstream de plan) |
| **Fast Path** | Ejecucion acelerada del dashboard via generate.py |
| **JSONP Polling** | Mecanismo de actualizacion cuando dashboard se abre como archivo local |
| **Inference Engine** | Motor que deduce trazabilidad code→spec desde commits y simbolos |

---

> **SDD no es burocracia. Es la diferencia entre construir una casa con planos
> y construir una casa "a ojo".** Los planos toman tiempo, pero la casa no se cae.
>
> Esta guia cubre TODAS las opciones. No necesitas usarlas todas en cada proyecto.
> Usa `/sdd:onboarding` para que el sistema te diga exactamente cuales necesitas.
