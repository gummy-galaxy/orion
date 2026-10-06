# Orion MCP

Orion's local MCP server exposes focused canvas and workspace actions to agents. It calls the Orion CLI for every action, so the CLI remains the only writer and keeps the app's file lock and revision behavior. The server never runs a shell command assembled from tool input.

## Install locally for Codex

Build the current CLI in `cli/` with `lute run install` and `lute run build`, then from the repository root:

```sh
npm ci --prefix mcp
bash mcp/install.sh
```

`mcp/install.sh` copies the server, its dependencies, and the built CLI to `~/.local/share/orion-mcp`, then registers `orion` with `codex mcp add`. The installed server uses the active Orion workspace by default; each tool also accepts an explicit workspace. Run the script again after updating the CLI or MCP server. `codex mcp remove orion` unregisters it.

The MCP server uses the same `ORION_DATA_DIR` override as the CLI. Registration does not grant write approval. In a Codex session with approval policy `never`, the live read worked but Codex rejected a write tool call before it reached Orion. For unattended local edits, a saved approval rule for the Orion CLI is currently the working route. Interactive MCP write calls may still need approval.

## Verify

```sh
ORION_TEST_BIN="$PWD/cli/build/orion" npm test --prefix mcp
codex mcp get orion
```

The test runs a server and client against a temporary Orion data folder and checks a workspace write, a read, error reporting, and literal handling of user text.
