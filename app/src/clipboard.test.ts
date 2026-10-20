import { GROUP_HEADER_HEIGHT, GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH } from './geometry'
import { describe, expect, it } from 'vitest'
import { clipAssets, copySelection, cutClip, DUPLICATE_OFFSET, moveClipAssets, pasteClip, type Clip } from './clipboard'
import { absolutePosition, byId, normalize, type AppNode, type Link } from './model'
import type { Sticker } from './sticker'
import { isAssetId } from './style'

const task = (id: string, x: number, y: number, parentId?: string, selected?: boolean): AppNode => ({
  id,
  type: 'task',
  parentId,
  selected,
  position: { x, y },
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})

const group = (id: string, x: number, y: number, parentId?: string, data: Partial<{ cover: string; background: string }> = {}): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position: { x, y },
  data: { kind: 'cluster', label: id, ...data },
})

const image = (id: string, x: number, y: number, asset: string): AppNode => ({
  id,
  type: 'image',
  position: { x, y },
  width: 256,
  height: 256,
  data: { kind: 'image', label: id, asset, workspace: 'source' },
})

const link = (from: string, to: string, kind: Link['kind'] = 'blocks'): Link => ({ id: `${from}>${to}`, from, to, kind })

const counter = () => {
  let next = 0

  return () => `new${next++}`
}

const copy = (nodes: AppNode[], links: Link[], ids: string[], stickers: Sticker[] = [], stickerIds: string[] = []) =>
  copySelection({ nodes: normalize(nodes), links, stickers }, { nodes: new Set(ids), stickers: new Set(stickerIds) }, 'source')!

describe('copying a selection', () => {
  it('keeps links between copied nodes and drops links that leave the selection', () => {
    const clip = copy(
      [task('a', 0, 0), task('b', 300, 0), task('c', 600, 0)],
      [link('a', 'b'), link('b', 'c'), link('c', 'a', 'related')],
      ['a', 'b'],
    )

    expect(clip.nodes.map((node) => node.id)).toEqual(['a', 'b'])
    expect(clip.links).toEqual([link('a', 'b')])
  })

  it('takes a group with everything inside it, at any depth', () => {
    const nodes = [group('g', 0, 0), group('inner', 40, 100, 'g'), task('a', 40, 100, 'inner'), task('b', 300, 100, 'g'), task('outside', 900, 0)]
    const clip = copy(nodes, [link('a', 'b'), link('b', 'outside')], ['g'])

    expect(clip.nodes.map((node) => node.id).sort()).toEqual(['a', 'b', 'g', 'inner'])
    expect(clip.links).toEqual([link('a', 'b')])
  })

  it('measures from the top-left of what was copied, wherever it sat', () => {
    const nodes = normalize([group('g', 100, 100), task('a', 200, 200, 'g'), task('b', 500, 400)])
    const clip = copySelection({ nodes, links: [], stickers: [] }, { nodes: new Set(['a', 'b']), stickers: new Set() }, 'source')!
    const absoluteA = absolutePosition(
      nodes.find((node) => node.id === 'a')!,
      byId(nodes),
    )

    expect(clip.bounds).toEqual({ x: absoluteA.x, y: absoluteA.y, width: 500 + TASK_WIDTH - absoluteA.x, height: 400 + TASK_HEIGHT - absoluteA.y })
    expect(clip.nodes.find((node) => node.id === 'a')).toMatchObject({ parentId: undefined, position: { x: 0, y: 0 } })
    expect(clip.parent).toBeNull()
  })

  it('remembers the group its items shared', () => {
    const clip = copy([group('g', 0, 0), task('a', 40, 100, 'g'), task('b', 300, 100, 'g')], [], ['a', 'b'])

    expect(clip.parent).toBe('g')
  })

  it('brings stickers stuck to copied nodes and picked loose ones, and loosens a picked one whose node stays', () => {
    const stickers: Sticker[] = [
      { id: 'on-a', kind: '🔥', x: 10, y: 10, tilt: 0, on: 'a' },
      { id: 'on-b', kind: '👀', x: 20, y: 20, tilt: 0, on: 'b' },
      { id: 'loose', kind: '🎉', x: 100, y: 100, tilt: 0 },
      { id: 'left', kind: '⭐', x: 900, y: 900, tilt: 0 },
    ]
    const clip = copy([task('a', 0, 0), task('b', 300, 0)], [], ['a'], stickers, ['loose', 'on-b'])

    expect(clip.stickers.map((sticker) => sticker.id)).toEqual(['on-a', 'on-b', 'loose'])
    expect(clip.stickers[0].on).toBe('a')
    expect(clip.stickers[1]).toEqual({ id: 'on-b', kind: '👀', x: 320, y: 20, tilt: 0 })
  })

  it('leaves out view state and a pending close-out', () => {
    const done: AppNode = {
      ...task('a', 0, 0, undefined, true),
      data: { kind: 'task', label: 'a', itemKind: 'step', status: 'done', celebrate: true },
    } as AppNode
    const clip = copy([done], [], ['a'])

    expect(clip.nodes[0].selected).toBeUndefined()
    expect((clip.nodes[0].data as { celebrate?: boolean }).celebrate).toBeUndefined()
  })

  it('copies nothing without a selection', () => {
    expect(copySelection({ nodes: [task('a', 0, 0)], links: [], stickers: [] }, { nodes: new Set(), stickers: new Set() }, 'source')).toBeNull()
  })
})

