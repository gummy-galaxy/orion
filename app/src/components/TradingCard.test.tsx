import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import type { CardView } from '../cardView'
import { TradingCard } from './TradingCard'

const pullRequest: CardView = {
  id: 'pull-658',
  kind: 'pr',
  title: 'Report release health to PostHog',
  tag: 'flipbook-labs/flipbook#658',
  url: null,
  status: 'review',
  statusLabel: 'In review',
  who: 'you',
  whoLabel: 'Your move',
  leverage: 3,
  upstream: 8,
  rarity: 'rare',
  checks: 'pending',
  readiness: 'running',
  changeSize: { additions: 412, deletions: 38 },
  sources: [],
  repo: 'flipbook-labs/flipbook',
  artSeed: 'pull-658',
}

describe('TradingCard', () => {
  it('shows the study structure and neutral pull size', () => {
    const markup = renderToStaticMarkup(<TradingCard view={pullRequest} />)

    expect(markup).toContain('trading-you')
    expect(markup).toContain('trading-number">#658')
    expect(markup).toContain('trading-move">Your move')
    expect(markup).toContain('Pull request · flipbook')
    expect(markup).not.toContain('trading-emblem')
    expect(markup).toContain('trading-rare')
    expect(markup).toContain('aria-label="Rare: 8 cards feed into this"')
    expect(markup).toContain('trading-add">+412')
    expect(markup).toContain('trading-del">−38')
    expect(markup).toContain('<title>Checks running</title>')
    expect(markup).toContain('In review</span>')
    expect(markup).toContain('trading-unblocks">unblocks 3')
  })

  it('saves your move for work that can move now', () => {
    const markup = renderToStaticMarkup(<TradingCard view={{ ...pullRequest, status: 'blocked', statusLabel: 'Blocked' }} />)

    expect(markup).toContain('trading-blocked')
    expect(markup).not.toContain('Your move')
    expect(markup).toContain('Blocked</span>')
  })

  it('stamps done cards and gives placeholders a dashed frame', () => {
    expect(renderToStaticMarkup(<TradingCard view={{ ...pullRequest, status: 'done', who: undefined }} />)).toContain('trading-stamp">Merged')
    expect(renderToStaticMarkup(<TradingCard view={{ ...pullRequest, kind: 'placeholder', status: 'ready', who: undefined }} />)).toContain(
      'trading-expected',
    )
  })

  it('keeps the symbol on done cards and leaves notes without rarity', () => {
    const done = renderToStaticMarkup(<TradingCard view={{ ...pullRequest, status: 'done' }} />)
    const note = renderToStaticMarkup(<TradingCard view={{ ...pullRequest, kind: 'note', rarity: undefined }} />)

    expect(done).toContain('trading-rarity-symbol-rare')
    expect(note).not.toContain('trading-rarity-symbol')
    expect(note).toContain('trading-note-label"><svg')
    expect(note).toContain('trading-frame-border"><div class="trading-inner"')
  })

  it('gives each work kind its own frame while retaining status and rarity layers', () => {
    for (const kind of ['step', 'pr', 'placeholder', 'gate'] as const) {
      const markup = renderToStaticMarkup(<TradingCard view={{ ...pullRequest, kind }} />)

      expect(markup).toContain(`trading-kind-${kind}`)
      expect(markup).toContain('trading-you')
      expect(markup).toContain('trading-foil')
      expect(markup).toContain('trading-rare')
    }
  })
})
