# Orion CLI

`orion`, written in Luau and compiled with [Lute](https://github.com/luau-lang/lute). It owns Orion's data: the app, agents, and MCP all go through it. [`CONTRIBUTING.md`](../CONTRIBUTING.md) covers building and testing it, and the [CLI reference](../docs/reference/cli/index.md) covers its commands.

Each module exports one function and has its spec beside it as `<module>.spec.luau`.

`store/runWithLock.luau` is the one place that holds a canvas's lock, and `store/runTransaction.luau` and `store/writeDoc.luau` are the only writers of the data file. [Architecture](../docs/development/engineering/architecture.md) covers how the CLI, server, and app fit together.
