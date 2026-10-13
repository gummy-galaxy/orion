import type { ComponentProps } from 'react'
import ReactMarkdown from 'react-markdown'

/**
 * The only elements a note can render. Anything else, including raw HTML and images,
 * is dropped or unwrapped to its text, so a note never runs code or loads anything itself.
 */
const ALLOWED_ELEMENTS = ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'em', 'strong', 'a', 'code', 'pre', 'blockquote', 'hr']

/** Links open in a new tab, so following one never replaces the canvas. */
function MarkdownLink({ node: _node, ...props }: ComponentProps<'a'> & { node?: unknown }) {
  return <a {...props} target="_blank" rel="noreferrer" />
}

/** Renders Markdown as React elements, with no raw HTML. Shared by any surface that shows a short written note. */
export function Markdown({ source, className }: { source: string; className?: string }) {
  return (
    <div className={className ? `markdown ${className}` : 'markdown'}>
      <ReactMarkdown allowedElements={ALLOWED_ELEMENTS} unwrapDisallowed skipHtml components={{ a: MarkdownLink }}>
        {source}
      </ReactMarkdown>
    </div>
  )
}
