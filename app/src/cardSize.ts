import type { TaskData } from './model'

/** Matches `TASK_WIDTH` and `TASK_HEIGHT` in model.ts, which import this module. */
const WIDTH = 216
const MIN_HEIGHT = 72
/** Notes and components stop growing here, so one long paragraph can't swallow a group. */
const MAX_HEIGHT = 320

const FONT_UI = "'Schibsted Grotesk', system-ui, -apple-system, 'Segoe UI', sans-serif"

/** The fonts and spacing index.css gives each kind of card text. */
const TEXT = {
  label: { font: `500 12.5px ${FONT_UI}`, size: 12.5, lineHeight: 12.5 * 1.25 },
  note: { font: `12px ${FONT_UI}`, size: 12, lineHeight: 12 * 1.3 },
  description: { font: `11.5px ${FONT_UI}`, size: 11.5, lineHeight: 11.5 * 1.25 },
}

/** Card padding top and bottom, the meta row, and the gap after it. */
const CHROME = 20 + 13 + 3
/** Room the source badge keeps on the right of a line, and the card's side padding. */
const SIDES = { note: 15 + 12 + 22, component: 12 + 12 + 22 }
/** Extra room some component shapes need around their text. */
const SHAPE_ROOM: Record<string, { x: number; y: number }> = {
  store: { x: 0, y: 12 },
  actor: { x: 12, y: 0 },
  interface: { x: 0, y: 8 },
  process: { x: 28, y: 0 },
  queue: { x: 8, y: 8 },
}

let context: CanvasRenderingContext2D | null | undefined
const widths = new Map<string, number>()

function measure(text: string, style: (typeof TEXT)[keyof typeof TEXT]): number {
  const key = style.font + '\n' + text
  const known = widths.get(key)

  if (known !== undefined) return known

  if (context === undefined) context = typeof document === 'undefined' ? null : document.createElement('canvas').getContext('2d')

  let width: number

  if (context) {
    context.font = style.font
    width = context.measureText(text).width
  } else width = text.length * style.size * 0.55

  widths.set(key, width)

  return width
}

/** How many lines `text` wraps to at `width`, breaking between words and at newlines like the card does. */
function lineCount(text: string, style: (typeof TEXT)[keyof typeof TEXT], width: number): number {
  let lines = 0

  for (const paragraph of text.split('\n')) {
    let line = ''

    lines++

    for (const word of paragraph.split(/\s+/).filter(Boolean)) {
      const next = line ? line + ' ' + word : word

      if (!line || measure(next, style) <= width) {
        line = next
        continue
      }

      lines++
      line = word
    }

    // A word too long for one line breaks anywhere, as `overflow-wrap: anywhere` lets it.
    lines += Math.max(0, Math.ceil(measure(line, style) / width) - 1)
  }

  return lines
}

/** Fonts that arrive after a first measure change every width, so measure again. */
export function forgetTextWidths() {
  widths.clear()
}

/** A card's height. Notes and components grow to show all their text; work cards keep one size. */
export function taskHeight(data: TaskData): number {
  let height: number

  if (data.itemKind === 'note') {
    height = CHROME + lineCount(data.label || 'Empty note', TEXT.note, WIDTH - SIDES.note) * TEXT.note.lineHeight
  } else if (data.itemKind === 'component') {
    const room = SHAPE_ROOM[data.shape ?? ''] ?? { x: 0, y: 0 }
    const width = WIDTH - SIDES.component - room.x
    const label = lineCount(data.label || 'Untitled component', TEXT.label, width) * TEXT.label.lineHeight
    const description = data.note ? 3 + lineCount(data.note, TEXT.description, width) * TEXT.description.lineHeight : 0

    height = CHROME + room.y + label + description
  } else return MIN_HEIGHT

  // A little slack covers rounding and a web font that measures slightly wider than its fallback.
  return Math.min(MAX_HEIGHT, Math.max(MIN_HEIGHT, Math.ceil((height + 4) / 4) * 4))
}
