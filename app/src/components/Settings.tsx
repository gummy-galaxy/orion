import { useEffect, useRef } from 'react'
import type { Appearance } from '../appearance'
import type { Keybindings } from '../keybindings'
import type { Scrolling } from '../scrolling'
import { AppearanceSettings } from './AppearanceSettings'
import { CanvasSettings } from './CanvasSettings'
import { ShortcutSettings } from './ShortcutSettings'

export type SettingsSection = 'appearance' | 'canvas' | 'shortcuts'

const SECTIONS: { id: SettingsSection; label: string }[] = [
  { id: 'appearance', label: 'Appearance' },
  { id: 'canvas', label: 'Canvas' },
  { id: 'shortcuts', label: 'Keyboard Shortcuts' },
]

type Props = {
  section: SettingsSection
  showSection: (section: SettingsSection) => void
  close: () => void
  appearance: Appearance
  chooseAppearance: (appearance: Appearance) => void
  scrolling: Scrolling
  chooseScrolling: (scrolling: Scrolling) => void
  keybindings: Keybindings
  chooseKeybindings: (keybindings: Keybindings) => void
}

/** Preferences saved on this device, one section at a time beside a list of sections. */
export function Settings({
  section,
  showSection,
  close,
  appearance,
  chooseAppearance,
  scrolling,
  chooseScrolling,
  keybindings,
  chooseKeybindings,
}: Props) {
  const dialog = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null

    dialog.current?.focus()

    return () => previous?.focus()
  }, [])

  // Keys stay inside the dialog, so the canvas behind it doesn't act on them.
  const onKeyDown = (event: React.KeyboardEvent) => {
    event.stopPropagation()

    if (event.key === 'Escape' && !event.isDefaultPrevented()) close()
  }

  return (
    <div className="settings-backdrop" onMouseDown={(event) => event.target === event.currentTarget && close()}>
      <div
        ref={dialog}
        className="settings panel"
        role="dialog"
        aria-modal="true"
        aria-label="Settings"
        // Focusable, so a click on blank space keeps keys inside the dialog.
        tabIndex={-1}
        onKeyDown={onKeyDown}
      >
        <nav className="settings-nav" aria-label="Settings sections">
          <h2>Settings</h2>
          {SECTIONS.map((item) => (
            <button
              key={item.id}
              type="button"
              className="settings-nav-item"
              aria-current={item.id === section ? 'page' : undefined}
              onClick={() => showSection(item.id)}
            >
              {item.label}
            </button>
          ))}
        </nav>
        <button type="button" className="settings-close" aria-label="Close settings" title="Close (Esc)" onClick={close}>
          ×
        </button>
        <div className="settings-body">
          {section === 'appearance' && <AppearanceSettings appearance={appearance} chooseAppearance={chooseAppearance} />}
          {section === 'canvas' && <CanvasSettings scrolling={scrolling} chooseScrolling={chooseScrolling} />}
          {section === 'shortcuts' && <ShortcutSettings scrolling={scrolling} keybindings={keybindings} chooseKeybindings={chooseKeybindings} />}
        </div>
      </div>
    </div>
  )
}
