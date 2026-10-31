// @vitest-environment happy-dom
import { act, render } from '@testing-library/react'
import { expect, test, vi } from 'vitest'
import type { QueryAnswer, QueryRequest } from '../persist'
import { TableTab } from './TableTab'

const watched: { request: QueryRequest; answer: (answer: QueryAnswer) => void; stop: () => void }[] = []

vi.mock('../persist', () => ({
  watchQuery: (request: QueryRequest, answer: (answer: QueryAnswer) => void) => {
    const stop = vi.fn()

    watched.push({ request, answer, stop })

    return stop
  },
}))

const reveal = () => {}

test("lists the server's answer and asks again when the open group changes", () => {
  watched.length = 0
  const view = render(<TableTab root={null} scope="All work" reveal={reveal} />)

  act(() =>
    watched[0].answer({
      canvas: 'default',
      revision: 1,
      total: 1,
      offset: 0,
      rows: [{ id: 'a', kind: 'step', label: 'First', status: 'ready' }],
    }),
  )

  expect(view.container.textContent).toContain('First')
  expect(view.container.textContent).toContain('1 card')

  view.rerender(<TableTab root="release" scope="Release" reveal={reveal} />)

  expect(watched[0].stop).toHaveBeenCalled()
  expect(watched[1].request.where).toContain('within = "release"')
})
