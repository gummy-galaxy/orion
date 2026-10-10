import { Provider } from 'jotai'
import { ReactFlowProvider } from '@xyflow/react'
import { windowFrame } from '../external'
import { Canvas } from './Canvas'
import { WindowControls } from './WindowControls'

export default function App() {
  return (
    <Provider>
      <ReactFlowProvider>
        <Canvas />
        {windowFrame() === 'custom' && <WindowControls />}
      </ReactFlowProvider>
    </Provider>
  )
}
