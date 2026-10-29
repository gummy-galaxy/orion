import { readFileSync, writeFileSync } from 'node:fs'
import { GAP, GROUP_PADDING } from '../geometry'
import { describe, expect, it } from 'vitest'
import { layoutOrder, layoutSpike, reflow } from '../layout'
import { absolutePosition, byId, isCluster, normalize, sizeOf, type AppNode, type ClusterData, type Link } from '../model'
import type { Saved } from '../persist'
import { toStored } from '../skinSpace'
import { skinOf } from '../skins'
import sprawlCanvas from './sprawlCanvas.json'

// Spike harness for compact, square groups: lays out the sprawl canvas and a few hand-built cases under each layout
// mode and measures every group. Set SPIKE_OUT to a file path to write the results as JSON.
const cardSize = skinOf('trading').size
const cell = { width: cardSize.width + GAP.inner.x, height: cardSize.height + GAP.inner.y }

const MODES: Record<string, Partial<typeof layoutSpike>> = {
  today: {},
  'wrap@1': { wrap: true, wrapAspect: 1 },
  wrap: { wrap: true },
  'wrap@2.4': { wrap: true, wrapAspect: 2.4 },
  rect: { pack: 'rect' },
  skyline: { pack: 'skyline' },
  'wrap+rect': { wrap: true, pack: 'rect' },
  'wrap+skyline': { wrap: true, pack: 'skyline' },
  'wrap+skyline+round': { wrap: true, pack: 'skyline', round: true },
  orphans: { orphans: true },
  'wrap+skyline+tight': { wrap: true, pack: 'skyline', spread: 1 },
  'wrap+skyline+orphans+tight': { wrap: true, pack: 'skyline', orphans: true, spread: 1 },
  'wrap+skyline+orphans': { wrap: true, pack: 'skyline', orphans: true },
}

type Box = { x: number; y: number; width: number; height: number }

const task = (id: string, parentId: string): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})
const cluster = (id: string, parentId?: string, data: Partial<ClusterData> = {}, x = 0): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y: 0 },
  data: { kind: 'cluster', label: id, ...data },
})
const blocks = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })
const related = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'related' })
const range = (count: number, prefix: string) => Array.from({ length: count }, (_, i) => `${prefix}${i}`)
const chain = (ids: string[]) => ids.slice(1).map((id, i) => blocks(ids[i], id))

/** Hand-built cases: a long chain, a fan, a mix of shapes, a phase holding epics of different sizes, and single epics. */
function cases(): Record<string, Saved> {
  const long = range(20, 'c')
  const fan = range(12, 'f')
  const mixed = {
    nodes: [cluster('mixed'), ...range(8, 'm').map((id) => task(id, 'mixed')), ...range(9, 's').map((id) => task(id, 'mixed'))],
    links: [] as Link[],
  }

  mixed.nodes.push(...range(10, 'u').map((id) => task(id, 'mixed')), ...['d0', 'd1', 'd2', 'd3'].map((id) => task(id, 'mixed')))
  mixed.links.push(...chain(range(8, 'm')), ...[0, 3, 6].flatMap((start) => chain(range(9, 's').slice(start, start + 3))))
  mixed.links.push(blocks('d0', 'd1'), blocks('d0', 'd2'), blocks('d1', 'd3'), blocks('d2', 'd3'))

  const epics = [3, 9, 5, 14, 2].map((count, i) => ({ id: `epic${i}`, cards: range(count, `e${i}-`) }))
  const phase = {
    nodes: [cluster('phase'), ...epics.flatMap((epic) => [cluster(epic.id, 'phase'), ...epic.cards.map((id) => task(id, epic.id))])],
    // Each epic's work runs as two short chains into its gate, the last card.
    links: epics.flatMap((epic) => {
      const gate = epic.cards[epic.cards.length - 1]
      const work = epic.cards.slice(0, -1)
      const half = Math.ceil(work.length / 2)

      return [work.slice(0, half), work.slice(half)]
        .filter((part) => part.length)
        .flatMap((part) => [...chain(part), blocks(part[part.length - 1], gate)])
    }),
  }

  return {
    chain: { nodes: [cluster('chain'), ...long.map((id) => task(id, 'chain'))], links: chain(long) },
    fan: {
      nodes: [cluster('fan'), task('start', 'fan'), ...fan.map((id) => task(id, 'fan')), task('gate', 'fan')],
      links: [...fan.map((id) => blocks('start', id)), ...fan.map((id) => blocks(id, 'gate'))],
    },
    mixed,
    phase,
    // One epic: five steps into its gate, and two parallel runs of four into a gate.
    epic: { nodes: [cluster('epic'), ...range(6, 'p').map((id) => task(id, 'epic'))], links: chain(range(6, 'p')) },
    // A group whose cards link in every way: a chain inside, a related pair inside, cards that only wait on or feed
    // groups to either side, one related to a card outside, and cards with no links at all.
    edges: {
      nodes: [
        cluster('upstream', undefined, {}, -3000),
        task('up', 'upstream'),
        cluster('downstream', undefined, {}, 5000),
        task('down', 'downstream'),
        cluster('edges'),
        ...['c0', 'c1', 'c2', 'c3', 'r0', 'r1', 'i0', 'i1', 'i2', 'x0', 'x1', 'q0', ...range(6, 'o')].map((id) => task(id, 'edges')),
      ],
      links: [
        ...chain(['c0', 'c1', 'c2', 'c3']),
        related('r0', 'r1'),
        ...['i0', 'i1', 'i2'].map((id) => blocks('up', id)),
        ...['x0', 'x1'].map((id) => blocks(id, 'down')),
        related('q0', 'up'),
      ],
    },
    twoRuns: {
      nodes: [
        cluster('twoRuns'),
        ...range(4, 'a').map((id) => task(id, 'twoRuns')),
        ...range(4, 'b').map((id) => task(id, 'twoRuns')),
        task('gate', 'twoRuns'),
      ],
      links: [...chain(range(4, 'a')), ...chain(range(4, 'b')), blocks('a3', 'gate'), blocks('b3', 'gate')],
    },
  }
}

