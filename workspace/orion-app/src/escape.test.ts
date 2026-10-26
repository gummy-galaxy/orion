import { TASK_HEIGHT, TASK_WIDTH } from './geometry'
import { describe, expect, it } from 'vitest'
import { dragRoots, dropTarget, followEscape, landInside, reparent, startEscape } from './escape'
import { byId, normalize, type AppNode, type ClusterData } from './model'

const size = { width: TASK_WIDTH, height: TASK_HEIGHT }
const POP = 90

const task = (id: string, parentId: string | undefined, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, status: 'todo' },
})
const cluster = (id: string, parentId: string | undefined, x: number, y: number, data: Partial<ClusterData> = {}): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  data: { kind: 'cluster', label: id, ...data },
})

/** A top-level `outer` group holding `inner`, which holds one card, and a loose `side` group beside them. */
const canvas = () =>
  normalize([
    cluster('outer', undefined, 0, 0),
    cluster('inner', 'outer', 32, 78),
    task('card', 'inner', 32, 78),
    task('stay', 'outer', 32, 400),
    cluster('side', undefined, 1200, 0),
    task('side-card', 'side', 32, 78),
    task('side-card-2', 'side', 32, 400),
  ])

const moved = (nodes: AppNode[], id: string, dx: number, dy: number) =>
  nodes.map((node) => (node.id === id ? { ...node, position: { x: node.position.x + dx, y: node.position.y + dy } } : node))

describe('dragRoots', () => {
  it('drops dragged nodes whose parent is dragged too', () => {
    expect(dragRoots(canvas(), ['inner', 'card', 'stay'])).toEqual(['inner', 'stay'])
  })
})

describe('startEscape', () => {
  it('records the starting group and its box', () => {
    const escape = startEscape(canvas(), ['inner'], size)

    expect(escape).toMatchObject({ roots: ['inner'], from: 'outer', home: 'outer', walls: { x: 0, y: 0 } })
  })

  it('gives up on work dragged from more than one group', () => {
    expect(startEscape(canvas(), ['card', 'stay'], size)).toBeNull()
  })
})

describe('followEscape', () => {
  it('keeps the work home while the drag stays near its edge', () => {
    const before = canvas()
    const escape = startEscape(before, ['inner'], size)!
    const nodeMap = byId(before)
    const inner = nodeMap.get('inner')!
    const near = moved(before, 'inner', nodeMap.get('outer')!.width! - (inner.position.x + inner.width!) + 40, 0)

    expect(followEscape(near, escape, before, POP, size)).toBe(escape)
  })

  it('pops out past the distance', () => {
    const before = canvas()
    const escape = startEscape(before, ['inner'], size)!
    const outerWidth = byId(before).get('outer')!.width!

    expect(followEscape(moved(before, 'inner', outerWidth + POP, 0), escape, before, POP, size).home).toBeUndefined()
  })

  it('pops through several levels in one sweep', () => {
    const before = canvas()
    const escape = startEscape(before, ['card'], size)!
    const far = moved(before, 'card', 0, 3000)

    expect(followEscape(far, escape, before, POP, size).home).toBeUndefined()
  })
})

describe('landInside', () => {
  it('moves work dropped past its group edge back within the group', () => {
    const before = canvas()
    const outer = byId(before).get('outer')!
    const landed = byId(landInside(moved(before, 'stay', outer.width!, 60), ['stay'], size))

    expect(landed.get('stay')!.position).toEqual({ x: outer.width! - 32 - TASK_WIDTH, y: outer.height! - 32 - TASK_HEIGHT })
  })

  it('keeps the formation of work dropped together', () => {
    const before = canvas()
    const side = byId(before).get('side')!
    const dropped = moved(moved(before, 'side-card', -100, 0), 'side-card-2', -100, 0)
    const landed = byId(landInside(dropped, ['side-card', 'side-card-2'], size))

    expect(landed.get('side-card')!.position.x).toBe(32)
    expect(landed.get('side-card-2')!.position.x).toBe(32)
    expect(landed.get('side-card-2')!.position.y - landed.get('side-card')!.position.y).toBe(322)
    expect(side.width).toBe(byId(normalize(landInside(dropped, ['side-card', 'side-card-2'], size))).get('side')!.width)
  })

  it('leaves work that is already inside, and work at the top level', () => {
    const before = canvas()

    expect(landInside(before, ['card', 'side'], size)).toBe(before)
  })
})

describe('dropTarget', () => {
  it('keeps work in its group while it stays inside', () => {
    const nodes = canvas()

    expect(dropTarget(nodes, startEscape(nodes, ['card'], size)!, size)).toBe('inner')
  })

  it('lands popped work at the top level, or in the group its center is over', () => {
    const before = canvas()
    const escape = { ...startEscape(before, ['inner'], size)!, home: undefined, walls: null }

    expect(dropTarget(moved(before, 'inner', 0, 2000), escape, size)).toBeUndefined()

    const side = byId(before).get('side')!
    const intoSide = moved(before, 'inner', side.position.x - 32 + 20, 0)

    expect(dropTarget(intoSide, escape, size)).toBe('side')
  })

  it('never targets the dragged group or what is inside it', () => {
    const nodes = canvas()
    const escape = { ...startEscape(nodes, ['outer'], size)!, home: undefined, walls: null }

    expect(dropTarget(nodes, escape, size)).toBeUndefined()
  })
})

describe('reparent', () => {
  it('keeps the work where it is on screen and asks automatic groups to lay out again', () => {
    const nodes = canvas()
    const nodeMap = byId(nodes)
    const outer = nodeMap.get('outer')!
    const inner = nodeMap.get('inner')!
    const lifted = byId(reparent(nodes, ['inner'], undefined, 'outer'))

    expect(lifted.get('inner')!.parentId).toBeUndefined()
    expect(lifted.get('inner')!.position).toEqual({ x: outer.position.x + inner.position.x, y: outer.position.y + inner.position.y })
    expect((lifted.get('outer')!.data as ClusterData).layout).toBe('refit')
  })

  it('leaves a custom group arranged as it is', () => {
    const nodes = canvas().map((node) =>
      node.id === 'side' ? cluster('side', undefined, node.position.x, node.position.y, { arrange: 'custom' }) : node,
    )
    const moved = byId(reparent(nodes, ['inner'], 'side', 'outer'))

    expect(moved.get('inner')!.parentId).toBe('side')
    expect((moved.get('side')!.data as ClusterData).layout).toBeUndefined()
  })

  it('returns the same nodes when the work stays put', () => {
    const nodes = canvas()

    expect(reparent(nodes, ['inner'], 'outer', 'outer')).toBe(nodes)
  })
})
