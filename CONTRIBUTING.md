# Contributing

Read [the charter](docs/development/charter.md) for where Orion is headed and [the decisions log](docs/development/decisions.md) for the calls made along the way. [`AGENTS.md`](AGENTS.md) indexes the guides in [`agents/`](agents/), which hold the code style and pull request conventions that people and agents both follow.

## Toolchain

- [Rokit](https://github.com/rojo-rbx/rokit), which installs Lute and StyLua from `rokit.toml`
- Node.js, for the app, the desktop shell, and the docs site
- Rust 1.90 or newer and the Xcode Command Line Tools, for the desktop app

## CLI

The CLI is written in Luau and compiled with [Lute](https://github.com/luau-lang/lute). Scripts in `.lute/` run from the repository root, and `lute test` runs from `workspace/orion-cli/`:

```sh
rokit install
lute run install
lute run build
```

That writes `workspace/orion-cli/build/orion`. `lute run install` installs the CLI's Luau packages and copies them into `workspace/orion-cli/packages`, so the build can bundle them from a checkout anywhere. Run it again after changing `loom.config.luau`.

Before committing CLI changes, run these:

```sh
lute run analyze
(cd workspace/orion-cli && lute test)
```

`lute run analyze` also checks the files `lute run generate` writes. It formats the docs reference with the docs site's Prettier, so run `npm ci` in `docs/` once first.

To see how well a module's spec pins down its behavior, run `lute run mutate workspace/orion-cli/src/<module>.luau`. It makes one small change at a time, runs the module's sibling spec against each, and lists the changes the spec didn't catch. Pass `--spec <path>` when the tests live elsewhere. Some survivors make no real difference, so read each one before writing a test for it.

[`workspace/orion-cli/README.md`](workspace/orion-cli/README.md) maps the code.

## App

Build the CLI first, then from `workspace/orion-app/`:

```sh
npm install
npm run dev
```

Vite starts `orion server start` and proxies `/api` to it. Set `ORION_BIN` to use another CLI binary. Without one, Vite still runs, but the canvas shows empty and nothing is saved, since `orion server start` is the only store.

The server uses a scratch data folder, `workspace/orion-app/.dev-data`, which the first run seeds with a sample canvas from `workspace/orion-app/fixtures/dev-canvas.json`. Delete it to start over. A branch's CLI moves the data it touches to that branch's layout, which an installed Orion from another build can't read, so the dev server stays off your real data unless you ask. Set `ORION_DATA_DIR` to serve another folder, or `ORION_REAL_DATA=1` for the real one.

PR cards show a **VS Code** button when `code` and [`hop`](https://github.com/vocksel/hop) are on the server's `PATH`.

[`workspace/orion-app/README.md`](workspace/orion-app/README.md) maps the code.

### Tests and coverage

`npm test` runs the unit tests. `npm run coverage` also writes a coverage summary and an HTML report to `workspace/orion-app/coverage/`. On pull requests, CI posts the coverage totals as a comment, replacing it on each run.

### Storybook

`npm run storybook` browses component stories without a server. Each story lives beside its component in `workspace/orion-app/src/components/`, with shared sample data in `storySupport/`. The toolbar switches theme, color mode, and colorblind palette. `npm run build-storybook` checks the static build.

### Performance

`npm run perf` compares this checkout against `origin/main` and writes `workspace/orion-app/.perf/report.md`. Pass `-- --base <ref>` to compare against another revision. Install the browser once with `npx playwright install chromium`.

It runs data benchmarks over generated canvases of 1,000 and 5,000 cards, and has Playwright drive a 1,000-card story to count React commits, frames, and main-thread time while idle, panning, zooming, hovering, and dragging. Add `-- --stories perf-canvas--cards-1000,perf-canvas--cards-5000` to profile the larger canvas too. `npx vitest bench --root src` runs the benchmarks alone.

It measures this machine, so close other heavy work while it runs. CI runs the same comparison on pull requests that touch `workspace/orion-app/` once they're ready for review.

## Desktop app

From `workspace/orion-desktop/`:

```sh
npm install
npm run dev
```

The development window uses the app's Vite server on port 5199. `npm run build` builds the CLI and packages it with the canvas, and the packaged app runs `orion server start` itself.

The packaged app saves the port it picks as `server-port` in its own folder (`~/Library/Application Support/com.vocksel.orion` on macOS) and reuses it, so the window keeps one origin and its browser storage across restarts.

## Docs

The docs site in `docs/` is built with VitePress. Run `npm install` and `npm run dev` there to browse it.

The CLI and MCP reference pages are generated from the command table and the MCP tool catalog. After changing a command, option, or MCP tool, run `lute run generate docs` from the repository root and commit what it writes. CI fails when they're out of date.
