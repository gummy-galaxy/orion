import { afterEach, expect, test, vi } from 'vitest'
import { startSession } from './startSession'

afterEach(() => {
  vi.unstubAllGlobals()
})

test('posts the card and preset to the server', async () => {
  const fetch = vi.fn((_url: string, _init?: RequestInit) => Promise.resolve(Response.json({ url: 'claude://code/new' })))

  vi.stubGlobal('fetch', fetch)

  await startSession('default', 'card-1', 'resolve-conflicts')

  const [url, init] = fetch.mock.calls[0]

  expect(url).toBe('/api/sessions/start')
  expect(init?.method).toBe('POST')
  expect(JSON.parse(String(init?.body))).toEqual({ canvas: 'default', id: 'card-1', preset: 'resolve-conflicts' })
})

test("fails with the server's reason", async () => {
  vi.stubGlobal('fetch', () => Promise.resolve(Response.json({ error: "The work preset doesn't fit" }, { status: 409 })))

  await expect(startSession('default', 'card-1', 'work')).rejects.toThrow("The work preset doesn't fit")
})
