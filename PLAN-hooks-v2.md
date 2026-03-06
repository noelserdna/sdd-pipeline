# Plan: SDD Hooks v2 + Dashboard Live Server

> Fecha: 2026-03-06
> Versiones afectadas: plugin v2.4.0, MCP server v2.4.0
> Resumen: Modernizar hooks al nuevo API, crear dashboard server con HTTP hooks para real-time updates, y agregar quality gates con prompt/agent hooks.

## Contexto

Claude Code ahora soporta:
- **HTTP hooks** (`type: "http"`) — POST directo a endpoints
- **Prompt hooks** (`type: "prompt"`) — LLM evalua yes/no
- **Agent hooks** (`type: "agent"`) — Subagente con herramientas verifica condiciones
- **Nuevos eventos**: `TaskCompleted`, `SubagentStart/Stop`, `PreCompact`, `ConfigChange`, `PostToolUseFailure`, `InstructionsLoaded`
- **Hooks en skill frontmatter** con `once: true`
- **`SessionStart` como evento propio** (ya no hack via PreToolUse matcher)
- **`last_assistant_message`** en Stop/SubagentStop
- **`updatedInput`** para modificar tool input

Nuestros hooks actuales (H1-H5) usan patrones deprecated y el dashboard depende de JSONP polling via archivo `live-status.js`.

---

## Escenarios de Migracion y Upgrade

### El problema

Existen dos repos y dos canales de instalacion:

| Canal | Donde viven los hooks | Como se actualizan |
|-------|----------------------|-------------------|
| **Plugin** (`claude-plugin-sdd`) | `hooks/hooks.json` + `scripts/` | **Automatico** al actualizar plugin — Claude Code lee hooks.json fresco en cada sesion |
| **Manual** (via `sdd-setup`) | `.claude/hooks/` + `.claude/settings.json` del proyecto | **Manual** — hay que re-correr sdd-setup o copiar archivos |

Cuando un proyecto usa el **plugin**, los hooks de `hooks/hooks.json` se cargan automaticamente. Si ademas el usuario corrio `sdd-setup` en algun momento, tiene hooks DUPLICADOS (plugin + proyecto), lo que causa que hooks se ejecuten DOS VECES.

### 5 escenarios de upgrade

| # | Escenario | Estado actual | Que necesita |
|---|-----------|--------------|-------------|
| **A** | Proyecto nuevo (greenfield) | Nada instalado | Instala todo nuevo via plugin o sdd-setup. Sin migracion |
| **B** | Plugin user, nunca corrio sdd-setup | Solo hooks del plugin (hooks.json) | Plugin update automatico. Solo necesita opt-in de features nuevos (dashboard server, quality gates) |
| **C** | Plugin user, corrio sdd-setup viejo | Hooks DUPLICADOS: plugin + .claude/settings.json | **Limpiar duplicados** de .claude/settings.json que ahora provee el plugin. Actualizar scripts copiados |
| **D** | Manual install (sin plugin), hooks v1 | .claude/hooks/ con scripts viejos + settings.json con patterns viejos | **Migracion completa**: scripts + settings.json + nuevo version marker |
| **E** | Partial SDD / Onboarding | Puede o no tener hooks. Tiene artifacts parciales | sdd-onboarding detecta version de hooks y recomienda upgrade como parte del action plan |

### Principio: Separacion Plugin vs Proyecto

```
Plugin hooks.json (auto-update, siempre activos)
├── H1: SessionStart (command) — status injection
├── H2: PreToolUse Edit|Write (command) — upstream guard
├── H3: PostToolUse Write (command, async) — state updater
└── H5: PreToolUse Grep|Glob|Read|Edit|Write (command) — context augment

Proyecto .claude/settings.json (opt-in via sdd-setup, NO duplicar lo del plugin)
├── H4: Stop (prompt) — pipeline consistency check
├── H6: HTTP hooks a dashboard server (SessionStart, PostToolUse, SubagentStart/Stop, Stop, TaskCompleted)
├── H7: TaskCompleted (agent) — traceability verification gate
└── Custom hooks del usuario

Skill frontmatter (auto-activos cuando la skill corre)
├── task-implementer: Stop prompt — verificar commits con trailers
└── spec-auditor: Stop prompt — verificar P0/P1 addressed
```

**Regla**: El plugin provee hooks CORE que todo proyecto necesita (H1-H3, H5). El proyecto solo agrega hooks OPCIONALES (H4, H6, H7). Nunca duplicar.

### Deteccion de version

Agregar `"sddVersion"` a `pipeline-state.json`:

```json
{
  "sddVersion": "2.4.0",
  "hooksVersion": 2,
  "currentStage": "...",
  "stages": { ... }
}
```

Senales de deteccion para v1 (sin version marker):

| Senal | Donde | Significado |
|-------|-------|-------------|
| `pipeline-state.json` sin campo `sddVersion` | Proyecto | Instalacion v1 o pre-versionada |
| `PreToolUse[matcher=SessionStart]` en `.claude/settings.json` | Proyecto | Pattern deprecated de H1 |
| `.claude/hooks/sdd-upstream-guard.sh` con `"permissionDecision"` sin `hookSpecificOutput` | Proyecto | Script v1 |
| Timeouts > 100 en settings.json | Proyecto | Valores en ms (v1) vs seconds (v2) |
| `.claude/hooks/sdd-session-start.sh` existe Y plugin esta instalado | Proyecto | Duplicacion — cleanup needed |

