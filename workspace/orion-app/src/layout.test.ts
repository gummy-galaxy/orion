import { TASK_HEIGHT, TASK_WIDTH } from './geometry'
import { describe, expect, it } from 'vitest'
import { ROW_WIDTH, WRAP, labelWidth, layoutOrder, reflow } from './layout'
import { type AppNode, type ClusterData, type Link } from './model'
import { toDisplayed } from './skinSpace'
import { skinOf } from './skins'

const largeSize = skinOf('trading').size

const task = (id: string, parentId = 'g', x = 0, y = 0): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, type: 'step', status: 'todo' },
})
const group = (data: Partial<ClusterData> = {}): AppNode => ({
  id: 'g',
  type: 'cluster',
  position: { x: 0, y: 0 },
  data: { kind: 'cluster', label: 'G', ...data },
})
const cluster = (id: string, parentId: string | undefined, data: Partial<ClusterData> = {}): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x: 0, y: 0 },
  data: { kind: 'cluster', label: id, ...data },
})
const blocks = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })
const ids = (count: number, prefix = 't') =>
  Array.from({ length: count }, (_, i) => prefix + String(i).padStart(2, '0'))

const placed = async (nodes: AppNode[], links: Link[] = []) => {
  const laidOut = await reflow(nodes, links, 'g')

  return new Map(laidOut.filter((node) => node.parentId === 'g').map((node) => [node.id, node.position]))
}

const distinct = (values: number[]) => new Set(values.map(Math.round)).size

const overlaps = (
  positions: Map<string, { x: number; y: number }>,
  size = { width: TASK_WIDTH, height: TASK_HEIGHT },
) => {
  const all = [...positions.values()]

  return all.some((first, i) =>
    all
      .slice(i + 1)
      .some((second) => Math.abs(first.x - second.x) < size.width && Math.abs(first.y - second.y) < size.height),
  )
}

