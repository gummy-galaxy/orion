# Migrations

Each module here upgrades data written by an Orion from before 0.1.0. Everyone who installs 0.1.0 or later starts on the current layout, so none of them are needed once it ships.

**Delete this folder at the 0.1.0 release**, along with the calls to it in `store/getActiveWorkspace.luau` and `store/decodeDocObject.luau`, and the paragraph on older versions in `docs/guide/data.md`. Clear the alias entries in [`../aliases/`](../aliases/README.md) in the same step.

| Module | Added | What it upgrades | Called from |
| --- | --- | --- | --- |
| `migrateWorkspaces.luau` | 2026-10-17, [#409](https://github.com/vocksel/orion/pull/409) | Moves `workspaces.json` and `workspaces/<name>/` to `canvases.json` and `canvases/<name>/`. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |
| `migrateImageCanvas.luau` | 2026-10-20, [#550](https://github.com/vocksel/orion/pull/550) | Moves an image's `data.workspace` to `data.canvas`. | `store/decodeDocObject.luau`, when reading an image that still has `workspace` |
| `migrateCanvasFiles.luau` | 2026-10-18, [#486](https://github.com/vocksel/orion/pull/486) | Splits each canvas's `orion.json` into `canvas.json`, `nodes/`, `links/`, and `local.json`, keeping the original as `orion.backup.json`. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |
| `migrateItemKind.luau` | 2026-10-26, [#215](https://github.com/gummy-galaxy/orion/issues/215) | Moves a card's `data.itemKind` onto types: a kind a person chose becomes `data.type`, and each ref records the type it attaches. | `store/decodeDocObject.luau`, when reading every card |
| `migrateSourceCommands.luau` | 2026-10-19, [#554](https://github.com/vocksel/orion/pull/554) | Moves the commands sources kept in each canvas's `canvas.json` into the data folder's `commands.json`, once. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |

Add a row for each new migration, with the date and pull request that added it. A migration that moves or rewrites files calls `server/findOtherServer` first and refuses while it returns a server, since a server from another build keeps writing the layout it knows.
