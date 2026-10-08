import type { ComponentType } from 'react'

export function resetComposition() {
  localStorage.removeItem('orion:v2')
  localStorage.removeItem('orion:viewport:default')

  return {}
}

export function compositionDecorator(Story: ComponentType) {
  return (
    <div style={{ width: '100vw', height: '100vh' }}>
      <Story />
    </div>
  )
}
