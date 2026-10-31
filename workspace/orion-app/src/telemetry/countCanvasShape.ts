import { type AppNode, isCluster, isImage, isNote, isWork, type Link } from '../model'
import type { Sticker } from '../sticker'

/** A canvas's size as `canvas_measured` reports it: counts only, never what the cards say. */
export type CanvasShape = {
  card_count: number
  group_count: number
  nesting_depth: number
  link_count: number
  note_count: number
  media_count: number
  sticker_count: number
}

/**
 * Counts a canvas's cards, groups, and the rest. Cards are work items, so notes and components don't count as cards.
 * Links are the dependencies between cards, and nesting depth is the most groups inside one another.
 */
export function countCanvasShape(
  nodes: readonly AppNode[],
  links: readonly Link[],
  depth: ReadonlyMap<string, number>,
  stickers: readonly Sticker[],
): CanvasShape {
  let cards = 0
  let groups = 0
  let notes = 0
  let media = 0
  let nesting = 0

  for (const node of nodes) {
    if (isWork(node)) cards++
    else if (isNote(node)) notes++
    else if (isImage(node)) media++
    else if (isCluster(node)) {
      groups++
      nesting = Math.max(nesting, (depth.get(node.id) ?? 0) + 1)
    }
  }

  return {
    card_count: cards,
    group_count: groups,
    nesting_depth: nesting,
    link_count: links.filter((link) => link.kind === 'blocks').length,
    note_count: notes,
    media_count: media,
    sticker_count: stickers.length,
  }
}
