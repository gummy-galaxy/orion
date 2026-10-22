import type { AppNode } from '../model'

/** Everything inside `id` at any depth, each node before what's inside it and siblings in node order. */
export function descendants(id: string, children: Map<string, AppNode[]>): Set<string> {
  const result = new Set<string>()

  const walk = (parentId: string) => {
    for (const node of children.get(parentId) ?? [])
      if (!result.has(node.id)) {
        result.add(node.id)
        walk(node.id)
      }
  }

  walk(id)

  return result
}
