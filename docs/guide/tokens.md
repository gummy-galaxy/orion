# Theme tokens

Every color, font, size, spacing step, shadow, and timing in the app reads a named token. A [theme file](/guide/themes) sets tokens by name, and anything it leaves out keeps its default. The defaults below are what Orion's Classic theme uses.

Names describe the role a value plays, such as `card.background`, rather than the value itself. Each token is also a CSS custom property, named by swapping the dots for dashes and adding two in front: `card.background` is `--card-background`. A theme file uses the name. A value that refers to another token uses the property, as in `var(--surface-background)`.

## Names are a contract

Token names are a public contract, so a theme written today keeps working as Orion changes.

- **New tokens can be added at any time.** A theme that doesn't set one gets the default.
- **A renamed token keeps its old name as an alias.** The old name goes on working, in theme files and as a custom property.
- **No token is dropped silently.** One is removed only on purpose, and the change that removes it says so.

The [aliases](#aliases) section lists every older name that still works.

## Color

Colors have a light and a dark default. Classic sets both, and a theme can set either.

| Name                      | Light                                                              | Dark                                                               | Used for                                          |
| ------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------ | ------------------------------------------------- |
| `canvas.background`       | `#f3f5f6`                                                          | `#0f1619`                                                          | The canvas and the app background                 |
| `canvas.dots`             | `#c3ccd1`                                                          | `#26343a`                                                          | Grid dots on the canvas                           |
| `surface.background`      | `#ffffff`                                                          | `#172227`                                                          | Menus, panels, and other raised surfaces          |
| `card.background`         | `var(--surface-background)`                                        | `var(--surface-background)`                                        | A card's fill                                     |
| `card.border`             | `var(--border-default)`                                            | `var(--border-default)`                                            | A card's outline                                  |
| `text.primary`            | `#17242b`                                                          | `#e3eaed`                                                          | Body text and icons                               |
| `text.muted`              | `#5d6d75`                                                          | `#92a3aa`                                                          | Secondary text and quiet icons                    |
| `border.default`          | `#d3dbdf`                                                          | `#2b3a41`                                                          | Dividers and outlines                             |
| `accent.default`          | `#0d6f74`                                                          | `#4fc1c4`                                                          | Focus rings, links, and selection                 |
| `accent.subtle`           | `#d8eeee`                                                          | `#163a3c`                                                          | Tinted backgrounds behind accent content          |
| `edge.default`            | `#9aa9b0`                                                          | `#4c5d65`                                                          | Links between cards                               |
| `edge.hot`                | `#0d6f74`                                                          | `#4fc1c4`                                                          | Live and held links                               |
| `edge.held`               | `color-mix(in srgb, var(--edge-hot) 25%, var(--edge-default))`     | `color-mix(in srgb, var(--edge-hot) 25%, var(--edge-default))`     | Links held in place by a dependency               |
| `edge.still`              | `color-mix(in srgb, var(--text-primary) 45%, var(--edge-default))` | `color-mix(in srgb, var(--text-primary) 45%, var(--edge-default))` | Links out of components, which carry no work      |
| `note.background`         | `#fbf3d5`                                                          | `#2e2a17`                                                          | A note's paper                                    |
| `note.border`             | `#d9b94a`                                                          | `#8a7428`                                                          | A note's edge and fold                            |
| `note.text`               | `#7a6418`                                                          | `#d9c272`                                                          | A note's text                                     |
| `snap.guide`              | `#e0457b`                                                          | `#ff6f9c`                                                          | Alignment guides while dragging                   |
| `sticker.edge`            | `#fff`                                                             | `#fff`                                                             | The die-cut edge around a sticker                 |
| `window.close.background` | `#c42b1c`                                                          | `#c42b1c`                                                          | The window's close button on hover                |
| `window.close.text`       | `#fff`                                                             | `#fff`                                                             | The close button's glyph on hover                 |
| `companion.body`          | `#fff`                                                             | `#fff`                                                             | The star companion's fill                         |
| `companion.edge`          | `#1d1a33`                                                          | `transparent`                                                      | The outline around each of the companion's stars  |
| `companion.ink`           | `#1d1a33`                                                          | `#1a1240`                                                          | The companion's face                              |
| `companion.halo`          | `rgb(76 64 160 / 0.18)`                                            | `rgb(255 255 255 / 0.55)`                                          | The soft light right around the companion's stars |
| `companion.glow`          | `rgb(98 80 200 / 0.22)`                                            | `color-mix(in srgb, var(--accent-default) 50%, transparent)`       | The glow around the companion and its tethers     |
| `companion.tether`        | `color-mix(in srgb, var(--companion-edge) 70%, transparent)`       | `color-mix(in srgb, var(--companion-body) 70%, transparent)`       | The lines joining the companion's three stars     |

## Status

Each status color also carries a shape, so color never has to stand alone. The colorblind status colors in Settings replace these in every theme.

| Name             | Light                   | Dark                    | Used for                       |
| ---------------- | ----------------------- | ----------------------- | ------------------------------ |
| `status.todo`    | `#5d6d75`               | `#92a3aa`               | Not started, and deferred work |
| `status.ready`   | `var(--accent-default)` | `var(--accent-default)` | Work that can start now        |
| `status.active`  | `#1f62c9`               | `#6ea2f2`               | In progress                    |
| `status.review`  | `#a56300`               | `#e2a34a`               | Waiting on review              |
| `status.blocked` | `#c0362c`               | `#f07a6f`               | Waiting on open work           |
| `status.done`    | `#2f7d4a`               | `#6cc28a`               | Finished                       |

## Tint

Groups and components in a system diagram can take one of these colors. A group's tint washes its frame and header, and the components inside take it unless they set their own.

| Name          | Light     | Dark      | Used for                     |
| ------------- | --------- | --------- | ---------------------------- |
| `tint.teal`   | `#0d8a8f` | `#4fc1c4` | Teal groups and components   |
| `tint.blue`   | `#2f6fd6` | `#6ea2f2` | Blue groups and components   |
| `tint.purple` | `#7a52cc` | `#a98bf0` | Purple groups and components |
| `tint.amber`  | `#c27a0e` | `#e2a34a` | Amber groups and components  |
| `tint.rose`   | `#cc4a6a` | `#f07a95` | Rose groups and components   |
| `tint.green`  | `#2f8a4f` | `#6cc28a` | Green groups and components  |
| `tint.slate`  | `#5f6f7a` | `#92a3aa` | Slate groups and components  |

## Font

| Name        | Default                                                                 | Used for                                          |
| ----------- | ----------------------------------------------------------------------- | ------------------------------------------------- |
| `font.ui`   | `'Schibsted Grotesk', system-ui, -apple-system, 'Segoe UI', sans-serif` | Interface text                                    |
| `font.data` | `'JetBrains Mono', ui-monospace, 'SF Mono', Menlo, monospace`           | Monospace text, such as shortcuts and identifiers |

## Weight

| Name               | Default | Used for                                    |
| ------------------ | ------- | ------------------------------------------- |
| `weight.regular`   | `400`   | Quiet text beside bolder labels             |
| `weight.medium`    | `500`   | Most labels, buttons, and headings          |
| `weight.semibold`  | `600`   | Group titles, tooltips, and the title field |
| `weight.bold`      | `700`   | The Done stamp, counts, and search matches  |
| `weight.extrabold` | `800`   | The companion's sleepy Z's                  |

## Text size

Each size is named for the role it most often plays, and every role that uses that exact size shares it.

| Name                    | Default  | Used for                                      |
| ----------------------- | -------- | --------------------------------------------- |
| `text.size.mini`        | `8px`    | Smallest tags                                 |
| `text.size.nano`        | `9px`    | The Plain skin's card meta and a snooze glyph |
| `text.size.tiny`        | `10px`   | Level and status badges                       |
| `text.size.micro`       | `10.5px` | Card meta and keyboard keys                   |
| `text.size.caption`     | `11px`   | Edge labels and counts                        |
| `text.size.detail`      | `11.5px` | Secondary facts and footers                   |
| `text.size.small`       | `12px`   | Helper text and image labels                  |
| `text.size.label`       | `12.5px` | Card labels and buttons                       |
| `text.size.body`        | `13px`   | Most controls and settings text               |
| `text.size.emphasis`    | `13.5px` | Group headings on the canvas                  |
| `text.size.base`        | `14px`   | The page's base size                          |
| `text.size.subheading`  | `15px`   | Settings navigation headings                  |
| `text.size.input`       | `16px`   | The command palette's input                   |
| `text.size.heading`     | `17px`   | Settings section headings and tool icons      |
| `text.size.glyph`       | `18px`   | Small glyph buttons                           |
| `text.size.glyph-large` | `20px`   | The settings close glyph                      |
| `text.size.sticker`     | `28px`   | Sticker wheel items                           |
| `text.size.sticker-art` | `40px`   | Stickers on the canvas                        |

## Line height

A bare number multiplies the text size. Like text sizes, each value is shared by every role that uses it.

| Name                  | Default | Used for                                               |
| --------------------- | ------- | ------------------------------------------------------ |
| `line-height.glyph`   | `1`     | Glyphs, badges, and close buttons that sit on one line |
| `line-height.tight`   | `1.2`   | A folded group's facts and the Plain skin's notes      |
| `line-height.label`   | `1.25`  | Card labels, group titles, and component notes         |
| `line-height.note`    | `1.3`   | Note text and labels in the focus view                 |
| `line-height.preview` | `1.4`   | The Done stamp and note previews                       |
| `line-height.base`    | `1.45`  | The page's base                                        |
| `line-height.prose`   | `1.5`   | Notes and Markdown in the inspector                    |

## Radius

| Name                 | Default            | Used for                      |
| -------------------- | ------------------ | ----------------------------- |
| `radius.xs`          | `4px`              | Small tags and chips          |
| `radius.sm`          | `6px`              | Buttons and inputs            |
| `radius.md`          | `8px`              | Menus and rows                |
| `radius.lg`          | `12px`             | Large panels and images       |
| `radius.card`        | `var(--radius-md)` | Cards                         |
| `radius.pill`        | `999px`            | Fully rounded tags and counts |
| `radius.round`       | `50%`              | Circles                       |
| `radius.hairline`    | `2px`              | A thin bar                    |
| `radius.note-corner` | `0 7px 0 3px`      | A note's folded corner        |

## Border

Widths for borders that outline or frame a box, such as a card, a group, or a control.

| Name                   | Default | Used for                                                 |
| ---------------------- | ------- | -------------------------------------------------------- |
| `border.width.default` | `1px`   | Cards, panels, menus, rows, and chips                    |
| `border.width.strong`  | `1.5px` | Group frames, drop targets, handles, and card gate marks |
| `border.width.rule`    | `2px`   | Quote bars and the timeline's rail                       |
| `border.width.stamp`   | `2.5px` | The Done stamp's border                                  |

## Ring

Rings sit around or inside a box without changing its size. They mark focus, selection, and status.

| Name                    | Default | Used for                                                                               |
| ----------------------- | ------- | -------------------------------------------------------------------------------------- |
| `ring.width.hairline`   | `1px`   | Traced cards, cards ready to merge, and the merge button                               |
| `ring.width.inset`      | `1.5px` | The sticker wheel's current and filling slots                                          |
| `ring.width.default`    | `2px`   | Focus outlines, link targets, a fresh sticker, and a folded group that needs attention |
| `ring.width.selection`  | `3px`   | A selected card and a picked sticker                                                   |
| `ring.width.pulse`      | `8px`   | How far the pulse around active work spreads                                           |
| `ring.offset.default`   | `1px`   | The gap between a control and its focus outline                                        |
| `ring.offset.wide`      | `2px`   | The gap around round buttons and selected images                                       |
| `ring.offset.selection` | `3px`   | The gap between a selected card and its outline                                        |
| `stripe.width.default`  | `3px`   | The status stripe down a card's left edge                                              |
| `stripe.width.strong`   | `4px`   | The stripe on ready, active, and review cards                                          |

Focus outlines that have to stay inside a clipped control, such as the window buttons, use the negative of an offset.

## Line width

Stroke widths for lines drawn on the canvas. A link's dash pattern shows what kind of link it is, so it stays fixed.

| Name                    | Default | Used for                                                     |
| ----------------------- | ------- | ------------------------------------------------------------ |
| `link.width.default`    | `1.3px` | Links between cards                                          |
| `link.width.focus`      | `1.5px` | Links in the focus view                                      |
| `link.width.still`      | `1.6px` | Links out of components, and related links in the focus view |
| `link.width.held`       | `1.7px` | Links held in place by a dependency                          |
| `link.width.focus-held` | `1.8px` | Held and still links in the focus view                       |
| `link.width.attention`  | `2px`   | The line toward work that needs attention                    |
| `link.width.related`    | `2.2px` | Related links, drawn as dots                                 |
| `link.width.traced`     | `2.6px` | Traced, hovered, and live links in the focus view            |
| `link.width.picked`     | `2.8px` | A picked link                                                |
| `snap.guide.width`      | `1px`   | Alignment guides while dragging                              |

## Space

Spacing for gaps, padding, and margins follows a 2px rhythm. A step ending in `.5`, such as `space.1.5`, sits halfway between its neighbors, for the small nudges that line things up.

| Name        | Default |
| ----------- | ------- |
| `space.0.5` | `1px`   |
| `space.1`   | `2px`   |
| `space.1.5` | `3px`   |
| `space.2`   | `4px`   |
| `space.2.5` | `5px`   |
| `space.3`   | `6px`   |
| `space.3.5` | `7px`   |
| `space.4`   | `8px`   |
| `space.4.5` | `9px`   |
| `space.5`   | `10px`  |
| `space.5.5` | `11px`  |
| `space.6`   | `12px`  |
| `space.7`   | `14px`  |
| `space.7.5` | `15px`  |
| `space.8`   | `16px`  |
| `space.8.5` | `18px`  |
| `space.9`   | `20px`  |
| `space.9.5` | `22px`  |
| `space.10`  | `24px`  |

## Shadow

`shadow.raised` has to read on the theme's background, so Classic gives it a lighter shadow in light mode. The sticker shadows go inside `drop-shadow()`, so each must be a single shadow with no `inset` or spread.

| Name                  | Default                                                                                                                        | Used for                                           |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| `shadow.raised`       | `0 1px 2px light-dark(rgb(23 36 43 / 0.06), rgb(0 0 0 / 0.3)), 0 5px 16px light-dark(rgb(23 36 43 / 0.06), rgb(0 0 0 / 0.25))` | Cards, panels, menus, and other raised surfaces    |
| `shadow.image`        | `0 8px 24px #0002`                                                                                                             | Image nodes                                        |
| `shadow.dialog`       | `0 14px 50px color-mix(in srgb, var(--text-primary) 20%, transparent)`                                                         | Settings and the command palette                   |
| `shadow.selection`    | `0 0 0 9px color-mix(in srgb, var(--accent-default) 26%, transparent)`                                                         | The halo around a selected card                    |
| `shadow.lift`         | `0 0 0 3px color-mix(in srgb, var(--text-primary) 16%, transparent), 0 14px 28px -10px rgb(0 0 0 / 0.4)`                       | The hovered card: a light ring and a deeper shadow |
| `shadow.sticker`      | `0 2px 2px rgb(23 36 43 / 0.25)`                                                                                               | A sticker resting on the canvas                    |
| `shadow.sticker-held` | `0 9px 7px rgb(23 36 43 / 0.22)`                                                                                               | A sticker being dragged                            |

## Motion

Durations and easings for transitions and one-shot animations. When Orion waits for an animation to finish, it reads the token, so a longer value is never cut off. Like text sizes, each exact value is one token, named for the role it most often plays. The Animations setting still decides whether anything moves.

| Name                            | Default | Used for                                                           |
| ------------------------------- | ------- | ------------------------------------------------------------------ |
| `motion.duration.stagger`       | `16ms`  | The delay between sticker wheel items opening                      |
| `motion.duration.blink`         | `80ms`  | The companion's eyes closing and opening                           |
| `motion.duration.chain`         | `90ms`  | The delay between each card down a chain clearing its finish stamp |
| `motion.duration.instant`       | `120ms` | Tooltips and sticker wheel hovers                                  |
| `motion.duration.quick`         | `140ms` | A sticker growing under the pointer                                |
| `motion.duration.fast`          | `150ms` | Handles, hover actions, and border changes                         |
| `motion.duration.open`          | `160ms` | The sticker wheel opening                                          |
| `motion.duration.fade`          | `180ms` | Nodes and panels fading in and out                                 |
| `motion.duration.base`          | `200ms` | Card, group, and link fades                                        |
| `motion.duration.reveal`        | `240ms` | Sticker wheel items popping in                                     |
| `motion.duration.hint`          | `250ms` | The companion's hint growing in                                    |
| `motion.duration.camera-focus`  | `260ms` | The camera heading for a card it's focusing                        |
| `motion.duration.pop`           | `340ms` | A far-zoom card popping up                                         |
| `motion.duration.stamp`         | `360ms` | The finish stamp landing                                           |
| `motion.duration.clear`         | `420ms` | A finish stamp clearing                                            |
| `motion.duration.camera`        | `450ms` | The camera panning and zooming, such as to fit the canvas          |
| `motion.duration.sticker-ring`  | `480ms` | The ring around a fresh sticker                                    |
| `motion.duration.sticker-stamp` | `520ms` | A fresh sticker stamping down                                      |

| Name                     | Default                             | Used for                                 |
| ------------------------ | ----------------------------------- | ---------------------------------------- |
| `motion.easing.standard` | `ease`                              | Hover changes                            |
| `motion.easing.enter`    | `ease-out`                          | Things appearing                         |
| `motion.easing.exit`     | `ease-in`                           | Things leaving                           |
| `motion.easing.pop`      | `cubic-bezier(0.2, 0.9, 0.3, 1.25)` | Stamps and far-zoom cards, with a bounce |
| `motion.easing.bounce`   | `cubic-bezier(0.2, 0.9, 0.3, 1.3)`  | Sticker wheel items, with more bounce    |
| `motion.easing.stamp`    | `cubic-bezier(0.2, 0.9, 0.3, 1.2)`  | A sticker stamping down                  |
| `motion.easing.spring`   | `cubic-bezier(0.3, 1.6, 0.5, 1)`    | The companion's hint, with a spring      |

## Looping animations

One cycle of each animation that repeats while something is live. Most loops step at 15 frames a second at their default length to keep repaints down, so a longer loop also moves in coarser steps. Loops stop when the canvas is zoomed far out or moving, and when animations are off.

| Name                     | Default | Used for                                                  |
| ------------------------ | ------- | --------------------------------------------------------- |
| `motion.loop.twinkle`    | `0.5s`  | The sparkle in the companion's eyes                       |
| `motion.loop.attention`  | `0.6s`  | The marching line toward work that needs attention        |
| `motion.loop.flow`       | `0.8s`  | Live links flowing toward the work they lead to           |
| `motion.loop.flow-group` | `1.2s`  | Live links into a folded group                            |
| `motion.loop.sync`       | `1.2s`  | The sync button spinning                                  |
| `motion.loop.check`      | `1.6s`  | Running checks breathing                                  |
| `motion.loop.shimmer`    | `2.4s`  | Finished work shimmering until it is closed out           |
| `motion.loop.snooze`     | `2.4s`  | The companion's sleepy Z's, each a third of a cycle apart |
| `motion.loop.pulse`      | `3.2s`  | The ring pulsing around active work                       |

## Aliases

These custom properties come from before tokens had role-based names. Each still resolves to its token, so CSS written against them keeps working. Theme files use the token names.

| Alias           | Token                |
| --------------- | -------------------- |
| `--bg`          | `canvas.background`  |
| `--dots`        | `canvas.dots`        |
| `--surface`     | `surface.background` |
| `--ink`         | `text.primary`       |
| `--muted`       | `text.muted`         |
| `--line`        | `border.default`     |
| `--accent`      | `accent.default`     |
| `--accent-soft` | `accent.subtle`      |
| `--edge`        | `edge.default`       |
| `--note`        | `note.background`    |
| `--note-edge`   | `note.border`        |
| `--note-ink`    | `note.text`          |
| `--snap`        | `snap.guide`         |
| `--st-todo`     | `status.todo`        |
| `--st-ready`    | `status.ready`       |
| `--st-active`   | `status.active`      |
| `--st-review`   | `status.review`      |
| `--st-blocked`  | `status.blocked`     |
| `--st-done`     | `status.done`        |
| `--shadow`      | `shadow.raised`      |

No token has been renamed since theme files arrived, so there are no older token names to alias yet.

## Not named yet

These still have literal values and will get tokens in a later change:

- The trading card skin's frame, gate, sticker, and tile shadows.

## Not tokens

These stay fixed, since changing them would change what something means or how the app is laid out rather than how it looks:

- Layout sizes, such as widths, positions, and the room kept beside badges and buttons.
- A link's dash pattern, which tells held, related, and component links apart.
- The strokes inside icons and the companion's face, which are part of the drawing.
- The canvas dot grid's pitch and size.

Sounds will get their own tokens with [the sound layer](https://github.com/vocksel/orion/issues/378).
