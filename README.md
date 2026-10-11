# Orion

A canvas for graph-shaped work: tasks and pull requests with dependencies, grouped freely across repositories, with a detail control that goes from single cards out to whole bodies of work.

This is a prototype. It runs in the browser or in a desktop shell.

See [`CHARTER.md`](CHARTER.md) for where it's headed and [`DECISIONS.md`](DECISIONS.md) for the calls made along the way.

- `app/`: the canvas.
- `desktop/`: the Tauri desktop shell.
- `cli/`: `orion`, a command-line tool for reading and editing the same data, meant for agents as much as people. `orion mcp` exposes its canvas and workspace actions to agents over MCP.
- `orion suggest` proposes groups for ungrouped cards (or every card with `--scope all`). It joins cards by links, Jira epics, shared branches, and references, then `--agent codex` or `--agent claude` names and splits the result into groups by outcome. The agent's CLI must already be signed in. Review with `orion suggestions`, then use `orion suggestions apply <id...> | --all` or `orion suggestions dismiss <id...> | --all`. These commands use the selected workspace. The app places new groups to the right of existing ones and refits groups whose cards moved.

## Data

The default canvas lives in `orion.json` inside Orion's user data folder: `~/Library/Application Support/Orion` on macOS, `%APPDATA%\Orion` on Windows, and `$XDG_DATA_HOME/orion` (or `~/.local/share/orion`) on Linux. Set `ORION_DATA_DIR` to use another data root. `orion serve` owns the app's data API, and all file access goes through the Luau CLI store. The app talks to that API over HTTP and receives changes over WebSocket. The CLI takes the same lock for every write, so the app and other commands can be open at once.

### Workspaces

The original canvas is the `default` workspace in the data root. Other workspaces keep separate `orion.json` files under `<data root>/workspaces/<name>/`. The root's `workspaces.json` records their names, labels, and the active workspace. Workspace names use lowercase letters, digits, and hyphens.

Images are canvas nodes with workspace-local files in `assets/`. The app's **Add image** control accepts PNG, JPEG, GIF, and WebP files up to 5 MB. Agents can insert one with `orion media insert ./concept.png --workspace orion --label "Concept"`; the command identifies supported images from their contents and can accommodate other media types later. `orion media list --workspace orion` lists media nodes. `orion serve` accepts raw bytes at `POST /api/images?workspace=<name>` and serves them at `GET /api/images/<asset>?workspace=<name>`. Both routes use the same asset storage as the CLI.

Use `orion workspace list`, `orion workspace create <name> [--label <label>]`, `orion workspace rename <name> <label>`, and `orion workspace use <name>` to manage them. Renaming changes only the label; the name and folder stay the same. `orion workspace current` shows the selected workspace, and `orion path` prints its folder. The app's sidebar can also create and switch workspaces. Pass `--workspace <name>` to a CLI command to use one without changing the active workspace; `ORION_WORKSPACE` provides the same choice for the environment. The command option takes precedence, followed by the environment, `workspaces.json`, and `default`.

Before replacing an existing data file, the CLI store copies it to `backups/orion-r<revision>-<UTC timestamp>.json` in that workspace's folder. Backups from the last 24 hours are kept, along with the newest backup for each UTC day in the last 30 days. Run `orion backups [--json]` to list the selected workspace's backups newest first, and `orion restore <revision>` to recover one in that workspace as a new revision. If several backups have that revision, restore uses the newest. Restoring also backs up the current file first.

While the app is open, it reports its open group and selection to `orion serve`. The server writes `focus.json` in the active workspace's folder without changing the canvas revision; `orion focus` reads it. The report is cleared when its tab closes, the workspace changes, or the server stops.

The app's preferences, such as the theme, color mode, scrolling, keyboard shortcuts, and whether the sidebar is shown, live in the data root's `settings.json`. `orion serve` reads and merges them at `/api/settings`, so they're shared by every workspace and by the browser and desktop app.

## Run the app

```sh
cd app
npm install
npm run dev
```

Build the CLI first with `cd cli && lute run build`. Vite starts `orion serve` and proxies `/api` to it. Set `ORION_BIN` to use another CLI binary. If the binary is missing, Vite still runs and the app falls back to browser storage.

PR cards show a **VS Code** button when the `code` and `hop` launchers are on the server's `PATH`. Clicking it runs `hop to <PR URL>`, which reuses or checks out the PR's worktree and opens it in VS Code.

