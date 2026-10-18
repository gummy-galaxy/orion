import type { AppNode, TaskData } from '../model'

/**
 * Keeps every appearance of a card showing the same data. When an edit changes one appearance's data, the card's own
 * node and each copy take it, so an edit in one place shows in the other at once. Each copy keeps its `copyOf`.
 */
export function syncCopies(previous: AppNode[], next: AppNode[]): AppNode[] {
  if (!next.some((node) => node.type === 'task' && (node.data as TaskData).copyOf)) return next

  const before = new Map(previous.map((node) => [node.id, node]))
  const families = new Map<string, AppNode[]>()

  for (const node of next) {
    if (node.type !== 'task') continue

    const card = (node.data as TaskData).copyOf ?? node.id

    families.set(card, [...(families.get(card) ?? []), node])
  }

  const replaced = new Map<string, TaskData>()

  for (const [card, members] of families) {
    if (members.length < 2) continue

    const changed = members.find((member) => before.get(member.id)?.data !== member.data)

    if (!changed || !before.has(changed.id)) continue

    const { copyOf: _copyOf, ...data } = changed.data as TaskData

    for (const member of members) {
      if (member === changed) continue

      replaced.set(member.id, member.id === card ? data : { ...data, copyOf: card })
    }
  }

  if (!replaced.size) return next

  return next.map((node) => {
    const data = replaced.get(node.id)

    return data ? ({ ...node, data } as AppNode) : node
  })
}