### Script de migracion

**Archivo nuevo**: `automation/scripts/migrate-hooks-v2.sh`

Logica:
```bash
#!/bin/bash
# SDD Hooks v1 → v2 Migration Script
# Safe, idempotent, non-destructive

# 1. Detect: is plugin installed?
PLUGIN_INSTALLED=$(claude plugin list 2>/dev/null | grep -c "sdd" || echo "0")

# 2. Backup
cp .claude/settings.json .claude/settings.json.bak-v1 2>/dev/null

# 3. If plugin installed: REMOVE project-level hooks that plugin now provides
#    (H1, H2, H3, H5 — avoid duplication)
if [ "$PLUGIN_INSTALLED" -gt 0 ]; then
  # Remove hooks with commands pointing to .claude/hooks/sdd-session-start.sh
  # Remove hooks with commands pointing to .claude/hooks/sdd-upstream-guard.sh
  # Remove hooks with commands pointing to .claude/hooks/sdd-pipeline-state-updater.sh
  # Keep only project-specific hooks
fi

# 4. If NO plugin: update scripts in-place
#    - sdd-upstream-guard.sh: wrap output in hookSpecificOutput
#    - settings.json: SessionStart event, fix timeouts

# 5. Add opt-in hooks (H4 prompt, H6 HTTP, H7 agent) — ask user

# 6. Add version marker to pipeline-state.json
#    sddVersion: "2.4.0", hooksVersion: 2

# 7. Report
```

### sdd-setup upgrade mode

`sdd-setup` gana Step 0: **Detect Existing Installation**

```
Step 0: Detect Existing Installation
  ├── Check pipeline-state.json for sddVersion field
  ├── Check .claude/settings.json for v1 patterns
  ├── Check if plugin is installed (claude plugin list)
  ├── If v1 detected:
  │     ├── Show migration report (what will change)
  │     ├── Ask user: "Upgrade to hooks v2? [Y/n]"
  │     ├── Run migrate-hooks-v2.sh
  │     └── Continue with normal setup (skipping what plugin already provides)
  └── If fresh install:
        └── Continue with normal setup
```

### sdd-onboarding integracion

En **Phase 2: SDD Artifact Scan**, agregar:

```
Step 2.7: Check automation version
  - Read pipeline-state.json → sddVersion
  - Scan .claude/settings.json for hook patterns
  - Detect plugin vs manual installation
  - Report: "Hooks v1 detected — recommend upgrade" or "Hooks v2 current"
  - Add to action plan: "Step 0: Run sdd-setup --upgrade" if v1 detected
```

El action plan template para **Scenario 4 (Partial SDD)** gana un paso previo:

```
| Step 0 | sdd-setup (upgrade) | Migrate hooks v1→v2, clean duplicates | .claude/ | Updated hooks | v1 installation | S |
```

---

## Arquitectura Objetivo

```
Claude Code Session
  |
  |-- SessionStart -----> HTTP POST /hooks/session-start
  |-- PostToolUse(Write|Edit) -> HTTP POST /hooks/artifact-changed
  |-- SubagentStart ----> HTTP POST /hooks/agent-event
  |-- SubagentStop -----> HTTP POST /hooks/agent-event
  |-- TaskCompleted ----> HTTP POST /hooks/task-completed
  |                       + agent hook: verify traceability
  |-- Stop -------------> HTTP POST /hooks/session-stop
  |                       + prompt hook: verify pipeline consistency
  |-- SessionEnd -------> HTTP POST /hooks/session-end
  |
  v
SDD Dashboard Server (Node.js, zero deps externas)
  |-- POST /hooks/*  <-- recibe eventos de hooks HTTP
  |-- GET  /         <-- sirve dashboard HTML
  |-- GET  /events   <-- SSE stream (Server-Sent Events)
  |-- GET  /api/status  <-- JSON estado actual
  |
  v
Browser (dashboard)
  |-- EventSource('/events') <-- recibe updates en real-time
  |-- Renderiza activity feed, pipeline status, artifact changes
```

### Decisiones de Diseno

| Decision | Opcion elegida | Razon |
|----------|---------------|-------|
| Server separado vs extension MCP | **Sibling entry point** en `server/` | Comparte tipos y graph-loader, pero no mezcla transportes stdio/http |
| WebSocket vs SSE | **SSE** (Server-Sent Events) | Unidireccional (server->browser), zero deps, `EventSource` nativo |
| Dependencias HTTP | **`node:http`** built-in | Zero deps externas, suficiente para nuestro caso |
| Ciclo de vida del server | **On-demand, resiliente** | Si no esta corriendo, HTTP hooks fallan silenciosamente (non-blocking). Se inicia manualmente o via sdd-setup/sdd-dashboard |
| JSONP backward compat | **Mantener temporalmente** | live-status.js sigue funcionando para file:// protocol. SSE es el path nuevo |

---

## Fases

### Fase 0: Fix Hooks Core + Plugin hooks.json (foundation)

**Objetivo**: Corregir patterns deprecated en los hooks CORE que viven en el plugin. Estos fixes se propagan automaticamente a todos los usuarios del plugin.

**Donde**: Plugin repo `claude-plugin-sdd/` → `hooks/hooks.json` + `scripts/`

#### Tarea 0.1: Migrar H1 a evento SessionStart real

