import { memo } from 'react'
import type { MiniMapNodeProps } from '@xyflow/react'

/**
 * A minimap card that fills as work moves, like the status shapes: hollow when ready, half in progress, solid in
 * review.
 */
export const MiniMapNode = memo(function MiniMapNode({
  id,
  x,
  y,
  width,
  height,
  borderRadius,
  className,
  shapeRendering,
  selected,
  onClick,
}: MiniMapNodeProps) {
  return (
    <>
      <rect
        className={`react-flow__minimap-node${selected ? ' selected' : ''} ${className}`}
        x={x}
        y={y}
        rx={borderRadius}
        ry={borderRadius}
        width={width}
        height={height}
        shapeRendering={shapeRendering}
        onClick={onClick ? (event) => onClick(event, id) : undefined}
      />
      {className === 'mm-active' && (
        <rect
          className="mm-active-half"
          x={x}
          y={y}
          width={width / 2}
          height={height}
          shapeRendering={shapeRendering}
        />
      )}
    </>
  )
})
