import type { Meta, StoryObj } from '@storybook/react-vite'
import { TelemetryPrompt } from './TelemetryPrompt'

const meta = { title: 'Interaction/Overlays/Telemetry prompt', parameters: { layout: 'fullscreen' } } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

/** The question asked once on launch, before anyone can use the canvas. */
export const FirstLaunch: Story = { render: () => <TelemetryPrompt choose={() => {}} dismiss={() => {}} /> }
