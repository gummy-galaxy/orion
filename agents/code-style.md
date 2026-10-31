# Code style

- Spell identifiers out: `nodes`, not `ns`; `TASK_HEIGHT`, not `TASK_H`; `event`, not `e`. These short names are fine: `doc`/`docs`, `id`, `url`, `ref`, `dir`, `deps`, `repo`, `app`, `pr`, an `ms` suffix, `i`/`j` for indices, `x`/`y` for coordinates, and `a`/`b` in comparators.
- Write a table, object, or type with more than one field across lines, one field per line with a trailing comma. A single field or a short list of plain values, such as `{ "a", "b" }`, can stay on one line. StyLua and Prettier keep whatever layout they're given, so a one-line table that later outgrows 120 columns gets rewritten whole, and the diff hides the field that actually changed.

  ```luau
  export type ItemTypes = {
  	primary: string,
  	types: { string },
  }
  ```

- Give each React component its own file named after it, such as `components/SourceBadges.tsx`. Don't add a component to another component's file.
- Log diagnostics from the CLI and `orion server start`, such as timings, flush sizes, and errors, with [Archivist](https://github.com/flipbook-labs/archivist). Report rough edges you find in it. Don't use it for the data operation log, which must commit with the change it records.
