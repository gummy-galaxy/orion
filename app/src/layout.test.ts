import { describe, expect, it } from 'vitest'
import { ROW_WIDTH, WRAP, labelWidth, reflow } from './layout'
import { TASK_HEIGHT, TASK_WIDTH, type AppNode, type ClusterData, type Link } from './model'

const task = (id: string, parentId = 'g', x = 0, y = 0): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})
const group = (data: Partial<ClusterData> = {}): AppNode => ({
  id: 'g',
  type: 'cluster',
  position: { x: 0, y: 0 },
  data: { kind: 'cluster', label: 'G', ...data },
})
const blocks = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })
const ids = (count: number, prefix = 't') => Array.from({ length: count }, (_, i) => prefix + String(i).padStart(2, '0'))

const placed = async (nodes: AppNode[], links: Link[] = []) => {
  const laidOut = await reflow(nodes, links, 'g')

  return new Map(laidOut.filter((node) => node.parentId === 'g').map((node) => [node.id, node.position]))
}

const distinct = (values: number[]) => new Set(values.map(Math.round)).size

const overlaps = (positions: Map<string, { x: number; y: number }>) => {
  const all = [...positions.values()]

  return all.some((first, i) =>
    all.slice(i + 1).some((second) => Math.abs(first.x - second.x) < TASK_WIDTH && Math.abs(first.y - second.y) < TASK_HEIGHT),
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

  it('keeps short chains on one row', async () => {
    const positions = await placed([group(), task('a'), task('b'), task('c')], [blocks('a', 'b'), blocks('b', 'c')])

    expect(distinct([...positions.values()].map((position) => position.y))).toBe(1)
  })

  it('leaves a custom group alone', async () => {
    const nodes = [group({ arrange: 'custom' }), task('a', 'g', 500, 40), task('b', 'g', 3, 900)]

    expect(await reflow(nodes, [blocks('a', 'b')], 'g')).toBe(nodes)
  })
})
