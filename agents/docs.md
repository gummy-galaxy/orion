# Docs

The docs site in `docs/` shows Orion's public surfaces. Its CLI and MCP reference pages are generated from the command table and the MCP tool catalog. After changing a command, an option, or an MCP tool, run `lute run generate docs` from the repository root and commit the pages it writes; CI fails when they're out of date. It formats them with the docs site's Prettier, so run `npm ci` in `docs/` first. Write the guide pages by hand, for someone who has never used Orion.

The generator owns every page in `docs/reference/` and removes any it didn't write, so hand-written pages go elsewhere. Pages about how Orion is made, such as audits, proposals, and studies, go in `docs/development/design/` or `docs/development/engineering/`, with an entry in that section's sidebar in `docs/.vitepress/config.mts`. Write them for a contributor who wasn't in the conversation that produced them.

Keep catalog lists sorted, such as the threads on a section's index page and their sidebar entries, and add a new entry in its place rather than at the end. Lists with a reading order, such as the guide's sidebar, or a date order, such as a timeline, keep that order.
