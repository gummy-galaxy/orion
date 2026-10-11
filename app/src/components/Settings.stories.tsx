import type { Meta, StoryObj } from '@storybook/react-vite'
import { useState } from 'react'
import type { Appearance } from '../appearance'
import { DEFAULT_KEYBINDINGS, type Keybindings } from '../keybindings'
import type { Scrolling } from '../scrolling'
import { Settings, type SettingsSection } from './Settings'

const meta = { title: 'Interaction/Overlays/Settings', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function Interactive({ section, keybindings = DEFAULT_KEYBINDINGS }: { section: SettingsSection; keybindings?: Keybindings }) {
  const [shown, setShown] = useState(section)
  const [appearance, setAppearance] = useState<Appearance>({ theme: 'classic', colorMode: 'system', statusColors: 'theme', animations: 'on' })
  const [scrolling, setScrolling] = useState<Scrolling>('zoom')
  const [bindings, setBindings] = useState(keybindings)

  return (
    <Settings
      section={shown}
      showSection={setShown}
      close={() => {}}
      appearance={appearance}
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
