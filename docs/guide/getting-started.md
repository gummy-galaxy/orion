# Getting started

Orion hasn't had its first release, so for now you build it from source. [`CONTRIBUTING.md`](https://github.com/gummy-galaxy/orion/blob/main/CONTRIBUTING.md) covers the toolchain and every build.

## The desktop app

The desktop app bundles the canvas with the `orion` CLI and runs its server for you. Build it with `npm run build` in `workspace/orion-desktop/`, then move the app it produces into your Applications folder.

The packaged app keeps one local address across restarts, so each canvas remembers its viewport and detail level.

## The CLI

The CLI reads and changes the same data as the app, and the app picks up every change while it's open. The desktop app ships the binary at `/Applications/Orion.app/Contents/MacOS/orion`, and a local build writes `workspace/orion-cli/build/orion`. Put one on your `PATH`, then run:

```sh
orion help
```

See the [CLI reference](/reference/cli/) for every command, or run `orion help --all` to print them all in the terminal.

## Connect an agent over MCP

`orion mcp start` runs an MCP server over stdin and stdout, so AI clients can discover Orion's canvas tools and call them. Each tool runs an existing CLI command in the same process, so the CLI stays the only writer and never runs a shell command built from tool input.

Add Orion to an MCP client as a stdio server that runs `orion mcp start`, using the full path to the binary. Most clients accept a config entry like this one, or an equivalent `mcp add` command:

```json
{
  "mcpServers": {
    "orion": {
      "command": "/Applications/Orion.app/Contents/MacOS/orion",
      "args": ["mcp", "start"]
    }
  }
}
```

Pass `--canvas <name>` to keep the server on one canvas. Otherwise each call uses the selected canvas unless the tool call names one. Set `ORION_DATA_DIR` in the server's environment to use another [data folder](./data).

See the [MCP reference](/reference/mcp) for every tool.

## Next steps

- [Concepts](./concepts) explains cards, links, groups, and sources.
- [Using the canvas](./canvas) walks through the app.
- [Sources](./sources) brings in your pull requests and issues.