describe('pasting a clip', () => {
  const original = () => normalize([task('a', 0, 0), task('b', 300, 0), task('c', 600, 0)])
  const links = [link('a', 'b'), link('b', 'c')]

  it('gives every node and link a new id and keeps the links between the copies', () => {
    const nodes = original()
    const clip = copySelection({ nodes, links, stickers: [] }, { nodes: new Set(['a', 'b']), stickers: new Set() }, 'source')!
    const pasted = pasteClip({ nodes, links, stickers: [] }, clip, { at: { x: 0, y: 500 }, parent: null, makeId: counter() })
    const added = pasted.nodes.filter((node) => !['a', 'b', 'c'].includes(node.id))
    const addedIds = new Set(added.map((node) => node.id))

    expect(added).toHaveLength(2)
    expect(pasted.nodes.map((node) => node.id).filter((id) => ['a', 'b', 'c'].includes(id))).toEqual(['a', 'b', 'c'])
    expect(pasted.links).toHaveLength(3)

    const copiedLink = pasted.links[2]

    expect(addedIds.has(copiedLink.from) && addedIds.has(copiedLink.to)).toBe(true)
    expect(new Set(pasted.links.map((each) => each.id)).size).toBe(3)
  })

  it('places the copy at the point given and selects it in place of the old selection', () => {
    const nodes = original().map((node) => (node.id === 'c' ? { ...node, selected: true } : node))
    const clip = copySelection({ nodes, links, stickers: [] }, { nodes: new Set(['b', 'c']), stickers: new Set() }, 'source')!
    const pasted = pasteClip({ nodes, links, stickers: [] }, clip, { at: { x: 1000, y: 1000 }, parent: null, makeId: counter() })
    const added = pasted.nodes.filter((node) => node.id.startsWith('new'))

    expect(added.map((node) => node.position)).toEqual([
      { x: 1000, y: 1000 },
      { x: 1300, y: 1000 },
    ])
    expect(pasted.nodes.filter((node) => node.selected).map((node) => node.id)).toEqual(added.map((node) => node.id))
  })

  it('pastes into a group, relative to where the group sits', () => {
    const nodes = normalize([group('g', 0, 0), task('inside', 100, 100, 'g'), task('a', 900, 900)])
    const clip = copySelection({ nodes, links: [], stickers: [] }, { nodes: new Set(['a']), stickers: new Set() }, 'source')!
    const groupNode = nodes.find((node) => node.id === 'g')!
    const at = { x: groupNode.position.x + GROUP_PADDING + 300, y: groupNode.position.y + GROUP_HEADER_HEIGHT }
    const pasted = pasteClip({ nodes, links: [], stickers: [] }, clip, { at, parent: 'g', makeId: counter() })
    const copyNode = pasted.nodes.find((node) => node.id === 'new0')!

    expect(copyNode.parentId).toBe('g')
    expect(absolutePosition(copyNode, byId(pasted.nodes))).toEqual(at)
  })

  it('rebuilds a copied group with its nesting under the new ids', () => {
    const nodes = normalize([group('g', 0, 0), group('inner', 40, 100, 'g'), task('a', 40, 100, 'inner')])
    const clip = copySelection({ nodes, links: [], stickers: [] }, { nodes: new Set(['g']), stickers: new Set() }, 'source')!
    const pasted = pasteClip({ nodes, links: [], stickers: [] }, clip, { at: { x: 2000, y: 0 }, parent: null, makeId: counter() })
    const nodeMap = byId(pasted.nodes)
    const copiedTask = pasted.nodes.find((node) => node.type === 'task' && node.id.startsWith('new'))!
    const copiedInner = nodeMap.get(copiedTask.parentId!)!

    expect(copiedInner.id).not.toBe('inner')
    expect(nodeMap.get(copiedInner.parentId!)?.id).toMatch(/^new/)
    expect(nodeMap.get('a')?.parentId).toBe('inner')
  })

  it('pastes the same clip again under different ids', () => {
    const nodes = original()
    const clip = copySelection({ nodes, links, stickers: [] }, { nodes: new Set(['a', 'b']), stickers: new Set() }, 'source')!
    const makeId = counter()
    const first = pasteClip({ nodes, links, stickers: [] }, clip, { at: { x: 0, y: 500 }, parent: null, makeId })
    const second = pasteClip(first, clip, { at: { x: 0, y: 900 }, parent: null, makeId })

    expect(new Set(second.nodes.map((node) => node.id)).size).toBe(7)
    expect(new Set(second.links.map((each) => each.id)).size).toBe(4)
  })

  it('draws again when a new id is already taken', () => {
    const nodes = original()
    const clip = copySelection({ nodes, links: [], stickers: [] }, { nodes: new Set(['a']), stickers: new Set() }, 'source')!
    const ids = ['a', 'b', 'fresh']
    const pasted = pasteClip({ nodes, links: [], stickers: [] }, clip, { at: { x: 0, y: 500 }, parent: null, makeId: () => ids.shift()! })

    expect(pasted.nodes.map((node) => node.id)).toEqual(['a', 'b', 'c', 'fresh'])
  })

  it('carries stickers onto the copies and places loose ones from the point given', () => {
    const nodes = original()
    const stickers: Sticker[] = [
      { id: 'on-a', kind: '🔥', x: 10, y: 10, tilt: 0, on: 'a' },
      { id: 'loose', kind: '🎉', x: 100, y: 100, tilt: 3 },
    ]
    const clip = copySelection({ nodes, links: [], stickers }, { nodes: new Set(['a']), stickers: new Set(['loose']) }, 'source')!
    const pasted = pasteClip({ nodes, links: [], stickers }, clip, { at: { x: 0, y: 500 }, parent: null, makeId: counter() })
    const [onCopy, looseCopy] = pasted.stickers.slice(2)

    expect(onCopy).toMatchObject({ on: 'new0', x: 10, y: 10 })
    expect(looseCopy).toEqual({ id: looseCopy.id, kind: '🎉', tilt: 3, x: 100, y: 600 })
    expect(pasted.stickerIds).toEqual([onCopy.id, looseCopy.id])
  })
})

