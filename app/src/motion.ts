import { useSyncExternalStore } from 'react'
import { readDurationMs } from './readDurationMs'

export type Motion = 'on' | 'reduced' | 'off'

const REDUCE_QUERY = '(prefers-reduced-motion: reduce)'

/** The motion the computer asks for, which Orion follows until a level is picked in Accessibility. */
export function systemMotion(): Motion {
  return window.matchMedia(REDUCE_QUERY).matches ? 'reduced' : 'on'
}

function subscribeSystemMotion(onChange: () => void) {
  const query = window.matchMedia(REDUCE_QUERY)

  query.addEventListener('change', onChange)

  return () => query.removeEventListener('change', onChange)
}

/** The computer's motion, updating when its reduced motion setting changes. */
export function useSystemMotion(): Motion {
  return useSyncExternalStore(subscribeSystemMotion, systemMotion)
}

/** Whether motion should stop, because Animations is Reduced or Off. */
export function motionReduced(): boolean {
  return document.documentElement.dataset.motion !== 'on'
}

/** How long a camera or layout move takes: its duration, or an instant jump when motion is reduced. */
export function glide(duration: number): number {
  return motionReduced() ? 0 : duration
}

/** How long the camera takes to pan or zoom, from `motion.duration.camera`. */
export function cameraGlide(): number {
  return glide(readDurationMs('--motion-duration-camera', 450))
}

/** How long the camera takes to head for a card it's focusing, from `motion.duration.camera-focus`. */
export function focusGlide(): number {
  return glide(readDurationMs('--motion-duration-camera-focus', 260))
}
