// sdd-live — what is happening in an SDD project, live, inside Claude Code.
//
// - Above the prompt: the SDD phase, the delivery in course, requirements proven, the gate; then what runs now (the
//   SDD skill, how many agents work and on what).
// - /sdd opens a pane: Now (skill and stage), Agents (each subagent: what it was asked, its type, how long, its last
//   action and its recent ones, how it ended), Project (requirements with their warnings in plain words), Journal,
//   and the customer page's link.
// - Toasts when an agent finishes and when the phase, the proven count or the gate changes.
//
// Agents are followed from the engine's own events: `agent.spawn` (what it was asked, its id), `tool.call` carrying
// that id (what it does), `turn.complete` carrying it (how it ended), and `$.agent.list()` for the status of the
// ones still alive. The project comes from `sdd status build --no-out` (read-only), refreshed when the session
// starts, after each main turn and after an SDD skill or a commit.
import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Agent, Now, Snapshot } from '../../types/sdd-live'

const PANE = 'sdd-live'
const snap = atom({ plugin: 'sdd-pipeline', key: 'snap' } as const, null)
const error = atom({ plugin: 'sdd-pipeline', key: 'error' } as const, null)
const target = atom({ plugin: 'sdd-pipeline', key: 'target' } as const, null)
const isHidden = atom({ plugin: 'sdd-pipeline', key: 'isHidden' } as const, false)
const agents = atom({ plugin: 'sdd-pipeline', key: 'agents' } as const, [])
const now = atom({ plugin: 'sdd-pipeline', key: 'now' } as const, { skill: null, skillAt: null, last: null, lastAt: null })

const PHASE: Record<string, string> = {
  understand: 'Entender', agree: 'Acordar', design: 'Diseñar', plan: 'Planificar',
  build: 'Construir', verify: 'Comprobar', deliver: 'Entregar', done: 'Entregado',
}
const STATUS: Record<string, string> = {
  pending: 'Pendiente', building: 'En construcción', shown: 'Demostrado', failing: 'No cumple',
  deferred: 'Aplazado', deprecated: 'Retirado',
}
const WARN: Record<string, string> = {
  unshown: 'falta captura', weakened: 'prueba sin el texto exacto', challenge: 'revisor encontró un problema',
  stale: 'evidencia antigua', failing: 'prueba falla',
}
const GATE: Record<number, string> = { 0: 'gate ok', 1: 'gate: no cumplido', 2: 'gate: evidencia antigua', 3: 'gate ok con aplazados', 4: 'gate: hallazgo abierto' }
const COLOR: Record<string, string> = { shown: 'success', building: 'suggestion', failing: 'error', deferred: 'remember', pending: 'subtle', deprecated: 'subtle' }
/** The SDD skills by the stage a person recognises. */
const SKILL: Record<string, string> = {
  'sdd-requirements-engineer': 'Requisitos', 'sdd-specifications-engineer': 'Especificaciones', 'sdd-spec-auditor': 'Auditoría de specs',
  'sdd-test-planner': 'Plan de pruebas', 'sdd-plan-architect': 'Plan de entregas', 'sdd-task-generator': 'Tareas',
  'sdd-task-implementer': 'Construcción', 'sdd-acceptance': 'Aceptación', 'sdd-gap-detector': 'Huecos spec/código',
  'sdd-req-change': 'Cambio de requisitos', 'sdd-tech-designer': 'Diseño técnico', 'sdd-ux-designer': 'Diseño UX',
  'sdd-security-auditor': 'Auditoría de seguridad', 'sdd-orchestrator': 'Orquestador', 'sdd-lead': 'Lead multisesión',
  'sdd-setup': 'Puesta en marcha', 'sdd-pipeline-status': 'Estado del pipeline', 'sdd-reverse-engineer': 'Ingeniería inversa',
  'sdd-reconcile': 'Reconciliar specs', 'sdd-import': 'Importar', 'sdd-session-summary': 'Resumen de sesión',
}
const LIVE = new Set(['pending', 'running', 'waiting'])
const AGENT_ICON: Record<string, string> = { running: '▶', pending: '…', waiting: '⏸', idle: '·', completed: '✓', failed: '✗', killed: '■' }
const AGENT_COLOR: Record<string, string> = { running: 'claude', pending: 'subtle', waiting: 'warning', idle: 'subtle', completed: 'success', failed: 'error', killed: 'subtle' }

