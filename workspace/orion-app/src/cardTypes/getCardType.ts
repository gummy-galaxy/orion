import type { TaskData } from '../model'
import { findCardType } from './findCardType'
import { getItemTypes } from './getItemTypes'
import type { CardType } from './types'

/** The declaration of a card's primary type. A type nothing registers reads as a step, so the card still draws. */
export function getCardType(data: Pick<TaskData, 'type' | 'types' | 'refs' | 'repo'>): CardType {
  return findCardType(getItemTypes(data).primary) ?? findCardType('step')!
}
