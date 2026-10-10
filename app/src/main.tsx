import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './components/App.tsx'
import { routeExternalLinks, windowFrame } from './external.ts'

routeExternalLinks()

// The desktop shell hides its native title bar, so the page makes room for the window controls.
document.documentElement.dataset.titlebar = windowFrame()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
