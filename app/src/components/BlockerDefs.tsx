/** Gradients every blocker shares. Render once, anywhere in the document. */
export function BlockerDefs() {
  return (
    <svg width="0" height="0" style={{ position: 'absolute' }} aria-hidden="true">
      <defs>
        <linearGradient id="orion-blocker-stone" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" style={{ stopColor: 'var(--blocker-stone-top)' }} />
          <stop offset="1" style={{ stopColor: 'var(--blocker-stone-bottom)' }} />
        </linearGradient>
        <radialGradient id="orion-blocker-mouth" cx="0.5" cy="1" r="1">
          <stop offset="0" style={{ stopColor: 'var(--blocker-glow-hot)' }} />
          <stop offset="0.4" style={{ stopColor: 'var(--blocker-glow)' }} />
          <stop offset="1" style={{ stopColor: 'var(--blocker-glow-deep)' }} />
        </radialGradient>
        <linearGradient id="orion-blocker-flame" x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" style={{ stopColor: 'var(--blocker-glow-hot)' }} />
          <stop offset="0.4" style={{ stopColor: 'var(--blocker-glow)' }} />
          <stop offset="0.8" style={{ stopColor: 'var(--blocker)' }} />
          <stop offset="1" style={{ stopColor: 'var(--blocker)', stopOpacity: 0.5 }} />
        </linearGradient>
      </defs>
    </svg>
  )
}
