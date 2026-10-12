import { useId } from 'react'
import type { CardView } from '../cardView'

type SceneKind = Exclude<CardView['kind'], 'note'>

// mulberry32: a small seeded generator, so a card's scene draws the same every time.
function createRandom(seed: number) {
  let state = seed >>> 0

  return () => {
    state = (state + 0x6d2b79f5) >>> 0

    let value = state

    value = Math.imul(value ^ (value >>> 15), value | 1)
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61)

    return ((value ^ (value >>> 14)) >>> 0) / 4294967296
  }
}

function sparkle(x: number, y: number, size: number) {
  const waist = size * 0.18

  return `M${x} ${y - size}Q${x + waist} ${y - waist} ${x + size} ${y}Q${x + waist} ${y + waist} ${x} ${y + size}Q${x - waist} ${y + waist} ${x - size} ${y}Q${x - waist} ${y - waist} ${x} ${y - size}Z`
}

/**
 * A card's art as a scene in the night sky. The kind picks the subject: steps are an orb rising over layered
 * hills, pull requests a ringed planet, expected pull requests an eclipse waiting to be lit, and gates a
 * four-point star. The seed places everything, and the group's inks color it. With `subjectOnly`, the starfield is
 * left out so the subject can sit on other art.
 */
export function TradingScene({ kind, seed, subjectOnly = false }: { kind: SceneKind; seed: number; subjectOnly?: boolean }) {
  const id = useId()
  const random = createRandom(seed)
  const glow = `${id}-glow`
  const body = `${id}-body`

  const stars = Array.from({ length: 16 }, () => ({
    x: random() * 264,
    y: random() * 170,
    r: 0.6 + random() * 1.3,
    opacity: 0.45 + random() * 0.5,
  }))

  const x = 96 + random() * 72
  const y = 70 + random() * 26
  const radius = 34 + random() * 14
  const tilt = -10 - random() * 18

  return (
    <svg className="trading-scene" viewBox="0 0 264 380" preserveAspectRatio="xMidYMin slice" aria-hidden="true">
      <defs>
        <radialGradient id={glow}>
          <stop offset="0" stopColor="#fff" stopOpacity="0.55" />
          <stop offset="0.35" style={{ stopColor: 'var(--trading-ink-two)' }} stopOpacity="0.45" />
          <stop offset="1" style={{ stopColor: 'var(--trading-ink-two)' }} stopOpacity="0" />
        </radialGradient>
        <radialGradient id={body} cx="0.35" cy="0.3" r="0.8">
          <stop offset="0" stopColor="#fff4f8" />
          <stop offset="0.35" style={{ stopColor: 'var(--trading-ink-two)' }} />
          <stop offset="1" style={{ stopColor: 'var(--trading-ink-one)' }} />
        </radialGradient>
      </defs>
      {!subjectOnly && stars.map((star, index) => <circle key={index} cx={star.x} cy={star.y} r={star.r} fill="#fff" opacity={star.opacity} />)}
      <path d={sparkle(30 + random() * 40, 30 + random() * 30, 5)} fill="#fff" opacity="0.8" />
      {kind === 'step' && (
        <>
          <circle cx={x} cy={y} r={radius * 2.2} fill={`url(#${glow})`} />
          <circle cx={x} cy={y} r={radius} fill={`url(#${body})`} />
          {[0, 1, 2].map((band) => (
            <ellipse
              key={band}
              cx={132 + (random() - 0.5) * 80}
              cy={150 + band * 22}
              rx={230}
              ry={46}
              style={{ fill: band % 2 ? 'var(--trading-ink-two)' : 'var(--trading-ink-one)' }}
              opacity={0.55 + band * 0.15}
            />
          ))}
        </>
      )}
      {kind === 'pr' && (
        <g transform={`rotate(${tilt} ${x} ${y})`}>
          <circle cx={x} cy={y} r={radius * 2.2} fill={`url(#${glow})`} />
          <ellipse cx={x} cy={y} rx={radius * 2} ry={radius * 0.42} fill="none" stroke="#ffe08a" strokeWidth="3" opacity="0.45" />
          <circle cx={x} cy={y} r={radius} fill={`url(#${body})`} />
          <path
            d={`M${x - radius * 2} ${y}A${radius * 2} ${radius * 0.42} 0 0 0 ${x + radius * 2} ${y}`}
            fill="none"
            stroke="#ffe08a"
            strokeWidth="3.5"
          />
        </g>
      )}
      {kind === 'placeholder' && (
        <>
          <circle cx={x} cy={y} r={radius * 1.9} fill={`url(#${glow})`} opacity="0.7" />
          <circle cx={x} cy={y} r={radius + 2} style={{ fill: 'var(--trading-ink-two)' }} opacity="0.9" />
          <circle cx={x + radius * 0.22} cy={y - radius * 0.12} r={radius} fill="#0c0920" />
        </>
      )}
      {kind === 'gate' && (
        <>
          <path d={`M-20 ${y + 70}Q132 ${y - 10} 284 ${y + 70}`} fill="none" stroke="#7af0e0" strokeWidth="2" opacity="0.6" />
          <circle cx={132} cy={y} r={radius * 2.4} fill={`url(#${glow})`} />
          <path d={sparkle(132, y, radius * 1.15)} fill="#fff" />
          <path d={sparkle(132 - radius * 1.7, y + 12, 9)} fill="#18d6c0" />
          <path d={sparkle(132 + radius * 1.7, y + 12, 9)} fill="#ff8fa3" />
        </>
      )}
    </svg>
  )
}
