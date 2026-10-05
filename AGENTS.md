# Orion agent guide

Orion is a canvas of work items, notes, and groups linked by dependencies. Use the `orion` CLI to read and change it. Never edit `orion.json` directly: the CLI takes the lock the app expects, and the app picks up every change while it's open.

## Reading the canvas

- `orion ready` lists work that can start now, the items that unblock the most first.
- `orion groups` lists groups with their progress.
- `orion list [--group <id>] [--all]` lists open items, or everything with `--all`.
- `orion show <id>` shows one item with what it waits on and leads to, or a group with its contents.

Add `--json` to any of these for structured output. Statuses in the output are derived: `ready` means nothing the item waits on is still open.

`orion backups [--json]` lists saved revisions. If a change was a mistake, `orion restore <revision>` restores the newest backup with that revision as a new revision and backs up the current file first.

Pass `--workspace <name>` to work in a specific workspace, or rely on the active workspace. Use `orion workspace list` and `orion workspace current` to check the available and active workspaces.

## Changing it

- `orion add <title> [--group <id>] [--source <kind:value|url>] [--kind gate] [--repo <name>] [--pr <number>] [--status <status>]` adds a work item. A gate is done once everything it waits on is; use one for a milestone such as an audit or sign-off.
- `orion attach <id> <kind> <value>` (or `orion attach <id> <url>`) links what a card stands for, and `orion detach` takes it off. Kinds are `github-pr` (`repo#123`, or `repo` for one not opened yet), `github-issue`, `github-release` (`repo@tag`), `jira` (`KEY-123`), `hop` (`repo:branch`), `slack`, and `url`. Jira tickets and issues say what the work is, pull requests stacked on them drive its status, and the rest are links.
- `orion set <id> [--label …] [--status …] [--who you|review|ci] [--note …] [--repo …] [--pr …]` changes fields. Pass an empty value to clear `--who` or `--note`.
- `orion done <id>` marks an item done.
- `orion link <first> <then>` makes `<then>` wait on `<first>`. Add `--related` for a link that never blocks. `orion unlink` removes one.
- `orion note <text> [--group <id>] [--after <id>] [--before <id>]` adds a note. With both `--after` and `--before`, it goes inside that existing link.
- `orion group <label> --items <id,id,…>`, `orion ungroup <id>`, and `orion move <id> --to <group>` (or `--top`) organize work.
- `orion remove <id>` deletes an item. Removing a note reconnects the links that ran through it.

Statuses are `todo`, `active`, `review`, `blocked`, `deferred`, and `done`. Set `blocked` or `deferred` only for reasons the graph can't show, since waiting on open work already reads as blocked.

## Organizing work

Run `orion suggest` to find related ungrouped cards, then review `orion suggestions`. Apply only suggestions that clearly fit with `orion suggestions apply <id...>`; use `orion suggestions dismiss <id...>` for the rest.

## Keeping pull requests current

Cards with a pull request source stay in step with GitHub through `orion sync`. It marks merged pull requests done and closed ones deferred, and sets whose move it is from drafts and reviews. A published `github-release` source finishes a card with no pull request. Run `orion sync --dry-run` first when unsure.

`orion sync` adds pending review requests without cards to the Review requests group. It also records your unplaced open pull requests and likely matching cards; inspect them with `orion matches`. Link one to an existing card with `orion attach <id> github-pr <repo>#<n>`.

`orion sync --discover` adds your unplaced open pull requests to an Inbox group. Only use it when asked, then move each new card into the group it belongs to.

## Sources and ingestion

Use `orion source list` to inspect configured GitHub, Jira, and hop sources. Add a GitHub source with `orion source add github --host <host> --owner <owner>` (repeat `--owner` for more owners; `--include` and `--exclude` filter repositories). Add Jira with `orion source add jira --command '<JSON array>' --browse <url>` and hop with `orion source add hop`. Keep credentials in `gh` and `acli`, never in the source command. Remove a source with `orion source remove <id>`.

Run `orion ingest --dry-run` before `orion ingest`; add `--json` for structured counts or `--source <id>` to limit the run. Ingestion files new cards in Unsorted, updates existing cards in place, and leaves cards that are no longer returned alone. Place cards into outcome groups after reviewing them.

## Habits

- Prefer notes for context, decisions, and reminders. Make an item only for work someone will do.
- Look up ids with `orion list --all` or `orion show` rather than guessing them.
- Group by outcome, not by repository.
