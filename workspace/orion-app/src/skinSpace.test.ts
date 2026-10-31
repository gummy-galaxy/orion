import { describe, expect, it } from 'vitest'
import { normalize, sizeOf, type AppNode } from './model'
import { toDisplayed, toStored } from './skinSpace'

const largeSize = { width: 288, height: 400 }
const task = (id: string, parentId: string | undefined, x: number, y: number): AppNode => ({
  id,
  type: 'task',
  parentId,
  position: { x, y },
  data: { kind: 'task', label: id, status: 'todo' },
})
const group = (id: string, parentId: string | undefined, x: number, y: number): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  data: { kind: 'cluster', label: id },
})

function boxesOverlap(first: AppNode, second: AppNode): boolean {
  const firstSize = sizeOf(first, largeSize)
  const secondSize = sizeOf(second, largeSize)

  return (
    first.position.x < second.position.x + secondSize.width &&
    second.position.x < first.position.x + firstSize.width &&
    first.position.y < second.position.y + secondSize.height &&
    second.position.y < first.position.y + firstSize.height
  )
}

function arrangedGroup(id: string, x: number, y: number): AppNode[] {
  const nestedId = `${id}-nested`

  return [
    group(id, undefined, x, y),
    task(`${id}-a`, id, 32, 78),
    task(`${id}-b`, id, 304, 78),
    group(nestedId, id, 32, 174),
    task(`${id}-nested-a`, nestedId, 32, 78),
    task(`${id}-nested-b`, nestedId, 304, 174),
  ]
}

describe('skin space', () => {
  const nodes = normalize([
    { id: 'outer', type: 'cluster', position: { x: 360, y: 200 }, data: { kind: 'cluster', label: 'Outer' } },
    {
      id: 'inner',
      type: 'cluster',
      parentId: 'outer',
      position: { x: 320, y: 180 },
      data: { kind: 'cluster', label: 'Inner' },
    },
    task('nested-a', 'inner', 32, 78),
    task('nested-b', 'inner', 304, 174),
    task('outer-card', 'outer', 32, 78),
    {
      id: 'image',
      type: 'image',
      parentId: 'outer',
      position: { x: 720, y: 78 },
      width: 320,
      height: 240,
      data: { kind: 'image', label: 'Image', asset: 'x', canvas: 'default' },
    },
    task('top-card', undefined, 1200, 200),
  ])

  it('uses the identity map at the Classic size', () => {
    const classicSize = { width: 216, height: 72 }

    expect(toDisplayed(nodes, classicSize)).toBe(nodes)
    expect(toStored(nodes, classicSize)).toBe(nodes)
  })

  it('round trips nested groups and images without moving stored positions', () => {
    const displayed = toDisplayed(nodes, largeSize)
    const restored = toStored(displayed, largeSize)
    const topCard = displayed.find((node) => node.id === 'top-card')!
    const nestedCard = displayed.find((node) => node.id === 'nested-b')!

    expect(topCard.position.x).toBeCloseTo((1200 * (largeSize.width + 56)) / (216 + 56), 9)
    expect(nestedCard.position.y).toBeCloseTo(78 + ((174 - 78) * (largeSize.height + 24)) / (72 + 24), 9)
    expect(restored).toEqual(nodes)
    expect(displayed.find((node) => node.id === 'image')).toMatchObject({ width: 320, height: 240 })
  })

  it('keeps stacked and side-by-side groups and all sibling boxes apart', () => {
    const stored = normalize([
      ...arrangedGroup('top-left', 0, 0),
      ...arrangedGroup('top-right', 736, 0),
      ...arrangedGroup('bottom-left', 0, 556),
      ...arrangedGroup('bottom-right', 736, 556),
    ])
    const displayed = toDisplayed(stored, largeSize)

    for (const first of displayed)
      for (const second of displayed)
        if (first.id < second.id && first.parentId === second.parentId) expect(boxesOverlap(first, second)).toBe(false)

    expect(toStored(displayed, largeSize)).toEqual(stored)
  })

  it('scales the room inside a group with a size and gives it back unchanged', () => {
    const sized = normalize([
      {
        id: 'g',
        type: 'cluster',
        position: { x: 0, y: 0 },
        data: { kind: 'cluster', label: 'G', arrange: 'custom', size: { width: 900, height: 600 } },
      },
      task('a', 'g', 32, 78),
    ])
    const shown = toDisplayed(sized, largeSize)
    const group = shown.find((node) => node.id === 'g')!

    expect(group.width).toBeGreaterThan(900)
    expect(toStored(shown, largeSize).find((node) => node.id === 'g')!.data).toEqual(
      sized.find((node) => node.id === 'g')!.data,
    )
  })
})
