# The command line

Everything the canvas shows, the `orion` command can read and change. The app picks up each change while it's open, so you can type a command and watch the card appear. This page walks through a first session. [Getting started](./getting-started#the-cli) covers putting `orion` on your `PATH`.

## Finding your way

Commands name the thing they act on, then the action: `orion card create`, `orion link create`, `orion group list`. To see what's there:

```sh
orion help               # the commands, and what Orion is
orion help card          # the subcommands of one command
orion help card create   # one command's arguments and options
orion help --all         # every command at once
```

`--help` after any command prints the same thing. The [CLI reference](/reference/cli/) has it all on the web.

## Canvases

Commands work on the active canvas. `orion canvas list` shows your canvases and marks the active one, `orion canvas create` makes another, and `orion canvas use <name>` switches to it. Pass `--canvas <name>` to run a single command on a different canvas without switching.

## Adding work

Add a card for each piece of work:

```sh
orion card create "Design the settings page"
```

Orion prints the new card's id. Give `--after` to add a card that waits on another one; it lands beside it, already linked:

```sh
orion card create "Build the settings page" --after 'label:"Design the settings page"'
```

Link cards you've already made with `orion link create`, first the work that has to happen first, then the work that waits on it. A gate is a card that's done once everything it waits on is, which suits a milestone such as a release:

```sh
orion card create "Ship settings" --kind gate
orion link create 'label:"Build the settings page"' 'label:"Ship settings"'
```

Notes hold context rather than work: `orion note create "Ask design about dark mode"`. `orion group create` gathers cards into a group, which shows their progress. [Concepts](./concepts) explains how these fit together.

## Reading the canvas

`orion next` lists the work that can start now, the cards that unblock the most first:

```sh
orion next
```

```text
ready    710e9920-…  Design the settings page    step    unblocks 2
```

A card is **ready** once nothing it waits on is open. `orion card list` lists every open card with its status, and `orion node show <id>` shows one card: its fields, its refs, and what it waits on and unblocks.

To find something, `orion node find <text>` searches labels, notes, and refs. `orion node query` is more precise, matching on fields such as status, repository, or pull request:

```sh
orion node query --where 'status = "ready" and repo = "gummy-galaxy/orion"'
```

The [query reference](/reference/query) lists every field and operator `--where` takes.

## Naming a card

Ids are long, so wherever a command takes one, a selector works too. `label:"Design the settings page"` names a card by its label, `pr:86` by its pull request, and `ref:jira:ABC-12` by an outside ref. A selector has to match exactly one card; when it matches several, the command lists their ids so you can pick. The [selector reference](/reference/selectors) has every form.

Quote selectors and expressions for your shell. Single quotes around the whole thing keep the double quotes inside it.

## Changing work

`orion card set` changes a card's fields, and `orion card done` finishes it:

```sh
orion card set 'label:"Design the settings page"' --status active
orion card done 'label:"Design the settings page"'
```

Statuses are `todo`, `active`, `review`, `blocked`, `deferred`, and `done`. Use `blocked` or `deferred` only for a reason the links don't show, since a card waiting on open work already reads as blocked.

## Tying cards to outside work

`--ref` attaches a pull request, an issue, or a branch to a card:

```sh
orion card set 'label:"Design the settings page"' --ref https://github.com/gummy-galaxy/orion/pull/86
```

A github.com link works as is. Jira issues and GitHub Enterprise need a [source](./sources) first, which also brings your pull requests and issues in as cards. The [ref reference](/reference/refs) lists every form `--ref` takes.

## Changing many cards safely

Commands that edit several cards, such as `orion card done` and `orion node remove`, take `--where` in place of ids. Preview one with `--dry-run`, which prints what it would change and the canvas's current revision:

```sh
orion card done --where 'label ~ "settings"' --dry-run
```

Then run it again with `--if-revision` and that revision, so it refuses to write if anything changed in between. If something still goes wrong, `orion history set <revision>` brings back the canvas from before, and `orion history list` shows which revision that is.

## Scripts and agents

Every command takes `--json`, and its output is meant for scripts: [Public surfaces](./surfaces#json-output) says what it promises. `orion apply` runs a whole plan of cards, notes, groups, and links in one write. Agents can call the same commands as tools through `orion mcp start`; [Getting started](./getting-started#connect-an-agent-over-mcp) shows how to connect one.
