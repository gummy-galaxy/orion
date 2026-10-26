---
bump: minor
category: Agents
kind: breaking
---

Card files store a card's kind as its type: `data.itemKind` becomes `data.type`, kept only for a kind someone chose, such as a gate, note, or component, and pull request and step cards take theirs from their refs. Canvases move over the first time this version opens them, and the next save keeps a backup. An older Orion then reads those cards as steps.
