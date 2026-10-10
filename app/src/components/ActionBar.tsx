import type { SyncStatus } from '../persist'
import { ToolIcon } from './ToolIcon'

type Props = {
  search: () => void
  addNote: () => void
  addImage: (file: File) => void
  /** Missing when the open group keeps a custom arrangement. */
  tidy?: { label: string; run: () => void }
  sync?: { status: SyncStatus; label: string; run: () => void }
}

const SEARCH = 'M8.5 3.5a5 5 0 1 0 0 10 5 5 0 0 0 0-10zM12.2 12.2L16.5 16.5'
const NOTE = 'M4 4h12v8l-4 4H4zM12 16v-4h4M8 8v4M6 10h4'
const IMAGE = 'M3.5 4.5h13v11h-13zM3.5 13l4-4 3.5 3.5 2-2 3.5 3.5M12.5 7.5h.01'
const TIDY = 'M3.5 3.5h5v5h-5zM11.5 3.5h5v5h-5zM3.5 11.5h5v5h-5zM11.5 11.5h5v5h-5z'
const SYNC = 'M15.5 8A6 6 0 0 0 4.7 6.3M4.5 3v3.5H8M4.5 12a6 6 0 0 0 10.8 1.7M15.5 17v-3.5H12'

/** Canvas actions stacked down the left edge, styled like the tool switcher. */
export function ActionBar({ search, addNote, addImage, tidy, sync }: Props) {
  return (
    <div className="panel toolbar vertical" role="toolbar" aria-label="Canvas actions" aria-orientation="vertical">
      <button type="button" className="tool" title="Search (⌘K)" aria-label="Search" onClick={search}>
        <ToolIcon path={SEARCH} />
      </button>
      <button type="button" className="tool" title="Add note (N)" aria-label="Add note" onClick={addNote}>
        <ToolIcon path={NOTE} />
      </button>
      <label className="tool image-upload" title="Add image">
        <ToolIcon path={IMAGE} />
        <input
          type="file"
          aria-label="Add image"
          accept="image/png,image/jpeg,image/gif,image/webp"
          onChange={(event) => {
            const file = event.currentTarget.files?.[0]

            if (file) addImage(file)

            event.currentTarget.value = ''
          }}
        />
      </label>
      {tidy && (
        <button type="button" className="tool" title={tidy.label} aria-label={tidy.label} onClick={tidy.run}>
          <ToolIcon path={TIDY} />
        </button>
      )}
      {sync && (
        <button
          type="button"
          className={`tool sync is-${sync.status.state}`}
          title={sync.status.message ?? sync.label}
          aria-label={sync.label}
          onClick={sync.run}
        >
          <ToolIcon path={SYNC} />
        </button>
      )}
    </div>
  )
}
