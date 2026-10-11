import { useId, type ReactNode } from 'react'
import { AREA_LABEL, type CardArea } from '../cardArea'

type Body =
  | { kind: 'rect'; x: number; y: number; width: number; height: number }
  | { kind: 'path'; d: string }
  | { kind: 'circle'; cx: number; cy: number; r: number }

// Each area is the system diagram's shape for it: a window, a cylinder, a server rack, a chevron, a box with an arrow
// leaving it, a person, and a stack of cards. Bodies get a solid plate and a dithered fill; details draw over them.
const SYMBOLS: Record<CardArea, { bodies: Body[]; details: ReactNode; dashed?: true }> = {
  interface: {
    bodies: [{ kind: 'rect', x: 5, y: 9, width: 38, height: 30 }],
    details: (
      <>
        <path className="trading-symbol-line" d="M5 17h38" />
        {[11, 16, 21].map((x) => (
          <circle key={x} className="trading-symbol-dot" cx={x} cy="13" r="1.5" />
        ))}
      </>
    ),
  },
  store: {
    bodies: [{ kind: 'path', d: 'M9 12v24c0 2.8 6.7 5 15 5s15-2.2 15-5V12c0-2.8-6.7-5-15-5S9 9.2 9 12Z' }],
    details: <path className="trading-symbol-line" d="M9 12c0 2.8 6.7 5 15 5s15-2.2 15-5M9 24c0 2.8 6.7 5 15 5s15-2.2 15-5" />,
  },
  service: {
    bodies: [
      { kind: 'rect', x: 7, y: 8, width: 34, height: 13 },
      { kind: 'rect', x: 7, y: 27, width: 34, height: 13 },
    ],
    details: (
      <>
        <circle className="trading-symbol-dot" cx="13" cy="14.5" r="1.8" />
        <circle className="trading-symbol-dot" cx="13" cy="33.5" r="1.8" />
        <path className="trading-symbol-line" d="M19 14.5h16M19 33.5h16" />
      </>
    ),
  },
  process: {
    bodies: [{ kind: 'path', d: 'M5 11h25l12 13-12 13H5l12-13Z' }],
    details: null,
  },
  external: {
    bodies: [{ kind: 'rect', x: 5, y: 13, width: 29, height: 29 }],
    details: <path className="trading-symbol-line" d="M27 6h15v15M42 6 21 27" />,
    dashed: true,
  },
  actor: {
    bodies: [
      { kind: 'circle', cx: 24, cy: 15, r: 8 },
      { kind: 'path', d: 'M8 43c0-8.8 7.2-15 16-15s16 6.2 16 15Z' },
    ],
    details: null,
  },
  queue: {
    bodies: [
      { kind: 'rect', x: 15, y: 5, width: 28, height: 20 },
      { kind: 'rect', x: 10, y: 13, width: 28, height: 20 },
      { kind: 'rect', x: 5, y: 21, width: 28, height: 20 },
    ],
    details: null,
  },
}

function drawBody(body: Body, className: string, extra: Record<string, string> = {}) {
  if (body.kind === 'rect') return <rect className={className} x={body.x} y={body.y} width={body.width} height={body.height} rx="3" {...extra} />

  if (body.kind === 'circle') return <circle className={className} cx={body.cx} cy={body.cy} r={body.r} {...extra} />

  return <path className={className} d={body.d} {...extra} />
}

/** The part of a system a card touches, drawn large over its art so a glance tells cards apart. */
export function TradingAreaSymbol({ area }: { area: CardArea }) {
  const ditherId = useId()
  const symbol = SYMBOLS[area]

  return (
    <svg className={`trading-symbol trading-symbol-${area}`} viewBox="0 0 48 48" role="img">
      <title>{AREA_LABEL[area]}</title>
      <defs>
        <pattern id={ditherId} width="3" height="3" patternUnits="userSpaceOnUse">
          <rect width="1.5" height="1.5" />
          <rect x="1.5" y="1.5" width="1.5" height="1.5" />
        </pattern>
      </defs>
      {symbol.bodies.map((body, index) => (
        <g key={index}>
          {drawBody(body, 'trading-symbol-halo')}
          {drawBody(body, 'trading-symbol-plate')}
          {drawBody(body, 'trading-symbol-dither', { fill: `url(#${ditherId})` })}
          {drawBody(body, `trading-symbol-edge${symbol.dashed ? ' trading-symbol-dashed' : ''}`)}
        </g>
      ))}
      {symbol.details}
    </svg>
  )
}
