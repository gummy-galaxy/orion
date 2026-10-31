import type { SnoozedFacts } from './derive'
import type { SourceRef } from './model'

/**
 * A pull request ref showing the facts `orion serve` derived with the card's snoozed CI jobs left out, when it sent
 * any.
 */
export function withSnoozedFacts(ref: SourceRef, facts: SnoozedFacts | undefined): SourceRef {
  if (!facts) return ref

  return { ...ref, readiness: facts.readiness, checks: facts.checks }
}
