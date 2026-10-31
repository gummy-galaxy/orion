import { TASK_HEIGHT, TASK_WIDTH } from './geometry'
import type { CardSize } from './cardSize'
import { descendants } from './hierarchy/descendants'
import { indexNodes } from './hierarchy/indexNodes'
import {
  absolutePosition,
  ancestors,
  byId,
  isCluster,
  isImage,
  isTask,
  normalize,
  sizeOf,
  type AppNode,
  type Link,
} from './model'
import { pushAside } from './pushAside'
import { STICKER_HALF_SIZE, type Sticker } from './sticker'

/** How far a duplicate lands from what it copies, right and down, so both stay in sight. */
export const DUPLICATE_OFFSET = 24

/**
 * A copied selection, kept apart from the canvas it came from so it can be pasted into any group or workspace. Its
 * top-level nodes and loose stickers sit relative to the top-left of what was copied, and everything keeps the ids it
 * had, which a paste replaces.
 */
export type Clip = {
  /** The workspace it came from, which holds its images and group covers. */
  workspace: string
  nodes: AppNode[]
  /** Only links between copied nodes. */
  links: Link[]
  stickers: Sticker[]
  /** Where the copied area was on the canvas, and its size. */
  bounds: { x: number; y: number; width: number; height: number }
  /** The group the copied nodes shared, or null at the top level. */
  parent: string | null
}

type Doc = { nodes: AppNode[]; links: Link[]; stickers: Sticker[] }

/** A pasted copy's place in the document, with its new top-level nodes selected and its stickers listed to pick. */
export type Pasted = Doc & { stickerIds: string[] }

const DEFAULT_CARD_SIZE: CardSize = { width: TASK_WIDTH, height: TASK_HEIGHT }

/** What a node keeps when copied: its stored fields, without view state. */
function stored(node: AppNode, overrides: Partial<AppNode>): AppNode {
  return {
    id: node.id,
    type: node.type,
    position: node.position,
    parentId: node.parentId,
    data: node.data,
    ...(isTask(node) ? {} : { width: node.width, height: node.height }),
    ...overrides,
  } as AppNode
}

/**
 * Copies the selected nodes with everything inside them, the links between them, and the picked stickers along with
 * any stuck to a copied node. A picked sticker on a node left behind comes along loose. Returns null when nothing is
 * selected.
 */
export function copySelection(
  doc: Doc,
  selection: { nodes: ReadonlySet<string>; stickers: ReadonlySet<string> },
  workspace: string,
  cardSize: CardSize = DEFAULT_CARD_SIZE,
): Clip | null {
  const { byId: nodeMap, children } = indexNodes(doc.nodes)
  const roots = doc.nodes.filter(
    (node) =>
      selection.nodes.has(node.id) && !ancestors(node.id, nodeMap).some((ancestor) => selection.nodes.has(ancestor)),
  )
  const copied = new Set(roots.flatMap((node) => [node.id, ...descendants(node.id, children)]))
  const stickers = doc.stickers
    .filter((sticker) => selection.stickers.has(sticker.id) || (sticker.on && copied.has(sticker.on)))
    .map((sticker): Sticker => {
      if (!sticker.on || copied.has(sticker.on)) return sticker

      const node = nodeMap.get(sticker.on)
      const origin = node ? absolutePosition(node, nodeMap) : { x: 0, y: 0 }

      return {
        id: sticker.id,
        kind: sticker.kind,
        tilt: sticker.tilt,
        x: origin.x + sticker.x,
        y: origin.y + sticker.y,
      }
    })

  if (!roots.length && !stickers.length) return null

  const boxes = [
    ...roots.map((node) => ({ ...absolutePosition(node, nodeMap), ...sizeOf(node, cardSize) })),
    ...stickers
      .filter((sticker) => !sticker.on)
      .map((sticker) => ({
        x: sticker.x - STICKER_HALF_SIZE,
        y: sticker.y - STICKER_HALF_SIZE,
        width: STICKER_HALF_SIZE * 2,
        height: STICKER_HALF_SIZE * 2,
      })),
  ]
  const x = Math.min(...boxes.map((box) => box.x))
  const y = Math.min(...boxes.map((box) => box.y))
  const width = Math.max(...boxes.map((box) => box.x + box.width)) - x
  const height = Math.max(...boxes.map((box) => box.y + box.height)) - y
  const rootIds = new Set(roots.map((node) => node.id))
  const chains = roots.map((node) => ancestors(node.id, nodeMap))
  const parent = chains[0]?.find((ancestor) => chains.every((chain) => chain.includes(ancestor))) ?? null

  return {
    workspace,
    nodes: doc.nodes
      .filter((node) => copied.has(node.id))
      .map((node) => {
        if (!rootIds.has(node.id)) return stored(node, {})

        const position = absolutePosition(node, nodeMap)

        return stored(node, { parentId: undefined, position: { x: position.x - x, y: position.y - y } })
      }),
    links: doc.links.filter((link) => copied.has(link.from) && copied.has(link.to)),
    stickers: stickers.map((sticker) => (sticker.on ? sticker : { ...sticker, x: sticker.x - x, y: sticker.y - y })),
    bounds: { x, y, width, height },
    parent,
  }
}

