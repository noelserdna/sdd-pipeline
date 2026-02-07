# SDD Skills

**Pipeline de Desarrollo Dirigido por Especificaciones para Claude Code, basado en SWEBOK v4.**

De requisitos a codigo en produccion — un pipeline estructurado, auditable y trazable que transforma requisitos en lenguaje natural en software implementado a traves de especificaciones formales, auditoria automatizada y ejecucion atomica de tareas.

> **Buscas el plugin instalable?** Ve [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd).
> Este repositorio es la **fuente de verdad** para desarrollo. El repo del plugin es el paquete distribuible.

---

## Tabla de Contenidos

- [Que es SDD?](#que-es-sdd)
- [El Pipeline](#el-pipeline)
- [Referencia de Skills](#referencia-de-skills)
- [Infraestructura de Automatizacion](#infraestructura-de-automatizacion)
- [Como Funciona en la Practica](#como-funciona-en-la-practica)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Gestion del Estado del Pipeline](#gestion-del-estado-del-pipeline)
- [La Constitucion SDD](#la-constitucion-sdd)
- [Estandares Referenciados](#estandares-referenciados)
- [Gaps Conocidos](#gaps-conocidos)
- [Contribuir](#contribuir)

---

## Que es SDD?

SDD (Specification-Driven Development) es una metodologia donde **las especificaciones son la unica fuente de verdad**. Cada linea de codigo, cada test y cada decision arquitectonica se traza hacia un documento de especificacion formal. Nada se asume, todo es auditable, y los cambios se propagan a traves de toda la cadena automaticamente.

El pipeline SDD esta implementado como una coleccion de **13 skills de Claude Code** que guian a un asistente de IA a traves de cada etapa — desde la elicitacion de requisitos hasta el commit de codigo en produccion. Cada skill impone restricciones, produce artefactos especificos y pasa la mano a la siguiente etapa con trazabilidad completa.

**Principios clave:**

- **Las specs dirigen todo** — el codigo es un artefacto derivado, no la fuente de verdad
- **Nunca asumir, siempre preguntar** — cada ambiguedad se presenta al usuario con opciones estructuradas
- **Trazabilidad completa** — cada artefacto se traza a traves de la cadena: REQ - UC - WF - API - BDD - INV - ADR - RN
- **Reversibilidad atomica** — cada tarea mapea exactamente a un commit de git con estrategia de rollback documentada
- **Auditoria por baseline** — la primera auditoria establece un baseline; las siguientes solo reportan hallazgos nuevos o regresiones

---

## El Pipeline

```
                          PIPELINE LINEAL
                          ===============

  requirements-engineer       requirements/REQUIREMENTS.md
          |
  specifications-engineer     spec/ (domain, use-cases, workflows, contracts, nfr, adr)
          |
  spec-auditor (Audit)        audits/AUDIT-BASELINE.md
          |
  spec-auditor (Fix)          documentos spec/ corregidos
          |
  test-planner                test/TEST-PLAN.md, TEST-MATRIX-*.md, PERF-SCENARIOS.md
          |
  plan-architect              plan/ (archivos FASE, PLAN.md, ARCHITECTURE.md)
          |
  task-generator              task/TASK-FASE-*.md
          |
  task-implementer            src/, tests/, git commits


                        SKILLS LATERALES
                        ================

  security-auditor            audits/SECURITY-AUDIT-BASELINE.md    (invocar en cualquier momento)
  req-change                  trigger de cascade del pipeline       (invocar en cualquier momento)


                        UTILIDADES
                        ==========

  pipeline-status             reporte de estado + recomendacion de siguiente accion
  traceability-check          verificacion de cadena REQ-UC-WF-API-BDD-INV-ADR
  session-summary             categorizacion de decisiones de sesion
```

Cada etapa lee artefactos de la etapa anterior y produce los propios. Las etapas no pueden modificar artefactos upstream — esto se impone automaticamente mediante hooks.

---

## Referencia de Skills

### Skills del Pipeline (9)

| # | Skill | Version | Entrada | Salida | SWEBOK |
|---|-------|---------|---------|--------|--------|
| 1 | **requirements-engineer** | v1.0.0 | Input del usuario | `requirements/REQUIREMENTS.md` | Ch01 |
| 2 | **specifications-engineer** | v1.0.0 | `requirements/` | `spec/` (6+ documentos) | Ch01 |
| 3 | **spec-auditor** | v1.1.0 | `spec/` | `audits/AUDIT-BASELINE.md`, `spec/` corregido | Ch01 |
| 4 | **test-planner** | v1.0.0 | `spec/`, `audits/` | `test/TEST-PLAN.md`, matrices, escenarios perf | Ch04 |
| 5 | **plan-architect** | v1.1.0 | `spec/`, `audits/`, `test/` | `plan/` (FASEs, PLAN, ARCHITECTURE) | Ch02 |
| 6 | **task-generator** | v1.1.0 | `plan/` | `task/TASK-FASE-*.md` | Ch04 |
| 7 | **task-implementer** | v1.1.0 | `task/`, `spec/`, `plan/` | `src/`, `tests/`, commits | Ch04 |
| 8 | **security-auditor** | v1.0.0 | `spec/` | `audits/SECURITY-AUDIT-BASELINE.md` | OWASP |
| 9 | **req-change** | v2.0.0 | Solicitud de cambio | `spec/`, `requirements/` actualizados, cascade | Ch01, Ch05 |

### Skills de Utilidad (3)

| Skill | Version | Proposito |
|-------|---------|-----------|
| **pipeline-status** | v1.0.0 | Reporta estado del pipeline, verificacion de artefactos, deteccion de staleness, siguiente accion |
| **traceability-check** | v1.0.0 | Verifica la cadena completa de trazabilidad, encuentra huerfanos |
| **session-summary** | v1.0.0 | Categoriza decisiones de sesion como formales vs informales, señala elecciones sin formalizar |

### Skill de Setup (1)

| Skill | Version | Proposito |
|-------|---------|-----------|
| **setup** | v1.0.0 | Instala automatizacion (hooks, agents, settings) en proyectos target |

---

## Infraestructura de Automatizacion

SDD incluye guardrails automatizados que imponen la integridad del pipeline sin intervencion manual.

### Hooks

| ID | Hook | Evento | Proposito |
|----|------|--------|-----------|
| H1 | `sdd-session-start.sh` | PreToolUse (SessionStart) | Lee `pipeline-state.json` e inyecta el estado actual del pipeline en el contexto de sesion |
| H2 | `sdd-upstream-guard.sh` | PreToolUse (Edit/Write) | **Bloquea** skills downstream de modificar artefactos upstream (Art. 4) |
| H3 | `sdd-pipeline-state-updater.sh` | PostToolUse (Write) | Auto-actualiza `pipeline-state.json` cuando se escribe en directorios de artefactos |
| H4 | Stop hook (prompt) | Stop | Verifica consistencia del pipeline al cerrar sesion |

### Agentes

| ID | Agente | Modelo | Proposito |
|----|--------|--------|-----------|
| A1 | **Constitution Enforcer** | haiku | Valida operaciones contra los 11 articulos de la Constitucion SDD |
| A2 | **Cross-Auditor** | sonnet | Cruza definiciones de skills buscando inconsistencias en contratos I/O |
| A3 | **Context Keeper** | haiku | Mantiene contexto informal del proyecto (preferencias, decisiones diferidas) |

---

## Como Funciona en la Practica

### Iniciando un proyecto nuevo

```
/sdd:setup                          # Instalar automatizacion en tu proyecto
/sdd:requirements-engineer          # Elicitar requisitos interactivamente
/sdd:specifications-engineer        # Transformar requisitos en specs formales
/sdd:spec-auditor                   # Auditar specs — produce baseline
/sdd:spec-auditor --fix             # Corregir hallazgos de auditoria
/sdd:test-planner                   # Generar estrategia de testing y matrices
/sdd:plan-architect                 # Generar archivos FASE y planes de implementacion
/sdd:task-generator                 # Descomponer en tareas atomicas
/sdd:task-implementer --fase 0      # Implementar FASE 0, tarea por tarea
```

### Manejando un cambio de requisitos a mitad del pipeline

```
/sdd:req-change --cascade=auto      # Agregar/modificar/deprecar un requisito
                                    # Propaga automaticamente a traves de:
                                    #   spec-auditor -> test-planner ->
                                    #   plan-architect -> task-generator ->
                                    #   task-implementer
```

### Verificando la salud del pipeline

```
/sdd:pipeline-status                # Que etapas estan done, stale o running?
/sdd:traceability-check             # Hay referencias huerfanas o links rotos?
/sdd:session-summary                # Que decidimos en esta sesion?
```

---

## Estructura del Proyecto

```
sdd-skills/
|
|-- sdd-requirements-engineer/      # Skill: elicitacion y auditoria de requisitos
|   |-- SKILL.md                    # Definicion del skill (YAML front matter + proceso)
|   +-- references/                 # Templates, checklists, bases de conocimiento
|       |-- audit-checklist.md
|       |-- elicitation-guide.md
|       +-- swebok-requirements-knowledge.md
|
|-- sdd-specifications-engineer/    # Skill: requisitos -> especificaciones formales
|-- sdd-spec-auditor/               # Skill: auditoria de calidad de specs + modo fix
|-- sdd-test-planner/               # Skill: estrategia de testing desde specs
|-- sdd-plan-architect/             # Skill: generacion de FASEs + planes de implementacion
|-- sdd-task-generator/             # Skill: descomposicion en tareas atomicas
|-- sdd-task-implementer/           # Skill: implementacion TDD desde tareas
|-- sdd-security-auditor/           # Skill: auditoria de postura de seguridad OWASP/CWE
|-- sdd-req-change/                 # Skill: gestion de cambios + cascade del pipeline
|-- sdd-pipeline-status/            # Skill: reportero de estado del pipeline
|-- sdd-traceability-check/         # Skill: verificador de cadena de trazabilidad
|-- sdd-session-summary/            # Skill: resumidor de decisiones de sesion
|-- sdd-setup/                      # Skill: instalador de automatizacion
|
|-- automation/
|   |-- hooks/                      # Scripts shell H1, H2, H3
|   |-- agents/                     # Definiciones de agentes A1, A2, A3
|   |-- settings-template.json      # Template de configuracion de hooks
|   +-- INSTALL.md                  # Guia de instalacion manual
|
|-- references/
|   +-- sdd-constitution.md         # Los 11 articulos que gobiernan el pipeline
|
|-- recursos/                       # Referencias externas (no en git)
|   |-- OpenSpec/                   # Framework de specs de Fission-AI
|   |-- spec-kit/                   # Toolkit SDD de GitHub
|   +-- swebok-v4.pdf               # Documento SWEBOK v4
|
+-- CLAUDE.md                       # Instrucciones del proyecto para Claude Code
```

Cada skill sigue el mismo patron: un `SKILL.md` que define el proceso completo, modos de operacion, restricciones y formato de salida, mas un directorio `references/` con material de soporte que se carga como contexto.

---

## Gestion del Estado del Pipeline

Cada proyecto que usa SDD trackea su progreso en `pipeline-state.json`:

```json
{
  "currentStage": "spec-auditor",
  "lastUpdated": "2026-02-07T10:30:00Z",
  "stages": {
    "requirements-engineer":    { "status": "done",    "lastRun": "...", "staleReason": null },
    "specifications-engineer":  { "status": "done",    "lastRun": "...", "staleReason": null },
    "spec-auditor":             { "status": "running", "lastRun": "...", "staleReason": null },
    "test-planner":             { "status": "pending", "lastRun": null,  "staleReason": null },
    "plan-architect":           { "status": "pending", "lastRun": null,  "staleReason": null },
    "task-generator":           { "status": "pending", "lastRun": null,  "staleReason": null },
    "task-implementer":         { "status": "pending", "lastRun": null,  "staleReason": null }
  }
}
```

**Transiciones de estado:**

```
pending --> running --> done --> stale --> running --> done
                                  ^                     |
                                  +---------------------+
```

**Propagacion de staleness:** Cuando la etapa N se vuelve stale, todas las etapas N+1 hasta 7 se marcan automaticamente como stale. La skill `req-change` puede disparar un cascade completo para re-ejecutar las etapas afectadas.

---

## La Constitucion SDD

El pipeline esta gobernado por 11 articulos que toda skill debe cumplir:

| # | Articulo | Principio |
|---|----------|-----------|
| 1 | **La Spec es Fuente de Verdad** | Todos los artefactos downstream derivan de las especificaciones |
| 2 | **Nunca Asumir, Siempre Preguntar** | Cada punto de decision se presenta al usuario |
| 3 | **La Trazabilidad No es Negociable** | REQ - UC - WF - API - BDD - INV - ADR - RN, sin huerfanos |
| 4 | **Inmutabilidad Upstream** | Skills downstream no pueden modificar artefactos upstream |
| 5 | **Calidad Lista para Implementar** | Las specs deben ser suficientemente detalladas para desarrolladores no familiarizados |
| 6 | **Auditoria por Baseline** | Auditorias subsecuentes solo reportan hallazgos nuevos o regresiones |
| 7 | **Una Tarea, Un Commit Atomico** | Cada tarea = un commit con formato Conventional Commits |
| 8 | **Construccion Test-First** | Los tests se escriben antes de la implementacion |
| 9 | **Feedback Loops Estructurados** | Issues de specs encontrados downstream se canalizan formalmente |
| 10 | **Operacion Context-Aware** | Las skills leen decisiones existentes antes de preguntar |
| 11 | **Iterativo Sobre Waterfall** | Input deficiente detiene el pipeline, no garbage-in-garbage-out |

Texto completo: [`references/sdd-constitution.md`](references/sdd-constitution.md)

---

## Estandares Referenciados

| Estandar | Usado Por | Cobertura |
|----------|-----------|-----------|
| **SWEBOK v4** | Todas las skills | Ch01 (Requisitos), Ch02 (Diseño), Ch04 (Testing), Ch05 (Mantenimiento) |
| **OWASP ASVS v4** | security-auditor | Framework de evaluacion de postura de seguridad |
| **CWE** | security-auditor | Enumeracion de debilidades para hallazgos |
| **IEEE 830** | requirements-engineer | Formato de documento de requisitos |
| **ISO 14764** | req-change | Clasificacion de mantenimiento (correctivo/adaptivo/perfectivo/preventivo) |
| **Modelo C4** | plan-architect | Vistas de diagramas de arquitectura |
| **Gherkin/BDD** | Todas las skills del pipeline | Formato de criterios de aceptacion |

---

## Gaps Conocidos

| Area | Estado | Notas |
|------|--------|-------|
| SWEBOK Ch05 (Mantenimiento) | Parcial | Cubierto por `req-change` v2.0.0 para mantenimiento a nivel de especificacion. Mantenimiento operacional (monitoreo, respuesta a incidentes) esta fuera de alcance. |
| SWEBOK Ch07 (Gestion de Ingenieria) | No cubierto | Sin estimacion de esfuerzo, gestion de riesgo ni metricas de control de proyecto. |
| SWEBOK Ch10 (Economia del Software) | No cubierto | Sin analisis costo-beneficio. |

---

## Contribuir

Este es el repositorio de desarrollo. Al modificar skills:

1. **Preservar el YAML front matter** — Claude Code usa `name:` y `description:` para registrar skills
2. **Mantener cross-references consistentes** — las skills se referencian por nombre; los cambios deben propagarse
3. **Ejecutar el Cross-Auditor** despues de cambios — el agente A2 detecta inconsistencias en contratos I/O
4. **Actualizar el plugin** — despues de cambios aqui, regenerar el [repo del plugin](https://github.com/noelserdna/claude-plugin-sdd)

---

## Licencia

MIT