describe('reflow', () => {
  it('leaves room between linked cards for the label on their link', async () => {
    const nodes = [group(), task('a'), task('b', 'g', 300)]
    const plain = await placed(nodes, [blocks('a', 'b')])
    const label = 'HTTP /api and WebSocket'
    const labeled = await placed(nodes, [{ ...blocks('a', 'b'), label }])
    const gap = (positions: Map<string, { x: number }>) => positions.get('b')!.x - positions.get('a')!.x - TASK_WIDTH

    expect(gap(labeled)).toBeGreaterThanOrEqual(labelWidth(label))
    expect(gap(labeled)).toBeGreaterThan(gap(plain))
  })

  it('keeps a mapped fan apart and reflows it at the trading card size', async () => {
    const fleet = ids(24)
    const nodes = [group(), task('start'), ...fleet.map((id) => task(id)), task('gate')]
    const links = [...fleet.map((id) => blocks('start', id)), ...fleet.map((id) => blocks(id, 'gate'))]
    const classic = await reflow(nodes, links, 'g')
    const mapped = toDisplayed(classic, largeSize)
    const positions = (items: AppNode[]) =>
      new Map(items.filter((node) => node.parentId === 'g').map((node) => [node.id, node.position]))

    expect(overlaps(positions(mapped), largeSize)).toBe(false)
    expect(overlaps(positions(await reflow(mapped, links, 'g', largeSize)), largeSize)).toBe(false)
  })

  it('wraps unlinked siblings at the default width', async () => {
    const positions = await placed([group(), ...ids(32).map((id, i) => task(id, 'g', i * 300))])

    expect(distinct([...positions.values()].map((position) => position.x))).toBeLessThanOrEqual(WRAP)
    expect(overlaps(positions)).toBe(false)
  })

  it('packs a fan of interchangeable work into a grid between what it waits on and what waits on it', async () => {
    const fleet = ids(32)
    const nodes = [group(), task('start'), ...fleet.map((id) => task(id)), task('gate')]
    const links = [...fleet.map((id) => blocks('start', id)), ...fleet.map((id) => blocks(id, 'gate'))]
    const positions = await placed(nodes, links)
    const fleetXs = fleet.map((id) => positions.get(id)!.x)

    expect(distinct(fleetXs)).toBeLessThanOrEqual(WRAP)
    expect(distinct(fleet.map((id) => positions.get(id)!.y))).toBeLessThanOrEqual(WRAP)
    expect(positions.get('start')!.x).toBeLessThan(Math.min(...fleetXs))
    expect(positions.get('gate')!.x).toBeGreaterThan(Math.max(...fleetXs))
    expect(overlaps(positions)).toBe(false)
  })

  it('wraps a long chain into rows that each read left to right', async () => {
    const chain = ids(14)
    const positions = await placed(
      [group(), ...chain.map((id) => task(id))],
      chain.slice(1).map((id, i) => blocks(chain[i], id)),
    )

    expect(distinct(chain.map((id) => positions.get(id)!.x))).toBe(WRAP)
    const rows = [...new Set(chain.map((id) => Math.round(positions.get(id)!.y)))]

    expect(rows).toHaveLength(Math.ceil(chain.length / WRAP))

    for (let i = 1; i < chain.length; i++) {
      const [previous, current] = [positions.get(chain[i - 1])!, positions.get(chain[i])!]

      expect(i % WRAP === 0 ? current.y > previous.y : current.x > previous.x && current.y === previous.y).toBe(true)
    }

    expect(overlaps(positions)).toBe(false)
  })

  it('wraps a chain of wide groups once a row reaches the row width', async () => {
    const sections = ids(6, 's')
    const nodes: AppNode[] = sections.flatMap((id) => [
      { id, type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: id } },
      task(id + 'a', id, 0, 0),
      task(id + 'b', id, 800, 0),
    ])
    const laidOut = await reflow(
      nodes,
      sections.slice(1).map((id, i) => blocks(sections[i], id)),
      undefined,
    )
    const tops = laidOut.filter((node) => sections.includes(node.id)).map((node) => node.position)

    expect(distinct(tops.map((position) => position.y))).toBeGreaterThan(1)
    expect(Math.max(...tops.map((position) => position.x))).toBeLessThan(ROW_WIDTH)
  })

  it('lays unlinked cards out in rows whose column count follows the square root of their count', async () => {
    const positions = await placed([group(), ...ids(10).map((id, i) => task(id, 'g', i * 300, 0))])
    const rows = [...new Set([...positions.values()].map((position) => Math.round(position.y)))]

    expect(distinct([...positions.values()].map((position) => position.x))).toBe(Math.ceil(Math.sqrt(10)))
    expect(rows).toHaveLength(Math.ceil(10 / Math.ceil(Math.sqrt(10))))
    expect(overlaps(positions)).toBe(false)
  })

  it('keeps unlinked cards in their reading order', async () => {
    const cards = ids(9)
    const nodes = [group(), ...cards.map((id, i) => task(id, 'g', (cards.length - i) * 300, 0))]
    const positions = await placed(nodes)
    const inReadingOrder = [...cards].sort((a, b) => {
      const [first, second] = [positions.get(a)!, positions.get(b)!]

      return first.y - second.y || first.x - second.x
    })

    expect(inReadingOrder).toEqual([...cards].reverse())
  })

  it('places a linked chain as one block beside unlinked cards', async () => {
    const chain = ids(3, 'c')
    const loose = ids(5, 'u')
    const positions = await placed(
      [group(), ...chain.map((id) => task(id)), ...loose.map((id) => task(id))],
      chain.slice(1).map((id, i) => blocks(chain[i], id)),
    )

    expect(distinct(chain.map((id) => positions.get(id)!.y))).toBe(1)
    expect(overlaps(positions)).toBe(false)
  })

  it('lines up unlinked subgroups of different widths in shared columns', async () => {
    const sections = ids(4, 's')
    const taskCounts = [1, 3, 1, 3]
    const nodes: AppNode[] = [
      group(),
      ...sections.map((id): AppNode => ({
        id,
        type: 'cluster',
        parentId: 'g',
        position: { x: 0, y: 0 },
        data: { kind: 'cluster', label: id },
      })),
      ...sections.flatMap((id, i) =>
        Array.from({ length: taskCounts[i] }, (_, j) => task(`${id}-${j}`, id, j * 300, 0)),
      ),
    ]
    const positions = await placed(nodes)
    const xs = sections.map((id) => positions.get(id)!.x)

    expect(distinct(xs)).toBe(2)
    expect(xs[2]).toBe(xs[0])
    expect(xs[3]).toBe(xs[1])
    expect(positions.get(sections[2])!.y).toBeGreaterThan(positions.get(sections[0])!.y)
  })

  it('lays out a large group of unlinked cards without overlaps', async () => {
    const cards = ids(400)
    const positions = await placed([group(), ...cards.map((id, i) => task(id, 'g', i * 300, 0))])

    expect(distinct([...positions.values()].map((position) => position.x))).toBe(20)
    expect(overlaps(positions)).toBe(false)
  })

  it('keeps short chains on one row', async () => {
    const positions = await placed([group(), task('a'), task('b'), task('c')], [blocks('a', 'b'), blocks('b', 'c')])

    expect(distinct([...positions.values()].map((position) => position.y))).toBe(1)
  })

  it('lays an automatic group with a size out within its width', async () => {
    const cards = ids(9).map((id) => task(id))
    const narrow = await placed([group({ size: { width: 2 * TASK_WIDTH + 32 + 64, height: 0 } }), ...cards])
    const wide = await placed([group({ size: { width: 9 * TASK_WIDTH + 8 * 32 + 64, height: 0 } }), ...cards])

    expect(distinct([...narrow.values()].map((position) => position.x))).toBe(2)
    expect(distinct([...wide.values()].map((position) => position.y))).toBe(1)
  })

  it('leaves a custom group alone', async () => {
    const nodes = [group({ arrange: 'custom' }), task('a', 'g', 500, 40), task('b', 'g', 3, 900)]

    expect(await reflow(nodes, [blocks('a', 'b')], 'g')).toBe(nodes)
  })
})

