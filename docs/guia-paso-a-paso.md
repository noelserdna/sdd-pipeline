# Guía Paso a Paso: Desarrollo con SDD

> **Specification-Driven Development** — Construye software que funciona bien *desde el principio*,
> no software que "funciona" y luego hay que arreglar.
>
> **Nota (5.0):** la instalación vigente está en [instalacion.md](instalacion.md). Los diagramas de esta guía
> simplifican la estructura real de `spec/` (`domain/01..05-*.md`, `use-cases/UC-NNN-*.md`, `workflows/`,
> `contracts/API-*.md`, `tests/BDD-UC-NNN.md`, `nfr/*.md`, `adr/ADR-NNN-*.md`); ante la duda manda el `SKILL.md`
> de cada skill.

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
│  ✓ Git ≥ 2.32       (commit --trailer)          │
│  ✓ Node.js 18+      (para el servidor MCP)      │
│  ✓ jq               (procesamiento JSON)        │
│  ✓ Plugin SDD       (este proyecto)             │
│                                                  │
│  Opcional:                                       │
│  ○ gh / glab         (issues y PRs, tracker)    │
│  ○ python3           (grafo JSON para el MCP)   │
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
/plugin marketplace add noelserdna/sdd-pipeline
```

Esto registra el repositorio de GitHub como fuente de plugins.

**Paso 2: Instalar el plugin**

```
/plugin install sdd-pipeline@noelserdna
```

> **Alternativa interactiva:** Puedes escribir `/plugin` sin argumentos para abrir
> un gestor visual con pestañas (Discover, Installed, Marketplaces).

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  ¿Qué sucede al instalar?                                                        │
│                                                                                  │
│  1. Descarga el plugin desde GitHub                                              │
│     noelserdna/sdd-pipeline                                                      │
│                                                                                  │
│  2. Registra las 21 skills como comandos /sdd-*                                  │
│     /sdd-requirements-engineer                                                   │
│     /sdd-specifications-engineer                                                 │
│     /sdd-spec-auditor                                                            │
│     ... (21 skills en total)                                                     │
│                                                                                  │
│  3. Activa los hooks de automatización (corren desde el plugin)                  │
│     Session start, upstream guard, state updater, etc.                            │
│                                                                                  │
│  4. No instala agentes: el plugin no distribuye ninguno                          │
│     (la conducción guiada es la skill /sdd-orchestrator)                         │
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
/plugin disable sdd-pipeline@noelserdna           # Desactivar temporalmente
/plugin enable sdd-pipeline@noelserdna            # Reactivar
/plugin uninstall sdd-pipeline@noelserdna         # Desinstalar
```

> **Repositorio del plugin:** https://github.com/noelserdna/sdd-pipeline

### Inicializar SDD en tu proyecto

Una vez instalado el plugin, navega a tu proyecto y ejecuta:

```bash
cd mi-proyecto
claude
```

Dentro de Claude Code:

```
/sdd-setup
```

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                  │
│  ¿Qué hace /sdd-setup?                                                          │
│                                                                                  │
│  A diferencia de /plugin install (que es global), /sdd-setup es POR PROYECTO:    │
│                                                                                  │
│  1. Crea pipeline-state.json (los hooks nunca lo crean)                          │
│     Estado del pipeline, con sddVersion y hooksVersion                           │
│                                                                                  │
│  2. Detecta upgrades (v1 → v2)                                                  │
│     Si tienes hooks antiguos, los migra automáticamente                          │
│                                                                                  │
│  3. Verifica dependencias (git ≥ 2.32, jq, node)                                 │
│                                                                                  │
│  4. Instala el hook git commit-msg (mismas reglas que `sdd verify`,              │
│     con el validador copiado en .claude/sdd/) y escribe un Stack Profile         │
│     mínimo con task_state: trailers (proyectos nuevos)                           │
│                                                                                  │
│  5. Genera reporte de verificación                                               │
│     Confirma que todo está listo para usar                                        │
│                                                                                  │
│  Resultado:                                                                      │
│                                                                                  │
│  tu-proyecto/                                                                    │
│  └── pipeline-state.json     ← Estado del pipeline SDD                           │
│                                                                                  │
│  Los hooks y el servidor MCP vienen incluidos                                   │
│  en el plugin — NO se copian al proyecto. Solo pipeline-state.json es local.     │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

> **Resumen:** `/plugin install` = instalar una vez, global.
> `/sdd-setup` = inicializar cada proyecto nuevo.

---

## 3. Visión general del pipeline

