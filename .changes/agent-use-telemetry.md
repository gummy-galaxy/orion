---
bump: minor
category: Agents
kind: new
---

When you share anonymous usage data, each `orion` command and MCP tool call now records its name, the names of the flags it was given, how long it took, and whether it failed, never its arguments or values. Commands also note whether a terminal was attached, so commands people type can be told apart from ones agents run.
