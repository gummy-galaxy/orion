import { Handle, Position } from '@xyflow/react'
import { BLOCKER_HEIGHT, BLOCKER_WIDTH, CRACKS, CROWN, DOOR_FIRE, PILLAR_FIRE, SILL_FIRE, calm } from '../blocker'
import { BlockerEmbers } from './BlockerEmbers'
import { BlockerFlames } from './BlockerFlames'

/**
 * Stands in front of work that waits on work that can start now: arrows from that work flow into it, and one arrow
 * leaves it, still, for the card it holds back. Orion places it; it can't be selected, moved, or removed. A stone
 * gateway crowned with spikes, a portcullis down across a doorway full of fire.
 */
export function BlockerView() {
  return (
    <div className="blocker">
      <Handle type="target" position={Position.Left} isConnectable={false} />
      <svg width={BLOCKER_WIDTH} height={BLOCKER_HEIGHT} aria-hidden="true">
        <g transform={`translate(${BLOCKER_WIDTH / 2} ${BLOCKER_HEIGHT / 2}) scale(2)`}>
          <BlockerFlames tongues={PILLAR_FIRE} offset={0} />
          <path d={CROWN} className="blocker-stone" />
          <path d="M-11.5,-11H11.5V16H-11.5Z" className="blocker-stone" />
          <path d="M-16.5,-11h5v27h-5ZM11.5,-11h5v27h-5Z" className="blocker-stone" />
          <path d="M-18,-16H18V-11H-18Z" className="blocker-stone" />
          <path d="M-17.5,-12h7v2h-7ZM10.5,-12h7v2h-7ZM-17.5,13.5h7V16h-7ZM10.5,13.5h7V16h-7Z" className="blocker-trim" />
          <path d="M-18,-13.5H18" className="blocker-groove" />
          <path d="M-8.6,16V-2A8.6,8.6 0 0 1 8.6,-2V16" className="blocker-arch" />
          <path d="M-1.3,-11.4H1.3L0.9,-8.6H-0.9Z" className="blocker-trim" />
          <path d="M-7,16V-2A7,7 0 0 1 7,-2V16Z" className="blocker-mouth" />
          <BlockerFlames tongues={DOOR_FIRE} offset={6} />
          <path
            d="M-7,1.4H7V2.4H-7ZM-7,8H7V9H-7ZM-5.1,-6.8H-3.9V13L-4.5,15.5L-5.1,13ZM-2.1,-8.6H-0.9V13L-1.5,15.5L-2.1,13ZM0.9,-8.6H2.1V13L1.5,15.5L0.9,13ZM3.9,-6.8H5.1V13L4.5,15.5L3.9,13Z"
            className="blocker-bars"
          />
          <g className="blocker-cracks">
            {CRACKS.map(([d, seconds], index) => (
              <g key={index}>
                <path d={d} className="blocker-crack-glow" />
                <path d={d}>
                  {!calm && <animate attributeName="stroke-opacity" values="0.5;1;0.65;0.5" dur={`${seconds}s`} repeatCount="indefinite" />}
                </path>
              </g>
            ))}
          </g>
          <BlockerFlames tongues={SILL_FIRE} offset={10} />
          <BlockerEmbers />
        </g>
      </svg>
      <Handle type="source" position={Position.Right} isConnectable={false} />
    </div>
  )
}
