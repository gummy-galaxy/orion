# Public surfaces

These are the ways people, agents, and other tools reach Orion, and what each one promises.

::: warning Before 0.1.0
Orion hasn't had its first release. Until it does, any command, option, tool, or output shape here can be cut or renamed, and the old form goes away in the same change.
:::

| Surface                            | Who uses it        | Before 0.1.0                                                |
| ---------------------------------- | ------------------ | ----------------------------------------------------------- |
| [CLI](/reference/cli/)             | People and agents  | None. Shapes are settling into a noun, then a verb.         |
| [MCP](/reference/mcp)              | Agents             | None. Each tool runs one CLI command and is named after it. |
| [`--json` output](#json-output)    | Scripts and agents | None. A short list becomes stable at 0.1.0.                 |
| Data files                         | Orion itself       | None.                                                       |
| [Theme tokens](/guide/tokens)      | Theme files        | Names are a contract. Renamed tokens keep an alias.         |
| HTTP API from `orion server start` | The Orion app only | Internal at every stage. Other tools shouldn't call it.     |

## JSON output

Every command takes `--json`. Under it:

- A failure prints `{"error": {"message": …}}` and exits nonzero.
- A write prints the `revision` it made, to pass to the next command's `--if-revision`. A command that changes one item prints `{"revision": …, "item": …}`.
- Cards, notes, and groups each have a shape of their own, and a group prints what `orion group list` does.
- Times use RFC 3339, such as `2026-10-17T16:46:00Z`.
- An absent value is `null` or a missing field, never an empty string.

From 0.1.0, these shapes are stable: the item shape that `card list`, `node show`, `node query`, and `next` print, the batch write envelope, `canvas check`'s list, `focus`, and `canvas list`. New fields may appear in them, and removing or renaming one is a breaking change. The rest stay unpromised.

## How the promises grow

- **Before 0.1.0:** anything can change, with no aliases or deprecation period. Theme token names are the exception: a renamed one keeps its old name as an alias.
- **From 0.1.0:** breaking changes still happen, but deliberately, and new commands, options, and tools have to show why they widen the surface.
- **From 1.0.0:** breaking changes ship with aliases first.

The CLI and MCP pages are generated from the code that defines them, so they always match what Orion accepts.

The [interface audit](/development/engineering/interface-audit) lists what is expected to change on each surface before 0.1.0.
