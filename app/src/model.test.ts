import { GAP, GROUP_HEADER_HEIGHT, GROUP_PADDING, TASK_HEIGHT, TASK_WIDTH } from './geometry'
import { describe, expect, it } from 'vitest'
import { reparent } from './escape'
import {
  absolutePosition,
  byId,
  editPullRef,
  getCheckCounts,
  getCheckCountsLabel,
  getItemKind,
  getPrimaryRef,
  getPullRef,
  getPullRequestNumber,
  getRefSummary,
  getTaskTag,
  getTaskUrl,
  normalize,
  pruneEmptied,
  removeNodes,
  sizeOf,
  survivingRoot,
  tintOf,
  type AppNode,
  type ClusterData,
  type TaskData,
} from './model'
import { moveOutOfGroup, ungroup } from './layout'

const task = (overrides: Partial<TaskData> = {}): TaskData => ({
  kind: 'task',
  label: 'Work',
  itemKind: 'step',
  status: 'todo',
  ...overrides,
})

describe('source refs', () => {
  it('uses the first linked ref for the tag and URL', () => {
    const data = task({
      repo: 'vocksel/orion',
      refs: [
        { source: 'hop', kind: 'branch', key: 'vocksel/orion@work' },
        { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' },
      ],
    })

    expect(getPrimaryRef(data)).toBe(data.refs?.[1])
    expect(getTaskTag(data)).toBe('ORN-12')
    expect(getTaskUrl(data)).toBe('https://jira.example.com/browse/ORN-12')
  })

  it('falls back to the first ref, repository, and kind', () => {
    const unlinked = task({ refs: [{ source: 'hop', kind: 'branch', key: 'vocksel/orion@work' }] })

    expect(getTaskTag(unlinked)).toBe('vocksel/orion@work')
    expect(getTaskUrl(unlinked)).toBeNull()
    expect(getTaskTag(task({ repo: 'vocksel/orion' }))).toBe('vocksel/orion')
    expect(getTaskTag(task({ itemKind: 'gate' }))).toBe('gate')
    expect(getTaskTag(task())).toBe('step')
  })

  it('finds a pull ref and parses its number', () => {
    const data = task({
      refs: [
        { source: 'jira', kind: 'issue', key: 'ORN-12' },
        { source: 'github', kind: 'pull', key: 'github.example.com/Vocksel/Orion#42' },
      ],
    })

    expect(getPullRef(data)).toBe(data.refs?.[1])
    expect(getPullRequestNumber(getPullRef(data))).toBe(42)
    expect(getPullRequestNumber(data.refs?.[0])).toBeUndefined()
    expect(getPullRequestNumber({ source: 'github', kind: 'pull', key: 'vocksel/orion#bad' })).toBeUndefined()
    expect(getItemKind(data)).toBe('pr')
    expect(getItemKind(task({ repo: 'vocksel/orion' }))).toBe('placeholder')
    expect(getItemKind(task({ itemKind: 'gate', refs: data.refs }))).toBe('gate')
  })
})

describe('editPullRef', () => {
  const issue = { source: 'jira', kind: 'issue', key: 'ORN-12', url: 'https://jira.example.com/browse/ORN-12' }

  it('adds a pull first and replaces the previous pull', () => {
    const data = task({ repo: 'vocksel/orion', refs: [issue, { source: 'github', kind: 'pull', key: 'vocksel/orion#41' }] })

    expect(editPullRef(data, 'vocksel/orion', 42)).toEqual({
      repo: 'vocksel/orion',
      itemKind: 'pr',
      refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42', url: 'https://github.com/vocksel/orion/pull/42' }, issue],
    })
  })

  it('rewrites the pull on repository change and preserves the typed repository', () => {
    const data = task({ repo: 'vocksel/orion', refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42' }, issue] })

    expect(editPullRef(data, 'Vocksel/Other ', 42)).toEqual({
      repo: 'Vocksel/Other ',
      itemKind: 'pr',
      refs: [{ source: 'github', kind: 'pull', key: 'Vocksel/Other#42', url: 'https://github.com/Vocksel/Other/pull/42' }, issue],
    })
  })

  it('preserves synced pull details when the key is unchanged ignoring case', () => {
    const existingPullRef = {
      source: 'gh-vocksel',
      kind: 'pull',
      key: 'Vocksel/Orion#42',
      url: 'https://github.example.com/Vocksel/Orion/pull/42',
      status: 'open',
      isDone: false,
      updatedAt: '2026-10-08T12:00:00Z',
      details: { checks: 'SUCCESS', branch: 'feature' },
    }
    const data = task({ repo: 'Vocksel/Orion', refs: [issue, existingPullRef] })
    const edited = editPullRef(data, 'vocksel/orion ', 42)

    expect(edited.repo).toBe('vocksel/orion ')
    expect(edited.refs?.[0]).toBe(existingPullRef)
    expect(edited.refs).toEqual([existingPullRef, issue])
    expect(edited.itemKind).toBe('pr')
  })

  it('clears the pull when the number or repository is cleared', () => {
    const data = task({ repo: 'vocksel/orion', refs: [{ source: 'github', kind: 'pull', key: 'vocksel/orion#42' }, issue] })

    expect(editPullRef(data, 'vocksel/orion', undefined)).toEqual({ repo: 'vocksel/orion', refs: [issue], itemKind: 'placeholder' })
    expect(editPullRef(data, undefined, 42)).toEqual({ repo: undefined, refs: [issue], itemKind: 'step' })
    expect(editPullRef(task(), undefined, undefined)).toEqual({ repo: undefined, refs: undefined, itemKind: 'step' })
  })
})

describe('tintOf', () => {
  const group = (id: string, color?: 'teal' | 'rose', parentId?: string): AppNode => ({
    id,
    type: 'cluster',
    parentId,
    position: { x: 0, y: 0 },
    data: { kind: 'cluster', label: id, color },
  })
  const card = (id: string, data: Partial<TaskData>): AppNode => ({
    id,
    type: 'task',
    parentId: 'inner',
    position: { x: 0, y: 0 },
    data: { kind: 'task', label: id, itemKind: 'component', status: 'todo', ...data },
  })
  const nodes = [
    group('outer', 'teal'),
    group('inner', undefined, 'outer'),
    card('plain', {}),
    card('own', { color: 'rose' }),
    card('work', { itemKind: 'step' }),
  ]
  const nodeMap = byId(nodes)

  it("takes a component's own tint, or else its nearest tinted group's", () => {
    expect(tintOf(nodeMap.get('own')!, nodeMap)).toBe('rose')
    expect(tintOf(nodeMap.get('plain')!, nodeMap)).toBe('teal')
    expect(tintOf(nodeMap.get('inner')!, nodeMap)).toBe('teal')
  })

  it('never tints work', () => {
    expect(tintOf(nodeMap.get('work')!, nodeMap)).toBeUndefined()
  })
})

describe('getRefSummary', () => {
  const ref = { source: 'github', kind: 'pull', key: 'vocksel/orion#1' }

  it('names the state its adapter read and when it read it', () => {
    const now = Date.parse('2026-10-08T14:00:00Z')

    expect(getRefSummary({ ...ref, stateLabel: 'Merged on GitHub', checkedAt: '2026-10-08T12:00:00Z' }, now)).toBe(
      'Merged on GitHub · checked 2h ago',
    )
    expect(getRefSummary({ ...ref, stateLabel: 'Open on GitHub' }, now)).toBe('Open on GitHub')
    expect(getRefSummary(ref, now)).toBeUndefined()
  })
})

describe('getCheckCounts', () => {
  it('returns counts only when the source reported all three', () => {
    expect(getCheckCounts({ state: 'pending', total: 8, finished: 5, failed: 0 })).toEqual({ total: 8, finished: 5, failed: 0 })
    expect(getCheckCounts({ state: 'pending', total: 8 })).toBeUndefined()
    expect(getCheckCounts(undefined)).toBeUndefined()
  })
})

describe('getCheckCountsLabel', () => {
  it('counts finished checks while the rest run, with any failures', () => {
    expect(getCheckCountsLabel({ total: 8, finished: 5, failed: 0 })).toBe('5 of 8 done')
    expect(getCheckCountsLabel({ total: 8, finished: 5, failed: 1 })).toBe('5 of 8 done, 1 failed')
  })

  it('counts only failures once every check finishes', () => {
    expect(getCheckCountsLabel({ total: 8, finished: 8, failed: 2 })).toBe('2 of 8 failed')
    expect(getCheckCountsLabel({ total: 8, finished: 8, failed: 0 })).toBeUndefined()
  })
})

const groupNode = (id: string, parentId?: string, position = { x: 0, y: 0 }): AppNode => ({
  id,
  type: 'cluster',
  parentId,
  position,
  width: 320,
  height: 200,
  data: { kind: 'cluster', label: id },
})

const cardNode = (id: string, parentId?: string, position = { x: 0, y: 0 }): AppNode => ({
  id,
  type: 'task',
  parentId,
  position,
  data: { kind: 'task', label: id, itemKind: 'step', status: 'todo' },
})

const rectOf = (nodes: AppNode[], id: string) => {
  const nodeMap = byId(nodes)
  const node = nodeMap.get(id)!
  const position = absolutePosition(node, nodeMap)
  const size = sizeOf(node)

  return { x: position.x, y: position.y, width: size.width, height: size.height }
}

const overlaps = (first: ReturnType<typeof rectOf>, second: ReturnType<typeof rectOf>) =>
  first.x < second.x + second.width && second.x < first.x + first.width && first.y < second.y + second.height && second.y < first.y + first.height

describe('moveOutOfGroup', () => {
  const nested = () =>
    normalize([groupNode('outer'), cardNode('keep', 'outer'), groupNode('inner', 'outer', { x: 300, y: 0 }), cardNode('deep', 'inner')])

  it('lifts a nested group to its parent level and leaves it where it was', () => {
    const before = nested()
    const after = moveOutOfGroup(before, 'inner')

    expect(byId(after).get('inner')?.parentId).toBeUndefined()
    expect(rectOf(after, 'inner')).toEqual(rectOf(before, 'inner'))
    expect(rectOf(after, 'deep')).toEqual(rectOf(before, 'deep'))
    expect(rectOf(after, 'keep')).toEqual(rectOf(before, 'keep'))
  })

  it('lifts a group to the grandparent when the parent is nested too', () => {
    const before = normalize([
      groupNode('top'),
      groupNode('middle', 'top'),
      cardNode('keep', 'middle'),
      groupNode('inner', 'middle', { x: 300, y: 0 }),
      cardNode('deep', 'inner'),
    ])
    const after = moveOutOfGroup(before, 'inner')

    expect(byId(after).get('inner')?.parentId).toBe('top')
    expect(rectOf(after, 'inner')).toEqual(rectOf(before, 'inner'))
  })

  it('lands below a card that covers where the group was', () => {
    const base = nested()
    const spot = rectOf(base, 'inner')
    const blocked = normalize([...base, cardNode('blocker', undefined, { x: spot.x, y: spot.y })])
    const after = moveOutOfGroup(blocked, 'inner')
    const landed = rectOf(after, 'inner')

    expect(overlaps(landed, rectOf(after, 'blocker'))).toBe(false)
    expect(overlaps(landed, rectOf(after, 'outer'))).toBe(false)
    expect(landed.y).toBe(spot.y + TASK_HEIGHT + GAP.top.component)
  })

  it('returns the nodes unchanged for a card, a top-level group, or a missing id', () => {
    const base = nested()

    expect(moveOutOfGroup(base, 'keep')).toBe(base)
    expect(moveOutOfGroup(base, 'outer')).toBe(base)
    expect(moveOutOfGroup(base, 'missing')).toBe(base)
  })
})

describe('survivingRoot', () => {
  const nested = () =>
    normalize([
      groupNode('top'),
      cardNode('keep', 'top'),
      groupNode('middle', 'top', { x: 300, y: 0 }),
      groupNode('inner', 'middle'),
      cardNode('deep', 'inner'),
    ])

  it('keeps the open group while it is still there', () => {
    const before = nested()

    expect(survivingRoot('inner', byId(before), byId(before))).toBe('inner')
  })

  it('opens the parent when moving a group out empties the open group', () => {
    const before = nested()
    const after = moveOutOfGroup(before, 'inner')

    expect(byId(after).has('middle')).toBe(false)
    expect(survivingRoot('middle', byId(before), byId(after))).toBe('top')
  })

  it('skips ancestors that went with it', () => {
    const before = nested()
    const after = removeNodes(before, ['middle', 'inner', 'deep'])

    expect(survivingRoot('inner', byId(before), byId(after))).toBe('top')
  })

  it('falls back to the top level when nothing above survives', () => {
    const before = nested()

    expect(survivingRoot('middle', byId(before), byId(ungroup(before, ['top', 'middle'])))).toBeNull()
    expect(survivingRoot('missing', byId(before), byId(before))).toBeNull()
  })
})

describe('empty groups', () => {
  it('keeps a group with nothing inside, at the size of one card, where it was', () => {
    const [group] = normalize([groupNode('kept', undefined, { x: 40, y: 80 })])

    expect(group.id).toBe('kept')
    expect(group.position).toEqual({ x: 40, y: 80 })
    expect(group.width).toBe(TASK_WIDTH + GROUP_PADDING * 2)
    expect(group.height).toBe(TASK_HEIGHT + GROUP_HEADER_HEIGHT + GROUP_PADDING)
  })

  it('leaves a group that was already empty alone', () => {
    const before = normalize([groupNode('kept'), groupNode('other'), cardNode('card', 'other')])
    const after = normalize([...before.filter((node) => node.id !== 'card'), cardNode('card')])

    expect(byId(pruneEmptied(before, after)).has('kept')).toBe(true)
  })

  it('removes a group the edit took its last card out of, and returns the same nodes when nothing emptied', () => {
    const before = normalize([groupNode('work'), cardNode('card', 'work')])
    const after = normalize([groupNode('work'), cardNode('card')])
    const pruned = pruneEmptied(before, after)

    expect(byId(pruned).has('work')).toBe(false)
    expect(byId(pruned).has('card')).toBe(true)

    const steady = normalize([groupNode('work'), cardNode('card', 'work')])

    expect(pruneEmptied(steady, steady)).toBe(steady)
  })

  it('removes a group the edit emptied and then the group holding it when that is empty too', () => {
    const before = normalize([groupNode('outer'), groupNode('inner', 'outer'), cardNode('card', 'inner')])
    const after = normalize([groupNode('outer'), groupNode('inner', 'outer'), cardNode('card')])
    const pruned = byId(pruneEmptied(before, after))

    expect(pruned.has('inner')).toBe(false)
    expect(pruned.has('outer')).toBe(false)
    expect(pruned.has('card')).toBe(true)
  })

  it('drops a group when its last card is removed, and keeps it while cards remain', () => {
    const base = normalize([groupNode('work'), cardNode('one', 'work'), cardNode('two', 'work')])

    expect(byId(removeNodes(base, ['one'])).has('work')).toBe(true)

    const emptied = removeNodes(removeNodes(base, ['one']), ['two'])

    expect(byId(emptied).has('work')).toBe(false)
  })

  it('drops a group whose last card is dropped somewhere else, and keeps one the card goes back into', () => {
    const before = normalize([groupNode('work'), cardNode('card', 'work'), groupNode('other')])
    const elsewhere = normalize(reparent(before, ['card'], 'other', 'work'))

    expect(byId(pruneEmptied(before, elsewhere)).has('work')).toBe(false)

    const back = normalize(reparent(before, ['card'], 'work', 'work'))

    expect(byId(pruneEmptied(before, back)).has('work')).toBe(true)
  })

  it('drops the group a moved group leaves empty', () => {
    const before = normalize([groupNode('outer'), groupNode('solo', 'outer'), cardNode('card', 'solo'), groupNode('empty')])
    const after = moveOutOfGroup(before, 'solo')

    expect(byId(after).has('outer')).toBe(false)
    expect(byId(after).get('solo')?.parentId).toBeUndefined()
    expect(byId(after).has('empty')).toBe(true)
  })

  it('drops the group that ungrouping leaves empty', () => {
    const before = normalize([groupNode('outer'), groupNode('inner', 'outer'), groupNode('kept')])
    const after = ungroup(before, ['inner'])

    expect(byId(after).has('inner')).toBe(false)
    expect(byId(after).has('outer')).toBe(false)
    expect(byId(after).has('kept')).toBe(true)
  })
})

describe('normalize with a group size', () => {
  const sized = (arrange: 'auto' | 'custom'): AppNode => ({
    id: 'g',
    type: 'cluster',
    position: { x: 100, y: 100 },
    data: { kind: 'cluster', label: 'g', arrange, size: { width: 800, height: 500 } },
  })

  it('keeps a custom group at least its size, with its corner where it was', () => {
    const group = byId(normalize([sized('custom'), cardNode('card', 'g', { x: 32, y: 78 })])).get('g')!

    expect(group.position).toEqual({ x: 100, y: 100 })
    expect({ width: group.width, height: group.height }).toEqual({ width: 800, height: 500 })
  })

  it('grows a custom group past its size to hold its contents, and remembers the new size', () => {
    const card = { ...cardNode('card', 'g'), position: { x: -40, y: 600 } }
    const nodes = normalize([sized('custom'), card])
    const group = byId(nodes).get('g')!

    expect(group.position.x).toBe(100 - 40 - 32)
    expect(group.width).toBe(800 + 40 + 32)
    expect((group.data as ClusterData).size).toEqual({ width: group.width, height: group.height })
    expect(normalize(nodes)).toEqual(nodes)
  })

  it('lets an automatic group hug its contents', () => {
    const group = byId(normalize([sized('auto'), cardNode('card', 'g')])).get('g')!

    expect(group.width).toBeLessThan(800)
  })
})
