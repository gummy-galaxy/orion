import { CARD_HEIGHT, CARD_WIDTH } from '../selectionSpike/board'
import type { Point, Positions, SpikeLink } from '../selectionSpike/types'

type Props = {
  links: SpikeLink[]
  positions: Positions
  /** Lines from a gather's starting card to what it would pick up. */
  tethers: { from: Point; to: Point }[]
}

const center = (position: Point) => ({ x: position.x + CARD_WIDTH / 2, y: position.y + CARD_HEIGHT / 2 })

/** Straight links between card centers, drawn under the cards, plus a gather's tethers. */
export function SpikeLinks({ links, positions, tethers }: Props) {
  return (
    <svg className="spike-links" width="1" height="1">
      {links.map((link) => {
        const from = center(positions[link.from])
        const to = center(positions[link.to])

        return <line key={`${link.from}-${link.to}`} x1={from.x} y1={from.y} x2={to.x} y2={to.y} />
      })}
      {tethers.map((tether, i) => (
        <line key={i} className="spike-tether" x1={tether.from.x} y1={tether.from.y} x2={tether.to.x} y2={tether.to.y} />
      ))}
    </svg>
  )
}
