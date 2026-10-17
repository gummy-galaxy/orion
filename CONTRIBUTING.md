# Contributing

Read [`CHARTER.md`](CHARTER.md) for where Orion is headed and [`DECISIONS.md`](DECISIONS.md) for the calls made along the way. [`AGENTS.md`](AGENTS.md) holds the code style and pull request conventions that people and agents both follow.

## Toolchain

- [Rokit](https://github.com/rojo-rbx/rokit), which installs Lute and StyLua from `rokit.toml`
- Node.js, for the app, the desktop shell, and the docs site
- Rust 1.90 or newer and the Xcode Command Line Tools, for the desktop app

## CLI

The CLI is written in Luau and compiled with [Lute](https://github.com/luau-lang/lute). From `cli/`:

```sh
rokit install
lute pkg install
lute run build
```

That writes `cli/build/orion`. `lute pkg install` fills `~/.loom/store`, which the build reads in place, and Lute can only bundle it from a checkout under your home directory.

Before committing CLI changes, run these from `cli/`:

```sh
lute run analyze
lute test
stylua src cli.luau .lute project.luau loom.config.luau .config.luau ../.lute ../.config.luau
```

To see how well a module's spec pins down its behavior, run `lute run mutate src/<module>.luau`. It makes one small change at a time, runs the module's sibling spec against each, and lists the changes the spec didn't catch. Pass `--spec <path>` when the tests live elsewhere. Some survivors make no real difference, so read each one before writing a test for it.

[`cli/README.md`](cli/README.md) maps the code.

## App

Build the CLI first, then from `app/`:

```sh
npm install
npm run dev
```

Vite starts `orion server start` and proxies `/api` to it. Set `ORION_BIN` to use another CLI binary. Without one, Vite still runs, but the canvas shows empty and nothing is saved, since `orion server start` is the only store.

PR cards show a **VS Code** button when `code` and [`hop`](https://github.com/vocksel/hop) are on the server's `PATH`.

[`app/README.md`](app/README.md) maps the code.

### Storybook

`npm run storybook` browses component stories without a server. Each story lives beside its component in `app/src/components/`, with shared sample data in `storySupport/`. The toolbar switches theme, color mode, and colorblind palette. `npm run build-storybook` checks the static build.

### Performance

`npm run perf` compares this checkout against `origin/main` and writes `app/.perf/report.md`. Pass `-- --base <ref>` to compare against another revision. Install the browser once with `npx playwright install chromium`.

It runs data benchmarks over generated canvases of 1,000 and 5,000 cards, and has Playwright drive a 1,000-card story to count React commits, frames, and main-thread time while idle, panning, zooming, hovering, and dragging. Add `-- --stories perf-canvas--cards-1000,perf-canvas--cards-5000` to profile the larger canvas too. `npx vitest bench --root src` runs the benchmarks alone.

It measures this machine, so close other heavy work while it runs. CI runs the same comparison on pull requests that touch `app/` once they're ready for review.

## Desktop app

From `desktop/`:

```sh
npm install
npm run dev
```

The development window uses the app's Vite server on port 5199. `npm run build` builds the CLI and packages it with the canvas, and the packaged app runs `orion server start` itself.

The packaged app saves the port it picks as `server-port` in its own folder (`~/Library/Application Support/com.vocksel.orion` on macOS) and reuses it, so the window keeps one origin and its browser storage across restarts.

## Docs

The docs site in `docs/` is built with VitePress. Run `npm install` and `npm run dev` there to browse it.

The CLI and MCP reference pages are generated from the command table and the MCP tool catalog. After changing a command, option, or MCP tool, run `lute run docs` from the repository root and commit what it writes. CI fails when they're out of date.
