import { GROUP_PADDING } from '../geometry'
import { isCluster, normalize, type AppNode } from '../model'
import type { CardSize } from '../cardSize'
import type { ReflowPlan } from '../layout'
import type { Box, ResizeEdges } from './types'

/** How finely a resize that only changes a group's height tries widths, in canvas units. */
const WIDTH_STEP = 16

/** The widest the contents may run for a group to come closest to `height`, keeping near `width` when tied. */
function widthForHeight(plan: ReflowPlan, width: number, height: number): number {
  const widest = plan.measure(Infinity).width
  let best = { maxWidth: width - GROUP_PADDING * 2, heightOff: Infinity, widthOff: Infinity }

  for (let maxWidth = 0; maxWidth <= widest; maxWidth += WIDTH_STEP) {
    const size = plan.measure(maxWidth)
    const heightOff = Math.abs(size.height - height)
    const widthOff = Math.abs(size.width - width)

    if (heightOff < best.heightOff || (heightOff === best.heightOff && widthOff < best.widthOff)) best = { maxWidth, heightOff, widthOff }
  }

  return best.maxWidth
}

/**
 * Lays an automatic group out for the box a resize asks for. A drag that moves its left or right edge lays the
 * contents out to fit the box's width; one that only moves its top or bottom picks the width whose layout comes
 * closest to the box's height. The group hugs the result, holding the edges the drag isn't moving, and remembers its
 * size so later layouts keep the shape. `start` is the group's box when the resize began, and `nodes` the canvas then.
 *
 * Until the box asks for a different layout than the group's starting width does, `nodes` comes back as it is. A
 * press on an edge moves nothing, and a group the CLI placed keeps its spacing until its cards actually rearrange.
 */
export function resizeAutoGroup(
  nodes: AppNode[],
  plan: ReflowPlan,
  groupId: string,
  start: Box,
  box: Box,
  edges: ResizeEdges,
  cardSize: CardSize,
): AppNode[] {
  const maxWidth = edges.left || edges.right ? box.width - GROUP_PADDING * 2 : widthForHeight(plan, start.width, box.height)

  if (plan.sameLayout(maxWidth, start.width - GROUP_PADDING * 2)) return nodes

  const size = plan.measure(maxWidth)
  const position = {
    x: edges.left ? start.x + start.width - size.width : start.x,
    y: edges.top ? start.y + start.height - size.height : start.y,
  }

  return normalize(
    plan
      .place(maxWidth)
      .map((node) => (node.id === groupId && isCluster(node) ? { ...node, position, data: { ...node.data, size, layout: undefined } } : node)),
    cardSize,
  )
}
