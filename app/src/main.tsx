import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './components/App.tsx'
import { inDesktop, routeExternalLinks } from './external.ts'

routeExternalLinks()

// The macOS shell hides its native title bar, so the app's own bar makes room for the traffic lights.
if (inDesktop() && navigator.userAgent.includes('Mac')) document.documentElement.dataset.titlebar = 'overlay'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
