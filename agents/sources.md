# Sources and pull request refresh

## Keeping pull requests current

Cards with a pull request ref stay in step with GitHub through `orion ingest`, which refreshes the cards already on the canvas as well as importing from sources. It marks merged pull requests done and closed ones deferred, and sets whose move it is from drafts and reviews. This runs even in a canvas with no sources configured. Run `orion ingest --dry-run` first when unsure.

The refresh records your unplaced open pull requests and likely matching cards; inspect them with `orion source matches`. When the canvas has GitHub sources, only pull requests in their repositories count. Link one to an existing card with `orion card set <id> --ref <pull request URL>`.

When a card has a branch ref for the pull request's head branch in its repository, the refresh attaches the new pull request to that card and records it as its pull request. If more than one card has that branch, the pull request stays unplaced and `orion source matches` lists those cards. Record the branch when you start work (`orion card set <id> --ref branch:owner/name@branch`) so the refresh can attach the pull request you open.

A failing job that isn't required doesn't make a card read as failing when the pull request has required jobs. To set aside a job that fails for a reason that doesn't matter, such as stale generated docs, snooze it for every card in its repository: `orion ci snooze <job> --repo <owner/name> [--until <UTC time or date>]`. Without `--until`, the snooze lasts on each card until the job next passes there. `orion ci list [--json]` lists snoozed jobs, and `orion ci unsnooze <job> --repo <owner/name>` counts the job again.

## Sources and ingestion

Use `orion source list` to inspect configured GitHub, Jira, and hop sources, and `orion source add <kind>` to add one; each kind takes only its own options. Keep credentials in `gh` and `acli`, never in the source command.

A source's command lives in this machine's `commands.json`, never in the canvas's files, and no MCP tool takes one. Leave a Jira source's `--command` to the person: when ingest reports a Jira source with no command on this machine, tell them to run `orion source add jira --id <id> --command '[...]'` rather than choosing a command yourself.

Run `orion ingest --dry-run` before `orion ingest`. Ingestion files new cards in Unsorted, updates existing cards in place, and leaves cards that are no longer returned alone. Place cards into outcome groups after reviewing them.

Cards keep pull requests, issues, and local branches in `data.refs`. Each ref records its source, kind, key, URL, status, completion state, update time, and source-specific details. A ref's kind and its source's stable `id` identify it across ingests, so a ref keeps its card when what it names is renamed or moved. A ref with no `id` yet, such as one added offline, matches by its case-insensitive key until its source is read. The source's adapter reads its details into source-neutral facts on the ref, such as `stateLabel`, `readiness`, and `checks`, and the app shows those rather than reading the details.
