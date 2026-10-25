# CLI and agents

The `orion` CLI is the one implementation of Orion's behavior. The app, the desktop shell, scripts, and agents all reach the data through it, either directly or through the server it starts. An agent reading the canvas and an agent changing it use the same commands a person does, so there is one set of rules to test and document.

This follows the [charter](/development/charter), principle 8: people and agents use the same verbs, and every edit can be previewed and undone.

## What the app shares with agents

Agents often need to know what someone is looking at. [`orion focus`](https://github.com/vocksel/orion/pull/33) reports the group the app has open, its ancestors and progress, and the current selection. The app sends this to `orion server start`, which stores it in the canvas's folder. The report is view state, so it skips the canvas lock and never changes the revision. It's cleared when the page closes, when the server starts or stops, and when the active canvas switches.

That lets an agent answer "what's left here?" from the open group rather than the whole canvas. `orion focus` is one of two reads kept at the top level, with `orion next`, because agents run both before almost anything else.

## Queries

`orion node query --where '<expr>'` finds cards and groups. It works with a small language:

- Fields: `kind`, `repo`, `status` (derived), `recordedStatus`, `group` (the parent id), `draft`, `label`, `pr`, and `ref` (any external key).
- Operators: `=` and `!=`, `~` for a case-insensitive substring, and `and`, `or`, and `not` with parentheses.
- Values are quoted, numbers and booleans included, so `pr = "86"` and `draft = "true"`.
- A missing field never matches, even under `not`.

The language is deliberately small. Expressions can't run code or read arbitrary data paths, so a query can only select cards and groups ([#140](https://github.com/vocksel/orion/pull/140)).

## Batch edits

The commands that change several cards take several ids or `--where`, plus three guards:

- `--dry-run` prints the targets and the current revision without writing.
- `--if-revision <n>` refuses the write if the document changed since the preview.
- `--json` returns the same result in a structured form.

Targets resolve against one snapshot, and every change lands in one transaction. A preview and then an apply with the printed revision is therefore safe: either the whole batch lands or none of it does. The same flags work on `card done`, `node remove`, `node move`, `group remove`, `group ungroup`, `group tidy`, `link create`, and `link insert` ([#140](https://github.com/vocksel/orion/pull/140)).

## Noun, then verb

Before 0.1.0, the CLI's surface changes freely. The [decisions](/development/decisions) say interfaces tighten in three stages: break freely before 0.1.0, make each break deliberate through 0.x, and promise stability from 1.0.0 with aliases first.

Within that, commands name the thing they act on first ([#346](https://github.com/vocksel/orion/pull/346)):

- Cards, notes, and links: `card list|create|set|done|import`, `note create`, `link create|remove|insert`.
- Any node: `node show|query|remove|move`.
- Groups: `group list|add|create|remove|set|ungroup|tidy`.
- Canvases: `canvas list|create|rename|set|archive|restore|use|current|path|check`.
- Backups, suggestions, sources, the server, and MCP: `backup list|restore`, `suggestion find|list|apply|dismiss`, `source matches`, `server start|status`, `mcp start`.

The old flat forms, such as `orion remove` and `orion ungroup`, are gone with no aliases. Each noun has its own options, so no flag changes meaning depending on what it targets. [Decision on noun-then-verb](/development/decisions) records the reasoning.

## The MCP server

`orion mcp start` runs an MCP server over stdio. It's built into the CLI binary, so a client launches the same program a person runs. Each tool validates its arguments and maps them onto one CLI command in the same process ([#134](https://github.com/vocksel/orion/pull/134)). The tool catalog is written in Luau beside the CLI.

Coverage is growing toward every CLI option:

- [`orion_tidy` and `orion_check`](https://github.com/vocksel/orion/pull/399) are merged. An agent can tidy groups and check the layout in bulk without a shell. `orion_check` is marked read-only.
- [Every existing option](https://github.com/vocksel/orion/pull/350) gets an MCP tool or field, and a spec checks in both directions that the CLI and MCP agree. Adding an option to one without the other fails the spec. This is in review.
- Calls that hit the canvas lock are [queued rather than failed](https://github.com/vocksel/orion/pull/403). Another Orion process, such as the app's server or another agent's MCP server, can hold the lock for longer than the store's 5-second wait. The call retries and keeps its place in line, and after 30 seconds it fails with an error that says nothing was changed. This merged on October 17.

The MCP server is kept generic. Orion documents how to register `orion mcp start` with any client, and ships no setup for each AI provider ([decisions](/development/decisions)).

## Reference

The CLI and MCP reference pages are generated from the command table and the tool catalog, so they match the code. `lute run docs` regenerates them, and CI fails when they're out of date ([#326](https://github.com/vocksel/orion/pull/326)). See the [CLI reference](/reference/cli/) and the [MCP reference](/reference/mcp).

## Agent features in review

Three features are in review. Each one exists so an agent can act on the canvas without the person losing track of what happened.

- **Reveal.** [`orion reveal`](https://github.com/vocksel/orion/pull/354) selects cards or groups in the open app and zooms to them. The app opens the innermost group that holds them all, and the move is one step in navigation history, so Back returns to where the person was. With no app running, it opens the installed app on the same data folder and reports success only after the app has reported the selection back.
- **Apply a plan.** [`orion apply`](https://github.com/vocksel/orion/pull/351) runs a JSON list of cards, notes, groups, and links in one transaction. A step can name a handle, and later steps refer to it as `@handle`. The whole plan lands or none of it does, and an error names the failing step by position.
- **Canvas log.** [`orion log`](https://github.com/vocksel/orion/pull/353) adds an append-only log. Each entry records its text, time, author, and the cards it touches, and entries are never edited. A correction is a new entry. The card details panel already shows a [timeline](https://github.com/vocksel/orion/pull/356) of a card's entries, and it shows nothing until the log lands.
