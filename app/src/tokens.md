# Visual tokens

Every visible property in the app reads a named token. [`docs/guide/tokens.md`](../../docs/guide/tokens.md) lists each one with its role and default, and [`docs/guide/themes.md`](../../docs/guide/themes.md) explains theme files. This note covers keeping the pieces in step.

- `tokens.css` sets the values every theme shares.
- `themes/<id>.css` sets the colors for one theme. A theme can set any token.
- `tokens.ts` lists every token, its CSS property, and its group.
- `cli/src/themes/tokenContract.luau` repeats that list, so `orion theme add` can check files without the app's source.

`tokens.test.ts` fails when these disagree: a token missing from a theme, from the docs page, or from the CLI's list, or a default on the docs page that doesn't match the stylesheet.

## Adding a token

1. Declare it in `tokens.css`, or in every file in `themes/` when the value depends on the theme.
2. Add it to `tokens.ts` and `tokenContract.luau`, in the same place in each.
3. Add a row to `docs/guide/tokens.md` with its default and what it's for, then run `npm run format` in `docs/`.

## Renaming a token

Token names are a public contract for theme files, and renames follow the [release stages](../../docs/development/decisions.md#public-interfaces-tighten-in-three-stages). Before 0.1.0, rename the token everywhere in one change, with no alias. From 1.0.0, a rename keeps the old name working: as a custom property declared in `tokens.css` as `--old: var(--new)`, and as a name in theme files through `themeFile.ts` and `checkThemeFile.luau`.

Never drop a token silently. Removing one is a deliberate change that says so.

## Checks

Names and values in theme files are checked in `themeFile.ts`, which `themeFile.test.ts` covers. `orion theme add` runs the same checks in `cli/src/themes/checkThemeFile.luau` and `checkThemeValue.luau`. The app also asks the browser whether it accepts each value, which the CLI can't do. The data folder's `themes` folder is read by `cli/src/themes/readThemeFiles.luau` and served by `GET /api/themes`, which returns each file's text for the app to check.
