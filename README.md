# Orion

A canvas for graph-shaped work: tasks and pull requests with dependencies, grouped freely across repositories, with zoom levels that go from single cards out to whole bodies of work.

This is a prototype seeded from a snapshot of the Flipbook Release Map. It runs in the browser or in a desktop shell.

- `app/`: the canvas.
- `desktop/`: the Tauri desktop shell.
- `cli/`: `orion`, a command-line tool for reading and editing the same data, meant for agents as much as people.
- `orion suggest` proposes groups for ungrouped cards (or every card with `--scope all`). It joins cards by links, Jira epics, shared branches, and references, then `--agent codex` or `--agent claude` names and splits the result into groups by outcome. The agent's CLI must already be signed in. Review with `orion suggestions`, then `orion suggestions apply <id...>` (or `--all`) or `dismiss`. The app lays out applied groups to the right of existing ones without moving anything else.

## Data

The default canvas lives in `~/Library/Application Support/Orion/orion.json`. Set `ORION_DATA_DIR` to use another data root. The app and the CLI take the same lock before writing and bump a revision with each write, so both can be open at once. Changes from either side show up in the other within a moment.

### Workspaces

The original canvas is the `default` workspace in the data root. Other workspaces keep separate `orion.json` files under `<data root>/workspaces/<name>/`. The root's `workspaces.json` records their names, labels, and the active workspace. Workspace names use lowercase letters, digits, and hyphens.

Images are nodes with workspace-local files in `assets/`, so the canvas document stores a small asset reference. The app's **Add image** control accepts PNG, JPEG, GIF, and WebP files up to 5 MB. Agents can add one with `orion image add ./concept.png --workspace orion --label "Concept"`; `orion image list --workspace orion` shows imported image nodes. The CLI and app validate file contents and keep assets in the selected workspace.

Use `orion workspace list`, `orion workspace create <name> [--label <label>] [--owner <github owner>]`, and `orion workspace use <name>` to manage them. `orion workspace current` shows the selected workspace, and `orion path` prints its folder. The app's sidebar can also create and switch workspaces. Pass `--workspace <name>` to a CLI command to use one without changing the active workspace; `ORION_WORKSPACE` provides the same choice for the environment. The command option takes precedence, followed by the environment, `workspaces.json`, and `default`.

Before replacing an existing data file, both writers copy it to `backups/orion-r<revision>-<UTC timestamp>.json` in the data folder. Backups from the last 24 hours are kept, along with the newest backup for each UTC day in the last 30 days. Run `orion backups [--json]` to list them newest first, and `orion restore <revision>` to recover one as a new revision. If several backups have that revision, restore uses the newest. Restoring also backs up the current file first.

## Run the app

```sh
cd app
npm install
npm run dev
```

The dev server reads and writes the active workspace's data file. When the default workspace has no file, it carries over what the browser had saved, or starts from the seed. Other new workspaces start empty.
It runs `orion sync --json` five seconds after startup and every five minutes, using `cli/build/orion` and the same data folder as the app. Set `ORION_BIN` to use another CLI binary. Returning to the window also requests a sync, with a one-minute server throttle.

## Desktop app

Install Rust 1.90 or newer and the Xcode Command Line Tools, then run:

```sh
cd desktop
npm install
npm run dev
```

The development window uses the app's Vite server on port 5199, including its data endpoint and automatic sync. `npm run build` packages the canvas with a native file bridge: the app and CLI read and write the same `orion.json` and workspace manifest under `~/Library/Application Support/Orion` (or `ORION_DATA_DIR`). The packaged app detects CLI edits while open. Automatic GitHub sync is available in the development window; use the CLI to sync the packaged app's canvas.

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

Configure sources once, then run `orion ingest --dry-run` to preview work involving you. `orion ingest` adds new cards to Unsorted, updates matching cards in place, files a pull request on the card of the Jira ticket its title or branch names, and links cards that reference each other. "Stacked on", "Depends on", and "Blocked by" before a reference, Jira "Blocks" issue links, and stacked branches make blocking links; other mentions make related ones. Include the description and issue links in the Jira command's output to link tickets from them. `orion source list --json` shows the configuration. Sources and cards live in the selected Orion data file; source commands run through the CLI and keep credentials in their own tools.

For a Roblox setup:

```sh
orion source add github --host github.com --owner Roblox
orion source add github --host github.example.com --owner Roblox --id gh-roblox-enterprise
orion source add jira --command '["acli","jira","workitem","search","--jql","assignee = currentUser() AND resolution = Unresolved","--json"]' --browse https://jira.example.com/browse
orion source add hop
orion ingest --dry-run
orion ingest
```

Use `orion ingest --source <id> --json` for one source and a machine-readable report. `orion source remove <id>` stops future ingestion from a source; cards already on the canvas remain.

## Using the canvas

