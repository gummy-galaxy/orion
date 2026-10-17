# Orion CLI

`orion`, written in Luau and compiled with [Lute](https://github.com/luau-lang/lute). It owns Orion's data: the app, agents, and MCP all go through it. [`CONTRIBUTING.md`](../CONTRIBUTING.md) covers building and testing it, and the [CLI reference](../docs/reference/cli/index.md) covers its commands.

Each module exports one function and has its spec beside it as `<module>.spec.luau`.

## Code layout

In `src/`:

- `cli/`: commands. `cli/init.luau` registers and dispatches them, and each command module defines its own options.
- `cli/mcp/`: the MCP server. `cli/mcp/tools.luau` lists every tool and the command it runs.
- `cli/describeCommands.luau`: describes every command for the generated reference, which the root `.lute/docs.luau` writes.
- `store.luau`: reading, locking, backing up, and writing the data file, and focus reports.
- `graph.luau`: derived status and leverage, and every edit the commands make.
- `server/`: HTTP routes, WebSocket events, file watching, and refresh scheduling for `orion server start`.
- `adapters/`: one adapter per source kind (`github`, `jira`, `hop`). Each validates its options, collects records for ingest, and resolves `--ref` values through `adapters/resolveRef.luau`.
- `ingest/`: running sources, placing their records, and linking mentioned issues.
- `github/`: looking up pull requests and mapping their state onto cards.
- `import/`: `orion card import`.
- `suggest/`: proposing groups for ungrouped cards.
- `query/`: parsing and matching `--where` expressions.
- `layout/`: the checks behind `orion canvas check`.
- `media/`: image assets.
- `platform/`: the data folder for each operating system.
- `migrations/`: upgrades for data from before 0.1.0, removed at that release. Its README lists each one.
- `render.luau`: text and JSON output.
- `mutation/`: the source changes `lute run mutate` tries against a module's spec.
