/** How long a new CI job snooze lasts: until the job next passes on each card, or for a while. */
export const SNOOZE_LENGTHS = [
  { id: 'pass', label: 'Until it passes', ms: undefined },
  { id: 'hour', label: 'For an hour', ms: 60 * 60 * 1000 },
  { id: 'day', label: 'For a day', ms: 24 * 60 * 60 * 1000 },
  { id: 'week', label: 'For a week', ms: 7 * 24 * 60 * 60 * 1000 },
] as const

export type SnoozeLength = (typeof SNOOZE_LENGTHS)[number]['id']
