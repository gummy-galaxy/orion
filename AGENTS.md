# Orion agent guide

Orion is a canvas of work items, notes, and groups linked by dependencies. Use the `orion` CLI to read and change it. Never edit `orion.json` directly: the Luau CLI owns the data and its lock. The app talks to `orion server start` over HTTP and WebSocket and picks up every change while it's open.

[The charter](docs/development/charter.md) sets Orion's direction: its principles, what it won't do, and the roadmap. Check new work against it, and call out a change that conflicts with it.

[The decisions log](docs/development/decisions.md) records the specific calls made along the way and why. They're defaults that can be challenged, and the charter outranks them. Follow them, raise a change that goes against one rather than working around it, and add or rewrite an entry when the person settles a new call.

## Commands

Run `orion help --all` before working with the canvas. It prints every command and subcommand with its arguments, options, and help, from the same definitions the CLI parses, so it can't fall behind. `orion help <command>` prints one command, and `orion help --all --json` prints the listing as JSON. This guide covers what help can't: which command to reach for, and how they fit together. When you add or change a command, put its syntax and what its options mean in its help text rather than here.

## Reading the canvas

- Start with `orion next` for work that can start now, the items that unblock the most first. `orion group list`, `orion card list`, and `orion node show <id>` fill in the rest, and `orion node query --where '<expr>'` finds cards and groups by their fields.
- Statuses in the output are derived: `ready` means nothing the item waits on is still open. Add `--json` for structured output.
- Query values are quoted strings, numbers and booleans included: `pr = "86"`, `draft = "true"`. A missing field never matches, even under `not`. Quotes are syntax, not shell commands; expressions can't evaluate code or read arbitrary data paths. `orion help node query` lists the fields and operators.
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

Run `orion server status [--json]` to find the running server and its URL. It checks the recorded process and endpoint and clears stale server records.

To show the person the app, or anything else served locally such as a dev server or Storybook, open its URL in the browser built into the tool you're running in. Fall back to an external browser only when that tool has none. Headless captures, such as PR screenshots and videos, are unaffected.

## Changing it

- A gate is done once everything it waits on is; use one for a milestone such as a release or sign-off. A component is a part of a system diagram rather than work; see below.
- `orion card set` changes cards and `orion group set` changes groups. Each takes only its own kind of node, and the error names the other command to use.
- `--ref` resolves through the adapter of the matching source, so a Jira URL works only under a configured Jira source. A branch ref such as `branch:vocksel/orion@agent/196-attach` records the branch work started on, keyed like hop's; GitHub Enterprise hosts go in front of the repository, as in `branch:github.example.com/owner/name@branch`. `--repo` and `--pr` are deprecated and stay for one release.
- `orion card import` adds a card for every ref in one transaction. A ref already on the canvas is skipped and keeps its card. One that doesn't resolve is reported and skipped while the rest are added, and the command then exits nonzero. Jira refs are read through their source's command, so a Jira key must appear in that source's results.
- Snoozing hides a card from attention and `orion next` until a time in the future; a bare date means the start of that day. A snoozed card keeps its derived status and still blocks the cards that wait on it, but has no leverage and isn't counted as ready in group progress. It wakes on its own with nothing written, and is stored as the `snoozedUntil` data field, in UTC.
- Linking an already linked pair updates its label. With both `--after` and `--before`, `orion note add` splits their link, or adds two blocking links if they aren't linked.
- `orion group add` wraps items that share a parent. `orion group remove` deletes everything inside a group at any depth, so preview it with `--dry-run`.
- The CLI never lays out groups itself. `orion group tidy` and changes to a group's members mark it, and the app lays out marked groups deepest first, so nested groups settle before their parents. Custom groups keep their arrangement, and auto groups wrap rows at about six. If `orion server start` isn't running, the layout waits until the app opens.
- `orion server start` accepts raw image bytes at `POST /api/images?canvas=<name>` and returns them at `GET /api/images/<asset>?canvas=<name>`.

Most commands that edit take `--dry-run` and `--if-revision <n>`. A dry run prints its targets and current revision without writing. Apply the same command with `--if-revision` to refuse a write if the document changed. Multiple targets are resolved from one snapshot and edited in one transaction. For example, review `orion node remove --where 'repo = "unrelated"' --dry-run`, then run `orion node remove --where 'repo = "unrelated"' --if-revision 12` using the revision the preview printed.

