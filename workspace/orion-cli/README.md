# Orion CLI

`orion`, written in Luau and compiled with [Lute](https://github.com/luau-lang/lute). It owns Orion's data: the app, agents, and MCP all go through it. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) covers building and testing it, and the [CLI reference](../../docs/reference/cli/index.md) covers its commands.

Each module exports one function and has its spec beside it as `<module>.spec.luau`. Constant tables, data lists, and command modules export tables instead.

`src` is grouped in layers. A folder requires from its own layer or one below it, never above:

| Folder | Holds |
| --- | --- |
| `cli`, `server` | The surfaces: commands and their arguments and output, MCP in `cli/mcp`, and the HTTP and WebSocket server for the app. |
| `sources`, `telemetry` | The outside world: shared adapter code, one folder per source, ingest and import, and usage events. |
| `storage` | The data folder: canvas files, the SQLite index, the lock and transactions, migrations, the log, and media. |
| `canvas` | The model: items, groups, links, placement, refs, queries, operations, and appearance, as pure changes to a doc. |
| `common` | Helpers with no Orion knowledge, such as running programs, errors, and text. |

Types, constants, and config tables, such as `types.luau`, `geometry.luau`, and `fileNames.luau`, sit at the top of `src` beside `testing.luau`, and any layer may require them. Code that only `.lute` scripts use lives in the repository's `.lute/lib`.

`storage/transactions/runWithLock.luau` is the one place that holds a canvas's lock, and `storage/transactions/runTransaction.luau` and `storage/canvases/writeDoc.luau` are the only writers of a canvas's files. [Architecture](../../docs/development/engineering/architecture.md) covers how the CLI, server, and app fit together.
