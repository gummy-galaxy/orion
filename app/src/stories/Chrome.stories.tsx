import { createRef, useLayoutEffect } from 'react'
import type { Meta, StoryObj } from '@storybook/react-vite'
import { DebugBar } from '../DebugBar'
import { FarTag } from '../FarTag'
import { Favicon } from '../Favicon'
import { Lock } from '../Lock'
import { ProcessUsage } from '../ProcessUsage'
import { Ring } from '../Ring'
import { Sidebar } from '../Sidebar'
import { SourceBadges } from '../SourceBadges'
import { SourceLink } from '../SourceLink'
import { Toolbar } from '../Toolbar'
import { StoryGraph } from './StoryGraph'
import { group, source } from './data'

const meta = { title: 'Interface/Chrome' } satisfies Meta
export default meta
type Story = StoryObj<typeof meta>

export const Groups: Story = {
  name: 'Sidebar',
  render: () => (
    <div style={{ height: 600, width: 300 }}>
      <Sidebar
        nodes={[group]}
        groups={new Map([[group.id, { total: 8, done: 3, ready: 2, blocked: 3, outside: 1 }]])}
        root={group.id}
        open={() => {}}
        readyTotal={2}
        hide={() => {}}
        workspaces={{
          active: 'personal',
          workspaces: [
            { name: 'personal', label: 'Personal' },
            { name: 'team', label: 'Team' },
          ],
        }}
        switchWorkspace={async () => {}}
        newWorkspace={async () => {}}
        colorMode="light"
        chooseColorMode={() => {}}
      />
    </div>
  ),
}

export const Tools: Story = {
  name: 'Toolbar',
  render: () => <Toolbar tool="select" sticker="🎉" setTool={() => {}} />,
}

export const Debug: Story = {
  name: 'DebugBar',
  render: () => (
    <StoryGraph nodes={[]}>
      <DebugBar
        canvas={createRef<HTMLDivElement>()}
        motion={{ arrows: true, glow: true, pauseWhileMoving: true }}
        setMotion={() => {}}
        close={() => {}}
      />
    </StoryGraph>
  ),
}

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

export const DesktopUsage: Story = { name: 'ProcessUsage', render: () => <DesktopUsageDemo /> }

export const SiteIcon: Story = {
  name: 'Favicon',
  render: () => <Favicon domain="example" />,
}

export const Sources: Story = {
  name: 'SourceBadges',
  render: () => <SourceBadges sources={[source, { ...source, label: 'vocksel/other' }]} />,
}

export const Source: Story = {
  name: 'SourceLink',
  render: () => <SourceLink source={source}>Open vocksel/orion ↗</SourceLink>,
}

export const Locked: Story = {
  name: 'Lock',
  render: () => (
    <span className="st">
      <Lock /> Blocked
    </span>
  ),
}

export const Progress: Story = {
  name: 'Ring',
  render: () => <Ring done={3} total={8} size={48} />,
}

export const DistantCard: Story = {
  name: 'FarTag',
  render: () => (
    <FarTag className="card st-active">
      <span className="label">Make the canvas welcoming</span>
    </FarTag>
  ),
}
