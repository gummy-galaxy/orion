# Orion CLI

`orion`, written in Luau and compiled with [Lute](https://github.com/luau-lang/lute). It owns Orion's data: the app, agents, and MCP all go through it. [`CONTRIBUTING.md`](../CONTRIBUTING.md) covers building and testing it, and the [CLI reference](../docs/reference/cli/index.md) covers its commands.

Each module exports one function and has its spec beside it as `<module>.spec.luau`.

## Code layout

In `src/`:

- `cli/`: commands. `cli/init.luau` registers and dispatches them, and each command module defines its own options.
- `cli/mcp/`: the MCP server. `cli/mcp/catalog/buildTools.luau` makes a tool for every command from its `mcp` declaration and its options, which `cli/addArgument.luau` gives value types.
- `cli/describeCommands.luau`: describes every command for the generated reference, which the root `.lute/docs.luau` writes, and for `orion help --all`, which `cli/formatAllHelp.luau` prints.
- `cli/reveal.luau`: selects items in the open app and waits for the app to report them, opening the app first when none is running.
- `store/`: the canvas list, the data file and its backups, and focus reports. `runWithLock` is the one place that holds a canvas's lock, and `runTransaction` and `writeDoc` are the only writers of the data file.
- `graph/`: derived status and leverage in `graph/derive.luau`, and every edit the commands make, one function per module. Shared types are in `graph/types.luau` and card and group sizes in `graph/sizes.luau`.
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
