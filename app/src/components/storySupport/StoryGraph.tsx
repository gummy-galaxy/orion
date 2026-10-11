import { useState, type ReactNode } from 'react'
import { Provider, createStore } from 'jotai'
import { ReactFlow, ReactFlowProvider, type Edge, type EdgeTypes, type NodeTypes } from '@xyflow/react'
import { ActionsContext } from '../../derive'
import type { AppNode, GhostNode, Link } from '../../model'
import { linksAtom, nodesAtom } from '../../state'
import { blocker, links as sampleLinks, task } from './data'

export function StoryGraph({
  nodes = [task, blocker],
  links = sampleLinks,
  edges = [],
  width = 760,
  height = 470,
  nodeTypes,
  edgeTypes,
  children,
}: {
  nodes?: (AppNode | GhostNode)[]
  links?: Link[]
  edges?: Edge[]
  width?: number | string
  height?: number | string
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

    return next
  })

  return (
    <Provider store={store}>
      <ActionsContext.Provider value={{ open: () => {}, reflow: () => {} }}>
        <ReactFlowProvider>
          <div style={{ width, height }}>
            <ReactFlow
              nodes={nodes}
              edges={edges}
              nodeTypes={nodeTypes}
              edgeTypes={edgeTypes}
              minZoom={0.1}
              fitView
              fitViewOptions={{ padding: 0.25 }}
            >
              {children}
            </ReactFlow>
          </div>
        </ReactFlowProvider>
      </ActionsContext.Provider>
    </Provider>
  )
}
