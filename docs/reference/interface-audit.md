# Interface audit

This audit lists what stays, what changes, and what goes on each of Orion's public surfaces before the first release. It's a snapshot of `main` on 2026-10-17 and the pull requests open that day, written for [#146](https://github.com/vocksel/orion/issues/146).

::: warning Recommendations
Nothing here is settled. Each answer and change is a recommendation until it's confirmed, and confirmed calls move into [`DECISIONS.md`](https://github.com/vocksel/orion/blob/main/DECISIONS.md). [Public surfaces](/guide/surfaces) says what each surface promises today.
:::

Each list uses three marks:

- **Keep:** stays as it is.
- **Change:** stays, in a different shape.
- **Remove:** goes, with no alias, as the three-stage decision asks before 0.1.0.

Work already underway is linked to its pull request or issue rather than proposed again.

## The four questions

### Should the MCP tools follow the CLI structure?

**Recommendation: yes.** Give each CLI command one tool, named `orion_<noun>_<verb>` after it, with arguments named after its options in camelCase. Top-level commands keep one word: `orion_next`, `orion_focus`, `orion_ingest`, `orion_apply`, and `orion_reveal`.

- Agents learn one vocabulary. The CLI reference already says which command each tool runs, so a name that matches makes that mapping obvious.
- [#350](https://github.com/vocksel/orion/pull/350) already brings every CLI option into MCP, with a spec that fails when the two drift. It leaves the names alone and calls renaming them a follow-up.
- Today's names mix three patterns, and open pull requests add more: `orion_add_item` (verb first), `orion_card_show` and `orion_log_add` ([#353](https://github.com/vocksel/orion/pull/353), noun first), `orion_create_group` ([#348](https://github.com/vocksel/orion/pull/348)), and bare verbs such as `orion_find` and `orion_tidy`. Each new tool makes a later rename larger.
- The cost is more tools, about 45 once the open pull requests land. Every tool is small and has its own schema, which is what lets a client check a call before it runs. One tool per noun with a `verb` argument, like today's `orion_inspect`, would give less precise schemas for a smaller count.

Rename them in one change once #350 and the open pull requests that add tools have landed, so each tool is renamed once.

### Is the HTTP API internal?

**Recommendation: yes, and enforce it.** The 2026-10-12 decision already calls the API that `orion server start` serves internal to the app at every stage. Keep that call. Today, though, any web page open in a browser on the same machine can call it:

- `POST` routes parse the body as JSON whatever its content type, so a page can send a cross-site `text/plain` request that needs no CORS preflight. `POST /api/merge` merges a pull request through `gh` given its URL and head commit, which are public for a public repository. `POST /api/workspaces`, `POST /api/settings`, and the coming `POST /api/operations` ([#343](https://github.com/vocksel/orion/pull/343)) change data the same way.
- The server answers any `Host` header, so a DNS-rebinding page can read `GET /api/orion`.
- `/api/events` accepts a WebSocket from any origin.

Checking `Host` and `Origin` against the server's own address and the app's dev server closes all three. A token handed to the app at launch would also stop other local processes, and is worth adding if the check alone proves too loose.

### Which JSON shapes are stable?

**Recommendation: none before 0.1.0, as [Public surfaces](/guide/surfaces) says, then a short named list.** From 0.1.0, promise these shapes: new fields may appear, and removing or renaming a field is a breaking change.

- The item shape that `card list`, `node show`, `node query`, and `next` print: `id`, `label`, `kind`, `status`, `recordedStatus`, `group`, `groupLabel`, `waitsOn`, `leadsTo`, `unblocks`, and refs.
- The write envelope that batch commands print: `dryRun`, `revision`, `baseRevision`, `action`, and `items`.
- `canvas check`'s `{kind, ids, bounds}` list, `focus`, and `canvas list`.

Everything else stays unpromised until a script needs it, including `suggestion list`, `source matches`, `server status`, and the `ingest` report. Fix the inconsistencies under [JSON output](#json-output) before promising anything, since each fix breaks the shape it touches.

Data files are never a public interface for writing: tools go through the CLI. They carry a `version`, and the CLI migrates older versions as it reads them. The charter's data layer promise applies to them from 1.0.

### How do breaking changes ship?

**Recommendation: keep the three stages in `DECISIONS.md`, and apply them to what's left over.** Before 0.1.0, a breaking change lands in one pull request that updates the CLI, the MCP tools, the generated reference, `AGENTS.md`, and the app together, with no alias. From 0.1.0, each break is deliberate and the release notes list it. From 1.0, aliases come first.

Three deprecated forms predate the decision and still promise a release of overlap, which the decision replaced: `orion sync`, `--pr`, and `--repo` used with `--pr`. Remove them now, and rewrite the "Ingest is the one command that pulls from outside" entry, which still keeps `orion sync` for a release.

## CLI

|            |                                                                                                                                                                                                                                                       |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | The noun-verb shape and its nouns: `card`, `note`, `link`, `node`, `group`, `ref`, `canvas`, `source`, `media`, `suggestion`, `theme`, `backup`, `server`, and `mcp`.                                                                                 |
| **Keep**   | Top-level `next`, `focus`, `ingest`, and `help`. `help` comes from the same command table as `--help`, so it costs nothing to keep.                                                                                                                   |
| **Keep**   | `--where`, `--dry-run`, `--if-revision`, and `--json` on batch commands.                                                                                                                                                                              |
| **Keep**   | `--canvas`, `--help`, and `--version` on every command.                                                                                                                                                                                               |
| **Keep**   | `ORION_DATA_DIR` and `ORION_CANVAS`, with the option winning over the variable.                                                                                                                                                                       |
| **Change** | Every command takes `--json`. These don't yet: `canvas create`, `rename`, `set`, `archive`, `restore`, `use`, `current`, and `path`, `link remove`, `backup restore`, `suggestion apply` and `dismiss`, and `source add` and `remove`.                |
| **Change** | With `--json`, a failure prints a JSON error and still exits nonzero. Today errors are text on stderr only.                                                                                                                                           |
| **Change** | Single-item writes take `--dry-run` and `--if-revision`: `card add` and `set`, `note add`, `group add` and `set`, `link remove`, `ref remove`, `media insert`, and `canvas set`. Add them as #343's fourth part moves these commands onto operations. |
| **Change** | `suggestion find --agent claude\|codex` runs those two tools by name, which is the per-provider code that "MCP stays generic" avoids. Take a `--command '<JSON array>'` as `source add jira` and `hop` do.                                            |
| **Change** | One verb for making groups. [#348](https://github.com/vocksel/orion/pull/348) adds `group create` beside `group add` and asks whether to fold them. Fold them: `group create <label> [--items …] [--in …]`.                                           |
| **Remove** | `orion sync` and `--discover`. `orion ingest` refreshes pull requests too, and a GitHub source files new ones in Unsorted.                                                                                                                            |
| **Remove** | `--pr` on `card add` and `set`, and `--repo` as its partner. Components still use `--repo` for the repository they belong to, so either keep it for that alone or take a repository URL through `--ref`. That's a call to make in the follow-up.      |

Commands that open pull requests add fit the shape: `node find` and selectors ([#349](https://github.com/vocksel/orion/pull/349)), `group create` (#348), `apply` ([#351](https://github.com/vocksel/orion/pull/351), top level because it spans every noun), `log` and `card show` (#353), `reveal` ([#354](https://github.com/vocksel/orion/pull/354)), `card snooze` ([#259](https://github.com/vocksel/orion/pull/259)), and `ci` ([#362](https://github.com/vocksel/orion/pull/362)).

The variables `ORION_BIN`, `ORION_PERF`, `ORION_STORYBOOK`, and `ORION_COMMIT` belong to the app's dev server, perf, Storybook, and desktop builds. They stay contributor-only and out of the public docs. `ORION_WORKSPACE` is already gone.

## MCP tools

|            |                                                                                                                                                                      |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | `orion mcp start` over stdio, each tool running a CLI command in the same process, and the server's `instructions` drawn from the CLI's orientation text.            |
| **Keep**   | Tools only, with no resources or prompts until something needs them.                                                                                                 |
| **Keep**   | The `-32000` error that asks the client to reconnect after Orion is updated.                                                                                         |
| **Keep**   | `readOnlyHint`, `destructiveHint`, and `openWorldHint` annotations.                                                                                                  |
| **Change** | Names follow the CLI, as in the table below.                                                                                                                         |
| **Change** | `orion_inspect` splits into one tool per command it runs. Its `view` argument switches between five commands, so its schema can't say which arguments go with which. |
| **Change** | The `workspace` argument and tool names say canvas. [#110](https://github.com/vocksel/orion/issues/110) covers the argument, and the rename above covers the names.  |
| **Change** | Missing options and batch `ids` arrive with #350, and calls that meet a held lock wait their turn with [#398](https://github.com/vocksel/orion/issues/398).          |
| **Remove** | `orion_sync`, and the `repo` and `pr` arguments, with their CLI forms.                                                                                               |

| Today                                                                                                    | Proposed                                                                                           |
| -------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `orion_workspaces`                                                                                       | `orion_canvas_list`                                                                                |
| `orion_create_workspace`, `orion_rename_workspace`, `orion_archive_workspace`, `orion_restore_workspace` | `orion_canvas_create`, `orion_canvas_rename`, `orion_canvas_archive`, `orion_canvas_restore`       |
| `orion_select_workspace`                                                                                 | `orion_canvas_use`                                                                                 |
| `orion_inspect` with `view` set to `list`, `ready`, `groups`, `matches`, or `show`                       | `orion_card_list`, `orion_next`, `orion_group_list`, `orion_source_matches`, and `orion_node_show` |
| `orion_add_item`, `orion_update_item`, `orion_import`                                                    | `orion_card_add`, `orion_card_set`, `orion_card_import`                                            |
| `orion_add_note`                                                                                         | `orion_note_add`                                                                                   |
| `orion_link`, `orion_unlink`                                                                             | `orion_link_add`, `orion_link_remove`                                                              |
| `orion_group`, `orion_remove_group`                                                                      | `orion_group_create`, `orion_group_remove`                                                         |
| `orion_move`, `orion_remove`                                                                             | `orion_node_move`, `orion_node_remove`                                                             |
| `orion_remove_ref`                                                                                       | `orion_ref_remove`                                                                                 |
| `orion_images`, `orion_add_image`                                                                        | `orion_media_list`, `orion_media_insert`                                                           |
| `orion_themes`, `orion_add_theme`, `orion_remove_theme`                                                  | `orion_theme_list`, `orion_theme_add`, `orion_theme_remove`                                        |
| `orion_ingest`                                                                                           | `orion_ingest`                                                                                     |
| `orion_sync`                                                                                             | Removed                                                                                            |

The open pull requests add tools that the same rule names:

| Pull request                                            | Adds                                                                                                          | Proposed                                                                                                                    |
| ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| #350                                                    | `orion_done`, `orion_query`, `orion_insert`, `orion_update_group`, `orion_ungroup`, `orion_update_canvas`     | `orion_card_done`, `orion_node_query`, `orion_link_insert`, `orion_group_set`, `orion_group_ungroup`, `orion_canvas_set`    |
| #350                                                    | `orion_sources`, `orion_suggest`, `orion_suggestions`, `orion_apply_suggestions`, `orion_dismiss_suggestions` | `orion_source_list`, `orion_suggestion_find`, `orion_suggestion_list`, `orion_suggestion_apply`, `orion_suggestion_dismiss` |
| #350                                                    | `orion_backups`, `orion_restore_backup`, `orion_server_status`, `orion_focus`                                 | `orion_backup_list`, `orion_backup_restore`, `orion_server_status`, `orion_focus`                                           |
| [#399](https://github.com/vocksel/orion/pull/399), #350 | `orion_tidy`, `orion_check`                                                                                   | `orion_group_tidy`, `orion_canvas_check`                                                                                    |
| #348                                                    | `orion_create_group`                                                                                          | `orion_group_create`                                                                                                        |
| #349                                                    | `orion_find`                                                                                                  | `orion_node_find`                                                                                                           |
| #353                                                    | `orion_log_add`, `orion_log_list`, `orion_card_show`                                                          | Already match                                                                                                               |
| #351, #354                                              | `orion_apply`, `orion_reveal`                                                                                 | Already match                                                                                                               |

## HTTP API

The app is the only client. Agents and scripts use the CLI or MCP.

| Route                                       | Methods       | What it's for                                                                             |
| ------------------------------------------- | ------------- | ----------------------------------------------------------------------------------------- |
| `/api/orion`                                | `GET`, `PUT`  | The canvas document. [#355](https://github.com/vocksel/orion/pull/355) removes the `PUT`. |
| `/api/orion/style`                          | `PUT`         | The canvas's cover, background, and header                                                |
| `/api/focus`                                | `POST`        | The app's open group and selection                                                        |
| `/api/workspaces`, `/api/workspaces/active` | `GET`, `POST` | List, create, and switch canvases                                                         |
| `/api/images`, `/api/images/<asset>`        | `POST`, `GET` | Upload and serve images                                                                   |
| `/api/settings`                             | `GET`, `POST` | The app's settings                                                                        |
| `/api/themes`                               | `GET`         | Theme files                                                                               |
| `/api/sync`                                 | `GET`, `POST` | Refresh status, and a refresh now                                                         |
| `/api/merge`                                | `POST`        | Merge a pull request through `gh`                                                         |
| `/api/editor`                               | `GET`, `POST` | Whether an editor is available, and open a pull request in it through hop                 |
| `/api/links`                                | `POST`        | Link previews                                                                             |
| `/api/events`                               | WebSocket     | `orion:changed`, `orion:workspace`, `orion:workspaces`, and `orion:sync`                  |

Open pull requests add `POST /api/operations` (#343), `GET /api/log` and `orion:log` (#353), a reveal route (#354), and `PUT /api/orion/check-snoozes` (#362).

|            |                                                                                                                                                                                                                                                                 |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | Internal at every stage, with no promise and no aliases when a route changes.                                                                                                                                                                                   |
| **Keep**   | One process owning the data, with the app writing through `POST /api/operations` once #343 and #355 land.                                                                                                                                                       |
| **Change** | Refuse requests whose `Host` or `Origin` isn't the server's own or the app's dev server, as [the HTTP question](#is-the-http-api-internal) explains. The same change can send a content security policy with the static app, since the desktop shell sets none. |
| **Change** | `/api/workspaces` and `?workspace=` say canvas, with #110.                                                                                                                                                                                                      |
| **Change** | Edits beyond the document, such as #362's check snoozes, go through `POST /api/operations` too once it lands, so the app has one write path.                                                                                                                    |
| **Remove** | `PUT /api/orion`, with #355.                                                                                                                                                                                                                                    |

## JSON output

|            |                                                                                                                                                                                                                                               |
| ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | Lists as arrays, one item as an object, and the batch write envelope.                                                                                                                                                                         |
| **Change** | Groups and notes get shapes of their own. `group add --json` and `group set --json` print a group with `kind: "step"`, `status`, and `waitsOn`, and a note prints `status: "done"`. A group should print what `group list` does, plus its id. |
| **Change** | Every write prints the `revision` it made, so the next command can pass `--if-revision`. Batch writes do. `card add`, `card set`, `note add`, and `group add` print only the item.                                                            |
| **Change** | Failures print `{"error": {"message": …}}` under `--json`, as in the [CLI list](#cli).                                                                                                                                                        |
| **Change** | Times use RFC 3339. `backup list` prints `20261017T164600Z`, taken from the backup's file name.                                                                                                                                               |
| **Change** | An absent value is `null` or a missing field, not an empty string. `suggestion list` prints `createdAt: ""` when nothing has run.                                                                                                             |
| **Change** | `canvas list` returns `canvases` instead of `workspaces`, with #110.                                                                                                                                                                          |

## Data files

| File                                    | What it holds                                                                                   |
| --------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `orion.json`                            | A canvas: nodes, links, settings, sources, and cached GitHub and suggestion results. Version 2. |
| `orion.lock`                            | The write lock                                                                                  |
| `backups/`                              | A copy before every write                                                                       |
| `assets/`                               | Image files                                                                                     |
| `focus.json`                            | The app's last focus report                                                                     |
| `workspaces.json`, `workspaces/<name>/` | The canvas list and each canvas's folder                                                        |
| `settings.json`                         | App preferences                                                                                 |
| `themes/`                               | Theme files                                                                                     |
| `serve.json`                            | The running server's process and address                                                        |

#353 adds `log.jsonl` in each canvas folder. The desktop app keeps its server port in `server-port` under its own app data folder.

|            |                                                                                                                                                                                                                                                                                                                                    |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | The CLI owns every file. Nothing else writes them, and the lock and revision rules stay as [Data and canvases](/guide/data) describes.                                                                                                                                                                                             |
| **Keep**   | A `version` in `orion.json`, migrated on read.                                                                                                                                                                                                                                                                                     |
| **Change** | Node vocabulary matches the public words. Nodes store `type: "task"` or `"cluster"`, repeat it in `data.kind`, and keep step, gate, note, and component in `data.itemKind`. Rename these in version 3 when [#122](https://github.com/vocksel/orion/issues/122) splits nodes from placements, since that rewrites the shape anyway. |
| **Change** | `workspaces.json` and `workspaces/` become `canvases.json` and `canvases/`, with #110. `serve.json` becomes `server.json` after the command, and can ride with that rename.                                                                                                                                                        |
| **Change** | Cached results such as `github` and `suggestions` leave `orion.json` for the SQLite index with [#121](https://github.com/vocksel/orion/issues/121), so a refresh doesn't rewrite the canvas.                                                                                                                                       |
| **Remove** | The version 1 migration. It guesses a GitHub owner of `flipbook-labs` when no source names one, which "No eager scaffolding" rules out. Before 0.1.0, refuse a version 1 file with a clear message instead.                                                                                                                        |

## Desktop shell

The shell starts the bundled `orion server start --static` on a saved port and opens a web view on it. The `orion` command links to the binary inside the bundle.

|            |                                                                                                                                                                                                      |
| ---------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Keep**   | One IPC command, `process_usage`, for the debug bar. Everything else goes through the server.                                                                                                        |
| **Keep**   | The opener and window-state plugins, and the Acknowledgements window.                                                                                                                                |
| **Keep**   | No URL scheme or deep links yet. When [#176](https://github.com/vocksel/orion/issues/176) adds links to cards, an `orion://` scheme should open them through the same path as `orion reveal` (#354). |
| **Change** | The capability that lets pages call IPC covers every port on `127.0.0.1`. Narrow it to the server's port if Tauri allows it at runtime.                                                              |
| **Change** | #354 launches `~/Applications/Orion.app` when no app is open, but Orion installs to `/Applications`.                                                                                                 |

## Where the docs differ

`README.md` matches this audit. `AGENTS.md` matches the code today, and these lines change with the recommendations:

- `--repo` and `--pr` "still work as aliases for one release", and the system-diagram example passes `--repo` to a component.
- `orion sync` and `--discover` are described as deprecated.
- `POST /api/images?workspace=<name>` and `GET /api/images/<asset>` are documented for agents, though the API is internal. Agents should use `orion media insert`.
