# Migrations

Each module here upgrades data written by an Orion from before 0.1.0. Everyone who installs 0.1.0 or later starts on the current layout, so none of them are needed once it ships.

**Delete this folder at the 0.1.0 release**, along with the calls to it in `store/decodeDocObject.luau` and `store/getActiveWorkspace.luau`, the `version < 2` and legacy-field checks around `migrateItem`, and the paragraph on older versions in `docs/guide/data.md`.

| Module | Added | What it upgrades | Called from |
| --- | --- | --- | --- |
| `migrateItem.luau` | 2026-10-09, [#152](https://github.com/vocksel/orion/pull/152) | Moves a card's `repo`, `pr`, `issue`, `branch`, `host`, `github`, `external`, `activity`, and `sources` fields onto its list of refs. | `store/decodeDoc.luau`, when reading a document below version 2 or a card that still has one of those fields |
| `migrateWorkspaces.luau` | 2026-10-17, [#409](https://github.com/vocksel/orion/pull/409) | Moves `workspaces.json` and `workspaces/<name>/` to `canvases.json` and `canvases/<name>/`. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |
| `migrateCanvasFiles.luau` | 2026-10-18, #475 | Splits each canvas's `orion.json` into `canvas.json`, `nodes/`, `links/`, and `local.json`, keeping the original as `orion.backup.json`. | `store/getActiveWorkspace.luau`, before every command resolves its canvas |

Add a row for each new migration, with the date and pull request that added it.
