# Orion

A canvas for graph-shaped work: tasks and pull requests with dependencies, grouped freely across repositories, with zoom levels that go from single cards out to whole bodies of work.

This is a prototype seeded from a snapshot of the Flipbook Release Map. It runs in the browser for now; a desktop shell comes later.

## Run

```sh
npm install
npm run dev
```

## Using the canvas

- Drag to pan, scroll to zoom. ⌘-drag selects; ⌘-click or ⇧-click adds to the selection. Right-click anything for its actions.
- ⌘G groups the selection. ⇧⌘G ungroups. Groups can nest and span repositories.
- The list on the left shows every group in canvas order. Click one to open it.
- Double-click a group, or press Enter with one selected, to open it. Esc goes back up, and the breadcrumbs jump to any level.
- An open group shows the outside work it waits on along its left side and the work waiting on it along its right. Click one to jump to it.
- Zooming out folds groups into single bodies, inner groups first. Links between folded groups are bundled into one line with a count.
- Hover a card to trace what it needs (amber) and what it unlocks (teal).
- Moving lines are dependencies that are still waiting. Still lines are satisfied. Dotted lines are related work that never blocks.
- "Unblocks N" counts every open task downstream, directly or not.
- N adds a note. Right-click a link to insert a note into it. Notes pass blocking through but never count as work, and can be turned into work items later.
- Reflow lays out the inside of a group. Tidy lays out the current level.
- Drag from the edge of a card to another card to add a dependency.

State saves to local storage. Reset to seed restores the snapshot.

Dashed cards are pull requests that aren't opened yet. Select a card to edit it, add notes, or open its pull request.

## Layout of the code

- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/layout.ts`: ELK layout for one group or the top level.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/nodes.tsx`: task cards and group frames.
- `src/App.tsx`: the canvas, semantic zoom, drill-in, connections outside an open group, notes, and the inspector.
- `src/Sidebar.tsx` and `src/ContextMenu.tsx`: the group list and right-click menu.
- `src/seed.json` and `src/seed.ts`: the Flipbook snapshot and its loader.
