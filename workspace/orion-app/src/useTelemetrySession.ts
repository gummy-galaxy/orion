import { useEffect, useRef, useState } from 'react'
import { inDesktop } from './external'
import { sendTelemetryEvents } from './telemetry'
import { createTelemetrySession, type TelemetrySession } from './telemetry/createTelemetrySession'

/**
 * How often a stretch of the session is sent. The app can quit or crash without warning, so waiting for the end would
 * lose most of it.
 */
const STRETCH_MS = 5 * 60 * 1000

type CanvasSize = { card_count: number; group_count: number }

/**
 * Gathers this session's usage and hands it to the server every few minutes, when the page goes away, and when the
 * desktop app asks before quitting. The server drops it unless this machine shares usage data.
 */
export function useTelemetrySession(getSize: () => CanvasSize): TelemetrySession {
  const [session] = useState(createTelemetrySession)
  const getSizeRef = useRef(getSize)

  useEffect(() => {
    getSizeRef.current = getSize
  })

  useEffect(() => {
    const send = () => sendTelemetryEvents(session.takeEvents(getSizeRef.current()))
    const timer = setInterval(() => void send(), STRETCH_MS)
    const onPageHide = () => void send()
    let unlisten: (() => void) | undefined
    let stopped = false

    window.addEventListener('pagehide', onPageHide)

    // The desktop app waits for this answer, or a second, before it quits and stops the server.
    if (inDesktop()) {
      void Promise.all([import('@tauri-apps/api/event'), import('@tauri-apps/api/core')])
        .then(([{ listen }, { invoke }]) =>
          listen('orion://quitting', () => {
            void send().finally(() => invoke('telemetry_flushed').catch(() => undefined))
          }),
        )
        .then((stop) => {
          if (stopped) stop()
          else unlisten = stop
        })
        .catch(() => undefined)
    }

    return () => {
      stopped = true
      clearInterval(timer)
      window.removeEventListener('pagehide', onPageHide)
      unlisten?.()
    }
  }, [session])

  return session
}
