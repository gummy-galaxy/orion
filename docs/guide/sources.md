# Sources

A source brings outside work onto the canvas: pull requests and issues from GitHub, issues from Jira, local branches through [hop](https://github.com/vocksel/hop), and Claude Code sessions. Sources keep their own data. Orion keeps references to it, plus the meaning that comes from linking it.

## Add sources

Configure each source once. Credentials stay in each tool's own CLI, `gh` for GitHub and `acli` for Jira, never in Orion.

```sh
orion source add github --host github.com --owners my-org
orion source add jira --command '["acli","jira","workitem","search","--jql","assignee = currentUser() AND resolution = Unresolved","--json"]' --browse https://jira.example.com/browse
orion source add hop
```

GitHub's `--owners`, `--include`, and `--exclude` take comma-separated lists. Add `--id` to tell two sources of the same kind apart, such as a GitHub Enterprise host next to github.com.

The command a Jira source runs, and the hop executable when it isn't `hop` on your `PATH`, stay on this machine in the data folder's `commands.json`. The canvas's files keep only the source's other settings, so a canvas you share through git can't make someone else's Orion run a program. When a canvas arrives with a Jira source and no command here, ingest says so. Run `orion source add jira --id <id> --command '[...]'` to set this machine's command: adding a source that already exists keeps the settings you leave out. Agents can add GitHub and hop sources and remove sources through MCP, but a Jira source's command is set only at the CLI.

`orion source list` shows what's configured, and `orion source remove <id>` stops ingesting from a source. Cards it already made stay.

## Ingest

Preview first, then run it:

```sh
orion ingest --dry-run
orion ingest
```

Ingest files new cards in an **Unsorted** group, updates matching cards in place, and links Jira or GitHub issues mentioned by pull requests. Cards a source stops returning are left alone. Move new cards into the groups they belong to.

Ingest also refreshes every card with a pull request: merged ones are marked done, closed ones deferred, and each card records whose move it is from drafts and reviews. `orion server start` runs this refresh shortly after it starts and every 15 minutes. In between, it checks your GitHub notifications every minute, which open pull requests changed every two minutes, and pending checks every 30 seconds, and refetches only what changed. The cards you're looking at, in the open group or the selection along with the cards blocking them, are checked for changes every 30 seconds instead. The app asks for a check when you return to its window. Click the sync status in the toolbar to refresh everything now.

Use `--source <id>` to run one source, and `--json` for a machine-readable report.

## Attach work to cards

A card's refs point at outside work. Attach one with `--ref` on `orion card create` or `orion card set`, using:

- a GitHub pull request or issue URL,
- a Jira issue URL, or `jira:ABC-12`,
- `branch:owner/name@branch` for the branch work started on.

When you open a pull request from a branch a card records, the next refresh attaches it to that card. `orion ref remove <id> <key>` takes a ref off.

To add cards for many refs at once, pass them to `orion card import`, or pipe one per line with `--stdin`. Refs already on the canvas are skipped, and ones that fail are reported without stopping the rest.

## Agent sessions

A Claude Code source puts each session on the card whose branch it ran on, as a `session` ref:

```sh
orion source add claude
orion ingest
```

It reads Claude Code's data folder, `~/.claude` unless `CLAUDE_CONFIG_DIR` or `--dir` names another, and never writes to it. Ingest looks at sessions active in the last three weeks, reading only the end of each transcript. A session attaches to the card with a branch ref, or a pull request, for the branch checked out where it ran. Sessions on `main` or with no matching card are left out, and a session never adds a card.

The ref records whose move it is. `sessionState` is `working` while Claude Code runs a turn, and `waiting` once it's your move, whether the session finished its turn or stopped on a permission prompt. `stateLabel` says the same in words. Nothing a session said is stored: the canvas's files keep only its state, and the app reads the session's turns from Claude Code when it shows them. Agents can't add a Claude Code source through MCP, since it reads every transcript on the machine.

## Organize what came in

`orion suggestion find` proposes groups for ungrouped cards by following links, Jira epics, shared branches, and refs. To have an agent name the groups and split them by outcome, pass its command as a JSON array with `--command`, such as `--command '["claude","-p","--output-format","json"]'`. Orion sends the cards as a prompt on stdin and reads the groups from the JSON it prints. The agent's CLI must already be signed in, and if it fails or replies with no usable groups, Orion keeps the groups it found itself.

Review with `orion suggestion list`, then `orion suggestion apply` or `orion suggestion dismiss` by id, or `--all`.
