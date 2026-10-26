import type { Meta, StoryObj } from '@storybook/react-vite'
import { createStore, Provider } from 'jotai'
import { derivedAtom, linksAtom, nodesAtom } from '../state'
import { DetailsPanel } from './DetailsPanel'
import { NoteInspector } from './NoteInspector'
import { blocker, component, derived, group, links, note, task } from './storySupport/data'
import { TableTab } from './TableTab'

const meta = { title: 'Interface/Chrome/DetailsPanel' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

const tableStore = createStore()

tableStore.set(nodesAtom, [group, { ...task, parentId: 'group' }, { ...blocker, parentId: 'group' }, note, component])
tableStore.set(linksAtom, links)
tableStore.set(derivedAtom, derived)

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
    <Provider store={tableStore}>
      <div style={{ display: 'flex', height: 600 }}>
        <DetailsPanel width={640} tab="table" chooseTab={() => {}} hide={() => {}}>
          <TableTab root={null} scope="Whole canvas" reveal={() => {}} />
        </DetailsPanel>
      </div>
    </Provider>
  ),
}
