import type { ComponentShape } from '../model'

/** Half the outline's stroke, so it sits inside the card's box. */
const INSET = 0.75
/** How deep a store's elliptical lid and base are. */
const LID = 8
/** How far a process's chevron points out. */
const POINT = 14
/** How far each card behind a queue's front card is offset. */
const STACK = 4

/** The outline behind a component card's text, drawn for its shape at the card's size. */
export function ShapeOutline({
  shape = 'service',
  width,
  height,
}: {
  shape?: ComponentShape
  width: number
  height: number
}) {
  const right = width - INSET
  const bottom = height - INSET
  const radius = (width - INSET * 2) / 2
  let body

  switch (shape) {
    case 'store':
      body = (
        <>
          <path
            className="shape-body"
            d={
              `M${INSET},${LID} V${bottom - LID} A${radius},${LID} 0 0 0 ${right},${bottom - LID} ` +
              `V${LID} A${radius},${LID} 0 0 0 ${INSET},${LID} Z`
            }
          />
          <path className="shape-line" d={`M${INSET},${LID} A${radius},${LID} 0 0 0 ${right},${LID}`} />
        </>
      )
      break
    case 'actor':
      body = (
        <rect
          className="shape-body"
          x={INSET}
          y={INSET}
          width={width - INSET * 2}
          height={height - INSET * 2}
          rx={Math.min(36, height / 2 - INSET)}
        />
      )
      break
    case 'process':
      body = (
        <path
          className="shape-body"
          d={
            `M${INSET},${INSET} H${right - POINT} L${right},${height / 2} L${right - POINT},${bottom} ` +
            `H${INSET} L${POINT},${height / 2} Z`
          }
        />
      )
      break
    case 'queue':
      body = (
        <>
          {[2, 1, 0].map((step) => (
            <rect
              key={step}
              className="shape-body"
              x={INSET + step * STACK}
              y={INSET + (2 - step) * STACK}
              width={width - INSET * 2 - STACK * 2}
              height={height - INSET * 2 - STACK * 2}
              rx={7}
            />
          ))}
        </>
      )
      break
    case 'interface':
      body = (
        <>
          <rect
            className="shape-body"
            x={INSET}
            y={INSET}
            width={width - INSET * 2}
            height={height - INSET * 2}
            rx={7}
          />
          <path className="shape-line" d={`M${INSET},13 H${right}`} />
          {[10, 17, 24].map((x) => (
            <circle key={x} className="shape-dot" cx={x} cy={7} r={2} />
          ))}
        </>
      )
      break
    default:
      body = (
        <rect className="shape-body" x={INSET} y={INSET} width={width - INSET * 2} height={height - INSET * 2} rx={7} />
      )
  }

  return (
    <svg
      className={`shape-outline shape-${shape}`}
      viewBox={`0 0 ${width} ${height}`}
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      {body}
    </svg>
  )
}
