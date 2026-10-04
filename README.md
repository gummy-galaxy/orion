# Orion

A canvas for graph-shaped work: tasks and pull requests with dependencies, grouped freely across repositories, with zoom levels that go from single cards out to whole bodies of work.

This is a prototype seeded from a snapshot of the Flipbook Release Map. It runs in the browser for now; a desktop shell comes later.

## Run

```sh
npm install
npm run dev
```

## Using the canvas

- Drag on empty space to select. ⌘-click or ⇧-click adds to the selection.
- ⌘G groups the selection. ⇧⌘G ungroups. Groups can nest and span repositories.
- Double-click a group, or press Enter with one selected, to open it. Esc goes back up, and the breadcrumbs jump to any level.
- Zooming out folds groups into single bodies, inner groups first. Links between folded groups are bundled into one line with a count.
- Hover a card to trace what it needs (amber) and what it unlocks (teal).
- Moving lines are dependencies that are still waiting. Still lines are satisfied. Dotted lines are related work that never blocks.
- "Unblocks N" counts every open task downstream, directly or not.
- Reflow lays out the inside of a group. Tidy lays out the current level.
- Drag from the edge of a card to another card to add a dependency.

State saves to local storage. Reset to seed restores the snapshot.

Dashed cards are pull requests that aren't opened yet. Select a card to edit it, add notes, or open its pull request.

## Layout of the code

- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/layout.ts`: ELK layout for one group or the top level.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/nodes.tsx`: task cards and group frames.
- `src/App.tsx`: the canvas, semantic zoom, drill-in, and the inspector.
- `src/seed.json` and `src/seed.ts`: the Flipbook snapshot and its loader.
