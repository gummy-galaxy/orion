import { describe, expect, it } from 'vitest'
import { isCluster, isTask } from '../model'
import { generateCanvas } from './fixture'

describe('generateCanvas', () => {
  it('builds the requested number of cards in nested groups', () => {
    const { nodes, links } = generateCanvas({ cards: 100 })
    const ids = new Set(nodes.map((node) => node.id))

    expect(nodes.filter(isTask)).toHaveLength(100)
    expect(nodes.filter(isCluster).length).toBeGreaterThan(5)
    expect(ids.size).toBe(nodes.length)
    expect(nodes.every((node) => !node.parentId || ids.has(node.parentId))).toBe(true)
    expect(links.every((link) => ids.has(link.from) && ids.has(link.to))).toBe(true)
  })

  it('builds the same canvas for the same seed', () => {
    expect(generateCanvas({ cards: 200, seed: 7 })).toEqual(generateCanvas({ cards: 200, seed: 7 }))
    expect(generateCanvas({ cards: 200, seed: 7 })).not.toEqual(generateCanvas({ cards: 200, seed: 8 }))
  })

  it('only links forward, so dependencies never loop', () => {
    const { links } = generateCanvas({ cards: 500 })
    const order = (id: string) => Number(id.split('-')[1])

    expect(links.filter((link) => link.kind === 'blocks').every((link) => order(link.from) < order(link.to))).toBe(true)
  })
})
