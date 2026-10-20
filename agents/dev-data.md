# Data folders in development

A CLI built from a branch moves any data folder it touches to that branch's layout, and an installed app from another build can't read the result. Keep branch builds away from the real data folder (`~/Library/Application Support/Orion` on macOS).

- `npm run dev` in `app/`, and the desktop shell's dev window, which runs it, serve `app/.dev-data`. The first run seeds it from `app/fixtures/dev-canvas.json` through `orion apply`. Delete the folder to start over.
- Unit tests, `vitest bench`, Storybook, and `npm run perf` never start a server on the real folder.
- `ORION_DATA_DIR=<folder>` points the dev server, or any CLI command, at another folder. `ORION_REAL_DATA=1` makes the dev server use the real one; set it only when the person asks for it.
- Running `cli/build/orion` yourself uses the real folder unless `ORION_DATA_DIR` is set, so set it on every command a branch build runs. A worktree on an older commit doesn't have the dev server's scratch default either.
- A migration refuses while a server from another build is serving the folder, but a stopped app can't object, so the scratch folder is the protection that counts.
