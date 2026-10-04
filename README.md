# Orion

A canvas for graph-shaped work: tasks and pull requests with dependencies, grouped freely across repositories, with zoom levels that go from single cards out to whole bodies of work.

This is a prototype seeded from a snapshot of the Flipbook Release Map. It runs in the browser for now; a desktop shell comes later.

- `app/`: the canvas.
- `cli/`: `orion`, a command-line tool for reading and editing the same data, meant for agents as much as people.

## Data

Everything lives in one file, `~/Library/Application Support/Orion/orion.json`. Set `ORION_DATA_DIR` to use another folder. The app and the CLI take the same lock before writing and bump a revision with each write, so both can be open at once. Changes from either side show up in the other within a moment.

## Run the app

```sh
cd app
npm install
npm run dev
```

The dev server reads and writes the data file. The first time it runs without one, it carries over what the browser had saved, or starts from the seed.

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

## Using the canvas

- Drag to pan, scroll to zoom. ⌘-drag selects; ⌘-click or ⇧-click adds to the selection. Right-click anything for its actions.
- ⌘G groups the selection. ⇧⌘G ungroups. Groups can nest and span repositories.
- The list on the left shows every group in canvas order. Click one to open it.
- Double-click a group, or press Enter with one selected, to open it. Esc goes back up, and the breadcrumbs jump to any level.
- An open group shows the outside work it waits on along its left side and the work waiting on it along its right. Click one to jump to it.
- Zooming out folds groups into single bodies, inner groups first. Links between folded groups are bundled into one line with a count.
- Hold ⌘ to see what needs you: your move on GitHub (blue) and unowned work that's ready to start (teal). Lines run from the cursor to each one; work off screen gets a chip at the edge that jumps to it.
- Hover a card to trace what it needs (amber) and what it unlocks (teal). Double-click a card to hold its trace while you pan; click anywhere or press Esc to let it go.
- Moving lines are dependencies that are still waiting. Still lines are satisfied. Dotted lines are related work that never blocks.
- "Unblocks N" counts every open task downstream, directly or not.
- N adds a note. Right-click a link to insert a note into it. Notes pass blocking through but never count as work, and can be turned into work items later.
- Reflow lays out the inside of a group. Tidy lays out the current level.
- Drag from the edge of a card to another card to add a dependency.

Reset to seed restores the snapshot.

Dashed cards are pull requests that aren't opened yet. Select a card to edit it, add notes, or open its pull request. Cards with a repository and pull request number show what GitHub reported the last time `orion sync` ran.

## Layout of the code

In `app/`:

- `server/store.ts`: the dev-server endpoint for the data file, its lock, and change notifications.
- `src/persist.ts`: loading, saving, and reacting to changes from other writers.
- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/layout.ts`: ELK layout for one group or the top level.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/nodes.tsx`: task cards and group frames.
- `src/App.tsx`: the canvas, semantic zoom, drill-in, connections outside an open group, notes, and the inspector.
- `src/Sidebar.tsx` and `src/ContextMenu.tsx`: the group list and right-click menu.
- `src/seed.json` and `src/seed.ts`: the Flipbook snapshot and its loader.

In `cli/src/`:

- `cli/init.luau`: commands and their options.
- `store.luau`: reading, locking, and writing the data file.
- `graph.luau`: derived status and leverage, and every edit the commands make.
- `github.luau`: looking up pull requests and mapping their state onto cards.
- `render.luau`: text and JSON output.
