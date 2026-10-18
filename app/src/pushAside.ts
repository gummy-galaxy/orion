import { GAP } from './layout'
import { absolutePosition, byId, isCluster, normalize, sizeOf, type AppNode } from './model'
import type { CardSize } from './cardSize'

type Box = { x: number; y: number; width: number; height: number }

/** Each pass settles one more level of ancestors, so this is deeper than any real canvas nests. */
const MAX_PASSES = 32

/** Boxes compare in canvas coordinates, so a parent that shifts while it refits doesn't move its children's boxes. */
const boxOf = (node: AppNode, nodeMap: Map<string, AppNode>, cardSize: CardSize): Box => ({
  ...absolutePosition(node, nodeMap),
  ...sizeOf(node, cardSize),
})

const right = (box: Box) => box.x + box.width
const bottom = (box: Box) => box.y + box.height
const overlapsRows = (a: Box, b: Box) => a.y < bottom(b) && b.y < bottom(a)
const overlapsColumns = (a: Box, b: Box) => a.x < right(b) && b.x < right(a)

/**
 * Moves siblings out of the way of boxes that grew or moved. A sibling that sat to the right of a box's earlier
 * extent, in the rows its new extent covers, moves right until the gap it had is back, up to the standard gap. One
 * that sat to the left moves left the same way, and ones above or below, in the columns it covers, move up or down.
 * Each sibling that moves pushes its own neighbors in turn. Gaps are measured from `earlier`, so running this again
 * changes nothing. Returns the boxes that moved.
 */
function pushSiblings(boxes: Map<string, Box>, earlier: Map<string, Box>, movers: string[], gap: { x: number; y: number }): Set<string> {
  const pushed = new Set<string>()
  const queue = [...movers]

  for (let index = 0; index < queue.length && index < boxes.size * 4; index++) {
    const id = queue[index]
    const before = earlier.get(id) ?? boxes.get(id)!
    const after = boxes.get(id)!

    for (const [otherId, other] of boxes) {
      if (otherId === id) continue

      const was = earlier.get(otherId) ?? other
      let shift = { x: 0, y: 0 }

      if (was.x >= right(before) && overlapsRows(other, after)) {
        const wanted = right(after) + Math.min(was.x - right(before), gap.x)

        if (other.x < wanted) shift = { x: wanted - other.x, y: 0 }
      } else if (right(was) <= before.x && overlapsRows(other, after)) {
        const wanted = after.x - Math.min(before.x - right(was), gap.x)

        if (right(other) > wanted) shift = { x: wanted - right(other), y: 0 }
      } else if (was.y >= bottom(before) && overlapsColumns(other, after)) {
        const wanted = bottom(after) + Math.min(was.y - bottom(before), gap.y)

        if (other.y < wanted) shift = { x: 0, y: wanted - other.y }
      } else if (bottom(was) <= before.y && overlapsColumns(other, after)) {
        const wanted = after.y - Math.min(before.y - bottom(was), gap.y)

        if (bottom(other) > wanted) shift = { x: 0, y: wanted - bottom(other) }
      }

      if (!shift.x && !shift.y) continue

      boxes.set(otherId, { ...other, x: other.x + shift.x, y: other.y + shift.y })
      pushed.add(otherId)
      queue.push(otherId)
    }
  }

  return pushed
}

/**
 * Keeps a group that grew from `previous` to `next` from covering its neighbors. Siblings on the side it grew toward
 * move aside, and each parent that grows as a result does the same at its own level, up to the top. Only a group that got
 * bigger pushes; one that was dragged somewhere else doesn't, and neither do nodes that only appear in `next`.
 * Returns `next` itself when nothing had to move.
 */
export function pushAside(previous: AppNode[], next: AppNode[], cardSize: CardSize): AppNode[] {
  const before = byId(previous)
  let nodes = next
  let changed = false

  for (let pass = 0; pass < MAX_PASSES; pass++) {
    const nodeMap = byId(nodes)
    const byParent = new Map<string | undefined, AppNode[]>()

    for (const node of nodes) byParent.set(node.parentId, [...(byParent.get(node.parentId) ?? []), node])

    const shifts = new Map<string, { x: number; y: number }>()

    for (const [parentId, siblings] of byParent) {
      const earlier = new Map<string, Box>()

      for (const node of siblings) {
        const old = before.get(node.id)

        if (old && old.parentId === node.parentId) earlier.set(node.id, boxOf(old, before, cardSize))
      }

      const boxes = new Map(siblings.map((node) => [node.id, boxOf(node, nodeMap, cardSize)]))
      const grown = siblings.filter((node) => {
        const oldBox = earlier.get(node.id)
        const newBox = boxes.get(node.id)!

        return isCluster(node) && oldBox && (newBox.width > oldBox.width || newBox.height > oldBox.height)
      })

      if (!grown.length) continue

      const start = new Map(boxes)
      const pushed = pushSiblings(
        boxes,
        earlier,
        grown.map((node) => node.id),
        parentId ? GAP.inner : GAP.top,
      )

      for (const id of pushed) shifts.set(id, { x: boxes.get(id)!.x - start.get(id)!.x, y: boxes.get(id)!.y - start.get(id)!.y })
    }

    if (!shifts.size) break

    changed = true
    nodes = normalize(
      nodes.map((node) => {
        const shift = shifts.get(node.id)

        return shift ? { ...node, position: { x: node.position.x + shift.x, y: node.position.y + shift.y } } : node
      }),
      cardSize,
    )
  }

  return changed ? nodes : next
}
