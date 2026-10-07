export type Req = { id: string; title: string; plain: string | null; status: string; warnings: string[]; fase: number | null }
export type Entry = { at: string; kind: string; text: string }
/** The SDD project as `sdd status build --no-out` describes it (contract sdd-status-v1, cut to what the views draw). */
export type Snapshot = {
  root: string
  name: string
  phase: string
  now: string
  next: string | null
  ask: string[]
  fase: string | null
  shown: number
  total: number
  gate: number | null
  reqs: Req[]
  journal: Entry[]
  url: string | null
  at: number
}
/** One subagent of this session: what it was asked, what it is doing now and how it ended. */
export type Agent = {
  id: string
  description: string
  type: string
  workflow: string | null
  parent: string | null
  status: string
  startedAt: number
  endedAt: number | null
  last: string | null
  lastAt: number | null
  actions: number
  recent: string[]
}
/** What is running in the main conversation: the SDD skill in course and the main loop's last action. */
export type Now = { skill: string | null; skillAt: number | null; last: string | null; lastAt: number | null }

declare module 'claude-code' {
  interface PluginState {
    'sdd-pipeline': {
      snap: Snapshot | null
      error: string | null
      target: string | null
      isHidden: boolean
      agents: Agent[]
      now: Now
    }
  }
}
