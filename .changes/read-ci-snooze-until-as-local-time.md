---
bump: patch
category: Agents
kind: fixed
---

`orion ci snooze --until` used to read a date as the start of that day in UTC and turn down times without a `Z`, so it disagreed with `orion card snooze` given the same value. It now reads dates and times as local unless they carry an offset, the same way `orion card snooze` does.
