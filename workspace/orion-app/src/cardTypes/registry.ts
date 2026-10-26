import builtinTypes from './builtinTypes.json'
import type { CardType } from './types'

/**
 * Every card type the app knows, by name. It starts with the types Orion ships, generated from the CLI by
 * `lute run card-types`, so built-in cards draw before the server answers, and `registerCardTypes` swaps in the
 * server's full list, with any types its sources declare.
 */
export const registry = new Map<string, CardType>((builtinTypes as CardType[]).map((cardType) => [cardType.name, cardType]))
