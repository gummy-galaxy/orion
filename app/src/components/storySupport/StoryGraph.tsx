import { useState, type ReactNode } from 'react'
import { Provider, createStore } from 'jotai'
import { ReactFlow, ReactFlowProvider, type Edge, type EdgeTypes, type NodeTypes } from '@xyflow/react'
import { ActionsContext } from '../../derive'
import type { AppNode, GhostNode } from '../../model'
import { derivedAtom, linksAtom, nodesAtom } from '../../state'
import { blocker, derived, links, task } from './data'

const noResize = { start: () => {}, move: () => {}, end: () => {} }

export function StoryGraph({
  nodes = [task, blocker],
  edges = [],
  nodeTypes,
  edgeTypes,
  children,
}: {
  nodes?: (AppNode | GhostNode)[]
  edges?: Edge[]
  nodeTypes?: NodeTypes
  edgeTypes?: EdgeTypes
  children?: ReactNode
}) {
  const [store] = useState(() => {
    const next = createStore()

    next.set(
      nodesAtom,
      nodes.filter((node): node is AppNode => node.type !== 'ghost'),
    )
    next.set(linksAtom, links)
    next.set(derivedAtom, derived)

    return next
  })

  return (
    <Provider store={store}>
      <ActionsContext.Provider value={{ open: () => {}, reflow: () => {}, celebrate: () => {}, resizeGroup: noResize }}>
        <ReactFlowProvider>
          <div style={{ width: 760, height: 470 }}>
            <ReactFlow nodes={nodes} edges={edges} nodeTypes={nodeTypes} edgeTypes={edgeTypes} fitView fitViewOptions={{ padding: 0.25 }}>
              {children}
            </ReactFlow>
          </div>
        </ReactFlowProvider>
      </ActionsContext.Provider>
    </Provider>
  )
}
