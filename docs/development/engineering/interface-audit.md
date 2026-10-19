# Interface audit

This audit lists what stays, what changes, and what goes on each of Orion's public surfaces before the first release. It's a snapshot of `main` on 2026-10-18, written for [#146](https://github.com/vocksel/orion/issues/146). The answers to its four questions are settled and recorded in the [decisions](/development/decisions). [Public surfaces](/guide/surfaces) says what each surface promises today.

Each list uses three marks:

- **Keep:** stays as it is.
- **Change:** stays, in a different shape.
- **Remove:** goes, with no alias, as the three-stage decision asks before 0.1.0.

Each change links to the issue that carries it.

## Since the snapshot

Some of the changes below have landed. The lists still describe `main` as it was on 2026-10-18.

- [#485](https://github.com/vocksel/orion/pull/485) builds the MCP tools from the CLI's command table, named after their commands, which settles [#415](https://github.com/vocksel/orion/issues/415). `orion_inspect` and `orion_sync` are gone.
- [#525](https://github.com/vocksel/orion/pull/525) refuses HTTP requests from other sites and drops the image routes from the agent guide, which settles [#468](https://github.com/vocksel/orion/issues/468).
- [#486](https://github.com/vocksel/orion/pull/486) and [#533](https://github.com/vocksel/orion/pull/533) store each canvas as a folder of node and link files read through a SQLite index, for [#121](https://github.com/vocksel/orion/issues/121). `orion.json` becomes `canvas.json`, so the [data files](#data-files) table no longer matches.

## The four questions

### Should the MCP tools follow the CLI structure?

**Yes.** Each CLI command gets one tool, named `orion_<noun>_<verb>` after it, with arguments named after its options in camelCase. Top-level commands keep one word: `orion_next`, `orion_focus`, `orion_ingest`, `orion_apply`, and `orion_reveal`. [#415](https://github.com/vocksel/orion/issues/415) builds the tool catalog from the CLI's command table and derives the names from it, so they can't drift.

- Agents learn one vocabulary. The MCP reference already says which command each tool runs, so a name that matches makes that mapping obvious.
- Today's names mix three patterns: verb first, such as `orion_add_item` and `orion_create_group`; noun first, such as `orion_log_add` and `orion_card_timeline`; and bare verbs, such as `orion_find` and `orion_tidy`. Each new tool makes a later rename larger.
- The cost is more tools, about 55. Every tool is small and has its own schema, which is what lets a client check a call before it runs. One tool per noun with a `verb` argument, like today's `orion_inspect`, would give less precise schemas for a smaller count.

### Is the HTTP API internal?

**Yes, and the server enforces it.** The API that `orion server start` serves is internal to the app at every stage. Today, though, any web page open in a browser on the same machine can call it:

- `POST` routes parse the body as JSON whatever its content type, so a page can send a cross-site `text/plain` request that needs no CORS preflight. `POST /api/merge` merges a pull request through `gh` given its URL and head commit, which are public for a public repository. `POST /api/canvases`, `POST /api/settings`, and `POST /api/operations` change data the same way.
- The server answers any `Host` header, so a DNS-rebinding page can read `GET /api/orion`.
- `/api/events` accepts a WebSocket from any origin.

[#468](https://github.com/vocksel/orion/issues/468) checks `Host` and `Origin` against the server's own address and the app's dev server, which closes all three. A token handed to the app at launch would also stop other local processes, and is worth adding only if the check alone proves too loose.

### Which JSON shapes are stable?

**None before 0.1.0, as [Public surfaces](/guide/surfaces) says, then a short named list.** From 0.1.0, these shapes are promised: new fields may appear, and removing or renaming a field is a breaking change.

- The item shape that `card list`, `node show`, `node query`, and `next` print: `id`, `label`, `kind`, `status`, `recordedStatus`, `group`, `groupLabel`, `waitsOn`, `leadsTo`, `unblocks`, and refs.
- The write envelope that batch commands print: `dryRun`, `revision`, `baseRevision`, `action`, and `items`.
- `canvas check`'s `{kind, ids, bounds}` list, `focus`, and `canvas list`.

Everything else stays unpromised until a script needs it, including `suggestion list`, `source matches`, `server status`, and the `ingest` report. The inconsistencies under [JSON output](#json-output) get fixed first, in [#470](https://github.com/vocksel/orion/issues/470), since each fix breaks the shape it touches.

Data files are never a public interface for writing: tools go through the CLI. They carry a `version`, and the CLI migrates older versions as it reads them. The charter's data layer promise applies to them from 1.0.

### How do breaking changes ship?

**In the three stages the [decisions](/development/decisions) already set.** Before 0.1.0, a breaking change lands in one pull request that updates the CLI, the MCP tools, the generated reference, the agent guide, and the app together, with no alias. From 0.1.0, each break is deliberate and the release notes list it. From 1.0, aliases come first.

Three deprecated forms predate that decision and still promise a release of overlap: `orion sync`, `--pr`, and `--repo` used with `--pr`. They go now, with no alias, in [#469](https://github.com/vocksel/orion/issues/469).

## CLI

|            |                                                                                                                                                                                                                                                                                                                   |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | The noun-verb shape and its nouns: `card`, `note`, `link`, `node`, `group`, `ref`, `canvas`, `source`, `media`, `suggestion`, `theme`, `backup`, `log`, `ci`, `server`, and `mcp`.                                                                                                                                |
| **Keep**   | Top-level `next`, `focus`, `ingest`, `apply`, `reveal`, and `help`. `apply` and `reveal` span every noun, and `help` comes from the same command table as `--help`, so it costs nothing to keep.                                                                                                                  |
| **Keep**   | `--where`, `--dry-run`, `--if-revision`, and `--json` on batch commands, and selectors wherever a command takes an id.                                                                                                                                                                                            |
| **Keep**   | `--canvas`, `--help`, and `--version` on every command.                                                                                                                                                                                                                                                           |
| **Keep**   | `ORION_DATA_DIR` and `ORION_CANVAS`, with the option winning over the variable.                                                                                                                                                                                                                                   |
| **Change** | Every command takes `--json` ([#470](https://github.com/vocksel/orion/issues/470)). These don't yet: `canvas create`, `rename`, `archive`, `restore`, `use`, `current`, and `path`, `link remove`, `backup restore`, `suggestion apply` and `dismiss`, `source add` and `remove`, and `ci snooze` and `unsnooze`. |
| **Change** | With `--json`, a failure prints a JSON error and still exits nonzero ([#470](https://github.com/vocksel/orion/issues/470)). Today errors are text on stderr only.                                                                                                                                                 |
| **Change** | Single-item writes take `--dry-run` and `--if-revision`: `card add` and `set`, `note add`, `group add`, `create`, and `set`, `link remove`, `ref remove`, `media insert`, and `canvas set`.                                                                                                                       |
| **Change** | `suggestion find --agent claude\|codex` runs those two tools by name, which is the per-provider code that "MCP stays generic" avoids. It takes a `--command '<JSON array>'` as `source add jira` and `hop` do ([#471](https://github.com/vocksel/orion/issues/471)).                                              |
| **Change** | One verb for making groups. `group create` makes an empty group and `group add` wraps items; fold them into `group create <label> [--items …] [--in …]`.                                                                                                                                                          |
| **Remove** | `orion sync` and `--discover` ([#469](https://github.com/vocksel/orion/issues/469)). `orion ingest` refreshes pull requests too, and a GitHub source files new ones in Unsorted.                                                                                                                                  |
| **Remove** | `--pr` on `card add` and `set`, and `--repo` as its partner ([#469](https://github.com/vocksel/orion/issues/469)). Components may still want `--repo` for the repository they belong to, or a repository URL through `--ref`; #469 settles which.                                                                 |

The variables `ORION_BIN`, `ORION_PERF`, `ORION_STORYBOOK`, and `ORION_COMMIT` belong to the app's dev server, perf, Storybook, and desktop builds. They stay contributor-only and out of the public docs. `ORION_WORKSPACE` is already gone.

## MCP tools

|            |                                                                                                                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | `orion mcp start` over stdio, each tool running a CLI command in the same process, and the server's `instructions` drawn from the CLI's orientation text.                       |
| **Keep**   | Tools only, with no resources or prompts until something needs them.                                                                                                            |
| **Keep**   | The `-32000` error that asks the client to reconnect after Orion is updated.                                                                                                    |
| **Keep**   | `readOnlyHint`, `destructiveHint`, and `openWorldHint` annotations.                                                                                                             |
| **Keep**   | Calls that meet a held lock wait their turn, as [#398](https://github.com/vocksel/orion/issues/398) made them.                                                                  |
| **Change** | Names follow the CLI, as in the table below, with [#415](https://github.com/vocksel/orion/issues/415).                                                                          |
| **Change** | `orion_inspect` splits into one tool per command it runs, with #415. Its `view` argument switches between five commands, so its schema can't say which arguments go with which. |
| **Remove** | `orion_sync`, and the `repo` and `pr` arguments, with their CLI forms in [#469](https://github.com/vocksel/orion/issues/469).                                                   |

| Today                                                                                                                                         | With #415                                                                                                        |
| --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `orion_canvases`                                                                                                                              | `orion_canvas_list`                                                                                              |
| `orion_create_canvas`, `orion_rename_canvas`, `orion_update_canvas`, `orion_archive_canvas`, `orion_restore_canvas`                           | `orion_canvas_create`, `orion_canvas_rename`, `orion_canvas_set`, `orion_canvas_archive`, `orion_canvas_restore` |
| `orion_select_canvas`, `orion_check`                                                                                                          | `orion_canvas_use`, `orion_canvas_check`                                                                         |
| `orion_inspect` with `view` set to `list`, `ready`, `groups`, `matches`, or `show`                                                            | `orion_card_list`, `orion_next`, `orion_group_list`, `orion_source_matches`, and `orion_node_show`               |
| `orion_find`, `orion_query`, `orion_move`, `orion_remove`                                                                                     | `orion_node_find`, `orion_node_query`, `orion_node_move`, `orion_node_remove`                                    |
| `orion_add_item`, `orion_update_item`, `orion_done`, `orion_import`                                                                           | `orion_card_add`, `orion_card_set`, `orion_card_done`, `orion_card_import`                                       |
| `orion_snooze`, `orion_unsnooze`                                                                                                              | `orion_card_snooze`, `orion_card_unsnooze`                                                                       |
| `orion_snoozed_jobs`, `orion_snooze_job`, `orion_unsnooze_job`                                                                                | `orion_ci_list`, `orion_ci_snooze`, `orion_ci_unsnooze`                                                          |
| `orion_add_note`                                                                                                                              | `orion_note_add`                                                                                                 |
| `orion_link`, `orion_unlink`, `orion_insert`                                                                                                  | `orion_link_add`, `orion_link_remove`, `orion_link_insert`                                                       |
| `orion_group`, `orion_create_group`                                                                                                           | `orion_group_create`, once `group add` folds into it                                                             |
| `orion_update_group`, `orion_remove_group`, `orion_ungroup`, `orion_tidy`                                                                     | `orion_group_set`, `orion_group_remove`, `orion_group_ungroup`, `orion_group_tidy`                               |
| `orion_remove_ref`                                                                                                                            | `orion_ref_remove`                                                                                               |
| `orion_images`, `orion_add_image`                                                                                                             | `orion_media_list`, `orion_media_insert`                                                                         |
| `orion_themes`, `orion_add_theme`, `orion_remove_theme`                                                                                       | `orion_theme_list`, `orion_theme_add`, `orion_theme_remove`                                                      |
| `orion_sources`                                                                                                                               | `orion_source_list`                                                                                              |
| `orion_suggest`, `orion_suggestions`, `orion_apply_suggestions`, `orion_dismiss_suggestions`                                                  | `orion_suggestion_find`, `orion_suggestion_list`, `orion_suggestion_apply`, `orion_suggestion_dismiss`           |
| `orion_backups`, `orion_restore_backup`                                                                                                       | `orion_backup_list`, `orion_backup_restore`                                                                      |
| `orion_log_add`, `orion_log_list`, `orion_card_timeline`, `orion_ingest`, `orion_apply`, `orion_reveal`, `orion_focus`, `orion_server_status` | Already match                                                                                                    |
| `orion_sync`                                                                                                                                  | Removed in #469                                                                                                  |

## HTTP API

The app is the only client. Agents and scripts use the CLI or MCP.

| Route                                   | Methods       | What it's for                                                                                    |
| --------------------------------------- | ------------- | ------------------------------------------------------------------------------------------------ |
| `/api/orion`                            | `GET`         | The canvas document                                                                              |
| `/api/operations`                       | `POST`        | Edits to the canvas, applied by the server                                                       |
| `/api/orion/style`                      | `PUT`         | The canvas's cover, background, and header                                                       |
| `/api/orion/check-snoozes`              | `PUT`         | CI jobs snoozed from the inspector                                                               |
| `/api/focus`                            | `POST`        | The app's open group and selection                                                               |
| `/api/canvases`, `/api/canvases/active` | `GET`, `POST` | List, create, and switch canvases                                                                |
| `/api/images`, `/api/images/<asset>`    | `POST`, `GET` | Upload and serve images                                                                          |
| `/api/log`                              | `GET`         | The canvas log                                                                                   |
| `/api/settings`                         | `GET`, `POST` | The app's settings                                                                               |
| `/api/themes`                           | `GET`         | Theme files                                                                                      |
| `/api/sync`                             | `GET`, `POST` | Refresh status, and a refresh now                                                                |
| `/api/merge`                            | `POST`        | Merge a pull request through `gh`                                                                |
| `/api/editor`                           | `GET`, `POST` | Whether an editor is available, and open a pull request in it through hop                        |
| `/api/links`                            | `POST`        | Link previews                                                                                    |
| `/api/reveal`                           | `POST`        | Reveal cards in the app for `orion reveal`                                                       |
| `/api/events`                           | WebSocket     | `orion:changed`, `orion:canvas`, `orion:canvases`, `orion:log`, `orion:reveal`, and `orion:sync` |

|            |                                                                                                                                                                                                                                                                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | Internal at every stage, with no promise and no aliases when a route changes.                                                                                                                                                                                                                         |
| **Keep**   | One process owning the data, with the app writing the document through `POST /api/operations`.                                                                                                                                                                                                        |
| **Change** | Refuse requests whose `Host` or `Origin` isn't the server's own or the app's dev server, as [the HTTP question](#is-the-http-api-internal) explains, and send a content security policy with the static app, since the desktop shell sets none ([#468](https://github.com/vocksel/orion/issues/468)). |
| **Change** | Edits beyond the document, such as the canvas style and check snoozes, go through `POST /api/operations` too, so the app has one write path.                                                                                                                                                          |

## JSON output

|            |                                                                                                                                                                                                                                               |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | Lists as arrays, one item as an object, and the batch write envelope.                                                                                                                                                                         |
| **Change** | Groups and notes get shapes of their own. `group add --json` and `group set --json` print a group with `kind: "step"`, `status`, and `waitsOn`, and a note prints `status: "done"`. A group should print what `group list` does, plus its id. |
| **Change** | Every write prints the `revision` it made, so the next command can pass `--if-revision`. Batch writes do. `card add`, `card set`, `note add`, and `group add` print only the item.                                                            |
| **Change** | Failures print `{"error": {"message": …}}` under `--json`, as in the [CLI list](#cli).                                                                                                                                                        |
| **Change** | Times use RFC 3339. `backup list` prints `20261017T164600Z`, taken from the backup's file name.                                                                                                                                               |
| **Change** | An absent value is `null` or a missing field, not an empty string. `suggestion list` prints `createdAt: ""` when nothing has run.                                                                                                             |

[#470](https://github.com/vocksel/orion/issues/470) carries every change in this list.

## Data files

| File                                | What it holds                                                                                   |
| ----------------------------------- | ----------------------------------------------------------------------------------------------- |
| `orion.json`                        | A canvas: nodes, links, settings, sources, and cached GitHub and suggestion results. Version 2. |
| `orion.lock`                        | The write lock                                                                                  |
| `backups/`                          | A copy before every write                                                                       |
| `assets/`                           | Image files                                                                                     |
| `log.jsonl`                         | The canvas log                                                                                  |
| `focus.json`                        | The app's last focus report                                                                     |
| `canvases.json`, `canvases/<name>/` | The canvas list and each canvas's folder                                                        |
| `settings.json`                     | App preferences                                                                                 |
| `themes/`                           | Theme files                                                                                     |
| `serve.json`                        | The running server's process and address                                                        |

The desktop app keeps its server port in `server-port` under its own app data folder.

|            |                                                                                                                                                                                                                                                                                                                                    |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | The CLI owns every file. Nothing else writes them, and the lock and revision rules stay as [Data and canvases](/guide/data) describes.                                                                                                                                                                                             |
| **Keep**   | A `version` in `orion.json`, migrated on read, and the folder moves in `cli/src/migrations/` until 0.1.0, as "Data folders move to a new layout on their own" says.                                                                                                                                                                |
| **Change** | Node vocabulary matches the public words. Nodes store `type: "task"` or `"cluster"`, repeat it in `data.kind`, and keep step, gate, note, and component in `data.itemKind`. Rename these in version 3 when [#122](https://github.com/vocksel/orion/issues/122) splits nodes from placements, since that rewrites the shape anyway. |
| **Change** | `serve.json` becomes `server.json`, after the command.                                                                                                                                                                                                                                                                             |
| **Change** | Cached results such as `github` and `suggestions` leave `orion.json` for the SQLite index with [#121](https://github.com/vocksel/orion/issues/121), so a refresh doesn't rewrite the canvas.                                                                                                                                       |
| **Remove** | The version 1 migration ([#471](https://github.com/vocksel/orion/issues/471)). It guesses a GitHub owner of `flipbook-labs` when no source names one, which "No eager scaffolding" rules out. Before 0.1.0, refuse a version 1 file with a clear message instead.                                                                  |

## Desktop shell

The shell starts the bundled `orion server start --static` on a saved port and opens a web view on it. The `orion` command links to the binary inside the bundle.

|            |                                                                                                                                                                                               |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | One IPC command, `process_usage`, for the debug bar. Everything else goes through the server.                                                                                                 |
| **Keep**   | The opener and window-state plugins, and the Acknowledgements window.                                                                                                                         |
| **Keep**   | No URL scheme or deep links yet. When [#176](https://github.com/vocksel/orion/issues/176) adds links to cards, an `orion://` scheme should open them through the same path as `orion reveal`. |
| **Change** | The capability that lets pages call IPC covers every port on `127.0.0.1`. Narrow it to the server's port if Tauri allows it at runtime.                                                       |
| **Change** | `orion reveal` launches `~/Applications/Orion.app` when no app is open, but Orion installs to `/Applications`.                                                                                |

## Where the docs differ

`README.md` matches this audit. The agent guide in `AGENTS.md` and `agents/` matches the code today, and these lines change with the follow-ups:

- `--repo` and `--pr` "stay for one release", and `orion sync` and `--discover` are described as deprecated. Both go with [#469](https://github.com/vocksel/orion/issues/469).
- `POST /api/images?canvas=<name>` and `GET /api/images/<asset>` are documented for agents, though the API is internal. Agents should use `orion media insert`, and [#468](https://github.com/vocksel/orion/issues/468) drops those lines.