/** The skill's short name: `sdd-pipeline:sdd-acceptance` → `sdd-acceptance`. */
function skillName(skill: string): string {
  return String(skill).split(':').pop() || String(skill)
}
function base(p: unknown): string {
  return String(p ?? '').split('/').filter(Boolean).pop() || String(p ?? '')
}
function clip(s: unknown, n: number): string {
  const t = String(s ?? '').replace(/\s+/g, ' ').trim()
  return t.length > n ? `${t.slice(0, n - 1)}…` : t
}
/** One line for what a tool call does, in the words a person reads in a log. */
function describe(e: any): string {
  switch (e.tool) {
    case 'Bash': return `$ ${clip(e.command, 70)}`
    case 'Read': return `lee ${base(e.file_path)}`
    case 'Edit': case 'MultiEdit': return `edita ${base(e.file_path)}`
    case 'Write': return `escribe ${base(e.file_path)}`
    case 'Grep': return `busca «${clip(e.pattern, 40)}»`
    case 'Glob': return `lista ${clip(e.pattern, 40)}`
    case 'Skill': return `skill ${skillName(e.skill)}`
    case 'Agent': case 'Task': return `lanza agente «${clip(e.description, 40)}»`
    case 'WebFetch': return `consulta ${clip(e.url, 50)}`
    case 'WebSearch': return `busca en la web «${clip(e.query, 40)}»`
    default: return String(e.tool)
  }
}
function ago(ms: number): string {
  const s = Math.max(0, Math.round(ms / 1000))
  if (s < 60) return `${s}s`
  const m = Math.floor(s / 60)
  return m < 60 ? `${m}m${String(s % 60).padStart(2, '0')}s` : `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}m`
}

/** The sdd.mjs this view runs: the plugin's own when shipped inside sdd-pipeline, else $SDD_PLUGIN_ROOT's, else the
 * newest installed sdd-pipeline in the plugin cache (a release ranks above its own pre-release). */
async function cli($: any): Promise<string | null> {
  const own = `${$.plugin.root}/scripts/sdd.mjs`
  if (await $.fs.exists(own)) return own
  const env = await $.env.get('SDD_PLUGIN_ROOT')
  if (env && (await $.fs.exists(`${env}/scripts/sdd.mjs`))) return `${env}/scripts/sdd.mjs`
  const home = await $.env.get('HOME')
  const cache = `${home}/.claude/plugins/cache/noelserdna/sdd-pipeline`
  if (!(await $.fs.exists(cache))) return null
  const versions = (await $.fs.list(cache)).filter((x: any) => x.kind === 'dir' && /^\d+\.\d+\.\d+/.test(x.name)).map((x: any) => x.name)
  const key = (v: string) => { const [core = '', pre] = v.split('-', 2); return [...core.split('.').map(n => Number(n) || 0), pre ? 0 : 1] }
  versions.sort((a: string, b: string) => { const x = key(a), y = key(b); for (let i = 0; i < 4; i++) if ((x[i] ?? 0) !== (y[i] ?? 0)) return (y[i] ?? 0) - (x[i] ?? 0); return 0 })
  return versions.length ? `${cache}/${versions[0]}/scripts/sdd.mjs` : null
}

/** Rebuilds the project snapshot (read-only); a folder with no SDD project leaves it null. */
async function refresh($: any, quiet = true) {
  const root = (await read($, target)) || (await $.session.cwd())
  const isSdd = (await $.fs.exists(`${root}/pipeline-state.json`)) || (await $.fs.exists(`${root}/requirements/REQUIREMENTS.md`))
  if (!isSdd) { await update($, snap, () => null); await update($, error, () => null); await status($); return }
  const sdd = await cli($)
  if (!sdd) { await update($, error, () => 'no encuentro el plugin sdd-pipeline'); return }
  const run = await $.process.run(['node', sdd, 'status', 'build', '--no-out'], { cwd: root, timeoutMs: 60000 })
  if (run.exitCode !== 0) { await update($, error, () => (run.stderr || run.stdout).split('\n')[0].slice(0, 200)); return }
  let d: any
  try { d = JSON.parse(run.stdout) } catch { await update($, error, () => 'salida de sdd status build ilegible'); return }
  const active = (d.requirements || []).filter((r: any) => r.status !== 'deprecated')
  const s: Snapshot = {
    root,
    name: d.project?.name || base(root),
    phase: d.where?.phase || 'understand',
    now: d.where?.now || '',
    next: d.where?.next ?? null,
    ask: (d.where?.needFromYou || []).map((a: any) => a.text),
    fase: d.where?.fase ? `entrega ${d.where.fase.n}/${d.where.fase.of}` : null,
    shown: active.filter((r: any) => r.status === 'shown').length,
    total: active.length,
    gate: d.technical?.gate?.code ?? null,
    reqs: active.map((r: any) => ({ id: r.id, title: r.title, plain: r.plain, status: r.status, fase: r.fase,
      warnings: [...new Set<string>((r.warnings || []).map((w: any) => w.code))] })),
    journal: (d.journal || []).slice(-8).reverse().map((j: any) => ({ at: j.at, kind: j.kind, text: j.text })),
    url: d.page?.url ?? null,
    at: await $.clock.now(),
  }
  const before = await read($, snap)
  await update($, snap, () => s)
  await update($, error, () => null)
  await status($)
  if (!quiet && before && before.root === s.root) {
    if (before.phase !== s.phase) $.ui.toast(`SDD: ahora ${PHASE[s.phase] || s.phase} — ${s.now}`)
    else if (before.shown !== s.shown) $.ui.toast(`SDD: ${s.shown} de ${s.total} requisitos demostrados`)
    else if (before.gate !== s.gate && s.gate !== null) $.ui.toast(`SDD: ${GATE[s.gate] || 'gate ' + s.gate}`)
  }
}

