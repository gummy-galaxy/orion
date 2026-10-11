import { ANIMATIONS, STATUS_COLORS, type Appearance } from '../appearance'

type Props = { appearance: Appearance; chooseAppearance: (appearance: Appearance) => void }

/** Settings that make Orion easier to see and use, saved on this device. */
export function AccessibilitySettings({ appearance, chooseAppearance }: Props) {
  return (
    <section className="settings-section">
      <h3>Accessibility</h3>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-status-colors">
            Colorblind colors
          </span>
          <p className="settings-field-detail">
            Status colors tuned for protanopia and deuteranopia (red-green) or tritanopia (blue-yellow), in any theme. Every status also has its own
            shape.
          </p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-status-colors">
          {STATUS_COLORS.map((option) => (
            <button
              key={option.id}
              type="button"
              aria-pressed={appearance.statusColors === option.id}
              onClick={() => chooseAppearance({ ...appearance, statusColors: option.id })}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-animations">
            Animations
          </span>
          <p className="settings-field-detail">
            On respects your computer’s reduced motion setting, stopping looping effects and gliding when it’s set. Off stops every animation in
            Orion, and the canvas jumps instead of gliding.
          </p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-animations">
          {ANIMATIONS.map((option) => (
            <button
              key={option.id}
              type="button"
              aria-pressed={appearance.animations === option.id}
              onClick={() => chooseAppearance({ ...appearance, animations: option.id })}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