To browse the component stories without starting `orion serve`, run `npm run storybook` from `app/`. Each component's story lives beside it in `app/src/components/`, with shared sample data in `storySupport/`. Pick a theme from the Theme menu, Light or Dark from the Color mode menu, and a colorblind palette from the Colorblind colors menu in Storybook's toolbar to check a story in each look. Run `npm run build-storybook` to check the static Storybook build. The stories use sample graph data and render the app composition against Storybook's own browser storage. The normal app build does not import the stories, so they are absent from the packaged app.

To check a change for performance regressions, run `npm run perf` from `app/`. It compares this checkout against `origin/main` (pass `-- --base <ref>` for another revision) and writes the report to `app/.perf/report.md`. Both sides run this checkout's harness in `app/src/perf/`: data benchmarks over generated canvases of 1,000 and 5,000 cards, and a 1,000-card perf story that Playwright drives in headless Chromium to count React commits, frames drawn, and main-thread and raster time while idle, panning, zooming, hovering, and dragging. Add `-- --stories perf-canvas--cards-1000,perf-canvas--cards-5000` to profile the larger canvas too, which is slow enough today to take several minutes. Install the browser once with `npx playwright install chromium`. Run `npx vitest bench --root src` for the benchmarks alone. Close other heavy work while it runs, since it measures this machine. On pull requests that touch `app/`, CI's perf job runs the same comparison against the base branch and posts the report as a comment, replacing it on each run.

`orion serve` reads and writes the active workspace's data file. Run it directly with `orion serve [--host 127.0.0.1] [--port 5198] [--static app/dist]`; `--static` serves a built app with an `index.html` fallback. When the default workspace has no file, the app carries over what the browser had saved. Otherwise a new workspace starts empty. The server syncs five seconds after startup and every five minutes. Returning to the window also requests a sync, with a one-minute throttle.

## Desktop app

Install Rust 1.90 or newer, the Xcode Command Line Tools, and Lute, then run:

```sh
cd desktop
npm install
npm run dev
```

The development window uses the app's Vite server on port 5199, which proxies the data API and WebSocket to `orion serve`. `npm run build` builds the CLI with Lute and packages it with the canvas. The packaged app runs `orion serve`, so it reads and writes the same workspace files as the CLI, including when `ORION_DATA_DIR` selects another data root. It picks a free port on first launch, saves it as `server-port` in the app's own folder (`~/Library/Application Support/com.vocksel.orion` on macOS), and reuses it after, so the window keeps one origin and its browser storage, such as each workspace's viewport and detail level, survives a restart. When another process holds that port for more than a few seconds, it picks and saves a new one.

## Build the CLI

