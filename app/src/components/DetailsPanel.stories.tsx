import type { Meta, StoryObj } from '@storybook/react-vite'
import { DetailsPanel } from './DetailsPanel'
import { NoteInspector } from './NoteInspector'
import { note } from './storySupport/data'

const meta = { title: 'Interface/Chrome/DetailsPanel' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div style={{ display: 'flex', height: 600 }}>
      <DetailsPanel hide={() => {}}>
        <NoteInspector
          node={note}
          focus={false}
          doneEditing={() => {}}
          update={() => {}}
          saveFields={() => Promise.resolve(null)}
          remove={() => {}}
        />
      </DetailsPanel>
    </div>
  ),
}