/** The status line: the phase and the agents at work. */
async function status($: any) {
  const s = await read($, snap)
  const live = (await read($, agents)).filter(a => LIVE.has(a.status)).length
  const parts = [s ? `SDD ${PHASE[s.phase] || s.phase} · ${s.shown}/${s.total}` : null, live ? `${live} agente${live === 1 ? '' : 's'}` : null].filter(Boolean)
  $.ui.status(parts.length ? parts.join(' · ') : undefined)
}

/** Records one agent's change; the list keeps the newest 40. */
async function touch($: any, id: string, change: (a: Agent) => Agent, create?: () => Agent) {
  await update($, agents, list => {
    const i = list.findIndex(a => a.id === id)
    if (i === -1) return create ? [create(), ...list].slice(0, 40) : list
    const next = [...list]
    next[i] = change(next[i] as Agent)
    return next
  })
}

/** Reconciles the statuses with the engine's own list (an agent stopped, killed or left waiting). */
async function poll($: any) {
  const mine = await read($, agents)
  if (!mine.some(a => LIVE.has(a.status))) return
  let rows: any[] = []
  try { rows = await $.agent.list() } catch { return }
  const at = await $.clock.now()
  for (const r of rows) {
    const known = mine.find(a => a.id === r.id)
    if (known && known.status !== r.status) {
      await touch($, r.id, a => ({ ...a, status: r.status, endedAt: LIVE.has(r.status) ? null : (a.endedAt ?? at) }))
    }
  }
  await status($)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'sdd', description: 'Panel en vivo del proyecto SDD: etapa, agentes en marcha, requisitos y diario', argumentHint: '[ruta del proyecto | refresh | off | clear]' })
    const started = await next(e)
    void refresh($).catch(() => {})
    $.clock.every(5000, () => { void poll($).catch(() => {}) })
    return started
  })

  on('agent.spawn', async ($, e, next) => {
    const r: any = await next(e)
    if (r && r.agentId) {
      const at = await $.clock.now()
      const ev: any = e
      await touch($, r.agentId, a => a, () => ({
        id: r.agentId, description: clip(ev.description || ev.subagentType, 80), type: String(ev.subagentType || 'agent'),
        workflow: ev.workflow?.runId ?? null, parent: ev.parentAgentId ?? null, status: 'running',
        startedAt: at, endedAt: null, last: null, lastAt: null, actions: 0, recent: [],
      }))
      await status($)
    }
    return r
  }).catch(($, e, next) => next(e)) // an observer: whatever fails here, the agent starts

  on('tool.call', async ($, e, next) => {
    const ev: any = e
    const line = describe(ev)
    const at = await $.clock.now()
    if (ev.agentId) {
      await touch($, ev.agentId, a => ({ ...a, status: 'running', last: line, lastAt: at, actions: a.actions + 1, recent: [line, ...a.recent].slice(0, 6) }))
    } else {
      await update($, now, n => ({ ...n, last: line, lastAt: at }))
      if (ev.tool === 'Skill' && /(^|:)sdd-/.test(String(ev.skill))) await update($, now, n => ({ ...n, skill: skillName(ev.skill), skillAt: at }))
    }
    const ran = await next(e)
    // a commit or an SDD skill changes the project: refresh it once the call is done
    if (!ev.agentId && ((ev.tool === 'Bash' && /\bgit (commit|merge|tag)\b|\bsdd(\.mjs)? (accept|journal|status|route)\b/.test(String(ev.command))) || ev.tool === 'Skill')) {
      void refresh($, false).catch(() => {})
    }
    return ran
  }).catch(($, e, next) => next(e)) // an observer: whatever fails here, the call runs

  on('skill.prompt', async ($, e, next) => {
    const name = skillName((e as any).skill)
    if (name.startsWith('sdd-')) { const at = await $.clock.now(); await update($, now, n => ({ ...n, skill: name, skillAt: at })) }
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const done: any = await next(e)
    const ev: any = e
    if (ev.agentId) {
      const at = await $.clock.now()
      const list = await read($, agents)
      const a = list.find(x => x.id === ev.agentId)
      if (a && LIVE.has(a.status)) {
        const ended = ev.isAborted ? 'killed' : 'completed'
        await touch($, ev.agentId, x => ({ ...x, status: ended, endedAt: at }))
        $.ui.toast(`${ended === 'completed' ? '✓' : '■'} Agente «${clip(a.description, 50)}» ${ended === 'completed' ? 'terminó' : 'se detuvo'} en ${ago(at - a.startedAt)}`)
        await status($)
      }
    } else {
      void refresh($, false).catch(() => {})
    }
    return done
  })

  on('command.run', { command: 'sdd' }, async ($, e) => {
    const arg = ((e as any).args || '').trim()
    if (arg === 'off') { await update($, target, () => null); await refresh($); return { text: 'sdd-live: vuelve a seguir el directorio de la sesión.' } }
    if (arg === 'clear') { await update($, agents, list => list.filter(a => LIVE.has(a.status))); await status($); return { text: 'sdd-live: agentes terminados borrados de la lista.' } }
    if (arg && arg !== 'refresh') {
      if (!(await $.fs.exists(arg))) return { text: `sdd-live: no existe ${arg}` }
      await update($, target, () => arg)
    }
    await update($, isHidden, () => false)
    await refresh($)
    const s = await read($, snap)
    await $.ui.open({ id: PANE, title: s ? `SDD · ${s.name}` : 'SDD · agentes' })
    const live = (await read($, agents)).filter(a => LIVE.has(a.status)).length
    return { text: s ? `Panel SDD de ${s.name} abierto (${live} agente${live === 1 ? '' : 's'} en marcha).` : ((await read($, error)) || `Este directorio no tiene un proyecto SDD; el panel muestra solo los agentes (${live} en marcha).`) }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const s = await read($, snap)
    const list = await read($, agents)
    const live = list.filter(a => LIVE.has(a.status))
    const n: Now = await read($, now)
    if ((!s && live.length === 0) || e.props.hasSurvey || (await read($, isHidden))) return next(e)
    const { Box, Text, Button } = $.ui.resolve(e)
    const t = await $.clock.now()
    const gate = s && s.gate !== null ? GATE[s.gate] : null
    const first = live[0]
    return (
      <Box flexDirection="column">
        <Box>
          <Text bold>SDD </Text>
          {s && <Text color="claude">{PHASE[s.phase] || s.phase}</Text>}
          {s && s.fase && <Text dimColor> · {s.fase}</Text>}
          {s && <Text dimColor> · {s.shown}/{s.total} demostrados</Text>}
          {gate && <Text color={s!.gate === 0 || s!.gate === 3 ? 'success' : 'warning'}> · {gate}</Text>}
          {n.skill && <Text dimColor> · {SKILL[n.skill] || n.skill}</Text>}
          {live.length > 0 && <Text color="claude"> · {live.length} agente{live.length === 1 ? '' : 's'}</Text>}
          <Text> </Text>
          <Button key="hide" label="Ocultar" plain onPress={() => update($, isHidden, () => true)} />
        </Box>
        {first && (
          <Text dimColor wrap="truncate-end">
            ▶ {first.description}{first.last ? ` — ${first.last}` : ''} ({ago(t - first.startedAt)}){live.length > 1 ? ` · y ${live.length - 1} más (/sdd)` : ''}
          </Text>
        )}
        {!first && s && s.ask.length > 0 && <Text color="warning" wrap="truncate-end">Necesitamos del cliente: {s.ask[0]}</Text>}
        {!first && s && s.ask.length === 0 && s.now && <Text dimColor wrap="truncate-end">{s.now}</Text>}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const s = await read($, snap)
    const err = await read($, error)
    const list = await read($, agents)
    const n: Now = await read($, now)
    const t = await $.clock.now()
    const live = list.filter(a => LIVE.has(a.status))
    const ended = list.filter(a => !LIVE.has(a.status)).slice(0, 6)
    const rows = Math.max(12, e.viewport?.rows ?? 30)
    const reqRoom = Math.max(3, rows - 18 - live.length * 3 - ended.length)
    const reqs = s ? [...s.reqs].sort((a, b) => (b.warnings.length - a.warnings.length) || a.id.localeCompare(b.id)).slice(0, reqRoom) : []
    return (
      <Box flexDirection="column">
        <Text bold>Ahora</Text>
        {s ? <Text wrap="wrap">{PHASE[s.phase] || s.phase}{s.fase ? ` · ${s.fase}` : ''} · {s.shown}/{s.total} demostrados — {s.now}</Text>
           : <Text dimColor wrap="wrap">{err || 'Sin proyecto SDD en este directorio (/sdd <ruta> para seguir otro).'}</Text>}
        {n.skill && <Text wrap="truncate-end">Skill: <Text color="claude">{SKILL[n.skill] || n.skill}</Text><Text dimColor> ({n.skill}, desde hace {ago(t - (n.skillAt ?? t))})</Text></Text>}
        {n.last && <Text dimColor wrap="truncate-end">Conversación principal: {n.last} (hace {ago(t - (n.lastAt ?? t))})</Text>}
        {s && s.ask.map(a => <Text color="warning" wrap="wrap">Del cliente: {a}</Text>)}
        <Text> </Text>
        <Text bold>Agentes {live.length ? `(${live.length} en marcha)` : ''}</Text>
        {list.length === 0 && <Text dimColor>Ningún agente lanzado en esta sesión.</Text>}
        {live.map(a => (
          <Box flexDirection="column">
            <Text wrap="truncate-end"><Text color={AGENT_COLOR[a.status] || 'text'}>{AGENT_ICON[a.status] || '?'} </Text><Text bold>{a.description}</Text><Text dimColor> · {a.type}{a.workflow ? ' · workflow' : ''} · {ago(t - a.startedAt)} · {a.actions} acciones</Text></Text>
            <Text dimColor wrap="truncate-end">   {a.last ? `ahora: ${a.last} (hace ${ago(t - (a.lastAt ?? t))})` : 'arrancando…'}</Text>
            {a.recent.length > 1 && <Text dimColor wrap="truncate-end">   antes: {a.recent.slice(1, 4).join(' · ')}</Text>}
          </Box>
        ))}
        {ended.map(a => (
          <Text dimColor wrap="truncate-end"><Text color={AGENT_COLOR[a.status] || 'subtle'}>{AGENT_ICON[a.status] || '·'} </Text>{a.description} · {a.type} · {ago((a.endedAt ?? t) - a.startedAt)} · {a.actions} acciones</Text>
        ))}
        {s && <Text> </Text>}
        {s && <Text bold>Requisitos</Text>}
        {reqs.map(r => (
          <Box flexDirection="column">
            <Text wrap="truncate-end">
              <Text color={COLOR[r.status] || 'text'}>{STATUS[r.status] || r.status}</Text>
              <Text dimColor> {r.id} </Text>
              {r.plain || r.title}
            </Text>
            {r.warnings.length > 0 && <Text color="warning" wrap="truncate-end">   ⚠ {r.warnings.map(w => WARN[w] || w).join(' · ')}</Text>}
          </Box>
        ))}
        {s && s.journal.length > 0 && <Text> </Text>}
        {s && s.journal.length > 0 && <Text bold>Diario</Text>}
        {s && s.journal.slice(0, 4).map(j => <Text wrap="truncate-end"><Text dimColor>{j.at.slice(0, 10)} </Text>{j.text}</Text>)}
        <Text> </Text>
        {s && (s.url ? <Text dimColor wrap="truncate-end">Página del cliente: {s.url}</Text> : <Text dimColor>Sin página del cliente publicada todavía.</Text>)}
        <Box>
          <Button key="refresh" label="Actualizar" onPress={() => refresh($, false)} />
          <Text> </Text>
          <Button key="clear" label="Limpiar terminados" onPress={() => update($, agents, l => l.filter(a => LIVE.has(a.status)))} />
        </Box>
      </Box>
    )
  })
}