describe('cutting a clip', () => {
  it('removes the copied nodes, every link that touched them, and their stickers', () => {
    const nodes = normalize([task('a', 0, 0), task('b', 300, 0), task('c', 600, 0)])
    const links = [link('a', 'b'), link('b', 'c')]
    const stickers: Sticker[] = [
      { id: 'on-b', kind: '🔥', x: 0, y: 0, tilt: 0, on: 'b' },
      { id: 'on-c', kind: '👀', x: 0, y: 0, tilt: 0, on: 'c' },
    ]
    const clip = copySelection({ nodes, links, stickers }, { nodes: new Set(['b']), stickers: new Set() }, 'source')!
    const cut = cutClip({ nodes, links, stickers }, clip)

    expect(cut.nodes.map((node) => node.id)).toEqual(['a', 'c'])
    expect(cut.links).toEqual([])
    expect(cut.stickers.map((sticker) => sticker.id)).toEqual(['on-c'])
  })

  it('takes a group with its contents, and pasting the cut brings it all back', () => {
    const nodes = normalize([group('g', 0, 0), task('a', 40, 100, 'g'), task('b', 300, 100, 'g'), task('outside', 900, 0)])
    const links = [link('a', 'b'), link('b', 'outside')]
    const clip = copySelection({ nodes, links, stickers: [] }, { nodes: new Set(['g']), stickers: new Set() }, 'source')!
    const cut = cutClip({ nodes, links, stickers: [] }, clip)

    expect(cut.nodes.map((node) => node.id)).toEqual(['outside'])

    const pasted = pasteClip(cut, clip, { at: { x: 0, y: 0 }, parent: null, makeId: counter() })

    expect(pasted.nodes).toHaveLength(4)
    expect(pasted.links).toHaveLength(1)
  })
})

