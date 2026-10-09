import { calm, flame, type Tongue } from '../blocker'

/**
 * Tongues of fire, each flickering out of step with the rest. SVG animation repaints rather than composites, which
 * keeps WebKit from rasterizing the zoomed canvas as one blurry layer.
 */
export function BlockerFlames({ tongues, offset }: { tongues: Tongue[]; offset: number }) {
  return (
    <g className="blocker-fire">
      {tongues.map(([x, base, width, height, seconds], index) => (
        <path key={index} d={flame(x, base, width, height, -1)}>
          {!calm && (
            <animate
              attributeName="d"
              dur={`${seconds}s`}
              begin={`-${((offset + index) * 0.13) % seconds}s`}
              repeatCount="indefinite"
              values={[
                flame(x, base, width, height, -1),
                flame(x, base, width * 0.9, height * 0.8, 1.2),
                flame(x, base, width * 1.05, height * 1.12, -0.6),
                flame(x, base, width, height * 0.9, 0.8),
                flame(x, base, width, height, -1),
              ].join(';')}
            />
          )}
        </path>
      ))}
    </g>
  )
}
