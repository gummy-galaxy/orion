# Code style

- Spell identifiers out: `nodes`, not `ns`; `TASK_HEIGHT`, not `TASK_H`; `event`, not `e`. These short names are fine: `doc`/`docs`, `id`, `url`, `ref`, `dir`, `deps`, `repo`, `app`, `pr`, an `ms` suffix, `i`/`j` for indices, `x`/`y` for coordinates, and `a`/`b` in comparators.
- Refer to a function or value by the name it already has, rather than storing it under a short alias like `local send = ...`. Each alias makes the reader remember what it stands for in this one place. For a dependency a caller can swap in, call it where it's used, such as `(options.sendTelemetryBatchAsync or sendTelemetryBatchAsync)(...)`, since Lute's `shadowing` lint flags a local that reuses the name.
- Give each React component its own file named after it, such as `components/SourceBadges.tsx`. Don't add a component to another component's file.
- Log diagnostics from the CLI and `orion server start`, such as timings, flush sizes, and errors, with [Archivist](https://github.com/flipbook-labs/archivist). Report rough edges you find in it. Don't use it for the data operation log, which must commit with the change it records.
