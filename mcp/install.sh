#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/mcp"
cli_bin="${ORION_BIN:-$repo_root/cli/build/orion}"
install_dir="$HOME/.local/share/orion-mcp"

if [[ ! -x "$cli_bin" ]]; then
  echo "Build the Orion CLI first: (cd cli && lute run build)" >&2
  exit 1
fi
if [[ ! -d "$source_dir/node_modules" ]]; then
  echo "Install MCP dependencies first: npm ci --prefix mcp" >&2
  exit 1
fi

mkdir -p "$install_dir"
ditto "$source_dir" "$install_dir"
cp "$cli_bin" "$install_dir/orion"
chmod +x "$install_dir/orion"

node_bin="$(command -v node)"
codex mcp remove orion >/dev/null 2>&1 || true
codex mcp add orion --env "ORION_BIN=$install_dir/orion" -- "$node_bin" "$install_dir/server.mjs"
codex mcp get orion
