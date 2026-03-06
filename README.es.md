# SDD Skills

**Pipeline de Desarrollo Dirigido por Especificaciones para Claude Code, basado en SWEBOK v4.**

De requisitos a codigo en produccion — un pipeline estructurado, auditable y trazable que transforma requisitos en lenguaje natural en software implementado.

> **Buscas el plugin instalable?** Ve [claude-plugin-sdd](https://github.com/noelserdna/claude-plugin-sdd).
> Este repositorio es la **fuente de verdad** para desarrollo. El repo del plugin es el paquete distribuible.

## Que contiene este repo

- **22 skills** en directorios `sdd-*/` (pipeline + onboarding + laterales + utilidades)
- **Servidor MCP** en `server/` (TypeScript, 5 herramientas para consultar el grafo de trazabilidad)
- **Automatizacion** en `automation/` (5 hooks, 3 agentes, template de settings)
- **Referencias** en `references/` (Constitucion SDD, conocimiento compartido)

## El Pipeline

```
sdd-requirements-engineer  →  requirements/REQUIREMENTS.md
sdd-specifications-engineer  →  spec/ (domain, use-cases, workflows, contracts, nfr, adr)
sdd-spec-auditor  →  audits/AUDIT-BASELINE.md + spec/ corregido
sdd-test-planner  →  test/TEST-PLAN.md, TEST-MATRIX-*.md
sdd-plan-architect  →  plan/ (ARCHITECTURE.md, PLAN.md, archivos FASE)
sdd-task-generator  →  task/TASK-FASE-*.md
sdd-task-implementer  →  src/, tests/, git commits
```

**Skills laterales** (en cualquier momento): `sdd-security-auditor`, `sdd-req-change`, `sdd-tech-designer`, `sdd-ux-designer`

**Onboarding** (proyectos existentes): `sdd-onboarding`, `sdd-reverse-engineer`, `sdd-reconcile`, `sdd-import`

**Utilidades**: `sdd-pipeline-status`, `sdd-traceability-check`, `sdd-dashboard`, `sdd-code-index`, `sdd-session-summary`, `sdd-setup`

## Cadena de Trazabilidad

Cada artefacto se traza de extremo a extremo:

```
REQ → UC → WF → API → BDD → INV → ADR → TASK → COMMIT → CODE → TEST
```

## Referencia de Skills

### Pipeline (7)

| # | Skill | Entrada | Salida |
|---|-------|---------|--------|
| 1 | requirements-engineer | Input del usuario | `requirements/` |
| 2 | specifications-engineer | `requirements/` | `spec/` |
| 3 | spec-auditor | `spec/` | `audits/`, `spec/` corregido |
| 4 | test-planner | `spec/`, `audits/` | `test/` |
| 5 | plan-architect | `spec/`, `audits/`, `test/` | `plan/` |
| 6 | task-generator | `plan/` | `task/` |
| 7 | task-implementer | `task/`, `spec/`, `plan/` | `src/`, `tests/`, commits |

### Onboarding (4)

| Skill | Proposito |
|-------|-----------|
| onboarding | Diagnosticar estado del proyecto (8 escenarios), generar plan de adopcion |
| reverse-engineer | Codigo → artefactos SDD (requisitos, specs, tareas, hallazgos) |
| reconcile | Detectar drift specs-codigo, clasificar divergencias, reconciliar |
| import | Docs externos → formato SDD (Jira, OpenAPI, Markdown, Notion, CSV, Excel) |

### Laterales (4)

| Skill | Proposito |
|-------|-----------|
| security-auditor | Analisis de seguridad basado en OWASP ASVS v4, CWE |
| req-change | Gestion de cambios de requisitos con cascade de pipeline |
| tech-designer | Exploracion de arquitectura tecnica en 12 dimensiones (ATAM-lite) |
| ux-designer | Sistema de diseno UI/UX en 12 dimensiones (WCAG 2.1 AA) |

### Utilidades (6)

| Skill | Proposito |
|-------|-----------|
| pipeline-status | Reporte de estado con recomendacion de siguiente accion |
| traceability-check | Verificar cadena completa, encontrar huerfanos |
| dashboard | Dashboard HTML interactivo de trazabilidad (5 vistas + guia) |
| code-index | Indexar codigo para trazabilidad profunda (puente GitNexus) |
| session-summary | Resumir decisiones de sesion |
| setup | Inicializar `pipeline-state.json` |

## Servidor MCP

El directorio `server/` contiene un servidor MCP en TypeScript que expone el grafo de trazabilidad:

| Herramienta | Proposito |
|-------------|-----------|
| `sdd_query` | Buscar artefactos por texto, ID, tipo o dominio |
| `sdd_impact` | Analisis de blast radius por profundidad |
| `sdd_context` | Vista 360° de un artefacto con todas sus conexiones |
| `sdd_coverage` | Analisis de gaps por dominio de negocio o capa tecnica |
| `sdd_trace` | Recorrido completo de cadena con deteccion de roturas |

Ademas incluye 7 resources `sdd://` y 2 prompts de workflow (`analyze_impact`, `generate_status_report`).

### Build

```bash
cd server && npm install && npm run build
```

### Instalacion

El servidor MCP se configura via `~/.claude/.mcp.json` (global) o `<proyecto>/.mcp.json` (por proyecto):

```json
{
  "mcpServers": {
    "sdd": {
      "command": "node",
      "args": ["/ruta/a/sdd-skills/server/dist/index.js"]
    }
  }
}
```

**Global vs por proyecto:** El servidor usa `process.cwd()` para localizar el grafo de trazabilidad, y Claude Code lanza los servidores MCP desde el directorio del proyecto actual. Esto significa que una instalacion global resuelve automaticamente al proyecto correcto — no necesitas configurar rutas.

**Como encuentra el grafo:** Al iniciar, el servidor busca `dashboard/traceability-graph.json` desde el `cwd` subiendo hasta 6 directorios padre. Si no encuentra ningun grafo, degrada gracefully (devuelve resultados vacios, sin crash). Esto significa:

- En proyectos **con** artefactos SDD: funcionalidad completa tras ejecutar `/sdd:dashboard`
- En proyectos **sin** artefactos SDD: el servidor carga pero todas las consultas devuelven resultados vacios

**Prerrequisitos:** Node.js 18+. Tras reiniciar Claude Code, se te pedira aprobar el servidor MCP "sdd" en el primer uso.

## Code Intelligence (Opcional)

El skill `sdd-code-index` mapea simbolos de codigo (funciones, clases, modulos) a artefactos SDD para trazabilidad profunda. Funciona en dos modos:

- **Modo Lite** (por defecto): Analisis basado en regex — no requiere dependencias extra
- **Modo Full**: Usa [GitNexus](https://github.com/nicobailon/gitnexus) para analisis AST con call graph, referencias cruzadas entre archivos y mapeo de flujos de ejecucion

### Instalar GitNexus

```bash
npm install -g gitnexus
```

O usarlo sin instalar:

```bash
npx gitnexus analyze
```

**Requisitos:** Node.js 18+

### Uso

```bash
# Modo full (con GitNexus)
/sdd-code-index

# Modo lite (solo regex, sin GitNexus)
/sdd-code-index --lite

# Ver estado del indice
/sdd-code-index --status

# Refrescar solo archivos modificados
/sdd-code-index --refresh
```

Con GitNexus disponible, `sdd-code-index` produce resultados mas ricos: call graphs a nivel de simbolo, inferencia transitiva (max 2 hops), mapeo de flujos de ejecucion y deteccion de dominios por comunidades. Sin el, el skill funciona igualmente pero solo provee deteccion de simbolos a nivel de archivo y anotaciones directas `// Refs:`.

## Automatizacion

En `automation/`:

**Hooks:**
- **H1** `sdd-session-start.sh` — Inyecta estado del pipeline al iniciar sesion
- **H2** `sdd-upstream-guard.sh` — Bloquea skills downstream de editar artefactos upstream
- **H3** `sdd-pipeline-state-updater.sh` — Auto-actualiza estado del pipeline al escribir
- **H4** Stop hook — Verificacion de consistencia al cerrar sesion

**Agentes:**
- **A1** Constitution Enforcer — Valida contra los 11 articulos de la Constitucion SDD
- **A2** Cross-Auditor — Cruza definiciones de skills buscando inconsistencias I/O
- **A3** Context Keeper — Mantiene contexto informal del proyecto

**Hook de Augmentacion de Contexto** (`automation/hooks/sdd-augment-hook.js`):
Intercepta Grep/Glob/Read/Edit/Write e inyecta contexto de trazabilidad SDD automaticamente.

## Estructura del Repositorio

```
sdd-skills/
├── sdd-requirements-engineer/   # Cada skill tiene SKILL.md + references/
├── sdd-specifications-engineer/
├── sdd-spec-auditor/
├── sdd-test-planner/
├── sdd-plan-architect/
├── sdd-task-generator/
├── sdd-task-implementer/
├── sdd-security-auditor/
├── sdd-req-change/
├── sdd-onboarding/
├── sdd-reverse-engineer/
├── sdd-reconcile/
├── sdd-import/
├── sdd-pipeline-status/
├── sdd-traceability-check/
├── sdd-dashboard/
├── sdd-code-index/
├── sdd-session-summary/
├── sdd-tech-designer/
├── sdd-ux-designer/
├── sdd-setup/
├── server/                      # Servidor MCP (TypeScript)
├── automation/
│   ├── hooks/                   # H1, H2, H3, augment hook
│   ├── agents/                  # A1, A2, A3
│   └── settings-template.json
├── references/
│   └── sdd-constitution.md      # 11 articulos que gobiernan el pipeline
└── recursos/                    # Referencias externas (no en git)
```

Cada skill sigue la misma estructura: `SKILL.md` (YAML front matter + proceso completo) y `references/` (templates, checklists, patrones).

## Contribuir

Al modificar skills:

1. Preservar YAML front matter (`name:`, `description:`) — Claude Code lo usa para registrar skills
2. Mantener cross-references consistentes — las skills se referencian por nombre
3. Ejecutar el Cross-Auditor (A2) despues de cambios para detectar inconsistencias I/O
4. Sincronizar cambios al [repo del plugin](https://github.com/noelserdna/claude-plugin-sdd) (adaptar nombres `sdd-X` → `X`)

## Estandares

SWEBOK v4 &middot; OWASP ASVS v4 &middot; CWE &middot; IEEE 830 &middot; ISO 14764 &middot; Modelo C4 &middot; Gherkin/BDD

## Licencia

MIT
