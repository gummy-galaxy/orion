import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { STALE_DAYS, type Motion, type Sticker } from '../skins/slotFacts'
import { ClusterView } from './ClusterView'
import { CurveEdge } from './CurveEdge'
import { SlotCard } from './SlotCard'
import { TaskView } from './TaskView'
import { StoryGraph } from './storySupport/StoryGraph'
import { stackLinks, stackNodes } from './storySupport/cardStack'

type SlotArgs = {
  kind: CardView['kind']
  title: string
  status: CardView['status']
  priority: 'unknown' | `${Priority}`
  size: 'unknown' | CardSizeLabel
  leverage: number
  sticker: 'none' | Sticker
  motion: 'none' | Motion
  blockers: number
  unblocks: number
  group: string
}

const DAY_MS = 24 * 60 * 60 * 1000

// A sticker that comes from readiness wins over motion, since a pull request has one readiness at a time.
function readinessOf(args: SlotArgs): Pick<CardView, 'readiness' | 'readyToMerge'> {
  if (args.sticker === 'conflict' || args.sticker === 'failing') return { readiness: args.sticker }

  if (args.sticker === 'mergeable') return { readiness: 'mergeable', readyToMerge: true }

  if (args.motion === 'running') return { readiness: 'running' }

  if (args.motion === 'queued') return { readiness: 'waiting' }

  return {}
}

function toView(args: SlotArgs): CardView {
  const stale = args.sticker === 'stale'

  return {
    id: 'playground',
    kind: args.kind,
    title: args.title,
    tag: 'vocksel/orion#158',
    url: null,
    status: args.status,
    statusLabel: args.status,
    leverage: args.leverage,
    sources: [],
    artSeed: 'playground',
    blockers: args.blockers,
    unblocks: args.unblocks,
    group: args.group,
    updatedAt: new Date(Date.now() - (stale ? STALE_DAYS + 6 : 0) * DAY_MS).toISOString(),
    ...readinessOf(args),
    ...(args.sticker === 'changes' ? { changesRequested: true as const } : {}),
    ...(args.priority !== 'unknown' ? { priority: Number(args.priority) as Priority } : {}),
    ...(args.size !== 'unknown' ? { size: args.size } : {}),
  }
}

function SlotFrame({ view }: { view: CardView }) {
  const className =
    view.kind === 'note'
      ? 'card skin-slots note'
      : `card skin-slots st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}`

  return (
    <div style={{ width: 264, height: 380 }}>
      <div className={className} style={{ width: '100%', height: '100%' }}>
        <SlotCard view={view} />
      </div>
    </div>
  )
}

const defaults: SlotArgs = {
  kind: 'pr',
  title: "Lay out cards at the active skin's size",
  status: 'review',
  priority: 'unknown',
  size: 'unknown',
  leverage: 8,
  sticker: 'mergeable',
  motion: 'none',
  blockers: 0,
  unblocks: 2,
  group: 'pr-queue',
}

const meta = {
  title: 'Canvas/Cards and edges/SlotCard',
  render: (args) => <SlotFrame view={toView(args)} />,
  args: defaults,
  argTypes: {
    kind: { control: 'inline-radio', options: ['pr', 'step', 'placeholder', 'gate', 'note'] },
    status: { control: 'select', options: ['ready', 'active', 'review', 'blocked', 'deferred', 'done'] },
    priority: {
      control: 'inline-radio',
      options: ['unknown', '0', '1', '2', '3'],
      description: 'Set by a source. Unknown falls back to an estimate from leverage.',
    },
    size: { control: 'inline-radio', options: ['unknown', 'S', 'M', 'L', 'XL'] },
    leverage: { control: { type: 'range', min: 0, max: 12 }, description: 'Open work downstream. 3 or more estimates P2, 6 or more P1.' },
    sticker: { control: 'select', options: ['none', 'conflict', 'failing', 'changes', 'stale', 'mergeable'] },
    motion: { control: 'inline-radio', options: ['none', 'running', 'queued'] },
    blockers: { control: { type: 'range', min: 0, max: 9 } },
    unblocks: { control: { type: 'range', min: 0, max: 9 } },
    group: { control: 'select', options: ['pr-queue', 'navigation', 'workspaces', 'backlog', 'release'], description: 'Picks the art palette.' },
  },
} satisfies Meta<SlotArgs>

export default meta
type Story = StoryObj<typeof meta>

export const Playground: Story = {}

export const Mergeable: Story = { name: '#158 · mergeable' }

export const ChecksRunning: Story = {
  name: '#272 · checks running',
  args: {
    title: "Show a card's far-zoom tag only while hovered or selected",
    leverage: 0,
    sticker: 'none',
    motion: 'running',
    unblocks: 0,
    group: 'navigation',
  },
}

export const BlockedAndFailing: Story = {
  name: '#164 · blocked, failing',
  args: {
    title: 'Draw trading card art as geometric posters built from each card',
    status: 'blocked',
    leverage: 1,
    sticker: 'failing',
    blockers: 1,
    unblocks: 1,
  },
}

export const Conflict: Story = {
  name: '#250 · conflict',
  args: { title: 'Select stickers like cards', leverage: 1, sticker: 'conflict', unblocks: 1, group: 'backlog' },
}

export const ChangesRequested: Story = {
  args: { title: 'Snap only to nearby nodes', leverage: 1, sticker: 'changes', unblocks: 1 },
}

export const Stale: Story = {
  args: { title: 'Pan with touchpad and hide shortcuts by default', leverage: 0, sticker: 'stale', unblocks: 0, group: 'navigation' },
}

export const CalmIssue: Story = {
  name: '#68 · calm issue',
  args: {
    kind: 'step',
    title: 'List commands after `>` in the command palette',
    status: 'ready',
    leverage: 1,
    sticker: 'none',
    unblocks: 1,
    group: 'navigation',
  },
}

export const SetByASource: Story = {
  args: { title: 'Report release health to PostHog', priority: '0', size: 'L', sticker: 'none', leverage: 2, group: 'release' },
}

export const UnlinkedStep: Story = {
  args: {
    kind: 'step',
    title: 'Let one card appear in many places',
    status: 'ready',
    leverage: 0,
    sticker: 'none',
    unblocks: 0,
    group: 'workspaces',
  },
}

export const ExpectedPullRequest: Story = {
  args: {
    kind: 'placeholder',
    title: 'Let the scroll setting follow the trackpad',
    status: 'ready',
    leverage: 0,
    sticker: 'none',
    unblocks: 0,
    group: 'navigation',
  },
}

export const Gate: Story = {
  args: { kind: 'gate', title: 'Card skins ship', status: 'blocked', leverage: 0, sticker: 'none', blockers: 2, unblocks: 0 },
}

export const Done: Story = {
  args: { title: 'Add a card skin registry with Classic and Plain skins', status: 'done', leverage: 0, sticker: 'none', unblocks: 0 },
}

export const Note: Story = {
  args: { kind: 'note', title: 'Merge the stack bottom up so each child picks up its parent before review.' },
}

/** Orion's own card skin stack and navigation work, linked and grouped as they are on the canvas. */
export const InGroups: Story = {
  parameters: { layout: 'fullscreen' },
  globals: { skin: 'slots', theme: 'vibrant' },
  render: () => (
    <StoryGraph
      nodes={stackNodes}
      links={stackLinks}
      edges={stackLinks.map((link) => ({ id: link.id, source: link.from, target: link.to, type: 'curve' }))}
      nodeTypes={{ cluster: ClusterView, task: TaskView }}
      edgeTypes={{ curve: CurveEdge }}
      width="100vw"
      height="100vh"
    />
  ),
}