/** Lays out every auto group deepest first, as the app does for groups waiting on layout, then the top level. */
async function layOut(saved: Saved): Promise<AppNode[]> {
  const marked = saved.nodes.map((node) => (isCluster(node) ? { ...node, data: { ...node.data, layout: 'pending' as const } } : node))
  let nodes = normalize(marked as AppNode[], cardSize)

  for (const group of layoutOrder(nodes)) nodes = await reflow(nodes, saved.links, group.id, cardSize)

  return reflow(nodes, saved.links, undefined, cardSize)
}

const centerX = (box: Box) => box.x + box.width / 2
const rowsOverlap = (a: Box, b: Box) => a.y < b.y + b.height && b.y < a.y + a.height
const intersect = (a: Box, b: Box) => a.x < b.x + b.width && b.x < a.x + a.width && rowsOverlap(a, b)

/** Overlaps between siblings once positions are mapped back to the classic card space the canvas is stored in. */
function storedOverlaps(nodes: AppNode[]) {
  const stored = toStored(nodes, cardSize)
  const nodeMap = byId(stored)
  const box = (node: AppNode): Box => ({ ...absolutePosition(node, nodeMap), ...sizeOf(node) })
  const found: { parent: string; depth: number }[] = []

  for (const group of [undefined, ...stored.filter(isCluster).map((node) => node.id)]) {
    const children = stored.filter((node) => node.parentId === group && (!group || nodeMap.get(group)?.data.kind === 'cluster'))
    const auto = !group || (nodeMap.get(group) as AppNode & { data: ClusterData }).data.arrange !== 'custom'

    if (!auto) continue

    children.forEach((a, i) =>
      children.slice(i + 1).forEach((b) => {
        const first = box(a)
        const second = box(b)

        if (intersect(first, second))
          found.push({
            parent: group ?? 'top',
            depth: Math.round(Math.min(first.y + first.height, second.y + second.height) - Math.max(first.y, second.y)),
          })
      }),
    )
  }

  return found
}

