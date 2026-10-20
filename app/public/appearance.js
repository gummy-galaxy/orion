// Applies the cached appearance before the first paint. Loaded as a file, not inline, so the content
// security policy can refuse inline scripts. Mirrors applyAppearance in src/appearance.ts.
try {
  const mode = localStorage.getItem('orion:color-mode')
  // Vibrant and Trading cards are the defaults, for an empty choice as well as a missing one.
  const theme = localStorage.getItem('orion:theme') || 'vibrant'
  const skin = localStorage.getItem('orion:skin') || 'trading'
  const statusColors = localStorage.getItem('orion:status-colors')
  const animations = localStorage.getItem('orion:animations')

  if (mode === 'light' || mode === 'dark') document.documentElement.dataset.colorMode = mode

  if (theme !== 'classic') document.documentElement.dataset.theme = theme

  if (skin !== 'trading') document.documentElement.dataset.skin = skin

  if (statusColors === 'red-green' || statusColors === 'blue-yellow') document.documentElement.dataset.statusColors = statusColors

  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches

  document.documentElement.dataset.motion = ['on', 'reduced', 'off'].includes(animations) ? animations : reduce ? 'reduced' : 'on'
} catch {
  // Storage can be unavailable; use the default theme.
  document.documentElement.dataset.theme = 'vibrant'
}