Statuses are `todo`, `active`, `review`, `blocked`, `deferred`, and `done`. Set `blocked` or `deferred` only for reasons the graph can't show, since waiting on open work already reads as blocked. Snoozing is not a status: use `orion card snooze` to hide a card for a while.

## Organizing work

Run `orion suggestion find` to find related ungrouped cards, then review `orion suggestion list`. Apply only suggestions that clearly fit with `orion suggestion apply <id...>`; use `orion suggestion dismiss <id...>` for the rest.

## System diagrams

A canvas can also draw a system: services, apps, files, and outside tools, linked by what flows between them. Make each part a component with `orion card add <name> --shape <shape> [--note <what it does>]`; a shape makes the card a component. Components have no status, never count as work, and grow to show their whole name and note.

- Shapes: `service` (a box, the default), `store` (a cylinder, for files and databases), `actor` (a pill, for people and agents), `external` (a dashed box, for anything outside the system), `interface` (a window, for a UI), `process` (a chevron, for commands and jobs), and `queue` (a stack, for streams of events).
- Colors: set one on a group with `orion group set <group> --color <color>`, and the components and groups inside take it unless they set their own.

Link components with `orion link add <caller> <callee> --label <what travels>`, pointing from what starts a call to what it calls. Group them by boundary, such as an app, a process, or everything outside the system, and nest smaller groups inside for its parts. `orion group add` wraps items that share a parent, so make the inner groups first.

Create the links before the groups, then run `orion group set <group> --arrange auto` on each group so the app lays it out by its links and leaves room for their labels; it lays out inner groups first. Run Tidy in the app for the top level. A folded group lists what it holds, and opening one shows the components outside it that it talks to. A note at the top level that explains the shapes and colors helps first-time readers.

## Keeping pull requests current

Cards with a pull request ref stay in step with GitHub through `orion ingest`, which refreshes the cards already on the canvas as well as importing from sources. It marks merged pull requests done and closed ones deferred, and sets whose move it is from drafts and reviews. This runs even in a canvas with no sources configured. Run `orion ingest --dry-run` first when unsure.

The refresh records your unplaced open pull requests and likely matching cards; inspect them with `orion source matches`. When the canvas has GitHub sources, only pull requests in their repositories count. Link one to an existing card with `orion card set <id> --ref <pull request URL>`.

When a card has a branch ref for the pull request's head branch in its repository, the refresh attaches the new pull request to that card and records it as its pull request. If more than one card has that branch, the pull request stays unplaced and `orion source matches` lists those cards. Record the branch when you start work (`orion card set <id> --ref branch:owner/name@branch`) so the refresh can attach the pull request you open.

`orion sync` is deprecated and runs only the GitHub refresh. Its `--discover` flag adds your unplaced open pull requests to an Inbox group; a GitHub source does the same through `orion ingest`, which files them in Unsorted. Only use `--discover` when asked, then move each new card into the group it belongs to.

## Sources and ingestion

Use `orion source list` to inspect configured GitHub, Jira, and hop sources, and `orion source add <kind>` to add one; each kind takes only its own options. Keep credentials in `gh` and `acli`, never in the source command.

Run `orion ingest --dry-run` before `orion ingest`. Ingestion files new cards in Unsorted, updates existing cards in place, and leaves cards that are no longer returned alone. Place cards into outcome groups after reviewing them.

Cards keep pull requests, issues, and local branches in `data.refs`. Each ref records its source, kind, key, URL, status, completion state, update time, and source-specific details. A ref's kind and case-insensitive key identify it across ingests. The source's adapter reads its details into source-neutral facts on the ref, such as `stateLabel`, `readiness`, and `checks`, and the app shows those rather than reading the details.

## Habits

