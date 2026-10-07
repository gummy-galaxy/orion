import { describe, expect, it } from 'vitest'
import { ROW_WIDTH, WRAP, reflow } from './layout'
import { TASK_H, TASK_W, type AppNode, type ClusterData, type Link } from './model'

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
const ids = (n: number, prefix = 't') => Array.from({ length: n }, (_, i) => prefix + String(i).padStart(2, '0'))

const placed = async (nodes: AppNode[], links: Link[] = []) => {
  const out = await reflow(nodes, links, 'g')
  return new Map(out.filter((n) => n.parentId === 'g').map((n) => [n.id, n.position]))
}
const distinct = (values: number[]) => new Set(values.map(Math.round)).size
const overlaps = (pos: Map<string, { x: number; y: number }>) => {
  const all = [...pos.values()]
  return all.some((a, i) => all.slice(i + 1).some((b) => Math.abs(a.x - b.x) < TASK_W && Math.abs(a.y - b.y) < TASK_H))
}

describe('reflow', () => {
  it('wraps unlinked siblings at the default width', async () => {
    const pos = await placed([group(), ...ids(32).map((id, i) => task(id, 'g', i * 300))])
    expect(distinct([...pos.values()].map((p) => p.x))).toBeLessThanOrEqual(WRAP)
    expect(overlaps(pos)).toBe(false)
  })

  it('packs a fan of interchangeable work into a grid between what it waits on and what waits on it', async () => {
    const fleet = ids(32)
    const nodes = [group(), task('start'), ...fleet.map((id) => task(id)), task('gate')]
    const links = [...fleet.map((id) => blocks('start', id)), ...fleet.map((id) => blocks(id, 'gate'))]
    const pos = await placed(nodes, links)
    const xs = fleet.map((id) => pos.get(id)!.x)
    expect(distinct(xs)).toBeLessThanOrEqual(WRAP)
    expect(distinct(fleet.map((id) => pos.get(id)!.y))).toBeLessThanOrEqual(WRAP)
    expect(pos.get('start')!.x).toBeLessThan(Math.min(...xs))
    expect(pos.get('gate')!.x).toBeGreaterThan(Math.max(...xs))
    expect(overlaps(pos)).toBe(false)
  })

  it('wraps a long chain into rows that each read left to right', async () => {
    const chain = ids(14)
    const pos = await placed(
      [group(), ...chain.map((id) => task(id))],
      chain.slice(1).map((id, i) => blocks(chain[i], id)),
    )
    expect(distinct(chain.map((id) => pos.get(id)!.x))).toBe(WRAP)
    const rows = [...new Set(chain.map((id) => Math.round(pos.get(id)!.y)))]
    expect(rows).toHaveLength(Math.ceil(chain.length / WRAP))
    for (let i = 1; i < chain.length; i++) {
      const [a, b] = [pos.get(chain[i - 1])!, pos.get(chain[i])!]
      expect(i % WRAP === 0 ? b.y > a.y : b.x > a.x && b.y === a.y).toBe(true)
    }
    expect(overlaps(pos)).toBe(false)
  })

  it('wraps a chain of wide groups once a row reaches the row width', async () => {
    const sections = ids(6, 's')
    const nodes: AppNode[] = sections.flatMap((id) => [
      { id, type: 'cluster', position: { x: 0, y: 0 }, data: { kind: 'cluster', label: id } },
      task(id + 'a', id, 0, 0),
      task(id + 'b', id, 800, 0),
    ])
    const out = await reflow(
      nodes,
      sections.slice(1).map((id, i) => blocks(sections[i], id)),
      undefined,
    )
    const tops = out.filter((n) => sections.includes(n.id)).map((n) => n.position)
    expect(distinct(tops.map((p) => p.y))).toBeGreaterThan(1)
    expect(Math.max(...tops.map((p) => p.x))).toBeLessThan(ROW_WIDTH)
  })

  it('keeps short chains on one row', async () => {
    const pos = await placed([group(), task('a'), task('b'), task('c')], [blocks('a', 'b'), blocks('b', 'c')])
    expect(distinct([...pos.values()].map((p) => p.y))).toBe(1)
  })

  it('leaves a custom group alone', async () => {
    const nodes = [group({ arrange: 'custom' }), task('a', 'g', 500, 40), task('b', 'g', 3, 900)]
    expect(await reflow(nodes, [blocks('a', 'b')], 'g')).toBe(nodes)
  })
})