- The toolbar at the bottom switches tools. Select (V) is the default: drag a box to select every card it covers at least a quarter of each way, and ⇧ adds to the selection. An open group is selected only when the box covers all of it. Middle-drag or hold Space and drag to pan. Pan (H) drags the canvas from anywhere, with ⌘-drag to select. Comment (C) drops a note where you click, then returns to Select. Esc also returns to Select.
- Hold S to open the sticker wheel, point at one, and let go; a quick tap or the toolbar button leaves it open for clicking, and 1–8 pick by number. With it open, type or paste any emoji to stamp that instead, and right-click a slot, or click an empty one, to put a different emoji there. Each canvas keeps its own wheel. Then click to stamp it as many times as you like. Stickers stamped on a card or group move with it. In Select, drag a sticker to move it or flick it to send it sliding; stickers bounce off each other and stay inside their group's walls. Keep pulling past a wall to pop one out of a group, or into another. Right-click a sticker to remove it.
- Scroll to pan; pinch or ⌘-scroll to zoom. ⌘-click or ⇧-click adds to the selection. Right-click anything for its actions.
- ⌘G groups the selection. ⇧⌘G ungroups. Groups can nest and span repositories.
- The list on the left shows every group in canvas order. Click one to open it.
- Press ⇧⌘P (or Ctrl+Shift+P) to search groups, cards, PRs, notes, and actions such as Reload window, then press Enter to jump to a result or run the action.
- Double-click a group, or press Enter with one selected, to open it. Esc goes back up, and the breadcrumbs jump to any level.
- Zoom out in an open group to peek at its faded surroundings. Keep zooming out, pan the group mostly off screen, or interact with outside work to leave without changing the viewport; the zoom distance scales with the group's work.
- An open group shows the outside work it waits on along its left side and the work waiting on it along its right. Click one to jump to it.
- Zooming out folds groups into single bodies, inner groups first. Links between folded groups are bundled into one line with a count.
- However far you zoom out, folded groups, cards, and notes keep their full details at a readable size, and open groups' headers grow to stay legible. Hover one to bring it above its neighbors.
- Hold Space over a card, note, or group to read it up close without changing the zoom. A group shows what it contains.
- Hold ⌥ to see where it's your move. Lines run from the cursor to each one; work off screen gets a chip at the edge that jumps to it.
- Hover a card to trace what it needs (amber), what it unlocks (teal), and what relates to it (dark dots). Double-click a card to hold its trace while you pan; click anywhere or press Esc to let it go.
- Moving lines are dependencies that are still waiting. Still lines are satisfied. Dotted lines are related work that never blocks; they show only while you hover, hold, or select one of their cards.
- "Unblocks N" counts every open task downstream, directly or not.
- N adds a note. Right-click a link to insert a note into it. Notes pass blocking through but never count as work, and can be turned into work items later.
- Reflow lays out the inside of a group. Tidy lays out the current level. Chains and runs of interchangeable cards wrap at about six across.
- A group's inspector picks its arrangement: Automatic flows by dependency, Grid places cards a set number of columns across, and Custom keeps cards where you put them. `orion set <group> --arrange grid --columns 4` does the same from the CLI.
- Drag from the edge of a card to another card to add a dependency.
- Arrows to a card well behind their source loop around instead of doubling back.
- A card's inspector lists what it waits on, what it unblocks, and related cards, each with a button to remove the link. **Add link** searches for another card to connect.

Reset to seed restores the snapshot.

Dashed cards are pull requests that aren't opened yet. Select a card to edit it, add notes, or open what it stands for. Cards take sources: Jira tickets and GitHub issues say what the work is, pull requests and hop branches stacked on them drive its status, and releases, Slack threads, and other links add context. The inspector lists and edits them, `orion attach` and `orion detach` do the same from the CLI, and each card shows a badge per source at its bottom right. Cards with a pull request show what GitHub reported the last time `orion sync` ran.
The toolbar shows when GitHub was last synced, or a sync error; click the status to force a sync. Linked cards show a checks dot (green passing, red failing, amber pending) and changed line count. The inspector shows checks, additions and deletions, update time, author, and review requests. An unlinked work item may show possible pull requests in its inspector; use **Link** to attach one to the card.

## Layout of the code

In `app/`:

- `server/store.ts`: the dev-server endpoint for the data file, its lock, and change notifications.
- `src/persist.ts`: loading, saving, and reacting to changes from other writers.
- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/layout.ts`: laying out one group or the top level: ELK with wrapping, grids, and custom groups left alone.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/sources.ts`: card sources, their precedence, links, and badges.
- `src/nodes.tsx`: task cards and group frames.
- `src/Lens.tsx`: holding Space to read one card, note, or group up close.
- `src/App.tsx`: the canvas, semantic zoom, drill-in, connections outside an open group, notes, and the inspector.
- `src/Sidebar.tsx` and `src/ContextMenu.tsx`: the group list and right-click menu.
- `src/seed.json` and `src/seed.ts`: the Flipbook snapshot and its loader.

In `cli/src/`:

- `cli/init.luau`: commands and their options.
- `store.luau`: reading, locking, and writing the data file.
- `graph.luau`: derived status and leverage, and every edit the commands make.
- `refs.luau`: card sources, their precedence, parsing, and carrying older fields over.
- `github.luau`: looking up pull requests and mapping their state onto cards.
- `render.luau`: text and JSON output.
