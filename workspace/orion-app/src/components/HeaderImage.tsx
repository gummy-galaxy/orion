import type { ComponentProps } from 'react'
import { isHeaderImage } from '../headerLayout'

/** A remote image in a header. Relative or non-web addresses render nothing, and the request sends no referrer. */
export function HeaderImage({ node: _node, src, alt, width, height }: ComponentProps<'img'> & { node?: unknown }) {
  if (!isHeaderImage(src)) return null

  return <img src={src} alt={alt ?? ''} width={width} height={height} loading="lazy" referrerPolicy="no-referrer" />
}
