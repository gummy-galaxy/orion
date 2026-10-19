# Architecture

Orion has a few pieces that share one data model. The `orion` CLI owns the data. The app, the desktop shell, and the agent interface all go through the CLI, so the rules for reading and changing a canvas live in one place.

![Orion's architecture drawn on an Orion canvas. People and agents and the desktop shell lead into the canvas app and the orion CLI. The CLI reads and writes the Workspace files and reaches outside tools such as GitHub, Jira, hop, and VS Code. A build-and-checks group sits at the top.](../design/images/system-diagram.webp)

The diagram is Orion's own architecture, drawn on an Orion canvas with the [system diagram components](https://github.com/vocksel/orion/pull/201). Its Workspace files labels still use the older name for canvases (`workspaces.json`), so read them as canvases.

## The CLI owns the data

The Luau CLI is the only code that reads, locks, or writes a canvas's files. [orion serve](https://github.com/vocksel/orion/pull/52) moved the app's data API into the CLI and removed the app's own store, so there is no second copy of the storage rules to keep in step. The command is now `orion server start`.

Every change the CLI makes goes through the same path, whether it comes from a terminal, an agent, the app, or the desktop shell. That is what lets the app pick up a change made from the command line while it is open. See [data and sync](/development/engineering/data-and-sync) for the file layout and locking.

## The server

`orion server start` serves the app's data over local HTTP and pushes change events over a WebSocket. The main routes are:

| Route                                   | What it does                                                  |
| --------------------------------------- | ------------------------------------------------------------- |
| `/api/orion`                            | Reads and saves the open canvas's document.                   |
| `/api/canvases`, `/api/canvases/active` | Lists canvases and switches the active one.                   |
| `/api/focus`                            | Stores the open group and selection that `orion focus` reads. |
| `/api/settings`, `/api/themes`          | App preferences and theme files.                              |
| `/api/images`                           | Stores and returns the bytes of image nodes.                  |
| `/api/events`                           | A WebSocket that sends change events to open apps.            |

A file watcher checks the data folder. When a canvas changes, the server sends `orion:changed` with the new revision to every open app, and `orion:canvases` when the list of canvases changes. The server also runs a background refresh of pull request cards ([#328](https://github.com/vocksel/orion/pull/328)). It exits when the process that started it is gone, so a crashed app or dev server doesn't leave one running ([#53](https://github.com/vocksel/orion/pull/53)).

Any route that doesn't match returns a JSON 404, so a typo in the app's API calls fails loudly instead of returning the static page.

The API is internal to the app, and the server refuses anything else a browser sends it ([#468](https://github.com/vocksel/orion/issues/468)). A request's `Host`, and its `Origin` when it has one, must name the server's own address or the app's dev server, which Vite passes as `--dev-port`. That stops another site from posting to the API or reading it through DNS rebinding. The built app is served with a content security policy, since the desktop shell sets none.

## The app

The app is a React Flow canvas. Its state lives in Jotai atoms, and each card reads only the values it shows through its own selector, so an edit redraws the cards it touches and not the whole canvas ([#124](https://github.com/vocksel/orion/pull/124)). The app talks to the server over HTTP and the WebSocket. If the CLI binary is missing, the app falls back to browser storage, so it still opens for development without the CLI.

Components have their own stories in Storybook ([#128](https://github.com/vocksel/orion/pull/128)). The perf harness has a story of its own that seeds a generated canvas and drives it. See [performance](/development/engineering/performance).

## The desktop shell

The desktop app is a [Tauri 2](https://tauri.app) shell around the app, added in [#19](https://github.com/vocksel/orion/pull/19). In development it opens the app's Vite server in a native window. In a packaged build it bundles the CLI as a sidecar, starts `orion server start` on a free local port, and loads the canvas from it, so the window and the CLI read and write the same files ([#53](https://github.com/vocksel/orion/pull/53)). If the sidecar fails to start, the window falls back to the bundled frontend and browser storage.

Three details follow from that design:

- The server keeps the same port across launches ([#282](https://github.com/vocksel/orion/pull/282)). The port is saved in the data folder and reused. Browser storage is keyed by origin, so a new port on every launch would start each launch with empty storage.
- The app draws its own window chrome, including the traffic lights on macOS, and the window controls on Windows and Linux ([#198](https://github.com/vocksel/orion/pull/198)).
- The packaged app installs to `/Applications/Orion.app`, so every user on the machine gets the same copy ([#357](https://github.com/vocksel/orion/pull/357)).

## The agent surface

The CLI binary also serves an MCP server. `orion mcp start` speaks MCP over stdio, with no Node runtime, so a client can launch the binary directly, including the copy bundled in the desktop app ([#134](https://github.com/vocksel/orion/pull/134)). Each tool checks its arguments and then runs the matching CLI command in the same process. The CLI stays the one implementation of Orion's behavior.

The MCP server is kept generic. Orion documents how to register `orion mcp start` with any client rather than shipping setup for each AI provider, as the [decisions](/development/decisions) explain. [CLI and agents](/development/engineering/cli-and-agents) covers the tools and the reference.

## Sources and adapters

GitHub, Jira, and hop feed the canvas through `orion ingest` ([#24](https://github.com/vocksel/orion/pull/24)). Each kind of source is an adapter with two jobs: `createSource` checks the options given to `orion source add`, and `collect` runs the source's command and returns records. GitHub also has `refresh`, which keeps the pull request cards already on the canvas current ([#155](https://github.com/vocksel/orion/pull/155)). A single `orion ingest` runs both, so there is one command that pulls from outside ([#328](https://github.com/vocksel/orion/pull/328)).

Cards point to external work through a list of refs in `data.refs`. Each ref records its source, kind, key, URL, and status, so a card doesn't need a field for each service ([#152](https://github.com/vocksel/orion/pull/152)). The [charter](/development/charter) keeps sources as the source of truth. Orion keeps references and derived state, not a copy that can drift.

## Where it's headed

The decisions log sets three directions, none of them fully built:

- **Files first, with a SQLite index.** A canvas becomes a folder of text files that can live in a repository, and SQLite becomes an index that can be rebuilt from them. This is the storage bet in the charter's first phase ([#246](https://github.com/vocksel/orion/pull/246)). See [data and sync](/development/engineering/data-and-sync).
- **Canvas edits as operations.** Each edit becomes one operation with an inverse, and the app sends those to the server instead of saving the whole document. The first part is [in review](https://github.com/vocksel/orion/pull/343), and the app side is [in review](https://github.com/vocksel/orion/pull/355) on top of it.
- **Adapters as Lute packages.** Each source adapter is a Lute package built on a shared core. The official adapters would live in their own repositories and ship with Orion, and people could copy them to build their own ([decisions](/development/decisions)).
