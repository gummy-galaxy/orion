import { afterEach, describe, expect, it, vi } from 'vitest'
import { fetchLog, getCardLog, type LogEntry } from './log'

afterEach(() => vi.unstubAllGlobals())

const entry = (id: string, cards: string[], author = { kind: 'person', name: 'Marin' }): LogEntry => ({
  id,
  text: `text ${id}`,
  time: '2026-10-12T10:00:00-07:00',
  author: author as LogEntry['author'],
  targets: cards.map((card) => ({ kind: 'card', id: card })),
})

const json = (body: unknown, status = 200) => ({
  ok: status < 400,
  status,
  headers: new Headers({ 'content-type': 'application/json' }),
  json: async () => body,
})

describe('fetchLog', () => {
  it('reads the named workspace and keeps well-formed entries', async () => {
    const fetchMock = vi.fn().mockResolvedValue(json({ entries: [entry('log-1', ['a']), { id: 'bad' }] }))

    vi.stubGlobal('fetch', fetchMock)

    const entries = await fetchLog('planning board')

    expect(fetchMock).toHaveBeenCalledWith('/api/log?workspace=planning%20board')
    expect(entries?.map((item) => item.id)).toEqual(['log-1'])
  })

  it('answers null for a missing endpoint, so the section stays hidden', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(json({ error: 'not found' }, 404)))

    expect(await fetchLog('default')).toBeNull()
  })

  it('answers null for a static build that serves its page instead of JSON', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 200, headers: new Headers({ 'content-type': 'text/html' }) }))

    expect(await fetchLog('default')).toBeNull()
  })

  it('answers null when the request fails', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('network down')))

    expect(await fetchLog('default')).toBeNull()
  })
})

describe('getCardLog', () => {
  it('returns only the entries attached to the card, newest first', () => {
    const entries = [entry('log-1', ['a']), entry('log-2', ['b']), entry('log-3', ['a', 'b']), entry('log-4', [])]

    expect(getCardLog(entries, 'a').map((item) => item.id)).toEqual(['log-3', 'log-1'])
    expect(getCardLog(entries, 'c')).toEqual([])
  })
})
