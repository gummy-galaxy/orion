import { useLayoutEffect } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { ProcessUsage } from './ProcessUsage'

const meta = { title: 'Interface/Chrome/ProcessUsage' } satisfies Meta

export default meta
type Story = StoryObj<typeof meta>

function DesktopUsageDemo() {
  useLayoutEffect(() => {
    const original = Object.getOwnPropertyDescriptor(window, '__TAURI_INTERNALS__')

    Object.defineProperty(window, '__TAURI_INTERNALS__', {
      configurable: true,
      value: { invoke: async () => [{ name: 'Orion', cpu: 12.3, memory: 128 * 1048576 }] },
    })

    return () => {
      if (original) Object.defineProperty(window, '__TAURI_INTERNALS__', original)
      else Reflect.deleteProperty(window, '__TAURI_INTERNALS__')
    }
  }, [])

  return (
    <div className="debug-bar">
      <ProcessUsage />
    </div>
  )
}

export const DesktopUsage: Story = { render: () => <DesktopUsageDemo /> }
