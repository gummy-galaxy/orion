import { useState } from 'react'
import { StartPlace } from './StartPlace'
import type { StartOptions } from '../sessions/types'

/** The inspector's way to hand a card's work to an agent: one button per preset that fits the card. */
export function StartSession({
  options,
  start,
}: {
  options: StartOptions
  /** Starts a session with the preset, resolving once the agent's app has the prompt. */
  start: (preset: string) => Promise<void>
}) {
  const [starting, setStarting] = useState<string | null>(null)
  const [outcome, setOutcome] = useState<{ ok: boolean; text: string } | null>(null)
  const agent = options.agent
  const ready = !options.problem

  return (
    <section className="insp-section start-session" aria-label="Agent session">
      <h3 className="insp-heading">Agent</h3>
      <div className="start-session-presets">
        {options.presets.map((preset) => (
          <button
            key={preset.id}
            type="button"
            className={preset.id === 'work' ? 'btn' : 'btn primary'}
            disabled={!ready || starting !== null}
            onClick={() => {
              setStarting(preset.id)
              setOutcome(null)
              start(preset.id)
                .then(() => setOutcome({ ok: true, text: `Opened ${agent}. Send the prompt there to start.` }))
                .catch((error: unknown) => setOutcome({ ok: false, text: error instanceof Error ? error.message : String(error) }))
                .finally(() => setStarting(null))
            }}
          >
            {starting === preset.id ? 'Opening…' : preset.label}
          </button>
        ))}
      </div>
      <p className="facts" role={outcome && !outcome.ok ? 'alert' : undefined}>
        {outcome?.text ?? options.problem ?? <StartPlace options={options} />}
      </p>
    </section>
  )
}
