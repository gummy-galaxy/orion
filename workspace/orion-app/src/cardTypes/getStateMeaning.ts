import type { Status, TaskData } from '../model'
import { getCardType } from './getCardType'

const MEANINGS: ReadonlySet<string> = new Set(['todo', 'active', 'review', 'blocked', 'deferred', 'done'])

/**
 * What a card's recorded state counts as, from its primary type's states, as the CLI's `getStateMeaning` reads it. A
 * type with no states, like a note, reads a recorded meaning as itself, and anything else is still to do.
 */
export function getStateMeaning(data: Pick<TaskData, 'type' | 'types' | 'refs' | 'repo' | 'status'>): Status {
  const { states } = getCardType(data)
  const state = states.find((candidate) => candidate.name === data.status)

  if (state) return state.means

  return states.length === 0 && MEANINGS.has(data.status) ? (data.status as Status) : 'todo'
}