**Archivo plugin**: `hooks/hooks.json`
**Archivo sdd-skills**: `automation/settings-template.json`

Cambios:
- Mover H1 de `PreToolUse[matcher=SessionStart]` a `SessionStart[matcher=startup|resume|compact]`
- El script `sdd-session-start.sh` no cambia (ya produce JSON correcto)

```json
// ANTES (deprecated — matcher "SessionStart" en PreToolUse)
"PreToolUse": [
  { "matcher": "SessionStart", "hooks": [{ "type": "command", "command": "..." }] }
]

// DESPUES (evento propio)
"SessionStart": [
  { "matcher": "startup|resume|compact", "hooks": [{ "type": "command", "command": "...", "timeout": 10 }] }
]
```

#### Tarea 0.2: Migrar H2 a hookSpecificOutput

**Archivo plugin**: `scripts/sdd-upstream-guard.sh`
**Archivo sdd-skills**: `automation/hooks/sdd-upstream-guard.sh`

Cambios en ambas copias:
- Wrappear output en `hookSpecificOutput` con `hookEventName: "PreToolUse"`

```json
// ANTES (deprecated top-level)
{"permissionDecision":"deny","reason":"..."}

// DESPUES
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}
```

#### Tarea 0.3: Fix timeouts

**Archivo plugin**: `hooks/hooks.json`
**Archivo sdd-skills**: `automation/settings-template.json`

Verificar que ambos usen segundos (no milisegundos). Si alguno tiene valores > 100, corregir.

#### Tarea 0.4: Remover H4 placeholder del plugin

**Archivo plugin**: `hooks/hooks.json`

El `echo {}` actual en Stop no hace nada. Removerlo del plugin. H4 pasa a ser opt-in via proyecto (prompt hook en Fase 2).

Razon: un Stop hook en el plugin afecta a TODOS los usuarios. Un prompt hook ahi podria bloquear workflow inesperadamente. Mejor que sea opt-in.

#### Tarea 0.5: Agregar `sddVersion` al template de pipeline-state.json

**Archivo sdd-skills**: `automation/hooks/sdd-pipeline-state-updater.sh`

En la seccion de init (cuando crea pipeline-state.json por primera vez), agregar `"sddVersion": "2.4.0"` y `"hooksVersion": 2`.

**Archivos totales Fase 0**: 4 modificados (hooks.json, upstream-guard.sh x2, settings-template.json, state-updater.sh)

---

### Fase 0.5: Script de Migracion + sdd-setup upgrade

**Objetivo**: Crear herramientas para que proyectos existentes migren de v1 a v2 sin perder datos.

#### Tarea 0.5.1: Crear script de migracion

**Archivo nuevo**: `automation/scripts/migrate-hooks-v2.sh`

Script idempotente y no-destructivo:

```bash
#!/bin/bash
# SDD Hooks v1 → v2 Migration
# Usage: bash migrate-hooks-v2.sh [--dry-run]

set -euo pipefail
DRY_RUN="${1:-}"
PROJECT_DIR="$(pwd)"

echo "=== SDD Hooks Migration v1 → v2 ==="

# --- Detection ---
V1_SIGNALS=0
PLUGIN_DETECTED=false

# Check if plugin is providing hooks (look for CLAUDE_PLUGIN_ROOT refs or plugin marker)
if [ -d ".claude/plugins" ] || command -v claude >/dev/null 2>&1; then
  # Best-effort plugin detection
  PLUGIN_DETECTED=true
fi

# Check for v1 signals in .claude/settings.json
if [ -f ".claude/settings.json" ]; then
  # Signal 1: PreToolUse with SessionStart matcher
  if grep -q '"SessionStart"' .claude/settings.json 2>/dev/null && \
     grep -q '"PreToolUse"' .claude/settings.json 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    echo "[DETECTED] v1 pattern: H1 SessionStart inside PreToolUse"
  fi

  # Signal 2: Timeouts > 100 (likely ms)
  if grep -qE '"timeout"\s*:\s*[0-9]{4,}' .claude/settings.json 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    echo "[DETECTED] v1 pattern: Timeouts in milliseconds"
  fi

  # Signal 3: echo {} stop hook
  if grep -q 'echo {}' .claude/settings.json 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    echo "[DETECTED] v1 pattern: Placeholder Stop hook"
  fi
fi

# Signal 4: Old script format
if [ -f ".claude/hooks/sdd-upstream-guard.sh" ]; then
  if grep -q '"permissionDecision"' .claude/hooks/sdd-upstream-guard.sh 2>/dev/null && \
     ! grep -q 'hookSpecificOutput' .claude/hooks/sdd-upstream-guard.sh 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    echo "[DETECTED] v1 pattern: upstream-guard without hookSpecificOutput"
  fi
fi

# Signal 5: No version marker
if [ -f "pipeline-state.json" ]; then
  if ! grep -q '"sddVersion"' pipeline-state.json 2>/dev/null; then
    V1_SIGNALS=$((V1_SIGNALS + 1))
    echo "[DETECTED] v1 pattern: pipeline-state.json without sddVersion"
  fi
fi

if [ "$V1_SIGNALS" -eq 0 ]; then
  echo "No v1 signals detected. Already on v2 or fresh install."
  exit 0
fi

echo ""
echo "Found $V1_SIGNALS v1 signals. Migration needed."

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "[DRY RUN] Would perform the following:"
  echo "  1. Backup .claude/settings.json"
  echo "  2. $([ "$PLUGIN_DETECTED" = true ] && echo 'Remove duplicate hooks (plugin provides them)' || echo 'Update hooks to v2 format')"
  echo "  3. Update hook scripts to v2 output format"
  echo "  4. Add sddVersion to pipeline-state.json"
  exit 0
fi

# --- Backup ---
echo ""
echo "--- Backing up ---"
[ -f ".claude/settings.json" ] && cp .claude/settings.json .claude/settings.json.bak-v1
echo "Backed up .claude/settings.json → .claude/settings.json.bak-v1"

# --- Migration ---
echo ""
echo "--- Migrating ---"

if [ "$PLUGIN_DETECTED" = true ]; then
  echo "Plugin detected. Removing project-level hooks that plugin now provides..."
  # Remove H1, H2, H3, H5 from .claude/settings.json (plugin provides these)
  # Keep any custom project hooks
  # This requires jq or node for safe JSON manipulation
  # [Implementation: jq filter to remove hooks with sdd-session-start, sdd-upstream-guard, etc.]
else
  echo "No plugin. Updating hooks in-place..."
  # Update .claude/settings.json: SessionStart event, timeouts
  # Update .claude/hooks/sdd-upstream-guard.sh: hookSpecificOutput
fi

# Add version marker
if [ -f "pipeline-state.json" ]; then
  echo "Adding sddVersion to pipeline-state.json..."
  # [jq/node: add sddVersion and hooksVersion fields]
fi

echo ""
echo "=== Migration complete ==="
echo "Restart Claude Code session to activate new hooks."
```

