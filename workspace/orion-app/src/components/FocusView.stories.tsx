import type { Meta, StoryObj } from '@storybook/react-vite'
import { FocusView } from './FocusView'

const meta = { title: 'Interaction/Overlays/FocusView', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  render: () => (
    <div style={{ width: '100vw', height: '100vh', position: 'relative' }}>
      <div
        className="card st-active"
        style={{ position: 'absolute', left: 500, top: 300, width: 216, height: 72, padding: 12 }}
      >
        <span className="meta-tag">orion</span>
        <div className="label">Make the canvas welcoming</div>
      </div>
      <FocusView
        label="Make the canvas welcoming"
        card={{ x: 500, y: 300, width: 216, height: 72 }}
        sideWidth={250}
        inset={20}
        incoming={[
          {
            id: 'first',
            label: 'Sketch the layout',
            tag: 'step',
            status: 'done',
            where: 'Canvas',
            related: false,
            flow: 'live',
          },
        ]}
        outgoing={[
          {
            id: 'next',
            label: 'Review the design',
            tag: 'step',
            status: 'ready',
            where: 'Canvas',
            related: false,
            flow: 'live',
          },
        ]}
        onFocus={() => {}}
        onExit={() => {}}
      />
    </div>
  ),
}
