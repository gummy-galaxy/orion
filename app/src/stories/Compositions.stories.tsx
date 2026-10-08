import { Provider } from 'jotai'
import { ReactFlowProvider } from '@xyflow/react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import App from '../components/App'
import { Canvas } from '../components/Canvas'

const meta = { title: 'App/Compositions', parameters: { layout: 'fullscreen' } } satisfies Meta
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
