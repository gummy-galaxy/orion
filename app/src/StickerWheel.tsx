import { useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react'
import { WHEEL_SLOTS, firstEmoji, type Loadout } from './sticker'

type StickerPoint = { x: number; y: number }

const WHEEL_RADIUS = 72
const WHEEL_EDGE = 120
const HUB_RADIUS = 30

/**
 * Picks a sticker. Opened by holding S, it follows FigJam: point at one and let go.
 * A quick tap leaves it open, as does opening it from the toolbar, and then any
 * emoji typed or pasted into the middle is loaded. Right-clicking a slot, or
 * clicking an empty one, fills it with the next emoji instead.
 */
export function StickerWheel({
  at,
  held,
  current,
  loadout,
  pick,
  assign,
  close,
}: {
  at: StickerPoint
  held: boolean
  current: string
  loadout: Loadout
  pick: (emoji: string) => void
  assign: (slot: number, emoji: string | null) => void
  close: () => void
}) {
  const [hover, setHover] = useState<number | null>(null)
  const [holding, setHolding] = useState(held)
  const [filling, setFilling] = useState<number | null>(null)
  const field = useRef<HTMLInputElement>(null)
  const center = {
    x: Math.max(WHEEL_EDGE, Math.min(window.innerWidth - WHEEL_EDGE, at.x)),
    y: Math.max(WHEEL_EDGE, Math.min(window.innerHeight - WHEEL_EDGE, at.y)),
  }

  const choose = (slot: number) => {
    const emoji = loadout[slot]
    if (emoji) return pick(emoji)
    setHolding(false)
    setFilling(slot)
  }
  const latest = useRef({ hover, holding, filling, choose, assign, close })
  useLayoutEffect(() => {
    latest.current = { hover, holding, filling, choose, assign, close }
  })

  useEffect(() => {
    if (!holding) field.current?.focus()
  }, [holding, filling])

  useEffect(() => {
    const opened = performance.now()
    const down = (event: KeyboardEvent) => {
      const { hover, filling, choose, assign, close } = latest.current
      const digit = Number(event.key)
      if (event.key === 'Escape') {
        if (filling !== null) setFilling(null)
        else close()
      } else if (/^[1-9]$/.test(event.key) && digit <= WHEEL_SLOTS) choose(digit - 1)
      else if (event.key === 'Enter' && hover !== null) choose(hover)
      else if ((event.key === 'Backspace' || event.key === 'Delete') && filling !== null) {
        assign(filling, null)
        setFilling(null)
      } else if (event.key.toLowerCase() !== 's' || event.target === field.current) return
      event.preventDefault()
      event.stopImmediatePropagation()
    }
    const up = (event: KeyboardEvent) => {
      const { hover, holding, choose, close } = latest.current
      if (!holding || event.key.toLowerCase() !== 's') return
      if (hover !== null) choose(hover)
      else if (performance.now() - opened > 350) close()
      else setHolding(false)
    }
    window.addEventListener('keydown', down, { capture: true })
    window.addEventListener('keyup', up)
    return () => {
      window.removeEventListener('keydown', down, { capture: true })
      window.removeEventListener('keyup', up)
    }
  }, [])

  const track = (event: React.PointerEvent) => {
    const deltaX = event.clientX - center.x
    const deltaY = event.clientY - center.y
    const distance = Math.hypot(deltaX, deltaY)
    if (distance < HUB_RADIUS || distance > WHEEL_EDGE * 1.6) return setHover(null)
    const turn = (Math.atan2(deltaX, -deltaY) / (2 * Math.PI) + 1) % 1
    setHover(Math.round(turn * WHEEL_SLOTS) % WHEEL_SLOTS)
  }

  const typed = (text: string) => {
    const emoji = firstEmoji(text)
    if (!emoji) return
    if (filling === null) return pick(emoji)
    assign(filling, emoji)
    setFilling(null)
  }

  return (
    <div
      className="wheel-backdrop"
      onPointerMove={track}
      onPointerDown={(event) => event.target === event.currentTarget && close()}
      onContextMenu={(event) => {
        event.preventDefault()
        close()
      }}
    >
      <div className="wheel" style={{ left: center.x, top: center.y }} role="menu" aria-label="Stickers">
        {loadout.map((emoji, i) => {
          const angle = (i / WHEEL_SLOTS) * 2 * Math.PI
          const classes = [
            'wheel-item',
            emoji ? '' : 'empty',
            hover === i ? 'hover' : '',
            emoji === current ? 'current' : '',
            filling === i ? 'filling' : '',
          ]
          return (
            <button
              key={i}
              type="button"
              role="menuitem"
              className={classes.filter(Boolean).join(' ')}
              style={{ '--x': `${Math.sin(angle) * WHEEL_RADIUS}px`, '--y': `${-Math.cos(angle) * WHEEL_RADIUS}px`, '--i': i } as CSSProperties}
              title={emoji ? `${emoji} (${i + 1}), right-click to change` : `Empty slot (${i + 1}), click to fill`}
              aria-label={emoji ?? `Empty slot ${i + 1}`}
              onClick={() => choose(i)}
              onContextMenu={(event) => {
                event.preventDefault()
                event.stopPropagation()
                setHolding(false)
                setFilling(i)
              }}
            >
              {emoji}
            </button>
          )
        })}
        <input
          ref={field}
          className="wheel-hub"
          value=""
          placeholder={filling === null ? 'any emoji' : `slot ${filling + 1}`}
          aria-label={filling === null ? 'Stamp any emoji' : `Emoji for slot ${filling + 1}`}
          onChange={(event) => typed(event.target.value)}
        />
        {!holding && (
          <p className="wheel-tip">
            {filling === null
              ? 'Type or paste any emoji, or ⌃⌘Space for all of them. Right-click a slot to change it.'
              : `Type or paste an emoji for slot ${filling + 1}. ⌫ empties it, Esc cancels.`}
          </p>
        )}
      </div>
    </div>
  )
}
