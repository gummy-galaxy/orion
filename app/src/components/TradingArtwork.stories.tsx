import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardView } from '../cardView'
import { getCardInks } from '../skins/frameColor'
import { TradingArtwork } from './TradingArtwork'

const view: CardView = {
  id: 'artwork',
  kind: 'pr',
  title: 'Report release health to PostHog',
  tag: 'flipbook-labs/flipbook#658',
  url: null,
  status: 'review',
  statusLabel: 'Review',
  leverage: 0,
  sources: [],
  repo: 'flipbook-labs/flipbook',
  artSeed: 'artwork',
}

const meta = { title: 'Canvas/Cards and edges/TradingArtwork', component: TradingArtwork } satisfies Meta<typeof TradingArtwork>

export default meta
type Story = StoryObj<typeof meta>

export const YourMove: Story = {
  args: { view, kind: 'pr', inks: getCardInks(view.repo, 'pr'), status: { label: 'Your move', className: 'you' } },
  decorators: [
    (Story) => (
      <div className="card skin-trading" style={{ width: 288, height: 400 }}>
        <div
          className="trading-frame trading-you"
          style={
            { '--trading-ink-one': getCardInks(view.repo, 'pr')[0], '--trading-ink-two': getCardInks(view.repo, 'pr')[1] } as React.CSSProperties
          }
        >
          <div className="trading-frame-border">
            <div className="trading-inner">
              <Story />
            </div>
          </div>
        </div>
      </div>
    ),
  ],
}
