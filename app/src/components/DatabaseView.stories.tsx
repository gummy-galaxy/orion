import type { Meta, StoryObj } from '@storybook/react-vite'
import App from './App'
import { writeDetail } from '../detail'
import { databaseCanvas } from './storySupport/databaseFixture'
import { fakeServe } from './storySupport/fakeServe'
import { OperationLog } from './storySupport/OperationLog'

/**
 * Spike #102: the table view beside the full app, over a canvas shaped like Orion's own work. A stand-in for
 * `orion serve` applies each edit and derives status again, so a status change in the table moves the card on the
 * canvas, ⌘Z takes it back, and the log in the corner shows the operations the server received.
 */
const meta = {
  title: 'Spikes/Database view',
  parameters: { layout: 'fullscreen' },
  beforeEach: () => fakeServe(databaseCanvas()),
  loaders: [
    () => {
      localStorage.removeItem('orion:v2')
      localStorage.removeItem('orion:viewport:default')
      localStorage.setItem('orion:table', '1')
      writeDetail('default', null)

      return {}
    },
  ],
  decorators: [
    (Story) => (
      <div style={{ width: '100vw', height: '100vh' }}>
        <Story />
      </div>
    ),
  ],
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const AllWork: Story = {
  render: () => (
    <>
      <App />
      <OperationLog />
    </>
  ),
}
