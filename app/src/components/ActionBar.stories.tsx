import type { Meta, StoryObj } from '@storybook/react-vite'
import { DEFAULT_KEYBINDINGS } from '../keybindings'
import { ActionBar } from './ActionBar'

const meta = { title: 'Interface/Chrome/ActionBar' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <ActionBar
      keybindings={DEFAULT_KEYBINDINGS}
      search={() => {}}
      addNote={() => {}}
      addImage={() => {}}
      tidy={{ label: 'Tidy canvas', run: () => {} }}
      sync={{ status: { state: 'idle', lastRun: new Date().toISOString() }, label: 'Synced just now', run: () => {} }}
    />
  ),
}

export const Syncing: Story = {
  render: () => (
    <ActionBar
      keybindings={DEFAULT_KEYBINDINGS}
      search={() => {}}
      addNote={() => {}}
      addImage={() => {}}
      sync={{ status: { state: 'running' }, label: 'Syncing…', run: () => {} }}
    />
  ),
}

export const SyncFailed: Story = {
  render: () => (
    <ActionBar
      keybindings={DEFAULT_KEYBINDINGS}
      search={() => {}}
      addNote={() => {}}
      addImage={() => {}}
      tidy={{ label: 'Tidy group', run: () => {} }}
      sync={{ status: { state: 'error', message: 'gh is not signed in' }, label: 'Sync failed', run: () => {} }}
    />
  ),
}