#### Tarea 0.5.2: Actualizar sdd-setup con Step 0 (upgrade detection)

**Archivo**: `sdd-setup/SKILL.md`

Agregar **Step 0: Detect Existing Installation** antes del Step 1 actual:

```markdown
### Step 0: Detect Existing Installation (Upgrade Check)

1. Check if `pipeline-state.json` exists with `sddVersion` field
2. Check if `.claude/settings.json` has v1 hook patterns (see detection signals table)
3. Check if plugin `sdd` is installed: look for plugin marker files or ask user
4. **If v1 detected + plugin installed (Scenario C)**:
   - Show: "Found v1 hooks AND plugin installed. Project hooks duplicate plugin hooks."
   - Ask: "Clean duplicate project hooks? Plugin will provide H1-H3, H5. [Y/n]"
   - If yes: remove duplicate hooks from `.claude/settings.json`, remove stale scripts
   - Offer: "Install optional features? (H4 pipeline check, H6 dashboard, H7 quality gates) [Y/n]"
5. **If v1 detected + no plugin (Scenario D)**:
   - Show: "Found v1 hooks. Upgrade available."
   - Ask: "Migrate to hooks v2? (fixes SessionStart event, output format, timeouts) [Y/n]"
   - If yes: run migration (update scripts + settings)
   - Offer optional features
6. **If fresh install (Scenario A)**:
   - Continue to Step 1 normally
7. **If already v2**:
   - Show: "Hooks v2 already installed."
   - Offer: "Check for new optional features? [Y/n]"
```

#### Tarea 0.5.3: Actualizar sdd-onboarding Phase 2

**Archivo**: `sdd-onboarding/SKILL.md`

En Phase 2 (SDD Artifact Scan), agregar Step 2.7:

```markdown
#### Step 2.7: Check Automation Version

1. Read `pipeline-state.json` → check for `sddVersion` field
2. If present: record version, compare with latest (2.4.0)
3. If absent: scan `.claude/settings.json` for v1 signals:
   - `PreToolUse[matcher=SessionStart]` → v1
   - Timeouts > 100 → v1
   - `echo {}` in Stop → v1
4. Check for plugin installation (`.claude/plugins/`, plugin markers)
5. Check for duplicate hooks (plugin + project-level)
6. Record in environment profile:
   - `hooksVersion`: 1 | 2 | "none"
   - `installationType`: "plugin" | "manual" | "both" | "none"
   - `upgradeNeeded`: true/false
   - `duplicateHooks`: true/false
```

Update action plan templates to include upgrade step when v1 detected.

**Archivos totales Fase 0.5**: 1 nuevo (migrate-hooks-v2.sh), 2 modificados (sdd-setup, sdd-onboarding)

---

### Fase 1: Dashboard Server (core)

**Objetivo**: Crear un servidor HTTP+SSE en el package `server/` que reciba eventos de hooks y pushee updates al browser.

#### Tarea 1.1: Crear dashboard-server.ts (entry point HTTP)

**Archivo nuevo**: `server/src/dashboard-server.ts`

Responsabilidades:
- `node:http` server en `localhost:3001` (configurable via `SDD_DASHBOARD_PORT` env)
- Importa `graph-loader.ts` para acceso al grafo
- Routing:
  - `POST /hooks/artifact-changed` — recibe PostToolUse data, actualiza activity feed
  - `POST /hooks/session-start` — registra inicio de sesion
  - `POST /hooks/session-stop` — registra fin de sesion
  - `POST /hooks/agent-event` — registra SubagentStart/Stop
  - `POST /hooks/task-completed` — registra task completado
  - `GET /` — sirve `dashboard/index.html` (static file)
  - `GET /events` — SSE stream
  - `GET /api/status` — JSON con estado actual + activity feed
  - `GET /api/graph` — proxy a traceability-graph.json
