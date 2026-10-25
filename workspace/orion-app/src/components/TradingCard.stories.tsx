import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { STALE_DAYS, type Motion, type StatusBadge } from '../skins/tradingFacts'
import { skinOf } from '../skins'
import { TradingCard } from './TradingCard'

type TradingArgs = {
  kind: CardView['kind']
  title: string
  status: CardView['status']
  priority: 'unknown' | `${Priority}`
  size: 'unknown' | CardSizeLabel
  statusBadge: 'none' | StatusBadge
  motion: 'none' | Motion
  checksFinished: number
  checksFailed: number
  checksTotal: number
  blockers: number
  unblocks: number
  group: string
  far: boolean
}

const DAY_MS = 24 * 60 * 60 * 1000

// A status badge that comes from readiness wins over motion, since a pull request has one readiness at a time.
function readinessOf(args: TradingArgs): Pick<CardView, 'readiness' | 'readyToMerge' | 'merge'> {
  if (args.statusBadge === 'conflict' || args.statusBadge === 'failing') return { readiness: args.statusBadge }

  if (args.statusBadge === 'mergeable')
    return { readiness: 'mergeable', readyToMerge: true, merge: { url: 'https://github.com/vocksel/orion/pull/158', head: 'storybook' } }

  if (args.motion === 'running') return { readiness: 'running' }

  if (args.motion === 'queued') return { readiness: 'waiting' }

  return {}
}

// Motion also comes from check progress, so checks keep running beside a failing status badge.
function checksOf(args: TradingArgs): Pick<CardView, 'checkProgress' | 'checkCounts'> {
  if (args.motion === 'none') return {}

  const checkProgress = args.motion === 'running' ? 'running' : 'waiting'

  if (args.checksTotal === 0) return { checkProgress }

  return { checkProgress, checkCounts: { total: args.checksTotal, finished: args.checksFinished, failed: args.checksFailed } }
}

function toView(args: TradingArgs): CardView {
  const stale = args.statusBadge === 'stale'

  return {
    id: 'playground',
    kind: args.kind,
    title: args.title,
    tag: 'vocksel/orion#158',
    url: null,
    status: args.status,
    statusLabel: args.status,
    leverage: 0,
    upstream: 0,
    sources: [],
    artSeed: 'playground',
    blockers: args.blockers,
    unblocks: args.unblocks,
    group: args.group,
    updatedAt: new Date(Date.now() - (stale ? STALE_DAYS + 6 : 0) * DAY_MS).toISOString(),
    ...readinessOf(args),
    ...checksOf(args),
    ...(args.kind === 'pr' ? { pullRequestUrl: 'https://github.com/vocksel/orion/pull/158' } : {}),
    ...(args.statusBadge === 'changes' ? { changesRequested: true as const } : {}),
    ...(args.priority !== 'unknown' ? { priority: Number(args.priority) as Priority } : {}),
    ...(args.size !== 'unknown' ? { size: args.size } : {}),
  }
}

// Far zoom wraps the card in the canvas's far-card tag, which sizes it on its own, inside a canvas below the compact
// breakpoint.
function TradingFrame({ view, far }: { view: CardView; far: boolean }) {
  const className =
    (view.kind === 'note'
      ? 'card skin-trading note'
      : `card skin-trading st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}`) +
    (far ? ' far-card' : '')

  if (far)
    return (
      <div className="canvas" data-zoom="compact">
        <div className={className} style={{ position: 'relative', translate: 'none' }}>
          <TradingCard view={view} />
        </div>
      </div>
    )

  return (
    <div style={skinOf('trading').size}>
      <div className={className} style={{ width: '100%', height: '100%' }}>
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
  statusBadge: 'mergeable',
  motion: 'none',
  checksFinished: 5,
  checksFailed: 0,
  checksTotal: 8,
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
    statusBadge: { control: 'select', options: ['none', 'conflict', 'failing', 'changes', 'stale', 'mergeable'] },
    motion: { control: 'inline-radio', options: ['none', 'running', 'queued'] },
    checksFinished: { control: { type: 'range', min: 0, max: 20 } },
    checksFailed: { control: { type: 'range', min: 0, max: 20 } },
    checksTotal: { control: { type: 'range', min: 0, max: 20 }, description: 'Zero hides the count, as for records synced before counts.' },
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
    statusBadge: 'none',
    motion: 'running',
    unblocks: 0,
    group: 'navigation',
  },
}

export const FailingWhileRunning: Story = {
  name: '#272 · failing while running',
  args: {
    title: "Show a card's far-zoom tag only while hovered or selected",
    statusBadge: 'failing',
    motion: 'running',
    checksFinished: 3,
    checksFailed: 1,
    checksTotal: 12,
    unblocks: 0,
    group: 'navigation',
  },
}

export const BlockedAndFailing: Story = {
  name: '#164 · blocked, failing',
  args: {
    title: 'Draw trading card art as geometric posters built from each card',
    status: 'blocked',
    statusBadge: 'failing',
    blockers: 1,
    unblocks: 1,
  },
}

export const Conflict: Story = {
  name: '#250 · conflict',
  args: { title: 'Select stickers like cards', statusBadge: 'conflict', unblocks: 1, group: 'backlog' },
}

export const ChangesRequested: Story = {
  args: { title: 'Snap only to nearby nodes', statusBadge: 'changes', unblocks: 1 },
}

export const Stale: Story = {
  args: { title: 'Pan with touchpad and hide shortcuts by default', statusBadge: 'stale', unblocks: 0, group: 'navigation' },
}

export const CalmIssue: Story = {
  name: '#68 · calm issue',
  args: {
    kind: 'step',
    title: 'List commands after `>` in the command palette',
    status: 'ready',
    statusBadge: 'none',
    unblocks: 1,
    group: 'navigation',
  },
}

export const SetByASource: Story = {
  args: { title: 'Report release health to PostHog', priority: '0', size: 'L', statusBadge: 'none', group: 'release' },
}

export const UnlinkedStep: Story = {
  args: {
    kind: 'step',
    title: 'Let one card appear in many places',
    status: 'ready',
    statusBadge: 'none',
    unblocks: 0,
    group: 'workspaces',
  },
}

export const ExpectedPullRequest: Story = {
  args: {
    kind: 'placeholder',
    title: 'Let the scroll setting follow the trackpad',
    status: 'ready',
    statusBadge: 'none',
    unblocks: 0,
    group: 'navigation',
  },
}

export const Gate: Story = {
  args: { kind: 'gate', title: 'Card skins ship', status: 'blocked', statusBadge: 'none', blockers: 2, unblocks: 0 },
}

export const FarZoom: Story = {
  args: {
    far: true,
    title: 'Draw trading card art as geometric posters built from each card',
    status: 'blocked',
    statusBadge: 'failing',
    blockers: 1,
    unblocks: 1,
    motion: 'none',
  },
}

export const FarZoomRunning: Story = {
  args: { far: true, title: "Show a card's far-zoom tag only while hovered or selected", statusBadge: 'none', motion: 'running', unblocks: 0 },
}

export const Done: Story = {
  args: { title: 'Add a card skin registry with Classic and Plain skins', status: 'done', statusBadge: 'none', unblocks: 0 },
}

export const Note: Story = {
  args: { kind: 'note', title: 'Merge the stack bottom up so each child picks up its parent before review.' },
}
