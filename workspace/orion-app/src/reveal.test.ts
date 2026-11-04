import { describe, expect, it } from 'vitest'
import { framedViewport, revealBounds, revealDetail, revealRoot } from './reveal'
import type { AppNode } from './model'

const CARD = { width: 216, height: 72 }

const task = (id: string, parentId?: string, x = 0, y = 0): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, type: 'step', status: 'todo' },
})

const group = (id: string, parentId?: string, x = 0, y = 0): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  width: 600,
  height: 400,
  data: { kind: 'cluster', label: id },
})

describe('reveal root', () => {
  it('stays at the top level for cards that share no group', () => {
    const nodes = [task('a'), task('b'), group('g'), task('c', 'g')]

    expect(revealRoot(nodes, ['a', 'c'])).toBe(null)
  })

  it('opens the innermost group that holds every id', () => {
    const nodes = [group('outer'), group('inner', 'outer'), task('a', 'inner'), task('b', 'inner'), task('c', 'outer')]

    expect(revealRoot(nodes, ['a', 'b'])).toBe('inner')
    expect(revealRoot(nodes, ['a', 'c'])).toBe('outer')
  })

  it('opens the group around a group, not the group itself', () => {
    const nodes = [group('outer'), group('inner', 'outer'), task('a', 'inner')]

    expect(revealRoot(nodes, ['inner'])).toBe('outer')
    expect(revealRoot(nodes, ['inner', 'a'])).toBe('outer')
  })
})

describe('reveal detail', () => {
  it('keeps the detail that already shows every id', () => {
    const nodes = [group('g'), task('a', 'g')]

    expect(revealDetail(nodes, 'g', ['a'], 2)).toBe(2)
    expect(revealDetail(nodes, 'g', ['a'], null)).toBe(null)
  })

  it('unfolds just enough levels to show a card inside a folded group', () => {
    // The card sits in a group at the top level, and a deeper group elsewhere keeps the canvas from showing everything.
    const nodes = [
      group('one'),
      task('x', 'one'),
      group('two'),
      group('mid', 'two'),
      group('deep', 'mid'),
      task('y', 'deep'),
    ]

    expect(revealDetail(nodes, null, ['x'], 1)).toBe(2)
    expect(revealDetail(nodes, null, ['x'], 2)).toBe(2)
  })

  it('shows every level once the needed one is the deepest', () => {
    const nodes = [group('one'), task('x', 'one')]

    expect(revealDetail(nodes, null, ['x'], 1)).toBe(null)
  })

  it('counts the groups inside the open one, not above it', () => {
    const nodes = [
      group('outer'),
      group('inner', 'outer'),
      group('deep', 'inner'),
      task('a', 'deep'),
      group('spare', 'outer'),
      task('b', 'spare'),
    ]

    expect(revealDetail(nodes, 'outer', ['a'], 1)).toBe(null)
    expect(revealDetail(nodes, 'outer', ['b'], 1)).toBe(2)
  })
})

describe('reveal bounds and framing', () => {
  it('spans the ids in flow coordinates, through their groups', () => {
    const nodes = [group('g', undefined, 100, 100), task('a', 'g', 10, 20), task('b', undefined, 0, 0)]

    expect(revealBounds(nodes, ['a'], CARD)).toEqual({ x: 110, y: 120, width: 216, height: 72 })
    expect(revealBounds(nodes, ['a', 'b'], CARD)).toEqual({ x: 0, y: 0, width: 326, height: 192 })
    expect(revealBounds(nodes, ['missing'], CARD)).toBe(null)
  })

  it('centers the bounds and zooms in only as far as the limit', () => {
    const box = { width: 1000, height: 800 }

    expect(framedViewport({ x: 0, y: 0, width: 100, height: 100 }, box, { padding: 0.2, maxZoom: 1.25 })).toEqual({
      x: 437.5,
      y: 337.5,
      zoom: 1.25,
    })
  })

  it('fits a wide selection inside the padding', () => {
    const viewport = framedViewport(
      { x: 0, y: 0, width: 2000, height: 1000 },
      { width: 1000, height: 800 },
      { padding: 0.2, maxZoom: 1.25 },
    )

    expect(viewport.zoom).toBeCloseTo(0.3)
    expect(viewport.x).toBeCloseTo(500 - 1000 * 0.3)
    expect(viewport.y).toBeCloseTo(400 - 500 * 0.3)
  })
})
