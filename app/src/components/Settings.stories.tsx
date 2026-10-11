import type { Meta, StoryObj } from '@storybook/react-vite'
import { useEffect, useState } from 'react'
import { type Appearance, type Theme } from '../appearance'
import { DEFAULT_KEYBINDINGS, type Keybindings } from '../keybindings'
import type { Scrolling } from '../scrolling'
import { cachedThemes, loadThemes } from '../themeFile'
import { Settings, type SettingsSection } from './Settings'

const meta = { title: 'Interaction/Overlays/Settings', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function Interactive({ section, keybindings = DEFAULT_KEYBINDINGS }: { section: SettingsSection; keybindings?: Keybindings }) {
  const [shown, setShown] = useState(section)
  const [appearance, setAppearance] = useState<Appearance>({
    theme: 'classic',
    skin: 'classic',
    colorMode: 'system',
    statusColors: 'theme',
    animations: 'system',
  })
  const [scrolling, setScrolling] = useState<Scrolling>('zoom')
  const [bindings, setBindings] = useState(keybindings)
  const [themes, setThemes] = useState<Theme[]>(cachedThemes)

  // Loads the picker's themes the way Canvas does when settings open, so the story shows the same list.
  useEffect(() => {
    void loadThemes().then(setThemes)
  }, [])

  return (
    <Settings
      section={shown}
      showSection={setShown}
      close={() => {}}
      appearance={appearance}
      themes={themes}
      chooseAppearance={setAppearance}
      scrolling={scrolling}
      chooseScrolling={setScrolling}
      keybindings={bindings}
      chooseKeybindings={setBindings}
    />
  )
}

export const AppearanceSection: Story = { render: () => <Interactive section="appearance" /> }

export const CanvasSection: Story = { render: () => <Interactive section="canvas" /> }

export const AccessibilitySection: Story = { render: () => <Interactive section="accessibility" /> }

export const ShortcutsSection: Story = { render: () => <Interactive section="shortcuts" /> }

/** A changed binding offers a reset, and one that clashes names the other shortcut. */
export const CustomizedShortcuts: Story = {
  render: () => <Interactive section="shortcuts" keybindings={{ ...DEFAULT_KEYBINDINGS, 'add-note': 'V', 'go-forward': '' }} />,
}
