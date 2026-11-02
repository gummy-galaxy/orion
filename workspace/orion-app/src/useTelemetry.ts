import { useCallback, useEffect, useState } from 'react'
import { chooseTelemetry, deleteTelemetryData, readTelemetry, type TelemetryStatus } from './telemetry'

/**
 * The machine's telemetry choice, read once on launch, a way to record a new one, and a way to delete what it shared.
 * A choice the server fails to save leaves the status as it was, so the dialog asks again next launch rather than
 * showing an answer that didn't stick.
 *
 * Deleting resolves once the data is deleted and rejects with the reason when it isn't, for Settings to show. The
 * server turns sharing off before it asks the backend, so a deletion that fails there still changes the choice, and
 * the status is read again after any failure.
 */
export function useTelemetry(): [TelemetryStatus | null, (enabled: boolean) => void, () => Promise<void>] {
  const [status, setStatus] = useState<TelemetryStatus | null>(null)

  useEffect(() => {
    let current = true

    void readTelemetry().then((read) => current && setStatus(read))

    return () => {
      current = false
    }
  }, [])

  const choose = useCallback((enabled: boolean) => {
    chooseTelemetry(enabled).then(setStatus, (error: unknown) =>
      console.error('Could not save the telemetry choice', error),
    )
  }, [])

  const deleteShared = useCallback(async () => {
    try {
      setStatus(await deleteTelemetryData())
    } catch (error) {
      void readTelemetry().then(setStatus)
      throw error
    }
  }, [])

  return [status, choose, deleteShared]
}
