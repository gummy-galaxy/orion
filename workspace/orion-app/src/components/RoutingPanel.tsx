import { APPROACHES, AVOID_LIMIT, SIZES, type Approach, type Size } from '../routing/approaches'

export type RoutingStats = { lastMs: number; averageMs: number; maxMs: number; frames: number; fallbacks: number; lines: number; note?: string }

/** The spike's switcher: pick an approach and a canvas size, and read how long routing took. */
export function RoutingPanel({
  approach,
  size,
  stats,
  onApproach,
  onSize,
}: {
  approach: Approach
  size: Size
  stats: RoutingStats
  onApproach: (approach: Approach) => void
  onSize: (size: Size) => void
}) {
  const button = (active: boolean) =>
    ({
      font: 'inherit',
      padding: '4px 10px',
      borderRadius: 6,
      border: '1px solid var(--border-default)',
      background: active ? 'var(--accent-default)' : 'transparent',
      color: active ? 'white' : 'inherit',
      cursor: 'pointer',
    }) as const

  return (
    <div
      style={{
        position: 'absolute',
        top: 12,
        left: 12,
        zIndex: 10,
        display: 'grid',
        gap: 8,
        padding: 12,
        borderRadius: 10,
        background: 'var(--surface-background)',
        color: 'var(--text-primary)',
        boxShadow: 'var(--shadow-dialog)',
        border: '1px solid var(--border-default)',
        font: '12px/1.4 system-ui, sans-serif',
        minWidth: 280,
      }}
    >
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {APPROACHES.map((option) => (
          <button key={option.id} style={button(option.id === approach)} onClick={() => onApproach(option.id)}>
            {option.label}
          </button>
        ))}
      </div>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <span>Links</span>
        {SIZES.map((option) => (
          <button
            key={option}
            style={button(option === size)}
            onClick={() => onSize(option)}
            disabled={approach === 'libavoid' && option > AVOID_LIMIT}
          >
            {option}
          </button>
        ))}
      </div>
      <div style={{ fontVariantNumeric: 'tabular-nums' }}>
        Routing: {stats.lastMs.toFixed(2)} ms last, {stats.averageMs.toFixed(2)} ms average, {stats.maxMs.toFixed(2)} ms worst over {stats.frames}{' '}
        frames
        <br />
        {stats.lines} lines drawn{stats.fallbacks ? `, ${stats.fallbacks} couldn't avoid cards` : ''}
        {stats.note ? (
          <>
            <br />
            {stats.note}
          </>
        ) : null}
      </div>
      <div style={{ opacity: 0.7 }}>Drag a card or group to reroute every frame.</div>
    </div>
  )
}
