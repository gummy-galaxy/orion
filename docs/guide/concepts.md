# Concepts

Orion keeps a graph of what you're working on. The app draws it as a canvas, and the `orion` CLI and its MCP server read and change the same data.

## Cards and notes

A **card** is a piece of work someone will do. It has a label, a recorded status, and optionally references to outside work such as a pull request or a Jira issue. A **gate** is a card that's done once everything it waits on is, such as a release or a sign-off.

A **note** holds context: a decision, a reminder, or a pointer. Notes never count as work, and blocking passes straight through them.

## Links

A link from one card to another means the second waits on the first. A **related** link connects two cards without blocking either.

## Status

Each card records one of `todo`, `active`, `review`, `blocked`, `deferred`, or `done`. Orion also derives a status from the graph: a `todo` card shows as **ready** once nothing it waits on is open, and as blocked while something is. Record `blocked` or `deferred` only for reasons the graph can't show.

## Groups

A **group** holds cards, notes, and other groups, and shows its progress. Group by outcome, not by repository. A group either arranges itself by dependency or keeps cards where you put them.

## Sources

A **source** connects Orion to outside work: GitHub repositories, a Jira project, or local branches through hop. Ingesting a source files new cards in an Unsorted group and updates the ones already on the canvas.

## Canvases

A **canvas** is one board with its own data folder. Commands work on the active canvas unless you pass `--canvas <name>`. The app still calls it a workspace for now.
