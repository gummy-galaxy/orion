import type { Meta, StoryObj } from '@storybook/react-vite'
import type { CardView } from '../cardView'
import { TradingKindIcon } from './TradingKindIcon'

const meta = { title: 'Canvas/Cards and edges/TradingKindIcon', component: TradingKindIcon } satisfies Meta<typeof TradingKindIcon>

export default meta
type Story = StoryObj<typeof meta>

export const PullRequest: Story = { args: { kind: 'pr' } }

export const KindSizes: Story = {
  args: { kind: 'step' },
  render: () => (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, max-content)', alignItems: 'center', gap: 16 }}>
      <span>Kind</span>
      <span>14px</span>
      <span>32px</span>
      {(['step', 'pr', 'placeholder', 'gate', 'note'] satisfies CardView['kind'][]).map((kind) => (
        <div key={kind} style={{ display: 'contents' }}>
          <span>{kind}</span>
          <span style={{ display: 'block', width: 14, height: 14 }}>
            <TradingKindIcon kind={kind} />
          </span>
          <span style={{ display: 'block', width: 32, height: 32 }}>
            <TradingKindIcon kind={kind} />
          </span>
        </div>
      ))}
    </div>
  ),
}
