import type { ComponentShape, Status, Tint, Who } from '../model'

/**
 * A card's field changes, named as `orion card set` names them, which `orion serve` checks with the CLI's rules. An
 * empty string clears a field. `pr` is a pull request number in the card's repository, which the GitHub adapter turns
 * into a ref, or empty to take the pull request off.
 */
export type CardFields = {
  label?: string
  status?: Status
  who?: Who | ''
  note?: string
  repo?: string
  kind?: 'step' | 'gate' | 'component'
  shape?: ComponentShape | ''
  color?: Tint | ''
  snoozedUntil?: string
  pr?: number | ''
  /** Fields the card's types declare, by name, as typed text the CLI checks. An empty string clears one. */
  values?: Record<string, string>
}

/** Sends a card's field changes to `orion serve` and resolves once it answers: with its error, or null once saved. */
export type SaveFields = (id: string, fields: CardFields) => Promise<string | null>
