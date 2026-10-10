import { useEffect, type ReactNode } from 'react'
import { ToolIcon } from './ToolIcon'

export type Tool = 'select' | 'hand' | 'comment' | 'sticker'

type ToolSpec = { id: Tool; label: string; key: string; hint: string; icon?: ReactNode }

const TOOLS: ToolSpec[] = [
  {
    id: 'select',
    label: 'Select',
    key: 'V',
    hint: 'Drag to select, middle-drag or hold Space to pan',
    icon: <ToolIcon path="M5 3l10 6.5-4.6 1.1L13 16l-2 1-2.6-5.4L5 15z" />,
  },
  {
    id: 'hand',
    label: 'Pan',
    key: 'H',
    hint: 'Drag anywhere to pan, ⌘-drag to select',
    icon: (
      <ToolIcon path="M7 10V4.8a1.2 1.2 0 0 1 2.4 0V9m0-.5V3.6a1.2 1.2 0 0 1 2.4 0V9m0-.5V4.6a1.2 1.2 0 0 1 2.4 0V11m0-4a1.2 1.2 0 0 1 2.4 0v5c0 3-2.2 5-5 5h-1.2c-1.8 0-3-.8-4-2.2L3.4 11a1.2 1.2 0 0 1 2-1.4L7 11.5" />
    ),
  },
  {
    id: 'comment',
    label: 'Comment',
    key: 'C',
    hint: 'Click to leave a note',
    icon: <ToolIcon path="M4 4h12v9h-6l-4 3.5V13H4z" />,
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
    const onKey = (event: KeyboardEvent) => {
      if (event.repeat || event.metaKey || event.ctrlKey || event.altKey || (event.target as HTMLElement).closest('input, textarea, select')) return

      const picked = TOOLS.find((toolSpec) => toolSpec.key.toLowerCase() === event.key.toLowerCase())

      if (picked) setTool(picked.id)
    }

    window.addEventListener('keydown', onKey)

    return () => window.removeEventListener('keydown', onKey)
  }, [setTool])

  return (
    <div className="panel toolbar" role="toolbar" aria-label="Canvas tools">
      {TOOLS.map((toolSpec) => (
        <button
          key={toolSpec.id}
          type="button"
          className={`tool${tool === toolSpec.id ? ' current' : ''}`}
          aria-pressed={tool === toolSpec.id}
          title={`${toolSpec.label} (${toolSpec.key}): ${toolSpec.hint}`}
          onClick={(event) => setTool(toolSpec.id, event.currentTarget.getBoundingClientRect())}
        >
          {toolSpec.icon ?? <span className="tool-emoji">{sticker}</span>}
        </button>
      ))}
    </div>
  )
}