- CORS headers para desarrollo local

Estructura del evento interno:
```typescript
interface DashboardEvent {
  id: string;           // auto-increment
  timestamp: string;    // ISO-8601
  type: 'session-start' | 'session-stop' | 'artifact-changed' | 'agent-start' | 'agent-stop' | 'task-completed';
  stage?: string;       // pipeline stage inferido del path
  detail: {
    filePath?: string;
    toolName?: string;
    agentType?: string;
    taskId?: string;
    taskSubject?: string;
    message: string;    // human-readable
  };
}
```

Activity feed: array in-memory (max 200 entries), persistido a `dashboard/activity-log.json` cada 30s.

#### Tarea 1.2: SSE (Server-Sent Events) manager

**Archivo nuevo**: `server/src/sse.ts`

Responsabilidades:
- Mantener lista de clientes SSE conectados
- `addClient(res)` — registrar nuevo cliente
- `removeClient(res)` — limpiar al desconectar
- `broadcast(event)` — enviar a todos los clientes
- Heartbeat cada 15s para mantener conexion viva

Formato SSE:
```
event: artifact-changed
data: {"id":"42","timestamp":"...","type":"artifact-changed","stage":"spec-auditor","detail":{"filePath":"spec/DOMAIN-MODEL.md","message":"Wrote spec/DOMAIN-MODEL.md"}}

event: heartbeat
data: {"timestamp":"..."}
```

#### Tarea 1.3: Path-to-stage mapper (shared utility)

**Archivo nuevo**: `server/src/path-mapper.ts`

Extraer la logica de mapeo `path -> stage` que hoy esta duplicada en `sdd-pipeline-state-updater.sh` a un modulo TypeScript reutilizable:

```typescript
export function pathToStage(relativePath: string): string | null {
  if (relativePath.startsWith('requirements/')) return 'requirements-engineer';
  if (relativePath.startsWith('spec/'))         return 'specifications-engineer';
  // ... etc
}

export function pathToHumanLabel(relativePath: string): string {
  // "spec/DOMAIN-MODEL.md" -> "Specification: DOMAIN-MODEL.md"
}
```

#### Tarea 1.4: CLI entry point para dashboard server

**Archivo nuevo**: `server/src/dashboard-entry.ts`

```typescript
#!/usr/bin/env node
import { startDashboardServer } from './dashboard-server.js';

const port = parseInt(process.env.SDD_DASHBOARD_PORT || '3001', 10);
startDashboardServer(port);
```

**Archivo modificado**: `server/package.json`

Agregar:
```json
{
  "bin": {
    "sdd-server": "dist/index.js",
    "sdd-dashboard-server": "dist/dashboard-entry.js"
  },
  "scripts": {
    "start:dashboard": "node dist/dashboard-entry.js"
  }
}
```

#### Tarea 1.5: Tests basicos del server

**Archivo nuevo**: `server/test/dashboard-server.test.ts`

Tests minimos:
- Server inicia y responde en /
- POST /hooks/artifact-changed acepta JSON y retorna 200
- GET /events abre stream SSE
- GET /api/status retorna JSON con feed vacio
- Path mapper funciona correctamente

**Archivos totales Fase 1**: 4 nuevos, 1 modificado

---

### Fase 2: HTTP Hooks + Opt-in Configuration

**Objetivo**: Crear los hooks HTTP para el dashboard server y el mecanismo de opt-in. Estos hooks NO van en el plugin (evitar POST a localhost en proyectos sin dashboard server). Van en un template separado que sdd-setup instala en `.claude/settings.json` del proyecto.

**Principio clave**: HTTP hooks son non-blocking por diseno. Si el server no corre, fallan silenciosamente. Pero no queremos que TODOS los usuarios del plugin intenten POST a localhost:3001 sin saberlo.

#### Tarea 2.1: Crear template de hooks opcionales

**Archivo nuevo**: `automation/settings-optional-dashboard.json`

Este es el template que sdd-setup ofrece como opt-in. Se MERGE con el settings.json del proyecto (no reemplaza).

```json
{
  "_comment": "SDD Dashboard Live Hooks — opt-in via sdd-setup. Requires dashboard server running on localhost:3001",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|compact",
        "hooks": [
          { "type": "http", "url": "http://localhost:3001/hooks/session-start", "timeout": 5 }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "http", "url": "http://localhost:3001/hooks/artifact-changed", "timeout": 5 }
        ]
      }
    ],
    "SubagentStart": [
      {
        "hooks": [
          { "type": "http", "url": "http://localhost:3001/hooks/agent-event", "timeout": 5 }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          { "type": "http", "url": "http://localhost:3001/hooks/agent-event", "timeout": 5 }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          { "type": "http", "url": "http://localhost:3001/hooks/task-completed", "timeout": 5 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "http", "url": "http://localhost:3001/hooks/session-stop", "timeout": 5 }
        ]
      }
    ]
  }
}
```

#### Tarea 2.2: Crear template de hooks opcionales (quality gates)

**Archivo nuevo**: `automation/settings-optional-quality-gates.json`