### El pipeline completo

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                          PIPELINE SDD COMPLETO                                  ║
╠══════════════════════════════════════════════════════════════════════════════════╣
║                                                                                  ║
║  ┌─────────────────────┐                                                         ║
║  │  /sdd-requirements-  │──→ requirements/REQUIREMENTS.md                        ║
║  │   engineer           │    "¿Qué necesita el usuario?"                         ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    spec/                                                ║
║  │  /sdd-specifications-│──→ ├── DOMAIN-MODEL.md                                ║
║  │   engineer           │    ├── USE-CASES.md                                    ║
║  └────────┬────────────┘    ├── WORKFLOWS.md                                    ║
║           │                  ├── API-CONTRACTS.md                                 ║
║           ▼                  ├── NFR.md                                           ║
║  ┌─────────────────────┐    └── adr/ADR-*.md                                    ║
║  │  /sdd-spec-auditor   │──→ audits/AUDIT-BASELINE.md                            ║
║  │   (Mode Audit)       │    "¿Hay problemas en las specs?"                      ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐                                                         ║
║  │  /sdd-spec-auditor   │──→ spec/ corregido                                    ║
║  │   (Mode Fix)         │    "Corregir los problemas encontrados"                ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    test/                                                ║
║  │  /sdd-test-planner   │──→ ├── TEST-PLAN.md                                   ║
║  └────────┬────────────┘    ├── TEST-MATRIX-*.md                                ║
║           │                  └── PERF-SCENARIOS.md                                ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    plan/                                                ║
║  │  /sdd-plan-architect │──→ ├── PLAN.md                                         ║
║  └────────┬────────────┘    ├── ARCHITECTURE.md                                  ║
║           │                  └── fases/FASE-*.md                                  ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    task/                                                ║
║  │  /sdd-task-generator │──→ ├── TASK-FASE-0.md                                 ║
║  └────────┬────────────┘    ├── TASK-FASE-1.md                                  ║
║           │                  └── TASK-ORDER.md                                    ║
║           ▼                                                                      ║
║  ┌─────────────────────┐                                                         ║
║  │  /sdd-task-           │──→ src/ + tests/ + git commits (rama de trabajo)      ║
║  │   implementer        │    "Código real, trazable y testeado" + demo           ║
║  └────────┬────────────┘                                                         ║
║           │                                                                      ║
║           ▼                                                                      ║
║  ┌─────────────────────┐    acceptance/                                          ║
║  │  /sdd-acceptance     │──→ ├── ACCEPTANCE-REPORT.md                            ║
║  │                      │    └── decisions.jsonl                                 ║
║  └─────────────────────┘    "¿Está cada requisito cumplido, y con qué prueba?"  ║
║                                                                                  ║
║  ┌─ Herramientas laterales ──────────────────────────────────────────────┐       ║
║  │  /sdd-tech-designer       Diseño técnico (12 dimensiones)             │       ║
║  │  /sdd-ux-designer         Diseño UX (12 dimensiones, WCAG)            │       ║
║  │  /sdd-security-auditor    Auditoría de seguridad (OWASP)              │       ║
║  │  /sdd-req-change          Gestión de cambios con cascada              │       ║
║  └───────────────────────────────────────────────────────────────────────┘       ║
║                                                                                  ║
║  ┌─ Utilidades ──────────────────────────────────────────────────────────┐       ║
║  │  /sdd-pipeline-status     Estado actual del pipeline                  │       ║
║  │  /sdd-gap-detector        Endpoints que faltan y código huérfano      │       ║
║  │  /sdd-session-summary     Resumen de sesión                           │       ║
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

> **Tip:** En cualquier momento puedes ejecutar `/sdd-pipeline-status` para ver
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
/sdd-requirements-engineer

Quiero hacer una app para gestionar tareas.
Los usuarios pueden crear tareas, marcarlas como completadas y eliminarlas.
Necesita login. Quiero que sea rápida.
```

Eso es todo. El skill toma tu descripción informal y empieza a trabajar.

#### Opción B: Tienes un documento con tus ideas

Si ya tienes un archivo con notas, requisitos preliminares, o cualquier documento
(un `.md`, un `.txt`, un `.docx` exportado a texto, lo que sea), díselo:

```
/sdd-requirements-engineer

Aquí están mis requisitos iniciales, están en el archivo docs/mi-idea.md
```

El skill leerá el archivo y lo usará como punto de partida.

#### Opción C: Tienes varias fuentes

Puedes darle todo lo que tengas — actas de reunión, correos, capturas, notas sueltas:

```
/sdd-requirements-engineer

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

1. **Necesidades del cliente, con sus palabras**: antes de escribir un solo requisito, el skill
   anota lo que pide el cliente, textual, en `requirements/CUSTOMER-NEEDS.md`. Cada necesidad
   (`N-NNN`) lleva la cita, quién la dijo y cuándo, y se relee con el cliente para confirmarla:

```
### N-001: Jot a task down without leaving the terminal
- **Quote:** "I live in the terminal and I keep forgetting small things. I want to write
  a task down in one command, without opening anything else."
- **Who:** Laura Gómez, product owner
- **When:** 2026-08-20
- **Status:** confirmed
```

2. **Elicitación**: El skill te hace preguntas estructuradas para extraer requisitos:
   - ¿Quiénes son los usuarios?
   - ¿Qué problemas resuelve?
   - ¿Qué funcionalidades necesita?
   - ¿Hay restricciones técnicas?

