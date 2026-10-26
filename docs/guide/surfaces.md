# Public surfaces

These are the ways people, agents, and other tools reach Orion, and what each one promises. New to the CLI? [The command line](./command-line) walks through it.

::: warning Before 0.1.0
Orion hasn't had its first release. Until it does, any command, option, tool, or output shape here can be cut or renamed. A renamed command or option keeps working under its old name, with a notice, until the next release.
:::

| Surface                            | Who uses it        | Before 0.1.0                                                |
| ---------------------------------- | ------------------ | ----------------------------------------------------------- |
| [CLI](/reference/cli/)             | People and agents  | None. Shapes are settling into a noun, then a verb.         |
| [MCP](/reference/mcp)              | Agents             | None. Each tool runs one CLI command and is named after it. |
| [`--json` output](#json-output)    | Scripts and agents | None until 1.0.0.                                           |
| Data files                         | Orion itself       | None.                                                       |
| [Theme tokens](/guide/tokens)      | Theme files        | Names are a contract. Renamed tokens keep an alias.         |
| HTTP API from `orion server start` | The Orion app only | Internal at every stage. Other tools shouldn't call it.     |

## JSON output

Every command takes `--json`. Under it:

- A failure prints `{"error": {"code": …, "message": …}}` on stdout and exits 1. Without `--json`, it prints `Error: …` on stderr instead, so stdout only holds output.
- A failure a script can act on has a `code`: `revision-conflict` when `--if-revision` no longer matches, `missing-item` when an id or selector matches nothing, and `ambiguous-selector` when a selector matches more than one item. Other failures leave it out. An MCP tool's error text is the same JSON error.
- A write prints the `revision` it made, to pass to the next command's `--if-revision`. A command that changes one item prints `{"revision": …, "item": …}`.
- Cards, notes, and groups each have a shape of their own, and a group prints what `orion group list` does.
- Times use RFC 3339, such as `2026-10-17T16:46:00Z`.
- An absent value is `null` or a missing field, never an empty string.

No shape is promised before 1.0.0. From 0.1.0, a change to one is deliberate and listed in the release notes.

## How the promises grow

- **Before 0.1.0:** anything can change, with no deprecation period. A renamed command, option, or theme token keeps its old name as an alias until the next release.
- **From 0.1.0:** breaking changes still happen, but deliberately, and new commands, options, and tools have to show why they widen the surface.
- **From 1.0.0:** breaking changes ship with aliases first.

The CLI and MCP pages are generated from the code that defines them, and the [query](/reference/query), [selector](/reference/selectors), and [ref](/reference/refs) pages from the code that parses them, so they always match what Orion accepts.

The [interface audit](/development/engineering/interface-audit) lists what is expected to change on each surface before 0.1.0.