```json
{
  "_comment": "SDD Quality Gate Hooks — opt-in via sdd-setup. Uses LLM to verify traceability and pipeline consistency.",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Review the pipeline session. Context: $ARGUMENTS\n\nCheck:\n1. Are there stages left in 'running' status that should be 'done' or 'error'?\n2. Did Claude report completing a stage but pipeline-state.json wasn't updated?\n\nRespond {\"ok\": true} if consistent, or {\"ok\": false, \"reason\": \"...\"} to fix something.",
            "timeout": 30
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "A task is being completed. Details: $ARGUMENTS\n\nVerify traceability:\n1. Check git log -5 for Refs: or Task: trailers\n2. Verify modified source files exist\n\nRespond {\"ok\": true} if adequate, or {\"ok\": false, \"reason\": \"...\"} if not.",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

#### Tarea 2.3: Actualizar sdd-setup para ofrecer opt-in

**Archivo**: `sdd-setup/SKILL.md`

Agregar despues de Step 5 (Configure Settings):

```markdown
### Step 5.7: Optional Features (Opt-in)

Present the user with optional hook packages:

1. **Dashboard Live Server** (H6):
   - "Enable real-time dashboard updates? Requires running `npm run start:dashboard` in the server/ directory."
   - If yes: merge `settings-optional-dashboard.json` into project settings
   - Show: "Dashboard hooks installed. Start the server with: cd $SDD/server && npm run start:dashboard"

2. **Quality Gates** (H4 + H7):
   - "Enable automatic traceability verification? Uses LLM to verify commits have proper trailers."
   - If yes: merge `settings-optional-quality-gates.json` into project settings
   - Warn: "Quality gates add ~30s to session end (H4) and ~60s per task completion (H7)"
   - Show: "Quality gates installed. They activate automatically next session."
```

**Archivos totales Fase 2**: 2 nuevos (templates opcionales), 1 modificado (sdd-setup)

---

### Fase 3: Dashboard HTML Updates

**Objetivo**: Actualizar el template HTML del dashboard para usar SSE en lugar de JSONP polling.

#### Tarea 3.1: SSE client en dashboard HTML

**Archivo**: `sdd-dashboard/references/html-template.md`

Agregar al template HTML (seccion JavaScript):

```javascript
// SSE Real-time connection (replaces JSONP polling)
(function initSSE() {
  const STATUS_DOT = document.getElementById('live-dot');
  const FEED = document.getElementById('activity-feed');

  // Detect if served via HTTP (SSE available) or file:// (fallback to JSONP)
  if (location.protocol === 'file:') {
    // Keep existing JSONP polling for file:// protocol
    initJSONPPolling();
    return;
  }

  const evtSource = new EventSource('/events');

  evtSource.addEventListener('artifact-changed', (e) => {
    const data = JSON.parse(e.data);
    addActivityEntry(data);
    updatePipelineStage(data.stage, 'running');
  });

  evtSource.addEventListener('session-start', (e) => { ... });
  evtSource.addEventListener('session-stop', (e) => { ... });
  evtSource.addEventListener('agent-start', (e) => { ... });
  evtSource.addEventListener('agent-stop', (e) => { ... });
  evtSource.addEventListener('task-completed', (e) => { ... });
  evtSource.addEventListener('heartbeat', () => { updateConnectionStatus('connected'); });

  evtSource.onerror = () => { updateConnectionStatus('disconnected'); };
})();
```

#### Tarea 3.2: Activity feed UI component

**Archivo**: `sdd-dashboard/references/html-template.md`

Agregar al template HTML (seccion del activity feed):
- Panel lateral o bottom drawer con el feed de actividad
- Cada entrada: timestamp, icono por tipo, stage badge, mensaje
- Auto-scroll al ultimo evento
- Indicador de conexion SSE (verde=conectado, gris=desconectado, amarillo=file:// mode)
- Max 50 entradas visibles (scroll para mas)

#### Tarea 3.3: Connection status indicator

**Archivo**: `sdd-dashboard/references/html-template.md`

En el header del dashboard:
- Dot verde pulsante: "Live" (SSE conectado)
- Dot gris: "Offline" (file:// protocol o server no disponible)
- Dot amarillo: "Polling" (JSONP fallback activo)

#### Tarea 3.4: Backward compatibility JSONP

La funcion `initJSONPPolling()` existente se mantiene intacta como fallback para `file://` protocol. No se elimina nada.

**Archivos totales Fase 3**: 1 modificado (html-template.md)

---

### Fase 4: Quality Gate Hooks

**Objetivo**: Agregar agent/prompt hooks que enforzan trazabilidad automaticamente.

#### Tarea 4.1: H7 — Traceability gate en TaskCompleted (agent hook)

**Archivo**: `automation/settings-template.json`

```json
"TaskCompleted": [
  {
    "hooks": [
      {
        "type": "http",
        "url": "http://localhost:3001/hooks/task-completed",
        "timeout": 5
      },
      {
        "type": "agent",
        "prompt": "A task is being marked as completed. Task details: $ARGUMENTS\n\nVerify traceability:\n1. Read the git log for the last 5 commits (git log -5 --format='%h %s' --no-walk)\n2. Check that commits related to this task have Refs: or Task: trailers (git log -5 --format='%(trailers:key=Refs,key=Task)')\n3. If the task involved source code changes, verify that modified files exist and are non-empty\n\nRespond {\"ok\": true} if traceability is adequate, or {\"ok\": false, \"reason\": \"Missing Refs: trailers in commits for this task. Add trailers before completing.\"} if not.",
        "timeout": 60
      }
    ]
  }
]
```

