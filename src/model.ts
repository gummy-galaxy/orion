import type { Node } from '@xyflow/react'

export const TASK_W = 208
export const TASK_H = 66
export const PAD = 24
export const HEAD = 52

export type Status = 'todo' | 'active' | 'review' | 'done'
export type Who = 'you' | 'review' | 'ci'
export type ViewStatus = 'ready' | 'active' | 'review' | 'blocked' | 'done'

export type TaskData = { kind: 'task'; label: string; tag: string; status: Status; who?: Who }
export type ClusterData = { kind: 'cluster'; label: string }
export type TaskNode = Node<TaskData, 'task'>
export type ClusterNode = Node<ClusterData, 'cluster'>
export type AppNode = TaskNode | ClusterNode

export type Link = { id: string; from: string; to: string; kind: 'blocks' | 'related' }

export const STATUS_LABEL: Record<ViewStatus, string> = {
  ready: 'Ready',
  active: 'In progress',
  review: 'In review',
  blocked: 'Blocked',
  done: 'Done',
}

export const isCluster = (n: AppNode): n is ClusterNode => n.type === 'cluster'
export const isTask = (n: AppNode): n is TaskNode => n.type === 'task'

export function byId(nodes: AppNode[]): Map<string, AppNode> {
  return new Map(nodes.map((n) => [n.id, n]))
}

/** Parent chain from the nearest parent up to the top level. */
export function ancestors(id: string, map: Map<string, AppNode>): string[] {
  const out: string[] = []
  let cur = map.get(id)?.parentId
  while (cur) {
    out.push(cur)
    cur = map.get(cur)?.parentId
  }
  return out
}

export function sizeOf(n: AppNode): { w: number; h: number } {
  if (isTask(n)) return { w: TASK_W, h: TASK_H }
  return { w: n.width ?? 320, h: n.height ?? 200 }
}

export function absPos(n: AppNode, map: Map<string, AppNode>): { x: number; y: number } {
  let x = n.position.x
  let y = n.position.y
  for (const a of ancestors(n.id, map)) {
    const p = map.get(a)
    if (p) {
      x += p.position.x
      y += p.position.y
    }
  }
  return { x, y }
}

/** Fills in the React Flow fields every node needs, so saved data stays minimal. */
function hydrate(n: AppNode): AppNode {
  if (isTask(n)) return { ...n, width: TASK_W, height: TASK_H, expandParent: !!n.parentId }
  return { ...n, dragHandle: '.drag', expandParent: !!n.parentId }
}

/** React Flow needs parents before children. */
function sortNodes(nodes: AppNode[]): AppNode[] {
  const map = byId(nodes)
  return [...nodes].sort((a, b) => ancestors(a.id, map).length - ancestors(b.id, map).length)
}

/**
 * Shrinks or grows every group to hug its children, deepest first, and removes
 * groups left empty. Children keep their place on screen.
 */
function fitGroups(nodes: AppNode[]): AppNode[] {
  const map = new Map(nodes.map((n) => [n.id, { ...n } as AppNode]))
  const depth = (id: string) => ancestors(id, map).length
  const clusters = [...map.values()].filter(isCluster).sort((a, b) => depth(b.id) - depth(a.id))
  for (const g of clusters) {
    const kids = [...map.values()].filter((n) => n.parentId === g.id)
    if (!kids.length) {
      map.delete(g.id)
      continue
    }
    let minX = Infinity
    let minY = Infinity
    let maxX = -Infinity
    let maxY = -Infinity
    for (const k of kids) {
      const s = sizeOf(k)
      minX = Math.min(minX, k.position.x)
      minY = Math.min(minY, k.position.y)
      maxX = Math.max(maxX, k.position.x + s.w)
      maxY = Math.max(maxY, k.position.y + s.h)
    }
    const dx = minX - PAD
    const dy = minY - HEAD
    for (const k of kids) k.position = { x: k.position.x - dx, y: k.position.y - dy }
    g.position = { x: g.position.x + dx, y: g.position.y + dy }
    g.width = maxX - minX + PAD * 2
    g.height = maxY - minY + HEAD + PAD
  }
  return [...map.values()]
}

export function normalize(nodes: AppNode[]): AppNode[] {
  return sortNodes(fitGroups(nodes)).map(hydrate)
}

/** Wraps the selection in a new group under the selection's nearest shared parent. */
export function groupSelection(nodes: AppNode[]): { nodes: AppNode[]; groupId: string } | null {
  const map = byId(nodes)
  const sel = nodes.filter((n) => n.selected && !n.hidden && !ancestors(n.id, map).some((a) => map.get(a)?.selected))
  if (!sel.length) return null
  const chains = sel.map((n) => ancestors(n.id, map))
  const parent = chains[0].find((a) => chains.every((c) => c.includes(a)))
  const parentNode = parent ? map.get(parent) : undefined
  const origin = parentNode ? absPos(parentNode, map) : { x: 0, y: 0 }
  const abs = new Map(sel.map((n) => [n.id, absPos(n, map)]))
  const minX = Math.min(...[...abs.values()].map((p) => p.x))
  const minY = Math.min(...[...abs.values()].map((p) => p.y))
  const gpos = { x: minX - origin.x - PAD, y: minY - origin.y - HEAD }
  const groupId = 'g-' + Date.now().toString(36)
  const group: ClusterNode = {
    id: groupId,
    type: 'cluster',
    position: gpos,
    parentId: parent,
    data: { kind: 'cluster', label: 'New group' },
    selected: true,
  }
  const next = nodes.map((n): AppNode => {
    const p = abs.get(n.id)
    if (p) return { ...n, parentId: groupId, selected: false, position: { x: p.x - origin.x - gpos.x, y: p.y - origin.y - gpos.y } }
    return n.selected ? { ...n, selected: false } : n
  })
  return { nodes: normalize([...next, group]), groupId }
}

/** Dissolves the given groups, handing their children to the group's parent in place. */
export function ungroup(nodes: AppNode[], ids: string[]): AppNode[] {
  let next = nodes
  for (const id of ids) {
    const g = next.find((n) => n.id === id)
    if (!g || !isCluster(g)) continue
    next = next
      .filter((n) => n.id !== id)
      .map((n): AppNode =>
        n.parentId === id
          ? { ...n, parentId: g.parentId, selected: true, position: { x: n.position.x + g.position.x, y: n.position.y + g.position.y } }
          : n,
      )
  }
  return normalize(next)
}

export function descendants(id: string, nodes: AppNode[]): Set<string> {
  const out = new Set<string>()
  const walk = (pid: string) => {
    for (const n of nodes)
      if (n.parentId === pid && !out.has(n.id)) {
        out.add(n.id)
        walk(n.id)
      }
  }
  walk(id)
  return out
}
