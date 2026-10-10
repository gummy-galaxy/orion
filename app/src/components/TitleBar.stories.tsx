import type { Meta, StoryObj } from '@storybook/react-vite'
import { TitleBar } from './TitleBar'

const meta = { title: 'Interface/Chrome/TitleBar' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const actions = (
  <>
    <button type="button" className="btn">
      Search <kbd>⇧⌘P</kbd>
    </button>
    <button type="button" className="btn">
      Add note
    </button>
  </>
)

export const Default: Story = {
  render: () => (
    <div style={{ width: 900 }}>
      <TitleBar
        crumbs={
          <>
            <button type="button" className="crumb">
              All work
            </button>
            <span className="crumb-wrap">
              <span className="sep">›</span>
              <button type="button" className="crumb current">
                Desktop shell
              </button>
            </span>
          </>
        }
        actions={actions}
      />
    </div>
  ),
}

export const AtTop: Story = {
  render: () => (
    <div style={{ width: 900 }}>
      <TitleBar
        crumbs={
          <button type="button" className="crumb current">
            All work
          </button>
        }
        actions={actions}
      />
    </div>
  ),
}
