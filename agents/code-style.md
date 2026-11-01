# Code style

- Spell identifiers out: `nodes`, not `ns`; `TASK_HEIGHT`, not `TASK_H`; `event`, not `e`. These short names are fine: `doc`/`docs`, `id`, `url`, `ref`, `dir`, `deps`, `repo`, `app`, `pr`, an `ms` suffix, `i`/`j` for indices, `x`/`y` for coordinates, and `a`/`b` in comparators.
- Give each React component its own file named after it, such as `components/SourceBadges.tsx`. Don't add a component to another component's file.
- Log diagnostics from the CLI and `orion server start`, such as timings, flush sizes, and errors, with [Archivist](https://github.com/flipbook-labs/archivist). Report rough edges you find in it. Don't use it for the data operation log, which must commit with the change it records.
- Start a callback that reports something that happened with `on`, named for the event, such as the `onChanged` that `watcher.create` calls when the canvas changes on disk, or the inspectors' `onDoneEditing`. A callback that tells the receiver what to do keeps its verb, such as `switchTo` or `close`.
