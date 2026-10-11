import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { STALE_DAYS, type Motion, type Sticker } from '../skins/tradingFacts'
import { TradingCard } from './TradingCard'

type TradingArgs = {
  kind: CardView['kind']
  title: string
  status: CardView['status']
  priority: 'unknown' | `${Priority}`
  size: 'unknown' | CardSizeLabel
  sticker: 'none' | Sticker
  motion: 'none' | Motion
  blockers: number
  unblocks: number
  group: string
  far: boolean
}

const DAY_MS = 24 * 60 * 60 * 1000

// A sticker that comes from readiness wins over motion, since a pull request has one readiness at a time.
function readinessOf(args: TradingArgs): Pick<CardView, 'readiness' | 'readyToMerge'> {
  if (args.sticker === 'conflict' || args.sticker === 'failing') return { readiness: args.sticker }

  if (args.sticker === 'mergeable') return { readiness: 'mergeable', readyToMerge: true }

  if (args.motion === 'running') return { readiness: 'running' }

  if (args.motion === 'queued') return { readiness: 'waiting' }

  return {}
}

function toView(args: TradingArgs): CardView {
  const stale = args.sticker === 'stale'

  return {
    id: 'playground',
    kind: args.kind,
    title: args.title,
    tag: 'vocksel/orion#158',
    url: null,
    status: args.status,
    statusLabel: args.status,
    leverage: 0,
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

// Far zoom wraps the card in the canvas's far-card tag, which sizes it on its own.
function TradingFrame({ view, far }: { view: CardView; far: boolean }) {
  const className =
    (view.kind === 'note'
      ? 'card skin-trading note'
      : `card skin-trading st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}`) +
    (far ? ' far-card' : '')

  return (
    <div style={far ? { position: 'relative', width: 240, height: 170 } : { width: 264, height: 380 }}>
      <div className={className} style={far ? { position: 'relative', translate: 'none' } : { width: '100%', height: '100%' }}>
        <TradingCard view={view} />
      </div>
    </div>
  )
}

const defaults: TradingArgs = {
  kind: 'pr',
  title: "Lay out cards at the active skin's size",
  status: 'review',
  priority: 'unknown',
  size: 'unknown',
  sticker: 'mergeable',
  motion: 'none',
  blockers: 0,
  unblocks: 2,
  group: 'pr-queue',
  far: false,
}

const meta = {
  title: 'Canvas/Cards and edges/TradingCard',
  render: (args) => <TradingFrame view={toView(args)} far={args.far} />,
  args: defaults,
  argTypes: {
    kind: { control: 'inline-radio', options: ['pr', 'step', 'placeholder', 'gate', 'note'] },
    status: { control: 'select', options: ['ready', 'active', 'review', 'blocked', 'deferred', 'done'] },
    priority: {
      control: 'inline-radio',
      options: ['unknown', '0', '1', '2', '3'],
      description: 'Set by a source. Unknown shows nothing.',
    },
    size: { control: 'inline-radio', options: ['unknown', 'S', 'M', 'L', 'XL'] },
    sticker: { control: 'select', options: ['none', 'conflict', 'failing', 'changes', 'stale', 'mergeable'] },
    motion: { control: 'inline-radio', options: ['none', 'running', 'queued'] },
    blockers: { control: { type: 'range', min: 0, max: 9 } },
    unblocks: { control: { type: 'range', min: 0, max: 9 } },
    far: { control: 'boolean', description: 'The compact form the canvas shows when zoomed far out.' },
    group: { control: 'select', options: ['pr-queue', 'navigation', 'workspaces', 'backlog', 'release'], description: 'Picks the art palette.' },
  },
} satisfies Meta<TradingArgs>

export default meta
type Story = StoryObj<typeof meta>

export const Playground: Story = {}

export const Mergeable: Story = { name: '#158 · mergeable' }

export const ChecksRunning: Story = {
  name: '#272 · checks running',
  args: {
    title: "Show a card's far-zoom tag only while hovered or selected",
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
    sticker: 'failing',
    blockers: 1,
    unblocks: 1,
  },
}

export const Conflict: Story = {
  name: '#250 · conflict',
  args: { title: 'Select stickers like cards', sticker: 'conflict', unblocks: 1, group: 'backlog' },
}

export const ChangesRequested: Story = {
  args: { title: 'Snap only to nearby nodes', sticker: 'changes', unblocks: 1 },
}

export const Stale: Story = {
  args: { title: 'Pan with touchpad and hide shortcuts by default', sticker: 'stale', unblocks: 0, group: 'navigation' },
}

export const CalmIssue: Story = {
  name: '#68 · calm issue',
  args: {
    kind: 'step',
    title: 'List commands after `>` in the command palette',
    status: 'ready',
    sticker: 'none',
    unblocks: 1,
    group: 'navigation',
  },
}

export const SetByASource: Story = {
  args: { title: 'Report release health to PostHog', priority: '0', size: 'L', sticker: 'none', group: 'release' },
}

export const UnlinkedStep: Story = {
  args: {
    kind: 'step',
    title: 'Let one card appear in many places',
    status: 'ready',
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
    sticker: 'none',
    unblocks: 0,
    group: 'navigation',
  },
}

export const Gate: Story = {
  args: { kind: 'gate', title: 'Card skins ship', status: 'blocked', sticker: 'none', blockers: 2, unblocks: 0 },
}

export const FarZoom: Story = {
  args: {
    far: true,
    title: 'Draw trading card art as geometric posters built from each card',
    status: 'blocked',
    sticker: 'failing',
    blockers: 1,
    unblocks: 1,
    motion: 'none',
  },
}

export const Done: Story = {
  args: { title: 'Add a card skin registry with Classic and Plain skins', status: 'done', sticker: 'none', unblocks: 0 },
}

export const Note: Story = {
  args: { kind: 'note', title: 'Merge the stack bottom up so each child picks up its parent before review.' },
}
