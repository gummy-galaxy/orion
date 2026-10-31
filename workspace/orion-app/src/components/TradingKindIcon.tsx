import type { CardView } from '../cardView'

/** The mark on a card's tile for its kind. A type with no mark of its own takes the step's. */
export function TradingKindIcon({ kind }: { kind: CardView['kind'] }) {
  if (kind === 'pr') {
    return (
      <svg viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
        <path
          d={
            'M5 3.25a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z' +
            'm0 2.122a2.25 2.25 0 1 0-1.5 0v5.256a2.25 2.25 0 1 0 1.5 0Z' +
            'm7.25 5.256V7a2.5 2.5 0 0 0-2.5-2.5H8.06l1.22-1.22-1.06-1.06L5.19 5.25l3.03 3.03 1.06-1.06L8.06 6h1.69' +
            'c.552 0 1 .448 1 1v3.628a2.25 2.25 0 1 0 1.5 0Z' +
            'M12.25 12a.75.75 0 1 1-1.5 0 .75.75 0 0 0 0-1.5Z'
          }
        />
      </svg>
    )
  }

  if (kind === 'placeholder') {
    return (
      <svg
        viewBox="0 0 16 16"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeDasharray="2 2"
        aria-hidden="true"
      >
        <circle cx="8" cy="8" r="5.5" />
      </svg>
    )
  }

  if (kind === 'gate') {
    return (
      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
        <path d="M3 14V6a5 5 0 0 1 10 0v8M3 14h10M8 9v5" />
      </svg>
    )
  }

  return (
    <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
      <circle cx="8" cy="8" r="5.5" />
      <path d="m5.5 8 1.8 1.8L10.8 6" />
    </svg>
  )
}