3. **Formato EARS**: Cada requisito se escribe en formato EARS (Easy Approach to Requirements Syntax):

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
│  REQ-F-001                                                           │
│  WHEN a user submits a new task with title and description           │
│  THE system SHALL create the task with status "pending"              │
│  AND assign a unique identifier                                      │
│  AND return the created task to the user                             │
│                                                                      │
│  Priority:      Must have                                            │
│  Needs:         N-001            ← qué necesidad del cliente cubre   │
│  Verification:  test             ← test | demo | measurement |       │
│                                    inspection                        │
│  Acceptance Criteria (con datos reales, revisados con el cliente):   │
│  GIVEN an empty task list                                            │
│  WHEN the user runs `todo add "Buy milk"`                            │
│  THEN a task with id 1, title "Buy milk" and status pending is stored│
└─────────────────────────────────────────────────────────────────────┘
```

   - **`Needs:`** enlaza el requisito con las necesidades que cubre. Toda necesidad acaba
     cubierta por algún requisito o marcada fuera de alcance con la decisión registrada; un
     requisito sin necesidad es candidato a *gold plating*.
   - **`Verification:`** dice cómo se demostrará que está cumplido. Lo usa después
     `/sdd-acceptance` para decidir qué cuenta como evidencia (un test que pasa, una demo
     observada, una medición con umbral o una revisión humana).
   - **Ejemplos**: cada criterio lleva un ejemplo con datos concretos. El cliente los revisa y
     queda escrito quién lo hizo (`Examples reviewed by:`).

4. **Clasificación**: Los requisitos se organizan por dominio y prioridad:

```
  ┌─────────────────────────────────────────────┐
  │  Requisitos                                  │
  │                                              │
  │  Funcionales (F)                             │
  │  ├── REQ-F-001     Crear tarea        Must  │
  │  ├── REQ-F-002     Listar tareas      Must  │
  │  ├── REQ-F-003     Completar tarea    Must  │
  │  ├── REQ-F-004     Eliminar tarea     Should│
  │  └── REQ-F-005     Filtrar tareas     Nice  │
  │                                              │
  │  No Funcionales (NF)                         │
  │  ├── REQ-NF-001    Respuesta < 200ms  Must  │
  │  └── REQ-NF-002    Cobertura ≥ 90 %   Should│
  │                                              │
  │  Must have · Should have · Nice to have      │
  └─────────────────────────────────────────────┘
```

   Si más del 60 % de los requisitos son Must, el skill lo avisa: cuando casi todo es
   imprescindible, el plan no puede ordenar por valor. En cualquier caso, el cliente confirma
   la lista Must explícitamente.

5. **Aprobación**: la comprobación mecánica tiene que salir limpia:

```bash
node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" lint --needs    # necesidades huérfanas, requisitos
                                                        # sin necesidad, Verification válido
```

   Después el skill pregunta al aprobador (nombre y rol): *"¿Apruebas los requisitos v1.0 como
   base de las especificaciones?"*. Solo un "Aprobar" explícito cuenta. Con él hace un commit
   `docs(requirements)` y crea el tag anotado `requirements-v{N}` con quién aprobó, su rol, la
   fecha y el hash de `REQUIREMENTS.md` y `CUSTOMER-NEEDS.md`. El hook de herramientas pide
   confirmación antes de crear ese tag, para evitar una auto-aprobación accidental.

### Archivos generados

```
requirements/
├── CUSTOMER-NEEDS.md    ← necesidades N-NNN, textuales
└── REQUIREMENTS.md      ← requisitos con Needs:, Verification: y ejemplos
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
/sdd-specifications-engineer
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
│  Refs:     REQ-F-001                                             │
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
│  Refs: REQ-NF-001                                                │
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
│  Refs: REQ-NF-002                                                │
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
/sdd-spec-auditor

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
/sdd-test-planner
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
verticales: cada FASE es un incremento que el cliente puede ver funcionar en una demo.

```
┌───────────────┐         ┌──────────────────────────────────────────┐
│  spec/        │         │  plan/                                    │
│  audits/      │──────▶  │  ├── PLAN.md          Plan-Style: vertical│
│  test/        │         │  ├── ARCHITECTURE.md  Diagramas C4        │
│               │         │  └── fases/                               │
│               │         │      ├── FASE-0-SKELETON.md   add + list  │
│               │         │      ├── FASE-1-LIFECYCLE.md  done + rm   │
│               │         │      ├── FASE-2-FILTER.md     filtrar     │
│               │         │      └── FASE-3-HARDENING.md  latencia    │
└───────────────┘         └──────────────────────────────────────────┘
```

### Cómo ejecutarlo

```
/sdd-plan-architect
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

### Las FASEs: incrementos verticales

Una FASE no es una capa (infraestructura, modelo, API, UI) sino un **recorrido de usuario
que funciona de punta a punta**. Así el cliente ve algo útil al final de cada FASE y puede
aceptarlo o corregir el rumbo pronto. Con el todo-app de ejemplo:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  FASE-0-SKELETON: apuntar tareas y verlas en otra ejecución          │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │ todo add (escribir) → todo list (observar) → data/todos.json│     │
│  │ (persistir). Solo la infraestructura que ese camino necesita│     │
│  │ REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002                 │     │
│  └───────────────────────────┬──────────────────────────────┘       │
│                ┌─────────────┴─────────────┐                         │
│                ▼                           ▼                         │
│  FASE-1-LIFECYCLE               FASE-2-FILTER                        │
│  completar y borrar tareas      filtrar por estado                   │
│  REQ-F-003, REQ-F-004           REQ-F-005                            │
│                └─────────────┬─────────────┘                         │
│                              ▼                                       │
│  FASE-3-HARDENING: latencia con 1 000 tareas (REQ-NF-001)            │
│  (solo existe porque hay un NFR medido)                              │
└─────────────────────────────────────────────────────────────────────┘
```

Reglas principales (`sdd-plan-architect/references/phase-assignment-rules.md`):

