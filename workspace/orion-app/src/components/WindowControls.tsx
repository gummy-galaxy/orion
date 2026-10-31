import { useEffect, useState } from 'react'

const loadWindow = () => import('@tauri-apps/api/window').then(({ getCurrentWindow }) => getCurrentWindow())

/** Minimize, maximize, and close for desktop platforms where the shell drops the native frame. */
export function WindowControls() {
  const [maximized, setMaximized] = useState(false)

  useEffect(() => {
    let stop: (() => void) | undefined
    let stopped = false

    void loadWindow()
      .then(async (appWindow) => {
        const sync = async () => setMaximized(await appWindow.isMaximized())
        const unlisten = await appWindow.onResized(() => void sync())

        if (stopped) unlisten()
        else stop = unlisten

        await sync()
      })
      .catch(() => {
        // Outside the desktop shell, such as in Storybook, the buttons do nothing.
      })

    return () => {
      stopped = true
      stop?.()
    }
  }, [])

  return (
    <div className="window-controls" role="group" aria-label="Window">
      <button
        type="button"
        title="Minimize"
        aria-label="Minimize"
        onClick={() => void loadWindow().then((appWindow) => appWindow.minimize())}
      >
        <svg viewBox="0 0 10 10" width="10" height="10" aria-hidden="true">
          <path d="M0 5h10" />
        </svg>
      </button>
      <button
        type="button"
        title={maximized ? 'Restore' : 'Maximize'}
        aria-label={maximized ? 'Restore' : 'Maximize'}
        onClick={() => void loadWindow().then((appWindow) => appWindow.toggleMaximize())}
      >
        <svg viewBox="0 0 10 10" width="10" height="10" aria-hidden="true">
          <path d={maximized ? 'M2.5.5h7v7M.5 2.5h7v7h-7z' : 'M.5.5h9v9h-9z'} />
        </svg>
      </button>
      <button
        type="button"
        className="close"
        title="Close"
        aria-label="Close"
        onClick={() => void loadWindow().then((appWindow) => appWindow.close())}
      >
        <svg viewBox="0 0 10 10" width="10" height="10" aria-hidden="true">
          <path d="M.5.5l9 9M9.5.5l-9 9" />
        </svg>
      </button>
    </div>
  )
}
