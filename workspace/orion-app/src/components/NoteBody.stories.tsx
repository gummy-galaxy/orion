import { useState } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { NoteBody } from './NoteBody'

const meta = { title: 'Details/Inspectors/NoteBody' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const SAMPLE_NOTE = `## Where this stands

The panel now reads top to bottom: **status** first, then this note, then the pull request.

- Waits on the *sticker wheel* fix, which landed in \`#312\`
- The timeline section goes between notes and the pull request
1. Panel width follows the window
2. Lists keep their markers

- Open question: do notes stay once the timeline exists?

See [the charter](https://example.com/charter) for the roadmap. Inline \`code\` and paths like
\`app/src/components/NoteBody.tsx\` stay readable.`

function NoteDemo() {
  const [note, setNote] = useState<string | undefined>(SAMPLE_NOTE)

  return (
    <div className="panel" style={{ width: 380, padding: 20 }}>
      <NoteBody id="story-note" note={note} change={setNote} />
    </div>
  )
}

export const Rendered: Story = { render: () => <NoteDemo /> }

export const Empty: Story = {
  render: () => (
    <div className="panel" style={{ width: 380, padding: 20 }}>
      <NoteBody id="story-note-empty" change={() => {}} />
    </div>
  ),
}
