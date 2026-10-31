import { TELEMETRY_EVENTS_URL, type TelemetryStatus } from '../telemetry'

type Props = { telemetry: TelemetryStatus | null; chooseTelemetry: (enabled: boolean) => void }

/** Whether this machine shares anonymous usage data, the answer to the dialog shown on first launch. */
export function PrivacySettings({ telemetry, chooseTelemetry }: Props) {
  const choice = telemetry?.choice

  return (
    <section className="settings-section">
      <h3>Privacy</h3>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-telemetry">
            Share usage data
          </span>
          <p className="settings-field-detail">
            {telemetry === null
              ? 'Orion’s server isn’t running, so this can’t be changed here. Run orion telemetry on or off instead.'
              : telemetry.override
                ? `${telemetry.override} is set, so Orion sends nothing whatever is chosen here.`
                : 'Anonymous counts and timings that show where Orion is slow and which tools get used. ' +
                  'Never titles, notes, links, or file paths.'}{' '}
            <a href={TELEMETRY_EVENTS_URL} target="_blank" rel="noreferrer">
              See every event
            </a>
          </p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-telemetry">
          <button
            type="button"
            aria-pressed={choice === 'on'}
            disabled={telemetry === null}
            onClick={() => chooseTelemetry(true)}
          >
            On
          </button>
          <button
            type="button"
            aria-pressed={choice === 'off'}
            disabled={telemetry === null}
            onClick={() => chooseTelemetry(false)}
          >
            Off
          </button>
        </div>
      </div>
    </section>
  )
}
