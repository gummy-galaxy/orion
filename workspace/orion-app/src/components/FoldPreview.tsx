import { memo } from 'react'
import { useFoldPreview } from '../state'

/**
 * Faded miniatures of what's inside a folded group, drawn in the group's own coordinates behind its label.
 * It has no pointer events and doesn't read the zoom, so zooming only moves the group's box.
 */
export const FoldPreview = memo(function FoldPreview({ id, width, height }: { id: string; width: number; height: number }) {
  const items = useFoldPreview(id)

  if (!items?.length) return null

  return (
    <svg className="fold-preview" viewBox={`0 0 ${width} ${height}`} aria-hidden="true">
      {items.map((item) => (
        <rect
          key={item.id}
          className={`fold-preview-${item.kind}`}
          data-status={item.status ?? undefined}
          x={item.x}
          y={item.y}
          width={item.width}
          height={item.height}
          rx={item.kind === 'group' ? 6 : 3}
        />
      ))}
    </svg>
  )
})