#### Tarea 4.2: Mejorar H4 — Pipeline consistency en Stop (ya definido en 0.4)

El prompt hook de Fase 0.4 ya cubre esto. Opcionalmente, podemos upgradearlo a agent hook si el prompt hook resulta insuficiente en la practica.

#### Tarea 4.3: Hooks en skill frontmatter (task-implementer)

**Archivo**: `sdd-task-implementer/SKILL.md`

Agregar al frontmatter YAML:

```yaml
---
name: sdd-task-implementer
description: "..."
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: "The task-implementer skill is about to stop. Context: $ARGUMENTS\n\nCheck: Did Claude commit all implemented tasks with proper Conventional Commits format and Refs:/Task: trailers? If the last message mentions uncommitted work, respond {\"ok\": false, \"reason\": \"Uncommitted task implementation detected. Commit with proper trailers before stopping.\"}. Otherwise respond {\"ok\": true}."
          timeout: 30
---
```

#### Tarea 4.4: Hooks en skill frontmatter (spec-auditor)

**Archivo**: `sdd-spec-auditor/SKILL.md`

```yaml
---
hooks:
  Stop:
    - hooks:
        - type: prompt
          prompt: "The spec-auditor skill is about to stop. Context: $ARGUMENTS\n\nCheck: Did Claude address all P0/P1 findings? If the audit report shows unresolved P0 or P1 findings and Claude hasn't mentioned deferring them with user approval, respond {\"ok\": false, \"reason\": \"Unresolved P0/P1 findings remain. Address critical findings before completing audit.\"}. Otherwise respond {\"ok\": true}."
          timeout: 30
---
```

**Archivos totales Fase 4**: 1 modificado (settings-template.json), 2 skills con frontmatter nuevo

---

### Fase 5: Setup & Documentation

**Objetivo**: Actualizar sdd-setup, documentacion, y MEMORY.

#### Tarea 5.1: Actualizar sdd-setup SKILL.md

**Archivo**: `sdd-setup/SKILL.md`

Agregar pasos:
- Step 5.5 (ya existe para MCP): extender para tambien verificar/build dashboard server
- Step nuevo: "Start Dashboard Server" (opcional, instrucciones para el usuario)
- Agregar verificacion de puerto 3001 disponible
- Nota: dashboard server es opcional — si no corre, HTTP hooks fallan silenciosamente

#### Tarea 5.2: Actualizar automation/INSTALL.md

**Archivo**: `automation/INSTALL.md`

Agregar seccion:
- "Dashboard Live Server" — como iniciar, configurar puerto, verificar que funciona
- Nota sobre HTTP hooks y non-blocking error handling

#### Tarea 5.3: Actualizar CLAUDE.md

**Archivo**: `CLAUDE.md`

Cambios:
- Actualizar tabla de hooks: H1-H8
- Agregar seccion "Dashboard Live Server" en MCP server
- Actualizar "Automation" para incluir HTTP hooks, prompt hooks, agent hooks, skill frontmatter hooks
- Mencionar nuevos eventos soportados
- Actualizar settings-template description

#### Tarea 5.4: Actualizar MEMORY

**Archivo**: `memory/MEMORY.md`

Agregar:
- Hooks v2 migration details
- Dashboard server architecture
- New hook types (H6, H7, H8)

#### Tarea 5.5: Actualizar READMEs del plugin

Para la sincronizacion al plugin repo posterior.

**Archivos totales Fase 5**: ~5 modificados

---

## Resumen de Archivos

### Nuevos (8)
| Archivo | Fase | Descripcion |
|---------|------|-------------|
| `automation/scripts/migrate-hooks-v2.sh` | 0.5.1 | Script de migracion v1→v2 |
| `automation/settings-optional-dashboard.json` | 2.1 | Template opt-in hooks HTTP dashboard |
| `automation/settings-optional-quality-gates.json` | 2.2 | Template opt-in quality gates |
| `server/src/dashboard-server.ts` | 1.1 | HTTP server + routing |
| `server/src/sse.ts` | 1.2 | SSE client manager |
| `server/src/path-mapper.ts` | 1.3 | Path-to-stage mapper |
| `server/src/dashboard-entry.ts` | 1.4 | CLI entry point |
| `server/test/dashboard-server.test.ts` | 1.5 | Tests basicos |

### Modificados (~12)
| Archivo | Fases | Cambios |
|---------|-------|---------|
| **Plugin** `hooks/hooks.json` | 0.1-0.4 | SessionStart event, remove H4 placeholder, fix timeouts |
| **Plugin** `scripts/sdd-upstream-guard.sh` | 0.2 | hookSpecificOutput wrapper |
| `automation/settings-template.json` | 0 | Mismos fixes que plugin (para manual install) |
| `automation/hooks/sdd-upstream-guard.sh` | 0.2 | hookSpecificOutput wrapper (copia sdd-skills) |
| `automation/hooks/sdd-pipeline-state-updater.sh` | 0.5 | sddVersion en template init |
| `server/package.json` | 1.4 | Agregar bin + script dashboard |
| `sdd-dashboard/references/html-template.md` | 3 | SSE client + activity feed + connection indicator |
| `sdd-task-implementer/SKILL.md` | 4.3 | Hooks en frontmatter |
| `sdd-spec-auditor/SKILL.md` | 4.4 | Hooks en frontmatter |
| `sdd-setup/SKILL.md` | 0.5.2, 2.3, 5.1 | Step 0 upgrade detection + opt-in features + dashboard |
| `sdd-onboarding/SKILL.md` | 0.5.3 | Step 2.7 automation version check |
| `CLAUDE.md` | 5.3 | Hooks v2, dashboard server, migration |

