# Orion MCP

Orion's local MCP server exposes focused canvas and workspace actions to agents. The JavaScript process is only the MCP transport. It loads the tool catalog with `orion mcp tools` and registers every tool in one loop. A tool call runs `orion mcp call <name>` and writes the arguments as one JSON object on stdin. The CLI maps that object onto the existing command, so it remains the only writer and keeps the file lock and revision behavior. The server never runs a shell command assembled from tool input.

`orion_add_image` imports a local PNG, JPEG, GIF, or WebP file as a canvas node; `orion_images` lists the workspace's image nodes. The CLI copies imported files into that workspace's assets folder.

## Install for Codex, Claude, and Cursor

Build the CLI in `cli/` with `lute run install` and `lute run build`, and install the MCP dependencies with `npm ci --prefix mcp` from the repository root. Then run:

```sh
cli/build/orion mcp register
```

`register` copies the server and the built CLI to an `mcp` folder in Orion's user data folder (`~/Library/Application Support/Orion` on macOS, `%APPDATA%\Orion` on Windows, `~/.local/share/orion` on Linux), then connects whichever of Codex, Claude, and Cursor are installed. Pass `codex`, `claude`, or `cursor` to connect one of them. Claude is registered for your user, so it is available outside this checkout. Cursor reads `~/.cursor/mcp.json`; restart Cursor or toggle the server after registering. Run `orion mcp unregister` to remove those client entries. Run `register` again after updating the CLI or MCP server.

The MCP server uses the same `ORION_DATA_DIR` override as the CLI. Registration does not grant write approval. In a Codex session with approval policy `never`, the live read worked but Codex rejected a write tool call before it reached Orion. For unattended local edits, a saved approval rule for the Orion CLI is currently the working route. Interactive MCP write calls may still need approval.

## Verify

```sh
ORION_TEST_BIN="$PWD/cli/build/orion" npm test --prefix mcp
codex mcp get orion
```

The test runs a server and client against a temporary Orion data folder and checks a workspace write, a read, error reporting, and literal handling of user text.
