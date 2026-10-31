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

  it('renders bulleted, numbered, and nested lists as their own list elements', () => {
    const html = render('1. first\n2. second\n\n- outer\n  - inner')

    expect(html).toContain('<ol>')
    expect(html).toContain('<li>first</li>')
    expect(html).toContain('<ul>')
    expect(html).toMatch(/<li>outer\s*<ul>\s*<li>inner<\/li>/)
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

describe('Markdown layout', () => {
  const layout = (source: string) => renderToStaticMarkup(<Markdown source={source} layout />)

  it('keeps layout boxes and the layout classes they name', () => {
    const html = layout('<div class="header-row"><span class="header-center">Orion</span></div>')

    expect(html).toContain(
      '<div class="markdown markdown-layout">' +
        '<div class="header-row"><span class="header-center">Orion</span></div></div>',
    )
  })

  it('drops classes outside the layout list, styles, and ids', () => {
    const html = layout('<div class="header-row unknown" style="position:fixed" id="top">Hi</div>')

    expect(html).toContain('<div class="header-row">Hi</div>')
    expect(html).not.toContain('unknown')
    expect(html).not.toContain('style=')
    expect(html).not.toContain('id=')
  })

  it('removes scripts and their text, and event handlers', () => {
    const html = layout('before <script>alert(1)</script><b onclick="alert(1)">bold</b> after')

    expect(html).not.toContain('script')
    expect(html).not.toContain('alert')
    expect(html).not.toContain('onclick')
  })

  it('keeps remote images and drops relative or non-web image sources', () => {
    const html = layout(
      '<img src="https://example.com/banner.png" alt="Banner"> ' +
        '<img src="/api/images/x.png"> <img src="javascript:alert(1)">',
    )

    expect(html).toContain('src="https://example.com/banner.png"')
    expect(html).toContain('no-referrer')
    expect(html).not.toContain('/api/images')
    expect(html).not.toContain('javascript:')
  })

  it('keeps only http, https, and mailto link targets', () => {
    const html = layout('[click](javascript:alert(1)) and [site](https://example.com)')

    expect(html).not.toContain('javascript:')
    expect(html).toContain('href="https://example.com"')
  })

  it('renders raw layout HTML only in layout mode', () => {
    expect(layout('<div>kept</div>')).toContain('<div>kept</div>')
    expect(render('<div>dropped</div>')).not.toContain('<div>dropped')
  })
})
