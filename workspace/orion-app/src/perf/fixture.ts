import {
  groupHeaderHeight,
  normalize,
  sizeOf,
  type AppNode,
  type ClusterNode,
  type Link,
  type Status,
  type TaskNode,
} from '../model'
import type { Saved } from '../persist'

export type FixtureOptions = {
  /** Cards to generate, spread across nested groups. */
  cards: number
  /** Cards in each innermost group. */
  perGroup?: number
  /** Innermost groups in each top-level group. */
  perArea?: number
  seed?: number
}

const ROW = 6
const GAP = 40

// `npm run perf` lays this harness over the base branch's app, so it reads sizes through functions every revision
// exports rather than importing the constants, which have moved between modules before.
const { width: TASK_WIDTH, height: TASK_HEIGHT } = sizeOf({
  id: 'size',
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: '', status: 'todo' },
} as TaskNode)
const GROUP_HEADER_HEIGHT = groupHeaderHeight(undefined)
// An empty group is one card wide plus its padding on each side.
const GROUP_PADDING =
  ((normalize([{ id: 'size', type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: '' } }])[0]
    .width ?? 0) -
    TASK_WIDTH) /
  2
const AREA_COLUMNS = 2
const TOP_COLUMNS = 4
const STATUSES: [Status, number][] = [
  ['done', 0.35],
  ['active', 0.1],
  ['review', 0.1],
  ['deferred', 0.03],
  ['todo', 0.42],
]

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

function pickStatus(roll: number): Status {
  let total = 0

  for (const [status, weight] of STATUSES) {
    total += weight

    if (roll < total) return status
  }

  return 'todo'
}

const groupWidth = (columns: number, inner: number, gap: number) =>
  2 * GROUP_PADDING + columns * inner + (columns - 1) * gap
const groupHeight = (rows: number, inner: number, gap: number) =>
  GROUP_HEADER_HEIGHT + rows * inner + (rows - 1) * gap + GROUP_PADDING

/**
 * A canvas shaped like a busy real one: top-level areas of nested groups, chains of dependent cards in each group,
 * links across groups, and a spread of statuses, so active glows and moving arrows show up everywhere.
 */
export function generateCanvas({ cards, perGroup = 24, perArea = 4, seed = 1 }: FixtureOptions): Saved {
  const roll = random(seed)
  const nodes: AppNode[] = []
  const links: Link[] = []
  const groupCount = Math.ceil(cards / perGroup)
  const areaCount = Math.ceil(groupCount / perArea)
  const rows = Math.ceil(perGroup / ROW)
  const innerWidth = groupWidth(ROW, TASK_WIDTH, GAP)
  const innerHeight = groupHeight(rows, TASK_HEIGHT, GAP)
  const areaWidth = groupWidth(AREA_COLUMNS, innerWidth, GAP)
  const areaHeight = groupHeight(Math.ceil(perArea / AREA_COLUMNS), innerHeight, GAP)
  const groupCards: string[][] = []
  let made = 0

  for (let area = 0; area < areaCount; area++) {
    const areaNode: ClusterNode = {
      id: `area-${area}`,
      type: 'cluster',
      position: {
        x: (area % TOP_COLUMNS) * (areaWidth + GAP * 4),
        y: Math.floor(area / TOP_COLUMNS) * (areaHeight + GAP * 4),
      },
      width: areaWidth,
      height: areaHeight,
      data: { kind: 'cluster', label: `Area ${area + 1}` },
    }

    nodes.push(areaNode)

    for (let slot = 0; slot < perArea && groupCards.length < groupCount; slot++) {
      const index = groupCards.length
      const groupId = `group-${index}`
      const ids: string[] = []

      nodes.push({
        id: groupId,
        type: 'cluster',
        parentId: areaNode.id,
        position: {
          x: GROUP_PADDING + (slot % AREA_COLUMNS) * (innerWidth + GAP),
          y: GROUP_HEADER_HEIGHT + Math.floor(slot / AREA_COLUMNS) * (innerHeight + GAP),
        },
        width: innerWidth,
        height: innerHeight,
        data: { kind: 'cluster', label: `Stream ${index + 1}` },
      })

      for (let i = 0; i < perGroup && made < cards; i++, made++) {
        const id = `card-${made}`
        const isPullRequest = roll() < 0.4
        const kindRoll = roll()
        const card: TaskNode = {
          id,
          type: 'task',
          parentId: groupId,
          position: {
            x: GROUP_PADDING + (i % ROW) * (TASK_WIDTH + GAP),
            y: GROUP_HEADER_HEIGHT + Math.floor(i / ROW) * (TASK_HEIGHT + GAP),
          },
          data: {
            kind: 'task',
            label: `Card ${made + 1} in stream ${index + 1}`,
            ...(kindRoll < 0.04 ? { type: 'note' } : kindRoll < 0.07 ? { type: 'gate' } : {}),
            status: pickStatus(roll()),
            ...(isPullRequest
              ? {
                  repo: 'vocksel/orion',
                  refs: [{ source: 'github', kind: 'pull', type: 'pr', key: `vocksel/orion#${1000 + made}` }],
                }
              : {}),
          },
        }

        nodes.push(card)
        ids.push(id)
      }

      groupCards.push(ids)
    }
  }

  for (const [index, ids] of groupCards.entries()) {
    for (let i = 1; i < ids.length; i++) {
      if (roll() < 0.7) links.push({ id: `chain-${ids[i]}`, from: ids[i - 1], to: ids[i], kind: 'blocks' })

      if (i > 2 && roll() < 0.2)
        links.push({ id: `skip-${ids[i]}`, from: ids[Math.floor(roll() * (i - 1))], to: ids[i], kind: 'blocks' })
    }

    // Links only run forward between groups, so dependencies never form a loop.
    const later = groupCards.length - index - 1

    if (later > 0 && ids.length) {
      const target = groupCards[index + 1 + Math.floor(roll() * Math.min(later, 6))]

      links.push({ id: `cross-${index}`, from: ids[ids.length - 1], to: target[0], kind: 'blocks' })
    }

    if (later > 0 && roll() < 0.5) {
      const target = groupCards[index + 1 + Math.floor(roll() * later)]

      links.push({
        id: `related-${index}`,
        from: ids[Math.floor(roll() * ids.length)],
        to: target[Math.floor(roll() * target.length)],
        kind: 'related',
      })
    }
  }

  return { nodes: normalize(nodes), links }
}
