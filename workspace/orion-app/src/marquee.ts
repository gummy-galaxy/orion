export type Box = { x0: number; y0: number; x1: number; y1: number }

/** How far across a card, on each side, the selection box has to reach to pick it up. */
export const MARQUEE_REACH = 0.25

/** Whether `area` reaches at least `reach` of `box` in both directions, so a sliver at the edge doesn't pick it up. */
export function covers(box: Box, area: Box, reach: number) {
  const width = Math.min(box.x1, area.x1) - Math.max(box.x0, area.x0)
  const height = Math.min(box.y1, area.y1) - Math.max(box.y0, area.y0)

  return width >= (box.x1 - box.x0) * reach - 0.5 && height >= (box.y1 - box.y0) * reach - 0.5
}
