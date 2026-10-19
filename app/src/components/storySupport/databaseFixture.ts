import {
  GROUP_HEADER_HEIGHT,
  GROUP_PADDING,
  normalize,
  type AppNode,
  type ClusterNode,
  type Link,
  type SourceRef,
  type TaskData,
  type TaskNode,
} from '../../model'
import type { Saved } from '../../persist'
import { skinOf } from '../../skins'

// Spike #102: a canvas shaped like Orion's own work, with pull requests, Jira issues, a gate, notes, and a nested group.

// The story shows the Trading Card skin, so cards are laid out at its size.
const CARD = skinOf('trading').size
const COLUMNS = 4
const GAP_X = 48
const GAP_Y = 40

const pull = (number: number, additions: number, deletions: number, extra: Partial<SourceRef> = {}): SourceRef => ({
  source: 'github',
  kind: 'pull',
  key: `vocksel/orion#${number}`,
  url: `https://github.com/vocksel/orion/pull/${number}`,
  additions,
  deletions,
  ...extra,
})

const issue = (number: number): SourceRef => ({
  source: 'github',
  kind: 'issue',
  key: `vocksel/orion#${number}`,
  url: `https://github.com/vocksel/orion/issues/${number}`,
})

const jira = (key: string, priority: string): SourceRef => ({
  source: 'jira',
  kind: 'issue',
  key,
  url: `https://example.atlassian.net/browse/${key}`,
  details: { priority },
})

type CardSpec = { id: string } & Partial<TaskData> & Pick<TaskData, 'label'>

const group = (id: string, label: string, x: number, y: number, parentId?: string): ClusterNode => ({
  id,
  type: 'cluster',
  position: { x, y },
  ...(parentId ? { parentId } : {}),
  data: { kind: 'cluster', label },
})

/** Cards in rows of four inside their group, starting `rowOffset` rows down. */
function cards(parentId: string, specs: CardSpec[], rowOffset = 0): TaskNode[] {
  return specs.map(({ id, ...data }, index) => ({
    id,
    type: 'task',
    parentId,
    position: {
      x: GROUP_PADDING + (index % COLUMNS) * (CARD.width + GAP_X),
      y: GROUP_HEADER_HEIGHT + (Math.floor(index / COLUMNS) + rowOffset) * (CARD.height + GAP_Y),
    },
    data: {
      kind: 'task',
      itemKind: data.refs?.some((ref) => ref.kind === 'pull') ? 'pr' : 'step',
      status: 'todo',
      repo: data.refs?.some((ref) => ref.source === 'github') ? 'vocksel/orion' : undefined,
      ...data,
    },
  }))
}

const engine = cards('engine', [
  { id: 'luau-store', label: 'Move the store into the Luau CLI', status: 'done', refs: [pull(212, 1840, 960)] },
  { id: 'operations', label: 'Send canvas edits as operations', status: 'done', refs: [pull(268, 720, 310)] },
  { id: 'derive-server', label: 'Derive status on the server', status: 'done', refs: [pull(301, 530, 410)] },
  { id: 'serve-ws', label: 'Push changes over WebSocket', status: 'review', who: 'review', refs: [pull(355, 240, 60)] },
  { id: 'snoozes', label: 'Apply CI job snoozes in orion serve', status: 'review', who: 'you', refs: [pull(440, 188, 42)] },
  { id: 'agent-guide', label: 'Split the agent guide by topic', status: 'active', who: 'you', refs: [pull(500, 96, 210)] },
  { id: 'engine-gate', label: 'Phase 1 ships', itemKind: 'gate' },
  { id: 'engine-note', label: 'One engine: every rule lives in the CLI, and the app only draws.', itemKind: 'note' },
])

const parity = cards('parity', [
  { id: 'parity-derive', label: 'Parity specs for derive', status: 'done', refs: [pull(377, 410, 12)] },
  { id: 'parity-layout', label: 'Parity specs for layout', status: 'active', who: 'ci', refs: [pull(462, 620, 80, { details: { draft: true } })] },
  { id: 'parity-query', label: 'Share the query grammar with the app' },
])

const spikes = cards('spikes', [
  { id: 'spike-placements', label: 'Spike: placements', status: 'active', who: 'you', refs: [issue(122)] },
  { id: 'spike-database', label: 'Spike: database views', status: 'active', who: 'you', refs: [issue(102)] },
  { id: 'spike-sessions', label: 'Spike: agent sessions', status: 'active', refs: [issue(293)] },
  { id: 'spike-verdicts', label: 'Phase 2 plan', itemKind: 'gate' },
  { id: 'type-registry', label: 'Type registry', refs: [issue(215)] },
  { id: 'spike-note', label: 'Each spike is time-boxed and ends in a verdict: pursue, reshape, or shelve.', itemKind: 'note' },
])

const support = cards('support', [
  { id: 'jira-sync', label: 'Jira sync drops sprint field', status: 'active', who: 'you', refs: [jira('ORI-41', 'High')] },
  { id: 'jira-login', label: 'Re-auth when the Jira token expires', refs: [jira('ORI-38', 'Highest')] },
  { id: 'jira-export', label: 'Export a group as CSV', refs: [jira('ORI-52', 'Low')] },
  {
    id: 'jira-dark',
    label: 'Dark mode contrast on gate cards',
    status: 'review',
    who: 'review',
    refs: [jira('ORI-47', 'Medium'), pull(471, 34, 12)],
  },
  { id: 'jira-flaky', label: 'Flaky reconnect test', status: 'deferred', refs: [jira('ORI-29', 'Low')] },
])

const docs = cards('docs', [
  { id: 'docs-reference', label: 'Generate the CLI reference', status: 'done', refs: [pull(318, 300, 40)] },
  { id: 'docs-themes', label: 'Document theme files', status: 'review', who: 'review', refs: [pull(486, 142, 18)] },
  { id: 'docs-tour', label: 'Write a first-run tour' },
  { id: 'docs-agents', label: 'Explain the agent workflow' },
])

const nodes: AppNode[] = [
  group('engine', 'Phase 1: One engine', 0, 0),
  ...engine,
  group('parity', 'Server parity', GROUP_PADDING, GROUP_HEADER_HEIGHT + 2 * (CARD.height + GAP_Y), 'engine'),
  ...parity,
  group('spikes', 'Phase 2 spikes', 1120, 0),
  ...spikes,
  group('support', 'Support', 1120, 840),
  ...support,
  group('docs', 'Docs site', 0, 1280),
  ...docs,
]

const blocks = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })

const links: Link[] = [
  blocks('luau-store', 'operations'),
  blocks('operations', 'derive-server'),
  blocks('derive-server', 'serve-ws'),
  blocks('derive-server', 'snoozes'),
  blocks('serve-ws', 'engine-gate'),
  blocks('snoozes', 'engine-gate'),
  blocks('agent-guide', 'engine-gate'),
  blocks('parity-derive', 'parity-layout'),
  blocks('parity-layout', 'parity-query'),
  blocks('parity-query', 'engine-gate'),
  blocks('engine-gate', 'spike-placements'),
  blocks('spike-placements', 'spike-verdicts'),
  blocks('spike-database', 'spike-verdicts'),
  blocks('spike-sessions', 'spike-verdicts'),
  blocks('spike-verdicts', 'type-registry'),
  blocks('jira-login', 'jira-sync'),
  blocks('docs-reference', 'docs-agents'),
  blocks('docs-themes', 'docs-tour'),
]

export const databaseCanvas = (): Saved => ({ nodes: normalize(structuredClone(nodes), CARD), links: structuredClone(links) })