### Sin cambios
| Archivo | Razon |
|---------|-------|
| `automation/hooks/sdd-session-start.sh` | Script ya produce JSON correcto; solo cambia el evento en hooks.json |
| `sdd-dashboard/generate.py` | Sin cambios; sigue generando traceability-graph.json |
| `sdd-dashboard/references/live-status-template.md` | Se mantiene para backward compat (file://) |

---

## Orden de Ejecucion y Dependencias

```
Fase 0 (fix hooks core — plugin + sdd-skills)
  |
  +--> Fase 0.5 (migracion + upgrade detection)
  |       |
  |       +--> depende de F0 porque el script de migracion debe saber el formato target
  |
  +--> Fase 1 (dashboard server)
  |       |
  |       +--> Fase 2 (opt-in HTTP hooks + templates) -- requiere que el server exista
  |       |
  |       +--> Fase 3 (dashboard HTML SSE) -- requiere conocer API del server
  |
  +--> Fase 4 (quality gates) -- independiente, parallelizable con F1
  |
  +--> Fase 5 (docs) -- va al final
```

**Critical path**: F0 → F0.5 → (F1 → F2 + F3) + F4 → F5

**Parallelizable**: F1 y F4 son independientes entre si.

## Riesgos y Mitigaciones

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| Server no esta corriendo cuando hooks HTTP disparan | Bajo | HTTP hooks non-blocking by design; error silencioso |
| Puerto 3001 ocupado | Bajo | Configurable via `SDD_DASHBOARD_PORT` env var |
| SSE no soportado en browser viejo | Bajo | Fallback a JSONP (file://) o EventSource polyfill |
| Agent hooks en TaskCompleted son lentos (60s) | Medio | Opt-in, infrecuente; timeout configurable |
| Prompt hooks en Stop causan loop infinito | Alto | `stop_hook_active` flag previene recursion; prompt dice "respond ok:true if no clear issues" |
| Hooks duplicados plugin + proyecto tras migracion | Alto | **migrate-hooks-v2.sh** detecta y limpia duplicados; sdd-setup Step 0 previene |
| Proyecto con hooks customizados pierde cambios en migracion | Alto | Migration script hace backup; solo toca hooks con commands conocidos (sdd-*); no borra hooks custom |
| Plugin update rompe proyectos con settings.json viejo | Medio | Plugin hooks.json y proyecto settings.json se MERGE — no se pisan. Plugin hooks nuevos coexisten con proyecto hooks viejos |
| Hooks en skill frontmatter no soportados en CC viejo | Bajo | Graceful degradation — CC ignora frontmatter desconocido |
| Timeouts seconds vs ms confusion durante transicion | Medio | Migration script corrige automaticamente; docs claros |

## Criterios de Completitud

- [ ] Fase 0: Plugin `hooks.json` usa SessionStart event real, hookSpecificOutput, sin H4 placeholder
- [ ] Fase 0.5: `migrate-hooks-v2.sh --dry-run` detecta v1 signals correctamente; sdd-setup Step 0 existe
- [ ] Fase 1: `node dist/dashboard-entry.js` arranca server, acepta POST, sirve SSE stream
- [ ] Fase 2: Templates opt-in existen; sdd-setup ofrece dashboard y quality gates como opciones
- [ ] Fase 3: Dashboard HTML usa EventSource via HTTP, fallback JSONP en file://
- [ ] Fase 4: Skill frontmatter hooks en task-implementer y spec-auditor
- [ ] Fase 5: CLAUDE.md, INSTALL.md, sdd-setup, sdd-onboarding actualizados
- [ ] E2E: Proyecto nuevo con plugin → hooks v2 activos sin sdd-setup
- [ ] E2E: Proyecto v1 con plugin → sdd-setup detecta duplicados y limpia
- [ ] E2E: Proyecto v1 sin plugin → migrate-hooks-v2.sh actualiza in-place

## Sincronizacion Plugin

| Que | De donde → A donde | Notas |
|-----|-------------------|-------|
| `hooks/hooks.json` | Editar directamente en plugin repo | Es la fuente de verdad para hooks core |
| `scripts/sdd-upstream-guard.sh` | sdd-skills → plugin | Mantener en sync |
| `server/` (dashboard server) | sdd-skills → plugin | Copiar archivos nuevos |
| Skill frontmatter hooks | sdd-skills → plugin | Adaptar prefijos (`sdd-` → sin prefijo) |
| Templates opcionales | sdd-skills → plugin `shared-references/` | Para que sdd-setup los encuentre |
| CHANGELOG, plugin.json | Editar directamente en plugin repo | Bump version a 2.4.0 |

Orden de sync:
1. Implementar todo en sdd-skills
2. Editar plugin hooks.json directamente (Fase 0)
3. Copiar server/, scripts/, shared-references/ al plugin
4. Adaptar skill frontmatter (sin prefijo sdd-)
5. Test end-to-end en proyecto real con plugin
6. Bump plugin version, update CHANGELOG