- **Orden**: las dependencias mandan; la prioridad MoSCoW desempata.
- **FASE-0 es el esqueleto andante**: el camino mínimo *escribir → observar → persistir* del
  caso de uso central, aunque cruce 2-3 requisitos, más la infraestructura que ese camino
  necesita, nada más.
- **Un recorrido de usuario por FASE**: el CRUD de una entidad es un incremento; como máximo
  3 casos de uso y unas 15 tareas por FASE.
- **Seguridad** (autenticación, validación) en la primera FASE que expone el recurso.
- **`FASE-N-HARDENING`** solo para NFR medidos (rendimiento, disponibilidad), y solo si existen.

Cada FASE empieza con una cabecera que otras herramientas leen:

```
# FASE 0: Esqueleto — apuntar tareas y verlas de nuevo

> **Estado:** Implementable
> **Incremento:** Apuntar tareas y verlas en otra ejecución
> **Requisitos:** REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002
> **Escenarios:** AC-001-01, AC-001-02, AC-001-03, AC-001-04, AC-002-01, ...
> **Necesidades:** N-001, N-002, N-004, N-005
> **Dependencias:** Ninguna (fase inicial)
```

Y termina con una **demo** de como máximo 10 pasos desde un checkout limpio, cada uno con su
escenario y las necesidades del cliente que demuestra:

```
## Demo

| # | Acción                          | Resultado esperado              | Escenario             |
|---|---------------------------------|---------------------------------|-----------------------|
| 1 | `rm -rf data && todo list`      | `No tasks`, exit 0              | AC-002-02 · N-002     |
| 2 | `todo add "Buy milk"`           | tarea 1 pending; fichero creado | AC-001-01 · N-001     |
| 3 | `todo add ""`                   | exit 2, `title must not be empty` | AC-001-03 · N-001   |
```

`plan/PLAN.md` lleva la marca `> **Plan-Style:** vertical`. Un plan sin ella se trata como
horizontal (planes anteriores) y sigue funcionando. La comprobación mecánica del plan:

```bash
node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" lint --plan
# V8: cada FASE tiene criterios y demo respaldados por IDs REQ/AC existentes
# V9: todo requisito Must está asignado a alguna FASE
```

---

## 9. Paso 6 — Generación de tareas

### ¿Qué hace este paso?

Descompone cada FASE en **tareas atómicas**: cada tarea es un commit,
con su mensaje predefinido, su estrategia de rollback, y su trazabilidad.

```
┌───────────────────┐     ┌──────────────────────────────────────────┐
│  plan/fases/      │     │  task/                                    │
│  FASE-0-SKELETON  │──▶  │  ├── TASK-FASE-0.md                       │
│  FASE-1-LIFECYCLE │     │  │   TASK-F0-001 Setup mínimo (Foundation)│
│  ...              │     │  │   ### UC-001 — Crear tarea             │
│                   │     │  │   TASK-F0-003 todo add, test-first     │
│                   │     │  │   ### UC-002 — Listar tareas           │
│                   │     │  │   TASK-F0-005 todo list, test-first    │
│                   │     │  ├── TASK-FASE-1.md                       │
│                   │     │  └── TASK-ORDER.md   Orden de ejecución   │
└───────────────────┘     └──────────────────────────────────────────┘
```

Con un plan vertical, las tareas se agrupan por caso de uso y la Foundation es mínima.
El generador comprueba que cada escenario de la cabecera `Escenarios:` lo cita alguna tarea.
`node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" lint` valida el formato de las tareas.

### Cómo ejecutarlo

```
/sdd-task-generator
```

### Anatomía de una tarea

```
- [ ] TASK-F0-003 [P] Create task (API-001-01), test-first | `tests/add.test.ts`, `src/api/add.ts`
  - blocked-by: TASK-F0-002
  - **Commit:** `feat(tasks): create task with incremental id`
  - **Acceptance:**
    - Test first: `AC-001-01 creates task 1 pending` — el nombre del test lleva el ID del escenario
    - Test first: `AC-001-03 rejects empty title with exit 2`
  - **Refs:** FASE-0, REQ-F-001, UC-001, API-001-01, INV-TSK-001
  - **Revert:** SAFE — ficheros nuevos
```

