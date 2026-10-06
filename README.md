# Orion

A canvas for graph-shaped work: tasks and pull requests with dependencies, grouped freely across repositories, with zoom levels that go from single cards out to whole bodies of work.

This is a prototype seeded from a snapshot of the Flipbook Release Map. It runs in the browser or in a desktop shell.

- `app/`: the canvas.
- `desktop/`: the Tauri desktop shell.
- `cli/`: `orion`, a command-line tool for reading and editing the same data, meant for agents as much as people.
- `orion suggest` proposes groups for ungrouped cards (or every card with `--scope all`). It joins cards by links, Jira epics, shared branches, and references, then `--agent codex` or `--agent claude` names and splits the result into groups by outcome. The agent's CLI must already be signed in. Review with `orion suggestions`, then use `orion suggestions apply <id...> | --all` or `orion suggestions dismiss <id...> | --all`. These commands use the selected workspace. The app places new groups to the right of existing ones and refits groups whose cards moved.

## Data

The default canvas lives in `~/Library/Application Support/Orion/orion.json`. Set `ORION_DATA_DIR` to use another data root. `orion serve` owns the app's data API, and all file access goes through the Luau CLI store. The app talks to that API over HTTP and receives changes over WebSocket. The CLI takes the same lock for every write, so the app and other commands can be open at once.

### Workspaces

The original canvas is the `default` workspace in the data root. Other workspaces keep separate `orion.json` files under `<data root>/workspaces/<name>/`. The root's `workspaces.json` records their names, labels, and the active workspace. Workspace names use lowercase letters, digits, and hyphens.

Use `orion workspace list`, `orion workspace create <name> [--label <label>] [--owner <github owner>]`, and `orion workspace use <name>` to manage them. `orion workspace current` shows the selected workspace, and `orion path` prints its folder. The app's sidebar can also create and switch workspaces. Pass `--workspace <name>` to a CLI command to use one without changing the active workspace; `ORION_WORKSPACE` provides the same choice for the environment. The command option takes precedence, followed by the environment, `workspaces.json`, and `default`.

Before replacing an existing data file, the CLI store copies it to `backups/orion-r<revision>-<UTC timestamp>.json` in that workspace's folder. Backups from the last 24 hours are kept, along with the newest backup for each UTC day in the last 30 days. Run `orion backups [--json]` to list the selected workspace's backups newest first, and `orion restore <revision>` to recover one in that workspace as a new revision. If several backups have that revision, restore uses the newest. Restoring also backs up the current file first.

## Run the app

```sh
cd app
npm install
npm run dev
```

Build the CLI first with `cd cli && lute run build`. Vite starts `orion serve` and proxies `/api` to it. Set `ORION_BIN` to use another CLI binary. If the binary is missing, Vite still runs and the app falls back to browser storage.

`orion serve` reads and writes the active workspace's data file. Run it directly with `orion serve [--host 127.0.0.1] [--port 5198] [--static app/dist]`; `--static` serves a built app with an `index.html` fallback. When the default workspace has no file, the app carries over what the browser had saved, or starts from the seed. Other new workspaces start empty. The server syncs five seconds after startup and every five minutes. Returning to the window also requests a sync, with a one-minute throttle.

## Desktop app

Install Rust 1.90 or newer, the Xcode Command Line Tools, and Lute, then run:

```sh
cd desktop
npm install
npm run dev
```

The development window uses the app's Vite server on port 5199, which proxies the data API and WebSocket to `orion serve`. `npm run build` builds the CLI with Lute and packages it with the canvas. The packaged app runs `orion serve`, so it reads and writes the same workspace files as the CLI, including when `ORION_DATA_DIR` selects another data root.

## Build the CLI

