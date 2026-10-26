---
bump: patch
category: Agents
kind: fixed
---

On Windows, the `orion` CLI now reads its canvas index, and notices when another Orion process is still running so it waits for that write instead of taking over its lock. CI now builds and tests the CLI and desktop app on macOS and Windows too.
