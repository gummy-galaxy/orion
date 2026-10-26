import { absolutePosition, isTask, sizeOf, type AppNode, type Link } from '../model'
import type { Scene } from './types'

/** Flattens canvas nodes into absolute boxes, so routers never deal with nesting. */
export function sceneOf(nodes: AppNode[], links: Link[]): Scene {
  const nodeMap = new Map(nodes.map((node) => [node.id, node]))
  const scene: Scene = { cards: [], groups: [], links: [] }

  for (const node of nodes) {
    const { x, y } = absolutePosition(node, nodeMap)
    const { width, height } = sizeOf(node)

    if (isTask(node)) scene.cards.push({ id: node.id, x, y, width, height, group: node.parentId ?? null })
    else scene.groups.push({ id: node.id, x, y, width, height })
  }

  const cardIds = new Set(scene.cards.map((card) => card.id))

  for (const link of links) {
    if (link.kind === 'blocks' && cardIds.has(link.from) && cardIds.has(link.to) && link.from !== link.to) {
      scene.links.push({ id: link.id, from: link.from, to: link.to })
    }
  }

  return scene
}