The CLI is written in Luau and compiled with [Lute](https://github.com/luau-lang/lute).

```sh
cd cli
rokit install
lute run install
lute run build
```

That produces `cli/build/orion`. Put it on your `PATH`, then run `orion help`. See [`AGENTS.md`](AGENTS.md) for how agents should use it.

Before committing CLI changes, run `lute run analyze` and `lute test` in `cli/`.

### Sources

Configure sources once, then run `orion ingest --dry-run` to preview work involving you. `orion ingest` adds new cards to Unsorted, updates matching cards in place, and links mentioned Jira issues or GitHub issues to pull requests. `orion source list --json` shows the configuration. Sources and cards live in the selected Orion data file; source commands run through the CLI and keep credentials in their own tools.

For GitHub sources, `--owners`, `--include`, and `--exclude` accept comma-separated lists. Spaces around entries are ignored, so `--owners vocksel,flipbook-labs --include "orion, hop"` works.

Ingested Jira cards store their source ID, issue key, URL, status, completion state, update time, and Jira-specific details in `data.external`. The source ID and key identify a card across ingests.

For a Roblox setup:

```sh
orion source add github --host github.com --owners Roblox
orion source add github --host github.example.com --owners Roblox --id gh-roblox-enterprise
orion source add jira --command '["acli","jira","workitem","search","--jql","assignee = currentUser() AND resolution = Unresolved","--json"]' --browse https://jira.example.com/browse
orion source add hop
orion ingest --dry-run
orion ingest
```

Use `orion ingest --source <id> --json` for one source and a machine-readable report. `orion source remove <id>` stops future ingestion from a source; cards already on the canvas remain.

## Using the canvas

- Drag or scroll to pan; pinch or ⌘-scroll to zoom. ⌘-drag selects; ⌘-click or ⇧-click adds to the selection. Right-click anything for its actions.
- ⌘G groups the selection. ⇧⌘G ungroups. Groups can nest and span repositories.
- The list on the left shows every group in canvas order. Click one to open it.
- Press ⌘K (or Ctrl+K) to search groups, cards, PRs, and notes, then press Enter to jump to a result.
- Double-click a group, or press Enter with one selected, to open it. Esc goes back up, and the breadcrumbs jump to any level.
- Zoom out in an open group to peek at its faded surroundings. Keep zooming out, pan the group mostly off screen, or interact with outside work to leave without changing the viewport; the zoom distance scales with the group's work.
- Zoom in while pointing at a group to enter it when it fills most of the canvas.
- An open group shows the outside work it waits on along its left side and the work waiting on it along its right. Click one to jump to it.
- Zooming out folds groups into single bodies, inner groups first. Links between folded groups are bundled into one line with a count.
- Hold ⌥ to see where it's your move. Lines run from the cursor to each one; work off screen gets a chip at the edge that jumps to it.
- Hover a card to trace what it needs (amber) and what it unlocks (teal). Double-click a card to hold its trace while you pan; click anywhere or press Esc to let it go.
- Moving lines are dependencies that are still waiting. Still lines are satisfied. Dotted lines are related work that never blocks.
- "Unblocks N" counts every open task downstream, directly or not.
- N adds a note. Right-click a link to insert a note into it. Notes pass blocking through but never count as work, and can be turned into work items later.
- Reflow lays out the inside of a group. Tidy lays out the current level.
- Drag from the edge of a card to another card to add a dependency.

Reset to seed restores the snapshot.

Dashed cards are pull requests that aren't opened yet. Select a card to edit it, add notes, or open its pull request. Cards with a repository and pull request number show what GitHub reported the last time `orion sync` ran.
The toolbar shows when GitHub was last synced, or a sync error; click the status to force a sync. Linked cards show a checks dot (green passing, red failing, amber pending) and changed line count. The inspector shows checks, additions and deletions, update time, author, and review requests. An unlinked work item may show possible pull requests in its inspector; use **Link** to attach one to the card.

## Layout of the code

In `app/`:

- `vite.config.ts`: starts `orion serve` for development and proxies its API.
- `src/persist.ts`: loading, saving, and reacting to changes from other writers.
- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/layout.ts`: ELK layout for one group or the top level.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/nodes.tsx`: task cards and group frames.
- `src/App.tsx`: the canvas, semantic zoom, drill-in, connections outside an open group, notes, and the inspector.
- `src/Sidebar.tsx` and `src/ContextMenu.tsx`: the group list and right-click menu.
- `src/seed.json` and `src/seed.ts`: the Flipbook snapshot and its loader.

In `cli/src/`:

- `cli/init.luau`: command registration and dispatch; command modules in `cli/` define their own options.
- `store.luau`: reading, locking, and writing the data file.
- `server/`: HTTP routes, WebSocket events, file watching, and sync scheduling for `orion serve`.
- `graph.luau`: derived status and leverage, and every edit the commands make.
- `github.luau`: looking up pull requests and mapping their state onto cards.
- `render.luau`: text and JSON output.
