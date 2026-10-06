# Orion agent guide

Orion is a canvas of work items, notes, and groups linked by dependencies. Use the `orion` CLI to read and change it. Never edit `orion.json` directly: the CLI takes the lock the app expects, and the app picks up every change while it's open.

## Reading the canvas

- `orion ready` lists work that can start now, the items that unblock the most first.
- `orion groups` lists groups with their progress.
- `orion list [--group <id>] [--all]` lists open items, or everything with `--all`.
- `orion show <id>` shows one item with what it waits on and leads to, or a group with its contents.

Add `--json` to any of these for structured output. Statuses in the output are derived: `ready` means nothing the item waits on is still open.

## What the person is looking at

`orion focus` shows the group open in the app, the groups it sits inside, and what's selected. Run it before answering a question about the canvas.

- Read the question as being about the selection first, then the open group, then work linked to either. Widen to the whole canvas only when the question names something else or the focus doesn't fit it.
- "This", "these", "here", and unnamed items most likely mean the selection, or the open group when nothing is selected.
- `orion list --group <id>` and `orion show <id>` fill in the details for whatever is in focus.
- Say which focus you assumed when it shaped the answer, so a wrong guess is easy to correct.
- At the top level with nothing selected, or with the app closed, there's no focus to lean on.

## Changing it

- `orion add <title> [--group <id>] [--repo <name>] [--pr <number>] [--status <status>]` adds a work item.
- `orion set <id> [--label …] [--status …] [--who you|review|ci] [--note …] [--repo …] [--pr …]` changes fields. Pass an empty value to clear `--who` or `--note`.
- `orion done <id>` marks an item done.
- `orion link <first> <then>` makes `<then>` wait on `<first>`. Add `--related` for a link that never blocks. `orion unlink` removes one.
- `orion note <text> [--group <id>] [--after <id>] [--before <id>]` adds a note. With both `--after` and `--before`, it goes inside that existing link.
- `orion group <label> --items <id,id,…>`, `orion ungroup <id>`, and `orion move <id> --to <group>` (or `--top`) organize work.
- `orion remove <id>` deletes an item. Removing a note reconnects the links that ran through it.

Statuses are `todo`, `active`, `review`, `blocked`, `deferred`, and `done`. Set `blocked` or `deferred` only for reasons the graph can't show, since waiting on open work already reads as blocked.

## Keeping pull requests current

Cards with a repository and pull request number stay in step with GitHub through `orion sync`. It marks merged pull requests done and closed ones deferred, and sets whose move it is from drafts and reviews. Run `orion sync --dry-run` first when unsure.

`orion sync` adds pending review requests without cards to the Review requests group. It also records your unplaced open pull requests and likely matching cards; inspect them with `orion matches`. Link one to an existing card with `orion set <id> --repo <repo> --pr <n>`.

`orion sync --discover` adds your unplaced open pull requests to an Inbox group. Only use it when asked, then move each new card into the group it belongs to.

## Habits

- Prefer notes for context, decisions, and reminders. Make an item only for work someone will do.
- Look up ids with `orion list --all` or `orion show` rather than guessing them.
- Group by outcome, not by repository.
