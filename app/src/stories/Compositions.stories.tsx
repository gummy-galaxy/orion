import { Provider } from 'jotai'
import { ReactFlowProvider } from '@xyflow/react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import App from '../components/App'
import { Canvas } from '../components/Canvas'

const meta = {
  title: 'App/Compositions',
  parameters: { layout: 'fullscreen' },
  loaders: [
    () => {
      localStorage.removeItem('orion:v2')
      localStorage.removeItem('orion:viewport:default')
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

export const FullApp: Story = { name: 'App', render: () => <App /> }

export const WorkCanvas: Story = {
  name: 'Canvas',
  render: () => (
    <Provider>
      <ReactFlowProvider>
        <Canvas />
      </ReactFlowProvider>
    </Provider>
  ),
}