Una tarea por línea (`- [ ] TASK-F{N}-NNN … | \`rutas\``), con sus campos indentados debajo.
El nombre de cada test lleva el ID de su escenario (`AC-NNN-NN`): así `sdd accept` puede
atar el resultado del test al criterio de aceptación que verifica.

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
│               │         │  Git log (rama fase-0-skeleton):       │
│               │         │  abc1234 feat(tasks): create task     │
│               │         │  def5678 feat(tasks): list tasks      │
│               │         │  ghi9012 feat(store): persist to JSON │
│               │         │  ...                                  │
└───────────────┘         └──────────────────────────────────────┘
```

### Cómo ejecutarlo

```
/sdd-task-implementer
```

### El ciclo TDD por tarea

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│   Para cada tarea (TASK-F{N}-NNN):                                   │
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
│   │ 4. COMMIT   │  git commit --trailer con mensaje predefinido      │
│   │    ✅       │  (trailers Task: y Refs:)                          │
│   └─────────────┘                                                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

#### Git: rama, commits con trailers y merge commit

Las reglas completas están en `references/git-conventions.md`. Lo esencial:

- **Rama de trabajo por defecto.** Antes del primer commit, si estás en la rama por defecto,
  el implementer crea la rama de la FASE (`fase-{N}-{slug}`); los cambios de requisitos van
  en `change/{CHG-ID}-{slug}`. Con HEAD suelto, para y pregunta.

  ```bash
  node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" branch start fase 0 skeleton   # → fase-0-skeleton
  ```

- **Trailers con `git commit --trailer`**, nunca escritos a mano: git solo lee los trailers del
  último párrafo, y una línea de prosa detrás los convierte en texto normal (y la tarea deja
  de contar como hecha).

  ```bash
  git commit -m "feat(tasks): create task with incremental id" \
    -m "Validates the title per RN-001." \
    --trailer "Task: TASK-F0-003" \
    --trailer "Refs: REQ-F-001, UC-001, API-001-01"
  ```

  | Trailer | Valor | Obligatorio en |
  |---|---|---|
  | `Task` | `TASK-F{N}-NNN` (uno por commit) | `feat`, `test`, `refactor`; `fix`/`perf` necesitan `Task` **o** `Change` |
  | `Refs` | IDs de spec | `docs(specs)` |
  | `Change` | `CHG-…`, `CR-N` o un hallazgo (`SEC-12`) | `fix`/`perf` sin tarea (hotfix, corrección de auditoría) |

- **El hook git `commit-msg`** (instalado por `/sdd-setup`) aplica las mismas reglas que
  `sdd verify --message`: rechaza un commit `feat` sin `Task:` y señala la línea de un bloque
  de trailers roto. Quedan exentos `docs`, `chore`, `ci`, `style`, `build`, merges, `Revert`
  y `fixup!`/`squash!`/`amend!`.
- **Solo merge commits.** Un squash o un rebase merge reescribe los commits por tarea en uno
  y borra todos los `Task:`. Se integra con `git merge --no-ff` (o un PR con merge commit), y
  `sdd verify --range base..head` detecta un squash. Hacer merge a la rama por defecto o push
  siempre pregunta.

### Verificación post-implementación

Después de implementar cada FASE, el skill verifica, ejecuta la demo desde un estado
limpio y calcula el veredicto de cada requisito de la FASE con `sdd accept --fase N`:

```
┌─────────────────────────────────────────────────────────────────┐
│  Verificación FASE-0                                             │
│                                                                  │
│  ✅ Todos los tests pasan (12/12)                                │
│  ✅ Cada tarea tiene exactamente 1 commit con su Task:           │
│  ✅ Demo: 6/6 pasos como se esperaba                             │
│  ✅ REQ-F-001 VERIFIED (3/3 test) · REQ-F-002 VERIFIED (2/2 test)│
│  ⚠️  Una desviación de spec registrada como SPEC-DEVIATION       │
│     en feedback/IMPL-FEEDBACK-FASE-0.md                          │
└─────────────────────────────────────────────────────────────────┘
```

Un requisito FAILING o MISSING hace fallar la FASE: se arregla el código, nunca el test
(Art. 12). La excepción es el requisito que se verifica por demo, medición o inspección: sin el
registro de una persona sigue MISSING, así que el implementador lo deja "pendiente en la puerta
de FASE", donde el cliente confirma esa evidencia antes de aceptar.

### La puerta de FASE: el cliente acepta el incremento

Al terminar una FASE de un plan vertical, el orquestador (o el lead) enseña al cliente el
incremento, la demo y el veredicto por requisito, y pregunta: *"¿Aceptas el incremento
FASE-0 (Apuntar tareas y verlas en otra ejecución)?"*

| Respuesta | Qué pasa |
|---|---|
| **Aceptado** | `/sdd-acceptance --sign-off --fase 0` registra la decisión (quién, rol, canal) en `acceptance/decisions.jsonl` y crea el tag anotado `fase-0-accepted` |
| **Aceptado con observaciones** | Igual, con tag; cada observación se enruta sin bloquear el incremento |
| **Rechazado, con feedback** | Sin tag; el feedback se enruta |

El feedback se clasifica en **defecto** (la entrega contradice lo que ya dicen los requisitos
→ tareas incrementales y se arregla el código), **petición de cambio** (comportamiento nuevo
→ `/sdd-req-change`) o **pregunta** (se responde y se vuelve a preguntar). Con Jev activado,
el set `feedback-route` propone la ruta; una persona siempre la confirma.

Si faltan requisitos por cumplir, `/sdd-acceptance --loop` itera (medir → enrutar → implementar)
hasta que todos los Must estén VERIFIED o WAIVED, o hasta que el código decida parar.

---

## 11. Herramientas laterales

Las herramientas laterales se pueden ejecutar en **cualquier momento** del pipeline.
No tienen un orden fijo — úsalas cuando las necesites.

### Diseño técnico (recomendado antes de plan-architect)

```
/sdd-tech-designer
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
│  Tip: Si ejecutas esto ANTES de /sdd-plan-architect,                │
│  el arquitecto consumirá automáticamente tus decisiones.            │
└─────────────────────────────────────────────────────────────────────┘
```

### Diseño UX (recomendado antes de plan-architect)

```
/sdd-ux-designer
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
│  5. Accesibilidad          (WCAG 2.2 AA, ARIA, contraste)          │
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
│  Tip: Si ejecutas esto ANTES de /sdd-plan-architect,                │
│  el arquitecto integrará tu diseño en las fases.                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Auditoría de seguridad

