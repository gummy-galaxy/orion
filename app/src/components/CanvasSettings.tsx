import { SCROLLINGS, type Scrolling } from '../scrolling'

type Props = { scrolling: Scrolling; chooseScrolling: (scrolling: Scrolling) => void }

/** How the canvas responds to input, saved on this device. */
export function CanvasSettings({ scrolling, chooseScrolling }: Props) {
  const chosen = SCROLLINGS.find((option) => option.id === scrolling) ?? SCROLLINGS[0]

  return (
    <section className="settings-section">
      <h3>Canvas</h3>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-scrolling">
            Scroll to
          </span>
          <p className="settings-field-detail">{chosen.detail}</p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-scrolling">
          {SCROLLINGS.map((option) => (
            <button key={option.id} type="button" aria-pressed={scrolling === option.id} onClick={() => chooseScrolling(option.id)}>
              {option.label}
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
