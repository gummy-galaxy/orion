import { GAP } from '../layout'
import { GROUP_PADDING, byId, groupHeaderHeight, isCluster, normalize, sizeOf, type AppNode } from '../model'
import type { CardSize } from '../cardSize'
import type { Box } from './types'

type Side = 'left' | 'right' | 'top' | 'bottom'

/** How many times a squeeze widens its limit to fit what it pushed. One is enough unless boxes nest oddly. */
const MAX_TRIES = 8

const right = (box: Box) => box.x + box.width
const overlapsRows = (a: Box, b: Box) => a.y < b.y + b.height && b.y < a.y + a.height

/** Turns a box so `side` faces right, letting one squeeze handle every side. Turning twice gives the box back. */
function turn(box: Box, side: Side): Box {
  if (side === 'left') return { ...box, x: -right(box) }

  if (side === 'bottom') return { x: box.y, y: box.x, width: box.height, height: box.width }

  if (side === 'top') return { x: -(box.y + box.height), y: box.x, width: box.height, height: box.width }

  return box
}

function turnBack(box: Box, side: Side): Box {
  if (side === 'top') return { x: box.y, y: -right(box), width: box.height, height: box.width }

  return turn(box, side)
}

/**
 * Pushes boxes left until each ends by `limit`. A box pushed into another in its rows pushes that one too, keeping
 * the gap they had up to `gap`. Boxes already clear of the limit stay where they are.
 */
function pushBack(boxes: Map<string, Box>, limit: number, gap: number): Map<string, Box> {
  const pushed = new Map<string, Box>()

  for (const [id, box] of [...boxes].sort(([, a], [, b]) => right(b) - right(a))) {
    let end = limit

    for (const [otherId, other] of pushed) {
      const was = boxes.get(otherId)!

      if (was.x >= right(box) && overlapsRows(was, box)) end = Math.min(end, other.x - Math.min(was.x - right(box), gap))
    }

    pushed.set(id, { ...box, x: Math.min(box.x, end - box.width) })
  }

  return pushed
}

/**
 * Moves `side` of the room inside a group to `limit`, pushing the boxes it meets. When they can't all fit before the
 * opposite side at `floor`, the side stops where they do. Limits are in the turned coordinates. Returns where the
 * side ended up and the boxes.
 */
function squeeze(boxes: Map<string, Box>, side: Side, limit: number, floor: number, gap: number) {
  const turned = new Map([...boxes].map(([id, box]) => [id, turn(box, side)]))
  let reach = limit
  let pushed = pushBack(turned, reach, gap)

  for (let tries = 0; tries < MAX_TRIES && pushed.size; tries++) {
    const lowest = Math.min(...[...pushed.values()].map((box) => box.x))

    if (lowest >= floor - 0.5) break

    reach += floor - lowest
    pushed = pushBack(turned, reach, gap)
  }

  return { reach, boxes: new Map([...pushed].map(([id, box]) => [id, turnBack(box, side)])) }
}

/**
 * Gives a custom group the box `box`, in its parent's coordinates. Its contents keep their places, except that an
 * edge moving in pushes the items it meets ahead of it, and each pushes the ones beyond it. The edge stops once
 * they fill the group. The group remembers the box as its size.
 */
export function resizeCustomGroup(nodes: AppNode[], groupId: string, box: Box, cardSize: CardSize): AppNode[] {
  const nodeMap = byId(nodes)
  const group = nodeMap.get(groupId)

  if (!group || !isCluster(group)) return nodes

  const start = sizeOf(group, cardSize)
  const header = groupHeaderHeight(group.data)
  // The new box in the group's own coordinates, which its children are placed in.
  let left = box.x - group.position.x
  let top = box.y - group.position.y
  let right = left + box.width
  let bottom = top + box.height
  let boxes = new Map(nodes.filter((node) => node.parentId === groupId).map((node) => [node.id, { ...node.position, ...sizeOf(node, cardSize) }]))

  if (right < start.width) {
    const squeezed = squeeze(boxes, 'right', right - GROUP_PADDING, left + GROUP_PADDING, GAP.inner.x)

    boxes = squeezed.boxes
    right = squeezed.reach + GROUP_PADDING
  }

  if (left > 0) {
    const squeezed = squeeze(boxes, 'left', -(left + GROUP_PADDING), -(right - GROUP_PADDING), GAP.inner.x)

    boxes = squeezed.boxes
    left = -squeezed.reach - GROUP_PADDING
  }

  if (bottom < start.height) {
    const squeezed = squeeze(boxes, 'bottom', bottom - GROUP_PADDING, top + header, GAP.inner.y)

    boxes = squeezed.boxes
    bottom = squeezed.reach + GROUP_PADDING
  }

  if (top > 0) {
    const squeezed = squeeze(boxes, 'top', -(top + header), -(bottom - GROUP_PADDING), GAP.inner.y)

    boxes = squeezed.boxes
    top = -squeezed.reach - header
  }

  const size = { width: right - left, height: bottom - top }

  return normalize(
    nodes.map((node) => {
      const moved = boxes.get(node.id)

      if (moved) return { ...node, position: { x: moved.x - left, y: moved.y - top } }

      if (node.id !== groupId || !isCluster(node)) return node

      return {
        ...node,
        position: { x: node.position.x + left, y: node.position.y + top },
        data: { ...node.data, size, layout: undefined },
      }
    }),
    cardSize,
  )
}