Ejecutar en cualquier momento para evaluar la postura de seguridad:

```
/sdd-security-auditor
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
/sdd-req-change
```

```
┌─────────────────────────────────────────────────────────────────────┐
│  Cambio de Requisito: REQ-F-001                                      │
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
│  │  REQ-F-001 ──▶ UC-TASK-001 ──▶ WF-TASK-CREATE        │          │
│  │       │                │               │                  │       │
│  │       ▼                ▼               ▼                  │       │
│  │  DOMAIN-MODEL    API-CONTRACTS    WORKFLOWS              │       │
│  │  (add priority   (add priority    (add priority          │       │
│  │   to Task)        to request)      selection step)       │       │
│  │       │                │               │                  │       │
│  │       ▼                ▼               ▼                  │       │
│  │  TEST-MATRIX     TASK-FASE-0      TASK-FASE-1            │       │
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
/sdd-pipeline-status
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
│  → Re-ejecutar /sdd-task-generator (inputs han cambiado)         │
└─────────────────────────────────────────────────────────────────┘
```

### Aceptación por requisito

```
/sdd-acceptance --check
```

Responde la pregunta que importa al cliente: **¿está cumplido cada requisito, y con qué
evidencia?** Ejecuta los tests con el comando `test_report` del Stack Profile (que escribe
JUnit XML), y `sdd accept` calcula un veredicto por requisito según su `Verification:`:

| Veredicto | Significa |
|---|---|
| **VERIFIED** | Cada criterio tiene evidencia válida y fresca (un test que pasa con su `AC-NNN-NN` en el nombre, una demo o una inspección registradas, una medición dentro del umbral). El informe dice cuántos: "3/5" |
| **FAILING** | Alguna evidencia falla |
| **MISSING** | Algún criterio no tiene evidencia (sin implementar, sin test, o el test no lleva el ID del escenario) |
| **WAIVED** | Una persona lo eximió para el texto actual del requisito; un Must exento exige motivo, rol e issue de seguimiento |

Los requisitos deprecados se listan aparte y no bloquean. El resultado queda en
`acceptance/ACCEPTANCE-REPORT.md` (legible por el cliente) y en `.sdd/acceptance.json`.
El mismo modo comprueba la integridad de la cadena de IDs (referencias rotas, definiciones
huérfanas, requisitos sin escenario), que antes hacía `/sdd-traceability-check`.

Otros modos:

```
/sdd-acceptance --fase 1       # solo los requisitos de la FASE 1
/sdd-acceptance --loop         # bucle hasta que todos los Must estén VERIFIED o WAIVED
/sdd-acceptance --sign-off     # puerta final + aceptación registrada + tag
/sdd-acceptance --publish      # bloque para el PR/issue y, opcional, página de estado
```

La puerta de entrega, también en CI (solo necesita Node y git):

```bash
node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" gate --mode enforce
# 0 objetivo cumplido (todos los Must VERIFIED o WAIVED)
# 1 no cumplido · 2 evidencia obsoleta · 3 cumplido con Must exentos
```

`--publish` puede publicar una página de estado como Artifact de Claude cuando la sesión lo
permite (siempre pregunta antes, porque saca títulos de requisitos de la máquina). Sin esa
herramienta, por ejemplo con `claude -p`, la vista para compartir es
`acceptance/ACCEPTANCE-REPORT.md`.

### Trazabilidad con git

Los trailers de los commits responden "¿qué commits implementan REQ-F-004?" sin herramientas
extra:

```bash
SDD="node $SDD_PLUGIN_ROOT/scripts/sdd.mjs"
$SDD trace req REQ-F-004            # commits cuyo Task/Refs/Change contiene ese ID exacto
$SDD trace why src/api/add.ts:42    # blame → commit → trailers → IDs de spec
$SDD trace delivered REQ-F-004      # tags y ramas que contienen ese trabajo
```

El servidor MCP (`sdd`) y los hooks leen además `dashboard/traceability-graph.json`, que
construye `scripts/sdd-graph.py` (solo el JSON; ya no hay dashboard HTML).

### Resumen de sesión

```
/sdd-session-summary
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
│  │ /sdd-req-change (ADD nuevos requisitos)    │                      │
│  │      ↓ cascada automática                  │                      │
│  │ SPEC → AUDIT → TEST → PLAN → TASK → IMPL  │                      │
│  └───────────────────────────────────────────┘                      │
│                         │                                            │
│                         ▼                                            │
│  Sprint 3: Bug fixes + mejoras                                       │
│  ┌───────────────────────────────────────────┐                      │
│  │ /sdd-req-change (MODIFY requisitos)        │                      │
│  │      ↓ cascada selectiva                   │                      │
│  │ Solo los artefactos afectados se actualizan│                      │
│  └───────────────────────────────────────────┘                      │
│                         │                                            │
│                         ▼                                            │
│  Continuo: Verificación                                              │
│  ┌───────────────────────────────────────────┐                      │
│  │ /sdd-pipeline-status                       │                      │
│  │ /sdd-acceptance --check                    │                      │
│  │ /sdd-security-auditor                      │                      │
│  │ /sdd-gap-detector                          │                      │
│  └───────────────────────────────────────────┘                      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### ¿Qué hacer cuando algo cambia?

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ¿Cambio en requisitos?                                              │
│  └──→ /sdd-req-change                                                │
│       Propaga automáticamente a specs, tests, plan, tasks            │
│                                                                      │
│  ¿Nuevo hallazgo de seguridad?                                       │
│  └──→ /sdd-security-auditor                                          │
│       Genera hallazgos → pueden convertirse en req-change            │
│                                                                      │
│  ¿El código se alejó de las specs?                                   │
│  └──→ /sdd-reconcile                                                 │
│       Detecta drift y propone correcciones                           │
│                                                                      │
│  ¿Pipeline roto o confuso?                                           │
│  └──→ /sdd-pipeline-status                                           │
│       Te dice exactamente qué paso ejecutar                          │
│                                                                      │
│  ¿Trazabilidad rota o requisitos sin cumplir?                        │
│  └──→ /sdd-acceptance --check                                        │
│       Veredicto por requisito, links rotos y huérfanos               │
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
/sdd-setup
```

