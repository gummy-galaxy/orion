import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardView } from '../cardView'
import { ClassicCard } from './ClassicCard'

const meta = { title: 'Canvas/Cards and edges/ClassicCard' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const ready: CardView = {
  id: 'ready-step',
  kind: 'step',
  layout: 'card',
  fields: [],
  badges: [],
  title: 'Review the canvas',
  tag: 'step',
  url: null,
  status: 'ready',
  statusLabel: 'Ready',
  leverage: 0,
  upstream: 0,
  sources: [],
  artSeed: 'ready-step',
}

function renderCard(view: CardView) {
  const className =
    view.kind === 'note'
      ? 'card note'
      : `card st-${view.status}${view.kind === 'placeholder' ? ' placeholder' : ''}${view.kind === 'gate' ? ' gate' : ''}`

  return (
    <div style={{ width: 216, height: 72 }}>
      <div className={className}>
        <ClassicCard view={view} />
      </div>
    </div>
  )
}

export const ReadyStep: Story = { render: () => renderCard(ready) }

export const ActivePullRequest: Story = {
  render: () =>
    renderCard({
      ...ready,
      id: 'active-pr',
      kind: 'pr',
      title: 'Make the canvas welcoming',
      tag: 'vocksel/orion#127',
      url: 'https://github.com/vocksel/orion/pull/127',
      status: 'active',
      statusLabel: 'In progress',
      who: 'you',
      whoLabel: 'Your move',
      checks: 'passing',
      sources: [{ domain: 'github.com', label: 'vocksel/orion#127', href: 'https://github.com/vocksel/orion/pull/127' }],
      repo: 'vocksel/orion',
      artSeed: 'active-pr',
    }),
}

export const BlockedPlaceholder: Story = {
  render: () =>
    renderCard({
      ...ready,
      id: 'blocked-placeholder',
      kind: 'placeholder',
      title: 'Prepare the next PR',
      tag: 'vocksel/orion',
      status: 'blocked',
      statusLabel: 'Blocked',
      leverage: 4,
      repo: 'vocksel/orion',
      artSeed: 'blocked-placeholder',
    }),
}

export const Gate: Story = {
  render: () => renderCard({ ...ready, id: 'gate', kind: 'gate', title: 'Release', tag: 'gate', artSeed: 'gate' }),
}

export const Done: Story = {
  render: () => renderCard({ ...ready, id: 'done', title: 'Review the canvas', status: 'done', statusLabel: 'Done', artSeed: 'done' }),
}

export const Note: Story = {
  render: () =>
    renderCard({ ...ready, id: 'note', kind: 'note', title: 'Keep the intent visible', status: 'done', statusLabel: 'Done', artSeed: 'note' }),
}
