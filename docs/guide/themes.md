# Themes

A theme sets Orion's colors, type, spacing, and motion. Orion ships with Vibrant, the default, and Classic, which is deprecated and will be removed. You can add your own as a theme file: a small JSON file of [token](/guide/tokens) values for the light and dark schemes. Pick a theme in Settings, under Appearance.

## Adding a theme

```sh
orion theme add dusk.json
```

`orion theme add` checks the file against the token names and copies it into the `themes` folder inside Orion's [data folder](./data). Copying the file there by hand works too, and Orion checks it when it reads the folder. Orion reads the folder at startup and again whenever Settings or the command palette opens, so there's nothing to restart. The theme then sits beside the built-in themes.

`orion theme list` lists installed theme files, and `orion theme remove dusk.json` removes one. Deleting the file works too. The [`orion theme`](/reference/cli/theme) reference has every option.

`examples/themes/dusk.json` in the repository is a complete example to start from.

## Format

```json
{
  "name": "Dusk",
  "author": "Orion",
  "light": { "canvas.background": "#f6f1ea", "accent.default": "#b4481f" },
  "dark": { "canvas.background": "#1c1726", "accent.default": "#ff9c6b" }
}
```

- `name` is the label in the picker, up to 40 characters. Without it, the file name is the label.
- `author` is optional. The picker shows it under the theme's buttons.
- `light` and `dark` are objects keyed by token name. Give at least one. A theme with only one scheme uses it whatever the color mode says, as Vibrant does.

## Token names

Keys are the names on the [tokens](/guide/tokens) page, such as `card.background`: not the CSS property (`--card-background`), and not an [alias](/guide/tokens#aliases) such as `--bg`.

- A name Orion doesn't know is ignored. While that theme is selected, the picker notes it.
- A token the file leaves out keeps its default for that scheme.
- When colorblind status colors are on, they replace a theme's status tokens, as they do for every theme.

Token names are a [public contract](/guide/tokens#names-are-a-contract). New ones can appear, but the names a theme uses today keep working.

## Values

Each value must be plain CSS for its token's type:

| Type                                           | Accepts                                                                                                                                                                                                  |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Color and status                               | `#rgb`, `#rrggbb`, `#rrggbbaa`, a named color, `transparent`, `rgb()`, `rgba()`, `hsl()`, `hsla()`, `hwb()`, `oklab()`, `oklch()`, `color-mix()`, and `var(--token)` for another token's custom property |
| Font                                           | A font family list, such as `'Schibsted Grotesk', system-ui, sans-serif`                                                                                                                                 |
| Weight                                         | A number from 100 to 1000                                                                                                                                                                                |
| Text size, space, border, ring, and line width | A length in `px`, `rem`, or `em`, such as `1.5px`                                                                                                                                                        |
| Line height                                    | A number, such as `1.4`, or a length in `px`, `rem`, or `em`                                                                                                                                             |
| Radius                                         | One to four lengths in `px`, `rem`, `em`, or `%`, such as `0 7px 0 3px`                                                                                                                                  |
| Shadow                                         | `none`, or one or more shadows of lengths, `inset`, and colors under the color rules, such as `0 1px 2px rgb(0 0 0 / 0.3)`                                                                               |
| Duration                                       | A time in `ms` or `s`, up to `10s`                                                                                                                                                                       |
| Easing                                         | `ease`, `ease-in`, `ease-out`, `ease-in-out`, `linear`, or `cubic-bezier()` with four numbers                                                                                                            |

A value is refused when it contains anything else. That includes `url()`, `image-set()`, `expression()`, any other function, `@` rules, semicolons, braces, and quotes outside a font name. Nothing in a theme file can load a remote resource or add a rule to the page. Each value is at most 200 characters, and Orion reads at most 256 KiB of a file.

## Broken files

A file that isn't JSON, isn't an object, has no `light` or `dark` object, or has a value that breaks the rules above is a broken theme. The picker lists it with the reason and doesn't let you pick it. If it was the selected theme, Orion shows Vibrant instead, and the theme comes back once the file is fixed. A bad file never stops the app from opening, and `orion theme add` refuses one without copying anything.

`orion theme add` can't ask a browser whether it accepts a value, so the app checks once more when the theme is picked. A value that passes `orion theme add` can still be refused there.
