import { ControlButton } from '@xyflow/react'
import { withChord, type Keybindings } from '../keybindings'

type Props = { level: number; levels: number; keybindings: Keybindings; change: (direction: -1 | 1) => void }

/** Steps through levels of nesting beside the zoom controls, with the level showing between the buttons. */
export function DetailStepper({ level, levels, keybindings, change }: Props) {
  return (
    <>
      <ControlButton
        className="detail-step"
        title={withChord('Less detail', keybindings['less-detail'])}
        aria-label="Less detail"
        disabled={level <= 1}
        onClick={() => change(-1)}
      >
        <svg viewBox="0 0 16 16" aria-hidden="true">
          <rect x="2.5" y="2.5" width="11" height="11" rx="2" />
        </svg>
      </ControlButton>
      <div className="detail-level" title={`Detail: ${level} of ${levels} levels of nesting`} aria-live="polite">
        {level}/{levels}
      </div>
      <ControlButton
        className="detail-step"
        title={withChord('More detail', keybindings['more-detail'])}
        aria-label="More detail"
        disabled={level >= levels}
        onClick={() => change(1)}
      >
        <svg viewBox="0 0 16 16" aria-hidden="true">
          <rect x="2.5" y="2.5" width="11" height="11" rx="2" />
          <rect x="5.5" y="5.5" width="5" height="5" rx="1" />
        </svg>
      </ControlButton>
    </>
  )
}
