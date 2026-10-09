import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import type { CardView } from '../cardView'
import { TradingCard } from './TradingCard'

const plannedWork: CardView = {
  id: 'planned-26',
  kind: 'placeholder',
  title: 'Prepare the layout',
  tag: 'vocksel/orion#26',
  url: null,
  status: 'ready',
  statusLabel: 'Ready',
  leverage: 0,
  sources: [],
  artSeed: 'planned-26',
}

describe('TradingCard', () => {
  it('labels planned work and shows its number without an absent check', () => {
    const markup = renderToStaticMarkup(<TradingCard view={plannedWork} />)

    expect(markup).toContain('Planned work')
    expect(markup).toMatch(/class="trading-pt"[^>]*><span>#26<\/span><\/span>/)
  })

  it.each([
    ['passing', '✓'],
    ['failing', '×'],
    ['pending', '…'],
  ] as const)('shows %s checks beside the number', (checks, glyph) => {
    const markup = renderToStaticMarkup(<TradingCard view={{ ...plannedWork, checks }} />)

    expect(markup).toContain(`aria-label="Checks: ${checks}">${glyph}</span><span>#26</span>`)
  })
})
