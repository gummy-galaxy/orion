// @vitest-environment happy-dom
import { act, render } from '@testing-library/react'
import { createStore, Provider } from 'jotai'
import { Profiler } from 'react'
import { expect, test } from 'vitest'
import type { AppNode } from '../model'
import { nodesAtom } from '../state'
import { card } from '../table/fixtures/card'
import { TableTab } from './TableTab'

const reveal = () => {}

function renderTable(nodes: AppNode[]) {
  const store = createStore()
  const renders = { count: 0 }

  store.set(nodesAtom, nodes)
  const view = render(
    <Profiler id="table" onRender={() => renders.count++}>
      <Provider store={store}>
        <TableTab root={null} scope="Whole canvas" reveal={reveal} />
      </Provider>
    </Profiler>,
  )

  return { store, renders, view }
}

test("doesn't redraw while cards are dragged or selected", () => {
  const nodes = [card('a', 'First'), card('b', 'Second')]
  const { store, renders } = renderTable(nodes)
  const before = renders.count

  act(() =>
    store.set(
      nodesAtom,
      nodes.map((node) => ({ ...node, position: { x: 90, y: 40 }, selected: true, dragging: true })),
    ),
  )

  expect(renders.count).toBe(before)
})

test('redraws when a card is renamed', () => {
  const nodes = [card('a', 'First'), card('b', 'Second')]
  const { store, view } = renderTable(nodes)

  act(() => store.set(nodesAtom, [nodes[0], card('b', 'Renamed')]))

  expect(view.container.textContent).toContain('Renamed')
  expect(view.container.textContent).toContain('2 cards')
})
