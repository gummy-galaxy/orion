import type { AppNode, Link } from './model'
import type { Saved } from './persist'
import { loadoutOf, type Loadout, type Sticker } from './sticker'

type Conflict = { id: string; field: string }
const missing = Symbol('missing')

function equal(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true
  if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') return false
  if (Array.isArray(a) || Array.isArray(b))
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((value, index) => equal(value, b[index]))
  const left = a as Record<string, unknown>
  const right = b as Record<string, unknown>
  const keys = Object.keys(left)
  return keys.length === Object.keys(right).length && keys.every((key) => Object.hasOwn(right, key) && equal(left[key], right[key]))
}

function value(object: Record<string, unknown> | undefined, key: string): unknown {
  return object && Object.hasOwn(object, key) ? object[key] : missing
}

function mergeValue(id: string, field: string, base: unknown, local: unknown, remote: unknown, conflicts: Conflict[]): unknown {
  if (equal(local, remote)) return local
  if (equal(local, base)) return remote
  if (equal(remote, base)) return local
  conflicts.push({ id, field })
  return local
}

function mergeFields<T extends { id: string }>(base: T | undefined, local: T, remote: T, fields: string[], conflicts: Conflict[]): T {
  const original = base as Record<string, unknown> | undefined
  const left = local as Record<string, unknown>
  const right = remote as Record<string, unknown>
  const result: Record<string, unknown> = { ...remote }
  for (const field of fields) {
    const next = mergeValue(local.id, field, value(original, field), value(left, field), value(right, field), conflicts)
    if (next === missing) delete result[field]
    else result[field] = next
  }
  return result as T
}

function mergeNode(base: AppNode | undefined, local: AppNode, remote: AppNode, conflicts: Conflict[]): AppNode {
  const node = mergeFields(base, local, remote, ['type', 'position', 'parentId', 'width', 'height'], conflicts)
  const baseData = base?.data as Record<string, unknown> | undefined
  const localData = local.data as Record<string, unknown>
  const remoteData = remote.data as Record<string, unknown>
  const data: Record<string, unknown> = {}
  for (const key of new Set([...Object.keys(baseData ?? {}), ...Object.keys(localData), ...Object.keys(remoteData)])) {
    const next = mergeValue(local.id, `data.${key}`, value(baseData, key), value(localData, key), value(remoteData, key), conflicts)
    if (next !== missing) data[key] = next
  }
  return { ...node, data } as AppNode
}

function sameNode(a: AppNode, b: AppNode): boolean {
  return (
    a.type === b.type &&
    equal(a.position, b.position) &&
    a.parentId === b.parentId &&
    a.width === b.width &&
    a.height === b.height &&
    equal(a.data, b.data)
  )
}

function mergeItems<T extends { id: string }>(
  base: T[],
  local: T[],
  remote: T[],
  merge: (base: T | undefined, local: T, remote: T, conflicts: Conflict[]) => T,
  unchanged: (base: T, changed: T) => boolean,
  conflicts: Conflict[],
): T[] {
  const original = new Map(base.map((item) => [item.id, item]))
  const left = new Map(local.map((item) => [item.id, item]))
  const right = new Map(remote.map((item) => [item.id, item]))
  const result: T[] = []
  for (const id of new Set([...right.keys(), ...left.keys(), ...original.keys()])) {
    const before = original.get(id)
    const ours = left.get(id)
    const theirs = right.get(id)
    if (ours && theirs) result.push(merge(before, ours, theirs, conflicts))
    else if (ours && (!before || !unchanged(before, ours))) result.push(ours)
    else if (theirs && (!before || !unchanged(before, theirs))) result.push(theirs)
  }
  return result
}

export function mergeDocs(base: Saved, local: Saved, remote: Saved): Saved & { conflicts: Conflict[] } {
  const conflicts: Conflict[] = []
  const nodes = mergeItems(base.nodes, local.nodes, remote.nodes, mergeNode, sameNode, conflicts)
  const ids = new Set(nodes.map((node) => node.id))
  const links = mergeItems<Link>(
    base.links,
    local.links,
    remote.links,
    (before, ours, theirs, found) => mergeFields(before, ours, theirs, ['from', 'to', 'kind'], found),
    equal,
    conflicts,
  ).filter((link) => ids.has(link.from) && ids.has(link.to))
  const stickers = mergeItems<Sticker>(
    base.stickers ?? [],
    local.stickers ?? [],
    remote.stickers ?? [],
    (before, ours, theirs, found) => mergeFields(before, ours, theirs, ['kind', 'x', 'y', 'tilt', 'on'], found),
    equal,
    conflicts,
  ).filter((sticker) => !sticker.on || ids.has(sticker.on))
  const before = loadoutOf(base.stickerLoadout)
  const left = loadoutOf(local.stickerLoadout)
  const right = loadoutOf(remote.stickerLoadout)
  const stickerLoadout: Loadout = before.map((slot, index) =>
    mergeValue('stickerLoadout', String(index), slot, left[index], right[index], conflicts),
  ) as Loadout
  return { nodes, links, stickers, stickerLoadout, conflicts }
}
