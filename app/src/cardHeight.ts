import type { CardSize } from './cardSize'
import { CARD_TEXT, TASK_HEIGHT, TASK_MAX_HEIGHT } from './geometry'
import type { TaskData } from './model'

const FONT_UI = "'Schibsted Grotesk', system-ui, -apple-system, 'Segoe UI', sans-serif"

/** The fonts and spacing index.css gives each kind of card text. */
const TEXT = {
  label: {
    font: `500 ${CARD_TEXT.label.size}px ${FONT_UI}`,
    size: CARD_TEXT.label.size,
    lineHeight: CARD_TEXT.label.size * CARD_TEXT.label.lineHeight,
  },
  note: { font: `${CARD_TEXT.note.size}px ${FONT_UI}`, size: CARD_TEXT.note.size, lineHeight: CARD_TEXT.note.size * CARD_TEXT.note.lineHeight },
  description: {
    font: `${CARD_TEXT.description.size}px ${FONT_UI}`,
    size: CARD_TEXT.description.size,
    lineHeight: CARD_TEXT.description.size * CARD_TEXT.description.lineHeight,
  },
}

const SHAPE_ROOM: Record<string, { x: number; y: number }> = CARD_TEXT.shapeRoom

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
  } else width = text.length * style.size * CARD_TEXT.characterWidth

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

/**
 * A card's height at the skin's card size. Notes grow past it to show all their text, and components size to theirs;
 * work cards keep the skin's height.
 */
export function taskHeight(data: TaskData, cardSize: CardSize): number {
  let height: number

  if (data.itemKind === 'note') {
    height = CARD_TEXT.chrome + lineCount(data.label || 'Empty note', TEXT.note, cardSize.width - CARD_TEXT.sides.note) * TEXT.note.lineHeight
  } else if (data.itemKind === 'component') {
    const room = SHAPE_ROOM[data.shape ?? ''] ?? { x: 0, y: 0 }
    const width = cardSize.width - CARD_TEXT.sides.component - room.x
    const label = lineCount(data.label || 'Untitled component', TEXT.label, width) * TEXT.label.lineHeight
    const description = data.note ? CARD_TEXT.descriptionGap + lineCount(data.note, TEXT.description, width) * TEXT.description.lineHeight : 0

    height = CARD_TEXT.chrome + room.y + label + description
  } else return cardSize.height

  // A little slack covers rounding and a web font that measures slightly wider than its fallback. Components never
  // shrink below a classic card, whatever the skin.
  const fit = Math.min(TASK_MAX_HEIGHT, Math.max(TASK_HEIGHT, Math.ceil((height + CARD_TEXT.slack) / CARD_TEXT.step) * CARD_TEXT.step))

  return data.itemKind === 'note' ? Math.max(cardSize.height, fit) : fit
}
