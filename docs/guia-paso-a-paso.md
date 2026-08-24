# Guía Paso a Paso: Desarrollo con SDD

> **Specification-Driven Development** — Construye software que funciona bien *desde el principio*,
> no software que "funciona" y luego hay que arreglar.

---

## Tabla de Contenidos

1. [¿Qué es SDD y por qué usarlo?](#1-qué-es-sdd-y-por-qué-usarlo)
2. [Prerrequisitos e instalación](#2-prerrequisitos-e-instalación)
3. [Visión general del pipeline](#3-visión-general-del-pipeline)
4. [Paso 1 — Requisitos](#4-paso-1--requisitos)
5. [Paso 2 — Especificaciones](#5-paso-2--especificaciones)
6. [Paso 3 — Auditoría de especificaciones](#6-paso-3--auditoría-de-especificaciones)
7. [Paso 4 — Plan de pruebas](#7-paso-4--plan-de-pruebas)
8. [Paso 5 — Arquitectura y plan de implementación](#8-paso-5--arquitectura-y-plan-de-implementación)
9. [Paso 6 — Generación de tareas](#9-paso-6--generación-de-tareas)
10. [Paso 7 — Implementación](#10-paso-7--implementación)
11. [Herramientas laterales](#11-herramientas-laterales)
12. [Herramientas de utilidad](#12-herramientas-de-utilidad)
13. [Iteración y gestión de cambios](#13-iteración-y-gestión-de-cambios)
14. [Ejemplo completo: App de gestión de tareas](#14-ejemplo-completo-app-de-gestión-de-tareas)
15. [Preguntas frecuentes](#15-preguntas-frecuentes)

---

## 1. ¿Qué es SDD y por qué usarlo?

### El problema: Agile en la práctica

En teoría, Agile dice: *"entrega valor rápido, itera, adapta"*. En la práctica,
la mayoría de los equipos terminan haciendo esto:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  El ciclo Agile en la vida real:                                                 │
│                                                                                  │
│  Sprint 1        Sprint 2        Sprint 3        Sprint 4        Sprint N       │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐     │
│  │ "Hagamos │   │ "Hay que │   │ "Se cayó │   │ "Nadie   │   │ "Hay que │     │
│  │  código" │──▶│  arreglar│──▶│  en prod"│──▶│  sabe por│──▶│  reescri-│     │
│  │          │   │  los bugs│   │          │   │  qué se  │   │  bir todo│     │
│  └──────────┘   └──────────┘   └──────────┘   │  hizo así│   └──────────┘     │
│                                                └──────────┘                     │
│                                                                                  │
│  Ticket → Código → PR → Merge → Bug → Hotfix → Más bugs → Deuda técnica → ...  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**¿Por qué pasa esto?** Porque Agile optimiza para *velocidad de entrega*, pero no define
*qué* se está construyendo con precisión. Los tickets de Jira dicen "como usuario quiero X"
pero nunca especifican:

- ¿Qué pasa cuando X falla?
- ¿Qué invariantes debe respetar?
- ¿Cómo interactúa X con las funcionalidades Y y Z?
- ¿Por qué se eligió esta arquitectura y no otra?

El resultado: código que **nadie entiende**, requisitos que **nadie formalizó**, decisiones
que **nadie documentó**, y cada cambio es una lotería de bugs.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  Agile típico:                          Lo que falta:                            │
│                                                                                  │
│  ✅ Entrega rápida                      ❌ Especificaciones formales             │
│  ✅ Adaptación al cambio                ❌ Trazabilidad de decisiones            │
│  ✅ Comunicación con stakeholders       ❌ Auditoría de consistencia             │
│  ✅ Iteraciones cortas                  ❌ Análisis de impacto de cambios        │
│  ✅ Feedback continuo                   ❌ Verificación de cobertura             │
│                                          ❌ Reversibilidad garantizada           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

> **Nota:** El problema no es Agile en sí — es que Agile no cubre ingeniería
> de especificaciones. SDD **complementa** Agile, no lo reemplaza. Puedes
> seguir usando sprints, standups y retrospectivas, pero con la certeza de
> que lo que construyes está bien definido antes de escribir código.

### La solución: SDD (Specification-Driven Development)

**SDD** invierte el proceso: primero defines *qué* debe hacer el sistema con
precisión formal, y luego construyes *exactamente eso*.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  Agile típico:                             SDD:                                  │
│                                                                                  │
│  Ticket vago                               Requisito formal (EARS)               │
│    → Código adivinando                       → Especificación verificable        │
│      → Tests después                           → Auditoría de specs              │
│        → Bugs en prod                            → Plan de pruebas ANTES         │
│          → Hotfix sin contexto                     → Arquitectura documentada    │
│            → Más bugs                                → Tareas atómicas trazables │
│              → Reescritura                             → Código con TDD          │
│                                                          → Cada commit rastreable│
│                                                                                  │
│  "¿Por qué hicimos esto?"                  "ADR-003 explica la decisión"        │
│  "¿Este cambio rompe algo?"                "El análisis de impacto dice que..."  │
│  "¿Funciona?"                              "Los 36 tests pasan"                  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

```
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │                                                                              │
 │   "Tengo una idea"                                                           │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Requisitos claros         ← ¿Qué necesita el usuario?                     │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Especificaciones formales ← ¿Cómo se comporta el sistema exactamente?     │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Auditoría                 ← ¿Hay ambigüedades o contradicciones?          │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Plan de pruebas           ← ¿Cómo verificamos que funciona?               │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Arquitectura              ← ¿Cómo lo construimos?                         │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Tareas atómicas           ← ¿En qué orden, paso a paso?                   │
 │        │                                                                     │
 │        ▼                                                                     │
 │   Implementación            ← Código con tests, trazable y reversible       │
 │                                                                              │
 └──────────────────────────────────────────────────────────────────────────────┘
```

### Beneficios concretos

| Sin SDD | Con SDD |
|---------|---------|
| "¿Por qué hicimos esto así?" | Cada decisión tiene un ADR trazable |
| "¿Este cambio rompe algo?" | Análisis de impacto automático |
| "¿Están todos los requisitos cubiertos?" | Cadena de trazabilidad verificable |
| "¿Qué nos falta por probar?" | Matriz de pruebas con cobertura medida |
| "Este commit rompió todo" | 1 tarea = 1 commit atómico y reversible |

### La cadena de trazabilidad

Cada pieza del sistema está conectada con las demás. Si algo cambia, puedes
rastrear exactamente qué se afecta:

```
REQ ──→ UC ──→ WF ──→ API ──→ BDD ──→ INV ──→ ADR ──→ TASK ──→ COMMIT ──→ CODE ──→ TEST
 │       │      │       │       │       │       │        │         │          │        │
 │       │      │       │       │       │       │        │         │          │        │
 ▼       ▼      ▼       ▼       ▼       ▼       ▼        ▼         ▼          ▼        ▼
Req.   Caso   Flujo  Contrato Escen.  Regla  Decisión  Tarea    Commit    Archivo   Test
       de Uso  de     de API   BDD    de neg. Arquit.  atómica  con SHA   fuente    auto.
               trabajo                                           trazable
```

**¿Qué significa cada sigla?**

| Sigla | Nombre | ¿Qué es? |
|-------|--------|----------|
| REQ | Requirement | Un requisito del usuario |
| UC | Use Case | Un caso de uso que describe una interacción |
| WF | Workflow | Un flujo de trabajo paso a paso |
| API | API Contract | El contrato de una interfaz (endpoint, función) |
| BDD | Behavior-Driven Design | Escenario Given/When/Then |
| INV | Invariant | Regla de negocio que siempre debe cumplirse |
| ADR | Architecture Decision Record | Registro de una decisión de diseño |
| TASK | Task | Una tarea atómica de implementación |
| COMMIT | Git Commit | Un commit con trazabilidad |
| CODE | Source Code | Archivo fuente implementado |
| TEST | Test | Test automatizado |

---

## 2. Prerrequisitos e instalación

### Lo que necesitas

```
┌─────────────────────────────────────────────────┐
│  Prerrequisitos                                  │
│                                                  │
│  ✓ Claude Code CLI  (claude.ai/code)            │
│  ✓ Git              (control de versiones)      │
│  ✓ Node.js 18+      (para el servidor MCP)      │
│  ✓ jq               (procesamiento JSON)        │
│  ✓ Plugin SDD       (este proyecto)             │
│                                                  │
│  Opcional:                                       │
│  ○ GitHub CLI (gh)   (para PRs automáticos)     │
│  ○ Notion API key    (para sync con Notion)     │
│  ○ GitNexus          (code intelligence)        │
│    npm i -g gitnexus                             │
└─────────────────────────────────────────────────┘
```

### Instalación del plugin SDD

Abre Claude Code en cualquier directorio:

```bash
claude
```

La instalación tiene **2 pasos**: agregar el marketplace y luego instalar el plugin.

**Paso 1: Agregar el marketplace**

```
/plugin marketplace add noelserdna/claude-plugin-sdd
```

Esto registra el repositorio de GitHub como fuente de plugins.

**Paso 2: Instalar el plugin**

```
/plugin install sdd@noelserdna-claude-plugin-sdd
```

> **Alternativa interactiva:** Puedes escribir `/plugin` sin argumentos para abrir
> un gestor visual con pestañas (Discover, Installed, Marketplaces).

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  ¿Qué sucede al instalar?                                                        │
│                                                                                  │
│  1. Descarga el plugin desde GitHub                                              │
│     noelserdna/claude-plugin-sdd                                                 │
│                                                                                  │
│  2. Registra los 22 skills como comandos /sdd:*                                  │
│     /sdd:requirements-engineer                                                   │
│     /sdd:specifications-engineer                                                 │
│     /sdd:spec-auditor                                                            │
│     ... (22 skills en total)                                                     │
│                                                                                  │
│  3. Instala hooks de automatización (H1-H5)                                      │
│     Session start, upstream guard, state updater, etc.                            │
│                                                                                  │
│  4. Registra agentes de validación (A1-A8)                                       │
│     Constitution enforcer, cross-auditor, etc.                                   │
│                                                                                  │
│  5. Configura el servidor MCP (si Node.js 18+ disponible)                        │
│     Herramientas de consulta de trazabilidad en tiempo real                       │
│                                                                                  │
│  El plugin queda instalado GLOBALMENTE — disponible en cualquier proyecto.       │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Gestión del plugin después de instalado:**

```
/plugin disable sdd@noelserdna-claude-plugin-sdd     # Desactivar temporalmente
/plugin enable sdd@noelserdna-claude-plugin-sdd      # Reactivar
/plugin uninstall sdd@noelserdna-claude-plugin-sdd   # Desinstalar
```

> **Repositorio del plugin:** https://github.com/noelserdna/claude-plugin-sdd

### Inicializar SDD en tu proyecto

Una vez instalado el plugin, navega a tu proyecto y ejecuta:

```bash
cd mi-proyecto
claude
```

Dentro de Claude Code:

```
/sdd:setup
```

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  ¿Qué hace /sdd:setup?                                                          │
│                                                                                  │
│  A diferencia de /plugin install (que es global), /sdd:setup es POR PROYECTO:    │
│                                                                                  │
│  1. Crea pipeline-state.json                                                     │
│     Estado del pipeline, con sddVersion y hooksVersion                           │
│                                                                                  │
│  2. Detecta upgrades (v1 → v2)                                                  │
│     Si tienes hooks antiguos, los migra automáticamente                          │
│                                                                                  │
│  3. Verifica dependencias (jq, node)                                             │
│     y compila el servidor MCP si es necesario                                    │
│                                                                                  │
│  4. Genera reporte de verificación                                               │
│     Confirma que todo está listo para usar                                        │
│                                                                                  │
│  Resultado:                                                                      │
│                                                                                  │
│  tu-proyecto/                                                                    │
│  └── pipeline-state.json     ← Estado del pipeline SDD                           │
│                                                                                  │
│  Los hooks (H1-H5), agentes (A1-A8) y servidor MCP vienen incluidos             │
│  en el plugin — NO se copian al proyecto. Solo pipeline-state.json es local.     │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

> **Resumen:** `/plugin install` = instalar una vez, global.
> `/sdd:setup` = inicializar cada proyecto nuevo.

---

## 3. Visión general del pipeline

### El pipeline completo

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                          PIPELINE SDD COMPLETO                                  ║
╠══════════════════════════════════════════════════════════════════════════════════╣
║                                                                                  ║
║  ┌─────────────────────┐                                                         ║
║  │  /sdd:requirements-  │──→ requirements/REQUIREMENTS.md                        ║
║  │   engineer           │    "¿Qué necesita el usuario?"                         ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    spec/                                                ║
║  │  /sdd:specifications-│──→ ├── DOMAIN-MODEL.md                                ║
║  │   engineer           │    ├── USE-CASES.md                                    ║
║  └────────┬────────────┘    ├── WORKFLOWS.md                                    ║
║           │                  ├── API-CONTRACTS.md                                 ║
║           ▼                  ├── NFR.md                                           ║
║  ┌─────────────────────┐    └── adr/ADR-*.md                                    ║
║  │  /sdd:spec-auditor   │──→ audits/AUDIT-BASELINE.md                            ║
║  │   (Mode Audit)       │    "¿Hay problemas en las specs?"                      ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐                                                         ║
║  │  /sdd:spec-auditor   │──→ spec/ corregido                                    ║
║  │   (Mode Fix)         │    "Corregir los problemas encontrados"                ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    test/                                                ║
║  │  /sdd:test-planner   │──→ ├── TEST-PLAN.md                                   ║
║  └────────┬────────────┘    ├── TEST-MATRIX-*.md                                ║
║           │                  └── PERF-SCENARIOS.md                                ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    plan/                                                ║
║  │  /sdd:plan-architect │──→ ├── PLAN.md                                         ║
║  └────────┬────────────┘    ├── ARCHITECTURE.md                                  ║
║           │                  └── fases/FASE-*.md                                  ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    task/                                                ║
║  │  /sdd:task-generator │──→ ├── TASK-FASE-01.md                                ║
║  └────────┬────────────┘    ├── TASK-FASE-02.md                                 ║
║           │                  └── TASK-INDEX.md                                    ║
║           ▼                                                                      ║
║  ┌─────────────────────┐                                                         ║
║  │  /sdd:task-           │──→ src/ + tests/ + git commits                        ║
║  │   implementer        │    "Código real, trazable y testeado"                  ║
║  └─────────────────────┘                                                         ║
║                                                                                  ║
║  ┌─ Herramientas laterales ──────────────────────────────────────────────┐       ║
║  │  /sdd:tech-designer       Diseño técnico (12 dimensiones)             │       ║
║  │  /sdd:ux-designer         Diseño UX (12 dimensiones, WCAG)            │       ║
║  │  /sdd:security-auditor    Auditoría de seguridad (OWASP)              │       ║
║  │  /sdd:req-change          Gestión de cambios con cascada              │       ║
║  └───────────────────────────────────────────────────────────────────────┘       ║
║                                                                                  ║
║  ┌─ Utilidades ──────────────────────────────────────────────────────────┐       ║
║  │  /sdd:pipeline-status     Estado actual del pipeline                  │       ║
║  │  /sdd:traceability-check  Verificar cadena de trazabilidad            │       ║
║  │  /sdd:dashboard           Dashboard HTML interactivo                  │       ║
║  │  /sdd:code-index          Indexar código para trazabilidad profunda   │       ║
║  │  /sdd:session-summary     Resumen de sesión                           │       ║
║  └───────────────────────────────────────────────────────────────────────┘       ║
║                                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════════╝
```

### Estado del pipeline

Cada paso tiene un estado que se rastrea automáticamente:

```
  pending ──→ running ──→ done ──→ stale ──→ running ──→ done
                                     ▲                      │
                                     │   (cambio upstream)   │
                                     └──────────────────────┘
```

- **pending** — Aún no se ha ejecutado
- **running** — En ejecución ahora mismo
- **done** — Completado exitosamente
- **stale** — Sus entradas cambiaron, necesita re-ejecutarse

> **Tip:** En cualquier momento puedes ejecutar `/sdd:pipeline-status` para ver
> en qué paso estás y qué deberías hacer a continuación.

---

## 4. Paso 1 — Requisitos

### ¿Qué hace este paso?

Transforma tu idea vaga en requisitos formales, claros y verificables.

```
┌──────────────────┐          ┌─────────────────────────────────────┐
│                  │          │  requirements/REQUIREMENTS.md        │
│  "Quiero una app │   ──→    │                                     │
│   de tareas"     │          │  REQ-001: WHEN a user creates a     │
│                  │          │  task THE system SHALL store it...   │
│                  │          │                                     │
└──────────────────┘          │  REQ-002: WHEN a user marks a task  │
    Tu idea                   │  as done THE system SHALL...        │
                              └─────────────────────────────────────┘
                                  Requisitos formales
```

### Cómo ejecutarlo

> **Idea clave:** Tú le das tu idea (con palabras normales, un documento, o lo que tengas),
> y el skill se encarga de convertirla en requisitos formales. No necesitas saber nada técnico.

#### Opción A: Solo tienes una idea en la cabeza

Simplemente escribe el comando y describe tu idea a continuación. Puede ser tan informal como quieras:

```
/sdd:requirements-engineer

Quiero hacer una app para gestionar tareas.
Los usuarios pueden crear tareas, marcarlas como completadas y eliminarlas.
Necesita login. Quiero que sea rápida.
```

Eso es todo. El skill toma tu descripción informal y empieza a trabajar.

#### Opción B: Tienes un documento con tus ideas

Si ya tienes un archivo con notas, requisitos preliminares, o cualquier documento
(un `.md`, un `.txt`, un `.docx` exportado a texto, lo que sea), díselo:

```
/sdd:requirements-engineer

Aquí están mis requisitos iniciales, están en el archivo docs/mi-idea.md
```

El skill leerá el archivo y lo usará como punto de partida.

#### Opción C: Tienes varias fuentes

Puedes darle todo lo que tengas — actas de reunión, correos, capturas, notas sueltas:

```
/sdd:requirements-engineer

Tengo varias fuentes:
- Un documento general en docs/proyecto.md
- Notas de una reunión en docs/notas-reunion.md
- Algunas ideas extra: quiero que tenga modo oscuro y notificaciones push
```

#### ¿Qué pasa después de ejecutarlo?

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Tú escribes tu idea          El skill te pregunta           Resultado│
│  (informal, como quieras)     lo que no entiende             final   │
│                                                                      │
│  "Quiero una app ──→  "¿Quiénes son los     ──→  requirements/      │
│   de tareas con         usuarios? ¿Solo            REQUIREMENTS.md   │
│   login y eso"          el dueño o también         (formal, con      │
│                         colaboradores?"             REQ-001, etc.)   │
│                                                                      │
│  Tú solo contestas     Él va preguntando           Tú no escribes    │
│  con palabras normales  hasta tener todo claro     el archivo final  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

> **Importante:** No tienes que dar toda la información perfecta de entrada.
> El skill va a ir preguntándote todo lo que necesita. Si no sabes algo,
> dile "no sé" o "tú decide" y te dará opciones para elegir.

### Lo que sucede

1. **Elicitación**: El skill te hace preguntas estructuradas para extraer requisitos:
   - ¿Quiénes son los usuarios?
   - ¿Qué problemas resuelve?
   - ¿Qué funcionalidades necesita?
   - ¿Hay restricciones técnicas?

2. **Formato EARS**: Cada requisito se escribe en formato EARS (Easy Approach to Requirements Syntax):

```
┌─────────────────────────────────────────────────────────────────────┐
│  Formato EARS                                                        │
│                                                                      │
│  WHEN <trigger>                                                      │
│  THE <system>                                                        │
│  SHALL <comportamiento obligatorio>                                  │
│                                                                      │
│  Ejemplo:                                                            │
│  ────────                                                            │
│  REQ-TASK-001                                                        │
│  WHEN a user submits a new task with title and description           │
│  THE system SHALL create the task with status "pending"              │
│  AND assign a unique identifier                                      │
│  AND return the created task to the user                             │
│                                                                      │
│  Acceptance Criteria:                                                │
│  Given a logged-in user                                              │
│  When they submit a task with title "Buy milk"                       │
│  Then the task is created with status "pending"                      │
│  And a unique ID is assigned (format: TASK-XXXX)                     │
└─────────────────────────────────────────────────────────────────────┘
```

3. **Clasificación**: Los requisitos se organizan por dominio y prioridad:

```
  ┌─────────────────────────────────────────────┐
  │  Requisitos                                  │
  │                                              │
  │  Funcionales (F)                             │
  │  ├── REQ-TASK-001  Crear tarea         P0   │
  │  ├── REQ-TASK-002  Listar tareas       P0   │
  │  ├── REQ-TASK-003  Completar tarea     P0   │
  │  ├── REQ-TASK-004  Eliminar tarea      P1   │
  │  └── REQ-TASK-005  Filtrar tareas      P2   │
  │                                              │
  │  No Funcionales (NF)                         │
  │  ├── REQ-PERF-001  Respuesta < 200ms   P0   │
  │  ├── REQ-SEC-001   Autenticación JWT   P0   │
  │  └── REQ-ACC-001   Responsive design   P1   │
  │                                              │
  │  P0 = Crítico  P1 = Importante  P2 = Deseable│
  └─────────────────────────────────────────────┘
```

### Archivo generado

```
requirements/
└── REQUIREMENTS.md
```

### Principio clave: "Nunca asumir, siempre preguntar"

El skill **nunca** inventa requisitos. Si algo no está claro, te presenta
opciones en una tabla estructurada para que tú decidas:

```
┌─────────────────────────────────────────────────────────────┐
│  Clarificación necesaria:                                    │
│                                                              │
│  ¿Cómo debe funcionar la autenticación?                      │
│                                                              │
│  │ Opción │ Descripción              │ Trade-off            │
│  │────────│──────────────────────────│──────────────────────│
│  │ A      │ JWT con refresh tokens   │ Más seguro, complejo │
│  │ B      │ Sesiones en servidor     │ Simple, más estado   │
│  │ C      │ OAuth con Google/GitHub  │ Delegado, dependencia│
│                                                              │
│  ¿Cuál prefieres? ─────────────────────────────              │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Paso 2 — Especificaciones

### ¿Qué hace este paso?

Transforma los requisitos en especificaciones técnicas formales que definen
*exactamente* cómo se comporta el sistema.

```
┌──────────────────────┐          ┌────────────────────────────────────┐
│  requirements/        │          │  spec/                              │
│  REQUIREMENTS.md      │   ──→    │  ├── DOMAIN-MODEL.md               │
│                       │          │  ├── USE-CASES.md                   │
│  (QUÉ necesita       │          │  ├── WORKFLOWS.md                   │
│   el usuario)        │          │  ├── API-CONTRACTS.md               │
│                       │          │  ├── NFR.md                         │
└──────────────────────┘          │  └── adr/                           │
                                  │      ├── ADR-001-auth-method.md     │
                                  │      └── ADR-002-database.md        │
                                  └────────────────────────────────────┘
                                      (CÓMO se comporta el sistema)
```

### Cómo ejecutarlo

```
/sdd:specifications-engineer
```

### Los 6 documentos que genera

#### 1. DOMAIN-MODEL.md — El modelo del dominio

Define las entidades, sus atributos y relaciones:

```
┌─────────────────────────────────────────────────────────────────┐
│                       MODELO DE DOMINIO                          │
│                                                                  │
│  ┌──────────┐     posee      ┌──────────┐     contiene         │
│  │   User   │───────────────▶│  TaskList │──────────────▶┐     │
│  │──────────│  1          *  │──────────│  1          *  │     │
│  │ id       │                │ id       │                │     │
│  │ email    │                │ name     │           ┌────┴───┐ │
│  │ name     │                │ ownerId  │           │  Task  │ │
│  └──────────┘                └──────────┘           │────────│ │
│                                                      │ id     │ │
│       ┌──────────┐                                   │ title  │ │
│       │   Tag    │◀──── tiene ──────────────────────│ status │ │
│       │──────────│  *          *                     │ dueDate│ │
│       │ id       │                                   └────────┘ │
│       │ name     │                                              │
│       │ color    │       Invariantes:                            │
│       └──────────┘       • INV-001: Task.status ∈ {pending,     │
│                                     in_progress, done}          │
│                          • INV-002: Task.title.length ∈ [1,200] │
│                          • INV-003: TaskList.owner = User.id    │
└─────────────────────────────────────────────────────────────────┘
```

#### 2. USE-CASES.md — Casos de uso

Describe cada interacción del usuario con el sistema:

```
┌─────────────────────────────────────────────────────────────────┐
│  UC-TASK-001: Crear tarea                                        │
│                                                                  │
│  Actor:    Usuario autenticado                                   │
│  Trigger:  Usuario envía formulario de nueva tarea               │
│  Refs:     REQ-TASK-001                                          │
│                                                                  │
│  Flujo principal:                                                │
│  1. Usuario completa título y descripción                        │
│  2. Sistema valida los datos (INV-002)                           │
│  3. Sistema crea tarea con status "pending" (INV-001)            │
│  4. Sistema asigna ID único                                      │
│  5. Sistema retorna tarea creada                                 │
│                                                                  │
│  Flujos alternativos:                                            │
│  2a. Título vacío → Error: "Title is required"                   │
│  2b. Título > 200 chars → Error: "Title too long"                │
│                                                                  │
│  BDD:                                                            │
│  Scenario: Create task successfully                              │
│    Given a logged-in user                                        │
│    When they submit title "Buy milk" and description "2% milk"   │
│    Then a task is created with status "pending"                   │
│    And the task has a unique ID matching /TASK-\d{4}/             │
└─────────────────────────────────────────────────────────────────┘
```

#### 3. WORKFLOWS.md — Flujos de trabajo

Secuencias paso a paso de operaciones:

```
┌─────────────────────────────────────────────────────────────────┐
│  WF-TASK-CREATE: Flujo de creación de tarea                      │
│                                                                  │
│  ┌────────┐    ┌──────────┐    ┌──────────┐    ┌────────────┐  │
│  │ Client │───▶│ Validate │───▶│  Create  │───▶│  Response  │  │
│  │ Request│    │  Input   │    │  Task    │    │  201/400   │  │
│  └────────┘    └──────────┘    └──────────┘    └────────────┘  │
│       │              │               │               │          │
│       │         Check INV-002   Assign UUID     Return JSON     │
│       │         Check auth      Set status      Include ID      │
│       ▼              ▼               ▼               ▼          │
│    POST /tasks   400 if invalid  Store in DB    { id, title,    │
│    { title,                                       status }      │
│      desc }                                                      │
└─────────────────────────────────────────────────────────────────┘
```

#### 4. API-CONTRACTS.md — Contratos de API

Definen los endpoints con total precisión:

```
┌─────────────────────────────────────────────────────────────────┐
│  API-TASK-001: POST /api/tasks                                   │
│  Refs: UC-TASK-001, WF-TASK-CREATE                               │
│                                                                  │
│  Request:                                                        │
│  {                                                               │
│    "title": string (1-200 chars, required),                      │
│    "description": string (0-2000 chars, optional),               │
│    "dueDate": ISO-8601 (optional, must be future)                │
│  }                                                               │
│                                                                  │
│  Response 201:                                                   │
│  {                                                               │
│    "id": "TASK-0001",                                            │
│    "title": "Buy milk",                                          │
│    "description": "2% milk",                                     │
│    "status": "pending",                                          │
│    "createdAt": "2026-03-02T10:00:00Z"                           │
│  }                                                               │
│                                                                  │
│  Response 400: { "error": "VALIDATION_ERROR", "details": [...] } │
│  Response 401: { "error": "UNAUTHORIZED" }                       │
└─────────────────────────────────────────────────────────────────┘
```

#### 5. NFR.md — Requisitos no funcionales

Performance, seguridad, accesibilidad:

```
┌─────────────────────────────────────────────────────────────────┐
│  NFR-PERF-001: Tiempo de respuesta                               │
│  Refs: REQ-PERF-001                                              │
│                                                                  │
│  • API responses: p95 < 200ms                                    │
│  • Page load: < 1.5s on 3G                                       │
│  • Database queries: < 50ms                                      │
│                                                                  │
│  Condiciones de medición:                                        │
│  • 100 usuarios concurrentes                                     │
│  • Base de datos con 10,000 tareas                               │
│  • Red: latencia 50ms                                            │
└─────────────────────────────────────────────────────────────────┘
```

#### 6. ADR (Architecture Decision Records)

Documenta cada decisión de diseño y *por qué* se tomó:

```
┌─────────────────────────────────────────────────────────────────┐
│  ADR-001: Método de autenticación                                │
│                                                                  │
│  Estado: Accepted                                                │
│  Fecha: 2026-03-02                                               │
│  Refs: REQ-SEC-001                                               │
│                                                                  │
│  Contexto:                                                       │
│  La app necesita autenticar usuarios para proteger sus tareas.   │
│                                                                  │
│  Decisión:                                                       │
│  Usar JWT con refresh tokens.                                    │
│                                                                  │
│  Alternativas consideradas:                                      │
│  • Sesiones en servidor — descartado por escalabilidad           │
│  • OAuth puro — descartado por complejidad para MVP              │
│                                                                  │
│  Consecuencias:                                                  │
│  (+) Stateless, escala horizontalmente                           │
│  (+) Standard de industria                                       │
│  (−) Necesita manejo de refresh tokens                           │
│  (−) Tokens pueden ser robados si no se protegen                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Paso 3 — Auditoría de especificaciones

### ¿Qué hace este paso?

Revisa las especificaciones buscando problemas: ambigüedades, contradicciones,
invariantes débiles, silencios peligrosos.

```
┌───────────────┐         ┌──────────────────────────────────────┐
│               │  Audit  │  audits/AUDIT-BASELINE.md             │
│    spec/      │──────▶  │                                      │
│               │         │  F-001 [P0] AMBIGUITY                │
│               │         │  UC-TASK-003 says "mark as done"     │
│               │         │  but doesn't specify what happens    │
│               │         │  to subtasks.                        │
│               │         │                                      │
│               │         │  F-002 [P1] DANGEROUS SILENCE        │
│               │         │  No spec for what happens when       │
│               │         │  a user deletes a task with          │
│               │         │  active subtasks.                    │
│               │  Fix    │                                      │
│               │◀────── │  F-003 [P2] WEAK INVARIANT           │
│  (corregido)  │         │  INV-002 doesn't specify Unicode     │
│               │         │  character handling for title length. │
└───────────────┘         └──────────────────────────────────────┘
```

### Cómo ejecutarlo

```
# Primero: auditar (encontrar problemas)
/sdd:spec-auditor

# Después: corregir (aplicar fixes)
# El skill te preguntará si quieres modo Audit o Fix
```

### Categorías de hallazgos

```
┌─────────────────────────────────────────────────────────────┐
│  Categorías de auditoría                                     │
│                                                              │
│  🔴 P0 — Bloqueante                                         │
│  │  CONTRADICTION    Dos specs se contradicen                │
│  │  AMBIGUITY        Spec interpretable de múltiples formas  │
│  │  MISSING_SPEC     Funcionalidad sin especificar           │
│                                                              │
│  🟠 P1 — Importante                                         │
│  │  DANGEROUS_SILENCE  Caso no cubierto que podría fallar    │
│  │  WEAK_INVARIANT     Regla de negocio incompleta           │
│                                                              │
│  🟡 P2 — Menor                                              │
│  │  INCONSISTENT_NAMING  Nombres diferentes para lo mismo    │
│  │  MISSING_BDD          Caso de uso sin escenario BDD       │
│                                                              │
│  ⚪ P3 — Informativo                                         │
│     STYLE_ISSUE        Formato o redacción mejorable         │
└─────────────────────────────────────────────────────────────┘
```

### Auditoría baseline vs incrementales

```
  Primera ejecución:                    Ejecuciones posteriores:

  ┌─────────────┐                       ┌─────────────┐
  │   spec/     │                       │   spec/     │
  │ (original)  │                       │(modificado) │
  └──────┬──────┘                       └──────┬──────┘
         │                                     │
         ▼                                     ▼
  ┌──────────────┐                      ┌──────────────┐
  │ AUDIT-       │                      │ Solo reporta │
  │ BASELINE.md  │                      │ NUEVOS       │
  │              │                      │ hallazgos y  │
  │ 15 findings  │                      │ REGRESIONES  │
  │ (F-001..F-015)│                     │              │
  └──────────────┘                      │ 3 nuevos     │
                                        │ 1 regresión  │
  Se crea el baseline                   └──────────────┘
  completo                              No repite los ya conocidos
```

---

## 7. Paso 4 — Plan de pruebas

### ¿Qué hace este paso?

Genera una estrategia de pruebas completa basada en las especificaciones.

```
┌───────────────┐         ┌──────────────────────────────────────┐
│  spec/        │         │  test/                                │
│  audits/      │──────▶  │  ├── TEST-PLAN.md                    │
│               │         │  │   Estrategia general de pruebas    │
│               │         │  │                                    │
│               │         │  ├── TEST-MATRIX-TASK.md              │
│               │         │  │   Matriz de pruebas por dominio    │
│               │         │  │                                    │
│               │         │  └── PERF-SCENARIOS.md                │
│               │         │      Escenarios de rendimiento        │
└───────────────┘         └──────────────────────────────────────┘
```

### Cómo ejecutarlo

```
/sdd:test-planner
```

### La matriz de pruebas

El plan genera una matriz que cruza requisitos con tipos de prueba:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  TEST MATRIX: Dominio Task                                               │
│                                                                          │
│              │ Unit  │ Integ. │ E2E   │ Perf  │ Sec   │ Coverage       │
│  ────────────│───────│────────│───────│───────│───────│────────────────│
│  UC-TASK-001 │ UT-01 │ IT-01  │ E2E-01│       │ ST-01 │ 4/5 = 80%    │
│  UC-TASK-002 │ UT-02 │ IT-02  │ E2E-02│       │       │ 3/5 = 60%    │
│  UC-TASK-003 │ UT-03 │ IT-03  │ E2E-03│       │       │ 3/5 = 60%    │
│  NFR-PERF-001│       │        │       │ PF-01 │       │ 1/5 = 20%    │
│  NFR-SEC-001 │       │        │       │       │ ST-02 │ 1/5 = 20%    │
│                                                                          │
│  Cobertura total: 12/25 celdas = 48%                                     │
│  Objetivo mínimo: 80% para P0, 60% para P1                              │
└─────────────────────────────────────────────────────────────────────────┘
```

### Escenarios de rendimiento

```
┌─────────────────────────────────────────────────────────────────┐
│  PERF-001: Carga de lista de tareas                              │
│  Refs: NFR-PERF-001, UC-TASK-002                                 │
│                                                                  │
│  Setup:                                                          │
│  • Base de datos con 10,000 tareas                               │
│  • 100 usuarios concurrentes                                     │
│  • Red: latencia 50ms simulada                                   │
│                                                                  │
│  Métricas esperadas:                                             │
│  ┌──────────────┬──────────┬──────────┬──────────┐              │
│  │ Métrica      │ Target   │ Warning  │ Fail     │              │
│  │──────────────│──────────│──────────│──────────│              │
│  │ p50 latency  │ < 100ms  │ < 150ms  │ ≥ 200ms  │              │
│  │ p95 latency  │ < 200ms  │ < 300ms  │ ≥ 500ms  │              │
│  │ p99 latency  │ < 500ms  │ < 800ms  │ ≥ 1000ms │              │
│  │ Error rate   │ < 0.1%   │ < 1%     │ ≥ 5%     │              │
│  └──────────────┴──────────┴──────────┴──────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Paso 5 — Arquitectura y plan de implementación

### ¿Qué hace este paso?

Diseña la arquitectura del sistema y divide la implementación en **fases** (FASEs)
ordenadas por dependencias.

```
┌───────────────┐         ┌──────────────────────────────────────┐
│  spec/        │         │  plan/                                │
│  audits/      │──────▶  │  ├── PLAN.md          Visión general │
│  test/        │         │  ├── ARCHITECTURE.md   Diagramas C4  │
│               │         │  └── fases/                           │
│               │         │      ├── FASE-01.md   Infraestructura│
│               │         │      ├── FASE-02.md   Modelo dominio │
│               │         │      ├── FASE-03.md   API core       │
│               │         │      └── FASE-04.md   UI             │
└───────────────┘         └──────────────────────────────────────┘
```

### Cómo ejecutarlo

```
/sdd:plan-architect
```

### Diagramas C4 (arquitectura por niveles)

El skill genera diagramas en 4 niveles de zoom:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Nivel 1: CONTEXTO (vista de pájaro)                                 │
│                                                                      │
│            ┌──────────┐                                              │
│            │  Usuario  │                                              │
│            └────┬─────┘                                              │
│                 │ usa                                                 │
│                 ▼                                                     │
│         ┌──────────────┐        ┌──────────────┐                     │
│         │  Task App    │───────▶│  Email Svc   │                     │
│         │  (nuestro    │        │  (externo)   │                     │
│         │   sistema)   │        └──────────────┘                     │
│         └──────────────┘                                             │
│                                                                      │
│  Nivel 2: CONTENEDORES (las piezas grandes)                          │
│                                                                      │
│         ┌──────────────────────────────────┐                         │
│         │           Task App               │                         │
│         │                                  │                         │
│         │  ┌──────────┐  ┌──────────────┐  │                         │
│         │  │  React   │  │  Node.js     │  │                         │
│         │  │  SPA     │──│  API Server  │  │                         │
│         │  └──────────┘  └──────┬───────┘  │                         │
│         │                       │          │                         │
│         │                ┌──────┴───────┐  │                         │
│         │                │  PostgreSQL  │  │                         │
│         │                │  Database    │  │                         │
│         │                └──────────────┘  │                         │
│         └──────────────────────────────────┘                         │
│                                                                      │
│  Nivel 3: COMPONENTES (dentro de un contenedor)                      │
│  Nivel 4: CÓDIGO (clases y funciones)                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Las FASEs

Cada FASE agrupa funcionalidades que se pueden construir juntas:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  FASE-01: Infraestructura        FASE-02: Modelo de dominio         │
│  ┌─────────────────────────┐     ┌─────────────────────────┐        │
│  │ • Setup proyecto         │     │ • Entidades: Task, User │        │
│  │ • Config TypeScript      │     │ • Repositorios           │        │
│  │ • Config testing         │────▶│ • Validaciones (INV-*)   │        │
│  │ • Config linter          │     │ • Migraciones BD         │        │
│  │ • CI/CD básico           │     └───────────┬─────────────┘        │
│  └─────────────────────────┘                  │                      │
│                                               ▼                      │
│  FASE-03: API Core               FASE-04: UI                        │
│  ┌─────────────────────────┐     ┌─────────────────────────┐        │
│  │ • Endpoints CRUD         │     │ • Componentes React      │        │
│  │ • Autenticación JWT      │────▶│ • Páginas                │        │
│  │ • Middleware validación   │     │ • Integración API        │        │
│  │ • Manejo de errores      │     │ • Tests E2E              │        │
│  └─────────────────────────┘     └─────────────────────────┘        │
│                                                                      │
│  Dependencias: FASE-01 → FASE-02 → FASE-03 → FASE-04               │
│  (cada fase depende de la anterior)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Paso 6 — Generación de tareas

### ¿Qué hace este paso?

Descompone cada FASE en **tareas atómicas**: cada tarea es un commit,
con su mensaje predefinido, su estrategia de rollback, y su trazabilidad.

```
┌───────────────┐         ┌──────────────────────────────────────┐
│  plan/        │         │  task/                                │
│  fases/       │──────▶  │  ├── TASK-FASE-01.md                 │
│  FASE-01.md   │         │  │   T-F01-01: Init project          │
│  FASE-02.md   │         │  │   T-F01-02: Config TypeScript     │
│  ...          │         │  │   T-F01-03: Config testing        │
│               │         │  │                                    │
│               │         │  ├── TASK-FASE-02.md                 │
│               │         │  │   T-F02-01: Create Task entity    │
│               │         │  │   T-F02-02: Create User entity    │
│               │         │  │   ...                              │
│               │         │  │                                    │
│               │         │  ├── TASK-INDEX.md                   │
│               │         │  │   Índice global de todas las tareas│
│               │         │  │                                    │
│               │         │  └── TASK-ORDER.md                   │
│               │         │      Orden de ejecución               │
└───────────────┘         └──────────────────────────────────────┘
```

### Cómo ejecutarlo

```
/sdd:task-generator
```

### Anatomía de una tarea

```
┌─────────────────────────────────────────────────────────────────────┐
│  T-F02-01: Crear entidad Task                                        │
│                                                                      │
│  FASE: 02 — Modelo de dominio                                        │
│  Refs: UC-TASK-001, DOMAIN-MODEL Task entity, INV-001, INV-002      │
│                                                                      │
│  Descripción:                                                        │
│  Crear la entidad Task con sus propiedades, validaciones             │
│  e invariantes según el modelo de dominio.                           │
│                                                                      │
│  Archivos a crear/modificar:                                         │
│  • src/domain/entities/task.ts           (CREATE)                    │
│  • tests/domain/entities/task.test.ts    (CREATE)                    │
│  • src/domain/types.ts                   (MODIFY — add TaskStatus)   │
│                                                                      │
│  Tests primero (TDD):                                                │
│  1. should create task with valid title                              │
│  2. should reject empty title (INV-002)                              │
│  3. should reject title > 200 chars (INV-002)                        │
│  4. should default status to "pending" (INV-001)                     │
│  5. should assign unique ID                                          │
│                                                                      │
│  Commit predefinido:                                                 │
│  feat(domain): add Task entity with validation                       │
│                                                                      │
│  Refs: UC-TASK-001, INV-001, INV-002                                 │
│  Task: T-F02-01                                                      │
│                                                                      │
│  Estrategia de rollback: SAFE                                        │
│  (Archivos nuevos, se eliminan sin afectar nada)                     │
│                                                                      │
│  Dependencias: T-F01-03 (testing config must exist)                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Estrategias de rollback

```
┌──────────────────────────────────────────────────────────────┐
│  Estrategias de Rollback                                      │
│                                                               │
│  SAFE       Archivos nuevos → simplemente eliminar            │
│             git revert es suficiente                           │
│                                                               │
│  COUPLED    Cambios que afectan otros archivos                │
│             Revert coordinado con tareas dependientes          │
│                                                               │
│  MIGRATION  Cambios de base de datos                          │
│             Incluye migration down script                      │
│                                                               │
│  CONFIG     Cambios de configuración                          │
│             Documentar valores anteriores para restaurar       │
└──────────────────────────────────────────────────────────────┘
```

---

## 10. Paso 7 — Implementación

### ¿Qué hace este paso?

Implementa las tareas una a una, siguiendo TDD (Test-Driven Development),
creando commits atómicos con trazabilidad completa.

```
┌───────────────┐         ┌──────────────────────────────────────┐
│  task/        │         │  Resultado:                           │
│  TASK-FASE-   │──────▶  │                                      │
│  01.md        │         │  src/                                 │
│               │         │  ├── domain/entities/task.ts          │
│  spec/        │         │  ├── domain/entities/user.ts          │
│  (referencia) │         │  ├── api/routes/tasks.ts              │
│               │         │  └── ...                              │
│  plan/        │         │                                      │
│  (referencia) │         │  tests/                               │
│               │         │  ├── domain/entities/task.test.ts     │
│               │         │  ├── api/routes/tasks.test.ts         │
│               │         │  └── ...                              │
│               │         │                                      │
│               │         │  Git log:                              │
│               │         │  abc1234 feat(domain): add Task entity│
│               │         │  def5678 feat(domain): add User entity│
│               │         │  ghi9012 feat(api): add POST /tasks   │
│               │         │  ...                                  │
└───────────────┘         └──────────────────────────────────────┘
```

### Cómo ejecutarlo

```
/sdd:task-implementer
```

### El ciclo TDD por tarea

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│   Para cada tarea (T-FXX-YY):                                        │
│                                                                      │
│   ┌─────────────┐                                                    │
│   │ 1. RED      │  Escribir tests que FALLAN                         │
│   │    🔴       │  (basados en los BDD scenarios de la spec)         │
│   └──────┬──────┘                                                    │
│          │                                                           │
│          ▼                                                           │
│   ┌─────────────┐                                                    │
│   │ 2. GREEN    │  Escribir el código MÍNIMO para pasar              │
│   │    🟢       │  (implementar según la spec, no más)               │
│   └──────┬──────┘                                                    │
│          │                                                           │
│          ▼                                                           │
│   ┌─────────────┐                                                    │
│   │ 3. REFACTOR │  Mejorar el código sin cambiar comportamiento      │
│   │    🔵       │  (clean code, nombres claros)                      │
│   └──────┬──────┘                                                    │
│          │                                                           │
│          ▼                                                           │
│   ┌─────────────┐                                                    │
│   │ 4. COMMIT   │  git commit con mensaje predefinido                │
│   │    ✅       │  + trailers de trazabilidad                        │
│   └─────────────┘                                                    │
│                                                                      │
│   Formato del commit:                                                │
│   ──────────────────                                                 │
│   feat(domain): add Task entity with validation                      │
│                                                                      │
│   Implement Task entity with title validation (1-200 chars)          │
│   and default pending status per domain model.                       │
│                                                                      │
│   Refs: UC-TASK-001, INV-001, INV-002                                │
│   Task: T-F02-01                                                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Verificación post-implementación

Después de implementar cada FASE, el skill verifica:

```
┌─────────────────────────────────────────────────────────────────┐
│  Verificación FASE-02                                            │
│                                                                  │
│  ✅ Todos los tests pasan (12/12)                                │
│  ✅ Cada tarea tiene exactamente 1 commit                        │
│  ✅ Todos los commits tienen trailers Refs: y Task:              │
│  ✅ Cobertura de código: 94% (objetivo: 80%)                     │
│  ✅ No hay archivos sin trazar                                   │
│  ⚠️  T-F02-03 requirió un cambio adicional a task.ts             │
│     (documentado en feedback/FEEDBACK-F02-03.md)                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 11. Herramientas laterales

Las herramientas laterales se pueden ejecutar en **cualquier momento** del pipeline.
No tienen un orden fijo — úsalas cuando las necesites.

### Diseño técnico (recomendado antes de plan-architect)

```
/sdd:tech-designer
```

Explora 12 dimensiones de arquitectura técnica y genera decisiones documentadas:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Tech Designer — 12 Dimensiones                                      │
│                                                                      │
│  1. Canales de entrega     (web, mobile, API, CLI)                  │
│  2. Estilo de arquitectura (monolito, microservicios, serverless)   │
│  3. Stack tecnológico      (lenguaje, framework, runtime)           │
│  4. Estrategia de datos    (SQL, NoSQL, caché, migrations)          │
│  5. Autenticación/Autoriz. (JWT, OAuth, RBAC, ABAC)                │
│  6. API design             (REST, GraphQL, gRPC, WebSocket)         │
│  7. Infraestructura        (cloud, containers, CDN)                 │
│  8. CI/CD                  (pipeline, deploy, rollback)             │
│  9. Observabilidad         (logs, metrics, tracing, alerting)       │
│ 10. Costos                 (estimación, optimización)               │
│ 11. Developer Experience   (DX, tooling, onboarding)                │
│ 12. i18n/l10n              (idiomas, formatos, timezones)           │
│                                                                      │
│  Salida:                                                             │
│  design/                                                             │
│  ├── TECHNICAL-DESIGN.md        ← Decisiones por dimensión          │
│  ├── QUALITY-ATTRIBUTES.md      ← ATAM-lite (trade-offs)            │
│  └── ADR-DRAFT-*.md             ← Borradores de ADRs                │
│                                                                      │
│  Tip: Si ejecutas esto ANTES de /sdd:plan-architect,                │
│  el arquitecto consumirá automáticamente tus decisiones.            │
└─────────────────────────────────────────────────────────────────────┘
```

### Diseño UX (recomendado antes de plan-architect)

```
/sdd:ux-designer
```

Define el sistema de diseño visual y de interacción en 12 dimensiones:

```
┌─────────────────────────────────────────────────────────────────────┐
│  UX Designer — 12 Dimensiones                                        │
│                                                                      │
│  1. Identidad de marca     (colores, tipografía, voz)               │
│  2. Design tokens          (variables reutilizables)                │
│  3. Componentes            (Atomic Design: atoms→organisms)         │
│  4. Responsive             (breakpoints, mobile-first)              │
│  5. Accesibilidad          (WCAG 2.1 AA, ARIA, contraste)          │
│  6. Interacción            (animaciones, feedback, estados)         │
│  7. Formularios            (validación, errores, UX)                │
│  8. Navegación             (IA, rutas, breadcrumbs)                 │
│  9. Seguridad frontend     (CSP, XSS, CSRF visual)                 │
│ 10. Performance            (Core Web Vitals, lazy loading)          │
│ 11. Mobile                 (touch, gestos, PWA)                     │
│ 12. Temas                  (dark mode, theming)                     │
│                                                                      │
│  Salida:                                                             │
│  ux/                                                                 │
│  ├── UI-DESIGN-SYSTEM.md        ← Sistema de diseño completo        │
│  ├── WIREFRAMES.md              ← Wireframes ASCII + descripción    │
│  ├── ACCESSIBILITY-SPEC.md      ← Especificación WCAG               │
│  ├── INTERACTION-MODEL.md       ← Modelo de interacción             │
│  └── DESIGN-TOKENS.json         ← Tokens exportables                │
│                                                                      │
│  Tip: Si ejecutas esto ANTES de /sdd:plan-architect,                │
│  el arquitecto integrará tu diseño en las fases.                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Auditoría de seguridad

Ejecutar en cualquier momento para evaluar la postura de seguridad:

```
/sdd:security-auditor
```

```
┌─────────────────────────────────────────────────────────────────────┐
│  Auditoría de Seguridad (OWASP ASVS v4)                             │
│                                                                      │
│  Scorecard (10 dimensiones):                                         │
│                                                                      │
│  Autenticación     ████████░░  8/10                                  │
│  Autorización      ██████░░░░  6/10                                  │
│  Sesiones          ████████░░  8/10                                  │
│  Validación input  ██████████  10/10                                 │
│  Criptografía      ████████░░  8/10                                  │
│  Manejo errores    ██████░░░░  6/10                                  │
│  Logging           ████░░░░░░  4/10                                  │
│  Protección datos  ████████░░  8/10                                  │
│  Comunicación      ██████████  10/10                                 │
│  Config seguridad  ██████░░░░  6/10                                  │
│                                                                      │
│  Score total: 74/100                                                 │
│  Nivel: B (Bueno, con mejoras necesarias)                            │
│                                                                      │
│  Hallazgos críticos:                                                 │
│  • SEC-F-001 [P0]: Falta rate limiting en login endpoint             │
│  • SEC-F-002 [P1]: Logs no sanitizan datos personales                │
└─────────────────────────────────────────────────────────────────────┘
```

### Gestión de cambios

Cuando necesitas cambiar un requisito después de que el pipeline ya avanzó:

```
/sdd:req-change
```

```
┌─────────────────────────────────────────────────────────────────────┐
│  Cambio de Requisito: REQ-TASK-001                                   │
│                                                                      │
│  Tipo: MODIFY                                                        │
│  Clasificación ISO 14764: Perfective (mejora)                        │
│                                                                      │
│  Cambio solicitado:                                                  │
│  "Las tareas ahora pueden tener prioridad (high/medium/low)"        │
│                                                                      │
│  Análisis de impacto:                                                │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │                                                           │       │
│  │  REQ-TASK-001 ──▶ UC-TASK-001 ──▶ WF-TASK-CREATE        │       │
│  │       │                │               │                  │       │
│  │       ▼                ▼               ▼                  │       │
│  │  DOMAIN-MODEL    API-CONTRACTS    WORKFLOWS              │       │
│  │  (add priority   (add priority    (add priority          │       │
│  │   to Task)        to request)      selection step)       │       │
│  │       │                │               │                  │       │
│  │       ▼                ▼               ▼                  │       │
│  │  TEST-MATRIX     TASK-FASE-02     TASK-FASE-03           │       │
│  │  (add tests)     (new task)       (modify task)          │       │
│  │                                                           │       │
│  └──────────────────────────────────────────────────────────┘       │
│                                                                      │
│  Artefactos afectados: 8                                             │
│  Cascada: spec-auditor → test-planner → task-generator               │
│                                                                      │
│  ¿Ejecutar cascada automática? [auto/manual/dry-run]                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 12. Herramientas de utilidad

### Estado del pipeline

```
/sdd:pipeline-status
```

```
┌─────────────────────────────────────────────────────────────────┐
│  Pipeline Status                                                 │
│                                                                  │
│  requirements-engineer    ████████████  done    2026-03-02       │
│  specifications-engineer  ████████████  done    2026-03-02       │
│  spec-auditor             ████████████  done    2026-03-02       │
│  test-planner             ████████████  done    2026-03-02       │
│  plan-architect           ████████░░░░  done    2026-03-02       │
│  task-generator           ██████░░░░░░  stale   ← spec cambió   │
│  task-implementer         ░░░░░░░░░░░░  pending                  │
│                                                                  │
│  Siguiente acción recomendada:                                   │
│  → Re-ejecutar /sdd:task-generator (inputs han cambiado)         │
└─────────────────────────────────────────────────────────────────┘
```

### Verificación de trazabilidad

```
/sdd:traceability-check
```

```
┌─────────────────────────────────────────────────────────────────┐
│  Traceability Check                                              │
│                                                                  │
│  Chain: REQ → UC → WF → API → BDD → INV → ADR                   │
│                                                                  │
│  REQ-TASK-001  ✅ UC-TASK-001 ✅ WF-TASK-CREATE ✅ API-TASK-001  │
│  REQ-TASK-002  ✅ UC-TASK-002 ✅ WF-TASK-LIST   ✅ API-TASK-002  │
│  REQ-TASK-003  ✅ UC-TASK-003 ⚠️ WF missing!    ── ──           │
│  REQ-SEC-001   ✅ UC-AUTH-001 ✅ WF-AUTH-LOGIN  ✅ API-AUTH-001  │
│                                                                  │
│  Problemas encontrados:                                          │
│  ⚠️ REQ-TASK-003 → UC-TASK-003: Missing workflow WF-TASK-DONE   │
│  ⚠️ ADR-002 no está referenciado por ningún UC                   │
│                                                                  │
│  Cobertura: 92% (23/25 links verificados)                        │
└─────────────────────────────────────────────────────────────────┘
```

### Dashboard visual

```
/sdd:dashboard
```

Genera un archivo HTML interactivo que puedes abrir en el navegador:

```
┌─────────────────────────────────────────────────────────────────┐
│  Dashboard generado:                                             │
│                                                                  │
│  dashboard/                                                      │
│  ├── index.html               ← Abrir en el navegador           │
│  ├── guide.html               ← Guía interactiva                │
│  ├── traceability-graph.json  ← Datos del grafo                 │
│  └── live-status.js           ← Estado en tiempo real            │
│                                                                  │
│  5 vistas disponibles:                                           │
│  1. Resumen ejecutivo     (health score, métricas clave)         │
│  2. Trazabilidad          (grafo interactivo)                    │
│  3. Cobertura             (gaps analysis)                        │
│  4. Pipeline              (estado de cada paso)                  │
│  5. Adopción              (progreso de adopción SDD)             │
│                                                                  │
│  Dos formas de usarlo:                                           │
│  • Abrir index.html directamente (funciona sin servidor)         │
│  • Usar el dashboard server para actualizaciones en vivo (SSE)  │
└─────────────────────────────────────────────────────────────────┘
```

**Opcional — Dashboard server con actualizaciones en vivo:**

Si quieres que el dashboard se actualice en tiempo real mientras trabajas
(sin tener que regenerarlo), puedes levantar el servidor:

```bash
# Busca la ruta del plugin
# En Mac/Linux:
node "$SDD_PLUGIN_ROOT/server/dist/server.js"   # SDD_PLUGIN_ROOT lo exporta el hook SessionStart del plugin

# El server arranca en http://localhost:3001
# SSE stream en http://localhost:3001/events
```

El dashboard detecta automáticamente si está servido por HTTP (usa SSE en vivo)
o abierto como archivo local (usa JSONP polling).

### Code intelligence

```
/sdd:code-index
```

Indexa tu código fuente y lo conecta con los artefactos SDD. Si tienes
**GitNexus** instalado (`npm i -g gitnexus`), genera un análisis profundo
con call graph, clusters y flujos de ejecución:

```
┌─────────────────────────────────────────────────────────────────┐
│  Code Intelligence                                               │
│                                                                  │
│  Sin GitNexus (modo básico):                                     │
│  • Escanea símbolos (funciones, clases, tipos)                  │
│  • Mapea commits con Refs:/Task: trailers a artefactos          │
│  • Enriquece traceability-graph.json con codeRefs               │
│                                                                  │
│  Con GitNexus (modo completo):                                   │
│  • Todo lo anterior +                                            │
│  • Call graph (quién llama a quién)                              │
│  • Clusters de código relacionado                                │
│  • Flujos de ejecución (execution flows)                        │
│  • Commit-symbol bridge (a nivel de función, no de archivo)     │
│                                                                  │
│  Ejecútalo después de implementar para ver:                     │
│  • Qué código implementa cada requisito                         │
│  • Blast radius: si cambias X, qué se afecta                   │
│  • Cobertura por origen: linked / inferred / uncovered          │
└─────────────────────────────────────────────────────────────────┘
```

### Resumen de sesión

```
/sdd:session-summary
```

Resume las decisiones tomadas durante la sesión actual,
separando el contexto formal (decisiones documentadas en artefactos)
del informal (preferencias, decisiones aplazadas).

---

## 13. Iteración y gestión de cambios

### El ciclo de vida del proyecto

SDD no es un proceso waterfall. Es un pipeline que puedes **iterar**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  Iteración típica de un proyecto SDD:                                │
│                                                                      │
│  Sprint 1: MVP                                                       │
│  ┌───────────────────────────────────────────┐                      │
│  │ REQ → SPEC → AUDIT → TEST → PLAN → TASK → IMPL                  │
│  │ (Pipeline completo, funcionalidad core)    │                      │
│  └───────────────────────────────────────────┘                      │
│                         │                                            │
│                         ▼                                            │
│  Sprint 2: Nuevas features                                           │
│  ┌───────────────────────────────────────────┐                      │
│  │ /sdd:req-change (ADD nuevos requisitos)    │                      │
│  │      ↓ cascada automática                  │                      │
│  │ SPEC → AUDIT → TEST → PLAN → TASK → IMPL  │                      │
│  └───────────────────────────────────────────┘                      │
│                         │                                            │
│                         ▼                                            │
│  Sprint 3: Bug fixes + mejoras                                       │
│  ┌───────────────────────────────────────────┐                      │
│  │ /sdd:req-change (MODIFY requisitos)        │                      │
│  │      ↓ cascada selectiva                   │                      │
│  │ Solo los artefactos afectados se actualizan│                      │
│  └───────────────────────────────────────────┘                      │
│                         │                                            │
│                         ▼                                            │
│  Continuo: Verificación                                              │
│  ┌───────────────────────────────────────────┐                      │
│  │ /sdd:pipeline-status                       │                      │
│  │ /sdd:traceability-check                    │                      │
│  │ /sdd:security-auditor                      │                      │
│  │ /sdd:dashboard                             │                      │
│  └───────────────────────────────────────────┘                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### ¿Qué hacer cuando algo cambia?

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ¿Cambio en requisitos?                                              │
│  └──→ /sdd:req-change                                                │
│       Propaga automáticamente a specs, tests, plan, tasks            │
│                                                                      │
│  ¿Nuevo hallazgo de seguridad?                                       │
│  └──→ /sdd:security-auditor                                          │
│       Genera hallazgos → pueden convertirse en req-change            │
│                                                                      │
│  ¿El código se alejó de las specs?                                   │
│  └──→ /sdd:reconcile                                                 │
│       Detecta drift y propone correcciones                           │
│                                                                      │
│  ¿Pipeline roto o confuso?                                           │
│  └──→ /sdd:pipeline-status                                           │
│       Te dice exactamente qué paso ejecutar                          │
│                                                                      │
│  ¿Trazabilidad rota?                                                 │
│  └──→ /sdd:traceability-check                                        │
│       Encuentra links rotos y huérfanos                              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Regla de propagación de cambios

Cuando modificas un artefacto, los artefactos *downstream* se vuelven "stale":

```
  Modificas requirements/ ?
  ┌────────────────────────────────────────────────────────────┐
  │  specifications-engineer  → stale (debe re-ejecutarse)     │
  │  spec-auditor             → stale                          │
  │  test-planner             → stale                          │
  │  plan-architect           → stale                          │
  │  task-generator           → stale                          │
  │  task-implementer         → stale                          │
  └────────────────────────────────────────────────────────────┘

  Modificas spec/ ?
  ┌────────────────────────────────────────────────────────────┐
  │  spec-auditor             → stale                          │
  │  test-planner             → stale                          │
  │  plan-architect           → stale                          │
  │  task-generator           → stale                          │
  │  task-implementer         → stale                          │
  └────────────────────────────────────────────────────────────┘

  Modificas plan/ ?
  ┌────────────────────────────────────────────────────────────┐
  │  task-generator           → stale                          │
  │  task-implementer         → stale                          │
  └────────────────────────────────────────────────────────────┘

  Modificas task/ ?
  ┌────────────────────────────────────────────────────────────┐
  │  task-implementer         → stale                          │
  └────────────────────────────────────────────────────────────┘
```

---

## 14. Ejemplo completo: App de gestión de tareas

Veamos un ejemplo real de principio a fin, creando una aplicación de gestión
de tareas.

### Paso 0: Crear el proyecto

```bash
mkdir mi-task-app
cd mi-task-app
git init
claude   # Abrir Claude Code
```

```
/sdd:setup
```

### Paso 1: Requisitos

```
/sdd:requirements-engineer
```

Le dices a Claude:

> "Quiero una app web de gestión de tareas. Los usuarios pueden crear tareas
> con título, descripción y fecha límite. Pueden marcar tareas como completadas,
> filtrar por estado, y cada usuario solo ve sus propias tareas. Necesita
> autenticación."

El skill te hace preguntas de clarificación y genera:

```
mi-task-app/
├── pipeline-state.json         ← requirements-engineer: done
└── requirements/
    └── REQUIREMENTS.md         ← 12 requisitos formales (EARS)
```

### Paso 2: Especificaciones

```
/sdd:specifications-engineer
```

Lee los requisitos y genera especificaciones completas:

```
mi-task-app/
├── pipeline-state.json         ← specifications-engineer: done
├── requirements/
│   └── REQUIREMENTS.md
└── spec/
    ├── DOMAIN-MODEL.md         ← Entidades: User, Task, TaskList
    ├── USE-CASES.md            ← 8 casos de uso
    ├── WORKFLOWS.md            ← 6 flujos de trabajo
    ├── API-CONTRACTS.md        ← 10 endpoints
    ├── NFR.md                  ← Rendimiento, seguridad, accesibilidad
    └── adr/
        ├── ADR-001-jwt-auth.md
        ├── ADR-002-postgresql.md
        └── ADR-003-react-spa.md
```

### Paso 3: Auditoría

```
/sdd:spec-auditor
```

Encuentra 5 problemas, los corriges:

```
mi-task-app/
├── audits/
│   └── AUDIT-BASELINE.md      ← 5 hallazgos (3 corregidos, 2 aceptados)
└── spec/                       ← Corregido con Mode Fix
```

### Paso 4: Plan de pruebas

```
/sdd:test-planner
```

```
mi-task-app/
└── test/
    ├── TEST-PLAN.md            ← Estrategia: unit + integration + E2E
    ├── TEST-MATRIX-TASK.md     ← 24 tests planificados
    ├── TEST-MATRIX-AUTH.md     ← 12 tests planificados
    └── PERF-SCENARIOS.md       ← 4 escenarios de rendimiento
```

### Paso 4b (opcional): Diseño técnico y UX

Antes de la arquitectura, puedes explorar decisiones técnicas y de diseño visual.
Esto es **opcional pero recomendado** — el plan-architect los consumirá automáticamente:

```
/sdd:tech-designer
```

```
mi-task-app/
└── design/
    ├── TECHNICAL-DESIGN.md     ← Stack: Next.js + PostgreSQL + JWT
    ├── QUALITY-ATTRIBUTES.md   ← Trade-offs documentados
    └── ADR-DRAFT-001.md        ← Borrador: ¿por qué Next.js?
```

```
/sdd:ux-designer
```

```
mi-task-app/
└── ux/
    ├── UI-DESIGN-SYSTEM.md     ← Componentes, colores, tipografía
    ├── WIREFRAMES.md           ← Wireframes ASCII de cada pantalla
    ├── ACCESSIBILITY-SPEC.md   ← WCAG 2.1 AA
    ├── INTERACTION-MODEL.md    ← Estados, animaciones, feedback
    └── DESIGN-TOKENS.json      ← Tokens exportables a CSS/Tailwind
```

### Paso 5: Arquitectura

```
/sdd:plan-architect
```

Si ejecutaste tech-designer y/o ux-designer, el arquitecto los consume automáticamente
en su Phase 0 y los integra en las fases:

```
mi-task-app/
└── plan/
    ├── PLAN.md                 ← Visión general: 4 fases, ~3 semanas
    ├── ARCHITECTURE.md         ← C4: React + Node + PostgreSQL
    └── fases/
        ├── FASE-01.md          ← Infraestructura (8 tareas)
        ├── FASE-02.md          ← Modelo dominio (6 tareas)
        ├── FASE-03.md          ← API core (10 tareas)
        └── FASE-04.md          ← UI (12 tareas)
```

### Paso 6: Tareas

```
/sdd:task-generator
```

```
mi-task-app/
└── task/
    ├── TASK-FASE-01.md         ← 8 tareas atómicas
    ├── TASK-FASE-02.md         ← 6 tareas atómicas
    ├── TASK-FASE-03.md         ← 10 tareas atómicas
    ├── TASK-FASE-04.md         ← 12 tareas atómicas
    ├── TASK-INDEX.md           ← Índice: 36 tareas total
    └── TASK-ORDER.md           ← Orden de ejecución
```

### Paso 7: Implementación

```
/sdd:task-implementer
```

El skill implementa tarea por tarea (puedes ir FASE por FASE):

```
mi-task-app/
├── src/
│   ├── domain/
│   │   ├── entities/task.ts
│   │   ├── entities/user.ts
│   │   └── types.ts
│   ├── api/
│   │   ├── routes/tasks.ts
│   │   ├── routes/auth.ts
│   │   └── middleware/
│   ├── ui/
│   │   ├── components/
│   │   └── pages/
│   └── config/
├── tests/
│   ├── domain/
│   ├── api/
│   └── e2e/
├── package.json
├── tsconfig.json
└── ... (36 commits trazables)
```

### Verificación final

```
/sdd:traceability-check    ← Todo conectado ✅
/sdd:dashboard             ← Dashboard HTML generado
/sdd:code-index            ← (opcional) Indexar código para blast radius
/sdd:pipeline-status       ← Todos los pasos: done ✅
```

### Estructura final del proyecto

```
mi-task-app/
├── pipeline-state.json
├── requirements/
│   └── REQUIREMENTS.md
├── spec/
│   ├── DOMAIN-MODEL.md
│   ├── USE-CASES.md
│   ├── WORKFLOWS.md
│   ├── API-CONTRACTS.md
│   ├── NFR.md
│   └── adr/ADR-*.md
├── audits/
│   └── AUDIT-BASELINE.md
├── test/
│   ├── TEST-PLAN.md
│   ├── TEST-MATRIX-*.md
│   └── PERF-SCENARIOS.md
├── design/                       ← (opcional) Tech Designer
│   ├── TECHNICAL-DESIGN.md
│   └── QUALITY-ATTRIBUTES.md
├── ux/                           ← (opcional) UX Designer
│   ├── UI-DESIGN-SYSTEM.md
│   ├── WIREFRAMES.md
│   └── DESIGN-TOKENS.json
├── plan/
│   ├── PLAN.md
│   ├── ARCHITECTURE.md
│   └── fases/FASE-*.md
├── task/
│   ├── TASK-FASE-*.md
│   ├── TASK-INDEX.md
│   └── TASK-ORDER.md
├── dashboard/
│   ├── index.html
│   ├── guide.html
│   └── traceability-graph.json
├── code-intelligence/            ← (opcional) Code Index
│   └── CODE-INDEX-REPORT.md
├── src/                          ← Código implementado
├── tests/                        ← Tests automatizados
├── package.json
└── tsconfig.json
```

---

## 15. Preguntas frecuentes

### ¿Puedo saltar pasos?

**No se recomienda.** Cada paso construye sobre el anterior. Si saltas la
auditoría, podrías implementar specs con errores. Si saltas el plan de pruebas,
no sabrás qué testear.

Sin embargo, puedes ejecutar `/sdd:pipeline-status` para ver qué pasos
ya están completos y retomar desde donde te quedaste.

### ¿Puedo usar SDD en un proyecto existente?

**Sí.** Usa las herramientas de onboarding:

```
/sdd:onboarding           ← Diagnostica tu proyecto
                              y te recomienda el camino

/sdd:reverse-engineer      ← Genera artefactos SDD desde código existente
/sdd:reconcile            ← Alinea specs existentes con el código
/sdd:import               ← Importa docs externos (Jira, Notion, etc.)
```

### ¿Es mucho overhead para un proyecto pequeño?

SDD escala con el proyecto. Para un proyecto pequeño, los pasos se ejecutan
rápido y generan artefactos concisos. El beneficio es que incluso proyectos
pequeños quedan bien documentados y trazables.

Para algo **muy** simple (un script de 50 líneas), probablemente no necesites SDD.
Para cualquier cosa que tenga múltiples entidades, API, o más de un desarrollador,
SDD ahorra tiempo a mediano plazo.

### ¿Cómo manejo múltiples sprints?

1. **Sprint 1:** Pipeline completo (REQ → IMPL)
2. **Sprint N:** `/sdd:req-change` para agregar/modificar requisitos
   con cascada automática al resto del pipeline

### ¿Puedo usar SDD con cualquier lenguaje o framework?

**Sí.** SDD define *qué* construir y *cómo* verificarlo. El skill
`task-implementer` genera código en el lenguaje y framework que tu
proyecto use (TypeScript, Python, Go, React, Vue, etc.).

### ¿Qué pasa si Claude se equivoca en una spec?

El ciclo de auditoría (`spec-auditor`) existe precisamente para eso.
Además, el principio "nunca asumir, siempre preguntar" significa que
Claude te consultará antes de tomar decisiones ambiguas.

Si encuentras un error después de implementar, usa `/sdd:req-change`
para corregirlo formalmente con trazabilidad.

### ¿Cómo actualizo el plugin a una nueva versión?

Desde Claude Code:

```
/plugin update sdd@noelserdna-claude-plugin-sdd
```

Después, en cada proyecto:

```
/sdd:setup
```

El setup detecta automáticamente si tu proyecto tiene una versión anterior
y migra lo necesario (actualiza `sddVersion` y `hooksVersion` en `pipeline-state.json`).

### ¿Para qué sirven tech-designer y ux-designer?

Son skills **laterales opcionales** que puedes ejecutar en cualquier momento,
pero son más útiles **antes de plan-architect**:

- **tech-designer**: Explora decisiones de stack, infraestructura, API design, CI/CD, etc. Si ya sabes exactamente qué tecnología usar, puedes saltarlo. Si quieres explorar opciones con trade-offs documentados, úsalo.
- **ux-designer**: Define sistema de diseño, wireframes, accesibilidad, tokens. Si tu proyecto no tiene UI (es solo una API), no lo necesitas.

Ambos generan artefactos que plan-architect consume automáticamente si existen.

### ¿Qué es el code intelligence?

`/sdd:code-index` analiza tu código fuente y lo conecta con los artefactos SDD.
Usa los commits con trailers `Refs:` y `Task:` (que task-implementer genera automáticamente)
para inferir qué código implementa cada requisito.

Con **GitNexus** instalado (`npm i -g gitnexus`), el análisis es mucho más profundo:
call graphs, clusters de código, flujos de ejecución. Sin GitNexus, funciona en modo básico.

### ¿Puedo ver el estado del pipeline en cualquier momento?

Sí, de tres formas:

1. `/sdd:pipeline-status` — Resumen en texto
2. `/sdd:dashboard` — Dashboard HTML interactivo
3. `pipeline-state.json` — Archivo JSON (automáticamente actualizado)

---

## Glosario rápido

| Término | Significado |
|---------|-------------|
| **Pipeline** | La secuencia de 7 pasos (REQ → IMPL) |
| **FASE** | Una fase de implementación (grupo de tareas) |
| **EARS** | Formato de requisitos: WHEN/THE/SHALL |
| **BDD** | Escenarios Given/When/Then |
| **ADR** | Registro de decisión de arquitectura |
| **INV** | Invariante (regla que siempre se cumple) |
| **Stale** | Un artefacto cuyos inputs cambiaron |
| **Cascade** | Propagación automática de cambios |
| **Traceability** | Conexión verificable entre artefactos |
| **TDD** | Test-Driven Development (test primero) |
| **C4 Model** | Diagramas de arquitectura en 4 niveles |
| **SWEBOK** | Body of Knowledge de ingeniería de software |
| **OWASP ASVS** | Estándar de verificación de seguridad |
| **SSE** | Server-Sent Events (actualizaciones en tiempo real) |
| **GitNexus** | Herramienta de code intelligence (call graph, clusters) |
| **Design Tokens** | Variables de diseño exportables (colores, spacing, etc.) |
| **WCAG** | Web Content Accessibility Guidelines |
| **Blast Radius** | Impacto de un cambio en el resto del sistema |
| **Code Intelligence** | Mapeo código ↔ artefactos SDD |

---

## Resumen: comandos esenciales

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                   │
│  PIPELINE (en orden):                                             │
│                                                                   │
│  1.  /sdd:setup                    Inicializar proyecto           │
│  2.  /sdd:requirements-engineer    Definir qué se necesita       │
│  3.  /sdd:specifications-engineer  Definir cómo funciona         │
│  4.  /sdd:spec-auditor             Verificar y corregir specs     │
│  5.  /sdd:test-planner             Planificar pruebas             │
│  6.  /sdd:plan-architect           Diseñar arquitectura y fases  │
│  7.  /sdd:task-generator           Generar tareas atómicas       │
│  8.  /sdd:task-implementer         Implementar con TDD            │
│                                                                   │
│  LATERALES (en cualquier momento):                                │
│                                                                   │
│  /sdd:tech-designer                Explorar stack y arquitectura  │
│  /sdd:ux-designer                  Diseño visual y accesibilidad │
│  /sdd:security-auditor             Auditoría OWASP               │
│  /sdd:req-change                   Gestión de cambios + cascada  │
│                                                                   │
│  UTILIDADES (cuando las necesites):                               │
│                                                                   │
│  /sdd:pipeline-status              ¿Dónde estoy?                 │
│  /sdd:traceability-check           ¿Está todo conectado?         │
│  /sdd:dashboard                    Verlo visualmente              │
│  /sdd:code-index                   Conectar código con specs     │
│  /sdd:session-summary              Resumen de sesión              │
│                                                                   │
│  ONBOARDING (proyecto existente):                                 │
│                                                                   │
│  /sdd:onboarding                   Diagnosticar proyecto          │
│  /sdd:reverse-engineer             Código → artefactos SDD       │
│  /sdd:reconcile                    Alinear specs ↔ código        │
│  /sdd:import                       Importar docs externos         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

> **SDD no es burocracia. Es la diferencia entre construir una casa con planos
> y construir una casa "a ojo".** Los planos toman tiempo, pero la casa no se cae.