- Prefer notes for context, decisions, and reminders. Make an item only for work someone will do.
- Write a note as a plain-language summary of where the card stands. Use Markdown for structure, such as headings and lists. Put code, file paths, and identifiers in code formatting rather than running them through the prose. Keep pull requests and issues in the card's refs (`orion card set <id> --ref ...`) instead of links in the text.
- Log each notable step on the card with `orion log add <text> --card <id> --agent <your agent name>`: a test run and its outcome, or a decision made. Keep the card's note as the short summary of where it stands rather than adding each step to it, and correct a logged mistake with a new entry.
- Find ids with `orion node find <text>`, which matches labels, notes, and refs. Where a command takes an id, a selector works too: `label:"Extract slider"`, `ref:jira:ABC-12` or `ref:<url>`, and `pr:86`. A selector must match exactly one item; when it matches several, the command lists them so you can pick an id.
- Group by outcome, not by repository.

## Issues

- **Filing.** When the person talks an idea through and asks for an issue, distill it into an issue labeled `needs grooming`. Follow `.claude/skills/file-issue/SKILL.md`. That issue can still carry open questions; settle them with the person, then remove the label, before building it.
- **Writing.** Give an issue one outcome, and say what done looks like concretely enough that someone who reads only the issue can tell whether a pull request finishes it. Write for someone who hasn't seen the conversation that led to it.
- **Progress.** When more than one pull request works on an issue, keep a **Progress** checklist at the end of its body. Check off each item with the pull request that shipped it, and add an unchecked item for any concrete work that turns up.

Direction and long-range plans belong in [the charter](docs/development/charter.md).

## Pull requests

When a pull request changes what the app shows, attach before and after screenshots to its description, or videos when the change is an interaction, an animation, or takes several steps to reach. Follow `.claude/skills/pr-screenshots/SKILL.md`, which captures or records both sides the same way, headless, into a scratch folder, uploads them to GitHub through the comment box without posting, and writes the description with `gh`.

CI's perf workflow compares every pull request that touches `app/` against its base branch and keeps the report in one pull request comment, replaced on each run. It skips drafts and runs once a pull request is ready for review. It also runs on every push to `main`, and each run records its medians in PostHog so performance can be charted over time. When a pull request touches canvas rendering, CSS animations or effects, `derive`, `layout`, `merge`, `snap`, the Jotai state, or `Canvas.tsx`, read that comment once it posts. Summarize any flagged regressions in the pull request's Testing section, or say why a flagged change is acceptable. To check before pushing, run `npm run perf` from `app/`. It takes several minutes and measures this machine, so run one at a time with no other heavy work going.

A pull request that finishes an issue closes it. Put `Closes #<n>` in the description, so merging it closes the issue. Don't point at an issue with "Part of", "Advances", "Related", or any other label instead. When a pull request finishes only some of an issue, say in its description which items on the issue's Progress checklist it finishes. When it leaves concrete work undone, add that work to the checklist, or file it as one follow-up issue when it stands on its own.

Give each pull request a place on the canvas. When a card already tracks the work, attach the pull request to it with `orion card set <id> --ref https://github.com/vocksel/orion/pull/<n>`. Otherwise add a card for it in the outcome group it belongs to.

## Docs

The docs site in `docs/` shows Orion's public surfaces. Its CLI and MCP reference pages are generated from the command table and the MCP tool catalog. After changing a command, an option, or an MCP tool, run `lute run docs` from the repository root and commit the pages it writes; CI fails when they're out of date. It formats them with the docs site's Prettier, so run `npm ci` in `docs/` first. Write the guide pages by hand, for someone who has never used Orion.

The generator owns every page in `docs/reference/` and removes any it didn't write, so hand-written pages go elsewhere. Pages about how Orion is made, such as audits, proposals, and studies, go in `docs/development/design/` or `docs/development/engineering/`, with an entry in that section's sidebar in `docs/.vitepress/config.mts`. Write them for a contributor who wasn't in the conversation that produced them.

## Trying a desktop build

A fresh worktree has none of the build's dependencies, and the build fails partway without them. Before the first build there, run `npm ci` in `app/` and `desktop/`, and `lute pkg install` in `cli/` for the Luau packages that `prepare-sidecar` requires.

To let someone try a change in the desktop app, run `npm run build` in `desktop/`, then replace `/Applications/Orion.app`, which installs it for every user on the machine. Every build shares one bundle id, so a fresh build elsewhere goes unseen, and a second copy in `~/Applications` shows up as a duplicate. Quit Orion, move the installed app to the Trash, `ditto` `desktop/src-tauri/target/release/bundle/macos/Orion.app` into its place, register it with `lsregister -f`, and relaunch. When the icon changed, also `touch` the bundle and run `killall Dock`, which otherwise keeps showing the old icon.

