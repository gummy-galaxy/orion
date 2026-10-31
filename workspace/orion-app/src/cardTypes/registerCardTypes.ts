import { registry } from './registry'
import type { CardType } from './types'

/** Replaces the known card types with the ones the server declares. A list that isn't one is ignored. */
export function registerCardTypes(declared: unknown) {
  if (!Array.isArray(declared) || declared.length === 0) return

  registry.clear()

  for (const cardType of declared as CardType[]) {
    if (typeof cardType?.name === 'string') registry.set(cardType.name, cardType)
  }
}
