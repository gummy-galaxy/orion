import { useEffect, useState } from 'react'

const KEY_LABELS: Record<string, string> = { Shift: '⇧', Alt: '⌥', Meta: '⌘', Control: '⌃', ' ': 'Space', Escape: 'Esc' }

const BUTTON_CLASSES = ['is-left', 'is-middle', 'is-right']

/** A drawn pointer and held keys, so a headless recording shows what the hand is doing. */
export function SpikePointer() {
  const [pointer, setPointer] = useState({ x: -100, y: -100, button: -1 })
  const [keys, setKeys] = useState<string[]>([])

  useEffect(() => {
    const move = (event: PointerEvent) => setPointer((current) => ({ ...current, x: event.clientX, y: event.clientY }))
    const down = (event: PointerEvent) => setPointer({ x: event.clientX, y: event.clientY, button: event.button })
    const up = (event: PointerEvent) => setPointer({ x: event.clientX, y: event.clientY, button: -1 })

    const keyDown = (event: KeyboardEvent) => {
      const label = KEY_LABELS[event.key] ?? event.key.toUpperCase()

      setKeys((current) => (current.includes(label) ? current : [...current, label]))
    }

    const keyUp = (event: KeyboardEvent) => {
      const label = KEY_LABELS[event.key] ?? event.key.toUpperCase()

      // A lone key press is gone before the next frame, so let it linger long enough to read.
      setTimeout(() => setKeys((current) => current.filter((key) => key !== label)), 350)
    }

    window.addEventListener('pointermove', move, true)
    window.addEventListener('pointerdown', down, true)
    window.addEventListener('pointerup', up, true)
    window.addEventListener('keydown', keyDown, true)
    window.addEventListener('keyup', keyUp, true)

    return () => {
      window.removeEventListener('pointermove', move, true)
      window.removeEventListener('pointerdown', down, true)
      window.removeEventListener('pointerup', up, true)
      window.removeEventListener('keydown', keyDown, true)
      window.removeEventListener('keyup', keyUp, true)
    }
  }, [])

  return (
    <>
      <div className={['spike-pointer', BUTTON_CLASSES[pointer.button]].filter(Boolean).join(' ')} style={{ left: pointer.x, top: pointer.y }} />
      {keys.length > 0 && <div className="spike-keys">{keys.join(' ')}</div>}
    </>
  )
}
