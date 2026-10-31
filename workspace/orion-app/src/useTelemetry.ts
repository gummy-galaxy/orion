import { useCallback, useEffect, useState } from 'react'
import { chooseTelemetry, readTelemetry, type TelemetryStatus } from './telemetry'

/**
 * The machine's telemetry choice, read once on launch, and a way to record a new one. A choice the server fails to save
 * leaves the status as it was, so the dialog asks again next launch rather than showing an answer that didn't stick.
 */
export function useTelemetry(): [TelemetryStatus | null, (enabled: boolean) => void] {
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

  return [status, choose]
}
