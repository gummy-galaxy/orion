# Working the canvas

## Commands

Run `orion help --all` before working with the canvas. It prints every command and subcommand with its arguments, options, and help, from the same definitions the CLI parses, so it can't fall behind. `orion help <command>` prints one command, and `orion help --all --json` prints the listing as JSON. This guide covers what help can't: which command to reach for, and how they fit together. When you add or change a command, put its syntax and what its options mean in its help text rather than here. The same definition is its MCP tool: give the command an `mcp` declaration beside `define`, and define an option whose value isn't plain text, such as an id, an enum, or an integer, with `addArgument` and its type. `lute test` fails for a command that declares no tool.

## Reading the canvas

- Start with `orion next` for work that can start now, the items that unblock the most first. `orion group list`, `orion card list`, and `orion node show <id>` fill in the rest, and `orion node query --where '<expr>'` finds cards and groups by their fields.
- Statuses in the output are derived: `ready` means nothing the item waits on is still open. Add `--json` for structured output.
- Query values are quoted strings, numbers and booleans included: `pr = "86"`, `draft = "true"`. A missing field never matches, even under `not`. Quotes are syntax, not shell commands; expressions can't evaluate code or read arbitrary data paths. `orion help node query` lists the fields and operators, and [the query reference](../docs/reference/query.md) explains each one.
- `orion canvas check` reports layout problems that come from stored positions and sizes, in canvas coordinates. It exits nonzero when it finds any, and `--json` prints a flat list of `{kind, ids, bounds}` entries, with `bounds` null for a dangling link.
- Pass `--canvas <name>` to work on a specific canvas, or rely on the active one. `orion canvas list` and `orion canvas current` show the available and active canvases.
- If a change was a mistake, `orion backup restore <revision>` restores the newest backup with that revision as a new revision, and backs up the current file first.

## What the person is looking at

The app reports its open group and selection to `orion server start`. `orion focus` shows that report for the selected canvas, including the open group's ancestors. Run it before answering a question about the canvas.

- Read the question as being about the selection first, then the open group, then work linked to either. Widen to the whole canvas only when the question names something else or the focus doesn't fit it.
- "This", "these", "here", and unnamed items most likely mean the selection, or the open group when nothing is selected.
- `orion card list --group <id>` and `orion node show <id>` fill in the details for whatever is in focus.
- Say which focus you assumed when it shaped the answer, so a wrong guess is easy to correct.
- At the top level with nothing selected, or with the app closed, there's no focus to lean on.

To point the person at cards, run `orion reveal <id…>`. The app selects them, opens the innermost group that holds them all, and zooms to them, and the step goes into its Back history. `--select-only` selects without moving the camera. With no app running, reveal opens the installed app first. Name the cards you revealed in your reply.

Run `orion server status [--json]` to find the running server and its URL. It checks the recorded process and endpoint and clears stale server records.

To show the person the app, or anything else served locally such as a dev server or Storybook, open its URL in the browser built into the tool you're running in. Fall back to an external browser only when that tool has none. Headless captures, such as PR screenshots and videos, are unaffected.

## Changing it

