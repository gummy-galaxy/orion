import { GAP, GROUP_PADDING } from '../geometry'
import { groupHeaderHeight, normalize, type AppNode, type ClusterNode, type Link, type Status, type TaskNode } from '../model'
import { skinOf } from '../skins'

export type MessyOptions = {
  /** Links to aim for. The canvas grows with it, at about 2.4 links per card like a busy real canvas. */
  links: number
  seed?: number
}

/** Group names borrowed from a real canvas, so the fixture reads like one. */
const NAMES = ['Sources', 'Editing', 'Layout', 'Releases', 'Navigation', 'Performance', 'Play and identity', 'Agent operations']
const STATUSES: Status[] = ['done', 'done', 'todo', 'todo', 'todo', 'active', 'review']
const CARDS_PER_GROUP = 10
/** Hand-placed groups spread their cards out a little and let each one drift up to this far off the grid. */
const LOOSE = { x: 48, y: 40 }
const DRIFT = { x: 40, y: 32 }
const LINKS_PER_CARD = 2.4
/** Cards are laid out at the default skin's size, the portrait trading card, so routes meet the shapes people see. */
const CARD = skinOf('trading').size

/** A small seeded generator, so every run builds the same canvas. */
function random(seed: number) {
  let state = seed >>> 0

  return () => {
    state = (state + 0x6d2b79f5) >>> 0

    let t = Math.imul(state ^ (state >>> 15), state | 1)

    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)

    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

/**
 * A canvas built to be hard on arrows: a grid of groups, some auto-arranged and some hand-placed, with chains inside
 * each one, a release gate that collects spokes from everywhere, bundles of parallel links between neighbors, long
 * links that cross several groups, and links that run backward.
 */
export function buildMessyCanvas({ links: target, seed = 26 }: MessyOptions): { nodes: AppNode[]; links: Link[] } {
  const roll = random(seed)
  const pick = <T>(list: T[]) => list[Math.floor(roll() * list.length)]
  const groupCount = Math.max(6, Math.round(target / LINKS_PER_CARD / CARDS_PER_GROUP))
  const columns = Math.ceil(Math.sqrt(groupCount * 1.2))
  const headerHeight = groupHeaderHeight(undefined)
  const nodes: AppNode[] = []
  const links: Link[] = []
  const members: string[][] = []
  const columnWidths: number[] = []
  const rowHeights: number[] = []
  const shapes: { perRow: number; rows: number; hand: boolean }[] = []

  for (let index = 0; index < groupCount; index++) {
    const perRow = 3 + Math.floor(roll() * 3)
    const shape = { perRow, rows: Math.ceil(CARDS_PER_GROUP / perRow), hand: index % 3 === 2 }
    const gapX = GAP.inner.x + (shape.hand ? LOOSE.x : 0)
    const gapY = GAP.inner.y + (shape.hand ? LOOSE.y : 0)
    const width = 2 * GROUP_PADDING + perRow * CARD.width + (perRow - 1) * gapX + (shape.hand ? DRIFT.x : 0)
    const height = headerHeight + shape.rows * CARD.height + (shape.rows - 1) * gapY + GROUP_PADDING + (shape.hand ? DRIFT.y : 0)

    shapes.push(shape)
    columnWidths[index % columns] = Math.max(columnWidths[index % columns] ?? 0, width)
    rowHeights[Math.floor(index / columns)] = Math.max(rowHeights[Math.floor(index / columns)] ?? 0, height)
  }

  for (let index = 0; index < groupCount; index++) {
    const column = index % columns
    const row = Math.floor(index / columns)
    const { perRow, hand } = shapes[index]
    const groupId = `group-${index}`
    const group: ClusterNode = {
      id: groupId,
      type: 'cluster',
      position: {
        x: columnWidths.slice(0, column).reduce((sum, width) => sum + width + GAP.top.x, 0),
        y: rowHeights.slice(0, row).reduce((sum, height) => sum + height + GAP.top.y, 0),
      },
      data: {
        kind: 'cluster',
        label: NAMES[index % NAMES.length] + (index >= NAMES.length ? ` ${Math.floor(index / NAMES.length) + 1}` : ''),
        ...(hand ? { arrange: 'custom' as const } : {}),
      },
    }
    const ids: string[] = []

    nodes.push(group)

    for (let i = 0; i < CARDS_PER_GROUP; i++) {
      const id = `${groupId}-card-${i}`
      // Hand-placed groups drift off the grid, the way people actually arrange cards, but never overlap.
      const gapX = GAP.inner.x + (hand ? LOOSE.x : 0)
      const gapY = GAP.inner.y + (hand ? LOOSE.y : 0)
      const driftX = hand ? Math.round(roll() * DRIFT.x) : 0
      const driftY = hand ? Math.round(roll() * DRIFT.y) : 0
      const card: TaskNode = {
        id,
        type: 'task',
        parentId: groupId,
        position: {
          x: GROUP_PADDING + (i % perRow) * (CARD.width + gapX) + driftX,
          y: headerHeight + Math.floor(i / perRow) * (CARD.height + gapY) + driftY,
        },
        data: { kind: 'task', itemKind: i === 0 && index % 4 === 3 ? 'gate' : 'step', label: `${group.data.label} ${i + 1}`, status: pick(STATUSES) },
      }

      nodes.push(card)
      ids.push(id)
    }

    members.push(ids)
  }

  const seen = new Set<string>()

  const link = (from: string, to: string) => {
    if (from === to || seen.has(`${from}>${to}`) || seen.has(`${to}>${from}`)) return

    seen.add(`${from}>${to}`)
    links.push({ id: `${from}>${to}`, from, to, kind: 'blocks' })
  }

  // Long chains: each group's cards run in order, so every row wraps back to the start of the next.
  for (const ids of members) {
    for (let i = 1; i < ids.length; i++) if (roll() < 0.85) link(ids[i - 1], ids[i])
  }

  const groupAt = (column: number, row: number) => members[row * columns + column]
  const rowCount = Math.ceil(groupCount / columns)

  // A hub: every few groups, one gate collects spokes from cards all over the canvas, like a release does.
  for (let hub = 3; hub < groupCount; hub += 8) {
    const gate = members[hub][0]

    for (let spoke = 0; spoke < 8; spoke++) link(pick(pick(members)), gate)
  }

  // Bundles: neighbors share several parallel links, right and down.
  for (let row = 0; row < rowCount; row++) {
    for (let column = 0; column < columns; column++) {
      const from = groupAt(column, row)
      const right = column + 1 < columns ? groupAt(column + 1, row) : undefined
      const below = row + 1 < rowCount ? groupAt(column, row + 1) : undefined

      if (!from) continue

      for (const to of [right, below]) {
        if (!to || roll() < 0.35) continue

        const count = 2 + Math.floor(roll() * 4)

        for (let i = 0; i < count; i++) link(pick(from), pick(to))
      }
    }
  }

  // The rest: long links across the canvas, a third of them running backward.
  while (links.length < target) {
    const from = pick(members)
    const to = pick(members)

    if (from !== to) link(pick(from), pick(to))
  }

  return { nodes: normalize(nodes, CARD), links: links.slice(0, target) }
}
