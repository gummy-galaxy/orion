import { useState } from 'react'
import type { TelemetryStatus } from '../telemetry'

type Props = { telemetry: TelemetryStatus | null; deleteTelemetryData: () => Promise<void> }

type Step =
  | { kind: 'idle' }
  | { kind: 'confirming' }
  | { kind: 'deleting' }
  | { kind: 'deleted' }
  | { kind: 'failed'; reason: string }

/**
 * Deletes every event this machine has shared, separately from opting out, which only stops sending. Deleting can't be
 * undone, so the button asks once more before it goes ahead. A failure is shown, since the person asked for this and
 * can try again.
 */
export function DeleteUsageDataField({ telemetry, deleteTelemetryData }: Props) {
  const [step, setStep] = useState<Step>({ kind: 'idle' })
  const hasShared = telemetry?.installId !== undefined

  const confirm = () => {
    setStep({ kind: 'deleting' })
    deleteTelemetryData().then(
      () => setStep({ kind: 'deleted' }),
      (error: unknown) => setStep({ kind: 'failed', reason: error instanceof Error ? error.message : String(error) }),
    )
  }

  return (
    <div className="settings-field">
      <div>
        <span className="settings-field-label">Delete my usage data</span>
        <p className="settings-field-detail" role="status">
          {step.kind === 'deleted'
            ? 'Deleted. It can take a few days to disappear, and sharing is off.'
            : step.kind === 'confirming'
              ? 'This deletes everything this machine has shared and turns sharing off. It can’t be undone.'
              : telemetry === null
                ? 'Orion’s server isn’t running, so this can’t be done here. Run orion telemetry delete instead.'
                : hasShared
                  ? 'Removes everything this machine has shared, not just what it would send next.'
                  : 'This machine hasn’t shared anything, so there’s nothing to delete.'}
        </p>
        {step.kind === 'failed' && (
          <p className="settings-field-error" role="alert">
            Couldn’t delete it: {step.reason}. Try again later.
          </p>
        )}
      </div>
      <div className="options">
        {step.kind === 'confirming' ? (
          <>
            <button type="button" className="danger" onClick={confirm}>
              Delete
            </button>
            <button type="button" onClick={() => setStep({ kind: 'idle' })}>
              Cancel
            </button>
          </>
        ) : (
          <button
            type="button"
            className="danger"
            disabled={!hasShared || step.kind === 'deleting'}
            onClick={() => setStep({ kind: 'confirming' })}
          >
            {step.kind === 'deleting' ? 'Deleting…' : 'Delete'}
          </button>
        )}
      </div>
    </div>
  )
}
