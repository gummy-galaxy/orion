---
bump: minor
category: Agents
kind: breaking
---

Card files keep a card's kind only when someone chose it, such as a gate, note, or component. Pull request, placeholder, and step cards take their kind from their refs and repository. Canvases move over the first time this version opens them, and the next save keeps a backup. An older Orion then reads those cards as steps.
