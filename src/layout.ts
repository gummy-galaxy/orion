import ELK from 'elkjs/lib/elk.bundled.js'
import { HEAD, PAD, byId, isCluster, ancestors, normalize, sizeOf, type AppNode, type Link } from './model'

const elk = new ELK()

const INNER = {
  'elk.algorithm': 'layered',
  'elk.direction': 'RIGHT',
  'elk.spacing.nodeNode': '24',
  'elk.layered.spacing.nodeNodeBetweenLayers': '56',
  'elk.spacing.componentComponent': '32',
}

const TOP = {
  ...INNER,
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
  const map = byId(nodes)
  const kids = nodes.filter((n) => n.parentId === groupId)
  if (!kids.length) return nodes
  const lift = (id: string): string | null => {
    let cur: string | undefined = id
    while (cur) {
      const n = map.get(cur)
      if (!n) return null
      if (n.parentId === groupId) return cur
      cur = n.parentId
    }
    return null
  }
  const seen = new Set<string>()
  const edges = []
  for (const l of links) {
    if (l.kind !== 'blocks') continue
    const a = lift(l.from)
    const b = lift(l.to)
    if (!a || !b || a === b || seen.has(a + '>' + b)) continue
    seen.add(a + '>' + b)
    edges.push({ id: a + '>' + b, sources: [a], targets: [b] })
  }
  const res = await elk.layout({
    id: 'root',
    layoutOptions: groupId ? INNER : TOP,
    children: kids.map((k) => ({ id: k.id, width: sizeOf(k).w, height: sizeOf(k).h })),
    edges,
  })
  const offset = groupId ? { x: PAD, y: HEAD } : { x: 0, y: 0 }
  const pos = new Map((res.children ?? []).map((c) => [c.id, { x: (c.x ?? 0) + offset.x, y: (c.y ?? 0) + offset.y }]))
  return normalize(nodes.map((n) => (pos.has(n.id) ? { ...n, position: pos.get(n.id)! } : n)))
}

/** Lays out every group from the deepest up, then the top level. */
export async function reflowAll(nodes: AppNode[], links: Link[]): Promise<AppNode[]> {
  const map = byId(nodes)
  const groups = nodes.filter(isCluster).sort((a, b) => ancestors(b.id, map).length - ancestors(a.id, map).length)
  let next = normalize(nodes)
  for (const g of groups) next = await reflow(next, links, g.id)
  return reflow(next, links, undefined)
}
