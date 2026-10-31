import { useRef } from 'react'
import { AREA_TINTS, CARD_HEIGHT, CARD_WIDTH, CARDS } from '../selectionSpike/board'
import type { Point, Positions, Rect } from '../selectionSpike/types'

type Props = { positions: Positions; view: Rect; selection: ReadonlySet<string>; jump: (center: Point) => void }

const WIDTH = 220
const HEIGHT = 140
const PADDING = 300

/** An overview of the whole board. Click or drag in it to move the view there. */
export function SpikeMinimap({ positions, view, selection, jump }: Props) {
  const ref = useRef<SVGSVGElement>(null)
  const xs = CARDS.map((card) => positions[card.id].x)
  const ys = CARDS.map((card) => positions[card.id].y)
  const bounds = {
    x0: Math.min(...xs) - PADDING,
    y0: Math.min(...ys) - PADDING,
    x1: Math.max(...xs) + CARD_WIDTH + PADDING,
    y1: Math.max(...ys) + CARD_HEIGHT + PADDING,
  }
  const scale = Math.min(WIDTH / (bounds.x1 - bounds.x0), HEIGHT / (bounds.y1 - bounds.y0))

  const toWorld = (event: React.PointerEvent) => {
    const box = ref.current!.getBoundingClientRect()

    return { x: (event.clientX - box.left) / scale + bounds.x0, y: (event.clientY - box.top) / scale + bounds.y0 }
  }

  return (
    <svg
      ref={ref}
      className="spike-minimap panel"
      width={WIDTH}
      height={HEIGHT}
      aria-label="Board overview"
      onPointerDown={(event) => {
        // Other buttons pass through, so a right or middle drag that starts here still pans.
        if (event.button !== 0) return

        event.stopPropagation()
        event.currentTarget.setPointerCapture(event.pointerId)
        jump(toWorld(event))
      }}
      onPointerMove={(event) => event.buttons === 1 && jump(toWorld(event))}
    >
      {CARDS.map((card) => (
        <rect
          key={card.id}
          x={(positions[card.id].x - bounds.x0) * scale}
          y={(positions[card.id].y - bounds.y0) * scale}
          width={CARD_WIDTH * scale}
          height={CARD_HEIGHT * scale}
          fill={selection.has(card.id) ? 'var(--accent-default)' : AREA_TINTS[card.area]}
        />
      ))}
      <rect
        className="spike-minimap-view"
        x={(view.x0 - bounds.x0) * scale}
        y={(view.y0 - bounds.y0) * scale}
        width={(view.x1 - view.x0) * scale}
        height={(view.y1 - view.y0) * scale}
      />
    </svg>
  )
}
