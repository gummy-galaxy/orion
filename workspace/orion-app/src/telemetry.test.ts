import { afterEach, expect, it, vi } from 'vitest'
import { chooseTelemetry, readTelemetry, shouldAskTelemetry } from './telemetry'

afterEach(() => vi.unstubAllGlobals())

it('reads no status without a server to ask', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
  expect(await readTelemetry()).toBeNull()

  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 404 }))
  expect(await readTelemetry()).toBeNull()
})

it('sends the answer and returns the status it leaves', async () => {
  const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ choice: 'off', enabled: false }) })

  vi.stubGlobal('fetch', fetchMock)

  expect(await chooseTelemetry(false)).toEqual({ choice: 'off', enabled: false })
  expect(fetchMock.mock.calls[0][1].body).toBe('{"enabled":false}')
})

it('rejects an answer the server refused, so the caller keeps the old status', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: false, status: 400 }))

  await expect(chooseTelemetry(true)).rejects.toThrow('400')
})

it('asks only an undecided machine with no override', () => {
  expect(shouldAskTelemetry({ choice: 'undecided', enabled: false })).toBe(true)
  expect(shouldAskTelemetry({ choice: 'undecided', override: 'DO_NOT_TRACK', enabled: false })).toBe(false)
  expect(shouldAskTelemetry({ choice: 'off', enabled: false })).toBe(false)
  expect(shouldAskTelemetry(null)).toBe(false)
})
