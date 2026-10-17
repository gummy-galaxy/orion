# Public surfaces

These are the ways people, agents, and other tools reach Orion, and what each one promises.

::: warning Before 0.1.0
Orion hasn't had its first release. Until it does, any command, option, tool, or output shape here can be cut or renamed, and the old form goes away in the same change.
:::

| Surface                            | Who uses it        | Before 0.1.0                                                  |
| ---------------------------------- | ------------------ | ------------------------------------------------------------- |
| [CLI](/reference/cli/)             | People and agents  | None. Shapes are settling into a noun, then a verb.           |
| [MCP](/reference/mcp)              | Agents             | None. Tools run CLI commands and will follow the CLI's names. |
| `--json` output                    | Scripts and agents | None.                                                         |
| Data files                         | Orion itself       | None.                                                         |
| HTTP API from `orion server start` | The Orion app only | Internal at every stage. Other tools shouldn't call it.       |

## How the promises grow

- **Before 0.1.0:** anything can change, with no aliases or deprecation period.
- **From 0.1.0:** breaking changes still happen, but deliberately, and new commands, options, and tools have to show why they widen the surface.
- **From 1.0.0:** breaking changes ship with aliases first.

The CLI and MCP pages are generated from the code that defines them, so they always match what Orion accepts.