/** Lays out marked groups the way the app's pending-layout effect does: one reflow per group, in `layoutOrder`. */
const settle = async (nodes: AppNode[], links: Link[] = []) => {
  let next = nodes

  for (const node of layoutOrder(nodes)) next = await reflow(next, links, node.id)

  return next
}

const rectangle = (nodes: AppNode[], id: string) => {
  const node = nodes.find((candidate) => candidate.id === id)!

  return { x: node.position.x, y: node.position.y, width: node.width ?? 0, height: node.height ?? 0 }
}

const rectanglesOverlap = (first: ReturnType<typeof rectangle>, second: ReturnType<typeof rectangle>) =>
  first.x < second.x + second.width &&
  second.x < first.x + first.width &&
  first.y < second.y + second.height &&
  second.y < first.y + first.height

describe('layoutOrder', () => {
  it('lays out deeper groups before the groups that contain them', () => {
    const nodes = [
      cluster('outer', undefined, { layout: 'refit' }),
      cluster('left', 'outer', { layout: 'refit' }),
      cluster('deep', 'left', { layout: 'refit' }),
    ]

    expect(layoutOrder(nodes).map((node) => node.id)).toEqual(['deep', 'left', 'outer'])
  })

  it('keeps node order between groups at the same depth', () => {
    const nodes = [
      cluster('b', undefined, { layout: 'pending' }),
      cluster('a', undefined, { layout: 'refit' }),
      cluster('c', undefined, { layout: 'refit' }),
    ]

    expect(layoutOrder(nodes).map((node) => node.id)).toEqual(['b', 'a', 'c'])
  })

  it('leaves out groups without a layout marker and cards', () => {
    const nodes = [cluster('outer', undefined), cluster('inner', 'outer', { layout: 'refit' }), task('t', 'inner')]

    expect(layoutOrder(nodes).map((node) => node.id)).toEqual(['inner'])
  })
})

describe('nested layout', () => {
  it('settles a parent with marked subgroups in one pass, so no subgroup covers its sibling', async () => {
    const outer = cluster('outer', undefined, { layout: 'refit' })
    const left = cluster('left', 'outer', { layout: 'refit' })
    const right = cluster('right', 'outer', { layout: 'refit' })
    const leftIds = ids(12, 'l')
    const rightIds = ids(12, 'r')
    const nodes = [
      outer,
      left,
      right,
      ...leftIds.map((id, i) => task(id, 'left', i * 300, 0)),
      ...rightIds.map((id, i) => task(id, 'right', i * 300, 0)),
    ]
    const laidOut = await settle(nodes)
    const [leftBox, rightBox] = [rectangle(laidOut, 'left'), rectangle(laidOut, 'right')]

    expect(rectanglesOverlap(leftBox, rightBox)).toBe(false)
    expect(
      laidOut
        .filter((node) => node.parentId === 'outer')
        .map((node) => node.id)
        .sort(),
    ).toEqual(['left', 'right'])
  })

  it('sizes each parent to its subgroups final size', async () => {
    const nodes = [
      cluster('outer', undefined, { layout: 'refit' }),
      cluster('inner', 'outer', { layout: 'refit' }),
      ...ids(20).map((id, i) => task(id, 'inner', i * 300, 0)),
    ]
    const laidOut = await settle(nodes)
    const inner = rectangle(laidOut, 'inner')
    const outer = rectangle(laidOut, 'outer')

    expect(outer.width).toBe(inner.width + 2 * 32)
    expect(outer.height).toBe(inner.height + 78 + 32)
  })
})
