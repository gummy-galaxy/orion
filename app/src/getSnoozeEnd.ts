import { SNOOZE_LENGTHS, type SnoozeLength } from './checkSnoozes'

/** When a CI job snooze of a length started now ends, or undefined for one that lasts until the job passes. */
export function getSnoozeEnd(length: SnoozeLength, now = Date.now()): string | undefined {
  const ms = SNOOZE_LENGTHS.find((option) => option.id === length)?.ms

  return ms ? new Date(now + ms).toISOString() : undefined
}
