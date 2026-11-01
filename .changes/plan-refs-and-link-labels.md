---
bump: minor
category: Agents
kind: new
---

Plans for `orion apply` can attach and take off a card's refs with `attachRef` and `detachRef`, and label links, so moving a pull request between cards and rewiring its links lands in one write. A plan's output, `--dry-run` included, now lists every item, link, and ref it changes.
