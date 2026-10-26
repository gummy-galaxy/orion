---
bump: patch
category: Agents
kind: improved
---

A failed command now prints its `Error:` line on stderr, so output redirected to a file holds only output. Under `--json`, the error carries a `code` such as `revision-conflict`, `missing-item`, or `ambiguous-selector`, so a script can retry a stale `--if-revision` without matching the message, and MCP tool errors include the same code.