### Paso 1: Requisitos

```
/sdd-requirements-engineer
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
/sdd-specifications-engineer
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
/sdd-spec-auditor
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
/sdd-test-planner
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
/sdd-tech-designer
```

```
mi-task-app/
└── design/
    ├── TECHNICAL-DESIGN.md     ← Stack: Next.js + PostgreSQL + JWT
    ├── QUALITY-ATTRIBUTES.md   ← Trade-offs documentados
    └── ADR-DRAFT-001.md        ← Borrador: ¿por qué Next.js?
```

```
/sdd-ux-designer
```

```
mi-task-app/
└── ux/
    ├── UI-DESIGN-SYSTEM.md     ← Componentes, colores, tipografía
    ├── WIREFRAMES.md           ← Wireframes ASCII de cada pantalla
    ├── ACCESSIBILITY-SPEC.md   ← WCAG 2.2 AA
    ├── INTERACTION-MODEL.md    ← Estados, animaciones, feedback
    └── DESIGN-TOKENS.json      ← Tokens exportables a CSS/Tailwind
```

### Paso 5: Arquitectura

```
/sdd-plan-architect
```

Si ejecutaste tech-designer y/o ux-designer, el arquitecto los consume automáticamente
en su Phase 0 y los integra en las fases:

```
mi-task-app/
└── plan/
    ├── PLAN.md                 ← Plan-Style: vertical, 4 incrementos
    ├── ARCHITECTURE.md         ← C4: React + Node + PostgreSQL
    └── fases/
        ├── FASE-0-SKELETON.md  ← Entrar, crear una tarea y verla tras recargar
        │                          (login + crear + listar + BD: el camino mínimo)
        ├── FASE-1-LIFECYCLE.md ← Completar y borrar tareas
        ├── FASE-2-FILTER.md    ← Filtrar por estado
        └── FASE-3-HARDENING.md ← Respuesta < 200 ms (REQ-NF-001, NFR medido)
```

La autenticación entra en FASE-0 porque es la primera FASE que expone las tareas. Cada FASE
termina con su demo, y `node "$SDD_PLUGIN_ROOT/scripts/sdd.mjs" lint --plan` comprueba el plan.

### Paso 6: Tareas

```
/sdd-task-generator
```

```
mi-task-app/
└── task/
    ├── TASK-FASE-0.md          ← 12 tareas atómicas (agrupadas por caso de uso)
    ├── TASK-FASE-1.md          ← 7 tareas
    ├── TASK-FASE-2.md          ← 5 tareas
    ├── TASK-FASE-3.md          ← 4 tareas
    └── TASK-ORDER.md           ← Orden de ejecución
```

### Paso 7: Implementación

```
/sdd-task-implementer
```

El skill implementa tarea por tarea, FASE por FASE, en una rama de trabajo por FASE
(`fase-0-skeleton`, …). Al final de cada FASE ejecuta la demo y el cliente acepta el
incremento (tag `fase-N-accepted`):

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
└── ... (28 commits trazables, uno por tarea, cada uno con su Task:)
```

### Verificación final

```
/sdd-acceptance --check    ← Veredicto por requisito + cadena de IDs íntegra ✅
/sdd-acceptance --loop     ← (si falta algo) itera hasta cumplir todos los Must
/sdd-acceptance --sign-off ← Aceptación registrada del cliente
/sdd-pipeline-status       ← Todos los pasos: done ✅
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

Sin embargo, puedes ejecutar `/sdd-pipeline-status` para ver qué pasos
ya están completos y retomar desde donde te quedaste.

### ¿Puedo usar SDD en un proyecto existente?

**Sí.** Empieza por el diagnóstico y sigue el plan que propone:

