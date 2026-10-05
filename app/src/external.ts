/**
 * The desktop shell's webview ignores new-window links, so inside Tauri
 * external links go to the system browser through the opener plugin.
 */

const inDesktop = () => '__TAURI_INTERNALS__' in window

export function openExternal(url: string) {
  if (!inDesktop()) {
    window.open(url, '_blank', 'noreferrer')
    return
  }
  void import('@tauri-apps/plugin-opener').then(({ openUrl }) => openUrl(url))
}

/** Sends clicks on `target="_blank"` links to `openExternal` while running in the desktop shell. */
export function routeExternalLinks() {
  if (!inDesktop()) return
  // Capture, because card badges stop their clicks from bubbling to the canvas.
  document.addEventListener(
    'click',
    (event) => {
      if (event.button !== 0) return
      const link = (event.target as Element | null)?.closest?.('a[target="_blank"]')
      if (!(link instanceof HTMLAnchorElement) || !/^https?:$/.test(link.protocol)) return
      event.preventDefault()
      openExternal(link.href)
    },
    true,
  )
}
