// @vitest-environment happy-dom
import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, expect, test, vi } from 'vitest'
import builtinTypes from '../cardTypes/builtinTypes.json'
import { FIGMA_FRAME } from '../cardTypes/fixtures/figmaFrame'
import { registerCardTypes } from '../cardTypes/registerCardTypes'
import { TypeFields } from './TypeFields'

afterEach(() => registerCardTypes(builtinTypes))

test("draws a declared type's fields and saves each change as text", () => {
  registerCardTypes([...builtinTypes, FIGMA_FRAME])

  const save = vi.fn()

  render(<TypeFields data={{ kind: 'task', label: 'Frame', status: 'todo', types: ['figma.frame'] }} save={save} />)

  fireEvent.change(screen.getByLabelText('Stage'), { target: { value: 'review' } })
  fireEvent.click(screen.getByLabelText('Shared'))

  const screens = screen.getByLabelText('Screens')

  fireEvent.change(screens, { target: { value: '4' } })
  fireEvent.blur(screens)

  expect(save.mock.calls).toEqual([[{ values: { stage: 'review' } }], [{ values: { shared: 'true' } }], [{ values: { screens: '4' } }]])
  expect(screen.getByText('Step · Figma frame')).toBeTruthy()
})

test('draws nothing for a card whose types declare only the built-in fields', () => {
  const { container } = render(<TypeFields data={{ kind: 'task', label: 'Step', status: 'todo' }} save={vi.fn()} />)

  expect(container.innerHTML).toBe('')
})
