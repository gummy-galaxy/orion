import type { Meta, StoryObj } from '@storybook/react-vite'
import builtinTypes from '../cardTypes/builtinTypes.json'
import { FIGMA_FRAME } from '../cardTypes/fixtures/figmaFrame'
import { registerCardTypes } from '../cardTypes/registerCardTypes'
import { TypeFields } from './TypeFields'

// A source's type, registered as the server would send it.
registerCardTypes([...builtinTypes, FIGMA_FRAME])

const meta = {
  title: 'Details/Inspectors/TypeFields',
  render: () => (
    <div className="insp task-insp" style={{ width: 320 }}>
      <TypeFields
        data={{
          kind: 'task',
          label: 'Settings panel in dark mode',
          status: 'active',
          types: ['figma.frame'],
          fields: { file: 'https://www.figma.com/file/abc', screens: 4, stage: 'review', due: '2026-11-02' },
        }}
        save={() => {}}
      />
    </div>
  ),
} satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

/** The fields a source's type declares, drawn from its declaration with no app code of its own. */
export const DeclaredFields: Story = {}
