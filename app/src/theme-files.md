# Theme files

A theme file sets token values from [tokens.md](./tokens.md) for the light and dark schemes. Install one with `orion theme add <file>`, which checks the file against the token names and copies it into the `themes` folder inside Orion's data folder (`orion canvas path` shows where that is). Copying the file there by hand works too; Orion checks it when it reads the folder. Orion reads the folder at startup and again when Settings or the command palette opens, so there is nothing to restart. The theme then sits beside Classic and Vibrant. Remove it with `orion theme remove <file>`, or delete the file.

`examples/themes/dusk.json` in the repository is an example. It is not installed by default.

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
- `light` and `dark` are objects keyed by token name. Give at least one. A theme with only one scheme uses that scheme whatever the color mode says, as Vibrant does.

## Token names

Keys are the role-based names in tokens.md, such as `card.background`. Not the CSS property (`--card-background`) and not the legacy names (`--bg`).

- A name Orion does not know is ignored. While that theme is selected, the picker notes it.
- A token the file leaves out takes the Classic value for that scheme.
- A status token is replaced by the colorblind status colors when those are on, as with every theme.

## Values

Each value must be plain CSS for its token's type:

| Type                               | Accepts                                                                                                                                                                                                  |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Color (`color`, `status`)          | `#rgb`, `#rrggbb`, `#rrggbbaa`, a named color, `transparent`, `rgb()`, `rgba()`, `hsl()`, `hsla()`, `hwb()`, `oklab()`, `oklch()`, `color-mix()`, and `var(--token)` for another token's custom property |
| Font (`font`)                      | A font family list, such as `'Schibsted Grotesk', system-ui, sans-serif`                                                                                                                                 |
| Weight (`weight`)                  | A number from 100 to 1000                                                                                                                                                                                |
| Size and spacing (`size`, `space`) | A length in `px`, `rem`, or `em`                                                                                                                                                                         |
| Border (`border`)                  | A length in `px`, `rem`, or `em`, such as `1.5px`                                                                                                                                                        |
| Radius (`radius`)                  | One to four lengths in `px`, `rem`, `em`, or `%`, such as `0 7px 0 3px`                                                                                                                                  |
| Shadow (`shadow`)                  | `none`, or one or more shadows of lengths, `inset`, and colors under the color rules, such as `0 1px 2px rgb(0 0 0 / 0.3)`                                                                               |
| Duration (`duration`)              | A time in `ms` or `s`, up to `10s`                                                                                                                                                                       |
| Easing (`easing`)                  | `ease`, `ease-in`, `ease-out`, `ease-in-out`, `linear`, or `cubic-bezier()` with four numbers                                                                                                            |

A value is refused when it contains anything else. That includes `url()`, `image-set()`, `expression()`, any other function, `@` rules, semicolons, braces, and quotes outside a font name. Nothing in a file can load a remote resource or add a rule to the page. Each value is at most 200 characters, and a file is read only up to 256 KiB.

## Broken files

A file that is not JSON, is not an object, has no `light` or `dark` object, or has a value that breaks the rules above is a broken theme. The picker lists it with its reason and does not let it be picked. If it was the selected theme, Orion shows Classic instead, and the theme returns once the file is fixed. A bad file never stops the app from opening. `orion theme add` refuses a broken file and copies nothing.

Names and values are checked in `app/src/themeFile.ts`, and `app/src/themeFile.test.ts` covers them. `orion theme add` runs the same checks in `cli/src/themes/checkThemeFile.luau` and `checkThemeValue.luau`, against the token list in `cli/src/themes/tokenContract.luau`. `app/src/tokens.test.ts` fails if that list drifts from `tokens.ts`. The app's browser check, which asks whether the browser accepts a value, runs only in the app, so a value that passes `orion theme add` can still be refused when the theme is picked. The data folder's `themes` folder is read by `cli/src/themes/readThemeFiles.luau` and served by `GET /api/themes`, which returns each file's text for the app to check.
