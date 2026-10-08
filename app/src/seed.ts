import seed from './seed.json'
import type { AppNode, ItemKind, Link, Status, Who } from './model'

// Snapshot of the Flipbook Release Map, imported once. Real sources will replace it.
type SeedTask = {
  id: string
  label: string
  kind: string
  status: string
  group: string
  repo?: string
  pr?: number
  note?: string
  who?: string
}

export function seedNodes(): AppNode[] {
  return [
    ...seed.groups.map((group): AppNode => ({
      id: group.id,
      type: 'cluster',
      position: { x: 0, y: 0 },
      data: { kind: 'cluster', label: group.label, blurb: group.blurb ?? undefined },
    })),
    ...(seed.tasks as SeedTask[]).map((task): AppNode => ({
      id: task.id,
      type: 'task',
      position: { x: 0, y: 0 },
      parentId: task.group,
      data: {
        kind: 'task',
        label: task.label,
        itemKind: task.kind as ItemKind,
        status: task.status as Status,
        repo: task.repo,
        pr: task.pr,
        note: task.note,
        who: task.who as Who | undefined,
      },
    })),
  ]
}

export function seedLinks(): Link[] {
  return seed.links.map((link): Link => ({ id: `${link.from}>${link.to}`, from: link.from, to: link.to, kind: 'blocks' }))
}
