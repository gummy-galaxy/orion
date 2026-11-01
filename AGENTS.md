# Orion agent guide

Orion is a canvas of work items, notes, and groups linked by dependencies. Use the `orion` CLI to read and change it. Never edit a canvas's files directly: the Luau CLI owns the data and its lock. The app talks to `orion server start` over HTTP and WebSocket and picks up every change while it's open.

[The charter](docs/development/charter.md) sets Orion's direction: its principles, what it won't do, and the roadmap. Check new work against it, and call out a change that conflicts with it.

[The decisions log](docs/development/decisions.md) records the specific calls made along the way and why. They're defaults that can be challenged, and the charter outranks them. Follow them, raise a change that goes against one rather than working around it, and add or rewrite an entry when the person settles a new call.

## Topics

The guides below hold the rest of the rules, one topic per file, so changes to different topics don't collide. Each `@` line imports its file; if your tool doesn't follow imports, read the files for the work at hand. Keep the list sorted, and put a new topic in its own file.

- @agents/canvas.md: reading and changing the canvas with the CLI, and what the person is looking at.
- @agents/changelog.md: when a change needs a `.changes/` entry, and how to choose its fields and word it.
- @agents/code-style.md: naming, modules, components, and logging, in both languages.
- @agents/desktop-build.md: building the desktop app and installing it for someone to try.
- @agents/dev-data.md: the scratch data folder dev servers use, and keeping branch builds off the real one.
- @agents/docs.md: the docs site and its generated reference.
- @agents/issues.md: filing and writing issues, and tracking their progress.
- @agents/luau-style.md: Luau modules and spacing.
- @agents/pull-requests.md: screenshots, perf reports, closing issues, and placing pull requests on the canvas.
- @agents/sources.md: sources, ingestion, and keeping pull request cards current.
- @agents/system-diagrams.md: drawing systems with components and labeled links.
- @agents/typescript-style.md: the app's TypeScript modules and tests.
- @agents/workflows.md: GitHub Actions workflows and required checks.
