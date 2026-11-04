import type { Status, TaskData } from '../model'
import { getCardType } from './getCardType'

/** The first state a card's primary type declares with a meaning, such as the one finishing it records. */
export function findState(data: Pick<TaskData, 'type' | 'types' | 'refs' | 'repo'>, means: Status): string {
  return getCardType(data).states.find((state) => state.means === means)?.name ?? means
}
