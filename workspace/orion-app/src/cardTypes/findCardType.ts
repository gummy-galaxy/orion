import { registry } from './registry'
import type { CardType } from './types'

/** A registered type by name. A card can carry one nothing registers, such as a type from a source this build lacks. */
export function findCardType(name: string): CardType | undefined {
  return registry.get(name)
}
