import fc from 'fast-check'
import { describe, expect, it } from 'vitest'
import { emptyHistory, record, redo, undo, type History } from './history'
import type { AppNode, Link, Status } from './model'
import { compactDoc, type Saved } from './persist'
import type { Sticker } from './sticker'

const STATUSES: Status[] = ['todo', 'active', 'done']
const STICKER_KINDS = ['🎉', '🔥', '👀']

/** A document built from a fixed pool of ids, so separate documents share cards and diverge field by field. */
function docOf(ids: string[]): fc.Arbitrary<Saved> {
  const node = (id: string) =>
    fc
      .record({
        x: fc.integer({ min: 0, max: 3 }),
        label: fc.constantFrom('one', 'two'),
        status: fc.constantFrom(...STATUSES),
        width: fc.option(fc.constantFrom(200, 320), { nil: undefined }),
        note: fc.option(fc.constant('context'), { nil: undefined }),
      })
      .map(({ x, label, status, width, note }): AppNode => ({
        id,
        type: 'task',
        position: { x, y: 0 },
        width,
        data: { kind: 'task', label, type: 'step', status, note },
      }))

  return fc
    .subarray(ids)
    .chain((present) =>
      fc.record({
        nodes: fc.tuple(...present.map(node)),
        links: fc.uniqueArray(
          fc.record({
            from: fc.constantFrom(...present, '?'),
            to: fc.constantFrom(...present, '?'),
            kind: fc.constantFrom('blocks', 'related'),
          }),
          { selector: ({ from, to }) => `${from}>${to}`, maxLength: 4 },
        ),
        stickerLoadout: fc.array(fc.constantFrom(null, ...STICKER_KINDS), { maxLength: 8 }),
        stickers: fc.uniqueArray(
          fc.record({
            id: fc.constantFrom(...ids.map((id) => `sticker-${id}`)),
            kind: fc.constantFrom(...STICKER_KINDS),
            x: fc.integer({ min: 0, max: 3 }),
            on: fc.option(fc.constantFrom(...present, '?'), { nil: undefined }),
          }),
          { selector: (sticker) => sticker.id, maxLength: 2 },
        ),
      }),
    )
    .map(({ nodes, links, stickers, stickerLoadout }) => {
      const present = new Set(nodes.map((node) => node.id))

      return compactDoc({
        nodes,
        links: links
          .filter(({ from, to }) => from !== to && present.has(from) && present.has(to))
          .map((link): Link => ({ id: `${link.from}>${link.to}`, ...link })),
        stickers: stickers
          .filter((sticker) => !sticker.on || present.has(sticker.on))
          .map((sticker): Sticker => ({ ...sticker, y: 0, tilt: 0 })),
        stickerLoadout,
      })
    })
}

const byId = <T extends { id: string }>(items: T[] = []) => [...items].sort((a, b) => a.id.localeCompare(b.id))

/** Documents compare ignoring the order of cards, links, and stickers. */
const normalize = (doc: Saved) => ({
  ...doc,
  nodes: byId(doc.nodes),
  links: byId(doc.links),
  stickers: byId(doc.stickers),
})

/** Problems that would leave a document the canvas can't show or save as it is. */
function findProblems(doc: Saved): string[] {
  const ids = new Set(doc.nodes.map((node) => node.id))
  const problems: string[] = []

  if (ids.size !== doc.nodes.length) problems.push('duplicate card ids')

  if (new Set(doc.links.map((link) => link.id)).size !== doc.links.length) problems.push('duplicate link ids')

  for (const link of doc.links) if (!ids.has(link.from) || !ids.has(link.to)) problems.push(`dangling link ${link.id}`)

  for (const sticker of doc.stickers ?? [])
    if (sticker.on && !ids.has(sticker.on)) problems.push(`dangling sticker ${sticker.id}`)

  if (doc.stickerLoadout?.length !== 8) problems.push('loadout is not 8 slots')

  if (!doc.nodes.every((node) => Object.values(node.data).every((value) => typeof value !== 'symbol')))
    problems.push('placeholder left in card data')

  return problems
}

/** Joins two documents with no ids in common, keeping the first one's loadout. */
const join = (first: Saved, second: Saved): Saved =>
  compactDoc({
    nodes: [...first.nodes, ...second.nodes],
    links: [...first.links, ...second.links],
    stickers: [...(first.stickers ?? []), ...(second.stickers ?? [])],
    stickerLoadout: first.stickerLoadout,
  })

const POOL = ['a', 'b', 'c', 'd']

describe('history properties', () => {
  it('undo restores the document before an edit, and redo restores the edit', () => {
    fc.assert(
      fc.property(docOf(POOL), docOf(POOL), (before, after) => {
        const undone = undo(record(emptyHistory(), { before, after }), after)!

        expect(normalize(undone.doc)).toEqual(normalize(before))

        const redone = redo(undone.history, undone.doc)!

        expect(normalize(redone.doc)).toEqual(normalize(after))
      }),
    )
  })

  it('walks back through every recorded edit and forward again', () => {
    fc.assert(
      fc.property(fc.array(docOf(POOL), { minLength: 2, maxLength: 6 }), (docs) => {
        let history: History = emptyHistory()

        for (let i = 1; i < docs.length; i++) history = record(history, { before: docs[i - 1], after: docs[i] })

        let current = docs.at(-1)!

        for (let i = docs.length - 2; i >= 0; i--) {
          ;({ history, doc: current } = undo(history, current)!)
          expect(normalize(current)).toEqual(normalize(docs[i]))
        }

        expect(undo(history, current)).toBeNull()

        for (let i = 1; i < docs.length; i++) {
          ;({ history, doc: current } = redo(history, current)!)
          expect(normalize(current)).toEqual(normalize(docs[i]))
        }

        expect(redo(history, current)).toBeNull()
      }),
    )
  })

  it('leaves a whole document whatever another writer did in between', () => {
    fc.assert(
      fc.property(fc.array(docOf(POOL), { minLength: 2, maxLength: 4 }), docOf(POOL), (docs, elsewhere) => {
        let history: History = emptyHistory()

        for (let i = 1; i < docs.length; i++) history = record(history, { before: docs[i - 1], after: docs[i] })

        let current = elsewhere

        for (let i = 1; i < docs.length; i++) {
          ;({ history, doc: current } = undo(history, current)!)
          expect(findProblems(current)).toEqual([])
        }

        for (let i = 1; i < docs.length; i++) {
          ;({ history, doc: current } = redo(history, current)!)
          expect(findProblems(current)).toEqual([])
        }
      }),
    )
  })

  it("keeps another writer's changes to cards the edit didn't touch", () => {
    const ours = ['a', 'b', 'c']
    const theirs = ['x', 'y', 'z']

    fc.assert(
      fc.property(
        docOf(ours),
        docOf(ours),
        docOf(theirs),
        docOf(theirs),
        (oursBefore, oursAfter, theirsBefore, theirsNow) => {
          const before = join(oursBefore, theirsBefore)
          const after = join(oursAfter, theirsBefore)
          const current = join(oursAfter, theirsNow)
          const undone = undo(record(emptyHistory(), { before, after }), current)!

          expect(normalize(undone.doc)).toEqual(normalize(join(oursBefore, theirsNow)))

          const redone = redo(undone.history, undone.doc)!

          expect(normalize(redone.doc)).toEqual(normalize(current))
        },
      ),
    )
  })
})
