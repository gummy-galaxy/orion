import { useEffect, useRef } from 'react'
import { TELEMETRY_EVENTS_URL } from '../telemetry'

type Props = {
  choose: (enabled: boolean) => void
  /** Closes the dialog for this launch without an answer, so it asks again next time. */
  dismiss: () => void
}

/** Asks once, on launch, whether this machine shares anonymous usage data. Settings changes the answer later. */
export function TelemetryPrompt({ choose, dismiss }: Props) {
  const dialog = useRef<HTMLDivElement>(null)

  // Focuses the dialog rather than either answer, so Enter can't pick one without a look.
  useEffect(() => {
    dialog.current?.focus()
  }, [])

  // Keys stay inside the dialog, so the canvas behind it doesn't act on them.
  const onKeyDown = (event: React.KeyboardEvent) => {
    event.stopPropagation()

    if (event.key === 'Escape') dismiss()
  }

  return (
    <div className="settings-backdrop">
      <div
        ref={dialog}
        className="telemetry-prompt panel"
        role="dialog"
        aria-modal="true"
        aria-labelledby="telemetry-prompt-title"
        aria-describedby="telemetry-prompt-detail"
        tabIndex={-1}
        onKeyDown={onKeyDown}
      >
        <h2 id="telemetry-prompt-title">Help make Orion faster?</h2>
        <div id="telemetry-prompt-detail">
          <p>
            Orion can share anonymous usage data: how long the canvas takes to draw, how big canvases get, and which tools and commands get used. It
            never includes titles, notes, links, repository names, or file paths.
          </p>
          <p>
            <a href={TELEMETRY_EVENTS_URL} target="_blank" rel="noreferrer">
              See every event Orion sends
            </a>
            . You can change this any time in Settings.
          </p>
        </div>
        {/* The answers carry equal weight, so neither reads as the expected one. */}
        <div className="telemetry-prompt-actions">
          <button type="button" onClick={() => choose(false)}>
            No thanks
          </button>
          <button type="button" onClick={() => choose(true)}>
            Share usage data
          </button>
        </div>
      </div>
    </div>
  )
}