## Code style

- Spell identifiers out: `nodes`, not `ns`; `TASK_HEIGHT`, not `TASK_H`; `event`, not `e`. These short names are fine: `doc`/`docs`, `id`, `url`, `ref`, `dir`, `deps`, `repo`, `app`, `pr`, an `ms` suffix, `i`/`j` for indices, `x`/`y` for coordinates, and `a`/`b` in comparators.
- Give each React component its own file named after it, such as `components/SourceBadges.tsx`, and list it in [`app/README.md`](app/README.md)'s code layout when it's a main piece of the app. Don't add a component to another component's file.
- Log diagnostics from the CLI and `orion server start`, such as timings, flush sizes, and errors, with [Archivist](https://github.com/flipbook-labs/archivist). Report rough edges you find in it. Don't use it for the data operation log, which must commit with the change it records.

## Workflows

- Keep each `run:` step to one command, ideally `lute run <script>`. Multi-line shell and multi-step logic go in a Luau script in `cli/.lute/`, run with `working-directory: cli`, so it runs locally the same way. Prefer `@std/*`, and use `process.run` from `@std/process` when an argument may contain spaces. Name steps in Title Case.
- Run a script's body through `runScript` from `cli/src/runScript.luau`. Lute exits 0 for some uncaught errors, such as a `process.run` whose program is missing, so without it a failed step can pass.
- Reference actions from the `actions` organization by major tag, such as `actions/checkout@v7`. Pin every other action to a commit SHA with a version comment.
- Set `timeout-minutes` to about one and a half times a measured run. Raise it only when real runs get close.
- Write every job as a future required check, since most become required once the repository is public. Skip work with a job condition fed by a filter job, like `changes` in `ci.yml`, rather than workflow-level `paths`, which leaves a required check waiting forever. Give each job a name no other workflow uses, because a required check matches the job name alone. Filter jobs are required too: when one fails, the jobs behind it are skipped, and a skipped job passes its check.

## Luau style

- Export one function per module, from a file named after it with a verb first, such as `platform/getDataDir.luau`. Put shared types in a sibling `types.luau` and tests in `<function>.spec.luau` beside it. Constant tables, data lists, and command modules stay tables.
- Keep a helper that only one module uses as a local function there. Once a second module needs it, move it into its own module rather than copying it. Look for an existing helper, such as `getStringField`, before writing one.
- Keep related requires, type aliases, constants, and short assignments together. Separate those groups and adjacent functions with blank lines.
- Name a required module after the module itself, such as `local cli = require("@batteries/cli")` and `local io = require("@lute/io")`, without prefixing the package.
- Within functions, use blank lines between logical steps: setup, guards, loops and branches, state changes, and the final result. Keep statements that form one step together.
- Run StyLua after editing Luau, then review the spacing yourself. StyLua sorts requires and formats statements, but does not add these logical blank lines.

## TypeScript style

The app's TypeScript mirrors the CLI's Luau layout. New and split modules follow these rules, and #427 brings the rest of `app/src` over.

- Export one function per module, from a file named after it with a verb first, such as `refs/getPrimaryRef.ts`. Group modules into folders by concept, put shared types in a sibling `types.ts`, and keep constant tables and data lists as one module.
- Keep a helper that only one module uses local to it, and move it into its own module once a second module needs it.
- Keep pure logic out of components and hooks. Components render and wire up state, and the logic moves into function modules that can be tested without React.
- When a function also exists in the CLI, give it the same name. Its folder can differ.
- Import each module directly by path, with no barrel files. Once #427 adds the `@/` alias for `app/src`, use it instead of relative paths.
- Put tests in `<function>.test.ts` beside the module, testing only that function. Keep them flat: use `test` rather than `it`, and leave out a `describe` that only repeats the file's name. Shared builders live in a folder of fixture modules, one per builder.
- Logic the CLI also needs belongs in Luau, with the app reading the result from `orion serve`. See "Shared logic lives in Luau" in [the decisions log](docs/development/decisions.md).