The CLI is written in Luau and compiled with [Lute](https://github.com/luau-lang/lute).

```sh
cd cli
rokit install
lute run install
lute run build
```

That produces `cli/build/orion`. Put it on your `PATH`, then run `orion help`. See [`AGENTS.md`](AGENTS.md) for how agents should use it.

Before committing CLI changes, run `lute run analyze` and `lute test` in `cli/`.
StyLua is installed through `cli/rokit.toml`. Run `stylua src cli.luau .lute project.luau loom.config.luau` from `cli/` to format all Luau sources, including the Lute scripts. CI checks the same paths.

### Connect agents over MCP

`orion mcp` runs an MCP server over stdin and stdout, so AI clients can discover Orion's canvas and workspace tools and call them directly. Each tool maps its arguments onto an existing CLI command in the same process, so the CLI stays the only writer and never runs a shell command built from tool input.

Add Orion to any MCP client as a stdio server that runs `orion mcp`, using the full path to the binary. Most clients accept a config entry like this one or an equivalent `mcp add` command:

```json
{
  "mcpServers": {
    "orion": {
      "command": "/Applications/Orion.app/Contents/MacOS/orion",
      "args": ["mcp"]
    }
  }
}
```

The desktop app bundles the binary at that path; use `cli/build/orion` for a local build. Add `ORION_DATA_DIR` to the server's environment to use another data root. Pass `--workspace <name>` to keep the server on one workspace; otherwise each call uses the selected workspace unless the tool call names one.

### Sources

Configure sources once, then run `orion ingest --dry-run` to preview work involving you. `orion ingest` adds new cards to Unsorted, updates matching cards in place, and links mentioned Jira issues or GitHub issues to pull requests. `orion source list --json` shows the configuration. Sources and cards live in the selected Orion data file; source commands run through the CLI and keep credentials in their own tools.

Each source kind is an adapter in `cli/src/adapters/<kind>/`. An adapter validates source options and collects records for ingest; GitHub also implements pull request refresh for sync.

For GitHub sources, `--owners`, `--include`, and `--exclude` accept comma-separated lists. Spaces around entries are ignored, so `--owners vocksel,flipbook-labs --include "orion, hop"` works.

Cards store pull requests, issues, and local branches in `data.refs`, including each source ID, key, URL, status, completion state, update time, and source-specific details. A ref's kind and case-insensitive key identify it across ingests.

For a Roblox setup:

```sh
orion source add github --host github.com --owners Roblox
orion source add github --host github.example.com --owners Roblox --id gh-roblox-enterprise
orion source add jira --command '["acli","jira","workitem","search","--jql","assignee = currentUser() AND resolution = Unresolved","--json"]' --browse https://jira.example.com/browse
orion source add hop
orion ingest --dry-run
orion ingest
```

Use `orion ingest --source <id> --json` for one source and a machine-readable report. `orion source remove <id>` stops future ingestion from a source; cards already on the canvas remain.

## Using the canvas

- The toolbar at the bottom switches tools. Select (V) is the default: drag a box to select everything it touches, and ⇧ adds to the selection. An open group is selected only when the box covers all of it. Middle-drag or hold Space and drag to pan. Pan (H) drags the canvas from anywhere, with ⌘-drag to select. Comment (C) drops a note where you click, then returns to Select. Esc also returns to Select.
- Hold S to open the sticker wheel, point at one, and let go; a quick tap or the toolbar button leaves it open for clicking, and 1–8 pick by number. With it open, type or paste any emoji to stamp that instead, and right-click a slot, or click an empty one, to put a different emoji there. Each canvas keeps its own wheel. Then click to stamp it as many times as you like. Stickers stamped on a card or group move with it. In Select, drag a sticker to move it or flick it to send it sliding; stickers bounce off each other and stay inside their group's walls. Keep pulling past a wall to pop one out of a group, or into another. Right-click a sticker to remove it.
- Scroll a mouse wheel or pinch to zoom, and scroll a trackpad, Space-drag, or middle-drag to pan. Settings › Canvas switches the mouse wheel to pan instead, with pinch or ⌘-scroll to zoom. ⌘-click or ⇧-click adds to the selection. Right-click anything for its actions.
- ⌘G groups the selection. ⇧⌘G ungroups. Groups can nest and span repositories.
- The list on the left shows every group in canvas order. Click one to open it.
- Press ⌘K (or Ctrl+K) to search groups, cards, PRs, and notes, then press Enter to jump to a result. Type `>` first, or press ⇧⌘P (or Ctrl+Shift+P), to list actions instead; deleting the `>` goes back to searching.
- Open Settings with ⌘, (or Ctrl+,), the Settings button at the bottom of the sidebar, or through ⇧⌘P. Appearance picks the theme, the card skin, and Light, Dark, or System color mode. Accessibility picks colorblind colors: Red-green or Blue-yellow swaps in status colors tuned for that kind of color blindness, in any theme. Animations follows your computer's reduced motion setting until you pick a level: Reduced stops looping effects and makes the canvas jump instead of glide but keeps fades, and Off stops every animation. Every status also has its own shape: an empty ring when ready, half full in progress, three quarters in review, a solid check when done, a dashed ring when deferred, and a lock when blocked. Whose move it is shows as a person, an eye, or a gear; notes have a folded corner; folded groups look like a stack of cards; and the minimap draws ready work hollow, work in progress half filled, and work in review solid. Canvas picks whether scrolling zooms or pans. Keyboard Shortcuts lists every shortcut and gesture; click a shortcut and press new keys to rebind it, and a clash with another shortcut is flagged on both. All four are saved in the data folder. The shortcuts in this section are the defaults.
- Card skins are listed in `app/src/skins.ts`, with a component and CSS file for each skin.
- Double-click a group, or press Enter with one selected, to open it. Esc or a double-click on empty canvas goes back up, and the breadcrumbs jump to any level.
- An open group shows the outside work it waits on along its left side and the work waiting on it along its right. Click one to focus on it.
- The detail stepper beside the zoom buttons, or [ and ], folds groups into single bodies one level of nesting at a time, inner groups first, counting from the open group. Each workspace remembers its level. Links between folded groups are bundled into one line with a count. Zoom only moves the view.
- However far you zoom out, folded groups, cards, and notes keep their full details at a readable size, and open groups' headers grow to stay legible. Hover one to bring it above its neighbors.
- Hold ⌥ to see where it's your move. Lines run from the cursor to each one; work off screen gets a chip at the edge that jumps to it.
- Hover a card to trace what it needs (amber), what it unlocks (teal), and what relates to it (dark dots).
- Double-click a card to focus on it. The canvas zooms onto it with its details above, what it waits on in a scrolling column on the left, and what it leads to on the right. Click one of those to focus on it instead, opening its group if it lives elsewhere. Esc or a click on the empty canvas goes back. ⌘ or ⇧ click adds to the selection.
- Moving lines are dependencies that are still waiting. Still lines are satisfied. Dotted lines are related work that never blocks; they stay faint until you hover, hold, or select one of their cards.
- "Unblocks N" counts every open task downstream, directly or not.
- N adds a note. Right-click a link to add a card or a note into it, or a bundled link between folded groups to remove one of its links. Notes pass blocking through but never count as work, and can be turned into work items later.
- Reflow lays out the inside of a group. Tidy lays out the current level. Chains and runs of interchangeable cards wrap at about six across.
- A group's inspector picks its arrangement: Automatic flows by dependency, and Custom keeps cards where you put them. `orion set <group> --arrange custom` does the same from the CLI.
- Drag from the edge of a card to another card to add a dependency.
- Arrows to a card well behind their source loop around instead of doubling back.
- A card's inspector lists what it waits on, what it unblocks, and related cards, with controls to remove or flip each link. **Add link** searches for another card to connect.

Dashed cards are pull requests that aren't opened yet. Cards with a diamond are gates: they finish on their own once everything they wait on is done, so they suit milestones like a release. Check "Gate" in a card's inspector to make one. Click a card to edit it, add notes, or open its pull request. Cards with a repository and pull request number show what GitHub reported the last time `orion sync` ran.
The toolbar shows when GitHub was last synced, or a sync error; click the status to force a sync. Linked cards show a checks dot (green passing, red failing, amber pending) and changed line count. The inspector shows checks, additions and deletions, update time, author, and review requests. An unlinked work item may show possible pull requests in its inspector; use **Link** to attach one to the card.

## Layout of the code

In `app/`:

- `vite.config.ts`: starts `orion serve` for development and proxies its API.
- `src/persist.ts`: loading, saving, reacting to changes from other writers, and reporting focus.
- `src/model.ts`: node and link types, grouping, ungrouping, and fitting groups to their contents.
- `src/layout.ts`: laying out one group or the top level: ELK with wrapping, and custom groups left alone.
- `src/snap.ts`, `src/useNodeSnapping.ts`, and `src/components/SnapGuides.tsx`: drag geometry, interaction state, and alignment guides.
- `src/derive.ts`: status, leverage, group progress, and hover tracing.
- `src/nodes.tsx`: task cards and group frames.
- `src/components/ImageView.tsx`: image nodes and their workspace-local previews.
- `src/SourceBadges.tsx`, `src/SourceMenu.tsx`, `src/SourceLink.tsx`, and `src/Favicon.tsx`: the source favicons on cards and group bubbles, and the links behind them.
- `src/LinkList.tsx`: a card's own links in the inspector, and adding, flipping, or removing them.
- `src/CurveEdge.tsx`: arrows that loop around cards when they run backward.
- `src/App.tsx`: the canvas, detail levels, drill-in, connections outside an open group, focusing on a card, notes, and the inspector.
- `src/focus.tsx`: the columns and lines around a focused card.
- `src/Sidebar.tsx` and `src/ContextMenu.tsx`: the group list and right-click menu.
- `src/Settings.tsx`, `src/AppearanceSettings.tsx`, `src/CanvasSettings.tsx`, and `src/ShortcutSettings.tsx`: the settings dialog. `app/src/keybindings.ts` lists each shortcut with its default and saves rebound ones.

In `cli/src/`:

- `cli/init.luau`: command registration and dispatch; command modules in `cli/` define their own options.
- `cli/focus.luau`: reads and renders the app's reported open group and selection.
- `cli/mcp/`: the MCP server and its tool catalog. `cli/mcp/tools.luau` lists every tool.
- `store.luau`: reading, locking, and writing the data file, and reading and writing focus reports.
- `server/`: HTTP routes, WebSocket events, file watching, and sync scheduling for `orion serve`.
- `graph.luau`: derived status and leverage, and every edit the commands make.
- `github/`: looking up pull requests and mapping their state onto cards.
- `render.luau`: text and JSON output.
