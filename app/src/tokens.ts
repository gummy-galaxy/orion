/**
 * Every named visual token. Components read the CSS custom property; `legacy` names alias it so older CSS keeps working.
 * Keep this list, tokens.css, and tokens.md in step. tokens.test.ts checks all three, and checks that each theme defines
 * every token.
 */
export type TokenGroup = 'color' | 'status' | 'font' | 'weight' | 'size' | 'radius' | 'border' | 'space' | 'shadow' | 'duration' | 'easing'

export type Token = {
  /** The role-based name documented in tokens.md, such as card.background. */
  name: string
  /** The custom property components read, such as --card-background. */
  cssVar: string
  group: TokenGroup
  /** The older custom property that still aliases this token. */
  legacy?: string
}

export const TOKENS: readonly Token[] = [
  { name: 'canvas.background', cssVar: '--canvas-background', group: 'color', legacy: '--bg' },
  { name: 'canvas.dots', cssVar: '--canvas-dots', group: 'color', legacy: '--dots' },
  { name: 'surface.background', cssVar: '--surface-background', group: 'color', legacy: '--surface' },
  { name: 'card.background', cssVar: '--card-background', group: 'color' },
  { name: 'card.border', cssVar: '--card-border', group: 'color' },
  { name: 'text.primary', cssVar: '--text-primary', group: 'color', legacy: '--ink' },
  { name: 'text.muted', cssVar: '--text-muted', group: 'color', legacy: '--muted' },
  { name: 'border.default', cssVar: '--border-default', group: 'color', legacy: '--line' },
  { name: 'accent.default', cssVar: '--accent-default', group: 'color', legacy: '--accent' },
  { name: 'accent.subtle', cssVar: '--accent-subtle', group: 'color', legacy: '--accent-soft' },
  { name: 'edge.default', cssVar: '--edge-default', group: 'color', legacy: '--edge' },
  { name: 'edge.hot', cssVar: '--edge-hot', group: 'color' },
  { name: 'edge.held', cssVar: '--edge-held', group: 'color' },
  { name: 'edge.still', cssVar: '--edge-still', group: 'color' },
  { name: 'note.background', cssVar: '--note-background', group: 'color', legacy: '--note' },
  { name: 'note.border', cssVar: '--note-border', group: 'color', legacy: '--note-edge' },
  { name: 'note.text', cssVar: '--note-text', group: 'color', legacy: '--note-ink' },
  { name: 'snap.guide', cssVar: '--snap-guide', group: 'color', legacy: '--snap' },
  { name: 'sticker.edge', cssVar: '--sticker-edge', group: 'color' },
  { name: 'window.close.background', cssVar: '--window-close-background', group: 'color' },
  { name: 'window.close.text', cssVar: '--window-close-text', group: 'color' },
  { name: 'companion.body', cssVar: '--companion-body', group: 'color' },
  { name: 'companion.edge', cssVar: '--companion-edge', group: 'color' },
  { name: 'companion.ink', cssVar: '--companion-ink', group: 'color' },
  { name: 'companion.halo', cssVar: '--companion-halo', group: 'color' },
  { name: 'companion.glow', cssVar: '--companion-glow', group: 'color' },
  { name: 'companion.tether', cssVar: '--companion-tether', group: 'color' },

  { name: 'status.todo', cssVar: '--status-todo', group: 'status', legacy: '--st-todo' },
  { name: 'status.ready', cssVar: '--status-ready', group: 'status', legacy: '--st-ready' },
  { name: 'status.active', cssVar: '--status-active', group: 'status', legacy: '--st-active' },
  { name: 'status.review', cssVar: '--status-review', group: 'status', legacy: '--st-review' },
  { name: 'status.blocked', cssVar: '--status-blocked', group: 'status', legacy: '--st-blocked' },
  { name: 'status.done', cssVar: '--status-done', group: 'status', legacy: '--st-done' },

  { name: 'tint.teal', cssVar: '--tint-teal', group: 'color' },
  { name: 'tint.blue', cssVar: '--tint-blue', group: 'color' },
  { name: 'tint.purple', cssVar: '--tint-purple', group: 'color' },
  { name: 'tint.amber', cssVar: '--tint-amber', group: 'color' },
  { name: 'tint.rose', cssVar: '--tint-rose', group: 'color' },
  { name: 'tint.green', cssVar: '--tint-green', group: 'color' },
  { name: 'tint.slate', cssVar: '--tint-slate', group: 'color' },

  { name: 'font.ui', cssVar: '--font-ui', group: 'font' },
  { name: 'font.data', cssVar: '--font-data', group: 'font' },

  { name: 'weight.regular', cssVar: '--weight-regular', group: 'weight' },
  { name: 'weight.medium', cssVar: '--weight-medium', group: 'weight' },
  { name: 'weight.semibold', cssVar: '--weight-semibold', group: 'weight' },
  { name: 'weight.bold', cssVar: '--weight-bold', group: 'weight' },
  { name: 'weight.extrabold', cssVar: '--weight-extrabold', group: 'weight' },

  { name: 'text.size.mini', cssVar: '--text-size-mini', group: 'size' },
  { name: 'text.size.nano', cssVar: '--text-size-nano', group: 'size' },
  { name: 'text.size.tiny', cssVar: '--text-size-tiny', group: 'size' },
  { name: 'text.size.micro', cssVar: '--text-size-micro', group: 'size' },
  { name: 'text.size.caption', cssVar: '--text-size-caption', group: 'size' },
  { name: 'text.size.detail', cssVar: '--text-size-detail', group: 'size' },
  { name: 'text.size.small', cssVar: '--text-size-small', group: 'size' },
  { name: 'text.size.label', cssVar: '--text-size-label', group: 'size' },
  { name: 'text.size.body', cssVar: '--text-size-body', group: 'size' },
  { name: 'text.size.emphasis', cssVar: '--text-size-emphasis', group: 'size' },
  { name: 'text.size.base', cssVar: '--text-size-base', group: 'size' },
  { name: 'text.size.subheading', cssVar: '--text-size-subheading', group: 'size' },
  { name: 'text.size.input', cssVar: '--text-size-input', group: 'size' },
  { name: 'text.size.heading', cssVar: '--text-size-heading', group: 'size' },
  { name: 'text.size.glyph', cssVar: '--text-size-glyph', group: 'size' },
  { name: 'text.size.glyph-large', cssVar: '--text-size-glyph-large', group: 'size' },
  { name: 'text.size.sticker', cssVar: '--text-size-sticker', group: 'size' },
  { name: 'text.size.sticker-art', cssVar: '--text-size-sticker-art', group: 'size' },

  { name: 'radius.xs', cssVar: '--radius-xs', group: 'radius' },
  { name: 'radius.sm', cssVar: '--radius-sm', group: 'radius' },
  { name: 'radius.md', cssVar: '--radius-md', group: 'radius' },
  { name: 'radius.lg', cssVar: '--radius-lg', group: 'radius' },
  { name: 'radius.card', cssVar: '--radius-card', group: 'radius' },
  { name: 'radius.pill', cssVar: '--radius-pill', group: 'radius' },
  { name: 'radius.round', cssVar: '--radius-round', group: 'radius' },
  { name: 'radius.hairline', cssVar: '--radius-hairline', group: 'radius' },
  { name: 'radius.note-corner', cssVar: '--radius-note-corner', group: 'radius' },

  { name: 'border.width.default', cssVar: '--border-width-default', group: 'border' },
  { name: 'border.width.strong', cssVar: '--border-width-strong', group: 'border' },

  { name: 'space.1', cssVar: '--space-1', group: 'space' },
  { name: 'space.2', cssVar: '--space-2', group: 'space' },
  { name: 'space.3', cssVar: '--space-3', group: 'space' },
  { name: 'space.4', cssVar: '--space-4', group: 'space' },
  { name: 'space.5', cssVar: '--space-5', group: 'space' },
  { name: 'space.6', cssVar: '--space-6', group: 'space' },
  { name: 'space.7', cssVar: '--space-7', group: 'space' },
  { name: 'space.8', cssVar: '--space-8', group: 'space' },
  { name: 'space.9', cssVar: '--space-9', group: 'space' },
  { name: 'space.10', cssVar: '--space-10', group: 'space' },

  { name: 'shadow.raised', cssVar: '--shadow-raised', group: 'shadow', legacy: '--shadow' },
  { name: 'shadow.image', cssVar: '--shadow-image', group: 'shadow' },
  { name: 'shadow.dialog', cssVar: '--shadow-dialog', group: 'shadow' },
  { name: 'shadow.selection', cssVar: '--shadow-selection', group: 'shadow' },
  { name: 'shadow.lift', cssVar: '--shadow-lift', group: 'shadow' },
  { name: 'shadow.sticker', cssVar: '--shadow-sticker', group: 'shadow' },
  { name: 'shadow.sticker-held', cssVar: '--shadow-sticker-held', group: 'shadow' },

  { name: 'motion.duration.stagger', cssVar: '--motion-duration-stagger', group: 'duration' },
  { name: 'motion.duration.blink', cssVar: '--motion-duration-blink', group: 'duration' },
  { name: 'motion.duration.instant', cssVar: '--motion-duration-instant', group: 'duration' },
  { name: 'motion.duration.quick', cssVar: '--motion-duration-quick', group: 'duration' },
  { name: 'motion.duration.fast', cssVar: '--motion-duration-fast', group: 'duration' },
  { name: 'motion.duration.open', cssVar: '--motion-duration-open', group: 'duration' },
  { name: 'motion.duration.fade', cssVar: '--motion-duration-fade', group: 'duration' },
  { name: 'motion.duration.base', cssVar: '--motion-duration-base', group: 'duration' },
  { name: 'motion.duration.reveal', cssVar: '--motion-duration-reveal', group: 'duration' },
  { name: 'motion.duration.pop', cssVar: '--motion-duration-pop', group: 'duration' },
  { name: 'motion.duration.stamp', cssVar: '--motion-duration-stamp', group: 'duration' },

  { name: 'motion.easing.standard', cssVar: '--motion-easing-standard', group: 'easing' },
  { name: 'motion.easing.enter', cssVar: '--motion-easing-enter', group: 'easing' },
  { name: 'motion.easing.exit', cssVar: '--motion-easing-exit', group: 'easing' },
  { name: 'motion.easing.pop', cssVar: '--motion-easing-pop', group: 'easing' },
  { name: 'motion.easing.bounce', cssVar: '--motion-easing-bounce', group: 'easing' },
  { name: 'motion.easing.stamp', cssVar: '--motion-easing-stamp', group: 'easing' },
]
