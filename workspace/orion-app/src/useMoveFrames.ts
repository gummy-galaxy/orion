import { useCallback, useEffect, useMemo, useRef } from 'react'
import type { TelemetrySession } from './telemetry/createTelemetrySession'

type Move = { zoom: number; frame: number; last: number | null; gaps: number[] }

/**
 * Times frames while the camera moves, and files them as pan or zoom frames once it stops, depending on whether the
 * zoom changed. Call `start` and `end` from React Flow's move callbacks with the viewport's zoom.
 */
export function useMoveFrames(session: TelemetrySession): {
  start: (zoom: number) => void
  end: (zoom: number) => void
} {
  const move = useRef<Move | null>(null)

  const stop = useCallback(() => {
    if (move.current) cancelAnimationFrame(move.current.frame)

    const ended = move.current

    move.current = null

    return ended
  }, [])

  const start = useCallback(
    (zoom: number) => {
      stop()

      const current: Move = { zoom, frame: 0, last: null, gaps: [] }

      const tick = (time: number) => {
        if (current.last !== null) current.gaps.push(time - current.last)

        current.last = time
        current.frame = requestAnimationFrame(tick)
      }

      current.frame = requestAnimationFrame(tick)
      move.current = current
    },
    [stop],
  )

  const end = useCallback(
    (zoom: number) => {
      const ended = stop()

      if (!ended) return

      const metric = ended.zoom === zoom ? 'pan_frame' : 'zoom_frame'

      for (const gap of ended.gaps) session.record(metric, gap)
    },
    [session, stop],
  )

  useEffect(
    () => () => {
      stop()
    },
    [stop],
  )

  return useMemo(() => ({ start, end }), [start, end])
}
