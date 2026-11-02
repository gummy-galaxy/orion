import type { CardType } from '../types'

/** A type a source might declare, with one field of each kind its face and inspector draw. */
export const FIGMA_FRAME: CardType = {
  name: 'figma.frame',
  label: 'Figma frame',
  pack: 'figma',
  supersedes: [],
  fields: [
    { name: 'file', label: 'File', kind: 'url' },
    { name: 'screens', label: 'Screens', kind: 'number' },
    { name: 'shared', label: 'Shared', kind: 'boolean' },
    { name: 'due', label: 'Due', kind: 'date' },
    {
      name: 'stage',
      label: 'Stage',
      kind: 'choice',
      choices: [
        { value: 'draft', label: 'Draft' },
        { value: 'review', label: 'In review' },
      ],
      default: 'draft',
    },
  ],
  face: { layout: 'card', shows: ['stage', 'screens'] },
  states: [{ name: 'approved', label: 'Approved', means: 'done' }],
  meaning: { isWork: true, canBlock: true, canBeDone: true, doneWhen: 'state' },
}
