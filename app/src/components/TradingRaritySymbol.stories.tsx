import type { Meta, StoryObj } from '@storybook/react-vite'
import { TradingRaritySymbol } from './TradingRaritySymbol'

const meta = { title: 'Canvas/Cards and edges/TradingRaritySymbol', component: TradingRaritySymbol } satisfies Meta<typeof TradingRaritySymbol>

export default meta
type Story = StoryObj<typeof meta>

export const AllTiers: Story = {
  args: { rarity: 'common', upstream: 0 },
  render: () => (
    <div style={{ display: 'flex', gap: 24, flexWrap: 'wrap' }}>
      {['#fff', '#151b24'].map((background) => (
        <div className="card skin-trading" key={background} style={{ padding: 20, background, display: 'flex', gap: 16, alignItems: 'center' }}>
          {(['common', 'uncommon', 'rare', 'mythic'] as const).map((rarity, index) => (
            <TradingRaritySymbol key={rarity} rarity={rarity} upstream={[0, 4, 8, 14][index]} />
          ))}
        </div>
      ))}
    </div>
  ),
}
