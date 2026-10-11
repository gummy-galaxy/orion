import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CSSProperties } from 'react'
import { AREA_LABEL, type CardArea } from '../cardArea'
import { TradingAreaSymbol } from './TradingAreaSymbol'

const meta = { title: 'Canvas/Cards and edges/TradingAreaSymbol' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const inks = { '--trading-ink-one': '#6f8bff', '--trading-ink-two': '#b45cff' } as CSSProperties

export const AllAreas: Story = {
  render: () => (
    <div className="card skin-trading" style={{ display: 'flex', flexWrap: 'wrap', gap: 12, width: 'auto', height: 'auto' }}>
      {(Object.keys(AREA_LABEL) as CardArea[]).map((area) => (
        <div key={area} className="trading-frame" style={{ ...inks, width: 140, height: 'auto' }}>
          <div className="trading-art" style={{ height: 120 }}>
            <TradingAreaSymbol area={area} />
          </div>
          <div style={{ marginTop: 4, font: '12px var(--font-ui)' }}>{AREA_LABEL[area]}</div>
        </div>
      ))}
    </div>
  ),
}
