import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { readFileSetting, restoreSettings, saveFileSetting, saveSettings } from './settings'

let stored: Map<string, string>

beforeEach(() => {
  stored = new Map()
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => stored.get(key) ?? null,
    setItem: (key: string, value: string) => stored.set(key, value),
    removeItem: (key: string) => stored.delete(key),
  })
})

afterEach(() => vi.unstubAllGlobals())

const respond = (body: unknown) => vi.fn().mockResolvedValue({ ok: true, json: async () => body })

it('copies saved preferences into browser storage', async () => {
  vi.stubGlobal('fetch', respond({ theme: 'vibrant', sidebar: 0, motion: { arrows: false } }))

  await restoreSettings()

  expect(stored.get('orion:theme')).toBe('vibrant')
  expect(stored.get('orion:sidebar')).toBe('0')
  expect(stored.get('orion:motion')).toBe('{"arrows":false}')
})

it('sends up preferences only this browser has', async () => {
  const fetchMock = respond({ theme: 'classic' })

  stored.set('orion:theme', 'vibrant')
  stored.set('orion:color-mode', 'dark')
  vi.stubGlobal('fetch', fetchMock)

  await restoreSettings()
  await vi.waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2))

  const [url, options] = fetchMock.mock.calls[1]

  expect(stored.get('orion:theme')).toBe('classic')
  expect(url).toBe('/api/settings')
  expect(JSON.parse(options.body)).toEqual({ 'color-mode': 'dark' })
})

it('leaves browser storage alone without a server', async () => {
  stored.set('orion:theme', 'vibrant')
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))

  await restoreSettings()

  expect(stored.get('orion:theme')).toBe('vibrant')
})

it('saves preferences in both places with one request', async () => {
  const fetchMock = respond({})

  vi.stubGlobal('fetch', fetchMock)

  saveSettings({ theme: 'vibrant', debug: '1' })
  await vi.waitFor(() => expect(fetchMock).toHaveBeenCalledOnce())

  expect(stored.get('orion:debug')).toBe('1')
  expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ theme: 'vibrant', debug: 1 })
})

it('sends saves in order', async () => {
  const fetchMock = respond({})

  vi.stubGlobal('fetch', fetchMock)

  saveSettings({ theme: 'vibrant' })
  saveSettings({ theme: 'classic' })
  await vi.waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2))

  expect(fetchMock.mock.calls.map(([, options]) => JSON.parse(options.body).theme)).toEqual(['vibrant', 'classic'])
})

it('reads one data-folder preference by key', async () => {
  vi.stubGlobal('fetch', respond({ 'palette-recents:orion': [{ kind: 'command', id: 'fit' }] }))

  expect(await readFileSetting('palette-recents:orion')).toEqual([{ kind: 'command', id: 'fit' }])
  expect(await readFileSetting('palette-recents:other')).toBeUndefined()
})

it('rejects a data-folder read that fails', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 500 }))

  await expect(readFileSetting('palette-recents:orion')).rejects.toThrow('500')
})

it('saves a data-folder preference without browser storage', async () => {
  const fetchMock = respond({})

  vi.stubGlobal('fetch', fetchMock)

  saveFileSetting('palette-recents:orion', [{ kind: 'node', id: 'a' }])
  await vi.waitFor(() => expect(fetchMock).toHaveBeenCalledOnce())

  expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({ 'palette-recents:orion': [{ kind: 'node', id: 'a' }] })
  expect(stored.size).toBe(0)
})
