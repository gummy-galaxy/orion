---
bump: patch
category: Agents
kind: fixed
---

Orion processes writing to the same canvas now take turns in the order they arrived, and a writer waits as long as the line keeps moving, so a busy canvas no longer makes a write fail with "timed out waiting". On Windows, the `orion` CLI also reads its canvas index correctly, and it notices when another Orion process is still running instead of taking over its lock.
