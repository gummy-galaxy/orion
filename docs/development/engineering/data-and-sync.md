# Data and sync

A canvas is a folder of JSON files. The CLI and the server write it under a shared lock, and every write produces a new revision. Around that core are backups, a merge for saves that lose a race, undo in the app, and a plan to read through a SQLite index.

## A folder of files per canvas, under a lock

Each canvas has its own folder ([#475](https://github.com/vocksel/orion/issues/475)). `canvas.json` holds its settings, its revision, and the order of its nodes and links. Each node is `nodes/<id>.json` and each link is `links/<id>.json`, so editing a link never rewrites a node file. Keys are sorted and formatting is stable. An id keeps lowercase letters, digits, hyphens, and underscores in its file name and escapes every other byte as `%` and two hex digits, uppercase letters included, so ids that differ only in case don't share a file on a case-insensitive disk.

Fields that record one machine's view of the canvas, the GitHub refresh's records and the stored suggestions, go in `local.json` instead. The lock, backups, focus report, and log sit beside the files for now, so a canvas can still be copied or backed up as a unit.

A write splits the whole canvas into files and rewrites only those whose text changed, removes node and link files the canvas no longer has, and replaces `canvas.json` last. Each file is written to a temporary file and moved into place. While a write runs, an `orion.writing` marker sits in the folder. A reader that sees the marker, or finds `canvas.json` changed by the time it finishes, reads again, so it never returns a write half done. A marker left by a writer that crashed doesn't hold readers up once its lock is gone. The server's watcher looks at `canvas.json`, since a change to it marks a finished write.

The first command a newer Orion runs splits every canvas's `orion.json` into files, keeping the original as `orion.backup.json`. It refuses while an older `orion server start` still serves the folder, since that server would keep writing `orion.json`; a server that reads folders says so in its `serve.json`.

Every writer takes the same lock. The lock is an `orion.lock` directory, created with `mkdir`, which either succeeds for one process or fails for the rest. A writer waits up to 5 seconds for it. Writes of view state skip the lock. The app's report of its open group and selection never changes the revision ([#33](https://github.com/vocksel/orion/pull/33)).

A lock can outlive its writer if the writer crashes. [Reclaiming those locks](https://github.com/vocksel/orion/pull/371) depends on whether the writer is still running, not only on the lock's age:

- A lock with no readable owner stamp uses the lock directory's modified time in its place.
- A stale lock is reclaimed once its owner process is gone, or when no owner process is recorded. After ten minutes it is reclaimed even if its process is still running, in case the process id was reused.

Before this change, any lock older than 30 seconds was reclaimed, even while its writer was still running. A second writer could then overwrite the first one's result.

Callers that read a revision can refuse a write when the document has moved on. `--if-revision` does this for the batch commands, and the same check is what lets an agent preview a change and then apply it safely ([CLI and agents](/development/engineering/cli-and-agents)).

## Rolling backups

Before a write, the writer saves the whole canvas it replaces as one JSON file in the canvas's `backups` folder, named with the revision it replaces and a UTC timestamp. Backups are kept for the last 24 hours, plus the newest backup from each UTC day for 30 days. Pruning only removes files that match that name pattern. A backup that fails doesn't stop the write.

`orion backup list` shows the saved revisions, newest first. `orion backup restore <revision>` brings one back as a new revision, after backing up the current file first ([#18](https://github.com/vocksel/orion/pull/18)). A restore is never destructive, so a mistaken restore can be undone the same way.

## Merging saves that lost a race

When the app's save is rejected because another writer saved first, the app no longer drops its edit. It fetches the newer file, merges its own changes onto it, and saves again, up to two retries ([#21](https://github.com/vocksel/orion/pull/21)). The same merge runs when another writer's change arrives while the app has an unsaved edit.

The merge is three-way. It compares the last copy known to match the file, the app's current state, and the newer file:

- Nodes and links match by id. Additions from either side are kept.
- A deletion wins only if the other side didn't edit the item.
- Position, parent, size, and each data field merge separately.
- If both sides changed the same field, the app's value wins, and a short notice says how many fields that touched.
- Links whose ends no longer exist are dropped.

## Workspaces became canvases

A workspace started as its own data folder ([#23](https://github.com/vocksel/orion/pull/23)). The CLI renamed the commands to `canvas` in [#346](https://github.com/vocksel/orion/pull/346), and [#409](https://github.com/vocksel/orion/pull/409) renamed the data, routes, and MCP tools to match.

The data folder now lists canvases in `canvases.json`, which also records the active one. Canvas folders live under `canvases/<name>/`. The first command a newer Orion runs moves an older layout into place:

- Folders move whole, so each canvas keeps its data and backups.
- The old list stays beside the new one as `workspaces.backup.json`.
- A move that stops partway picks up where it left off.
- The move refuses while an older `orion server start` is still serving the folder.

The migrations live in `cli/src/migrations/`, and that folder's README dates each one. They're removed at the 0.1.0 release, since nobody installing that release has an older folder. The [decisions](/development/decisions) explain why data moves on its own instead of by hand.

## Refs and document version 2

Cards used to carry source-specific fields such as `pr`, `branch`, and `external`. [Version 2 of the document](https://github.com/vocksel/orion/pull/152) replaces them with `data.refs`, a list of refs that each record their source, kind, key, URL, status, and source-specific details. A ref's kind and case-insensitive key identify it across ingests. Older documents migrate when they are read, so nothing needs a manual step.

## Undo and redo

The app records undo steps in memory ([#166](https://github.com/vocksel/orion/pull/166)). A step is recorded once the document has been still for 300 milliseconds, so a drag, a tidy's animation, or a burst of typing counts as one step. Nothing is recorded while a card is being dragged.

Undo doesn't restore a copy of the old document. It merges the step's inverse onto the current one. Writes from the CLI, a sync, or another window stay in place, and where one of them touched the same field as the step, its value wins. History holds the last 100 steps and starts over when the canvas changes. The [decisions](/development/decisions) say undo history should survive a canvas switch, which this version doesn't do yet.

## Edits as operations

Each canvas edit is becoming one operation with an inverse ([charter](/development/charter), principle 8). [Part one](https://github.com/vocksel/orion/pull/343) is in review. It adds `cli/src/operations/`, where a list of operations applies in order under the lock. If one no longer applies, the earlier ones are undone and the whole list is refused, with the failing position named. Each operation returns the nodes and links it changed as they were before, so applying those inverses in reverse restores the document exactly. Nothing stores those inverses yet. Storing them is the next step.

The operations go out through `POST /api/operations`. A list lands as one revision. An optional base revision must still match, and a refused list or a stale base leaves the file's bytes alone.

[Part two](https://github.com/vocksel/orion/pull/355), also in review, changes the app to send each committed edit to that endpoint instead of saving the whole document. The plan then removes the whole-document save and the app's merge, once the operations path covers every edit.

## Store hardening

Several changes exist to protect the data:

- Concurrent writers are tested. A [spec](https://github.com/vocksel/orion/pull/374), in review, starts six `orion add` processes at once and checks that every card lands and the final revision is right. It also checks that an unreadable or truncated data file is left byte for byte unchanged. Creating a fresh data folder had a race that lost one writer, and the same change fixes it.
- Undo is tested against random edits. A [property test](https://github.com/vocksel/orion/pull/373), in review, checks that undo and redo never leave dangling links or duplicate ids, even when another writer changed the document in between.
- A [mutation testing script](https://github.com/vocksel/orion/pull/375) for Luau modules checks whether the specs catch deliberate changes to the code.

## Where it's headed

The charter's first phase has a storage bet: a canvas becomes a folder of text files that can live in a repository, like an Obsidian vault, and SQLite becomes a rebuildable index for reads ([#246](https://github.com/vocksel/orion/pull/246), [#121](https://github.com/vocksel/orion/issues/121)). The files came first. The index, a journal for writes that touch several files, re-indexing after a `git pull`, and merge-friendly ids and ordering follow. The decision keeps simple read and write commands in the CLI and keeps one `sqlite3` process open in the server. Files stay easy to inspect and diff, and the index keeps large canvases fast.
