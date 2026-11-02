---
bump: minor
category: Cards
kind: new
---

Card types can now declare their own states, such as a design moving from Drafting to Approved, each with a meaning like done or blocked that blocking and progress follow. The details panel offers a card's own states, `orion card set <id> --status` takes them, and marking a card done records whichever state its type means as done.
