import { useEffect, type ReactNode } from 'react'

export type Tool = 'select' | 'hand' | 'comment' | 'sticker'

type ToolSpec = { id: Tool; label: string; key: string; hint: string; icon?: ReactNode }

const icon = (d: string) => (
  <svg viewBox="0 0 20 20" width="18" height="18" aria-hidden="true">
    <path d={d} fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
  </svg>
)

const TOOLS: ToolSpec[] = [
  {
    id: 'select',
    label: 'Select',
    key: 'V',
    hint: 'Drag to select, middle-drag or hold Space to pan',
    icon: icon('M5 3l10 6.5-4.6 1.1L13 16l-2 1-2.6-5.4L5 15z'),
  },
  {
    id: 'hand',
    label: 'Pan',
    key: 'H',
    hint: 'Drag anywhere to pan, ⌘-drag to select',
    icon: icon(
      'M7 10V4.8a1.2 1.2 0 0 1 2.4 0V9m0-.5V3.6a1.2 1.2 0 0 1 2.4 0V9m0-.5V4.6a1.2 1.2 0 0 1 2.4 0V11m0-4a1.2 1.2 0 0 1 2.4 0v5c0 3-2.2 5-5 5h-1.2c-1.8 0-3-.8-4-2.2L3.4 11a1.2 1.2 0 0 1 2-1.4L7 11.5',
    ),
  },
  {
    id: 'comment',
    label: 'Comment',
    key: 'C',
    hint: 'Click to leave a note',
    icon: icon('M4 4h12v9h-6l-4 3.5V13H4z'),
  },
  {
    id: 'sticker',
    label: 'Sticker',
    key: 'S',
    hint: 'Hold S to pick from the wheel, then click to stamp',
  },
]

/**
 * The canvas's tool switcher. Each tool's letter picks it from anywhere outside a text field.
 * `from` is the button that picked the tool, when it wasn't a key.
 */
export function Toolbar({ tool, sticker, setTool }: { tool: Tool; sticker: string; setTool: (tool: Tool, from?: DOMRect) => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.repeat || e.metaKey || e.ctrlKey || e.altKey || (e.target as HTMLElement).closest('input, textarea, select')) return
      const picked = TOOLS.find((t) => t.key.toLowerCase() === e.key.toLowerCase())
      if (picked) setTool(picked.id)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [setTool])
  return (
    <div className="panel toolbar" role="toolbar" aria-label="Canvas tools">
      {TOOLS.map((t) => (
        <button
          key={t.id}
          type="button"
          className={`tool${tool === t.id ? ' current' : ''}`}
          aria-pressed={tool === t.id}
          title={`${t.label} (${t.key}): ${t.hint}`}
          onClick={(e) => setTool(t.id, e.currentTarget.getBoundingClientRect())}
        >
          {t.icon ?? <span className="tool-emoji">{sticker}</span>}
        </button>
      ))}
    </div>
  )
}