- A gate is done once everything it waits on is; use one for a milestone such as a release or sign-off. A component is a part of a system diagram rather than work; see [System diagrams](system-diagrams.md).
- `orion card set` changes cards and `orion group set` changes groups. Each takes only its own kind of node, and the error names the other command to use.
- `--ref` resolves through the adapter of the matching source, so a Jira URL works only under a configured Jira source. A branch ref such as `branch:vocksel/orion@agent/196-attach` records the branch work started on, keyed like hop's; GitHub Enterprise hosts go in front of the repository, as in `branch:github.example.com/owner/name@branch`. Attach a pull request with `--ref` and its URL; `--repo` only records the repository a card belongs to, such as a component's. [The ref reference](../docs/reference/refs.md) lists every form `--ref` takes and the key each one stores.
- `orion apply` runs a plan in one write, so a timeline of many cards, notes, groups, and links takes one call instead of one per change. A plan is a JSON list of operations that run in order and land whole or not at all. `addCard` and `addNote` take a `handle`, and later steps refer to it as `"@handle"`; refer to existing cards and groups by id. The output maps each handle to the id it got.
- `orion card import` adds a card for every ref in one transaction. A ref already on the canvas is skipped and keeps its card. One that doesn't resolve is reported and skipped while the rest are added, and the command then exits nonzero. Jira refs are read through their source's command, so a Jira key must appear in that source's results.
- Finishing a card leaves it waiting, shimmering until the person closes it out and its Done stamp lands along with the waiting cards chained to it. That moment is theirs, so run `orion card chain-close` only when they ask.
- Snoozing hides a card from attention and `orion next` until a time in the future; a bare date means the start of that day. A snoozed card keeps its derived status and still blocks the cards that wait on it, but has no leverage and isn't counted as ready in group progress. It wakes on its own with nothing written, and is stored as the `snoozedUntil` data field, in UTC.
- Linking an already linked pair updates its label. With both `--after` and `--before`, `orion card create` and `orion note create` split their link, or add two blocking links if they aren't linked.
- A new card lands beside the card that blocks it, or before the card it blocks, so give `--after` or `--before` when you know its neighbor; a card linked later stays where it first landed. One with no links in its group continues the group's last row without widening it. `orion apply` places a plan's new cards after its last step, so its links count.
- `orion group create` wraps items that share a parent. `orion group remove` deletes everything inside a group at any depth, so preview it with `--dry-run`.
- The CLI never lays out groups itself. `orion group tidy` and changes to a group's members mark it, and the app lays out marked groups deepest first, so nested groups settle before their parents. Custom groups keep their arrangement, and auto groups wrap rows at about six. If `orion server start` isn't running, the layout waits until the app opens.
- `orion media add <file>` adds an image to the canvas, and `orion media list` lists them. Don't call `orion server start`'s HTTP API; it's internal to the app.

With `--json`, every write prints the `revision` it made, and a failure prints `{"error": {"message": …}}`. Most commands that edit take `--dry-run` and `--if-revision <n>`. A dry run prints its targets and current revision without writing. Apply the same command with `--if-revision` to refuse a write if the document changed. Multiple targets are resolved from one snapshot and edited in one transaction. For example, review `orion node remove --where 'repo = "unrelated"' --dry-run`, then run `orion node remove --where 'repo = "unrelated"' --if-revision 12` using the revision the preview printed.

Statuses are `todo`, `active`, `review`, `blocked`, `deferred`, and `done`. Set `blocked` or `deferred` only for reasons the graph can't show, since waiting on open work already reads as blocked. Snoozing is not a status: use `orion card snooze` to hide a card for a while.

## Organizing work

Run `orion suggestion find` to find related ungrouped cards, then review `orion suggestion list`. It groups by links, epics, branches, and refs; to have an agent name the groups instead, pass its command as a JSON array with `--command`. Apply only suggestions that clearly fit with `orion suggestion apply <id...>`; use `orion suggestion dismiss <id...>` for the rest.

## Habits

- Prefer notes for context, decisions, and reminders. Make an item only for work someone will do.
- Write a note as a plain-language summary of where the card stands. Use Markdown for structure, such as headings and lists. Put code, file paths, and identifiers in code formatting rather than running them through the prose. Keep pull requests and issues in the card's refs (`orion card set <id> --ref ...`) instead of links in the text.
- Log each notable step on the card with `orion log add <text> --card <id> --agent <your agent name>`: a test run and its outcome, or a decision made. Keep the card's note as the short summary of where it stands rather than adding each step to it, and correct a logged mistake with a new entry.
- Find ids with `orion node find <text>`, which matches labels, notes, and refs. Where a command takes an id, a selector works too: `label:"Extract slider"`, `ref:jira:ABC-12` or `ref:<url>`, and `pr:86`. A selector must match exactly one item; when it matches several, the command lists them so you can pick an id. [The selector reference](../docs/reference/selectors.md) has every form.
- Group by outcome, not by repository.
