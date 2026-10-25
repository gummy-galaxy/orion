import type { AppNode } from './model'

/**
 * Moves each selected node one step later (`1`) or earlier (`-1`) among its siblings, which is the
 * order React Flow paints overlapping siblings in. A run of selected siblings moves as a block past
 * the unselected sibling next to it. Returns the same array when nothing moves.
 */
export function stackNodes(nodes: AppNode[], ids: string[], direction: 1 | -1): AppNode[] {
  const selected = new Set(ids)
  const slotsByParent = new Map<string | undefined, number[]>()

  nodes.forEach((node, index) => {
    const slots = slotsByParent.get(node.parentId) ?? []

    slots.push(index)
    slotsByParent.set(node.parentId, slots)
  })

  const next = [...nodes]
  let moved = false

  for (const slots of slotsByParent.values()) {
    const order = slots.map((slot) => nodes[slot])
    const start = direction === 1 ? order.length - 2 : 1
    const end = direction === 1 ? -1 : order.length
    const step = direction === 1 ? -1 : 1

    for (let index = start; index !== end; index += step) {
      const mover = order[index]
      const neighbor = order[index + direction]

      if (selected.has(mover.id) && !selected.has(neighbor.id)) {
        order[index] = neighbor
        order[index + direction] = mover
        moved = true
      }
    }

    slots.forEach((slot, position) => {
      next[slot] = order[position]
    })
  }

  return moved ? next : nodes
}
