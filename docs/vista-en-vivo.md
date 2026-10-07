# Vista en vivo: el mod `sdd-live`

La página de estado (`references/status-page.md`) es para compartir con el cliente. Esta vista es para quien trabaja
dentro de Claude Code: en qué etapa SDD está el proyecto, qué skill se está ejecutando y **qué hacen los agentes**
que se han lanzado, sin abrir nada.

Viene con el plugin `sdd-pipeline`: al instalarlo o actualizarlo y reiniciar Claude Code queda activa (terminal, la
pestaña Code de la app de escritorio y VS Code). No necesita configuración.

## Qué muestra

**Encima del prompt**, en dos líneas:

```
SDD Construir · entrega 2/4 · 5/12 demostrados · gate: no cumplido · Construcción · 3 agentes  [Ocultar]
▶ Implementar TASK-F2-004 — edita src/ui/cv.js (1m12s) · y 2 más (/sdd)
```

Sin agentes en marcha, la segunda línea dice lo que necesitamos del cliente o qué se está haciendo. En un directorio
sin proyecto SDD, la franja solo aparece cuando hay agentes.

**El panel** (`/sdd`):

- **Ahora**: fase, entrega y requisitos demostrados; la skill SDD en curso y desde cuándo; la última acción de la
  conversación principal; lo que se necesita del cliente.
- **Agentes**: cada subagente de la sesión con lo que se le pidió, su tipo (y si viene de un workflow), cuánto lleva,
  cuántas acciones ha hecho, qué hace ahora y sus tres acciones anteriores. Los terminados quedan debajo con su
  duración y su final (✓ terminó, ■ se detuvo, ✗ falló).
- **Requisitos**: los que tienen avisos primero, con el aviso en llano (falta captura, prueba sin el texto exacto,
  un revisor encontró un problema…).
- **Diario**: las últimas líneas del diario del proyecto.
- El enlace a la página del cliente, y los botones «Actualizar» y «Limpiar terminados».

**Avisos** cuando un agente termina o se detiene, y cuando cambian la fase, los requisitos demostrados o el gate.
**Barra de estado**: `SDD Construir · 5/12 · 3 agentes`.

## Comandos

| Comando | Qué hace |
|---|---|
| `/sdd` | Abre el panel |
| `/sdd <ruta>` | Sigue otro proyecto SDD (útil desde un repo que no lo es) |
| `/sdd off` | Vuelve a seguir el directorio de la sesión |
| `/sdd refresh` | Vuelve a leer el proyecto |
| `/sdd clear` | Quita de la lista los agentes terminados |

## Cómo funciona

- Los agentes se siguen con los eventos del propio motor: `agent.spawn` (qué se le pidió y su id), cada
  `tool.call` que lleva ese id (qué hace), `turn.complete` con ese id (cómo terminó) y `$.agent.list()` cada 5 s para
  el estado de los que siguen vivos.
- El proyecto se lee con `sdd status build --no-out` (el mismo contrato que la página del cliente, sin escribir
  nada) al empezar la sesión, al terminar cada turno, tras una skill SDD y tras un commit, un merge, un tag o un
  `sdd accept|journal|status|route`.
- Solo observa: si algo falla en el mod, la herramienta o el agente siguen igual.
- El código está en `hooks/live/register.tsx`; su contrato de estado en `types/sdd-live.d.ts`; sus tests en
  `hooks/live/sdd-live.test.tsx` (`claude plugin test ./`).