/**
 * Places a fresh copy of a clip with its top-left at `at`, in canvas coordinates, inside `parent` or at the top level.
 * Every node, link, and sticker gets a new id that nothing in the document uses, so a clip pastes as many times as
 * you like. The pasted top-level nodes are selected in place of whatever was, and a group that grows to hold them
 * moves its neighbors aside.
 */
export function pasteClip(
  doc: Doc,
  clip: Clip,
  options: { at: { x: number; y: number }; parent: string | null; makeId: () => string; cardSize?: CardSize },
): Pasted {
  const cardSize = options.cardSize ?? DEFAULT_CARD_SIZE
  const nodeMap = byId(doc.nodes)
  const taken = new Set([
    ...doc.nodes.map((node) => node.id),
    ...doc.links.map((link) => link.id),
    ...doc.stickers.map((sticker) => sticker.id),
  ])

  const freshId = () => {
    let id = options.makeId()

    while (taken.has(id)) id = options.makeId()

    taken.add(id)

    return id
  }

  const ids = new Map(clip.nodes.map((node) => [node.id, freshId()]))
  const parentNode = options.parent ? nodeMap.get(options.parent) : undefined
  const origin = parentNode ? absolutePosition(parentNode, nodeMap) : { x: 0, y: 0 }
  const pasted = clip.nodes.map((node): AppNode => {
    const id = ids.get(node.id)!

    if (node.parentId) return { ...node, id, parentId: ids.get(node.parentId), selected: false }

    return {
      ...node,
      id,
      parentId: parentNode?.id,
      position: { x: options.at.x + node.position.x - origin.x, y: options.at.y + node.position.y - origin.y },
      selected: true,
    }
  })
  const links = clip.links.map((link): Link => {
    const from = ids.get(link.from)!
    const to = ids.get(link.to)!

    return { ...link, id: freshId(), from, to }
  })
  const stickers = clip.stickers.map((sticker): Sticker =>
    sticker.on
      ? { ...sticker, id: freshId(), on: ids.get(sticker.on) }
      : { ...sticker, id: freshId(), x: options.at.x + sticker.x, y: options.at.y + sticker.y },
  )
  const nodes = pushAside(
    doc.nodes,
    normalize([...doc.nodes.map((node) => (node.selected ? { ...node, selected: false } : node)), ...pasted], cardSize),
    cardSize,
  )

  return {
    nodes,
    links: [...doc.links, ...links],
    stickers: [...doc.stickers, ...stickers],
    stickerIds: stickers.map((sticker) => sticker.id),
  }
}

/**
 * Takes what a clip copied out of the document it came from, with every link that touched it. A group left empty
 * goes too, as it does whenever its last item leaves.
 */
export function cutClip(doc: Doc, clip: Clip, cardSize: CardSize = DEFAULT_CARD_SIZE): Doc {
  const nodeIds = new Set(clip.nodes.map((node) => node.id))
  const stickerIds = new Set(clip.stickers.map((sticker) => sticker.id))

  return {
    nodes: normalize(
      doc.nodes.filter((node) => !nodeIds.has(node.id)),
      cardSize,
    ),
    links: doc.links.filter((link) => !nodeIds.has(link.from) && !nodeIds.has(link.to)),
    stickers: doc.stickers.filter((sticker) => !stickerIds.has(sticker.id)),
  }
}

/**
 * Points a clip's images and group covers and backgrounds at copies of their assets in another workspace. Assets
 * missing from `copied` stay as they were, so an image keeps showing from the workspace it came from.
 */
export function moveClipAssets(clip: Clip, workspace: string, copied: ReadonlyMap<string, string>): Clip {
  const asset = (id: string | undefined) => (id && copied.get(id)) ?? id

  return {
    ...clip,
    workspace,
    nodes: clip.nodes.map((node): AppNode => {
      if (isImage(node))
        return copied.has(node.data.asset)
          ? { ...node, data: { ...node.data, asset: copied.get(node.data.asset)!, canvas: workspace } }
          : node

      if (isCluster(node) && (copied.has(node.data.cover ?? '') || copied.has(node.data.background ?? '')))
        return {
          ...node,
          data: { ...node.data, cover: asset(node.data.cover), background: asset(node.data.background) },
        }

      return node
    }),
  }
}

/**
 * The asset ids a clip's images and group covers and backgrounds use, which a paste into another workspace copies over.
 */
export function clipAssets(clip: Clip, isAsset: (value: string | undefined) => boolean): string[] {
  const assets = clip.nodes.flatMap((node) => {
    if (isImage(node)) return [node.data.asset]

    if (isCluster(node))
      return [node.data.cover, node.data.background].filter((value): value is string => isAsset(value))

    return []
  })

  return [...new Set(assets)]
}
