import { Provider } from 'jotai'
import { ReactFlowProvider } from '@xyflow/react'
import { Canvas } from './Canvas'

export default function App() {
  return (
    <Provider>
      <ReactFlowProvider>
        <Canvas />
      </ReactFlowProvider>
    </Provider>
  )
}
