import { describe, expect, it } from 'vitest'
import { TASK_HEIGHT, TASK_WIDTH, type AppNode, type Link } from './model'
import { WEAVE_GAP, weave } from './weave'

const task = (id: string, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})
const blocks = (from: string, to: string): Link => ({ id: `${from}>${to}`, from, to, kind: 'blocks' })
const at = (nodes: AppNode[]) => new Map(nodes.map((n) => [n.id, n.position]))

describe('weave', () => {
  it('leaves a level alone when no line runs through a card', () => {
    const nodes = [task('a', 0, 0), task('b', 400, 0), task('c', 0, 300)]
    const r = weave(nodes, [blocks('a', 'b')], undefined)

    expect(r.outcome).toBe('clean')
    expect(r.nodes).toBe(nodes)
  })

  it('slides a card off a line the short way and leaves the line alone', () => {
    // The line runs along y = TASK_HEIGHT / 2; the card sits mostly below it, so up is the long way round.
    const nodes = [task('a', 0, 0), task('c', 900, 0), task('b', 400, 20)]
    const r = weave(nodes, [blocks('a', 'c')], undefined)

    expect(r.outcome).toBe('woven')
    expect(r.after).toBe(0)
    const p = at(r.nodes)

    expect(p.get('a')).toEqual({ x: 0, y: 0 })
    expect(p.get('c')).toEqual({ x: 900, y: 0 })
    const b = p.get('b')!

    expect(b.y).toBeGreaterThan(20)
    expect(b.y - 20).toBeLessThanOrEqual(TASK_HEIGHT / 2 - 20 + WEAVE_GAP + 8)
  })

  it('shoves the cards in the way when the shortest way out is crowded', () => {
    // The line clips the top of `b`, so down is shortest, but `d` sits right below it.
    const bY = TASK_HEIGHT / 2 + 4
    const dY = bY + TASK_HEIGHT + WEAVE_GAP + 4
    const nodes = [task('a', 0, 0), task('c', 900, 0), task('b', 400, bY), task('d', 400, dY)]
    const r = weave(nodes, [blocks('a', 'c')], undefined)

    expect(r.before).toBe(1)
    expect(r.after).toBe(0)
    const p = at(r.nodes)

    expect(p.get('b')!.y).toBeGreaterThan(bY)
    expect(p.get('b')!.y - bY).toBeLessThan(TASK_HEIGHT / 2)
    expect(p.get('d')!.y).toBeGreaterThan(dY)
    expect(p.get('d')!.y - p.get('b')!.y).toBeGreaterThanOrEqual(TASK_HEIGHT + WEAVE_GAP)
  })

  it('gives up without moving anything when the level is a knot', () => {
    const nodes: AppNode[] = []
    const links: Link[] = []

    for (let i = 0; i < 6; i++) {
      nodes.push(task(`s${i}`, 0, i * 120), task(`t${i}`, 2400, i * 120))

      for (let j = 0; j < 6; j++) links.push(blocks(`s${i}`, `t${j}`))
    }

    for (let x = 0; x < 6; x++) for (let y = 0; y < 6; y++) nodes.push(task(`m${x}${y}`, 300 + x * (TASK_WIDTH + 60), y * 120))

    const r = weave(nodes, links, undefined)

    expect(r.outcome).toBe('tangled')
    expect(r.nodes).toBe(nodes)
  })

  it('moves only the direct children of the group it weaves', () => {
    const group: AppNode = { id: 'g', type: 'cluster', position: { x: 0, y: 0 }, width: 1200, height: 200, data: { kind: 'cluster', label: 'G' } }
    const inside = (n: AppNode): AppNode => ({ ...n, parentId: 'g' })
    const nodes = [group, inside(task('a', 24, 52)), inside(task('c', 924, 52)), inside(task('b', 424, 72)), task('out', 0, 600)]
    const r = weave(nodes, [blocks('a', 'c')], 'g')

    expect(r.outcome).toBe('woven')
    expect(at(r.nodes).get('out')).toEqual({ x: 0, y: 600 })
  })
})
