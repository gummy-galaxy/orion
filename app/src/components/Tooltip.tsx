import { cloneElement, useEffect, useId, useState, type FocusEvent, type PointerEvent, type ReactElement } from 'react'
import { createPortal } from 'react-dom'

/** How long the pointer rests on something before its tooltip shows. */
const DELAY_MS = 350
const GAP = 8

type AnchorProps = {
  onPointerEnter?: (event: PointerEvent<HTMLElement>) => void
  onPointerLeave?: (event: PointerEvent<HTMLElement>) => void
  onFocus?: (event: FocusEvent<HTMLElement>) => void
  onBlur?: (event: FocusEvent<HTMLElement>) => void
  'aria-describedby'?: string
}

/**
 * Shows a label above its one child on hover or focus. It renders into the page body at a fixed size,
 * so a card's clipping and the canvas zoom don't affect it.
 */
export function Tooltip({ label, children }: { label: string; children: ReactElement<AnchorProps> }) {
  const id = useId()
  const [hovered, setHovered] = useState<{ target: HTMLElement; wait: number } | null>(null)
  const [at, setAt] = useState<{ x: number; y: number } | null>(null)

  useEffect(() => {
    if (!hovered) return

    const timer = window.setTimeout(() => {
      const box = hovered.target.getBoundingClientRect()

      setAt({ x: box.left + box.width / 2, y: box.top - GAP })
    }, hovered.wait)

    return () => window.clearTimeout(timer)
  }, [hovered])

  const show = (target: HTMLElement, wait: number) => setHovered({ target, wait })

  const hide = () => {
    setHovered(null)
    setAt(null)
  }

  const anchor = cloneElement(children, {
    onPointerEnter: (event) => {
      children.props.onPointerEnter?.(event)
      show(event.currentTarget, DELAY_MS)
    },
    onPointerLeave: (event) => {
      children.props.onPointerLeave?.(event)
      hide()
    },
    onFocus: (event) => {
      children.props.onFocus?.(event)
      show(event.currentTarget, 0)
    },
    onBlur: (event) => {
      children.props.onBlur?.(event)
      hide()
    },
    'aria-describedby': at ? id : undefined,
  })

  return (
    <>
      {anchor}
      {at &&
        createPortal(
          <div id={id} role="tooltip" className="tooltip" style={{ left: at.x, top: at.y }}>
            {label}
          </div>,
          document.body,
        )}
    </>
  )
}
