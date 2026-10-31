import { describe, expect, it } from 'vitest'
import { getItemTypes } from '../cardTypes/getItemTypes'
import type { TaskData } from '../model'
import type { Saved } from '../persist'
import sprawlCanvas from './sprawlCanvas.json'

// A real canvas after weeks of agents adding to it, anonymized: 28 groups, about 500 cards, and their links, with
// labels, notes, and refs replaced. Kept for layout work such as #520, which needs a board that sprawled on its own.
const canvas = sprawlCanvas as unknown as Saved

describe('sprawlCanvas', () => {
  it('keeps every parent and link end on the canvas', () => {
    const types = new Map(canvas.nodes.map((node) => [node.id, node.type]))

    expect(canvas.nodes.every((node) => !node.parentId || types.get(node.parentId) === 'cluster')).toBe(true)
    expect(canvas.links.every((link) => types.has(link.from) && types.has(link.to))).toBe(true)
  })

  it('holds no labels from the original canvas', () => {
    expect(canvas.nodes.every((node) => /^(Card|Group|Image) \d+$/.test(node.data.label))).toBe(true)
  })

  it('keeps each card the kind it was on the original canvas', () => {
    const counts: Record<string, number> = {}

    for (const node of canvas.nodes) {
      if (node.type !== 'task') continue

      const { primary } = getItemTypes(node.data as TaskData)

      counts[primary] = (counts[primary] ?? 0) + 1
    }

    expect(counts).toEqual({ pr: 342, placeholder: 147, gate: 7, note: 8, step: 4 })
  })
})
