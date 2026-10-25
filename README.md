# Orion

Everything you're juggling, in one graph. Pull requests, issues, and plain to-dos become cards, links say what waits on what, and groups gather work by outcome across repositories. People work it on a canvas, and agents work it from the CLI and MCP.

Orion is a prototype and hasn't had its first release, so anything can still change.

## Docs

- [Getting started](docs/guide/getting-started.md): build the app and CLI, and connect an agent.
- [Concepts](docs/guide/concepts.md): cards, links, groups, and sources.
- [Using the canvas](docs/guide/canvas.md), [Sources](docs/guide/sources.md), and [Data and canvases](docs/guide/data.md).
- [CLI](docs/reference/cli/index.md) and [MCP](docs/reference/mcp.md) reference.
- [Development](docs/development/index.md): design and engineering write-ups on how Orion is made.

## Repository

| Folder                     | What's in it                                                |
| -------------------------- | ----------------------------------------------------------- |
| `workspace/orion-app/`     | The canvas, in React                                        |
| `workspace/orion-cli/`     | `orion`, the Luau CLI that owns the data                    |
| `workspace/orion-desktop/` | The Tauri desktop shell                                     |
| `docs/`                    | The docs site, with the design history and the logo sources |
| `examples/`                | Example theme files                                         |

[The charter](docs/development/charter.md) sets where Orion is headed, and [the decisions log](docs/development/decisions.md) records the calls made along the way. [`CONTRIBUTING.md`](CONTRIBUTING.md) covers building and testing. Agents start at [`AGENTS.md`](AGENTS.md).

## License

Orion is released under the [MIT License](LICENSE).
