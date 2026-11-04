import type { TaskData } from '../model'
import { findCardType } from './findCardType'
import { getRefType } from './getRefType'
import type { ItemTypes } from './types'

/**
 * The types attached to a card, as the CLI's `getItemTypes` works them out. The primary type is the one a person chose,
 * or else its first source's, or else a placeholder when the card names a repository. A source's type takes over when
 * it supersedes it, as a pull request does a placeholder, and a card with none is a step.
 */
export function getItemTypes(data: Pick<TaskData, 'type' | 'types' | 'refs' | 'repo'>): ItemTypes {
  const sourced = (data.refs ?? []).map(getRefType).filter((name): name is string => !!name)
  let primary = data.type ?? sourced[0] ?? (data.repo ? 'placeholder' : 'step')

  for (const candidate of sourced) {
    if (findCardType(candidate)?.supersedes.includes(primary)) primary = candidate
  }

  const chosen = data.type ? [data.type] : []

  return { primary, types: [...new Set([primary, ...chosen, ...sourced, ...(data.types ?? [])])] }
}
