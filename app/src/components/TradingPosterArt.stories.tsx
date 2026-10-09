import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardView } from '../cardView'
import { TradingArtwork } from './TradingArtwork'

const meta = { title: 'Canvas/Cards and edges/TradingPosterArt' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const compositionSeeds = ['poster-seed-0', 'poster-seed-16', 'poster-seed-8', 'poster-seed-3', 'poster-seed-4', 'poster-seed-1']

const base: CardView = {
  id: 'poster',
  kind: 'step',
  title: 'Poster art',
  tag: 'step',
  url: null,
  status: 'active',
  statusLabel: 'Active',
  leverage: 2,
  upstream: 3,
  sources: [],
  artSeed: 'poster',
  repo: 'vocksel/orion',
}

function renderRow(title: string, views: CardView[]) {
  return (
    <section key={title} style={{ marginBottom: 24 }}>
      <h3>{title}</h3>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 12 }}>
        {views.map((view) => (
          <div key={view.id} className="card skin-trading" style={{ width: 192, height: 185 }}>
            <div className="trading-frame" style={{ width: '100%', height: 156 }}>
              <TradingArtwork view={view} kind={view.kind} status={{ label: view.statusLabel, className: view.status }} />
            </div>
            <div style={{ font: '12px monospace', marginTop: 4 }}>
              {view.artSeed} · {view.kind} · {view.upstream}↑ · {view.leverage}↗ · {view.status}
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}

export const Grid: Story = {
  render: () => (
    <div style={{ padding: 20, minWidth: 1250 }}>
      {(['step', 'pr', 'placeholder', 'gate', 'note'] as const).map((kind) =>
        renderRow(
          kind,
          compositionSeeds.map((artSeed, index) => ({ ...base, id: `${kind}-${index}`, artSeed, kind })),
        ),
      )}
      {renderRow(
        'Upstream',
        [0, 1, 3, 6, 12, 20].map((upstream) => ({ ...base, id: `upstream-${upstream}`, upstream })),
      )}
      {renderRow(
        'Leverage',
        [0, 1, 2, 3, 6, 9].map((leverage) => ({ ...base, id: `leverage-${leverage}`, leverage })),
      )}
      {renderRow(
        'Status',
        (['ready', 'active', 'review', 'blocked', 'deferred', 'done'] as const).map((status) => ({
          ...base,
          id: `status-${status}`,
          status,
          statusLabel: status,
        })),
      )}
    </div>
  ),
}
