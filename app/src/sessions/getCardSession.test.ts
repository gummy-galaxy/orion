import { expect, test } from 'vitest'
import type { SourceRef } from '../model'
import { getCardSession } from './getCardSession'

const session = (key: string, updatedAt: string, sessionState: string): SourceRef => ({
  source: 'claude',
  kind: 'session',
  key,
  updatedAt,
  sessionState,
  lastMessage: `${key} said hi`,
  details: { title: `Title ${key}`, isLive: true },
})

test('picks the most recently active session', () => {
  const refs = [session('claude:a', '2026-10-18T10:00:00Z', 'done'), session('claude:b', '2026-10-18T11:00:00Z', 'waiting')]

  expect(getCardSession(refs)).toEqual({
    key: 'claude:b',
    title: 'Title claude:b',
    state: 'waiting',
    lastMessage: 'claude:b said hi',
    updatedAt: '2026-10-18T11:00:00Z',
    isLive: true,
  })
})

test('ignores other refs and unknown states', () => {
  const pull: SourceRef = { source: 'github', kind: 'pull', key: 'vocksel/orion#1' }

  expect(getCardSession([pull, session('claude:a', '2026-10-18T10:00:00Z', 'sleeping')])).toBeUndefined()
  expect(getCardSession(undefined)).toBeUndefined()
})
