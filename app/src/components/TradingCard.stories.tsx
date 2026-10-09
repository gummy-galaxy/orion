import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardView } from '../cardView'
import { TradingCard } from './TradingCard'

const meta = { title: 'Canvas/Cards and edges/TradingCard' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const base: CardView = {
  id: 'ready-step',
  kind: 'step',
  title: 'Prepare the release environment',
  tag: 'step',
  url: null,
  status: 'ready',
  statusLabel: 'Ready',
  leverage: 0,
  sources: [],
  note: 'Create the shared account and configure the release checks.',
  artSeed: 'ready-step',
}

function renderCard(view: CardView) {
  const className = view.kind === 'note' ? 'card skin-trading note' : `card skin-trading st-${view.status}`

  return (
    <div style={{ width: 288, height: 400 }}>
      <div className={className}>
        <TradingCard view={view} />
      </div>
    </div>
  )
}

export const Ready: Story = { render: () => renderCard(base) }
export const YourMove: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'your-move',
      kind: 'pr',
      title: 'Report release health to PostHog',
      tag: 'flipbook-labs/flipbook#658',
      repo: 'flipbook-labs/flipbook',
      status: 'review',
      statusLabel: 'Review',
      who: 'you',
      whoLabel: 'Your move',
      checks: 'pending',
      changeSize: { additions: 412, deletions: 38 },
      note: 'Needs the flipbook-posthog-ci item and a posthog environment with OP_SERVICE_ACCOUNT_TOKEN.',
      artSeed: 'your-move',
    }),
}
export const Blocked: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'blocked',
      kind: 'pr',
      title: 'Publish v2.6.0',
      tag: 'flipbook-labs/flipbook#641',
      repo: 'flipbook-labs/flipbook',
      status: 'blocked',
      statusLabel: 'Blocked',
      checks: 'failing',
      changeSize: { additions: 96, deletions: 12 },
      note: 'The publish check needs the cleanup first.',
      artSeed: 'blocked',
    }),
}
export const InReview: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'in-review',
      kind: 'pr',
      title: 'Review the canvas',
      tag: 'vocksel/orion#127',
      repo: 'vocksel/orion',
      status: 'review',
      statusLabel: 'In review',
      who: 'review',
      whoLabel: 'Waiting on review',
      checks: 'passing',
      changeSize: { additions: 68, deletions: 14 },
      artSeed: 'in-review',
    }),
}
export const Done: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'done',
      kind: 'pr',
      title: 'Make the canvas welcoming',
      tag: 'vocksel/orion#126',
      repo: 'vocksel/orion',
      status: 'done',
      statusLabel: 'Done',
      artSeed: 'done',
    }),
}
export const Placeholder: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'placeholder',
      kind: 'placeholder',
      title: 'Prepare the next PR',
      tag: 'vocksel/orion',
      repo: 'vocksel/orion',
      note: undefined,
      artSeed: 'placeholder',
    }),
}
export const Gate: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'gate',
      kind: 'gate',
      title: 'v2.6.0 ready to ship',
      tag: 'gate',
      note: 'Publish after all release checks pass.',
      artSeed: 'gate',
    }),
}
export const LongNote: Story = {
  render: () =>
    renderCard({
      ...base,
      id: 'long-note',
      kind: 'pr',
      title: 'Review the canvas',
      tag: 'vocksel/orion#129',
      repo: 'vocksel/orion',
      note: 'Check the whole path from source to canvas. The note should stay readable even when it contains several sentences, and the rest of the card should keep its shape. Follow up on the empty state, keyboard focus, and the details panel before the release review.',
      artSeed: 'long-note',
    }),
}
export const Note: Story = {
  render: () =>
    renderCard({ ...base, id: 'note', kind: 'note', title: 'Keep the intent visible', status: 'done', statusLabel: 'Done', artSeed: 'note' }),
}
