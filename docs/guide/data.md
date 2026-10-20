# Data and canvases

Orion keeps everything in plain files on your machine. The CLI owns them: the app and agents go through it, and it locks every write, so the app and any number of commands can run at once.

## Where data lives

| Platform | Data folder                                                  |
| -------- | ------------------------------------------------------------ |
| macOS    | `~/Library/Application Support/Orion`                        |
| Windows  | `%APPDATA%\Orion`                                            |
| Linux    | `$XDG_DATA_HOME/orion`, or `~/.local/share/orion` without it |

Set `ORION_DATA_DIR` to use another folder on any platform. It takes precedence over `XDG_DATA_HOME` and `APPDATA`, and a relative path resolves from the current folder. The app's preferences, such as the theme and keyboard shortcuts, live in its `settings.json` and apply to every canvas.

## Canvases

The `default` canvas lives in the data folder itself. Every other canvas has its own folder under `canvases/<name>/`, and `canvases.json` records their names, labels, which one is active, and which are archived. Canvas names use lowercase letters, digits, and hyphens.

A canvas is a folder of small JSON files:

- `canvas.json` holds its settings.
- `nodes/<id>.json` holds each card, note, group, and image, with its place in the canvas's order and when each of its fields last changed.
- `links/<id>.json` holds each link.
- `local.json` holds what this machine recorded about it, such as its revision and the last GitHub check.

Keys are sorted and formatting is stable, so a change rewrites only the files it touches. New cards and links get random ids, so two copies of a canvas in git that each add or edit different cards merge without a conflict. Keep `local.json` and `index.sqlite` out of git, since they change on every write. Change the files through the CLI rather than by hand.

Orion reads a canvas through `index.sqlite` beside its files, which it builds from them with the `sqlite3` command and keeps up to date. It holds nothing the files don't, so deleting it is safe. Without `sqlite3` installed, Orion reads every file instead, which is slower on large canvases.

Older versions of Orion kept each canvas in one `orion.json`. The first command a newer Orion runs splits it into files and keeps the original beside them as `orion.backup.json`.

Older versions of Orion called canvases workspaces and kept them in `workspaces/` and `workspaces.json`. The first command a newer Orion runs moves them into place and keeps the old list as `workspaces.backup.json`. Quit an older Orion that is still open first, since it would keep writing to the old folders.

Data files from Orion's first weeks, saved as data version 1, aren't read anymore, and commands on one stop with a message saying so. To upgrade one, make a single change to it with an Orion built from commit `40320db6` or earlier, such as moving a card, which saves it as version 2.

```sh
orion canvas list
orion canvas create --label "Focus areas"   # named focus-areas
orion canvas use focus-areas
```

Rename changes only a canvas's label. Archive takes a canvas off the list and keeps its folder, so `orion canvas restore` brings it back. The active canvas and `default` can't be archived. The app's sidebar can also create and switch canvases.

Commands use the active canvas. Pass `--canvas <name>`, or set `ORION_CANVAS`, to use another without switching; the option wins over the variable.

## Images

Images are canvas nodes, with their files in the canvas's `assets/` folder. Use **Add image** in the app, or:

```sh
orion media insert ./concept.png --label "Concept"
```

Orion accepts PNG, JPEG, GIF, and WebP images up to 5 MB.

## Backups

Before every write, Orion saves the whole canvas as one file in its `backups/` folder. It keeps every backup from the last day and the newest from each of the last 30 days.

```sh
orion backup list
orion backup restore <revision>
```

Restoring brings a backup back as a new revision, and backs up the current canvas first.

## The server

`orion server start` serves the app's data over HTTP and sends changes over WebSocket. The desktop app runs it for you. Its API is internal to the app; other tools should use the CLI or [MCP](./getting-started#connect-an-agent-over-mcp).

While the app is open, it reports its open group and selection to the server, and `orion focus` prints that report. Agents use it to know what "this" means. `orion reveal <id…>` works the other way: it selects cards or groups in the open app and zooms the canvas to them, opening the innermost group that holds them all. With no app running, it opens the installed app on the same data folder first.
