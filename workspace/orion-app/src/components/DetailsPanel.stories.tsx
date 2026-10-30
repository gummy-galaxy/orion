import type { Meta, StoryObj } from '@storybook/react-vite'
import type { TableRow } from '../table/types'
import { CardTable } from './CardTable'
import { DetailsPanel } from './DetailsPanel'
import { NoteInspector } from './NoteInspector'
import { note } from './storySupport/data'

const meta = { title: 'Interface/Chrome/DetailsPanel' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const rows: TableRow[] = [
  { id: 'task', label: 'Ship the query endpoint', kind: 'pr', status: 'review', group: 'Release', ref: 'gummy-galaxy/orion#655' },
  { id: 'blocker', label: 'Add a Table tab', kind: 'pr', status: 'blocked', group: 'Release', ref: 'gummy-galaxy/orion#656' },
  { id: 'step', label: 'Measure at 5,000 cards', kind: 'step', status: 'ready', group: 'Release' },
  { id: 'note', label: 'Rows come from orion serve', kind: 'note' },
  { id: 'component', label: 'orion serve', kind: 'component' },
]

export const Default: Story = {
  render: () => (
    <div style={{ display: 'flex', height: 600 }}>
      <DetailsPanel tab="details" chooseTab={() => {}} hide={() => {}}>
        <NoteInspector
          node={note}
          focus={false}
          doneEditing={() => {}}
          update={() => {}}
          saveFields={() => Promise.resolve(null)}
          remove={() => {}}
        />
      </DetailsPanel>
    </div>
  ),
}

export const Table: Story = {
  render: () => (
    <div style={{ display: 'flex', height: 600 }}>
      <DetailsPanel width={640} tab="table" chooseTab={() => {}} hide={() => {}}>
        <CardTable rows={rows} scope="All work" reveal={() => {}} />
      </DetailsPanel>
    </div>
  ),
}
