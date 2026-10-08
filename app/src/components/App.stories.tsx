import type { Meta, StoryObj } from '@storybook/react-vite'
import App from './App'
import { compositionDecorator, resetComposition } from './storySupport/composition'

const meta = {
  title: 'App/Compositions/App',
  parameters: { layout: 'fullscreen' },
  loaders: [resetComposition],
  decorators: [compositionDecorator],
} satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = { render: () => <App /> }
