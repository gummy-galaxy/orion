import { ViewportPortal } from '@xyflow/react'
import type { Guide } from '../snap'

export function SnapGuides({ guides, zoom }: { guides: Guide[]; zoom: number }) {
  const tick = 4 / zoom

  return (
    <ViewportPortal>
      <svg className="snap-guides">
        {guides.map((guide, index) => {
          // Lines on the x axis stand upright; gaps on the x axis lie flat.
          const horizontal = (guide.kind === 'gap') === (guide.axis === 'x')
          const segment = (from: number, to: number, atStart: number, atEnd: number) =>
            horizontal ? { x1: from, x2: to, y1: atStart, y2: atEnd } : { x1: atStart, x2: atEnd, y1: from, y2: to }

          return guide.kind === 'line' ? (
            <line key={index} {...segment(guide.from, guide.to, guide.at, guide.at)} />
          ) : (
            <g key={index}>
              <line {...segment(guide.from, guide.to, guide.at, guide.at)} />
              <line {...segment(guide.from, guide.from, guide.at - tick, guide.at + tick)} />
              <line {...segment(guide.to, guide.to, guide.at - tick, guide.at + tick)} />
            </g>
          )
        })}
      </svg>
    </ViewportPortal>
  )
}
