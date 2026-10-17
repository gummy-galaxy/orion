import { GAP } from './layout'
import { GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH, groupHeaderHeight, isCluster, normalize, type AppNode } from './model'
import type { CardSize } from './cardSize'

const CLASSIC_SIZE = { width: TASK_WIDTH, height: TASK_HEIGHT }

export function cardPitchOf(size: CardSize): { x: number; y: number } {
  return { x: (size.width + GAP.inner.x) / (TASK_WIDTH + GAP.inner.x), y: (size.height + GAP.inner.y) / (TASK_HEIGHT + GAP.inner.y) }
}

function mapPositions(nodes: AppNode[], size: CardSize, isInverse: boolean): AppNode[] {
  if (size.width === TASK_WIDTH && size.height === TASK_HEIGHT) return nodes

  const { x: pitchX, y: pitchY } = cardPitchOf(size)
  const headers = new Map(nodes.filter(isCluster).map((group) => [group.id, groupHeaderHeight(group.data)]))

  return normalize(
    nodes.map((node) => {
      const origin = node.parentId ? { x: GROUP_PADDING, y: headers.get(node.parentId) ?? groupHeaderHeight(undefined) } : { x: 0, y: 0 }

      return {
        ...node,
        position: {
          x: isInverse ? Math.round(origin.x + (node.position.x - origin.x) / pitchX) : origin.x + (node.position.x - origin.x) * pitchX,
          y: isInverse ? Math.round(origin.y + (node.position.y - origin.y) / pitchY) : origin.y + (node.position.y - origin.y) * pitchY,
        },
      }
    }),
    isInverse ? CLASSIC_SIZE : size,
  )
}

export function toDisplayed(nodes: AppNode[], size: CardSize): AppNode[] {
  return mapPositions(nodes, size, false)
}

export function toStored(nodes: AppNode[], size: CardSize): AppNode[] {
  return mapPositions(nodes, size, true)
}
