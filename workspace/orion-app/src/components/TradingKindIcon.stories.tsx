import type { Meta, StoryObj } from '@storybook/react-vite'
import { TradingKindIcon } from './TradingKindIcon'

const meta = { title: 'Canvas/Cards and edges/TradingKindIcon', component: TradingKindIcon } satisfies Meta<
  typeof TradingKindIcon
>

export default meta
type Story = StoryObj<typeof meta>

export const PullRequest: Story = { args: { kind: 'pr' } }
