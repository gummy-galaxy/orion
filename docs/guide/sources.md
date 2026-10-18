# Sources

A source brings outside work onto the canvas: pull requests and issues from GitHub, issues from Jira, and local branches through [hop](https://github.com/vocksel/hop). Sources keep their own data. Orion keeps references to it, plus the meaning that comes from linking it.

## Add sources

Configure each source once. Credentials stay in each tool's own CLI, `gh` for GitHub and `acli` for Jira, never in Orion.

```sh
orion source add github --host github.com --owners my-org
orion source add jira --command '["acli","jira","workitem","search","--jql","assignee = currentUser() AND resolution = Unresolved","--json"]' --browse https://jira.example.com/browse
orion source add hop
```

GitHub's `--owners`, `--include`, and `--exclude` take comma-separated lists. Add `--id` to tell two sources of the same kind apart, such as a GitHub Enterprise host next to github.com.

`orion source list` shows what's configured, and `orion source remove <id>` stops ingesting from a source. Cards it already made stay.

## Ingest

Preview first, then run it:

```sh
orion ingest --dry-run
orion ingest
```

Ingest files new cards in an **Unsorted** group, updates matching cards in place, and links Jira or GitHub issues mentioned by pull requests. Cards a source stops returning are left alone. Move new cards into the groups they belong to.

Ingest also refreshes every card with a pull request: merged ones are marked done, closed ones deferred, and each card records whose move it is from drafts and reviews. `orion server start` runs this refresh shortly after it starts and every 15 minutes. In between, it checks your GitHub notifications every minute and which open pull requests changed every two minutes, and refetches only those. The app asks for a check when you return to its window. Click the sync status in the toolbar to refresh everything now.

Use `--source <id>` to run one source, and `--json` for a machine-readable report.

## Attach work to cards

A card's refs point at outside work. Attach one with `--ref` on `orion card add` or `orion card set`, using:

- a GitHub pull request or issue URL,
- a Jira issue URL, or `jira:ABC-12`,
- `branch:owner/name@branch` for the branch work started on.

When you open a pull request from a branch a card records, the next refresh attaches it to that card. `orion ref remove <id> <key>` takes a ref off.

To add cards for many refs at once, pass them to `orion card import`, or pipe one per line with `--stdin`. Refs already on the canvas are skipped, and ones that fail are reported without stopping the rest.

## Organize what came in

`orion suggestion find` proposes groups for ungrouped cards by following links, Jira epics, shared branches, and refs. Add `--agent codex` or `--agent claude` to have that agent name the groups and split them by outcome; its CLI must already be signed in.

Review with `orion suggestion list`, then `orion suggestion apply` or `orion suggestion dismiss` by id, or `--all`.
