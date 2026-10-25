import type { ComponentProps } from 'react'
import ReactMarkdown from 'react-markdown'
import rehypeRaw from 'rehype-raw'
import rehypeSanitize from 'rehype-sanitize'
import { HEADER_SCHEMA } from '../headerLayout'
import { HeaderImage } from './HeaderImage'

/**
 * The only elements a note can render. Anything else, including raw HTML and images,
 * is dropped or unwrapped to its text, so a note never runs code or loads anything itself.
 */
const ALLOWED_ELEMENTS = ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'em', 'strong', 'a', 'code', 'pre', 'blockquote', 'hr']

/** Links open in a new tab, so following one never replaces the canvas. */
function MarkdownLink({ node: _node, ...props }: ComponentProps<'a'> & { node?: unknown }) {
  return <a {...props} target="_blank" rel="noreferrer" />
}

/**
 * Renders Markdown as React elements. By default it shows no raw HTML, which suits notes shared by any surface.
 * With `layout`, a sanitized subset of HTML renders for layout instead (see `headerLayout.ts`), which suits headers.
 */
export function Markdown({ source, className, layout = false }: { source: string; className?: string; layout?: boolean }) {
  const classes = [layout ? 'markdown markdown-layout' : 'markdown', className].filter(Boolean).join(' ')

  if (layout) {
    return (
      <div className={classes}>
        <ReactMarkdown rehypePlugins={[rehypeRaw, [rehypeSanitize, HEADER_SCHEMA]]} components={{ a: MarkdownLink, img: HeaderImage }}>
          {source}
        </ReactMarkdown>
      </div>
    )
  }

  return (
    <div className={classes}>
      <ReactMarkdown allowedElements={ALLOWED_ELEMENTS} unwrapDisallowed skipHtml components={{ a: MarkdownLink }}>
        {source}
      </ReactMarkdown>
    </div>
  )
}
