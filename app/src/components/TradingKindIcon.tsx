import type { CardView } from '../cardView'

export function TradingKindIcon({ kind }: { kind: CardView['kind'] }) {
  const shared = {
    viewBox: '0 0 32 32',
    width: '100%',
    height: '100%',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
    'aria-hidden': true as const,
  }

  if (kind === 'step') {
    return (
      <svg {...shared}>
        <rect x="4" y="4" width="24" height="24" rx="1" />
        <path d="m9 16 5 5 9-10" />
      </svg>
    )
  }

  if (kind === 'pr') {
    return (
      <svg {...shared}>
        <circle cx="8" cy="6" r="3" />
        <circle cx="8" cy="26" r="3" />
        <circle cx="24" cy="10" r="3" />
        <path d="M8 9v14m0 0v-4c0-6 16-2 16-6" />
      </svg>
    )
  }

  if (kind === 'placeholder') {
    return (
      <svg {...shared}>
        <circle cx="16" cy="16" r="12" strokeDasharray="3 3" />
        <path d="M16 10v12m-6-6h12" />
      </svg>
    )
  }

  if (kind === 'gate') {
    return (
      <svg {...shared}>
        <path d="M4 28V15a12 12 0 0 1 24 0v13H4Z" />
        <path d="M11 28V16a5 5 0 0 1 10 0v12" />
      </svg>
    )
  }

  return (
    <svg {...shared}>
      <path d="M5 4h15l7 7v17H5V4Z" />
      <path d="M20 4v7h7M10 17h12m-12 5h9" />
    </svg>
  )
}
