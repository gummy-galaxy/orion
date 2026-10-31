import { CompanionEye } from './CompanionEye'

// The logo's four-pointed star: long vertical points, shorter side points, and a round core.
const VERTICAL = 182
const HORIZONTAL = 104
const WAIST = 24
const OUTLINE = [
  [0, -VERTICAL],
  [WAIST, -WAIST],
  [HORIZONTAL, 0],
  [WAIST, WAIST],
  [0, VERTICAL],
  [-WAIST, WAIST],
  [-HORIZONTAL, 0],
  [-WAIST, -WAIST],
]
const OUTLINE_PATH = `M${OUTLINE.map((point) => point.join(' ')).join(' L')} Z`

/** A star of the companion: the body with a face, or a plain side star. */
export function CompanionStar({ face = false }: { face?: boolean }) {
  const coreRadius = face ? 66 : 46

  return (
    <svg viewBox="-110 -190 220 380" aria-hidden="true">
      {/* The edge draws the shape again with a wide stroke underneath, so the outline traces the points and core
          as one. */}
      <g className="companion-edge">
        <path d={OUTLINE_PATH} />
        <circle r={coreRadius} />
      </g>
      <g className="companion-fill">
        <path d={OUTLINE_PATH} />
        <circle r={coreRadius} />
      </g>
      {face && (
        <g
          className="eyes"
          fill="none"
          stroke="currentColor"
          strokeWidth={11}
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <CompanionEye side="l" x={-24} />
          <CompanionEye side="r" x={24} />
        </g>
      )}
    </svg>
  )
}
