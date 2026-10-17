# Data and canvases

Orion keeps everything in plain files on your machine. The CLI owns them: the app and agents go through it, and it locks every write, so the app and any number of commands can run at once.

## Where data lives

| Platform | Data folder                                                  |
| -------- | ------------------------------------------------------------ |
| macOS    | `~/Library/Application Support/Orion`                        |
| Windows  | `%APPDATA%\Orion`                                            |
| Linux    | `$XDG_DATA_HOME/orion`, or `~/.local/share/orion` without it |

Set `ORION_DATA_DIR` to use another folder. The app's preferences, such as the theme and keyboard shortcuts, live in its `settings.json` and apply to every canvas.

## Canvases

The `default` canvas is `orion.json` in the data folder. Every other canvas has its own folder under `canvases/<name>/`, and `canvases.json` records their names, labels, which one is active, and which are archived. Canvas names use lowercase letters, digits, and hyphens.

Older versions of Orion called canvases workspaces and kept them in `workspaces/` and `workspaces.json`. The first command a newer Orion runs moves them into place and keeps the old list as `workspaces.backup.json`. Quit an older Orion that is still open first, since it would keep writing to the old folders.

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

Before every write, Orion copies the current file to the canvas's `backups/` folder. It keeps every backup from the last day and the newest from each of the last 30 days.

```sh
orion backup list
orion backup restore <revision>
```

Restoring brings a backup back as a new revision, and backs up the current file first.

## The server

`orion server start` serves the app's data over HTTP and sends changes over WebSocket. The desktop app runs it for you. Its API is internal to the app; other tools should use the CLI or [MCP](./getting-started#connect-an-agent-over-mcp).

While the app is open, it reports its open group and selection to the server, and `orion focus` prints that report. Agents use it to know what "this" means.
