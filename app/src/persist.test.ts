import { afterEach, expect, it, vi } from 'vitest'
import { clearFocus, fetchRemote, reportFocus } from './persist'

afterEach(() => vi.unstubAllGlobals())

it('reads the requested workspace during a conflict retry', async () => {
  const remote = { revision: 3, settings: { githubOwner: 'example' }, nodes: [], links: [] }
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
