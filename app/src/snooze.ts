/** A snooze choice from the card menu: a fixed span from now, the next day or week, or a date picked in the menu. */
export type SnoozeChoice = 'later' | 'tomorrow' | 'nextWeek' | { date: string }

const LATER_MS = 4 * 60 * 60 * 1000

/** A UTC time in the form the CLI stores, such as 2026-10-12T07:00:00Z. */
export function toStoredTime(date: Date): string {
  return date.toISOString().replace(/\.\d{3}Z$/, 'Z')
}

/** A date as YYYY-MM-DD in local time, the form date inputs use. */
export function localDateValue(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')

  return `${date.getFullYear()}-${month}-${day}`
}

/**
 * When a snooze ends. "Tomorrow", "next week", and a picked date all wake at the start of that local day, which is how
 * `orion snooze --until <date>` reads a plain date, so the app and the CLI agree.
 */
export function snoozeUntil(choice: SnoozeChoice, now: Date): string {
  if (choice === 'later') return toStoredTime(new Date(now.getTime() + LATER_MS))

  if (choice === 'tomorrow') return toStoredTime(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1))

  if (choice === 'nextWeek') {
    const daysUntilMonday = (1 - now.getDay() + 7) % 7 || 7

    return toStoredTime(new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysUntilMonday))
  }

  const [year, month, day] = choice.date.split('-').map(Number)

  return toStoredTime(new Date(year, month - 1, day))
}
