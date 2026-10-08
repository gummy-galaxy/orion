/** Layered lays a level out from scratch; Weave nudges the current arrangement until lines clear the cards. */
export type LayoutMode = 'layered' | 'weave'

const MODES: LayoutMode[] = ['layered', 'weave']

export function LayoutModeToggle({ mode, onChange }: { mode: LayoutMode; onChange: (mode: LayoutMode) => void }) {
  return (
    <span className="seg" role="group" aria-label="Layout mode">
      {MODES.map((option) => (
        <button
          key={option}
          type="button"
          className={mode === option ? 'on' : undefined}
          aria-pressed={mode === option}
          title={option === 'weave' ? 'Nudge cards off the lines that run through them' : 'Lay everything out again'}
          onClick={() => onChange(option)}
        >
          {option === 'weave' ? 'Weave' : 'Layered'}
        </button>
      ))}
    </span>
  )
}
