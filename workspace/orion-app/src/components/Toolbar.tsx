import { useEffect, type ReactNode } from 'react'
import { matchesChord, withChord, type Keybindings, type ShortcutId } from '../keybindings'
import { ToolIcon } from './ToolIcon'

export type Tool = 'select' | 'hand' | 'comment' | 'sticker'

type ToolSpec = { id: Tool; label: string; shortcut: ShortcutId; hint: string; icon?: ReactNode }

const TOOLS: ToolSpec[] = [
  {
    id: 'select',
    label: 'Select',
    shortcut: 'tool-select',
    hint: 'Drag to select, middle-drag or hold Space to pan',
    icon: <ToolIcon path="M5 3l10 6.5-4.6 1.1L13 16l-2 1-2.6-5.4L5 15z" />,
  },
  {
    id: 'hand',
    label: 'Pan',
    shortcut: 'tool-hand',
    hint: 'Drag anywhere to pan, ⌘-drag to select or move',
    icon: (
      <ToolIcon path="M7 10V4.8a1.2 1.2 0 0 1 2.4 0V9m0-.5V3.6a1.2 1.2 0 0 1 2.4 0V9m0-.5V4.6a1.2 1.2 0 0 1 2.4 0V11m0-4a1.2 1.2 0 0 1 2.4 0v5c0 3-2.2 5-5 5h-1.2c-1.8 0-3-.8-4-2.2L3.4 11a1.2 1.2 0 0 1 2-1.4L7 11.5" />
    ),
  },
  {
    id: 'comment',
    label: 'Comment',
    shortcut: 'tool-comment',
    hint: 'Click to leave a note',
    icon: <ToolIcon path="M4 4h12v9h-6l-4 3.5V13H4z" />,
  },
  {
    id: 'sticker',
    label: 'Sticker',
    shortcut: 'tool-sticker',
    hint: 'Hold its key to pick from the wheel, then click to stamp',
  },
]

type Props = { tool: Tool; sticker: string; keybindings: Keybindings; setTool: (tool: Tool, from?: DOMRect) => void }

/**
 * The canvas's tool switcher. Each tool's shortcut picks it from anywhere outside a text field.
 * `from` is the button that picked the tool, when it wasn't a key.
 */
export function Toolbar({ tool, sticker, keybindings, setTool }: Props) {
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.repeat || (event.target as HTMLElement).closest('input, textarea, select')) return

      const picked = TOOLS.find((toolSpec) => matchesChord(event, keybindings[toolSpec.shortcut]))

      if (picked) setTool(picked.id)
    }

    window.addEventListener('keydown', onKey)

    return () => window.removeEventListener('keydown', onKey)
  }, [keybindings, setTool])

  return (
    <div className="panel toolbar" role="toolbar" aria-label="Canvas tools">
      {TOOLS.map((toolSpec) => (
        <button
          key={toolSpec.id}
          type="button"
          className={`tool${tool === toolSpec.id ? ' current' : ''}`}
          aria-pressed={tool === toolSpec.id}
          title={`${withChord(toolSpec.label, keybindings[toolSpec.shortcut])}: ${toolSpec.hint}`}
          onClick={(event) => setTool(toolSpec.id, event.currentTarget.getBoundingClientRect())}
        >
          {toolSpec.icon ?? <span className="tool-emoji">{sticker}</span>}
        </button>
      ))}
    </div>
  )
}
