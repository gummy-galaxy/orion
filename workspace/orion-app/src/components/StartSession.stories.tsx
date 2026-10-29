import type { Meta, StoryObj } from '@storybook/react-vite'
import { StartSession } from './StartSession'
import type { StartOptions } from '../sessions/types'

const meta = {
  title: 'Details/Inspectors/StartSession',
  component: StartSession,
  decorators: [
    (Story) => (
      <div className="panel task-insp" style={{ width: 380, padding: 20 }}>
        <Story />
      </div>
    ),
  ],
} satisfies Meta<typeof StartSession>

export default meta
type Story = StoryObj<typeof meta>

const ready: StartOptions = {
  presets: [{ id: 'work', label: 'Work on this card' }],
  agent: 'Claude Code',
  attaches: true,
  repo: 'gummy-galaxy/orion',
  branch: 'agent/616-start-session',
  place: 'checkout',
  folder: '/Users/me/git/orion-616-start-session',
  problem: null,
}

const start = () => new Promise<void>((resolve) => setTimeout(resolve, 600))

export const Ready: Story = { args: { options: ready, start } }

export const Conflicting: Story = {
  args: {
    options: { ...ready, presets: [...ready.presets, { id: 'resolve-conflicts', label: 'Resolve conflicts' }] },
    start,
  },
}

export const InClone: Story = {
  args: { options: { ...ready, place: 'clone', folder: '/Users/me/git/orion' }, start },
}

export const NoFolder: Story = {
  args: { options: { ...ready, place: 'none', folder: null, attaches: false }, start },
}

export const Refused: Story = {
  args: { options: ready, start: () => Promise.reject(new Error('Could not open claude://code/new: nothing handles it')) },
}
