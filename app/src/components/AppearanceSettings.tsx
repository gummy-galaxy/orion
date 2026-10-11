import { COLOR_MODES, THEMES, colorModeOf, themeOf, type Appearance } from '../appearance'

type Props = { appearance: Appearance; chooseAppearance: (appearance: Appearance) => void }

const capitalize = (text: string) => text[0].toUpperCase() + text.slice(1)

/** The theme and color mode, saved on this device. */
export function AppearanceSettings({ appearance, chooseAppearance }: Props) {
  const theme = themeOf(appearance.theme)
  const fixed = theme.schemes.length === 1
  const colorMode = colorModeOf(appearance)

  return (
    <section className="settings-section">
      <h3>Appearance</h3>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-theme">
            Theme
          </span>
          <p className="settings-field-detail">The colors the canvas and its cards use.</p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-theme">
          {THEMES.map((option) => (
            <button
              key={option.id}
              type="button"
              aria-pressed={appearance.theme === option.id}
              onClick={() => chooseAppearance({ ...appearance, theme: option.id })}
            >
              {option.label}
            </button>
          ))}
        </div>
      </div>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-color-mode">
            Color mode
          </span>
          <p className="settings-field-detail">
            {fixed ? `${theme.label} is ${theme.schemes[0]} only.` : 'System follows your computer’s light or dark setting.'}
          </p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-color-mode">
          {COLOR_MODES.map((mode) => (
            <button
              key={mode}
              type="button"
              disabled={fixed}
              aria-pressed={colorMode === mode}
              onClick={() => chooseAppearance({ ...appearance, colorMode: mode })}
            >
              {capitalize(mode)}
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
