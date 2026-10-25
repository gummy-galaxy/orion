import { useEffect } from 'react'
import { useSetAtom } from 'jotai'
import { inspectingAtom } from './state'

/** A short delay keeps Ctrl shortcuts from flashing inspect mode on. */
const INSPECT_DELAY_MS = 150

/**
 * Holding Ctrl turns on inspect mode. Another key, a click, or a drag turns it off, so Ctrl
 * shortcuts and Ctrl-dragging past snaps never start it.
 */
export function useInspecting() {
  const setInspecting = useSetAtom(inspectingAtom)

  useEffect(() => {
    let timer: ReturnType<typeof setTimeout> | undefined
    let pressed = false

    const stop = () => {
      clearTimeout(timer)
      setInspecting(false)
    }

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Control' || event.metaKey || event.altKey || event.shiftKey) return stop()

      if (event.repeat || pressed) return

      timer = setTimeout(() => setInspecting(true), INSPECT_DELAY_MS)
    }

    const onKeyUp = (event: KeyboardEvent) => event.key === 'Control' && stop()

    const onPointerDown = () => {
      pressed = true
      stop()
    }

    const onPointerUp = () => (pressed = false)

    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    window.addEventListener('blur', stop)
    window.addEventListener('pointerdown', onPointerDown)
    window.addEventListener('pointerup', onPointerUp)

    return () => {
      clearTimeout(timer)
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
      window.removeEventListener('blur', stop)
      window.removeEventListener('pointerdown', onPointerDown)
      window.removeEventListener('pointerup', onPointerUp)
    }
  }, [setInspecting])
}
