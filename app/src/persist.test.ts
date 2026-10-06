import { afterEach, expect, it, vi } from 'vitest'
import { fetchRemote } from './persist'

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
