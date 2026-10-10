import type { ReactNode } from 'react'

type Props = {
  crumbs: ReactNode
  actions: ReactNode
}

/**
 * The bar across the top of the canvas. The desktop shell hides the native
 * title bar on macOS, so empty space here drags and zooms the window.
 */
export function TitleBar({ crumbs, actions }: Props) {
  return (
    <header className="titlebar" data-tauri-drag-region="deep">
      <nav className="crumbs" aria-label="Open group">
        {crumbs}
      </nav>
      <div className="titlebar-actions">{actions}</div>
    </header>
  )
}
