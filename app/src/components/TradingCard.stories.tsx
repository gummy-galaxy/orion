import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardSizeLabel, CardView, Priority } from '../cardView'
import { getRarity, MYTHIC_UPSTREAM, RARE_UPSTREAM, UNCOMMON_UPSTREAM } from '../rarity'
import { STALE_DAYS, type Motion, type Sticker } from '../skins/tradingFacts'
import { TRADING_IDENTITIES, TradingIdentityContext, type SealSide, type TradingIdentity } from '../skins/tradingIdentity'
import { skinOf } from '../skins'
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
  upstream: number
  identity: TradingIdentity
  sealSide: SealSide
  far: boolean
}

const DAY_MS = 24 * 60 * 60 * 1000

// A sticker that comes from readiness wins over motion, since a pull request has one readiness at a time.
function readinessOf(args: TradingArgs): Pick<CardView, 'readiness' | 'readyToMerge' | 'merge'> {
  if (args.sticker === 'conflict' || args.sticker === 'failing') return { readiness: args.sticker }

  if (args.sticker === 'mergeable')
    return { readiness: 'mergeable', readyToMerge: true, merge: { url: 'https://github.com/vocksel/orion/pull/158', head: 'storybook' } }

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
    upstream: args.upstream,
    ...(args.kind === 'note' ? {} : { rarity: getRarity(args.upstream) }),
    sources: [],
    artSeed: args.title,
    blockers: args.blockers,
    unblocks: args.unblocks,
    group: args.group,
    updatedAt: new Date(Date.now() - (stale ? STALE_DAYS + 6 : 0) * DAY_MS).toISOString(),
    ...readinessOf(args),
    ...(args.kind === 'pr' ? { pullRequestUrl: 'https://github.com/vocksel/orion/pull/158' } : {}),
    ...(args.sticker === 'changes' ? { changesRequested: true as const } : {}),
    ...(args.priority !== 'unknown' ? { priority: Number(args.priority) as Priority } : {}),
    ...(args.size !== 'unknown' ? { size: args.size } : {}),
  }
}

// Far zoom wraps the card in the canvas's far-card tag, which sizes it on its own.
function TradingFrame({ view, far, identity, sealSide }: { view: CardView; far: boolean; identity: TradingIdentity; sealSide: SealSide }) {
  const className =
    (view.kind === 'note'
      ? 'card skin-trading note'
      : `card skin-trading st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}`) +
    (far ? ' far-card' : '')

  return (
    <div style={far ? { position: 'relative', width: 240, height: 170 } : skinOf('trading').size}>
      <div className={className} style={far ? { position: 'relative', translate: 'none' } : { width: '100%', height: '100%' }}>
        <TradingIdentityContext.Provider value={{ identity, sealSide }}>
          <TradingCard view={view} />
        </TradingIdentityContext.Provider>
      </div>
    </div>
  )
}

const IDENTITY_LABEL: Record<TradingIdentity, string> = {
  tile: 'Tile: the icon over the art, as on #275',
  emblem: 'Emblem: the kind drawn into the art, its mark by the title',
  frame: "Frame: emblem inside the vibrant study's rim, lit by status and the art's inks",
  shape: 'Shape: frame, with an outline cut by kind',
}

const LINEUP_KINDS: CardView['kind'][] = ['step', 'pr', 'placeholder', 'gate']

const LINEUP_TITLES: Record<CardView['kind'], string> = {
  step: 'List commands after `>` in the command palette',
  pr: "Lay out cards at the active skin's size",
  placeholder: 'Let the scroll setting follow the trackpad',
  gate: 'Card skins ship',
  note: '',
}

