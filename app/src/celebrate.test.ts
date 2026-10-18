import { describe, expect, it } from 'vitest'
import { CHAIN_STEP_MS, celebrationDelays, clearCelebrations, closesOut, finishedHops, patchTaskData } from './celebrate'
import { isTask, type AppNode, type ItemKind, type Link, type Status, type TaskData, type TaskNode } from './model'

const task = (id: string, status: Status = 'todo', extra: Partial<TaskData> = {}, itemKind: ItemKind = 'step'): AppNode => ({
  id,
  type: 'task',
  position: { x: 0, y: 0 },
  data: { kind: 'task', label: id, itemKind, status, ...extra },
})
const link = (from: string, to: string, kind: Link['kind'] = 'blocks'): Link => ({ id: `${from}>${to}`, from, to, kind })

// Notes take their status from the server, so a test names the notes it treats as done.
const finished =
  (nodes: AppNode[], doneNotes: string[] = []) =>
  (id: string) =>
    doneNotes.includes(id) || nodes.some((node) => node.id === id && isTask(node) && node.data.itemKind !== 'note' && node.data.status === 'done')

describe('finishedHops', () => {
  it('walks upstream and downstream through finished cards only', () => {
    const nodes = [task('up', 'done'), task('start', 'done'), task('down', 'done'), task('open', 'active')]
    const links = [link('up', 'start'), link('start', 'down'), link('down', 'open')]

    const hops = finishedHops('start', links, finished(nodes))

    expect([...hops]).toEqual([
      ['start', 0],
      ['up', 1],
      ['down', 1],
    ])
  })

  it('chains through a finished card that is not waiting, so the chain can reach past it', () => {
    const nodes = [task('a', 'done', { celebrate: true }), task('b', 'done'), task('c', 'done', { celebrate: true })]
    const links = [link('a', 'b'), link('b', 'c')]

    expect(finishedHops('a', links, finished(nodes)).get('c')).toBe(2)
  })

  it('ignores related links and does not revisit cards in a cycle', () => {
    const nodes = [task('a', 'done'), task('b', 'done'), task('c', 'done')]
    const links = [link('a', 'b'), link('b', 'c'), link('c', 'a'), link('a', 'c', 'related')]

    const hops = finishedHops('a', links, finished(nodes))

    expect(hops.get('b')).toBe(1)
    expect(hops.get('c')).toBe(1)
    expect(hops.size).toBe(3)
  })

  it('follows a chain through a finished note, since notes pass blocking through', () => {
    const nodes = [task('a', 'done'), task('n', 'todo', {}, 'note'), task('b', 'done')]
    const links = [link('a', 'n'), link('n', 'b')]

    expect(finishedHops('a', links, finished(nodes, ['n'])).get('b')).toBe(2)
  })
})

describe('celebrationDelays', () => {
  it('lists only waiting cards in the chain, each delayed by its distance from the click', () => {
    const nodes = [
      task('a', 'done', { celebrate: true }),
      task('b', 'done', { celebrate: true }),
      task('c', 'done'),
      task('d', 'done', { celebrate: true }),
      task('open', 'active', { celebrate: true }),
    ]
    const links = [link('a', 'b'), link('b', 'c'), link('c', 'd'), link('d', 'open')]

    const delays = celebrationDelays('a', nodes, links, finished(nodes))

    expect([...delays]).toEqual([
      ['a', 0],
      ['b', CHAIN_STEP_MS],
      ['d', 3 * CHAIN_STEP_MS],
    ])
  })

  it('leaves out cards that a related link connects', () => {
    const nodes = [task('a', 'done', { celebrate: true }), task('b', 'done', { celebrate: true })]
    const links = [link('a', 'b', 'related')]

    expect([...celebrationDelays('a', nodes, links, finished(nodes))]).toEqual([['a', 0]])
  })

  it('does nothing when the clicked card is not waiting', () => {
    const nodes = [task('a', 'done'), task('b', 'done', { celebrate: true })]
    const links = [link('a', 'b')]

    expect(celebrationDelays('a', nodes, links, finished(nodes)).size).toBe(0)
  })

  it('caps the delay so a long chain still clears in about a second', () => {
    const ids = Array.from({ length: 20 }, (_, index) => `t${index}`)
    const nodes = ids.map((id) => task(id, 'done', { celebrate: true }))
    const links = ids.slice(1).map((id, index) => link(ids[index], id))

    const delays = celebrationDelays('t0', nodes, links, finished(nodes))

    expect(Math.max(...delays.values())).toBe(8 * CHAIN_STEP_MS)
  })
})

describe('clearCelebrations', () => {
  it('removes the flag only from the listed cards and keeps other nodes as they were', () => {
    const nodes = [task('a', 'done', { celebrate: true }), task('b', 'done', { celebrate: true }), task('c', 'done', { celebrate: true })]

    const cleared = clearCelebrations(nodes, new Set(['a', 'b']))

    expect((cleared[0] as TaskNode).data.celebrate).toBeUndefined()
    expect('celebrate' in cleared[0].data).toBe(false)
    expect((cleared[1] as TaskNode).data.celebrate).toBeUndefined()
    expect(cleared[2]).toBe(nodes[2])
  })
})

describe('patchTaskData', () => {
  it('closes a card out when it changes to done and clears the flag when the card is reopened', () => {
    const data = task('a', 'active').data as TaskData

    const finishedData = patchTaskData(data, { status: 'done' })

    expect(finishedData.celebrate).toBe(false)

    const reopened = patchTaskData(finishedData, { status: 'todo' })

    expect('celebrate' in reopened).toBe(false)
  })

  it('keeps the flag through edits that leave the status alone', () => {
    const data = task('a', 'done', { celebrate: true }).data as TaskData

    expect(patchTaskData(data, { label: 'Renamed', status: 'done' }).celebrate).toBe(true)
    expect(patchTaskData(data, { label: 'Renamed' }).celebrate).toBe(true)
  })

  it('does not flag notes', () => {
    const data = task('n', 'todo', {}, 'note').data as TaskData

    expect(patchTaskData(data, { status: 'done' }).celebrate).toBeUndefined()
  })
})

// The card menu's Mark done and the inspector's Done both save `{ status: 'done' }` through the same patch.
describe('finishing a card in the app', () => {
  it('closes it out at once from the card menu', () => {
    const data = task('a', 'active').data as TaskData
    const patch = { status: 'done' } as const

    expect(closesOut(data, patch)).toBe(true)
    expect(patchTaskData(data, patch).celebrate).toBe(false)
    expect(celebrationDelays('a', [task('a', 'done', patchTaskData(data, patch))], [], () => true).size).toBe(0)
  })

  it('closes it out at once from the inspector', () => {
    const data = task('a', 'review').data as TaskData
    const patch: Partial<TaskData> = { status: 'done' }

    expect(closesOut(data, patch)).toBe(true)
    expect(patchTaskData(data, patch).celebrate).toBe(false)
  })

  it('leaves cards finished outside the app waiting', () => {
    const data = task('a', 'done', { celebrate: true }).data as TaskData

    expect(closesOut(data, { status: 'done' })).toBe(false)
    expect(closesOut(data, { label: 'Renamed' })).toBe(false)
    expect(patchTaskData(data, { label: 'Renamed' }).celebrate).toBe(true)
  })

  it('does not land a stamp on notes or components', () => {
    expect(closesOut(task('n', 'todo', {}, 'note').data as TaskData, { status: 'done' })).toBe(false)
    expect(closesOut(task('c', 'todo', {}, 'component').data as TaskData, { status: 'done' })).toBe(false)
  })
})
