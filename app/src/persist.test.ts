import { afterEach, expect, it, vi } from 'vitest'
import { clearFocus, compactDoc, fetchRemote, fingerprint, reportFocus } from './persist'

afterEach(() => vi.unstubAllGlobals())

it('reads the requested workspace during a conflict retry', async () => {
  const remote = { version: 2, revision: 3, settings: {}, nodes: [], links: [] }
  const fetchMock = vi.fn().mockResolvedValue({
    ok: true,
    headers: new Headers({ 'content-type': 'application/json' }),
    json: async () => remote,
  })

  vi.stubGlobal('fetch', fetchMock)

  expect(await fetchRemote('other')).toEqual(remote)
  expect(fetchMock).toHaveBeenCalledWith('/api/orion', { headers: { 'x-orion-workspace': 'other' } })
})

it('reports the selection with a tab and workspace', () => {
  const fetchMock = vi.fn().mockResolvedValue({ ok: true })

  vi.stubGlobal('fetch', fetchMock)

  reportFocus({ open: 'group', selected: ['card'] }, 'planning')

  const [url, options] = fetchMock.mock.calls[0]

  expect(url).toBe('/api/focus')
  expect(options.method).toBe('POST')
  expect(JSON.parse(options.body)).toEqual({ tab: expect.any(String), workspace: 'planning', open: 'group', selected: ['card'] })
})

it('sends a closing report for the same workspace', async () => {
  const sendBeacon = vi.fn()

  vi.stubGlobal('navigator', { sendBeacon })

  clearFocus('planning')

  const [url, body] = sendBeacon.mock.calls[0]

  expect(url).toBe('/api/focus')
  expect(JSON.parse(await (body as Blob).text())).toEqual({ tab: expect.any(String), workspace: 'planning', closed: true })
})

it('fingerprints a document the same however its position keys are ordered', () => {
  // The server returns positions as y then x; the canvas builds x then y. Both are the same document.
  const canvas = compactDoc({
    nodes: [{ id: 'a', type: 'task', position: { x: 10, y: 20 }, data: { kind: 'task', label: 'a' } }] as never,
    links: [],
  })
  const server = compactDoc({
    nodes: [{ id: 'a', type: 'task', position: { y: 20, x: 10 }, data: { label: 'a', kind: 'task' } }] as never,
    links: [],
  })

  expect(fingerprint(canvas)).toBe(fingerprint(server))
})