```
/sdd-pipeline-status --diagnose  ← Diagnostica tu proyecto
                                    y te recomienda el camino

/sdd-reverse-engineer      ← Genera artefactos SDD desde código existente
/sdd-reconcile            ← Alinea specs existentes con el código
/sdd-import               ← Importa docs externos (Jira, Notion, etc.)
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
2. **Sprint N:** `/sdd-req-change` para agregar/modificar requisitos
   con cascada automática al resto del pipeline

### ¿Puedo usar SDD con cualquier lenguaje o framework?

**Sí.** SDD define *qué* construir y *cómo* verificarlo. El skill
`task-implementer` genera código en el lenguaje y framework que tu
proyecto use (TypeScript, Python, Go, React, Vue, etc.).

### ¿Qué pasa si Claude se equivoca en una spec?

El ciclo de auditoría (`spec-auditor`) existe precisamente para eso.
Además, el principio "nunca asumir, siempre preguntar" significa que
Claude te consultará antes de tomar decisiones ambiguas.

Si encuentras un error después de implementar, usa `/sdd-req-change`
para corregirlo formalmente con trazabilidad.

### ¿Cómo actualizo el plugin a una nueva versión?

Desde Claude Code:

```
/plugin update sdd-pipeline@noelserdna
```

Después, en cada proyecto:

```
/sdd-setup
```

El setup detecta automáticamente si tu proyecto tiene una versión anterior
y migra lo necesario (actualiza `sddVersion` y `hooksVersion` en `pipeline-state.json`).

### ¿Para qué sirven tech-designer y ux-designer?

Son skills **laterales opcionales** que puedes ejecutar en cualquier momento,
pero son más útiles **antes de plan-architect**:

- **tech-designer**: Explora decisiones de stack, infraestructura, API design, CI/CD, etc. Si ya sabes exactamente qué tecnología usar, puedes saltarlo. Si quieres explorar opciones con trade-offs documentados, úsalo.
- **ux-designer**: Define sistema de diseño, wireframes, accesibilidad, tokens. Si tu proyecto no tiene UI (es solo una API), no lo necesitas.

Ambos generan artefactos que plan-architect consume automáticamente si existen.

### ¿Cómo sé qué código implementa cada requisito?

Por los trailers de los commits (`Task:`, `Refs:`, `Change:`), que task-implementer escribe
con `git commit --trailer`. `sdd trace req REQ-F-004` lista los commits de un requisito y
`sdd trace why src/api/add.ts:42` recorre blame → commit → trailers hasta los IDs de spec.

### ¿Puedo ver el estado del pipeline en cualquier momento?

Sí, de tres formas:

1. `/sdd-pipeline-status` — Resumen en texto (incluye el resumen de aceptación)
2. `acceptance/ACCEPTANCE-REPORT.md` — Veredicto por requisito, legible por el cliente
   (`/sdd-acceptance --publish` puede publicarlo además como página de estado)
3. `pipeline-state.json` — Archivo JSON (automáticamente actualizado)

---

## Glosario rápido

| Término | Significado |
|---------|-------------|
| **Pipeline** | La secuencia de 7 pasos (REQ → IMPL), más la aceptación |
| **FASE** | Un incremento vertical: un recorrido de usuario que se demuestra al cliente |
| **Necesidad (N-NNN)** | Lo que pidió el cliente, con sus palabras (`CUSTOMER-NEEDS.md`) |
| **Veredicto** | VERIFIED / FAILING / MISSING / WAIVED por requisito (`sdd accept`) |
| **Trailer** | Línea `Clave: valor` al final del commit (`Task:`, `Refs:`, `Change:`) |
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
| **Design Tokens** | Variables de diseño exportables (colores, spacing, etc.) |
| **WCAG** | Web Content Accessibility Guidelines |
| **Blast Radius** | Impacto de un cambio en el resto del sistema |

---

## Resumen: comandos esenciales

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                   │
│  PIPELINE (en orden):                                             │
│                                                                   │
│  1.  /sdd-setup                    Inicializar proyecto           │
│  2.  /sdd-requirements-engineer    Definir qué se necesita       │
│  3.  /sdd-specifications-engineer  Definir cómo funciona         │
│  4.  /sdd-spec-auditor             Verificar y corregir specs     │
│  5.  /sdd-test-planner             Planificar pruebas             │
│  6.  /sdd-plan-architect           Diseñar arquitectura y fases  │
│  7.  /sdd-task-generator           Generar tareas atómicas       │
│  8.  /sdd-task-implementer         Implementar con TDD            │
│  9.  /sdd-acceptance               ¿Cumplido cada requisito?      │
│                                                                   │
│  LATERALES (en cualquier momento):                                │
│                                                                   │
│  /sdd-tech-designer                Explorar stack y arquitectura  │
│  /sdd-ux-designer                  Diseño visual y accesibilidad │
│  /sdd-security-auditor             Auditoría OWASP               │
│  /sdd-req-change                   Gestión de cambios + cascada  │
│                                                                   │
│  UTILIDADES (cuando las necesites):                               │
│                                                                   │
│  /sdd-pipeline-status              ¿Dónde estoy?                 │
│  /sdd-gap-detector                 ¿Qué falta o sobra en código?  │
│  /sdd-orchestrator                 Conducir todo el pipeline     │
│  /sdd-session-summary              Resumen de sesión              │
│                                                                   │
│  PROYECTO EXISTENTE:                                              │
│                                                                   │
│  /sdd-pipeline-status --diagnose   Diagnosticar proyecto          │
│  /sdd-reverse-engineer             Código → artefactos SDD       │
│  /sdd-reconcile                    Alinear specs ↔ código        │
│  /sdd-import                       Importar docs externos         │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

> **SDD no es burocracia. Es la diferencia entre construir una casa con planos
> y construir una casa "a ojo".** Los planos toman tiempo, pero la casa no se cae.
