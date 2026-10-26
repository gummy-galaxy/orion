---
bump: patch
category: Agents
kind: fixed
---

On Windows, the `orion` CLI now notices when another Orion process is still running, so it waits for a write in progress instead of taking over its lock. CI now builds and tests the CLI and desktop app on macOS and Windows too.
