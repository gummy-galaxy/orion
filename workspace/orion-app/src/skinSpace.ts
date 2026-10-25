import { GAP, GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH } from './geometry'
import { groupHeaderHeight, isCluster, normalize, type AppNode } from './model'
import type { CardSize } from './cardSize'

const CLASSIC_SIZE = { width: TASK_WIDTH, height: TASK_HEIGHT }

export function cardPitchOf(size: CardSize): { x: number; y: number } {
  return { x: (size.width + GAP.inner.x) / (TASK_WIDTH + GAP.inner.x), y: (size.height + GAP.inner.y) / (TASK_HEIGHT + GAP.inner.y) }
}

function mapPositions(nodes: AppNode[], size: CardSize, isInverse: boolean): AppNode[] {
  if (size.width === TASK_WIDTH && size.height === TASK_HEIGHT) return nodes

  const { x: pitchX, y: pitchY } = cardPitchOf(size)
  const headers = new Map(nodes.filter(isCluster).map((group) => [group.id, groupHeaderHeight(group.data)]))

  const scale = (offset: number, value: number, pitch: number) =>
    isInverse ? Math.round(offset + (value - offset) / pitch) : offset + (value - offset) * pitch

  return normalize(
    nodes.map((node): AppNode => {
      const origin = node.parentId ? { x: GROUP_PADDING, y: headers.get(node.parentId) ?? groupHeaderHeight(undefined) } : { x: 0, y: 0 }
      const position = { x: scale(origin.x, node.position.x, pitchX), y: scale(origin.y, node.position.y, pitchY) }

      // A group's size scales like the room inside it, so the padding and header stay as they are.
      if (!isCluster(node) || !node.data.size) return { ...node, position }

      const { width, height } = node.data.size
      const frame = { x: GROUP_PADDING * 2, y: headers.get(node.id)! + GROUP_PADDING }

      return { ...node, position, data: { ...node.data, size: { width: scale(frame.x, width, pitchX), height: scale(frame.y, height, pitchY) } } }
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
