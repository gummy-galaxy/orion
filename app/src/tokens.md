# Visual tokens

Every color, status color, font, weight, text size, radius, spacing value, shadow, and transition timing in the app reads a named token. Names describe the role a value plays, such as `card.background`, rather than the value itself. Each token is a CSS custom property, so a theme can change it without touching components.

- `tokens.css` sets the values every theme shares.
- `themes/<id>.css` sets the colors for one theme. A theme can set any token.
- `tokens.ts` lists every token, its CSS property, and its legacy name. The list is the machine-readable form of this page.

Token names are a public contract for theme files (#221). Add new tokens freely. When a token is renamed, keep the old custom property as an alias, and never drop one silently.

Legacy names such as `--bg`, `--st-ready`, or `--shadow` still work. Each aliases its new custom property in `tokens.css`, so CSS written against them keeps resolving.

## Color

| Name                      | CSS property                | Legacy          | Used for                                          |
| ------------------------- | --------------------------- | --------------- | ------------------------------------------------- |
| `canvas.background`       | `--canvas-background`       | `--bg`          | The canvas and the app background                 |
| `canvas.dots`             | `--canvas-dots`             | `--dots`        | Grid dots on the canvas                           |
| `surface.background`      | `--surface-background`      | `--surface`     | Menus, panels, and other raised surfaces          |
| `card.background`         | `--card-background`         |                 | A card's fill; defaults to the surface            |
| `card.border`             | `--card-border`             |                 | A card's outline; defaults to the default border  |
| `text.primary`            | `--text-primary`            | `--ink`         | Body text and icons                               |
| `text.muted`              | `--text-muted`              | `--muted`       | Secondary text and quiet icons                    |
| `border.default`          | `--border-default`          | `--line`        | Dividers and outlines                             |
| `accent.default`          | `--accent-default`          | `--accent`      | Focus rings, links, and selection                 |
| `accent.subtle`           | `--accent-subtle`           | `--accent-soft` | Tinted backgrounds behind accent content          |
| `edge.default`            | `--edge-default`            | `--edge`        | Links between cards                               |
| `edge.hot`                | `--edge-hot`                |                 | Live and held links                               |
| `edge.held`               | `--edge-held`               |                 | Links held in place by a dependency               |
| `note.background`         | `--note-background`         | `--note`        | A note's paper                                    |
| `note.border`             | `--note-border`             | `--note-edge`   | A note's edge and fold                            |
| `note.text`               | `--note-text`               | `--note-ink`    | A note's text                                     |
| `snap.guide`              | `--snap-guide`              | `--snap`        | Alignment guides while dragging                   |
| `sticker.edge`            | `--sticker-edge`            |                 | The die-cut edge around a sticker                 |
| `window.close.background` | `--window-close-background` |                 | The close button on hover                         |
| `window.close.text`       | `--window-close-text`       |                 | The close button's glyph on hover                 |
| `companion.body`          | `--companion-body`          |                 | The star companion's fill                         |
| `companion.edge`          | `--companion-edge`          |                 | The outline around each of the companion's stars  |
| `companion.ink`           | `--companion-ink`           |                 | The companion's face                              |
| `companion.halo`          | `--companion-halo`          |                 | The soft light right around the companion's stars |
| `companion.glow`          | `--companion-glow`          |                 | The glow around the companion and its tethers     |
| `companion.tether`        | `--companion-tether`        |                 | The lines joining the companion's three stars     |

## Status

Status colors also carry a shape, so they never stand alone. The colorblind sets in `themes/colorblind.css` replace these values.

| Name             | CSS property       | Legacy         | Used for                                        |
| ---------------- | ------------------ | -------------- | ----------------------------------------------- |
| `status.todo`    | `--status-todo`    | `--st-todo`    | Not started, and deferred work                  |
| `status.ready`   | `--status-ready`   | `--st-ready`   | Work that can start now; defaults to the accent |
| `status.active`  | `--status-active`  | `--st-active`  | In progress                                     |
| `status.review`  | `--status-review`  | `--st-review`  | Waiting on review                               |
| `status.blocked` | `--status-blocked` | `--st-blocked` | Waiting on open work                            |
| `status.done`    | `--status-done`    | `--st-done`    | Finished                                        |

## Font

| Name        | CSS property  | Used for                                          |
| ----------- | ------------- | ------------------------------------------------- |
| `font.ui`   | `--font-ui`   | Interface text                                    |
| `font.data` | `--font-data` | Monospace text, such as shortcuts and identifiers |

## Weight

| Name              | CSS property        | Value |
| ----------------- | ------------------- | ----- |
| `weight.regular`  | `--weight-regular`  | 400   |
| `weight.medium`   | `--weight-medium`   | 500   |
| `weight.semibold` | `--weight-semibold` | 600   |
| `weight.bold`     | `--weight-bold`     | 700   |

## Text size

Sizes are named for the role they most often play. A size is shared by every role that uses that exact value.

| Name                    | CSS property              | Value  | Used for                                 |
| ----------------------- | ------------------------- | ------ | ---------------------------------------- |
| `text.size.mini`        | `--text-size-mini`        | 8px    | Smallest tags                            |
| `text.size.tiny`        | `--text-size-tiny`        | 10px   | Level and status badges                  |
| `text.size.micro`       | `--text-size-micro`       | 10.5px | Card meta and keyboard keys              |
| `text.size.caption`     | `--text-size-caption`     | 11px   | Edge labels and counts                   |
| `text.size.detail`      | `--text-size-detail`      | 11.5px | Secondary facts and footers              |
| `text.size.small`       | `--text-size-small`       | 12px   | Helper text and image labels             |
| `text.size.label`       | `--text-size-label`       | 12.5px | Card labels and buttons                  |
| `text.size.body`        | `--text-size-body`        | 13px   | Most controls and settings text          |
| `text.size.emphasis`    | `--text-size-emphasis`    | 13.5px | Group headings on the canvas             |
| `text.size.base`        | `--text-size-base`        | 14px   | The page's base size                     |
| `text.size.subheading`  | `--text-size-subheading`  | 15px   | Settings navigation headings             |
| `text.size.input`       | `--text-size-input`       | 16px   | The command palette's input              |
| `text.size.heading`     | `--text-size-heading`     | 17px   | Settings section headings and tool icons |
| `text.size.glyph`       | `--text-size-glyph`       | 18px   | Small glyph buttons                      |
| `text.size.glyph-large` | `--text-size-glyph-large` | 20px   | The settings close glyph                 |
| `text.size.sticker`     | `--text-size-sticker`     | 28px   | Sticker wheel items                      |
| `text.size.sticker-art` | `--text-size-sticker-art` | 40px   | Stickers on the canvas                   |

## Radius

| Name                 | CSS property           | Value       | Used for                       |
| -------------------- | ---------------------- | ----------- | ------------------------------ |
| `radius.xs`          | `--radius-xs`          | 4px         | Small tags and chips           |
| `radius.sm`          | `--radius-sm`          | 6px         | Buttons and inputs             |
| `radius.md`          | `--radius-md`          | 8px         | Menus and rows                 |
| `radius.lg`          | `--radius-lg`          | 12px        | Large panels and images        |
| `radius.card`        | `--radius-card`        | 8px         | Cards; defaults to `radius.md` |
| `radius.pill`        | `--radius-pill`        | 999px       | Fully rounded tags and counts  |
| `radius.round`       | `--radius-round`       | 50%         | Circles                        |
| `radius.hairline`    | `--radius-hairline`    | 2px         | A thin bar                     |
| `radius.note-corner` | `--radius-note-corner` | 0 7px 0 3px | A note's folded corner         |

## Space

Spacing follows a 4px rhythm with half steps. Use these for `gap`, `padding`, and `margin`.

| Name       | CSS property | Value |
| ---------- | ------------ | ----- |
| `space.1`  | `--space-1`  | 2px   |
| `space.2`  | `--space-2`  | 4px   |
| `space.3`  | `--space-3`  | 6px   |
| `space.4`  | `--space-4`  | 8px   |
| `space.5`  | `--space-5`  | 10px  |
| `space.6`  | `--space-6`  | 12px  |
| `space.7`  | `--space-7`  | 14px  |
| `space.8`  | `--space-8`  | 16px  |
| `space.9`  | `--space-9`  | 20px  |
| `space.10` | `--space-10` | 24px  |

## Shadow

`shadow.raised` comes from the theme, since it has to read on that theme's background. The rest are shared.

| Name                  | CSS property            | Legacy     | Used for                                           |
| --------------------- | ----------------------- | ---------- | -------------------------------------------------- |
| `shadow.raised`       | `--shadow-raised`       | `--shadow` | Cards, panels, menus, and other raised surfaces    |
| `shadow.image`        | `--shadow-image`        |            | Image nodes                                        |
| `shadow.dialog`       | `--shadow-dialog`       |            | Settings and the command palette                   |
| `shadow.selection`    | `--shadow-selection`    |            | The halo around a selected card                    |
| `shadow.lift`         | `--shadow-lift`         |            | The hovered card: a light ring and a deeper shadow |
| `shadow.sticker`      | `--shadow-sticker`      |            | A sticker resting on the canvas; one layer only    |
| `shadow.sticker-held` | `--shadow-sticker-held` |            | A sticker being dragged; one layer only            |

The sticker shadows go inside `drop-shadow()`, so each must be a single shadow with no `inset` or spread.

## Motion

Durations and easings for transitions and one-shot animations. Like text sizes, each exact value is one token, named for the role it most often plays. Motion settings still decide whether animations run at all.

| Name                      | CSS property                | Value | Used for                                      |
| ------------------------- | --------------------------- | ----- | --------------------------------------------- |
| `motion.duration.stagger` | `--motion-duration-stagger` | 16ms  | The delay between sticker wheel items opening |
| `motion.duration.instant` | `--motion-duration-instant` | 120ms | Tooltips and sticker wheel hovers             |
| `motion.duration.quick`   | `--motion-duration-quick`   | 140ms | A sticker growing under the pointer           |
| `motion.duration.fast`    | `--motion-duration-fast`    | 150ms | Handles, hover actions, and border changes    |
| `motion.duration.open`    | `--motion-duration-open`    | 160ms | The sticker wheel opening                     |
| `motion.duration.fade`    | `--motion-duration-fade`    | 180ms | Nodes and panels fading in and out            |
| `motion.duration.base`    | `--motion-duration-base`    | 200ms | Card, group, and link fades                   |
| `motion.duration.reveal`  | `--motion-duration-reveal`  | 240ms | Sticker wheel items popping in                |
| `motion.duration.pop`     | `--motion-duration-pop`     | 340ms | A far-zoom card popping up                    |
| `motion.duration.stamp`   | `--motion-duration-stamp`   | 360ms | The finish stamp landing                      |

| Name                     | CSS property               | Value                             | Used for                                 |
| ------------------------ | -------------------------- | --------------------------------- | ---------------------------------------- |
| `motion.easing.standard` | `--motion-easing-standard` | ease                              | Hover changes                            |
| `motion.easing.enter`    | `--motion-easing-enter`    | ease-out                          | Things appearing                         |
| `motion.easing.exit`     | `--motion-easing-exit`     | ease-in                           | Things leaving                           |
| `motion.easing.pop`      | `--motion-easing-pop`      | cubic-bezier(0.2, 0.9, 0.3, 1.25) | Stamps and far-zoom cards, with a bounce |
| `motion.easing.bounce`   | `--motion-easing-bounce`   | cubic-bezier(0.2, 0.9, 0.3, 1.3)  | Sticker wheel items, with more bounce    |
| `motion.easing.stamp`    | `--motion-easing-stamp`    | cubic-bezier(0.2, 0.9, 0.3, 1.2)  | A sticker stamping down                  |

## Not named yet

These are left for later passes, so they keep their literal values:

- Sounds. The app plays none yet.
- Looping animations, such as flowing links, the active pulse, and the sync spinner. Each `steps()` count is paired with its duration to hold 15 frames a second, so the two change together.
- Durations a script waits on: the finish stamp clearing (420ms, `CLEAR_MS` in `celebrate.ts`) and a fresh sticker's stamp and ring (520ms, and 480ms after 140ms, inside `STICKER_FRESH_MS`). A theme that lengthened them would see them cut off.
- Rings and stripes built from color tokens, such as a card's inset status stripe and the 1px tracing outlines. Their widths are part of the shape, not the elevation.
- The trading card skin's frame, gate, sticker, and tile shadows, which belong to its art like its other literal colors.
- Line heights, and layout sizes such as tool buttons and the space reserved beside panels.
- Spacing values off the scale: 1, 3, 5, 7, 9, 11, 15, 18, and 22px. Extending the scale or naming each one is an open question.
- The canvas dot pitch and size passed to React Flow in `Canvas.tsx`, which are not CSS properties.
- The transparent mask gradient in `index.css`.
