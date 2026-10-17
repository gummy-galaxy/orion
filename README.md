# Orion

Everything you're juggling, in one graph. Pull requests, issues, and plain to-dos become cards, links say what waits on what, and groups gather work by outcome across repositories. People work it on a canvas, and agents work it from the CLI and MCP.

Orion is a prototype and hasn't had its first release, so anything can still change.

## Docs

- [Getting started](docs/guide/getting-started.md): build the app and CLI, and connect an agent.
- [Concepts](docs/guide/concepts.md): cards, links, groups, and sources.
- [Using the canvas](docs/guide/canvas.md), [Sources](docs/guide/sources.md), and [Data and canvases](docs/guide/data.md).
- [CLI](docs/reference/cli/index.md) and [MCP](docs/reference/mcp.md) reference.

## Repository

| Folder      | What's in it                             |
| ----------- | ---------------------------------------- |
| `app/`      | The canvas, in React                     |
| `cli/`      | `orion`, the Luau CLI that owns the data |
| `desktop/`  | The Tauri desktop shell                  |
| `docs/`     | The docs site                            |
| `design/`   | Logo sources                             |
| `examples/` | Example theme files                      |

[`CHARTER.md`](CHARTER.md) sets where Orion is headed, and [`DECISIONS.md`](DECISIONS.md) records the calls made along the way. [`CONTRIBUTING.md`](CONTRIBUTING.md) covers building and testing. Agents start at [`AGENTS.md`](AGENTS.md).
