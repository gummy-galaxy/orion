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
    ...seed.groups.map((g): AppNode => ({
      id: g.id,
      type: 'cluster',
      position: { x: 0, y: 0 },
      data: { kind: 'cluster', label: g.label, blurb: g.blurb ?? undefined },
    })),
    ...(seed.tasks as SeedTask[]).map((t): AppNode => ({
      id: t.id,
      type: 'task',
      position: { x: 0, y: 0 },
      parentId: t.group,
      data: {
        kind: 'task',
        label: t.label,
        itemKind: t.kind as ItemKind,
        status: t.status as Status,
        repo: t.repo,
        pr: t.pr,
        note: t.note,
        who: t.who as Who | undefined,
      },
    })),
  ]
}

export function seedLinks(): Link[] {
  return seed.links.map((l): Link => ({ id: `${l.from}>${l.to}`, from: l.from, to: l.to, kind: 'blocks' }))
}
