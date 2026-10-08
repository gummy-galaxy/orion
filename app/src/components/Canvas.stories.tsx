import { Provider } from 'jotai'
import { ReactFlowProvider } from '@xyflow/react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { Canvas } from './Canvas'
import { compositionDecorator, resetComposition } from './storySupport/composition'

const meta = {
  title: 'App/Compositions/Canvas',
  parameters: { layout: 'fullscreen' },
  loaders: [resetComposition],
  decorators: [compositionDecorator],
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <Provider>
      <ReactFlowProvider>
        <Canvas />
      </ReactFlowProvider>
    </Provider>
  ),
}
