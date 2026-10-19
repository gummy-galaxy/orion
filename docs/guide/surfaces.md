# Public surfaces

These are the ways people, agents, and other tools reach Orion, and what each one promises.

::: warning Before 0.1.0
Orion hasn't had its first release. Until it does, any command, option, tool, or output shape here can be cut or renamed, and the old form goes away in the same change.
:::

| Surface                            | Who uses it        | Before 0.1.0                                                |
| ---------------------------------- | ------------------ | ----------------------------------------------------------- |
| [CLI](/reference/cli/)             | People and agents  | None. Shapes are settling into a noun, then a verb.         |
| [MCP](/reference/mcp)              | Agents             | None. Each tool runs one CLI command and is named after it. |
| `--json` output                    | Scripts and agents | None.                                                       |
| Data files                         | Orion itself       | None.                                                       |
| [Theme tokens](/guide/tokens)      | Theme files        | Names are a contract. Renamed tokens keep an alias.         |
| HTTP API from `orion server start` | The Orion app only | Internal at every stage. Other tools shouldn't call it.     |

## How the promises grow

- **Before 0.1.0:** anything can change, with no aliases or deprecation period. Theme token names are the exception: a renamed one keeps its old name as an alias.
- **From 0.1.0:** breaking changes still happen, but deliberately, and new commands, options, and tools have to show why they widen the surface.
- **From 1.0.0:** breaking changes ship with aliases first.

The CLI and MCP pages are generated from the code that defines them, so they always match what Orion accepts.
