import { useEffect, useRef, useState, type ReactNode } from 'react'
import 'hover-tilt/web-component'

/** Tips a card toward the pointer while it's held, then lets it lie flat again so the zoomed canvas stays sharp. */
export function CardTilt({ children }: { children: ReactNode }) {
  const [settling, setSettling] = useState(false)
  const timer = useRef<number>(undefined)

  useEffect(() => () => clearTimeout(timer.current), [])

  return (
    <hover-tilt
      className={`tilt${settling ? ' settling' : ''}`}
      tilt-factor={0.6}
      scale-factor={1.04}
      exit-delay={60}
      glare-intensity={0}
      shadow
      onPointerEnter={() => {
        clearTimeout(timer.current)
        setSettling(false)
      }}
      onPointerLeave={() => {
        setSettling(true)
        timer.current = window.setTimeout(() => setSettling(false), 700)
      }}
    >
      {children}
    </hover-tilt>
  )
}
