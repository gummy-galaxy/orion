import { afterEach, expect, test, vi } from 'vitest'
import { fetchStartOptions } from './fetchStartOptions'

afterEach(() => {
  vi.unstubAllGlobals()
})

test('asks the server about the card on its canvas', async () => {
  const options = {
    presets: [{ id: 'work', label: 'Work on this card' }],
    agent: 'Claude Code',
    attaches: true,
    repo: 'owner/repo',
    branch: 'agent/fix',
    place: 'checkout',
    folder: '/w',
    problem: null,
  }
  const fetch = vi.fn(() => Promise.resolve(Response.json(options)))

  vi.stubGlobal('fetch', fetch)

  await expect(fetchStartOptions('my canvas', 'card-1')).resolves.toEqual(options)
  expect(fetch).toHaveBeenCalledWith('/api/sessions/start?canvas=my+canvas&id=card-1')
})

test('reads as nothing when the server fails or answers oddly', async () => {
  vi.stubGlobal('fetch', () => Promise.resolve(Response.json({ error: 'no card' }, { status: 404 })))
  await expect(fetchStartOptions('default', 'gone')).resolves.toBeNull()

  vi.stubGlobal('fetch', () => Promise.resolve(Response.json({ presets: 'nope' })))
  await expect(fetchStartOptions('default', 'odd')).resolves.toBeNull()

  vi.stubGlobal('fetch', () => Promise.reject(new Error('offline')))
  await expect(fetchStartOptions('default', 'offline')).resolves.toBeNull()
})
