# Migrations

Each module here upgrades data written by an Orion from before 0.1.0. Everyone who installs 0.1.0 or later starts on the current layout, so none of them are needed once it ships.

**Delete this folder at the 0.1.0 release**, along with the call to it in `store/getActiveWorkspace.luau` and the paragraph on older versions in `docs/guide/data.md`. Clear the alias entries in [`../aliases/`](../aliases/README.md) in the same step.

| Module | Added | What it upgrades | Called from |
| --- | --- | --- | --- |
| `migrateWorkspaces.luau` | 2026-10-17, [#409](https://github.com/vocksel/orion/pull/409) | Moves `workspaces.json` and `workspaces/<name>/` to `canvases.json` and `canvases/<name>/`. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |
| `migrateCanvasFiles.luau` | 2026-10-18, [#486](https://github.com/vocksel/orion/pull/486) | Splits each canvas's `orion.json` into `canvas.json`, `nodes/`, `links/`, and `local.json`, keeping the original as `orion.backup.json`. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |

Add a row for each new migration, with the date and pull request that added it. A migration that moves or rewrites files calls `server/findOtherServer` first and refuses while it returns a server, since a server from another build keeps writing the layout it knows.
