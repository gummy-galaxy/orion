import { useRef, type KeyboardEvent, type PointerEvent } from 'react'

const KEY_STEP = 16

const clamp = (value: number, minimum: number, maximum: number) => Math.round(Math.max(minimum, Math.min(maximum, value)))

/**
 * A splitter between a side panel and the canvas. Dragging it, or pressing the arrow keys while it has focus, sets the
 * panel's width, and a double-click puts the panel back at its default width.
 */
export function ResizeHandle({
  panel,
  label,
  min,
  max,
  resize,
  reset,
}: {
  /** Which side of the handle the panel is on. */
  panel: 'before' | 'after'
  label: string
  min: number
  max: number
  /** Sets the width live while dragging, with `done` set once the drag ends. */
  resize: (width: number, done: boolean) => void
  reset: () => void
}) {
  const drag = useRef<{ x: number; width: number; latest: number } | null>(null)
  const direction = panel === 'before' ? 1 : -1

  const panelWidth = (handle: HTMLElement) => {
    const element = panel === 'before' ? handle.previousElementSibling : handle.nextElementSibling

    return element?.getBoundingClientRect().width ?? min
  }

  const start = (event: PointerEvent<HTMLDivElement>) => {
    if (event.button !== 0) return

    const width = panelWidth(event.currentTarget)

    event.preventDefault()
    event.currentTarget.setPointerCapture(event.pointerId)
    drag.current = { x: event.clientX, width, latest: width }
  }

  const move = (event: PointerEvent<HTMLDivElement>) => {
    if (!drag.current) return

    const width = clamp(drag.current.width + (event.clientX - drag.current.x) * direction, min, max)

    if (width === drag.current.latest) return

    drag.current.latest = width
    resize(width, false)
  }

  const end = () => {
    if (!drag.current) return

    // A click without a drag, such as half of a double-click, keeps the default width instead of saving it.
    if (drag.current.latest !== drag.current.width) resize(drag.current.latest, true)

    drag.current = null
  }

  const nudge = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.key === 'ArrowRight' ? KEY_STEP : event.key === 'ArrowLeft' ? -KEY_STEP : 0

    if (!step) return

    event.preventDefault()
    resize(clamp(panelWidth(event.currentTarget) + step * direction, min, max), true)
  }

  return (
    <div
      className="resize-handle"
      role="separator"
      aria-orientation="vertical"
      aria-label={label}
      title={`${label}. Double-click to reset.`}
      tabIndex={0}
      onPointerDown={start}
      onPointerMove={move}
      onPointerUp={end}
      onPointerCancel={end}
      onDoubleClick={reset}
      onKeyDown={nudge}
    />
  )
}
