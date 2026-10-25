import type { AppNode, Link } from './model'
import type { Saved } from './persist'
import type { Sticker } from './sticker'

/** One edit, as the stored document before and after it. */
export type Step = { before: Saved; after: Saved }
export type History = { undo: Step[]; redo: Step[] }

export const HISTORY_LIMIT = 100

export const emptyHistory = (): History => ({ undo: [], redo: [] })

/** A new edit starts a new branch, so whatever was undone can't come back. */
export function record(history: History, step: Step, limit = HISTORY_LIMIT): History {
  return { undo: [...history.undo, step].slice(-limit), redo: [] }
}

type Fields = Record<string, unknown>

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b)

/** A node, link, or sticker as flat fields, so each one can be carried on its own. Data keys are prefixed. */
function fieldsOf(item: AppNode | Link | Sticker | undefined): Fields | undefined {
  if (!item) return undefined

  if ('tilt' in item) return { kind: item.kind, x: item.x, y: item.y, tilt: item.tilt, on: item.on }

  if (!('type' in item)) return { kind: item.kind }

  const fields: Fields = { type: item.type, position: item.position, parentId: item.parentId, width: item.width, height: item.height }

  for (const [key, value] of Object.entries(item.data)) fields[`data.${key}`] = value

  return fields
}

/**
 * Applies one field-level change: a field the step left alone keeps `current`'s value, and a field `current` changed since
 * the step keeps `current`'s value. Only a field that still holds what the step left is moved back to what it was.
 */
function carryFields(from: Fields = {}, to: Fields = {}, current: Fields = {}): Fields {
  const result: Fields = {}

  for (const key of new Set([...Object.keys(from), ...Object.keys(to), ...Object.keys(current)])) {
    const value = same(from[key], to[key]) || !same(current[key], from[key]) ? current[key] : to[key]

    if (value !== undefined) result[key] = value
  }

  return result
}

function carryNode(from: AppNode | undefined, to: AppNode | undefined, current: AppNode | undefined): AppNode | undefined {
  const fields = carryFields(fieldsOf(from), fieldsOf(to), fieldsOf(current))
  const id = (current ?? to ?? from)?.id

  if (!id || typeof fields.type !== 'string') return undefined

  const data: Record<string, unknown> = {}

  for (const [key, value] of Object.entries(fields)) if (key.startsWith('data.')) data[key.slice('data.'.length)] = value

  const node = { id, type: fields.type, position: fields.position, data } as AppNode

  if (fields.parentId !== undefined) node.parentId = fields.parentId as string

  if (fields.width !== undefined) node.width = fields.width as number

  if (fields.height !== undefined) node.height = fields.height as number

  return node
}

/**
 * Applies the change from `from` to `to` on top of `current`, field by field. Writes from elsewhere, such as the CLI or
 * another window, stay, and where both touched the same field, `current` wins. Links and stickers on cards that end up
 * gone go with them.
 */
function carry(from: Saved, to: Saved, current: Saved): Saved {
  const fromNodes = new Map(from.nodes.map((node) => [node.id, node]))
  const toNodes = new Map(to.nodes.map((node) => [node.id, node]))
  const currentNodes = new Map(current.nodes.map((node) => [node.id, node]))
  const ids = [...new Set([...current.nodes.map((node) => node.id), ...to.nodes.map((node) => node.id), ...from.nodes.map((node) => node.id)])]
  const nodes: AppNode[] = []

  for (const id of ids) {
    const node = carryNode(fromNodes.get(id), toNodes.get(id), currentNodes.get(id))

    if (node) nodes.push(node)
  }

  const present = new Set(nodes.map((node) => node.id))
  const linkKey = (link: Link) => `${link.from}\0${link.to}`
  const fromLinks = new Map(from.links.map((link) => [linkKey(link), link]))
  const toLinks = new Map(to.links.map((link) => [linkKey(link), link]))
  const currentLinks = new Map(current.links.map((link) => [linkKey(link), link]))
  const keys = [...new Set([...current.links.map(linkKey), ...to.links.map(linkKey), ...from.links.map(linkKey)])]
  const links: Link[] = []

  for (const key of keys) {
    const kept = carryFields(fieldsOf(fromLinks.get(key)), fieldsOf(toLinks.get(key)), fieldsOf(currentLinks.get(key)))
    const link = currentLinks.get(key) ?? toLinks.get(key)

    if (link && kept.kind !== undefined && present.has(link.from) && present.has(link.to)) links.push({ ...link, kind: kept.kind as Link['kind'] })
  }

  const fromStickers = new Map((from.stickers ?? []).map((sticker) => [sticker.id, sticker]))
  const toStickers = new Map((to.stickers ?? []).map((sticker) => [sticker.id, sticker]))
  const currentStickers = new Map((current.stickers ?? []).map((sticker) => [sticker.id, sticker]))
  const stickerIds = [...new Set([...currentStickers.keys(), ...toStickers.keys(), ...fromStickers.keys()])]
  const stickers: Sticker[] = []

  for (const id of stickerIds) {
    const kept = carryFields(fieldsOf(fromStickers.get(id)), fieldsOf(toStickers.get(id)), fieldsOf(currentStickers.get(id)))

    if (kept.kind === undefined || (kept.on !== undefined && !present.has(kept.on as string))) continue

    stickers.push({ id, ...kept } as Sticker)
  }

  return {
    ...current,
    nodes,
    links,
    stickers,
    stickerLoadout: same(from.stickerLoadout, to.stickerLoadout) ? current.stickerLoadout : to.stickerLoadout,
  }
}

export function undo(history: History, current: Saved): { history: History; doc: Saved } | null {
  const step = history.undo.at(-1)

  if (!step) return null

  return { history: { undo: history.undo.slice(0, -1), redo: [...history.redo, step] }, doc: carry(step.after, step.before, current) }
}

export function redo(history: History, current: Saved): { history: History; doc: Saved } | null {
  const step = history.redo.at(-1)

  if (!step) return null

  return { history: { undo: [...history.undo, step], redo: history.redo.slice(0, -1) }, doc: carry(step.before, step.after, current) }
}
