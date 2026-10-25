import { useEffect, useRef } from 'react'

/** A date picked from a date field in the menu; `run` gets it as YYYY-MM-DD. `min` is the earliest date allowed. */
export type MenuDate = { label: string; min: string; run: (date: string) => void }

export type MenuItem = { label: string; hint?: string; danger?: boolean; run: () => void } | MenuDate | 'divider'

const isDate = (item: Exclude<MenuItem, 'divider'>): item is MenuDate => 'min' in item

type Props = { x: number; y: number; items: MenuItem[]; close: () => void }

export function ContextMenu({ x, y, items, close }: Props) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const away = (event: Event) => {
      if (!ref.current?.contains(event.target as Node)) close()
    }

    const key = (event: KeyboardEvent) => event.key === 'Escape' && close()

    window.addEventListener('pointerdown', away, true)
    window.addEventListener('wheel', close, { passive: true })
    window.addEventListener('keydown', key)
    ref.current?.querySelector('button')?.focus()

    return () => {
      window.removeEventListener('pointerdown', away, true)
      window.removeEventListener('wheel', close)
      window.removeEventListener('keydown', key)
    }
  }, [close])

  // Keep the menu on screen near the edges.
  const left = Math.min(x, window.innerWidth - 230)
  const top = Math.min(y, window.innerHeight - (items.length * 32 + 16))

  return (
    <div ref={ref} className="menu panel" role="menu" style={{ left, top }}>
      {items.map((item, i) => {
        if (item === 'divider') return <hr key={i} />

        if (isDate(item))
          return (
            <label key={i} className="menu-date">
              <span>{item.label}</span>
              <input
                type="date"
                min={item.min}
                aria-label={item.label}
                onChange={(event) => {
                  const date = event.target.value

                  if (!date) return

                  close()
                  item.run(date)
                }}
              />
            </label>
          )

        return (
          <button
            key={i}
            type="button"
            role="menuitem"
            className={item.danger ? 'danger' : undefined}
            onClick={() => {
              close()
              item.run()
            }}
          >
            <span>{item.label}</span>
            {item.hint && <kbd>{item.hint}</kbd>}
          </button>
        )
      })}
    </div>
  )
}