// One row of cards per option, at the size the canvas shows them, so the options compare side by side.
function Lineup({ rows }: { rows: { label: string; cards: { args: TradingArgs; key: string }[] }[] }) {
  return (
    <div style={{ display: 'grid', gap: 28 }}>
      {rows.map((row) => (
        <section key={row.label} style={{ display: 'grid', gap: 10 }}>
          <h3 style={{ margin: 0, font: '600 14px var(--font-ui)', color: 'var(--muted)' }}>{row.label}</h3>
          <div style={{ display: 'flex', gap: 22, flexWrap: 'wrap', alignItems: 'flex-start' }}>
            {row.cards.map(({ args, key }) => (
              <TradingFrame key={key} view={toView(args)} far={args.far} identity={args.identity} sealSide={args.sealSide} />
            ))}
          </div>
        </section>
      ))}
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
  upstream: 5,
  identity: 'emblem',
  sealSide: 'right',
  far: false,
}

const meta = {
  title: 'Canvas/Cards and edges/TradingCard',
  render: (args) => <TradingFrame view={toView(args)} far={args.far} identity={args.identity} sealSide={args.sealSide} />,
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
    upstream: {
      control: { type: 'range', min: 0, max: 20 },
      description: `Cards that feed into this one. Rarity: uncommon from ${UNCOMMON_UPSTREAM}, rare from ${RARE_UPSTREAM}, mythic from ${MYTHIC_UPSTREAM}.`,
    },
    identity: {
      control: 'inline-radio',
      options: TRADING_IDENTITIES,
      description: 'How the card shows its kind. Tile is #275; the others are being compared.',
    },
    sealSide: { control: 'inline-radio', options: ['left', 'right'], description: 'Which end of the caption row holds the rarity seal.' },
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

export const IdentityLineup: Story = {
  name: 'Identity · every option by kind',
  render: (args) => (
    <Lineup
      rows={TRADING_IDENTITIES.map((identity) => ({
        label: IDENTITY_LABEL[identity],
        cards: LINEUP_KINDS.map((kind) => ({ key: kind, args: { ...args, identity, kind, title: LINEUP_TITLES[kind] } })),
      }))}
    />
  ),
  args: { sticker: 'none', status: 'ready', unblocks: 1 },
}

export const IdentityStates: Story = {
  name: 'Identity · states for one option',
  render: (args) => (
    <Lineup
      rows={LINEUP_KINDS.map((kind) => ({
        label: `${LINEUP_TITLES[kind]} (${kind})`,
        cards: (['ready', 'review', 'blocked', 'done'] as const).map((status) => ({
          key: status,
          args: { ...args, kind, status, title: `${status[0].toUpperCase()}${status.slice(1)}`, blockers: status === 'blocked' ? 2 : 0 },
        })),
      }))}
    />
  ),
  args: { sticker: 'none', unblocks: 1 },
}

export const RarityTiers: Story = {
  name: 'Rarity · every tier',
  render: (args) => (
    <Lineup
      rows={(['right', 'left'] as const).map((sealSide) => ({
        label: `Seal on the ${sealSide}`,
        cards: [0, UNCOMMON_UPSTREAM, RARE_UPSTREAM, MYTHIC_UPSTREAM].map((upstream) => ({
          key: String(upstream),
          args: { ...args, sealSide, upstream, title: `${getRarity(upstream)}: ${upstream} cards feed into this` },
        })),
      }))}
    />
  ),
  args: { sticker: 'none', status: 'ready' },
}

export const Foil: Story = {
  name: 'Foil · priority',
  render: (args) => (
    <Lineup
      rows={(['emblem', 'frame', 'shape'] as const).map((identity) => ({
        label: IDENTITY_LABEL[identity],
        cards: (['0', '1', '2', 'unknown'] as const).map((priority) => ({
          key: priority,
          args: {
            ...args,
            identity,
            priority,
            title: priority === 'unknown' ? 'No priority set' : `P${priority}: ${['holo', 'foil rim', 'no foil'][Number(priority)]}`,
          },
        })),
      }))}
    />
  ),
  args: { sticker: 'none', status: 'ready' },
}
