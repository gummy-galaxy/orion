import type { Options } from 'rehype-sanitize'

/**
 * The layout classes a header may use. Each one is styled only under `.markdown-layout`, so a header can
 * lay out its own text without reaching the rest of the app.
 */
export const HEADER_LAYOUT_CLASSES = ['header-row', 'header-column', 'header-center', 'header-end']

/** Markdown's own elements, plus the HTML a header may use for layout: boxes and line breaks. */
const HEADER_TAGS = [
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'em',
  'strong',
  'a',
  'code',
  'pre',
  'blockquote',
  'hr',
  'div',
  'span',
  'br',
  'img',
]

/** Elements removed with their contents, so script, style, and embedded documents never render, even as text. */
const STRIPPED_TAGS = [
  'script',
  'style',
  'iframe',
  'object',
  'embed',
  'svg',
  'math',
  'noscript',
  'template',
  'form',
  'input',
  'button',
  'select',
  'textarea',
]

/**
 * Sanitizes a header after raw HTML is parsed. Only the tags above survive, attributes are limited to link and image
 * targets plus the layout classes, and `style`, `id`, and event handlers are dropped. Links and images keep only
 * http and https targets; images are also filtered to absolute addresses in `HeaderImage`.
 */
export const HEADER_SCHEMA: Options = {
  clobber: [],
  clobberPrefix: '',
  strip: STRIPPED_TAGS,
  tagNames: HEADER_TAGS,
  attributes: {
    '*': [['className', ...HEADER_LAYOUT_CLASSES]],
    a: ['href', 'title'],
    img: ['src', 'alt', 'width', 'height'],
  },
  protocols: {
    href: ['http', 'https', 'mailto'],
    src: ['http', 'https'],
  },
}

/** A remote image a header may show. Relative addresses would point at Orion's own server, so they don't count. */
export const isHeaderImage = (src: string | undefined): src is string => src !== undefined && /^https?:\/\//i.test(src)
