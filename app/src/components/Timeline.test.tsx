import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import type { LogEntry } from '../log'
import { Timeline } from './Timeline'

const entry: LogEntry = {
  id: 'log-1',
  text: 'Parked on **review**',
  time: new Date().toISOString(),
  author: { kind: 'agent', name: 'codex' },
  targets: [{ kind: 'card', id: 'a' }],
}

describe('Timeline', () => {
  it('renders nothing while there is no log to show', () => {
    expect(renderToStaticMarkup(<Timeline entries={null} />)).toBe('')
  })

  it('says so when the card has no entries yet', () => {
    expect(renderToStaticMarkup(<Timeline entries={[]} />)).toContain('Nothing logged yet.')
  })

  it('marks agent entries and renders their text as Markdown', () => {
    const html = renderToStaticMarkup(<Timeline entries={[entry]} />)

    expect(html).toContain('timeline-author is-agent')
    expect(html).toContain('<span class="timeline-kind">agent</span>')
    expect(html).toContain('<strong>review</strong>')
  })

  it('leaves person entries unmarked', () => {
    const html = renderToStaticMarkup(<Timeline entries={[{ ...entry, author: { kind: 'person', name: 'Marin' } }]} />)

    expect(html).toContain('<span class="timeline-author">Marin')
    expect(html).not.toContain('timeline-kind')
  })
})
