// @vitest-environment happy-dom
import { act, cleanup, fireEvent, render } from '@testing-library/react'
import { afterEach, expect, test, vi } from 'vitest'
import { DeleteUsageDataField } from './DeleteUsageDataField'

afterEach(cleanup)

const shared = { choice: 'on' as const, installId: 'example', enabled: true }

test('asks once more, then deletes and says so', async () => {
  const deleteTelemetryData = vi.fn().mockResolvedValue(undefined)
  const view = render(<DeleteUsageDataField telemetry={shared} deleteTelemetryData={deleteTelemetryData} />)

  fireEvent.click(view.getByText('Delete'))
  expect(deleteTelemetryData).not.toHaveBeenCalled()
  expect(view.container.textContent).toContain('can’t be undone')

  await act(async () => fireEvent.click(view.getByText('Delete')))

  expect(deleteTelemetryData).toHaveBeenCalledTimes(1)
  expect(view.container.textContent).toContain('Deleted.')
})

test('shows why a deletion failed', async () => {
  const deleteTelemetryData = vi.fn().mockRejectedValue(new Error('the telemetry backend answered 502'))
  const view = render(<DeleteUsageDataField telemetry={shared} deleteTelemetryData={deleteTelemetryData} />)

  fireEvent.click(view.getByText('Delete'))
  await act(async () => fireEvent.click(view.getByText('Delete')))

  expect(view.getByRole('alert').textContent).toContain('the telemetry backend answered 502')
})

test('has nothing to delete on a machine that never shared', () => {
  const view = render(
    <DeleteUsageDataField telemetry={{ choice: 'off', enabled: false }} deleteTelemetryData={vi.fn()} />,
  )

  expect((view.getByText('Delete') as HTMLButtonElement).disabled).toBe(true)
  expect(view.container.textContent).toContain('nothing to delete')
})
