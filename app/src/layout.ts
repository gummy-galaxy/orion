import ELK from 'elkjs/lib/elk.bundled.js'
import { GROUP_HEADER_HEIGHT, GROUP_PADDING, byId, isCluster, ancestors, normalize, sizeOf, type AppNode, type Link } from './model'

const elk = new ELK()

const INNER_LAYOUT_OPTIONS = {
  'elk.algorithm': 'layered',
  'elk.direction': 'RIGHT',
  'elk.spacing.nodeNode': '24',
  'elk.layered.spacing.nodeNodeBetweenLayers': '56',
  'elk.spacing.componentComponent': '32',
}

const TOP_LAYOUT_OPTIONS = {
  ...INNER_LAYOUT_OPTIONS,
  'elk.spacing.nodeNode': '72',
  'elk.layered.spacing.nodeNodeBetweenLayers': '120',
  'elk.spacing.componentComponent': '96',
}

/**
 * Lays out the direct children of one group (or the top level when `groupId`
 * is undefined). Links between deeper descendants are lifted to the child that
 * contains them, so nested groups are placed as single boxes.
 */
export async function reflow(nodes: AppNode[], links: Link[], groupId: string | undefined): Promise<AppNode[]> {
  const nodeMap = byId(nodes)
  const children = nodes.filter((node) => node.parentId === groupId)
  if (!children.length) return nodes
  const lift = (id: string): string | null => {
    let current: string | undefined = id
    while (current) {
      const node = nodeMap.get(current)
      if (!node) return null
      if (node.parentId === groupId) return current
      current = node.parentId
    }
    return null
  }
  const seen = new Set<string>()
  const edges = []
  for (const link of links) {
    if (link.kind !== 'blocks') continue
    const source = lift(link.from)
    const target = lift(link.to)
    if (!source || !target || source === target || seen.has(source + '>' + target)) continue
    seen.add(source + '>' + target)
    edges.push({ id: source + '>' + target, sources: [source], targets: [target] })
  }
  const result = await elk.layout({
    id: 'root',
    layoutOptions: groupId ? INNER_LAYOUT_OPTIONS : TOP_LAYOUT_OPTIONS,
    children: children.map((child) => ({ id: child.id, width: sizeOf(child).width, height: sizeOf(child).height })),
    edges,
  })
  const offset = groupId ? { x: GROUP_PADDING, y: GROUP_HEADER_HEIGHT } : { x: 0, y: 0 }
  const positions = new Map((result.children ?? []).map((child) => [child.id, { x: (child.x ?? 0) + offset.x, y: (child.y ?? 0) + offset.y }]))
  return normalize(nodes.map((node) => (positions.has(node.id) ? { ...node, position: positions.get(node.id)! } : node)))
}

/** Lays out every group from the deepest up, then the top level. */
export async function reflowAll(nodes: AppNode[], links: Link[]): Promise<AppNode[]> {
  const nodeMap = byId(nodes)
  const groups = nodes
    .filter(isCluster)
    .sort((firstGroup, secondGroup) => ancestors(secondGroup.id, nodeMap).length - ancestors(firstGroup.id, nodeMap).length)
  let next = normalize(nodes)
  for (const group of groups) next = await reflow(next, links, group.id)
  return reflow(next, links, undefined)
}
