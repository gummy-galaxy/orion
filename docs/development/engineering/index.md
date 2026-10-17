# Engineering

Engineering pages cover how Orion is built: its architecture, its public interfaces, and proposals for changing them.

An audit or proposal is a snapshot. It recommends changes as of the day it was written, and once a change is settled, the call moves into the [decisions](/development/decisions). For what Orion accepts today, see the [CLI](/reference/cli/) and [MCP](/reference/mcp) reference.

## Threads

- [Architecture](/development/engineering/architecture): how the CLI, server, app, desktop shell, MCP server, and sources fit together.
- [Data and sync](/development/engineering/data-and-sync): one document per canvas under a shared lock, backups, merges, undo, and the move toward operations and files.
- [Performance](/development/engineering/performance): the 1,000-card target, the work that keeps the canvas responsive, and the perf harness that checks each pull request.
- [CLI and agents](/development/engineering/cli-and-agents): the CLI as the one implementation, its queries and batch edits, and the MCP server that wraps it.

## Timeline

Each date is when the pull request was opened. Pull requests still open are marked as in review.

### October 5, 2026

- [Rolling backups](https://github.com/vocksel/orion/pull/18) of the data file before each write, kept for a day and a month.
- [A Tauri desktop shell](https://github.com/vocksel/orion/pull/19) around the app, with a native window.
- [Three-way merge](https://github.com/vocksel/orion/pull/21) for saves that lose a race, instead of dropping the edit.
- [Workspaces with their own data folders](https://github.com/vocksel/orion/pull/23).
- [Ingest from GitHub, Jira, and hop](https://github.com/vocksel/orion/pull/24) through each source's command.
- [Animate less](https://github.com/vocksel/orion/pull/29), after WebKit's GPU process stayed near 40% CPU while idle.

### October 6, 2026

- [orion focus](https://github.com/vocksel/orion/pull/33) lets agents see the group and selection open in the app.
- [orion serve](https://github.com/vocksel/orion/pull/52) serves the app's data from the CLI and removes the app's own store.
- [The packaged desktop app](https://github.com/vocksel/orion/pull/53) runs the server as a bundled sidecar.

### October 7, 2026

- [StyLua in CI](https://github.com/vocksel/orion/pull/97) checks Luau formatting.
- [A debug bar](https://github.com/vocksel/orion/pull/107) shows frame timing and animation toggles.
- [Spelled-out names](https://github.com/vocksel/orion/pull/118) across the codebase.

### October 8, 2026

- [Redraw only what changes](https://github.com/vocksel/orion/pull/124), with per-card selectors.
- [Storybook and component stories](https://github.com/vocksel/orion/pull/128).
- [One React component per module](https://github.com/vocksel/orion/pull/127).
- [An MCP server](https://github.com/vocksel/orion/pull/134) built into the CLI binary.
- [Queries and batch edits](https://github.com/vocksel/orion/pull/140) in one transaction, with dry runs and revision checks.

### October 9, 2026

- [Refs on cards](https://github.com/vocksel/orion/pull/152), replacing the GitHub-specific card fields.
- [One card view model](https://github.com/vocksel/orion/pull/153) that every card skin renders from.
- [Source adapters](https://github.com/vocksel/orion/pull/155) behind ingest and sync.
- [Undo and redo](https://github.com/vocksel/orion/pull/166) for canvas edits.
- [A perf harness](https://github.com/vocksel/orion/pull/172) that compares a branch against main.
- [A skill for before and after screenshots](https://github.com/vocksel/orion/pull/151) on pull requests.

### October 10, 2026

- [CI on Linux](https://github.com/vocksel/orion/pull/180).
- [A perf comparison on each pull request](https://github.com/vocksel/orion/pull/181).
- [The desktop sidecar built by a Lute script](https://github.com/vocksel/orion/pull/183).
- [A platform matrix and CI uploads](https://github.com/vocksel/orion/pull/184).
- [The CLI packaged as a zip](https://github.com/vocksel/orion/pull/186) that Rokit and Foreman can install.
- [Perf noise judged by run-to-run spread](https://github.com/vocksel/orion/pull/193).
- [Orion's own window chrome](https://github.com/vocksel/orion/pull/198) in the desktop app.
- [System diagrams](https://github.com/vocksel/orion/pull/201) with components and labeled links, merged October 17.
- [Conventions and pitfalls](https://github.com/vocksel/orion/pull/206) written down for agents.
- [App preferences saved in the data folder](https://github.com/vocksel/orion/pull/210).

### October 11, 2026

- [CI on the self-hosted runner](https://github.com/vocksel/orion/pull/212).
- [Perf runs one at a time](https://github.com/vocksel/orion/pull/237).
- [A product charter](https://github.com/vocksel/orion/pull/238), and [file-backed canvases with a SQLite index](https://github.com/vocksel/orion/pull/246) planned in it.
- [Nested groups laid out deepest first](https://github.com/vocksel/orion/pull/247).
- [Source options split by kind](https://github.com/vocksel/orion/pull/251), and [new pull requests attached to the card their branch was recorded on](https://github.com/vocksel/orion/pull/260).
- [orion import](https://github.com/vocksel/orion/pull/261) adds cards for a list of refs in one step.
- [orion tidy and orion check](https://github.com/vocksel/orion/pull/262) for layout.
- [Scrolling always pans](https://github.com/vocksel/orion/pull/268), and the zoom-on-scroll setting goes.
- [Perf on exclusive cores](https://github.com/vocksel/orion/pull/273), and [draft pull requests skip perf](https://github.com/vocksel/orion/pull/274).
- [The desktop app keeps its server port](https://github.com/vocksel/orion/pull/282) across launches.
- [Settled decisions recorded](https://github.com/vocksel/orion/pull/283) in the decisions log.

### October 12, 2026

- [Perf compares against the merge commit's first parent](https://github.com/vocksel/orion/pull/290).
- [Where priority and size come from](https://github.com/vocksel/orion/pull/312) recorded in the decisions log.
- [Groups removed with their contents](https://github.com/vocksel/orion/pull/315).

### October 13, 2026

- [Ingest refreshes pull requests](https://github.com/vocksel/orion/pull/328), and `orion sync` is deprecated.
- [Finished cards stamped Done](https://github.com/vocksel/orion/pull/322) once they're closed out.
- [Interfaces tighten in stages](https://github.com/vocksel/orion/pull/325) before 0.1.0, recorded in the decisions log.
- [Noun-then-verb CLI commands](https://github.com/vocksel/orion/pull/346).
- [A VitePress docs site](https://github.com/vocksel/orion/pull/326) with a generated CLI and MCP reference.
- [Only the cards near the view draw](https://github.com/vocksel/orion/pull/345).
- [Compact cards at far zoom](https://github.com/vocksel/orion/pull/332).
- [Folded groups preview what they hold](https://github.com/vocksel/orion/pull/339).
- [Storybook published through Chromatic](https://github.com/vocksel/orion/pull/338), and [the build shown in --version](https://github.com/vocksel/orion/pull/337).
- [The desktop app installs to /Applications](https://github.com/vocksel/orion/pull/357) for every user.
- [A card's timeline from the canvas log](https://github.com/vocksel/orion/pull/356), merged October 17.
- [Canvas edits as operations, part one](https://github.com/vocksel/orion/pull/343) (in review).
- [MCP tools for every CLI option](https://github.com/vocksel/orion/pull/350), [apply a plan](https://github.com/vocksel/orion/pull/351), [the canvas log](https://github.com/vocksel/orion/pull/353), and [reveal](https://github.com/vocksel/orion/pull/354) (all in review).

### October 14, 2026

- [GitHub sync kept under GitHub's query time limit](https://github.com/vocksel/orion/pull/367).

### October 15, 2026

- [Store locks reclaimed](https://github.com/vocksel/orion/pull/371) only when their writer is gone.
- [App test coverage posted as a pull request comment](https://github.com/vocksel/orion/pull/372).
- [A mutation testing script](https://github.com/vocksel/orion/pull/375) for Luau modules.
- [Undo tested against random edits](https://github.com/vocksel/orion/pull/373) and [the store tested under concurrent writers](https://github.com/vocksel/orion/pull/374) (both in review).

### October 16, 2026

- [Desktop installer and app uploads only from main](https://github.com/vocksel/orion/pull/383).
- [Orion licensed under MIT](https://github.com/vocksel/orion/pull/387).

### October 17, 2026

- [The README restructured](https://github.com/vocksel/orion/pull/388), with its detail moved into the docs.
- [Lute scripts fail when they error after yielding](https://github.com/vocksel/orion/pull/389).
- [Workspaces renamed to canvases](https://github.com/vocksel/orion/pull/409) in data, routes, MCP, and docs, with an automatic folder migration.
- [orion_tidy and orion_check](https://github.com/vocksel/orion/pull/399) MCP tools.
- [Cards closed out at once](https://github.com/vocksel/orion/pull/407) when finished in the app.
- [MCP calls queued behind the canvas lock](https://github.com/vocksel/orion/pull/403) instead of failing.
- [Per-frame paint work cut](https://github.com/vocksel/orion/pull/394) (in review).
- [An audit of Orion's public interfaces](https://github.com/vocksel/orion/pull/408) (in review).
- [A Development section on the docs site](https://github.com/vocksel/orion/pull/418).
