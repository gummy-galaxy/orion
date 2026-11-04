import { STATUS_CHOICES, type TaskData } from '../model'
import { getCardType } from './getCardType'

/**
 * The statuses a multi-selection can set. Setting one has each card record the state its own type declares for it, so
 * a status that any card's type has no state for isn't offered. A type with no states takes them all.
 */
export function getSharedStatusChoices(items: Pick<TaskData, 'type' | 'types' | 'refs' | 'repo'>[]) {
  return STATUS_CHOICES.filter((choice) =>
    items.every((item) => {
      const { states } = getCardType(item)

      return states.length === 0 || states.some((state) => state.means === choice.value)
    }),
  )
}
