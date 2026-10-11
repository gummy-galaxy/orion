/** Whether motion should stop, because Animations is off in Orion or the computer asks to reduce motion. */
export function motionReduced(): boolean {
  return document.documentElement.dataset.animations === 'off' || window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

/** How long a camera or layout move takes: its duration, or an instant jump when motion is reduced. */
export function glide(duration: number): number {
  return motionReduced() ? 0 : duration
}
