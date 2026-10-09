import { EMBERS, calm } from '../blocker'

/** Sparks drifting up out of the doorway. */
export function BlockerEmbers() {
  if (calm) return null

  return (
    <g className="blocker-fire-embers">
      {EMBERS.map(([x, drift, seconds, into], index) => {
        const timing = { dur: `${seconds}s`, begin: `-${into}s`, repeatCount: 'indefinite' }

        return (
          <circle key={index} cx={x} cy={-14} r={0.7}>
            <animate attributeName="cy" values="-14;-38" {...timing} />
            <animate attributeName="cx" values={`${x};${x + drift};${x - drift / 2}`} {...timing} />
            <animate attributeName="r" values="0.8;0.6;0.15" {...timing} />
            <animate attributeName="fill-opacity" values="0;1;0.8;0" {...timing} />
          </circle>
        )
      })}
    </g>
  )
}