describe('duplicating', () => {
  it('lands the copy offset from the original, in the group they share', () => {
    const nodes = normalize([group('g', 0, 0), task('a', 40, 100, 'g')])
    const clip = copySelection({ nodes, links: [], stickers: [] }, { nodes: new Set(['a']), stickers: new Set() }, 'source')!
    const pasted = pasteClip({ nodes, links: [], stickers: [] }, clip, {
      at: { x: clip.bounds.x + DUPLICATE_OFFSET, y: clip.bounds.y + DUPLICATE_OFFSET },
      parent: clip.parent,
      makeId: counter(),
    })
    const nodeMap = byId(pasted.nodes)
    const before = absolutePosition(nodeMap.get('a')!, nodeMap)
    const after = absolutePosition(nodeMap.get('new0')!, nodeMap)

    expect(nodeMap.get('new0')?.parentId).toBe('g')
    expect({ x: after.x - before.x, y: after.y - before.y }).toEqual({ x: DUPLICATE_OFFSET, y: DUPLICATE_OFFSET })
  })
})

describe('moving a clip to another workspace', () => {
  const asset = 'abc123.png'
  const cover = 'def456.webp'

  const clipWith = (): Clip =>
    copy(
      [image('picture', 0, 0, asset), group('g', 400, 0, undefined, { cover, background: '#ff0000' }), task('inside', 440, 100, 'g')],
      [],
      ['picture', 'g'],
    )

  it('lists the assets its images and group covers use', () => {
    expect(clipAssets(clipWith(), isAssetId).sort()).toEqual([asset, cover].sort())
  })

  it('points images and covers at the copied assets and leaves colors alone', () => {
    const moved = moveClipAssets(clipWith(), 'target', new Map([[asset, 'fed789.png']]))
    const picture = moved.nodes.find((node) => node.id === 'picture')!
    const groupNode = moved.nodes.find((node) => node.id === 'g')!

    expect(picture.data).toMatchObject({ asset: 'fed789.png', workspace: 'target' })
    expect(groupNode.data).toMatchObject({ cover, background: '#ff0000' })
  })

  it('keeps an image showing from its own workspace when its asset could not be copied', () => {
    const moved = moveClipAssets(clipWith(), 'target', new Map())

    expect(moved.nodes.find((node) => node.id === 'picture')!.data).toMatchObject({ asset, workspace: 'source' })
  })
})
