import type { SourceRef } from '../model'
import type { CardSession, SessionState } from './types'

const STATES: readonly SessionState[] = ['working', 'waiting', 'done']

/** The card's most recently active session, from its `session` refs. */
export function getCardSession(refs: readonly SourceRef[] | undefined): CardSession | undefined {
  let latest: SourceRef | undefined

  for (const ref of refs ?? []) {
    if (ref.kind !== 'session' || !STATES.includes(ref.sessionState as SessionState)) continue

    if (!latest || (ref.updatedAt ?? '') > (latest.updatedAt ?? '')) latest = ref
  }

  if (!latest) return undefined

  const title = latest.details?.title

  return {
    key: latest.key,
    title: typeof title === 'string' ? title : latest.key,
    state: latest.sessionState as SessionState,
    ...(latest.lastMessage ? { lastMessage: latest.lastMessage } : {}),
    ...(latest.updatedAt ? { updatedAt: latest.updatedAt } : {}),
    isLive: latest.details?.isLive === true,
  }
}