/** `before` is the canvas as it was before layout, which decides the side a `related` link to the outside faces. */
function measure(nodes: AppNode[], links: Link[], before: AppNode[]) {
  const nodeMap = byId(nodes)
  const beforeMap = byId(before)
  const startBox = (node: AppNode): Box => ({ ...absolutePosition(node, beforeMap), ...sizeOf(node, cardSize) })
  const box = (node: AppNode): Box => ({ ...absolutePosition(node, nodeMap), ...sizeOf(node, cardSize) })

  return nodes.filter(isCluster).map((group) => {
    const own = box(group)
    const children = nodes.filter((node) => node.parentId === group.id)

    const lift = (id: string) => {
      let current = nodeMap.get(id)

      while (current && current.parentId !== group.id) current = current.parentId ? nodeMap.get(current.parentId) : undefined

      return current
    }

    let backward = 0
    let wrapped = 0
    let linked = 0

    for (const link of links) {
      if (link.kind !== 'blocks') continue

      const source = lift(link.from)
      const target = lift(link.to)

      if (!source || !target || source === target) continue

      linked++

      const from = box(source)
      const to = box(target)

      // A link whose end sits left of its start: on the same row it reads backward; below, it's a wrap like a line of text.
      if (centerX(to) < centerX(from) - 1) {
        if (rowsOverlap(from, to)) backward++
        else wrapped++
      }
    }

    // How each child links: inside the group, only outside it, or not at all.
    const kinds = new Map(children.map((child) => [child.id, 'orphan' as 'inside' | 'outside' | 'orphan']))
    const facing = new Map<string, number>()
    const center = startBox(beforeMap.get(group.id)!).x + startBox(beforeMap.get(group.id)!).width / 2

    for (const link of links) {
      const source = lift(link.from)
      const target = lift(link.to)

      if (source && target) {
        if (source !== target) for (const end of [source, target]) kinds.set(end.id, 'inside')

        continue
      }

      const inside = source ?? target
      const other = nodeMap.get(source ? link.to : link.from)

      if (!inside || !other) continue

      if (kinds.get(inside.id) === 'orphan') kinds.set(inside.id, 'outside')

      const leftward = link.kind === 'blocks' ? !!target : startBox(beforeMap.get(other.id)!).x < center

      facing.set(inside.id, (facing.get(inside.id) ?? 0) + (leftward ? 1 : -1))
    }

    const ofKind = (kind: string) => children.filter((child) => kinds.get(child.id) === kind).map(box)
    const insideBoxes = ofKind('inside')
    // Only cards count as orphans, as in the layout.
    const orphanCards = new Set(children.filter((child) => kinds.get(child.id) === 'orphan' && child.type === 'task'))
    const orphanBoxes = [...orphanCards].map(box)
    const orphanFrame =
      orphanBoxes.length > 1
        ? orphanBoxes.reduce((frame, next) => {
            const x = Math.min(frame.x, next.x)
            const y = Math.min(frame.y, next.y)

            return {
              x,
              y,
              width: Math.max(frame.x + frame.width, next.x + next.width) - x,
              height: Math.max(frame.y + frame.height, next.y + next.height) - y,
            }
          })
        : undefined
    // Connected cards sitting among the orphans, inside the frame around them.
    const intruders = orphanFrame ? children.filter((child) => !orphanCards.has(child) && intersect(box(child), orphanFrame)).length : 0
    const outsideIds = children.filter((child) => kinds.get(child.id) === 'outside').map((child) => child.id)
    // A card linked only outside faces its links when nothing linked inside the group sits further toward them.
    const faced = outsideIds.filter((id) => {
      const own = box(nodeMap.get(id)!)

      return (facing.get(id) ?? 0) >= 0
        ? insideBoxes.every((other) => own.x <= other.x)
        : insideBoxes.every((other) => own.x + own.width >= other.x + other.width)
    }).length

    const childBoxes = children.map(box)
    const overlaps = childBoxes.flatMap((a, i) =>
      childBoxes
        .slice(i + 1)
        .filter((b) => intersect(a, b))
        .map((b) => Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y)),
    )
    const content = {
      width: own.width - GROUP_PADDING * 2,
      height: own.height - (childBoxes.length ? Math.min(...childBoxes.map((child) => child.y)) - own.y : 0) - GROUP_PADDING,
    }
    const filled = childBoxes.reduce((sum, child) => sum + child.width * child.height, 0)

    return {
      id: group.id,
      arrange: group.data.arrange ?? 'auto',
      children: children.length,
      width: Math.round(own.width),
      height: Math.round(own.height),
      aspect: own.width / own.height,
      cells: { across: (content.width + GAP.inner.x) / cell.width, down: (content.height + GAP.inner.y) / cell.height },
      area: own.width * own.height,
      fill: filled / (content.width * content.height),
      linked,
      backward,
      wrapped,
      overlaps: overlaps.map(Math.round),
      orphans: orphanBoxes.length,
      intruders,
      outside: outsideIds.length,
      faced,
    }
  })
}

describe('square groups spike', () => {
  it('measures each layout mode', { timeout: 120_000 }, async () => {
    const inputs: Record<string, Saved> = { sprawl: sprawlCanvas as unknown as Saved, ...cases() }

    // SPIKE_INPUT adds another saved canvas, such as one exported from a scratch data folder.
    if (process.env.SPIKE_INPUT) inputs.input = JSON.parse(readFileSync(process.env.SPIKE_INPUT, 'utf8')) as Saved

    const results: Record<string, Record<string, ReturnType<typeof measure>>> = {}
    const stored: Record<string, Record<string, ReturnType<typeof storedOverlaps>>> = {}

    for (const [mode, settings] of Object.entries(MODES)) {
      Object.assign(layoutSpike, { wrap: false, pack: 'grid', round: false, orphans: false, aspect: 1, wrapAspect: 1.6, spread: 2 }, settings)
      results[mode] = {}

      for (const [name, saved] of Object.entries(inputs)) {
        const laidOut = await layOut(saved)

        results[mode][name] = measure(laidOut, saved.links, normalize(saved.nodes, cardSize))
        stored[mode] = { ...stored[mode], [name]: storedOverlaps(laidOut) }
      }
    }

    Object.assign(layoutSpike, { wrap: false, pack: 'grid', round: false, orphans: false, aspect: 1, wrapAspect: 1.6, spread: 2 })

    if (process.env.SPIKE_OUT) writeFileSync(process.env.SPIKE_OUT, JSON.stringify({ results, stored }, null, 2))

    expect(Object.keys(results)).toEqual(Object.keys(MODES))
  })
})
