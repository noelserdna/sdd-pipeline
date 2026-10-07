import { test, expect } from 'claude-code/testing'

import { DATA } from './fixture'

/** The engine's answers for an SDD project at /p: its files, the installed CLI and `sdd status build --json`. */
function project(on: any, data: unknown) {
  on('session.cwd', () => ({ value: '/p' }))
  on('env.get', ($: any, e: any) => ({ value: e.name === 'HOME' ? '/home/me' : undefined }))
  on('fs.exists', ($: any, e: any) => ({ value: e.path === '/p/pipeline-state.json' || String(e.path).startsWith('/home/me/.claude/plugins/cache/noelserdna/sdd-pipeline') }))
  on('fs.list', () => ({ value: [{ name: '5.2.0-rc.1', kind: 'dir' as const, size: 0, mtimeMs: 0, isLink: false }, { name: '5.2.0', kind: 'dir' as const, size: 0, mtimeMs: 0, isLink: false }] }))
  on('process.run', ($: any, e: any) => ({ value: { exitCode: e.argv.includes('build') && String(e.argv[1]).includes('/5.2.0/') ? 0 : 1, stdout: JSON.stringify(data), stderr: '' } }))
  on('clock.now', () => ({ value: 0 }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('ui.status', () => ({ value: undefined as never }))
}

test('/sdd reads the project and the band and pane show it in plain words', async ($, on) => {
  project(on, DATA)
  const { text } = await $.command.run({ command: 'sdd', args: '' } as any)
  expect(text).toContain('Citas del Taller Ruiz')
  for (const surface of ['terminal', 'desktop'] as const) {
    const band = await $.ui.mount({ plugin: 'sdd-pipeline', surface, component: 'AbovePrompt', props: { hasSurvey: false } as any })
    expect(await band.find({ type: 'Text', text: /Construir/ })).toBeDefined()
    expect(await band.find({ type: 'Text', text: /3\/8 demostrados/ })).toBeDefined()
    await band.unmount()
  }
  const pane = await $.ui.mount({ plugin: 'sdd-pipeline', surface: 'terminal', component: 'Pane', requestId: 'sdd-live', props: {} as any })
  expect(await pane.find({ type: 'Text', text: /prueba sin el texto exacto/ })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: /revisor encontró un problema/ })).toBeDefined()
  await pane.unmount()
})

test('a folder with no SDD project says so and draws nothing above the prompt', async ($, on) => {
  on('session.cwd', () => ({ value: '/empty' }))
  on('fs.exists', () => ({ value: false }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('ui.status', () => ({ value: undefined as never }))
  const { text } = await $.command.run({ command: 'sdd', args: '' } as any)
  expect(text).toContain('no tiene un proyecto SDD')
})

test('a subagent shows up above the prompt and in the pane with what it was asked', async ($, on) => {
  on('session.cwd', () => ({ value: '/empty' }))
  on('fs.exists', () => ({ value: false }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('ui.status', () => ({ value: undefined as never }))
  on('clock.now', () => ({ value: 1_000_000 }))
  on('agent.spawn', () => ({ model: 'claude-opus-5-5', agentId: 'a-1' }))
  await $.agent.spawn({ prompt: 'Revisa los requisitos', description: 'Auditar requisitos', subagentType: 'general-purpose' } as any)
  for (const surface of ['terminal', 'desktop'] as const) {
    const band = await $.ui.mount({ plugin: 'sdd-pipeline', surface, component: 'AbovePrompt', props: { hasSurvey: false } as any })
    expect(await band.find({ type: 'Text', text: /1 agente/ })).toBeDefined()
    expect(await band.find({ type: 'Text', text: /Auditar requisitos/ })).toBeDefined()
    await band.unmount()
  }
  await $.command.run({ command: 'sdd', args: '' } as any)
  const pane = await $.ui.mount({ plugin: 'sdd-pipeline', surface: 'terminal', component: 'Pane', requestId: 'sdd-live', props: {} as any })
  expect(await pane.find({ type: 'Text', text: /Auditar requisitos/ })).toBeDefined()
  expect(await pane.find({ type: 'Text', text: /general-purpose/ })).toBeDefined()
  await pane.unmount()
})
