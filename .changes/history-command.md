---
bump: minor
category: Agents
kind: new
highlight: Jump between a canvas's revisions
---

`orion history list` shows a canvas's recent revisions and whether a command, an MCP tool, or the app made each, and `orion history set <revision>` jumps the canvas back or forward to one, with `--dry-run` to preview. The newest 200 revisions are kept, plus one a day for 30 days. `orion backup list` and `orion backup restore` still work until the next release.
