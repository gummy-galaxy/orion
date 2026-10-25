import { COLOR_MODES, THEMES, colorModeOf, themeOf, type Appearance, type Theme } from '../appearance'
import { SKINS, skinOf } from '../skins'

type Props = { appearance: Appearance; themes: readonly Theme[]; chooseAppearance: (appearance: Appearance) => void }

const capitalize = (text: string) => text[0].toUpperCase() + text.slice(1)

/** The theme, card skin, color mode, and companion, saved on this device. */
export function AppearanceSettings({ appearance, themes, chooseAppearance }: Props) {
  const theme = themeOf(appearance.theme, themes)
  const fixed = theme.schemes.length === 1
  const colorMode = colorModeOf(appearance, themes)
  const skin = skinOf(appearance.skin)
  const problems = themes.flatMap((option) => [
    ...(option.error ? [`${option.label} ${option.error}.`] : []),
    ...(option.id === theme.id ? (option.notes ?? []).map((note) => `${option.label}: ${note}.`) : []),
  ])

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
          {themes.map((option) => (
            <button
              key={option.id}
              type="button"
              disabled={option.error !== undefined}
              aria-pressed={appearance.theme === option.id}
              onClick={() => chooseAppearance({ ...appearance, theme: option.id })}
            >
              {option.label}
              {option.deprecated && <span className="option-tag">Deprecated</span>}
            </button>
          ))}
        </div>
        {theme.deprecated && (
          <p className="settings-field-detail">
            {theme.label} is deprecated and will be removed. {THEMES[0].label} is the default.
          </p>
        )}
        {theme.author && (
          <p className="settings-field-detail">
            {theme.label} by {theme.author}.
          </p>
        )}
        {problems.map((problem) => (
          <p key={problem} className="settings-field-detail">
            {problem}
          </p>
        ))}
      </div>
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-skin">
            Cards
          </span>
          <p className="settings-field-detail">How cards on the canvas are drawn.</p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-skin">
          {SKINS.map((option) => (
            <button
              key={option.id}
              type="button"
              aria-pressed={appearance.skin === option.id}
              onClick={() => chooseAppearance({ ...appearance, skin: option.id })}
            >
              {option.label}
              {'deprecated' in option && <span className="option-tag">Deprecated</span>}
            </button>
          ))}
        </div>
        {'deprecated' in skin && (
          <p className="settings-field-detail">
            {skin.label} cards are deprecated and will be removed. {SKINS[0].label} are the default.
          </p>
        )}
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
      <div className="settings-field">
        <div>
          <span className="settings-field-label" id="settings-companion">
            Companion
          </span>
          <p className="settings-field-detail">A little star that perches on the card nearest the pointer and reacts to its status.</p>
        </div>
        <div className="options" role="group" aria-labelledby="settings-companion">
          {[true, false].map((shown) => (
            <button
              key={String(shown)}
              type="button"
              aria-pressed={appearance.companion === shown}
              onClick={() => chooseAppearance({ ...appearance, companion: shown })}
            >
              {shown ? 'On' : 'Off'}
            </button>
          ))}
        </div>
      </div>
    </section>
  )
}
