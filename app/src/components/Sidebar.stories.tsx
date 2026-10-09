import type { Meta, StoryObj } from '@storybook/react-vite'
import { Sidebar } from './Sidebar'
import { group } from './storySupport/data'

const meta = { title: 'Interface/Chrome/Sidebar' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div style={{ height: 600, width: 300 }}>
      <Sidebar
        nodes={[group]}
        groups={new Map([[group.id, { total: 8, done: 3, ready: 2, blocked: 3, outside: 1 }]])}
        root={group.id}
        open={() => {}}
        readyTotal={2}
        hide={() => {}}
        workspaces={{
          active: 'personal',
          workspaces: [
            { name: 'personal', label: 'Personal' },
            { name: 'team', label: 'Team' },
          ],
        }}
        switchWorkspace={async () => {}}
        newWorkspace={async () => {}}
        appearance={{ theme: 'classic', skin: 'classic', colorMode: 'light' }}
        chooseAppearance={() => {}}
      />
    </div>
  ),
}
