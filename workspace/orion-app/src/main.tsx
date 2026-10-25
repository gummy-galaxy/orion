import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './components/App.tsx'
import { routeExternalLinks, windowFrame } from './external.ts'
import { applyAppearance, readAppearance } from './appearance.ts'
import { restoreSettings } from './settings.ts'
import { cachedThemes, loadThemes } from './themeFile.ts'

routeExternalLinks()

// The desktop shell hides its native title bar, so the page makes room for the window controls.
document.documentElement.dataset.titlebar = windowFrame()

// Saved preferences arrive before the app reads them. public/appearance.js applied the cached
// appearance, which is empty when the desktop app starts on a new origin, so apply it again.
await restoreSettings()
await loadThemes()
applyAppearance(readAppearance(), document.documentElement, cachedThemes())

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
