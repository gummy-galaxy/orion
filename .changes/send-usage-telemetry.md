---
bump: minor
category: Desktop app
kind: new
---

When you've chosen to share anonymous usage data, Orion now sends it. Events wait in a small queue in Orion's data folder and go out about once a minute while the app is open, and a batch that can't be sent is dropped. Nothing is sent from a machine that hasn't opted in or that sets `DO_NOT_TRACK=1` or `ORION_TELEMETRY=0`.
