import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { Markdown } from './Markdown'

const render = (source: string) => renderToStaticMarkup(<Markdown source={source} />)

describe('Markdown', () => {
  it('renders headings, lists, emphasis, links, and inline code', () => {
    const html = render('## Plan\n\n- **ship** it\n- see [docs](https://example.com) and `app/src`')

    expect(html).toContain('<h2>Plan</h2>')
    expect(html).toContain('<li><strong>ship</strong> it</li>')
    expect(html).toContain('<a href="https://example.com" target="_blank" rel="noreferrer">docs</a>')
    expect(html).toContain('<code>app/src</code>')
  })

  it('drops raw HTML instead of rendering it', () => {
    const html = render('before <script>alert(1)</script> <img src="x" onerror="alert(1)"> after')

    expect(html).not.toContain('<script')
    expect(html).not.toContain('<img')
    expect(html).not.toContain('onerror')
  })

  it('keeps no javascript links', () => {
    const html = render('[click](javascript:alert(1))')

    expect(html).not.toContain('javascript:')
  })
})
