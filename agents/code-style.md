# Code style

These rules hold for the CLI's Luau and the app's TypeScript alike. [Luau style](luau-style.md) and [TypeScript style](typescript-style.md) add what's particular to each.

- Spell identifiers out: `nodes`, not `ns`; `TASK_HEIGHT`, not `TASK_H`; `event`, not `e`. These short names are fine: `doc`/`docs`, `id`, `url`, `ref`, `dir`, `deps`, `repo`, `app`, `pr`, an `ms` suffix, `i`/`j` for indices, `x`/`y` for coordinates, and `a`/`b` in comparators.
- Export one function per module, from a file named after it with a verb first, such as `common/platform/getDataDir.luau` in the CLI and `refs/isSameRef.ts` in the app. Put the types a folder's modules share in a sibling `types.luau` or `types.ts`. Constant tables, data lists, and command modules are tables instead.
- Give a function that exists in both the CLI and the app the same name in each. Its folder can differ.
- Keep a helper that only one module uses as a local function there. Once a second module needs it, move it into its own module rather than copying it. Look for an existing helper, such as `common/getStringField.luau`, before writing one.
- Give each React component its own file named after it, such as `components/SourceBadges.tsx`.
- Log diagnostics from the CLI and `orion server start`, such as timings, flush sizes, and errors, with [Archivist](https://github.com/flipbook-labs/archivist). Report rough edges you find in it. Don't use it for the data operation log, which must commit with the change it records.
