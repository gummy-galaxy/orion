import { STATUS_CHOICES, type TaskData } from '../model'
import { getCardType } from './getCardType'

/** The states a person can record on a card, in its type's order. A type with none, like a note, takes the shipped ones. */
export function getStateChoices(data: Pick<TaskData, 'type' | 'types' | 'refs' | 'repo'>): { value: string; label: string }[] {
  const { states } = getCardType(data)

  return states.length > 0 ? states.map((state) => ({ value: state.name, label: state.label })) : STATUS_CHOICES
}
